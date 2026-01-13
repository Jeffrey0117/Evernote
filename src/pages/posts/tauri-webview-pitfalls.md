---
layout: ../../layouts/PostLayout.astro
title: Tauri 輕是輕，但坑也不少
date: 2026-01-14T02:31
description: Tauri 號稱打包只有幾 MB，但系統 WebView 各平台不一樣，坑超多
tags:
  - Tauri
  - Rust
  - 桌面應用
---

Electron 打包 50MB 讓我很困擾，於是我轉向 [Tauri](https://tauri.app/)。

官方說打包只有幾 MB，跨平台，還能寫 Rust。
聽起來完美。

我花了一週把專案從 Electron 遷移過來。
然後我發現...

**系統 WebView 各平台不一樣。**

Windows 用 [WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)，Mac 用 [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)，Linux 用 [WebKitGTK](https://webkitgtk.org/)。

這代表你的網頁在三個平台上，其實是跑在三個不同的瀏覽器引擎裡。

## 為什麼 Tauri 會這樣

這時候我才搞懂 Tauri 的設計哲學：

**它根本沒打算統一 WebView。**

Electron 自帶 Chromium（Chrome 的開源核心），所以行為一致。
Tauri 用系統 WebView，所以... 系統怎樣它就怎樣。

這不是 bug，是 feature。
Tauri 的目標是「輕」，不是「一致」。

理解這點之後，我改變了處理方式。

## 我踩過的坑

這是我踩過最痛的部分。

### CSS：同一段 code，三個平台三種結果

我寫了一個很簡單的 Grid 佈局：

```css
.container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px;
}
```

Windows 上完美，Mac 上完美，Linux 上...格子全部擠在一起。
本來應該是 4x3 的卡片格，結果全部變成一直排。

查了一下發現是 WebKitGTK 版本太舊，`gap` 屬性還不支援。
要改成用 `margin` 模擬。

另外像 `backdrop-filter: blur()` 這種特效，WebView2 支援，但舊版 WebKitGTK 不支援。
你在 Windows 開發得好好的，部署到 Linux 上發現特效全沒了。

### JavaScript API：Windows 能跑，Mac 炸了

我用 `navigator.clipboard.writeText()` 做複製功能。

```javascript
await navigator.clipboard.writeText('要複製的文字');
```

Windows 上正常，Mac 上有時候會失敗。
原因是 WKWebView 對 Clipboard API 的權限處理比較嚴格。

最後只好改成用 Tauri 的 Rust API 來做複製。

還有 `ResizeObserver`，在 Windows 正常，結果舊版 Linux 上直接噴錯。

### Windows 7/8 用戶：你的 WebView2 呢

這個很多人不知道。

WebView2 是 Windows 10 以上才內建的。
如果你的用戶還在用 Windows 7 或 8，他們要另外安裝 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section)。

這就破壞了「開箱即用」的體驗。

### 字體渲染不一樣

同一個字體，在三個平台上看起來就是不一樣。

粗細不同、間距不同、甚至 anti-aliasing（字體邊緣平滑處理）方式都不同。
講究設計的話，準備崩潰。

## 怎麼處理

踩了這些坑之後，我整理了幾個處理方式。

### 第一反應：用 Polyfill 補

Polyfill 是一種「補丁」，用來在舊環境模擬新功能。

```javascript
// 先安裝：npm install resize-observer-polyfill
import ResizeObserver from 'resize-observer-polyfill';

if (!window.ResizeObserver) {
  window.ResizeObserver = ResizeObserver;
}
```

但 polyfill 也有極限，有些東西真的補不了。

### 認命：針對平台寫判斷

polyfill 搞不定的，只好寫 if-else。

```javascript
// Tauri 1.x 寫法
import { platform } from '@tauri-apps/api/os';

// Tauri 2.x 寫法
// import { platform } from '@tauri-apps/plugin-os';

const currentPlatform = await platform();

if (currentPlatform === 'darwin') {
  // Mac 專用處理
} else if (currentPlatform === 'win32') {
  // Windows 專用處理
} else {
  // Linux 專用處理
}
```

這很醜。
三個平台三份 code，維護起來想哭。

### 終極解法：乾脆用 Rust 做

如果某個功能在 WebView 上搞不定，可以改用 Tauri 的 Rust API。

像是剪貼簿、檔案系統、系統通知這些，用 Rust 做會比較穩定。
反正 Tauri 的賣點就是可以寫 Rust。

### 或者回去用 Electron

如果你發現相容性問題多到處理不完，也許 Electron 才是正確答案。

[Electron 打包很肥？那是你不會 Tree Shaking](/Evernote/posts/electron-tree-shaking)

Electron 自帶 Chromium，三個平台的行為一致。
肥是肥了點，但至少不用處理這些相容性問題。

## Tauri 適合什麼場景

小工具。
功能單純、UI 簡單，Tauri 幾 MB 的體積是真香。

你得接受一個前提：願意在三個平台都跑一遍測試。
不願意？選 Electron。

會 Rust 的話加分。
很多事情繞過 WebView 直接用 Rust 做，問題少一半。
不會 Rust？學習曲線會讓你懷疑人生。

## 跟其他方案的比較

踩了這些坑之後，我重新評估了各個方案：

| 方案 | 打包體積 | 跨平台一致性 | 學習曲線 | 一句話定位 |
|------|----------|--------------|----------|-----------|
| Electron | 大（50MB+） | 一致 | 低 | 肥但穩，不想踩坑選這個 |
| Tauri | 小（幾 MB） | 各平台差異大 | 中 | 輕但要花時間處理相容性 |
| Qt | 中（20-40MB） | 一致 | 高 | 老牌穩定，但學 C++/PyQt |
| 原生開發 | 最小 | N/A（每平台獨立寫） | 最高 | 效能最好，但工作量 x3 |

想了解更多桌面應用開發選項，可以看這篇總覽：[跨平台桌面應用開發](/Evernote/posts/cross-platform-desktop-overview)

如果你考慮用 Python 做桌面應用，Qt 是個選擇：[Qt + Python 的搭配](/Evernote/posts/qt-python-vibe-coding)

如果跨平台框架都不滿意，可以考慮[何時該原生開發](/Evernote/posts/when-to-go-native)。

想看官方怎麼說體積差異：[Tauri vs Electron 官方比較](https://tauri.app/concept/size)

---

Tauri 輕是輕，但輕的代價是三份 WebView 的差異要你自己扛。

我的結論：除非你的 app 很簡單，或者你本來就會 Rust，否則 Electron 省心很多。
