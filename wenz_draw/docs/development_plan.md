# wenz_draw 模块闭环开发方案

> 制定日期：2026-06-17
> 适用范围：`wenz_draw` SDK + example，以及与 `wenzflow` 的集成。
> 前置状态：`sdk_packaging_plan.md` 中 Phase 0–5 已全部完成（内核 + mindmap 模块 + UI 套件三个 barrel 已就绪）。

本方案针对六个核心问题，给出分阶段、可验收、文件级到点的开发路线。每一阶段都标注**目标**、**任务清单（含相关文件）**、**验收标准**，便于排期与回归。

---

## 0. 现状速览（决策依据）

### wenz_draw 当前能力
- **三个 barrel**：`wenz_draw.dart`（内核）、`wenz_draw_mindmap.dart`（思维导图，可选）、`wenz_draw_ui.dart`（编辑器 UI 套件，可选）。
- **内核**：无限画布、元素体系（rect/ellipse/line/path/text/image/polyline/curve/arrow/drawio_shape/widget/unknown）、工具（pen/line/rect/ellipse/select/arrow/text/eraser/highlighter/curve/polyline/shape/pan）、图层、历史、四叉树、序列化、PNG/SVG 导出、minimap。
- **stencil 体系**：已有 `basic / arrow / flowchart / bpmn` 四套图元库，通过 `ShapeDefinitionRegistry` 注册；drawio 形状（rhombus/hexagon/cylinder/actor/swimlane/note/cube…）通过 `DrawioShapeAdapter.fromStyleString` 接入。
- **文档格式**：`CanvasDocument` schema 2.0（metadata/viewport/assets/layers/elements/extras），`DocumentMigrator` 负责老版本升级，`UnknownElement` 保留未知类型，round-trip 不丢数据。
- **图片加载**：`ImageLoader` 抽象 + `ImageLoaderRegistry`（base64/network/file 内置），`CanvasImageResolver` 自动重解码。
- **mindmap 模块**：节点是 `widgetType=='mindmap_node'` 的 `CanvasWidgetElement`，靠 `parentId` 链重建树，`MindmapActions` 做增删改，`MindmapSyncController` 监听画布自动 re-layout，`MindmapLinkOpener` 抽象掉 `url_launcher` 硬依赖。
- **UI 套件**：`WenzDrawEditor`（组装件）+ `EditorConfig`（开关 + 插槽：leftPanelBuilder/rightPanelBuilder/toolbarBuilder）+ `InspectorSectionRegistry`（模块贡献右侧 inspector section）。

### wenzflow 当前集成现状（关键！）
- wenzflow **已通过 `wenz_mindmap` 独立包**（`D:\project\GitHub\wenz_flutter\wenz_mindmap`）集成思维导图，而非 wenz_draw。两者数据模型**不互通**：
  - `wenz_mindmap`：`MindDocument` / `MindNodeInfo` / `MindMapController`（DMindMapController）。
  - `wenz_draw` 的 mindmap 模块：`CanvasWidgetElement`（widgetType='mindmap_node'）+ `MindmapActions` + `MindmapSyncController`。
- wenzflow 的笔记通过 `NoteItemProvider`（`noteContent` 是 JSON 字符串）加载/保存，`NoteType` 区分 `richtext` / `mindmap` / `mind`，`NoteTypeConverter` 做双向转换。
- wenzflow AI 能力：`ChatFunctions` 聚合 `Note/Task/Doc/Nav/Fs/Project` 六大模块的 `FunctionDefinition`，通过 `executeFunction` 路由执行；`ContextService` 收集当前界面上下文注入 prompt。

> **结论**：wenz_draw 要接入 wenzflow，本质是新增一种**笔记类型 `drawboard`（或复用 richtext 通道）**，把 `CanvasDocument.toJson()` 作为 noteContent 存储，用 `WenzDrawEditor` 作为编辑视图。这与现有 `wenz_mindmap` 集成模式高度同构，可复用 `NoteItemProvider` 抽象。

---

## 阶段总览

> **AI 接入暂缓**：本期先完成画布闭环、格式、元素库、wenzflow 系统集成等"非 AI"能力。AI（Q4）相关任务整体后置为**后续阶段（Phase G）**，待前置能力稳定后再排期。

