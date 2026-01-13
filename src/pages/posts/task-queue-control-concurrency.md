---
layout: ../../layouts/PostLayout.astro
title: 任務佇列：為什麼不能同時做太多事
date: 2026-01-14T03:04
description: 併發控制、生產者消費者模式、asyncio.Queue 實作
tags:
  - 任務佇列
  - 併發
  - Python
  - asyncio
---

[Ytify](/posts/ytify-self-hosted-youtube-downloader) 一開始沒有做任務佇列。

使用者按下載，後端就開始下載。

10 個人同時按，後端就同時下載 10 個影片。

然後我的小伺服器就爆了。

---

## 問題：資源是有限的

同時下載 10 個影片會怎樣：

| 資源 | 後果 |
|------|------|
| 頻寬 | 100Mbps 分給 10 個，每個只剩 10Mbps |
| CPU | 解碼、合併要運算，10 個同時跑 CPU 爆炸 |
| 記憶體 | 每個下載要 buffer，10 個同時開記憶體吃光 |
| 硬碟 | 同時寫 10 個檔案，I/O 排隊 |

結果就是：**每個下載都變超慢，還可能全部失敗**。

---

## 解法：排隊

與其同時做 10 件事每件都慢，不如：

1. 同時最多做 3 件事
2. 多的排隊
3. 做完一件再拿下一件

這就是**任務佇列**的概念。

```
使用者請求：下載 A, B, C, D, E, F, G, H, I, J

任務佇列：[D, E, F, G, H, I, J]  排隊中
正在執行：[A, B, C]              同時最多 3 個

A 完成 → 從佇列拿 D 開始執行
[E, F, G, H, I, J]  排隊中
[B, C, D]           正在執行
```

---

## 如果要自幹一個任務佇列...

### 基本版：用 list

```python
import asyncio

class SimpleQueue:
    def __init__(self, max_concurrent=3):
        self.max_concurrent = max_concurrent
        self.queue = []           # 等待中的任務
        self.running = 0          # 正在執行的數量

    async def submit(self, task_func, *args):
        """提交任務"""
        self.queue.append((task_func, args))
        await self._process()

    async def _process(self):
        """處理佇列"""
        while self.queue and self.running < self.max_concurrent:
            task_func, args = self.queue.pop(0)
            self.running += 1
            asyncio.create_task(self._run(task_func, args))

    async def _run(self, task_func, args):
        """執行單個任務"""
        try:
            await task_func(*args)
        finally:
            self.running -= 1
            await self._process()  # 完成後處理下一個
```

問題：這個實作有 race condition，多個協程同時操作 `queue` 和 `running` 可能出錯。

### 改良版：用 asyncio.Queue + Semaphore

```python
import asyncio

class TaskQueue:
    def __init__(self, max_concurrent=3):
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.queue = asyncio.Queue()
        self.results = {}  # task_id -> 結果

    async def start_workers(self, num_workers=5):
        """啟動 worker"""
        workers = [
            asyncio.create_task(self._worker())
            for _ in range(num_workers)
        ]
        return workers

    async def _worker(self):
        """Worker：從佇列拿任務執行"""
        while True:
            task_id, task_func, args = await self.queue.get()

            async with self.semaphore:  # 限制同時執行數量
                try:
                    result = await task_func(*args)
                    self.results[task_id] = {'status': 'done', 'result': result}
                except Exception as e:
                    self.results[task_id] = {'status': 'error', 'error': str(e)}

            self.queue.task_done()

    async def submit(self, task_id, task_func, *args):
        """提交任務到佇列"""
        self.results[task_id] = {'status': 'pending'}
        await self.queue.put((task_id, task_func, args))

    def get_status(self, task_id):
        """查詢任務狀態"""
        return self.results.get(task_id, {'status': 'not_found'})
```

使用：

```python
queue = TaskQueue(max_concurrent=3)

# 啟動 worker（通常在應用程式啟動時）
await queue.start_workers()

# 提交任務
await queue.submit('task-001', download_video, 'https://youtube.com/...')
await queue.submit('task-002', download_video, 'https://youtube.com/...')

# 查詢狀態
status = queue.get_status('task-001')
print(status)  # {'status': 'pending'} 或 {'status': 'done', 'result': ...}
```

---

## 生產者-消費者模式

任務佇列本質上是**生產者-消費者模式**：

```
生產者（API 端點）                消費者（Worker）
     │                                │
     │  submit task                   │
     ├───────────────→ [Queue] ───────┤
     │                                │  取出任務
     │                                │  執行下載
     │                                │  更新狀態
```

