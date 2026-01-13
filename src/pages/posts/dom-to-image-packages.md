---
layout: ../../layouts/PostLayout.astro
title: 網頁截圖套件：html2canvas vs dom-to-image
date: 2026-01-14T06:00
description: 想把網頁元素變成圖片？不用開 Puppeteer，這兩個套件在瀏覽器裡就能做
tags:
  - JavaScript
  - 前端
  - 套件推薦
---

有些需求很常見：

- 「分享這張卡片到社群」→ 要產生圖片
- 「下載這張圖表」→ 要把 canvas/SVG 變成 PNG
- 「儲存這個畫面」→ 要截圖

你可能會想到用 [Playwright](/Evernote/posts/browser-automation-packages) 截圖，但那是後端方案，要開一個無頭瀏覽器。

**如果只是要在前端把 DOM 變成圖片，有更輕量的做法。**

---

## 兩個主流套件

| 套件 | GitHub Stars | 大小 | 原理 |
|------|--------------|------|------|
| [html2canvas](https://html2canvas.hertzen.com/) | 30k+ | ~40KB | 重新繪製 DOM 到 canvas |
| [dom-to-image](https://github.com/tsayen/dom-to-image) | 10k+ | ~10KB | 用 SVG foreignObject |

---

## html2canvas

html2canvas 的原理是：**讀取 DOM 結構和 CSS 樣式，然後用 canvas API 重新畫一遍**。

```javascript
import html2canvas from 'html2canvas';

// 基本用法
const element = document.getElementById('capture');
const canvas = await html2canvas(element);

// 轉成圖片
const image = canvas.toDataURL('image/png');

// 下載
const link = document.createElement('a');
link.download = 'screenshot.png';
link.href = image;
link.click();
```

### 常用選項

```javascript
const canvas = await html2canvas(element, {
    scale: 2,                    // 解析度倍數（預設 1）
    backgroundColor: '#ffffff',  // 背景色
    useCORS: true,               // 允許跨域圖片
    logging: false,              // 關閉 console log
    width: 800,                  // 指定寬度
    height: 600,                 // 指定高度
});
```

### 限制

html2canvas 不是真的截圖，是「重新畫」，所以有些東西它畫不出來：

| 支援 | 不支援 / 有問題 |
|------|-----------------|
| 基本 HTML 元素 | iframe |
| 大部分 CSS | 部分 CSS（如 filter、某些 transform） |
| 本地圖片 | 跨域圖片（除非設 useCORS） |
| 文字 | 某些特殊字型 |

---

## dom-to-image

dom-to-image 的原理不同：**把 DOM 包進 SVG 的 foreignObject，然後轉成圖片**。

```javascript
import domtoimage from 'dom-to-image';

const element = document.getElementById('capture');

// 轉成 PNG
const dataUrl = await domtoimage.toPng(element);

// 轉成 JPEG
const dataUrl = await domtoimage.toJpeg(element, { quality: 0.95 });

// 轉成 Blob（可以上傳）
const blob = await domtoimage.toBlob(element);

// 轉成 SVG
const dataUrl = await domtoimage.toSvg(element);
```

### 下載圖片

```javascript
const dataUrl = await domtoimage.toPng(element);

const link = document.createElement('a');
link.download = 'screenshot.png';
link.href = dataUrl;
link.click();
```

### 選項

```javascript
const dataUrl = await domtoimage.toPng(element, {
    width: 800,
    height: 600,
    style: {
        transform: 'scale(2)',
        transformOrigin: 'top left',
    },
    filter: (node) => {
        // 過濾掉某些元素
        return node.tagName !== 'BUTTON';
    },
});
```

---

## 比較

| 功能 | html2canvas | dom-to-image |
|------|-------------|--------------|
| 原理 | 重繪到 canvas | SVG foreignObject |
| 套件大小 | ~40KB | ~10KB |
| CSS 支援 | 較好 | 一般 |
| 速度 | 較慢 | 較快 |
| 輸出格式 | canvas → 自己轉 | PNG/JPEG/SVG/Blob |
| 維護狀態 | 活躍 | 較少更新 |
| Safari 支援 | 較好 | 有些問題 |

### 實測結果

截一個包含文字、圖片、CSS 漸層的卡片：

| 指標 | html2canvas | dom-to-image |
|------|-------------|--------------|
| 時間 | ~200ms | ~80ms |
| 輸出品質 | 好 | 好 |
| CSS 漸層 | 正確 | 正確 |
| box-shadow | 正確 | 有時偏移 |
| 跨域圖片 | 需設定 useCORS | 需設定 |

---

## 我自己的判斷

### 用 html2canvas

- 需要較好的 CSS 支援
- 需要支援 Safari
- 專案已經在用，不想換

```javascript
// 我的常用封裝
async function captureElement(element, filename = 'screenshot.png') {
    const canvas = await html2canvas(element, {
        scale: 2,
        useCORS: true,
        backgroundColor: null,  // 透明背景
    });

    const link = document.createElement('a');
    link.download = filename;
    link.href = canvas.toDataURL('image/png');
    link.click();
}
```

### 用 dom-to-image

- 追求速度和輕量
- 需要直接輸出 Blob（上傳用）
- 不需要支援 Safari

```javascript
// 我的常用封裝
async function captureElement(element, filename = 'screenshot.png') {
    const dataUrl = await domtoimage.toPng(element, {
        style: {
            transform: 'scale(2)',
            transformOrigin: 'top left',
        },
        width: element.offsetWidth * 2,
        height: element.offsetHeight * 2,
    });

    const link = document.createElement('a');
    link.download = filename;
    link.href = dataUrl;
    link.click();
}
```

### 都不夠用的時候

如果需要：
- 完美還原所有 CSS
- 截取整個網頁（包括滾動區域）
- 截取 iframe 內容

那就老實用 [Playwright](/Evernote/posts/browser-automation-packages) 吧。

---

## 常見用途

### 1. 社群分享卡片

```javascript
// 產生分享卡片
async function generateShareCard(data) {
    // 1. 建立隱藏的 DOM 元素
    const card = document.createElement('div');
    card.innerHTML = `
        <div style="width: 600px; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
            <h1 style="color: white;">${data.title}</h1>
            <p style="color: rgba(255,255,255,0.8);">${data.description}</p>
        </div>
    `;
    card.style.position = 'absolute';
    card.style.left = '-9999px';
    document.body.appendChild(card);

    // 2. 截圖
    const canvas = await html2canvas(card.firstElementChild, { scale: 2 });

    // 3. 清理
    document.body.removeChild(card);

    return canvas.toDataURL('image/png');
}
```

### 2. 圖表下載

```javascript
// 讓使用者下載圖表
document.getElementById('download-chart').addEventListener('click', async () => {
    const chart = document.getElementById('chart-container');
    const dataUrl = await domtoimage.toPng(chart);

    const link = document.createElement('a');
    link.download = 'chart.png';
    link.href = dataUrl;
    link.click();
});
```

### 3. 上傳到後端

```javascript
async function uploadScreenshot(element) {
    const blob = await domtoimage.toBlob(element);

    const formData = new FormData();
    formData.append('image', blob, 'screenshot.png');

    await fetch('/api/upload', {
        method: 'POST',
        body: formData,
    });
}
```

---

## 踩過的坑

### 跨域圖片

如果 DOM 裡面有跨域圖片，預設會失敗。

```javascript
// html2canvas
const canvas = await html2canvas(element, {
    useCORS: true,  // 需要圖片伺服器支援 CORS
});

// 如果伺服器不支援 CORS，要先把圖片轉成 base64
```

### 字型載入

如果用了 web font，要確保字型載入完成：

```javascript
await document.fonts.ready;  // 等字型載入
const canvas = await html2canvas(element);
```

### 隱藏元素

display: none 的元素截不到，要用 visibility: hidden 或移到畫面外。

---

## 相關文章

- [瀏覽器自動化：Playwright vs Puppeteer](/Evernote/posts/browser-automation-packages) — 後端截圖方案
- [圖片處理套件：sharp vs Pillow](/Evernote/posts/image-processing-packages) — 截圖後處理

---

簡單的 DOM 截圖，不需要開無頭瀏覽器。

這兩個套件在前端就能搞定。
