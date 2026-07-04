# 自定义组件接入指南

本指南说明业务侧如何向 `wenz_richtext` 接入自定义组件——例如流程图、CRM 卡片、审批单、看板卡片等。它不是新造一套接口，而是把已落地的四层接入契约（数据 / 渲染 / 插入 / 更新 / 复用）沉淀成一份接口设计方案，并以「流程图」作为贯穿示例给出具体实现方案。

> 阅读路径：先看 [§1 选型](#1-选型三种接入位) 确定你的组件走哪条接入位，再按 [§3 四层契约](#3-四层契约流程图贯穿示例) 逐层落地。完整字段契约以 [`docs/api_reference.md`](api_reference.md) 与 [`docs/integration_guide.md`](integration_guide.md) §5/§10 为准；本指南只补充「自定义组件」这一垂直场景的选型与边界说明，不重复既有接口。

## 1. 选型：三种接入位

`wenz_richtext` 的扩展点对业务组件提供三条互斥的接入位。先按下表对号入座，再进入对应的契约：

| 业务形态 | 推荐接入位 | 配置字段 / 注册方法 | 数据落点 | 适用示例 |
| --- | --- | --- | --- | --- |
| 整行级业务块（块级对象） | `BlockEmbedNode` + `blockEmbedRenderers` | `WenzEditorConfiguration.blockEmbedRenderers: Map<String, BlockRendererBuilder>` | `BlockEmbedNode.embedType` + `BlockEmbedNode.data` | 流程图、CRM 卡片、审批单、看板卡片、投票、任务清单 |
| 行内片段 | `InlineEmbed` + `inlineEmbedRenderers` | `WenzEditorConfiguration.inlineEmbedRenderers: Map<String, InlineEmbedSpanBuilder>` | `InlineEmbed.embedType` + `InlineEmbed.data` | @mention chip、状态标签、inline 图标、inline 公式 |
| 改写内置块外观 | 覆盖既有 `BlockType` renderer | `WenzEditorConfiguration.blockRenderers: Map<BlockType, BlockRendererBuilder>` | 复用既有 `BlockType` 模型（不改数据结构） | 自定义图片解码、自定义代码块高亮、自定义表格渲染 |

**流程图属于「整行级业务块」**——它独占一整行、有自身几何与交互、需要随文档持久化——因此走 `BlockEmbedNode` + `blockEmbedRenderers` 路径。下文全部以流程图为样本。

## 2. 边界：BlockEmbedNode vs InlineEmbed vs 覆盖 BlockType

三条接入位看起来都「注册一个 builder」，但数据模型、选区行为、序列化保真度完全不同，**不要混用**：

| 维度 | `BlockEmbedNode`（块级 embed） | `InlineEmbed`（行内 embed） | 覆盖 `BlockType` renderer |
| --- | --- | --- | --- |
| 数据模型 | `BlockEmbedNode`，`type == BlockType.embed`，`embedType` 区分业务种类 | `InlineEmbed`，嵌在 `TextBlockNode` 的 inline 序列里 | 复用既有 `BlockNode` 子类（`ImageBlockNode` / `CodeBlockNode` / `TableBlockNode` …） |
| 在文档中的位置 | 顶层 block，独占一行 | 文本流中的一个逻辑字符 | 顶层 block，独占一行 |
| 选区语义 | object block 选区（命中即选中整块） | 占一个字符位，参与文本选区与删除 | 沿用被覆盖类型的既有选区语义 |
| 持久化保真度 | rich JSON 完整保留 `data`；HTML/Markdown/纯文本经 `displayText`/`fallbackText` 降级 | rich JSON 保留；导出时降级 | 由既有类型的 codec 决定（通常保真度高） |
| 何时选它 | 你有一个**自包含业务对象**，需要自己的数据结构、自己的渲染、自己的交互 | 你要在**文字之间**插入一个原子 chip/标记 | 你只是想**换内置块的皮**，数据结构不变 |

**判断口诀：**
- 数据结构是你的（自定义 schema）→ `BlockEmbedNode` 或 `InlineEmbed`。
- 它独占一行 → `BlockEmbedNode`；它在文字中间 → `InlineEmbed`。
- 数据结构是内置的、你只换外观 → 覆盖 `BlockType` renderer。

> 注意 `BlockEmbedNode.embedType` 与 `InlineEmbed.embedType` 是**两个独立的命名空间**：同一个字符串（如 `'flowchart'`）在块级注册表和行内注册表里互不影响。块级和行内不共享 builder。

### 2.1 mention 的特殊边界

`mention` 虽然也是 `InlineEmbed`，但它已经有一条内置编辑链路。业务侧通常不需要先写 `inlineEmbedRenderers['mention']`：

- 搜索：通过 `WenzEditorConfiguration.mentionSearch` 返回 `WenzMentionCandidate` 列表。`request.query` 不包含前导 `@`，callback 可以同步返回，也可以异步查用户目录。
- 插入：内置 `@` 浮层选中候选项后会调用 `WenzRichTextController.insertMention(candidate.id, candidate.label, data: candidate.toMentionData())`，替换触发范围。手动入口也应调用 `insertMention(id, label, data: ...)`，不要自己拼 `InlineEmbed`。
- 数据：`WenzMentionCandidate.data` / `insertMention(data: ...)` 只放 JSON 友好字段；`id` / `label` 是规范字段，冲突时显式参数优先。额外业务字段会保存在 `InlineEmbed.data`，供 rich JSON 往返和点击详情使用。
- 点击：通过 `WenzEditorConfiguration.onMentionTap` 接收 `WenzMentionTapDetails`，读取 `details.id`、`details.label`、`details.data` 和 `details.position` 打开成员卡、用户详情或业务面板。

只有在要改 `@label` 的视觉样式时才覆盖 `inlineEmbedRenderers['mention']`。自定义 renderer 返回非 `null` span 时，点击识别与业务行为由该 renderer 自己负责；返回 `null` 则继续使用默认 `@label` 渲染和 editor 级 `onMentionTap`。如果自定义 renderer 已经持有该 mention 的 `DocumentPosition`，可以调用 `WenzMentionTapHandler.maybeOf(context)?.notifyMentionTap(embed, position)` 复用同一套公开回调 payload。

## 3. 四层契约：流程图贯穿示例

接入一个块级自定义组件，按「数据 → 渲染 → 插入 → 更新」四层落地，可选用「插件」封装复用。下面每一层都给出流程图的具体写法。

### 3.1 数据层：BlockEmbedNode

数据契约由 `BlockEmbedNode` 承载（`lib/src/core/model/block_node.dart`）：

```dart
const BlockEmbedNode({
  required super.id,
  required this.embedType,        // 业务种类，如 'flowchart'
  this.data = const <String, Object?>{},  // JSON 友好的业务数据
  this.fallbackText = '',          // 导出降级时的纯文本兜底
  super.attributes,
}) : super(type: BlockType.embed);
```

关键行为（均为只读 getter，已稳定）：
- `embedType` / `normalizedEmbedType`：后者把空串归一化为 `'custom'`，并作为 renderer 注册表的查找键。
- `data`：`Map<String, Object?>`，**必须 JSON 可往返**（`String` / `num` / `bool` / `null` / `List` / `Map`），rich JSON 会原样持久化。
- `fallbackText`：HTML / Markdown / 纯文本导出且无法保留结构时的兜底文案。
- `displayText`：降级文案的派生顺序——`fallbackText` → formula（仅 `isFormula`）→ `data` 中的 `title` / `label` / `name` / `url`（取第一个非空）→ `normalizedEmbedType`。设计 `data` 时尽量把人类可读标题放进这几个键之一。
- `toJson()` / `fromJson()`：自动往返，`data` 非空才写入；文档归一化（`document_schema.dart` 的 `_normalizeBlockEmbed`）会保留 `data`。

流程图的数据契约设计为：

```dart
// data = {
//   'nodes': <Map<String, Object?>>[
//     {'id': 'n1', 'label': '开始', 'x': 40.0, 'y': 40.0, 'kind': 'start'},
//     {'id': 'n2', 'label': '处理', 'x': 40.0, 'y': 160.0, 'kind': 'process'},
//   ],
//   'edges': <Map<String, Object?>>[
//     {'from': 'n1', 'to': 'n2', 'label': '提交'},
//   ],
//   'direction': 'TB', // 'TB' 纵向 | 'LR' 横向
//   'version': 1,
// }
// fallbackText = '流程图'（displayText 也可读到 data['title'] 之类字段，二者择一）
final flow = BlockEmbedNode(
  id: blockId,
  embedType: 'flowchart',
  data: <String, Object?>{...},
  fallbackText: '流程图',
);
```

约定：`data` 全部用基础 JSON 类型、坐标用 `double`、`version` 用于后续 schema 迁移。这保证 rich JSON 往返后节点 / 边 / 坐标一个不丢。

### 3.2 渲染层：BlockRendererBuilder + WenzObjectBlockSurface

注册一个 `BlockRendererBuilder`（`lib/src/widgets/block_renderer_registry.dart`）：

```dart
typedef BlockRendererBuilder = Widget Function(
  BuildContext context,
  BlockRenderContext renderContext,
);
```

builder 收到 `BlockRenderContext`，其中与自定义组件最相关的字段：
- `block`：当前 block（强转为 `BlockEmbedNode`，读 `embedType` / `data`）。
- `selection` / `showCaret`：当前选区与是否显示光标。
- `canEdit`：是否处于可编辑态（由 `permission` 与 widget readOnly 派生）——**业务手势（拖拽节点）应只在 `canEdit` 时启用**。
- `mediaResolver` / `inlineEmbedRenderer`：媒体解析与行内 embed 渲染（业务块通常用不到）。
- `objectBlockToolbarOverlayController`：编辑器级对象块工具栏 Overlay 控制器；需要像内置图片 / 视频一样悬浮工具栏时，用它发布 `ObjectBlockToolbarOverlayRequest`。
- `onObjectBlockAction`：对象块操作回调（命中测试 / 块把手相关，由外层处理）。

**核心约束：业务 widget 必须用 `WenzObjectBlockSurface` 包裹**（`lib/src/widgets/wenz_rich_text_editor.dart`），这样它才能拿到与内置 image / video / file 一致的选区命中、光标、几何与块把手；不包裹则选区、行把手、排序 chrome 都不会正确生效。

默认图片块已经内置可编辑态交互：选中图片后，frame 左右边缘会出现 resize 手柄，拖拽按图片有效宽高比同步调整 `showWidth/showHeight`，并在拖拽结束时通过 controller/command pipeline 调用 `updateImageBlock` 提交一次更新。拖拽过程只做临时预览，不创建新图片块、不改变 block id，也不需要业务层用“创建块副本”来模拟尺寸变化；图片块的内置对象菜单也不会暴露副本入口。`readOnly` 或非编辑权限下手柄隐藏且不会提交尺寸更新。

如果业务块还需要悬浮对象工具栏，不要把工具栏塞进业务 widget 的 `Column` / `Stack`，也不要靠负偏移或额外占位制造悬浮效果。正确做法是在业务对象框顶部布置 `ObjectBlockToolbarOverlayAnchor`，通过 `objectBlockToolbarOverlayController` 发布请求，由编辑器级 `ObjectBlockToolbarOverlayHost` 承载工具栏；这样选中 / 取消选中不会改变业务块高度、frame 位置或周边正文布局。未显式迁移的非媒体对象块仍沿用既有块级浮动工具栏路径。

```dart
Widget Function(BuildContext, BlockRenderContext) flowchartBuilder =
    (_, renderContext) {
  final block = renderContext.block as BlockEmbedNode;
  return WenzObjectBlockSurface(
    renderContext: renderContext,
    child: FlowchartView(
      data: block.data,
      canEdit: renderContext.canEdit, // 只读态收敛交互
      onChanged: (nextData) => /* 见 §3.4 回写 */,
    ),
  );
};
```

`FlowchartView` 是业务自己实现的 widget（`CustomPainter` + `Stack` 定位节点 + 手势拖拽即可），核心包不依赖任何图形库。

### 3.3 插入层：insertBlockEmbed + SlashMenuItem + WenzToolbarItem

插入入口是 controller 的 typed helper（`lib/src/controller/wenz_rich_text_controller.dart`），底层走 `insertBlocks` / `InsertBlocksCommand`，受权限闸门、计入历史记录：

```dart
ChangeSet insertBlockEmbed({
  int? index,                       // 缺省追加到文档末尾
  required String blockId,
  required String embedType,
  Map<String, Object?> data = const <String, Object?>{},
  String fallbackText = '',
  DocumentSelection? selection,
});
```

把它接到 slash 菜单与工具栏，让用户能「打出 `/流程图`」或点工具栏插入：

```dart
// SlashMenuItem（lib/src/controller/slash_menu_controller.dart）
// SlashMenuAction = void Function(WenzRichTextController editor, SlashMenuContext context)
final flowSlashItem = SlashMenuItem(
  id: 'flowchart',
  title: '流程图',
  icon: 'account_tree',
  keywords: const <String>['flowchart', '图', 'liuchengtu'],
  action: (editor, context) {
    editor.insertBlockEmbed(
      blockId: context.generatedId('flowchart'),
      embedType: 'flowchart',
      data: defaultFlowchartData(),
      fallbackText: '流程图',
    );
  },
);

// WenzToolbarItem（lib/src/controller/toolbar_controller.dart）
// WenzToolbarItemAction = void Function(WenzRichTextController editor, ToolbarState state)
final flowToolbarItem = WenzToolbarItem(
  id: 'flowchart',
  title: '流程图',
  icon: 'account_tree',
  isEnabled: (state) => state.canSetBlockType,
  action: (editor, state) => editor.insertBlockEmbed(
    blockId: newBlockId('flowchart'),
    embedType: 'flowchart',
    data: defaultFlowchartData(),
    fallbackText: '流程图',
  ),
);
```

`blockId` 由业务生成（`SlashMenuContext.generatedId(prefix)` 或自有 id 工厂），需保证文档内唯一。
`WenzToolbarItem` 会进入 `WenzToolbarItemRegistry`；使用
`WenzEditorBootstrap.buildDefaultDesktopToolbar()` 时，默认桌面工具栏会自动渲染
registry 中的插件/宿主按钮。工具栏用 `ToolbarState` 计算
`isEnabled` / `isActive`，点击后把 `WenzRichTextController` 与当前
`ToolbarState` 传给 `action`。`icon` 是字符串 token：默认工具栏会把
`account_tree` / `extension` / `image` / `video` / `file` / `link` /
`formula` / `emoji` 等常见 token 映射到 Material icon，未知 token 稳定回退到
extension 图标；完全自定义工具栏可以按自己的规则解释同一个 descriptor。

### 3.4 更新层：updateBlockEmbed

流程图这类需要「原地编辑」的组件（拖拽改节点坐标、增删边），不能每次重建整块，否则会丢失选区与几何。controller 提供与 `updateImageBlock` / `updateVideoBlock` / `updateFileBlock` 对称的通用就地更新 helper（`updateBlockEmbed`，底层复用 `replaceBlocks`）：

```dart
ChangeSet updateBlockEmbed({
  required String blockId,
  Map<String, Object?>? data,
  String? fallbackText,
  String? embedType,
  DocumentSelection? selection,
});
```

- `blockId` 不存在，或 `data` / `fallbackText` / `embedType` 全为 `null` 时为 noop（返回空 `ChangeSet`，不抛异常）。
- 只替换传入的字段，未传字段保留原值；`blockId` 保持不变以维持选区与块几何。
- 走命令层，保留历史记录、触发 `onChanged` / `onCommandExecuted`，受权限闸门。

拖拽结束时用它回写：

```dart
// FlowchartView.onChanged
onChanged: (nextData) => controller.updateBlockEmbed(
  block.id,
  data: nextData, // 拖拽后的完整 data map
);
```

> 若运行环境中尚未提供 `updateBlockEmbed`，可临时退回低层 `replaceBlocks(index: i, deleteCount: 1, blocks: [block.copyWith(data: nextData)])`（`replaceBlocks` 见 `wenz_rich_text_controller.dart`）；二者语义等价，正式接入以 `updateBlockEmbed` 为准。

### 3.5 复用层（可选）：WenzRichTextPlugin

当组件需要在多个宿主共享时，封装为 `WenzRichTextPlugin`（`lib/src/plugins/editor_plugin.dart`），在 `install` 内一次性注册 renderer / slash item / toolbar item（乃至命令、middleware、快捷键、粘贴转换）：

```dart
abstract class WenzRichTextPlugin {
  String get id;
  WenzPluginApiStatus get apiStatus; // 默认 stabilising
  void install(WenzPluginContext context);
}
```

`WenzPluginContext` 提供的注册方法（节选）：
- `registerBlockEmbedRenderer(String embedType, BlockRendererBuilder builder)` — 注册块级 renderer。
- `registerInlineEmbedRenderer(String embedType, InlineEmbedSpanBuilder builder)` — 注册行内 renderer。
- `registerSlashMenuItem(SlashMenuItem item)` / `registerSlashMenuItems(Iterable<SlashMenuItem>)` — 注册 slash 菜单项。
- `registerToolbarItem(WenzToolbarItem item)` — 注册工具栏项。
- `registerCommand(CommandDescriptor)` / `addMiddleware(CommandMiddleware)` — 注册命名命令与中间件。
- `registerShortcutConfiguration(...)` / `registerPasteTransformer(...)` — 注册快捷键片段与粘贴转换。

流程图插件示意：

```dart
class FlowchartPlugin extends WenzRichTextPlugin {
  const FlowchartPlugin();
  @override
  String get id => 'flowchart';
  @override
  void install(WenzPluginContext context) {
    context.registerBlockEmbedRenderer('flowchart', flowchartBuilder);
    context.registerSlashMenuItem(flowSlashItem);
    context.registerToolbarItem(flowToolbarItem);
  }
}
```

宿主只需 `plugins: [const FlowchartPlugin()]` 即可整体接入。声明式批量场景也可用 `WenzPluginBundle`（同文件），它把以上字段作为构造参数，省去手写 `install`。

## 4. 两条接入路径

自定义组件可以通过任一路径接入，二者等价（最终都进同一个注册表）：

1. **一次性配置注入**：宿主在 `WenzEditorConfiguration` 直接填 `blockEmbedRenderers` + `slashMenuItems` + `toolbarItems`。适合「只有这一个宿主用」、配置就地可见的场景。与 `example/lib/main.dart` 中的 CRM 卡片写法一致。
2. **可复用插件**：宿主持有 `FlowchartPlugin extends WenzRichTextPlugin`，`install` 内集中注册；`plugins: [const FlowchartPlugin()]` 接入。适合跨宿主复用、或需要同时注册命令 / middleware / 快捷键的场景。

example 会**同时演示**两条路径（CRM 走配置注入、流程图走插件），以便对比选型。

## 5. 合并顺序与覆盖语义

bootstrap 装配顺序固定为「**默认能力 → 插件贡献 → 宿主配置**」（见 `lib/src/integration/wenz_editor_bootstrap.dart` 的 `WenzEditorBootstrap.create`）：

1. 先 `installDefaultRenderers`，保证零配置 editor 可直接运行。
2. 再经 `WenzPluginContext` 安装所有 `plugins`。
3. 最后注册宿主 `blockEmbedRenderers` / `slashMenuItems` / `toolbarItems` / `inlineEmbedRenderers` / `blockRenderers`。

因此同 `embedType` / 同 slash id / 同 toolbar id 冲突时：**宿主覆盖插件，插件覆盖默认值，默认值仅作 fallback**。这一规则与 README「扩展点」、`integration_guide.md` §5 完全一致。粘贴转换是顺序 pipeline（返回 `null` 才交给下一级）。设计插件时**不要假设自己的 renderer / item 一定能赢**——宿主有权覆盖。

`WenzToolbarItemRegistry.items` 和默认桌面工具栏的显式 `toolbarItems` 都按
`priority` 升序、再按 `id` 字典序渲染；同一个 `id` 只保留最后注册/显式传入的
item。bootstrap 的安装顺序是「默认能力 → 插件贡献 → 宿主配置」，因此配置里的
host toolbar item 会覆盖插件同 id item。若调用
`buildDefaultDesktopToolbar(toolbarItems: [...])` 再额外传入显式 items，这些显式
items 会覆盖 registry 中同 id 项，适合页面局部替换或临时按钮。

若想「必胜」，宿主侧直接用配置注入即可（路径 1）；插件侧应接受被覆盖。

## 6. 权限闸门

权限以 `WenzEditorConfiguration.permission` 为唯一来源，有序：`read < comment < edit`（`lib/src/core/commands/editor_command.dart` 的 `WenzEditorPermission`）。`insertBlockEmbed` / `updateBlockEmbed` 等写入命令默认 `requiredPermission = edit`，controller 的 `execute` / `canExecute` 统一拦截：

- `read` / `comment` 下，命令层返回 blocked `ChangeSet` 且**不改文档**——即使 UI 没隐藏按钮。
- 业务渲染侧应读 `renderContext.canEdit`：只读态下禁用拖拽、禁用就地编辑入口，仅展示。
- 自定义 toolbar / slash item / 快捷键 / 插件命令的 `action` **仍必须走 controller 命令入口**，让权限闸门兜底；不要只隐藏按钮或禁用 UI 来替代命令层权限。

> 与 [`integration_guide.md`](integration_guide.md) §6 / §7 一致：`permission` 控命令策略，`buildEditor(readOnly: true)` 控输入观感，二者组合才锁死只读。

## 7. 序列化与降级

自定义 embed 的保真度按格式分级：

| 格式 | 入口 | 行为 |
| --- | --- | --- |
| Rich JSON | `controller.toJson()` / `loadJson(source)` | **首选持久化格式**，`embedType` + `data`（含节点 / 边 / 坐标）+ `fallbackText` 完整保留，往返无损。 |
| Legacy JSON | `loadJson(source, legacy: true)` | 旧 `wenz_editor` 数据导入；`data` 在归一化时保留。 |
| HTML | `toHtml()` / `loadHtml(source)` | 降级：块级 embed 不写出私有结构，导出为 `displayText` / `fallbackText` 纯文本。 |
| Markdown | `toMarkdown()` / `loadMarkdown(source)` | 降级为 `displayText` / `fallbackText` 文本。 |
| 纯文本 | `toPlainText()` | 降级为 `BlockEmbedNode.plainText`（即 `displayText`）。 |

**验证要点**：写入流程图 embed 后 `toJson()` → `loadJson()` 往返，节点 / 边 / 坐标 / `fallbackText` 必须完整保留；`toMarkdown()` / `toPlainText()` 应降级为人类可读文案（优先 `fallbackText`，否则依次读 `data` 的 `title` → `label` → `name` → `url`，最后 `normalizedEmbedType`）。

**无 renderer 回退**：未注册 `flowchart` builder 时，`BlockRendererRegistry.resolveForBlock` 落到通用 `BlockType.embed` renderer，渲染 `displayText`，不报错。因此「能插、能持久化」不依赖 renderer 是否注册——renderer 只影响编辑态视觉与交互。

## 8. 常见陷阱与约束

- **业务手势 vs 选区命中**：流程图拖拽用 `GestureDetector` 等手势会与编辑器选区竞争命中测试。约束：业务手势只在 `renderContext.canEdit == true` 且命中具体节点时生效；命中空白处仍交给 `WenzObjectBlockSurface` 产生对象块选区。
- **blockId 稳定性**：就地更新必须用 `updateBlockEmbed`（`blockId` 不变），不要用 `replaceBlocks` 改 id——否则选区、块把手、行排序几何会错位。
- **`data` 必须可序列化**：只能放基础 JSON 类型；不要塞 `Offset` / `Color` 等 Dart 对象，否则 rich JSON 往返会失败或丢字段。坐标存 `double`、颜色存 `0xAARRGGBB` 整数。
- **不要直接改内部 list**：替换整篇文档走 `loadJson` / `replaceDocument`，改单块走命令层（`insertBlockEmbed` / `updateBlockEmbed`）；绕过命令层会丢历史记录与回调。
- **不要依赖 `src/` 内部实现**：业务只依赖从 `package:wenz_richtext/wenz_richtext.dart` 导出的 tier 1/2 类型（见 README「Public surface 分层」）；如需更深定制，转化为配置 / 插件 / renderer / codec / 命令接入点。

## 9. 参考实现索引

- **CRM 卡片（既有、可运行的块级 embed 范例）**：`example/lib/main.dart` —— 通过 `blockEmbedRenderers['crm-card']` 注册，`WenzObjectBlockSurface` 包裹，`insertBlockEmbed` 插入，与本指南流程图的「配置注入路径」写法一致。
- **mention 搜索与详情模拟（行内 embed 内置链路范例）**：`example/lib/main.dart` —— 通过 `mentionSearch` 返回模拟成员，编辑区 `@` 浮层插入 mention，`onMentionTap` 打开详情弹窗。
- **流程图样本（具体实现方案落地处）**：`example/lib/flowchart/` —— 数据契约 helper、`FlowchartView` widget、`FlowchartPlugin`，example 同时演示配置注入与插件两条路径。
- **README 扩展点**：[README 扩展点与派生控制器接口](../README.md#扩展点与派生控制器接口) —— `BlockRendererRegistry` / `InlineEmbedRenderer` / `MediaResolver` / `WenzRichTextPlugin` 的总览与合并顺序。
- **标准接入契约**：[`integration_guide.md`](integration_guide.md) §5（扩展注入）、§10（配置字段 → 扩展点映射）、§6/§7（权限与三态）。
- **完整 API 参考**：[`api_reference.md`](api_reference.md) —— 各 helper、registry、plugin context 的字段与异常契约。

## 10. 接入清单（流程图）

落地一个自定义组件，逐项打勾即可：

- [ ] 选定接入位（块级对象 → `BlockEmbedNode`，行内 → `InlineEmbed`，换皮 → 覆盖 `BlockType`）。
- [ ] 设计 `data` schema（JSON 友好、带 `version`）与 `fallbackText` / `displayText` 字段。
- [ ] 实现 `BlockRendererBuilder`，用 `WenzObjectBlockSurface` 包裹业务 widget，按 `canEdit` 收敛交互。
- [ ] 经 `blockEmbedRenderers`（配置注入）或 `registerBlockEmbedRenderer`（插件）注册 builder。
- [ ] 注册 `SlashMenuItem` + `WenzToolbarItem`，`action` 调 `insertBlockEmbed`。
- [ ] 就地编辑回写走 `updateBlockEmbed`（保持 `blockId` 不变）。
- [ ] 验证 `toJson()` → `loadJson()` 往返无损，`toMarkdown()` / `toPlainText()` 降级合理。
- [ ] 验证未注册 renderer 时落到通用 `BlockType.embed` 不报错。
- [ ] 验证 `WenzEditorPermission.read` 下 insert / update 被 blocked 且不改文档。
