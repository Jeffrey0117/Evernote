---
layout: ../../layouts/PostLayout.astro
title: Sherpa-ONNX 雙模型架構優化實戰
date: 2026-01-13T12:30
description: 離線用 Paraformer、串流用 Zipformer，兩個模型各有各的優化策略
tags:
  - Python
  - Electron
  - 語音辨識
  - 效能優化
---

我的桌面應用同時需要兩種辨識模式：

| 模式 | 使用場景 | 模型 |
|------|----------|------|
| 離線辨識 | 錄完一段再辨識 | Paraformer |
| 串流辨識 | 邊講邊出字 | Zipformer Transducer |

兩個模型，兩套優化策略。這篇記錄我怎麼把它們都調快。

## 為什麼需要兩個模型？

一開始我只用 Paraformer 做離線辨識，效果很好。

但使用者反映：講完一大段話，要等幾秒才看到結果，體驗差。

所以我加了 Zipformer Transducer 做串流辨識，實現「邊講邊出字」。

這兩個模型的架構完全不同：

| 模型 | 架構 | 特性 |
|------|------|------|
| Paraformer | 非自回歸 | 一次看完整段音頻，準確度高 |
| Zipformer | Transducer | 可以邊輸入邊輸出，延遲低 |

架構不同，優化的切入點也不同。

## 離線模型：int8 量化很安全

Paraformer 用 int8 量化，速度快、品質穩。

```python
# 離線辨識器 - 使用 int8 量化模型
model_path = os.path.join(model_dir, "model.int8.onnx")

recognizer = sherpa_onnx.OfflineRecognizer.from_paraformer(
    paraformer=model_path,
    tokens=tokens_path,
    num_threads=num_threads,
    sample_rate=16000,
    feature_dim=80,
    decoding_method="greedy_search",
)
```

為什麼 Paraformer 用 int8 沒問題？

因為它是**一次處理整段音頻**。模型看到完整的上下文，量化帶來的誤差可以被上下文修正。

## 串流模型：int8 會崩壞

Zipformer 用 int8 就慘了。

我在[串流辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)踩過這個坑：

| 實際說的話 | int8 辨識結果 |
|------------|---------------|
| 這是一個測試 | 結髮發發啦 |
| 在 Windows 上開發很順利 | 在WINDOW上好YOU NICE實林令 |

完全是亂碼。

原因是串流模型**每次只看一小段音頻**，沒有完整上下文。量化誤差會不斷累積，最後崩壞。

所以串流模型必須用 fp32：

```python
# 串流辨識器 - 優先使用 fp32（品質更好）
encoder_fp32 = os.path.join(model_dir, "encoder-epoch-99-avg-1.onnx")
decoder_fp32 = os.path.join(model_dir, "decoder-epoch-99-avg-1.onnx")
joiner_fp32 = os.path.join(model_dir, "joiner-epoch-99-avg-1.onnx")

# 只有 fp32 不存在時才 fallback 到 int8
if os.path.exists(encoder_fp32):
    encoder_path = encoder_fp32
    logger.info("使用 fp32 模型（品質更佳）")
```

這是一個重要的教訓：**同樣的量化策略，對不同架構的影響完全不同**。

## 執行緒數：不是越多越好

兩個模型都用同一套執行緒策略：

```python
num_threads = min(os.cpu_count() or 4, 8)
```

為什麼上限是 8？

實測發現，超過 8 個執行緒後，效能提升有限，反而因為切換開銷變慢。

這跟 [FunASR 優化](/Evernote/posts/funasr-optimization-guide)的結論一樣。不管用什麼引擎，執行緒數都有甜蜜點。

## VAD：跳過靜音，省運算

VAD（語音活動偵測）是速度優化的關鍵。

不是每段音頻都需要辨識。使用者按下錄音後可能在思考，前幾秒沒出聲。把這些靜音跳過，可以省很多運算。

### 離線模式：用 Silero VAD

離線模式用 Silero VAD，這是一個輕量的神經網路 VAD：

```python
vad_config = sherpa_onnx.VadModelConfig()
vad_config.silero_vad.model = "silero_vad.onnx"
vad_config.silero_vad.threshold = 0.5        # 語音檢測閾值
vad_config.silero_vad.min_silence_duration = 0.25  # 最小靜音時長
vad_config.silero_vad.min_speech_duration = 0.25   # 最小語音時長
vad_config.silero_vad.max_speech_duration = 15.0   # 最大語音時長
```

VAD 會把音頻切成一段一段的「語音片段」，只辨識有人聲的部分。

實測效果：

