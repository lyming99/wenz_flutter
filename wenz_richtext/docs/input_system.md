# Input System

阶段 1 输入系统的架构说明：IME 桥、剪贴板、快捷键、命令合并。

## 总览

输入由六条路径汇入 `WenzRichTextController`：

1. **IME / TextInputClient**（字符输入、组合输入）— `EditorTextInputClient`。
2. **键盘快捷键**（非字符键、Ctrl 组合）— `EditorShortcutManager` 解析 keymap，`WenzRichTextEditor` 执行动作。
3. **剪贴板**（复制/剪切/粘贴）— `ClipboardService` + 控制器方法。
4. **右键菜单**（桌面 secondary-click UI 入口）— `SelectionGestureOverlay` 触发，`WenzRichTextEditor` 定位并分发菜单动作。
5. **外部图片输入**（图片剪贴板 flavor、外部文件拖拽）— `ExternalImageInput` + `ExternalImageStore`。
6. **命令合并**（undo 粒度）— `CommandExecutor` + `HistoryManager.merge`。

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
- `AutoLinkUrlsCommand` 由 `insertText` 在检测到 URL 候选文本或收尾字符后自动触发，并与前一条 `InsertTextCommand` 合并为同一个 undo step。
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
| 跨块范围 | `wenz-richtext-json:v1\n` + JSON（`{type:blocks, blocks:[...], plain}`），保留每个 block 的 type/attributes/inline 属性；首尾 block 按选区 offset 切片。`plain` 字段是 `\n` 连接的纯文本回退 |

### 粘贴

`ClipboardService.parse` 检测魔法前缀：有 → 解析富文本（`inline` 或 `blocks`）；无 → 当纯文本。

- `inline`：以多个 `InsertTextCommand`（逐 run，保留属性）插入当前 caret。
- `blocks`：走 `PasteBlocksCommand`——删除当前选区后，在 caret 处分裂当前 block，首块 inline 合并进前半段，末块 inline 合并进后半段，中间 block 按原 type/attributes 作为新 block 插入。
- 普通块纯文本多行：首行插入当前块，后续每行触发 `EnterCommand` 分段，保持段落粘贴拆分为多个 block 的既有语义。
- 代码块内纯文本：当 `pasteText(raw)` 解析为 plain text，且当前 selection 完全位于同一个 `CodeBlockNode` 的 `PositionPath.blockCode` 内时，不再按换行拆分；控制器通过一次 `InsertTextCommand` 把原始文本插入同一个 `CodeBlockNode.code`，保留 `\n`、空行、缩进、尾随换行和普通代码字符。

代码块纯文本快路径仍然走 `WenzRichTextController.execute`，所以 permission gate、selection 替换、schema normalisation、history、`lastChangedBlockIds` 和回调顺序都与普通命令一致。一次代码块多行粘贴表现为单个命令、单个 undo step、一次 `onChanged`、一次 `onCommandExecuted` 和一次 listener 通知；插入后 caret 落在粘贴文本末尾，代码块 `id`、`language` 和 `attributes` 保持不变。该快路径只作用于 plain text；Wenz rich JSON、HTML、Markdown、外部图片和表格单元格粘贴仍按各自路径处理。

普通纯文本输入/粘贴默认会识别 `http(s)://` 和 `www.` URL，并通过命令层写入 `TextAttributes.url`；代码块纯文本快路径会显式关闭 Markdown shortcut 与 AutoLink，避免 `# `、三个反引号或 URL 等代码内容产生格式化/链接副作用。业务侧可在直接调用 `insertText` 时传 `applyAutoLinkUrls: false` 关闭本次自动识别。

控制器方法：`copySelection()` / `cutSelection()` / `pasteText(raw)` /
`pasteMarkdown(markdown)` / `pasteHtml(html)`。widget 的 Ctrl+C/X/V 调用纯文本
入口并桥接 `Clipboard.setData/getText`；业务层如果能拿到平台 HTML/Markdown
flavour，可以直接调用对应入口。

### 图片粘贴与外部文件拖拽

Flutter 标准 `Clipboard` 不暴露图片 bytes、文件 URI 或微信/QQ 等 IM 软件复制图片时的多 flavor 数据；这些平台数据通过 `ExternalImageClipboardReader` 进入 widget 层，并在进入控制器前转换成稳定的 `ExternalImageInput`：

