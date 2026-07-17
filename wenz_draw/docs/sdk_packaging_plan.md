# wenz_draw SDK 封装与扩展开发计划

> **进度（2026-06-16）**：Phase 0–5 全部完成。
> - SDK `flutter analyze` 零 issue；`flutter test` 242 个全过。
> - example `flutter analyze` 零 issue；`flutter test` 全过。
> - 三个 barrel 入口：`wenz_draw.dart`（内核）、`wenz_draw_mindmap.dart`（思维导图，可选）、`wenz_draw_ui.dart`（编辑器 UI 套件，可选）。

本计划回答四个核心问题，并把 example 的能力产品化为可被业务 App 直接接入的 SDK：

1. 如何把 example 的代码封装进 wenz_draw 作为 SDK？
2. 如何确定数据格式？
3. 如何自定义图片组件加载器？
4. 如何自定义左侧面板、右侧面板、工具栏？

## 现状判断

`wenz_draw` 已经是一个 SDK（`lib/src/` 内核 + `lib/wenz_draw.dart` 统一 export），example 是产品级编辑器外壳的雏形。真正要做的不是"从零封装"，而是：

- 把 example 里**可复用的产品级 UI 外壳**（工具栏/左右面板/图片导入）和**能力子系统**（思维导图）下沉进 SDK，让业务方不用照抄 demo。
- 补齐几个关键缺口：图片加载断链、文档格式、未知元素保留、面板可替换机制。

### 已确认的关键缺口

1. **图片加载断链**：`ImageElement.decodeBase64Image` 在整个 SDK 里没有任何调用方。加载 JSON 后 `image` 为 `null`，渲染器只画灰框占位。`image_importer.dart` 在 example 里且依赖 `file_selector`（SDK 未引入）。
2. **序列化器对未知 type 静默降级成 `LineElement`**（`canvas_serializer.dart:285`），丢数据。
3. **面板/工具栏是写死的 Widget**，没有插槽/替换机制。
4. **文档格式** `CanvasDocument` 只有 `version/layers/elements`，缺 metadata/viewport/assets/migration。
5. **mindmap 子系统全部躺在 example 里**（20 个文件），业务方要用思维导图必须整块搬。

### 已确认的迁移友好度（好消息）

- 内核 `lib/src/` **完全不引用 mindmap**，迁移方向单向（mindmap 依赖内核，内核不依赖 mindmap）。
- mindmap 已通过 SDK 标准扩展点接入：节点是 `widgetType == 'mindmap_node'` 的 `CanvasWidgetElement`，数据在 `widgetData`，靠 `parentId` 链重建树，`MindmapActions` 挂在 `CanvasController` 上做增删改，`MindmapSyncController` 监听画布自动 re-layout。
- mindmap 的唯一外部硬依赖是 `mindmap_node_builder.dart` 里的 `url_launcher`（打开节点链接），需抽象掉。

### 已确认的死代码（迁移时丢弃）

example/lib/mindmap 里的旧"组件模式"实现，内部无互相引用、外部无引用：
- `mindmap_widget.dart`、`mindmap_controller.dart`、`mindmap_data.dart`、`mindmap_builder.dart`
- `mindmap_connection_painter.dart`（v1，已被 `_v2` 取代）

活跃代码（迁移）是"非组件模式"那一套：`mindmap_node` / `mindmap_node_data` / `mindmap_node_metrics` / `mindmap_theme` / `mindmap_tree` / `mindmap_layout` / `mindmap_layout_engine` / `mindmap_actions` / `mindmap_sync_controller` / `mindmap_drag_session` / `mindmap_connection_layer` / `mindmap_connection_painter_v2` / `mindmap_node_widget` / `mindmap_textfield` / `mindmap_node_builder`。

## 目标目录结构

遵循 Flutter 包惯例：`lib/` 下只放 barrel 入口，实现统一收在 `lib/src/`，用子目录划分模块。

```
lib/
  wenz_draw.dart              # 内核 barrel（现有，export src/ 内核目录）
  wenz_draw_mindmap.dart      # 新增：思维导图 barrel（可选引入）
  wenz_draw_ui.dart           # 新增：UI 套件 barrel（可选引入）
  src/
    ├── canvas/               # ─┐
    ├── elements/             #  │
    ├── history/              #  │ 现有内核，不动
    ├── infinite_canvas/      #  │
    ├── layers/               #  │
    ├── rendering/            #  │
    ├── routing/              #  │
    ├── serialization/        #  │
    ├── snap/                 #  │
    ├── stencils/             #  │
    ├── tools/                #  │
    ├── utils/                #  │
    ├── widgets/              # ─┘
    │
    ├── mindmap/              # 新增：思维导图模块（从 example/lib/mindmap 搬入）
    │   ├── data/             #   node / node_data / node_metrics / theme / side
    │   ├── tree/             #   tree builder / layout / layout_engine
    │   ├── actions/          #   actions / sync_controller / drag_session
    │   ├── rendering/        #   connection_layer / connection_painter_v2
    │   ├── widgets/          #   node_widget / textfield / node_builder
    │   └── mindmap_module.dart  # registerMindmapModule() 入口
    │
    └── ui/                   # 新增：UI 套件（从 example/lib/components 搬入）
        ├── editor/           #   WenzDrawEditor + EditorConfig
        ├── panels/           #   left / right inspector
        ├── toolbar/          #   editor toolbar
        ├── widgets/          #   color_picker / search_box 等通用件
        └── theme/            #   editor_theme（替代 example 的 ui_colors）
```

