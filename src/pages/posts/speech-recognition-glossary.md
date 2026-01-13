---
layout: ../../layouts/PostLayout.astro
title: 名詞科普：VAD、ASR、STT 到底在講什麼？
date: 2026-01-13T13:00
description: 語音辨識領域的術語太多了，這篇一次整理清楚
tags:
  - 語音辨識
  - 科普
---

剛開始研究語音辨識的時候，被一堆縮寫搞得很亂。

VAD、ASR、STT、TTS、NLP... 每篇文章都在用，但沒人解釋。

這篇把常見的術語整理一次。

## 核心概念

### ASR (Automatic Speech Recognition)

自動語音辨識。把人說的話轉成文字。

這是整個領域的核心技術。你對著麥克風講話，電腦輸出文字，這個過程就是 ASR。

### STT (Speech-to-Text)

語音轉文字。跟 ASR 是**同一件事**，只是換個說法。

ASR 比較學術，STT 比較口語。看到這兩個詞，當成同義詞就好。

### TTS (Text-to-Speech)

文字轉語音。ASR/STT 的反向操作。

輸入文字，輸出人聲。Siri、Google 助理念給你聽的聲音，就是 TTS。

這篇不討論 TTS，但知道它是 ASR 的反向就好。

### VAD (Voice Activity Detection)

語音活動偵測。判斷音頻裡面「有沒有人在講話」。

為什麼需要這個？因為不是每段音頻都需要辨識。

使用者按下錄音後可能在思考，前幾秒沒出聲。VAD 會偵測到這是靜音，跳過不處理，省下運算資源。

VAD 是 ASR 的**前處理**，不是 ASR 本身。

### NLP (Natural Language Processing)

自然語言處理。讓電腦理解人類語言的技術。

ASR 只負責「聽」，把聲音變成文字。NLP 負責「懂」，理解文字的意思。

例如：
- ASR：「幫我訂明天下午三點的會議室」（純文字）
- NLP：理解這是一個「訂會議室」的指令，時間是「明天下午三點」

語音助理 = ASR + NLP + TTS。

## 模型架構相關

### Encoder-Decoder

編碼器-解碼器。一種常見的神經網路架構。

- **Encoder**：把輸入（音頻）壓縮成一個「特徵向量」
- **Decoder**：把特徵向量展開成輸出（文字）

大部分 ASR 模型都是這個架構的變體。

### Transducer

一種特殊的 Encoder-Decoder 架構，專門設計給**串流辨識**用。

傳統 Encoder-Decoder 要等整段音頻輸入完才能輸出。Transducer 可以邊輸入邊輸出，實現「邊講邊出字」。

Sherpa-ONNX 的串流模型 Zipformer 就是 Transducer 架構。

### Transformer

一種神經網路架構，2017 年 Google 提出，現在幾乎統治了整個 AI 領域。

特點是「注意力機制」(Attention)，可以讓模型關注輸入的不同部分。

Whisper、Conformer、Zipformer 都是基於 Transformer 的變體。

### Conformer

Convolution + Transformer。結合 CNN 和 Transformer 的優點。

CNN 擅長抓局部特徵（例如音頻的頻譜），Transformer 擅長抓全局關係（例如前後文）。Conformer 兩個都要。

很多現代 ASR 模型都用 Conformer 架構。

### Zipformer

Conformer 的改良版，由 k2/icefall 團隊提出。

比 Conformer 更快、更省記憶體，效果差不多。Sherpa-ONNX 的串流模型就是用 Zipformer。

### Paraformer

阿里達摩院提出的非自回歸 ASR 模型。

「非自回歸」意思是輸出不依賴前一個輸出，可以一次並行產生所有文字。所以速度很快。

缺點是不適合串流，要等整段音頻才能辨識。

FunASR 和 Sherpa-ONNX 的離線模型都支援 Paraformer。

## 處理流程相關

### 採樣率 (Sample Rate)

每秒鐘取樣多少次。單位是 Hz。

語音辨識通常用 **16000 Hz**（16kHz）。意思是每秒有 16000 個數據點。

音樂通常用 44100 Hz 或 48000 Hz，但語音不需要這麼高。

### RTF (Real-Time Factor)

實時係數。衡量辨識速度的指標。

```
RTF = 處理時間 / 音頻時長
```

- RTF = 1.0：處理 10 秒音頻要 10 秒（剛好實時）
- RTF = 0.5：處理 10 秒音頻只要 5 秒（比實時快 2 倍）
- RTF = 2.0：處理 10 秒音頻要 20 秒（比實時慢）

串流辨識必須 RTF < 1，不然會越來越延遲。

### 端點偵測 (Endpoint Detection)

判斷使用者「講完一句話」的技術。

在串流辨識裡很重要。模型要知道什麼時候該分段、什麼時候該等使用者繼續講。

通常用靜音時長來判斷：停頓超過 X 秒就視為句子結束。

### 熱詞 (Hotword)

提高特定詞彙辨識率的技術。

例如你的產品叫「聲聲慢」，但模型可能辨識成「生生慢」。加入熱詞後，模型會優先輸出「聲聲慢」。

也叫 keyword boosting 或 contextual biasing。

## 量化相關

### fp32 / fp16 / int8

模型的數值精度。

- **fp32**：32 位元浮點數，最精確，最慢，最大
- **fp16**：16 位元浮點數，精度略降，速度快一倍
- **int8**：8 位元整數，精度再降，速度更快，體積最小

量化就是把 fp32 模型轉成 fp16 或 int8，用精度換速度。

### ONNX

Open Neural Network Exchange。一種模型格式標準。

把模型轉成 ONNX 格式後，可以用 ONNX Runtime 跑推理，不需要原本的框架（PyTorch、TensorFlow）。

好處是更快、更輕量、跨平台。Sherpa-ONNX 就是用 ONNX Runtime。

---

這些術語搞懂之後，看其他文章就不會霧煞煞了。

相關文章：

- [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison)
- [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)
