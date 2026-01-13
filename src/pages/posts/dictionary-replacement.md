---
layout: ../../layouts/PostLayout.astro
title: 每次都辨識錯的詞，用字典硬換掉
date: 2026-01-13T17:54
description: 熱詞搞不定的，字典替換來補
tags:
  - 語音辨識
  - 功能實作
---

在[熱詞功能](/Evernote/posts/hotwords-implementation)那篇，我講了怎麼用 Hotwords 提升專有名詞辨識率。

但有些詞，加了熱詞還是不行。

例如「TypeScript」，模型可能輸出：

- 「太破思科瑞普」
- 「泰普斯克立特」
- 「type script」（中間多個空格）

熱詞是告訴模型「這個詞很重要」，但發音差太多，模型還是會聽錯。

第一次看到「太破思科瑞普」，我笑了。

第三次看到，我皺眉。

第十次看到，我開始懷疑人生：「我加了熱詞啊，為什麼還是聽成這樣？」

然後我意識到：熱詞是「建議」，不是「強制」。模型可以不聽。

## 那就後處理硬換

既然模型搞不定，那就辨識完之後，用字典硬把錯的換成對的。

```python
replacements = {
    "太破思科瑞普": "TypeScript",
    "泰普斯克立特": "TypeScript",
    "生生慢": "聲聲慢",
}

def apply_dictionary(text):
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text
```

簡單粗暴，但有效。

## 熱詞 vs 字典替換

| | 熱詞 | 字典替換 |
|---|------|----------|
| **時機** | 辨識過程中 | 辨識完成後 |
| **原理** | 影響模型解碼 | 純文字替換 |
| **效果** | 讓模型「更可能」輸出這個詞 | 強制把 A 換成 B |

兩個搭配用最好。

熱詞讓模型盡量輸出正確的，字典替換兜底處理漏掉的。

## 適合用字典替換的情況

### 同音異字

「聲聲慢」可能被辨識成「生生慢」「身身慢」。

發音一模一樣，熱詞有幫助但不是 100%。

字典替換可以兜底：

```
生生慢 → 聲聲慢
身身慢 → 聲聲慢
```

### 縮寫展開

口語常講縮寫，但輸出想要完整詞：

```
JS → JavaScript
TS → TypeScript
```

### 統一用詞

模型輸出的是中國用語，想換成台灣用語：

```
緩存 → 快取
異步 → 非同步
數組 → 陣列
```

這種其實 [OpenCC](https://github.com/BYVoid/OpenCC) 也能做，但有些詞 OpenCC 會漏掉，或者轉換結果不是你要的。

字典替換可以精準控制。

## 字典怎麼維護

### 內建預設字典

```python
DEFAULT_REPLACEMENTS = {
    # 常見錯誤
    "生生慢": "聲聲慢",
    "身身慢": "聲聲慢",

    # OpenCC 漏掉的
    "异步": "非同步",
}
```

這些是通用的，每個使用者都會遇到。

### 使用者自訂字典

每個人講的專有名詞不一樣。老闆名字、公司名字、專案代號...

讓使用者可以自己加：

```
# 使用者字典
老闆名字錯誤版 → 老闆名字正確版
競爭對手名字錯誤版 → 競爭對手名字正確版
```

載入時合併：

```python
def load_dictionary():
    result = dict(DEFAULT_REPLACEMENTS)
    user_dict = load_user_dictionary()
    result.update(user_dict)
    return result
```

## 我搞錯順序的那天

一開始我把字典替換放在標點恢復之前。

結果「TypeScript」被標點系統拆成「Type，Script」。

字典裡寫的是「太破思科瑞普」，但實際輸出是「太破思科瑞普，」——多了個逗號，就換不到了。

花了一小時 debug，才發現是順序問題。

**結論：字典替換要放在標點恢復之後。**

```python
text = transcribe(audio)           # 1. 辨識
text = add_punctuation(text)       # 2. 標點
text = apply_dictionary(text)      # 3. 字典替換
text = to_traditional(text)        # 4. 簡繁轉換
```

為什麼？

標點會改變文字結構。如果先做字典替換，標點可能會把替換後的詞拆開。

例如「TypeScript」被標點系統拆成「Type，Script」，就換不到了。

## 進階：Aho-Corasick

如果字典很大（幾千個詞），每個詞都 `replace` 一次會很慢。

[Aho-Corasick 演算法](https://en.wikipedia.org/wiki/Aho%E2%80%93Corasick_algorithm)可以一次掃描找出所有匹配，時間複雜度是 O(n)。

Python 有現成套件：

```python
import ahocorasick

def build_automaton(replacements):
    A = ahocorasick.Automaton()
    for old, new in replacements.items():
        A.add_word(old, (old, new))
    A.make_automaton()
    return A
```

我的應用字典不大，用簡單版就夠了。

但如果你的字典有幾萬個詞，Aho-Corasick 會快很多。

---

字典替換是很簡單的功能，但對使用者體驗影響很大。

每次看到辨識錯誤都要手動改，改到第三次就會很幹。

字典替換讓那些「每次都錯」的詞自動處理掉。

**使用者不知道你做了什麼，但會覺得辨識變準了。**

相關文章：

- [熱詞功能實作：讓語音辨識認得你的專有名詞](/Evernote/posts/hotwords-implementation)
- [用 5KB 正規表達式幹掉 500MB 深度學習模型](/Evernote/posts/rule-based-punctuation-restoration)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
