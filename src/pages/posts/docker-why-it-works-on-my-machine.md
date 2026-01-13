---
layout: ../../layouts/PostLayout.astro
title: Docker：終結「在我電腦上可以跑」的魔咒
date: 2026-01-14T03:01
description: 為什麼要用 Docker、容器 vs 虛擬機、Dockerfile 怎麼寫
tags:
  - Docker
  - DevOps
  - 部署
---

「在我電腦上可以跑啊。」

這句話是工程師吵架的起點。

你寫的程式在你的電腦上運作正常，但部署到伺服器就爆炸。

為什麼？

因為環境不一樣。

---

## 環境地獄

一個 Python 專案要跑起來，需要：

- Python 3.11（不是 3.10，不是 3.12）
- 一堆 pip 套件（版本要對）
- ffmpeg（系統指令，不是 Python 套件）
- 特定的環境變數
- 特定的資料夾結構

你的電腦有這些，伺服器不一定有。

更慘的是，伺服器上可能已經有其他專案，它需要 Python 3.9，和你的專案衝突。

**Docker 解決的就是這個問題：把環境一起打包。**

---

## 容器 vs 虛擬機

「打包環境」聽起來像虛擬機（VM），但 Docker 不是虛擬機。

| | 虛擬機 | Docker 容器 |
|--|--------|-------------|
| 包含什麼 | 整個作業系統 | 只有應用程式和依賴 |
| 大小 | 幾 GB | 幾百 MB |
| 啟動時間 | 幾分鐘 | 幾秒 |
| 效能損耗 | 10-20% | 幾乎沒有 |
| 隔離程度 | 完全隔離 | 共用 kernel |

虛擬機是「整台電腦的模擬」，Docker 容器是「只打包應用程式需要的東西」。

```
虛擬機：
┌─────────────────────┐
│  你的應用程式         │
├─────────────────────┤
│  完整的 Guest OS     │  ← 幾 GB
├─────────────────────┤
│  Hypervisor         │
├─────────────────────┤
│  Host OS            │
└─────────────────────┘

Docker：
┌─────────────────────┐
│  你的應用程式         │
├─────────────────────┤
│  必要的 libraries    │  ← 幾百 MB
├─────────────────────┤
│  Docker Engine      │
├─────────────────────┤
│  Host OS            │
└─────────────────────┘
```

Docker 容器共用 Host 的 kernel，所以輕量、快速。

---

## Dockerfile：環境的說明書

Dockerfile 就是告訴 Docker「怎麼建立這個環境」：

```dockerfile
# 從 Python 3.11 開始
FROM python:3.11-slim

# 裝系統套件（ffmpeg）
RUN apt-get update && apt-get install -y ffmpeg

# 設定工作目錄
WORKDIR /app

# 複製依賴清單，先裝依賴
COPY requirements.txt .
RUN pip install -r requirements.txt

# 複製程式碼
COPY . .

# 開放 port
EXPOSE 8765

# 啟動指令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8765"]
```

這就是 [Ytify](/posts/ytify-self-hosted-youtube-downloader) 的 Dockerfile（簡化版）。

有了這個檔案，任何人都能用一行指令建立一模一樣的環境：

```bash
docker build -t ytify .
docker run -p 8765:8765 ytify
```

---

## 為什麼先複製 requirements.txt

你可能注意到 Dockerfile 裡面：

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
```

為什麼不直接 `COPY . .` 然後再 `pip install`？

因為 **Docker 有快取機制**。

每一行指令都會建立一層「layer」，如果這一層沒有變化，就會用快取。

```
COPY requirements.txt .  ← 套件清單沒變，用快取
RUN pip install ...      ← 用快取，不用重新下載
COPY . .                 ← 程式碼變了，這層要重建
```

如果把 `COPY . .` 放前面，每次改程式碼都要重新 `pip install`，浪費時間。

這叫 **multi-stage 最佳化**——把不常變的放前面。

---

## docker-compose：多個容器一起管理

Ytify 不只有 Python 應用程式，還有：

- Watchtower（自動更新容器）
- 未來可能有 Redis、資料庫

用 docker-compose 可以一次管理多個容器：

```yaml
# docker-compose.yml
version: '3.8'

