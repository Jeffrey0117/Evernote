---
layout: ../../layouts/PostLayout.astro
title: 用 Next.js 動態路由讓每個租戶有自己的網址
date: 2026-01-13T12:15
description: 用 App Router 的動態路由讓每個租戶有自己的網址，以及 TenantContext 怎麼設計才不會踩坑
tags:
  - Next.js
  - App Router
  - Multi-Tenant
  - React Context
---

我在做線上課程平台的時候，一開始覺得「每個講師的課程頁面」用個 ID 區分就好。

`platform.com/courses?instructor=123`，簡單明瞭。

結果第一個講師入駐就問：「我可以有自己的網址嗎？像 `platform.com/jeff` 這樣。」

我當下覺得，這不就是虛榮心嗎？

後來才想通——**這不是虛榮，是品牌。**

講師分享自己的課程連結時，`platform.com/jeff` 看起來像「Jeff 的教學網站」，而 `platform.com/courses?instructor=123` 看起來像「某個平台上的某個人」。

學生進來看到的第一眼，會覺得這是講師的地盤，不是平台的附屬品。

這就是 Multi-Tenant（多租戶）架構要解決的事情之一。

## 先講一下什麼是 Multi-Tenant

如果你做的是 SaaS，通常會有很多「租戶」共用同一套系統。

以我的課程平台為例，每個講師就是一個租戶。

他們共用同一套程式碼、同一個資料庫，但各自有獨立的資料、獨立的設定、獨立的品牌外觀。

這就是 Multi-Tenant。

跟「每個客戶部署一套獨立系統」相比，Multi-Tenant 的好處是維護成本低——修一次 bug，所有租戶都修好了。

壞處是設計要更小心，不然 A 租戶可能看到 B 租戶的資料。

[上一篇](/posts/multi-tenant-saas-architecture)我講了資料隔離策略，用 `tenant_id` 欄位區分不同租戶的資料。

這篇要講的是另一個問題：**怎麼讓每個租戶有自己的網址**。

---

## 子路徑 vs 子網域

第一個問題：網址要怎麼設計？

有兩種主流做法：

**子路徑（Subpath）**
```
platform.com/jeff/courses
platform.com/alice/courses
```

**子網域（Subdomain）**
```
jeff.platform.com/courses
alice.platform.com/courses
```

兩種我都考慮過，最後選子路徑。原因：

| 考量 | 子路徑 | 子網域 |
|------|--------|--------|
| SSL 憑證 | 一張就夠 | 需要 wildcard 憑證 |
| 部署設定 | 不用改 | 要設定 DNS wildcard |
| Next.js 支援 | 原生支援 | 要用 middleware 解析 hostname |
| SEO | 主網域權重共享 | 每個子網域是獨立網站 |
| Cookie 共享 | 天然共享 | 要設定 domain 屬性 |

子網域看起來比較「專業」，但設定複雜很多。

我只是想趕快把功能做出來，不想花時間在 DevOps。

如果你的客戶是企業，願意付高價換取「完全獨立的網址」（甚至自訂網域），那子網域甚至 custom domain 值得考慮。

但對我這種小型 SaaS，子路徑就夠用了。

---

## App Router 的動態路由

