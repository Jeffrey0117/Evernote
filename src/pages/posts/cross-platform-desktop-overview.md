---
layout: ../../layouts/PostLayout.astro
title: 跨平台桌面方案，先搞懂在選什麼
date: 2026-01-14T02:31
description: 別再問 Electron 還是 Tauri，問題問錯了。先搞懂自己要什麼，再選工具。
tags:
  - Electron
  - 開發觀念
  - 桌面應用
---

去年幫朋友公司做一個內部工具，他們一開始就說「用 Tauri，打包小」。

結果呢？三個月後整個專案重寫成 Electron。

不是 Tauri 不好，是他們團隊沒人會 Rust，每次改後端邏輯都要外包。
打包小有什麼用？開發速度慢三倍。

從那次之後，每次有人問我「Electron 還是 Tauri？」我都會反問：「你要做什麼？你團隊會什麼？」

選工具的邏輯跟選套件管理工具一樣——選擇困難來自不了解各自定位。
之前寫過一篇 [為什麼 Cargo 讓我覺得其他套件管理都是垃圾](/Evernote/posts/why-cargo-is-the-best)，聊的也是這件事。

所以這篇不是要告訴你「選 X 就對了」，而是讓你搞懂每個方案在幹嘛，然後自己判斷。

## 我走過的彎路

剛開始學桌面開發時，我的選擇邏輯是這樣：

1. 看到 Electron 打包 150MB，「太肥了，不考慮」
2. 看到 Tauri 只有 3MB，「就是它了！」
3. 用了 Tauri 三個月，WebView 相容性問題讓我崩潰
4. 換回 Electron，兩週搞定，使用者根本沒抱怨檔案大

這讓我意識到：**打包大小根本不是重點**。

選工具之前，要先搞懂每個方案的架構差異，不然比來比去只是在比數字。

## 四種架構，四種思路

### Electron：自帶瀏覽器

