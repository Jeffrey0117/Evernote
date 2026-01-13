---
layout: ../../layouts/PostLayout.astro
title: 不用 Redux 的 Undo/Redo
date: 2026-01-13T11:35
description: 用 200 行實作編輯器的撤銷重做功能，附帶事件系統和自動存檔
tags:
  - React
  - 架構
---

PasteV 的 AI Gen Mode 需要編輯功能：拖曳元素、修改文字、調整樣式。

有編輯就要有 Undo/Redo，不然使用者改錯了沒辦法回復。

## 先講 Redux 是什麼

[Redux](https://redux.js.org/) 是 React 生態系最知名的狀態管理工具。

React 本身的狀態（`useState`）是綁在單一元件上的。當多個元件需要共用狀態，或是狀態邏輯變複雜，就會很難管理。

Redux 的解法是把所有狀態集中放在一個 **Store**，元件要改狀態就發送 **Action**，由 **Reducer** 統一處理。

```
元件 → dispatch(action) → Reducer → 新狀態 → 元件更新
```

好處是狀態變化可預測、可追蹤，而且 Redux DevTools 可以看到每次變化的歷史，甚至支援「時光旅行」（回到任意時間點的狀態）。

聽起來很美好，但代價是：

- 要寫很多 boilerplate（action types、action creators、reducers）
- 學習曲線陡
- 小專案用起來像殺雞用牛刀

[Zustand](https://github.com/pmndrs/zustand) 是比較輕量的替代方案，API 簡單很多，但還是多了一層抽象。

## 我的需求其實很單純

PasteV 需要的狀態管理：

1. 存一個 `slides` 陣列（編輯器的內容）
2. 修改時記錄歷史，支援 Undo/Redo
3. 元件要能訂閱狀態變化
4. 可以存到 localStorage（自動存檔）

這些東西自己寫 200 行就搞定了。我把它叫做 `EditorState`——一個管理編輯器所有狀態的 class。

## 為什麼用 class 而不是 useState

React 的 `useState` 適合管理單一元件的狀態。但編輯器的狀態會被很多地方用到：

- 畫布元件要讀取 slides 來渲染
- 工具列要知道 canUndo / canRedo 來決定按鈕是否 disabled
- 屬性面板要讀取選中元素的資料
- 自動存檔要監聽所有變化

把這些邏輯都塞進 React 元件會很亂。抽成一個獨立的 class，邏輯集中、好測試、好維護。

## Undo/Redo 的原理

每次修改前，把當前狀態存進歷史陣列。Undo 就是載入上一個，Redo 就是載入下一個。

```
歷史: [狀態0, 狀態1, 狀態2, 狀態3]
                            ↑ 目前 index = 3

按 Undo → index = 2，載入狀態2
按 Redo → index = 3，載入狀態3
```

如果在狀態2的時候做了新的修改，就要把狀態3丟掉：

```
歷史: [狀態0, 狀態1, 狀態2, 新狀態]
                            ↑ 舊的狀態3被截斷了
```

## 實作

```typescript
interface HistoryEntry {
  slides: SlideContent[];
  timestamp: number;
}

class EditorState {
  private _slides: SlideContent[] = [];
  private _history: HistoryEntry[] = [];
  private _historyIndex = -1;
  private _isUndoRedoing = false;
  private maxHistorySize = 50;

  setSlides(slides: SlideContent[], recordHistory = true): void {
    if (recordHistory && !this._isUndoRedoing) {
      this._recordHistory();
    }
    this._slides = slides;
  }

  private _recordHistory(): void {
    // 在歷史中間修改，截斷後面的 redo 歷史
    if (this._historyIndex < this._history.length - 1) {
      this._history = this._history.slice(0, this._historyIndex + 1);
    }

    // 深拷貝當前狀態存進歷史
    this._history.push({
      slides: JSON.parse(JSON.stringify(this._slides)),
      timestamp: Date.now(),
    });

    // 超過上限就丟掉最舊的
    if (this._history.length > this.maxHistorySize) {
      this._history.shift();
    } else {
      this._historyIndex++;
    }
  }

  undo(): void {
    if (this._historyIndex <= 0) return;

    this._isUndoRedoing = true;
    this._historyIndex--;
    this._slides = JSON.parse(JSON.stringify(this._history[this._historyIndex].slides));
    this._isUndoRedoing = false;
  }

  redo(): void {
    if (this._historyIndex >= this._history.length - 1) return;

    this._isUndoRedoing = true;
    this._historyIndex++;
    this._slides = JSON.parse(JSON.stringify(this._history[this._historyIndex].slides));
    this._isUndoRedoing = false;
  }
}
```

## `_isUndoRedoing` 是幹嘛的

Undo 的時候會呼叫 `setSlides` 載入舊狀態，但這時候不應該把「載入舊狀態」這個動作也記進歷史，不然會亂掉。

這個 flag 就是用來區分「使用者主動修改」和「Undo/Redo 載入」。

## 深拷貝是什麼

JavaScript 的物件是**傳參照**的。

```typescript
const a = { name: 'Alice' };
const b = a;  // b 指向同一個物件
b.name = 'Bob';
console.log(a.name);  // 'Bob'，a 也被改了
```

這就是為什麼不能直接把 `this._slides` 存進歷史：

```typescript
// 錯誤做法
this._history.push({ slides: this._slides });
this._slides[0].title = '新標題';
// 歷史裡的資料也變成 '新標題' 了，Undo 沒用
```

**深拷貝**（Deep Copy）是把整個物件複製一份新的，跟原本完全獨立。

```typescript
JSON.parse(JSON.stringify(obj))
```

這招是最簡單的深拷貝——先轉成 JSON 字串，再轉回物件。因為字串沒有參照問題，轉回來的就是全新的物件。

限制是不能處理函式、循環參照、特殊物件（Date、Map 等）。但對純資料來說夠用了。

## 事件系統：讓元件知道狀態變了

React 元件怎麼知道 EditorState 裡的資料變了？

最簡單的方式是自己寫一個發布/訂閱模式：

```typescript
class SimpleEvent<T> {
  private listeners: Array<(data: T) => void> = [];

  subscribe(listener: (data: T) => void): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  emit(data: T): void {
    this.listeners.forEach(listener => listener(data));
  }
}
```

EditorState 在狀態變化時 emit 事件：

```typescript
class EditorState {
  readonly onSlidesChanged = new SimpleEvent<SlideContent[]>();

  setSlides(slides: SlideContent[]): void {
    // ... 原本的邏輯
    this.onSlidesChanged.emit(slides);
  }
}
```

React 元件用 `useEffect` 訂閱：

```typescript
useEffect(() => {
  const unsubscribe = editorState.onSlidesChanged.subscribe(setSlides);
  return unsubscribe; // cleanup
}, []);
```

這就是 Redux 的 `subscribe` 在做的事，只是我們自己寫了一個極簡版。

## 序列化：讓狀態可以存檔

**序列化**（Serialization）是把記憶體中的物件轉成字串（通常是 JSON），這樣就可以：

- 存進 localStorage / IndexedDB
- 傳到後端儲存
- 匯出成檔案

加上 `toJSON` 和 `fromJSON`：

```typescript
class EditorState {
  toJSON(): string {
    return JSON.stringify({
      version: 1,
      slides: this._slides,
      timestamp: Date.now(),
    });
  }

  static fromJSON(json: string): SlideContent[] | null {
    try {
      const data = JSON.parse(json);
      return data.slides;
    } catch {
      return null;
    }
  }
}
```

有了這個，自動存檔就是一行：

```typescript
useEffect(() => {
  const unsub = editorState.onSlidesChanged.subscribe(() => {
    localStorage.setItem('editor-draft', editorState.toJSON());
  });
  return unsub;
}, []);
```

使用者編輯到一半關掉瀏覽器，下次打開資料還在。這對編輯器類的工具來說是基本功能。

## 為什麼不直接用 Redux

| 需求 | Redux 做法 | 自己寫 |
|------|-----------|--------|
| 狀態集中管理 | Store | 一個 class |
| 狀態變化通知 | connect / useSelector | SimpleEvent |
| Undo/Redo | redux-undo middleware | 50 行歷史陣列 |
| 序列化 | 要自己處理 | toJSON / fromJSON |

Redux 的優勢在複雜應用：多人協作、大型狀態樹、需要嚴格的狀態追蹤。

但對 PasteV 這種「一個編輯器、一份資料、單人使用」的場景，自己寫更直接。

---

## 學會這個能幹嘛

這篇講的四個概念，組合起來可以做很多事：

**Undo/Redo（歷史陣列 + 索引）**
- 任何編輯器：文字編輯器、繪圖工具、表單設計器
- 遊戲存檔：回到上一個檢查點
- 表單多步驟：上一步 / 下一步

**事件系統（發布/訂閱）**
- 跨元件通訊：不用 props drilling 一層一層傳
- 解耦模組：A 模組不用知道 B 模組存在，只要發事件
- 插件系統：外部程式碼可以訂閱內部事件

**深拷貝（JSON 序列化）**
- 狀態快照：記錄某個時間點的完整狀態
- 比較差異：拷貝一份，改完再跟原本比對
- 隔離測試：測試時複製一份資料，不影響原本的

**序列化（toJSON / fromJSON）**
- 自動存檔：localStorage、IndexedDB
- 雲端同步：送到後端儲存
- 匯出匯入：讓使用者下載 / 上傳設定檔

這些都是通用的程式設計模式，不只適用於 React，任何語言都能用。

理解原理之後，你會發現 Redux、MobX、Zustand 這些工具都在做類似的事，只是包裝不同。看到新工具不會怕，因為你知道底層是什麼。
