---
layout: ../../layouts/PostLayout.astro
title: Taro：一套程式碼，多個小程式平台
date: 2026-01-14T06:25
description: 微信、支付寶、抖音小程式都要做？Taro 讓你用 React 寫一次，編譯到多個平台
tags:
  - 前端
  - React
  - 小程式
  - 跨平台
---

在 GitHub 上逛到 [Taro](https://github.com/NervJS/taro)，35k+ stars。

京東前端團隊做的，解決一個很現實的問題：**中國有太多小程式平台了**。

---

## 問題：每個平台都要重寫

中國的小程式生態：

| 平台 | 說明 |
|------|------|
| 微信小程式 | 最大的 |
| 支付寶小程式 | 阿里系 |
| 百度小程式 | |
| 抖音小程式 | 字節跳動 |
| QQ 小程式 | |
| 京東小程式 | |
| 快手小程式 | |

每個平台的 API 不一樣、語法有差異。

如果你的業務要上多個平台，每個都重寫一遍？瘋了。

---

## Taro 的解法

用 React 語法寫一次，編譯到多個平台：

```javascript
import { View, Text, Button } from '@tarojs/components';
import { useState } from 'react';

function App() {
    const [count, setCount] = useState(0);

    return (
        <View>
            <Text>Count: {count}</Text>
            <Button onClick={() => setCount(count + 1)}>+1</Button>
        </View>
    );
}

export default App;
```

然後：

```bash
# 編譯到微信小程式
taro build --type weapp

# 編譯到支付寶小程式
taro build --type alipay

# 編譯到 H5 網頁
taro build --type h5

# 編譯到 React Native
taro build --type rn
```

**一套程式碼，多個產出。**

---

## 支援的平台

| 平台 | 類型 | 指令 |
|------|------|------|
| 微信小程式 | 小程式 | `--type weapp` |
| 支付寶小程式 | 小程式 | `--type alipay` |
| 百度小程式 | 小程式 | `--type swan` |
| 抖音小程式 | 小程式 | `--type tt` |
| QQ 小程式 | 小程式 | `--type qq` |
| 京東小程式 | 小程式 | `--type jd` |
| H5 | 網頁 | `--type h5` |
| React Native | App | `--type rn` |
| 鴻蒙 | App | `--type harmony` |

---

## 基本用法

### 建立專案

```bash
npm install -g @tarojs/cli
taro init myApp
```

### 專案結構

```
myApp/
├── src/
│   ├── pages/
│   │   └── index/
│   │       ├── index.tsx
│   │       └── index.scss
│   ├── app.tsx
│   └── app.config.ts
├── config/
│   ├── index.js
│   └── dev.js
└── package.json
```

### 頁面設定

```typescript
// src/app.config.ts
export default {
    pages: [
        'pages/index/index',
        'pages/user/index',
    ],
    window: {
        navigationBarTitleText: 'My App',
    },
};
```

### 呼叫平台 API

```javascript
import Taro from '@tarojs/taro';

// 統一的 API，Taro 會轉換成各平台對應的 API
Taro.showToast({ title: 'Hello!' });
Taro.getSystemInfo().then(info => console.log(info));
Taro.request({ url: 'https://api.example.com/data' });
```

---

## 跨平台的代價

不是完全沒代價：

### 1. 最小公約數

各平台功能不同，Taro 只能支援「大家都有的」功能。

想用微信獨有的 API？要寫條件判斷：

```javascript
if (process.env.TARO_ENV === 'weapp') {
    // 微信專屬功能
    wx.someWechatOnlyAPI();
}
```

### 2. 樣式差異

各平台的渲染引擎不同，同樣的 CSS 可能呈現不一樣。

要花時間在各平台上測試、調整。

### 3. 效能

編譯轉換會有額外開銷，比原生開發稍慢。

但對於大部分應用來說，感覺不出差別。

---

## 類似的方案

| 框架 | 技術棧 | 特點 |
|------|--------|------|
| Taro | React | 京東出品，React 生態 |
| uni-app | Vue | DCloud 出品，Vue 生態 |
| Remax | React | 阿里出品，較輕量 |
| WePY | 類 Vue | 騰訊出品，只支援微信 |

如果你熟 Vue，[uni-app](https://uniapp.dcloud.io/) 可能更適合。

---

## 我自己的判斷

### 什麼時候用 Taro

- 要同時上 2 個以上的小程式平台
- 團隊熟 React
- 京東的專案（他們自己在用，維護有保障）

### 什麼時候不用

- 只做微信小程式 → 直接用原生，更簡單
- 只做一個平台 → 原生開發，沒有轉換成本
- 對效能極度敏感 → 原生開發

### 台灣市場

老實說，台灣市場不太需要這個。

台灣沒有「多個小程式平台」的問題，LINE 的 LIFF 也不在 Taro 支援範圍內。

這個工具主要是為了中國市場設計的。

---

## 相關文章

- [Preact 和 Nerv：輕量版 React](/Evernote/posts/preact-nerv-lightweight-react) — Nerv 是同一個團隊做的
- [跨平台桌面開發](/Evernote/posts/cross-platform-desktop-overview) — 桌面端的跨平台方案
- [寫程式解決問題之前，先決定你要做什麼](/Evernote/posts/what-should-i-build) — 什麼時候需要 App

---

跨平台框架的價值在於「一次開發多處部署」。

如果你只做一個平台，直接用原生可能更省事。
