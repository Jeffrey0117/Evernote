---
layout: ../../layouts/PostLayout.astro
title: Cloudflare Tunnel：不用開 port 也能讓外網連進來
date: 2026-01-14T02:37
description: 內網穿透的幾種方案比較，以及反向隧道的原理
tags:
  - Cloudflare
  - 內網穿透
  - 網路
---

伺服器跑在家裡的電腦，我想從公司、從手機連進來。

聽起來很簡單，做起來超麻煩。

---

## 傳統做法：Port Forwarding

教學文章都說：「去路由器設定 port forwarding」。

我試了，遇到三個問題：

1. **路由器介面超難用** — 每家廠牌不一樣，設定完還不一定會動
2. **沒有固定 IP** — 中華電信隔幾天就換一個 IP，每次都要重設
3. **社區網路根本進不去** — 路由器是大樓管理的，我連設定頁面都看不到

搞了一個晚上，放棄。

---

## 比較：內網穿透的幾種方案

| 方案 | 原理 | 優點 | 缺點 |
|------|------|------|------|
| **Port Forwarding** | 路由器開 port | 直連，延遲低 | 要動路由器、要固定 IP |
| **ngrok** | 反向隧道 | 一行指令 | 免費版網址會變、有流量限制 |
| **frp** | 反向隧道 | 開源、可自架 | 要另外租一台有公網 IP 的伺服器 |
| **Cloudflare Tunnel** | 反向隧道 | 免費、穩定、有 CDN | 要有自己的域名 |

我最後選了 Cloudflare Tunnel。

原因是：

1. 我本來就有域名放在 Cloudflare
2. 免費版沒有流量限制
3. 順便享受 Cloudflare 的 CDN 和 DDoS 防護

---

## 三行指令搞定

```bash
# 1. 建立隧道
cloudflared tunnel create ytify

# 2. 設定 DNS
cloudflared tunnel route dns ytify download.example.com

# 3. 啟動
cloudflared tunnel run ytify
```

就這樣，`download.example.com` 就能連到我家裡的電腦了。

不用開 port、不用固定 IP、不用動路由器。

---

## 但我好奇，反向隧道是怎麼運作的

為什麼不用開 port 也能讓外面連進來？

### 傳統的方式：外面主動連進來

```
外網使用者 ──────────────→ 路由器 ──────────────→ 你的電腦
            需要 port forwarding
            需要知道你的 IP
```

問題是：

1. 路由器預設會擋掉外面的連線（NAT）
2. 外面的人不知道你的 IP

### 反向隧道：你主動連出去

```
你的電腦 ─────→ Cloudflare 伺服器 ←───── 外網使用者
         主動建立連線
         保持連線不斷              透過 Cloudflare 中轉
```

關鍵在於：**是你主動連到 Cloudflare，而不是 Cloudflare 連到你**。

路由器不會擋「連出去」的連線。

連線建立後，Cloudflare 就能透過這條通道，把外面的請求轉給你。

### 如果要自幹一個簡單的反向隧道...

```python
# === 你的電腦（內網） ===
import socket
import threading

def tunnel_client():
    # 主動連到中繼伺服器
    tunnel = socket.socket()
    tunnel.connect(("relay.example.com", 9000))

    while True:
        # 收到中繼伺服器轉發的請求
        request = tunnel.recv(4096)

        # 轉給本地服務
        local = socket.socket()
        local.connect(("localhost", 8080))
        local.send(request)

        # 把回應送回去
        response = local.recv(4096)
        tunnel.send(response)
        local.close()

# === 中繼伺服器（公網） ===
def relay_server():
    # 等內網電腦連進來
    tunnel_sock = socket.socket()
    tunnel_sock.bind(("0.0.0.0", 9000))
    tunnel_sock.listen(1)
    tunnel_conn, _ = tunnel_sock.accept()

    # 接收外網請求
    public_sock = socket.socket()
    public_sock.bind(("0.0.0.0", 80))
    public_sock.listen(5)

    while True:
        client, _ = public_sock.accept()
        request = client.recv(4096)

        # 轉發給內網電腦
        tunnel_conn.send(request)
        response = tunnel_conn.recv(4096)

        # 回給外網使用者
        client.send(response)
        client.close()
```

實際的 Cloudflare Tunnel 比這複雜得多：

- 支援多條連線（連線池）
- 支援 WebSocket
- 加密傳輸
- 自動重連
- 負載均衡

但核心概念就是這個：**你主動連出去，建立一條隧道，外面的請求透過隧道進來**。

---

## 進階設定：config.yml

如果你有多個服務要穿透，可以用設定檔：

```yaml
# ~/.cloudflared/config.yml
tunnel: ytify
credentials-file: /home/user/.cloudflared/ytify.json

ingress:
  - hostname: download.example.com
    service: http://localhost:8765

  - hostname: blog.example.com
    service: http://localhost:3000

  # 預設規則（必須）
  - service: http_status:404
```

一個隧道，多個子域名，各自導到不同的本地服務。

---

## 研究完之後

理解反向隧道原理後，我更清楚 Cloudflare Tunnel 幫我省了多少事：

- 不用設定路由器
- 不用租有公網 IP 的伺服器
- 不用處理連線池、加密、重連
- 不用自己寫中繼伺服器
- 還免費送 CDN 和 DDoS 防護

如果你也想讓外網連到家裡的服務，Cloudflare Tunnel 是目前最省事的方案。

唯一的前提是：你要有一個域名，而且 DNS 要放在 Cloudflare。
