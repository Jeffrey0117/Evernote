---
layout: ../../layouts/PostLayout.astro
title: 讓資料庫自動擋住跨租戶查詢
date: 2026-01-13T12:14
description: 用 PostgreSQL 的 Row-Level Security 功能，從資料庫層級防止跨租戶資料洩漏
tags:
  - Supabase
  - PostgreSQL
  - RLS
  - Multi-Tenant
---

先講一下背景。

我在做一個課程平台，想讓不同客戶（講師、補習班、企業）都能用同一套系統開課。
每個客戶看到的是自己的品牌、自己的課程、自己的學員，互相看不到。

這種架構叫 **Multi-Tenant（多租戶）**。
「Tenant」就是「租戶」，你可以想成是「房客」——大家住在同一棟大樓，但各自有各自的房間，不能跑進別人家。

實作上最直接的做法是：每張資料表都加一個 `tenant_id` 欄位，查資料的時候加上 `WHERE tenant_id = ?`，這樣就只會拿到自己租戶的資料。

聽起來很簡單對吧？

然後我就踩坑了。

---

## 那個忘記加 WHERE 的下午

某天我在寫一個「查詢所有課程」的 API，寫完測試，沒問題，上線。

過了幾天，有個講師回報：「欸，我怎麼在後台看到別人的課程？」

我愣了一下，打開 console 一看——

幹，忘記加 `tenant_id` 了。

那個 API 把**所有租戶**的課程都撈出來了。

更慘的是，這種 bug 不會報錯。
程式正常執行，資料正常回傳，只是回傳的資料**不該被這個人看到**。

如果不是講師剛好注意到，這個洞可能會一直開著。

---

## 問題不是「你忘記」，是「你會忘記」

當下的修法很簡單，補上 `.eq('tenant_id', currentTenantId)` 就好。

但這不是根本解法。

**只要是人寫的 code，就會有忘記的時候。**

新人加入團隊，不知道每個查詢都要加 tenant_id。
趕 deadline 的時候腦袋一片空白。
複製貼上的時候漏掉那一行。
寫 raw SQL 的時候更容易忘。

每張表、每個查詢、每個 API，都要記得加那個條件。

這不是工程問題，是人性問題。

有沒有辦法讓**資料庫自己擋**？
就算 code 寫錯，資料庫也會說「不，你沒權限看這筆」？

有。這就是 **RLS（Row-Level Security）**。

---

## RLS 是什麼？白話版

