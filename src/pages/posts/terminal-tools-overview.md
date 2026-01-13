---
layout: ../../layouts/PostLayout.astro
title: 終端工具全家桶，先搞懂誰是誰
date: 2026-01-14T02:12
description: 終端模擬器、多工器、編輯器... 這些東西到底什麼關係
tags:
  - CLI
  - 開發工具
  - 工作流程
---

我原本就是個 VS Code 使用者。

寫 code、看 git、跑 build，全部在 VS Code 裡面搞定。

夠用了，沒什麼好抱怨的。

直到我開始用 [Claude Code](https://www.anthropic.com/claude-code)。

## Claude Code 開啟的新世界

Claude Code 是 Anthropic 出的 AI 命令列工具，讓你可以在終端跟 AI 協作寫程式。

問題是，它要在終端跑。

一開始我就傻傻地打開 Windows Terminal，照著官方文件操作。

用了幾天發現：**欸，原來終端可以這樣玩？**

分割視窗讓 AI 跑一邊、自己寫一邊。切換不同專案不用開一堆 VS Code。快捷鍵按一按就切換焦點。

然後就開始聽到一堆名詞：Vim、Neovim、tmux、Alacritty、Zellij...

每個都有人在推，每個都說很厲害。

但我搞不懂：**這些東西到底是什麼關係？誰取代誰？要裝哪些？**

這篇就是要把這個搞清楚。

## 三層架構

先講結論。

終端世界的工具可以分成三層，從外到內：

```
終端模擬器（Windows Terminal / Alacritty）
    └── 終端多工器（tmux / Zellij）← 可選
            └── 編輯器 / Shell（Vim / Neovim / Fish）
```

**第一層：終端模擬器**

就是那個黑色視窗本人。你打開它，它給你一個地方打字。

**第二層：終端多工器**

在終端裡面再開好幾個「虛擬終端」，可以分割畫面、保持 session。

這層是可選的。Windows Terminal 自己就有分割功能，不一定要裝。

**第三層：編輯器 / Shell**

在終端裡面實際跑的東西。可能是 Vim 讓你寫程式，可能是 Fish 給你更好用的 shell。

搞懂這三層，後面就不會亂了。

## 終端模擬器：那個黑框框

終端模擬器就是那個視窗。

以前 Windows 只有 cmd 那個醜醜的黑框框。現在選擇多了。

### 主流選擇

| 終端模擬器 | 特色 | 適合誰 |
|-----------|------|--------|
| [Windows Terminal](https://github.com/microsoft/terminal) | 微軟官方、免費、內建分割視窗 | Windows 使用者首選 |
| [Alacritty](https://github.com/alacritty/alacritty) | GPU 加速、設定檔控制、跨平台 | 追求速度、喜歡用設定檔的人 |
| [Kitty](https://github.com/kovidgoyal/kitty) | GPU 加速、可顯示圖片、有插件系統 | 想在終端看圖片、不想裝多工器的人 |
| [WezTerm](https://github.com/wez/wezterm) | Lua 腳本控制一切、內建多工器功能 | 想用程式碼控制終端行為的人 |
| [iTerm2](https://iterm2.com/) | macOS 專用、功能完整 | Mac 使用者的經典選擇 |

Alacritty 標榜「最快的終端模擬器」，因為用 GPU 渲染（讓顯示卡來畫畫面，比 CPU 算快很多）。

### Windows Terminal 就夠用了

但說實話，對一般使用來說，**Windows Terminal 就很夠用了**。

分割視窗、多 tab、主題、字體設定，該有的都有。而且是原生內建，不用另外裝。

## 終端多工器：分身術

終端多工器做的事情是：**在一個終端裡面開好幾個「虛擬終端」**。

可以分割畫面、可以切換、可以把 session（工作階段）保存起來——斷線重連不會不見。

### 主流選擇

| 終端多工器 | 特色 | 適合誰 |
|-----------|------|--------|
| [tmux](https://github.com/tmux/tmux) | 超老牌、功能強大、到處都有 | 伺服器管理、遠端連線、想學經典工具的人 |
| [Zellij](https://github.com/zellij-org/zellij) | Rust 寫的、介面友善、有預設快捷鍵提示 | 覺得 tmux 太難記、想要現代化體驗的人 |
| [screen](https://www.gnu.org/software/screen/) | 比 tmux 更老、大部分 Linux 都有 | 在沒有 tmux 的伺服器上應急 |

### tmux vs Zellij

tmux 是這個領域的標準答案。

功能很強，但快捷鍵要背。先按 `Ctrl+b` 放開，再按第二個鍵：

| 按鍵 | 功能 |
|------|------|
| `%` | 垂直分割（左右兩塊） |
| `"` | 水平分割（上下兩塊） |
| `方向鍵` | 切換到那個方向的 pane |
| `d` | detach，離開但程式繼續跑 |

Zellij 是比較新的選擇，用 Rust 寫的，介面下面會顯示快捷鍵提示，對新手友善很多。

### 但你可能不需要

如果你在 Windows 上用 Windows Terminal，它內建就有分割視窗功能。

`Alt + Shift + +` 水平分割，`Alt + Shift + -` 垂直分割。

詳情見：[讓我棄坑 VS Code 的神物 Windows Terminal](/Evernote/posts/windows-terminal-split-pane)

tmux 的優勢是 **session 保存**。

你可以用 `tmux detach` 離開一個 session，下次用 `tmux attach` 接回來，裡面的東西都還在。

這在遠端連線的時候特別有用。SSH 斷掉，重連之後 attach 回去，正在跑的程式還在跑。

但如果你只是在本機用，Windows Terminal 的分割功能可能就夠了。

## 編輯器：戰場在這

這層是大家吵最兇的。

Vim 還是 VS Code？Neovim 又是什麼？

| 編輯器 | 特色 | 適合誰 |
|--------|------|--------|
| [Vim](https://www.vim.org/) | 經典中的經典、到處都有、模式編輯 | 想學一次到處能用、伺服器上要編輯檔案 |
| [Neovim](https://neovim.io/) | Vim 的現代化分支、Lua 設定、插件生態強 | 想用 Vim 但要更多功能的人 |
| [Helix](https://helix-editor.com/) | Rust 寫的、內建 LSP、開箱即用 | 覺得 Vim 太複雜、想要現代化體驗 |

### Vim 跟 VS Code 差在哪

VS Code 是 GUI（圖形介面）編輯器，有滑鼠、有選單、有側邊欄。

Vim 是終端編輯器，全鍵盤操作，有「模式」的概念。

Vim 的學習曲線很陡，但學會之後**編輯速度會快很多**。

比如你要刪掉一整行，VS Code 要按 `Ctrl+Shift+K`，或是用滑鼠選取再刪。Vim 只要打 `dd`，兩個字母，手不用離開鍵盤中央。

想把一個單字改成另一個？Vim 打 `ciw`（change in word），直接進入編輯模式，改完按 `Esc` 就好。

所有操作都在鍵盤上，不用移動手去拿滑鼠。

### Neovim 又是什麼

Neovim 是 Vim 的 fork（從原本的程式碼分出來，另起爐灶開發的版本），目標是現代化 Vim。

設定檔可以用 Lua 寫（Vim 用 Vimscript，比較難懂）。

插件生態很強，可以裝 LSP（Language Server Protocol，提供自動補全和錯誤提示的東西）、檔案樹、模糊搜尋... 基本上可以堆成一個 IDE。

很多人說「Neovim 是窮人的 VS Code」，但其實設定好之後，有些體驗比 VS Code 還順。

### Helix 的賣點

Helix 是比較新的選擇，用 Rust 寫的。

最大的賣點是**開箱即用**。LSP、語法高亮、多游標編輯，裝完就有，不用像 Neovim 一樣自己設定一堆。

操作邏輯跟 Vim 有點像，但選擇邏輯不一樣（先選再動作，而不是先動作再選）。

如果你覺得 Neovim 的設定太麻煩，Helix 是一個值得試試的選項。

## 番外：GUI 包裝

有些人會把終端工具包成 GUI 應用程式。

最常見的例子是 [Neovide](https://neovide.dev/)——它是 Neovim 的 GUI 前端。

本質上就是一個視窗，裡面跑 Neovim。

但它加了一些 GUI 才能做的事情：

- **動畫效果**：游標移動會有滑順的動畫
- **字體渲染**：用 GPU 渲染，字體更漂亮
- **原生視窗**：可以用 `Cmd+V` 貼上，不用搞終端的剪貼簿

為什麼有人要這樣做？

因為他們喜歡 Neovim 的操作方式，但想要 GUI 的視覺體驗。

魚與熊掌可以兼得。

## 你需要哪些？

講了這麼多，到底要裝什麼？

看你想做什麼。

### 你只是想跑 Claude Code？

沒有其他花俏的需求，就是想用 AI 寫程式。

**答案：Windows Terminal 就夠了。**

內建、免費、分割視窗都有。不用想太多。

### 你想玩分割視窗？

想要更強的分割功能，或是想要 session 保存（斷線重連不會不見）。

**兩個選擇：**

1. 先試 Windows Terminal 的內建分割，大部分情況夠用
2. 如果不夠，學 tmux 或 Zellij

Zellij 對新手友善一點，tmux 是經典工具，學一次到處都能用。

### 你受夠 VS Code 了？

想要更輕量的開發環境，不想再等 VS Code 載入。

**Neovim + 插件生態系**。

但這是一條不歸路。

你需要花時間學 Vim 的操作邏輯，花時間設定插件，花時間調整成順手的樣子。

好處是：設定好之後，開編輯器變成一瞬間的事情。VS Code 冷啟動要 3-5 秒，Neovim 是 0.1 秒。

如果你只是想試試，可以先裝 Helix。開箱即用，不用設定，體驗一下終端編輯器的感覺。

## 什麼時候選哪個

講了這麼多工具，直接給你選擇指南。

### 終端模擬器

| 選 Windows Terminal | 選 Alacritty | 選 WezTerm |
|---------------------|--------------|------------|
| Windows 使用者、不想折騰 | 追求速度、喜歡 GPU 渲染 | 想用 Lua 腳本控制一切 |
| 內建功能就夠用 | 喜歡用設定檔控制 | 需要內建多工器功能 |
| 不想額外安裝東西 | 跨平台使用 | 想要高度客製化 |

**我自己的判斷：**
- Windows 使用者 → **Windows Terminal** 就夠了，內建、免費、分割視窗都有
- 想要 GPU 渲染、更快的渲染速度 → **Alacritty**
- 想要用程式碼控制終端行為 → **WezTerm**

### 終端多工器

| 不用 tmux | 用 tmux | 用 Zellij |
|-----------|---------|-----------|
| Windows Terminal 內建分割夠用 | 需要 session 保持 | 覺得 tmux 快捷鍵難記 |
| 只在本機使用 | 常 SSH 遠端連線 | 想要現代化體驗 |
| 不想學新工具 | 伺服器上要用 | 喜歡預設快捷鍵提示 |

**我自己的判斷：**
- 本機使用、分割視窗夠用 → **不用裝 tmux**
- 要 session 保持、常 SSH 遠端 → **tmux**（學一次到處能用）
- 想要友善的 UI、不想背快捷鍵 → **Zellij**

### 編輯器

| 繼續用 VS Code | 用 Neovim | 用 Helix |
|----------------|-----------|----------|
| 不想學新東西 | 想要全鍵盤操作 | 不想設定一堆插件 |
| GUI 操作習慣了 | 願意花時間設定 | 想要開箱即用 |
| 插件生態熟悉 | 追求啟動速度 | 想體驗終端編輯器 |

**我自己的判斷：**
- 不想學新東西、現有工作流順暢 → **繼續用 VS Code**
- 想在終端編輯、願意投資時間學習 → **Neovim**
- 不想設定一堆插件、想快速體驗 → **Helix**

---

原本只是想跑個 Claude Code，結果一路挖下去發現終端世界這麼深。

Windows Terminal、tmux、Neovim... 每個都可以再深入研究。

這篇先把大方向講清楚，後續會再寫：

- **Vim vs Neovim vs Helix**：三個終端編輯器的詳細比較
- **tmux vs Zellij**：終端多工器怎麼選
- **終端模擬器比較**：Alacritty、Kitty、WezTerm 誰適合你
- **Neovide 介紹**：把 Neovim 包成 GUI 是什麼體驗

## 延伸閱讀

想深入研究的話，這些資源不錯：

- [Vim Adventures](https://vim-adventures.com/)：用遊戲學 Vim，不無聊
- [The Missing Semester - Editors](https://missing.csail.mit.edu/2020/editors/)：MIT 的 Vim 教學，免費
- [tmux cheatsheet](https://tmuxcheatsheet.com/)：tmux 快捷鍵速查表
- [Helix 官方教學](https://docs.helix-editor.com/usage.html)：Helix 入門指南

---

**三層架構：模擬器 → 多工器 → 編輯器。記住這個，終端世界的地圖就有了。**
