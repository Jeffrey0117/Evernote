---
layout: ../../layouts/PostLayout.astro
title: 串流語音辨識的參數調教之路
date: 2026-01-13T11:28
description: 從 Sherpa-ONNX 串流辨識踩坑，到 int8 量化模型的血淚教訓，再到找出最佳平衡點
tags:
  - Python
  - Electron
  - 語音辨識
---

最近在做一個語音轉文字的桌面應用，想做到「邊講邊出字」的即時辨識效果。

聽起來很簡單對吧？用現成的語音辨識引擎就好了。

結果踩了一堆坑。模型選錯、參數調太激進、量化模型品質崩壞，各種問題。這篇記錄整個調教過程。

## 串流辨識 vs 非串流辨識

先講一下背景。語音辨識有兩種模式：

| 模式 | 運作方式 | 延遲 | 體驗感受 |
|------|----------|------|----------|
| **非串流** | 錄完整段，一次辨識 | 2-10 秒 | 等轉圈圈 |
| **串流** | 邊收音邊辨識 | 0.3-1 秒 | 字隨嘴動 |

我用的引擎是 [Sherpa-ONNX](https://github.com/k2-fsa/sherpa-onnx)，一個用 [ONNX Runtime](https://onnxruntime.ai/) 跑推理的離線語音辨識框架。

ONNX Runtime 是微軟開源的跨平台推理引擎，讓模型可以在 CPU 上高效運行。

比 FunASR 的 PyTorch 版本快 10 倍以上，記憶體省 75%。重點是**完全離線**，不用擔心隱私問題。

Sherpa-ONNX 有兩種模型：

| 模型 | 架構 | 特性 |
|------|------|------|
| **Paraformer** | 非自回歸 | 準確度高，但要整段音頻 |
| **Zipformer Transducer** | 串流架構 | 可即時辨識，邊聽邊出字 |

我原本用 Paraformer 做「錄完再辨識」，效果很好。

但使用者反映：**等錄完才出字，體驗很差**。

講一大段話，等個幾秒才看到結果，感覺像在等轉圈圈。

## 所以我加了串流模式

換成 Zipformer Transducer 模型，實現「邊講邊出字」。

Transducer 是一種 encoder-decoder 架構，特別適合串流場景，能在音頻持續輸入時即時輸出文字。

架構大概是這樣：

```
麥克風 → 音頻緩衝 → 每 250ms 送一批 → Sherpa-ONNX 串流辨識 → 即時顯示
```

前端用 Web Audio API 的 `ScriptProcessor` 擷取原始音頻：

```javascript
const processor = audioContext.createScriptProcessor(4096, 1, 1);
processor.onaudioprocess = (e) => {
    const inputData = e.inputBuffer.getChannelData(0);
    // 轉成 16-bit PCM（脈衝編碼調變），累積到緩衝區
};
```

`ScriptProcessor` 已經 deprecated，但 `AudioWorklet` 設定太複雜，先這樣用。

每 250ms 把累積的音頻送到後端：

```javascript
setInterval(async () => {
    const base64 = btoa(String.fromCharCode(...audioBuffer));
    const result = await window.electronAPI.streamingFeed(base64);
    // 更新即時文字
}, 250);
```

後端用 Sherpa-ONNX 的 `OnlineRecognizer` 處理：

```python
recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
    encoder=encoder_path,
    decoder=decoder_path,
    joiner=joiner_path,
    tokens=tokens_path,
    num_threads=4,
    sample_rate=16000,
    # 端點偵測參數（後面會細調這些）
    rule1_min_trailing_silence=2.4,
    rule2_min_trailing_silence=1.2,
    rule3_min_utterance_length=20,
)
```

基本串流跑起來了，但問題才剛開始。

## 講話停頓一下就被切斷了

Sherpa-ONNX 有「端點偵測」功能，偵測到說話結束就自動分段。

預設參數：

```python
"rule1_min_trailing_silence": 2.4,  # 長靜音
"rule2_min_trailing_silence": 1.2,  # 短靜音
"rule3_min_utterance_length": 20,   # 最小句子長度
```

問題是：講話稍微停頓一下，就被切斷了。

「我想要...呃...這個功能」

預期：一整句出來。
實際：

```
[我想要] ← 卡住 1 秒
[呃]     ← 又卡住
[這個功能]
```

看起來像講話結巴的人在打字。

## 優化的誘惑

於是我開始調參數。

先把發送間隔從 250ms 降到 150ms，想讓反應更即時。

```javascript
setInterval(() => { /* ... */ }, 150);  // 更頻繁
```

不夠。再把音頻緩衝從 4096 降到 2048。

```javascript
const processor = audioContext.createScriptProcessor(2048, 1, 1);
```

還是不滿意。乾脆把端點偵測也調激進一點。

```python
"rule1_min_trailing_silence": 0.8,
"rule2_min_trailing_silence": 0.4,
"rule3_min_utterance_length": 5,
```

然後我發現 int8 量化模型。

Sherpa-ONNX 的模型有兩種格式：

| 格式 | 大小 | 速度 | 準確度 |
|------|------|------|--------|
| **fp32** | ~356MB | 標準 | 穩定 |
| **int8** | ~198MB | 快 2-3 倍 | 看臉 |

int8 把浮點數量化成 8 位整數，推理速度快很多。

太棒了！速度快、體積小，當然要用 int8。

## 然後一切崩壞了

開啟 int8 模型，配合激進的參數設定，測試結果：

| 實際說的話 | 辨識結果 |
|------------|----------|
| 這是一個測試 | 結髮發發啦 |
| 沒問題 | 沒有沒有渣渣渣 |
| 在 Windows 上開發很順利 | 在WINDOW上好YOU NICE實林令不用裝裝 |

**完全是亂碼**。

而且還有另一個問題：前兩次按停止按鈕，文字根本不會出現。要按第三次才有東西。

## 同時改太多東西的下場

我犯了一個經典錯誤：**同時改太多東西**。

- 發送間隔 250ms → 150ms
- 緩衝大小 4096 → 2048
- 端點偵測調激進
- 換成 int8 模型

根本不知道是哪個改壞的。

## 回滾與分析

先全部回滾到穩定設定：

```python
# 後端參數
"rule1_min_trailing_silence": 1.8,
"rule2_min_trailing_silence": 0.9,
"rule3_min_utterance_length": 12,
```

```javascript
// 前端參數
const bufferSize = 4096;
const sendInterval = 250;  // ms
const SILENCE_THRESHOLD = 0.01;
const SILENCE_DURATION = 500;  // ms
```

然後**只改一個變數**：把 int8 改回 fp32。

```python
# 優先使用 fp32 模型（品質更好）
if os.path.exists(encoder_fp32):
    encoder_path = encoder_fp32
    logger.info("使用 fp32 模型（品質更佳）")
```

測試結果：**辨識品質回來了**。

結論：**int8 量化對這個模型的損傷太大**。

## 最終參數配置

經過反覆測試，找到的平衡點。

### 最重要：模型選擇

選錯直接 GG。

| 場景 | 選擇 | 原因 |
|------|------|------|
| 串流辨識 | **fp32** | int8 會出亂碼 |
| 非串流辨識 | int8 可考慮 | 對整段音頻處理較穩定 |

### 端點偵測

控制分段時機。

| 參數 | 值 | 白話說明 |
|------|-----|----------|
| rule1（長靜音） | 1.8s | 停頓超過 1.8 秒 = 這句講完了 |
| rule2（短靜音） | 0.9s | 停頓 0.9 秒 = 可能是句中思考 |
| rule3（最小長度） | 12 | 至少要 12 個 token 才算一句 |

### VAD（語音活動偵測）

VAD 用來判斷使用者是否正在說話，避免把環境噪音送去辨識。

| 參數 | 值 | 說明 |
|------|-----|------|
| 靜音門檻 | 0.01 | RMS 音量低於此視為靜音 |
| 靜音持續 | 500ms | 觸發分段的靜音時長 |

RMS（Root Mean Square）是計算音頻響度的標準方法，數值越高聲音越大。

### 音頻處理

除非你知道自己在幹嘛，否則不要改。

| 參數 | 值 | 說明 |
|------|-----|------|
| 緩衝大小 | 4096 | 太小會不穩定 |
| 發送間隔 | 250ms | 太快反而會卡 |
| 採樣率 | 16000 Hz | 語音辨識標準 |

## 標點呢？

Sherpa-ONNX 輸出的是純文字，沒有標點。

```
原始輸出：這是一個測試我想要這個功能
```

我用 [FunASR](https://github.com/modelscope/FunASR) 的 `ct-punc` 模型做標點恢復。

但後來發現 ct-punc 太重了（500MB），我另外做了一個[純規則式的輕量方案](/Evernote/posts/rule-based-punctuation-restoration)，只有 5KB，用正規表達式就能達到 80% 的效果。

ct-punc 的用法：

```python
from funasr import AutoModel
punc_model = AutoModel(model="ct-punc")
result = punc_model.generate(input=text)
# 輸出：這是一個測試，我想要這個功能。
```

但這又踩了另一個坑：**重複標點**。

```
輸出：這是一個測試，，我想要這個功能。。
```

原因是串流分段時已經加過標點，結束時又加一次。

解法是檢查文字是否已經有標點：

```python
# 如果這段文字還沒加過標點，才加
if remaining_text and remaining_text not in text_buffer:
    remaining_with_punc = self._add_punctuation(remaining_text)
    text_with_punc = text_buffer + remaining_with_punc
else:
    text_with_punc = text_buffer  # 已經有標點，跳過
```

---

調了快一整天，學到幾件事：

1. **int8 量化不是免費午餐**——對某些模型來說品質損失太大
2. **一次只改一個變數**——不然出問題根本不知道是誰的鍋
3. **先求穩再求快**——使用者寧可等 0.5 秒看到正確的字，也不要瞬間看到亂碼

串流辨識的參數調教就是在走鋼索。太激進會不穩定，太保守又沒意義。

目前這組設定，每天講幾小時也沒出過包。

下一篇打算寫前端音頻處理的坑——`ScriptProcessor` 已經 deprecated，但 `AudioWorklet` 有它自己的地獄。

## 延伸閱讀

- [Sherpa-ONNX 官方文件](https://k2-fsa.github.io/sherpa/onnx/index.html)
- [Sherpa-ONNX 模型下載](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [int8 量化原理](https://huggingface.co/docs/optimum/concept_guides/quantization)——為什麼有時候會壞掉
