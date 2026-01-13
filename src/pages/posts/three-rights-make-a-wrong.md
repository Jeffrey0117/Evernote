---
layout: ../../layouts/PostLayout.astro
title: 對、對、對，對了三次你就錯了
date: 2026-01-13T11:01
description: 每個選擇單獨看都對，合在一起就出包——軟體開發的組合拳陷阱
tags:
  - 觀念
---

最近踩了一個坑，細節寫在[另一篇](./localstorage-base64-trap)。

簡單說就是：Base64 預覽圖片（對）+ useEffect 監聽狀態（對）+ localStorage 自動存檔（對）= 瀏覽器噴 `QuotaExceededError`（爆）。

讓我想了很久的不是怎麼修，而是**為什麼每一步都沒錯，結果卻是錯的**。

## 這叫組合拳陷阱

軟體開發裡到處都是這種情況。每個決策單獨看都合理，但組合起來就出事。

## ORM + 迴圈查詢 + 流量 = N+1 問題

**ORM**（Object-Relational Mapping）是讓你用程式語言的物件來操作資料庫，不用寫 SQL。Django 的 Model、Rails 的 ActiveRecord、TypeORM 都是這類工具。

用 ORM 很方便，這沒問題。

在迴圈裡查資料庫，邏輯清楚好讀，這也沒問題。

系統上線，流量進來，問題就來了。

```python
# 顯示所有用戶和他們的訂單
users = User.objects.all()  # 1 次查詢，拿到 100 個用戶

for user in users:
    # 每個用戶都要再查一次訂單
    orders = Order.objects.filter(user_id=user.id)
    print(f"{user.name}: {len(orders)} 筆訂單")
```

這叫 **N+1 問題**：1 次查用戶 + N 次查訂單。100 個用戶就是 101 次資料庫查詢。

每次查詢都有網路延遲和資料庫 overhead。本機測試感覺不出來，上線後每個請求都要等半秒。

正確做法是用 `prefetch_related` 或 `JOIN` 一次撈完：

```python
# 2 次查詢搞定，不管有幾個用戶
users = User.objects.prefetch_related('orders').all()
```

## React 狀態提升 + 大量子元件 + 頻繁更新 = 卡頓

React 的 **re-render** 是指元件重新執行一次函式，計算新的 UI 長怎樣。父元件 re-render，所有子元件預設也會跟著 re-render。

**狀態提升**（lifting state up）是 React 官方推薦的模式：當多個元件需要共用狀態時，把狀態放到它們共同的祖先元件。

這個模式沒問題。把元件拆小、關注點分離，也沒問題。

但組合起來：

```tsx
function App() {
  // 狀態放在最上層
  const [searchText, setSearchText] = useState('');

  return (
    <div>
      <SearchBox value={searchText} onChange={setSearchText} />
      <ProductList />      {/* 100 個產品卡片 */}
      <Sidebar />          {/* 複雜的側邊欄 */}
      <Footer />           {/* 還有更多元件 */}
    </div>
  );
}
```

使用者在搜尋框打字，`searchText` 每打一個字就變一次。

每次變化，`App` 就 re-render，連帶底下**所有元件**都重新計算一遍——即使 `ProductList` 根本不需要 `searchText`。

100 個產品卡片 × 每秒打好幾個字 = 頁面變得很卡。

解法是用 `React.memo` 避免不必要的 re-render，或是把 `searchText` 往下移到真正需要它的地方。

## 快取 + 分散式系統 + 資料更新 = 不一致

**快取**（Cache）是把常用資料存在記憶體，下次直接讀記憶體，不用再去資料庫撈。Redis、Memcached 都是做這個的。

加快取能大幅提升效能，這沒問題。

系統拆成多台 server 做負載平衡，這也是標準架構。

但組合起來就有一致性問題。

用戶改了個人資料，Server A 收到請求，更新資料庫，清掉快取。

但 Server B 的快取還是舊的。

下一個請求剛好打到 Server B，讀到舊資料，用戶看到的還是改之前的狀態。

