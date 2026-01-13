---
layout: ../../layouts/PostLayout.astro
title: 視窗一直被蓋掉，煩死了
date: 2026-01-13T17:56
description: 語音辨識應用需要置頂和縮小到托盤，不然用起來很痛苦
tags:
  - Electron
  - 桌面應用
  - UI/UX
---

語音辨識應用有個使用場景：一邊看辨識結果，一邊打字到其他視窗。

你對著麥克風講話，辨識結果出來，你要複製貼到文件裡。

**問題來了：每次點其他視窗，辨識視窗就被蓋掉。**

要切回來看結果，再切過去貼上。來來回回，我超煩。

## 我一開始想的方法

講完一段，Alt+Tab 切到聲聲慢，看辨識結果，Ctrl+C 複製，Alt+Tab 切回去，Ctrl+V 貼上。

重複二十次之後，我手指開始痛。

然後我想：有沒有辦法讓視窗不要被蓋掉？

搜尋「electron window always visible」，第一個結果就是 `setAlwaysOnTop`。

一行程式碼。我之前在幹嘛。

## 置頂功能

Electron 內建：

```javascript
mainWindow.setAlwaysOnTop(true);
```

一行程式碼。

### 做成可以開關

置頂不是每個時候都要。有時候想讓它被蓋掉。

做個切換按鈕：

```javascript
function toggleAlwaysOnTop() {
    const isOnTop = mainWindow.isAlwaysOnTop();
    mainWindow.setAlwaysOnTop(!isOnTop);
    return !isOnTop;
}
```

### 記住使用者偏好

每次開應用都要重新設定很煩。

用 [electron-store](https://github.com/sindresorhus/electron-store) 存偏好：

```javascript
const Store = require('electron-store');
const store = new Store();

function toggleAlwaysOnTop() {
    const isOnTop = !mainWindow.isAlwaysOnTop();
    mainWindow.setAlwaysOnTop(isOnTop);
    store.set('alwaysOnTop', isOnTop); // 記住設定
    return isOnTop;
}

// 啟動時恢復
const alwaysOnTop = store.get('alwaysOnTop', false);
mainWindow.setAlwaysOnTop(alwaysOnTop);
```

## 縮小到托盤

![Electron 系統托盤範例](https://www.tutorialspoint.com/electron/images/tray.jpg)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>Windows 右下角那排小圖示。點一下就能叫出應用。</small></p>

語音辨識應用通常要「一直開著」。

但不需要一直佔著畫面。

**使用者想要：關掉視窗，但程式繼續跑。需要時再叫出來。**

### 我第一版的 bug

第一版我沒加 `app.isQuitting` 判斷。

結果是：使用者點托盤的「退出」，視窗隱藏了，但程式沒關。因為 `close` 事件被我攔截了，永遠不會真的關閉。

使用者要開工作管理員強制結束。

這個 bug 被回報了三次我才發現。

### 正確的做法

正常情況，點 X 會關閉應用。我們要讓它變成「縮小到托盤」，但要留一條路讓程式能真的關掉：

```javascript
mainWindow.on('close', (event) => {
    if (!app.isQuitting) {
        event.preventDefault();
        mainWindow.hide(); // 縮小而不是關閉
    }
});

// 真正要退出時
app.on('before-quit', () => {
    app.isQuitting = true;
});
```

### 建立托盤圖示

縮到托盤要有圖示，不然使用者找不到。

```javascript
const { Tray, Menu } = require('electron');

let tray = null;

function createTray() {
    tray = new Tray('icon.png');

    const contextMenu = Menu.buildFromTemplate([
        {
            label: '顯示視窗',
            click: () => {
                mainWindow.show();
                mainWindow.focus();
            }
        },
        { type: 'separator' },
        {
            label: '退出',
            click: () => {
                app.isQuitting = true;
                app.quit();
            }
        }
    ]);

    tray.setToolTip('聲聲慢');
    tray.setContextMenu(contextMenu);

    // 點擊托盤圖示顯示/隱藏視窗
    tray.on('click', () => {
        mainWindow.isVisible() ? mainWindow.hide() : mainWindow.show();
    });
}
```

### 要不要給選項

有些使用者可能不喜歡這個行為。

「我點 X 就是要關閉，不要幫我縮小。」

可以做成設定：

```javascript
const closeToTray = store.get('closeToTray', true);

mainWindow.on('close', (event) => {
    if (!app.isQuitting && closeToTray) {
        event.preventDefault();
        mainWindow.hide();
    }
});
```

預設是縮小到托盤，但使用者可以在設定裡關掉。

## macOS 的差異

macOS 的托盤叫 Menu Bar，行為不太一樣。

### 圖示大小

macOS 建議用 16x16 或 18x18 的 Template Image：

```javascript
const icon = nativeImage.createFromPath('iconTemplate.png');
icon.setTemplateImage(true);
```

`Template Image` 會自動適應深淺色模式。

### Dock 圖示

即使縮到托盤，Dock 可能還會顯示圖示。

如果想要純托盤應用：

```javascript
if (process.platform === 'darwin') {
    app.dock.hide();
}
```

## 完整範例

```javascript
const { app, BrowserWindow, Tray, Menu, ipcMain } = require('electron');
const Store = require('electron-store');

const store = new Store();
let mainWindow;
let tray;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 400,
        height: 600,
        alwaysOnTop: store.get('alwaysOnTop', false),
    });

    // 縮小到托盤
    mainWindow.on('close', (event) => {
        if (!app.isQuitting && store.get('closeToTray', true)) {
            event.preventDefault();
            mainWindow.hide();
        }
    });
}

function createTray() {
    tray = new Tray('icon.png');

    const contextMenu = Menu.buildFromTemplate([
        { label: '顯示視窗', click: () => mainWindow.show() },
        { type: 'separator' },
        {
            label: '退出',
            click: () => {
                app.isQuitting = true;
                app.quit();
            }
        }
    ]);

    tray.setContextMenu(contextMenu);
    tray.on('click', () => {
        mainWindow.isVisible() ? mainWindow.hide() : mainWindow.show();
    });
}

// 切換置頂
ipcMain.handle('toggle-always-on-top', () => {
    const isOnTop = !mainWindow.isAlwaysOnTop();
    mainWindow.setAlwaysOnTop(isOnTop);
    store.set('alwaysOnTop', isOnTop);
    return isOnTop;
});

app.whenReady().then(() => {
    createWindow();
    createTray();
});

app.on('before-quit', () => {
    app.isQuitting = true;
});
```

---

這兩個功能做起來不難。

但沒做的話，使用者會覺得「這應用用起來很卡」。

有做的話，使用者不會特別注意，只會覺得「用起來很順」。

**使用者體驗就是這些小細節堆起來的。**

相關文章：

- [為什麼桌面應用不能多開？談 Electron 單實例鎖](/Evernote/posts/why-prevent-multiple-instances)
- [聲聲慢：我做了一個離線語音轉文字工具](/Evernote/posts/shengshengman-intro)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
