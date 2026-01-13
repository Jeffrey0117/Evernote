---
layout: ../../layouts/PostLayout.astro
title: 文章題材待挖掘清單
date: 2026-01-13T15:30
description: 從 commit 歷史挖出來的潛在文章題材
tags:
  - 備忘
draft: true
---

這是從 ququ 專案的 commit 歷史挖出來的潛在文章題材，之後慢慢寫。

---

## 🎤 音頻處理

### ✅ Web Audio API 的坑（ScriptProcessor → AudioWorklet）

**已完成** → [web-audio-api-pitfalls.md](/Evernote/posts/web-audio-api-pitfalls)

---

### 音頻預處理：正規化與降噪

**來源 commit**：`Add audio preprocessing: volume normalization and noise reduction`

**可寫內容**：
- 為什麼需要音量正規化（太小辨識不清、太大削波）
- -3dB (0.7 peak) 這個數字怎麼來的
- 簡易降噪 vs 專業降噪
- numpy 實作

---

### 錄音格式：WebM vs PCM

**來源 commit**：`Rewrite normal mode recording to use direct PCM capture`、`Fix audio decode error`

**可寫內容**：
- 一開始用 MediaRecorder 錄 WebM 遇到的問題
- 為什麼改成直接擷取 PCM
- 不同瀏覽器的音頻格式支援差異

---

## 🖥️ Electron 開發

### electronmon：開發體驗優化

**來源 commit**：`dx: add electronmon for auto-restart on main process changes`

**可寫內容**：
- Electron 開發的痛點（改 main process 要手動重啟）
- electronmon 怎麼解決
- 其他 Electron DX 工具

---

### ✅ 視窗控制：置頂與縮小到托盤

**已完成** → [electron-window-controls.md](/Evernote/posts/electron-window-controls)

---

## 🎨 UI/UX 設計

### ✅ 中文桌面應用的字體選擇

**已完成** → [chinese-font-selection.md](/Evernote/posts/chinese-font-selection)

---

### 串流模式的視覺反饋

**來源 commit**：`ui: streaming mode indicators`、`feat: add visual distinction for streaming mode`

**可寫內容**：
- 使用者怎麼知道「正在辨識」
- 即時文字 vs 最終文字的視覺區分
- 載入狀態的設計

---

### 有趣的統計 banner

**來源 commit**：`Add fun statistics banner to history page`、`Improve stats banner with friendlier copy and humor`

**可寫內容**：
- 用幽默文案提升使用者體驗
- 「你已經講了 X 小時」的心理效果
- 數據視覺化的小巧思

---

## ⚙️ 功能實作

### ✅ 字典替換：自動校正專有名詞

**已完成** → [dictionary-replacement.md](/Evernote/posts/dictionary-replacement)

---

### OpenCC 簡繁轉換的坑

**來源 commit**：`fix opencc s2twp to s2t`

**可寫內容**：
- s2t vs s2tw vs s2twp 的差異
- 為什麼語音辨識場景不該用 s2twp
- 用詞轉換的副作用

---

### 完全信任模式：自動貼上與送出

**來源 commit**：`feat: 新增完全信任模式 - 自動貼上與自動送出設定`

**可寫內容**：
- 使用者體驗的極致優化
- 「信任」的設計哲學
- 自動送出的風險與取捨

---

## 🐛 踩坑記錄

### 重複標點的除錯過程

**來源 commit**：`fix: prevent duplicate punctuation`、`fix: resolve duplicate punctuation`

**可寫內容**：
- 串流模式的狀態管理
- 端點觸發時加標點 vs 結束時加標點
- 除錯過程與解法

---

### 串流模式文字不出現的問題

**來源 commit**：`fix: streaming mode text display`、`fix: rollback aggressive optimizations and fix empty text issue`

**可寫內容**：
- 過度優化導致的 bug
- 為什麼按三次才有文字
- 回滾與分析的過程

---

## 📝 待確認的想法

- Silero VAD vs WebRTC VAD 比較
- Electron 打包大小優化
- Python subprocess 與 Electron 的通訊方式
- 語音辨識的 A/B 測試怎麼做

---

## 優先順序建議

~~1. **Web Audio API 的坑** - ✅ 已完成~~
~~2. **字體選擇** - ✅ 已完成~~
~~3. **字典替換** - ✅ 已完成~~
~~4. **視窗控制** - ✅ 已完成~~

**下一輪**：
1. **音頻預處理** - 技術含量高
2. **OpenCC 的坑** - 簡單但實用
3. **串流視覺反饋** - UI/UX 系列
4. **electronmon** - Electron 系列

---

<small>最後更新：2026-01-13</small>
