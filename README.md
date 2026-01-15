<div align="center">

# Evernote

一個用 Astro 建的技術筆記部落格

[![Astro](https://img.shields.io/badge/Astro-FF5D01?logo=astro&logoColor=white)](https://astro.build)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white)](https://typescriptlang.org)

[線上預覽](https://jeffrey0117.github.io/Evernote/)

</div>

---

## 這專案有什麼

- 文章分類過濾（技術 / 觀念 / 專案 / 工具）
- 分頁
- Pagefind 全站搜尋
- RSS feed
- GitHub Actions 自動部署
- **AI 寫作工具** — 用 Claude + Gemini 分工寫技術筆記

## AI 寫作工具

這套工具讓你用 AI 高效產出技術筆記，核心概念是 **分工省 token**：

| 角色 | 任務 | 成本 |
|------|------|------|
| Claude | 從對話抽出原料（背景、踩坑、解法） | ~200 tokens |
| Gemini | 讀完整規範，寫出文章 | 免費 |

Claude 有對話 context 所以抽原料很快；Gemini 讀長文免費所以負責寫文章。

### 三個工具

```
C:\DEV\Evernote\
├── find-topics.bat    # 從 git commits 找新題材
├── write-article.bat  # 叫 Gemini 寫文章
└── move-articles.bat  # 搬文章到 posts/
```

**找題材：**
```bash
find-topics "C:\path\to\your\repo"
# Gemini 會看 commits 和現有文章，建議不重複的新題材
```

**寫文章：**
```bash
write-article "React useEffect 清理函數踩坑"
# Gemini 讀 project-guide.md 規範，產出符合風格的文章
```

**搬文章：**
```bash
move-articles
# 把 cloudpipe 裡寫好的 .md 搬到 posts/
```

### 相關規範檔

| 檔案 | 用途 |
|------|------|
| `src/pages/posts/project-guide.md` | 完整寫作規範（給 Gemini 讀） |
| `src/pages/posts/context-spec.md` | 原料清單（給 Claude 讀） |

### 工作流程

1. 開發專案時用 Claude 解決問題
2. 想寫筆記時，貼 `context-spec.md` 給 Claude
3. Claude 輸出原料清單
4. 執行 `write-article` 把原料丟給 Gemini
5. 執行 `move-articles` 搬到 posts/
6. 完成

## 技術棧

```
Astro          靜態網站框架，載入極快
Pagefind       全站搜尋
@astrojs/rss   RSS feed 生成
@astrojs/sitemap   Sitemap 生成
```

## 快速開始

```bash
# Clone
git clone https://github.com/Jeffrey0117/Evernote.git
cd Evernote

# 安裝
npm install

# 開發
npm run dev

# 建置（含搜尋索引）
npm run build

# 預覽
npm run preview
```

## 專案結構

```
src/
├── layouts/
│   ├── BaseLayout.astro      # 基礎版型（SEO、搜尋）
│   └── PostLayout.astro      # 文章版型
├── pages/
│   ├── index.astro           # 首頁（文章列表、分頁、過濾）
│   ├── about.astro           # 關於
│   ├── rss.xml.ts            # RSS feed
│   └── posts/                # Markdown 文章
├── styles/
│   └── global.css            # 全域樣式（CSS 變數）
public/
├── favicon.svg
├── robots.txt
└── og-default.png            # 預設 OG 圖片
```

## 新增文章

在 `src/pages/posts/` 新增 `.md` 檔：

```markdown
---
layout: ../../layouts/PostLayout.astro
title: 文章標題
date: 2026-01-13T12:00
description: 一句話描述
tags:
  - Electron
  - React
pinned: false
---

文章內容...
```

### Frontmatter 參數

| 參數 | 必填 | 說明 |
|------|------|------|
| `layout` | ✓ | 固定為 `../../layouts/PostLayout.astro` |
| `title` | ✓ | 文章標題 |
| `date` | ✓ | 發布日期時間 `YYYY-MM-DDTHH:mm` |
| `description` | ✓ | 文章描述（顯示在列表） |
| `tags` | ✓ | 標籤陣列 |
| `pinned` |  | 是否置頂，預設 `false` |

### 分類對應

文章會根據 tags 自動歸類：

| 分類 | 標籤 |
|------|------|
| 技術 | Electron, React, Python, Node.js, CSS, TypeScript, Astro... |
| 觀念 | 開發觀念, 專案管理, 寫作, Vibe Coding... |
| 專案 | 專案心得, 專案文件 |
| 工具 | CLI, VSCode, 開發工具, DX, Windows... |

## 自訂樣式

編輯 `src/styles/global.css`：

```css
:root {
  --bg-primary: #F9F7F4;      /* 背景 */
  --text-primary: #2C2C2C;    /* 文字 */
  --accent: #9C8B7A;          /* 強調色 */
  --font-mono: 'IBM Plex Mono', monospace;
  --font-sans: 'Noto Sans TC', sans-serif;
}
```

## 部署

已設定 GitHub Actions 自動部署到 GitHub Pages。

Push 到 `main` 分支即自動部署。

手動部署到其他平台：

```bash
npm run build
# dist/ 目錄即為靜態檔案
```

支援：Vercel、Netlify、Cloudflare Pages、任何靜態空間

---

<div align="center">

Built with [Astro](https://astro.build)

</div>
