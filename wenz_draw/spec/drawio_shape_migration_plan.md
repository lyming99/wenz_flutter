# wenz_draw 移植 drawio 图形元素开发阶段计划

## 1. 背景与目标

参考 spec「drawio 项目图形元素实现分析」，draw.io 的图形能力不是单个 Shape 类完成的，而是由 `mxCell/mxGeometry` 数据层、`style=key=value;` 样式层、`mxCellRenderer` 渲染分发、`mxShape`/JS Shape/XML Stencil 绘制层、连接点/Perimeter/Palette 共同组成。

`wenz_draw` 当前已经具备无限画布、`CanvasElement` 抽象、`ElementRendererRegistry` 注册、基础矩形/椭圆/线条/折线/箭头/文本/图片/Widget 元素、图形内嵌文字、吸附点、连接线绑定、序列化和 SVG 导出能力。迁移 draw.io 图形元素时，应优先复用这套体系，并补齐通用 shape/stencil/style 基座，而不是为每个 draw.io 形状临时堆一个独立工具。

本计划目标：

- 在 `wenz_draw` 中建立可扩展的 draw.io 风格图形元素体系。
- 分阶段迁移 draw.io 常用内置图形：菱形、三角形、六边形、圆柱、双椭圆、Actor、云、泳道、文档、便签、平行四边形、梯形、Callout、Plus/Cross、基础立体图形等。
- 兼容 draw.io 的核心样式表达：`shape=...`、`rounded=1`、`whiteSpace=wrap`、`fillColor/strokeColor/strokeWidth`、`direction`、`arcSize`、`points` 等关键字段。
- 为后续 XML stencil 子集、draw.io 导入、图形库 palette、连接点/边界连接算法留出稳定接口。

非目标：

- 第一阶段不完整移植 draw.io 全部 AWS/Azure/GCP/Kubernetes/Cisco 等超大图标库。
- 第一阶段不实现完整 mxGraph 编辑器模型或完整 `.drawio` 双向兼容。
- 第一阶段不替换现有 `RectElement`、`EllipseElement`、`LineElement`、`PolylineElement`，而是保持向后兼容并逐步桥接。

## 2. 迁移总体策略

### 2.1 分层映射

| draw.io / mxGraph | wenz_draw 对应落点 |
|---|---|
| `mxCell.vertex` | `CanvasElement` 子类，优先新增 `DrawioShapeElement` |
| `mxGeometry` | `Rect rect`、`List<Offset> points`、label offset/bounds |
| `style=key=value;` | 新增 `DrawioStyle` / `DrawioStyleParser`，再映射到 `PaintStyle` 与 shape 参数 |
| `mxCellRenderer.defaultShapes` | 扩展 `ElementRendererRegistry`，新增 `ShapeDefinitionRegistry` |
| JS Shape `paintVertexShape` | Dart `ShapeDefinition.buildPath` / `paint` / `hitTest` |
| XML `mxStencil` | 后续新增 `StencilDefinition`、`StencilParser`、`StencilRenderer` |
| `getConstraints` / stencil `<connections>` | 扩展 `SnapResolver.pointsForElement` 与 routing perimeter |
| Sidebar palette template | 新增 shape palette/tool/example 入口 |

### 2.2 元素迁移清单

第一批 MVP 图形：

- 已有能力桥接：`rectangle`、`rounded rectangle`、`ellipse`、`line`、`text`、`image`。
- 新增内置顶点图形：`rhombus`、`triangle`、`hexagon`、`cylinder`/`cylinder3`、`doubleEllipse`、`actor`、`cloud`、`swimlane`。
- 流程图常用图形：`document`、`note`、`parallelogram`、`trapezoid`、`callout`、`process`、`manualInput`。
- 基础符号：`plus`、`cross`、`step`、`cube` 或简化 `isoRectangle`。

第二批 stencil/图形库：

