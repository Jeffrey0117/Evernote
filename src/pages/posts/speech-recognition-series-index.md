---
layout: ../../layouts/PostLayout.astro
title: 所有你應該知道的語音辨識，都在這
date: 2026-01-13T14:00
description: 從零到一做語音辨識桌面應用的完整記錄，9 篇文章的閱讀指南
tags:
  - 語音辨識
  - 索引
---

這是我做語音辨識桌面應用的完整記錄，從選型、優化到產品，整理成系列文章。

## 產品介紹

| 文章 | 內容 |
|------|------|
| [聲聲慢：我做了一個離線語音轉文字工具](/Evernote/posts/shengshengman-intro) | 產品介紹、功能、未來計畫（APP 版） |

## 分類總覽

### 入門科普

剛接觸語音辨識？從這裡開始。

| 文章 | 內容 |
|------|------|
| [名詞科普：VAD、ASR、STT 到底在講什麼？](/Evernote/posts/speech-recognition-glossary) | 術語解釋，看懂其他文章的前置知識 |
| [那些我沒用過的開源語音辨識方案](/Evernote/posts/asr-alternatives-i-didnt-use) | Vosk、Kaldi、WeNet 等方案介紹 |
| [該不該花錢買語音辨識 API？](/Evernote/posts/should-you-pay-for-asr-api) | 雲端 API vs 本地模型的分析 |

### 選型比較

選擇適合的模型和方案。

| 文章 | 內容 |
|------|------|
| [離線語音辨識模型大亂鬥](/Evernote/posts/speech-recognition-models-comparison) | Whisper、FunASR、Sherpa-ONNX 實測比較 |

### 實戰優化

我實際用過的方案，怎麼調到最快。

| 文章 | 內容 |
|------|------|
| [FunASR 極限優化指南](/Evernote/posts/funasr-optimization-guide) | 並行載入、量化、執行緒調整 |
| [Sherpa-ONNX 雙模型架構優化實戰](/Evernote/posts/sherpa-onnx-optimization) | 離線 + 串流雙模型、VAD、音頻預處理 |
| [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization) | 端點偵測、int8 踩坑、參數平衡 |
| [熱詞功能實作：讓語音辨識認得你的專有名詞](/Evernote/posts/hotwords-implementation) | Hotwords 原理與實作 |
| [從 FunASR 遷移到 Sherpa-ONNX](/Evernote/posts/funasr-to-sherpa-migration) | 架構遷移的決策與過程 |

### 周邊工具

辨識之外的處理。

| 文章 | 內容 |
|------|------|
| [用 5KB 正規表達式幹掉 500MB 深度學習模型](/Evernote/posts/rule-based-punctuation-restoration) | 規則式標點恢復 |

### Electron 開發

桌面應用開發的眉角。

| 文章 | 內容 |
|------|------|
| [為什麼桌面應用不能多開？談 Electron 單實例鎖](/Evernote/posts/why-prevent-multiple-instances) | 多開會炸的原因，以及怎麼防止 |

### 方法論

從實戰抽出的抽象原則。

| 文章 | 內容 |
|------|------|
| [優化方法論：從語音辨識學到的事](/Evernote/posts/optimization-methodology) | 6 個優化原則 + SOP |

---

## 建議閱讀順序

### 路線 A：我想快速了解全貌

```
名詞科普 → 模型大亂鬥 → 該不該買 API
```

3 篇看完，對語音辨識生態系有基本認識。

### 路線 B：我想自己做一個語音辨識應用

```
名詞科普
    ↓
模型大亂鬥（選型）
    ↓
Sherpa-ONNX 優化（如果選 Sherpa）
或 FunASR 優化（如果選 FunASR）
    ↓
串流辨識調參（如果需要即時辨識）
    ↓
標點恢復（後處理）
```

### 路線 C：我想學優化思維

```
任選一篇實戰文章（FunASR / Sherpa-ONNX / 串流）
    ↓
優化方法論（抽象總結）
```

---

## 文章關係圖

```
                    ┌─────────────────┐
                    │    名詞科普      │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ 沒用過的方案     │ │  模型大亂鬥     │ │  該不該買 API   │
└─────────────────┘ └────────┬────────┘ └─────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  FunASR 優化    │ │ Sherpa-ONNX 優化│ │   串流調參      │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   優化方法論     │
                    └─────────────────┘

                    ┌─────────────────┐
                    │   標點恢復       │ ← 獨立模組，各篇都會連到
                    └─────────────────┘
```

---

## 我的技術棧

最後整理一下我目前用的組合：

```
音頻輸入
  ↓
VAD 過濾靜音（Silero VAD / RMS 能量）
  ↓
語音辨識
  ├── 離線模式：Sherpa-ONNX Paraformer (int8)
  └── 串流模式：Sherpa-ONNX Zipformer (fp32)
  ↓
標點恢復（ct-punc / 規則式）
  ↓
簡轉繁（OpenCC）
  ↓
輸出文字
```

這套組合的優化過程，就是這個系列的全部內容。
