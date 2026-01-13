---
layout: ../../layouts/PostLayout.astro
title: Google OAuth 的 Token 會過期
date: 2026-01-14T03:07
description: 用 Google 登入很簡單，但 token 過期的時候你的 app 會直接爛掉
tags:
  - OAuth
  - React
  - TypeScript
---

用 Google 登入很簡單，裝個 [@react-oauth/google](https://www.npmjs.com/package/@react-oauth/google) 就搞定了。

但有一個問題很多人沒處理：**token 會過期**。

Google 的 access token 預設只有一小時的壽命。一小時後，你的 API 請求會開始噴 401，使用者莫名其妙被登出。

## OAuth 2.0 的 token 類型

先搞清楚有哪些 token：

| Token | 用途 | 壽命 |
|-------|------|------|
| Access Token | 打 API 用的通行證 | 1 小時 |
| Refresh Token | 用來換新的 Access Token | 很長（可能永久） |
| ID Token | 證明使用者身份 | 1 小時 |

Access token 是你實際拿來打 YouTube API、Google Drive API 的東西。

它故意設計成短命的，這樣就算被偷走，損害也有限。

## @react-oauth/google 給你什麼

用 `useGoogleLogin` 登入成功後，你會拿到一個 `tokenResponse`：

```typescript
const login = useGoogleLogin({
  onSuccess: (tokenResponse) => {
    console.log(tokenResponse);
    // {
    //   access_token: "ya29.a0AfH6SM...",
    //   expires_in: 3599,
    //   scope: "https://www.googleapis.com/auth/youtube...",
    //   token_type: "Bearer"
    // }
  },
  scope: 'https://www.googleapis.com/auth/youtube',
});
```

注意 `expires_in: 3599`，單位是秒，大約一小時。

**這個套件預設不給你 refresh token。**

要拿 refresh token，需要用 `flow: 'auth-code'` 模式，然後在後端換 token。這比較複雜，很多小專案不想搞。

## 沒有 refresh token 怎麼辦

如果你的專案跟我一樣，只是個 side project，不想架後端處理 refresh token，有幾個選項：

### 選項 1：記錄過期時間，過期就重新登入

```typescript
const handleGoogleLogin = (tokenResponse: any) => {
  // 儲存 token
  localStorage.setItem('access_token', tokenResponse.access_token);

  // 計算過期時間
  const expiresAt = Date.now() + tokenResponse.expires_in * 1000;
  localStorage.setItem('token_expires_at', expiresAt.toString());
};
```

每次用 token 之前，檢查有沒有過期：

```typescript
useEffect(() => {
  const expiresAt = localStorage.getItem('token_expires_at');
  if (expiresAt && Date.now() > parseInt(expiresAt)) {
    logout();
    navigate('/login');
  }
}, []);
```

### 選項 2：API 回傳 401 就登出

不主動檢查，等 API 噴錯再處理：

```typescript
const response = await fetch(url, {
  headers: { Authorization: `Bearer ${token}` }
});

if (response.status === 401) {
  // Token 過期或無效
  logout();
  throw new Error('TOKEN_EXPIRED');
}
```

這個做法比較被動，但實作簡單。

### 選項 3：用 Google 的 silent refresh

`@react-oauth/google` 有提供 `useGoogleOneTapLogin`，可以在背景偷偷刷新 token。

但這個行為不太穩定，而且使用者體驗有點奇怪（會跳出 Google 的 one-tap UI）。

## 我的做法

在 YouTube DB 這個專案裡，我用的是選項 1 + 2 混合。

登入時記錄過期時間，每次進 Dashboard 檢查有沒有過期，API 回傳 401 也會觸發登出。

```typescript
// useAuth.ts
useEffect(() => {
  if (token) {
    const expiresAt = localStorage.getItem('token_expires_at');
    if (expiresAt && Date.now() > parseInt(expiresAt)) {
      logout();
      navigate('/');
    }
  }
}, [token]);
```

```typescript
// youtube.ts
if (response.status === 401) {
  throw new Error('TOKEN_EXPIRED');
}
```

```typescript
// Dashboard.tsx
useEffect(() => {
  if (queryError?.message === 'TOKEN_EXPIRED') {
    showToast('登入已過期，請重新登入');
    setTimeout(() => logout(), 2000);
  }
}, [queryError]);
```

使用者會看到「登入已過期」的提示，然後被導回登入頁。

## 要不要用 refresh token

| 情況 | 建議 |
|------|------|
| Side project、POC | 不用，過期就重新登入 |
| 正式產品、長時間操作 | 要用，不然使用者會很火 |

Refresh token 需要後端配合，因為你不能把 client secret 放在前端。

前端拿到 auth code 後要傳給後端，後端用 client secret 跟 Google 換 tokens，再把 access token 傳回前端，refresh token 留在後端。

搞這麼複雜，就為了讓使用者不用每小時重新登入一次。

對於一個「把 YouTube 當資料庫」的北爛專案，我覺得不值得。

使用者一小時後被登出，重新登入就好。

---

OAuth 看起來簡單，但魔鬼都在細節裡。

Token 過期這件事，不處理的話 app 會在某個時間點突然壞掉，debug 的時候又好了（因為你重新登入了）。

先想好怎麼處理，不要等上線被使用者罵才發現。
