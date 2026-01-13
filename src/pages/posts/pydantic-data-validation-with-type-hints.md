---
layout: ../../layouts/PostLayout.astro
title: Pydantic：用 Type Hints 驗證資料
date: 2026-01-14T03:08
description: Python 型別提示的威力、Pydantic 怎麼做資料驗證、為什麼 v2 用 Rust 重寫
tags:
  - Pydantic
  - Python
  - FastAPI
  - 型別
---

Python 是動態型別語言。

變數可以是任何型別，不用事先宣告。

```python
x = 1        # 是數字
x = "hello"  # 現在是字串
x = [1, 2]   # 現在是 list
```

這很方便，但也很危險。

你以為 `user_id` 是數字，結果前端傳了字串 `"abc"`。

程式爆炸。

---

## 問題：資料驗證很煩

API 收到請求，你要驗證：

- 必填欄位有沒有
- 型別對不對
- 範圍對不對（例如 age 要大於 0）
- 格式對不對（例如 email 要有 @）

手動寫很痛苦：

```python
def create_user(data):
    if "name" not in data:
        raise ValueError("name is required")
    if not isinstance(data["name"], str):
        raise ValueError("name must be string")
    if len(data["name"]) < 1:
        raise ValueError("name cannot be empty")

    if "age" not in data:
        raise ValueError("age is required")
    if not isinstance(data["age"], int):
        raise ValueError("age must be integer")
    if data["age"] < 0:
        raise ValueError("age must be positive")

    if "email" in data:
        if "@" not in data["email"]:
            raise ValueError("invalid email format")

    # 終於可以用資料了...
```

欄位一多，驗證程式碼比業務邏輯還長。

---

## Pydantic：用 Type Hints 定義資料

Pydantic 讓你用 Python 的 type hints 定義資料格式，它會**自動驗證**：

```python
from pydantic import BaseModel, Field, EmailStr

class User(BaseModel):
    name: str
    age: int = Field(ge=0)  # greater than or equal to 0
    email: EmailStr | None = None  # 選填

# 使用
user = User(name="小明", age=25, email="ming@example.com")
print(user.name)  # 小明
print(user.age)   # 25

# 驗證失敗
User(name="小明", age=-1)
# ValidationError: age must be greater than or equal to 0

User(name="小明", age="abc")
# ValidationError: age must be integer
```

定義一次，驗證自動完成。

---

## 和 FastAPI 的結合

[FastAPI](/posts/fastapi-why-i-switched-from-flask) 深度整合 Pydantic：

```python
from fastapi import FastAPI
from pydantic import BaseModel, HttpUrl

app = FastAPI()

class DownloadRequest(BaseModel):
    url: HttpUrl
    format: str = "mp4"
    quality: int = Field(ge=1, le=4, default=1)

@app.post("/download")
async def download(req: DownloadRequest):
    # 走到這裡，req 一定通過驗證了
    return {"url": req.url, "format": req.format}
```

如果請求不符合格式，FastAPI 自動回 422，還會告訴你哪個欄位錯了：

```json
{
  "detail": [
    {
      "loc": ["body", "quality"],
      "msg": "ensure this value is less than or equal to 4",
      "type": "value_error.number.not_le"
    }
  ]
}
```

不用自己寫任何驗證程式碼。

---

## 常用的欄位類型

```python
from pydantic import BaseModel, Field, EmailStr, HttpUrl
from typing import Optional
from datetime import datetime
from enum import Enum

class Format(str, Enum):
    mp4 = "mp4"
    webm = "webm"
    mp3 = "mp3"

class DownloadRequest(BaseModel):
    # 基本類型
    url: HttpUrl                    # 自動驗證是合法網址
    title: str                      # 字串，必填
    views: int                      # 整數，必填

    # 選填（有預設值）
    format: Format = Format.mp4     # 限定選項
    quality: int = Field(default=1, ge=1, le=4)  # 1-4 之間

    # 可以是 None
    description: Optional[str] = None

    # 更多驗證
    tags: list[str] = Field(default_factory=list, max_length=10)
    email: EmailStr | None = None   # 驗證 email 格式
    created_at: datetime = Field(default_factory=datetime.now)
```

| 類型 | 驗證內容 |
|------|----------|
| `str` | 是字串 |
| `int` | 是整數（會自動轉換 `"123"` → `123`） |
| `HttpUrl` | 是合法網址 |
| `EmailStr` | 是合法 email |
| `Enum` | 是列舉中的值 |
| `Field(ge=1)` | 大於等於 1 |
| `Field(max_length=10)` | 最多 10 個元素 |