- `memory`：截图、IM 临时图片、平台暴露的 PNG/JPEG/GIF/WebP/BMP bytes。
- `filePath`：复制图片文件或拖拽图片文件时得到的本地路径。
- `fileUri`：平台拖放/剪贴板暴露的 `file://` URI。

粘贴优先级保持兼容：

1. Wenz rich JSON 前缀优先，保证编辑器自身复制的富文本语义不被图片 flavor 抢占。
2. 其次处理外部图片输入；成功准备出的图片按现有块级粘贴语义插入 `ImageBlockNode`。
3. 无可用图片时继续回退 HTML / Markdown / plain text。

外部图片拖拽由 `WenzRichTextEditor` 的外部 drop target 接收，并与图片剪贴板共用同一条 `ExternalImageInput` -> `ExternalImageStore.prepare` -> `WenzRichTextController.pasteExternalImages` 管线。平台提供的本地路径、`file://` URI 或图片 bytes 会转换成 `ExternalImageInputSource.drop` 的 `filePath` / `fileUri` / `memory` 候选；通过扩展名、MIME、URI scheme 或字节签名校验的候选按平台顺序交给 store，随后进入 `PasteBlocksCommand` / `InsertBlocksCommand`，因此撤销/重做、selection 和权限门禁与普通块粘贴一致。外部 drop 入口只在 `enableExternalImageInput == true`、`enableExternalDragDrop == true`、非只读、controller 可编辑且当前平台不是移动端选择 UI 平台时挂载；Android/iOS 等触摸移动端不挂载外部 `DropRegion`，避免干扰文字选择手势。

默认 IO store 的边界：

- 文件 path / file URI：插入前校验路径存在、非目录、非空文件，并按扩展名/MIME/文件签名确认是支持的图片；校验通过后会尽量读取本地文件 bytes，从 PNG/JPEG/GIF/WebP/BMP 字节头提取原始像素 `width`/`height`，并写入 `ExternalImageBlockDescription`。
- 内存 bytes：写入系统临时目录，文件名带 `wenz-external-image` 前缀，扩展名优先来自 MIME，其次来自 bytes 签名；写入前同样尽量读取原始像素 `width`/`height`，并写入 `ExternalImageBlockDescription`。
- 尺寸读取失败时字段留空，插入流程继续使用已有 fallback；Web 或不支持平台返回可诊断失败，不向 UI 抛异常。

`ExternalImageBlockDescription.width` / `height` 表示原图固有像素尺寸；
`ClipboardService.parseExternalImages` 会把它们透传到 `ImageBlockNode.width`
/ `height`，供默认图片块按真实比例约束首次显示框；未知尺寸进入
`ImageBlockNode` 时为 `0`。`showWidth` / `showHeight` 只表示用户调整后的显示尺寸，
首次粘贴不会用原始像素尺寸填充这两个字段。默认图片显示框按
`showWidth`/`showHeight`、固有 `width`/`height`、兼容占位比例的顺序确定几何尺寸；
因此已知真实像素的外部图片首次显示会保持原始宽高比，选中框和 resize 命中区与同一框对齐。
自定义 `ExternalImageStore` 在 materialize 图片时应尽量提供真实尺寸；无法获得时可留空，编辑器会回退到兼容占位比例。

宿主可通过 `WenzEditorConfiguration` 或直接构造 `WenzRichTextEditor` 接管策略：

```dart
WenzEditorConfiguration(
  enableExternalImageInput: true,
  enableExternalDragDrop: true,
  externalImageClipboardReader: myPlatformReader,
  externalImageStore: myStore,
);
```

`enableExternalImageInput: false` 会关闭图片剪贴板 flavor 和所有外部图片拖拽输入；普通文本、Wenz rich JSON、HTML、Markdown 粘贴不受影响。`enableExternalDragDrop: false` 只卸载桌面外部图片拖拽入口，图片剪贴板仍按 `enableExternalImageInput` 处理。核心包只生成图片块描述、可用时的原图尺寸和临时/本地文件引用，不负责上传、长期持久化、清理临时文件或把本地路径映射为业务 asset，这些策略应由宿主通过 `ExternalImageStore` 或 `MediaResolver` 接管。

### HTML/Markdown 粘贴

