# Selection & Position Model

本文档定义 `wenz_richtext` 的选区与位置模型，供后续阶段（输入、跨块选区、表格编辑、渲染）作为契约参考。

## 1. 核心类型

位置与选区的定义集中在 `lib/src/core/position/document_position.dart`：

- `DocumentPosition` — 指向文档中一个可编辑坐标点。
- `DocumentSelection` — 由 `base` 和 `extent` 两个 `DocumentPosition` 构成的选区；`isCollapsed` 表示 collapsed caret。
- `PositionPath` — 描述"位置指向 block 内部的什么东西"，是位置语义的核心。

`DocumentPosition` 的字段：

| 字段 | 含义 |
| --- | --- |
| `blockId` | 所属 block 的 id。对表格 cell 位置，是**表格 block** 的 id，不是 cell id。 |
| `blockIndex` | block 在 `document.blocks` 中的顶层索引。 |
| `path` | 见下节。 |
| `offset` | 在 `path` 所指向内容中的字符偏移。 |

## 2. PositionPath 的三种形态

`PositionPath` 只通过命名工厂构造，segments 是内部存储，外部应使用类型化访问器。

| 工厂 | 指向 | 便捷构造 |
| --- | --- | --- |
| `PositionPath.blockText(blockId)` | `TextBlockNode`（paragraph/heading/quote/listItem）的 inline 文本 | `DocumentPosition.text(...)` |
| `PositionPath.blockCode(blockId)` | `CodeBlockNode` 的 code 字符串 | `DocumentPosition.code(...)` |
| `PositionPath.tableCellText(tableId, row, col)` | 表格某 cell 的**第一个** `TextBlockNode` 的 inline 文本 | `DocumentPosition.tableCell(...)` |

类型化访问器：`isBlockText` / `isBlockCode` / `isTableCellText` / `blockId` / `tableRowIndex` / `tableColumnIndex`。

## 3. 排序语义（`compareTo`）

`DocumentPosition.compareTo` 的顺序：

1. `blockIndex`（数值）
2. `path.compare(other.path)`（**结构化**比较，非字典序）
3. `offset`（数值）

`PositionPath.compare` 先按 path 类型秩（blockText < blockCode < tableCellText）比较，再逐段比较 segments：两段都是 int/num 时按数值，否则按字符串。**关键**：这意味着 `row/10` 排在 `row/2` 之后（数值序），而不是之前（字典序）。历史上用 `path.toString()` 字典序比较会得到错误的表格 cell 排序，已在阶段 0 修复。

## 4. 当前编辑路由方式（重要现状）

截至阶段 0，`path` 是**结构性元数据**，命令的编辑路由仍主要依赖 `blockIndex` + block 运行时类型判断（`is TextBlockNode` / `is CodeBlockNode` / `is TableBlockNode`）：

- 普通文本/代码块的增删改（`InsertTextCommand`、`DeleteBackwardCommand`、`FormatTextCommand`、`EnterCommand` 等）通过 `blockIndex` 定位顶层 block 后按类型分发。
- 表格 cell 的文本编辑**不**走主命令链，而是通过专用命令族（`InsertTableCellTextCommand` / `DeleteTableCellTextCommand` / `FormatTableCellTextCommand`），它们从构造参数（`blockIndex`/`rowIndex`/`columnIndex`/`offset`）自行定位，忽略入参 selection 的 path。
- `MoveCaretCommand`（方向键）目前只能产生 `blockText` / `blockCode` 路径，**不能**把光标移入表格 cell。

这是阶段 0 刻意收敛的范围：统一了 path 形状与排序，但**没有**把表格 cell 接入主命令链。

## 5. 阶段边界声明

| 能力 | 状态 |
| --- | --- |
| 文本块 / 代码块内编辑、选区、caret | ✅ 已支持 |
| 跨文本块拖拽选区（`DeleteSelectionCommand` 跨块合并） | ✅ 已支持 |
| 拖拽自动滚动（指针到视口边缘 → 列表跟随滚动） | ✅ 已支持（B2：同步边缘滚动全设备 + 鼠标/触控笔 Ticker 持续滚动） |
| 表格 cell 内文本编辑（专用命令族） | ✅ 已支持 |
| 表格 cell 范围选区（cell 内多字符高亮选区） | ✅ 已支持（阶段 4） |
| 方向键 / Tab 在 cell 间导航 | ✅ 已支持（阶段 4） |
| Enter / Format / Delete 主命令链直接作用于 cell | ✅ 已支持（阶段 4） |
| 多 block cell 的非首 block 寻址 | ❌ path 暂无 sub-block 段，留到后续阶段 |

**阶段 4 已落地**：主命令链已改为 path-aware 分发（`path.isTableCellText` 判定后下沉到 cell 的首个 text block），`MoveCaretCommand` 与新增的 `MoveTableCellVerticalCommand` 可产生 `tableCellText` 路径。表格键盘导航覆盖 Tab/Shift+Tab（末尾 cell Tab 新增行）、Enter（cell 内换行）、Left/Right（cell 内字符 + 跨 cell）、Up/Down（同列跨行，跳过 merged `covered` cell）。业务方仍可使用 `*TableCellTextCommand` 族直接编辑表格。

## 6. 不变量与测试

- 所有 `PositionPath` 必须经命名工厂构造，禁止外部直接拼 segments。
- `compareTo` 与 `==` 必须一致：`a.compare(b) == 0` ⟺ `a == b`。
- 表格行/列对齐在增删列后必须重建（`InsertTableColumnCommand` 与 `DeleteTableColumnCommand` 对称），相关测试见 `test/core/table_commands_test.dart`。
