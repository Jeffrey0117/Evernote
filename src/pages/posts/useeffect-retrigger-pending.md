---
layout: ../../layouts/PostLayout.astro
title: 上傳五張圖，只處理了一張
date: 2026-01-13T12:05
description: 用 useEffect 監聽狀態變化，自動補跑漏掉的非同步任務
tags:
  - React
  - 非同步
---

做 PasteV 的時候遇到一個問題。這是給創作者用的圖卡翻譯工具，可以一次上傳多張素材圖，系統背景自動跑 OCR 辨識文字。

測試時發現：上傳五張圖，只有第一張被處理，其他四張卡在「等待中」不會動。

## 問題在哪

上傳圖片的流程：

```typescript
const handleUpload = async (files: File[]) => {
  // 1. 把檔案轉成 ImageData，狀態設為 'pending'
  const newImages = files.map(file => ({
    id: generateId(),
    file,
    status: 'pending',
  }));

  setImages(prev => [...prev, ...newImages]);

  // 2. 開始跑 OCR
  startDetection(newImages);
};
```

`startDetection` 會逐一處理圖片：

```typescript
const startDetection = async (imagesToProcess: ImageData[]) => {
  setIsDetecting(true);

  for (const img of imagesToProcess) {
    await runOcr(img);  // 每張圖跑 2-3 秒
  }

  setIsDetecting(false);
};
```

問題來了：**如果使用者在 OCR 跑到一半的時候又上傳了新圖片呢？**

```
時間軸：
0s   - 上傳圖片 A，開始 OCR
2s   - 使用者又上傳了圖片 B、C、D（此時 A 還在處理中）
3s   - A 處理完，isDetecting 變成 false
      - 但 B、C、D 沒有被處理，因為 startDetection 已經結束了
```

第二次上傳的時候，`startDetection(newImages)` 確實被呼叫了，但因為 `isDetecting` 是 `true`，函式可能有提前 return 的邏輯，或者狀態更新的時機不對。

總之結果就是：後來上傳的圖片永遠卡在 `pending`。

## 解法：用 useEffect 監聽「還有沒有漏掉的」

既然問題是「OCR 結束後沒有檢查還有沒有待處理的圖片」，那就加一個 useEffect 來補跑：

```typescript
useEffect(() => {
  // 只在「不是正在處理中」的時候檢查
  if (!isDetecting && images.length > 0) {
    // 找出還在 pending 的圖片
    const pendingImages = images.filter(img => img.status === 'pending');

    if (pendingImages.length > 0) {
      // 還有漏掉的，補跑
      startDetection(pendingImages);
    }
  }
}, [isDetecting, images, startDetection]);
```

這個 useEffect 的邏輯：

1. `isDetecting` 從 `true` 變成 `false`（OCR 結束）
2. useEffect 觸發，檢查有沒有 `status === 'pending'` 的圖片
3. 如果有，呼叫 `startDetection` 開始處理

這樣不管使用者什麼時候上傳，都不會漏掉。

## 為什麼不在 startDetection 裡面處理

你可能會想：乾脆在 `startDetection` 結束的時候再檢查一次不就好了？

```typescript
const startDetection = async (imagesToProcess: ImageData[]) => {
  setIsDetecting(true);

  for (const img of imagesToProcess) {
    await runOcr(img);
  }

  setIsDetecting(false);

  // 結束後再檢查一次？
  const stillPending = images.filter(img => img.status === 'pending');
  if (stillPending.length > 0) {
    startDetection(stillPending);  // 遞迴呼叫
  }
};
```

問題是 `images` 是 React state，在這個函式裡面拿到的是**呼叫當下的 snapshot**，不是最新的值。

使用者在 OCR 跑的過程中上傳的新圖片，不會出現在這個 `images` 裡面。

useEffect 就不一樣了。它的 dependency array 包含 `images`，所以每次 `images` 變化都會重新執行，拿到的永遠是最新的值。

## useEffect 的 dependency array

```typescript
useEffect(() => {
  // ...
}, [isDetecting, images, startDetection]);
```

這三個 dependency 的意思是：

- `isDetecting`：OCR 狀態變化時觸發
- `images`：圖片列表變化時觸發
- `startDetection`：函式變化時觸發（用 useCallback 包的話不會變）

只要其中一個變了，useEffect 就會重新執行。

## 避免無限迴圈

這個 pattern 有個風險：如果 `startDetection` 會改變 `images`，而 `images` 變化又會觸發 useEffect，可能會造成無限迴圈。

關鍵是 `startDetection` 會把 `status` 從 `'pending'` 改成 `'processing'` 或 `'done'`。

所以下次 useEffect 觸發的時候，`pendingImages` 會是空的，不會再呼叫 `startDetection`。

```typescript
if (pendingImages.length > 0) {  // 這個條件擋住了無限迴圈
  startDetection(pendingImages);
}
```

---

## 回到 PasteV

加了這個 useEffect 之後，不管使用者怎麼上傳，圖片都會被處理。

一次上傳 10 張、分三次上傳、邊上傳邊等結果——都沒問題。系統會自動把漏掉的補上。

使用者不需要知道這些，他們只會覺得「上傳就會處理，很順」。

---

## 這個 pattern 可以用在哪

任何「非同步任務 + 可能有新任務插進來」的場景：

| 場景 | 怎麼套用 |
|------|----------|
| 檔案上傳佇列 | 上傳完一個，檢查還有沒有待上傳的 |
| 訊息發送佇列 | 發完一則，檢查還有沒有待發送的 |
| 下載管理器 | 下載完一個，檢查還有沒有待下載的 |
| 批次 API 請求 | 處理完一批，檢查還有沒有新加入的 |

核心概念是：**不要假設任務列表是靜態的**。隨時可能有新任務加入，處理完要記得回頭看一眼。

useEffect 剛好是做這件事的好工具——它會在狀態變化時自動觸發，不需要手動輪詢。
