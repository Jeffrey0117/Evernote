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

## 兩種網址設計

網址要怎麼設計？有兩種主流做法。

**子路徑**：`platform.com/jeff/courses`

**子網域**：`jeff.platform.com/courses`

子網域看起來更「專業」，像是獨立網站。

但我最後選子路徑，因為子網域的設定成本太高了。

首先是 SSL 憑證。子路徑只需要一張憑證保護 `platform.com`，子網域需要 wildcard 憑證（`*.platform.com`），不是每個主機商都免費提供。

再來是 DNS 設定。子網域需要設定 DNS wildcard，讓 `*.platform.com` 都指向同一台伺服器，然後在程式裡解析 hostname 判斷是哪個租戶。

[Next.js](https://nextjs.org/) 的 App Router 對子路徑是原生支援，子網域要額外寫 middleware 解析。

還有 Cookie 問題。子路徑天然共享 Cookie，子網域要特別設定 `domain=.platform.com` 才能跨子網域共享。

**我只是想趕快把功能做出來，不想花時間搞 DevOps。**

當然，如果你的客戶是企業，願意付更高的價格換取「看起來完全獨立的網站」，甚至想要自訂網域（`learn.jeff.com`），那子網域和 custom domain 值得投資。

但對早期的小型 SaaS 來說，子路徑就夠了。

---

## 用動態路由實作

選定子路徑之後，接下來是怎麼實作。

Next.js App Router 用資料夾名稱定義路由，`[slug]` 這種方括號語法代表「動態路由段」。

我的資料夾結構長這樣：

```
app/
├── [tenantSlug]/           ← 這就是動態路由
│   ├── layout.tsx          ← 租戶專屬的 layout
│   ├── page.tsx            ← 租戶首頁
│   └── courses/
│       └── page.tsx        ← 課程列表
└── page.tsx                ← 平台首頁
```

當使用者訪問 `/jeff/courses`，Next.js 會把 `jeff` 當作 `params.tenantSlug` 傳進頁面元件。

頁面就可以用這個 slug 去查這個租戶的課程資料。

聽起來很簡單，但實際做下去會發現一個問題。

---

## 為什麼需要 TenantContext

每個頁面都要拿到租戶資料——課程列表頁要顯示講師名稱，設定頁要顯示講師 Logo，課程詳情頁要套用講師的品牌色。

最直覺的做法是每個頁面自己查：

```tsx
// courses/page.tsx
const tenant = await getTenantBySlug(tenantSlug);

// settings/page.tsx
const tenant = await getTenantBySlug(tenantSlug);

// courses/[id]/page.tsx
const tenant = await getTenantBySlug(tenantSlug);
```

這樣寫的問題是：**重複太多次了。**

每個頁面都查一次資料庫，每個頁面都要處理「租戶不存在」的錯誤，每個頁面都要把租戶資料一層一層往下傳給子元件。

有沒有辦法只查一次，然後讓所有頁面和元件都能用？

React 的 Context 就是幹這個的。

**Context 就像一個「廣播系統」**——在最上層放進去的資料，底下任何一層都能直接拿到，不用一層一層傳。

---

## TenantContext 怎麼設計

我的做法是在 `[tenantSlug]/layout.tsx` 查一次租戶資料，然後用 Context 傳給所有子頁面。

```tsx
// app/[tenantSlug]/layout.tsx

export default async function TenantLayout({ children, params }) {
  const { tenantSlug } = await params;
  const tenant = await getTenantBySlug(tenantSlug);

  if (!tenant) {
    notFound();  // 找不到租戶就 404
  }

  return (
    <TenantProvider tenant={tenant}>
      {children}
    </TenantProvider>
  );
}
```

Layout 查完之後，任何子頁面只要呼叫 `useTenant()` 就能拿到資料：

```tsx
// 任何子頁面或元件
const tenant = useTenant();
console.log(tenant.name);  // "Jeff 的教學網站"
```

這樣設計的好處很明顯——租戶資料只查一次，錯誤處理只寫一次，子頁面和元件都變得很乾淨。

到這邊為止，一切都很順利。

然後我踩到一個大坑。

---

## Session 跨租戶的坑

事情是這樣的。

我找了個朋友測試，他在 Jeff 的網站註冊了帳號、買了課程。

過幾天，我上線了 Alice 這個講師。

朋友好奇就點進去 `/alice`，結果他發現——**他還是登入狀態**。

他沒在 Alice 那邊註冊過，怎麼會是登入的？

我查了一下才搞懂。

[Supabase](https://supabase.com/) Auth 的 session 是存在 Cookie 裡的，而 Cookie 是綁在網域上，不是綁在路徑上。

`platform.com/jeff` 和 `platform.com/alice` 對瀏覽器來說是**同一個網域**，所以 Cookie 是共用的。

使用者在 Jeff 那邊登入之後，跑去 Alice 那邊，瀏覽器還是會帶著同一個 session。

這就麻煩了。

使用者在 Jeff 那邊是學生，但在 Alice 那邊可能根本沒有帳號。

更糟的情況：如果這個使用者在 Jeff 那邊是「講師助教」，跑去 Alice 那邊，系統會不會誤判他有管理權限？

**Session 告訴你「這個人是誰」，但沒告訴你「這個人在這個租戶有什麼權限」。**

這兩件事要分開處理。

---

## 加入角色檢查

我的做法是在 TenantContext 裡多查一層：除了租戶資料，還要查「使用者在這個租戶的角色」。

資料庫有一張 `tenant_members` 表，記錄每個使用者在每個租戶的角色：

| user_id | tenant_id | role |
|---------|-----------|------|
| user_123 | jeff_tenant | student |
| user_123 | alice_tenant | (沒有記錄) |
| user_456 | jeff_tenant | admin |

使用者進入 Jeff 的網站時，去 `tenant_members` 查一下：

- 有記錄 → 他是這個租戶的成員，取得對應角色
- 沒記錄 → 他跟這個租戶沒關係，視為訪客

現在 `useTenant()` 除了回傳租戶資料，還會回傳 `role`。

頁面就可以根據 role 決定要顯示什麼：

```tsx
const { tenant, role } = useTenant();

// 只有 owner 和 admin 能進設定頁
if (role !== 'owner' && role !== 'admin') {
  redirect(`/${tenant.slug}`);
}
```

這樣就解決了跨租戶的權限問題。

Session 告訴我們「這個人是誰」，`tenant_members` 表告訴我們「這個人在這個租戶是什麼角色」。

---

## 效能考量

你可能會問：每次進入租戶頁面都要查 `tenant_members`，會不會太慢？

有幾個優化方式。

**在 Server Component 預先查好**

Layout 是 Server Component，可以在伺服器端就把租戶資料和權限一起查好，然後傳給 TenantProvider。這樣第一次載入就有資料，不用等 client 端再發一次請求。

**快取**

用 [React Query](https://tanstack.com/query/latest) 或 [SWR](https://swr.vercel.app/) 快取權限資料。使用者在同一個租戶裡切換頁面時，不用每次都重新查詢。

**RLS 兜底**

就算前端判斷出錯，[Supabase](https://supabase.com/) 的 Row-Level Security 還是會擋住未授權的資料存取。

這是最後一道防線。前端的權限檢查是為了 UX（不讓使用者看到不該看的 UI），後端的 RLS 是為了安全（就算前端被繞過，資料還是拿不到）。

---

回頭看這篇講的東西：

**網址設計**選了子路徑而不是子網域，因為設定成本低，對早期產品來說夠用了。

**動態路由**用 Next.js 的 `[tenantSlug]` 語法，原生支援，沒什麼好說的。

**TenantContext** 的設計重點是「查一次就好」——layout 查完租戶資料，底下所有頁面都能直接用。

**最坑的是 Session 跨租戶問題**。因為子路徑共用 Cookie，使用者在 A 租戶登入後跑去 B 租戶還是登入狀態。所以光知道「這個人是誰」不夠，還要額外查「這個人在這個租戶是什麼角色」。

其實還有很多可以聊的，像是：

- **使用者同時屬於多個租戶**——在 Jeff 那邊是學生、在 Alice 那邊是助教，切換租戶的 UI 要怎麼設計
- **租戶的自訂設定**——品牌色、Logo、自訂 CSS，怎麼套用到頁面上
- **RLS 政策**——怎麼確保 A 租戶的資料永遠不會被 B 租戶看到

下一篇來講多租戶的權限設計。
