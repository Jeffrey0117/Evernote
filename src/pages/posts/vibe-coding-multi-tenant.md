---
layout: ../../layouts/PostLayout.astro
title: Vibe Coding 知識庫：Multi-Tenant 篇
date: 2026-01-14T10:00
description: 讓 AI 幫你寫多租戶 SaaS 之前，你自己要先懂這些概念
tags:
  - Vibe Coding
  - Multi-Tenant
  - SaaS
  - AI
---

你想做一個平台，讓很多人可以用。

每個人有自己的帳號、自己的資料、自己的後台。

像 [Notion](https://www.notion.so/) 那樣，每個 workspace 是獨立的。

像 [Shopify](https://www.shopify.com/) 那樣，每個商家有自己的店。

這種架構叫 **Multi-Tenant（多租戶）**。

你不用會寫程式也能做，讓 AI 幫你寫就好。

但有個前提：**你要懂概念，AI 才知道怎麼實作。**

---

## AI 不會幫你想架構

這是很多人踩的坑。

你跟 AI 說「幫我做一個課程平台」，它會生出一堆 code。

看起來會動，但資料隔離沒做好。

結果 A 客戶看到 B 客戶的課程。

這不是 bug，這是資安事故。

**AI 很會寫 code，但它不會主動幫你想「這個系統要怎麼設計才安全」。**

這是你的工作。

---

## Multi-Tenant 是什麼

用一個比喻來說。

你蓋了一棟公寓大樓，租給很多住戶。

- 大樓是你的系統
- 每一戶是一個租戶（客戶）
- 大家共用電梯、水電（共用程式碼和資料庫）
- 但每戶的東西是分開的（資料隔離）

重點是最後一項：**資料要隔離**。

A 住戶不能跑進 B 住戶家裡翻東西。

技術上怎麼做？我寫了一篇詳細講：

👉 [從自架課程網站到 SaaS 平台，我才搞懂什麼是 Multi-Tenant](/posts/multi-tenant-saas-architecture)

---

## 不懂這些概念會怎樣？

讓我用「不懂 → 爆炸 → 正解」的方式講。

### 1. 資料沒有 tenant_id

**不懂的人會這樣做：**

直接開一張 `courses` 表，裡面有 `id`、`title`、`price`。

**然後爆炸：**

所有租戶的課程混在一起。A 講師看到 B 講師的課程。

更慘的是，A 講師可以刪掉 B 講師的課程。

**正解：**

每張表都要有 `tenant_id` 欄位，標記「這筆資料屬於哪個租戶」。

👉 [從自架課程網站到 SaaS 平台，我才搞懂什麼是 Multi-Tenant](/posts/multi-tenant-saas-architecture)

### 2. 查詢沒有自動過濾

**不懂的人會這樣做：**

有了 `tenant_id`，但查資料的時候忘記加 `WHERE tenant_id = ?`。

**然後爆炸：**

某天某個頁面漏加這個條件，資料就外洩了。

人會忘記，AI 也會忘記。

**正解：**

用 **RLS（Row-Level Security）**，讓資料庫自動過濾。

就算程式忘記加 WHERE，資料庫也會擋住。

👉 [讓資料庫自動擋住跨租戶查詢](/posts/multi-tenant-rls)

### 3. 網址沒有區分租戶

**不懂的人會這樣做：**

所有租戶共用同一個網址，用 query string 區分：`platform.com/courses?tenant=123`。

**然後爆炸：**

網址醜、不專業。

講師分享課程連結，學生看到的是「某個平台的某個人」，不是「這是 Jeff 的網站」。

**正解：**

用子路徑區分：`platform.com/jeff/courses`。

讓每個租戶有自己的「門面」。

👉 [用 Next.js 動態路由讓每個租戶有自己的網址](/posts/multi-tenant-routing)

### 4. 權限綁在 user 身上

**不懂的人會這樣做：**

在 `users` 表加一個 `role` 欄位，`user.role = 'admin'`。

**然後爆炸：**

Jeff 在自己公司是老闆，在別人公司是客戶。

但 `role` 只能存一個值。

Jeff 變成 admin 之後，跑去別人的租戶也變成 admin 了。

**正解：**

權限要綁在「user 和 tenant 的關係」上。

開一張 `user_tenant_access` 表，記錄「誰在哪個租戶是什麼角色」。

👉 [當一個用戶同時屬於三個租戶](/posts/multi-tenant-permissions)

### 5. 沒有白牌功能（選配）

**不懂的人會這樣做：**

所有租戶的頁面長得一模一樣，都掛著平台的 Logo。

**然後爆炸：**

講師覺得這不是「他的網站」，只是「借用別人的平台」。

高端客戶不會買單。

**正解：**

讓租戶可以換 Logo、換顏色、換 Favicon。

這叫「白牌」——平台退到幕後，讓客戶站到台前。

👉 [白牌是什麼？讓平台退到幕後的品牌魔法](/posts/multi-tenant-branding)

---

## 給 AI 的 Prompt

當你要開始做的時候，複製這段給 AI：

<div style="position: relative; background: #EFEBE5; border: 1px solid #DDD7CE; border-radius: 6px; padding: 1rem; margin: 1rem 0;">
  <pre id="prompt-text" style="margin: 0; white-space: pre-wrap; font-family: 'IBM Plex Mono', monospace; font-size: 0.85rem;">我要做一個多租戶的 SaaS 平台。

請確保：
1. 每張資料表都有 tenant_id 欄位
2. 使用 RLS（Row-Level Security）自動過濾租戶資料
3. 權限用 user_tenant_access 中間表，記錄「誰在哪個租戶是什麼角色」
4. 支援同一個用戶屬於多個租戶，在不同租戶有不同角色
5. 網址用 /[tenantSlug]/ 的子路徑結構區分租戶

如果你不確定怎麼做，先問我，不要亂猜。</pre>
  <button onclick="navigator.clipboard.writeText(document.getElementById('prompt-text').innerText).then(() => { this.innerText = '已複製!'; setTimeout(() => this.innerText = '複製', 1500); })" style="position: absolute; top: 0.5rem; right: 0.5rem; font-family: 'IBM Plex Mono', monospace; font-size: 0.75rem; padding: 0.3em 0.8em; background: #2C2C2C; color: #F9F7F4; border: none; border-radius: 3px; cursor: pointer;">複製</button>
</div>

這段 prompt 會讓 AI 知道你要的架構是什麼。

不給這些指示，AI 會自己亂猜，通常猜錯。

---

## 你要檢查的事

AI 寫完之後，你要檢查：

**資料表有沒有 tenant_id？**

打開資料庫，看每張表的欄位。

**RLS 有沒有開？**

在 [Supabase](https://supabase.com/) 裡面，每張表要設定 Policy。

**權限是怎麼存的？**

應該要有一張 `user_tenant_access` 表，裡面有 `user_id`、`tenant_id`、`role`。

如果權限是寫在 `users` 表的某個欄位裡，那就是錯的。

---

## 還是不懂？

這篇只是概念總覽。

每個主題我都有寫詳細的文章：

1. [Multi-Tenant 是什麼？三種隔離策略怎麼選](/posts/multi-tenant-saas-architecture)
2. [用 RLS 讓資料庫自動擋住跨租戶查詢](/posts/multi-tenant-rls)
3. [用 Next.js 動態路由區分租戶](/posts/multi-tenant-routing)
4. [多租戶權限設計](/posts/multi-tenant-permissions)
5. [白牌功能怎麼做](/posts/multi-tenant-branding)

先讀完這些，再開始 vibe coding。

不然 AI 寫錯了，你也看不出來。