| 阶段 | 主题 | 对应问题 | 工期 |
|------|------|----------|------|
| Phase A | SDK 闭环（保存/加载/导出打通） | Q1（闭环） | 2–3 天 |
| Phase B | 无限画布能力补强与接入文档 | Q2（无限画布） | 2–3 天 |
| Phase C | 数据格式硬化与校验 | Q3（格式正确） | 2–3 天 |
| Phase D | 自定义元素库（流程图/甘特/用例/UML/ER/笔记卡） | Q5（自定义元素） | 6–8 天 |
| Phase F | wenzflow 系统集成（笔记类型 + Provider + 互转 + 搜索） | Q6（接入 wenzflow） | 3.5–4 天 |
| ~~Phase G~~（后续） | AI 能力接入（SDK 侧 + wenzflow 侧） | Q4（AI 功能） | 暂缓 |

**本期总工期 ~16–21 天**。阶段间有依赖：A→C（格式）、B 与 D 并行、F 依赖 A+C。

---

## Phase A — SDK 闭环（Q1：如何闭环 wenz_draw 模块）

### 目标
让"新建 → 编辑 → 保存 → 关闭 → 重新打开 → 继续编辑 → 导出"形成完整闭环，且 example 演示该闭环。当前 example 只演示了"编辑 + 内嵌"，缺**保存到文件 / 从文件加载 / 导出**的串联。

### 任务清单

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| A-1 | example 顶部工具栏增加"保存到 JSON 文件 / 从 JSON 加载 / 导出 PNG / 导出 SVG / 清空"按钮组 | `example/lib/pages/canvas_demo_page.dart`、`lib/src/ui/editor/editor_actions.dart` |
| A-2 | 抽象 `DocumentStore` 接口（`save(String json)` / `Future<String?> load()`），example 用本地文件实现，wenzflow 用 NoteProvider 实现 | 新增 `lib/src/serialization/document_store.dart` |
| A-3 | `CanvasController` 增加 `loadDocument(CanvasDocument doc)`：清空 + 重放 layers/elements + 恢复 viewport（`InfiniteCanvasController.applyViewport`） | `lib/src/canvas/canvas_controller.dart`、`lib/src/infinite_canvas/infinite_canvas_controller.dart` |
| A-4 | viewport 持久化：编辑时记录当前 viewport，保存时写入 `CanvasDocument.viewport`，加载时由 `InfiniteCanvasController` 应用 | `lib/src/infinite_canvas/infinite_canvas_controller.dart`、`lib/src/serialization/canvas_serializer.dart` |
| A-5 | 闭环冒烟测试：构造文档 → toJson → fromJson → 重新渲染 → 比对元素数/类型/坐标/viewport | 新增 `test/roundtrip_closure_test.dart` |
| A-6 | `EditorContentCallbacks` 增加 `onSaveDocument` / `onLoadDocument` 回调，UI 套件默认隐藏，由宿主提供 | `lib/src/ui/editor/editor_config.dart` |

### 验收
- example 点"保存"→选路径→文件写入；点"加载"→选同一文件→画布 100% 还原（含图层、元素、viewport、图片）。
- `flutter test test/roundtrip_closure_test.dart` 全绿。
- `flutter analyze` 无 error。

---

## Phase B — 无限画布能力补强（Q2：如何集成无限画布）

### 目标
无限画布内核已具备（pan/zoom/网格/四叉树裁剪/minimap），但**对宿主的"如何嵌入"文档和最小化接入路径不完整**。本阶段把内核做成"5 行代码嵌入、按需裁剪"的形态，并补齐移动端手势与性能护栏。

### 任务清单

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| B-1 | 最小化嵌入示例：仅内核，无 UI 套件（`InfiniteCanvasWidget` + 5 行）写入 example 与 README | `example/lib/pages/minimal_canvas_page.dart`（新增）、`README.md` |
| B-2 | `InfiniteCanvasConfig` 暴露可配置项：`minScale/maxScale`、`flingDecayFactor`、`doubleTapZoomFactor`、`enablePinch`、`enableWheel`、`enableKeyboard` | `lib/src/infinite_canvas/infinite_canvas_config.dart` |
| B-3 | 移动端手势完善：双指捏合缩放阈值、fling 惯性、避免与子 Widget 手势冲突的 `HitTestBehavior` 策略 | `lib/src/infinite_canvas/infinite_canvas_widget.dart` |
| B-4 | 性能护栏：大文档（>2000 元素）自动关闭实时选区重绘、`RepaintBoundary` 分层、四叉树懒重建 | `lib/src/canvas/spatial_index.dart`、`lib/src/rendering/viewport_culling.dart` |
| B-5 | `ZoomControls` 与 `MinimapWidget` 暴露为可独立嵌入的 Widget，文档化 | `lib/src/infinite_canvas/zoom_controls.dart`、`lib/src/infinite_canvas/minimap_widget.dart` |
| B-6 | 嵌入文档章节："Headless kernel"、"Embedded editor"、"Mobile gestures" | `docs/extension_api.md` |

