---
layout: ../../layouts/PostLayout.astro
title: CORS：為什麼瀏覽器擋住我的請求
date: 2026-01-14T03:06
description: 跨來源資源共用是什麼、為什麼瀏覽器要擋、怎麼設定才能通
tags:
  - CORS
  - 前端
  - 後端
  - 安全性
---

前端 console 印出紅色錯誤：

```
Access to fetch at 'https://api.example.com' from origin 'https://example.com'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
on the requested resource.
```

每個前端工程師都被這個錯誤搞過。

**明明 API 是好的，用 Postman 測都正常，為什麼瀏覽器就是打不通？**

---

## 問題：同源政策

瀏覽器有一個安全機制叫**同源政策（Same-Origin Policy）**。

「同源」是指：**協定、網域、port 都一樣**。

| 網址 A | 網址 B | 同源嗎 |
|--------|--------|--------|
| https://example.com | https://example.com/page | ✓ 同源 |
| https://example.com | http://example.com | ✗ 協定不同 |
| https://example.com | https://api.example.com | ✗ 網域不同 |
| https://example.com | https://example.com:8080 | ✗ port 不同 |

如果不同源，瀏覽器預設會**擋住 JavaScript 發出的請求**。

```javascript
// 你的網站是 https://example.com
// 想打 https://api.example.com 的 API

fetch('https://api.example.com/data')
// 瀏覽器：「不同源，擋住。」
```

---

## 為什麼要擋

想像一個場景：

1. 你登入了網路銀行 `https://bank.com`
2. 你順便逛了一個惡意網站 `https://evil.com`
3. 惡意網站的 JavaScript 偷偷發請求到 `https://bank.com/transfer?to=hacker&amount=10000`
4. 因為你登入過，瀏覽器會自動帶上 Cookie
5. 銀行收到請求，以為是你本人操作
6. 錢就這樣被轉走了

**同源政策就是為了防止這種攻擊。**

惡意網站的 JavaScript 不能隨便打你登入過的其他網站 API。

---

## 但我真的需要跨來源請求

有時候跨來源是合理的：

- 前端 `example.com`，API 在 `api.example.com`
- [Tampermonkey 腳本](/posts/tampermonkey-inject-code-into-any-website)在 YouTube 打 Ytify 的 API
- 第三方服務整合

這時候就需要 **CORS（Cross-Origin Resource Sharing）**。

CORS 是一種機制，讓伺服器告訴瀏覽器：「這個來源的請求，我允許。」

---

## CORS 怎麼運作

### 簡單請求

如果請求符合以下條件，瀏覽器會直接發出去：

- 方法是 GET、HEAD、POST
- 只有基本的 Header（Accept、Content-Type 等）
- Content-Type 是 `text/plain`、`multipart/form-data`、`application/x-www-form-urlencoded`

瀏覽器發請求，伺服器回應時帶上：

```
Access-Control-Allow-Origin: https://example.com
```

瀏覽器看到這個 header，就知道「伺服器允許這個來源」，放行。

### 預檢請求（Preflight）

如果請求不符合「簡單請求」的條件（例如 `Content-Type: application/json`），瀏覽器會先發一個 **OPTIONS 請求**，問伺服器「我可以發這個請求嗎？」

```
1. 瀏覽器：OPTIONS /api/data
   Origin: https://example.com
   Access-Control-Request-Method: POST
   Access-Control-Request-Headers: Content-Type

2. 伺服器：200 OK
   Access-Control-Allow-Origin: https://example.com
   Access-Control-Allow-Methods: POST, GET, OPTIONS
   Access-Control-Allow-Headers: Content-Type

3. 瀏覽器：「伺服器說可以，那我發真正的請求」
   POST /api/data
   Content-Type: application/json
```

如果伺服器沒有正確回應 OPTIONS，真正的請求根本不會發出去。

---

## 後端怎麼設定

### FastAPI

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://example.com", "https://www.youtube.com"],
    allow_credentials=True,  # 允許帶 Cookie
    allow_methods=["*"],     # 允許所有方法
    allow_headers=["*"],     # 允許所有 header
)
```

### Express (Node.js)

```javascript
const cors = require('cors');

app.use(cors({
    origin: ['https://example.com'],
    credentials: true
}));
```

### Nginx

```nginx
location /api {
    add_header 'Access-Control-Allow-Origin' 'https://example.com';
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
    add_header 'Access-Control-Allow-Headers' 'Content-Type';

    if ($request_method = 'OPTIONS') {
        return 204;
    }
}
```

---

## Ytify 的 CORS 設定

Ytify 要允許 [Tampermonkey 腳本](/posts/tampermonkey-inject-code-into-any-website)從 YouTube 頁面打 API：

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://www.youtube.com",
        "https://youtube.com",
        "https://m.youtube.com",  # 手機版
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

這樣在 YouTube 頁面執行的腳本就能打 Ytify 的 API 了。

---

## 常見的坑

### 1. allow_origins 不能用 * 又要 credentials

```python
# 錯誤：credentials=True 時，origin 不能是 *
allow_origins=["*"],
allow_credentials=True,
# 瀏覽器會擋

# 正確：明確列出允許的來源
allow_origins=["https://example.com"],
allow_credentials=True,
```

### 2. 忘記處理 OPTIONS

```python
# 有些框架不會自動處理 OPTIONS
# 要確保 OPTIONS 請求有正確回應

@app.options("/api/{path:path}")
async def options_handler():
    return Response(status_code=204)
```

### 3. Nginx 蓋掉了 header

```nginx
# 如果 Nginx 在 FastAPI 前面，可能會蓋掉 CORS header
# 要在 Nginx 或 FastAPI 其中一個設定就好，不要兩邊都設
```

### 4. http vs https

```
前端：https://example.com
API：http://api.example.com  # 注意是 http

瀏覽器：「協定不同，而且 http 不安全，擋住」
```

---

## 如果要自幹 CORS 處理...

```python
from fastapi import FastAPI, Request, Response

app = FastAPI()

ALLOWED_ORIGINS = ["https://example.com"]

@app.middleware("http")
async def cors_middleware(request: Request, call_next):
    origin = request.headers.get("origin")

    # 處理 preflight
    if request.method == "OPTIONS":
        response = Response(status_code=204)
    else:
        response = await call_next(request)

    # 檢查來源是否允許
    if origin in ALLOWED_ORIGINS:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type"

    return response
```

核心就是：根據 `Origin` header 決定要不要加 `Access-Control-Allow-*` header。

---

## CORS 只是瀏覽器的限制

重要的是：**CORS 只在瀏覽器生效**。

| 環境 | 有 CORS 限制嗎 |
|------|----------------|
| 瀏覽器 JavaScript | 有 |
| curl / Postman | 沒有 |
| 後端發請求 | 沒有 |
| 手機 App | 沒有 |

所以用 Postman 測都正常，瀏覽器就不行——因為只有瀏覽器在執行同源政策。

這也是為什麼 CORS 不是真正的「安全機制」，它只是保護**使用者的瀏覽器**不被惡意網站利用。

---

## 總結

| 問題 | 答案 |
|------|------|
| CORS 是什麼 | 跨來源資源共用，讓不同來源可以互相請求 |
| 為什麼要有這個限制 | 防止惡意網站偷發請求 |
| 怎麼解決 | 後端設定 `Access-Control-Allow-Origin` |
| Preflight 是什麼 | 瀏覽器先發 OPTIONS 問伺服器可不可以 |

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-frontend.com"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

這幾行程式碼，讓你不再被紅色錯誤困擾。
