# 富文本编辑器进阶功能矩阵

更新时间：2026-06-24

本文档对应 \`docs/advanced\_feature\_development\_plan.md\` 中的 \`\[done\] ADV-001\` / \`\[done\] ADV-002\`，用于记录当前能力基线、进阶功能状态、主要代码落点和下一步任务。

## 状态定义

状态 | 含义
--- | ---
`supported` | 已有模型、命令、渲染或 codec，并具备可用主流程。
`partial` | 已有模型、接口或骨架，但体验、UI、测试或平台接入还不完整。
`planned` | 计划实现，当前没有稳定代码入口。
`deferred` | 有价值，但不进入近期核心开发，先通过方案或外部 adapter 预留。

## 阶段 0 验收状态

任务 | 状态 | 覆盖内容 | 验收结论
--- | --- | --- | ---
`[done] ADV-001` | supported | 当前能力基线、进阶功能状态、代码/文档落点、后续任务入口 | 已产出本矩阵文档，并对每个后续阶段保留 schema 影响与测试入口。
`[done] ADV-002` | supported | rich JSON v2 基线、schema bump 规则、future v3 候选、必测清单 | 不引入破坏现有 JSON round-trip 的 schema 变更；详见 `docs/schema_migration_impact.md`。

## 当前能力摘要

- \`ADV-002\` 已补 \`docs/schema\_migration\_impact.md\`，当前 rich JSON 以 v2 为基线；后续破坏性字段变更必须先补 migration 方案和 fixture 测试。

- 当前核心已经具备自研文档模型、命令体系、history、IME、剪贴板、selection、block renderer registry、media resolver、inline embed renderer、Markdown/HTML codec。

- 适合优先补齐的不是“基础模型”，而是高频编辑体验：Markdown 快捷输入、快捷键集中管理、粘贴 pipeline、查找替换、Slash 菜单。

- 结构化内容中，Callout 已完成类型/标题/图标增强；表格已补默认浮动工具条、列宽拖拽与 HTML 合并单元格 codec，File、Video、InlineEmbed 已有模型或渲染基础但部分高级交互仍属于 \`partial\`。

- PDF/DOCX 已完成 adapter 边界设计；版本快照已提供外部存储模型和恢复 helper；评论线程已具备基础模型、JSON 持久化和侧栏 UI，修订仍属于后续阶段，需要先设计 schema 和 adapter 边界。

## 功能矩阵

分类 | 功能 | 状态 | 当前代码/文档落点 | 下一步任务
--- | --- | --- | --- | ---
文档模型 | RichTextDocument + BlockNode + InlineNode | supported | `lib/src/core/model/`、`docs/architecture.md` | 继续保持纯 Dart 模型边界
文档模型 | Schema normalize | supported | `lib/src/core/schema/document_schema.dart`、`docs/schema_and_commands.md` | 新字段进入前按 `docs/schema_migration_impact.md` 评估 migration 策略
文档模型 | Schema 影响与 JSON migration 方案 | supported | `docs/schema_migration_impact.md`、`lib/src/codecs/document_migration.dart` | `[done] ADV-002`：当前不新增 schema bump；评论/修订/内建链接预览/document metadata 需先做 v3 方案
文档模型 | 文档 metadata | planned | 无正文级稳定模型 | 版本历史元信息由 `[done] ADV-020` 外部快照模型承载；正文 metadata 后续另评估
基础编辑 | 文本输入、删除、回车分段 | supported | `lib/src/core/commands/text_commands.dart` | 保持回归测试
基础编辑 | undo/redo | supported | `lib/src/history/history_manager.dart`、`lib/src/core/commands/command_executor.dart` | 与自动格式化合并历史步
基础编辑 | 连续输入/删除命令合并 | supported | `docs/input_system.md` | 为 Markdown 快捷输入补合并策略
基础编辑 | 查找替换 | supported | `WenzFindReplaceController`、`WenzFindReplacePanel`、`WenzRichTextEditor.findController` | `[done] ADV-006`：支持当前/全部替换、全部命中高亮、上/下一个、大小写/全词匹配
基础编辑 | 拖拽调整块顺序 | planned | 无稳定入口 | 阶段 2 后评估
格式样式 | bold/italic/underline/strike/color/background/font | supported | `lib/src/core/model/attributes.dart`、`lib/src/core/commands/style_commands.dart` | 工具栏和快捷键补全
格式样式 | link 设置/清除 | supported | `SetLinkCommand`、`AutoLinkUrlsCommand`、`WenzLinkEditDialog` | `[done] ADV-014`：链接编辑 UI 和自动识别 URL 已接入
格式样式 | remark 标记 | partial | `TextAttributes.remark`、`ToggleMarkCommand` | 与评论 anchor 合并设计
块结构 | heading/paragraph/quote/listItem/code/table/image/video/file/callout/divider | supported | `lib/src/core/model/block_node.dart` | 新 block 走 schema + codec + renderer
块结构 | 有序/无序/任务列表 | supported | `BlockAttributes.listType/checked/indent`、`EnterCommand`、`IndentCommand`、`ToggleTodoCommand` | `[done] ADV-008`：非空列表 Enter 延续；task 新项默认未勾选；空列表 Enter 退出列表；缩进复用 indent/outdent
块结构 | Callout | supported | `CalloutBlockNode`、`SetCalloutVariantCommand`、`UpdateCalloutBlockCommand`、默认 `_CalloutRenderer`、`HtmlCodec`/`MarkdownCodec` | `[done] ADV-010`：支持 info/success/warning/danger、标题、图标、正文；默认 renderer 提供类型下拉，切换与元数据更新进入 undo/redo；HTML 结构化保留，Markdown 降级为 blockquote
块结构 | 代码块语言、复制与 Tab 缩进 | supported | `CodeBlockNode.language`、`SetCodeLanguageCommand`、`IndentCodeBlockCommand`、默认 `_CodeBlockToolbar` | `[done] ADV-009`：默认代码块工具条支持语言下拉与复制代码；Tab/Shift+Tab 在代码块内缩进/反缩进并进入 undo/redo
块结构 | Slash 菜单 | supported | `SlashMenuController`、`SlashMenuRegistry`、`WenzSlashMenuOverlay`、`WenzRichTextEditor.slashMenuController` | `[done] ADV-007`：支持 `/heading`、`/list`、`/todo`、`/quote`、`/code`、`/table`、`/image`，键盘上下/Enter/Esc
Markdown | Markdown import/export | supported | `lib/src/codecs/markdown_codec.dart`、`docs/migration_guide.md` | 增强复杂 block 降级策略
Markdown | Markdown 快捷输入 | supported | `lib/src/core/commands/markdown_shortcut_commands.dart`、`WenzRichTextController.insertText` | 后续扩展更多规则和 widget 场景
HTML | HTML import/export | supported | `lib/src/codecs/html_codec.dart`、`docs/migration_guide.md`、`docs/import_export_strategy.md` | `[done] ADV-021`：主流 block/inline 已覆盖；HTML inline image、Wenz file/video 元数据、table `rowspan`/`colspan` 已补 round-trip 与 example demo 验收
HTML | HTML paste 解析 | supported | `ClipboardService.parseHtml`、`parse(format: html)` | 平台剪贴板 HTML flavor 由业务层桥接
剪贴板 | 纯文本复制/粘贴 | supported | `ClipboardService.parse`、`WenzRichTextController.pasteText` | 后续可插拔 paste transformer
剪贴板 | 富文本 inline/cross-block copy paste | supported | `ClipboardService`、`PasteBlocksCommand` | 补 UI 端平台覆盖
剪贴板 | Markdown paste | supported | `ClipboardService.parseMarkdown`、`parse(format: markdown)`、`WenzRichTextController.pasteMarkdown` | 后续平台 Markdown flavor 由业务层桥接
输入 | IME / DeltaTextInputClient | supported | `lib/src/input/editor_text_input_client.dart`、`docs/input_system.md` | 保持 Windows/Web 回归
输入 | 基础键盘导航和剪贴板快捷键 | supported | `EditorShortcutManager`、`WenzRichTextEditor._performShortcut`、`docs/input_system.md` | 后续扩展可配置 keymap
输入 | 样式快捷键、查找替换快捷键 | partial | keymap 已集中，查找/替换 intent 已补 | 样式快捷键待后续任务
Selection | caret、跨块 selection、双击/三击、自动滚动 | supported | `lib/src/widgets/selection_gesture_overlay.dart`、`docs/selection_engine.md` | 针对移动端 handles 后续补强
Selection | 表格单元格 selection | supported | `DocumentSelection.tableCellRange`、table commands、默认表格浮动工具 | `[done] ADV-011` 已接入多 cell 工具入口
表格 | 插入/删除行列、宽度、表头、背景、合并拆分 | supported | `lib/src/core/commands/table_commands.dart` | 稳定 API tier
表格 | 表格浮动工具条、列宽拖拽 | supported | 默认 `_TableBlockRenderer` 浮动工具条、`TableToolbarActionIntent`、列宽 resize handle | `[done] ADV-011`；行高拖拽暂不进入当前模型
媒体 | ImageBlockNode 宽高、显示尺寸、caption、alt text | supported | `ImageBlockNode.width/height/showWidth/showHeight/caption/altText`、`UpdateImageBlockCommand`、`WenzRichTextController.updateImageBlock` | `[done] ADV-012`：默认 renderer 展示 caption，语义标签优先 alt，Markdown/HTML/plain text codec 已接入
媒体 | FileBlockNode 附件元数据与默认卡片 | supported | `FileBlockNode.mimeType/downloadUrl/uploadStatus/uploadError`、`UpdateFileBlockCommand`、`WenzRichTextController.insertFile/updateFileBlock`、MediaResolver | `[done] ADV-013`：JSON round-trip、Markdown/HTML/plain text export、默认卡片显示大小/类型/状态
媒体 | MediaResolver | supported | `lib/src/widgets/media_resolver.dart`、`docs/rendering.md` | 增加上传 adapter 示例
嵌入 | 链接编辑与 URL 自动识别 | supported | `TextAttributes.url`、`SetLinkCommand`、`AutoLinkUrlsCommand`、`WenzRichTextController.autoLinkUrls`、`WenzLinkEditDialog` | `[done] ADV-014`：`insertText` 默认识别 `http(s)://`/`www.` URL，自动链接与输入合并为同一 undo step；example 工具栏复用库内链接弹窗
嵌入 | formula/mention/emoji inline embed | supported | `InsertInlineEmbedCommand`、`WenzRichTextController.insertFormula/insertMention/insertEmoji`、`InlineEmbedRenderer` | `[done] ADV-015`：默认 renderer 可读展示；JSON round-trip；Markdown/HTML 可读降级
嵌入 | inline image | partial | `WenzRichTextController.insertInlineImage`、`InlineEmbedRenderer` fallback `[img]` | 后续补媒体菜单与真实 inline image renderer
嵌入 | link preview card | reserved | `BlockEmbedNode` / `BlockRendererRegistry.registerEmbed` / `InlineEmbed` 可承载 | `[done] ADV-014` 预留链接识别；`[done] ADV-016` 已提供业务 block embed 承载，内建预览卡片仍可作为独立 renderer 推进
渲染 | BlockRendererRegistry | supported | `lib/src/widgets/block_renderer_registry.dart`、`WenzObjectBlockSurface` | `[done] ADV-016`：支持按 `BlockType` 覆盖，也支持按 `BlockEmbedNode.embedType` 注入业务 renderer；对象块 surface 保留 selection/geometry/debug 行为
渲染 | InlineEmbedRenderer | supported | `lib/src/widgets/inline_embed_renderer.dart` | inline 小组件保持 `TextSpan` 扩展；大交互内容优先用 `BlockEmbedNode` + `BlockRendererRegistry.registerEmbed`
渲染 | 虚拟化和增量 rebuild | supported | `docs/rendering.md`、`WenzRichTextController.lastChangedBlockIds` | benchmark 覆盖基础大文档与高级混合文档
工具栏 | ToolbarController 状态派生 | supported | `lib/src/controller/toolbar_controller.dart` | 增加高级功能 toolbar 项
工具栏 | 块插入菜单、表格菜单、媒体菜单 | partial | Slash 菜单基础已支持，表格浮动工具已补，图片元数据 API 已补 | `[done] ADV-007`、`[done] ADV-011`、`[done] ADV-012`；媒体专项菜单后续
文档导航 | 大纲目录 | supported | `WenzOutlineController`、`OutlineItem`、`WenzRichTextController.setBlockAnchor` | `[done] ADV-017`：从 heading 派生目录，支持按 blockId/anchor 跳转
文档导航 | block anchor / bookmark | partial | `BlockAttributes.anchor`、`SetBlockAnchorCommand` | `[done] ADV-017` 覆盖 block anchor；bookmark metadata 后续任务再设计
文档统计 | 字数、字符数、阅读时间 | supported | `WenzDocumentStatsController`、`DocumentStats` | `[done] ADV-018`：从 document 派生 block/paragraph/heading/image/word/character/embed/read-time 快照，example inspector 实时展示
保存 | dirty state、自动保存示例 | supported | `WenzAutoSaveController`、`AutoSaveState`、`AutoSaveSnapshot` | `[done] ADV-019`：派生 dirty/scheduled/saving/failed 状态，防抖调用外部持久化 adapter，example inspector 展示 Autosave
版本 | 文档快照与恢复 | supported | `DocumentVersionSnapshot`、`DocumentVersionSnapshotJsonCodec`、`WenzRichTextController.createVersionSnapshot/restoreVersionSnapshot` | `[done] ADV-020`：外部存储快照 id/时间/作者/说明，恢复走 `replaceDocument`，`baseSnapshotId` 预留 diff
评论 | 评论线程与批注侧栏 | partial | `CommentThread`、`CommentAnchor`、`RichTextDocument.comments`、`TextAttributes.commentIds`、`WenzCommentSidebar` | `[done] ADV-023`：评论线程可随 rich JSON 保存恢复，侧栏点击回调返回 `DocumentSelection`；评论命令、内联高亮交互和 composer 后续补齐
修订 | 修订模式、接受/拒绝 | partial | `RevisionChange`、`RevisionRange`、`RichTextDocument.revisions`、`TextAttributes.revisionIds`、`InsertRevisionTextCommand`、`MarkDeletionRevisionCommand`、`MarkFormatRevisionCommand`、`AcceptRevisionCommand`、`RejectRevisionCommand`、`WenzRichTextController.setRevisionMode/acceptRevision/rejectRevision` | `[done] ADV-024`：rich JSON 可保存恢复修订元数据；controller 修订模式将同块文本插入/删除/格式转为可 undo/redo 命令；跨块/表格修订、修订侧栏和可视化渲染后续补齐
协作 | remote cursor/selection adapter | supported | `WenzCollaborationAdapter`、`WenzCollaborationController`、`WenzRemoteSelectionUpdate` | `[done] ADV-025`：app-owned adapter 合约；核心不绑定 CRDT/服务端，remote selection 作为运行时状态暴露给渲染层
权限 | read/comment/edit 权限态 | supported | `WenzEditorPermission`、`EditorCommand.requiredPermission`、`WenzRichTextController.canExecute/canExecuteCommand` | `[done] ADV-026`：controller 在命令进入 executor 前禁用无权限命令；toolbar edit enable 态和 undo/redo 跟随权限；comment-only 插件命令可覆写 requiredPermission
插件 | CommandRegistry 和 middleware | supported | `WenzRichTextPlugin`、`WenzPluginBundle`、`WenzPluginContext`、`CommandRegistry`、`CommandMiddleware` | `[done] ADV-027`：统一插件安装入口；命令仍走 `WenzRichTextController.executeCommand` / undo/redo / schema normalize
插件 | renderer 插件 | supported | `BlockRendererRegistry`、`InlineEmbedRendererRegistry`、`InlineEmbedRendererCallback` | `[done] ADV-027`：block renderer 与 inline embed renderer 都可通过插件 bundle 注册；宿主仍负责把 registry 传入 editor
插件 | paste transformer / slash item / toolbar item | supported | `ClipboardPasteTransformer`、`SlashMenuRegistry`、`WenzToolbarItemRegistry` | `[done] ADV-027`：paste transformer 先于内建 parser 运行；toolbar item 为 headless descriptor，具体 UI 由业务渲染
导出 | Plain text / Rich JSON / Legacy JSON | supported | `lib/src/codecs/` | 持续兼容
导入导出 | Markdown / HTML | supported | `lib/src/codecs/markdown_codec.dart`、`lib/src/codecs/html_codec.dart`、`docs/import_export_strategy.md` | `[done] ADV-021`：主流 block/inline 样式、demo、自动化矩阵已覆盖；Markdown file/merged table 仍按格式边界降级
导出 | PDF export | partial | `lib/src/exporters/document_conversion_plan.dart`、`docs/import_export_strategy.md` | `[done] ADV-022`：仅提供平台/依赖/降级边界与 app-owned adapter 合约；核心不引 PDF/print 依赖
导出 | DOCX import/export | partial | `lib/src/exporters/document_conversion_plan.dart`、`docs/import_export_strategy.md` | `[done] ADV-022`：仅提供平台/依赖/降级边界与 app-owned adapter 合约；核心不引 OOXML/DOCX 依赖
质量 | core/controller/widget/codec tests | supported | `test/` | 新功能必须补测试
质量 | Golden tests | supported | `test/widgets/goldens/` | `[done] ADV-028`：覆盖基础块、合并表格、selection/caret、高级块 + inline embed
质量 | benchmark | supported | `test/benchmarks/editor_benchmarks.dart` | `[done] ADV-028`：含 1k blocks、10k runs、50×20 table、scroll remount、高级混合文档
发布 | README / CHANGELOG / release checklist / migration guide | supported | `README.md`、`CHANGELOG.md`、`docs/release_checklist.md`、`docs/migration_guide.md` | `[done] ADV-030`：覆盖安装、初始化、命令、序列化、扩展点、FAQ、发布门禁与已知 alpha 边界
可访问性 | 语义节点、键盘可达、高对比度 | supported | `WenzRichTextEditorAccessibility`、编辑器/块/table `Semantics`、高对比焦点框 | `[done] ADV-029`：编辑器级 label/hint/readOnly 语义、focusable text field 状态、高对比聚焦边框已接入