`ClipboardService.parse(raw, format: ...)` 是统一解析入口：

- `auto`：默认行为，识别 Wenz rich JSON 前缀，否则作为纯文本。
- `plainText`：强制纯文本，不识别 rich JSON。
- `markdown`：经 `MarkdownCodec.decode` 还原为 `ClipboardPaste.blocks`。
- `html`：经 `HtmlCodec.decode` 还原为 `ClipboardPaste.blocks`。

`ClipboardService.parseMarkdown` / `parseHtml` 是对应的便捷入口；
`pasteHtml` 保留为 `parseHtml` 的别名。旧的 `pasteMarkdown` 保留 inline-only
兼容行为，完整块结构粘贴请使用 `parseMarkdown` 或 `parse(..., format: markdown)`。

## 右键菜单

右键菜单是桌面端的 UI 入口，不是新的数据通道。`SelectionGestureOverlay`
在鼠标 secondary button 按下时构造 `SelectionContextMenuRequest`，包含全局
坐标和命中的 `DocumentPosition?`；`WenzRichTextEditor` 再根据当前 selection、
命中位置、`readOnly` 和 controller 权限生成 `WenzEditorContextMenuContext`。

### selection 与定位

- 如果右键落在已有非折叠 selection 内，菜单保留原 selection，复制、剪切、
  删除等动作继续作用于那段选区。
- 如果右键落在 selection 外且能解析到文档位置，编辑器会先把 selection 更新为
  该命中位置对应的 collapsed/对象选区，再打开菜单；菜单 action 收到的是更新后的
  context。
- 菜单锚点使用请求时的全局坐标，并按当前视口约束计算可见区域内的位置；代码块、
  表格单元格、对象块、空段落和滚动中的虚拟挂载块都走同一套 geometry/hit-test
  contract。

### 默认动作与权限

默认项包含复制、剪切、粘贴、删除、全选，以及插入段落、标题、引用、代码块、
分割线、表格、图片块、视频块、文件块、公式和提示块。复制/剪切/粘贴/全选显示
平台快捷键提示（Windows/Linux/Web/Android 为 Ctrl，macOS/iOS 为 Cmd），但这些
提示只是菜单 chrome；实际执行仍复用快捷键路径里的 `_handleCopy`、`_handleCut`、
`_handlePaste`、`selectAll` 和已有 controller/helper。

只读或无编辑权限时，复制、全选等非写动作在满足选区条件时仍可用；剪切、粘贴、
删除和插入类写动作会禁用。即使自定义菜单误触发写逻辑，真正的文档变更也必须走
`WenzRichTextController` 的命令/helper，因此 `WenzEditorPermission` gate、
history、schema normalisation、undo/redo 和回调仍是唯一可信边界。

### 与 IME、剪贴板和 overlay 的关系

- 复制/剪切/粘贴菜单项复用 `ClipboardService` 与平台 `Clipboard` 桥接，粘贴优先级
  仍是 Wenz rich JSON → 外部图片输入 → HTML/Markdown/plain text。
- 右键菜单打开前会同步输入缓冲；菜单本身不修改 IME composing 区间，也不会绕过
  `EditorTextInputClient`。
- 右键菜单使用 `showMenu` route，而不是 slash menu、mention search 或公式编辑器
  overlay。打开菜单前会关闭这些同级浮层，避免多个输入浮层同时抢键盘/焦点。
- 点击外部、滚动、selection 变化、controller 替换、`readOnly` 切换或 editor
  dispose 时会 dismiss 菜单 route；关闭后如果编辑器原本有焦点，会恢复焦点并同步
  buffer。

宿主可通过 `WenzEditorContextMenuConfiguration` 追加或替换菜单项。自定义 action
收到 `WenzEditorContextMenuContext`，可读取 `selection`、`hitPosition`、
`hitInsideSelection`、`canEdit` 和 `controller`，但应继续调用 controller 命令或业务
UI，不应直接改 document model。

## 快捷键

`EditorShortcutManager`（`lib/src/input/shortcut_manager.dart`）负责把
`KeyEvent` 解析为 `EditorShortcutIntent`，不直接依赖 controller、Clipboard
或 widget 状态。`WenzRichTextEditor._handleKeyEvent` 只读取当前修饰键状态，
把解析结果交给 `_performShortcut` 执行，因此 keymap 可以用纯单元测试覆盖。

