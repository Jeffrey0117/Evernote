---
layout: ../../layouts/PostLayout.astro
title: 白牌是什麼？讓平台退到幕後的品牌魔法
date: 2026-01-13T12:17
description: 從 Shopify 到線上課程平台，聊聊 SaaS 的白牌功能怎麼讓租戶擁有自己的品牌形象
tags:
  - Multi-Tenant
  - React
  - CSS Variables
  - 白牌
---

講到白牌，不是路邊攔車那種白牌喔。

台灣人聽到「白牌」，第一反應大概是白牌計程車——沒有計程車牌照，但私底下載客的車。

![透過 LINE 群組叫白牌車的對話截圖](https://shuj.shu.edu.tw/wp-content/uploads/2021/05/S__1515663.jpg)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>在台灣，白牌是遊走灰色地帶的代名詞。在軟體圈，白牌是讓客戶站上舞台的魔法。</small></p>

但在軟體世界裡，白牌（White Label）是完全不同的東西。

它指的是：**你做的產品，可以貼上別人的品牌**。

---

## 為什麼要做白牌

想像一下這個情境。

你開了一間 SaaS 公司，做了一套線上課程平台。

有個講師來找你：「我想用你的系統開課，但我不想讓學生看到你的 Logo。我要用我自己的品牌。」

這就是白牌需求。

講師不想讓學生知道他用的是哪家平台，他要學生覺得：「這是我的網站」。

最經典的例子是 [Shopify](https://www.shopify.com/)。

你有沒有發現，用 Shopify 開的網店，看起來一點都不像 Shopify？

每家店都有自己的 Logo、自己的配色、自己的品牌風格。

如果不特別去查，你根本不知道這家店是架在 Shopify 上。

![Shopify 商店範例：家居品牌](https://cdn.shopify.com/shopifycloud/brochure/assets/examples/image-tabs/home-and-decor/poly-and-bark-large-a8df2c510b6e18b359caba00b02f7a38a86bdc44a955a0cc01ff965a919ecf9c.jpg)

![Shopify 商店範例：服飾品牌](https://cdn.shopify.com/shopifycloud/brochure/assets/examples/image-tabs/clothing-and-fashion/negative-underwear-large-aa1b6de0850a8a1af24c3f24f9b6d2a3b8a836be74b3debcdbcec1bfe24c944d.jpg)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>這兩個網站都是用 Shopify 架的。你看得出來嗎？</small></p>

**這就是白牌的魔法——平台退到幕後，讓商家站到台前。**

---

## 先聊聊 Multi-Tenant

在講白牌怎麼做之前，要先解釋一個概念：Multi-Tenant（多租戶）。

如果你沒看過這系列的前幾篇，簡單說就是：

**一套系統，服務 N 個客戶。**

傳統做法是每個客戶開一台主機、一個資料庫，但那樣維護成本會爆炸。

Multi-Tenant 的做法是大家共用同一套系統，但資料彼此隔離。

每個客戶叫做一個「租戶（Tenant）」。

租戶 A 看不到租戶 B 的資料，就像住在同一棟大樓的不同住戶，各自有獨立的空間。

![Multi-Tenant 就像公寓大樓，大家共用基礎設施但各自獨立](https://www.gooddata.com/img/blog/_2000xauto/tenants_building.png.webp)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>房東只有一個，但每戶都覺得這是自己的家。</small></p>

白牌功能，就是讓每個租戶可以自訂自己的「門面」——Logo、顏色、網站名稱。

雖然大家都住在同一棟大樓，但每戶的裝潢可以完全不同。

---

## 白牌要自訂什麼

租戶最常要求的，大概是這幾樣：

**Logo** — 導覽列左上角那個圖，要換成自己的

**網站名稱** — 瀏覽器 tab 上的標題，要顯示自己的品牌名

**Favicon** — 瀏覽器 tab 上的小圖示，那個 16x16 的小東西

**品牌色** — 按鈕、連結、hover 效果，全部要換成自己的顏色

**法律文件** — 隱私政策、服務條款，每家店的規定不一樣

有些進階的還會要求自訂網域，讓網址從 `platform.com/my-brand` 變成 `courses.my-brand.com`。

這篇先聚焦在前四個，自訂網域比較複雜，之後另外寫。

---

## 資料表設計

知道要存什麼之後，就是開一張表來放這些設定。

```sql
CREATE TABLE site_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),

  -- 品牌基本資訊
  site_name TEXT DEFAULT '',
  logo_url TEXT DEFAULT '',
  favicon_url TEXT DEFAULT '',

  -- 顏色
  primary_color TEXT DEFAULT NULL,   -- 例如 "#3B82F6"
  accent_color TEXT DEFAULT NULL,

  UNIQUE(tenant_id)
);
```

幾個設計重點。

每個 tenant 只有一筆設定，用 `UNIQUE(tenant_id)` 保證一對一關係。

每個欄位都給預設值。

這很重要，不然前端會一直撞到 `null`。

```tsx
// 沒給預設值會這樣炸
settings.site_name.length  // Cannot read properties of null
```

---

## 顏色跟著租戶走

這是最有趣的部分。

我想讓每個租戶可以自訂主色調，但又不想為每個租戶打包一份 CSS。

解法是 **CSS 變數（CSS Custom Properties）**。

先講原理。

CSS 變數就像是在 CSS 裡面開一個「全域變數」，長這樣：

```css
:root {
  --primary: 221 83% 53%;   /* 藍色 */
}
```

然後整個網站的元件都引用這個變數：

```css
.button {
  background-color: hsl(var(--primary));
}
```

**當你改變 `--primary` 的值，所有引用它的元件顏色都會跟著變。**

這就是白牌的關鍵技術。

不用為每個租戶寫一份 CSS，只要動態改變這幾個變數的值就好。

在 [Tailwind CSS](https://tailwindcss.com/) 裡面，`bg-primary`、`text-accent` 這些 class 底層都是用 CSS 變數。

所以只要改變 `:root` 上的變數值，整個網站的配色就會跟著換。

實作上，我寫了一個元件來動態注入顏色：

```tsx
// TenantTheme.tsx
export function TenantTheme() {
  const { settings } = useSiteSettings();

  useEffect(() => {
    if (!settings?.primary_color) return;

    const root = document.documentElement;
    const hsl = hexToHSL(settings.primary_color);
    root.style.setProperty('--primary', hsl);

    // 離開時恢復預設
    return () => {
      root.style.removeProperty('--primary');
    };
  }, [settings?.primary_color]);

  return null;
}
```

這個元件不渲染任何東西，純粹是 side effect。

當租戶設定了 `primary_color`，就把它轉成 HSL 格式塞進 `:root`。

按鈕、連結、hover 效果，全部都會自動套用新顏色。

---

## Favicon 動態替換

Favicon 是瀏覽器 tab 上的小圖示。

![Favicon 就是瀏覽器分頁標籤上的那個小圖示](https://www.w3schools.com/html/img_favicon.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>16x16 像素的小東西，卻是品牌識別的重要一環。</small></p>

這個比較麻煩，因為 favicon 通常是在 HTML `<head>` 裡面用 `<link>` 標籤指定的，是靜態的。

解法是用 JavaScript 動態修改 `<head>` 裡面的內容：

```tsx
// DynamicFavicon.tsx
export function DynamicFavicon() {
  const { settings } = useSiteSettings();

  useEffect(() => {
    if (!settings?.favicon_url) return;

    let link = document.querySelector("link[rel~='icon']");

    if (!link) {
      link = document.createElement("link");
      link.rel = "icon";
      document.head.appendChild(link);
    }

    link.href = settings.favicon_url;
  }, [settings?.favicon_url]);

  return null;
}
```

當 `settings.favicon_url` 變化時，瀏覽器 tab 上的圖示就會跟著換。

---

## Logo 替換

Logo 相對單純，直接在導覽列判斷就好：

```tsx
{settings?.logo_url ? (
  <img src={settings.logo_url} alt={settings.site_name} />
) : (
  <DefaultIcon />
)}
```

有 Logo 就顯示圖片，沒有就顯示預設的 icon。

---

## 用 Context 讓設定到處都能用

這些設定會在很多地方用到——導覽列要用、頁尾要用、SEO 設定要用。

我用 [React](https://react.dev/) Context 把設定包起來，這樣任何元件都可以方便取用：

```tsx
const { settings } = useSiteSettings();
```

不用每個元件都自己去撈資料庫。

---

## 踩過的坑

有個坑我踩過。

當你事後新增欄位，如果沒設定 DEFAULT 值，現有的資料就會是 NULL。

然後前端就會炸。

解法是資料庫和前端都要防禦：

```sql
-- Migration 時一定要給預設值
ALTER TABLE site_settings
ADD COLUMN IF NOT EXISTS favicon_url TEXT DEFAULT '';

-- 把現有的 NULL 改掉
UPDATE site_settings SET favicon_url = '' WHERE favicon_url IS NULL;
```

```tsx
// 前端也做防禦
const siteName = settings?.site_name || '預設名稱';
```

兩邊都做，比較保險。

---

## 進階：自訂網域

有些租戶會問：「我可以用自己的網域嗎？」

他們想要 `courses.mycompany.com` 而不是 `platform.com/mycompany`。

這叫自訂網域（Custom Domain），概念上要做幾件事：

1. 租戶把自己的網域 CNAME 指向你的平台
2. 自動簽發 SSL 證書（用 [Let's Encrypt](https://letsencrypt.org/) 或 [Cloudflare](https://www.cloudflare.com/)）
3. Middleware 根據 Host header 判斷是哪個租戶

這個功能我還沒做，主要是 SSL 證書管理比較麻煩。

等有需求再說吧。

---

## 系列回顧

寫到這裡，Multi-Tenant 系列就告一段落了。

回顧一下這五篇講了什麼：

**[第一篇：Multi-Tenant 是什麼？](/posts/multi-tenant-saas-architecture)** — 為什麼要做多租戶架構，三種隔離策略怎麼選。

**第二篇：Supabase RLS 實戰** — 用 RLS 讓資料庫自動過濾 `tenant_id`，程式碼忘記加 WHERE 也不會漏資料。

**第三篇：Next.js 動態路由** — 用 `app/[slug]/` 讓每個租戶有自己的網址。

**第四篇：多租戶權限設計** — 當用戶同時屬於多個租戶時，權限怎麼處理。

**第五篇：白牌功能（這篇）** — 讓平台退到幕後，每個租戶有自己的品牌長相。

---

回頭看，Multi-Tenant 讓我可以用一套程式碼服務 N 個客戶。

修 bug 或加功能，所有客戶同時生效。

新增一個租戶只是在資料庫插一筆資料，不是開一台機器。

當然也有代價——每個功能都要考慮「這是哪個租戶的？」，複雜度蹭蹭往上漲。

![Notion 的 Teamspace 功能就是 Multi-Tenant 的實際應用](https://images.ctfassets.net/spoqsaf9291f/1y8zOHVAPsvoKhcfV2ZuFq/d53ca7ae217a0ff77576ec2a8038224f/teamspaces-best-practice__4_.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>你用的 Notion、Slack、Shopify，背後都是同一套邏輯。</small></p>

但對我來說，能用同一套系統服務幾十個講師，比幫每個講師維護一套獨立系統划算太多了。

[Notion](https://www.notion.so/)、[Slack](https://slack.com/)、[Shopify](https://www.shopify.com/) 都是這樣做的。
