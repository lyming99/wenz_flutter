# wenz_richtext

`wenz_richtext` 是一个自研 Flutter 富文本编辑器 package，包含文档模型、命令体系、历史记录、输入桥、渲染组件、导入导出和扩展点。当前版本面向内部 alpha / 业务接入验证。

## 安装

Flutter SDK 需满足 `>=3.22.0`，Dart SDK 需满足 `>=3.3.4`。在本仓库或 monorepo 内部接入时使用 path dependency：

```yaml
dependencies:
  wenz_richtext:
    path: ../wenz_richtext
```

发布到包仓库后可切换为版本依赖，例如 `wenz_richtext: ^0.1.0`。

## 快速开始

`WenzEditorConfiguration` + `WenzEditorBootstrap` 是标准对外接口（tier 1 推荐入口）：零配置即可创建一个可用编辑器，并通过配置注入媒体解析、自定义 renderer、slash / toolbar item、插件、快捷键与回调。README 内的首要 API 入口见 [接口文档](#接口文档)，完整契约见 [`docs/integration_guide.md`](docs/integration_guide.md)，更完整的接入样例（CRM embed + 自动保存 + slash 菜单 + 回调事件）见 `example/lib/main.dart`。

```dart
import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  // 装配一次：创建 controller + 各注册表 + 派生控制器 + 插件。
  late final WenzEditorBootstrap bootstrap =
      WenzEditorBootstrap.create(WenzEditorConfiguration());

  @override
  void dispose() {
    bootstrap.dispose(); // 按依赖逆序释放派生控制器与 controller。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: bootstrap.buildEditor(autofocus: true),
    );
  }
}
```

数据读写、版本快照、权限（read / comment / edit）与回调都收敛在门面上：

```dart
bootstrap.loadJson(source);
final html = bootstrap.toHtml();
final snapshot = bootstrap.createVersionSnapshot(id: 'v1');
```

需要注入业务扩展时，把 media resolver / 自定义 block embed renderer / slash item / 插件 / 快捷键 / 回调填进 `WenzEditorConfiguration` 即可，无需自行拼装 6+ 个 registry：

```dart
final bootstrap = WenzEditorBootstrap.create(
  WenzEditorConfiguration(
    permission: WenzEditorPermission.edit,
    mediaResolver: myMediaResolver,
    blockEmbedRenderers: {'crm-card': myCrmCardBuilder},
    slashMenuItems: mySlashItems,
    plugins: [myPlugin],
    onChanged: (doc) => saveDraft(doc),
  ),
);
```

后续接口文档会先给出 README 内的业务接入快速参考；常用能力章节仍保留可直接使用的高级扩展点：`WenzRichTextController`、`WenzRichTextEditor` 与各 registry / plugin 契约保持 tier 2 不变，门面内部复用的就是同一套装配逻辑。

## 接口文档

本节是业务接入方在 README 内完成首轮 API 选型的快速参考：优先说明推荐门面入口，再索引 typed API、高级扩展点、实验能力和不承诺稳定的 internal 边界。完整字段、方法和错误契约仍以 [`docs/api_reference.md`](docs/api_reference.md) 与 [`docs/integration_guide.md`](docs/integration_guide.md) 为准；public surface 的稳定性分层与 [`lib/wenz_richtext.dart`](lib/wenz_richtext.dart) 导出注释保持一致。

### Public surface 分层

| 层级 | 稳定性定位 | 适合接入的 API | 使用边界 |
| --- | --- | --- | --- |
| Tier 1 推荐入口 | Stable core，业务默认入口 | `WenzEditorConfiguration` + `WenzEditorBootstrap`、`RichTextDocument` / `BlockNode` / `InlineNode` / `TableModel`、`DocumentPosition` / `DocumentSelection`、`WenzRichTextController`、核心文本 / 块 / 样式 / 选区命令、`HistoryManager`、`ClipboardService` | 新业务优先走门面装配 editor、读写数据、接回调并在页面销毁时 `dispose()`；需要直接控制文档时再使用 controller typed helper。 |
| Tier 2 高级扩展点 | Stabilising，供深度定制 | `WenzRichTextEditor`、rich / legacy JSON、`PlainTextCodec`、`MarkdownCodec`、`HtmlCodec`、`CommandRegistry` / `CommandMiddleware`、`WenzRichTextPlugin`、`BlockRendererRegistry`、`InlineEmbedRenderer`、`MediaResolver`、`ToolbarController`、`SlashMenuController`、查找替换、outline、统计和自动保存控制器 | 推荐通过 `WenzEditorConfiguration` 注入 renderer、media resolver、slash / toolbar item、插件、快捷键和回调；只有宿主需要接管装配细节时才直接组合 registry 与 widget。 |
| Tier 3 实验能力 | Experimental，可能继续演进 | 表格细粒度命令、表格单元格编辑契约、`VideoBlockNode`、`FileBlockNode`、部分富媒体 / 业务 block embed 能力 | 可以用于 alpha 验证，但业务侧应保留适配层；低层表格选择、上传重试和真实播放器仍由业务或后续版本补齐。 |
| Internal 边界 | 不承诺稳定 | 未从 `package:wenz_richtext/wenz_richtext.dart` 导出的 `src/` 内部实现、默认 widget 私有状态、测试 / 脚本 helper、渲染实现细节 | 不建议业务直接依赖；如需扩展，请转化为配置、插件、renderer、codec、命令或 adapter 接入点。 |

### README 接口阅读路径

1. **首选门面**：用 `WenzEditorConfiguration` 描述业务能力，用 `WenzEditorBootstrap.create` 一次性装配 editor、controller、派生控制器、插件和默认扩展。
2. **数据与命令**：通过 bootstrap 或 `WenzRichTextController` 读写 rich JSON、legacy JSON、Markdown、HTML、plain text，并使用 typed helper 执行文本、样式、块、媒体和历史命令。
3. **业务扩展**：把 block / inline renderer、`MediaResolver`、slash item、toolbar item、插件、快捷键、粘贴转换和生命周期回调放进配置；冲突时以宿主配置覆盖插件默认值为原则。
4. **高级控制器**：toolbar、slash、find / replace、outline、stats、autosave 等派生控制器由门面创建并归属门面释放；手动装配时需要自行维护创建顺序与 `dispose()` 顺序。
5. **详细契约**：字段清单、异常、迁移和完整 API 表继续查看 [`docs/api_reference.md`](docs/api_reference.md)；标准接入流程、权限与 internal 稳定边界继续查看 [`docs/integration_guide.md`](docs/integration_guide.md)。

### 门面与配置接口

`WenzEditorConfiguration` 是无副作用的声明式配置：构造时不创建 controller、不持有 `BuildContext`、不构建 widget。所有字段都有安全默认值，`WenzEditorConfiguration()` 可直接运行，默认 `permission` 为 `WenzEditorPermission.edit`，slash / find / outline / stats / toolbar 派生控制器默认启用，autosave 默认关闭。

| 字段分组 | 字段 | 说明 |
| --- | --- | --- |
| 初始文档与选区 | `document`、`selection` | 透传给 `WenzRichTextController`；`document == null` 时使用空文档，`selection == null` 时不强制设置初始选区。 |
| 权限 | `permission` | 命令层权限闸门，支持 read / comment / edit；UI 的 `readOnly` 只影响编辑器表现，不能替代命令层权限。 |
| Codec 与数据迁移 | `richTextJsonCodec` | 用于 rich JSON 序列化和 schema 迁移；为 `null` 时使用默认 `RichTextJsonCodec()`。Markdown、HTML、plain text 读写由 bootstrap 代理到 controller。 |
| 媒体解析与渲染 | `mediaResolver`、`blockRenderers`、`blockEmbedRenderers`、`inlineEmbedRenderers`、`accessibility` | 媒体 resolver 负责图片 / 文件 / 视频资源解析；renderer 在默认渲染器之后注册，适合覆盖内置 block 或接入业务 embed；accessibility 透传给 editor。 |
| 菜单、工具栏与插件 | `slashMenuItems`、`toolbarItems`、`plugins` | 插件先安装，宿主配置后注册；同 id / 同类型冲突时宿主 renderer、slash item、toolbar item 覆盖插件贡献。 |
| 粘贴与快捷键 | `pasteTransformers`、`shortcutConfiguration` | 粘贴转换与插件贡献进入同一 pipeline；快捷键在 build 阶段按“插件片段先、宿主配置后”合并，因此宿主快捷键覆盖插件默认值。 |
| 回调 | `onMentionTap`、`onChanged`、`onSelectionChanged`、`onCommandExecuted` | mention 点击回调透传到 editor；文档、选区和命令回调在 controller 通知 listeners 前同步触发，适合记录状态、埋点或触发宿主保存。 |
| 功能开关 | `enableSlashMenu`、`enableFindReplace`、`enableOutline`、`enableStats`、`enableToolbar` | 只决定 bootstrap 是否创建对应派生控制器；关闭后对应 `bootstrap.*Controller` 为 `null`，业务不要再强制取 `!`。 |
| 自动保存 | `enableAutosave`、`onAutosave`、`autosaveDebounce` | autosave 是 opt-in；只有 `enableAutosave: true` 且提供 `onAutosave` 时才会创建 `WenzAutoSaveController`，否则 `autosaveController == null`。 |

`WenzEditorBootstrap.create` 负责把配置变成可运行实例，装配顺序固定：

1. 创建 `ClipboardService` 与 `WenzRichTextController`，透传初始文档、选区、权限、rich JSON codec 和 media resolver，并在任何变更发生前挂载宿主回调。
2. 创建 renderer / inline embed / slash / toolbar 注册表，先安装默认 block renderer 与默认 slash item，保证零配置 editor 可直接运行。
3. 通过 `WenzPluginContext` 安装 `WenzRichTextPlugin` / `WenzPluginBundle`，收集插件 renderer、slash item、toolbar item、快捷键和粘贴转换。
4. 再注册宿主提供的 renderer、slash item、toolbar item 和快捷键配置；宿主覆盖插件，插件覆盖默认值，默认能力只作为 fallback。
5. 按 `enable*` 开关创建派生控制器；outline 先于 find / replace 创建，autosave 只有在开关和 `onAutosave` 同时存在时创建。
6. `buildEditor(...)` 返回普通 `WenzRichTextEditor`，自动注入 controller、注册表、派生控制器、mention 回调、accessibility 和合并后的快捷键；`dispose()` 按 toolbar → stats → autosave → find / replace → outline → slash → controller 的逆依赖顺序释放，重复调用无副作用。

最小门面装配可直接放进页面 `State`，与快速开始示例一致：

```dart
late final WenzEditorBootstrap _bootstrap =
    WenzEditorBootstrap.create(const WenzEditorConfiguration());

@override
void dispose() {
  _bootstrap.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: _bootstrap.buildEditor(autofocus: true),
  );
}
```

带业务扩展的配置建议仍从门面进入，避免手动拼装多个 registry：

```dart
late final WenzEditorBootstrap _bootstrap = WenzEditorBootstrap.create(
  WenzEditorConfiguration(
    document: initialDocument,
    selection: initialSelection,
    permission: WenzEditorPermission.edit,
    richTextJsonCodec: RichTextJsonCodec(migrations: migrations),
    mediaResolver: _mediaResolver,
    blockEmbedRenderers: <String, BlockRendererBuilder>{
      'crm-card': (_, renderContext) {
        final block = renderContext.block as BlockEmbedNode;
        return WenzObjectBlockSurface(
          renderContext: renderContext,
          child: CrmCardView(data: block.data),
        );
      },
    },
    slashMenuItems: crmSlashItems,
    toolbarItems: crmToolbarItems,
    plugins: <WenzRichTextPlugin>[auditPlugin],
    pasteTransformers: <ClipboardPasteTransformer>[crmPasteTransformer],
    shortcutConfiguration: crmShortcuts,
    onMentionTap: openMemberCard,
    onChanged: markDirty,
    onSelectionChanged: recordSelection,
    onCommandExecuted: logCommand,
    enableFindReplace: false,
    enableOutline: true,
    enableAutosave: true,
    onAutosave: draftAdapter.save,
    autosaveDebounce: const Duration(milliseconds: 800),
  ),
);

late final WenzRichTextController _controller = _bootstrap.controller;
late final ToolbarController? _toolbar = _bootstrap.toolbarController;
late final WenzAutoSaveController? _autosave = _bootstrap.autosaveController;
```

数据读写优先使用 bootstrap 代理；需要命令级操作时再取 `_bootstrap.controller`：

```dart
_bootstrap.loadJson(source);
final result = _bootstrap.tryLoadJson(source, legacy: true);
if (result.ok) {
  final richJson = _bootstrap.toJson();
  final markdown = _bootstrap.toMarkdown();
  final html = _bootstrap.toHtml();
  final plainText = _bootstrap.toPlainText();
  final snapshot = _bootstrap.createVersionSnapshot(id: 'draft-v1');
  saveDocument(richJson, markdown, html, plainText, snapshot);
}

_bootstrap.loadMarkdown(markdownSource);
_bootstrap.loadHtml(htmlSource);
final snapshotToRestore = loadSnapshot();
_bootstrap.restoreVersionSnapshot(snapshotToRestore);
```

### 控制器、模型与命令接口

`WenzRichTextController` 是 tier 1 的文档状态与命令执行入口。业务优先通过 `WenzEditorBootstrap` 读写数据；需要即时编辑、工具栏联动、插件命令或自定义 UI 时，再使用 controller 的 typed helper。完整方法签名和参数细节见 [`docs/api_reference.md`](docs/api_reference.md)，README 只保留业务最常用的入口索引。

| 模型 | 用途 | 业务边界 |
| --- | --- | --- |
| `RichTextDocument` | 文档根对象，包含 `version`、`blocks`、`comments`、`revisions`，并提供 `plainText` 汇总。 | 作为 rich JSON 的 canonical model；替换整篇文档优先走 `loadJson` / `replaceDocument`，避免业务直接改内部 list 后绕过通知。 |
| `BlockNode` | 顶层 block 抽象，常见实现包括 `TextBlockNode`、`CodeBlockNode`、`ImageBlockNode`、`TableBlockNode`、`DividerBlockNode`、`VideoBlockNode`、`FileBlockNode`、`BlockEmbedNode`、`CalloutBlockNode`。 | `TextBlockNode` / `CodeBlockNode` / 基础媒体属于稳定接入面；表格细粒度能力与部分富媒体 block 仍按 tier 3 谨慎封装。 |
| `InlineNode` | 行内内容抽象，主要是 `TextRun` 与 `InlineEmbed`。 | formula、mention、emoji、inline image 等语义内容通过 inline embed 表达，默认按一个逻辑字符参与选区和删除。 |
| `TextAttributes` | 行内样式：粗体、斜体、下划线、删除线、颜色、背景色、字号、字体、链接、批注和修订 id。 | 推荐通过 `formatText`、`setTextColor`、`setLink` 等 helper 修改，保证历史记录、选区和回调一致。 |
| `BlockAttributes` | 块级属性：标题层级、缩进、对齐、列表类型、todo 勾选、引用、锚点和子备注。 | 推荐通过 `setBlockType`、`indent`、`toggleTodo`、`toggleQuote`、`setAlignment` 等 helper 修改。 |
| `DocumentPosition` / `DocumentSelection` | 光标与选区模型，使用 `PositionPath` 定位 block text、code、object 或 table cell。 | `DocumentSelection.isCollapsed` 判断光标态；跨表格选择使用 `TableCellRange` 相关入口，避免只按纯文本 offset 推断。 |
| `TableModel` / `TableCellNode` | 表格模型，记录行列、单元格内嵌 block、合并跨度、表头、背景色、列宽和列对齐。 | 表格命令族仍是实验能力；业务工具栏可调用 typed helper，但建议把复杂表格交互隔离在适配层。 |
| 评论模型 | `CommentAnchor`、`CommentEntry`、`CommentThread` 表达批注锚点、消息和 open / resolved 状态。 | 核心模型保存数据与锚点，评论侧栏 UI 和业务权限策略由宿主决定。 |
| 修订模型 | `RevisionRange`、`RevisionChange` 表达插入、删除、格式变更及 pending / accepted / rejected 状态。 | `setRevisionMode` 与修订命令可用于审阅模式；业务仍应保存作者、时间和审阅流元数据。 |
| 版本快照 | `DocumentVersionSnapshot` 保存 `id`、完整 `document`、创建时间、作者、描述、基线快照和 metadata。 | 用于业务自有版本历史；创建和恢复优先使用 `createVersionSnapshot` / `restoreVersionSnapshot`。 |

Controller helper 按业务场景使用即可，不建议在 README 逐方法机械展开：

| 场景 | 常用入口 | 说明 |
| --- | --- | --- |
| 文本、选区与剪贴板 | `insertText`、`deleteSelection`、`deleteBackward`、`deleteForward`、`enter`、`setSelection`、`selectAll`、`copySelection`、`cutSelection`、`pasteText`、`pasteMarkdown`、`pasteHtml` | 这些入口统一走 command pipeline，保留撤销/重做、回调和权限校验。 |
| 光标移动 | `moveCaretBackward`、`moveCaretForward`、`moveCaretByWord`、`moveCaretVertical`、`moveCaretToBlockBoundary`、`moveCaretToDocumentBoundary`、`moveTableCell`、`moveTableCellVertical` | 用于自定义快捷键或键盘导航；表格移动会遵守 table cell 位置语义。 |
| 内联样式与语义 | `formatText`、`setTextColor`、`clearTextColor`、`clearStyle`、`setLink`、`autoLinkUrls`、`toggleRemark` | 覆盖普通富文本样式、链接和批注标记；批注 / 修订 id 保存在 `TextAttributes`。 |
| 块类型、列表与代码块 | `setBlockType`、`setAlignment`、`indent`、`outdent`、`toggleTodo`、`setTodoChecked`、`toggleQuote`、`setCodeLanguage`、`indentCodeBlock`、`insertCallout`、`updateCalloutBlock` | 覆盖标题、段落、列表、todo、引用、代码块和 callout 等常见编辑能力。 |
| 块结构 | `insertBlocks`、`replaceBlocks`、`moveBlock`、`setBlockAnchor` | 用于批量插入、替换、排序和锚点更新；拖拽排序和 block 行操作也应落到这些命令层能力。 |
| 表格 | `insertTable`、`insertTableRow`、`insertTableColumn`、`deleteTableRow`、`deleteTableColumn`、`setTableColumnAlignment`、`setTableColumnWidth`、`setTableCellHeader`、`setTableCellBackground`、`mergeTableCells`、`splitTableCell`、`selectTableRow`、`selectTableColumn`、`selectTable`、`insertTableCellText`、`deleteTableCellText`、`formatTableCellText` | tier 3 实验能力；工具栏可先接 typed helper，复杂合并、列宽和单元格编辑要保留版本适配空间。 |
| 图片、文件、视频与业务 embed | `insertImage`、`updateImageBlock`、`insertVideo`、`updateVideoBlock`、`deleteVideoBlock`、`insertFile`、`updateFileBlock`、`insertBlockEmbed`、`insertInlineImage` | 核心只写模型和默认占位；`ImageBlockNode.file` 可保存本地路径/URI；真实文件选择、上传、下载、播放器和业务卡片渲染通过宿主 UI、`MediaResolver` / renderer / adapter 注入。 |
| 公式、mention 与 emoji | `insertFormula`、`updateInlineFormula`、`updateBlockFormula`、`insertMention`、`insertEmoji` | 公式可行内或块级表达；mention 的 `id` / `label` / `data` 是点击回调与业务资料页的交互契约。 |
| 历史、权限与安全执行 | `undo`、`redo`、`execute`、`canExecute`、`executeCommand`、`canExecuteCommand`、`tryExecuteCommand` | typed helper 最终都会走 `execute`；权限不足返回 blocked `ChangeSet` 且不改文档；插件命令优先用 `canExecuteCommand` / `tryExecuteCommand` 做无异常分支。 |
| 修订与版本 | `setRevisionMode`、`insertRevisionText`、`markDeletionRevision`、`markFormatRevision`、`acceptRevision`、`rejectRevision`、`createVersionSnapshot`、`restoreVersionSnapshot` | 审阅流和版本历史由业务持久化，controller 负责把修订和快照应用到当前文档。 |

序列化入口按保真度从高到低选择：

| 格式 | 读写入口 | 降级与错误处理 |
| --- | --- | --- |
| Rich JSON | `toJson()`、`loadJson(source)`、`tryLoadJson(source)` | 首选持久化格式，保留模型、属性、评论、修订和业务 embed 数据；JSON 结构错误会抛 `DocumentDecodeException`，UI / 打开文件等 no-throw 路径用 `tryLoadJson` 读取 `TryLoadResult.ok`、`document`、`error`。 |
| Legacy JSON | `loadJson(source, legacy: true)`、`tryLoadJson(source, legacy: true)` | 用于旧 `wenz_editor` 数据导入；导出仍建议写 rich JSON，并在业务层记录迁移版本。 |
| Markdown | `toMarkdown()`、`loadMarkdown(source)`、`tryLoadMarkdown(source)` | 适合外部粘贴、轻量导入导出和文本协作；复杂媒体、评论、修订和业务 embed 会按导入导出策略降级为文本、链接或占位信息。 |
| HTML | `toHtml()`、`loadHtml(source)`、`tryLoadHtml(source)` | 适合 Web 内容互转；只保留当前模型支持的 block / inline 语义，未知标签、复杂样式和业务私有结构需要业务自定义转换策略。 |
| Plain text | `toPlainText()`、`pasteText(raw)` | 只保留文本内容和换行；没有独立 `loadPlainText` 门面，整篇纯文本导入可由业务构造 `RichTextDocument` 后 `replaceDocument`，或按光标位置使用 `pasteText`。 |

命令注册表用于插件和宿主自定义命令：`executeCommand(name, args)` 会在命令名未注册时抛 `UnknownCommandException`；`canExecuteCommand` 与 `tryExecuteCommand` 会把未知命令或参数解码失败转换为 `false`，适合 toolbar、slash menu、快捷键等 UI 先探测再执行。更细的命令参数和 schema 说明继续查看 [`docs/api_reference.md`](docs/api_reference.md) 与 [`docs/schema_and_commands.md`](docs/schema_and_commands.md)。

### 扩展点与派生控制器接口

扩展点属于 tier 2 稳定化能力，推荐优先通过 `WenzEditorConfiguration` 注入；只有宿主需要完全手动装配时，才直接创建 registry、controller 和 widget。bootstrap 的合并顺序固定为“默认能力 → 插件贡献 → 宿主配置”，因此同 id / 同类型冲突时宿主 renderer、slash item、toolbar item 和快捷键覆盖插件，插件再覆盖默认值；粘贴转换是顺序 pipeline，返回 `null` 才会交给下一个 transformer 或内置解析器。

| 扩展点 | 推荐配置字段 | 用途与边界 |
| --- | --- | --- |
| `BlockRendererRegistry` / `BlockRendererBuilder` | `blockRenderers`、`blockEmbedRenderers` | 覆盖内置 `BlockType` renderer，或按 `BlockEmbedNode.embedType` 渲染 CRM 卡片、审批单等业务块；builder 通过 `BlockRenderContext` 读取 block、选区、`canEdit`、媒体 resolver、inline renderer 和表格 / 对象块回调。 |
| `InlineEmbedRenderer` / `InlineEmbedRendererRegistry` | `inlineEmbedRenderers` | 为 formula、mention、emoji、inline image 或业务 chip 返回 `InlineSpan`；返回 `null` 时走内置 fallback。自定义 mention span 如需保留默认点击事件，可复用 `WenzMentionTapHandler`。 |
| `MediaResolver` | `mediaResolver` | 为 `ImageBlockNode`、`VideoBlockNode`、`FileBlockNode` 返回真实预览、播放器或下载入口；返回 `null` 时使用内置占位。上传重试、鉴权、播放器依赖仍由业务层负责。 |
| `WenzRichTextPlugin` / `WenzPluginBundle` | `plugins` | 插件可通过 `WenzPluginContext` 注册命令、middleware、renderer、slash item、toolbar item、快捷键和粘贴转换；插件不应假设自己优先级高于宿主配置。 |
| `CommandRegistry` / `CommandDescriptor` | 插件 `context.registerCommand(...)` 或 controller `registry` | 为插件或宿主自定义命令提供命名入口；UI 调用前优先使用 `canExecuteCommand`，执行时优先用 `tryExecuteCommand` 处理未知命令和参数解码失败。 |
| `CommandMiddleware` | 插件 `context.addMiddleware(...)` | `before` 可短路命令并返回自定义 `ChangeSet`，`after` 可观察执行结果；适合审计、埋点、业务限制，避免在 middleware 中直接改 UI 状态。 |
| `ClipboardPasteTransformer` | `pasteTransformers` 或插件 `context.registerPasteTransformer(...)` | 在内置 rich / plain / Markdown / HTML 解析前识别业务剪贴板格式；返回 `ClipboardPaste` 即短路，返回 `null` 则继续后续解析。 |
| `EditorShortcutConfiguration` | `shortcutConfiguration` 或插件 shortcut fragments | 通过 handled / ignored / passThrough 绑定快捷键；插件片段先合并，宿主配置最后合并，所以宿主快捷键覆盖插件默认值。 |

派生控制器由 `WenzEditorBootstrap.create` 按开关创建，并由 `bootstrap.dispose()` 统一释放；手动装配时才需要业务自行持有并按逆依赖顺序释放。

| 控制器 | 创建来源 | 用途 | dispose 归属 |
| --- | --- | --- | --- |
| `ToolbarController` | `enableToolbar`，读取 `bootstrap.toolbarController` | 根据当前 selection 和权限派生 `ToolbarState`，提供 active / enabled 状态和 toolbar 操作 helper。 | bootstrap 释放；关闭开关时为 `null`。 |
| `SlashMenuController` / `SlashMenuRegistry` | `enableSlashMenu`，读取 `bootstrap.slashMenuController` | 监听 `/query` 触发、筛选 registry item、移动高亮并执行 item action；registry 先有默认 item，再合并插件和宿主 item。 | bootstrap 释放；overlay 由 `buildEditor` 注入。 |
| `WenzFindReplaceController` | `enableFindReplace`，读取 `bootstrap.findReplaceController` | 管理查找、替换、当前 match 与 match 列表；可配合 outline 展开折叠标题以露出命中内容。 | bootstrap 释放。 |
| `WenzOutlineController` | `enableOutline`，读取 `bootstrap.outlineController` | 从 heading block 派生 outline tree，管理折叠、展开和可见 block 投影。 | bootstrap 释放，且先于 find / replace 创建。 |
| `WenzDocumentStatsController` | `enableStats`，读取 `bootstrap.statsController` | 派生 block、段落、标题、图片、字数、字符数、inline embed 和阅读时间统计。 | bootstrap 释放。 |
| `WenzAutoSaveController` | `enableAutosave && onAutosave != null`，读取 `bootstrap.autosaveController` | 跟踪 dirty / scheduled / saving / failed 状态，按 debounce 调用宿主 `onAutosave`，也可 `saveNow` 或 `markClean`。 | bootstrap 释放；缺少 `onAutosave` 时不会创建。 |

扩展示例建议从配置进入，下面是精简伪代码，展示 block embed、inline embed、media resolver、slash item、toolbar item 和插件注册的组合方式：

```dart
final crmBlockRenderers = <String, BlockRendererBuilder>{
  'crm-card': (context, renderContext) {
    final block = renderContext.block as BlockEmbedNode;
    return WenzObjectBlockSurface(
      renderContext: renderContext,
      child: CrmCardView(data: block.data),
    );
  },
};

final inlineRenderers = <String, InlineEmbedSpanBuilder>{
  'status-chip': (context, embed, textStyle) {
    final label = embed.data['label']?.toString() ?? 'status';
    return TextSpan(text: '[$label]', style: textStyle);
  },
};

class AppMediaResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode) {
      final source = block.file.isNotEmpty ? block.file : block.assetId;
      if (source.startsWith('https://')) {
        return Image.network(source);
      }
    }
    if (block is VideoBlockNode && block.effectivePlaybackUrl.isNotEmpty) {
      return BusinessVideoPlayer(url: block.effectivePlaybackUrl);
    }
    return null; // 交回内置占位 renderer。
  }
}

final crmSlashItem = SlashMenuItem(
  id: 'crm.card',
  title: 'CRM 卡片',
  icon: '💼',
  keywords: const <String>['crm', 'customer'],
  action: (editor, context) {
    editor.insertBlockEmbed(
      blockId: newBlockId('crm'),
      embedType: 'crm-card',
      data: <String, Object?>{'recordId': selectedRecordId},
      fallbackText: 'CRM card',
    );
  },
);

final crmToolbarItem = WenzToolbarItem(
  id: 'crm.card',
  title: 'CRM 卡片',
  icon: '💼',
  isEnabled: (state) => state.canSetBlockType,
  action: (editor, state) => editor.insertBlockEmbed(
    blockId: newBlockId('crm'),
    embedType: 'crm-card',
    data: <String, Object?>{'recordId': selectedRecordId},
    fallbackText: 'CRM card',
  ),
);

class CrmPlugin extends WenzRichTextPlugin {
  const CrmPlugin();

  @override
  String get id => 'crm';

  @override
  void install(WenzPluginContext context) {
    context.registerSlashMenuItem(crmSlashItem);
    context.registerToolbarItem(crmToolbarItem);
    context.registerPasteTransformer(crmPasteTransformer);
    context.registerShortcutConfiguration(crmShortcutConfiguration);
    context.addMiddleware(CrmAuditMiddleware());
  }
}

final bootstrap = WenzEditorBootstrap.create(
  WenzEditorConfiguration(
    mediaResolver: AppMediaResolver(),
    blockEmbedRenderers: crmBlockRenderers,
    inlineEmbedRenderers: inlineRenderers,
    slashMenuItems: <SlashMenuItem>[crmSlashItem],
    toolbarItems: <WenzToolbarItem>[crmToolbarItem],
    plugins: const <WenzRichTextPlugin>[CrmPlugin()],
    shortcutConfiguration: crmShortcutConfiguration,
    pasteTransformers: <ClipboardPasteTransformer>[crmPasteTransformer],
  ),
);
```

权限必须以 `WenzEditorConfiguration.permission` 为准：`read < comment < edit`，命令声明自己的 `requiredPermission`，controller 的 `execute` / `canExecute` 会统一拦截。`read` 只允许读取类命令，`comment` 可运行批注级命令，文本、块、表格、图片 / 文件 / 视频等写入或媒体插入默认仍需要 `edit`。`ToolbarState` 的 `can*`、`ToolbarController.canInsertImage`、`ToolbarController.canInsertVideo`、slash 菜单展示与媒体插入 UI 会随 readOnly / `canEdit` 降级，但这只是用户体验层；自定义 toolbar、slash item、快捷键、插件命令和媒体插入 action 仍必须走 controller 命令入口，让权限闸门最终兜底。不要只隐藏按钮或禁用 UI 来替代命令层权限。

## 常用能力

本章节保留专题能力的行为说明，不再重复展开接口契约；配置字段、生命周期和扩展边界以前文 [接口文档](#接口文档) 为首要入口。下列能力均可通过 `WenzEditorConfiguration` 的对应字段接入门面，也可直接使用 tier 2 的 typed API（`WenzRichTextController` / `WenzRichTextEditor` / 各 registry）。命令与序列化入口在门面上等价提供（如 `bootstrap.toJson()` / `bootstrap.loadMarkdown()`）。

- **命令**：直接调用 `WenzRichTextController.insertText`、`setBlockType`、`insertTable`、`insertImage`、`insertVideo` 等 typed helper；工具栏场景优先用 `ToolbarController` 派生 active / enabled 状态。
- **Slash 智能菜单**：编辑器接入 `SlashMenuController` 后，在空段落、段首或空白后输入 `/` 会在光标附近打开命令 popup；继续输入 `h`、`table`、`video` 等关键词会实时筛选，ArrowUp/ArrowDown 移动高亮，Enter 执行，Esc 或点击外部关闭。只读、IME 组合输入中、无匹配命令、触发符被删除或光标离开 `/query` 范围时不会展示 popup。
- **Block 行操作**：编辑模式下每个顶层 block 左侧有拖拽把手；点击/键盘 Enter/Space 打开复制、引用、复制副本、上移/下移、删除等菜单，拖过阈值后显示落点线并调整行位置，变更可撤销/重做；只读模式隐藏把手但保留文本选区。自定义 `BlockRendererRegistry` 仍由编辑器外层统一包裹行把手，业务 renderer 不需要额外处理排序 chrome。
- **序列化**：`controller.toJson()` 输出当前 canonical rich JSON；`controller.loadJson(source)` 读取 rich JSON；`controller.loadJson(source, legacy: true)` 读取旧 `wenz_editor` JSON。
- **Markdown / HTML**：通过 `controller.toMarkdown()`、`controller.loadMarkdown(source)` 和 `HtmlCodec` 覆盖常见 block / inline 互转；列表支持无序、有序、无序 todo 和有序 todo（`ordered + checked`），引用通过 `BlockAttributes.quoted` 叠加在段落、标题、列表或 todo 上，导入/导出时映射为 Markdown `>` / HTML `<blockquote>`；复杂媒体与业务 embed 按文档策略降级。
- **连续引用块**：相邻的 quoted text block（`attributes.isQuoted` 或兼容输入 `BlockType.quote`）默认渲染为一个视觉连续的引用背景，组内没有段落缝隙，左侧强调条贯通，仅引用组外边缘保留圆角；引用标题、引用列表、引用 todo 可与引用段落处于同一组，引用与非引用块之间仍保留正常块间距。
- **代码块**：默认渲染等宽代码块、语法高亮、固定左侧 1-based 行号栏、横向滚动正文，以及“左侧语言类型、右侧复制内容”的常驻操作栏；行号仅属于展示层，不写入模型、导出结果或剪贴板。语法高亮基于 [highlight](https://pub.dev/packages/highlight)（highlight.js 的 Dart 移植，纯 Dart 依赖），支持 dart / javascript / typescript / python / java / kotlin / swift / go / rust / sql / json / yaml / html / css / markdown / bash 等 20+ 常见语言及 `js`/`ts`/`sh`/`md`/`c#`/`html`/`toml` 等常见别名，未知语言自动降级为等宽纯文本。
- **视频组件**：通过斜杠菜单 `video`/`视频`、`ToolbarController.insertVideo` 或 `WenzRichTextController.insertVideo` 写入 `VideoBlockNode`；默认只提供占位渲染，真实播放器由业务通过 `MediaResolver` 注入，核心包不依赖 `video_player`；视频占位和自定义播放器都会被限制并裁剪在圆角视频 frame 内，避免溢出编辑器内容区。
- **图片组件**：通过斜杠菜单 `image`/`图片` 插入占位，或由宿主 UI 先完成系统文件选择后调用 `ToolbarController.insertImage` / `WenzRichTextController.insertImage` 写入 `ImageBlockNode`；本地路径或 URI 放在 `ImageBlockNode.file`，文件名可写入 `caption` / `altText`。核心包不依赖文件选择器或图片解码库，真实网络/本地预览仍由 `MediaResolver` 或自定义 renderer 注入。
- **@ 提及点击**：`WenzRichTextController.insertMention(id, label)` 写入 `mention` inline embed；默认显示为 `@label`（空 label 显示 `@mention`），点击后通过 `WenzRichTextEditor.onMentionTap` 把 `id`、`label`、原始 `data` 和文档位置交给业务层，核心包不内置用户页或弹窗。
- **快捷键配置**：通过 `WenzRichTextEditor.shortcutConfiguration` 追加、覆盖、禁用或透传快捷键；配置只负责把键盘事件解析为 `EditorShortcutIntent` / `EditorShortcutResolution`，实际编辑仍走 controller 命令与 `_performShortcut` 路径。
- **扩展**：通过 `BlockRendererRegistry`、`InlineEmbedRenderer`、`MediaResolver` 和 `WenzRichTextPlugin` 注入业务 block、inline embed、媒体渲染、slash item、toolbar item、paste transformer 与快捷键片段。
- **质量门禁**：Golden baseline 覆盖基础块、合并表格、selection / caret、高级块与 inline embed；benchmark 覆盖大文档、复杂表格、滚动 remount 与高级混合文档。

## @ 提及点击打开

核心包只负责识别并派发提及点击事件，业务自行打开用户资料页、成员卡片或弹窗：

```dart
WenzRichTextEditor(
  controller: controller,
  onMentionTap: (details) {
    final userId = details.id;
    if (userId == null || userId.isEmpty) {
      return;
    }
    showUserProfile(
      context,
      userId: userId,
      displayName: details.label ?? details.data['label']?.toString(),
      sourceBlockId: details.blockId,
    );
  },
);

// 写入提及：默认渲染为 @Ada，点击时 details.data 保留原始 payload。
controller.insertMention('u-ada', 'Ada');
```

`WenzMentionTapDetails` 中的 `data` 是原始 `InlineEmbed.data`；建议至少包含 `id` 和 `label`，也可以放入业务字段（如部门、头像、成员类型）。默认 mention 点击不拦截拖拽选择、双击/三击选择；如果通过 `InlineEmbedRenderer` 自定义 `mention` span，则自定义 renderer 需要自行处理点击，或复用 `WenzMentionTapHandler.maybeOf(context)?.notifyMentionTap(...)` 派发同一事件。

## 代码块设计差异梳理

- **现状实现位置**：代码块默认渲染集中在 `lib/src/widgets/wenz_rich_text_editor.dart` 的 `_CodeBlockRenderer`；背景、圆角、边框、内边距、行号栏、代码正文横向滚动与顶部操作栏都在该渲染层组合。
- **语言与复制现状**：`_CodeBlockToolbar` 作为代码块内部常驻操作栏显示，左侧是语言类型标签并保留语言切换入口，右侧是复制代码内容按钮；语言展示文案由 `_codeLanguageLabel` 处理，空语言显示为 `Plain text`。
- **正文与行号边界**：`WenzCodeBlockLineNumbers` 负责 1-based 行号标签，`_CodeLineNumberGutter` 将行号注册为选区排除区域；`_CodeScrollableTextSurface` 只包裹代码正文并保持横向滚动，行号不进入模型、导出或剪贴板内容。
- **语法高亮边界**：`lib/src/widgets/code_syntax_highlighter.dart` 根据 `CodeBlockNode.language` 调用 `highlight` 库（highlight.js 的 Dart 移植）解析并生成 `TextSpan`，通过选择性注册语言控制包体积，覆盖选择器列出的全部语言并补充 cpp / c# / php / ruby / scala / shell / ini(toml) 等常见语言；语言串经别名归一化（`md`→`markdown`、`sh`→`bash`、`js`→`javascript`、`c#`→`cs`、`html`→`xml`、`toml`→`ini` 等）；未知或未注册语言回退为纯文本，不承担 toolbar 或布局职责。
- **测试覆盖现状**：`test/widgets/wenz_rich_text_editor_test.dart` 已覆盖代码块行号展示层策略、复制纯代码内容、语言切换不改写代码，以及暗色主题下内置 block 颜色可读性。
- **设计差异结论**：设计稿要求语言类型位于代码块左侧、复制内容入口位于右侧，二者在同一操作栏内水平对齐且不随代码正文横向滚动；当前实现已按该结构调整为常驻顶部操作栏，后续视觉回归以 widget/golden 覆盖为准。
- **无需变更范围**：本轮梳理确认后续样式调整可限制在默认渲染层与必要测试/README 描述内，不需要修改 `CodeBlockNode` 模型、codec、命令体系或剪贴板序列化格式。

## 字体颜色配置

字体颜色分为“编辑器默认文字颜色”和“内联字体颜色”两层：

- 默认文字颜色通过 `WenzRichTextEditor.defaultTextColor` 配置，只影响没有内联 `TextAttributes.color` 的文本；未传时继续使用 `textStyle.color` 或主题色。
- 选区字体颜色通过 `WenzRichTextController.setTextColor(Color)` 或 `ToolbarController.setTextColor(Color)` 设置，底层存储为稳定的 `0xAARRGGBB` 整数。
- 清除颜色用 `clearTextColor()`，只移除内联字体颜色，保留加粗、链接、背景色等其它样式；`clearStyle()` 仍表示清除整组选区内联样式。
- 读取当前颜色用 `ToolbarController.textColor` 和 `ToolbarController.textColorMixed`：单一颜色返回 `0xAARRGGBB`，混合颜色时 `textColor == null && textColorMixed == true`。
- 渲染优先级为内联字体颜色 > 链接色 > 默认文字颜色/主题色；Markdown 导出会降级为纯文本，HTML 与 rich JSON 会保留颜色。

```dart
const brandText = Color(0xFF1F2937);
const accentText = Color(0xFFD81B60);

WenzRichTextEditor(
  controller: controller,
  textStyle: Theme.of(context).textTheme.bodyLarge,
  defaultTextColor: brandText,
);

// 业务按钮或工具栏回调：
controller.setTextColor(accentText);
controller.clearTextColor();

final toolbar = ToolbarController(controller);
final currentColor = toolbar.textColor == null
    ? null
    : Color(toolbar.textColor!);
final isMixed = toolbar.textColorMixed;
```

## 主题与深浅色适配

编辑器跟随 Flutter `ThemeData` / `ColorScheme` 工作，不新增独立的编辑器主题 API，也不会把主题信息写入文档 JSON：

- `Brightness.light` 下编辑器默认承载背景为白色，`Brightness.dark` 下为黑色；宿主仍可在外层包裹自己的 surface。
- 正文、光标、选区、查找高亮、表格、代码块、callout、文件卡片、embed/formula、浮层和辅助面板会从当前 `ColorScheme` 派生可读颜色。
- 文档内显式样式仍保持稳定：`TextAttributes.color` / `background`、`TableCellNode.backgroundColor` 等属于内容数据，不随主题自动改写。
- example 已提供 AppBar 深浅主题切换，可作为接入 `theme` / `darkTheme` / `themeMode` 的参考。

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
  themeMode: themeMode,
  home: WenzRichTextEditor(controller: controller),
);
```

## 公式编辑

编辑器内置的行内公式和块级公式支持点击编辑当前公式文本：

- 点击行内公式或块级公式卡片会打开公式编辑 popup，输入框会预填当前公式的 LaTeX 文本。
- 点击“确认”会把非空内容写回原公式节点；“取消”、关闭按钮或点击外部会关闭 popup 且不修改文档。
- `readOnly: true` 或未提供编辑上下文时，公式仅展示，不会弹出编辑 popup。
- 若业务通过自定义 inline/block embed renderer 接管公式渲染，需要在自定义渲染中自行接入编辑入口。

## 快捷键配置示例

未传 `shortcutConfiguration` 时，默认快捷键保持兼容：选择、撤销/重做、复制/剪切/粘贴、查找/替换、方向键、Home/End、PageUp/PageDown、删除、回车和字符输入仍按内置规则处理。

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
    // 为宿主“保存”预留 Ctrl/Cmd+S，让外层 Focus/Actions 或浏览器接手。
    EditorShortcutBinding.passThrough(
      shortcut: EditorShortcutKey(
        LogicalKeyboardKey.keyS,
        modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
      ),
    ),
    // 把 Ctrl/Cmd+K 改成打开查找入口。
    EditorShortcutBinding.handled(
      shortcut: EditorShortcutKey(
        LogicalKeyboardKey.keyK,
        modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
      ),
      intent: EditorShortcutIntent.find,
    ),
  ],
  // 禁用默认粘贴；只读态下写操作仍会被编辑器忽略。
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

`EditorShortcutModifier.primary` 表示 Windows/Linux/Web/Android 上的 Ctrl、macOS/iOS 上的 Cmd；需要精确匹配时可改用 `control`、`meta`、`alt`、`shift`。同一组合键后注册的绑定覆盖先注册的绑定，同一 intent 可以有多个组合键别名。

## 文档地图

- 首要 API 入口：[README 接口文档](#接口文档)
- Docs 索引：[`docs/README.md`](docs/README.md)
- 标准对外接口详细契约：[`docs/integration_guide.md`](docs/integration_guide.md)
- 完整 API 参考：[`docs/api_reference.md`](docs/api_reference.md)
- 架构概览：[`docs/architecture.md`](docs/architecture.md)
- 迁移指南：[`docs/migration_guide.md`](docs/migration_guide.md)
- 命令与 schema：[`docs/schema_and_commands.md`](docs/schema_and_commands.md)
- 输入系统与 Slash 菜单：[`docs/input_system.md`](docs/input_system.md)
- 导入导出：[`docs/import_export_strategy.md`](docs/import_export_strategy.md)
- 运行 example：[`docs/running_guide.md`](docs/running_guide.md)
- 发布检查：[`docs/release_checklist.md`](docs/release_checklist.md)
- 选区与 block 拖拽：[`docs/selection_engine.md`](docs/selection_engine.md)

## 回归验证

- Block 行操作改动优先运行：`flutter test test/core/block_structure_commands_test.dart --name MoveBlockCommand`、`flutter test test/widgets/wenz_rich_text_editor_test.dart --name "block drag handles"`、`flutter test test/widgets/editor_golden_test.dart --name "golden: block"`
- 更新视觉基线时使用：`flutter test test/widgets/editor_golden_test.dart --update-goldens --name "golden: block"`
- 发布或合并前再运行：`flutter analyze` 与 `flutter test`

## FAQ

- **是否依赖原生插件？** 不依赖。核心 package 是纯 Flutter / Dart；视频播放、下载、远端资源加载等由业务通过 resolver 或 adapter 注入。
- **是否兼容旧数据？** 支持。旧 `wenz_editor` JSON 可用 `legacy: true` 导入；rich JSON 使用 `DocumentMigrationRegistry` 管理 schema version。
- **PDF / DOCX 是否内建？** 当前只提供平台、依赖和 adapter 合约方案，核心库不引入 PDF、print、OOXML 依赖。
- **alpha 还有哪些边界？** 屏幕阅读器抽样手验、移动端 selection handles、部分三端 IME 手验仍按 `docs/release_checklist.md` 作为发布门禁。
