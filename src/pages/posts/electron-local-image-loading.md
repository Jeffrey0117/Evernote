---
layout: ../../layouts/PostLayout.astro
title: Electron 載入本地圖片的正確姿勢
date: 2026-01-13T07:10
description: 從網頁圖片載入原理，到 Electron 踩坑，再到 IPC + Base64 的解法
tags:
  - Electron
  - React
  - TypeScript
---

在做 Unifold 檔案管理器時，需要顯示本地圖片的縮圖。聽起來很簡單對吧？結果踩了一個大坑。這篇文章記錄整個除錯過程和學到的東西。

## 網頁載入圖片的基本原理

先回顧一下，在一般網頁中怎麼載入圖片：

```html
<img src="https://example.com/image.jpg" />
```

瀏覽器看到 `<img>` 標籤，就會去 `src` 指定的網址抓圖片回來顯示。

除了 `https://` 網址，其實 `src` 還可以放另一種東西：**Data URL**。

```html
<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEU..." />
```

這種寫法是把圖片資料直接塞在 URL 裡面，瀏覽器不用額外發請求，直接解碼顯示。

你可能有注意過，**Google 圖片搜尋**在你滑動頁面時，縮圖一開始是模糊的，然後才變清楚。那個模糊的版本就是用 Data URL 內嵌的超小圖，等真正的圖片載入完才換掉。這招可以讓頁面看起來載入很快，不會一片空白。

## 原本以為很簡單

好，回到 Electron。

應用跑在本機，圖片也在本機硬碟上，應該很簡單吧？本地檔案嘛，那就用 `file://` 協議：

```tsx
<img src={`file://${filePath}`} />
```

但 Windows 的路徑長這樣：

```
C:\Users\jeffb\Desktop\photo.jpg
```

直接塞進去會變成：

```
file://C:\Users\jeffb\Desktop\photo.jpg
```

這格式不對。URL 的標準是用**正斜線** `/`，不是 Windows 的反斜線 `\`。而且本地檔案的 `file://` 協議要有**三個斜線**：

```
file:///C:/Users/jeffb/Desktop/photo.jpg
```

### 為什麼 Windows 硬要用反斜線？

歷史包袱。早期 DOS 系統用 `/` 當命令參數的前綴（像 `dir /w`），所以微軟只好選 `\` 當路徑分隔符。而 URL 是基於 Unix 設計的，用正斜線。兩邊就是不一樣。

所以處理 Windows 路徑要記得轉換，空格也要編碼：

```typescript
const toFileUrl = (path: string) => {
    // C:\Users\jeffb\My Photos\cat.jpg
    // → file:///C:/Users/jeffb/My%20Photos/cat.jpg
    return 'file:///' + path.replace(/\\/g, '/').replace(/ /g, '%20')
}
```

## 結果：死圖

處理完路徑格式，滿心期待地測試：

```tsx
<img src={toFileUrl(file.path)} />
```

**圖片不顯示。**

DevTools 看不到明顯錯誤，Network 面板也沒有失敗的請求。就是一片空白。

## 又是瀏覽器的安全機制在搞

查了一下，果然是 Chromium 的安全限制。

瀏覽器這東西就是毛很多。平常寫網頁就被 CORS（跨來源資源共用）搞過，API 打不過去、字體載入失敗、iframe 被擋，各種莫名其妙的安全限制。這次換成 `file://` 協議被擋。

> 即使設定了 `webSecurity: false`，Chromium 對 `file://` 協議的某些載入行為還是會阻擋。

