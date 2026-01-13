---
layout: ../../layouts/PostLayout.astro
title: LLM API 批量請求的正確姿勢
date: 2026-01-13T11:15
description: 500 次 API 請求變 10 次，速度快 50 倍，費用省 90%
tags:
  - LLM
  - API
---

我在做 PasteV 的時候需要批量翻譯。

100 張圖片，每張 OCR 出 5 個文字欄位，總共 500 段文字要翻譯成中文。

第一版的寫法很直覺：

```typescript
for (const image of images) {
  for (const field of image.fields) {
    const translated = await translateAPI(field.text);
    field.translatedText = translated;
  }
}
```

結果跑了 4 分多鐘，而且 API 費用噴了一波。

## 問題在哪

LLM API（像 OpenAI、DeepSeek、Claude）有三個特性：

| 特性 | 影響 |
|------|------|
| 每次請求有延遲 | 500 次 × 500ms = 250 秒 |
| 按 token 計費 | 每次請求都有固定 overhead |
| 有 rate limit | 每分鐘 60 次，超過就被擋 |

逐筆請求在資料少的時候沒感覺，資料一多就三個問題同時爆發。

## 解法：批次處理

把多段文字合成一個請求，請 LLM 一次翻譯完。

```typescript
const prompt = `請翻譯以下文字，每行一個結果：
1. Hello world
2. Good morning
3. Thank you`;

// 一次請求，三個結果
const response = await llmAPI(prompt);
```

500 段文字分成 10 批，每批 50 段，只要 10 次 API 請求。

速度從 4 分鐘變成 5 秒，費用也省了一大截。

## 實作細節

批次處理聽起來簡單，但有幾個眉角。

## 怎麼組 Prompt

要讓 LLM 知道輸入有多段，而且輸出要能對應回去。

我用編號 + 分隔符號：

```typescript
function buildBatchPrompt(texts: string[]): string {
  const lines = texts.map((t, i) => `${i + 1}. ${t}`).join('\n');

  return `請將以下文字翻譯成繁體中文：

${lines}

輸出格式：每行 "序號||| 翻譯結果"
例如：
1||| 你好世界
2||| 早安`;
}
```

用 `|||` 當分隔符號是因為它不太會出現在正常文字裡，比較好 parse。

## 怎麼 Parse 回應

LLM 的輸出不一定 100% 照格式，要有 fallback：

```typescript
function parseTranslations(content: string, originalTexts: string[]): string[] {
  const results: string[] = [];
  const lines = content.trim().split('\n');

  // 嘗試解析 "序號||| 翻譯" 格式
  for (const line of lines) {
    const match = line.match(/^(\d+)\|\|\|\s*(.+)$/);
    if (match) {
      const index = parseInt(match[1]) - 1;
      results[index] = match[2].trim();
    }
  }

  // Fallback：如果格式不對，就按行對應
  if (results.filter(Boolean).length === 0) {
    return lines.map(l => l.trim());
  }

  // 沒翻譯到的用原文
  return originalTexts.map((orig, i) => results[i] || orig);
}
```

重點是**不要讓解析失敗導致整批資料丟掉**。最差情況就是回傳原文。

## 加上快取

同樣的文字不用重複翻譯。

```typescript
class TranslationCache {
  private cache = new Map<string, { value: string; timestamp: number }>();
  private maxSize = 1000;
  private maxAge = 24 * 60 * 60 * 1000; // 24 小時

  get(text: string): string | null {
    const entry = this.cache.get(text.toLowerCase().trim());
    if (!entry) return null;
    if (Date.now() - entry.timestamp > this.maxAge) {
      this.cache.delete(text);
      return null;
    }
    return entry.value;
  }

  set(text: string, translation: string): void {
    if (this.cache.size >= this.maxSize) {
      // 刪掉最舊的
      const oldest = this.cache.keys().next().value;
      this.cache.delete(oldest);
    }
    this.cache.set(text.toLowerCase().trim(), {
      value: translation,
      timestamp: Date.now()
    });
  }
}
```

請求前先查快取，只翻譯沒翻過的：

```typescript
const cached: Record<string, string> = {};
const toTranslate: string[] = [];

for (const text of texts) {
  const hit = cache.get(text);
  if (hit) {
    cached[text] = hit;
  } else {
    toTranslate.push(text);
  }
}

// 只翻譯沒快取的
if (toTranslate.length > 0) {
  const translations = await batchTranslate(toTranslate);
  // 存進快取...
}
```

實測下來，快取命中率大概 30-50%，又省了一半的 API 請求。

## 錯誤處理

批次請求失敗的話，不要整批重試，要能降級：

```typescript
try {
  return await batchTranslate(texts);
} catch (error) {
  console.error('Batch failed, falling back to individual requests');

  // 降級成逐筆請求（慢但穩）
  const results: string[] = [];
  for (const text of texts) {
    try {
      results.push(await translateSingle(text));
    } catch {
      results.push(text); // 最差情況：回傳原文
    }
  }
  return results;
}
```

## 成效

| 指標 | 逐筆請求 | 批次處理 |
|------|----------|----------|
| 500 段文字耗時 | ~250 秒 | ~5 秒 |
| API 請求次數 | 500 次 | 10 次 |
| 費用 | $$ | $ |
| 會撞 rate limit | 會 | 不會 |

批次處理的代價是程式碼變複雜——要處理 prompt 組裝、回應解析、快取、fallback。

但資料量一大，這些複雜度就是必要的。

---

這個模式不只適用於翻譯。任何「大量資料 × 外部 API」的場景都適用：

- 批量生成文案
- 批量分類內容
- 批量提取資訊

核心概念就是：**把 N 次請求變成 N/M 次，用 prompt 設計換取效能**。