### 验收
- 移动端/桌面端均能流畅 pan/zoom，2000 元素文档交互 ≥30fps（profile 模式抽样）。
- README 新增"Headless 内核嵌入"代码块可直接复制运行。
- `flutter analyze` 无 error。

---

## Phase C — 数据格式硬化与校验（Q3：如何确保格式正确）

### 目标
`CanvasDocument` schema 2.0 已成型，但缺**写入校验**和**加载容错**。本阶段让格式"写出去一定合法、读进来一定不崩"。

### 任务清单

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| C-1 | `CanvasSerializer.toJson` 增加 schema 校验：必填字段（id/rect）、枚举值（type ∈ 已注册集合）、数值范围（rect 非负、scale>0），非法抛 `DocumentFormatException` | `lib/src/serialization/canvas_serializer.dart` |
| C-2 | 新增 `DocumentFormatException`，区分 `fatal`（无法加载）/ `recoverable`（跳过坏元素并继续） | 新增 `lib/src/serialization/document_format_exception.dart` |
| C-3 | 加载容错：单元素反序列化失败 → 降级为 `UnknownElement`（保留原 JSON）+ 告警回调，不中断整文档加载 | `lib/src/serialization/canvas_serializer.dart`、`lib/src/elements/unknown_element.dart` |
| C-4 | `DocumentMigrator` 补齐 1.0 → 2.0 全路径单测，覆盖老格式（`version` 字段、无 `schemaVersion`、缺 `assets`） | `lib/src/serialization/document_migrator.dart`、`test/document_migrator_test.dart` |
| C-5 | JSON Schema 文件（`docs/canvas_document.schema.json`）作为宿主侧校验参考，CI 校验示例文档符合 | 新增 `docs/canvas_document.schema.json` |
| C-6 | round-trip 全量测试矩阵：每种元素类型 × (新增/编辑/删除/移动/缩放) × (保存/加载) | `test/serialization_test.dart`（扩充） |

### 验收
- 构造含坏元素（rect 为负、type 未知、id 缺失）的 JSON，加载后画布正常渲染合法元素，坏元素保留为 `UnknownElement`，不抛未捕获异常。
- JSON Schema 文件可被 `ajv` 等工具校验示例文档通过。
- 全量 round-trip 测试矩阵全绿。

---

## Phase D — 自定义元素库（Q5：插入常见自定义元素）

### 目标
提供**开箱即用**的高级图元库：流程图、甘特图、思维导图（已有）、笔记/文档卡片、用例图、UML 类图/时序图、ER 图。统一走 SDK 扩展点（`ElementRendererRegistry` / `WidgetElementRegistry` / `StencilLibraryRegistry`），宿主一行注册即可。

### 子阶段

### Phase D1 — 流程图套件完善（1 天）
> 流程图 stencil 已有，需补**连线智能路由 + 模板一键插入**。

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D1-1 | 流程图模板：开始/判断/处理/结束/并行的预设组合，`StencilLibraryRegistry.registerTemplate(...)` | `lib/src/stencils/libraries/flowchart_stencils.dart`、`lib/src/stencils/libraries/stencil_library_registry.dart` |
| D1-2 | 连线智能吸附：`OrthConnector` + 节点 `ShapeConnectionPoints` 自动连接，左面板拖出节点时显示吸附锚点 | `lib/src/routing/orth_connector.dart`、`lib/src/elements/shape_connection_points.dart` |
| D1-3 | 左侧面板"流程图"分区，拖拽到画布生成元素 | `lib/src/ui/panels/left_shape_panel.dart`、`lib/src/ui/panels/shape_palette_data.dart` |

