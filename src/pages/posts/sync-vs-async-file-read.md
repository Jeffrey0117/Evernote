---
layout: ../../layouts/PostLayout.astro
title: 一個人在讀檔案，全世界都要等他
date: 2026-01-13T12:10
description: Node.js 的 readFileSync 會卡住整個 server，改用 await fs.readFile 才對
tags:
  - Node.js
  - 效能
---

PasteV 的後端有一支 OCR API，接收圖片、辨識文字、回傳座標和內容。整個翻譯流程的起點。

本機測都很順，上線後偶爾收到回報：「API 怎麼突然變很慢？」

查 log 發現：某個使用者傳了一張 8MB 的圖，其他人的請求全部卡住，等那張圖讀完才繼續。一個人慢，全世界陪他等。

## 老樣子，先講 Node.js 的執行模型

Node.js 是**單執行緒**的。只有一個主執行緒在跑你的 JavaScript 程式碼。

但它可以處理大量併發請求，靠的是 **Event Loop** 機制：

```
收到請求 A → 開始讀檔案（交給作業系統）→ 不等，繼續處理請求 B
                                           ↓
收到請求 B → 開始查資料庫（交給作業系統）→ 不等，繼續處理請求 C
                                           ↓
檔案讀完了 → 執行 A 的 callback
資料庫查完了 → 執行 B 的 callback
```

關鍵是「**不等**」。把耗時的 I/O 操作交給作業系統，主執行緒繼續做其他事。

## Sync 函式會卡住 Event Loop

Node.js 的 `fs` 模組有兩種版本的函式：

```typescript
// 同步版本 - 會等
const data = fs.readFileSync('/path/to/file');

// 非同步版本 - 不會等
const data = await fs.promises.readFile('/path/to/file');
// 或
fs.readFile('/path/to/file', (err, data) => { ... });
```

`readFileSync` 的 **Sync** 就是 Synchronous（同步）的意思。它會**卡住主執行緒**，直到檔案讀完。

```
時間軸（使用 readFileSync）：
0ms   - 收到請求 A，開始讀 8MB 檔案
0ms   - 收到請求 B... 但主執行緒被卡住了，沒辦法處理
0ms   - 收到請求 C... 也在排隊
500ms - A 的檔案讀完了，主執行緒解放
500ms - 開始處理 B
```

一個人在讀大檔案，其他人全部排隊等。

## 改成 async 就好了

```typescript
// 之前
import fs from 'fs';

router.post('/ocr', async (req, res) => {
  const imageBuffer = fs.readFileSync(req.file.path);  // 卡住！
  const result = await Tesseract.recognize(imageBuffer);
  res.json(result);
});

// 之後
import fs from 'fs/promises';

router.post('/ocr', async (req, res) => {
  const imageBuffer = await fs.readFile(req.file.path);  // 不卡
  const result = await Tesseract.recognize(imageBuffer);
  res.json(result);
});
```

`fs/promises` 是 Node.js 提供的 Promise 版本 fs 模組，所有函式都是非同步的，可以用 `await`。

改完之後：

```
時間軸（使用 await fs.readFile）：
0ms   - 收到請求 A，開始讀 8MB 檔案（交給 OS）
0ms   - 收到請求 B，馬上開始處理
0ms   - 收到請求 C，馬上開始處理
500ms - A 的檔案讀完了，繼續處理 A
```

每個請求獨立處理，不會互相卡住。

## 常見的 Sync 函式

這些都有 Sync 版本，都會卡住 Event Loop：

| Sync 版本 | Async 版本 |
|-----------|------------|
| `fs.readFileSync()` | `await fs.promises.readFile()` |
| `fs.writeFileSync()` | `await fs.promises.writeFile()` |
| `fs.existsSync()` | `await fs.promises.access()` |
| `fs.mkdirSync()` | `await fs.promises.mkdir()` |
| `fs.readdirSync()` | `await fs.promises.readdir()` |
| `child_process.execSync()` | `await promisify(exec)()` |

## 什麼時候可以用 Sync

程式啟動的時候：

```typescript
// 啟動時讀設定檔，只跑一次，可以用 Sync
const config = JSON.parse(fs.readFileSync('./config.json', 'utf-8'));

// 啟動時建立資料夾，只跑一次，可以用 Sync
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads', { recursive: true });
}

// 之後開始接收請求
app.listen(3000);
```

程式還沒開始接收請求，沒有人會被卡住，用 Sync 沒問題。

但在 **request handler 裡面**，絕對不要用 Sync。

## 怎麼檢查有沒有用到 Sync

用 ESLint 可以自動檢查：

```javascript
// .eslintrc.js
module.exports = {
  rules: {
    'no-sync': 'warn',  // 警告使用 Sync 函式
  },
};
```

或者直接在專案裡搜尋 `Sync(`：

```bash
grep -r "Sync(" src/
```

---

## 回到 PasteV

把 `readFileSync` 改成 `await fs.readFile` 之後，那個「一個人卡住全部人」的問題就消失了。

改動很小，就一個單字的差別。但對多人同時使用的 server 來說，影響很大。

---

## 記住這個原則

在 Node.js server 裡：

- **啟動時**可以用 Sync（讀設定、建資料夾）
- **處理請求時**一律用 Async（讀檔案、寫檔案、呼叫外部 API）

只要看到 `Sync` 結尾的函式出現在 route handler 裡，就應該警覺。

一個人慢，不應該拖累其他人。這是 server 的基本禮儀。
