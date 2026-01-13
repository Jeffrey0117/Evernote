---
layout: ../../layouts/PostLayout.astro
title: 讓租戶有自己的品牌長相
date: 2026-01-13T12:17
description: Multi-Tenant 系列完結篇，從資料表設計到動態 CSS 變數，手把手教你實作白牌功能
tags:
  - Multi-Tenant
  - React
  - CSS Variables
  - 白牌
---

做到這一步，系統已經有了完整的多租戶架構。

RLS 擋住跨租戶查詢，動態路由讓每個租戶有自己的網址，權限系統處理好「同一個人在不同租戶有不同身份」的情境。

但租戶們還不滿足。

「我想要自己的 Logo。」

「網站顏色可以換成我們品牌的顏色嗎？」

「瀏覽器 tab 上那個小圖示，可以換成我的嗎？」

這些需求有個統稱——**白牌（White Label）**。

意思是，平台本身退到幕後，讓每個租戶看起來像是在用自己專屬的系統。

---

## site_settings 表設計

第一步，先建一張表存放設定。

我一開始只想放 `logo_url`，後來發現需要的欄位越來越多。
現在長這樣：

```sql
CREATE TABLE site_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

  -- 品牌
  site_name TEXT DEFAULT '',
  site_name_style TEXT DEFAULT 'gradient',  -- gradient, primary, dark, muted
  site_description TEXT DEFAULT '',
  logo_url TEXT DEFAULT '',
  favicon_url TEXT DEFAULT '',
  og_image TEXT DEFAULT '',

  -- 顏色（進階功能）
  primary_color TEXT DEFAULT NULL,  -- 例如 "#3B82F6"
  accent_color TEXT DEFAULT NULL,

  -- 聯絡資訊
  contact_email TEXT DEFAULT '',
  contact_phone TEXT DEFAULT '',
  contact_address TEXT DEFAULT '',

  -- 社群連結
  facebook_url TEXT DEFAULT '',
  instagram_url TEXT DEFAULT '',
  twitter_url TEXT DEFAULT '',

  -- SEO
  meta_description TEXT DEFAULT '',
  meta_keywords TEXT DEFAULT '',

  -- 法律文件
  privacy_policy TEXT DEFAULT '',
  terms_of_service TEXT DEFAULT '',
  refund_policy TEXT DEFAULT '',
  show_privacy_policy BOOLEAN DEFAULT true,
  show_terms_of_service BOOLEAN DEFAULT true,
  show_refund_policy BOOLEAN DEFAULT true,

  -- 首頁版塊
  home_sections JSONB DEFAULT '[]',
  hide_hero_section BOOLEAN DEFAULT false,
  hide_cta_section BOOLEAN DEFAULT false,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(tenant_id)
);

-- 別忘了 RLS
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read site settings" ON site_settings
  FOR SELECT USING (true);

CREATE POLICY "Tenant admins can update" ON site_settings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM tenants t
      WHERE t.id = site_settings.tenant_id
      AND t.owner_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM tenant_members tm
      WHERE tm.tenant_id = site_settings.tenant_id
      AND tm.user_id = auth.uid()
      AND tm.role = 'admin'
    )
  );
```

幾個設計決策。

每個 tenant 只有一筆 site_settings，用 `UNIQUE(tenant_id)` 保證一對一關係。

SELECT 是公開的，因為訪客也要能看到 Logo 和網站名稱。
但寫入受限，只有租戶的 owner 或 admin 可以改設定。

每個欄位都給預設值，新租戶建立後不會是 NULL，這點很重要，後面會講到。

---

## 用 Context 讓設定到處都能用

設定存進資料庫後，前端要能方便取用。