### Phase D2 — 甘特图元素（1.5 天）
> 甘特图是时间轴 + 任务条，适合用 `CanvasWidgetElement` 承载交互（拖动改期）。

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D2-1 | `GanttChartElement`（CanvasWidgetElement，widgetType='gantt_chart'）：任务列表、起止日期、依赖线，存于 `widgetData` | 新增 `lib/src/widgets/elements/gantt/gantt_element.dart`、`gantt_widget.dart` |
| D2-2 | `GanttWidgetBuilder` 渲染：时间轴、任务行、进度条、依赖箭头，支持点击编辑日期 | 新增 `lib/src/widgets/elements/gantt/gantt_widget_builder.dart` |
| D2-3 | 甘特图 inspector section（`InspectorSectionBuilder`）：增删任务、改日期/进度 | 新增 `lib/src/widgets/elements/gantt/gantt_inspector.dart` |
| D2-4 | 导出占位：PNG/SVG 渲染甘特图为静态矩形（`WidgetElement` 占位机制已有） | `lib/src/serialization/exporters/png_exporter.dart`、`svg_exporter.dart` |

### Phase D3 — 笔记/文档卡片元素（1 天）
> 复用现有 sticky note 模式，做成富文本卡片，支持 markdown。

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D3-1 | `NoteCardElement`（CanvasWidgetElement，widgetType='note_card'）：title + body（markdown）+ color | 新增 `lib/src/widgets/elements/note_card/note_card_element.dart` |
| D3-2 | `NoteCardWidgetBuilder`：渲染 markdown，双击进入编辑（TextField/markdown 编辑器） | 新增 `lib/src/widgets/elements/note_card/note_card_widget_builder.dart` |
| D3-3 | 笔记卡 inspector：颜色、字号、折叠态 | 新增 `lib/src/widgets/elements/note_card/note_card_inspector.dart` |

### Phase D4 — 用例图元素（1 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D4-1 | 用例图 stencil：Actor（已有 drawio actor）、UseCase（椭圆）、System Boundary（矩形框）、`<<include>>`/`<<extend>>` 虚线箭头 | 新增 `lib/src/stencils/libraries/usecase_stencils.dart` |
| D4-2 | `StencilLibraryRegistry.registerXmlDefinitions` 注册，左面板分区 | `lib/src/stencils/libraries/stencil_library_registry.dart`、`lib/src/ui/panels/shape_palette_data.dart` |

### Phase D5 — UML 类图 / 时序图（1.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D5-1 | UML 类图 stencil：三段式类框（类名/属性/方法），分隔线；继承/聚合/组合箭头（实线空心三角/实线实心菱形/虚线） | 新增 `lib/src/stencils/libraries/uml_stencils.dart` |
| D5-2 | 时序图 stencil：生命线（垂直虚线）、激活条、同步/异步消息箭头、自调用 | `lib/src/stencils/libraries/uml_stencils.dart`（同文件） |
| D5-3 | UML 箭头端点 marker（`ArrowElement` 的 `endMarker` 扩展空心三角/菱形） | `lib/src/elements/arrow_element.dart` |

### Phase D6 — ER 图元素（1 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D6-1 | ER 图 stencil：实体框（表名 + 字段列表）、弱实体、属性椭圆 | 新增 `lib/src/stencils/libraries/er_stencils.dart` |
| D6-2 | 关系连线：1:1 / 1:N / N:M 鸦爪标记（crow's foot），扩展 `ArrowElement` 的端点 marker | `lib/src/elements/arrow_element.dart`、`lib/src/stencils/libraries/er_stencils.dart` |
| D6-3 | ER inspector：增删字段、设主键、改关系基数 | 新增 `lib/src/stencils/libraries/er_inspector.dart` |

### Phase D7 — 元素库统一注册入口（0.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| D7-1 | `registerDiagramModules()` 一行注册所有图元库（类似 mindmap 的 `registerMindmapModule`），放在可选 barrel `wenz_draw_diagrams.dart` | 新增 `lib/wenz_draw_diagrams.dart`、`lib/src/diagrams/diagram_module.dart` |
| D7-2 | 左面板"图元库"导航：基础/流程图/用例/UML/ER/甘特/笔记，可切换 | `lib/src/ui/panels/left_shape_panel.dart` |

### 验收
- 每种图元：拖入画布 → 编辑（文字/属性）→ 连线 → 保存 → 加载 → 导出 PNG/SVG，全链路通过。
- `registerDiagramModules()` 后左面板出现全部分区；不调用则不引入。
- 每类图元至少 1 个单测（序列化 round-trip + 渲染快照）。

---

## Phase E — AI 能力接入（Q4：如何集成 AI 功能）