- `basic.xml` 和 `flowchart.xml` 中可由 path/rect/ellipse/text 表达的静态 stencil。
- 暂不迁移依赖图片资源、复杂动态 JS、复杂外部字体/图标的图形库。

线条类元素说明：

- 线条、连接器、marker、edge routing 已有独立规格和部分实现，本计划只要求 shape 端提供稳定连接点、perimeter 和样式兼容入口。
- `filledEdge`、`pipe`、`wire`、`zigzag` 可作为后续与线条规格合并推进的扩展任务。

## 3. 开发阶段计划

### 阶段 0：基线梳理与迁移目录

目标：明确 draw.io shape 到 wenz_draw 实现的优先级、命名、样式兼容范围和测试样例。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 建立 draw.io shape 迁移目录，列出 shape key、类别、是否已有、目标实现方式、优先级 | `spec/drawio_shape_catalog.md`（新增） | 至少覆盖第一批 MVP 图形；每个 shape 有目标 element/renderer/stencil 归属；未知或延期项有明确原因 |
| 建立样例用例与视觉验收清单 | `test/fixtures/drawio_shapes/`（新增）、`example/lib/main.dart` | 每个 MVP shape 至少有一个固定尺寸样例；样例包含填充、描边、label、不同宽高比例 |
| 锁定现有基础元素行为 | `test/shape_label_test.dart`、`test/polyline_element_test.dart`、`test/snap_resolver_test.dart`、`test/routing/routing_test.dart` | 新计划开始前现有测试可通过；作为后续迁移的回归基线 |

### 阶段 1：通用 DrawioShape 数据模型与注册体系

目标：新增一个通用图形元素承载多数 draw.io 顶点形状，避免为每个静态形状复制大量 `CanvasElement` 模板代码。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 新增 `DrawioShapeElement`，包含 `id`、`shapeKey`、`rect`、`strokeStyle`、`fillStyle`、label、opacity、layerId、zIndex、shape 参数 | `lib/src/elements/drawio_shape_element.dart`（新增）、`lib/src/elements/canvas_element.dart` | 支持 `bounds`、`hitTest`、`copyWith`、`translate`、`scaleElement`、`toJson`；无 label 时行为稳定；缩放时 stroke/label 同步缩放 |
| 新增 `ShapeDefinition` / `ShapeDefinitionRegistry`，把 `shapeKey` 映射到绘制、命中、连接点和 label bounds 逻辑 | `lib/src/elements/shape_definition.dart`（新增）、`lib/src/elements/shape_definition_registry.dart`（新增） | `DrawioShapeElementRenderer` 可通过 registry 渲染不同 shape；未注册 shape 降级为矩形且不中断渲染 |
| 注册到现有渲染体系 | `lib/src/elements/element_registry.dart`、`lib/wenz_draw.dart` | `ElementRendererRegistry.ensureBuiltInsRegistered()` 自动注册 drawio shape renderer；SDK 对外导出新增类型 |
| 序列化反序列化接入 | `lib/src/serialization/canvas_serializer.dart` | JSON round-trip 后 `shapeKey`、rect、style、label、参数完整保留；旧 `rect/ellipse` JSON 不受影响 |
| 单元测试 | `test/drawio_shape_element_test.dart`（新增） | 覆盖 copy/translate/scale/bounds/hitTest/toJson/fromJson；`flutter test` 通过 |

### 阶段 2：迁移 draw.io 内置顶点 Shape MVP

