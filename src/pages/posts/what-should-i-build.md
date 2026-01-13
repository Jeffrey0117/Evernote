---
layout: ../../layouts/PostLayout.astro
title: 寫程式解決問題之前，先決定你要做什麼
date: 2026-01-14T05:50
description: 腳本、擴充套件、網頁、API、App？選錯形式比選錯框架更浪費時間
tags:
  - 開發觀念
  - 新手指南
  - 架構決策
---

我看過太多人這樣問問題：

「我想做一個 XXX，應該用 React 還是 Vue？」

**等等，你確定要做網頁嗎？**

很多問題根本不需要網頁。有些用腳本 10 分鐘解決，有些用瀏覽器擴充套件更適合。

選錯形式，比選錯框架浪費更多時間。

---

## 五種形式

| 形式 | 一句話定義 | 典型用途 |
|------|------------|----------|
| 腳本 | 跑一次、做完就結束 | 批次處理、自動化、資料轉換 |
| 擴充套件 | 寄生在瀏覽器或編輯器上 | 改變現有軟體的行為 |
| 網頁 | 開瀏覽器就能用 | 給別人用的工具、展示內容 |
| API 服務 | 沒有畫面，只提供資料 | 後端服務、給其他程式呼叫 |
| App | 安裝在電腦或手機上 | 需要離線、系統整合、效能要求高 |

---

## 怎麼選

### 問自己這幾個問題

```
1. 這個東西是給誰用的？
   ├── 只有我自己 → 腳本 或 擴充套件
   └── 給別人用 → 網頁 或 App

2. 需要畫面嗎？
   ├── 不需要 → 腳本 或 API
   └── 需要 → 網頁 或 App 或 擴充套件

3. 要一直跑還是跑一次？
   ├── 跑一次就好 → 腳本
   └── 要持續運行 → API 服務

4. 是要改變現有軟體的行為嗎？
   ├── 是 → 擴充套件
   └── 否 → 其他形式

5. 需要存取本機檔案、系統功能嗎？
   ├── 需要 → App 或 腳本
   └── 不需要 → 網頁
```

---

## 腳本：90% 的問題用這個就夠

**適合的情況**：

- 只有你自己會用
- 做完一件事就結束
- 不需要漂亮的介面
- 自動化重複性工作

**例子**：

| 問題 | 腳本解法 |
|------|----------|
| 把 100 張圖片轉成 WebP | Python + Pillow，10 行搞定 |
| 從 API 抓資料存成 CSV | Python + httpx，20 行搞定 |
| 重新命名一堆檔案 | Python + os，5 行搞定 |
| 定時備份資料庫 | Shell script + cron |

```python
# 例：批次轉換圖片格式
from pathlib import Path
from PIL import Image

for file in Path('images').glob('*.png'):
    with Image.open(file) as img:
        img.save(file.with_suffix('.webp'), 'WEBP')
```

**別把腳本硬做成網頁**。

我見過有人想「把 100 張圖片轉格式」，結果做了一個網頁上傳系統。

花了三天，結果自己用一次就沒再用了。

腳本 10 分鐘就解決的事。

---

## 擴充套件：改變現有軟體的行為

**適合的情況**：

- 想在現有網站/軟體上加功能
- 不需要（或沒辦法）改原始碼
- 功能跟特定網站/軟體綁定

**例子**：

| 問題 | 擴充套件解法 |
|------|--------------|
| YouTube 跳過廣告 | 瀏覽器擴充套件 |
| GitHub 顯示檔案樹 | 瀏覽器擴充套件 |
| VS Code 加新功能 | VS Code Extension |
| Obsidian 自訂功能 | Obsidian Plugin |

**瀏覽器擴充套件的門檻比你想的低**：

```javascript
// 最簡單的 content script：在每個頁面跑
// manifest.json 設定好，這段 JS 就會注入到網頁裡
document.querySelectorAll('.ad').forEach(el => el.remove());
```

