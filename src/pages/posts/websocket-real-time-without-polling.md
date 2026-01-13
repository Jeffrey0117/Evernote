---
layout: ../../layouts/PostLayout.astro
title: WebSocket：不用一直問「好了沒」的即時通訊
date: 2026-01-14T02:38
description: 從輪詢到 WebSocket 的演進，以及 WebSocket 握手的原理
tags:
  - WebSocket
  - JavaScript
  - Python
  - 即時通訊
---

做 [Ytify](/posts/ytify-self-hosted-youtube-downloader) 的時候，我需要顯示下載進度。

使用者按下「下載」後，要讓他知道「現在下載到哪了」。

一開始我用最直覺的方法：**輪詢（Polling）**。

---

## 輪詢：一直問「好了沒」

```javascript
// 前端：每秒問一次
setInterval(async () => {
    const res = await fetch(`/api/progress/${taskId}`);
    const data = await res.json();
    updateProgressBar(data.progress);
}, 1000);
```

可以動，但用了幾天後發現一個問題。

同時下載 3 個影片時，前端每秒發 3 個請求。

**其實大部分時候進度根本沒變**，卻一直在白白發請求。

而且輪詢有延遲——如果進度在 0.1 秒時更新，要等到下一次輪詢（最多 1 秒後）才會顯示。

---

## 比較：即時通訊的幾種方案

| 方案 | 原理 | 優點 | 缺點 |
|------|------|------|------|
| **輪詢** | 前端定時問 | 簡單 | 浪費頻寬、有延遲 |
| **Long Polling** | 伺服器等到有資料才回 | 減少無效請求 | 實作複雜、連線佔用 |
| **Server-Sent Events** | 伺服器單向推送 | 原生支援、自動重連 | 只能伺服器推、不能前端發 |
| **WebSocket** | 雙向即時通訊 | 延遲最低、雙向 | 要處理連線管理 |

對於「下載進度」這種場景，伺服器單向推送就夠了（SSE 可以搞定）。

但我後來想做「取消下載」功能——前端要能發訊息給後端。

所以選了 WebSocket。

---

## WebSocket：建立連線後，雙方都能隨時發訊息

```javascript
// 前端
const ws = new WebSocket(`ws://localhost:8765/ws/progress/${taskId}`);

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    updateProgressBar(data.progress);
};

// 要取消下載時
ws.send(JSON.stringify({ action: "cancel" }));
```

```python
# 後端（FastAPI）
@router.websocket("/ws/progress/{task_id}")
async def websocket_progress(websocket: WebSocket, task_id: str):
    await websocket.accept()

    while True:
        # 有進度更新時推送
        progress = get_progress(task_id)
        await websocket.send_json(progress)

        # 也能收前端的訊息
        try:
            msg = await asyncio.wait_for(
                websocket.receive_json(),
                timeout=0.1
            )
            if msg.get("action") == "cancel":
                cancel_download(task_id)
        except asyncio.TimeoutError:
            pass
```

有更新才推，沒更新就不推。前端也能隨時發訊息。

---

## 但我好奇，WebSocket 是怎麼運作的

HTTP 是「一問一答」的協定——前端發請求，後端回應，結束。

WebSocket 怎麼做到「連線建立後，雙方都能隨時發訊息」？

### 答案：先用 HTTP 握手，然後升級協定

WebSocket 的建立過程：

```
前端                           後端
  |                              |
  |─── HTTP GET /ws ────────────→|
  |    Upgrade: websocket        |
  |    Connection: Upgrade       |
  |    Sec-WebSocket-Key: xxx    |
  |                              |
  |←── HTTP 101 Switching ───────|
  |    Upgrade: websocket        |
  |    Sec-WebSocket-Accept: yyy |
  |                              |
  |══════ WebSocket 連線 ════════|
  |    （不再是 HTTP 了）         |
  |←────────── 推送 ─────────────|
  |←────────── 推送 ─────────────|
  |───────────→ 發送 ───────────→|