### 依赖方向（避免循环）

```
wenz_draw_ui ──depends on──> wenz_draw (内核)
wenz_draw_mindmap ──depends on──> wenz_draw (内核)
wenz_draw_ui ──optional──> wenz_draw_mindmap   ← 右面板的 mindmap inspector section
```

右面板选中 mindmap 节点时要显示 mindmap inspector。为避免 `ui` 强依赖 `mindmap`，走"模块贡献"机制：内核提供 `InspectorSectionBuilder` 注册接口，mindmap 模块注册自己的 section，`ui` 面板遍历已注册的 section。没引入 mindmap 的业务方，右面板自然不显示那一段。

## Q1：如何把 example 代码封装进 SDK？

**不整包搬，按层拆分：**

- **纯内核能力**（思维导图引擎）→ 下沉到 `lib/src/mindmap/`，独立 barrel `wenz_draw_mindmap.dart`。
- **可复用 UI 外壳**（Toolbar / LeftShapePanel / RightInspectorPanel / CanvasStage / color_picker）→ 下沉到 `lib/src/ui/`，独立 barrel `wenz_draw_ui.dart`。带配置项，业务方可整体用，也可替换。
- **Demo 专属**（`canvas_demo_page.dart` 的示例图、`_addStickyNote` 等业务回调）→ 留在 example，作为接入示范。

三个 barrel 分工，让只想用内核、自己写 UI 的业务方不被强制引入 Widget。

## Q2：如何确定数据格式？

当前已是 `CanvasDocument` → JSON，结构清晰，**不推倒重来，而是加字段 + 版本迁移**。补齐成完整文档格式（向后兼容）：

```json
{
  "schemaVersion": "2.0",
  "metadata": { "title","createdAt","updatedAt","appId","appVersion" },
  "viewport": { "scale","offsetX","offsetY" },
  "assets": [
    { "id":"asset-1","type":"image","source":"base64|file|url","ref":"...","width":...,"height":... }
  ],
  "layers": [ ... ],
  "elements": [
    { "type":"image","assetId":"asset-1","rect":{...}, ... }
  ]
}
```

配套：
- **`DocumentMigrator` 迁移管线**：`1.0 → 1.1 → 2.0`，老文档自动升级。
- **`UnknownElement` 保留**：未知 type 原样存 `Map`，round-trip 不丢数据。
- **assets 抽离**：`ImageElement` 改存 `assetId`（保留 base64 作为 source 的一种），图片可来自 URL/文件/base64 三种来源。

## Q3：如何自定义图片组件加载器？

当前最大功能缺口。设计 `ImageLoader` 抽象 + 注册表，挂在 `CanvasController` 上：

```dart
abstract class ImageLoader {
  bool supports(ImageSource source);
  Future<ui.Image> load(ImageSource source);
}

class ImageSource {
  final String? assetId;   // 指向 CanvasDocument.assets 条目
  final String? url;
  final String? filePath;
  final String? base64;
  final double? maxWidth;  // 可选下采样上限
}
```

接入点：
- `CanvasController` 持有 `ImageLoaderRegistry`（默认装 `Base64ImageLoader` + `NetworkImageLoader`）。
- `InfiniteCanvasWidget` 维护 `Map<elementId, ui.Image>` 解码缓存，对 `image==null` 的 `ImageElement` 异步解码后重绘。
- **业务方自定义**：实现 `MyImageLoader extends ImageLoader`，`controller.imageLoaders.register('oss', myLoader)`，asset ref 里 `type:'oss'`。

example 的 `image_importer.dart`（依赖 `file_selector`）不进 SDK，作为"本地文件 ImageLoader + 录入入口"的示例保留在 example。

## Q4：如何自定义面板、工具栏？

给 UI 套件引入插槽 + 配置机制，三个层面：

**层面 A：配置开关（零代码）**

```dart
WenzDrawEditor(
  controller: controller,
  config: EditorConfig(
    showLeftPanel: true,
    showRightPanel: true,
    toolbarItems: EditorToolbarItems.standard,  // .minimal / 自定义集合
    leftPanelSections: [PaletteSection.shapes, PaletteSection.flowchart],
  ),
)
```

**层面 B：插槽替换（给 Widget）**