RLS 是 [PostgreSQL](https://www.postgresql.org/) 內建的功能，全名 Row-Level Security，中文叫「列級安全性」。

用大白話講：**讓資料庫知道「這個人只能看哪些 row」**。

傳統的權限控制是「你可以讀這張表」或「你不能讀這張表」，整張表一起管。
RLS 更細，是「這張表裡面，你只能讀 tenant_id = xxx 的那幾筆」。

你可以在資料庫裡定義規則（Policy），告訴它：用戶 A 只能看 `tenant_id = 'xxx'` 的資料，用戶 B 只能看 `tenant_id = 'yyy'` 的資料。

定義好之後，不管你的 SQL 怎麼寫，資料庫都會**自動**幫你過濾。

就算你寫 `SELECT * FROM courses`，沒加任何 WHERE，資料庫也會自動幫你加上條件，只回傳你該看到的資料。

用一個比喻來說：假設每個人的感應卡都綁定了自己住的樓層。
刷卡進電梯的時候，系統會自動判斷「這張卡只能開 3 樓的門」。
不用靠保全人工檢查，系統自己會擋。

RLS 就是這個概念——**把權限檢查從應用程式下沉到資料庫層**。

---

## [Supabase](https://supabase.com/) 把 RLS 變成標配

RLS 是 [PostgreSQL](https://www.postgresql.org/) 2016 年就有的功能，但一直沒什麼人用。

原因很簡單：設定麻煩。

你需要寫 SQL 建立 Policy、設定角色、處理 session 變數，很多 ORM 也不支援。
大部分人寧願在 application layer 處理權限。

Supabase 做的事情，是把 RLS 變成**一等公民**。

Supabase 的架構是這樣：

```
Client (瀏覽器/App)
    ↓
  Supabase API（PostgREST）
    ↓
  PostgreSQL（你的資料庫）
```

當你用 Supabase Client 查詢，它不是透過傳統的後端 API，而是**直接打 PostgreSQL**。

這代表什麼？

代表**權限控制必須在資料庫層**。
因為沒有後端 code 可以攔截。

所以 Supabase 預設就開啟 RLS。
你新建一張表，如果沒有設定 Policy，**什麼資料都讀不到**。

一開始我覺得很煩——怎麼每張表都要寫 Policy？

後來才發現這是好事。
**它強迫你思考權限**。

---

## 三步驟設定 RLS

假設我有一張 `courses` 表：

```sql
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  title TEXT NOT NULL,
  price INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

要設定 RLS，需要三個步驟：

### Step 1：啟用 RLS

```sql
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
```

啟用之後，**所有查詢預設都會被擋**（除了 superuser 和 table owner）。

### Step 2：建立 Policy

Policy 就是「規則」。我們要告訴資料庫：「誰可以看哪些 row」。

```sql
CREATE POLICY "Users can view courses in their tenant"
ON courses
FOR SELECT
USING (tenant_id = get_current_tenant_id());
```

這段的意思是：

- `FOR SELECT`：這條規則適用於 SELECT 操作
- `USING (...)`：只有符合這個條件的 row 才會被回傳
- `get_current_tenant_id()`：這是一個自訂函數，待會會講

你也可以針對不同操作設定不同規則：

```sql
-- INSERT：只能新增到自己的租戶
CREATE POLICY "Users can insert courses in their tenant"
ON courses
FOR INSERT
WITH CHECK (tenant_id = get_current_tenant_id());

-- UPDATE：只能更新自己租戶的資料
CREATE POLICY "Users can update courses in their tenant"
ON courses
FOR UPDATE
USING (tenant_id = get_current_tenant_id())
WITH CHECK (tenant_id = get_current_tenant_id());

-- DELETE：只能刪除自己租戶的資料
CREATE POLICY "Users can delete courses in their tenant"
ON courses
FOR DELETE
USING (tenant_id = get_current_tenant_id());
```

注意 `USING` 和 `WITH CHECK` 的差別：

- `USING`：過濾可以讀取/更新/刪除的 row
- `WITH CHECK`：驗證新增/更新後的資料是否合法

### Step 3：設定 get_current_tenant_id() 函數

這個函數要回傳「目前用戶所屬的租戶 ID」。

Supabase 提供了一個方式：把資訊放在 JWT token 裡，然後用 `auth.jwt()` 讀取。

假設你的 JWT 裡有 `tenant_id` 這個 claim：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN (auth.jwt() ->> 'tenant_id')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

`auth.jwt()` 會回傳一個 JSON，`->> 'tenant_id'` 取出字串，`::UUID` 轉成 UUID 型別。

另一種做法是從 `user_metadata` 取：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT (raw_user_meta_data ->> 'tenant_id')::UUID
    FROM auth.users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

哪種好？看你的場景。

如果用戶可以**切換租戶**（例如一個人同時是多個租戶的成員），把 tenant_id 放在 session 或 request 層級比較彈性。
這個我會在《[多租戶權限設計：當用戶同時屬於多個租戶](/posts/multi-tenant-permissions)》詳細講。

---

## 踩坑：RLS + JOIN 效能爆炸

RLS 設定好之後，一開始跑得很順。

直到有一天，我寫了一個稍微複雜的查詢：

```typescript
const { data } = await supabase
  .from('orders')
  .select(`
    *,
    course:courses(*),
    user:users(*)
  `)
```

這是 Supabase 的 nested select 語法，會產生 JOIN。

然後頁面就卡住了。

打開 Supabase 的 Dashboard 看 query performance——一個查詢跑了 **8 秒**。

怎麼回事？

---

### 問題：每張表的 RLS 都會被執行

當你 JOIN 多張表，每張表的 RLS Policy 都會被檢查。

假設 Policy 是這樣寫的：

```sql
CREATE POLICY "tenant_isolation" ON orders
USING (
  tenant_id = (
    SELECT tenant_id FROM user_tenant_mappings
    WHERE user_id = auth.uid()
    LIMIT 1
  )
);
```

看起來沒問題對吧？

問題是這個 subquery 會**對每一個 row 執行一次**。

如果 `orders` 有 10,000 筆資料，這個 subquery 就會跑 10,000 次。

再加上 `courses` 和 `users` 的 Policy 也有類似的 subquery，執行次數是乘法：

```
10,000 (orders) × 1,000 (courses) × 500 (users) = ...
```

難怪會卡住。

---

## Policy 要盡量簡單

RLS Policy 的效能關鍵——**不要在 USING clause 裡面放複雜的查詢**。

壞寫法：

```sql
USING (
  tenant_id IN (
    SELECT tenant_id FROM user_tenant_mappings
    WHERE user_id = auth.uid()
  )
)
```

好寫法：

```sql
USING (tenant_id = get_current_tenant_id())
```

讓複雜的邏輯封裝在函數裡，而且函數要**直接回傳值**，不要回傳查詢結果。

如果用戶真的可能屬於多個租戶，考慮把「當前租戶」存在 session 變數：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN current_setting('app.current_tenant_id', true)::UUID;
END;
$$ LANGUAGE plpgsql STABLE;
```

然後在每次 request 開始時設定：

```sql
SET app.current_tenant_id = 'xxx-xxx-xxx';
```

這樣 Policy 的檢查就變成簡單的字串比對，超快。

---

## 用 SECURITY DEFINER 跳過 RLS

有時候你需要「跳過 RLS」做一些特殊操作。

例如：統計所有租戶的用戶數量（給 superadmin 看的報表）。

這時候可以用 `SECURITY DEFINER` 函數：

```sql
CREATE OR REPLACE FUNCTION get_all_tenant_stats()
RETURNS TABLE (tenant_id UUID, user_count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, COUNT(u.id)
  FROM tenants t
  LEFT JOIN users u ON u.tenant_id = t.id
  GROUP BY t.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

`SECURITY DEFINER` 的意思是：這個函數用**建立者的權限**執行，不是**呼叫者的權限**。

建立者通常是 superuser，不受 RLS 限制。

**但這很危險。**

如果函數寫錯，就會暴露不該暴露的資料。
使用時要非常小心：

1. 函數內部要**自己做權限檢查**
2. 只回傳**必要的資料**，不要回傳整個 row
3. 用 `SET search_path = ''` 防止 schema 注入攻擊

```sql
CREATE OR REPLACE FUNCTION get_all_tenant_stats()
RETURNS TABLE (tenant_id UUID, user_count BIGINT) AS $$
BEGIN
  -- 權限檢查：只有 superadmin 可以呼叫
  IF NOT is_superadmin(auth.uid()) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  RETURN QUERY
  SELECT t.id, COUNT(u.id)
  FROM public.tenants t
  LEFT JOIN public.users u ON u.tenant_id = t.id
  GROUP BY t.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
```

---

## 用 Service Role Key 直接繞過

Supabase 有兩種 API Key：

- **anon key**：給前端用，受 RLS 限制
- **service_role key**：給後端用，**繞過 RLS**

當你需要做「跨租戶」的操作（例如背景任務、webhook 處理），可以用 service_role key 建立一個 admin client：

```typescript
import { createClient } from '@supabase/supabase-js'

// 一般 client（受 RLS 限制）
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
)

// Admin client（繞過 RLS）
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
)

