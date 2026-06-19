# Selection Engine

阶段 2 选区与布局引擎的架构说明：跨块拖拽、选词/选段、自动滚动、只读选择。

## 总览

阶段 0 的选区是**单块手势**——每个 `_TextSelectionSurface` 独占 `GestureDetector`，拖拽无法跨块。阶段 2 把手势上移到**文档级 overlay**，通过 `BlockGeometryRegistry` 把全局坐标解析为 `DocumentPosition`，从而支持跨块。

关键事实：**选区模型、命令层、跨块高亮绘制在阶段 0/1 已支持跨块**（`DocumentSelection` 无单块约束、`_selectionRangeForPath` 按 blockIndex 区间全块高亮）。阶段 2 补的只是手势生产。

## 架构

```
SelectionGestureOverlay（文档级 Listener + 手势判定）
        │
        │  全局坐标 → DocumentPosition
        ▼
BlockGeometryRegistry（注册表：blockId → GlobalKey + layoutResolver）
        │
        │  遍历已注册 surface，RenderBox.globalToLocal + TextLayoutService.offsetAt
        ▼
controller.setSelection(DocumentSelection)  ──▶ 各 _TextSelectionSurface 按区间重绘高亮
```

## BlockGeometryRegistry

`lib/src/widgets/block_geometry_registry.dart`。文档级单例（`_WenzRichTextEditorState` 持有，注入每个 surface）。

- 每个 `_TextSelectionSurface` 在 `initState` 用 `register(BlockEntry)` 注册：`blockId`、`blockIndex`、`path`、`textLength`、`GlobalKey`、`positionFromLocal` 回调、`wordRangeAt` 回调。`dispose` 时 `unregister`。
- `positionFromGlobalOffset(Offset global)`：遍历 entries，用 `RenderBox.globalToLocal` + `contains` 找命中块；命中则用该块 `TextLayoutService.offsetAt` 得 offset 构造 `DocumentPosition`。未命中（块间空隙/视口外）则 `_clampToNearest`——按垂直邻近选最近块的首/尾，保证拖拽到块间隙也能预测地扩展选区。
- `wordRangeAt(blockId, offset)` / `paragraphRange(blockId)`：委托给命中块的 `TextLayoutService`，供双击/三击。

## SelectionGestureOverlay

`lib/src/widgets/selection_gesture_overlay.dart`。包裹 `SingleChildScrollView`，用 `Listener`（`PointerDown/Move/Up/Cancel`）统一接管指针事件。

### 手势类型

| 输入 | 行为 |
| --- | --- |
| 单击 | `_tapAnchor` → collapsed caret |
| 拖拽（位移 > slop 阈值） | base 固定，extent 跟随全局坐标（**可跨块**），up 时定稿 |
| 双击 | `wordRangeAt` → 选词 |
| 三击 | `paragraphRange` → 选整块 |

- **多击计数**：`_lastTapTime` + `_lastTapPosition`，300ms 时间窗 + slop 位移内算连续。`_tapCount` 累加；双击/三击抑制 drag 启动（`_dragOrigin = null`），但 `_tapAnchor` 始终记录。
- **拖拽跨块**：`_extendSelection` 每帧用 registry 解析 extent，可落在任意已注册块。绘制层（`_selectionRangeForPath`）自动处理跨块高亮：中间块全块高亮，首尾块按 offset 截断。

### 自动滚动

`_maybeAutoScroll`：拖拽 move 时，若全局坐标距视口边缘 < 48px，按差值（上限 24px/帧）`scrollable.position.jumpTo`。视口边界用 overlay 自身 RenderBox 近似。

## TextLayoutService 增强

`lib/src/rendering/text_layout_service.dart`（阶段 0 抽出，阶段 2 增强）：
- `wordRangeAt(painter, offset)`：`TextPainter.getWordBoundary`（platform 文本分段，支持中文）。
- `paragraphRange(painter)`：`TextRange(0, textLength)`——阶段 2 "段" = 单块。

## 只读模式

overlay 在只读下仍接管所有手势产生 selection（阶段 0 已让只读可选；阶段 2 overlay 统一后保持）。编辑类命令仍由 `_handleKeyEvent` 的 `readOnly` 守卫。只读下不显示 caret，只显示 selection 高亮。

## IME 同步

overlay 产生 selection 后，`_handleSelectionChanged` 调 `EditorTextInputClient.syncBuffer()` 刷新 IME 缓冲，让平台输入跟随新光标位置。

## 阶段边界（留到后续）

- **selection overlay handles**（移动端拖拽手柄）→ 阶段 8。
- 行级 layout（Home/End 移到真实行首而非块首）→ 阶段 5（依赖虚拟化后的行布局缓存）。
- 富文本跨块复制粘贴 → 随跨块选区已在，剪贴板层补齐（阶段 1 已预留）。