相關資源：
- [Electron 官方文檔：Security](https://www.electronjs.org/docs/latest/tutorial/security)
- [Stack Overflow 討論](https://stackoverflow.com/questions/30864573/loading-local-image-files-in-electron)

結論：`file://` 在 Electron 的渲染進程中不可靠，不能直接拿來載入圖片。

## 那個常被誤以為是壓縮的 Base64

卡住的時候，我想起之前做圖片上傳功能用過 Base64。把使用者選的圖片轉成 Base64 字串，再 POST 到後端。

那反過來也可以吧？**讓主進程讀取圖片，轉成 Base64，傳給前端用 Data URL 顯示。**

這邊要釐清一個常見誤解：**Base64 不是壓縮，是編碼**。

- **壓縮**：讓資料變小（gzip、zip）
- **編碼**：換一種表示方式，大小可能不變甚至變大

Base64 把二進位資料轉成純文字（只用 A-Z、a-z、0-9、+、/ 這 64 個字元），讓二進位資料可以安全地透過文字管道傳輸。

代價是：**編碼後會變大約 33%**。3 個 bytes 變 4 個字元。

## 先講一下 IPC

Electron 有兩種進程：

- **主進程（Main Process）**：Node.js 環境，能存取檔案系統
- **渲染進程（Renderer Process）**：Chromium 環境，跑 React

這兩個進程是隔離的，要溝通得透過 IPC（Inter-Process Communication）：

```
渲染進程 → (IPC 請求) → 主進程 → (讀檔案) → (IPC 回應) → 渲染進程
```

IPC 是 Electron 開發的核心概念，這篇先簡單帶過，之後會另外寫一篇詳細講。想先了解可以看 [Electron 官方文檔：IPC](https://www.electronjs.org/docs/latest/tutorial/ipc)。

## 實作解法

### 1. 主進程：讀檔案轉 Base64

```typescript
// main/index.ts
import { ipcMain } from 'electron'
import { readFile } from 'fs/promises'
import { extname } from 'path'

ipcMain.handle('read-image-base64', async (_event, filePath: string) => {
    try {
        const ext = extname(filePath).toLowerCase().slice(1)
        const mimeMap: Record<string, string> = {
            jpg: 'image/jpeg',
            jpeg: 'image/jpeg',
            png: 'image/png',
            gif: 'image/gif',
            webp: 'image/webp',
            svg: 'image/svg+xml'
        }
        const mime = mimeMap[ext] || 'image/png'
        const data = await readFile(filePath)
        return {
            success: true,
            dataUrl: `data:${mime};base64,${data.toString('base64')}`
        }
    } catch (error: unknown) {
        return { success: false, error: (error as Error).message }
    }
})
```

### 2. Preload：暴露 API 給渲染進程

Preload 是 Electron 用來安全地把主進程能力暴露給網頁的機制。這塊也蠻複雜的，之後另外寫，先看程式碼：

```typescript
// preload/index.ts
import { contextBridge, ipcRenderer } from 'electron'

const api = {
    readImageBase64: (filePath: string) =>
        ipcRenderer.invoke('read-image-base64', filePath)
}

contextBridge.exposeInMainWorld('api', api)
```

延伸閱讀：[Electron 官方文檔：Context Isolation](https://www.electronjs.org/docs/latest/tutorial/context-isolation)

### 3. React 元件：非同步載入

```tsx
// components/ImageThumbnail.tsx
import { useState, useEffect } from 'react'

function ImageThumbnail({ path, className }: { path: string; className?: string }) {
    const [src, setSrc] = useState<string | null>(null)

    useEffect(() => {
        let mounted = true
        window.api.readImageBase64(path).then(res => {
            if (mounted && res.success) setSrc(res.dataUrl)
        })
        return () => { mounted = false }
    }, [path])

    if (!src) return <div className="w-12 h-12 bg-gray-700 animate-pulse" />
    return <img src={src} alt="" className={className} />
}
```

## 其他解法

除了 IPC + Base64，還有幾種方式：

| 方法 | 說明 |
|------|------|
| **自訂協議** | 用 `protocol.registerFileProtocol` 註冊 `app://`，最優雅但設定複雜 |
| **本地 HTTP 伺服器** | 開個 localhost 伺服器 serve 檔案，有點殺雞用牛刀 |
| **nativeImage** | Electron 內建，但主要給系統圖示用，不適合網頁大量顯示 |

目前用 IPC + Base64，簡單直接。如果之後大圖片效能有問題，可能會改成自訂協議。

## 整理：網頁載入資源的方式

| 標籤/方法 | 用途 | 載入時機 |
|-----------|------|----------|
| `<img src="">` | 圖片 | 解析到標籤時 |
| `<script src="">` | JavaScript | 解析到標籤時（會阻塞） |
| `<link href="">` | CSS、字體、預載 | 解析到標籤時 |
| `fetch()` | 任意資源 | 程式呼叫時 |
| `import()` | ES Module | 動態載入 |

在 Electron 多了一層考量——主進程和渲染進程的分離，讓載入本地資源變得沒那麼直覺：

| 方法 | 說明 |
|------|------|
| `file://` 協議 | 受限，不一定能用 |
| IPC + Base64 | 可靠，但資料量增加 33% |
| 自訂協議 | 最優雅，但設定複雜 |
| 本地 HTTP 伺服器 | 可行，但 overkill |

---

經過這次踩坑，學到一件事：**瀏覽器要載入東西，就是會很靠北**。

不管是 CORS 擋 API、CSP 擋 script、還是 `file://` 擋圖片，反正就是各種安全限制等著你。下次碰到資源載入不出來，先別懷疑人生，回來看這篇，從協議、安全限制、傳輸方式這幾個角度去排查。
