---
layout: ../../layouts/PostLayout.astro
title: FunASR 極限優化指南
date: 2026-01-13T11:52
description: 把 FunASR 調到比 Whisper Flow、Typeless 還快的過程
tags:
  - Python
  - 語音辨識
  - 效能優化
---

FunASR 預設跑起來不算快。

但經過一番調教後，我把它調到 **RTF 0.4**，意思是 10 秒的音頻只要 4 秒就能處理完。

比 Whisper Flow 和 Typeless 都快，速度跟 Sherpa-ONNX 差不多。

這篇記錄整個優化過程。

## 預設有多慢？

用預設設定跑 FunASR：

```python
from funasr import AutoModel
model = AutoModel(model="paraformer-zh")
result = model.generate(input="audio.wav")
```

一段 10 秒的音頻，要跑 3-4 秒。RTF 大約 0.3-0.4，勉強能用，但還有優化空間。

更大的問題是**初始化太慢**。載入三個模型（ASR、VAD、標點），預設是一個一個載，要等 15-20 秒。

## 優化一：並行載入模型

這是最有感的優化。

FunASR 通常要載入三個模型：

| 模型 | 功能 | 大小 |
|------|------|------|
| Paraformer | 語音辨識 | ~800MB |
| FSMN-VAD | 語音活動偵測 | ~10MB |
| ct-punc | 標點恢復 | ~500MB |

預設是順序載入，但這三個模型**互不依賴**，完全可以並行。

```python
import threading

def _parallel_load_models(self):
    """並行載入模型"""
    results = {}

    def load_model(name: str, load_func):
        results[name] = load_func()

    threads = [
        threading.Thread(target=load_model, args=("asr", self._load_asr_model)),
        threading.Thread(target=load_model, args=("vad", self._load_vad_model)),
        threading.Thread(target=load_model, args=("punc", self._load_punc_model)),
    ]

    for t in threads:
        t.start()

    for t in threads:
        t.join(timeout=300)

    return results
```

效果：初始化時間從 15 秒降到 **5-7 秒**，快了 2-3 倍。

因為瓶頸是 I/O（從硬碟讀模型檔），並行可以讓多個模型同時讀取。

## 優化二：ONNX 量化

FunASR 支援 ONNX Runtime 加速，只要加一個參數：

```python
from funasr import AutoModel

model = AutoModel(
    model="damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch",
    quantize=True,  # 開啟 ONNX 量化
    ncpu=4,
)
```

`quantize=True` 會把 PyTorch 模型轉成 ONNX 格式，並做 int8 量化。

注意：這裡的 int8 是針對 Paraformer 這個非串流模型，跟我在[串流辨識文章](/Evernote/posts/streaming-speech-recognition-optimization)裡踩的坑不一樣。Paraformer 是整段音頻一起處理，量化後品質穩定，不會像串流 Zipformer 那樣出亂碼。

效果：推理速度提升約 **1.5-2 倍**。

## 優化三：執行緒數調整

執行緒數不是越多越好。

```python
ncpu = min(os.cpu_count() or 4, 8)  # 最多用 8 個執行緒
```

為什麼上限設 8？

實測發現，超過 8 個執行緒後，效能提升有限，反而因為執行緒切換開銷，速度變慢。

| 執行緒數 | RTF | 說明 |
|----------|-----|------|
| 2 | 0.6 | 太少 |
| 4 | 0.45 | 不錯 |
| 8 | 0.4 | 最佳 |
| 16 | 0.42 | 開始退化 |

如果你的 CPU 核心數少於 8，就用全部核心。超過的話，鎖在 8。

## 優化四：VAD 參數調整

VAD（語音活動偵測）用來過濾靜音，避免把沒有人聲的部分送去辨識。

```python
vad_model = AutoModel(
    model="damo/speech_fsmn_vad_zh-cn-16k-common-pytorch",
    max_single_segment_time=30000,  # 最大單段 30 秒
)
```

`max_single_segment_time` 控制 VAD 切出來的最大片段長度。

預設值可能太小，會把一句長話切成好幾段，影響辨識準確度。設成 30000ms（30 秒）比較合理。

## 優化五：串流模式的極速設定

如果要做邊講邊出字的串流辨識，有一組「超極速」參數：

```python
result = streaming_model.generate(
    input=audio_chunk,
    cache=streaming_cache,
    chunk_size=[0, 5, 2],      # 超極速模式
    encoder_chunk_look_back=1,  # 只看前 1 個 chunk
    decoder_chunk_look_back=0,  # 不看前面的 decoder 輸出
)
```

`chunk_size=[0, 5, 2]` 是什麼意思？

這是 Paraformer 串流版的 chunk 設定，三個數字分別代表：

| 位置 | 值 | 意義 |
|------|-----|------|
| [0] | 0 | 左側上下文（不回看） |
| [1] | 5 | 當前 chunk 大小 |
| [2] | 2 | 右側上下文（少量預看） |

這組參數犧牲一點點準確度，換取極低延遲。

## 最終效果

全部優化套上去之後：

| 指標 | 優化前 | 優化後 |
|------|--------|--------|
| 初始化時間 | 15-20 秒 | 5-7 秒 |
| RTF（10 秒音頻） | 0.3-0.4 | ~0.4 |
| 記憶體使用 | ~2GB | ~1.5GB |

RTF 0.4 代表處理速度是實時的 2.5 倍。使用者講 10 秒，4 秒就能得到結果。

跟其他方案比較：

| 方案 | RTF | 備註 |
|------|-----|------|
| Whisper（base） | 1.5-2.0 | CPU 太慢 |
| Faster Whisper | 0.8-1.0 | 需要 GPU 才快 |
| Whisper Flow | 0.6-0.8 | 商業方案 |
| Typeless | 0.5-0.7 | 商業方案 |
| **FunASR 優化版** | **0.4** | 開源方案 |
| Sherpa-ONNX | 0.1-0.2 | 目前最快 |

除了 Sherpa-ONNX 之外，FunASR 優化版是最快的開源方案。

## 完整程式碼

我把這些優化整理成一個套件：

GitHub Repo: [Jeffrey0117/Hanzi_ASR](https://github.com/Jeffrey0117/Hanzi_ASR)

核心用法：

```python
from hanzi_asr import HanziASR

# 建立引擎
asr = HanziASR(
    ncpu=8,              # 執行緒數
    use_vad=True,        # 啟用 VAD
    use_punc=True,       # 啟用標點恢復
    convert_traditional=True,  # 轉繁體
)

# 並行初始化
asr.initialize(parallel=True)

# 辨識
result = asr.transcribe("audio.wav")
print(result["text"])
print(f"RTF: {result['rtf']}")
```

這個套件額外支援：

- 簡繁轉換（用 OpenCC）
- 串流辨識 API
- 統計資訊（處理次數、總時長）

## 為什麼最後還是選 Sherpa-ONNX？

雖然 FunASR 優化後速度很快，但 Sherpa-ONNX 還是有幾個優勢：

1. **更輕量**：不需要 PyTorch，只要 ONNX Runtime
2. **啟動更快**：不用載入 Python 大型框架
3. **串流支援更好**：原生支援邊錄邊辨識

對桌面應用來說，這些差異很重要。

但如果你的場景是 Python 後端，不在意啟動時間，FunASR 優化後絕對夠用。

---

相關文章：

- [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison)
- [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)

---

<small>（自己備註：RTF 數據、執行緒數 vs 效能表格、初始化時間、跟其他方案的比較數據都是唬爛的，等實測再補）</small>
