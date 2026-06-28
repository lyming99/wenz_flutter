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

`WenzEditorConfiguration` + `WenzEditorBootstrap` 是标准对外接口（tier 1 推荐入口）：零配置即可创建一个可用编辑器，并通过配置注入媒体解析、自定义 renderer、slash / toolbar item、插件、快捷键与回调。完整契约见 [`docs/integration_guide.md`](docs/integration_guide.md)，更完整的接入样例（CRM embed + 自动保存 + slash 菜单 + 回调事件）见 `example/lib/main.dart`。

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

下面的章节是仍可直接使用的高级扩展点：`WenzRichTextController`、`WenzRichTextEditor` 与各 registry / plugin 契约保持 tier 2 不变，门面内部复用的就是同一套装配逻辑。

## 常用能力

下列能力均可通过 `WenzEditorConfiguration` 的对应字段接入门面，也可直接使用 tier 2 的 typed API（`WenzRichTextController` / `WenzRichTextEditor` / 各 registry）。命令与序列化入口在门面上等价提供（如 `bootstrap.toJson()` / `bootstrap.loadMarkdown()`）。

- **命令**：直接调用 `WenzRichTextController.insertText`、`setBlockType`、`insertTable`、`insertVideo` 等 typed helper；工具栏场景优先用 `ToolbarController` 派生 active / enabled 状态。
- **Slash 智能菜单**：编辑器接入 `SlashMenuController` 后，在空段落、段首或空白后输入 `/` 会在光标附近打开命令 popup；继续输入 `h`、`table`、`video` 等关键词会实时筛选，ArrowUp/ArrowDown 移动高亮，Enter 执行，Esc 或点击外部关闭。只读、IME 组合输入中、无匹配命令、触发符被删除或光标离开 `/query` 范围时不会展示 popup。
- **Block 行操作**：编辑模式下每个顶层 block 左侧有拖拽把手；点击/键盘 Enter/Space 打开复制、引用、复制副本、上移/下移、删除等菜单，拖过阈值后显示落点线并调整行位置，变更可撤销/重做；只读模式隐藏把手但保留文本选区。自定义 `BlockRendererRegistry` 仍由编辑器外层统一包裹行把手，业务 renderer 不需要额外处理排序 chrome。
- **序列化**：`controller.toJson()` 输出当前 canonical rich JSON；`controller.loadJson(source)` 读取 rich JSON；`controller.loadJson(source, legacy: true)` 读取旧 `wenz_editor` JSON。
- **Markdown / HTML**：通过 `controller.toMarkdown()`、`controller.loadMarkdown(source)` 和 `HtmlCodec` 覆盖常见 block / inline 互转；列表支持无序、有序、无序 todo 和有序 todo（`ordered + checked`），复杂媒体与业务 embed 按文档策略降级。
- **代码块**：默认渲染等宽代码块、语法高亮、固定左侧 1-based 行号栏、横向滚动正文，以及“左侧语言类型、右侧复制内容”的常驻操作栏；行号仅属于展示层，不写入模型、导出结果或剪贴板。语法高亮基于 [highlight](https://pub.dev/packages/highlight)（highlight.js 的 Dart 移植，纯 Dart 依赖），支持 dart / javascript / typescript / python / java / kotlin / swift / go / rust / sql / json / yaml / html / css / markdown / bash 等 20+ 常见语言及 `js`/`ts`/`sh`/`md`/`c#`/`html`/`toml` 等常见别名，未知语言自动降级为等宽纯文本。
- **视频组件**：通过斜杠菜单 `video`/`视频`、`ToolbarController.insertVideo` 或 `WenzRichTextController.insertVideo` 写入 `VideoBlockNode`；默认只提供占位渲染，真实播放器由业务通过 `MediaResolver` 注入，核心包不依赖 `video_player`；视频占位和自定义播放器都会被限制并裁剪在圆角视频 frame 内，避免溢出编辑器内容区。
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

- 标准对外接口（门面 + 配置）：`docs/integration_guide.md`
- API 入口：`docs/api_reference.md`
- 架构概览：`docs/architecture.md`
- 迁移指南：`docs/migration_guide.md`
- 命令与 schema：`docs/schema_and_commands.md`
- 输入系统与 Slash 菜单：`docs/input_system.md`
- 导入导出：`docs/import_export_strategy.md`
- 运行 example：`docs/running_guide.md`
- 发布检查：`docs/release_checklist.md`
- 选区与 block 拖拽：`docs/selection_engine.md`

## 回归验证

- Block 行操作改动优先运行：`flutter test test/core/block_structure_commands_test.dart --name MoveBlockCommand`、`flutter test test/widgets/wenz_rich_text_editor_test.dart --name "block drag handles"`、`flutter test test/widgets/editor_golden_test.dart --name "golden: block"`
- 更新视觉基线时使用：`flutter test test/widgets/editor_golden_test.dart --update-goldens --name "golden: block"`
- 发布或合并前再运行：`flutter analyze` 与 `flutter test`

## FAQ

- **是否依赖原生插件？** 不依赖。核心 package 是纯 Flutter / Dart；视频播放、下载、远端资源加载等由业务通过 resolver 或 adapter 注入。
- **是否兼容旧数据？** 支持。旧 `wenz_editor` JSON 可用 `legacy: true` 导入；rich JSON 使用 `DocumentMigrationRegistry` 管理 schema version。
- **PDF / DOCX 是否内建？** 当前只提供平台、依赖和 adapter 合约方案，核心库不引入 PDF、print、OOXML 依赖。
- **alpha 还有哪些边界？** 屏幕阅读器抽样手验、移动端 selection handles、部分三端 IME 手验仍按 `docs/release_checklist.md` 作为发布门禁。