services:
  ytify:
    build: .
    ports:
      - "8765:8765"
    volumes:
      - ./downloads:/app/downloads
      - ./data:/app/data
    restart: unless-stopped

  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 300
    restart: unless-stopped
```

```bash
# 一行指令，全部啟動
docker-compose up -d

# 看 log
docker-compose logs -f ytify

# 停止
docker-compose down
```

---

## Volume：資料要持久化

容器是「用完即丟」的，容器刪掉裡面的資料就不見了。

但下載的影片、資料庫檔案要保留，怎麼辦？

用 **Volume**（掛載卷）：

```yaml
volumes:
  - ./downloads:/app/downloads  # 左邊是 host，右邊是容器內
```

這樣 `/app/downloads` 裡面的檔案其實存在 host 的 `./downloads`，容器刪掉也不會消失。

---

## 常用指令

```bash
# 建立 image
docker build -t myapp .

# 執行容器
docker run -d -p 8080:8080 myapp

# 看正在跑的容器
docker ps

# 看 log
docker logs -f 容器ID

# 進入容器內部
docker exec -it 容器ID bash

# 停止容器
docker stop 容器ID

# 刪除容器
docker rm 容器ID

# 刪除 image
docker rmi myapp

# 清理沒用的東西
docker system prune
```

---

## 如果要自幹一個簡易版容器...

Docker 底層用的是 Linux 的 namespace 和 cgroup：

```python
# 概念示意（實際上要用 C 和 syscall）
import os

def run_in_container(command):
    # 1. 建立新的 namespace（隔離檔案系統、網路、process）
    os.unshare(CLONE_NEWNS | CLONE_NEWPID | CLONE_NEWNET)

    # 2. 改變 root 目錄（chroot）
    os.chroot("/path/to/container/rootfs")
    os.chdir("/")

    # 3. 設定資源限制（cgroup）
    with open("/sys/fs/cgroup/memory/limit", "w") as f:
        f.write("512M")  # 限制記憶體 512MB

    # 4. 執行指令
    os.execvp(command[0], command)
```

核心概念：

| 技術 | 功能 |
|------|------|
| **Namespace** | 隔離：讓容器看不到 host 的 process、網路 |
| **Cgroup** | 資源限制：限制 CPU、記憶體使用量 |
| **Chroot** | 檔案系統隔離：容器有自己的根目錄 |
| **Union FS** | 分層：image 的每一層可以共用、快取 |

Docker 把這些 Linux 原生功能包裝成好用的工具。

---

## 什麼時候不該用 Docker

| 情境 | 說明 |
|------|------|
| 本機開發 | 有時候直接跑比較方便 |
| GUI 應用程式 | Docker 主要是跑 server |
| 需要 GPU | 要額外設定 nvidia-docker |
| Windows 容器 | 支援有限 |

---

## 總結

| 沒有 Docker | 有 Docker |
|-------------|-----------|
| 「在我電腦上可以跑」 | 在哪都能跑 |
| 環境設定文件寫半天 | 一個 Dockerfile |
| 部署要手動裝一堆東西 | `docker run` 搞定 |
| 不同專案環境衝突 | 每個容器獨立 |
| 回滾版本很麻煩 | 換個 image tag 就好 |

Docker 不是銀彈，但對於部署 server 應用程式，它解決了「環境不一致」這個大問題。

朋友說想自己架 [Ytify](/posts/ytify-self-hosted-youtube-downloader)，我不用寫安裝教學，直接給他：

```bash
docker run -d -p 8765:8765 jeffrey0117/ytify
```

一行指令，跑起來了。

這就是 Docker。