> ⛔ **本期暂缓**。AI 接入在前置能力（闭环、格式、元素库、wenzflow 集成）稳定后再启动。本节保留设计草案，供后续排期参考。

### 目标（后续）
分两层：
1. **SDK 内核层**：提供 AI 可调用的"画布操作函数"和"上下文提取"，让 AI 能读/写画布。
2. **宿主层**：wenzflow 把画布函数注册进 `ChatFunctions`，AI 在对话中创建/修改图。

### 设计原则
- **SDK 不依赖任何 AI 库**：只暴露纯 Dart 接口（`CanvasAiFunctions`），由宿主桥接到 wenzflow 的 `FunctionDefinition`。
- 复用 wenzflow 现有 AI 架构（`ChatFunctions` 聚合 + `ContextService` 上下文 + provider 层 OpenAI/Claude）。

### 任务清单

| 编号 | 任务 | 相关文件 |
|------|------|----------|
| E-1 | `CanvasContextExtractor`：把当前画布转成 AI 可读文本（元素清单、坐标、连线、文本内容、缩略 markdown 大纲），支持 token 预算裁剪 | 新增 `lib/src/ai/canvas_context_extractor.dart` |
| E-2 | `CanvasAiFunctions` 纯 Dart 接口：`addElement(json)` / `removeElement(id)` / `updateElement(id, patch)` / `connect(fromId, toId, style)` / `applyTemplate(name, at)` / `layoutAuto()` / `exportAs(format)` | 新增 `lib/src/ai/canvas_ai_functions.dart` |
| E-3 | `CanvasPromptTemplates`：内置 prompt 模板（"根据描述生成流程图"→输出元素 JSON、"优化布局"→重排），AI 返回结构化 JSON 由 `CanvasAiFunctions` 应用 | 新增 `lib/src/ai/canvas_prompt_templates.dart` |
| E-4 | 流式应用：AI 返回增量元素 JSON 时，`CanvasController` 批量事务（`BatchCommand`）避免多次撤销步骤 | `lib/src/history/commands/batch_command.dart` |
| E-5 | AI 操作历史隔离：`HistoryManager` 支持 `label` 分组，AI 批量操作作为单个"AI 生成"撤销点 | `lib/src/history/history_manager.dart` |
| E-6 | example 接入示范：简易 AI 输入框（输入"画一个登录流程图"→调用 mock/template → 生成元素） | `example/lib/pages/ai_demo_page.dart`（新增） |

### wenzflow 侧桥接（Phase F 一并做）

### 验收
- example AI 输入"画一个登录流程"→ 画布出现 开始→输入账号→验证→（成功→主页 / 失败→重试）→结束 的流程图。
- 撤销一次可回退整次 AI 生成。
- `CanvasContextExtractor` 输出的 markdown 大纲人类可读。

---

## Phase F — wenzflow 系统集成（Q6：如何像思维导图那样接入 wenzflow）

### 目标
参照 wenzflow 现有 `wenz_mindmap` 集成模式，把 wenz_draw 作为**第四种笔记类型 `drawboard`** 接入。**本期不含 AI 函数注册**（见 Phase G 后置）。

### 集成架构（与 mindmap 同构）

```
wenzflow NoteItemProvider
   ├── richtext  → wenz_editor
   ├── mindmap   → wenz_mindmap (MindDocument JSON)
   └── drawboard → wenz_draw   (CanvasDocument JSON)  ← 新增
                    └── WenzDrawEditor 作为编辑视图
```

### 任务清单

#### F1 — 包依赖与笔记类型注册（0.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| F1-1 | wenzflow `pubspec.yaml` 增加 `wenz_draw`（git path：`wenz_flutter/wenz_draw`） | `wenzflow_flutter/pubspec.yaml` |
| F1-2 | `NoteType` 增加 `drawboard = 'drawboard'`；`NoteTypeConverter` 增加 `drawboard ↔ richtext` / `drawboard ↔ mindmap` 转换（画布元素 ↔ 大纲） | `lib/utils/note/note_type_converter.dart` |

