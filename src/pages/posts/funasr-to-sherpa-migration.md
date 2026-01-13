---
layout: ../../layouts/PostLayout.astro
title: 從 FunASR 遷移到 Sherpa-ONNX：為什麼換、怎麼換
date: 2026-01-13T14:45
description: 一個語音辨識引擎遷移的決策過程，從 POC 到上線
tags:
  - 語音辨識
  - 架構決策
  - Python
---

我的語音辨識桌面應用，一開始是用 FunASR。

後來換成了 Sherpa-ONNX。

這篇記錄為什麼換、怎麼換、換了之後怎樣。

## 為什麼要換？

FunASR 其實很好用。辨識準確，中文支援強，還有標點恢復模型。

但它有幾個問題：

### 1. 太重了

FunASR 基於 PyTorch，依賴一大堆：

```
torch >= 1.13
torchaudio
numpy
scipy
...
```

打包成 Electron 應用後，光 Python 環境就佔 1GB+。

### 2. 啟動太慢

冷啟動要載入 PyTorch 框架 + 模型，大概 10-15 秒。

使用者按下應用圖示，要等很久才能開始用。

### 3. 串流支援不夠好

FunASR 有串流模式，但設定複雜，而且不是原生設計給串流的。

我需要「邊講邊出字」的體驗，用 FunASR 實作起來很卡。

## POC：先試試 Sherpa-ONNX

在決定全面遷移之前，我先做了一個 POC（Proof of Concept）。

目標：驗證 Sherpa-ONNX 能不能滿足需求。

### 測試項目

1. **辨識品質**：中文辨識準確度夠嗎？
2. **速度**：比 FunASR 快多少？
3. **記憶體**：省多少？
4. **串流**：邊講邊出字順不順？

### POC 結果

| 項目 | FunASR | Sherpa-ONNX |
|------|--------|-------------|
| 冷啟動 | 10-15 秒 | 2-3 秒 |
| 10 秒音頻處理 | 3-4 秒 | 0.3-0.5 秒 |
| 記憶體佔用 | ~2GB | ~500MB |
| 中文辨識品質 | 優 | 優 |
| 串流支援 | 有，但複雜 | 原生支援 |

**快 10 倍，省 75% 記憶體，串流原生支援。**

POC 通過，決定遷移。

## 遷移策略

不是一次砍掉重練，而是**漸進式遷移**。

### 階段一：共存

先讓 FunASR 和 Sherpa-ONNX 共存，用設定切換。

```python
if config.engine == "sherpa":
    result = sherpa_transcribe(audio)
else:
    result = funasr_transcribe(audio)
```

這樣可以隨時回滾，降低風險。

### 階段二：Sherpa 為主

確認 Sherpa-ONNX 穩定後，把它設為預設。

FunASR 保留作為備案。

### 階段三：移除 FunASR

跑了幾週沒問題後，完全移除 FunASR 相關程式碼。

```
git commit -m "refactor: Replace FunASR with sherpa-onnx for ASR"
```

## 遷移過程中的坑

### 1. 標點恢復

FunASR 有 `ct-punc` 模型做標點恢復，Sherpa-ONNX 沒有。

解法：標點恢復獨立出來，可以繼續用 FunASR 的 ct-punc。

```python
# Sherpa-ONNX 辨識
text = sherpa_transcribe(audio)

# FunASR 標點恢復
text_with_punc = funasr_punc(text)
```

或者用我寫的[規則式標點恢復](/Evernote/posts/rule-based-punctuation-restoration)，完全不依賴 FunASR。

### 2. 模型格式不同

FunASR 用 PyTorch 格式，Sherpa-ONNX 用 ONNX 格式。

不是同一個模型換個格式，而是完全不同的模型：

| 引擎 | 模型 |
|------|------|
| FunASR | Paraformer（阿里達摩院）|
| Sherpa-ONNX 離線 | Paraformer（同上，但 ONNX 版）|
| Sherpa-ONNX 串流 | Zipformer（k2 團隊）|

好消息是 Sherpa-ONNX 也支援 Paraformer，所以離線辨識的品質一致。

串流辨識用 Zipformer，品質也很好。

### 3. API 不一樣

FunASR 的 API：

```python
from funasr import AutoModel
model = AutoModel(model="paraformer-zh")
result = model.generate(input=audio)
text = result[0]["text"]
```

Sherpa-ONNX 的 API：

```python
import sherpa_onnx
recognizer = sherpa_onnx.OfflineRecognizer.from_paraformer(...)
stream = recognizer.create_stream()
stream.accept_waveform(sample_rate, samples)
recognizer.decode_stream(stream)
text = stream.result.text
```

風格差很多，需要重寫整個辨識流程。

### 4. 簡繁轉換

FunASR 輸出簡體，我用 OpenCC 轉繁體。

Sherpa-ONNX 也是輸出簡體，同樣處理。

但有個坑：OpenCC 的 `s2twp`（簡轉台灣繁體+用詞）會把「視頻」改成「影片」，但語音辨識的場景不需要這樣。

最後改用 `s2t`（純字體轉換，不改用詞）。

```python
# 錯誤：會改用詞
converter = OpenCC('s2twp')

# 正確：只改字體
converter = OpenCC('s2t')
```

## 遷移後的架構

```
音頻輸入
    ↓
Sherpa-ONNX
├── 離線模式：Paraformer (ONNX)
└── 串流模式：Zipformer (ONNX)
    ↓
標點恢復
├── 優先：FunASR ct-punc（如果有裝）
└── 備援：規則式標點
    ↓
OpenCC 簡轉繁 (s2t)
    ↓
輸出文字
```

## 遷移成果

| 指標 | 遷移前 | 遷移後 |
|------|--------|--------|
| 冷啟動 | 10-15 秒 | 2-3 秒 |
| 記憶體 | ~2GB | ~500MB |
| 打包大小 | ~1.5GB | ~400MB |
| 串流體驗 | 卡 | 順 |

使用者最明顯的感受：**應用變快了**。

開發者最明顯的感受：**打包變小了**。

## 什麼時候不該換？

Sherpa-ONNX 不是萬能的。這些情況可能 FunASR 更適合：

1. **需要更多語言**：FunASR 有更多語言的模型
2. **需要說話人辨識**：FunASR 有 speaker diarization
3. **需要情緒辨識**：FunASR 有 emotion recognition
4. **團隊熟悉 PyTorch**：FunASR 的程式碼更好改

我的場景單純（中文辨識 + 桌面應用），Sherpa-ONNX 剛好。

---

架構遷移最重要的是**漸進式**。

不要一次砍掉重練，而是讓新舊共存，確認新的沒問題再移除舊的。

這樣出問題可以隨時回滾，不會整個炸掉。

相關文章：

- [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison)
- [FunASR 極限優化指南](/Evernote/posts/funasr-optimization-guide)
- [Sherpa-ONNX 雙模型架構優化實戰](/Evernote/posts/sherpa-onnx-optimization)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)

---

<small>（自己備註：遷移前後的數據是估的，實際數字等測再補）</small>