```dart
WenzDrawEditor(
  controller: controller,
  leftPanelBuilder: (ctx, controller) => MyOwnPalette(controller),
  rightPanelBuilder: null,                      // 用默认
  toolbarTrailing: [MyExportButton()],          // 工具栏尾部追加
)
```

**层面 C：内核扩展点（已存在）**
- 自定义图形 → `ElementRendererRegistry.register`
- 自定义工具 → `controller.toolManager.registerTool`
- 自定义交互组件 → `WidgetElementRegistry.register`

## 分阶段计划

### Phase 0 — 稳定基线 ⏱️1-2 天 ✅

目标：让示例和 SDK 回到可信状态，后续改动靠测试把关。

- 跑 `flutter analyze`、`flutter test` 确认当前失败项。
- 修复 example widget_test 导入错误（从 `main.dart` 导入 `WenzDrawExampleApp` 解析失败）。
- 修复 `CanvasWidgetElement` 角点缩放被当作移动的问题。
- **验收**：`flutter test` 全绿，`flutter analyze` 无 error。

### Phase 1 — 图片加载器 ⏱️2-3 天 ✅

解决最大缺口：消灭"加载 JSON 后图片变灰框"。

- 新增 `ImageLoader` 抽象 + `ImageLoaderRegistry`（base64/network/file 三种内置实现）。
- `ImageElement` 增加 `assetId` / `url` / `filePath` 字段（保留 `imageData` 向后兼容）。
- `InfiniteCanvasWidget` 增加图片异步解码 + 缓存。
- example 的 `image_importer.dart` 改造成"本地文件 ImageLoader"示范。
- **验收**：保存→重新加载 JSON，图片正确显示；自定义 loader 能接管 OSS 来源。

### Phase 2 — 文档格式硬化 ⏱️2-3 天 ✅

让保存/加载适合真实业务文档。

- `CanvasDocument` 增加 `schemaVersion`/`metadata`/`viewport`/`assets`。
- `DocumentMigrator` 迁移管线（1.0→1.1→2.0）。
- `UnknownElement` 保留机制，序列化器不再静默降级。
- **验收**：老文档可加载升级；未知元素 round-trip 不丢数据；图片资产保存恢复稳定。

### Phase 3 — mindmap 模块迁移 ⏱️3-4 天 ✅

把思维导图从 example 下沉进 SDK，作为可选模块。

1. 确认并清理死代码（旧"组件模式"4 文件 + v1 connection painter）。
2. `example/lib/mindmap/` → `lib/src/mindmap/`，按 data/tree/actions/rendering/widgets 分目录，调整 import 路径。
3. 抽象 `MindmapLinkOpener`，移除 `url_launcher` 硬依赖：
   ```dart
   abstract class MindmapLinkOpener {
     Future<bool> open(Uri url);
   }
   ```
   `registerMindmapModule` 接收 `linkOpener`，example 侧实现 `UrlLauncherLinkOpener` 注入。
4. 新增 `registerMindmapModule()` + `lib/wenz_draw_mindmap.dart` barrel 入口。
5. example 改为调用 `registerMindmapModule(linkOpener: UrlLauncherLinkOpener())`。
6. 补 mindmap 单元测试（数据 round-trip、layout、drop target 计算）。
- **验收**：example 思维导图功能 100% 还原；SDK 不依赖 `url_launcher`；不需要 mindmap 的业务方不引入该模块。

### Phase 4 — UI 套件产品化 ⏱️4-5 天 ✅

把工具栏/左右面板搬进 SDK，做成开箱即用且可配置的编辑器。

- `example/lib/components/{toolbar,left_panel,right_panel,canvas_stage,color_picker,common}` → `lib/src/ui/`。
- `theme/ui_colors.dart` → `EditorTheme` 可配置。
- 新增 `WenzDrawEditor`（组装件）+ `EditorConfig`（开关 + 插槽，即 Q4 层面 A/B）。
- 新增 `lib/wenz_draw_ui.dart` barrel。
- 内核提供 `InspectorSectionBuilder` 注册接口；右面板硬编码的 mindmap inspector 改为 mindmap 模块贡献的 section，避免 `ui` 反向依赖 `mindmap`。
- example 瘦身为 `WenzDrawEditor` 的薄封装 + 业务定制示范。
- **验收**：业务方 <10 行代码嵌入完整编辑器；能替换任一面板；能配置工具栏项。

### Phase 5 — 文档与测试收尾 ⏱️1-2 天 ✅

- 完善 `docs/extension_api.md`：补图片加载器、面板插槽、文档格式、mindmap 模块四节。
- README 增加"快速嵌入编辑器"和"自定义 UI"两段示例。
- 补 SDK 测试：图片加载器、文档迁移、未知元素保留。
- **验收**：文档自洽，新业务方照文档即可接入。

**总工期 ~13-19 天。**
