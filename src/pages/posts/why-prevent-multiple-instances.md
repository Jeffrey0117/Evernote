---
layout: ../../layouts/PostLayout.astro
title: 為什麼桌面應用不能多開？談 Electron 單實例鎖
date: 2026-01-13T15:15
description: 多開會炸的原因，以及 Electron 怎麼防止
tags:
  - Electron
  - 桌面應用
---

使用者有時候會不小心點兩次應用圖示。

如果你的桌面應用沒處理好，就會開兩個視窗，然後各種奇怪的事情開始發生。

## 多開會怎樣？

以我的語音辨識應用為例：

### 1. 資源衝突

兩個實例同時存取麥克風，會打架。

一個在錄音，另一個也想錄，結果兩邊都錄到爛音。

### 2. 檔案鎖定

兩個實例同時寫入同一個資料庫檔案。

SQLite 不支援多進程同時寫入，會直接報錯或資料損壞。

### 3. 快捷鍵衝突

兩個實例都註冊全域快捷鍵 `Ctrl+Shift+R`。

使用者按下去，到底觸發哪一個？答案是：不一定，看運氣。

### 4. 系統托盤重複

兩個實例都在系統托盤顯示圖示。

使用者會看到兩個一樣的圖示，不知道點哪個。

### 5. 背景進程失控

每個 Electron 實例都會啟動自己的背景 Python 進程（語音辨識服務）。

多開 = 多個 Python 進程 = 記憶體爆炸。

## Electron 的解法：單實例鎖

Electron 提供了 `app.requestSingleInstanceLock()` API，可以確保只有一個實例在運行。

```javascript
const { app } = require('electron');

// 嘗試取得單實例鎖
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
    // 已經有另一個實例在跑了，退出
    console.log('另一個實例已在運行，退出');
    app.quit();
} else {
    // 我是唯一的實例，正常啟動
    app.on('ready', () => {
        createWindow();
    });

    // 當使用者嘗試開啟第二個實例時觸發
    app.on('second-instance', (event, commandLine, workingDirectory) => {
        // 把現有視窗帶到前面
        if (mainWindow) {
            if (mainWindow.isMinimized()) {
                mainWindow.restore();
            }
            mainWindow.focus();
        }
    });
}
```

### 運作原理

`requestSingleInstanceLock()` 會嘗試取得一個系統級的鎖。

- 第一個實例：取得鎖，正常運行
- 第二個實例：取不到鎖，知道已經有人在跑了

當第二個實例嘗試啟動時，系統會通知第一個實例（觸發 `second-instance` 事件），然後第二個實例自己退出。

### 使用者體驗

使用者點兩次圖示，會發生什麼？

1. 第一次：應用正常啟動
2. 第二次：看起來沒反應，但原本的視窗會跳到前面

這是正確的行為。使用者以為「沒開起來」再點一次，結果是把已經開著的視窗叫出來。

## 進階：傳遞參數

有些應用支援用命令列參數開啟特定檔案。

例如：`myapp.exe document.txt`

如果應用已經在跑，第二個實例應該把檔案路徑傳給第一個實例，讓它開啟。

```javascript
app.on('second-instance', (event, commandLine, workingDirectory) => {
    // commandLine 包含第二個實例的命令列參數
    const filePath = commandLine[commandLine.length - 1];

    if (filePath && filePath.endsWith('.txt')) {
        // 開啟檔案
        openFile(filePath);
    }

    // 視窗帶到前面
    if (mainWindow) {
        mainWindow.focus();
    }
});
```

這樣即使應用已經在跑，使用者雙擊檔案還是能正常開啟。

## 我的實作

```javascript
// main.js
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
    console.log('應用已在運行中，退出新實例');
    app.quit();
} else {
    app.on('second-instance', (event, commandLine, workingDirectory) => {
        console.log('偵測到第二個實例，聚焦現有視窗');

        if (mainWindow) {
            // 如果視窗最小化或隱藏到托盤，恢復它
            if (mainWindow.isMinimized()) {
                mainWindow.restore();
            }
            if (!mainWindow.isVisible()) {
                mainWindow.show();
            }
            mainWindow.focus();
        }
    });

    // 正常的應用初始化
    app.whenReady().then(() => {
        createWindow();
        // ...
    });
}
```

加了這段之後，使用者不管點幾次圖示，都只會有一個實例。

## 其他平台的做法

單實例鎖不是 Electron 獨有的概念。

| 平台 | 做法 |
|------|------|
| Windows (C#) | `Mutex` |
| macOS (Swift) | `NSDistributedLock` 或 `NSRunningApplication` |
| Linux | 檔案鎖 (`flock`) 或 socket |
| Java | `FileLock` |
| Python | `filelock` 套件 |

原理都一樣：用某種系統資源（檔案、socket、命名物件）來協調多個進程。

## 什麼時候需要允許多開？

不是所有應用都要禁止多開。

**應該禁止多開**：
- 會存取獨佔資源（麥克風、特定檔案）
- 有系統托盤圖示
- 註冊全域快捷鍵
- 背景服務會衝突

**可以允許多開**：
- 純檢視用途（圖片檢視器）
- 每個視窗獨立運作
- 沒有共享狀態

我的語音辨識應用屬於「應該禁止多開」，所以加了單實例鎖。

---

單實例鎖是桌面應用的基本功。

不加的話，使用者不小心多開，就會遇到各種莫名其妙的 bug，而且很難 debug。

加了之後，這類問題直接消失。

相關文章：

- [聲聲慢：我做了一個離線語音轉文字工具](/Evernote/posts/shengshengman-intro)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
