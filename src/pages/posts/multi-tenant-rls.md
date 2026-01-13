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

## 為什麼選 Supabase？

RLS 是 PostgreSQL 2016 年就有的功能，但一直沒什麼人用。

原因很簡單：設定麻煩。
你需要寫 SQL 建立 Policy、設定角色、處理 session 變數，很多 ORM 也不支援。
大部分人寧願在 application layer 處理權限。

[Supabase](https://supabase.com/) 做的事情，是把 RLS 變成**一等公民**。

它的架構比較特別：前端可以直接打資料庫（透過 PostgREST），不一定需要經過後端 API。
這代表什麼？代表**權限控制必須在資料庫層**，因為沒有後端 code 可以攔截。

所以 Supabase 預設就開啟 RLS。
你新建一張表，如果沒有設定 Policy，**什麼資料都讀不到**。

一開始我覺得很煩——怎麼每張表都要寫 Policy？

後來才發現這是好事。
**它強迫你思考權限**。

---

## 設定 RLS 的核心概念

設定 RLS 其實只有三件事要做：

**第一，啟用 RLS。** 在資料表上執行 `ENABLE ROW LEVEL SECURITY`，告訴資料庫「這張表要做列級權限控制」。啟用之後，所有查詢預設都會被擋，除非你定義了 Policy。

**第二，建立 Policy。** Policy 就是規則，告訴資料庫「誰可以對哪些 row 做什麼操作」。你可以針對 SELECT、INSERT、UPDATE、DELETE 分別設定不同規則。

**第三，讓資料庫知道「目前是誰」。** 這是最關鍵的一步。資料庫怎麼知道現在發 request 的人是哪個租戶？你需要一個方式把這個資訊傳進去。

在 Supabase 裡，這個資訊通常放在 JWT token 裡。用戶登入的時候，token 裡會帶著 `tenant_id`，然後你寫一個函數 `get_current_tenant_id()` 去讀這個值。

Policy 長這樣：

```sql
CREATE POLICY "tenant_isolation" ON courses
FOR ALL
USING (tenant_id = get_current_tenant_id())
WITH CHECK (tenant_id = get_current_tenant_id());
```

這段的意思是：不管是讀、寫、改、刪，都只能操作 `tenant_id` 等於目前用戶所屬租戶的那些 row。

`USING` 負責過濾「你能讀到哪些 row」，`WITH CHECK` 負責驗證「你寫入的資料是否合法」。

而 `get_current_tenant_id()` 這個函數，就是去 JWT 裡把 `tenant_id` 讀出來：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN (auth.jwt() ->> 'tenant_id')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

這樣一來，每張需要做租戶隔離的表，都套用這個 Policy，就完成了。

---

## 然後我又踩坑了：效能爆炸

RLS 設定好之後，一開始跑得很順。

直到有一天，我寫了一個稍微複雜的查詢——訂單列表，要順便撈出課程資訊和用戶資訊，也就是 JOIN 三張表。

然後頁面就卡住了。

打開 Supabase 的 Dashboard 看 query performance——一個查詢跑了 **8 秒**。

怎麼回事？

問題出在：**當你 JOIN 多張表，每張表的 RLS Policy 都會被檢查**。

而且 Policy 裡的條件，會**對每一個 row 執行一次**。

假設你的 Policy 是這樣寫的：

```sql
USING (
  tenant_id = (
    SELECT tenant_id FROM user_tenant_mappings
    WHERE user_id = auth.uid()
    LIMIT 1
  )
)
```

看起來沒問題對吧？

問題是這個 subquery 會**對每一個 row 執行一次**。

如果 `orders` 有 10,000 筆資料，這個 subquery 就會跑 10,000 次。
再加上 `courses` 和 `users` 的 Policy 也有類似的 subquery，執行次數是乘法。

難怪會卡住。

---

## Policy 的寫法決定效能

踩完這個坑，我學到一個重要的原則：**Policy 要盡量簡單，不要在裡面放複雜的查詢**。

壞的寫法是在 Policy 裡做子查詢。
好的寫法是把複雜邏輯封裝在函數裡，而且函數要**直接回傳值**，不是回傳查詢結果。

簡單講，就是讓 Policy 的檢查變成「欄位 = 固定值」的比對，而不是每次都去撈另一張表。

如果用戶可能屬於多個租戶，你可以在每次 request 開始時把「目前選擇的租戶」存到 session 變數：

```sql
SET app.current_tenant_id = 'xxx-xxx-xxx';
```

然後函數去讀這個變數：

```sql
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN current_setting('app.current_tenant_id', true)::UUID;
END;
$$ LANGUAGE plpgsql STABLE;
```

這樣 Policy 的檢查就變成簡單的字串比對，超快。

---

## 有時候需要跳過 RLS

講完怎麼設定 RLS，還要講一個實務上一定會遇到的問題：**有時候你需要「跨租戶」操作**。

例如：你想寫一個 superadmin 報表，統計每個租戶有多少用戶。
這時候 RLS 會擋住你——你只能看到自己租戶的資料。

有兩種方式可以繞過。

### 方式一：SECURITY DEFINER 函數

你可以寫一個特殊的函數，用 `SECURITY DEFINER` 關鍵字標記。
這個函數會用**建立者的權限**執行，而不是呼叫者的權限。建立者通常是 superuser，不受 RLS 限制。

但這很危險。
如果函數寫錯，就會暴露不該暴露的資料。

所以用的時候要特別小心：函數內部要**自己做權限檢查**，確認呼叫者真的有權限。
不要因為可以繞過 RLS 就忘記驗證身份。

### 方式二：Service Role Key

Supabase 有兩種 API Key：

- **anon key**：給前端用，受 RLS 限制
- **service_role key**：給後端用，**繞過 RLS**

當你需要做跨租戶的操作（例如背景任務、webhook 處理），可以用 service_role key 建立一個 admin client。

**但絕對不要在前端用 service_role key**——這個 key 可以做任何事情，包括刪除所有資料。
後端使用時，也要自己做權限檢查，RLS 被繞過了，責任就在你的 code。

---

## 我現在怎麼做

經過幾次踩坑，我現在的架構大概是這樣：

**前端直接用 Supabase Client，一切受 RLS 保護。**
就算 code 寫錯，RLS 會擋住。安心。

**後端 API 需要跨租戶操作時，用 admin client。**
但要自己做權限檢查，確認呼叫者是 superadmin。

**RLS Policy 保持簡單。**
就是一個等式比對：`tenant_id = get_current_tenant_id()`。
不要在裡面放子查詢，效能會爆炸。

這樣的好處是：
- 前端不用擔心忘記加 `tenant_id`
- 複雜的跨租戶邏輯放在後端 API，有完整的權限控制
- Policy 保持簡單，效能有保障

---

RLS 解決的是「資料隔離」的問題。
讓資料庫自動擋住跨租戶的查詢，不用靠人記得加 WHERE。

但還有另一個問題：**網址怎麼區分不同租戶？**

`acme.example.com` 和 `beta.example.com` 怎麼對應到不同的 `tenant_id`？

這個會在下一篇《[Next.js 動態路由：一個網址架構服務 N 個租戶](/posts/multi-tenant-routing)》詳細講。
