---
layout: ../../layouts/PostLayout.astro
title: 用 Next.js 和 Supabase 建構 Multi-Tenant SaaS 架構
date: 2026-01-13T12:13
description: 從零打造多租戶線上課程平台，踩過的坑和學到的事
tags:
  - Next.js
  - Supabase
  - Multi-Tenant
  - SaaS
  - PostgreSQL
---

一開始只是想做一個簡單的網頁，放我自己的課程。

用戶註冊、買課、看影片，功能很單純。

做完之後覺得還不錯，就想說加個後台管理、加個金流串接、加個進度追蹤。功能越疊越多，慢慢變成一個完整的課程平台。

然後有朋友問：「欸，這個可以給我用嗎？我也想賣課。」

我說可以啊，幫你開個帳號。

結果他又問：「可是我想要有自己的網址、自己的品牌，學生進來看到的是我的 Logo，不是你的。」

我愣了一下。

這不就變成要做 **Teachable**、**Thinkific** 那種東西嗎？

一個平台，N 個講師，每個講師有自己的網址、自己的品牌、自己的學生。學生 A 在講師甲那邊買的課，不會出現在講師乙的後台。

我去 Google 才發現，這種架構有個專有名詞——**Multi-Tenant（多租戶）**。

當時完全不知道怎麼做。單一租戶的系統我會，加個 `user_id` 就搞定。但多租戶？資料要怎麼隔離？網址要怎麼處理？權限要怎麼設計？

後來花了幾個月，硬是把 Classroo 這個專案做出來了。

踩了一堆坑，但也學到很多。

---

## Multi-Tenant 到底是什麼

先講清楚這個詞。

Multi-Tenant 直譯是「多租戶」。想像一棟公寓大樓，每個住戶有自己的房間，共用電梯和水電，但彼此看不到對方家裡的東西。

對應到軟體：

- **大樓** = 你的 SaaS 平台
- **住戶** = 每個租戶（講師、公司、組織）
- **房間** = 租戶的資料和設定
- **電梯水電** = 共用的程式碼和基礎設施

每個租戶覺得自己在用一個獨立的系統，但其實大家共用同一套程式碼。

這種架構的好處是省錢。你不用幫每個客戶開一台 server、部署一套程式碼。壞處是複雜度爆炸，資料隔離要做好，不然 A 看到 B 的資料就完蛋了。

---

## 三種隔離策略

做 Multi-Tenant 第一個要決定的是：**資料怎麼隔離**？

| 策略 | 做法 | 優點 | 缺點 | 適合場景 |
|------|------|------|------|----------|
| **Database per Tenant** | 每個租戶一個獨立資料庫 | 隔離最徹底，效能好 | 管理麻煩，成本高 | 企業客戶、資安要求高 |
| **Schema per Tenant** | 同一個資料庫，每個租戶一個 schema | 隔離不錯，遷移方便 | PostgreSQL 限定，schema 太多會變慢 | 中型 SaaS、需要資料遷移 |
| **Row-Level** | 同一張表，用 `tenant_id` 區分 | 簡單，成本低 | 查詢要小心，漏加條件就爆炸 | 新創、小型 SaaS、快速迭代 |

我選 Row-Level。

原因很實際：Supabase 免費方案只有一個資料庫，開不了多個。而且 Classroo 的租戶數量不會太多（幾十到幾百個講師），Row-Level 夠用。

做法就是每張表都加一個 `tenant_id`：

```sql
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  title TEXT NOT NULL,
  price INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_courses_tenant ON courses(tenant_id);
```

看起來簡單，但魔鬼在細節。

---

## RLS：Supabase 的殺手鐧