目标：用 Dart `Path` 和 Flutter `Canvas` 实现 draw.io 常用 JS shape 的核心视觉效果。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 实现多边形类：`rhombus`、`triangle`、`hexagon`、`parallelogram`、`trapezoid` | `lib/src/elements/drawio_shape_definitions.dart`（新增）、`lib/src/utils/shape_path_utils.dart`（新增） | 不同宽高下路径正确闭合；填充/描边/透明度生效；stroke-only 与 fill 命中测试符合现有 `RectElement` 语义 |
| 实现曲线类：`cylinder`/`cylinder3`、`doubleEllipse`、`actor`、`cloud` | `lib/src/elements/drawio_shape_definitions.dart`、`test/drawio_shape_rendering_test.dart`（新增） | 圆柱上下椭圆比例稳定；双椭圆内圈随尺寸缩放；actor/cloud 使用 cubic path，视觉不塌陷 |
| 实现容器/复合类：`swimlane`、`document`、`note`、`callout` | `lib/src/elements/drawio_shape_definitions.dart`、`lib/src/elements/shape_label_painter.dart` | `swimlane` 有 header 区域参数；document 底部波浪可缩放；note 折角正确；callout 箭头区域进入 bounds |
| 实现基础符号：`plus`、`cross`、`step`、简化 `cube/isoRectangle` | `lib/src/elements/drawio_shape_definitions.dart` | 符号路径在小尺寸下不反转；填充和描边层次清晰 |
| 补充 SVG 导出 | `lib/src/serialization/exporters/svg_exporter.dart` | 每个新增 shape 导出为 `<path>` 或组合 SVG；颜色、strokeWidth、opacity、label 保持一致 |
| 测试覆盖 | `test/drawio_shape_rendering_test.dart`、`test/svg_exporter_test.dart`（新增） | 每个 MVP shape 至少覆盖 path 非空、bounds、序列化、SVG 输出；现有测试仍通过 |

### 阶段 3：draw.io 样式字符串兼容层

目标：支持从 draw.io 常见 `style` 字符串创建 wenz_draw 图形元素，为后续导入 `.drawio` 或 palette 模板铺路。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 新增 `DrawioStyleParser`，解析 `key=value;` 和裸 key | `lib/src/drawio/drawio_style.dart`（新增）、`lib/src/drawio/drawio_style_parser.dart`（新增） | 支持 `shape=...`、`rounded=1`、`whiteSpace=wrap`、`html=1`、`fillColor`、`strokeColor`、`strokeWidth`、`dashed`、`direction`、`arcSize`；未知字段保留在 `raw`/`extra` 中 |
| 新增 style 到 element 的适配器 | `lib/src/drawio/drawio_shape_adapter.dart`（新增） | `shape=rhombus;fillColor=#fff2cc;strokeColor=#d6b656;` 可生成 `DrawioShapeElement`；`ellipse` 可选择复用 `EllipseElement` 或统一生成 drawio shape，策略明确且测试覆盖 |
| 支持 draw.io 颜色与 none 语义 | `lib/src/drawio/drawio_color.dart`（新增）、`lib/src/canvas/paint_style.dart` | `none` 映射为空 fill/stroke；hex 颜色、透明度、strokeWidth 映射正确 |
| 单元测试 | `test/drawio_style_parser_test.dart`（新增） | 样式解析覆盖常见 draw.io 模板；非法 token 不抛异常；adapter 输出稳定 |

### 阶段 4：连接点、Perimeter 与吸附集成

目标：让新增图形可以像 draw.io 一样提供固定连接点，并让线条端点绑定后随图形移动/缩放更新。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 为 `ShapeDefinition` 增加默认连接点定义 | `lib/src/elements/shape_definition.dart`、`lib/src/elements/shape_connection_points.dart`（新增） | 矩形类默认中心、边中点、角点；菱形/三角形/六边形提供对应顶点与边中点；swimlane header/body 有可区分 anchor |
| 扩展 `SnapResolver.pointsForElement` 支持 `DrawioShapeElement` | `lib/src/snap/snap_resolver.dart` | 线条工具可吸附新增 shape；隐藏图层/锁定图层规则与现有元素一致 |
| 扩展 perimeter 计算 | `lib/src/routing/perimeter.dart`、`lib/src/routing/connector_routing.dart` | 菱形、椭圆/双椭圆、三角形、六边形、圆柱的连接线端点落在可视边界附近；正交连接线重算不穿过源/目标主体 |
| 绑定重算回归 | `lib/src/canvas/canvas_controller.dart`、`test/snap_resolver_test.dart`、`test/routing/routing_test.dart` | 新 shape 被移动后，绑定到它的 `LineElement`/`PolylineElement` 端点同步更新；现有 rect/ellipse/widget 绑定不回退 |

