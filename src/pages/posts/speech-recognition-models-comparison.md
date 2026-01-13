---
layout: ../../layouts/PostLayout.astro
title: 離線語音辨識模型大亂鬥
date: 2026-01-13T11:50
description: Whisper、Faster Whisper、FunASR、Sherpa-ONNX 實測比較，找出最適合桌面應用的方案
tags:
  - Python
  - 語音辨識
  - Whisper
---

做語音轉文字桌面應用，第一個問題就是：**用哪個模型？**

我前前後後試了四五種方案，踩了不少坑。這篇整理一下各個模型的優缺點。

## 先講結論

| 模型 | 速度 | 準確度 | 記憶體 | 適合場景 |
|------|------|--------|--------|----------|
| Whisper | 慢 | 極高 | 大 | 有 GPU、不趕時間 |
| Faster Whisper | 中 | 極高 | 中 | 有 GPU、要快一點 |
| FunASR | 快 | 高 | 大 | 中文為主、可優化 |
| **Sherpa-ONNX** | 極快 | 高 | 小 | 桌面應用首選 |

我最後選了 Sherpa-ONNX，因為它**輕、快、離線**，最適合塞進 Electron 應用。

## Whisper：準到不行，但超級慢

[Whisper](https://github.com/openai/whisper) 是 OpenAI 出的語音辨識模型，準確度沒話說。

但問題是：**慢到不行**。

```python
import whisper
model = whisper.load_model("base")
result = model.transcribe("audio.wav")
```

一段 30 秒的音頻，在我的 M1 Mac 上要跑 40 秒。

比實際講話還久，這怎麼用？

而且模型很大：

| 模型 | 大小 | 速度 |
|------|------|------|
| tiny | 39MB | 勉強能用 |
| base | 74MB | 有點慢 |
| small | 244MB | 很慢 |
| medium | 769MB | 超慢 |
| large | 1.5GB | 別想了 |

用 tiny 速度勉強，但準確度掉很多。用 base 以上，速度又不行。

## Faster Whisper：快一點，但還是不夠

[Faster Whisper](https://github.com/guillaumekln/faster-whisper) 用 CTranslate2 重新實作 Whisper，號稱快 4 倍。

```python
from faster_whisper import WhisperModel
model = WhisperModel("base", compute_type="int8")
segments, info = model.transcribe("audio.wav")
```

實測確實快不少，但還是不夠即時。

而且它需要 GPU 才能發揮實力。純 CPU 跑的話，優勢不明顯。

## FunASR：中文神器，但要調教

[FunASR](https://github.com/modelscope/FunASR) 是阿里達摩院出的，專門針對中文優化。

```python
from funasr import AutoModel
model = AutoModel(model="paraformer-zh")
result = model.generate(input="audio.wav")
```

中文辨識準確度很高，而且有現成的標點恢復模型 `ct-punc`。

但預設設定下，速度還是不夠快。

**經過一番優化後**，我把 FunASR 調到跟 Sherpa-ONNX 差不多快，甚至比 Whisper Flow 和 Typeless 都快。

這個優化過程很有趣，之後會專門寫一篇：[FunASR 極限優化指南](/Evernote/posts/funasr-optimization-guide)。

## Sherpa-ONNX：目前的最終選擇

[Sherpa-ONNX](https://github.com/k2-fsa/sherpa-onnx) 是用 ONNX Runtime 跑推理的離線語音辨識框架。

```python
import sherpa_onnx
recognizer = sherpa_onnx.OfflineRecognizer.from_paraformer(...)
result = recognizer.create_stream()
```

優點：

1. **超級快**：比 FunASR PyTorch 版快 10 倍
2. **超級輕**：記憶體省 75%
3. **完全離線**：不用網路，不用擔心隱私
4. **支援串流**：可以邊錄邊辨識

我的桌面應用最後就是用這個。

## VAD：不是每段音頻都要辨識

講到這裡，要提一個重要的東西：**VAD（Voice Activity Detection）**。

VAD 是「語音活動偵測」，用來判斷音頻裡面有沒有人在講話。

為什麼重要？因為**不是每段音頻都需要送去辨識**。

想像一下：使用者按下錄音，但前 3 秒在想要講什麼，沒出聲。

如果把這 3 秒的靜音也送去辨識，就是浪費運算資源。

```python
# 用 Silero VAD 偵測語音活動
import torch
model, utils = torch.hub.load('snakers4/silero-vad', 'silero_vad')
speech_timestamps = utils[0](audio, model)
```

Sherpa-ONNX 內建 Silero VAD，可以自動過濾靜音段落。

我在串流辨識裡也自己實作了簡單的 VAD：用 RMS 音量判斷是否有聲音，超過一定時間的靜音就觸發分段。

串流辨識的完整調教過程，包含 VAD、端點偵測、模型選擇，可以看這篇：[串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)。

## 標點恢復

語音辨識輸出的文字沒有標點，要另外處理。

兩種方案：

1. **深度學習**：用 FunASR 的 `ct-punc` 模型，準確度 95%，但要 500MB
2. **規則式**：用正規表達式匹配詞彙和句式，準確度 80%，只要 5KB

我兩種都用。優先用 ct-punc，環境不支援就 fallback 到規則式。

規則式的詳細設計，可以看這篇：[用 5KB 正規表達式幹掉 500MB 深度學習模型](/Evernote/posts/rule-based-punctuation-restoration)。

## 選擇指南

| 你的情況 | 推薦方案 |
|----------|----------|
| 有 GPU、追求極致準確 | Whisper large |
| 有 GPU、要快一點 | Faster Whisper |
| 中文為主、願意花時間調教 | FunASR（優化版） |
| 桌面應用、要輕量 | **Sherpa-ONNX** |
| 嵌入式、資源超有限 | Sherpa-ONNX + int8 |

## 我的技術棧

最後整理一下我目前用的組合：

```
音頻輸入
  ↓
VAD 過濾靜音（Silero VAD）
  ↓
語音辨識（Sherpa-ONNX Paraformer / Zipformer）
  ↓
標點恢復（ct-punc / 規則式）
  ↓
簡轉繁（OpenCC）
  ↓
輸出文字
```

這套組合在我的 Electron 應用裡跑得很順，冷啟動 3 秒，辨識速度比實時快 10 倍以上。

---

下一篇會詳細講 FunASR 的優化過程。當初花了不少時間調參數，最後把速度拉到跟 Sherpa-ONNX 差不多，甚至比一些商業方案還快。

敬請期待：[FunASR 極限優化指南](/Evernote/posts/funasr-optimization-guide)
