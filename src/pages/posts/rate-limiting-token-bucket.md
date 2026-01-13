---
layout: ../../layouts/PostLayout.astro
title: Rate Limiting：為什麼你的 API 需要限流
date: 2026-01-14T03:02
description: 令牌桶演算法是什麼、為什麼要限流、slowapi 怎麼用
tags:
  - Rate Limiting
  - API
  - 後端
  - Python
---

[Ytify](/posts/ytify-self-hosted-youtube-downloader) 上線後，我分享給幾個朋友用。

其中一個朋友很興奮，同時開了 10 個下載。

然後我的伺服器就卡死了。

---

## 為什麼要限流

不限流會發生什麼事：

| 情境 | 後果 |
|------|------|
| 有人狂刷 API | 伺服器資源被吃光 |
| 爬蟲來掃 | 頻寬被占滿 |
| 惡意攻擊 | 服務癱瘓 |
| Bug 導致無限重試 | 自己打爆自己 |

限流就是：**規定每個人在一段時間內只能發多少請求**。

超過就拒絕，回 `429 Too Many Requests`。

---

## 限流的策略

### 1. 固定窗口（Fixed Window）

最簡單的做法：每分鐘重置計數器。

```
時間軸：
|-------- 第1分鐘 --------|-------- 第2分鐘 --------|
     請求 1,2,3,4,5              計數器歸零
        ↓
   到達上限，拒絕
```

問題：**窗口邊界會有突刺**。

如果限制 10 次/分鐘：

- 0:59 發 10 個請求 ✓
- 1:00 計數器歸零
- 1:01 又發 10 個請求 ✓

結果：2 秒內發了 20 個請求，限流形同虛設。

### 2. 滑動窗口（Sliding Window）

改良版：不是固定時間點重置，而是看「過去一分鐘內」的請求數。

```
現在是 1:30
過去一分鐘 = 0:30 ~ 1:30 的請求數
```

解決了突刺問題，但要記錄每個請求的時間戳，記憶體開銷大。

### 3. 令牌桶（Token Bucket）

最優雅的解法。

想像一個桶子：

1. 桶子裡有令牌，每個請求消耗一個令牌
2. 桶子會定期補充令牌
3. 桶子有容量上限，滿了就不補了

```
桶子容量：10 個令牌
補充速度：每秒 2 個

時間 0: 桶裡有 10 個令牌
請求 1: 消耗 1 個，剩 9 個 ✓
請求 2: 消耗 1 個，剩 8 個 ✓
...
請求 10: 消耗 1 個，剩 0 個 ✓
請求 11: 沒有令牌了 ✗

時間 1 秒: 補充 2 個，現在有 2 個
請求 12: 消耗 1 個，剩 1 個 ✓
```

好處：

- **允許突發流量**：桶子有容量，可以應對短時間的請求高峰
- **長期平均可控**：補充速度決定了長期的平均請求率
- **實作簡單**：不用記錄每個請求的時間戳

---

## 如果要自幹一個令牌桶...

```python
import time

class TokenBucket:
    def __init__(self, capacity: int, refill_rate: float):
        """
        capacity: 桶子容量（最大令牌數）
        refill_rate: 每秒補充的令牌數
        """
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.tokens = capacity  # 一開始是滿的
        self.last_refill = time.time()

    def _refill(self):
        """補充令牌"""
        now = time.time()
        elapsed = now - self.last_refill

        # 根據經過的時間補充令牌
        new_tokens = elapsed * self.refill_rate
        self.tokens = min(self.capacity, self.tokens + new_tokens)

        self.last_refill = now

    def consume(self, tokens: int = 1) -> bool:
        """嘗試消耗令牌，成功回傳 True"""
        self._refill()

        if self.tokens >= tokens:
            self.tokens -= tokens
            return True
        return False


# 使用
bucket = TokenBucket(capacity=10, refill_rate=2)

for i in range(15):
    if bucket.consume():
        print(f"請求 {i+1}: 通過")
    else:
        print(f"請求 {i+1}: 被限流")
    time.sleep(0.3)
```

輸出：
```
請求 1: 通過
請求 2: 通過
...
請求 10: 通過
請求 11: 被限流
請求 12: 通過     # 過了一點時間，補充了令牌
請求 13: 被限流
請求 14: 通過
...
```

---

## 用 slowapi 實作

自己寫當然可以，但 [slowapi](https://github.com/laurentS/slowapi) 已經幫你包好了：

```python
from fastapi import FastAPI, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# 用 IP 當作識別 key
limiter = Limiter(key_func=get_remote_address)
app = FastAPI()
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={"error": "請求太頻繁，請稍後再試"}
    )

@app.post("/download")
@limiter.limit("10/minute")  # 每分鐘 10 次
async def download(request: Request):
    ...

@app.get("/info")
@limiter.limit("30/minute")  # 查詢可以多一點
async def get_info(request: Request):
    ...
```

就這麼簡單。超過限制就自動回 429。

---

## Ytify 的限流設定

```python
# 不同端點不同限制
@limiter.limit("30/minute")   # 查詢影片資訊
async def get_info(): ...

@limiter.limit("10/minute")   # 下載影片
async def download(): ...

@limiter.limit("5/minute")    # 下載播放清單（更吃資源）
async def download_playlist(): ...

@limiter.limit("2/hour")      # 更新 yt-dlp（不需要常用）
async def update_ytdlp(): ...
```

根據操作的「重量」設定不同限制：

- 查詢資訊：輕量，可以多一點
- 下載影片：吃頻寬，要限制
- 更新 yt-dlp：幾乎不用，嚴格限制

---

## 進階：分散式限流

單機限流很簡單，但如果你有多台伺服器呢？

```
使用者 → Load Balancer → 伺服器 A（限流 10/分鐘）
                       → 伺服器 B（限流 10/分鐘）
```

使用者可以對 A 發 10 個，對 B 發 10 個，總共 20 個。

解法：用 Redis 存計數器，所有伺服器共用同一個。

```python
from slowapi import Limiter
from slowapi.util import get_remote_address
import redis

# 用 Redis 當 storage
limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="redis://localhost:6379"
)
```

這樣所有伺服器看到的是同一個計數器。

---

## 繞過限流的方法（攻擊者視角）

知道攻擊手法才能更好地防禦：

| 手法 | 防禦 |
|------|------|
| 換 IP | 用帳號、Session 限流，不只靠 IP |
| 分散請求 | 設定合理的總體 QPS 上限 |
| 慢速攻擊 | 限制同時連線數 |
| 偽造 Header | 檢查 X-Forwarded-For 的可信度 |

沒有完美的限流，但有限流總比沒有好。

---

## 總結

| 沒有限流 | 有限流 |
|----------|--------|
| 一個人就能打爆伺服器 | 單一來源影響有限 |
| 爬蟲隨便爬 | 爬蟲要排隊 |
| 成本不可控 | 資源使用可預測 |

限流是 API 設計的基本功。

你可以選擇自己實作令牌桶，也可以用 slowapi 這種現成的套件。

重點是：**上線前就要想好，不要等被打爆才後悔**。

```python
@limiter.limit("10/minute")
async def your_api():
    ...
```

一行裝飾器，省下很多麻煩。
