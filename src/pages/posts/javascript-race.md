---
layout: ../../layouts/PostLayout.astro
title: JavaScript 的賽跑問題
date: 2026-01-14T01:22
description: Race condition 是什麼？為什麼非同步程式碼會亂跑？
tags:
  - JavaScript
  - 觀念
---

如果你寫 JavaScript 要處理多筆資料，遲早會遇到這個問題。

比如說批次刪除使用者上傳的 100 張圖片，跑完發現只刪了 73 張。再跑一次，變 81 張。第三次，剩 12 張沒刪到。

這種「每次結果都不一樣」的 bug，叫 **race condition**。

## 什麼是 race condition

想像兩個人同時要改同一個檔案：

1. A 讀取檔案，內容是 `100`
2. B 讀取檔案，內容是 `100`
3. A 把內容改成 `100 + 50 = 150`，存檔
4. B 把內容改成 `100 + 30 = 130`，存檔

最後檔案內容是 `130`。

但正確答案應該是 `180` 才對。

這就是 race condition：**多個操作同時跑，結果取決於誰先完成，而不是你寫的順序**。

## JavaScript 為什麼會有這個問題

JavaScript 是單執行緒沒錯，但它有非同步。

```javascript
console.log('1');
setTimeout(() => console.log('2'), 0);
console.log('3');
```

輸出是 `1, 3, 2`，不是 `1, 2, 3`。

`setTimeout` 把 callback 丟到事件佇列，等目前的程式碼跑完才執行。

這就是問題的根源：**你寫的順序不等於執行的順序**。

## 壞的賽跑：forEach + async

最常見的 race condition 是 `forEach` 配 `async`：

```javascript
ids.forEach(async (id) => {
  await deleteRecord(id);
});
console.log('刪除完成');
```

你以為會一個一個刪，刪完才印「刪除完成」。

實際上 `forEach` 不管你的 `await`，瞬間發射所有請求，馬上印「刪除完成」。

100 個刪除請求同時打 API，互相踩來踩去，有的成功有的失敗，結果每次都不一樣。

詳細解釋和解法看這篇：[forEach 配 async 是個陷阱](/Evernote/posts/foreach-async-trap)

## 好的賽跑：Promise.race

但賽跑不一定是壞事。

有時候你就是要讓兩個東西比賽，誰先完成就用誰的結果：

```javascript
const result = await Promise.race([
  fetchFromCDN1(),  // 可能 200ms
  fetchFromCDN2(),  // 可能 150ms
]);
// 誰快就用誰，不用等慢的
```

最常見的用法是**超時機制**：

```javascript
const result = await Promise.race([
  slowOperation(),   // 可能跑很久
  timeout(5000),     // 5 秒後 reject
]);
// 5 秒內沒完成就放棄
```

讓「實際工作」跟「計時器」比賽。計時器贏了就代表超時，不用繼續等。

詳細實作看這篇：[Promise.race 處理 OCR 超時](/Evernote/posts/promise-race-timeout)

## 怎麼分辨好壞

| 情況 | 是不是問題 |
|------|-----------|
| 你預期順序執行，結果亂跑 | 是，要修 |
| 你故意讓它們比賽 | 不是，這是功能 |

關鍵在於：**你有沒有控制權**。

壞的 race condition 是你以為有順序，但其實沒有。

好的 race 是你故意設計的，你知道會發生什麼。

## 怎麼避免

需要順序執行？用 `for...of` 而不是 `forEach`：

```javascript
// 壞
ids.forEach(async (id) => await doSomething(id));

// 好
for (const id of ids) {
  await doSomething(id);
}
```

多個任務可以同時跑，但要等全部完成？用 `Promise.all`：

```javascript
// 壞：不等結果
ids.map(id => doSomething(id));

// 好：等全部完成
await Promise.all(ids.map(id => doSomething(id)));
```

不想無限等？用 `Promise.race` 設停損：

```javascript
await Promise.race([
  actualWork(),
  timeout(5000),
]);
```

最後，多個 async 同時改同一個變數一定會出事：

```javascript
let count = 0;
await Promise.all(ids.map(async () => {
  const current = count;
  await delay(100);
  count = current + 1;  // 結果不會是你想的
}));
```

共享狀態就是要排隊處理，沒有捷徑。

---

Race condition 不難理解，就是「順序亂了」。

難的是發現它。因為它不是每次都爆，有時候正常有時候不正常，debug 的時候又好了。

下次遇到「時好時壞」的 bug，先想想是不是 race condition。
