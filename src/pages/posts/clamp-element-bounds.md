---
layout: ../../layouts/PostLayout.astro
title: 元素拖出畫布外就回不來了
date: 2026-01-13T12:00
description: 用 Math.min 和 Math.max 限制座標範圍，讓拖曳永遠在可見區域內
tags:
  - React
  - UX
---

PasteV 是我做的圖卡製作工具。創作者貼上外文素材，OCR 辨識文字，翻成中文蓋回原本的位置，快速產出中文版圖卡。

編輯器裡可以拖曳文字欄位調整位置。拖著拖著發現一個問題：欄位可以拖到畫布外面，然後就選不到、刪不掉了。

## 老樣子，先講 clamp 是什麼

**Clamp** 是「夾住」的意思。把一個數值限制在某個範圍內。

```typescript
// 數學寫法
clamp(value, min, max)

// 如果 value < min，回傳 min
// 如果 value > max，回傳 max
// 否則回傳 value
```

JavaScript 沒有內建 `clamp` 函式，但可以用 `Math.min` 和 `Math.max` 組合：

```typescript
// clamp(value, min, max)
const clamped = Math.max(min, Math.min(value, max));
```

這行有點繞，拆開來看：

```typescript
Math.min(value, max)  // 確保不超過上限
Math.max(min, ...)    // 確保不低於下限
```

## 問題：座標可以是負數或超大

拖曳的時候，座標是根據滑鼠位置計算的：

```typescript
const handleDrag = (e: MouseEvent) => {
  const newX = e.clientX - offset.x;
  const newY = e.clientY - offset.y;
  setPosition({ x: newX, y: newY });
};
```

滑鼠移到畫布外面，`newX` 和 `newY` 就會變成負數或超過畫布寬高。

元素跑到畫布外面，CSS 的 `overflow: hidden` 會讓它看不到。看不到就點不到，點不到就選不到，選不到就刪不掉。

使用者只能重新整理頁面。

## 解法：拖曳時 clamp 座標

```typescript
const handleDrag = (e: MouseEvent) => {
  const newX = e.clientX - offset.x;
  const newY = e.clientY - offset.y;

  // 限制在畫布範圍內
  const clampedX = Math.max(0, Math.min(newX, canvasWidth - elementWidth));
  const clampedY = Math.max(0, Math.min(newY, canvasHeight - elementHeight));

  setPosition({ x: clampedX, y: clampedY });
};
```

`canvasWidth - elementWidth` 是為了讓元素的**右邊界**不超出畫布，而不只是左上角。

## 還有一個情況：畫布縮小了

使用者可能先把欄位拖到 x=800 的位置，然後把畫布寬度從 1000 改成 600。

這時候欄位就在畫布外面了。

解法是用 `useEffect` 監聽畫布大小變化，自動把超出的欄位拉回來：

```typescript
useEffect(() => {
  const clampedFields = fields.map((field) => {
    const maxX = Math.max(0, canvasWidth - 50);  // 至少留 50px 可見
    const maxY = Math.max(0, canvasHeight - 30);

    const clampedX = Math.max(0, Math.min(field.x, maxX));
    const clampedY = Math.max(0, Math.min(field.y, maxY));

    // 只有真的需要調整才回傳新物件
    if (field.x !== clampedX || field.y !== clampedY) {
      return { ...field, x: clampedX, y: clampedY };
    }
    return field;
  });

  // 只有真的有變化才更新
  const needsUpdate = clampedFields.some((f, i) =>
    f.x !== fields[i].x || f.y !== fields[i].y
  );

  if (needsUpdate) {
    onFieldsChange(clampedFields);
  }
}, [canvasWidth, canvasHeight, fields]);
```

重點是 `needsUpdate` 的判斷。如果不判斷，每次 render 都會觸發 `onFieldsChange`，造成無限迴圈。

## 為什麼留 50px 而不是 0

```typescript
const maxX = Math.max(0, canvasWidth - 50);
```

如果 `maxX = canvasWidth - elementWidth`，元素剛好卡在邊界，只露出一點點邊角，很難點到。

留 50px 是為了確保至少有一塊區域可以讓使用者點擊選取。

這是 UX 的考量，不是技術必要。

---

## 回到 PasteV

加了座標 clamp 之後，欄位永遠不會消失在畫布外面。

使用者隨便拖，拖到邊界就會「卡住」，不會跑出去。畫布縮小的時候，超出的欄位會自動被拉回來。

這個修復很小，但使用體驗差很多。

---

## 不只是拖曳

Clamp 這個概念到處都能用：

| 場景 | 用法 |
|------|------|
| 拖曳限制範圍 | `clamp(x, 0, maxX)` |
| 縮放倍率 | `clamp(zoom, 0.1, 3)` |
| 音量控制 | `clamp(volume, 0, 100)` |
| 分頁索引 | `clamp(page, 0, totalPages - 1)` |
| 顏色值 | `clamp(rgb, 0, 255)` |

任何「數值不應該超出某個範圍」的場景，都可以用 clamp。

有些語言（像 CSS）有內建的 `clamp()` 函式，JavaScript 沒有，但自己寫一個也很簡單：

```typescript
function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(value, max));
}
```

三行 code，用一輩子。