---

## 自動型別轉換

Pydantic 會嘗試把資料轉成正確的型別：

```python
class Item(BaseModel):
    count: int
    price: float
    active: bool

# 這些都會成功
Item(count="10", price="99.9", active="true")
# count=10, price=99.9, active=True

Item(count=10.5, price=100, active=1)
# count=10, price=100.0, active=True
```

這在處理 HTTP 請求時很方便——query string 都是字串，Pydantic 自動轉成正確型別。

---

## 巢狀結構

```python
class Address(BaseModel):
    city: str
    street: str

class User(BaseModel):
    name: str
    addresses: list[Address]  # 巢狀

# 使用
data = {
    "name": "小明",
    "addresses": [
        {"city": "台北", "street": "忠孝東路"},
        {"city": "高雄", "street": "中正路"}
    ]
}

user = User(**data)
print(user.addresses[0].city)  # 台北
```

---

## 為什麼 Pydantic v2 這麼快

Pydantic v2（2023 年發布）用 **Rust** 重寫了核心驗證邏輯。

```
Pydantic v1: 純 Python
Pydantic v2: 核心用 Rust（pydantic-core）
```

效能提升：

| 操作 | v1 | v2 | 提升 |
|------|----|----|------|
| Model 驗證 | 1x | 5-50x | 快很多 |
| JSON 序列化 | 1x | 10x | 快很多 |

Rust 是編譯語言，執行速度比 Python 快幾十倍。

而且 Pydantic v2 用的是 Rust 的 `pyo3`，可以直接被 Python 呼叫。

---

## 如果要自幹驗證...

不用 Pydantic，自己寫驗證會是這樣：

```python
def validate_download_request(data: dict) -> dict:
    errors = []

    # url
    if "url" not in data:
        errors.append("url is required")
    elif not isinstance(data["url"], str):
        errors.append("url must be string")
    elif not data["url"].startswith(("http://", "https://")):
        errors.append("url must be valid URL")

    # format
    format_val = data.get("format", "mp4")
    if format_val not in ["mp4", "webm", "mp3"]:
        errors.append("format must be mp4, webm, or mp3")

    # quality
    quality = data.get("quality", 1)
    if not isinstance(quality, int):
        try:
            quality = int(quality)
        except:
            errors.append("quality must be integer")
    if isinstance(quality, int) and not (1 <= quality <= 4):
        errors.append("quality must be between 1 and 4")

    if errors:
        raise ValueError(errors)

    return {
        "url": data["url"],
        "format": format_val,
        "quality": quality
    }
```

這只是 3 個欄位，已經這麼長了。

用 Pydantic：

```python
class DownloadRequest(BaseModel):
    url: HttpUrl
    format: Literal["mp4", "webm", "mp3"] = "mp4"
    quality: int = Field(ge=1, le=4, default=1)
```

4 行搞定。

---

## Ytify 怎麼用 Pydantic

```python
# models/request.py
from pydantic import BaseModel, Field, HttpUrl
from typing import Optional
from enum import Enum

class VideoFormat(str, Enum):
    mp4 = "mp4"
    webm = "webm"
    mp3 = "mp3"

class DownloadRequest(BaseModel):
    url: HttpUrl
    format: VideoFormat = VideoFormat.mp4
    quality: int = Field(ge=1, le=4, default=1)
    audio_only: bool = False

class DownloadResponse(BaseModel):
    task_id: str
    status: str
    message: Optional[str] = None

# routes.py
@app.post("/download", response_model=DownloadResponse)
async def download(req: DownloadRequest):
    task_id = await queue.submit(req.url, req.format, req.quality)
    return DownloadResponse(
        task_id=task_id,
        status="queued",
        message="任務已加入佇列"
    )
```

`response_model` 也用 Pydantic，確保回應格式一致。

---

## 總結

| 沒有 Pydantic | 有 Pydantic |
|---------------|-------------|
| 手動寫 if-else 驗證 | 用 type hints 定義 |
| 每個欄位都要檢查 | 自動驗證 |
| 型別轉換自己寫 | 自動轉換 |
| 錯誤訊息自己組 | 自動產生詳細錯誤 |

```python
class User(BaseModel):
    name: str
    age: int = Field(ge=0)
    email: EmailStr
```

三行定義，Pydantic 幫你處理驗證、轉換、錯誤訊息。

這就是「用型別系統做驗證」的威力。