`_handleKeyEvent` 按修饰键分层：

| 键 | 行为 | 只读可用 |
| --- | --- | --- |
| 字符（IME 未 attach） | `insertText` | 否 |
| ←/→ | 移动 caret（Shift 扩选） | 否 |
| Home/End | 块首/块尾（Shift 扩选） | 否 |
| PageUp/Down | 按视口高度翻页（Shift 扩选），跳完后自动滚动到 caret | 否 |
| Backspace/Delete | 删除 | 否 |
| Enter | 分段 | 否 |
| Ctrl+Enter / Ctrl+NumpadEnter | 在当前选择下方插入空正文段落 | 否 |
| Ctrl+Shift+Enter / Ctrl+Shift+NumpadEnter | 在当前选择上方插入空正文段落 | 否 |
| Ctrl/Cmd+A | 全选 | 是 |
| Ctrl/Cmd+C | 复制 | 是 |
| Ctrl/Cmd+X | 剪切 | 否 |
| Ctrl/Cmd+V | 粘贴 | 否 |
| Ctrl/Cmd+F | 查找 | 是（仅在接入查找入口时拦截） |
| Ctrl/Cmd+H | 替换 | 否（仅在接入替换入口时拦截） |
| Ctrl/Cmd+Z / Ctrl+Shift+Z | 撤销/重做 | 否 |
| Ctrl/Cmd+Y | 重做 | 否 |
| Ctrl/Cmd+←/→ | 按词移动（Shift 扩选） | 否 |
| Ctrl/Cmd+Home/End | 文档首/尾 | 否 |

`EditorShortcutManager` 的查找/替换 intent 由 widget 层按需启用：
`WenzRichTextEditor` 只有在传入 `findController`、`onFindRequested` 或
`onReplaceRequested` 时才会处理 Ctrl/Cmd+F/H；否则这些组合键继续冒泡给
浏览器或宿主应用。

Enter 的键盘路径只负责把 intent 分发到 `controller.enter()`，实际文档语义由
`EnterCommand` 决定，和业务直接调用 `WenzRichTextController.enter()` 共用同一条
命令、history、schema normalisation、selection 和回调路径。标题块末尾按 Enter 会
在标题后创建空正文段落，caret 落在新段落开头；标题中部仍按当前文本分裂为两个标题。
普通段落、列表续行/空列表退出、引用续行/空引用退出、代码块内换行和表格单元格内换行
继续走各自既有命令分支。这个行为只影响命令生成的新块类型和属性，不改变持久化 schema，
不需要 schema migration，也不应在 widget 层另加一次性特殊分支。

Ctrl+Enter 和 Ctrl+NumpadEnter 不分裂当前内容，而是通过
`controller.insertTextBlockBelow()` 在当前选择结束块下方插入空 paragraph；
Ctrl+Shift+Enter 和 Ctrl+Shift+NumpadEnter 对应
`controller.insertTextBlockAbove()`，使用选择起点块上方作为插入位置。新块始终是
普通空正文段落，caret 落在新块开头，并沿用同一条 command、history、permission、
selection 同步路径；对象块、代码块和表格单元格选择只决定 top-level 插入边界，
不复制原块类型。

### 快捷键配置契约

快捷键配置只描述“键盘事件如何解析”，不直接执行命令、不访问 Clipboard，
也不绕过 `_performShortcut`。未传入配置时必须保持上表默认行为兼容，包括
选择、撤销/重做、复制/剪切/粘贴、查找/替换、方向键、Home/End、
PageUp/PageDown、删除、回车和普通字符输入。

配置对象需要能表达以下能力：

- 追加绑定：为某个 `EditorShortcutIntent` 增加新的组合键，同一 intent 可以有多个别名。
- 覆盖默认绑定：同一标准化组合键后定义的绑定覆盖先定义的绑定。
- 禁用 intent：把指定 intent 的解析结果转为 `ignored`，常用于关闭写操作或业务不开放的能力。
- 透传组合键：把指定组合键解析为 `passThrough`，交回宿主 `Focus`/`Actions`、浏览器或外层应用处理。
- 平台主修饰键：使用 `primary` 表示 Windows/Linux/Web/Android 上的 Ctrl、macOS/iOS 上的 Cmd，也允许精确指定 Ctrl/Alt/Meta/Shift。

