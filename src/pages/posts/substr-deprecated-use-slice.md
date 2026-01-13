---
layout: ../../layouts/PostLayout.astro
title: substr 還能用，但遲早會壞
date: 2026-01-13T12:15
description: JavaScript 的 substr() 已經 deprecated，改用 slice() 或 substring()
tags:
  - JavaScript
---

整理 PasteV 程式碼的時候跑了一次 ESLint。這專案前後端加起來幾千行，想說順手清一下警告。

結果跳了一堆：

```
'substr' is deprecated. Use 'slice' or 'substring' instead.
```

程式還是能跑，但這個警告是在說：**這個函式以後可能會被移除**。

## 老樣子，先講 deprecated 是什麼

**Deprecated**（已棄用）是軟體開發的術語，意思是「這個功能還在，但官方不建議使用，未來可能會移除」。

為什麼不直接移除？因為太多舊程式碼在用，直接移除會造成大規模災難。所以官方會先標記 deprecated，給大家時間慢慢改。

通常的時間軸：

```
v1.0 - 新增功能 A
v2.0 - 新增功能 B（更好的替代方案）
v3.0 - 標記功能 A 為 deprecated
v5.0 - 移除功能 A
```

在 v3.0 到 v5.0 之間，功能 A 還能用，但會跳警告。等到 v5.0，直接噴錯。

## substr vs slice vs substring

JavaScript 有三個看起來很像的字串切割函式：

```typescript
const str = 'Hello World';

str.substr(0, 5);     // 'Hello' - 從 index 0 開始，取 5 個字元
str.slice(0, 5);      // 'Hello' - 從 index 0 到 index 5（不含）
str.substring(0, 5);  // 'Hello' - 從 index 0 到 index 5（不含）
```

三個的結果一樣？差別在參數意義和邊界處理：

| 方法 | 參數意義 | 負數處理 |
|------|----------|----------|
| `substr(start, length)` | 起點 + 長度 | start 負數從尾巴數 |
| `slice(start, end)` | 起點 + 終點 | 負數都從尾巴數 |
| `substring(start, end)` | 起點 + 終點 | 負數當作 0 |

`substr` 的問題是它不在 ECMAScript 標準裡，只在「附錄 B」（遺留功能）。瀏覽器為了相容舊網站才保留。

## 改成 slice

大部分情況直接把 `substr` 換成 `slice`：

```typescript
// 之前
str.substr(0, 10);

// 之後
str.slice(0, 10);
```

如果原本用的是「起點 + 長度」的邏輯，要調整第二個參數：

```typescript
// 之前：從 index 5 開始，取 3 個字元
str.substr(5, 3);

// 之後：從 index 5 到 index 8
str.slice(5, 5 + 3);  // 或 str.slice(5, 8)
```

## 負數索引

`slice` 支援負數，從字串尾巴開始數：

```typescript
const str = 'Hello World';

str.slice(-5);      // 'World' - 最後 5 個字元
str.slice(0, -1);   // 'Hello Worl' - 去掉最後一個字元
str.slice(-5, -2);  // 'Wor' - 倒數第 5 到倒數第 2
```

這個特性很方便，比如取副檔名：

```typescript
const filename = 'image.png';
const ext = filename.slice(-4);  // '.png'
```

## slice 還可以用在陣列

`Array.prototype.slice` 跟 `String.prototype.slice` 用法一模一樣：

```typescript
const arr = [1, 2, 3, 4, 5];

arr.slice(0, 3);   // [1, 2, 3]
arr.slice(-2);     // [4, 5]
arr.slice(1, -1);  // [2, 3, 4]
```

學一個，兩邊都能用。

---

## 回到 PasteV

把所有 `substr` 改成 `slice`，ESLint 警告消失了。

程式行為完全一樣，但未來 JavaScript 引擎更新的時候不會壞掉。

改動不難，就是找出來、換掉。用 IDE 的全域搜尋取代就好：

```
搜尋：.substr(
取代：.slice(
```

然後檢查一下第二個參數是不是「長度」還是「終點」，需要的話調整一下。

---

## 其他常見的 deprecated

JavaScript 裡還有一些 deprecated 的東西：

| Deprecated | 替代方案 |
|------------|----------|
| `substr()` | `slice()` 或 `substring()` |
| `escape()` / `unescape()` | `encodeURIComponent()` / `decodeURIComponent()` |
| `__proto__` | `Object.getPrototypeOf()` |
| `with` 語句 | 不要用 |
| `arguments.callee` | 用具名函式 |

看到 deprecated 警告不要忽略。現在能跑不代表以後能跑。

趁警告還在的時候改掉，比等到噴錯再來救火輕鬆多了。
