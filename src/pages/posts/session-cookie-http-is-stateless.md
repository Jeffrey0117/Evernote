---
layout: ../../layouts/PostLayout.astro
title: Session 與 Cookie：HTTP 是無狀態的，那怎麼記住我
date: 2026-01-14T03:05
description: HTTP 無狀態是什麼意思、Cookie 怎麼運作、Session ID 怎麼實現多租戶隔離
tags:
  - Session
  - Cookie
  - HTTP
  - 認證
---

[Ytify](/posts/ytify-self-hosted-youtube-downloader) 分享給朋友用之後，發現一個問題：

**每個人都看得到其他人的下載歷史。**

朋友 A 一打開頁面，就看到朋友 B 下載了什麼。

尷尬。

---

## 為什麼會這樣

因為 HTTP 是**無狀態的（stateless）**。

每次請求都是獨立的，伺服器不知道「這次請求」和「上次請求」是不是同一個人。

```
使用者 A ──GET /history──→ 伺服器
使用者 B ──GET /history──→ 伺服器

伺服器：「這兩個請求是同一個人嗎？我不知道。」
```

你關掉瀏覽器再打開，伺服器不知道你是誰。

你換個分頁，伺服器也不知道你是誰。

**HTTP 協定本身沒有「記住使用者」的機制。**

---

## 那網站怎麼做到登入的

既然 HTTP 無狀態，網站怎麼知道你登入了？

答案是：**Cookie**。

### Cookie 是什麼

Cookie 是伺服器發給瀏覽器的一小段資料，瀏覽器會自動儲存，並在之後的每次請求都帶上。

```
第一次請求：
瀏覽器 ──GET /login──→ 伺服器
瀏覽器 ←──Set-Cookie: session_id=abc123──── 伺服器

之後的請求：
瀏覽器 ──GET /history, Cookie: session_id=abc123──→ 伺服器
         ↑ 瀏覽器自動帶上 Cookie
```

伺服器看到 `session_id=abc123`，就知道：「喔，這是剛才那個人」。

### Session 是什麼

**Session 是伺服器端儲存的使用者資料**，用 Session ID 來識別。

```
伺服器的 Session 資料：
{
  "abc123": { "user_id": 1, "name": "小明" },
  "xyz789": { "user_id": 2, "name": "小華" }
}

請求帶著 Cookie: session_id=abc123
→ 伺服器查表，知道這是 user_id=1 的小明
```

Cookie 存在瀏覽器，Session 存在伺服器。

Cookie 只存一個 ID，真正的資料（你是誰、購物車有什麼）存在伺服器的 Session 裡。

---

## 如果要自幹 Session 機制...

```python
import uuid
from fastapi import FastAPI, Request, Response

app = FastAPI()

# 伺服器端的 Session 儲存（實務上會用 Redis）
sessions = {}

def get_session_id(request: Request) -> str:
    """從 Cookie 取得 Session ID"""
    return request.cookies.get("session_id")

def create_session() -> str:
    """建立新的 Session"""
    session_id = str(uuid.uuid4())
    sessions[session_id] = {}  # 空的 Session 資料
    return session_id

@app.middleware("http")
async def session_middleware(request: Request, call_next):
    session_id = get_session_id(request)

    # 沒有 Session ID，或 Session ID 無效
    if not session_id or session_id not in sessions:
        session_id = create_session()

    # 把 Session 資料放到 request.state，讓路由可以用
    request.state.session_id = session_id
    request.state.session = sessions[session_id]

    response = await call_next(request)

    # 設定 Cookie
    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,  # JavaScript 不能讀取，防 XSS
        max_age=7 * 24 * 3600  # 7 天後過期
    )

    return response

@app.get("/history")
async def get_history(request: Request):
    session_id = request.state.session_id

    # 只回傳這個 Session 的歷史記錄
    return db.query(session_id=session_id)
```

---

