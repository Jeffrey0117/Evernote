---
layout: ../../layouts/PostLayout.astro
title: 用 Astro 建立技術筆記網站
date: 2025-01-12T10:00
description: 記錄使用 Astro 框架建立部落格的過程，包含 Markdown 內容管理和簡約風格設計。
tags:
  - Astro
  - 部落格
  - 前端
---

Astro 是一個以內容為導向的靜態網站框架，特別適合建立部落格、文件網站這類內容網站。

## 為什麼選擇 Astro

Astro 的優勢在於它的「零 JavaScript」理念。預設情況下，Astro 不會向瀏覽器發送任何 JavaScript，讓頁面載入速度極快。

```bash
# 建立新專案
npm create astro@latest my-blog
```

## Markdown 支援

Astro 原生支援 Markdown，只要把 `.md` 檔案放在 `src/pages` 目錄下，就會自動生成對應的頁面。

每篇文章的開頭可以使用 frontmatter 定義 metadata：

```markdown
---
title: 文章標題
date: 2025-01-12
tags:
  - Astro
---
```

## 簡約設計

這個筆記網站採用米白色調，強調閱讀體驗。字型選用 IBM Plex Mono 作為等寬字體，搭配 Noto Sans TC 作為內文字體。

關鍵是保持克制，不過度設計。
