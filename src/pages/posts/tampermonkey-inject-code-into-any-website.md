---
layout: ../../layouts/PostLayout.astro
title: Tampermonkey：在任何網頁注入你的程式碼
date: 2026-01-14T03:03
description: 用瀏覽器腳本在 YouTube 頁面加下載按鈕，不用裝額外的擴充功能
tags:
  - Tampermonkey
  - JavaScript
  - 瀏覽器
  - userscript
---

[Ytify](/posts/ytify-self-hosted-youtube-downloader) 做好之後，下載影片要這樣：

1. 複製 YouTube 網址
2. 開一個新分頁
3. 貼網址到 Ytify
4. 選格式
5. 按下載

五個步驟。

能不能變成一個步驟？

**在 YouTube 頁面直接加一個下載按鈕，按下去就下載。**

---

## Tampermonkey 是什麼

Tampermonkey 是一個瀏覽器擴充功能，讓你可以在**任何網頁執行自己的 JavaScript**。

```javascript
// 這段程式碼會在每次開 YouTube 時執行
// @match *://www.youtube.com/*

document.body.innerHTML = "<h1>YouTube 被我改掉了</h1>";
```

當然我們不會這麼搞破壞，而是用來**增強**網頁功能。

---

## 安裝

1. 去 Chrome/Firefox/Edge 的擴充功能商店
2. 搜尋「Tampermonkey」
3. 安裝

完成。現在你可以在任何網頁執行自己的程式碼了。

---

## Userscript 的基本結構

```javascript
// ==UserScript==
// @name         Ytify 下載按鈕
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  在 YouTube 頁面加入下載按鈕
// @author       你的名字
// @match        *://www.youtube.com/*
// @grant        GM_xmlhttpRequest
// @connect      your-ytify-server.com
// ==/UserScript==

(function() {
    'use strict';
    // 你的程式碼放這裡
})();
```

重點是那些 `@` 開頭的設定：

| 設定 | 意思 |
|------|------|
| `@match` | 這個腳本在哪些網站執行 |
| `@grant` | 需要什麼特殊權限 |
| `@connect` | 允許連到哪些外部網址 |

---

## 在 YouTube 加下載按鈕

### 步驟 1：找到要插入的位置

YouTube 頁面的 DOM 結構會變，但影片資訊區域大概是這樣：

```html
<div id="above-the-fold">
  <div id="title">影片標題</div>
  <div id="owner">頻道名稱</div>
  <!-- 我們要在這裡加按鈕 -->
</div>
```

用 F12 開發者工具，找到適合插入的位置。

### 步驟 2：建立按鈕

```javascript
function createDownloadButton() {
    const button = document.createElement('button');
    button.textContent = '下載影片';
    button.style.cssText = `
        background: #ff0000;
        color: white;
        border: none;
        padding: 10px 20px;
        border-radius: 20px;
        cursor: pointer;
        font-size: 14px;
        margin-left: 10px;
    `;
    button.onclick = downloadVideo;
    return button;
}
```

### 步驟 3：插入按鈕

```javascript
function insertButton() {
    // 找到標題區域
    const titleContainer = document.querySelector('#above-the-fold');
    if (!titleContainer) return;

    // 避免重複插入
    if (document.querySelector('#ytify-download-btn')) return;

    const button = createDownloadButton();
    button.id = 'ytify-download-btn';

    // 插入到標題旁邊
    const title = titleContainer.querySelector('#title');
    if (title) {
        title.appendChild(button);
    }
}
```

### 步驟 4：處理下載邏輯

```javascript
function downloadVideo() {
    const videoUrl = window.location.href;

    // 用 GM_xmlhttpRequest 發請求（可以跨域）
    GM_xmlhttpRequest({
        method: 'POST',
        url: 'https://your-ytify-server.com/api/download',
        headers: {
            'Content-Type': 'application/json'
        },
        data: JSON.stringify({ url: videoUrl }),
        onload: function(response) {
            const data = JSON.parse(response.responseText);
            alert('下載任務已建立: ' + data.task_id);
        },
        onerror: function(error) {
            alert('下載失敗');
        }
    });
}
```

### 步驟 5：偵測頁面變化

YouTube 是 SPA（單頁應用程式），切換影片不會真的換頁面。

所以要用 MutationObserver 偵測 DOM 變化：

```javascript
function observePageChange() {
    // 偵測 URL 變化
    let lastUrl = location.href;

    const observer = new MutationObserver(() => {
        if (location.href !== lastUrl) {
            lastUrl = location.href;
            // 等 DOM 更新完再插入按鈕
            setTimeout(insertButton, 1000);
        }
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
}

// 啟動
insertButton();
observePageChange();
```