## Ytify 的多租戶隔離

Ytify 不需要登入系統，但還是要區分不同的使用者。

策略：**用 Session ID + IP 來識別**。

```python
# services/session.py
SESSION_COOKIE_NAME = "ytify_session"

def get_client_ip(request: Request) -> str:
    """取得使用者 IP（考慮 proxy）"""
    # Cloudflare
    if cf_ip := request.headers.get("CF-Connecting-IP"):
        return cf_ip
    # 其他 proxy
    if forwarded := request.headers.get("X-Forwarded-For"):
        return forwarded.split(",")[0].strip()
    # 直連
    return request.client.host

def get_session_id(request: Request) -> str:
    """取得 Session ID"""
    return request.cookies.get(SESSION_COOKIE_NAME)
```

查詢歷史記錄時：

```python
def get_history(session_id=None, client_ip=None, user_id=None):
    # 優先順序：登入用戶 > Session > IP
    if user_id:
        return db.query(user_id=user_id)
    elif session_id:
        return db.query(session_id=session_id)
    elif client_ip:
        return db.query(client_ip=client_ip)
```

這樣每個瀏覽器看到的是自己的歷史記錄，不會互相干擾。

---

## Cookie 的屬性

```python
response.set_cookie(
    key="session_id",
    value="abc123",
    httponly=True,       # JS 不能讀取
    secure=True,         # 只在 HTTPS 傳送
    samesite="lax",      # 防止 CSRF
    max_age=3600,        # 存活時間（秒）
    path="/",            # 哪些路徑可以帶這個 Cookie
    domain=".example.com"  # 哪些網域可以帶
)
```

| 屬性 | 用途 |
|------|------|
| `httponly` | 防止 XSS 攻擊偷 Cookie |
| `secure` | 只在 HTTPS 傳送，防止中間人攻擊 |
| `samesite` | 防止 CSRF，限制跨站請求帶 Cookie |
| `max_age` | Cookie 存活時間 |

---

## Session vs Token（JWT）

現代的認證有兩種主流做法：

| | Session | JWT |
|--|---------|-----|
| 資料存哪 | 伺服器 | Token 本身（瀏覽器） |
| 伺服器負擔 | 要查 Session 資料 | 只要驗證簽名 |
| 登出 | 刪掉 Session 就好 | 麻煩，Token 發出去就有效 |
| 擴展性 | 多台伺服器要共享 Session | 無狀態，天生適合分散式 |
| 安全性 | Session ID 洩漏就完了 | Token 洩漏也完了 |

Session 適合：傳統網站、需要精細控制（例如強制登出）

JWT 適合：API 服務、微服務架構、需要跨網域認證

Ytify 用 Session，因為簡單，不需要複雜的認證流程。

---

## 常見的坑

### 1. Cookie 不見了

```
症狀：Session ID 每次都變
原因：沒設 max_age，關掉瀏覽器就消失了
解法：設定 max_age
```

### 2. 跨網域 Cookie 不帶

```
症狀：API 在 api.example.com，前端在 example.com，Cookie 不帶
原因：預設 Cookie 只在同網域帶
解法：設定 domain=".example.com"
```

### 3. HTTPS 才能設 Secure Cookie

```
症狀：本機開發 Cookie 設不上去
原因：secure=True 但本機是 HTTP
解法：本機開發時 secure=False
```

---

## 總結

| 概念 | 說明 |
|------|------|
| HTTP 無狀態 | 每次請求都是獨立的 |
| Cookie | 瀏覽器儲存，每次請求自動帶上 |
| Session | 伺服器儲存，用 Session ID 識別 |
| Session ID | 存在 Cookie 裡，對應伺服器的 Session 資料 |

Cookie + Session 的搭配，讓無狀態的 HTTP 也能「記住」使用者。

```python
session_id = request.cookies.get("session_id")
user_data = sessions[session_id]
```

這就是網站記住你的原理。