[Row-Level Security（RLS）](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)是 PostgreSQL 的功能，[Supabase](https://supabase.com/docs/guides/auth/row-level-security) 把它發揚光大。

概念是這樣：你在資料表上設一個「政策」，每次查詢都會自動套用。不符合政策的資料，查不到、改不了、刪不掉。

```sql
-- 啟用 RLS
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;

-- 政策：只能看到自己租戶的課程
CREATE POLICY "Users can view own tenant courses" ON courses
  FOR SELECT
  USING (tenant_id = get_current_tenant_id());
```

`get_current_tenant_id()` 是自訂函數，從當前 session 拿租戶 ID。實作大概長這樣：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
  SELECT COALESCE(
    current_setting('app.current_tenant_id', true)::UUID,
    NULL
  );
$$ LANGUAGE sql STABLE;
```

每次 API 請求進來，先設定 `app.current_tenant_id`，之後所有查詢都會自動套用。

這樣不管你的 code 怎麼寫，忘記加 `WHERE tenant_id = ?` 也沒關係，RLS 會自動擋。

**聽起來很美好對吧？**

然後我就踩坑了。

### RLS + JOIN = 地獄

有一張 `orders` 表，要 JOIN `courses` 拿課程名稱：

```sql
SELECT orders.*, courses.title
FROM orders
JOIN courses ON orders.course_id = courses.id
WHERE orders.tenant_id = '...'
```

看起來沒問題，但跑下去爆炸了。

原因是 RLS 會套用在**每一張參與查詢的表**。`courses` 表有自己的 RLS 政策，`orders` 表也有。JOIN 的時候兩邊都要過，邏輯就變得很複雜。

更慘的是，如果 RLS 政策裡面又去查別的表（例如檢查用戶權限），就會變成遞迴查詢，效能直接爆炸。

後來我學到的原則：

1. **RLS 政策盡量簡單**，只檢查 `tenant_id`，不要再 JOIN 別的表
2. **複雜查詢用 SQL function**，設成 `SECURITY DEFINER` 繞過 RLS
3. **後台管理用 Admin Client**，用 service_role key 直接繞過

```typescript
// 一般查詢用這個，會套用 RLS
const supabase = createClient(url, anonKey);

// 後台管理用這個，繞過 RLS
const adminSupabase = createClient(url, serviceRoleKey);
```

---

## 動態路由：一個網址打天下

Multi-Tenant 還有一個問題：網址。

每個租戶要有自己的網址。最簡單的做法是用子路徑：

```
https://classroo.tw/jeff      → 講師 Jeff 的網站
https://classroo.tw/alice     → 講師 Alice 的網站
```

在 Next.js App Router 裡面，這用動態路由就能做到：

```
app/
  [slug]/
    page.tsx          → 租戶首頁
    courses/
      page.tsx        → 課程列表
      [id]/
        page.tsx      → 課程詳情
    admin/
      page.tsx        → 後台管理
```

`[slug]` 就是租戶的識別碼。訪問 `/jeff/courses` 時，`params.slug` 會是 `"jeff"`。

但這樣每個頁面都要先查一次「這個 slug 對應哪個租戶」，很煩。

所以我做了一個 Context：

```tsx
// TenantContext.tsx
const TenantContext = createContext<Tenant | null>(null);

export function TenantProvider({ slug, children }) {
  const [tenant, setTenant] = useState(null);

  useEffect(() => {
    fetchTenantBySlug(slug).then(setTenant);
  }, [slug]);

  return (
    <TenantContext.Provider value={tenant}>
      {children}
    </TenantContext.Provider>
  );
}

export function useTenant() {
  return useContext(TenantContext);
}
```

在 `[slug]/layout.tsx` 包一層：

```tsx
export default function TenantLayout({ params, children }) {
  return (
    <TenantProvider slug={params.slug}>
      {children}
    </TenantProvider>
  );
}
```

這樣底下所有頁面都可以用 `useTenant()` 拿到當前租戶，不用重複查詢。

### 踩坑：Session 跨租戶

這裡有個坑我踩了。

Supabase Auth 的 session 是全站共用的。用戶在 `/jeff` 登入後，跑去 `/alice`，還是登入狀態。

這時候要檢查：**他在 Alice 的租戶有沒有權限？**

一開始沒注意到這點，結果 A 租戶的用戶跑去 B 租戶的後台，雖然進不去（RLS 擋住了），但會看到一個醜醜的錯誤頁面。

後來在 `TenantProvider` 加了一層檢查：

```tsx
export function TenantProvider({ slug, children }) {
  const { user } = useAuth();
  const [tenant, setTenant] = useState(null);
  const [hasAccess, setHasAccess] = useState(false);

  useEffect(() => {
    async function init() {
      const t = await fetchTenantBySlug(slug);
      setTenant(t);

      if (user && t) {
        const access = await checkUserTenantAccess(user.id, t.id);
        setHasAccess(!!access);
      }
    }
    init();
  }, [slug, user]);

  if (tenant && user && !hasAccess) {
    return <NoAccessPage />;
  }

  return (
    <TenantContext.Provider value={tenant}>
      {children}
    </TenantContext.Provider>
  );
}
```

進入租戶頁面時，先確認用戶有沒有這個租戶的存取權，沒有就顯示「你沒有權限」而不是噴錯誤。

---

## 權限：誰能做什麼

Multi-Tenant 的權限比一般系統複雜。

不只是「登入 vs 未登入」，還要考慮：

- 這個用戶是**哪個租戶的**？
- 他在這個租戶裡是**什麼角色**？（擁有者、管理員、學生）
- 他能存取**哪些資源**？

一開始我把這三件事混在一起處理，結果 code 變成義大利麵。

用戶 A 是講師甲的學生，同時也是講師乙的管理員。我用一個 `role` 欄位想搞定所有情況，結果判斷邏輯寫到自己都看不懂。

後來砍掉重練，拆成三層：

### 認證層

用 [Supabase Auth](https://supabase.com/docs/guides/auth)，處理登入登出。這層不管租戶，純粹確認「這個人是誰」。

### 租戶歸屬層

用一張 `user_tenant_access` 表記錄用戶和租戶的關係：

```sql
CREATE TABLE user_tenant_access (
  user_id UUID REFERENCES auth.users(id),
  tenant_id UUID REFERENCES tenants(id),
  role TEXT NOT NULL,  -- 'owner', 'admin', 'member'
  PRIMARY KEY (user_id, tenant_id)
);
```

一個用戶可以屬於多個租戶。例如我在自己的網站是 owner，在朋友的網站是 member。

### 資源權限層

課程、文章、商品這些資源，每個都有 `tenant_id`。

查詢的時候，先確認用戶有沒有這個租戶的存取權，再確認資源是不是屬於這個租戶。

```typescript
async function canAccessCourse(userId: string, courseId: string) {
  // 1. 查課程屬於哪個租戶
  const course = await getCourse(courseId);

  // 2. 查用戶有沒有這個租戶的權限
  const access = await getUserTenantAccess(userId, course.tenant_id);

  // 3. 判斷
  if (!access) return false;
  if (access.role === 'owner') return true;
  if (course.is_published) return true;

  return false;
}
```

聽起來囉嗦，但這樣權限邏輯很清楚，不容易出錯。

---

## 租戶自訂：Logo、顏色、Favicon

每個租戶都想要自己的品牌。

我用一張 `site_settings` 表存這些設定：

```sql
CREATE TABLE site_settings (
  tenant_id UUID PRIMARY KEY REFERENCES tenants(id),
  site_name TEXT,
  logo_url TEXT,
  favicon_url TEXT,
  primary_color TEXT,
  -- ... 一堆設定
);
```

然後在前端根據設定動態調整：

```tsx
function TenantTheme({ children }) {
  const { settings } = useTenant();

  return (
    <>
      <Head>
        <link rel="icon" href={settings.favicon_url} />
      </Head>
      <style jsx global>{`
        :root {
          --primary-color: ${settings.primary_color};
        }
      `}</style>
      {children}
    </>
  );
}
```

這樣每個租戶進去看到的 Logo、顏色都不一樣。

---

## 踩過的其他坑

### Webhook 忘記帶 tenant_id

金流串接的時候，Webhook 回來要知道是哪個租戶的訂單。

一開始忘記把 `tenant_id` 塞進 metadata，Webhook 回來不知道要更新哪個租戶的訂單，debug 了好久。

現在建立訂單的時候一定會帶：

```typescript
const order = await createOrder({
  tenant_id: currentTenant.id,
  user_id: user.id,
  amount: price,
  metadata: {
    tenant_id: currentTenant.id,  // 冗餘但必要
    course_id: course.id,
  }
});
```

### Migration 要考慮所有租戶

改資料庫 schema 的時候，新增的欄位可能要幫現有租戶補預設值。

例如新增 `site_settings.favicon_url`，要跑一個 migration 把現有租戶的 favicon 設成預設值：

```sql
ALTER TABLE site_settings ADD COLUMN favicon_url TEXT;

UPDATE site_settings
SET favicon_url = 'https://classroo.tw/default-favicon.ico'
WHERE favicon_url IS NULL;
```

不然舊租戶的網站會壞掉。

---

## 這套架構的限制

講完優點，也要講限制。

**效能天花板**：所有租戶共用一個資料庫，資料量大了會變慢。Classroo 目前幾十個租戶、幾萬筆資料，完全沒問題。但如果有一個租戶突然爆量（幾百萬學生），就得把他獨立出去，這會是一番大工程。

**隔離不夠徹底**：Row-Level 隔離終究是邏輯隔離，不是物理隔離。金融業、醫療業的客戶通常會直接要求獨立資料庫，這種需求 Row-Level 做不到。

**複雜度**：比單租戶系統複雜很多。每個功能都要想「這在多租戶環境下會怎樣」。開發速度會變慢。

但對大多數 SaaS 來說，這些限制可以接受。

---

## 技術選型總結

| 需求 | 選擇 | 原因 | 替代方案 |
|------|------|------|----------|
| 框架 | [Next.js App Router](https://nextjs.org/docs/app) | Server Components、動態路由、Vercel 部署方便 | Remix、Nuxt |
| 資料庫 | [Supabase](https://supabase.com/) (PostgreSQL) | RLS 內建、Auth 內建、免費額度夠用 | PlanetScale、Neon |
| 隔離策略 | Row-Level | 簡單、成本低、Supabase 原生支援 | Schema per Tenant |
| 認證 | Supabase Auth | 跟資料庫整合好、RLS 可以直接用 `auth.uid()` | Auth0、Clerk |
| 部署 | [Vercel](https://vercel.com/) | Next.js 官方支援、Preview Deployment 好用 | Netlify、Railway |

---

## 其實你每天都在用 Multi-Tenant

回頭看，Multi-Tenant 根本不是什麼新鮮事。你每天用的服務，大部分都是這種架構：

| 服務 | 租戶是誰 | 你看到什麼 |
|------|----------|------------|
| **Notion** | 每個 Workspace | 你只看到自己 Workspace 的頁面，看不到別人的 |
| **Slack** | 每個公司 | 你只能在自己公司的頻道聊天 |
| **Shopify** | 每個商家 | 每個商家有獨立網址、獨立後台、獨立商品 |
| **Figma** | 每個團隊 | 團隊的設計檔彼此隔離 |
| **GitHub** | 每個組織 | Organization 內的 private repo 外人看不到 |
| **Vercel** | 每個 Team | 部署、域名、環境變數都是 Team 層級 |

這些產品的共同點：**一套程式碼，服務百萬個「租戶」**。

Notion 不會幫每個 Workspace 開一台 server。Shopify 不會幫每個商家部署一套獨立程式碼。他們都是用 Multi-Tenant 架構，在同一套系統裡隔離資料。

所以當你做出一個 Multi-Tenant 系統，你其實是在用跟這些大公司一樣的架構思維。

---

其實還有很多可以聊的，像是：

- **訂閱計費** — 怎麼處理不同方案的功能限制
- **租戶 Onboarding** — 新租戶註冊後要跑哪些初始化
- **資料遷移** — 租戶想搬走的時候怎麼匯出資料
- **監控告警** — 怎麼知道哪個租戶的資料庫查詢特別慢

這些之後再寫。

做完這個專案最大的感想是：**Multi-Tenant 沒有想像中難，但也沒有想像中簡單。**

難的不是技術本身，是腦袋要隨時切換。寫每一行 code 都要問自己：「這在多租戶環境下會出事嗎？」查詢有沒有加 `tenant_id`？權限有沒有檢查對？Webhook 有沒有帶租戶資訊？

這種思維轉換才是最累的。

但做完之後很有成就感。一套程式碼服務 N 個客戶，看著租戶數量從 1 變成 10、變成 50，每個租戶都以為自己在用一個獨立的系統。

這就是 Notion、Slack、Shopify 在做的事。

而你也可以。
