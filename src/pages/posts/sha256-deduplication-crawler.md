---
layout: ../../layouts/PostLayout.astro
title: 爬蟲去重用 SHA256，不要傻傻比對標題
date: 2026-01-13T10:10
description: 做 PTT 爬蟲時踩到的去重問題，為什麼字串比對不夠用，要用 hash
tags:
  - Node.js
  - 爬蟲
  - 資料庫
---

做短網址工具的時候，有一個功能是自動爬 PTT 表特版的文章，產生短網址草稿。

爬蟲本身不難，難的是**去重**。

去重就是「判斷這篇抓過沒」。
PTT 每天都有新文章，爬蟲可能每小時跑一次。
如果不做去重，同一篇文章會被重複處理，資料庫裡出現一堆重複資料。

去重沒做好會怎樣？

我親身體驗過：短網址後台直接爆掉，同一個連結生成了四個不同的短網址。
使用者問我「為什麼同一篇文章出現四次」，我只能尷尬地說系統有 bug。
更慘的是，如果你的爬蟲會呼叫付費 API（像是 [OpenAI](https://openai.com/)），重複處理就是直接燒錢。

所以去重一定要做對。
聽起來很簡單對吧？比對一下標題，有就跳過？

沒那麼簡單。

## 第一個直覺：比對標題

第一版的去重邏輯是這樣：

```javascript
const existingTitles = await db.query('SELECT title FROM scraped_items');
const titleSet = new Set(existingTitles.map(item => item.title));

for (const post of posts) {
  if (titleSet.has(post.title)) {
    console.log('跳過重複:', post.title);
    continue;
  }
  // 處理...
}
```

看起來沒問題，對吧？

跑了一週，發現兩個問題。

**問題一：不同文章被誤擋**

PTT 每天都有人發「[正妹] 今天的女神」、「[正妹] 路上看到的」這種標題。用標題去重，第二篇之後全部被擋掉，但明明是不同文章、不同圖片。

**問題二：同文章被重複存**

更詭異的是，同一篇文章有時候又會被存多次。
後來發現是我自己的 bug — 標題欄位有時候會帶換行符號，`"台大校花"` 跟 `"台大校花\n"` 被判斷成不同。

結論：**標題不是唯一識別**。
不同文章可能同標題，同文章的標題字串也可能有細微差異。

那用 URL 呢？URL 是唯一的，不會有這問題。
但 PTT 的 URL 有時候超過 200 個字元，當資料庫 index 效能很差。

## 把 200 個字元壓成 64 個

問題整理一下：
- 標題不能當唯一識別（會重複）
- URL 可以當唯一識別，但太長，index 效能差

所以我需要一個方法：**把長字串變成固定長度的短字串，而且不會重複**。

這就是 hash 在做的事。

### 任意長度進去，固定長度出來

Hash（雜湊）是一種單向函數，輸入任意長度的資料，輸出固定長度的字串。

```
"https://www.ptt.cc/bbs/Beauty/M.1234567890.A.ABC.html"
    ↓ hash
"a1b2c3d4e5f6..." (固定 64 字元)
```

重點是：
- **固定長度**：不管輸入多長，輸出都一樣長
- **不可逆**：從 hash 值無法還原原本的輸入
- **抗碰撞**：不同的輸入幾乎不可能產生相同的輸出

常見的 hash 演算法有 [MD5](https://en.wikipedia.org/wiki/MD5)、[SHA-1](https://en.wikipedia.org/wiki/SHA-1)、[SHA-256](https://en.wikipedia.org/wiki/SHA-2) 等。
這篇文章介紹得蠻清楚的：[What Is Hashing?](https://www.geeksforgeeks.org/what-is-hashing/)。

Hash 最常見的用途是密碼儲存（資料庫不存明文密碼，存 hash 值），但其實拿來做去重也超好用。

### 所以我的做法

**把 URL 和標題組合起來，算一個 hash 值**。

[Node.js](https://nodejs.org/) 有內建的 `crypto` 模組，不用另外安裝：

```javascript
import crypto from 'crypto';

function generateSourceHash(post) {
  const content = `${post.url}|${post.title}`;
  return crypto.createHash('sha256').update(content).digest('hex');
}
```

為什麼這招有效？

URL 不同就是不同文章，就算標題一樣也不會搞混。
標題有換行符號、空格差異？全部算進 hash 裡，不用特別處理。
而且 64 個字元的 hex string（十六進位字串，只有 0-9 和 a-f）比一整個 URL 短，當 index 效能更好。

hash 出來的結果長這樣：

```
a1b2c3d4e5f6... (64 個字元)
```

存進資料庫，之後只要查 hash 有沒有存在就好。

## 碰撞？別想了

常見的 hash 演算法有 MD5 和 SHA256。

MD5 輸出 32 個字元，SHA256 輸出 64 個字元。
兩個速度差不多，但 MD5 已經被認為[不安全](https://security.stackexchange.com/questions/19906/is-md5-considered-insecure)，理論上可以被碰撞攻擊。
雖然爬蟲去重不需要密碼學等級的安全性，但既然 [SHA256](https://en.wikipedia.org/wiki/SHA-2) 一樣快，沒理由用舊的。

你可能會擔心：萬一兩篇不同文章算出一樣的 hash？

機率是 1/2^256，大概是 10^77 分之一。
宇宙的原子數量大概是 10^80 個，所以算出碰撞的機率，比隨機選中宇宙某顆原子還低。

別想了。

## 存進資料庫

流程很簡單：
1. 爬到一篇文章，算出 hash
2. 查資料庫有沒有這個 hash
3. 有 → 跳過，沒有 → 處理並存入

所以資料庫要存 hash，而且要能快速查詢。

### 表怎麼開

我用 [Supabase](https://supabase.com/) 當資料庫。
Supabase 是一個開源的 [Firebase](https://firebase.google.com/) 替代方案，底層跑的是 [PostgreSQL](https://www.postgresql.org/)（一種很成熟的關聯式資料庫）。
免費額度很夠用，而且有漂亮的後台可以直接看資料，很適合 side project。

想了解更多可以看 [Supabase 官方文件](https://supabase.com/docs)。

表結構長這樣：

```sql
CREATE TABLE scraped_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  robot_id UUID NOT NULL,
  source_url TEXT NOT NULL,
  source_hash TEXT NOT NULL,  -- 64 字元的 SHA256
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- 同一個機器人不能有重複的 hash
  UNIQUE(robot_id, source_hash)
);

-- 加 index 加速查詢
CREATE INDEX idx_scraped_items_hash ON scraped_items(robot_id, source_hash);
```

這裡有個細節：`UNIQUE(robot_id, source_hash)` 是複合唯一鍵。
因為我有多個爬蟲機器人，A 機器人爬過的文章 B 機器人可能還沒爬過。

### 查有沒有存在

爬蟲跑的時候，先算 hash，查有沒有存在：

```javascript
async function checkIsDuplicate(robotId, sourceHash) {
  const { data } = await supabase
    .from('scraped_items')
    .select('id')
    .eq('robot_id', robotId)
    .eq('source_hash', sourceHash)
    .limit(1);

  return data && data.length > 0;
}
```

如果不存在，就處理文章並把 hash 存進去。

## 讓資料庫幫你做事

上面的寫法可以動，但有個問題讓我很不爽。

前端這邊要寫 `.from('scraped_items').select('id').eq('robot_id', robotId).eq('source_hash', sourceHash).limit(1)`，一長串。

### 對了，這個寫法超經典

你可能會好奇，這種一路 `.` 下去的寫法是怎麼做到的？

這叫 **Method Chaining**（方法鏈）。
當年 [jQuery](https://jquery.com/) 就是靠這招紅遍全世界，讓一堆人愛上寫 JavaScript。

原理其實很簡單：每個 method 最後都 `return this`，所以可以一直串下去。

```javascript
// 簡化版原理
class QueryBuilder {
  from(table) { this.table = table; return this; }
  select(cols) { this.cols = cols; return this; }
  eq(col, val) { this.filters.push([col, val]); return this; }
}
```

這個設計模式叫 [Fluent Interface](https://en.wikipedia.org/wiki/Fluent_interface)，Martin Fowler 在 2005 年提出的。
之後有機會再寫一篇專門講這個，底層實作比想像中有趣。

想先了解的可以看這篇：[Method Chaining in JavaScript](https://www.geeksforgeeks.org/method-chaining-in-javascript/)。

### 但這樣寫有個問題

後來需求變了，要加「只檢查最近 30 天」，前端又要改。
再後來要 join 另一張表，前端又要改。

每次改需求，前端都要動。
而且這些邏輯散落在前端 code 裡，哪天換人接手，他要看懂整個前端才知道去重邏輯怎麼運作。

### 前端一行 code 搞定

後來我發現一招：**把邏輯寫在資料庫裡，前端只要呼叫一個 function**。

這招叫 RPC（Remote Procedure Call）。
你在 PostgreSQL 裡面寫一個 function，前端一行 code 呼叫它，不用自己組 SQL。

想深入了解可以看 [Supabase 官方的 RPC 文件](https://supabase.com/docs/guides/database/functions)。

### 這招屌在哪

聽起來好像只是換個地方寫 code，但意義完全不同。

**你在寫資料庫的時候，其實是在幫未來的前端省事。**

邏輯鎖在資料庫層，前端不用管實作細節，改需求也只改資料庫。

這讓我體會到一件事。
以前覺得「我是寫前端的，SQL 不關我事」。
現在發現會一點資料庫，前端 code 可以變超乾淨。

什麼都要懂一點，才能做出好東西。

### 先在資料庫建一個 function

在 Supabase 裡面：

```sql
CREATE OR REPLACE FUNCTION is_duplicate_item(
  p_robot_id UUID,
  p_source_hash TEXT,
  days_back INT DEFAULT 30
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM scraped_items
    WHERE robot_id = p_robot_id
      AND source_hash = p_source_hash
      AND created_at > NOW() - (days_back || ' days')::INTERVAL
  );
END;
$$ LANGUAGE plpgsql;
```

然後前端這樣呼叫：

```javascript
const { data, error } = await supabase.rpc('is_duplicate_item', {
  p_robot_id: robotId,
  p_source_hash: sourceHash,
  days_back: 30
});

// data 會是 true 或 false
```

一行搞定，不用自己寫 `.from().select().eq().eq()`。

### 但 RPC 有時候會掛

有個地方卡了我一陣子。

RPC 有時候會失敗，回傳 error 但文章其實是重複的。
可能是網路問題，也可能是 Supabase 那邊的暫時性錯誤。

這種情況如果直接當作「不重複」處理，就會產生重複資料。

所以我加了一個 fallback：

```javascript
if (error) {
  console.error('RPC 失敗，改用直接查詢');

  // fallback: 直接查表
  const { data: items } = await supabase
    .from('scraped_items')
    .select('id')
    .eq('robot_id', robotId)
    .eq('source_hash', sourceHash)
    .limit(1);

  return items && items.length > 0;
}
```

去重失敗的時候，寧可多擋誤殺，也不要放過重複的。
這種事錯一次就會被罵。

## 還有什麼選擇

| 方法 | 優點 | 缺點 | 適用場景 |
|------|------|------|----------|
| 標題比對 | 直覺好懂 | 空格、全半形會搞死你 | 資料格式 100% 可控時 |
| URL 當 unique key | 簡單暴力 | URL 太長，index 效能差 | URL 短且固定時 |
| **Hash 去重** | 固定長度、比對快 | 需要額外計算 | 任何情況都適用 |

我沒有用「URL 當主鍵」是因為 PTT 的 URL 有時候超過 200 個字元，當 index 效能不好。
hash 固定 64 個字元，查詢更快。

---

去重這種東西，做對了沒人發現，做錯了被罵到爆。

字串比對是最直覺的做法，但真實世界的資料髒得超乎想像。
hash 把所有變數壓縮成 64 個字元，比對起來乾淨俐落。

下次做爬蟲記得用 hash，不要傻傻比對字串。
