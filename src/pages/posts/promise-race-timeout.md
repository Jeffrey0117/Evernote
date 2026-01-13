---
layout: ../../layouts/PostLayout.astro
title: Promise.race 處理 OCR 超時
date: 2026-01-13T11:40
description: 外部服務可能卡住，用 Promise.race 加上超時機制保護你的 API
tags:
  - JavaScript
  - Node.js
---

PasteV 用 Tesseract.js 做 OCR。

大部分圖片幾秒就辨識完了，但偶爾會遇到特別複雜的圖，跑了兩三分鐘還沒結果。

這時候使用者的請求就卡住了，API 沒有回應，體驗很差。

## 老樣子，先講 Promise 是什麼

JavaScript 是單執行緒的，一次只能做一件事。如果要等一個很慢的操作（讀檔案、打 API、OCR），整個程式就會卡住。

**Promise** 是 JavaScript 處理非同步操作的方式。它代表「一個未來會完成的事情」。

```typescript
// fetch 回傳一個 Promise
const promise = fetch('https://api.example.com/data');

// Promise 有三種狀態：
// - pending：還在跑
// - fulfilled：成功了，有結果
// - rejected：失敗了，有錯誤
```

用 `await` 可以等 Promise 完成：

```typescript
const response = await fetch('https://api.example.com/data');
// 程式會在這裡「暫停」，等 fetch 完成
// 但不會卡住整個 JavaScript，其他事件還是可以處理
```

## Promise 為什麼沒有內建超時

這是設計哲學的問題。

Promise 的職責是「代表一個非同步操作的結果」，它不管這個操作要花多久。超時是**使用者的需求**，不是操作本身的特性。

同一個 API 請求：
- 在前端可能要設 5 秒超時（使用者等不及）
- 在後端批次處理可能可以等 5 分鐘（沒人在等）

所以 Promise 把超時的決定權留給使用者，而不是內建死的時間。

## 問題：沒設超時就會一直等

```typescript
// 這個可能跑很久
const result = await Tesseract.recognize(imageBuffer, 'eng+chi_tra');
```

如果 Tesseract 卡住了，這行就會一直等。沒有任何機制可以說「等太久了，不要了」。

## Promise.race 是什麼

`Promise.race` 接受一個 Promise 陣列，**誰先完成就回傳誰的結果**，其他的不管了。

```typescript
const fast = new Promise(resolve => setTimeout(() => resolve('快'), 100));
const slow = new Promise(resolve => setTimeout(() => resolve('慢'), 5000));

const winner = await Promise.race([fast, slow]);
console.log(winner);  // '快'，不用等 5 秒
```

用這個特性，我們可以「讓計時器跟實際工作比賽」：

```typescript
const result = await Promise.race([
  actualWork(),      // 真正要做的事
  timeoutPromise(),  // 計時器，時間到就 reject
]);
```

如果計時器先完成（reject），整個 race 就會 reject，不用繼續等 actualWork。

## 包成工具函式

**工具函式**（Utility Function）就是把常用的邏輯抽出來，變成一個可以重複呼叫的函式。

為什麼要包？因為「Promise.race + 計時器」這個模式會一直重複用到。每次都寫一遍很煩，而且容易寫錯。包成函式之後，任何需要超時的地方都可以直接用。

```typescript
function withTimeout<T>(
  promise: Promise<T>,
  ms: number,
  errorMessage: string
): Promise<T> {
  // 建立一個計時炸彈
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => reject(new Error(errorMessage)), ms);
  });

  // 讓實際工作跟計時炸彈比賽
  return Promise.race([promise, timeout]);
}
```

`Promise<never>` 是 TypeScript 的寫法，表示這個 Promise 永遠不會 resolve，只會 reject。

## 使用方式

```typescript
const OCR_TIMEOUT = 120000; // 2 分鐘

try {
  const result = await withTimeout(
    Tesseract.recognize(imageBuffer, 'eng+chi_tra'),
    OCR_TIMEOUT,
    'OCR 處理超時，請嘗試較小的圖片'
  );
  // 成功，繼續處理 result
} catch (error) {
  // 可能是超時，也可能是 OCR 本身的錯誤
  console.error(error.message);
}
```

## 完整的 API endpoint

```typescript
router.post('/ocr', async (req, res) => {
  try {
    const imageBuffer = await fs.readFile(req.file.path);

    const result = await withTimeout(
      Tesseract.recognize(imageBuffer, 'eng+chi_tra', {
        logger: (m) => {
          if (m.status === 'recognizing text') {
            console.log(`OCR 進度: ${Math.round(m.progress * 100)}%`);
          }
        }
      }),
      120000,
      'OCR 處理超時，請嘗試較小的圖片'
    );

    res.json({ success: true, text: result.data.text });

  } catch (error) {
    res.status(500).json({
      error: 'OCR 處理失敗',
      details: error.message
    });
  }
});
```

## 注意：原本的 Promise 還是會繼續跑

`Promise.race` 只是讓你的程式不用繼續等，**但原本的操作不會被取消**。

```typescript
const slow = new Promise(resolve => {
  setTimeout(() => {
    console.log('我還是跑完了');
    resolve('slow');
  }, 5000);
});

const fast = new Promise(resolve => setTimeout(() => resolve('fast'), 100));

await Promise.race([slow, fast]);
// 馬上得到 'fast'
// 但 5 秒後 '我還是跑完了' 還是會印出來
```

如果要真正取消操作，需要用 [AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)：

```typescript
const controller = new AbortController();

setTimeout(() => controller.abort(), 5000);  // 5 秒後取消

const response = await fetch(url, { signal: controller.signal });
```

但不是所有 library 都支援 abort。Tesseract.js 就不支援，所以只能讓它在背景跑完。

對 API endpoint 來說，至少使用者不用一直等，server 可以早點回應。

---

## 回到 PasteV

加了 `withTimeout` 之後，OCR 卡住的問題解決了。

以前遇到複雜的圖片，使用者要等三分鐘才發現失敗。現在兩分鐘沒結果就會收到「處理超時，請嘗試較小的圖片」的提示，可以馬上換張圖重試。

API 也不會被一個卡住的請求堵住。Server 早點回應，資源早點釋放，其他使用者的請求也能正常處理。

這個模式後來在專案裡到處用：

| 場景 | 超時設定 |
|------|----------|
| OCR 辨識 | 2 分鐘 |
| LLM 翻譯 API | 30 秒 |
| 圖片下載 | 10 秒 |

只要是「可能會卡住」的外部操作，都包一層 `withTimeout`。程式碼多幾行，但使用者體驗好很多。

---

## 不是要你排隊，學會先搶先贏

**這個概念的核心**是「讓兩個 Promise 比賽」。

Promise.race 是 JavaScript 原生 API，不用裝套件。除了超時，還可以用在：

- **取最快的結果**：同時打多個 CDN，誰先回就用誰的
- **使用者取消**：使用者按取消按鈕，就 reject 那個 Promise
- **備援機制**：主要服務沒回應，就用備援的結果

任何「不想無限等待」的場景，都可以用這招。理解原理之後，你會發現很多卡住的問題都能用同一個模式解決。
