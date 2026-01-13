# 網站規格文件

## 1. SEO 優化

### 現況（已完成）

| 項目 | 狀態 | 說明 |
|------|------|------|
| `<title>` 和 `<meta description>` | ✅ 完成 | 基本 SEO |
| Open Graph 標籤 | ✅ 完成 | og:title, og:description, og:image |
| Twitter Card | ✅ 完成 | summary_large_image |
| Sitemap | ✅ 完成 | `@astrojs/sitemap` |
| robots.txt | ✅ 完成 | `public/robots.txt` |
| Canonical URL | ✅ 完成 | `<link rel="canonical">` |

### 待做

| 項目 | 說明 | 優先級 |
|------|------|--------|
| 預設 OG 圖片 | 需要建立 `public/og-default.png` | 高 |
| 結構化資料 | JSON-LD，讓 Google 更懂文章內容 | 低 |

### 實作方式

```astro
<!-- BaseLayout.astro head 內 -->
<meta property="og:title" content={title} />
<meta property="og:description" content={description} />
<meta property="og:type" content="article" />
<meta property="og:url" content={Astro.url} />
<meta property="og:image" content={ogImage || defaultOgImage} />

<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content={title} />
<meta name="twitter:description" content={description} />
```

Sitemap 安裝：

```bash
npx astro add sitemap
```

---

## 2. 開源模板化

### 目標

讓其他人能 fork 這個 repo，改幾個設定就能用。

### 需要抽離的設定

| 項目 | 目前位置 | 改成 |
|------|----------|------|
| 網站標題 | 散落各處硬編碼 | `src/config.ts` |
| 作者名稱 | 硬編碼 | `src/config.ts` |
| 網站描述 | 硬編碼 | `src/config.ts` |
| 社群連結 | `index.astro` 側邊欄 | `src/config.ts` |
| 主分類定義 | `index.astro` | `src/config.ts` |
| 隨機標語 | `BaseLayout.astro` | `src/config.ts` |
| 網站開始日期 | `index.astro` script | `src/config.ts` |
| GA / Analytics ID | 無 | `src/config.ts` |

### config.ts 結構

```typescript
export const SITE = {
  title: 'Jeffrey0117 技術筆記',
  subtitle: '沒有技術的技術部落格',
  description: '紀錄開發專案時學到的技術、踩過的坑、一些想法。',
  author: 'Jeffrey0117',
  startDate: '2026-01-13',

  // GitHub Pages 用
  site: 'https://jeffrey0117.github.io',
  base: '/Evernote',
};

export const SOCIAL = {
  github: 'https://github.com/Jeffrey0117',
  twitter: '', // 選填
  email: '', // 選填
};

export const CATEGORIES = {
  '全部': [],
  '技術': ['Electron', 'React', 'Python', ...],
  '觀念': ['開發觀念', '專案管理', ...],
  // ...
};

export const TAGLINES = [
  '我如果沒有寫文章，這裡就不會有東西',
  '當我來這裡的時候，關你屁事？',
  // ...
];
```

### 文件

需要寫一份 `README.md` 給使用者：

1. 如何 fork 和 clone
2. 如何修改 `src/config.ts`
3. 如何新增文章
4. 如何部署到 GitHub Pages
5. 如何自訂樣式

### 要清理的東西

- 刪除現有文章（或移到 `_examples` 資料夾）
- `project-guide.md` 要留著當範例還是刪掉？
- `.gitignore` 確認沒有奇怪的東西

---

## 3. 文章圖片規範（AI 生成用）

### 目標

讓 AI 生成文章時，能用穩定、乾淨的圖片來源，不會壞圖、不會侵權。

### 圖片來源優先順序

| 優先級 | 來源 | 說明 | 穩定性 |
|--------|------|------|--------|
| 1 | Unsplash | 免費高品質圖庫，URL 永久有效 | 極高 |
| 2 | Pexels | 免費圖庫，類似 Unsplash | 高 |
| 3 | 官方文件/GitHub | 工具的官方截圖或 logo | 高 |
| 4 | 自己截圖 | 需要人工操作 | - |
| 禁止 | Google 圖片搜尋 | 版權不明、URL 不穩定 | 低 |
| 禁止 | 隨便的網站圖片 | 可能下架、侵權 | 低 |

### Unsplash 使用規範

Unsplash 提供永久連結格式：

```
https://images.unsplash.com/photo-{PHOTO_ID}?w={WIDTH}&q={QUALITY}
```

**AI 生成文章時的標準格式：**

```markdown
![圖片描述](https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&q=80)
```

| 參數 | 建議值 | 說明 |
|------|--------|------|
| w | 800 | 內文圖寬度 |
| q | 80 | 品質（80 夠用且檔案小） |

**搜尋圖片：**
1. 去 [unsplash.com](https://unsplash.com) 搜尋關鍵字
2. 點進圖片，URL 會有 photo ID
3. 用上面的格式組成連結

### 圖片類型對應

| 文章類型 | 適合的圖片 | Unsplash 搜尋關鍵字 |
|----------|------------|---------------------|
| 技術教學 | 程式碼螢幕、鍵盤 | code, programming, laptop |
| 工具介紹 | 工具官方 logo 或截圖 | 用官方資源 |
| 觀念文 | 抽象、思考相關 | thinking, ideas, minimal |
| 專案心得 | 工作環境、筆記本 | workspace, notebook |

### 不需要圖片的情況

以下類型文章可以不放圖：

- 速查筆記（純指令表格）
- 短篇問題解決紀錄
- 程式碼為主的教學（程式碼區塊本身就是視覺）

### Markdown 格式

```markdown
<!-- 好的寫法：Unsplash 永久連結 -->
![程式碼編輯器](https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&q=80)

<!-- 好的寫法：官方資源 -->
![Astro Logo](https://astro.build/assets/press/astro-logo-dark.svg)

<!-- 壞的寫法：隨便的 URL -->
![圖片](https://some-random-site.com/image.jpg)
```

### 本地圖片（備用）

如果必須用本地圖片：

```
public/
  images/
    posts/
      文章-slug/
        screenshot.png
```

引用：
```markdown
![截圖](/Evernote/images/posts/文章-slug/screenshot.png)
```

### AI 生成文章的圖片指令

在請 AI 寫文章時，可以加上：

> 如果需要配圖，使用 Unsplash 圖片，格式為 `https://images.unsplash.com/photo-{ID}?w=800&q=80`。
> 不要用 Google 搜尋來的圖片。
> 如果是工具介紹，優先用官方 logo 或截圖。
> 純技術教學文可以不放圖。

---

## 優先順序建議

1. **SEO** - sitemap 和 og 標籤，影響分享和搜尋
2. **圖片規範** - 定好規則，之後寫文章才不會亂
3. **模板化** - 最後做，因為要等功能穩定

---

## 備註

這份文件是規劃用，實作時再細修。
