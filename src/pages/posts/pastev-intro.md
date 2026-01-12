---
layout: ../../layouts/PostLayout.astro
title: 用 Tesseract.js 和 JSZip 做圖片翻譯工具
date: 2026-01-13T15:00
description: 用 Tesseract.js 做 OCR，再用 JSZip 批次打包，把圖片翻譯流程自動化
tags:
  - React
  - OCR
  - Tesseract.js
  - JSZip
---

最近做了一個東西叫 PasteV，我自己覺得蠻酷的。

功能是：**上傳圖片 → 自動辨識上面的文字 → 翻譯 → 產出新圖片**。

會想做這個是因為，我發現「把外文圖片翻成中文」這件事，本質上就是固定的流程：OCR 抓文字、翻譯、把翻譯結果塞回原本的位置、匯出。既然是固定流程，那就應該可以自動化。

但我又不想搞 n8n、Make 那些 no-code 工具，太重了，而且很多細節控制不了。乾脆自己寫一個。

---

所以現在的流程變成：上傳一張圖，Tesseract 跑完 OCR，AI 幫你翻譯，然後直接輸出新圖片。以前要手動打字、開 Canva 排版、調顏色，現在全部省掉。

批次處理也做了。100 張圖上傳，全部辨識完、翻譯完，最後用 JSZip 打包成一個 ZIP 下載。

---

## 圖片文字辨識怎麼做

OCR 的選擇其實不少：

| 方案 | 優點 | 缺點 |
|------|------|------|
| Google Cloud Vision | 準確度最高 | 要錢，按次數計費 |
| AWS Textract | 整合 AWS 生態系 | 一樣要錢，設定麻煩 |
| Tesseract.js | 免費、可以跑在前端或後端 | 準確度稍遜，但夠用 |

