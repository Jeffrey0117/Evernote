---
layout: ../../layouts/PostLayout.astro
title: ffmpeg：影音處理的瑞士刀
date: 2026-01-14T03:07
description: 為什麼下載 YouTube 影片要用 ffmpeg、影音格式的基本概念、常用指令
tags:
  - ffmpeg
  - 影音處理
  - yt-dlp
---

用 [yt-dlp](/posts/yt-dlp-how-youtube-download-works) 下載 YouTube 影片時，你會看到這樣的訊息：

```
[Merger] Merging formats into "video.mp4"
```

下載完還要「Merge」是在幹嘛？

因為 **YouTube 的高畫質影片，音訊和視訊是分開的**。

yt-dlp 下載完之後，要用 ffmpeg 把它們合併起來。

---

## 為什麼要分開

YouTube 用的是 **DASH（Dynamic Adaptive Streaming over HTTP）**：

```
video_360p.mp4   → 只有畫面
video_720p.mp4   → 只有畫面
video_1080p.mp4  → 只有畫面
video_4k.mp4     → 只有畫面

audio_128k.m4a   → 只有聲音
audio_256k.m4a   → 只有聲音
```

為什麼不直接存成一個檔案？

| 原因 | 說明 |
|------|------|
| 節省空間 | 不管看什麼畫質，音訊都一樣，不用重複存 |
| 彈性切換 | 網速變慢時可以降畫質，音訊不用重新載入 |
| 分開處理 | 影片和音訊可以獨立壓縮、編碼 |

但下載回來的時候，我們想要一個「正常的」影片檔案，所以要合併。

---

## ffmpeg 是什麼

ffmpeg 是一個命令列工具，可以處理幾乎所有影音格式：

- 格式轉換（MP4 轉 MKV）
- 編碼轉換（H.264 轉 H.265）
- 合併音視訊
- 裁切、剪輯
- 加字幕、浮水印
- 調整解析度、幀率

**它不是一個程式，而是一個「瑞士刀」**——什麼都能做。

---

## 合併音視訊

```bash
# 把視訊和音訊合併成一個檔案
ffmpeg -i video.mp4 -i audio.m4a -c copy output.mp4
```

| 參數 | 意思 |
|------|------|
| `-i video.mp4` | 輸入檔案 1（視訊） |
| `-i audio.m4a` | 輸入檔案 2（音訊） |
| `-c copy` | 直接複製，不重新編碼 |
| `output.mp4` | 輸出檔案 |

`-c copy` 很重要——它表示「不要重新編碼，直接複製」。

重新編碼很慢（要解碼再編碼），而且可能損失畫質。

如果只是合併，用 `-c copy` 幾秒就完成。

---

## 影音格式基礎知識

### 容器 vs 編碼

很多人搞混「MP4」和「H.264」。

| 概念 | 例子 | 說明 |
|------|------|------|
| **容器（Container）** | MP4, MKV, AVI, WebM | 裝東西的「盒子」 |
| **視訊編碼（Codec）** | H.264, H.265, VP9, AV1 | 壓縮視訊的演算法 |
| **音訊編碼** | AAC, MP3, Opus | 壓縮音訊的演算法 |

MP4 是容器，裡面可以裝 H.264 視訊 + AAC 音訊。

MKV 也是容器，裡面可以裝同樣的內容。

就像：

- 容器 = 便當盒
- 編碼 = 便當的內容（飯、菜）

同樣的飯菜可以裝在不同的便當盒裡。

### 常見的組合

| 容器 | 常見的視訊編碼 | 常見的音訊編碼 |
|------|---------------|---------------|
| MP4 | H.264, H.265 | AAC |
| WebM | VP9, AV1 | Opus |
| MKV | 幾乎都支援 | 幾乎都支援 |

YouTube 主要用 MP4 + H.264/AAC 或 WebM + VP9/Opus。

---

## 常用指令

### 格式轉換

```bash
# MP4 轉 MKV（只換容器，不重新編碼）
ffmpeg -i input.mp4 -c copy output.mkv

# 轉成 H.265（重新編碼，檔案會變小）
ffmpeg -i input.mp4 -c:v libx265 -c:a copy output.mp4
```

