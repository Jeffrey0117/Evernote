---
layout: ../../layouts/PostLayout.astro
title: Qt 配 Python，Vibe Coding 最舒服
date: 2026-01-14T02:31
description: 試過 Electron、試過 Tauri，最後發現 Qt + Python 才是 Vibe Coding 的最佳拍檔
tags:
  - Python
  - Qt
  - 桌面應用
  - Vibe Coding
---

試過 [Electron](/Evernote/posts/electron-tree-shaking)、試過 [Tauri](/Evernote/posts/tauri-webview-pitfalls)，最後發現 Qt 配 Python 寫桌面應用超舒服。

不用管前端那堆東西，純 Python 搞定。

## 為什麼繞了一大圈

我之前做桌面應用，第一個想到的就是 Electron。

畢竟 VS Code、Discord、Slack 都是 Electron 做的，生態系成熟，網路上資源也多。

但用了一陣子發現幾個問題：

1. **記憶體吃超兇** — 開一個只有一顆按鈕的 Hello World 就吃 200MB RAM，這是什麼鬼
2. **要會前端** — React、Vue、[webpack](https://webpack.js.org/)、[Vite](https://vitejs.dev/)... 光設定檔就一堆
3. **打包超慢** — electron-builder 跑一次要等好幾分鐘

後來聽說 [Tauri](https://tauri.app/) 很輕量，用 Rust 寫後端，前端還是 Web 技術。

試了一下，確實記憶體省很多，但問題來了：

1. **還是要寫前端** — 換湯不換藥
2. **Rust 學習曲線** — 想改後端邏輯要先搞懂 Rust
3. **WebView 相容性** — 不同系統的 WebView 行為不一樣，踩坑機率高

繞了一大圈，我只是想做個小工具，為什麼要搞這麼複雜？

## 原來 Qt + Python 才是正解

就在我準備放棄桌面開發的時候，偶然看到一個開源專案是用 PySide6 寫的。

等等，[Qt](https://www.qt.io/) 不是 C++ 的東西嗎？原來有 Python 綁定？

Qt 是老牌的跨平台 GUI 框架，專門用來做桌面應用的介面。

試著跑了一下範例，**啟動只要 0.3 秒，記憶體 30MB**。

這跟 Electron 的 200MB 是什麼差距？

用 Python 寫 Qt，不用管前端那套，**純 Python 從頭寫到尾**。

UI 是原生的，不是 Web 技術模擬的，所以記憶體用量低、啟動速度快、跟系統整合度高。

最重要的是，**不用學 React、不用設定 webpack、不用管 node_modules 黑洞**。

## PyQt vs PySide

Google 一下發現 Python 的 Qt 綁定有兩個：[PyQt](https://www.riverbankcomputing.com/software/pyqt/) 和 [PySide](https://doc.qt.io/qtforpython-6/)。

這就讓我困惑了——兩個 API 幾乎一樣，到底差在哪？

爬了一堆文才搞懂，**差別在授權**。

| | PyQt | PySide |
|------|------|--------|
| **維護者** | Riverbank Computing（第三方） | Qt 官方 |
| **授權** | GPL（開源傳染性）/ 商業授權 | LGPL（商用友善，不傳染） |
| **文件** | 多，網路資源豐富 | 官方文件完整 |
| **API** | 跟 PySide 幾乎一樣 | 跟 PyQt 幾乎一樣 |

GPL 像病毒，你用了它你的程式碼也要開源；LGPL 比較佛系，只要你別動 Qt 本身的 code，閉源沒問題。

我一開始裝了 PyQt6，結果寫到一半才發現 GPL 授權的問題——我的工具不想開源，但也不想付錢買商業授權。

最後換成 **PySide6**，官方維護，授權也友善。

```bash
pip install PySide6
```

關於 Python 套件管理的選擇，可以看這篇：[Python 套件管理，pip 之外的選擇](/Evernote/posts/python-package-managers)

## 開發體驗

### Qt Designer 拉 UI

一開始我興奮地用 [Qt Designer](https://doc.qt.io/qt-6/qtdesigner-manual.html) 拉了一堆元件，結果生成的 `.ui` 檔不知道怎麼用。

Google 了半天才發現要轉成 Python：

```bash
pyside6-uic main.ui -o ui_main.py
```

或者直接在程式碼裡讀取：

```python
from PySide6.QtWidgets import QApplication
from PySide6.QtUiTools import QUiLoader

app = QApplication([])
loader = QUiLoader()
window = loader.load("main.ui")
window.show()
app.exec()
```

但後來我放棄 Designer 了，原因是每次改 UI 都要重新轉檔或重啟程式，很煩。

**直接用程式碼寫反而更快**：

```python
from PySide6.QtWidgets import QApplication, QWidget, QPushButton, QVBoxLayout

app = QApplication([])
window = QWidget()
layout = QVBoxLayout()

button = QPushButton("Click me")
layout.addWidget(button)

window.setLayout(layout)
window.show()
app.exec()
```

### Signal/Slot 機制

Qt 的事件處理用 Signal/Slot 機制，比 callback hell（callback 一層包一層的地獄）優雅多了。

```python
from PySide6.QtWidgets import QApplication, QPushButton

def on_click():
    print("Button clicked!")

app = QApplication([])
button = QPushButton("Click me")
button.clicked.connect(on_click)  # Signal 連接 Slot
button.show()
app.exec()
```

`clicked` 是 Signal，`on_click` 是 Slot。

按鈕被點擊時，Signal 發出，Slot 被呼叫。

這套機制讓程式碼很乾淨，不用到處傳 callback。

### 熱重載

這是我最痛的點——**Qt 沒有內建熱重載**。

改一行 code 就要關掉視窗、重跑程式、點回原本的畫面... 超級煩。

試了幾個方案，最後用 [watchdog](https://github.com/gorakhargosh/watchdog) 監聽檔案變更，然後重啟應用。

更簡單的方式是用之前寫的 [Python 自動重載方案](/Evernote/posts/python-auto-reload)，改完 code 自動重跑。

## 打包

寫完要打包成 exe，主要有兩個選擇：

| 工具 | 特色 |
|------|------|
| [PyInstaller](https://pyinstaller.org/) | 最常用，支援多平台，一行指令搞定 |
| [cx_Freeze](https://cx-freeze.readthedocs.io/) | 打包產物稍小，適合想細控打包內容的人 |

新手用 PyInstaller 就好，一行指令搞定：

```bash
pip install pyinstaller
pyinstaller --onefile --windowed main.py
```

- `--onefile`：打包成單一 exe
- `--windowed`：不顯示 console 視窗

### 打包的三個大坑

打包是我被搞最久的地方。

**第一個坑：檔案大小**

PySide6 打包出來的 exe 大概 50-100MB，因為要包整個 Qt runtime。

比 Electron 打包的 150-200MB 小一半，但還是比想像中大。

**第二個坑：路徑問題**

程式在開發時能跑，打包後卻找不到設定檔。

搞了兩個小時才發現，PyInstaller 會把檔案解壓到臨時目錄，路徑完全不一樣。

讀取圖片、設定檔等資源時，要用這個 helper 取得正確路徑：

```python
import sys
import os

def resource_path(relative_path):
    """打包後也能正確讀取資源檔"""
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)
```

**第三個坑：防毒誤報**

好不容易打包成功，傳給朋友測試，結果被 Windows Defender 擋掉。

他以為我傳病毒給他。

PyInstaller 打包的 exe 有時候會被防毒軟體誤判，可以加數位簽章解決。

## 什麼時候不適合

Qt + Python 不是萬能的，有些情況還是用別的比較好：

1. **介面很花俏** — 像 Figma、Notion 那種一堆動畫、拖拉互動的介面，Web 技術比較擅長，Qt 刻起來累。這時候還是考慮 [Electron](/Evernote/posts/electron-tree-shaking)。

2. **團隊全是前端** — 硬要學 Qt 不如用熟悉的 Electron，至少 debug 不會瞎子摸象。

3. **深度整合 Web 服務** — OAuth（第三方登入）、WebSocket（即時雙向通訊）這些 Web 原生支援，Qt 要自己刻。

4. **要榨效能** — Python 還是有 overhead，真的要快就考慮 [原生開發](/Evernote/posts/when-to-go-native)。

跨平台桌面開發的選擇很多，可以看這篇總覽：[跨平台桌面開發，選項太多了](/Evernote/posts/cross-platform-desktop-overview)

## Vibe Coding 心得

為什麼說 Qt + Python 是 Vibe Coding 最舒服的組合？

**因為 AI 生成 Python 程式碼超級順。**

Python 語法簡單、風格統一，AI 很容易產出能跑的程式碼。

相比之下，叫 AI 寫 Electron 設定檔就很痛苦。

electron-builder.yml、webpack.config.js、vite.config.ts... 每個專案設定都不一樣，AI 很容易搞混。

React 的 JSX、hooks、state？AI 會寫，但常常寫出怪東西。

Qt + Python 就很單純：UI 邏輯都在 Python 裡，沒有前後端分離的問題，沒有一堆設定檔要管。

我現在做小工具就是：跟 AI 說需求 → 貼上生成的 code → 不滿意再改。整個 loop 超快。

不用停下來查「這個 webpack 設定怎麼改」「這個 React hook 為什麼不 work」。

**專注在功能本身，不用花時間在工具鏈上。**

---

繞了一大圈，試過 Electron 的肥、試過 Tauri 的坑，最後發現 Qt + Python 才是做小工具最舒服的選擇。

Electron、Tauri 有它們的場景，但做小工具？殺雞用牛刀。

**Qt + Python 真的很香。**

尤其是 Vibe Coding 的時代，Python 的簡潔讓 AI 能快速產出能用的程式碼。

這種「想到就能做」的感覺，才是寫程式最爽的地方。

## 延伸閱讀

- [PySide6 官方教學](https://doc.qt.io/qtforpython-6/tutorials/index.html)
- [Qt Designer 完整指南](https://doc.qt.io/qt-6/qtdesigner-manual.html)
- [PyInstaller 打包指南](https://pyinstaller.org/en/stable/)