最小示例：

```dart
import 'package:flutter/services.dart';

final pluginShortcuts = <EditorShortcutConfiguration>[];
installWenzRichTextPlugins(
  plugins: [myPlugin],
  context: WenzPluginContext(
    controller: controller,
    shortcutConfigurations: pluginShortcuts,
  ),
);

final appShortcuts = EditorShortcutConfiguration(
  bindings: const <EditorShortcutBinding>[
    // Ctrl/Cmd+S 不由编辑器处理，交给宿主保存逻辑。
    EditorShortcutBinding.passThrough(
      shortcut: EditorShortcutKey(
        LogicalKeyboardKey.keyS,
        modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
      ),
    ),
    // Ctrl/Cmd+K 改为触发现有查找 intent。
    EditorShortcutBinding.handled(
      shortcut: EditorShortcutKey(
        LogicalKeyboardKey.keyK,
        modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
      ),
      intent: EditorShortcutIntent.find,
    ),
  ],
  // 禁用默认粘贴 intent。
  disabledIntents: const <EditorShortcutIntent>{EditorShortcutIntent.paste},
);

WenzRichTextEditor(
  controller: controller,
  onFindRequested: openFindPanel,
  shortcutConfiguration: mergeWenzShortcutConfigurations(
    pluginConfigurations: pluginShortcuts,
    editorConfiguration: appShortcuts,
  ),
);
```

合并与冲突策略固定为：默认 keymap → 插件/扩展贡献 → 编辑器显式配置。
标准化组合键由平台集合、修饰键集合和 `LogicalKeyboardKey` 组成；同一组合键
绑定多个 intent 时后者覆盖前者，同一 intent 绑定多个组合键时全部保留。
无效字符键（例如空字符、多字符、控制字符，或没有 `character` 的
`insertCharacter` 绑定）会出现在 `EditorShortcutConfiguration.validate()` 的
结果中，运行时不应退化为普通文本输入。

配置解析仍需遵守输入系统边界：只读态下写 intent（撤销/重做、剪切、粘贴、
删除、回车、插入字符等）解析后转为 `ignored`；IME composing 或 text input
client 已 attach 时禁止把普通字符键解析成 `insertCharacter`，但带主修饰键的
命令快捷键仍可继续解析。斜杆菜单打开时的 ArrowUp/ArrowDown/Enter/Escape，
以及代码块内的 Tab/Shift+Tab，仍由 widget 层优先处理，不由普通 keymap 覆盖。

配置能力的边界是“键盘事件 → 解析结果”：它不会绕过
`WenzRichTextController`、不会直接修改文档模型，也不会替代外层 Flutter
`Focus`/`Actions`。业务自定义命令若不属于现有 `EditorShortcutIntent`，应把组合键
配置为 `passThrough`，在宿主层处理后再调用自己的 controller 命令或 UI 逻辑。

## 查找替换

`WenzFindReplaceController` 监听宿主 `WenzRichTextController`，维护 query、
replacement、匹配项列表和当前命中。匹配范围使用现有
`DocumentSelection`/`PositionPath`，覆盖普通文本块、代码块和表格单元格的
首个文本块。

- `next()` / `previous()` 会把编辑器 selection 移到当前命中。
- `replaceCurrent()` 通过 `controller.insertText(..., applyMarkdownShortcuts: false)`
  替换当前 selection，因此复用既有删除选区、表格 cell 输入和 history 逻辑。
- `replaceAll()` 从后往前替换，避免前面的替换移动后续 offset。
- `FindReplaceOptions.caseSensitive` 和 `wholeWord` 已预留并实现基础匹配。

`WenzRichTextEditor.findController` 会把所有命中绘制为搜索高亮，当前命中用
更明显的颜色；`WenzFindReplacePanel` 是可嵌入的基础 UI，业务层可以放在
工具栏、侧栏或自定义浮层内。

## Slash 菜单

`SlashMenuController` 监听宿主 `WenzRichTextController`，在 collapsed caret
前检测 `/query` 触发范围。菜单项来自 `SlashMenuRegistry`，默认包含
`heading`、`list`、`todo`、`quote`、`code`、`table`、`image`；业务侧可以
通过 `registry.register(SlashMenuItem(...))` 扩展。