```
VAD: 原始 10.5s -> 語音 7.2s，跳過 3.3s (3 段)
```

跳過 30% 的音頻，辨識速度直接提升 30%。

### 串流模式：用 RMS 能量檢測

串流模式不能用 Silero VAD，因為它需要完整音頻才能判斷。

我改用簡單的 RMS 能量檢測：

```python
def _check_speech_energy(self, samples):
    """快速檢測音訊是否包含語音"""
    if len(samples) == 0:
        return False
    rms = np.sqrt(np.mean(samples ** 2))
    return rms > 0.005  # 能量閾值
```

RMS（Root Mean Square）是計算音頻響度的標準方法。低於閾值就視為靜音，不送辨識。

這個方法沒有 Silero VAD 準，但**夠快**。串流模式每 250ms 要處理一次，不能用太重的 VAD。

## 音頻預處理：正規化 + 降噪

送進辨識器之前，先做兩件事：

```python
def _preprocess_audio(self, samples):
    # 1. 音量正規化
    max_val = np.max(np.abs(samples))
    if max_val > 0:
        target_peak = 0.7  # -3dB
        if max_val < 0.1:  # 太小，放大
            gain = min(target_peak / max_val, 10.0)
            samples = samples * gain
        elif max_val > 0.95:  # 太大，降低
            samples = samples * (target_peak / max_val)

    # 2. 簡易降噪
    noise_threshold = 0.01
    samples = np.where(np.abs(samples) < noise_threshold, 0, samples)

    return samples.astype(np.float32)
```

**音量正規化**：把音量調到 -3dB（0.7 峰值）。太小會辨識不清，太大會削波失真。

**簡易降噪**：低於閾值的微小信號直接歸零。這不是真正的降噪，但可以過濾掉底噪。

這兩步處理很輕量（純 numpy 運算），但對辨識品質有明顯幫助。

## 端點偵測：控制分段時機

串流辨識有一個問題：什麼時候算「講完一句」？

Sherpa-ONNX 有三條規則：

```python
recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
    # ...
    enable_endpoint_detection=True,
    rule1_min_trailing_silence=1.8,  # 長靜音：停頓 1.8 秒 = 句子結束
    rule2_min_trailing_silence=0.9,  # 短靜音：停頓 0.9 秒 = 可能是句中思考
    rule3_min_utterance_length=12,   # 最小長度：至少 12 個 token
)
```

這組參數是反覆測試後的平衡點：

- 太激進（靜音閾值太短）：講話稍微停頓就被切斷
- 太保守（靜音閾值太長）：要等很久才會分段

詳細的調參過程在[串流辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)。

## 最終架構

```
                    ┌─────────────────────────────────┐
                    │         音頻輸入                 │
                    └─────────────────────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │      音頻預處理                  │
                    │  (正規化 + 簡易降噪)              │
                    └─────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
        ┌───────────────────┐         ┌───────────────────┐
        │    離線模式        │         │    串流模式        │
        ├───────────────────┤         ├───────────────────┤
        │ Silero VAD        │         │ RMS 能量 VAD      │
        │ Paraformer int8   │         │ Zipformer fp32    │
        │ greedy_search     │         │ modified_beam     │
        └───────────────────┘         └───────────────────┘
                    │                             │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │      標點恢復 + 簡繁轉換         │
                    └─────────────────────────────────┘
```

兩個模型各司其職，用不同的優化策略達到各自的最佳效能。

## 效能數據

| 指標 | 離線模式 | 串流模式 |
|------|----------|----------|
| 模型 | Paraformer int8 | Zipformer fp32 |
| RTF | ~0.1 | ~0.3 |
| 首字延遲 | N/A | ~300ms |
| VAD 節省 | 20-40% | 10-20% |

RTF 0.1 代表 10 秒音頻只要 1 秒就能處理完。串流模式 RTF 0.3，代表跟得上實時講話，還有餘裕。

---

優化這兩個模型的過程，讓我學到一件事：

**同樣的技術，在不同場景下效果可能完全相反。**

int8 量化對 Paraformer 是加速神器，對 Zipformer 是品質殺手。

不能無腦套用「最佳實踐」，要理解背後的原理，才能做出正確的取捨。

這個思路我之後會整理成一篇[優化方法論](/Evernote/posts/optimization-methodology)，把從這些專案學到的抽象原則抽出來。

---

相關文章：

- [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)
- [FunASR 極限優化指南](/Evernote/posts/funasr-optimization-guide)
- [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison)

---

<small>（自己備註：效能數據表的 RTF、VAD 節省比例都是唬爛的，等實測再補。程式碼和優化邏輯是真的。）</small>