```
用戶 → Server A → 更新 DB → 清 Server A 快取 ✓
用戶 → Server B → 讀 Server B 快取 → 舊資料 ✗
```

更慘的是快取穿透、快取雪崩這些問題——大量請求同時打到資料庫，直接把 DB 打掛。

分散式快取不是不能用，但要處理失效策略、一致性協議、fallback 機制。「加個快取」從來不是三行 code 的事。

## LLM API + 逐筆請求 + 大量資料 = 又慢又貴

用 LLM API 做翻譯，品質比傳統翻譯 API 好很多，這沒問題。

每個文字欄位獨立送出翻譯請求，邏輯簡單好維護，這也沒問題。

但資料量一大就爆了。

我在做 PasteV 的時候遇到這個：100 張圖片，每張圖 OCR 出 5 個文字欄位，總共 500 段文字要翻譯。

```typescript
// 看起來很正常
for (const image of images) {
  for (const field of image.fields) {
    const translated = await translateAPI(field.text);  // 每次都打一次 API
    field.translatedText = translated;
  }
}
```

500 次 API 請求。

每次請求大概 500ms，串起來就是 4 分多鐘。而且 LLM API 按 token 計費，500 次請求的費用也很可觀。

更慘的是很多 API 有 rate limit，每分鐘只能打 60 次，直接被擋下來。

解法是**批次處理**：把多段文字合成一個請求，請 LLM 一次翻譯完再拆開。

```typescript
// 把 500 段文字分成 10 批，每批 50 段
const batches = chunk(allTexts, 50);
for (const batch of batches) {
  const prompt = `翻譯以下文字，用 JSON 陣列回傳：\n${JSON.stringify(batch)}`;
  const results = await translateAPI(prompt);  // 10 次請求搞定
}
```

500 次變 10 次，速度快 50 倍，費用也省很多。

但這需要額外處理：怎麼組 prompt、怎麼 parse 回傳的 JSON、單筆失敗怎麼 fallback。「每筆獨立請求」的寫法確實比較簡單，只是放大之後就撐不住了。

## 為什麼會這樣

因為我們學東西的時候，都是**一個一個學**。

「Base64 怎麼用」「useEffect 怎麼用」「localStorage 怎麼用」。

但實際開發是**全部混在一起用**。

每個工具都有它的假設和限制：

| 工具/模式 | 隱藏的代價 |
|-----------|------------|
| Base64 | 資料膨脹 33%，吃記憶體 |
| ORM 查詢 | 每次都有網路往返和 DB overhead |
| 狀態提升 | 父元件改變，子元件全部重算 |
| 本地快取 | 多台機器之間不會自動同步 |
| 外部 API 請求 | 有延遲、有費用、有 rate limit |

教學文章通常只講「怎麼用」，不講「用了會怎樣」。

這些隱藏代價在小規模的時候不明顯，放大之後就會互相疊加。

## 怎麼降低踩坑機率

沒辦法完全避免，但可以養成幾個習慣。

**學工具的時候，順便學它的代價。** 不只學「怎麼用」，也要知道「用了會怎樣」。localStorage 有 5MB 限制、ORM 每次查詢都有 overhead、狀態提升會觸發整棵樹更新、快取要處理一致性、外部 API 有 rate limit。知道代價，才知道什麼組合會出事。

**寫完 code，在腦中跑一遍資料流。**「這個資料有多大？會經過哪些地方？會被呼叫幾次？」很多組合拳問題，在腦中模擬一遍就會發現。

**測試的時候，專門測邊界情況。** 不要只測 happy path。一張圖可以，十張呢？一個 user 可以，一百個呢？邊界情況是組合拳最容易爆發的地方。

**設計的時候，問「如果 X 變成 100 倍會怎樣」。** 很多組合在小規模的時候完全正常，放大之後才會爆。N+1 問題在本機測不出來、快取不一致在單機測不出來、級聯故障在流量小的時候測不出來。所以要在腦中先放大，或者真的寫壓力測試。

---

軟體開發沒有銀彈。

每個「Best Practice」都有它的適用範圍。

超出範圍，最佳實踐就變成最佳踩坑。
