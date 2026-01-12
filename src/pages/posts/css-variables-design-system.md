---
layout: ../../layouts/PostLayout.astro
title: 現代 CSS 變數系統設計
date: 2025-01-08T14:00
description: 如何使用 CSS Custom Properties 建立可維護的設計系統。
tags:
  - CSS
  - 設計系統
---

CSS 變數（Custom Properties）是建立一致設計系統的基礎。

## 定義變數

在 `:root` 中定義全域變數：

```css
:root {
  --bg-primary: #F9F7F4;
  --text-primary: #2C2C2C;
  --space-md: 1rem;
}
```

## 命名規則

採用語意化命名，而非顏色名稱：

```css
/* ✓ 好的命名 */
--text-primary: #2C2C2C;
--bg-secondary: #F3F0EB;

/* ✗ 避免 */
--dark-gray: #2C2C2C;
--light-beige: #F3F0EB;
```

## 實際應用

```css
body {
  background: var(--bg-primary);
  color: var(--text-primary);
  padding: var(--space-md);
}
```

使用 CSS 變數可以讓主題切換變得簡單，只需要重新定義變數值即可。