---

## 完整程式碼

```javascript
// ==UserScript==
// @name         Ytify 下載按鈕
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  在 YouTube 頁面加入下載按鈕
// @match        *://www.youtube.com/*
// @grant        GM_xmlhttpRequest
// @connect      *
// ==/UserScript==

(function() {
    'use strict';

    const YTIFY_SERVER = 'https://your-ytify-server.com';

    function createDownloadButton() {
        const button = document.createElement('button');
        button.id = 'ytify-download-btn';
        button.textContent = '⬇ 下載';
        button.style.cssText = `
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 18px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            margin-left: 12px;
            transition: transform 0.2s;
        `;
        button.onmouseover = () => button.style.transform = 'scale(1.05)';
        button.onmouseout = () => button.style.transform = 'scale(1)';
        button.onclick = downloadVideo;
        return button;
    }

    function downloadVideo() {
        const videoUrl = window.location.href;

        GM_xmlhttpRequest({
            method: 'POST',
            url: `${YTIFY_SERVER}/api/download`,
            headers: { 'Content-Type': 'application/json' },
            data: JSON.stringify({
                url: videoUrl,
                format: 'mp4',
                quality: 'best'
            }),
            onload: (res) => {
                const data = JSON.parse(res.responseText);
                if (data.task_id) {
                    // 開新分頁到 Ytify 看進度
                    window.open(`${YTIFY_SERVER}/download.html?task=${data.task_id}`);
                }
            },
            onerror: () => alert('連接 Ytify 伺服器失敗')
        });
    }

    function insertButton() {
        if (document.querySelector('#ytify-download-btn')) return;
        if (!location.pathname.startsWith('/watch')) return;

        const container = document.querySelector('#owner');
        if (container) {
            container.appendChild(createDownloadButton());
        }
    }

    function init() {
        insertButton();

        // 偵測 SPA 換頁
        let lastUrl = location.href;
        new MutationObserver(() => {
            if (location.href !== lastUrl) {
                lastUrl = location.href;
                setTimeout(insertButton, 1500);
            }
        }).observe(document.body, { childList: true, subtree: true });
    }

    // 等 YouTube 頁面載入完成
    if (document.readyState === 'complete') {
        init();
    } else {
        window.addEventListener('load', init);
    }
})();
```

---

## 為什麼要用 GM_xmlhttpRequest

普通的 `fetch()` 會被 [CORS](/posts/cors-why-browser-blocks-your-request) 擋住：

```javascript
// 這個會失敗
fetch('https://your-server.com/api')
// Error: blocked by CORS policy
```

因為你在 YouTube 的頁面，瀏覽器不讓你隨便發請求到其他網站。

`GM_xmlhttpRequest` 是 Tampermonkey 提供的特殊函數，可以繞過 CORS 限制。

（當然你要在 `@connect` 列出允許的網站）

---

## 其他有用的 GM_ 函數

| 函數 | 功能 |
|------|------|
| `GM_xmlhttpRequest` | 跨域請求 |
| `GM_setValue` / `GM_getValue` | 儲存資料（關閉瀏覽器也保留） |
| `GM_notification` | 桌面通知 |
| `GM_setClipboard` | 複製到剪貼簿 |
| `GM_addStyle` | 注入 CSS |

---

## Userscript 的應用場景

| 場景 | 範例 |
|------|------|
| 去廣告 | 移除網頁上的廣告元素 |
| 增強功能 | 在 GitHub 加快捷鍵 |
| 修改外觀 | 把網站改成深色模式 |
| 自動化 | 自動填表單、自動簽到 |
| 整合工具 | 把網頁資料送到你的服務 |

Ytify 的腳本就是最後一種——把 YouTube 和你的下載服務整合在一起。

---

## 注意事項

| 問題 | 建議 |
|------|------|
| 網站改版 | DOM 結構會變，腳本要跟著改 |
| 安全性 | 別裝來路不明的腳本，它能讀取你所有資料 |
| 效能 | 別在 MutationObserver 裡做太重的操作 |
| 衝突 | 多個腳本可能會打架 |

---

## 總結

| 沒有 Tampermonkey | 有 Tampermonkey |
|-------------------|-----------------|
| 複製網址、開新頁、貼上 | 直接按按鈕 |
| 網頁功能不夠用 | 自己加功能 |
| 要等官方更新 | 自己動手 |

Tampermonkey 讓你變成網頁的主人，而不只是使用者。

看到哪個網站不順眼，改它。

```javascript
// @match *://annoying-website.com/*
document.querySelector('.popup-ad').remove();
```

這就是 userscript 的威力。
