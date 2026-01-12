---
layout: ../../layouts/PostLayout.astro
title: 為什麼選 Astro 做技術筆記網站
date: 2026-01-13T06:00
description: 從 Vibe Coding 的混亂中誕生的整理需求，以及為什麼 Astro 是最適合的選擇
tags:
  - Astro
  - 專案心得
---

最近在瘋狂 Vibe Coding。

一個語音辨識桌面應用、一個 AI 聊天介面、一個自動化腳本... 專案開了一堆，學到的東西也不少。但問題來了：

**學到的東西都散落在各個專案的對話紀錄裡。**

想找「上次那個 Electron 自動重啟怎麼弄的」，要翻好幾個聊天記錄。想回顧「CSS 變數怎麼組織的」，又要去另一個專案找。

太累了。

## 整理的需求

我需要一個地方，把這些零散的技術筆記集中起來：

- 寫 Markdown 就好，不要搞複雜的編輯器
- 能按技術分類篩選（React、CSS、Electron...）
- 部署簡單，最好是靜態網站
- 長得要順眼，畢竟是自己要看的

於是，又多了一個新專案的點子。

## 為什麼是 Astro

看了幾個選項：

### Next.js

功能強大，但對於純內容網站來說太重了。我不需要 API routes、不需要 Server Components、不需要 ISR。只是想放一堆 Markdown 而已。

### Gatsby

曾經很紅的靜態網站生成器，但 GraphQL 那套對於簡單的部落格來說太複雜。而且生態系有點老化了。

### VitePress / Docusaurus

專門做文件網站的，但風格太「文件」了。我想要的是部落格的感覺，不是技術文件。

### Hugo / Jekyll

老牌靜態網站生成器，速度快。但模板語法不太習慣，而且想用現代的前端工具鏈。

### Astro

然後我發現了 Astro。

## Astro 的優勢

### 1. 內容優先

Astro 的設計理念就是「內容優先」。把 `.md` 檔案丟進 `src/pages` 目錄，自動就變成頁面。不用設定 routing、不用寫 loader、不用搞 GraphQL。

```
src/pages/posts/my-article.md → /posts/my-article
```

就這麼簡單。

### 2. 零 JavaScript（預設）

Astro 預設不會向瀏覽器發送任何 JavaScript。頁面載入超快，因為就只是 HTML + CSS。

對於技術筆記這種純閱讀的網站，根本不需要什麼互動功能。零 JS 正好。

### 3. 需要互動時也能加

雖然預設零 JS，但需要的時候可以加。像首頁的 tag 過濾功能，就是用一小段 JavaScript 做的。Astro 不會限制你。

### 4. 熟悉的語法

`.astro` 檔案的語法很像 JSX，前端工程師上手很快：

```astro
---
// 這裡寫 JavaScript
const posts = await Astro.glob('./posts/*.md');
---

<!-- 這裡寫 HTML -->
<ul>
  {posts.map(post => (
    <li>{post.frontmatter.title}</li>
  ))}
</ul>
```

### 5. 建置速度快

用 Vite 當底層，建置速度很快。改個檔案，HMR 瞬間更新。

## 對比表

| 框架 | 學習曲線 | 適合場景 | JS 大小 |
|------|----------|----------|---------|
| Astro | 低 | 內容網站、部落格 | 0 KB（預設） |
| Next.js | 中 | 全端應用、複雜網站 | 較大 |
| Gatsby | 高 | 內容網站（但複雜） | 中等 |
| VitePress | 低 | 技術文件 | 小 |
| Hugo | 中 | 部落格、文件 | 0 KB |

## 實際體驗

用了幾天，感想是：

1. **設定超少**：`npm create astro@latest`，選個模板就能開始寫
2. **Markdown 體驗好**：frontmatter 定義 metadata，內容直接寫，支援 GFM 語法
3. **樣式自由**：想用 CSS、Tailwind、Sass 都可以，不強迫你用特定方案
4. **部署簡單**：建置出來就是純靜態檔案，丟 GitHub Pages、Vercel、Netlify 都行

## 小結

對於「想整理技術筆記」這個需求，Astro 剛剛好：

- 不過度設計
- 不強迫學新概念
- 內容優先，寫 Markdown 就好
- 建置快、載入快

有時候，最適合的工具不是功能最多的，而是最符合需求的。

```bash
npm create astro@latest my-notes
```

然後開始寫筆記。就這樣。
