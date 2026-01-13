---
layout: ../../layouts/PostLayout.astro
title: 讓我棄坑 VS Code 的神物 Windows Terminal
date: 2026-01-13T09:07
description: 原生內建的東西居然這麼強
tags:
  - CLI
  - Windows
  - 開發工具
---

[Windows Terminal](https://github.com/microsoft/terminal) 居然是 Windows 原生內建的。

我一直以為要搞這種分割視窗、多 tab 的終端機，要另外裝什麼工具。

結果這東西就躺在那邊，免費、好看、功能完整。

## 為什麼會發現這東西

之前寫 code 習慣開 VS Code。

一個專案一個視窗，很合理吧？

問題是專案越開越多，筆電開始撐不住了。

VS Code 吃記憶體吃很兇，開個三四個視窗，風扇就開始狂轉。

後來想說，我很多時候根本不需要完整的 IDE 啊。

看個 log、跑個指令、改個設定檔，用 terminal 就夠了。

於是開始認真研究 Windows Terminal。

## 最扯的是分割功能

一個視窗可以切成好幾塊，每塊獨立跑不同的東西。

| 操作 | 快捷鍵 |
|------|--------|
| 水平分割（左右） | `Alt + Shift + +` |
| 垂直分割（上下） | `Alt + Shift + -` |
| 切換焦點 | `Alt + 方向鍵` |
| 調整大小 | `Alt + Shift + 方向鍵` |
| 關閉當前面板 | `Ctrl + Shift + W` |

`Alt + Shift + -` 按下去，畫面就切成上下兩塊。

再按一次，變三塊。

每塊都是獨立的 shell，可以一邊跑 `npm run dev`，一邊看 `git log`，一邊開 `htop` 監控資源。

## 也可以用指令開

```powershell
# 水平分割，開 PowerShell
wt -w 0 sp -H

# 垂直分割，開 cmd
wt -w 0 sp -V -p "Command Prompt"
```

`-H` 是 horizontal（水平），`-V` 是 vertical（垂直）。

## 類似的東西

| 工具 | 說明 |
|------|------|
| [tmux](https://github.com/tmux/tmux) | Linux/macOS 的終端多工器，功能更強但要學指令 |
| [screen](https://www.gnu.org/software/screen/) | 比 tmux 老，功能類似 |
| Windows Terminal | 夠用，不用額外裝東西 |

tmux 功能確實更強，但我在 Windows 上用，內建的就夠了。

---

我現在的用法是這樣：

用 Windows 原生的視窗分割（`Win + 方向鍵`），把螢幕切成三個直的區塊。

每個 Windows Terminal 視窗裡面再用 `Alt + Shift + -` 做上下分割。

這樣一個螢幕可以塞 6 個 terminal，而且視覺上很整齊。

之前試過直接在一個視窗裡塞四個面板然後左右分割，但看起來有點亂，眼睛不知道要看哪裡。

三直排 + 各自上下分，對我來說最舒服。

沒想到用久了，很多事情反而不開 VS Code 了。

