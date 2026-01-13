---
layout: ../../layouts/PostLayout.astro
title: 我只是想錄個音，瀏覽器就是要搞事
date: 2026-01-13T17:50
description: ScriptProcessor 都 deprecated 十年了還沒被移除，AudioWorklet 說是替代方案但設定複雜到爆
tags:
  - Electron
  - Web Audio API
  - JavaScript
---

做語音辨識桌面應用，需要「即時拿到麥克風的音頻數據」。

不是錄完一段再處理，而是**邊錄邊拿**，每幾百毫秒就要送一批數據去辨識。

聽起來很基本對吧？結果我在這上面卡了超久。

## 原本想得很美好

Web Audio API 有個東西叫 `ScriptProcessor`，用法超直覺：

```javascript
const audioContext = new AudioContext({ sampleRate: 16000 });
const source = audioContext.createMediaStreamSource(stream);
const processor = audioContext.createScriptProcessor(4096, 1, 1);

processor.onaudioprocess = (e) => {
    const inputData = e.inputBuffer.getChannelData(0);
    // inputData 就是原始音頻數據
};

source.connect(processor);
processor.connect(audioContext.destination);
```

幾行就搞定。我照著寫，跑起來，完美。

**然後 VS Code 就跳出一條灰色的刪除線。**

`createScriptProcessor` 被劃掉了。Deprecated。

## 2014 年就說要移除了

查了一下，Chrome 從 **2014 年**就標記 `ScriptProcessor` 為 deprecated。

2014 年。

那時候我還在用 iPhone 5s。十年前的事。

但到現在 2026 年，**它還是能用**。

這就是 Web 標準的魔幻之處。說要移除，但怕破壞太多網站，所以一直拖著。

## 為什麼要 deprecated 它

`ScriptProcessor` 的 callback 跑在**主線程**。

當 `onaudioprocess` 被觸發時，如果主線程正在忙（渲染 UI、跑其他 JavaScript），音頻處理就會延遲。

結果就是**音頻斷斷續續**。

在簡單應用裡感覺不出來，但在複雜應用裡會炸。

所以官方說：你們不要用這個了，改用 `AudioWorklet`。

## AudioWorklet 號稱是解法

`AudioWorklet` 跑在**獨立的音頻線程**，不會被主線程拖慢。

聽起來很棒。

然後我看了一下怎麼用。

### 多一個檔案

```javascript
// audio-processor.js（獨立檔案）
class AudioProcessor extends AudioWorkletProcessor {
    process(inputs, outputs, parameters) {
        const input = inputs[0];
        if (input && input[0]) {
            this.port.postMessage(input[0]);
        }
        return true;
    }
}

registerProcessor('audio-processor', AudioProcessor);
```

### 主程式也要改

```javascript
const audioContext = new AudioContext({ sampleRate: 16000 });

// 非同步載入 worklet 模組
await audioContext.audioWorklet.addModule('audio-processor.js');

// 建立 worklet 節點
const workletNode = new AudioWorkletNode(audioContext, 'audio-processor');

// 接收資料要用 message
workletNode.port.onmessage = (e) => {
    const audioData = e.data;
};

source.connect(workletNode);
```

好，程式碼多了一倍，還要管理一個獨立檔案。

但這不是重點。

### 重點是 Electron 裡會炸

`addModule()` 載入本地檔案，在 Electron 裡會被安全限制擋掉。

要嘛設定 `webSecurity: false`（不推薦），要嘛把 worklet 檔案 inline 成 Blob URL，要嘛搞一堆 CSP header。

**我只是想錄個音。**

### 還有資料傳輸的問題

`AudioWorklet` 跑在獨立線程，要把資料傳回主線程得用 `postMessage`。

每次 `postMessage` 都會**複製資料**。

音頻是高頻率、大量資料的場景，這個複製開銷不小。

想避免？用 `SharedArrayBuffer`。但那個設定又是另一個坑，要 COOP/COEP headers...

算了。

## 我的結論

**繼續用 ScriptProcessor。**

理由：

1. **它還能用** — 雖然 deprecated 十年了，但沒被移除
2. **我的應用很簡單** — 主線程不忙，不會斷
3. **Electron 環境可控** — 我知道跑的是什麼版本的 Chromium

「能用就不要亂改」。

什麼時候會換？等 Chrome 真的把它移除那天吧。到時候再來痛苦遷移。

## 其他小坑

### 緩衝區大小要 2 的冪次

`createScriptProcessor(bufferSize, inputChannels, outputChannels)`

`bufferSize` 只能是：256, 512, 1024, 2048, 4096, 8192, 16384。

| 大小 | 延遲 | 穩定性 |
|------|------|--------|
| 256 | 最低 | 容易斷 |
| 4096 | 中等 | 穩定 |
| 16384 | 最高 | 最穩定 |

我用 4096，平衡延遲和穩定性。

### 採樣率轉換

麥克風通常是 44100Hz 或 48000Hz，語音辨識模型要 16000Hz。

```javascript
const audioContext = new AudioContext({ sampleRate: 16000 });
```

瀏覽器會自動重採樣。品質不一定好，但堪用。

### 沒聲音也會一直觸發

`ScriptProcessor` 會一直觸發 callback，即使是靜音。

要自己做檢測，不然會送一堆空資料出去：

```javascript
processor.onaudioprocess = (e) => {
    const inputData = e.inputBuffer.getChannelData(0);
    const rms = Math.sqrt(inputData.reduce((sum, x) => sum + x * x, 0) / inputData.length);

    if (rms > 0.01) {
        // 有聲音
    }
};
```

---

Web Audio API 這東西，設計得很強大，用起來很痛苦。

一個 deprecated 十年還沒移除的 API，跟一個複雜到讓人放棄的替代方案。

這就是 Web 標準的日常。

相關文章：

- [串流語音辨識的參數調教之路](/Evernote/posts/streaming-speech-recognition-optimization)
- [所有你應該知道的語音辨識，都在這](/Evernote/posts/speech-recognition-series-index)
