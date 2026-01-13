---
layout: ../../layouts/PostLayout.astro
title: 那些我沒用過的開源語音辨識方案
date: 2026-01-13T13:15
description: Vosk、Kaldi、WeNet，聽過但沒用過，這篇整理它們是什麼
tags:
  - 語音辨識
  - 科普
---

研究語音辨識的時候，會看到很多方案的名字。

有些我實際用過（Whisper、FunASR、Sherpa-ONNX），有些只是聽過。

這篇整理那些我**聽過但沒用過**的開源方案，純粹介紹它們是什麼、定位在哪。

沒用過就不評價好壞，只做資料整理。

## Kaldi

[Kaldi](https://github.com/kaldi-asr/kaldi) 是語音辨識領域的「老前輩」。

2011 年發布，比深度學習熱潮還早。當時的 ASR 主流是 HMM-GMM（隱馬可夫模型 + 高斯混合模型），Kaldi 是這個時代的代表作。

### 特點

- **學術界標準**：很多語音辨識的論文都用 Kaldi 做實驗
- **功能完整**：從特徵提取、模型訓練到解碼，整套流程都有
- **C++ 實作**：效能好，但程式碼複雜
- **食譜系統**：提供各種資料集的訓練腳本（recipe）

### 定位

Kaldi 是給**研究人員**用的。

如果你要發論文、做實驗、訓練自己的模型，Kaldi 是經典選擇。

但如果你只是要「拿現成模型來用」，Kaldi 的學習曲線太陡。它不是設計給應用開發者的。

### 現況

Kaldi 的原班人馬後來做了 [k2](https://github.com/k2-fsa/k2) 和 [icefall](https://github.com/k2-fsa/icefall)，用 PyTorch 重寫，更現代化。

Sherpa-ONNX 就是 k2 團隊的作品，可以說是 Kaldi 的精神續作。

## Vosk

[Vosk](https://github.com/alphacep/vosk-api) 是一個輕量級的離線語音辨識工具包。

### 特點

- **輕量**：模型小（50MB 起），適合嵌入式設備
- **多語言**：支援 20+ 種語言
- **多平台**：Python、Java、C#、JavaScript、iOS、Android 都有 SDK
- **離線**：完全不需要網路
- **簡單**：API 很簡潔，幾行程式碼就能跑

### 定位

Vosk 是給**應用開發者**用的。

它的目標是「讓語音辨識變簡單」。不用懂模型原理，不用自己訓練，下載預訓練模型就能用。

適合：
- 快速原型開發
- 資源受限的環境（樹莓派、手機）
- 不想碰 Python 的開發者（有多語言 SDK）

### 跟 Sherpa-ONNX 的差異

兩者定位很像，都是「輕量離線 ASR」。

Vosk 的模型基於 Kaldi 訓練，用的是比較傳統的架構。Sherpa-ONNX 用的是更新的 Zipformer/Paraformer，理論上效果更好。

但我沒實際比較過，不確定差多少。

## WeNet

[WeNet](https://github.com/wenet-e2e/wenet) 是一個端到端的語音辨識工具包，由出門問問（Mobvoi）開發。

### 特點

- **端到端**：用 Transformer/Conformer 架構，不需要傳統的 HMM
- **生產就緒**：設計目標是能直接上線用，不只是研究
- **串流支援**：支援 U2（Unified Two-pass）架構，兼顧串流和非串流
- **中文優化**：出門問問是中國公司，中文支援很好

### U2 架構

WeNet 的特色是 U2（Unified Two-pass）架構：

1. **第一遍**：串流模式，快速輸出初步結果
2. **第二遍**：非串流模式，用完整音頻修正結果

這樣可以兼顧「即時反應」和「最終準確度」。

### 定位

WeNet 介於 Kaldi 和 Vosk 之間。

比 Kaldi 更面向應用（有現成模型可用），比 Vosk 更面向研究（可以自己訓練模型）。

適合想要**客製化模型**但又不想從零開始的團隊。

## 其他聽過的名字

### PaddleSpeech

百度的語音工具包，基於 PaddlePaddle 框架。

中文支援很好（百度嘛），但要用 PaddlePaddle，生態系跟 PyTorch 不同。

### ESPnet

另一個學術界常用的端到端語音工具包。

功能很完整，但主要是給研究用的，不是給應用開發者。

### NeMo

NVIDIA 的對話式 AI 工具包，包含 ASR、TTS、NLP。

效果好，但綁定 NVIDIA GPU，不適合純 CPU 環境。

## 為什麼我沒用這些？

我的需求是：

1. **離線**：不能連網路
2. **輕量**：要塞進 Electron 應用
3. **中文好**：主要辨識中文
4. **有現成模型**：沒時間自己訓練

最後選了 Sherpa-ONNX，因為它剛好全中：

- 基於 ONNX Runtime，輕量
- 有預訓練的中文模型（Paraformer、Zipformer）
- k2 團隊維護，品質有保證
- 同時支援離線和串流

Vosk 其實也符合條件，但當時我先碰到 Sherpa-ONNX，就沒再試 Vosk 了。

Kaldi 和 WeNet 太重了，不適合我的場景。

---

這篇純粹是資料整理。如果你的需求跟我不一樣，這些方案可能更適合你。

相關文章：

- [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison)
- [名詞科普：VAD、ASR、STT 到底在講什麼？](/Evernote/posts/speech-recognition-glossary)
