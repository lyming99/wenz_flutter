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

### Block 拖拽把手排除边界

Block 左侧把手属于**顶层 block 行 chrome**，不属于 `_TextSelectionSurface`、`BlockRendererBuilder` 或对象块内部控件。后续渲染/拖拽实现必须复用 `BlockDragHandleSpec` 中的尺寸与阈值，并在命中把手时先消费指针事件，避免事件继续进入 `SelectionGestureOverlay` 生成文本选区。

| 项 | 交互约定 |
| --- | --- |
| 归属 | 只挂在 `_MeasuredVirtualBlockList` 产生的 `controller.document.blocks` 顶层行外壳；表格单元格文本、行内 embed、对象块内部按钮/resize 控件都不是可排序行。 |
| 位置 | 使用 leading 方向的行外 gutter，遵循 `Directionality`；把手在内容框外侧，不改变 renderer 内容宽度、缩进或表格列宽。 |
| 尺寸 | gutter 宽 `32px`，命中/焦点区域 `28×28px`，图标 `18×18px`，与内容边缘间距 `4px`，距 block 顶部 `2px`，视觉上锚定首行或对象块顶部控制行。 |
| 状态 | 默认透明但保留稳定命中区域；行/rail hover 时显示 `0.72` opacity；键盘 focus、菜单打开或拖拽中为 `1.0`；只读或无编辑权限时不显示、不可聚焦。 |
| 菜单 vs 拖拽 | pointer down 在命中区后进入 pending：释放前移动距离 `< 6px` 视为点击/轻触并打开 block 菜单；移动距离 `>= 6px` 进入排序拖拽，抑制菜单、文本选区和 IME caret 变更。 |
| 合法落点 | 仅允许落到顶层 block 之间或首尾边界，不允许落入表格单元格、行内 embed 或对象块内部控件；同位置/无合法目标为 no-op 且不记历史。 |
| 禁用/no-op | 空文档无把手；只读或 `canEdit=false` 无菜单和拖拽；单 block 文档可打开菜单但排序拖拽、上移/下移为 no-op；首行禁用上移，末行禁用下移。 |

### Block 拖拽把手回归矩阵

- **菜单入口**：点击/轻触或键盘 Enter/Space 打开统一 block 菜单；菜单动作复用 `ObjectBlockAction`，普通文本块和对象块都走同一分发链路。
- **拖拽排序**：超过 `BlockDragHandleSpec.dragStartSlop` 后进入排序态，显示 `wenz-richtext-block-reorder-drop-indicator`，释放后调用 `MoveBlockCommand` 写入历史；拖到原位置不记 history。
- **边界与取消**：首行禁用上移、末行禁用下移；pointer cancel 会移除落点指示、恢复把手透明度，并允许下一次点击重新打开菜单。
- **只读与选区**：只读模式仍允许文本选区和复制，但不渲染 block 把手；把手命中区注册为 selection exclusion，避免拖拽排序误触发跨 block 文本选区。
- **长文档与虚拟化**：排序落点只基于已注册顶层 block 行，首尾/视口边缘通过 `BlockGeometryRegistry.blockReorderDropTargetFromGlobalOffset` 夹取到合法位置；命中把手时不会启动 `SelectionGestureOverlay` 的文本选区自动滚动，普通文本长拖拽的自动滚动仍由 overlay 覆盖。
- **视觉基线**：`editor_golden_test.dart` 覆盖左侧 gutter/把手 chrome 对常见 block 组合的布局影响，并用交互 golden 固定菜单打开态与 `wenz-richtext-block-reorder-drop-indicator` 落点线。

### Block 拖拽把手定向验证

- 命令层：`flutter test test/core/block_structure_commands_test.dart --name MoveBlockCommand`，覆盖异构顶层 block、对象元数据、评论/修订 retarget、撤销/重做和 no-op 边界。
- Widget 层：`flutter test test/widgets/wenz_rich_text_editor_test.dart --name "block drag handles"`，覆盖点击菜单、键盘菜单、拖拽排序、取消、只读隐藏、长文档隔离和历史回放。
- Golden 层：`flutter test test/widgets/editor_golden_test.dart --name "golden: block"`，覆盖常见 block gutter、菜单入口视觉态和拖拽落点线。

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
