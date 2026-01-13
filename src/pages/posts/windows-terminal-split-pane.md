---
layout: ../../layouts/PostLayout.astro
title: Windows Terminal 分割視窗速查
date: 2026-01-13T09:07
description: 快捷鍵一覽，不廢話
tags:
  - CLI
  - Windows
  - 速查
---

Windows Terminal 內建分割視窗功能，不用另外裝 tmux。

## 快捷鍵

| 操作 | 快捷鍵 |
|------|--------|
| 水平分割（左右） | `Alt + Shift + +` |
| 垂直分割（上下） | `Alt + Shift + -` |
| 切換焦點 | `Alt + 方向鍵` |
| 調整大小 | `Alt + Shift + 方向鍵` |
| 關閉當前面板 | `Ctrl + Shift + W` |

## 用指令開

也可以在新分頁時直接指定分割：

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
| [tmux](https://github.com/tmux/tmux) | Linux/macOS 的終端多工器，功能更強大但要學指令 |
| [screen](https://www.gnu.org/software/screen/) | 比 tmux 老，功能類似 |
| Windows Terminal 內建 | 夠用，不用額外裝東西 |

對我來說 Windows Terminal 內建的就夠了，不需要另外搞 tmux。

---

我自己的用法是這樣：

用 Windows 原生的視窗分割（`Win + 方向鍵`），把螢幕切成三個直的區塊。

然後每個 Windows Terminal 視窗裡面再用 `Alt + Shift + -` 做上下分割。

這樣一個螢幕可以塞 6 個 terminal，而且視覺上很整齊。

之前試過直接在一個視窗裡塞四個面板然後左右分割，但看起來有點亂，眼睛不知道要看哪裡。

三直排 + 各自上下分，對我來說最舒服。

