---
layout: ../../layouts/PostLayout.astro
title: Zustand 就是簡單版的 Redux
date: 2026-01-14T03:07
description: 不是每個專案都需要 Redux，有時候你只是要存個登入狀態
tags:
  - React
  - Zustand
  - 狀態管理
---

我每次開新的 React 專案，都會卡在同一個問題：「狀態管理要用什麼？」

Redux？光是 boilerplate 就寫到煩。

Context？一更新整棵樹都重新渲染。

Jotai？Recoil？MobX？選項太多，每個都要學。

後來我發現，大部分 side project 根本不需要這麼複雜的東西。

![選對工具](/Evernote/images/posts/zustand-simple.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>你只是要去巷口買個早餐，不需要開卡車。</small></p>

## 先問自己需要管什麼

在選工具之前，先想清楚你要管理什麼狀態：

| 狀態類型 | 例子 | 需要全域嗎 |
|----------|------|-----------|
| UI 狀態 | modal 開關、sidebar 展開 | 通常不用 |
| 表單狀態 | input value、validation | 不用 |
| Server 狀態 | API 回傳的資料 | 用 React Query |
| Auth 狀態 | 登入 token、使用者資訊 | 要 |
| 全域設定 | 主題、語言 | 要 |

很多時候你以為需要全域狀態，其實用 React Query 就夠了。

真正需要全域狀態管理的，通常就是 auth 和一些全域設定。

## Redux 哪裡重

![Redux 的 boilerplate](/Evernote/images/posts/zustand-mess.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>左邊是 Redux 專案，右邊是 Zustand 專案。你想維護哪個？</small></p>

Redux 本身的概念不複雜：單一 store、action、reducer。

但實際用起來：

```typescript
// 定義 action types
const SET_USER = 'SET_USER';
const SET_TOKEN = 'SET_TOKEN';
const LOGOUT = 'LOGOUT';

// 定義 action creators
const setUser = (user) => ({ type: SET_USER, payload: user });
const setToken = (token) => ({ type: SET_TOKEN, payload: token });
const logout = () => ({ type: LOGOUT });

// 定義 reducer
const authReducer = (state = initialState, action) => {
  switch (action.type) {
    case SET_USER:
      return { ...state, user: action.payload };
    case SET_TOKEN:
      return { ...state, token: action.payload };
    case LOGOUT:
      return initialState;
    default:
      return state;
  }
};

// 建立 store
const store = createStore(authReducer);

// 使用
const user = useSelector(state => state.user);
const dispatch = useDispatch();
dispatch(setUser({ name: 'Jeff' }));
```

為了存一個登入狀態，要寫這麼多 boilerplate。

Redux Toolkit 改善了很多，但還是需要 slice、thunk 那些概念。

## Zustand 長怎樣

![簡單的小店](/Evernote/images/posts/zustand-store.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>Zustand 在德文是「狀態」的意思。這隻熊就是你的狀態管理員。</small></p>

同樣的功能，用 [Zustand](https://github.com/pmndrs/zustand)：

```typescript
import { create } from 'zustand';

interface AuthStore {
  token: string | null;
  user: User | null;
  setToken: (token: string) => void;
  setUser: (user: User) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthStore>((set) => ({
  token: null,
  user: null,

  setToken: (token) => set({ token }),
  setUser: (user) => set({ user }),
  logout: () => set({ token: null, user: null }),
}));
```

使用的時候：

```typescript
// 讀取
const token = useAuthStore(state => state.token);
const user = useAuthStore(state => state.user);

// 或一次拿多個
const { token, user, logout } = useAuthStore();

// 更新
const setToken = useAuthStore(state => state.setToken);
setToken('new-token');
```

沒有 action、沒有 reducer、沒有 dispatch。

就是一個 hook，裡面有狀態和更新函式。

## 加上 localStorage 持久化

![持久化儲存](/Evernote/images/posts/zustand-persist.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>localStorage 就像寶箱，關掉瀏覽器東西還在。</small></p>

登入狀態通常要存到 localStorage，這樣重新整理才不會登出：

```typescript
export const useAuthStore = create<AuthStore>((set) => ({
  // 初始值從 localStorage 讀取
  token: localStorage.getItem('token'),
  user: null,
  isAuthenticated: !!localStorage.getItem('token'),

  setToken: (token) => {
    localStorage.setItem('token', token);
    set({ token, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem('token');
    set({ token: null, user: null, isAuthenticated: false });
  },
}));
```

如果你有很多東西要存，Zustand 有 `persist` middleware：

```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export const useAuthStore = create(
  persist<AuthStore>(
    (set) => ({
      token: null,
      user: null,
      setToken: (token) => set({ token }),
      logout: () => set({ token: null, user: null }),
    }),
    {
      name: 'auth-storage', // localStorage 的 key
    }
  )
);
```

## 什麼時候用 Redux

| 情況 | 用什麼 |
|------|--------|
| 簡單的全域狀態 | Zustand |
| 複雜的狀態邏輯、需要 middleware | Redux Toolkit |
| 很多非同步操作、需要 saga | Redux |
| Server 狀態 | React Query |
| 只有一兩個元件要共享 | Context 或 prop drilling |

Redux 的優勢是生態系成熟，devtools 很強，大型專案有規範可循。

但如果你的需求只是「存個登入狀態」「存個 theme 設定」，Zustand 夠用了。

## 我的使用習慣

1. **Server 狀態**：全部用 React Query，不放進 store
2. **Auth 狀態**：Zustand，因為很多地方要用
3. **UI 狀態**：useState，除非真的需要跨元件
4. **表單狀態**：React Hook Form

這樣分下來，Zustand 真正要管的東西很少，程式碼也簡單。

---

![選對大小的工具](/Evernote/images/posts/zustand-right.png)
<p align="center" style="margin-top: -1em; margin-bottom: 3em; color: #666;"><small>背包大小要看你走多遠，不是看別人背多大。</small></p>

不是說 Redux 不好，是很多專案根本用不到那些功能。

選工具要看需求，不要因為「大家都在用」就跟著用。

一個 side project 硬要上 Redux，就像開一台卡車去買早餐。
