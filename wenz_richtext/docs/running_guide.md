# Running the Example (Web / Windows)

`wenz_richtext` 自身是纯 Flutter package（无原生插件），example 已配置 `web/` 和 `windows/` 平台目录，可在两端运行。

## 前置要求

- Flutter SDK `>=3.22.0`，Dart SDK `>=3.3.4`（见根 `pubspec.yaml`）。
- 运行时依赖很少：除 Flutter SDK 外，当前仅引入纯 Dart 的 `package:html` 用于 HTML import/export。

## 运行 example

example 工程位于 `example/`，进入该目录执行命令。

### Windows（桌面）

```bash
cd example
flutter run -d windows
```

首次运行会编译 `windows/` runner，耗时较长。之后增量构建很快。

### Web（Chrome）

```bash
cd example
flutter run -d chrome
```

或构建静态产物：

```bash
cd example
flutter build web
# 产物在 example/build/web，可用任意静态服务器托管
```

### 选择设备

`flutter devices` 列出当前可用目标。未指定 `-d` 时 Flutter 会提示选择。

## 已支持的交互

两端均已支持（对应验收报告 1.x–6.x 已落地项）：

- **输入**：字符输入 + 中文 IME 组合输入（`EditorTextInputClient` 桥，组合区下划线渲染、选词提交）；Enter/Backspace/Delete/方向键/Shift 扩选/Ctrl 按词/Home/End/Ctrl+A/PageUp/PageDown。
- **选择**：点击定位 caret、跨块拖拽选择、双击选词、三击选段、拖到视口边缘自动滚动（鼠标/触控笔持续滚动）、整行/整列/整表选择、选区高亮 + caret 绘制。
- **剪贴板**：复制/剪切/粘贴纯文本 + 同块富 JSON + 跨块富文本（`type:blocks` payload 还原多 block 结构）+ HTML / Markdown 粘贴（`ClipboardService.parse(..., format: html/markdown)` 把 fragment 还原多 block）。
- **编辑**：加粗/斜体/下划线/删除线/批注/清除样式、link、H1–H3/段落/quote/todo/有序/无序列表、indent/outdent、代码块语言、表格结构（行列增删/列宽/对齐/表头/背景/合并/拆分）、callout、分割线。
- **undo/redo**：连续输入/删除合一 undo step，方向键/格式切换打断合并，光标移动不入历史。
- **工具栏**：`ToolbarController` 驱动 active 样式 + 命令 enable 态；example 工具栏接 bold/italic/underline/strikethrough/remark/link/clear style/H1-H3/paragraph/quote/todo/ordered/unordered/indent/outdent + 插入 code/callout/table/image/video/file/CRM embed + 表格结构按钮；Callout 默认渲染器内置类型下拉。
- **性能**：1k blocks 虚拟化（`ListView.separated` + keep-alive）、增量 rebuild（`lastChangedBlockIds`）、跨 remount 的 `SharedTextLayoutCache`。
- **序列化**：rich JSON（版本化 + migration）、legacy JSON 导入、纯文本导出。
- **媒体渲染**：`MediaResolver` 钩子让业务注入图片/视频/文件真渲染（example 用 `Image.network` 渲染 picsum 图片，并用纯 Flutter 视频预览卡演示业务播放器接入点）；未注入或 resolver 返回 `null` 时图片/视频回退占位，文件回退附件元数据卡片。
- **业务 block embed**：example 通过 `BlockRendererRegistry.registerEmbed('crm-card', ...)` 注入 CRM card renderer，并提供 `Insert CRM embed` 工具栏按钮；rich JSON/HTML 保留 `BlockEmbedNode` 数据，Markdown/plain text 可读降级。
- **Mermaid 预览**：example 默认启用 Mermaid code block 预览，初始文档内置中文流程图样例，可用于核验深色预览区的节点、连线、判断菱形和中文标签可读性。

## 当前边界（待办，详见 acceptance_report.md）

以下能力**尚未落地**，调用方应据此设定预期：

- **合并单元格视觉横跨**：默认 table renderer 已按 rowSpan/columnSpan 让 origin cell 真正跨行/跨列占满，covered cell 不渲染也不参与点击命中；三端手验仍在 `acceptance_manual_checklist.md` 中记录。
- **Markdown 导入导出**：已支持（`MarkdownCodec`，覆盖 heading/段落/list/code/table/image/divider + bold/italic/strike/underline/link）。**HTML 导入导出**：已支持（`HtmlCodec`，引 `package:html` 依赖；覆盖同上标签矩阵 + Wenz file/video 元数据 round-trip + 嵌套 emphasis 合并；malformed HTML 容错降级段落不抛）。
- **图片/视频/文件真实渲染**：注入 `MediaResolver` 后由业务自渲染（example 用 `Image.network` 渲染 picsum 图片、用无播放器依赖的视频预览卡展示 `VideoBlockNode`）；未注入或 resolver 返回 null 时图片/视频回退占位，文件回退附件元数据卡片。`video_player` 等依赖由业务侧引入。
- **移动端 selection handles**：iOS/Android 手柄拖拽改选区，任务 C9（触屏跨视口选区目前由同步边缘滚动承接）。
- **Golden tests / a11y 语义节点**：Golden 矩阵已覆盖基础块、selection/caret 与高级块 + inline embed；C6 自动化 Semantics 节点已补齐，TalkBack/Narrator 抽样仍需人工手验。
- **formula / mention / emoji inline**：默认 renderer 会显示公式文本、`@label` 与 emoji 字符，业务可通过 `InlineEmbedRenderer` 覆盖为自定义 `TextSpan`；Markdown/HTML 仍按可读文本降级，不还原为 embed。
- **Block embed 业务 renderer**：大交互内容优先使用 `BlockEmbedNode` + `BlockRendererRegistry.registerEmbed`；自定义原子块可包 `WenzObjectBlockSurface` 保留 selection/geometry/debug 行为。

## Web 焦点

点击编辑器区域会显式请求焦点以显示 caret。如遇 caret 不出现，确认浏览器未拦截焦点（部分 iframe 嵌入场景需要 `tabindex`）。

## Mermaid 预览人工核验

在 Windows desktop example 中打开初始文档里的 Mermaid 中文流程图 code block，执行以下手验：

1. 点击 code block 右上角预览按钮，确认流程图完整适配在固定比例预览区内，节点、连线、箭头、判断菱形和中文标签在深色背景下清晰可读。
2. 点击预览区使其聚焦，直接滚动鼠标滚轮或触控板，确认无需进入额外全图视图即可缩放。
3. 在预览区拖拽平移，确认缩放后的流程图可移动查看，父级编辑器滚动不抢占当前缩放手势。
4. 缩放或平移后切回源码，再切回预览，确认 SVG 仍可重新完整适配并继续响应滚轮缩放和拖拽平移。

## Debug overlay

example 右侧 Inspector 面板有 "Debug overlay" 开关。开启后，当前命中的 block 右上角叠加显示 `blockIndex`、`blockId`、`path`、`offset`，用于排查选区与定位问题。不影响布局与 offset 计算。

Inspector 面板还包含：JSON inspector（实时展示 `controller.toJson()`）、ToolbarController 状态、Events 节（最近一条 `onChanged`/`onSelectionChanged`/`onCommandExecuted`），以及 Autosave 节（dirty/status/revision/草稿字节数/手动 Save now），演示 `WenzAutoSaveController` 通过外部草稿 adapter 做防抖保存。

## 排查

- `flutter analyze` 在根目录应无问题。
- `flutter test` 在根目录运行全部单元 + widget 测试。
- example 单独分析：`cd example && flutter analyze`。