如果你只是想在「某個網站」加功能，甚至不用做擴充套件——用 [Tampermonkey](https://www.tampermonkey.net/) 寫 userscript 就好。

更多細節見：[Tampermonkey：在任何網站注入你的程式碼](/Evernote/posts/tampermonkey-inject-code-into-any-website)

---

## 網頁：給別人用的工具

**適合的情況**：

- 要給不會寫程式的人用
- 不想讓人安裝東西
- 需要跨平台（電腦、手機都能用）
- 需要多人協作或分享

**例子**：

| 問題 | 為什麼是網頁 |
|------|--------------|
| 讓同事查詢資料 | 他們不會跑 Python |
| 做一個計算機給大家用 | 開瀏覽器就能用 |
| 展示作品集 | 要讓別人看到 |
| 多人協作編輯 | 需要即時同步 |

**但網頁不是萬能的**：

- 沒辦法存取本機檔案（除非使用者手動選）
- 離線就不能用（除非做 PWA）
- 效能有上限

如果你的需求是「處理本機檔案」，網頁可能不是好選擇。

---

## API 服務：給程式呼叫的後端

**適合的情況**：

- 不需要畫面
- 給其他程式（前端、App、其他服務）呼叫
- 需要持續運行
- 處理資料、商業邏輯

**例子**：

| 問題 | API 解法 |
|------|----------|
| 前端需要資料 | 後端 API 提供 |
| 接收 Webhook | API endpoint |
| 第三方整合 | 提供 API 給別人串 |
| 定時任務 | 跑在伺服器上的服務 |

```python
# FastAPI 範例
from fastapi import FastAPI

app = FastAPI()

@app.get("/users/{user_id}")
async def get_user(user_id: int):
    return {"id": user_id, "name": "Jeff"}
```

**API 服務需要部署和維護**。

如果只是自己用一次，不需要開 API——直接跑腳本就好。

---

## App：需要深度整合或離線使用

**適合的情況**：

- 需要存取系統功能（檔案、通知、背景執行）
- 需要離線使用
- 效能要求高
- 需要原生體驗

**例子**：

| 問題 | 為什麼是 App |
|------|--------------|
| 影片剪輯 | 效能要求高，要存取本機檔案 |
| 音樂播放器 | 背景播放、離線使用 |
| 筆記軟體 | 離線優先，本機儲存 |
| 遊戲 | 效能、系統整合 |

**但 App 的成本最高**：

- 要考慮跨平台（Windows、Mac、Linux、iOS、Android）
- 要處理安裝、更新
- 要過 App Store 審核（如果要上架）

如果網頁能解決，優先考慮網頁。

跨平台桌面應用的選擇，見：[跨平台桌面開發：Electron、Tauri、還是原生？](/Evernote/posts/cross-platform-desktop-overview)

---

## 常見的錯誤選擇

### 1. 把腳本做成網頁

「我想批次處理圖片」→ 做了一個上傳網站

**問題**：花三天做一個自己用一次的東西。

**正確做法**：寫個 Python 腳本，10 分鐘搞定。

### 2. 把擴充套件做成獨立網站

「我想在 YouTube 上加功能」→ 做了一個獨立網站讓使用者貼 URL

**問題**：每次都要開另一個網站，麻煩。

**正確做法**：做瀏覽器擴充套件，直接在 YouTube 頁面上跑。

### 3. 把網頁做成 App

「我想做一個待辦事項」→ 用 Electron 做桌面應用

**問題**：Electron 肥、開發成本高、要維護多平台。

**正確做法**：做 PWA，網頁就能加到桌面，還能離線用。

### 4. 把 API 做成全端應用

「我只是要提供資料給前端」→ 做了一個有登入、有管理後台的完整系統

**問題**：過度工程。

**正確做法**：先做純 API，之後有需要再加。

---

## 我的決策流程

```
有人要用嗎？
├── 只有我自己
│   ├── 改變現有軟體？ → 擴充套件
│   └── 其他 → 腳本
│
└── 給別人用
    ├── 需要畫面？
    │   ├── 需要系統整合/離線？ → App
    │   └── 不需要 → 網頁
    └── 不需要畫面 → API
```

**先選對形式，再選技術。**

---

## 各形式的技術選擇

選好形式之後，再來選技術：

| 形式 | 我的首選 | 備選 |
|------|----------|------|
| 腳本 | Python | Node.js、Bash |
| 瀏覽器擴充套件 | 原生 JS + manifest v3 | Plasmo 框架 |
| 編輯器擴充套件 | 看編輯器 | VS Code 用 TypeScript |
| 網頁 | Astro（靜態）/ Next.js（動態） | Vue、Svelte |
| API | FastAPI | Express、Hono |
| 桌面 App | Tauri | Electron |
| 手機 App | React Native | Flutter |

這些技術的詳細比較，見各自的文章。

---

## 相關文章

- [Python 套件管理的混亂現狀](/Evernote/posts/python-package-managers) — 寫腳本的環境
- [Tampermonkey：在任何網站注入程式碼](/Evernote/posts/tampermonkey-inject-code-into-any-website) — 最簡單的擴充套件
- [跨平台桌面開發](/Evernote/posts/cross-platform-desktop-overview) — App 的技術選擇
- [FastAPI：為什麼我從 Flask 轉過來](/Evernote/posts/fastapi-why-i-switched-from-flask) — API 的技術選擇

---

下次想做什麼東西之前，先問自己：

「這個問題，真的需要做成 XXX 嗎？」

選對形式，可以省下 80% 的時間。
