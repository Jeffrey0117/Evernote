---
layout: ../../layouts/PostLayout.astro
title: dir 太醜了，換個方式看資料夾
date: 2026-01-13T08:36
description: 用 yazi 讓 terminal 的檔案瀏覽變得視覺化
tags:
  - CLI
  - Windows
  - 開發工具
---

最近越來越常用 [Windows Terminal](https://github.com/microsoft/terminal)。

以前覺得 terminal 就是黑底白字、打指令用的，沒什麼好玩的。但 Windows Terminal 出來之後，**分頁、分割視窗、自訂主題、GPU 加速渲染**，整個質感不一樣了。

用久了發現，很多事情在 terminal 裡做比開 GUI 還快。看 git log、跑 build、開 dev server，都不用離開鍵盤。

但有一件事還是很煩：**看資料夾內容**。

## dir 的問題

在 Windows Terminal 打 `dir`，出來的東西長這樣：

```
 Volume in drive C is OS
 Directory of C:\Users\jeffb\Desktop\code

01/13/2026  08:30 AM    <DIR>          .
01/13/2026  08:30 AM    <DIR>          ..
01/13/2026  07:00 AM    <DIR>          Evernote
01/12/2026  15:30 PM    <DIR>          PasteV
01/10/2026  09:00 AM    <DIR>          Unifold
...
```

能用，但很醜。想快速看有哪些專案、哪個最近改過、裡面有什麼檔案，要一直 cd 進去再 dir，很煩。

我想要的是那種**可以用方向鍵瀏覽、按 Enter 進資料夾、有預覽**的東西。

## yazi

[yazi](https://github.com/sxyazi/yazi) 是一個用 Rust 寫的終端檔案管理器，很快，而且長得很漂亮。

裝法（Windows 用 scoop）：

```bash
scoop install yazi
```

### scoop vs winget

[scoop](https://scoop.sh/) 和 [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) 都是 Windows 的套件管理器，但設計哲學不一樣：

| | scoop | winget |
|------|-------|--------|
| **來源** | 社群維護 | 微軟官方 |
| **安裝位置** | 使用者目錄，不需要管理員權限 | 系統目錄，有些要管理員權限 |
| **軟體類型** | 偏開發工具、CLI 工具 | 什麼都有，包括一般桌面軟體 |
| **更新機制** | `scoop update *` 一鍵更新全部 | `winget upgrade --all` |

我自己兩個都用。CLI 工具用 scoop 裝（yazi、fzf、ripgrep），一般軟體用 winget 裝（VS Code、Discord）。

macOS 的 [Homebrew](https://brew.sh/) 跟 scoop 比較像，Linux 的 `apt` 跟 winget 比較像。

### 自己寫 batch 檔

裝完後在 terminal 打 `yazi` 就會進入檔案瀏覽模式。

但 `yazi` 四個字有點長，我寫了一個 batch 檔讓我打 `lls` 就能呼叫：

```batch
@echo off
yazi %*
```

放在 PATH 裡就能用了。

寫完這個之後我就想：**欸，那我幹嘛不把其他 Unix 指令也做出來？**

`ls`、`cat`、`grep`... 這些在 Linux 和 macOS 上很自然的指令，Windows 上都沒有。

每次手指習慣性打 `ls`，出來的是「不是內部或外部命令」。

於是我真的做了一個工具，用 JSON 設定檔產生一堆 batch 檔，讓 Windows 也能用 Unix 指令。

詳情見：[在 Windows 上跑 Unix 指令不用裝 WSL](/Evernote/posts/cmdx-unix-commands-on-windows)

## 為什麼選 yazi

其他類似的工具：

| 工具 | 說明 |
|------|------|
| [ranger](https://github.com/ranger/ranger) | Python 寫的，很老牌，但在 Windows 上裝比較麻煩 |
| [lf](https://github.com/gokcehan/lf) | Go 寫的，輕量，但功能比較少 |
| [nnn](https://github.com/jarun/nnn) | C 寫的，超快超輕量，但介面比較陽春 |
| [yazi](https://github.com/sxyazi/yazi) | Rust 寫的，快、漂亮、功能完整 |

yazi 的優勢是**圖片預覽**和**非同步 I/O**，大資料夾也不會卡。而且內建主題系統，可以調成自己喜歡的樣子。

## 基本操作

一開始有點卡，因為是 Vim 式的操作邏輯。記幾個常用的：

**移動**
- `j` / `k`：上下移動（j 往下，想成 jump down）
- `h` / `l`：h 回上層資料夾，l 進入資料夾（h 是 left，l 是 right）
- `gg`：跳到最上面
- `G`：跳到最下面

**操作檔案**
- `Enter`：用預設程式開啟檔案
- `y`：yank，複製（跟 Vim 一樣）
- `p`：paste，貼上
- `d`：delete，刪除（會進垃圾桶）
- `r`：rename，重新命名

**其他**
- `/`：搜尋
- `q`：quit，離開
- `~`：回到家目錄
- `?`：顯示所有快捷鍵

列了一堆，但說實話最常用的就 `h`、`l`、`/`、`q`。

進出資料夾、搜尋、離開，這樣就夠了。

原本以為 terminal 操作就是死記硬背一堆指令，但用了 yazi 才發現，原來 terminal 世界也有這麼多選項可以玩。

Vim 式操作、檔案預覽、主題系統... 不是想像中那麼生硬。

---

沒想到 terminal 用久了會越來越回不去。

以前寫 code 都開 VS Code 的檔案總管看資料夾結構，現在反而習慣開 terminal 打 `lls`。

看 git 狀態也是 `git status` 比按按鈕快，跑指令也是直接打比找選單快。

**越活越回去，居然不太用 VS Code 的側邊欄了。**

