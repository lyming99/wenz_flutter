# Input System

阶段 1 输入系统的架构说明：IME 桥、剪贴板、快捷键、命令合并。

## 总览

输入由四条路径汇入 `WenzRichTextController`：

1. **IME / TextInputClient**（字符输入、组合输入）— `EditorTextInputClient`。
2. **键盘快捷键**（非字符键、Ctrl 组合）— `WenzRichTextEditor._handleKeyEvent`。
3. **剪贴板**（复制/剪切/粘贴）— `ClipboardService` + 控制器方法。
4. **命令合并**（undo 粒度）— `CommandExecutor` + `HistoryManager.merge`。

所有改动最终经 `EditorCommand` → `CommandExecutor.execute` → `DocumentSession`，保持单一变更入口。

## IME / TextInputClient

`EditorTextInputClient`（`lib/src/input/editor_text_input_client.dart`）混入 `DeltaTextInputClient`，在 widget 获得焦点时 `TextInput.attach`，向平台暴露**当前可编辑块的纯文本缓冲**。

### 工作流程

```
平台 IME ──TextEditingDelta──▶ EditorTextInputClient.updateEditingValueWithDeltas
                                      │
                                      ▼
                      ┌───────────────┴───────────────┐
                insertion/deletion/replacement    nonTextUpdate
                      │                               │
                      ▼                               ▼
          controller.insertText /            controller.setCompositionState
          controller.deleteSelection         (组合区间 → 渲染下划线)
```

- **缓冲模型**：`_buffer` = 当前光标所在块的纯文本 + caret/composing。平台只看到单块文本，delta 的 offset 直接映射到块内偏移。
- **组合输入**（中文 IME）：拼音输入阶段，`composing` region 非空 → `controller.compositionState` 被设置 → 渲染层给该范围加下划线（`TextDecoration.underline`）。候选词提交时 delta 是 `Replacement`（用候选字替换拼音），组合区间清空。
- **生命周期**：`WenzRichTextEditor.enableIme`（默认 true）控制。获得焦点且非只读时 attach，失焦/dispose 时 detach。`enableIme: false` 时字符输入回退到 key-event `character`（用于无平台 IME 的测试环境）。

### CompositionState

`CompositionState`（`lib/src/input/composition_state.dart`）描述当前组合区间：`blockId` / `blockIndex` / `path` / `startOffset` / `endOffset`。`isEmpty` 表示无组合。它**不进 undo/redo 历史**，是临时 UI 状态，由 `controller.setCompositionState` 驱动、`notifyListeners` 触发重绘。

## 命令合并（undo 粒度）

`CommandExecutor.execute` 在 `history.push` 前咨询 `command.canMergeWith(lastCommand)`：

- `InsertTextCommand.canMergeWith` → 连续相同 attributes 的插入合并为一个 undo step。
- `DeleteBackwardCommand` / `DeleteForwardCommand` → 连续同向删除合并。
- `MoveCaretCommand` / `MoveCaretByWordCommand` / `*BoundaryCommand` / `SelectAllCommand` → `breaksMergeRun: true`，**移动光标打断合并**（即便它们 `recordHistory: false`）。
- `EnterCommand` / `DeleteSelectionCommand` / 样式/块命令 → 不合并，每步独立。

连续性由 `CommandExecutor._isContiguous` 保证：新命令开始时的 collapsed caret 必须等于上一条命令结束时的 caret，否则降级为 push。这防止光标跳转后误合并。

## 剪贴板

`ClipboardService`（`lib/src/input/clipboard_service.dart`）是纯逻辑层，不直接调用 `Clipboard`（platform 交互在 widget 层）。

### 复制格式

| 选区 | 输出 |
| --- | --- |
| 同块文本范围 | `wenz-richtext-json:v1\n` + JSON（`{type:inline, runs:[...], plain}`），保留 TextRun 属性 |
| 代码块范围 | 纯文本切片 |
| 跨块范围 | 纯文本，行用 `\n` 连接（富文本跨块留到阶段 2） |

### 粘贴

`ClipboardService.parse` 检测魔法前缀：有 → 解析富文本 inline runs；无 → 当纯文本。纯文本多行：首行插入当前块，后续每行触发 `EnterCommand` 分段。

控制器方法：`copySelection()` / `cutSelection()` / `pasteText(raw)`。widget 的 Ctrl+C/X/V 调用它们并桥接 `Clipboard.setData/getText`。

### HTML/Markdown 预留

`ClipboardService.pasteHtml` / `pasteMarkdown` 当前返回 `null`（阶段 6 实现），接口已预留。

## 快捷键

`_handleKeyEvent` 按修饰键分层：

| 键 | 行为 | 只读可用 |
| --- | --- | --- |
| 字符（IME 未 attach） | `insertText` | 否 |
| ←/→ | 移动 caret（Shift 扩选） | 否 |
| Home/End | 块首/块尾（Shift 扩选） | 否 |
| PageUp/Down | 块首/块尾（阶段 5 精化视口） | 否 |
| Backspace/Delete | 删除 | 否 |
| Enter | 分段 | 否 |
| Ctrl/Cmd+A | 全选 | 是 |
| Ctrl/Cmd+C | 复制 | 是 |
| Ctrl/Cmd+X | 剪切 | 否 |
| Ctrl/Cmd+V | 粘贴 | 否 |
| Ctrl/Cmd+Z / Ctrl+Shift+Z | 撤销/重做 | 否 |
| Ctrl/Cmd+Y | 重做 | 否 |
| Ctrl/Cmd+←/→ | 按词移动（Shift 扩选） | 否 |
| Ctrl/Cmd+Home/End | 文档首/尾 | 否 |

## 阶段边界（留到后续）

- 跨块拖拽选择 → 阶段 2。
- 富文本跨块复制粘贴 → 阶段 2（依赖跨块选区）。
- Tab 缩进 / 列表缩进 → 阶段 3。
- HTML/Markdown 导入导出 → 阶段 6。
- IME 组合期的精确 selection handles（移动端）→ 阶段 2/8。
