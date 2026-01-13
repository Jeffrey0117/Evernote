---
layout: ../../layouts/PostLayout.astro
title: 系統預設字體太醜，我自己選
date: 2026-01-13T17:52
description: 為什麼中文桌面應用不該用微軟正黑體，以及我怎麼選字體
tags:
  - UI/UX
  - 字體
  - Electron
---

做聲聲慢的時候，一開始用系統預設字體。

Windows 是微軟正黑體，macOS 是蘋方。

能用，但看著就是不對勁。

辨識出來的文字一大段，用微軟正黑體顯示，像在看公文。

## 系統預設的問題

### 跨平台長得不一樣

| 系統 | 預設中文字體 |
|------|-------------|
| Windows | 微軟正黑體 |
| macOS | 蘋方 |
| Linux | Noto Sans CJK |

同一個應用，在不同系統上看起來不一樣。

字體風格、粗細、間距都不同。

### 風格太「系統」

系統字體是為「通用」設計的。

**什麼都能用，但什麼都不突出。**

如果應用想要有點個性——文藝一點、復古一點、手寫一點——系統字體做不到。

### 字重選擇有限

微軟正黑體只有 Light 和 Regular。

想要 Bold？沒有。

想要更細的字體做標題？也沒有。

## 我選了什麼

### 主字體：源雲明體

[源雲明體](https://github.com/nickchou/GenWanMin) 是基於思源宋體修改的字體。

明體風格，有傳統印刷的韻味。筆畫清晰，小字也能看清楚。

用來顯示辨識結果剛好。一大段文字看起來像在讀文章，不像公文。

而且是 OFL 授權，免費開源，商用也沒問題。

### 次字體：jf open 粉圓

[jf open 粉圓](https://justfont.com/huninn/) 是 justfont 出的免費字體。

圓體風格，親切、可愛。

用在按鈕、提示文字這種需要輕鬆感的地方。

而且是台灣團隊做的，繁體中文的調校很到位。

## 怎麼載入

### CSS @font-face

```css
@font-face {
    font-family: 'GenWanMin';
    src: url('/fonts/GenWanMin-Regular.ttf') format('truetype');
    font-weight: normal;
    font-style: normal;
    font-display: swap;
}
```

`font-display: swap` 很重要。

字體載入時先顯示備用字體，不會整個畫面空白等字體。

### 打包進應用

對離線應用來說，字體必須打包進去：

```
src/
├── fonts/
│   ├── GenWanMin-Regular.ttf
│   └── jf-openhuninn-Regular.ttf
└── ...
```

缺點是檔案變大。一個中文字體通常 5-15MB。

但對桌面應用來說，這點大小不算什麼。

## 中文字體要大一點

中文字體需要比英文大一點才好讀。

英文 14px 剛好，中文最好 16px。

```css
body {
    font-size: 16px;
    line-height: 1.8; /* 行高也要大一點 */
}
```

中文字筆畫多，太小會糊在一起。行高太窄也會擠。

## 開源中文字體推薦

順便整理一下我看過的字體。

### 黑體（無襯線）

| 字體 | 特點 | 授權 |
|------|------|------|
| [思源黑體](https://github.com/adobe-fonts/source-han-sans) | Adobe + Google 合作，字重超完整 | OFL |
| [Noto Sans TC](https://fonts.google.com/noto/specimen/Noto+Sans+TC) | Google 版思源黑體 | OFL |
| [jf open 粉圓](https://justfont.com/huninn/) | 圓體風格，台灣團隊 | OFL |

### 明體（襯線）

| 字體 | 特點 | 授權 |
|------|------|------|
| [思源宋體](https://github.com/adobe-fonts/source-han-serif) | Adobe + Google 合作 | OFL |
| [源雲明體](https://github.com/nickchou/GenWanMin) | 基於思源宋體，更有韻味 | OFL |

### 手寫/特殊

| 字體 | 特點 | 授權 |
|------|------|------|
| [芫荽](https://github.com/nickchou/ChenYuluoyan) | 手寫風格 | OFL |
| [霞鶩文楷](https://github.com/lxgw/LxgwWenKai) | 楷體風格 | OFL |

OFL（SIL Open Font License）— 字體界的「請隨便用」授權。免費、商用 OK、改了再發也 OK，唯一條件是保留授權聲明。

## 我的 CSS 設定

```css
:root {
    --font-serif: 'GenWanMin', 'Noto Serif TC', 'PMingLiU', serif;
    --font-sans: 'jf-openhuninn', 'Noto Sans TC', 'Microsoft JhengHei', sans-serif;
}

body {
    font-family: var(--font-serif);
    font-size: 16px;
    line-height: 1.8;
}

button, .ui-element {
    font-family: var(--font-sans);
}
```

用 CSS 變數統一管理，之後要換字體改一個地方就好。

---

換完字體那天，我截圖給朋友看。

他說：「感覺變高級了。」

我沒改任何功能，只換了字體。

系統預設字體像制服——能穿，但你一眼就知道是公家發的。自己選字體，應用才像是你做的。

相關文章：

- [聲聲慢：我做了一個離線語音轉文字工具](/Evernote/posts/shengshengman-intro)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