### 阶段 5：XML Stencil 子集与资源化图形库

目标：为 draw.io 的静态 XML stencil 建立可控子集，先支持基础 path/rect/ellipse/text/connection，不追求一次吃下全部图形库。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 新增 stencil 数据模型 | `lib/src/stencils/stencil_definition.dart`（新增）、`lib/src/stencils/stencil_command.dart`（新增） | 可表达 `shape w/h/aspect/strokewidth`、`background`、`foreground`、`connections`、基础绘制命令 |
| 新增 XML parser | `lib/src/stencils/stencil_parser.dart`（新增）、`pubspec.yaml` | 可解析 `<move>`、`<line>`、`<quad>`、`<curve>`、`<arc>`、`<close>`、`<rect>`、`<roundrect>`、`<ellipse>`、`<text>`、`<include-shape>`；若引入 XML 依赖，需要锁定版本并补测试 |
| 新增 stencil renderer | `lib/src/stencils/stencil_renderer.dart`（新增）、`lib/src/elements/shape_definition_registry.dart` | 支持 `aspect=variable/fixed` 的坐标映射；支持 `direction=north/south/east/west` 的基础旋转/换向策略 |
| 资源化基础图形库 | `lib/src/stencils/builtin_stencils.dart`（新增）或 `assets/stencils/` | 至少接入 basic/flowchart 中 10 个静态 stencil；未支持命令给出可诊断错误并降级为空占位 |
| 测试 | `test/stencil_parser_test.dart`、`test/stencil_renderer_test.dart` | XML 样例解析稳定；fixed aspect 居中缩放正确；连接点从 `<connections>` 进入 `SnapResolver` |

### 阶段 6：图形创建工具、Palette 与示例应用

目标：让业务方和 example 能实际创建这些图形，而不只是代码层可构造。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 新增通用 shape tool | `lib/src/tools/shape_tool.dart`（新增）、`lib/src/tools/tool_manager.dart`、`lib/src/canvas/canvas_controller.dart` | 工具可配置 `shapeKey`；拖拽生成对应 `DrawioShapeElement`；预览与最终元素一致 |
| 保持 Rect/Ellipse 工具兼容 | `lib/src/tools/rect_tool.dart`、`lib/src/tools/ellipse_tool.dart` | 原工具行为不变；如后续统一到 shape tool，需要保留原 `idValue` 和 API 兼容 |
| Example palette | `example/lib/main.dart`、`example/lib/` 相关 UI 文件 | 示例应用可选择并绘制 MVP shape；至少展示 basic、flowchart、container 三组 |
| 文档 | `README.md`、`docs/drawio_shapes.md`（新增） | 文档包含创建代码、支持 shape 列表、样式字符串兼容范围、延期项说明 |

### 阶段 7：导入/导出与兼容能力

目标：让新增图形进入现有文档、导出和后续 draw.io 兼容链路。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| Canvas JSON 稳定化 | `lib/src/serialization/canvas_serializer.dart`、`lib/src/serialization/canvas_document.dart` | 新图形可保存/加载；未知 `shapeKey` 不导致文档加载失败；版本字段可用于未来迁移 |
| SVG 导出完善 | `lib/src/serialization/exporters/svg_exporter.dart` | SVG 中新增 shape、label、opacity、fill/stroke、strokeWidth 与 Canvas 渲染一致；stencil shape 可导出 path |
| draw.io 样式导入原型 | `lib/src/drawio/drawio_importer.dart`（新增） | 能从简化 `mxCell` JSON/XML 抽取 `geometry/style/value` 并生成元素；至少支持 vertex 基础 shape，不要求完整 mxGraphModel |
| 测试 | `test/drawio_importer_test.dart`、`test/svg_exporter_test.dart` | 从 draw.io 常见 style 样例导入后 shapeKey/rect/label/style 正确；SVG 字符串可被基础 XML 校验解析 |

