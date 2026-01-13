---
layout: ../../layouts/PostLayout.astro
title: localStorage 存圖片 Base64 的大坑
date: 2026-01-13T10:58
description: 做自動存檔功能時踩到的 localStorage 容量限制，以及怎麼處理
tags:
  - React
  - JavaScript
---

我在做一個圖片翻譯工具叫 PasteV。

用途是這樣：上傳一張英文的社群圖片，OCR 辨識文字，翻譯成中文，然後輸出一張新的圖。

做內容行銷的人會用到，把國外的素材翻成中文版。

這次踩的坑很有意思——不是因為我做錯什麼，而是**三個正確的決策組合在一起，就爆了**。

## 第一個正確決策：圖片預覽用 Base64

使用者上傳圖片後，要在網頁上顯示預覽。

前端標準做法是用 `FileReader.readAsDataURL`，把圖片轉成 Base64 字串：

```typescript
const reader = new FileReader();
reader.onload = (event) => {
  const base64 = event.target?.result as string;
  // base64 長這樣：data:image/png;base64,iVBORw0KGgo...
};
reader.readAsDataURL(file);
```

然後就可以直接塞進 `<img src={base64} />`，不用另外建立 Object URL。

這是前端的標準做法，沒毛病。

## 第二個正確決策：用 useEffect 監聽狀態

想讓使用者重新整理頁面後，進度還在。

狀態變了就做某件事，用 `useEffect` 加 dependency array。

```typescript
useEffect(() => {
  // 狀態變了就存檔
  saveToStorage(data);
}, [data]);
```

React 官方推薦的寫法，沒毛病。

## 第三個正確決策：自動存檔用 localStorage

[localStorage](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage) 是瀏覽器內建的，不用裝套件，API 簡單。

```typescript
localStorage.setItem('session', JSON.stringify(data));
```

聽起來也沒毛病。

## 三個加在一起就爆了

把三個決策組合起來：

```typescript
useEffect(() => {
  const data = { images, fieldTemplates, canvasSettings };
  // images 裡面有圖片的 Base64
  localStorage.setItem('session', JSON.stringify(data));
}, [images, fieldTemplates, canvasSettings]);
```

上傳幾張圖片，瀏覽器 console 噴錯：

```
QuotaExceededError: Failed to execute 'setItem' on 'Storage':
The quota has been exceeded.
```

這是瀏覽器在說：**儲存空間滿了**。

## 一開始以為是 JSON 的問題

我第一反應是 `JSON.stringify` 壞掉了。

花了半小時在那邊 debug，檢查有沒有 circular reference、有沒有特殊字元。

結果根本不是那個問題。

## 後來想說壓縮看看

