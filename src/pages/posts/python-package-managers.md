---
layout: ../../layouts/PostLayout.astro
title: Python 的套件管理有多亂？
date: 2026-01-14T01:40
description: pip、uv、poetry、conda 四大 Python 套件管理工具比較
tags:
  - Python
  - CLI
  - 開發工具
---

Python 的套件管理是出了名的亂。

不是「有點亂」，是「每個人講的都不一樣」那種亂。

你問十個 Python 開發者怎麼管套件，會得到十二種答案。

有人說用 pip，有人說 pip + venv，有人說 poetry，有人說 conda，有人說 pipenv（然後馬上被另一個人說 pipenv 已經過氣了）。

**到底該用哪個？**

我踩過不少坑，這篇把我的經驗整理出來。

## pip + venv 能用但很煩

Python 內建的套件管理就是 [pip](https://pip.pypa.io/)。

裝套件就是 `pip install XXX`，簡單直接。

但問題來了：pip 預設把套件裝在全域環境。

你做專案 A 裝了 `requests 2.28`，做專案 B 裝了 `requests 2.31`，兩個打架。

所以要搭配 [venv](https://docs.python.org/3/library/venv.html)（虛擬環境）：

```bash
# 建立虛擬環境
python -m venv .venv

# 啟動虛擬環境
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

# 現在 pip install 的東西只會裝在這個環境裡
pip install requests
pip install flask

# 匯出依賴
pip freeze > requirements.txt

# 別的電腦要裝
pip install -r requirements.txt
```

能用，但很煩。

**每次開新專案都要：**
1. 手動建 venv
2. 手動啟動 venv
3. 裝完套件要手動 `pip freeze`
4. 更新套件要手動改 requirements.txt

而且 `requirements.txt` 沒有版本範圍的概念。你寫 `requests==2.28.0`，就是釘死 2.28.0，不會自動更新。

最慘的是 **依賴衝突**。A 套件要 `numpy>=1.20`，B 套件要 `numpy<1.20`，pip 不會提前告訴你，裝到一半才爆炸。

## poetry 想一條龍但有點重

[poetry](https://python-poetry.org/) 想解決 pip 的所有問題。

```bash
# 建新專案
poetry new my-project

# 或是在現有目錄初始化
poetry init

# 加套件
poetry add requests
poetry add flask

# 裝依賴
poetry install

# 跑指令
poetry run python main.py
```

poetry 用 `pyproject.toml` 管設定，用 `poetry.lock` 鎖版本。

```toml
# pyproject.toml
[tool.poetry.dependencies]
python = "^3.10"
requests = "^2.28"
flask = "^2.0"
```

`^2.28` 表示「2.28 以上，但不到 3.0」，有版本範圍的概念。

**優點**：
- 自動管虛擬環境
- 依賴解析比 pip 好
- `poetry.lock` 保證每個人裝到一樣的版本
- 可以直接發布到 PyPI

**缺點**：
- 速度偏慢，依賴解析有時候要等很久
- 跟某些套件的相容性有問題
- 設定檔語法有點囉嗦

我之前用 poetry 用了一陣子，體驗不錯。

但每次 `poetry add` 都要等它解析依賴，大專案有時候要等一兩分鐘。

## uv 快到誇張

[uv](https://github.com/astral-sh/uv) 是 2024 年冒出來的新星。

用 Rust 寫的，目標是成為「Python 的 Cargo」。

**有多快？官方說比 pip 快 10-100 倍，比 poetry 快 10 倍以上。**

我實測過，真的很快。以前 `poetry install` 要等 30 秒的專案，用 uv 只要 2 秒。

```bash
# 裝 uv（用 pip 裝或其他方式）
pip install uv

# 或用 scoop（Windows）
scoop install uv

# 建專案
uv init my-project

# 加套件
uv add requests
uv add flask

# 跑指令
uv run python main.py

# 也可以直接取代 pip
uv pip install requests
```

uv 的野心很大，想統一 Python 的套件管理。

它的功能已經覆蓋：
- pip 的功能（裝套件）
- venv 的功能（虛擬環境）
- pip-tools 的功能（鎖版本）
- poetry 的功能（專案管理）

**優點**：
- 超級快
- 相容 pip 的生態系
- 設計現代化
- 開發超積極，每週都有新功能

**缺點**：
- 比較新，可能有 bug
- 生態系還在長，有些邊緣案例可能沒處理好

我現在新專案都用 uv。

## conda 適合科學計算

[conda](https://docs.conda.io/) 不只管 Python 套件，還管系統套件。

如果你要裝 numpy、pandas、scikit-learn、tensorflow 這些科學計算套件，conda 可能是最省事的選擇。

為什麼？因為這些套件底層有 C/C++ 的依賴。用 pip 裝可能要自己編譯，用 conda 裝直接給你編好的 binary。

```bash
# 裝 miniconda（比完整的 Anaconda 輕量）
# 然後：
conda create -n myproject python=3.10
conda activate myproject
conda install numpy pandas scikit-learn
```

**優點**：
- 科學計算套件超齊全
- 不用自己編譯
- 可以管理不同版本的 Python

**缺點**：
- 體積大
- 跟 pip 的生態系有時候衝突
- 速度不快

如果你主要做資料科學、機器學習，conda 是合理的選擇。

如果你做 web 開發或一般的 Python 專案，用 uv 或 poetry 就好。

## 四個工具比較

| 工具 | 速度 | 易用性 | 適合場景 |
|------|------|--------|----------|
| pip + venv | 中 | 基本但手動 | 簡單腳本、學習用 |
| poetry | 慢 | 一條龍 | 正式專案、需要發布套件 |
| uv | 超快 | 現代化 | 任何場景，新專案首選 |
| conda | 慢 | 科學計算友好 | 資料科學、機器學習 |

## 我怎麼選

我現在的選擇：

- **新專案** → uv
- **科學計算專案** → conda
- **維護舊專案** → 看它原本用什麼就用什麼

poetry 我已經不太用了。不是不好，是 uv 太快了。

pip + venv 還是有用，但只有在很簡單的腳本或者要教新手的時候才用。

## 但什麼時候該用哪個？

| 情境 | 選這個 |
|------|--------|
| 快速測試、寫個小腳本 | pip 就好 |
| 正式專案、要鎖版本 | uv 或 poetry |
| 科學計算、機器學習 | conda |
| 要特定版本的 Python | conda |
| 新專案、沒歷史包袱 | uv |

**我自己的判斷：**
- 寫個 100 行的腳本 → **pip**（別折騰了）
- 正式專案要協作 → **uv**（快又現代）
- 裝 numpy、pandas、tensorflow → **conda**（省得自己編譯）
- 專案已經在用 poetry → **繼續用**（沒壞別修）
- 新專案選誰 → **uv**（2024 年後的首選）

能動就好。不用每個專案都追求最佳解，pip + venv 用了十幾年也沒死人。

## 跟其他生態系比較

Python 的套件管理為什麼這麼亂？

因為歷史包袱太重。pip 設計的時候沒想到現代的需求，後來各種工具補破網。

對比一下其他語言：

- [Rust 的 Cargo](/Evernote/posts/why-cargo-is-the-best)：從一開始就設計好了，公認最好用
- [Node.js 的 npm/yarn/pnpm](/Evernote/posts/nodejs-package-managers)：也有混亂期，但現在穩定了
- [Deno](/Evernote/posts/deno-no-package-manager)：直接用 URL import，根本不需要套件管理器
- [Windows 的 winget/scoop](/Evernote/posts/windows-package-managers)：作業系統層級的套件管理

Python 正在往 uv 統一的方向走。

uv 的背後是 [Astral](https://astral.sh/)，就是做 [Ruff](https://github.com/astral-sh/ruff)（超快的 Python linter）的那家公司。他們用 Rust 重寫 Python 工具鏈的策略很成功。

---

Python 的套件管理從「各自為政」到「漸漸統一」，走了快二十年。

現在終於有個像樣的選擇了。

**如果你還在用 pip + venv，試試 uv。快到你會懷疑以前在裝什麼鬼。**
