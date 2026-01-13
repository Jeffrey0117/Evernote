---
layout: ../../layouts/PostLayout.astro
title: Electron 肥是你不會 Tree Shaking
date: 2026-01-14T02:31
description: 大家都說 Electron 肥，但其實會優化的話可以壓到 50MB 以下
tags:
  - Electron
  - 前端
  - 效能
---

上個月幫朋友打包一個 [Electron](https://www.electronjs.org/) 小工具，打完一看：152MB。

朋友當場傻眼：「我就寫了三個畫面，怎麼比 VS Code 還肥？」

我也不信邪，打開 dist 資料夾一翻——整個 node_modules 都被塞進去了。
那些測試用的 mock 套件、只在 CI 跑的 lint 工具，全部躺在裡面。

我花了一整個下午把它從 152MB 壓到 48MB。

**問題不是 Electron，是打包方式。**

## 先搞清楚肥在哪

我一開始以為是 [Chromium](https://www.chromium.org/)（Chrome 的開源核心）的問題，畢竟它就是大。
但 Chromium 本體差不多 100MB，剩下 50MB 去哪了？

我用指令一個一個資料夾看：

```bash
# Linux/macOS
du -sh dist/resources/app.asar.unpacked/node_modules/*

# Windows PowerShell
Get-ChildItem -Recurse dist | Measure-Object -Property Length -Sum
```

結果發現 `@babel/core` 佔了 8MB，`typescript` 佔了 12MB。

等等，這些不是 devDependencies 嗎？怎麼會在 production build 裡？

150MB 其實花在這三個地方：

- **Chromium 本體**：約 100MB，沒救，這是 Electron 的本質
- **Node.js Runtime**：10-20MB，讓你在主進程跑 Node
- **你的 node_modules**：這才是問題，一堆沒用的東西被塞進去

## 搖掉沒用的 code

[Tree Shaking](https://webpack.js.org/guides/tree-shaking/) 顧名思義：**把沒用到的 code 搖掉**，打包時只留有用的。

我一開始以為 Tree Shaking 自動就會生效。
結果打包出來還是一樣肥。

後來才發現：**我有些套件用 require() 引入**。

### 前提：要用 ES Module

```javascript
// ES Module - 可以 Tree Shaking
import { useState } from 'react';

// CommonJS - 沒辦法 Tree Shaking
const { useState } = require('react');
```

ES Module 是 2015 年加入 JavaScript 的官方模組標準，是靜態的，打包工具可以在編譯時就知道你用了什麼。

CommonJS 是 Node.js 早期自己發明的，是動態的，只有執行時才知道，沒辦法分析。

### 打包工具選擇

| 工具 | 一句話定位 | 速度 | 適合場景 |
|------|-----------|------|----------|
| [webpack](https://webpack.js.org/) | 瑞士刀，什麼都能做 | 慢 | 需要複雜 loader/plugin 的專案 |
| [Vite](https://vitejs.dev/) | 開發爽，打包交給 Rollup | 中 | Vue/React 新專案首選 |
| [esbuild](https://esbuild.github.io/) | 只做打包，快到飛起 | 極快（10-100倍） | 追求極致打包速度、CI/CD |

我自己是用 esbuild 打包渲染進程，webpack 打包主進程。

Electron 有兩種進程：**主進程**（Main Process）負責系統層級操作如開啟視窗、存取檔案；**渲染進程**（Renderer Process）就是跑你網頁的那個。

esbuild 打包速度是 webpack 的 **10-100 倍**。
我的專案用 webpack 打包要 **12 秒**，換 esbuild 只要 **0.2 秒**。

## 實際優化步驟

好，動手。

### 用 electron-builder 的 asar

[electron-builder](https://www.electron.build/) 是最常用的 Electron 打包工具。

它預設會把你的 app 打包成 `.asar` 檔案。
asar（Atom Shell Archive）是 Electron 專用的壓縮格式，把整個 app 打包成一個檔案，類似 tar 但可以直接讀取不用解壓。

我第一次設定的時候寫成這樣：

```json
{
  "build": {
    "files": ["dist/**/*"]
  }
}
```

結果 node_modules 還是被打包進去了。
後來才搞懂：electron-builder 預設會自動包含 dependencies，要明確排除才行。

```json
{
  "build": {
    "asar": true,
    "asarUnpack": ["node_modules/sharp/**/*"]
  }
}
```

`asarUnpack` 是告訴它哪些檔案不要壓進 asar。
像 [sharp](https://sharp.pixelplumbing.com/)（圖片處理庫）這種有原生 C++ 依賴的套件，壓進去會壞掉，要另外處理。

### 排除不需要的 node_modules

這是最有效的一招。

```json
{
  "build": {
    "files": [
      "dist/**/*",
      "!node_modules/**/*",
      "node_modules/electron-store/**/*",
      "node_modules/better-sqlite3/**/*"
    ]
  }
}
```

像 `electron-store`（讀寫設定）、`better-sqlite3`（本地資料庫）這種主進程會用到的套件要明確列出來。

或者更乾淨的做法：把渲染進程的依賴用打包工具（bundler）打包進 JS，只留主進程需要的套件。

### 用 esbuild 打包渲染進程

```javascript
// build.js
const esbuild = require('esbuild');

esbuild.build({
  entryPoints: ['src/renderer/index.tsx'],
  bundle: true,
  minify: true,
  treeShaking: true,
  outfile: 'dist/renderer.js',
});
```

打包完的 `renderer.js` 可能只有幾百 KB，比整包 node_modules 小太多了。

### 檢查打包結果

打包完，去看看 `dist` 資料夾裡有什麼。

```bash
# Linux/macOS
du -sh dist/*

# Windows - 直接右鍵看資料夾大小
```

如果看到一堆不應該在的套件，回去調整 `files` 設定。

想看更多效能優化細節，可以參考 [Electron 官方效能指南](https://www.electronjs.org/docs/latest/tutorial/performance)。

## 還是很肥怎麼辦

做完這些，150MB 壓到 50-80MB 沒問題。

但 50MB 還是很肥啊。

### 接受它

Chromium 100MB 你省不掉，這是 Electron 的本質。

如果你的目標用戶是桌面應用使用者，50MB 其實還好。
VS Code、Slack、Discord 都是 Electron 做的，大家也沒在抱怨。

### 或者考慮 Tauri

如果你真的很在意體積，可以考慮 [Tauri](https://tauri.app/)。

Tauri 不自帶 Chromium，而是用系統內建的 WebView。
打包出來只有幾 MB。

我有認真考慮過 Tauri，測了一下發現：
- Windows 上用的是 WebView2（基於 Chromium），還好
- macOS 上用 WKWebView，有些 CSS 跟 Chrome 不一樣
- Linux 上用 WebKitGTK，版本混亂，有些系統根本沒裝

我的專案有用到一些比較新的 CSS 特性，不想為了相容性再燒時間。
所以最後還是選 Electron，然後認真優化打包。

但 Tauri 有自己的坑，想了解更多可以看這篇：[Tauri 輕是輕，但坑也不少](/Evernote/posts/tauri-webview-pitfalls)

## 什麼時候選哪個

| 接受 Electron 的肥 | 該考慮換方案 |
|-------------------|-------------|
| 要快速出產品，沒時間優化 | 真的受不了 50MB+ 的體積 |
| 團隊熟悉前端技術棧 | 效能敏感，記憶體吃不消 |
| 需要跨平台行為一致 | 目標用戶網路環境差，下載大檔案困難 |
| 用到很多 npm 生態的套件 | 簡單工具，功能單純 |

**我自己的判斷：**
- 內部工具、快速原型 → **Electron**，反正自己人用，肥一點沒差
- 團隊都是前端出身 → **Electron**，學習成本最低
- 輕量小工具、CLI 的 GUI 版 → **Tauri**，幾 MB 才合理
- 效能敏感的專業軟體 → **原生或 Qt**，別在 Web 技術上硬撐

## 還有更多可以聊的

關於桌面應用開發，我之前整理過一篇總覽：[跨平台桌面應用開發](/Evernote/posts/cross-platform-desktop-overview)

如果你考慮用 Python 做桌面應用，可以看看 [Qt + Python 的搭配](/Evernote/posts/qt-python-vibe-coding)。

如果跨平台框架都不滿意，也可以考慮[何時該原生開發](/Evernote/posts/when-to-go-native)。

---

我那個 152MB 的專案，最後壓到 48MB。

省下的 100MB 裡面：
- 50MB 是 devDependencies 被誤打包
- 30MB 是渲染進程的 node_modules 沒有 bundle
- 20MB 是一些只有主進程用的套件跑進渲染進程

node_modules 肥大不只 Electron 有，這是整個 Node.js 生態的通病。
想了解更多可以看這篇：[Node.js 套件管理器比較](/Evernote/posts/nodejs-package-managers)

Electron 肥不肥，看你怎麼打包。
會 Tree Shaking 的人笑著用，不會的人罵著用。