#### F2 — DrawboardProvider + 编辑视图（1.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| F2-1 | `DrawboardNoteProvider extends NoteItemProvider`：`noteContent` 存 `CanvasDocument.toJson()` 字符串，`fetchContent`/`saveNote` 走 wenzflow note service | 新增 `lib/widgets/editor/provider/drawboard_note_provider.dart` |
| F2-2 | `DrawboardContentController`（参照 `WenzMindContentController`）：持有 `CanvasController` + `InfiniteCanvasController`，`refresh()` 加载文档，`onChanged` 触发 `saveCache` | 新增 `lib/widgets/editor/drawboard/controller.dart` |
| F2-3 | `DrawboardContentView`：嵌入 `WenzDrawEditor`，顶部浮动工具栏（保存/导出/转思维导图/转富文本）复用 mindmap 的 `splitLayoutController` 模式 | 新增 `lib/widgets/editor/drawboard/view.dart`、`mobile_view.dart` |
| F2-4 | 路由注册：`go_router` 增加 drawboard 笔记路由，笔记卡片点击按 `noteType` 分流到对应视图 | `lib/route/`、`lib/view/desktop/note/card/` |

#### F3 — 复用 wenzflow 文件管理（1 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| F3-1 | 实现 `WenzFlowImageLoader extends ImageLoader`：`source='url'` 时走 `WenzWebAssetsFileManager`（OSS/CDN），`source='oss'` 自定义 key | 新增 `lib/widgets/editor/drawboard/wenzflow_image_loader.dart`；参考 `lib/src/canvas/image_loader.dart` |
| F3-2 | 图片插入回调：`EditorContentCallbacks.onInsertImage` 走 wenzflow 的图片选择 + 上传 + 返回 URL | `lib/widgets/editor/drawboard/controller.dart` |
| F3-3 | 链接打开：`MindmapLinkOpener` 实现 wenzflow 版（复用 `UrlLauncherLinkOpener` 或 wenzflow 内部导航） | `lib/widgets/editor/drawboard/wenzflow_link_opener.dart` |

#### F5 — 类型互转与迁移（0.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| F5-1 | `NoteTypeConverter.drawboardToMindMap`：画布元素树 → `MindDocument`（思维导图根节点 = 画布标题，子节点 = 元素 label 按连线关系） | `lib/utils/note/note_type_converter.dart` |
| F5-2 | `NoteTypeConverter.mindMapToDrawboard`：思维导图 → 画布（节点 → 矩形/椭圆，父子关系 → 连线，自动布局） | `lib/utils/note/note_type_converter.dart` |
| F5-3 | 笔记卡片"转换类型"菜单增加 drawboard 选项 | `lib/view/desktop/note/card/mindmap_card.dart`、`note_card.dart` |

#### F6 — 搜索与导航（0.5 天）
| 编号 | 任务 | 相关文件 |
|------|------|----------|
| F6-1 | drawboard 笔记全文索引：`CanvasContextExtractor`（**注意：该类原属 Phase E，本期改为 F6 内联提供一个简易 `DrawboardTextExtractor`，不引入 AI 模块依赖**）提取文本 → 写入笔记 `textContent`（供 `searchService` 检索，复用 mindmap 的 `_generateMindNote` 模式） | `lib/widgets/editor/drawboard/controller.dart`、新增 `lib/widgets/editor/drawboard/drawboard_text_extractor.dart` |
| F6-2 | 全局搜索结果点击 → 打开 drawboard → 定位到对应元素（`InfiniteCanvasController.centerOnRect`） | `lib/view/desktop/global/search/view.dart`、`lib/widgets/editor/drawboard/controller.dart` |

### 验收
- wenzflow 新建笔记 → 选"画板"类型 → 打开 `WenzDrawEditor` → 编辑 → 自动保存 → 关闭重开还原。
- 画板里的图片走 wenzflow OSS，关闭重开图片正常显示。
- 画板 ↔ 思维导图 ↔ 富文本可互转，内容不丢主体结构。
- 全局搜索能命中画板内文字，点击跳转定位。
- **AI 生成/修改元素不在本期验收范围**（Phase G）。

---

## 依赖与排期建议

```
Phase A (闭环) ──→ Phase C (格式硬化) ──┐
                                         ├─→ Phase F (wenzflow 集成)
Phase B (无限画布) ─┐                    
                   └─→ 可与 D 并行       
Phase D (元素库) ───┘                    
```

- **Week 1**：A（闭环）+ B（无限画布）并行
- **Week 2**：C（格式硬化）+ D1–D3（流程图/甘特/笔记卡）
- **Week 3**：D4–D7（用例/UML/ER/统一注册）
- **Week 4**：F（wenzflow 集成，依赖 A/C 交付）
- **后续**：G（AI 接入，暂缓）

