---
layout: ../../layouts/PostLayout.astro
title: 裝軟體還在到處找安裝檔？
date: 2026-01-14T01:40
description: winget、scoop、Chocolatey 三大 Windows 套件管理器比較與選擇指南
tags:
  - Windows
  - CLI
  - 開發工具
---

以前在 Windows 上裝軟體是這樣的：

1. 開瀏覽器，搜尋「XXX 下載」
2. 找到官網（或是可疑的第三方網站）
3. 下載 .exe 或 .msi
4. 雙擊安裝，狂按下一步
5. 中間可能還會偷裝什麼工具列或防毒軟體
6. 完成

裝一個軟體要花五分鐘，裝十個要花一小時。

換一台電腦？全部重來一遍。

我以前就是這樣活過來的，覺得這是常態。

直到某天我看 Linux 的朋友，他打一行 `apt install XXX`，軟體就裝好了。

**什麼？這麼簡單？**

## Windows 也有套件管理器

後來發現 Windows 也有這種東西，而且不只一個，有三個主流的選擇：

| 工具 | 維護者 | 定位 | 需要管理員權限 |
|------|--------|------|----------------|
| [winget](https://github.com/microsoft/winget-cli) | 微軟官方 | 通用軟體安裝，像是 Windows 版的 App Store CLI | 部分需要 |
| [scoop](https://scoop.sh/) | 社群 | 開發者工具，乾淨安裝到使用者目錄 | 不需要 |
| [Chocolatey](https://chocolatey.org/) | 社群 | 老牌，套件最多，但比較肥 | 需要 |

三個都能用指令裝軟體，但設計哲學很不一樣。

## winget 是微軟的親兒子

[winget](https://github.com/microsoft/winget-cli) 是微軟在 2020 年推出的套件管理器，Windows 10/11 內建。

裝軟體就是：

```bash
winget install vscode
winget install discord
winget install spotify
```

**優點**：
- 內建，不用另外裝
- 套件來源是官方的 Windows Package Manager 倉庫，或直接從軟體官網下載
- 裝的東西跟你手動下載安裝的一樣，出現在「新增或移除程式」裡面

**缺點**：
- 有些軟體安裝時需要管理員權限
- 更新比較慢，新軟體可能找不到

一般桌面軟體我都用 winget 裝。

## scoop 才是開發者的好朋友

[scoop](https://scoop.sh/) 是社群維護的套件管理器，主打「不需要管理員權限」和「乾淨安裝」。

所有軟體都裝在 `~/scoop/` 目錄下，不會動到系統目錄。

```bash
# 先裝 scoop（只需要一次）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 然後就能裝軟體了
scoop install git
scoop install nodejs
scoop install python
scoop install fzf
scoop install ripgrep
```

**優點**：
- 不需要管理員權限
- 安裝乾淨，想刪掉直接砍目錄就好
- 開發工具超齊全
- 一鍵更新：`scoop update *`

**缺點**：
- 主要是 CLI 工具和開發相關的軟體
- 一般桌面軟體比較少

我的 git、Node.js、Python、各種 CLI 工具都用 scoop 裝。

### scoop 的 bucket 系統

scoop 用「bucket」來分類套件：

```bash
# 加入更多來源
scoop bucket add extras      # 一般桌面軟體
scoop bucket add versions    # 特定版本
scoop bucket add nerd-fonts  # 程式設計師字體

# 然後就能裝 extras 裡的東西
scoop install vscode         # 需要 extras bucket
```

像是 VS Code、Windows Terminal、OBS 這些，要先加 extras bucket 才裝得到。

## Chocolatey 我不用

[Chocolatey](https://chocolatey.org/) 是最老的 Windows 套件管理器，2011 年就有了。

套件數量最多，什麼都有。

但我不用。原因：

1. **需要管理員權限** — 每次裝東西都要開 admin shell，很煩
2. **會動到系統目錄** — 不像 scoop 那麼乾淨
3. **有商業版** — 開源版功能有限制
4. **速度比較慢** — 啟動和安裝都比 scoop 慢

如果你是系統管理員要管很多台電腦，Chocolatey 的自動化功能很強。

但對個人開發者來說，scoop + winget 就夠了。

## 我怎麼選

我自己的原則很簡單：

- **CLI 工具、開發工具** → scoop
- **一般桌面軟體** → winget
- **Chocolatey** → 不用

為什麼這樣分？

scoop 的設計就是給開發者的。不需要管理員權限、安裝乾淨、版本管理方便。裝 Node.js 的時候不會問你要不要順便裝什麼 Bing 工具列。

winget 適合裝那些「正常」的桌面軟體。Discord、Spotify、VS Code 這些，用 winget 裝跟手動裝的結果一樣，但省了下載的步驟。

| 我要裝什麼 | 用哪個 |
|------------|--------|
| git | scoop |
| Node.js | scoop |
| Python | scoop |
| fzf、ripgrep、yazi 等 CLI 工具 | scoop |
| VS Code | winget |
| Discord | winget |
| Chrome | winget |

這樣分的好處是 **scoop 目錄裡全是開發工具，想重灌的時候整包備份就好**。

## 但什麼時候該用哪個？

| 選 winget | 選 scoop |
|-----------|----------|
| 一般桌面軟體 | CLI 工具、開發工具 |
| 想要正式安裝 | 想要便攜版 |
| 有管理員權限 | 公司電腦有限制 |
| 要跟系統整合 | 要乾淨好移除 |

**我自己的判斷：**
- 裝 Chrome、VS Code、Discord → **winget**
- 裝 git、node、python → **scoop**
- 要便攜版、不留痕跡 → **scoop**
- 公司電腦沒有管理員權限 → **scoop**（不需要 admin）

有時候同一個軟體兩邊都有，那就看你在不在意「乾淨」。scoop 裝的東西砍掉目錄就沒了，winget 裝的要去「新增或移除程式」。

## 跟其他生態系比較

套件管理器不是只有 Windows 才有，每個平台、每個語言都有自己的選擇。

**作業系統層級**：
- macOS 有 [Homebrew](https://brew.sh/)，跟 scoop 很像
- Linux 有 apt、yum、pacman，跟 winget 比較像

**程式語言層級**：
- Python 有 [pip](/Evernote/posts/python-package-managers)，還有 uv、poetry、conda
- Node.js 有 [npm](/Evernote/posts/nodejs-package-managers)，還有 yarn、pnpm
- Rust 有 [Cargo](/Evernote/posts/why-cargo-is-the-best)，公認設計最好的
- Deno [根本不需要套件管理器](/Evernote/posts/deno-no-package-manager)，直接 URL import

每個生態系都在解決同一個問題：**怎麼讓安裝軟體變簡單**。

---

從到處找安裝檔，到一行指令搞定。

從裝軟體要花一小時，到十分鐘裝完所有東西。

套件管理器真的是現代開發的基礎設施。

**用了就回不去了。**
