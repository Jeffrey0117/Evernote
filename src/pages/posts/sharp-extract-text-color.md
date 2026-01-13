---
layout: ../../layouts/PostLayout.astro
title: OCR 只給位置，顏色要自己抓
date: 2026-01-13T11:30
description: 用 Tesseract.js 做 OCR，再用 Sharp 從圖片中提取文字顏色
tags:
  - Node.js
  - 圖片處理
---

做 PasteV 的時候遇到一個問題：OCR 辨識出文字的位置了，但我還需要知道文字是什麼顏色。

翻譯後的文字要盡量保持原本的顏色，不然畫面會很突兀。

## Tesseract.js 給的資料

[Tesseract.js](https://github.com/naptha/tesseract.js) 是前端和 Node.js 都能用的 OCR 引擎，辨識結果長這樣：

```typescript
const result = await Tesseract.recognize(imageBuffer, 'eng+chi_tra');

// result.data.words 是每個字的資訊
{
  text: "Hello",
  bbox: { x0: 100, y0: 50, x1: 200, y1: 80 },
  confidence: 95
}
```

有文字內容、有位置（bounding box），但**沒有顏色**。

## 顏色要自己從圖片裡抓

知道位置就好辦了——去圖片的那個座標取樣像素。

我用 [Sharp](https://sharp.pixelplumbing.com/) 來處理。Sharp 是 Node.js 最快的圖片處理 library，底層用 libvips。

最直覺的寫法：

```typescript
for (const block of textBlocks) {
  const { data } = await sharp(imageBuffer)
    .extract({ left: block.x, top: block.y, width: 1, height: 1 })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const r = data[0], g = data[1], b = data[2];
}
```

問題是 OCR 一張圖可能辨識出幾十個文字區塊，每個都重新讀一次圖片，太慢了。

## 一次讀完，批量取樣

正確做法：**把整張圖的像素一次讀進記憶體，再用座標去查**。

```typescript
async function extractTextColors(
  imageBuffer: Buffer,
  blocks: Array<{ x: number; y: number; width: number; height: number }>
): Promise<string[]> {
  const image = sharp(imageBuffer);
  const metadata = await image.metadata();
  const { width: imgWidth = 0, height: imgHeight = 0 } = metadata;

  // 關鍵：一次把整張圖的 raw pixels 讀出來
  const { data, info } = await image
    .removeAlpha()  // 去掉 alpha channel，只留 RGB
    .raw()          // 輸出原始像素資料
    .toBuffer({ resolveWithObject: true });

  const colors: string[] = [];
  const channels = info.channels; // RGB = 3

  for (const block of blocks) {
    // 取文字區塊的中心點
    const centerX = Math.floor(block.x + block.width / 2);
    const centerY = Math.floor(block.y + block.height / 2);

    // 邊界檢查
    const x = Math.min(Math.max(centerX, 0), imgWidth - 1);
    const y = Math.min(Math.max(centerY, 0), imgHeight - 1);

    // 計算這個座標在 buffer 裡的位置
    const pixelIndex = (y * info.width + x) * channels;

    const r = data[pixelIndex] || 0;
    const g = data[pixelIndex + 1] || 0;
    const b = data[pixelIndex + 2] || 0;

    // 轉成 hex
    const hex = `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`.toUpperCase();
    colors.push(hex);
  }

  return colors;
}
```

## 為什麼取中心點

文字區塊的邊緣可能是背景色或模糊的邊界，中心點比較可能是文字本身的顏色。

這不是 100% 準確——如果文字是漸層色，或中心點剛好是空白，就會抓錯。

更精確的做法是多點取樣取眾數，但對我的場景來說中心點夠用了。

## raw() 的記憶體格式

`sharp().raw().toBuffer()` 回傳的是扁平的 `Buffer`，像素按順序排列：

```
[R, G, B, R, G, B, R, G, B, ...]
 ↑第一個像素  ↑第二個像素
```

如果沒有 `removeAlpha()`，會是 RGBA 四個 channel。

座標 (x, y) 對應的 index：

```
index = (y × 圖片寬度 + x) × channels
```

## 整合進 OCR 流程

```typescript
// 1. OCR 辨識
const result = await Tesseract.recognize(imageBuffer, 'eng+chi_tra');

// 2. 整理位置資訊
const rawBlocks = result.data.words.map(word => ({
  text: word.text,
  x: word.bbox.x0,
  y: word.bbox.y0,
  width: word.bbox.x1 - word.bbox.x0,
  height: word.bbox.y1 - word.bbox.y0,
}));

// 3. 批量取色（一次讀圖）
const colors = await extractTextColors(imageBuffer, rawBlocks);

// 4. 合併結果
const textBlocks = rawBlocks.map((block, i) => ({
  ...block,
  color: colors[i] || '#000000'
}));
```

50 個文字區塊跟 1 個的耗時差不多，因為只讀了一次圖。

---

這個模式適用於任何「知道座標，需要從圖片取資訊」的場景。重點是避免在迴圈裡重複讀取整張圖——先把像素讀進記憶體，再用座標查。