[Next.js](https://nextjs.org/) 的 App Router 用資料夾名稱定義路由。

`[slug]` 這種方括號語法代表動態路由段。

我的資料夾結構長這樣：

```
app/
├── [tenantSlug]/
│   ├── layout.tsx      ← 租戶專屬的 layout
│   ├── page.tsx        ← 租戶首頁
│   ├── courses/
│   │   ├── page.tsx    ← 課程列表
│   │   └── [courseId]/
│   │       └── page.tsx  ← 單一課程頁
│   └── settings/
│       └── page.tsx    ← 租戶設定頁（講師用）
└── page.tsx            ← 平台首頁
```

當使用者訪問 `/jeff/courses`，Next.js 會匹配到 `app/[tenantSlug]/courses/page.tsx`，然後把 `jeff` 當作 `params.tenantSlug` 傳進去。

頁面可以這樣拿到 slug：

```tsx
// app/[tenantSlug]/courses/page.tsx

interface PageProps {
  params: Promise<{ tenantSlug: string }>;
}

export default async function CoursesPage({ params }: PageProps) {
  const { tenantSlug } = await params;

  // 用 slug 查詢這個租戶的課程
  const courses = await fetchCourses(tenantSlug);

  return (
    <div>
      <h1>{tenantSlug} 的課程</h1>
      {courses.map(course => (
        <CourseCard key={course.id} course={course} />
      ))}
    </div>
  );
}
```

看起來很簡單對吧？

但如果每個頁面都要自己 `await params` 然後查一次租戶資料，問題就來了。

每個頁面都查一次 `SELECT * FROM tenants WHERE slug = ?`，重複到不行。

每個頁面都要寫一樣的錯誤處理——租戶不存在怎麼辦？

子元件要用租戶資料時，還要再 prop drilling 傳下去，煩死。

這就是為什麼需要 TenantContext。

---

## TenantContext 設計

我在 `[tenantSlug]/layout.tsx` 裡面做一次查詢，然後用 Context 傳給所有子頁面。

先定義 Context：

```tsx
// contexts/TenantContext.tsx
'use client';

import { createContext, useContext, ReactNode } from 'react';

interface Tenant {
  id: string;
  slug: string;
  name: string;
  logoUrl: string | null;
  primaryColor: string | null;
}

interface TenantContextValue {
  tenant: Tenant;
}

const TenantContext = createContext<TenantContextValue | null>(null);

export function TenantProvider({
  tenant,
  children,
}: {
  tenant: Tenant;
  children: ReactNode;
}) {
  return (
    <TenantContext.Provider value={{ tenant }}>
      {children}
    </TenantContext.Provider>
  );
}

export function useTenant(): Tenant {
  const context = useContext(TenantContext);
  if (!context) {
    throw new Error('useTenant must be used within TenantProvider');
  }
  return context.tenant;
}
```

然後在 layout 裡面包起來：

```tsx
// app/[tenantSlug]/layout.tsx

import { notFound } from 'next/navigation';
import { TenantProvider } from '@/contexts/TenantContext';
import { getTenantBySlug } from '@/lib/tenants';

interface LayoutProps {
  children: React.ReactNode;
  params: Promise<{ tenantSlug: string }>;
}

export default async function TenantLayout({ children, params }: LayoutProps) {
  const { tenantSlug } = await params;

  // 查詢租戶資料
  const tenant = await getTenantBySlug(tenantSlug);

  // 找不到租戶就 404
  if (!tenant) {
    notFound();
  }

  return (
    <TenantProvider tenant={tenant}>
      <TenantHeader />
      <main>{children}</main>
      <TenantFooter />
    </TenantProvider>
  );
}
```

這樣設計的好處是 layout 查完，所有子頁面直接用，不用每個頁面都查一次。

租戶不存在？layout 統一處理，子頁面不用管。

不管是 courses 頁還是 courses/[id] 頁，`useTenant()` 都能拿到資料。

子頁面變得很乾淨：

```tsx
// app/[tenantSlug]/courses/page.tsx
'use client';

import { useTenant } from '@/contexts/TenantContext';

export default function CoursesPage() {
  const tenant = useTenant();

  return (
    <div>
      <h1>{tenant.name} 的課程</h1>
      {/* ... */}
    </div>
  );
}
```

---

## Session 跨租戶的大坑

這邊有一個大坑，我花了兩天才搞清楚。

[Supabase](https://supabase.com/) Auth 的 session 是**全站共用**的。

什麼意思？

假設使用者在 Jeff 的網站登入，session 會存在瀏覽器的 cookie 裡。

這個 cookie 是 `platform.com` 的，不是 `platform.com/jeff` 的。

所以當這個使用者跑去 `/alice`，他還是**已登入狀態**。

這就麻煩了。

使用者在 Jeff 那邊是學生，但在 Alice 那邊可能根本沒有帳號。

如果我們不檢查，他就能看到 Alice 的課程列表（雖然看不到內容，但 UI 上會很奇怪）。

更糟的情況：如果這個使用者在 Jeff 那邊是「講師管理員」，跑去 Alice 那邊，系統會不會誤判他有管理權限？

**Session 告訴你「這個人是誰」，但沒告訴你「這個人在這個租戶有什麼權限」。**

---

## 在 TenantProvider 檢查存取權

我的做法是在 TenantProvider 裡加一層權限檢查。

```tsx
// contexts/TenantContext.tsx
'use client';

import { createContext, useContext, ReactNode, useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

interface Tenant {
  id: string;
  slug: string;
  name: string;
  logoUrl: string | null;
  primaryColor: string | null;
}

type TenantRole = 'owner' | 'admin' | 'member' | 'student' | null;

interface TenantContextValue {
  tenant: Tenant;
  role: TenantRole;       // 使用者在這個租戶的角色
  isLoading: boolean;     // 權限查詢中
}

const TenantContext = createContext<TenantContextValue | null>(null);

export function TenantProvider({
  tenant,
  children,
}: {
  tenant: Tenant;
  children: ReactNode;
}) {
  const [role, setRole] = useState<TenantRole>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function checkAccess() {
      const supabase = createClient();
      const { data: { user } } = await supabase.auth.getUser();

      if (!user) {
        // 未登入，公開訪客
        setRole(null);
        setIsLoading(false);
        return;
      }

      // 查詢使用者在這個租戶的角色
      const { data: membership } = await supabase
        .from('tenant_members')
        .select('role')
        .eq('tenant_id', tenant.id)
        .eq('user_id', user.id)
        .single();

      setRole(membership?.role ?? null);
      setIsLoading(false);
    }

    checkAccess();
  }, [tenant.id]);

  return (
    <TenantContext.Provider value={{ tenant, role, isLoading }}>
      {children}
    </TenantContext.Provider>
  );
}

export function useTenant() {
  const context = useContext(TenantContext);
  if (!context) {
    throw new Error('useTenant must be used within TenantProvider');
  }
  return context;
}
```

現在 `useTenant()` 會回傳 `tenant`（租戶資料）、`role`（使用者在這個租戶的角色，`null` 代表沒有權限）、還有 `isLoading`（權限還在查詢中）。

頁面可以根據 role 決定要顯示什麼：

```tsx
// app/[tenantSlug]/settings/page.tsx
'use client';

import { useTenant } from '@/contexts/TenantContext';
import { redirect } from 'next/navigation';

export default function SettingsPage() {
  const { tenant, role, isLoading } = useTenant();

  if (isLoading) {
    return <div>載入中...</div>;
  }

  // 只有 owner 和 admin 能進設定頁
  if (role !== 'owner' && role !== 'admin') {
    redirect(`/${tenant.slug}`);
  }

  return (
    <div>
      <h1>{tenant.name} 設定</h1>
      {/* 管理介面 */}
    </div>
  );
}
```

這樣就解決了跨租戶的權限問題。

Session 告訴我們使用者是誰，`tenant_members` 表告訴我們他在這個租戶有什麼權限。

---

## 效能怎麼辦

你可能注意到了，每次進入租戶頁面都要查一次 `tenant_members`。

這會不會太慢？

有幾個優化方式。

### Server Component 預查詢

把權限查詢放到 layout 的 Server Component 裡，跟租戶資料一起查，然後傳給 TenantProvider：

```tsx
// app/[tenantSlug]/layout.tsx

export default async function TenantLayout({ children, params }: LayoutProps) {
  const { tenantSlug } = await params;
  const tenant = await getTenantBySlug(tenantSlug);

  if (!tenant) notFound();

  // 在 server 端查好權限
  const role = await getUserRoleInTenant(tenant.id);

  return (
    <TenantProvider tenant={tenant} initialRole={role}>
      {children}
    </TenantProvider>
  );
}
```

這樣第一次載入就有權限資料，不用等 client 端再查一次。

### 快取

用 [React Query](https://tanstack.com/query/latest) 或 [SWR](https://swr.vercel.app/) 快取權限資料，切換頁面時不用重新查詢。

### RLS 兜底

就算前端判斷出錯，[Supabase](https://supabase.com/) 的 RLS 還是會擋住未授權的資料存取。

這是最後一道防線，我在[上一篇](/posts/multi-tenant-rls)有詳細講。

---

這篇講的是 Multi-Tenant 的路由層面。

子路徑和子網域我選了前者，因為簡單，不想搞 wildcard 憑證那些有的沒的。

`[tenantSlug]` 動態路由是 [Next.js](https://nextjs.org/) App Router 原生支援的，用起來很直覺。

TenantContext 的設計重點是查一次就好，layout 查完，所有子頁面都能用。

最坑的是 [Supabase](https://supabase.com/) Auth 的 session 是全站共用的，所以光知道使用者是誰還不夠，還要額外檢查他在這個租戶有什麼權限。

下一篇會深入講多租戶的權限設計——當使用者同時屬於多個租戶（在 Jeff 那邊是學生、在 Alice 那邊是助教），資料模型和 UI 要怎麼處理。

