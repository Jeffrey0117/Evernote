---
layout: ../../layouts/PostLayout.astro
title: 不小心把 API Key 推到 GitHub 怎麼辦
date: 2026-01-12T23:38
description: 從一次差點洩露 API Key 的經驗，聊聊 Git 的安全機制和補救方法
tags:
  - Git
  - 安全
---

我最近在用 Claude Code 幫我 review 一個專案。

它掃了一輪之後，跟我說：「你的 DeepSeek API Key 洩露了。」

我心想，不會吧，我 `.gitignore` 有設定啊。

結果它貼給我看：

```
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
```

幹，真的是我的 key。

## 還好是虛驚一場

查了一下，`.env` 從來沒被 commit 過，只是我**本地檔案裡有真實的 key**。Claude Code 讀到本地檔案，好心提醒我。

但這讓我想到一個問題：如果真的不小心推上去了，怎麼辦？

這種事情其實很常見。尤其是 Vibe Coding 的時候——就是那種「感覺對了就好」的寫 code 方式。不看文件、不寫測試、`git add .` 然後 `git push` 收工。

GitHub 上一堆 public repo 裡面躺著真實的 API key，有些人到現在都還不知道。

## 第一步永遠是撤銷金鑰

不管你接下來要怎麼清 Git 歷史，**先去把 key 撤銷掉**。

這是最重要的一步。因為：

1. 駭客可能已經拿到了
2. 清 Git 歷史需要時間
3. 就算清了，別人可能已經 fork 或 clone 了

去服務商後台重新生成一組新的 key，舊的作廢。

常見的服務商後台：
- [OpenAI](https://platform.openai.com/api-keys)
- [AWS](https://console.aws.amazon.com/iam/home#/security_credentials)
- [DeepSeek](https://platform.deepseek.com)

## 然後才是清 Git 歷史

Git 的特性是**所有 commit 都會保留**。就算你之後把 `.env` 刪掉再 commit，舊的 commit 裡面還是有那個檔案。

所以要用特殊工具把歷史裡的敏感檔案徹底移除。

### 用 BFG 最簡單

[BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) 是專門做這件事的工具，比 Git 內建的 `filter-branch` 快很多。

```bash
# 移除某個檔案的所有歷史
bfg --delete-files .env

# 或者移除特定字串（比如 API Key）
echo "你的 API Key" > passwords.txt
bfg --replace-text passwords.txt

# 清理垃圾
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 強制推送
git push --force
```

### 用 filter-branch 也行

Git 內建的方法，不用裝額外工具，但比較慢：

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

git push origin --force --all
```

兩個方法都會**改寫 Git 歷史**，所以其他協作者要重新 clone 或 `git reset --hard origin/main`。

## 但預防比補救重要

與其事後補救，不如一開始就設定好。

### .gitignore 要設定

專案一開始就建立 `.gitignore`，把 `.env` 加進去：

```gitignore
# .gitignore
.env
.env.local
.env.production
```

然後建立一個 `.env.example` 當模板，這個可以 commit：

```env
# .env.example
PORT=3001
API_KEY=your_api_key_here
```

### 不要無腦 git add .

這是最常見的洩露原因。

`git add .` 會把所有檔案都加進去，包括你不想 commit 的東西。

養成習慣：

```bash
# 先看有什麼會被加進去
git status

# 確認沒問題再 add
git add .
```

或者用 `git add -p` 互動式選擇要加哪些。

### 裝 git-secrets 自動檢查

[git-secrets](https://github.com/awslabs/git-secrets) 是 AWS 出的工具，會在 commit 前自動掃描有沒有敏感資訊：

```bash
# 安裝
brew install git-secrets

# 在專案裡啟用
git secrets --install
git secrets --register-aws

# 之後 commit 時會自動檢查
```

如果偵測到 AWS key 的格式，會擋住不讓你 commit。

---

反正就是：**專案開始的前 5 分鐘，把 `.gitignore` 設定好。**

不然哪天 key 被掃走拿去亂用，那才真的很煩。