### 提取音訊

```bash
# 從影片提取音訊
ffmpeg -i video.mp4 -vn -c:a copy audio.m4a

# 轉成 MP3
ffmpeg -i video.mp4 -vn -c:a libmp3lame -q:a 2 audio.mp3
```

### 調整解析度

```bash
# 縮小到 720p
ffmpeg -i input.mp4 -vf "scale=1280:720" -c:a copy output.mp4

# 等比例縮放（寬度 1280，高度自動）
ffmpeg -i input.mp4 -vf "scale=1280:-1" -c:a copy output.mp4
```

### 裁切影片

```bash
# 從 10 秒開始，擷取 30 秒
ffmpeg -i input.mp4 -ss 00:00:10 -t 00:00:30 -c copy output.mp4

# 從 1:30 到 2:00
ffmpeg -i input.mp4 -ss 00:01:30 -to 00:02:00 -c copy output.mp4
```

### 加字幕

```bash
# 燒錄字幕（字幕變成影片的一部分）
ffmpeg -i input.mp4 -vf "subtitles=sub.srt" output.mp4

# 嵌入字幕（可以開關的）
ffmpeg -i input.mp4 -i sub.srt -c copy -c:s mov_text output.mp4
```

---

## 在 Python 裡呼叫 ffmpeg

```python
import subprocess

def merge_video_audio(video_path, audio_path, output_path):
    """合併視訊和音訊"""
    cmd = [
        'ffmpeg',
        '-i', video_path,
        '-i', audio_path,
        '-c', 'copy',
        '-y',  # 覆蓋已存在的檔案
        output_path
    ]

    process = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )

    if process.returncode != 0:
        raise Exception(f"ffmpeg 錯誤: {process.stderr}")

    return output_path
```

yt-dlp 內建會呼叫 ffmpeg，你通常不用自己處理。

但如果要做進階處理（例如加浮水印、調整畫質），就需要自己寫。

---

## 為什麼 ffmpeg 指令這麼難懂

```bash
ffmpeg -i input.mp4 -c:v libx264 -preset slow -crf 22 -c:a aac -b:a 128k output.mp4
```

這串是什麼鬼？

| 參數 | 意思 |
|------|------|
| `-c:v libx264` | 視訊編碼器用 libx264 |
| `-preset slow` | 編碼速度慢但品質好 |
| `-crf 22` | 品質等級（越低越好，18-28 是常用範圍） |
| `-c:a aac` | 音訊編碼器用 AAC |
| `-b:a 128k` | 音訊位元率 128kbps |

ffmpeg 的設計哲學是「什麼都能做」，所以參數超多。

常用的記起來就好，其他的 Google 再查。

---

## Ytify 怎麼用 ffmpeg

yt-dlp 下載時會自動呼叫 ffmpeg 合併：

```python
opts = {
    'format': 'bestvideo[height<=1080]+bestaudio/best',
    'merge_output_format': 'mp4',  # 合併後的格式
    # yt-dlp 會自動找 ffmpeg
}
```

所以 [Docker 打包](/posts/docker-why-it-works-on-my-machine)時要確保 ffmpeg 有裝：

```dockerfile
RUN apt-get update && apt-get install -y ffmpeg
```

---

## 總結

| ffmpeg 能做的事 | 指令 |
|----------------|------|
| 合併音視訊 | `ffmpeg -i video.mp4 -i audio.m4a -c copy output.mp4` |
| 轉格式 | `ffmpeg -i input.mp4 -c copy output.mkv` |
| 提取音訊 | `ffmpeg -i video.mp4 -vn audio.mp3` |
| 調整解析度 | `ffmpeg -i input.mp4 -vf "scale=1280:720" output.mp4` |
| 裁切影片 | `ffmpeg -i input.mp4 -ss 00:01:00 -t 00:00:30 output.mp4` |

ffmpeg 是影音處理的基礎工具，幾乎所有影音相關的程式背後都在用它。

學會基本指令，你就能處理大部分的影音需求。

```bash
ffmpeg -i input.mp4 -c copy output.mkv
```

一行指令，格式就換了。

這就是 ffmpeg 的威力。
