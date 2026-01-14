---
layout: ../../layouts/PostLayout.astro
title: Preact 和 Nerv：輕量版 React
date: 2026-01-14T06:20
description: React 太肥？這兩個套件 API 幾乎一樣，但只有 3-9KB
tags:
  - 前端
  - React
  - 框架
  - 套件推薦
---

在 GitHub 上逛到 [Preact](https://preactjs.com/)（36k+ stars）和 [Nerv](https://github.com/NervJS/nerv)（5k+ stars）。

都是「輕量版 React」，API 跟 React 相容，但小很多。

---

## 為什麼要輕量版

React 的 bundle size：

```
react + react-dom = ~40KB gzipped
```

對於複雜應用，40KB 不算什麼。

但如果你只是：
- 做一個簡單的互動頁面
- 嵌入到別人網站的 widget
- 需要支援低端設備

40KB 的框架 + 10KB 的業務程式碼，有點浪費。

---

## Preact：3KB 的 React

```javascript
// 跟 React 一模一樣的寫法
import { useState } from 'preact/hooks';

function Counter() {
    const [count, setCount] = useState(0);

    return (
        <div>
            <p>Count: {count}</p>
            <button onClick={() => setCount(count + 1)}>+1</button>
        </div>
    );
}
```

### 為什麼能這麼小

| 功能 | React | Preact |
|------|-------|--------|
| 大小 | ~40KB | ~3KB |
| 合成事件 | 自己實作一套 | 直接用原生事件 |
| Fiber 架構 | 有 | 沒有 |
| 開發者工具 | 內建 | 另外裝 |

Preact 砍掉了 React 的「企業級」功能，專注在核心。

### preact/compat：相容層

想用 React 生態的套件？加一個 alias：

```javascript
// vite.config.js
export default {
    resolve: {
        alias: {
            'react': 'preact/compat',
            'react-dom': 'preact/compat',
        },
    },
}
```

這樣大部分 React 套件都能跑，bundle 大約 5KB。

---

## Nerv：京東做的輕量 React

[Nerv](https://github.com/NervJS/nerv) 是京東前端團隊做的，目標類似 Preact。

```javascript
import Nerv from 'nervjs';

class App extends Nerv.Component {
    state = { count: 0 };

    render() {
        return (
            <div>
                <p>Count: {this.state.count}</p>
                <button onClick={() => this.setState({ count: this.state.count + 1 })}>
                    +1
                </button>
            </div>
        );
    }
}
```

### 為什麼京東要自己做

| 對比 | React | Nerv |
|------|-------|------|
| 大小 | ~40KB | ~9KB |
| IE8 支援 | 不支援 | 支援 |

京東的業務需要支援 IE8（中國市場的老電腦），React 16+ 放棄了 IE，所以他們自己做了一個。

---

## Preact vs Nerv

| 功能 | Preact | Nerv |
|------|--------|------|
| 大小 | 3KB | 9KB |
| IE8 支援 | 不支援 | 支援 |
| 維護者 | 社群活躍 | 京東團隊 |
| 生態 | 較大 | 較小 |
| 更新頻率 | 頻繁 | 較少 |

**結論**：

- 不需要 IE8 → **Preact**（更小、社群更活躍）
- 需要 IE8 → **Nerv**（但現在還需要 IE8 的場景很少了）

---

## 什麼時候用輕量 React

### 適合的場景

**嵌入式 widget**：

```javascript
// 給別人嵌入的回饋按鈕，要越小越好
import { h, render } from 'preact';
import { useState } from 'preact/hooks';

function FeedbackButton() {
    const [open, setOpen] = useState(false);
    return (
        <div>
            <button onClick={() => setOpen(true)}>Feedback</button>
            {open && <FeedbackModal onClose={() => setOpen(false)} />}
        </div>
    );
}

render(<FeedbackButton />, document.getElementById('feedback-widget'));
// 整個 bundle 可以壓到 5KB 以下
```

**簡單的互動頁面**：

不需要 React 全家桶，只是加點互動。

**低端設備**：

JS 解析也吃 CPU，bundle 小 = 啟動快。

### 不適合的場景

- 需要 React 進階功能（Concurrent Mode、Suspense）
- 團隊都熟 React，不想踩坑
- 大型專案，40KB 不算什麼

---

## 順便提：Svelte

如果願意學新語法，[Svelte](https://svelte.dev/) 是另一個選擇。

Svelte 的思路不同：**沒有 runtime**。

```svelte
<script>
    let count = 0;
</script>

<button on:click={() => count++}>
    Clicked {count} times
</button>
```

編譯後直接變成原生 JS，不需要框架 runtime。

| 對比 | React | Preact | Svelte |
|------|-------|--------|--------|
| Runtime | ~40KB | ~3KB | ~2KB |
| 語法 | JSX | JSX | .svelte |
| 學習成本 | - | 會 React 就會 | 要學新語法 |
| Virtual DOM | 有 | 有 | 沒有 |

Svelte 通常效能最好（沒有 Virtual DOM diff），但要學新語法。

---

## 我自己的判斷

| 情況 | 選擇 |
|------|------|
| 大型專案、團隊熟 React | React |
| 簡單專案、省 bundle | Preact |
| 需要 IE8 | Nerv（但真的還需要嗎？） |
| 願意學新東西、追求效能 | Svelte |
| 嵌入式 widget | Preact |

```javascript
// 我做嵌入式 widget 的選擇
// Preact + 簡單的狀態管理，整包 < 10KB
```

---

## 相關文章

- [Taro：跨平台小程式框架](/Evernote/posts/taro-cross-platform-miniprogram) — Nerv 同一個團隊做的
- [前端打包工具總覽](/Evernote/posts/bundler-overview) — 怎麼看 bundle size
- [esbuild 快到不講道理](/Evernote/posts/esbuild-speed) — 打包工具

---

不需要大砲打小鳥。

簡單的需求，用輕量的工具。