触发规则与代码编辑器的命令补全类似：

- caret 必须位于可编辑的普通文本块内，且 selection 是 collapsed。
- `/` 可以出现在段落开头，或出现在 ASCII/Unicode 空白字符之后；例如空段落输入
  `/`、段首输入 `/`、正文中输入 `hello /` 都会打开菜单。
- `/` 后面的连续非空白文本作为 query；输入 `/h`、`/table`、`/video` 会实时刷新
  `SlashMenuController.query` 和过滤后的菜单项。
- URL、单词中间的 `/`、跨 block selection、对象块 selection、表格对象 selection
  不会触发，避免把普通文本误判为命令。

`WenzRichTextEditor.slashMenuController` 接入后会：

- 在菜单打开时把 `WenzSlashMenuOverlay` 绘制到全局 Overlay，并以当前 caret 作为
  锚点；空间不足时会在可视区域内选择上方或下方展示，避免被编辑器父布局裁剪。
- ArrowUp / ArrowDown 移动高亮项。
- Enter 执行当前项。
- Esc 关闭菜单。
- 鼠标点击菜单项会执行对应命令，焦点仍回到编辑器。

执行菜单项时，controller 先用现有 `deleteSelection` 删除 `/query` 触发文本，
再运行菜单项 action。默认项都转成既有命令或 controller helper，因此进入
undo/redo：文本类走 `setBlockType` / `toggleTodo`，代码/图片走
`insertBlocks` / `replaceBlocks`，表格走 `insertTable`。

不展示 popup 时优先按以下顺序排查：

- 是否把同一个 `WenzRichTextController` 传给了 `WenzRichTextEditor.controller` 和
  `SlashMenuController(editor: controller)`，并把后者传入
  `WenzRichTextEditor.slashMenuController`。
- 编辑器是否处于 `readOnly: true`，或 controller 权限不是可编辑状态。
- 输入法是否仍在 composing 阶段；组合输入期间菜单会冻结/不打开，commit 后再重新检测。
- 当前 query 是否无匹配项；无匹配命令时 `isOpen` 为 false，不显示空 popup。
- 是否刚手动 Esc/点击外部关闭；只有触发范围或 query 发生变化后才会重新打开。
- caret 是否已经离开 `/query` 范围，或 `/` 已被删除。

## 代码块 Tab 缩进

当 selection 位于同一个 `CodeBlockNode` 的 `PositionPath.blockCode` 内时，
`WenzRichTextEditor` 会优先拦截 Tab / Shift+Tab，不再把它当成表格导航或
焦点切换。Tab 调用 `controller.indentCodeBlock()`，Shift+Tab 调用
`controller.indentCodeBlock(outdent: true)`；底层为 `IndentCodeBlockCommand`，
会对 selection 覆盖到的每一行插入或移除缩进，并同步修正 caret/selection
offset，因此可以 undo/redo。

## Markdown 快捷输入

`WenzRichTextController.insertText` 在单字符输入后会尝试执行
`ApplyMarkdownShortcutCommand`。快捷转换本身仍然走命令层，所以 schema
normalise、history、callbacks 和 undo/redo 都保持一致。

当前触发规则：

| 输入 | 行为 |
| --- | --- |
| `# ` / `## ` / ... / `###### ` | 转为 1-6 级标题 |
| `- ` / `* ` | 转为无序列表 |
| `1. ` / `2. ` / ... | 转为有序列表 |
| `> ` | 转为引用块 |
| 三个反引号 | 转为空代码块 |
| `---` | 转为分割线，并在后面创建一个空段落 |
| 在无序列表项中输入 `[ ] ` | 转为未勾选任务列表 |
| 在无序列表项中输入 `[x] ` / `[X] ` | 转为已勾选任务列表 |

程序化插入不希望触发自动格式化时，可以传：

```dart
controller.insertText(' ', applyMarkdownShortcuts: false);
```

## 阶段边界（留到后续）

- 可配置 keymap → 后续插件化阶段。
- 可插拔 paste transformer → 后续插件化阶段。
- 列表缩进体验增强 → `[done] ADV-008`；代码块 Tab/Shift+Tab 缩进 → `[done] ADV-009`。
- IME 组合期的精确 selection handles（移动端）→ 后续移动端专项。