[Electron](https://www.electronjs.org/) 的架構很暴力——把整個 Chromium 和 Node.js 打包進去。

你的「桌面應用」其實就是一個網頁跑在專屬的 Chrome 裡面。

好處是什麼？**Web 技術直接用**。
React、Vue、Tailwind，你會什麼就用什麼，不用學新東西。

壞處也很明顯——Chromium 很肥。
一個 Hello World 打包出來就 150MB 起跳。

但說實話，現代電腦硬碟空間不值錢，使用者真的在乎嗎？
VS Code、Slack、Discord、Notion 都是 Electron，大家還不是用得很開心。

### Tauri：借用系統的瀏覽器

[Tauri](https://tauri.app/) 看起來很美好——打包只有幾 MB，我當初也是被這個數字吸引。

但真正開始用之後，我在 Windows 上開發的介面，到 Linux 上直接爆炸。
原因是 Linux 的 WebKitGTK 版本太舊，不支援我用的 CSS Grid 語法。

這才讓我搞懂 Tauri 的架構：**它不自帶瀏覽器，用的是系統的 WebView**。

WebView 就是嵌入在應用裡的迷你瀏覽器。
Windows 用 WebView2（微軟的 Edge 內核），macOS 用 WKWebView（Apple 的 Safari 內核），Linux 用 WebKitGTK。

每個平台的渲染引擎版本不同，支援的 Web API 也不同。

而且 Tauri 的後端是 Rust。
如果你本來就會 Rust，那很好；如果不會，學習曲線會讓你懷疑人生。

我踩過的坑都記在 [Tauri WebView 的各種坑](/Evernote/posts/tauri-webview-pitfalls)。

### Qt：真正的原生 UI

[Qt](https://www.qt.io/) 是老牌的跨平台 GUI 框架，完全不用 Web 技術。

它自己畫 UI，但會模擬各平台的原生外觀。

好處是**效能和體驗都是最好的**，真正的原生感。

壞處是學習曲線陡峭。
Qt 有自己一套 C++ 框架，或者用 Python 綁定。
PySide 是 Qt 官方維護、LGPL 授權；PyQt 是第三方、GPL 授權。

如果你是 Python 人，可以看看我寫的 [Qt + Python 快速開發桌面應用](/Evernote/posts/qt-python-vibe-coding)。

### Flutter：自己畫一切

[Flutter](https://flutter.dev/) 的思路更激進——不借用任何系統 UI，全部自己畫。

它用 [Skia](https://skia.org/) 渲染引擎（Google 開發的 2D 圖形引擎，Chrome 和 Android 都用它），在每個平台上畫出一模一樣的介面。

好處是**真正的跨平台一致性**，Windows、Mac、Linux、手機、網頁，長得一模一樣。

壞處是它不像原生。
因為是自己畫的，不會有平台特有的 UI 元素和行為。
而且要學 Dart——Google 開發的語言，主要為 Flutter 而生，生態系比較小。

## 直接看表格

| | Electron | Tauri | Qt | Flutter |
|------|----------|-------|-----|---------|
| **一句話** | 自帶瀏覽器的網頁套殼 | 借系統瀏覽器的輕量套殼 | 真正的原生 UI 框架 | 自己畫一切的跨平台引擎 |
| **打包大小** | 150MB+ | 3-10MB | 20-50MB | 15-30MB |
| **效能** | 中等 | 良好 | 最佳 | 良好 |
| **記憶體** | 吃很多 | 少 | 少 | 中等 |
| **學習曲線** | 低（會 Web 就行） | 中高（要會 Rust） | 高（Qt 框架複雜） | 中（要學 Dart） |
| **原生感** | 低 | 低 | 高 | 低（自己畫的） |
| **生態系** | 最豐富 | 成長中 | 成熟但小眾 | 成長中 |
| **熱門應用** | VS Code、Slack、Discord | 尚無超大型案例 | VLC、OBS | Google Ads、eBay Motors |

看完表格別急著下結論。

數字是死的，你的情況是活的。

「打包大小 150MB」聽起來很嚇人，但使用者電腦硬碟 500GB 起跳。
「效能最佳」聽起來很棒，但你的應用真的需要那種效能嗎？

重點不是數字，是**你的專案需要什麼**。

## 怎麼選

### 想快？Electron 不用想

你會 Web 技術嗎？會的話直接用 [Electron](https://www.electronjs.org/)。

不用學新東西，npm 生態系隨便用，遇到問題 Stack Overflow 一堆答案。

打包大？現代電腦不在乎這幾百 MB。
吃記憶體？使用者電腦 16GB 起跳。

**先把東西做出來再說。**

如果之後真的遇到效能瓶頸，可以看看 [Electron Tree Shaking 優化打包體積](/Evernote/posts/electron-tree-shaking)。

### 打包要小？Tauri 可以，但有代價

如果你真的很在意打包大小，例如做一個剪貼簿管理工具、截圖標註工具，那可以考慮 [Tauri](https://tauri.app/)。

但你要有心理準備：
1. 各平台 WebView 的差異會讓你抓狂
2. 要學 Rust（至少基礎）
3. 社群資源比 Electron 少很多

如果你本來就會 Rust，那 Tauri 是好選擇。
如果不會，先想清楚這個學習成本值不值得。

### 想要真正原生？那就 Qt

做的東西需要跟系統深度整合？例如存取系統托盤、讀寫註冊表、監聽全域熱鍵？

那就用 [Qt](https://www.qt.io/)。

它是真正的原生 UI，不是 Web 套殼。

用 C++ 或 Python 都可以，看你團隊會什麼。

### 團隊本來就會 Dart？那 Flutter 順便

如果團隊本來就在用 [Flutter](https://flutter.dev/) 做手機 App，那順便用 Flutter Desktop 很划算。

一套程式碼，手機和桌面都能跑。

但如果團隊不會 Dart，**不要為了桌面應用去學 Flutter**，成本太高。

## 這篇只是開場

跨平台桌面開發這個主題很大，這篇只是讓你搞清楚在選什麼。

後面還有很多可以聊：

| 主題 | 文章 |
|------|------|
| Electron 瘦身 | [Electron Tree Shaking 優化打包體積](/Evernote/posts/electron-tree-shaking) |
| Tauri 踩坑 | [Tauri WebView 的各種坑](/Evernote/posts/tauri-webview-pitfalls) |
| Qt + Python | [Qt + Python 快速開發桌面應用](/Evernote/posts/qt-python-vibe-coding) |
| 何時用原生 | [不是每個專案都需要跨平台](/Evernote/posts/when-to-go-native) |

選工具的邏輯跟選套件管理工具一樣，搞懂定位才能做對選擇。
可以看看 [Python 套件管理工具怎麼選](/Evernote/posts/python-package-managers)，思路是類似的。

---

回到開頭那個幫朋友重寫專案的經歷。

如果當初他們先問「團隊會什麼」，而不是「哪個打包小」，就不會浪費三個月。

選工具的邏輯很簡單：

1. **先問團隊會什麼** — 學習成本比打包大小重要一百倍
2. **再問專案需要什麼** — 小工具和大產品的選擇完全不同
3. **最後才看數字** — 效能、大小這些都是次要的

**別問哪個最好，問你的團隊會什麼。**
