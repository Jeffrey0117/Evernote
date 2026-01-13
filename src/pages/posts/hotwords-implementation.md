---
layout: ../../layouts/PostLayout.astro
title: 熱詞功能實作：讓語音辨識認得你的專有名詞
date: 2026-01-13T14:30
description: 用 Hotwords 提升專有名詞辨識率，從原理到實作
tags:
  - 語音辨識
  - Electron
  - Python
---

語音辨識最常見的抱怨：**專有名詞辨識不準**。

「聲聲慢」被辨識成「生生慢」，「Sherpa」被辨識成「蛇趴」。

這不是模型爛，而是模型根本沒見過這些詞。

解法是**熱詞（Hotwords）**。

## 熱詞是什麼？

熱詞就是告訴模型：「這些詞很重要，優先輸出它們。」

技術上叫 **Contextual Biasing** 或 **Keyword Boosting**。

原理是在解碼時，給特定詞彙加分。當模型猶豫要輸出「生生慢」還是「聲聲慢」時，因為「聲聲慢」有加分，就會選它。

## Sherpa-ONNX 的熱詞支援

Sherpa-ONNX 的串流辨識器支援熱詞功能，但有幾個條件：

1. 必須用 `modified_beam_search` 解碼（不能用 `greedy_search`）
2. 需要 `bpe.vocab` 詞彙表檔案
3. 熱詞格式有特殊要求

### 熱詞格式

這是最坑的地方。

Sherpa-ONNX 的熱詞**必須用空格分隔每個字**，而且要用**簡體中文**（因為模型是用簡體訓練的）。

```
# 錯誤
聲聲慢
語音轉錄

# 正確
声 声 慢
语 音 转 录
```

一開始我沒注意到這個，熱詞完全沒效果，debug 了半天。

### 實作程式碼

```python
# 內建熱詞（簡體 + 空格分隔）
_BUILTIN_HOTWORDS = [
    "声 声 慢",        # 聲聲慢
    "语 音 转 录",     # 語音轉錄
    "异 步",           # 非同步
    "缓 存",           # 快取
    "渲 染",           # 渲染
    "组 件",           # 組件
    # ...
]

# 建立辨識器時傳入熱詞
recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
    encoder=encoder_path,
    decoder=decoder_path,
    joiner=joiner_path,
    tokens=tokens_path,
    hotwords_file=hotwords_path,  # 熱詞檔案路徑
    hotwords_score=1.5,           # 加分幅度 (1.0-3.0)
    decoding_method="modified_beam_search",  # 必須用這個
    bpe_vocab=bpe_vocab_path,     # BPE 詞彙表
    # ...
)
```

### hotwords_score 怎麼調？

`hotwords_score` 控制熱詞的加分幅度：

| 分數 | 效果 |
|------|------|
| 1.0 | 幾乎沒影響 |
| 1.5 | 適中，推薦 |
| 2.0 | 明顯偏好熱詞 |
| 3.0 | 強制優先熱詞 |

太高會有副作用：模型可能在不該出現熱詞的地方也硬塞熱詞。

我實測 1.5 是比較平衡的值。

## 內建熱詞 vs 使用者熱詞

我的設計是分兩層：

1. **內建熱詞**：開發相關術語，不顯示給使用者
2. **使用者熱詞**：使用者自己加的，可以在設定裡管理

```python
def _get_all_hotwords(self):
    """取得所有熱詞（內建 + 使用者）"""
    user_words = self._load_hotwords_file()
    all_words = list(self._BUILTIN_HOTWORDS)
    for word in user_words:
        if word not in all_words:
            all_words.append(word)
    return all_words
```

內建熱詞是我自己常用的開發術語：

```python
_BUILTIN_HOTWORDS = [
    # 前端
    "异 步", "同 步", "缓 存", "渲 染", "组 件",
    "框 架", "状 态", "路 由", "钩 子", "插 件",
    # 後端
    "接 口", "函 数", "回 调", "线 程", "进 程",
    "容 器", "部 署", "编 译", "调 试",
    # ...
]
```

這些詞在一般對話不常出現，但開發者天天在講。加進熱詞後，辨識率明顯提升。

## 動態更新熱詞

使用者改了熱詞設定後，辨識器需要重新初始化才會生效。

```python
def set_hotwords(self, config):
    # 更新設定
    if "words" in config:
        self._save_hotwords_file(config["words"])

    # 如果辨識器已初始化，需要重建
    if self.streaming_initialized:
        self.streaming_initialized = False
        self.streaming_recognizer = None
        # 清除進行中的會話
        self.streaming_sessions.clear()
        # 重新初始化
        self.initialize_streaming()
```

這裡有個取捨：重建辨識器需要幾秒鐘，會中斷正在進行的辨識。

我的做法是在設定頁面提醒使用者：「更新熱詞會中斷當前辨識」。

## 效果對比

| 原本 | 加熱詞後 |
|------|----------|
| 生生慢 | 聲聲慢 |
| 一步 | 異步 |
| 緩村 | 緩存 |
| 元件 | 組件 |

不是 100% 準確，但常用詞的辨識率明顯提升。

## 踩過的坑

### 1. 忘記用空格分隔

熱詞 `声声慢` 沒效果，要寫成 `声 声 慢`。

### 2. 用了繁體

模型是簡體訓練的，熱詞要用簡體。辨識結果再用 OpenCC 轉繁體。

### 3. greedy_search 不支援

熱詞功能只在 `modified_beam_search` 解碼模式下有效。

### 4. bpe.vocab 檔案缺失

沒有這個檔案，熱詞功能會靜默失效，不會報錯。要特別檢查。

---

熱詞是提升專有名詞辨識率最直接的方法。

雖然設定有點麻煩（空格分隔、簡體），但效果明顯。如果你的應用有很多專業術語，強烈建議加上這個功能。

相關文章：

- [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)
- [Sherpa-ONNX 雙模型架構優化實戰](/Evernote/posts/sherpa-onnx-optimization)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