- **生產者**：接收使用者請求，把任務丟進佇列
- **佇列**：暫存任務，先進先出
- **消費者**：從佇列取任務，實際執行工作

好處：

| 優點 | 說明 |
|------|------|
| 解耦 | 接收請求和執行任務分開 |
| 削峰填谷 | 請求多時排隊，不會爆炸 |
| 可擴展 | 多開幾個 worker 就能處理更多 |
| 重試 | 失敗的任務可以重新放回佇列 |

---

## Ytify 的實作

```python
# services/queue.py
class DownloadQueue:
    def __init__(self, max_concurrent=3):
        self.max_concurrent = max_concurrent
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.tasks = {}  # task_id -> 任務資訊

    async def submit(self, task_id, url, options):
        """提交下載任務"""
        self.tasks[task_id] = {
            'status': 'queued',
            'url': url,
            'progress': 0
        }

        # 背景執行，不阻塞 API 回應
        asyncio.create_task(self._execute(task_id, url, options))

        return task_id

    async def _execute(self, task_id, url, options):
        """執行下載（受 semaphore 限制）"""
        # 等待取得執行權
        async with self.semaphore:
            self.tasks[task_id]['status'] = 'downloading'

            try:
                await download_with_ytdlp(
                    url,
                    options,
                    progress_callback=lambda p: self._update_progress(task_id, p)
                )
                self.tasks[task_id]['status'] = 'completed'
            except Exception as e:
                self.tasks[task_id]['status'] = 'failed'
                self.tasks[task_id]['error'] = str(e)

    def _update_progress(self, task_id, progress):
        """更新進度"""
        self.tasks[task_id]['progress'] = progress

    def get_status(self, task_id):
        """查詢狀態"""
        return self.tasks.get(task_id)

    def get_queue_info(self):
        """查詢佇列資訊"""
        queued = sum(1 for t in self.tasks.values() if t['status'] == 'queued')
        running = sum(1 for t in self.tasks.values() if t['status'] == 'downloading')

        return {
            'queued': queued,
            'running': running,
            'max_concurrent': self.max_concurrent
        }
```

API 端：

```python
@app.post("/api/download")
async def download(req: DownloadRequest):
    task_id = generate_task_id()

    # 提交到佇列，馬上回應
    await queue.submit(task_id, req.url, req.options)

    return {
        'task_id': task_id,
        'status': 'queued',
        'message': '任務已加入佇列'
    }

@app.get("/api/status/{task_id}")
async def get_status(task_id: str):
    return queue.get_status(task_id)
```

---

## Semaphore 是什麼

`asyncio.Semaphore` 是用來限制同時執行數量的工具：

```python
semaphore = asyncio.Semaphore(3)  # 最多同時 3 個

async def do_work():
    async with semaphore:  # 取得許可
        # 這裡同時最多 3 個協程在執行
        await some_io_operation()
    # 離開 with 區塊，自動釋放許可
```

原理很簡單：

1. Semaphore 有一個計數器，初始值是 3
2. `async with semaphore` 會把計數器 -1
3. 如果計數器變成 0，後面的要等
4. 離開 `with` 區塊，計數器 +1
5. 等待的協程被喚醒

---

## 進階：分散式佇列

如果任務量很大，單機的 `asyncio.Queue` 不夠用。

這時候要用專門的訊息佇列：

| 工具 | 特色 |
|------|------|
| **Redis Queue (RQ)** | 簡單，用 Redis 當 backend |
| **Celery** | 功能完整，支援排程、重試 |
| **RabbitMQ** | 企業級，可靠性高 |
| **Kafka** | 超大流量，日誌處理 |

Ytify 是個人專案，`asyncio.Semaphore` 就夠用了。

但如果要做成「公開服務」，可能要考慮 Celery + Redis。

---

## 總結

| 沒有任務佇列 | 有任務佇列 |
|-------------|-----------|
| 請求多少就同時做多少 | 最多同時做 N 個 |
| 資源搶奪，全部變慢 | 排隊執行，每個都快 |
| 伺服器容易崩潰 | 資源使用可控 |
| 沒辦法查詢進度 | 每個任務有狀態 |

任務佇列是後端系統的基本功。

記住這個原則：**控制併發，排隊處理，削峰填谷**。

```python
semaphore = asyncio.Semaphore(3)

async with semaphore:
    await do_heavy_work()
```

這幾行程式碼，救了我的伺服器。