每个阶段完成后跑 `flutter analyze` + `flutter test`，阶段验收清单逐项打勾方可进入下一阶段。

---

## Phase G — AI 能力接入（Q4，暂缓/后续）

> ⛔ **本期不实施**。待 A/B/C/D/F 稳定后排期。以下为设计备忘，避免后续重新勘察。

启动时需：
1. 落地 Phase E 的 `CanvasContextExtractor` / `CanvasAiFunctions` / `CanvasPromptTemplates`（SDK 层）。
2. 落地原 Phase F 的 F4：`DrawboardFunctions` 注册进 wenzflow `ChatFunctions`，`ContextService` 收集 drawboard 上下文。
3. example AI demo 页（`ai_demo_page.dart`）。
4. 验收：AI 对话"画一个登录流程图"→ 画布生成；撤销一次回退整次 AI 生成。

---

## 文件改动总览（新增 vs 修改）

> 本期范围对应 Phase A/B/C/D/F。**Phase G（AI）相关文件不在本期**，下列清单已剔除 AI 模块。

### wenz_draw 新增
- `lib/src/serialization/document_store.dart`
- `lib/src/serialization/document_format_exception.dart`
- `lib/src/diagrams/diagram_module.dart`
- `lib/src/widgets/elements/gantt/*.dart`
- `lib/src/widgets/elements/note_card/*.dart`
- `lib/src/stencils/libraries/{usecase,uml,er}_stencils.dart`
- `lib/wenz_draw_diagrams.dart`
- `docs/canvas_document.schema.json`
- `docs/development_plan.md`（本文档）
- `test/roundtrip_closure_test.dart` 等

### wenz_draw 修改
- `lib/src/canvas/canvas_controller.dart`（loadDocument）
- `lib/src/infinite_canvas/{infinite_canvas_controller,infinite_canvas_widget,infinite_canvas_config}.dart`
- `lib/src/serialization/{canvas_serializer,canvas_document,document_migrator}.dart`
- `lib/src/history/history_manager.dart`（label 分组）
- `lib/src/elements/arrow_element.dart`（端点 marker 扩展）
- `lib/src/ui/editor/editor_config.dart`（回调扩展）
- `lib/src/ui/panels/{left_shape_panel,shape_palette_data}.dart`
- `README.md`、`docs/extension_api.md`

### wenzflow 新增
- `lib/widgets/editor/provider/drawboard_note_provider.dart`
- `lib/widgets/editor/drawboard/{controller,view,mobile_view,wenzflow_image_loader,wenzflow_link_opener,drawboard_text_extractor}.dart`

### wenzflow 修改
- `pubspec.yaml`（加 wenz_draw 依赖）
- `lib/utils/note/note_type_converter.dart`（drawboard 类型 + 互转）
- `lib/view/desktop/note/card/*.dart`（转换菜单）
- `lib/view/desktop/global/search/view.dart`（搜索跳转）

> 注：`lib/service/ai/functions/chat_functions.dart`、`lib/service/ai/context_service.dart`、wenz_draw 的 `lib/src/ai/*.dart` 均属 Phase G，本期不动。

---

## 风险与对策

| 风险 | 对策 |
|------|------|
| wenz_draw mindmap 与 wenz_mindmap 数据模型不同，用户期望"同一份思维导图" | Phase F5 提供互转；明确两者定位差异（wenz_draw mindmap 是画布上的节点树，wenz_mindmap 是独立笔记类型） |
| 大文档性能 | Phase B4 性能护栏 + 四叉树懒重建 + RepaintBoundary |
| 移动端手势与嵌入式 Widget 冲突 | Phase B3 HitTestBehavior 策略 + 现有 `CanvasWidgetLayer` 已有 pointer 分发逻辑 |
| wenzflow 依赖 wenz_draw 后编译时间增长 | wenz_draw 保持零重依赖（仅 flutter/uuid/xml）；diagrams/mindmap 模块可选 barrel，不强制引入 |
| 加载/保存 round-trip 丢数据 | Phase C 校验 + `UnknownElement` 兜底 + 全量 round-trip 测试矩阵 |
| 搜索文本提取依赖 AI 模块（原 `CanvasContextExtractor` 属 Phase E） | Phase F6 改为内联 `DrawboardTextExtractor`，不引入 `lib/src/ai/` 依赖 |