Google 了「compress base64 javascript」，找到 [lz-string](https://github.com/pieroxy/lz-string) 這個壓縮 library。

試了一下，字串確實變小了。

但還是爆。

因為問題不在壓縮，是 **localStorage 本身就只有 5MB 左右**。

## Base64 本來就很肥

[Base64](https://en.wikipedia.org/wiki/Base64) 是把二進位資料轉成純文字的編碼方式。

但它不是壓縮，**反而會讓資料變大約 33%**。

原理是這樣：每 3 bytes 轉成 4 個字元。

比如 `Man`（3 bytes）會變成 `TWFu`（4 字元）。

所以一張 1MB 的圖片，Base64 後會變成 1.33MB。

存兩三張就把 localStorage 塞爆了。

## 為什麼三個「對」會變成「錯」

| 決策 | 單獨來看 | 組合起來的問題 |
|------|----------|----------------|
| 預覽用 Base64 | 前端標準做法 | 資料膨脹 33% |
| useEffect 監聽 | React 標準做法 | 每次變化都觸發存檔 |
| 存檔用 localStorage | 簡單方便 | 只有 5MB 限制 |

每個工具都有它的邊界。單獨用的時候不明顯，混在一起就撞牆了。

## 怎麼解決

有幾個方向：

| 方案 | 定位 | 優點 | 缺點 |
|------|------|------|------|
| 不存圖片 | 懶人首選 | 最簡單 | 重新整理就沒圖了 |
| 用 [IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API) | 正規解法 | 容量大（幾百 MB） | API 很醜 |
| 存前檢查大小 | 救急用 | 不用改架構 | 超過還是會丟資料 |

如果圖片不大、數量不多，第三個方案就夠用了。

正經的生產環境還是乖乖用 IndexedDB。

我選了「存前檢查大小」，因為改動最小。

## 存之前先量體重

關鍵是用 [Blob](https://developer.mozilla.org/en-US/docs/Web/API/Blob) 來算 JSON 字串的實際大小：

```typescript
const dataString = JSON.stringify(data);
const dataSizeKB = new Blob([dataString]).size / 1024;
```

為什麼不用 `dataString.length`？

因為 JavaScript 字串內部是 UTF-16 編碼。

`'a'.length` 是 1，`'中'.length` 也是 1，但實際佔的 bytes 不一樣。

Blob 算的才是真正存進去的大小。

## 超過就只存 metadata

第一版我直接 `return` 不存。

結果使用者說：「我設定了半天的欄位模板怎麼不見了？」

對欸，圖片可以重傳，但設定不能丟。

所以改成：**圖片砍掉，其他留著**。

```typescript
if (dataSizeKB > 4500) {
  // 圖片只存前 100 字元當標記
  const metadataImages = images.map(img => ({
    ...img,
    originalImage: img.originalImage.substring(0, 100) + '...[truncated]'
  }));

  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    images: metadataImages,
    fieldTemplates,
    canvasSettings,
    _truncated: true  // 標記資料被截斷
  }));
}
```

## try-catch 也要加

就算檢查了大小，還是可能爆。

因為同一個 origin 下的所有頁面共用同一個 localStorage。

你在 `localhost:3000/app` 存的，`localhost:3000/editor` 也看得到。

別的頁面塞了一堆東西，你這邊就爆了。

所以外面還是要包 try-catch：

```typescript
try {
  localStorage.setItem(key, data);
} catch (e) {
  console.error('存檔失敗:', e);
  // 最後手段：只存最重要的設定
  try {
    localStorage.setItem(key + '_backup', JSON.stringify({
      fieldTemplates,
      canvasSettings
    }));
  } catch {
    // 真的救不了就算了
  }
}
```

---

## 其實從頭就不該用 Base64 存

Base64 的設計初衷是**傳輸**，不是儲存。

它是為了在只支援文字的環境（像 email、JSON）裡傳送二進位資料。

把它存進 localStorage 是用錯地方了——硬把二進位轉成文字，體積還膨脹 33%。

### 顯示預覽不需要 Base64

其實前端顯示圖片預覽，用 [URL.createObjectURL()](https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL_static) 更好：

```typescript
const file = e.target.files[0];
const objectUrl = URL.createObjectURL(file);
// objectUrl: "blob:http://localhost:3000/xxxx-xxxx"
```

Object URL 只是一個指向記憶體的參照，不會像 Base64 那樣複製一份肥大的字串。

用完記得 `URL.revokeObjectURL()` 釋放記憶體。

### 儲存要用 IndexedDB + Blob

[IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API) 可以直接存 Blob 和 File 物件，不用轉成文字：

```typescript
// 存
const db = await openDB('myApp', 1);
await db.put('images', file, 'image-1');  // 直接存 File 物件

// 取
const file = await db.get('images', 'image-1');
const url = URL.createObjectURL(file);
```

容量有幾百 MB，而且存的是原始二進位，不會膨脹。

### 如果真的要壓小一點

可以用 Canvas 轉成 WebP：

```typescript
const canvas = document.createElement('canvas');
const ctx = canvas.getContext('2d');
ctx.drawImage(img, 0, 0);

// 轉成 WebP，品質 0.8
canvas.toBlob((blob) => {
  // blob 會比原圖小很多
}, 'image/webp', 0.8);
```

WebP 的壓縮率比 JPEG 好，同樣品質體積更小。

但這會損失畫質，要看你的場景能不能接受。

## 我的情況

我目前還是用「存前檢查大小」的土方法撐著。

因為 PasteV 的圖片最後都會輸出成新的圖，原圖丟了也沒差。

但如果是要保留原圖的場景，乖乖用 IndexedDB 才是正解。

## 延伸閱讀

- [對、對、對，對了三次你就錯了](./three-rights-make-a-wrong) — 這種「組合拳陷阱」不只這個例子，軟體開發裡到處都是
- [localForage](https://github.com/localForage/localForage) — 把 IndexedDB 包成像 localStorage 一樣簡單
- [idb](https://github.com/jakearchibald/idb) — Jake Archibald 寫的輕量 IndexedDB wrapper
- [Storage for the Web](https://web.dev/articles/storage-for-the-web) — 各種瀏覽器儲存方案的比較