// 這個會受 RLS 限制
const { data: userCourses } = await supabase
  .from('courses')
  .select('*')

// 這個不受 RLS 限制，會拿到所有資料
const { data: allCourses } = await supabaseAdmin
  .from('courses')
  .select('*')
```

**重要提醒**：

1. **絕對不要在前端用 service_role key**——這個 key 可以做任何事情，包括刪除所有資料
2. 後端使用時，要**自己做權限檢查**——RLS 被繞過了，責任在你的 code
3. 把 key 存在環境變數，不要 commit 到 git

---

## 我現在的做法

經過幾次踩坑，我現在的架構是這樣：

### 前端（直接用 Supabase Client）

```typescript
// 前端只用 anon key，一切受 RLS 保護
const { data } = await supabase
  .from('courses')
  .select('*')
```

就算 code 寫錯，RLS 會擋住。安心。

### 後端 API（需要時用 Admin Client）

```typescript
// 需要跨租戶操作時，用 admin client
// 但要自己做權限檢查
export async function GET(request: Request) {
  const user = await getUser(request)

  if (!user.isSuperAdmin) {
    return new Response('Forbidden', { status: 403 })
  }

  const { data } = await supabaseAdmin
    .from('courses')
    .select('*')

  return Response.json(data)
}
```

### RLS Policy（保持簡單）

```sql
-- 簡單的等式比對
CREATE POLICY "tenant_isolation" ON courses
FOR ALL
USING (tenant_id = get_current_tenant_id())
WITH CHECK (tenant_id = get_current_tenant_id());
```

### get_current_tenant_id()（從 JWT 讀取）

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
DECLARE
  tenant UUID;
BEGIN
  tenant := (auth.jwt() ->> 'tenant_id')::UUID;
  RETURN tenant;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

這樣的好處是：

- 前端不用擔心忘記加 `tenant_id`
- 複雜的跨租戶邏輯放在後端 API，有完整的權限控制
- Policy 保持簡單，效能有保障

---

這篇講的是 RLS 的核心概念和實戰技巧。

RLS 是 PostgreSQL 的原生功能，讓資料庫自動過濾 row。
Supabase 把它變成標配，因為 client 直接打 DB，權限必須在 DB 層處理。

設定就三步：ENABLE RLS、CREATE POLICY、實作 `get_current_tenant_id()`。

但要注意效能陷阱——Policy 裡不要放複雜查詢，每個 row 都會執行一次。
需要跨租戶操作的時候，可以用 SECURITY DEFINER 函數或 Service Role Key 繞過。

RLS 解決的是「資料隔離」的問題。
但還有另一個問題：**網址怎麼區分不同租戶？**

`acme.example.com` 和 `beta.example.com` 怎麼對應到不同的 tenant_id？

這個會在下一篇《[Next.js 動態路由：一個網址架構服務 N 個租戶](/posts/multi-tenant-routing)》詳細講。
