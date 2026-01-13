---
layout: ../../layouts/PostLayout.astro
title: node_modules 是黑洞，但你有三個選擇
date: 2026-01-14T01:41
description: npm、yarn、pnpm 三個套件管理器的差異與選擇
tags:
  - Node.js
  - 套件管理
  - JavaScript
---

上週我想快速改一行 bug，結果 `npm install` 跑了三分鐘。

三分鐘。改一行字。

這專案上禮拜才裝過依賴，但我換了電腦，又要重來一次。

打開硬碟一看，node_modules 佔了 800MB。我的程式碼才 50KB。

更慘的是，每個專案都有自己的 node_modules，十個專案就十份。

電腦裡可能有 47 份一模一樣的 `lodash@4.17.21`，佔了 94MB——就只是因為它們在不同專案裡。

這問題大家都知道，所以才會有三個套件管理器在搶市場。

## npm 還是老大哥

[npm](https://www.npmjs.com/) 是 Node.js 官方內建的套件管理器，裝 Node.js 就自動有了。

```bash
npm install lodash
```

優點是**到處都有**，不用另外裝任何東西。

### 我受不了的三件事

1. **慢**：早期版本的 npm 是出了名的慢，裝個依賴要等好久
2. **node_modules 肥到爆**：每個套件都完整複製一份，不會共用
3. **幽靈依賴**：你沒有在 package.json 裡直接宣告的套件，卻能 import 進來用。這是因為你裝的套件 A 依賴了套件 B，npm 順便裝了 B，你就偷偷能用。哪天 A 不再依賴 B，你的程式碼就炸了

npm 這幾年有改善，加了 cache、改進了演算法，速度比以前好很多。

但 node_modules 的結構問題還是在，這是設計上的先天限制。

## yarn 當年驚艷全場

2016 年，Facebook 受不了 npm 的問題，自己做了 [yarn](https://yarnpkg.com/)。

```bash
yarn add lodash
```

當年 yarn 一出來就驚艷全場：

- **快**：並行下載，比 npm 快很多
- **lock 檔**：`yarn.lock` 記錄每個套件的精確版本。沒有它的話，`lodash@^4.17.0` 可能今天裝 4.17.21，明天裝 4.18.0，結果程式碼就爆了。npm 後來也學了，叫 `package-lock.json`
- **離線模式**：裝過的套件會 cache，沒網路也能裝

### yarn PnP：不要 node_modules 了

後來 yarn 2 推出了 **Plug'n'Play（PnP）** 模式——名字是「插上就能玩」的意思，但實際上是「不用 node_modules 也能跑」。

```bash
yarn set version berry
yarn config set nodeLinker pnp
```

PnP 直接**不產生 node_modules 資料夾**。

對，你沒看錯。它用一個 `.pnp.cjs` 檔案記錄所有依賴的位置，Node.js 載入時去 cache 裡面找。

這解決了：
- **磁碟空間**：不用複製幾萬個檔案
- **安裝速度**：不用寫那麼多檔案到硬碟
- **幽靈依賴**：嚴格模式下，沒宣告的套件 import 不到

### 我踩過的坑

當年我信了 yarn PnP 的宣傳，把一個專案換過去。

結果 Jest 炸了、Webpack 炸了、連 VSCode 的 TypeScript 提示都壞了。

花了半天 debug，最後發現要裝一堆 `@yarnpkg/plugin-*`，還要改 `.yarnrc.yml`。

改完之後確實能跑，但心累。

生態系是越來越好，但還是會踩到坑。想深入了解可以看 [yarn 官方文件](https://yarnpkg.com/features/pnp)。

## pnpm 用硬連結解決一切

[pnpm](https://pnpm.io/) 的思路不一樣：node_modules 還是要有，但用**硬連結（hard link）**。

```bash
pnpm add lodash
```

它會把所有套件存在一個全域的 store 裡面（通常在 `~/.pnpm-store`），然後用硬連結指過去。

> 硬連結是什麼？簡單說，就是讓多個「檔名」指向硬碟上同一塊資料。不像複製會產生新檔案佔空間，硬連結就像是幫同一份檔案取了多個名字。

```
~/.pnpm-store/
  lodash@4.17.21/
    index.js
    ...

~/my-project/node_modules/
  lodash -> hard link to ~/.pnpm-store/lodash@4.17.21
```

十個專案用同一版 lodash，硬碟上只存一份。

這招兼顧了：
- **相容性**：node_modules 還是在，舊工具能用
- **省空間**：不會重複存檔案
- **速度**：建立硬連結比複製檔案快很多
- **嚴格依賴**：幽靈依賴問題也解決了

pnpm 現在越來越紅，很多大專案都在用。

## 所以我該用哪個

| | npm | yarn | pnpm |
|------|-----|------|------|
| **一句話** | 不用裝，最穩 | 想玩新概念 | 省空間首選 |
| **安裝** | Node.js 內建 | 要另外裝 | 要另外裝 |
| **速度** | 普通 | 快 | 最快 |
| **磁碟用量** | 肥 | PnP 模式很省 | 硬連結很省 |
| **相容性** | 最好 | PnP 有些坑 | 幾乎都 OK |

我自己的選擇：

**個人專案用 pnpm**。省空間、速度快、相容性好，沒什麼理由不用。

**公司專案看團隊**。如果大家都在用 npm，就別搞事。統一比效能重要。

**想嘗鮮可以玩 yarn PnP**。概念很酷，但要有心理準備踩坑。

## 但什麼時候該用哪個？

| 情境 | 選這個 |
|------|--------|
| 不想折騰、求穩 | npm |
| 想省硬碟空間 | pnpm |
| monorepo 專案 | pnpm 或 yarn |
| 公司專案已經在用的 | 別換，跟著用 |
| 想玩新東西 | yarn PnP |

**我自己的判斷：**
- 個人 side project → **pnpm**（省空間、夠快）
- 公司專案用 npm → **跟著用 npm**（統一比效能重要）
- monorepo、很多子專案 → **pnpm**（workspace 支援好）
- 想要最穩、最少問題 → **npm**（沒人會因為用 npm 被罵）
- 想挑戰自己 → **yarn PnP**（概念很酷，但要有心理準備）

說真的，三個都能用。選錯了頂多慢一點、肥一點，不會讓你的專案失敗。別糾結。

## 其他語言怎麼做

JavaScript 的套件管理一直被吐槽，那其他語言呢？

| 語言 | 套件管理器 | 特色 |
|------|-----------|------|
| Python | pip / uv / poetry | [各有優缺，uv 最近很紅](/Evernote/posts/python-package-managers) |
| Rust | Cargo | [公認最好用的套件管理器](/Evernote/posts/why-cargo-is-the-best) |
| Windows | winget / scoop | [系統層級的套件管理](/Evernote/posts/windows-package-managers) |
| Deno | 不需要 | [直接 import URL](/Evernote/posts/deno-no-package-manager) |

Rust 的 Cargo 常被拿來當標竿，Node.js 社群一直在想辦法追上。

Deno 更狠，直接說「不需要套件管理器」。

---

node_modules 的問題不會消失，但至少現在有選擇了。

npm 還是最穩的選項，yarn 和 pnpm 各有特色，看你在意什麼。

**都是裝套件，別糾結，挑順手的就對了。**
