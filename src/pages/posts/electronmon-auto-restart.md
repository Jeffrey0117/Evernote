---
layout: ../../layouts/PostLayout.astro
title: Electronmon - Electron 主進程自動重啟神器
date: 2026-01-13
description: 解決 Electron 開發時每次改 main.js 都要手動重啟的痛苦，讓開發體驗更絲滑
tags:
  - Electron
  - 開發工具
  - DX
---

最近在做一個語音辨識的桌面應用，用 Electron 包 React 前端，後面接 Python 跑 Sherpa-ONNX 模型。

整個架構其實蠻複雜的：前端要處理麥克風錄音、即時顯示辨識結果，主進程要管 IPC 通訊、系統托盤、全域快捷鍵，還有一堆音訊預處理、VAD 語音檢測的邏輯要調。

然後我發現一件很煩的事。

## 改 main.js 要重啟，每次都要

前端的部分有 Vite 的 HMR，改個元件存檔就自動刷新，超爽。

但主進程呢？每次改 `main.js`、`preload.js`、IPC handlers，都要：

1. 關掉 Electron
2. 重新 `npm run dev`
3. 等它啟動
4. 繼續測試

一開始還好，改個幾次就算了。但當你在調串流辨識的 IPC 邏輯，或是優化音訊處理的參數，一個小時改二三十次的時候...

我受夠了。

## 原理其實很簡單

想解決這問題，核心概念就三件事：

1. **監聽檔案變化** - 知道什麼時候有人存檔
2. **殺掉舊進程** - 把正在跑的 Electron 關掉
3. **啟動新進程** - 重新跑一個新的 Electron

土炮的話大概長這樣：

```javascript
// watch-main.js
const chokidar = require('chokidar');
const { spawn } = require('child_process');

let child = null;

function startElectron() {
  if (child) child.kill();
  child = spawn('electron', ['.'], { stdio: 'inherit' });
}

chokidar.watch(['main.js', 'preload.js']).on('change', () => {
  console.log('檔案變更，重啟 Electron...');
  startElectron();
});

startElectron();
```

20 行搞定，能用。

但實際跑起來會遇到一堆問題：

- **進程清理不乾淨** - `child.kill()` 有時候殺不掉子進程，導致 port 被佔用
- **重啟太快** - 存檔連按兩下會觸發兩次重啟，要做 debounce
- **ignore 規則** - `node_modules` 裡的檔案變化也會觸發，要過濾
- **錯誤處理** - 進程 crash 了要能自動重試
- **Windows 相容** - `kill` 在 Windows 上行為不太一樣
- **依賴追蹤** - 只監聽 main.js 不夠，被 require 的檔案也要監聽

這些東西一個一個處理下來，20 行會變 200 行。

## Electronmon 幫你處理這些

[Electronmon](https://github.com/catdad/electronmon) 就是把上面那些瑣事都包好了：

- ✅ 用 chokidar 監聽檔案（跨平台穩定）
- ✅ 自動追蹤 require 的依賴
- ✅ 正確清理進程和子進程
- ✅ 內建 debounce 防止連續觸發
- ✅ 預設 ignore node_modules
- ✅ 進程 crash 自動重試
- ✅ Windows / macOS / Linux 都能跑

你只要：

```bash
npm install -D electronmon
```

然後把 `electron .` 換成 `electronmon .`：

```json
{
  "scripts": {
    "dev:main": "electronmon ."
  }
}
```

它就會幫你監聽 `main.js`、`preload.js` 和所有被 require 的檔案，有變化就自動重啟。

## 其他類似的工具

當然不只 Electronmon 一個選擇：

### Electron-reload

```bash
npm install -D electron-reload
```

要在 `main.js` 裡面加 require：

```javascript
if (process.env.NODE_ENV === 'development') {
  require('electron-reload')(__dirname);
}
```

原理不太一樣，它是從 main process 內部監聽，然後呼叫 `app.relaunch()`。缺點是要改程式碼，而且有時候重啟不太乾淨。

### Electron-reloader

```bash
npm install -D electron-reloader
```

```javascript
try {
  require('electron-reloader')(module);
} catch {}
```

比較輕量，但功能也比較少。

### Vite Plugin Electron

如果用 Vite，`vite-plugin-electron` 整合了 renderer 和 main process 的開發體驗。但設定比較複雜，適合新專案從頭設定。

## 比較

| 工具 | 原理 | 需要改程式碼 | 設定複雜度 |
|------|------|-------------|-----------|
| Electronmon | 外部監聽 + spawn | 不用 | 低 |
| Electron-reload | 內部監聽 + relaunch | 要 | 中 |
| Electron-reloader | 內部監聽 + relaunch | 要 | 低 |
| Vite Plugin | 整合 Vite 建構 | 不用 | 高 |

Electronmon 勝在**不用改任何程式碼**，就是換個指令。對已經有一堆東西的專案來說，這點很重要。

## 實際設定

我的 `package.json` 長這樣：

```json
{
  "scripts": {
    "dev": "concurrently \"npm:dev:renderer\" \"npm:dev:main\"",
    "dev:main": "cross-env NODE_ENV=development electronmon .",
    "dev:renderer": "vite"
  }
}
```

跑 `npm run dev`，Vite 負責前端 HMR，Electronmon 負責主進程重啟，各司其職。

## 自訂監聽規則

預設監聽：
- `main.js`（或 package.json 的 main 欄位）
- `preload.js`
- 所有被 require 的檔案

要自訂的話，建一個 `electronmon.config.js`：

```javascript
module.exports = {
  patterns: ['**/*.js', '**/*.json'],
  ignore: ['node_modules', 'dist', 'src']  // src 讓 Vite 處理
}
```

## 小結

| 改動檔案 | 之前 | 之後 |
|----------|------|------|
| `src/*.jsx` | HMR 自動 | HMR 自動 |
| `main.js` | 手動重啟 | 自動重啟 |
| `preload.js` | 手動重啟 | 自動重啟 |
| IPC handlers | 手動重啟 | 自動重啟 |

原理很簡單：監聽檔案、殺進程、重啟。但要處理好各種邊界情況很煩，Electronmon 幫你包好了。

```bash
npm install -D electronmon
```

然後把 `electron .` 換成 `electronmon .`。

就這樣。
