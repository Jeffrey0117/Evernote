---
layout: ../../layouts/PostLayout.astro
title: SQLite：你早就在用的資料庫
date: 2026-01-14T02:36
description: 為什麼 SQLite 是個人專案的最佳選擇，以及資料庫索引的原理
tags:
  - SQLite
  - 資料庫
  - Python
---

每次開新專案，總會遇到一個問題：**資料要存在哪裡？**

最直覺的做法是存 JSON 檔案。

```python
import json

def save_data(data):
    with open("data.json", "w") as f:
        json.dump(data, f)
```

一開始很好用。

但資料變多之後，問題來了：

- 想找特定資料，要把整個檔案讀進來
- 想改一筆資料，要把整個檔案重寫
- 兩個程式同時寫入，資料就爛掉了

**這時候就需要資料庫。**

---

## 比較：SQLite vs MySQL vs PostgreSQL

| 資料庫 | 架構 | 適合場景 | 設定難度 |
|--------|------|----------|----------|
| **SQLite** | 單檔案 | 個人專案、嵌入式 | 零設定 |
| **MySQL** | Client-Server | 中型網站 | 要裝伺服器 |
| **PostgreSQL** | Client-Server | 大型專案、複雜查詢 | 要裝伺服器 |

MySQL 和 PostgreSQL 都是「Client-Server 架構」：

1. 你要先裝一個資料庫伺服器
2. 設定帳號密碼
3. 開一個 port
4. 應用程式透過網路連過去

對於個人專案來說，這太麻煩了。

SQLite 不一樣。它是「嵌入式資料庫」——整個資料庫就是一個檔案。

```python
import sqlite3

# 就這樣，資料庫建好了
conn = sqlite3.connect("data.db")
```

不用裝伺服器、不用設定、不用開 port。

檔案複製到另一台電腦，資料就跟著過去了。

---

## 我在 Ytify 裡怎麼用 SQLite

在 [Ytify](/posts/ytify-self-hosted-youtube-downloader)（我做的 YouTube 下載服務）裡，我用 SQLite 存下載歷史：

```python
# 建表
conn.execute("""
    CREATE TABLE IF NOT EXISTS download_history (
        task_id TEXT UNIQUE,
        video_id TEXT,
        title TEXT,
        status TEXT,
        client_ip TEXT,
        session_id TEXT,
        created_at TEXT
    )
""")
```

查詢某個使用者的下載歷史：

```python
def get_history(session_id):
    return conn.execute("""
        SELECT * FROM download_history
        WHERE session_id = ?
        ORDER BY created_at DESC
        LIMIT 100
    """, (session_id,)).fetchall()
```

SQL 的好處是：**你說你要什麼，它幫你找**。

不用自己寫迴圈、不用自己排序、不用自己處理檔案 I/O。

---

## 但我好奇，資料庫怎麼那麼快

一個檔案裡面有 10 萬筆資料，我說「找 session_id = 'abc123' 的資料」，它幾毫秒就找到了。

如果是 JSON 檔案，我要一筆一筆比對，要花好幾秒。

**差在哪裡？**

### 答案：索引（Index）

資料庫不是真的一筆一筆找，它用的是「索引」。

想像一本書：

- **沒有索引**：想找「Python」這個詞出現在哪裡，要從第一頁翻到最後一頁
- **有索引**：翻到書後面的索引頁，「Python: p.23, p.45, p.89」，直接跳過去

資料庫的索引也是一樣的道理。

### 所以如果要自幹一個簡單的索引...

```python
# 假設我們有一堆資料
data = [
    {"id": 1, "session_id": "abc", "title": "影片1"},
    {"id": 2, "session_id": "xyz", "title": "影片2"},
    {"id": 3, "session_id": "abc", "title": "影片3"},
    # ... 10 萬筆
]

# 沒有索引：O(n) 線性搜尋
def find_by_session_slow(session_id):
    result = []
    for item in data:  # 要跑 10 萬次
        if item["session_id"] == session_id:
            result.append(item)
    return result

# 有索引：O(1) 直接查表
index_by_session = {}  # session_id -> [資料位置]

def build_index():
    for i, item in enumerate(data):
        sid = item["session_id"]
        if sid not in index_by_session:
            index_by_session[sid] = []
        index_by_session[sid].append(i)

def find_by_session_fast(session_id):
    positions = index_by_session.get(session_id, [])
    return [data[i] for i in positions]
```

實際的資料庫用的是更複雜的資料結構（B-Tree），可以處理範圍查詢、排序等操作。

但核心概念一樣：**先建索引，查詢時就不用從頭掃到尾**。

### SQLite 建索引

```sql
-- 建立索引
CREATE INDEX idx_session_id ON download_history(session_id);

-- 之後這個查詢就會很快
SELECT * FROM download_history WHERE session_id = 'abc123';
```

建索引的代價是：

- 多佔一點硬碟空間
- 新增/修改資料時要更新索引，會慢一點

但對於「讀多寫少」的場景（像下載歷史），絕對值得。

---

## SQLite 的限制

SQLite 不是萬能的：

| 場景 | SQLite 行不行 |
|------|---------------|
| 單機、單應用程式 | 沒問題 |
| 多個應用程式同時讀 | 沒問題 |
| 多個應用程式同時寫 | 會卡（有鎖） |
| 資料量超過幾百 GB | 會慢 |
| 多台伺服器共用 | 不行 |

如果你的服務會長大到「多台伺服器、每秒幾千個寫入」，那一開始就該選 PostgreSQL。

但對於個人專案、prototype、嵌入式應用，SQLite 省下的麻煩遠大於它的限制。

---

## 研究完之後

理解索引原理後，我更清楚 SQLite 幫我省了多少事：

- 不用裝資料庫伺服器
- 不用設定帳號密碼
- 不用自己實作索引
- 不用自己處理並發鎖
- 備份就是複製檔案

下次開新專案，如果你也在猶豫「資料要存哪裡」，先試試 SQLite。

```python
import sqlite3
conn = sqlite3.connect("data.db")
```

就這一行，你就有一個功能完整的資料庫了。