## Schema 影响矩阵

功能族 | 是否需要 schema 变更 | 说明
--- | --- | ---
Schema version / migration 策略 | 已完成 | `[done] ADV-002` 固定当前 rich JSON v2 基线、bump 规则、后续 feature impact 与 future v3 候选；详见 `docs/schema_migration_impact.md`。
Markdown 快捷输入 | 否 | 触发后转为现有 block/style 命令。
快捷键集中管理 | 否 | 输入层重构，不改变文档结构。
粘贴 pipeline | 否/少量 | 默认复用现有 codecs；若支持更多 HTML 样式，需要确认 attrs 白名单。
查找替换 | 否 | 只读查询 + 文本替换命令。
Slash 菜单 | 否 | 菜单项最终转为现有或新增命令。
列表增强 | 否/可选 | `[done] ADV-008` 继续复用 `listType/checked/indent`，未新增 schema；复杂编号样式后续才可能需要新 attrs。
图片 caption/alt | 已完成 | `[done] ADV-012`：`ImageBlockNode` 增加 `caption`/`altText`，JSON 读取兼容旧 `alt` key；Markdown 图片 title 和 HTML figure 可 round-trip。
文件附件体验 | 已完成 | `[done] ADV-013`：`FileBlockNode` 保留 `assetId/name/size/file` 兼容字段，并新增 `mimeType/downloadUrl/uploadStatus/uploadError`；失败重试由业务 resolver/toolbar 基于状态接入。
链接编辑/自动 URL | 已完成/无新增 schema | `[done] ADV-014` 复用 `TextAttributes.url`；自动识别只写 run attribute，链接预览卡片仍作为 custom block/embed 或后续内建 schema 扩展。
链接预览卡片 | 是/可选 | 可作为 custom block/embed；若内建则需新增 block 或 attrs。
mention/formula/emoji | 已完成/无新增 schema | `[done] ADV-015` 复用 `InlineEmbed`，约定 `formula.text/latex/value`、`mention.id/label`、`emoji.emoji/shortName` 数据字段；Markdown/HTML 仅可读降级，不还原为 embed。
大纲目录 | 否 | 从 heading 派生。
anchor/bookmark | 已完成/可选 | `[done] ADV-017` 已提供 `BlockAttributes.anchor` 作为 block-level anchor；bookmark/document metadata 后续再扩展。
文档统计 | 已完成/无新增 schema | `[done] ADV-018` 由 `WenzDocumentStatsController` 从 document 派生，不写入 schema；inline embed 按 Markdown/HTML 可读降级字段参与统计。
自动保存 dirty state | 已完成/无新增 schema | `[done] ADV-019` 由 `WenzAutoSaveController` 比较 rich JSON 快照派生，草稿 JSON 交给外部 adapter 保存。
版本快照 | 已完成/外部 | `[done] ADV-020` 外部存储 `DocumentVersionSnapshot`，核心提供 JSON codec 与 controller 创建/恢复 helper；不新增正文 `versions` schema。
评论线程 | 已完成 additive schema | `[done] ADV-023` 新增可选顶层 `comments` 与 inline `commentIds`；旧文档缺省为空，无需 migration。
修订模式 | 已完成 additive schema | `[done] ADV-024` 新增可选顶层 `revisions` 与 inline `revisionIds`，旧文档缺省为空；Markdown/HTML/plain text 不导出修订元数据。
协作 adapter | 已完成/外部 | `[done] ADV-025` 仅提供 adapter、local change event、remote document update 与 remote selection/presence 数据结构；不写入文档 JSON，评论/修订另算。
权限态 | 否 | `[done] ADV-026`：controller runtime 策略，不写入文档正文。
PDF/DOCX | 否/外部 | `[done] ADV-022`：`WenzDocumentConversionPlan` 只描述 app-owned adapter 边界，不污染核心模型。

## 推荐下一步

第一批执行任务状态：

1. \`\[done\] ADV-001\`：建立进阶功能矩阵。

1. \`\[done\] ADV-002\`：基于本文档补一份 schema 影响与 migration 方案。

1. \`\[done\] ADV-003\`：实现 Markdown 快捷输入引擎。

1. \`\[done\] ADV-004\`：把 keyboard shortcuts 从 widget 里抽成可测的 shortcut manager。

1. \`\[done\] ADV-005\`：统一粘贴 pipeline，并接入 HTML/Markdown paste。

1. \`\[done\] ADV-006\`：实现查找替换 controller 和基础 UI。

状态收敛：计划任务表已补齐 \`ADV-003\`、\`ADV-004\`、\`ADV-005\` 的 \`\[done\]\` 标记；\`ADV-001\` 至 \`ADV-030\` 均已完成并可进入发布前回归。