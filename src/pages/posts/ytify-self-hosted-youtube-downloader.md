---
layout: ../../layouts/PostLayout.astro
title: 自己架 YouTube 下載器，不用再忍受廣告和限速
date: 2026-01-14T02:19
description: 用 FastAPI + yt-dlp 架一個自己的 YouTube 下載服務，支援 WebSocket 即時進度、多租戶隔離、Cloudflare Tunnel 穿透
tags:
  - FastAPI
  - Python
  - yt-dlp
  - WebSocket
  - Docker
---

每次要下載 YouTube 影片都很煩。

Google 搜尋「YouTube 下載」，出來一堆線上工具。

點進去，廣告蓋滿整個畫面。

關掉，又跳一個。

好不容易找到下載按鈕，按下去，「請等待 60 秒」。

等完，下載速度 100KB/s。

**我只是想下載一個 5 分鐘的影片，搞了 10 分鐘。**

後來我發現有個東西叫 [yt-dlp](https://github.com/yt-dlp/yt-dlp)。

命令列工具，開源的。貼網址就能下載，沒廣告、沒限速，速度直接拉滿——這才是人該用的東西。

但每次都要開終端機、打指令，還是有點麻煩。

而且我想在手機上用，想分享給朋友用，命令列不是每個人都會。

**所以我架了一個 Web 服務。**

把 yt-dlp 包成 API，前端做個介面，貼網址、選畫質、按下載。

自己用爽，也能分享給朋友。

---

## 整體架構

技術棧長這樣：

| 層級 | 技術 | 為什麼選它 |
|------|------|------|
| 後端框架 | [FastAPI](/posts/fastapi-why-i-switched-from-flask) | yt-dlp 是 Python 寫的，FastAPI 可以直接 import，不用開子進程 |
| 下載核心 | [yt-dlp](https://github.com/yt-dlp/yt-dlp) | 比 youtube-dl 更新更快，YouTube 改版也能跟上 |
| 即時推送 | [WebSocket](/posts/websocket-real-time-without-polling) | 雙向通信，進度有更新才推，不用前端一直問 |
| 資料庫 | [SQLite](/posts/sqlite-the-database-you-already-have) | 單檔案資料庫，不用裝 MySQL，適合個人服務 |
| 內網穿透 | [Cloudflare Tunnel](/posts/cloudflare-tunnel-expose-localhost-without-port-forwarding) | 不用開 port、不用固定 IP，三行指令搞定 |
| 前端 | 原生 HTML/CSS/JS | 不想為了一個下載頁面引入 React |

[FastAPI](/posts/fastapi-why-i-switched-from-flask) 還有一個好處：原生支援非同步。

下載是 I/O 密集的操作（大部分時間在等網路），非同步可以同時處理多個下載請求，不會卡住。

---

## 下載進度怎麼推

下載影片不是一瞬間的事，使用者會想知道「現在下載到哪了」。

一開始我用輪詢，前端每秒打一次 API 問進度。

可以動，但用了幾天後發現一個問題：**同時下載 3 個影片時，伺服器光是回答進度查詢就要處理 9 個請求/秒**。

其實大部分時候進度根本沒變，卻一直在白白發請求。

後來改成 **[WebSocket](/posts/websocket-real-time-without-polling)**——一種雙向通信協定，連線建立後，後端有更新就推，沒更新就不推。

```
前端                    後端
  |                       |
  |--- 建立 WebSocket --->|
  |                       |
  |<-- 進度 10% ----------|
  |<-- 進度 25% ----------|
  |<-- 進度 50% ----------|
  |<-- 進度 100% 完成 ----|
  |                       |
```

[FastAPI](/posts/fastapi-why-i-switched-from-flask) 原生支援 WebSocket：

```python
@router.websocket("/ws/progress/{task_id}")
async def websocket_progress(websocket: WebSocket, task_id: str):
    await websocket.accept()
    # 當進度更新時，推送給前端
    await websocket.send_json({
        "progress": 50,
        "speed": "2.5MB/s",
        "eta": "00:30"
    })
```

yt-dlp 本身有 progress hook（進度回調函數），每次下載進度更新都會觸發。

我只要在 callback 裡面把資料推到 WebSocket 就好，不用自己算進度。

---

## 多人用怎麼辦

自己用沒問題，但分享給朋友用就暴露出兩個坑。

### 下載歷史混在一起

朋友 A 一開瀏覽器，看得到朋友 B 的下載歷史。

這不行。

一開始想做登入系統，但太麻煩了。後來妥協：**用 Session ID 區分**。

每個瀏覽器第一次訪問時，後端會發一個隨機 ID 存在 Cookie 裡。之後查歷史記錄就只回傳這個 ID 的資料。

```python
def get_history(session_id: str = None, client_ip: str = None):
    # 優先用 session_id，沒有就用 IP
    if session_id:
        return db.query(session_id=session_id)
    return db.query(client_ip=client_ip)
```

不是完美的隔離（清 Cookie 就變新用戶），但對於「朋友借用」的場景夠用了。

### 有人狂刷下載

另一個坑：朋友 C 一個人同時開 10 個下載，把我的頻寬吃光。

解法是 **Rate Limit**，用 [slowapi](https://github.com/laurentS/slowapi) 限制每個 IP 的請求頻率：

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/download")
@limiter.limit("10/minute")  # 每分鐘最多 10 次
async def download(request: Request):
    ...
```

超過就回 429 Too Many Requests。想搞事也搞不動。

---

## 從外面連進來

伺服器跑在家裡的電腦，但我想從公司、從手機連進來。

傳統做法是設定路由器的 port forwarding（連接埠轉發）。

我試過，遇到三個問題：

1. 路由器介面超難用，設定完還不一定會動
2. 我的網路沒有固定 IP，重開機就換一個
3. 社區網路根本進不去路由器設定頁面

搞了一個晚上，放棄。

後來發現 [Cloudflare Tunnel](/posts/cloudflare-tunnel-expose-localhost-without-port-forwarding)。

原理是在你的電腦上跑一個 agent，主動連到 Cloudflare 的伺服器。外面的請求進來時，Cloudflare 再轉給你。

不用開 port，不用固定 IP，不用動路由器。

```bash
cloudflared tunnel create ytify
cloudflared tunnel route dns ytify your-domain.com
cloudflared tunnel run ytify
```

三行指令，服務就能從外網存取了。這才是 2024 年該有的做法。

---

## 這套服務還有很多故事

寫到這裡才發現，一個「簡單的下載工具」涉及的東西比想像多。

最有趣的是後來才加的功能：

- **任務佇列** — 一開始沒想到要做，結果朋友同時下載 10 個影片，頻寬直接吃光，伺服器卡到不行
- **yt-dlp 自動更新** — YouTube 改版的速度比我想像快，隔幾週 yt-dlp 就會壞掉，要不是做了自動更新，早就放棄維護了
- **Tampermonkey 腳本** — 在 YouTube 頁面直接加下載按鈕，這個幾乎是最後才想到的，但用起來最爽
- **Docker 打包** — 朋友說想自己架一個，我才意識到環境設定有多麻煩，包成 container 後一行指令就能跑

這些坑都值得單獨寫一篇。

---

GitHub Repo: [Jeffrey0117/Ytify](https://github.com/Jeffrey0117/Ytify)