我選 [Tesseract.js](https://github.com/naptha/tesseract.js)。

Tesseract 本身是 Google 維護的開源 OCR 引擎，C++ 寫的。Tesseract.js 是它的 JavaScript port，用 WebAssembly 編譯，所以不用裝額外 binary，npm install 就能用。

對我來說最重要的是**免費**。這種工具如果按 API 次數收錢，用起來會很有壓力，每張圖都在燒錢的感覺。Tesseract.js 跑在自己的 server，要辨識幾張都隨便。

用起來很簡單：

```javascript
import Tesseract from 'tesseract.js';

const result = await Tesseract.recognize(image, 'eng');
console.log(result.data.text);
```

它還會回傳每個文字區塊的座標跟信心度，這對後面「把翻譯塞回原位置」很重要。

---

## 批次匯出要打包

100 張圖處理完，總不能讓使用者點 100 次下載。要打包成 ZIP。

前端打包 ZIP 的 library 不多，主要就兩個：

| Library | 定位 | 適合場景 |
|---------|------|----------|
| [JSZip](https://stuk.github.io/jszip/) | 簡單易用，API 直覺 | 一般場景，快速開發 |
| [fflate](https://github.com/101arrowz/fflate) | 效能導向，體積小，速度快 | 大檔案、高效能需求 |

fflate 號稱是「最快的 JavaScript 壓縮 library」，用 TypeScript 寫的，支援 streaming，壓縮大檔案時不會卡住。但 API 比較底層，要自己處理比較多細節。

JSZip 就是典型的「簡單好用」路線，三行搞定：

```javascript
import JSZip from 'jszip';

const zip = new JSZip();
zip.file('image1.png', blob1);
zip.file('image2.png', blob2);

const zipBlob = await zip.generateAsync({ type: 'blob' });
```

對我的需求來說，圖片本身已經是壓縮格式（PNG/JPG），ZIP 再壓也壓不了多少，效能不是瓶頸，所以選 JSZip。

用是很簡單，但我好奇 ZIP 到底是怎麼運作的，就去研究了一下。

### ZIP 的結構

ZIP 其實不複雜，就是一堆檔案串在一起，最後加一個目錄：

```
[檔案 1 的 header][檔案 1 的內容]
[檔案 2 的 header][檔案 2 的內容]
...
[Central Directory]  ← 所有檔案的索引
[End of Central Directory]
```

每個檔案的 header 長這樣（簡化版）：

| offset | 長度 | 內容 |
|--------|------|------|
| 0 | 4 bytes | Magic number `0x04034b50` |
| 4 | 2 bytes | 版本 |
| 8 | 2 bytes | 壓縮方式（0=不壓縮，8=DEFLATE） |
| 14 | 4 bytes | CRC32 checksum |
| 18 | 4 bytes | 壓縮後大小 |
| 22 | 4 bytes | 原始大小 |
| 26 | 2 bytes | 檔名長度 |
| 30 | n bytes | 檔名 |

後面接檔案內容。如果壓縮方式是 0（STORE），就是原封不動塞進去；如果是 8（DEFLATE），要先用 [DEFLATE 演算法](https://en.wikipedia.org/wiki/Deflate) 壓縮。

最後的 Central Directory 是整個 ZIP 的目錄，記錄每個檔案在 ZIP 裡的 offset，這樣解壓縮的時候可以直接跳到指定檔案，不用從頭讀。

### CRC32 怎麼算

比較麻煩的是 CRC32。

CRC32 是一種 checksum 演算法，用來驗證檔案有沒有損壞。ZIP 規定每個檔案都要算 CRC32 塞進 header。

演算法本身是 bit 操作，核心概念是把資料當成一個超長的二進位數字，對一個「多項式」做除法，取餘數。實作上會建一個 lookup table 加速：

```javascript
function makeCrcTable() {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c;
  }
  return table;
}

function crc32(data) {
  const table = makeCrcTable();
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < data.length; i++) {
    crc = table[(crc ^ data[i]) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}
```

那個 `0xEDB88320` 是 CRC32 的多項式常數，反轉過的版本。這段 code 我看了三遍才懂它在幹嘛。想深入理解可以看這篇：[A Painless Guide to CRC Error Detection Algorithms](http://www.ross.net/crc/download/crc_v3.txt)。

### 自幹 ZIP 會怎樣

所以如果要自幹一個 ZIP，大概要：

1. 對每個檔案算 CRC32
2. 組 Local File Header（用 `DataView` 操作 ArrayBuffer）
3. 串檔案內容
4. 記錄每個檔案的 offset
5. 最後組 Central Directory 和 End of Central Directory

用 `DataView` 寫 header 大概長這樣：

```javascript
const header = new ArrayBuffer(30 + filename.length);
const view = new DataView(header);

view.setUint32(0, 0x04034b50, true);   // magic number
view.setUint16(4, 20, true);            // 版本
view.setUint16(8, 0, true);             // 壓縮方式：STORE
view.setUint32(14, crc, true);          // CRC32
view.setUint32(18, size, true);         // 壓縮後大小
view.setUint32(22, size, true);         // 原始大小
view.setUint16(26, filename.length, true);
// ... 塞檔名、串內容 ...
```

可以做，但要處理的細節很多，還有檔名編碼（UTF-8 flag）、64 位元擴展（ZIP64）之類的邊界情況。

研究完之後更理解 JSZip 幫我省了多少事。想看完整的 ZIP 規格可以參考 [PKWARE 的官方文件](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)。

---

## 其他技術

除了 Tesseract 和 JSZip，專案還用了：

- **Sharp** — Node.js 的圖片處理 library，用來擷取文字區塊的背景顏色
- **html2canvas** — 把 DOM 元素轉成圖片，用在最後輸出的時候

這兩個比較複雜，之後會另外寫一篇來講。

---

## 接下來想做的

目前 PasteV 已經可以用了，但還有很多可以改進的地方：

- **更自動化** — 現在還是要手動確認翻譯結果，想做到「上傳就直接輸出」的全自動模式
- **更多語言** — 目前主要測英翻中，之後想支援日文、韓文
- **桌面應用** — 可能用 Electron 包起來，不用開瀏覽器

這個專案還會繼續長大。

---

下一篇會講 Sharp 怎麼處理圖片、html2canvas 怎麼把排版好的內容轉成圖片輸出。
