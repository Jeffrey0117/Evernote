# vibe.notes

一個乾淨簡約的 Astro 部落格，用於記錄 Vibe Coding 過程中的技術知識。

## 特色

- 🎨 溫暖米白灰色調，工程師筆記風格
- 📝 Markdown 內容管理
- ⚡ Astro 靜態網站，載入極快
- 🔤 精選字型：IBM Plex Mono + Noto Sans TC

## 快速開始

```bash
# 安裝依賴
npm install

# 開發模式
npm run dev

# 建置
npm run build

# 預覽建置結果
npm run preview
```

## 新增文章

在 `src/pages/posts/` 目錄下新增 `.md` 檔案：

```markdown
---
layout: ../../layouts/PostLayout.astro
title: 文章標題
date: 2025-01-12
description: 文章描述
tags:
  - 標籤1
  - 標籤2
---

文章內容...
```

## 專案結構

```
src/
├── layouts/
│   ├── BaseLayout.astro    # 基礎版型
│   └── PostLayout.astro    # 文章版型
├── pages/
│   ├── index.astro         # 首頁（文章列表）
│   ├── about.astro         # 關於頁面
│   └── posts/              # Markdown 文章
├── styles/
│   └── global.css          # 全域樣式
public/
└── favicon.svg             # 網站圖示
```

## 自訂樣式

編輯 `src/styles/global.css` 中的 CSS 變數：

```css
:root {
  --bg-primary: #F9F7F4;      /* 主背景色 */
  --text-primary: #2C2C2C;     /* 主文字色 */
  --accent: #9C8B7A;           /* 強調色 */
}
```

## 部署

建置後的靜態檔案在 `dist/` 目錄，可部署到：

- Vercel
- Netlify
- GitHub Pages
- Cloudflare Pages

---

Built with ♥ and Astro