```

1. 前端發一個特殊的 HTTP 請求，說「我想升級成 WebSocket」
2. 後端回 101，表示「好，我們升級」
3. 之後這條 TCP 連線就變成 WebSocket 協定了

### 如果要自幹一個簡單的 WebSocket 伺服器...

```python
import socket
import hashlib
import base64

def handle_websocket(client_socket):
    # 1. 收 HTTP 握手請求
    request = client_socket.recv(4096).decode()

    # 2. 取出 Sec-WebSocket-Key
    for line in request.split("\r\n"):
        if line.startswith("Sec-WebSocket-Key:"):
            key = line.split(": ")[1]
            break

    # 3. 計算回應的 Accept 值（RFC 6455 規定的算法）
    GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    accept = base64.b64encode(
        hashlib.sha1((key + GUID).encode()).digest()
    ).decode()

    # 4. 回傳握手回應
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n"
        "\r\n"
    )
    client_socket.send(response.encode())

    # 5. 現在可以收發 WebSocket 訊息了
    while True:
        # WebSocket 訊息有自己的格式（frame）
        # 這邊省略解析邏輯...
        frame = client_socket.recv(4096)
        message = decode_websocket_frame(frame)

        # 送訊息回去
        response_frame = encode_websocket_frame("收到: " + message)
        client_socket.send(response_frame)
```

實際的 WebSocket 實作還要處理：

- 訊息分片（大訊息拆成多個 frame）
- 遮罩（client 發的訊息要 mask）
- Ping/Pong（心跳檢測）
- 關閉連線的握手

但核心概念就是：**先用 HTTP 握手，然後升級成另一種協定**。

---

## 連線管理：誰訂閱了這個任務

一個下載任務可能有多個人在看進度（比如你開了兩個瀏覽器分頁）。

所以要有一個地方記錄「這個任務有哪些 WebSocket 連線在聽」：

```python
# services/websocket_manager.py
class ConnectionManager:
    def __init__(self):
        # task_id -> [websocket 連線們]
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, task_id: str, websocket: WebSocket):
        await websocket.accept()
        if task_id not in self.active_connections:
            self.active_connections[task_id] = []
        self.active_connections[task_id].append(websocket)

    def disconnect(self, task_id: str, websocket: WebSocket):
        self.active_connections[task_id].remove(websocket)

    async def broadcast(self, task_id: str, message: dict):
        """推送給所有訂閱這個任務的連線"""
        for ws in self.active_connections.get(task_id, []):
            await ws.send_json(message)
```

下載進度更新時：

```python
await manager.broadcast(task_id, {
    "progress": 50,
    "speed": "2.5MB/s",
    "eta": "00:30"
})
```

所有訂閱的連線都會收到更新。

---

## 研究完之後

理解 WebSocket 原理後，我更清楚它幫我省了多少事：

- 不用自己處理 HTTP 升級握手
- 不用自己實作 frame 編解碼
- 不用自己管理心跳和重連
- 不用自己處理連線池

而且 [FastAPI 原生支援 WebSocket](/posts/fastapi-why-i-switched-from-flask)，幾行程式碼就能建立即時通訊：

```python
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    await websocket.send_json({"hello": "world"})
```

---

## 哪些場景會用到

WebSocket 不只是下載進度，很多網頁功能都靠它：

| 場景 | 為什麼用 WebSocket |
|------|-------------------|
| **聊天室** | 對方發訊息要馬上看到，不能等輪詢 |
| **通知系統** | 有人按讚、留言、@你，要即時跳出來 |
| **協作編輯** | Google Docs 那種多人同時編輯，游標要即時同步 |
| **股票行情** | 價格一直在變，輪詢會漏掉波動 |
| **線上遊戲** | 玩家動作要即時同步，延遲一秒就輸了 |
| **直播互動** | 彈幕、送禮、投票，觀眾操作要即時顯示 |

你在用的 Facebook、Discord、Slack、Notion，背後都有 WebSocket。

下次看到網頁上有「即時」的東西，打開 DevTools 的 Network 分頁，篩選 WS，大概率能看到 WebSocket 連線。

---

如果你的應用需要即時更新，WebSocket 是比輪詢更好的選擇。

別再讓前端一直問「好了沒」了。
