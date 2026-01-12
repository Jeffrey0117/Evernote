---
layout: ../../layouts/PostLayout.astro
title: 用 YouTube Playlist 當 NoSQL 資料庫
date: 2026-01-12T23:50
description: 一個異想天開、很北爛、很 POC 的專案，用 YouTube 免費幫你存資料
tags:
  - React
  - YouTube API
  - 北爛專案
---

我一直在想一個問題。

雲端資料庫要錢。Firebase 要錢、Supabase 免費額度用完要錢、自己架 server 更要錢。

對於一個只是想做 side project 的人來說，**光是資料庫這一塊就夠煩了**。

然後某天我在整理 YouTube 播放清單的時候，突然想到一件事。

## YouTube 其實是免費的雲端儲存

你想想看：

- YouTube 讓你上傳影片，**免費**
- 每部影片有標題、描述欄位，**你可以寫任何東西**
- 播放清單可以無限建立，**就像資料表**
- 有完整的 API 可以 CRUD

等等，這不就是一個免費的 NoSQL 資料庫嗎？

**Playlist = Table**
**Video = Document**
**Description = JSON Data**

我越想越覺得這個想法很北爛。

但也越想越覺得，**好像真的可以**。

## 所以我就做了一個

YouTubeDB——一個用 YouTube Playlist 當後端的 NoSQL 資料庫管理介面。

說真的，這個專案從頭到尾都透著一股「我就故意的」的氣息：

- 你建立一個 Playlist，它就是一張資料表
- 你新增一筆資料，它就上傳一個 1 秒的黑畫面影片
- 資料存在影片的 description 裡面，JSON 格式
- 支援 CRUD，有搜尋，有排序

完全不需要後端伺服器。完全免費。

## 技術上怎麼做的

整個專案是 React + TypeScript，用 Vite 建的。

核心就是 YouTube Data API v3，做了幾件事：

### 把 Playlist 當資料表

```typescript
// 建立新「資料表」
export async function createPlaylist(
  accessToken: string,
  title: string
): Promise<YouTubePlaylist> {
  const response = await fetch(`${BASE_URL}/playlists?part=snippet,status`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      snippet: { title, description: '' },
      status: { privacyStatus: 'unlisted' },
    }),
  });
  return response.json();
}
```

### 把影片描述當 JSON 欄位

新增資料的時候，會上傳一個最小的 WebM 影片（就是 1 秒黑畫面），然後把 JSON 資料塞在 description 裡面：

```typescript
const metadata = {
  snippet: {
    title: record.id,
    description: JSON.stringify(record), // 資料就存這裡
    categoryId: '22',
  },
  status: { privacyStatus: 'unlisted' },
};
```

讀取的時候就 parse 回來：

```typescript
const jsonData = JSON.parse(item.snippet.description);
return {
  id: item.snippet.title,
  ...jsonData,
};
```

### 分頁和重試

YouTube API 一次最多回傳 50 筆，所以要處理 pagination：

```typescript
do {
  const response = await fetchWithRetry(url.toString(), { ... });
  const data = await response.json();
  allItems.push(...(data.items || []));
  pageToken = data.nextPageToken;
} while (pageToken);
```

網路不穩的時候會自動重試，用指數退避：

```typescript
const delay = baseDelay * Math.pow(2, attempt);
await new Promise(resolve => setTimeout(resolve, delay));
```

## 這東西能幹嘛

老實說，**大部分情況下你不應該用這個**。

但有些場景還真的可以：

| 場景 | 為什麼可以 |
|------|----------|
| POC / Demo | 不想花錢架資料庫，先 demo 給人看 |
| 個人小工具 | 資料量不大，不需要正經後端 |
| 教學範例 | 展示 API 怎麼用，順便惡搞 |
| 純粹好玩 | 就...好玩啊 |

## 限制超多

當然，這東西限制一堆：

- **上傳有 quota** — YouTube API 每天有配額限制，大量寫入會爆
- **速度很慢** — 上傳影片要處理，不像真的資料庫那麼快
- **沒有 index** — 搜尋就是全撈出來 filter，資料多會很慢
- **沒有 transaction** — 沒有原子操作，race condition 要自己處理
- **Google 可能會 ban 你** — 用途太詭異可能違反 ToS

所以這真的就是一個 POC，一個「我就是想證明這個北爛想法可以動」的專案。

## 但說真的

這個專案讓我想到一件事。

很多時候我們被「正確的做法」框住了。資料庫就該用 PostgreSQL、MongoDB、Firebase。雲端儲存就該用 S3、GCS。

但其實很多服務都有「意料之外」的用法：

- GitHub Gist 可以當 JSON 儲存
- Google Sheets 可以當簡易資料庫
- Notion API 可以當 CMS
- 現在 YouTube Playlist 也可以當 NoSQL 了

這些用法正不正經？不正經。

能不能用？**能用**。

---

反正這個專案的精神就是：

**免費的最貴，但如果你夠北爛，免費的就是免費的。**

薅羊毛薅到 YouTube 頭上，也算是一種成就吧。