我用 [React](https://react.dev/) Context 把設定包起來：

```tsx
// src/contexts/SiteSettingsContext.tsx
"use client";

import { createContext, useContext, ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useTenant } from './TenantContext';

interface SiteSettings {
  id: string;
  tenant_id: string;
  site_name: string;
  site_name_style: string | null;
  logo_url: string | null;
  favicon_url: string | null;
  primary_color: string | null;
  accent_color: string | null;
  // ... 其他欄位
}

interface SiteSettingsContextType {
  settings: SiteSettings | null;
  isLoading: boolean;
}

const SiteSettingsContext = createContext<SiteSettingsContextType | undefined>(undefined);

export const SiteSettingsProvider = ({ children }: { children: ReactNode }) => {
  const { tenant } = useTenant();

  const { data: settings, isLoading } = useQuery({
    queryKey: ['site-settings', tenant?.id],
    queryFn: async () => {
      if (!tenant) return null;

      const { data, error } = await supabase
        .from('site_settings')
        .select('*')
        .eq('tenant_id', tenant.id)
        .maybeSingle();

      if (error) throw error;
      return data as SiteSettings;
    },
    enabled: !!tenant,
    staleTime: 1000 * 60 * 5, // 5分鐘快取
  });

  return (
    <SiteSettingsContext.Provider value={{ settings: settings || null, isLoading }}>
      {children}
    </SiteSettingsContext.Provider>
  );
};

export const useSiteSettings = () => {
  const context = useContext(SiteSettingsContext);
  if (context === undefined) {
    throw new Error('useSiteSettings must be used within SiteSettingsProvider');
  }
  return context;
};
```

然後在 Layout 裡面使用：

```tsx
// app/[slug]/layout.tsx
"use client";

import { TenantProvider } from '@/contexts/TenantContext';
import { SiteSettingsProvider } from '@/contexts/SiteSettingsContext';
import { DynamicFavicon } from '@/components/DynamicFavicon';

export default function TenantLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ slug: string }>;
}) {
  const { slug } = use(params);

  return (
    <TenantProvider initialSlug={slug}>
      <SiteSettingsProvider>
        <DynamicFavicon />
        {children}
      </SiteSettingsProvider>
    </TenantProvider>
  );
}
```

這樣在任何元件裡面都可以用 `useSiteSettings()` 取得設定。

---

## 顏色跟著租戶走

這是最有趣的部分。

我想讓每個租戶可以自訂主色調，但又不想為每個租戶打包一份 CSS。

解法是 **[CSS 變數（CSS Custom Properties）](https://developer.mozilla.org/en-US/docs/Web/CSS/--*)**。

先在 globals.css 定義預設值：

```css
@layer base {
  :root {
    --primary: 221 83% 53%;           /* 預設藍色 */
    --primary-foreground: 0 0% 100%;
    --accent: 199 89% 48%;
    --accent-foreground: 0 0% 100%;
    /* ... */
  }
}
```

然後寫一個元件，根據租戶設定覆蓋這些變數：

```tsx
// src/components/TenantTheme.tsx
"use client";

import { useEffect } from "react";
import { useSiteSettings } from "@/contexts/SiteSettingsContext";

// 把 HEX 轉成 HSL 格式（CSS 變數用的格式）
function hexToHSL(hex: string): string {
  // 移除 # 號
  hex = hex.replace('#', '');

  const r = parseInt(hex.slice(0, 2), 16) / 255;
  const g = parseInt(hex.slice(2, 4), 16) / 255;
  const b = parseInt(hex.slice(4, 6), 16) / 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0, s = 0, l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
      case g: h = ((b - r) / d + 2) / 6; break;
      case b: h = ((r - g) / d + 4) / 6; break;
    }
  }

  // 回傳 "221 83% 53%" 這種格式
  return `${Math.round(h * 360)} ${Math.round(s * 100)}% ${Math.round(l * 100)}%`;
}

export function TenantTheme() {
  const { settings } = useSiteSettings();

  useEffect(() => {
    if (!settings) return;

    const root = document.documentElement;

    // 如果有自訂主色調
    if (settings.primary_color) {
      const hsl = hexToHSL(settings.primary_color);
      root.style.setProperty('--primary', hsl);
      root.style.setProperty('--ring', hsl);
    }

    // 如果有自訂強調色
    if (settings.accent_color) {
      const hsl = hexToHSL(settings.accent_color);
      root.style.setProperty('--accent', hsl);
    }

    // Cleanup：離開時恢復預設
    return () => {
      root.style.removeProperty('--primary');
      root.style.removeProperty('--ring');
      root.style.removeProperty('--accent');
    };
  }, [settings?.primary_color, settings?.accent_color]);

  return null;
}
```

把這個元件加到 Layout 裡面，整個網站的顏色就會跟著租戶設定變化。

按鈕、連結、hover 效果，全部都會自動套用新顏色。
因為它們本來就是用 `bg-primary`、`text-accent` 這類 [Tailwind](https://tailwindcss.com/) class。

---

## 每個租戶有自己的小圖示

Favicon 是瀏覽器 tab 上的小圖示。

這個比較麻煩，因為 favicon 通常是在 HTML `<head>` 裡面用 `<link>` 標籤指定的，是靜態的。

我的解法是用 JavaScript 動態修改：

```tsx
// src/components/DynamicFavicon.tsx
"use client";

import { useEffect } from "react";
import { useSiteSettings } from "@/contexts/SiteSettingsContext";

export function DynamicFavicon() {
  const { settings } = useSiteSettings();

  useEffect(() => {
    if (!settings?.favicon_url) return;

    // 找到現有的 favicon link，或建立新的
    let link = document.querySelector("link[rel~='icon']") as HTMLLinkElement | null;

    if (!link) {
      link = document.createElement("link");
      link.rel = "icon";
      document.head.appendChild(link);
    }

    link.href = settings.favicon_url;

    // 順便更新 apple-touch-icon（iOS 加到主畫面時用的圖示）
    let appleLink = document.querySelector("link[rel='apple-touch-icon']") as HTMLLinkElement | null;
    if (!appleLink) {
      appleLink = document.createElement("link");
      appleLink.rel = "apple-touch-icon";
      document.head.appendChild(appleLink);
    }
    appleLink.href = settings.favicon_url;

  }, [settings?.favicon_url]);

  return null;
}
```

這個元件不渲染任何東西，純粹是 side effect。

當 `settings.favicon_url` 變化時，瀏覽器 tab 上的圖示就會跟著換。

---

## Logo 替換

Logo 相對單純，直接在 Navigation 元件裡面判斷：

```tsx
// Navigation.tsx（節錄）
const { settings } = useSiteSettings();

return (
  <Link href={`/${slug}`} className="flex items-center gap-2 font-bold text-xl">
    {settings?.logo_url ? (
      <img
        src={settings.logo_url}
        alt={settings.site_name}
        className="h-12 w-auto object-contain"
      />
    ) : (
      <BookOpen className="h-8 w-8 text-primary" />
    )}

    <span className={
      settings?.site_name_style === 'primary' ? 'text-primary' :
      settings?.site_name_style === 'dark' ? 'text-foreground' :
      settings?.site_name_style === 'muted' ? 'text-muted-foreground' :
      'bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent'
    }>
      {settings?.site_name || 'Classroo'}
    </span>
  </Link>
);
```

有 Logo 就顯示圖片，沒有就顯示預設的 icon。

網站名稱的樣式也可以選——漸層、主色調、深色、柔和色。

---

## 踩坑：現有租戶怎麼辦

這個坑我踩過。

當你新增欄位時，如果沒設定 DEFAULT 值，現有的資料就會是 NULL。
然後前端就會出問題：

```tsx
// 這會炸
settings.site_name.length  // Cannot read properties of null
```

解法是 Migration 時一定要給預設值：

```sql
-- 新增 favicon_url 欄位
ALTER TABLE site_settings
ADD COLUMN IF NOT EXISTS favicon_url TEXT DEFAULT '';

-- 把現有的 NULL 值改成空字串
UPDATE site_settings
SET favicon_url = ''
WHERE favicon_url IS NULL;
```

或者更保險的寫法，在 TypeScript 那邊加上防禦：

```tsx
const siteName = settings?.site_name || 'Classroo';
const faviconUrl = settings?.favicon_url ?? '';
```

我的習慣是兩邊都做——資料庫層面保證不會有 NULL，前端層面也做防禦。

---

## 後台設定介面

最後要給租戶一個介面來設定這些東西。

```tsx
// app/[slug]/admin/settings/page.tsx（節錄）
<Card>
  <CardHeader>
    <CardTitle>品牌設定</CardTitle>
    <CardDescription>
      自訂網站名稱和 Logo
    </CardDescription>
  </CardHeader>
  <CardContent className="space-y-4">
    <div className="space-y-2">
      <Label htmlFor="site_name">網站名稱</Label>
      <Input
        id="site_name"
        value={formData.site_name}
        onChange={(e) => handleChange('site_name', e.target.value)}
        placeholder="我的課程網站"
      />
    </div>

    <div className="space-y-2">
      <Label htmlFor="logo_url">Logo 網址</Label>
      <Input
        id="logo_url"
        value={formData.logo_url}
        onChange={(e) => handleChange('logo_url', e.target.value)}
        placeholder="https://example.com/logo.png"
      />
      <p className="text-sm text-muted-foreground">
        建議尺寸：高度 48px，PNG 或 SVG 格式
      </p>
    </div>

    <div className="space-y-2">
      <Label htmlFor="favicon_url">Favicon 網址</Label>
      <Input
        id="favicon_url"
        value={formData.favicon_url}
        onChange={(e) => handleChange('favicon_url', e.target.value)}
        placeholder="https://example.com/favicon.ico"
      />
      <p className="text-sm text-muted-foreground">
        瀏覽器分頁上的小圖示，建議 32x32 或 64x64 像素
      </p>
    </div>
  </CardContent>
</Card>
```

這裡我只是用簡單的 URL 輸入。
更完整的做法是加上圖片上傳功能，讓租戶可以直接拖拉圖片。

---

## 自訂網域

有些租戶會問：「我可以用自己的網域嗎？我想要 `courses.mycompany.com` 而不是 `classroo.com/mycompany`。」

這就是自訂網域（Custom Domain）功能。

概念上要做幾件事。

在 tenants 表加一個 `custom_domain` 欄位。
租戶把自己的網域 CNAME 指向你的平台。
用 [Let's Encrypt](https://letsencrypt.org/) 或 [Cloudflare](https://www.cloudflare.com/) 自動簽發 SSL 證書。
Middleware 要能根據 Host header 判斷是哪個租戶。

```typescript
// middleware.ts（概念）
export function middleware(request: NextRequest) {
  const host = request.headers.get('host');

  // 如果是自訂網域
  if (host && !host.includes('classroo.com')) {
    const tenant = await getTenantByCustomDomain(host);
    if (tenant) {
      // Rewrite 到對應的 slug 路徑
      return NextResponse.rewrite(
        new URL(`/${tenant.slug}${request.nextUrl.pathname}`, request.url)
      );
    }
  }

  return NextResponse.next();
}
```

這個功能我還沒做。
主要是 SSL 證書管理比較麻煩，要接 Cloudflare API 或自己跑 certbot。
等有需求再說吧。

---

## 系列回顧

寫到這裡，Multi-Tenant 系列就告一段落了。

讓我回顧一下這五篇講了什麼：

**[第一篇：Multi-Tenant 是什麼？](/posts/multi-tenant-saas-architecture)** — 從「朋友說想用我的系統」開始，解釋什麼是多租戶架構。
三種隔離策略各有優缺點，我選了 Row-Level 因為最簡單、[Supabase](https://supabase.com/) 免費方案只有一個資料庫。

**第二篇：Supabase RLS 實戰** — RLS（Row-Level Security）是 [PostgreSQL](https://www.postgresql.org/) 的功能，讓資料庫自動幫你過濾 `tenant_id`。
就算程式碼忘記加 WHERE 條件也不會漏資料。

**第三篇：Next.js 動態路由** — 用 `app/[slug]/` 資料夾結構，讓每個租戶有自己的網址。
Middleware 處理重導向和權限檢查。

**第四篇：多租戶權限設計** — 當用戶可以同時屬於多個租戶時，權限就不能只看 `user_id`。
要用 `tenant_members` 表記錄「誰在哪個租戶有什麼角色」。

**第五篇：租戶品牌自訂（這篇）** — 白牌功能讓每個租戶看起來像是在用自己的系統。
Logo、顏色、Favicon 都可以自訂。

---

## 值不值得做

回頭看，Multi-Tenant 架構讓我可以用一套程式碼服務 N 個客戶，不用幫每個客戶開一台 server。
修 bug 或加功能，所有客戶同時生效。
資料庫、伺服器、CDN 都是共用的，成本攤下來很低。
新增一個租戶只是在資料庫插一筆資料，不是開一台機器。

當然也有代價——每個功能都要考慮「這是哪個租戶的？」，複雜度蹭蹭往上漲。
程式碼寫錯可能導致資料外洩，所以才要 RLS 當保險。
如果某個大客戶要求獨特功能，會影響整體架構，客製化受限。

對我來說，能用同一套系統服務幾十個講師，比幫每個講師維護一套獨立系統划算太多了。

[Notion](https://www.notion.so/)、[Slack](https://slack.com/)、[Shopify](https://www.shopify.com/) 都是這樣做的。