### 阶段 8：质量、性能与回归验收

目标：保证大量图形与现有无限画布能力共存，避免迁移后影响选择、吸附、移动、导出和渲染性能。

| 任务 | 相关代码文件 | 验收标准 |
|---|---|---|
| 单元与 widget 测试扩展 | `test/drawio_shape_element_test.dart`、`test/drawio_shape_rendering_test.dart`、`test/performance_widget_test.dart` | 所有新增 shape 覆盖序列化、hitTest、bounds、label、snap；`flutter test` 全量通过 |
| 性能场景 | `test/performance_widget_test.dart`、`example/lib/main.dart` | 500 个混合元素包含至少 100 个 `DrawioShapeElement` 时，平移/缩放/选择无明显卡顿；viewport culling 不回退 |
| API 稳定性检查 | `lib/wenz_draw.dart`、`CHANGELOG.md` | 新增公开类型导出完整；旧公开 API 不破坏；CHANGELOG 记录 drawio shape 支持范围 |
| 视觉验收 | `test/fixtures/drawio_shapes/`、`docs/drawio_shapes.md` | MVP shape 在固定样例中的视觉结果可人工检查；每个延期 shape 有下一阶段说明 |

## 4. 阶段里程碑

| 里程碑 | 包含阶段 | 可交付结果 |
|---|---|---|
| M1：Shape 基座可用 | 阶段 0-1 | `DrawioShapeElement`、registry、序列化、基础测试完成 |
| M2：常用图形可绘制 | 阶段 2 | 第一批 MVP shape 可在 Canvas 与 SVG 中渲染 |
| M3：draw.io style 可桥接 | 阶段 3-4 | 常见 draw.io style 字符串能生成元素，新增图形支持吸附和连接线绑定 |
| M4：Stencil 子集可运行 | 阶段 5 | 基础 XML stencil 可解析、渲染、暴露连接点 |
| M5：用户入口完整 | 阶段 6-8 | Example 可绘制图形，文档/测试/性能验收完成 |

## 5. 总体验收标准

- 功能：MVP shape 清单中的图形可创建、渲染、选择、移动、缩放、命中测试、显示 label、参与吸附、序列化、SVG 导出。
- 兼容：现有 `RectElement`、`EllipseElement`、`LineElement`、`PolylineElement`、`ArrowElement`、`TextElement`、`CanvasWidgetElement` 行为不破坏。
- 样式：draw.io 常见 style 字段可解析并映射到 wenz_draw；未知 style 不丢失且不导致异常。
- 连接：新增 shape 的固定连接点和 perimeter 能被 `SnapResolver` 与 routing 使用，绑定元素移动后连接线同步更新。
- 测试：全量 `flutter test` 通过；新增测试覆盖模型、style parser、shape rendering、stencil parser、snap/perimeter、SVG export。
- 性能：500 混合元素场景下，新增 shape 不绕过现有 culling 和层级规则，交互无明显卡顿。
- 文档：README 或 docs 中列出支持图形、使用方式、style 兼容范围、延期图形库。

## 6. 实施建议

建议先完成 M1-M2，把常用图形以 Dart 内置 shape definition 方式跑通；这能最快提升 `wenz_draw` 的图形表达能力。M3 再做 draw.io style 兼容和连接点/perimeter，因为这部分会影响导入和连接线体验。M4 的 XML stencil 子集应保持保守，只支持稳定命令，避免一次性把 draw.io 的全部 stencil 复杂度搬进 SDK。