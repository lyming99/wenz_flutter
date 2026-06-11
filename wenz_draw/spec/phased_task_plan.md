# wenz_draw 阶段性任务实施规格

## 1. 背景与目标

当前 `wenz_draw` 已完成基础绘图功能，并具备无限画布、图形元素、Widget 嵌入、图层、历史记录、序列化、导出、Minimap、ZoomControls 与示例应用能力。后续阶段目标是补齐绘图元素与 Flutter Widget 元素混合渲染、缩放自适配、自动分层、大元素量性能、文字与线条增强，以及 SDK 接入文档。

本文将阶段性任务拆解为可执行方案，明确任务列表、相关文件与验收标准，作为后续实现和验收依据。

## 2. 当前基础能力概览

- 基础绘图功能：已完成，包含路径、线条、矩形、椭圆、箭头、文本、高亮、橡皮、选择、移动、撤销/重做。
- Widget 嵌入基础：已完成 `CanvasWidgetElement`、`CanvasWidgetLayer`、`WidgetElementBuilder`、`WidgetElementRegistry` 与示例 Widget。
- 图层基础：已完成 `CanvasLayer`、`LayerManager`、图层可见性、锁定、透明度、顺序与 active layer 插入。
- 性能基础：已有 `SpatialIndex`、`QuadTree`、`ViewportCulling`、Widget snapshot 渲染模式。
- 文档基础：已有 `README.md`、`docs/extension_api.md`、`spec/custom_widget_support.md`、`spec/wenz_draw_infinite_canvas.md`。

## 3. 阶段任务方案

### 3.1 绘图与 Widget 重叠

#### 目标

保证普通绘图元素与 `CanvasWidgetElement` 在同一画布坐标系、同一图层顺序下可以正确重叠显示，并且选择、命中、移动、Widget 内部交互不会互相抢占。

#### 技术方案

当前 `CanvasWidgetLayer` 已将背景、绘图元素分段、Widget host、选择层组合在同一个 `Stack` 中，并按 layer 遍历 `_LayerMixedStack`。本阶段需要完善混合渲染规则：

- 统一图形元素与 Widget 元素的排序入口，确保 `layerIndex + zIndex` 决定绘制顺序。
- 对同一图层内的连续元素按类型切分为 paint segment 与 widget host segment，保持交错顺序。
- Widget snapshot 模式与 live 模式保持视觉一致；选中的 snapshot widget 使用 live overlay 时不改变层级表现。
- 命中测试使用相同排序规则，优先命中视觉上最上层的元素。
- 对 Widget 内部交互与画布选择/拖拽建立明确策略：点击可交互 Widget 时交给 Widget；拖动超过阈值时可提升为画布选择/移动。

#### 任务列表

- 梳理 `_LayerMixedStack`、`_MixedElementStack` 的元素切分逻辑，确认绘图与 Widget 交错顺序。
- 抽取或复用统一排序方法，避免 painter、widget layer、hitTest 三处排序规则发散。
- 修正 selected snapshot widget live overlay 的层级位置，避免选中后被强制置顶造成视觉跳变。
- 补充重叠场景测试：图形压 Widget、Widget 压图形、跨图层重叠、隐藏图层、锁定图层。
- 在 example 中增加重叠示例数据，便于人工观察。

#### 相关文件

- `lib/src/widgets/canvas_widget_layer.dart`
- `lib/src/infinite_canvas/infinite_canvas_painter.dart`
- `lib/src/infinite_canvas/infinite_canvas_widget.dart`
- `lib/src/canvas/canvas_controller.dart`
- `lib/src/canvas/element_manager.dart`
- `lib/src/layers/layer_manager.dart`
- `lib/src/elements/widget_element.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 同一图层中，`zIndex` 更高的元素显示在上层，无论该元素是绘图元素还是 Widget 元素。
- 不同图层中，上层图层元素显示在下层图层元素之上，Widget 与绘图元素行为一致。
- Widget 元素被选中、取消选中、切换 snapshot/live 时，视觉层级不发生非预期跳变。
- 点击重叠区域时，命中结果与视觉最上层元素一致。
- 可交互 Widget 内部按钮、输入框、滚动等事件可正常响应；画布选择、拖拽、平移仍可正常工作。
- 新增或更新的单元/Widget 测试通过，example 可人工验证重叠效果。

### 3.2 Widget 元素多缩放率尺寸视图自适配

#### 目标

让 `CanvasWidgetElement` 在不同缩放率下具备明确的尺寸策略，支持随画布缩放、绘制缩放、固定屏幕尺寸等模式，并保证布局、命中和快照渲染一致。

#### 技术方案

当前 `CanvasWidgetElement` 已包含 `CanvasWidgetScaleMode.layoutScale`、`paintScale`、`fixedScreenSize`。本阶段需要补齐三种模式的行为定义和边界处理：

- `layoutScale`：Widget 的布局尺寸随画布缩放变化，适合便签、卡片、表单等真实画布对象。
- `paintScale`：Widget 以世界尺寸布局后通过 Transform 缩放，适合复杂 UI 低成本缩放。
- `fixedScreenSize`：屏幕尺寸保持稳定，世界坐标位置跟随画布，适合锚点、标记、控制柄。
- 加入最小/最大屏幕尺寸约束，避免缩放极端时 Widget 过小不可交互或过大溢出。
- 确保 snapshot capture 与 live host 使用同一尺寸计算路径。

#### 任务列表

- 审查 `_CanvasWidgetHost` 中三种 `scaleMode` 的 Transform、SizedBox、Clip 行为。
- 抽取 Widget 尺寸计算辅助类或函数，例如 `CanvasWidgetLayoutResolver`。
- 为 `fixedScreenSize` 明确命中区域：优先使用屏幕尺寸反投影得到世界命中区域。
- 增加 `minScreenSize`、`maxScreenSize` 或等价配置能力，明确默认值。
- 更新序列化逻辑，确保新增尺寸配置可保存和恢复。
- 在 example 中增加不同 scaleMode 的 Widget，支持缩放观察。

#### 相关文件

- `lib/src/elements/widget_element.dart`
- `lib/src/widgets/canvas_widget_layer.dart`
- `lib/src/widgets/widget_element_builder.dart`
- `lib/src/serialization/canvas_serializer.dart`
- `lib/src/infinite_canvas/canvas_transform.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 三种缩放模式在 25%、100%、400% 缩放下符合定义。
- Widget 的视觉尺寸、布局尺寸、命中区域一致或有明确映射，不出现点击错位。
- snapshot 与 live 渲染模式在同一缩放率下尺寸一致。
- 序列化后重新加载，缩放模式和尺寸策略保持不变。
- 极端缩放下 Widget 不出现 0 尺寸、无限尺寸、布局异常或不可恢复的交互问题。

### 3.3 绘图元素与 Widget 元素自动分层算法

#### 目标

提供自动分层能力，使新增元素、重叠元素和不同类型元素可以按规则自动获得合理的 `layerId` 与 `zIndex`，降低业务方手动维护层级的成本。

#### 技术方案

在现有 `LayerManager` 与 `CanvasController.nextZIndex` 基础上增加自动分层策略。策略需要可配置，默认保持当前行为兼容。

建议策略：

- `manual`：保持当前行为，由调用方指定 layer/zIndex。
- `activeLayer`：插入到当前 active layer，并放到该层最上方。
- `typeLane`：按元素类型分 lane，例如 background、drawing、widget、annotation、connector。
- `overlapAware`：插入时检测与已有元素重叠关系，自动调整 zIndex，避免连接线、Widget、文字被不合理遮挡。

核心实现应放在 controller/service 层，而不是散落在工具中。新增元素通过统一入口 `addElement` 或 `_prepareElementForInsert` 应用策略。

#### 任务列表

- 定义自动分层策略模型与配置入口。
- 在 `CanvasController._prepareElementForInsert` 中接入策略，不破坏现有 `bringToFront`。
- 为 Widget、文字、连接线、普通图形提供默认优先级。
- 使用空间索引或 viewport culling 辅助 overlap 查询，避免大元素量下退化明显。
- 增加 API 文档说明业务方如何关闭或自定义分层策略。
- 增加序列化兼容检查，自动分层不应改变已保存文档的显式层级。

#### 相关文件

- `lib/src/canvas/canvas_controller.dart`
- `lib/src/canvas/element_manager.dart`
- `lib/src/canvas/canvas_state.dart`
- `lib/src/layers/layer_manager.dart`
- `lib/src/layers/canvas_layer.dart`
- `lib/src/canvas/spatial_index.dart`
- `lib/src/rendering/viewport_culling.dart`
- `lib/src/elements/canvas_element.dart`
- `docs/extension_api.md`
- `test/`

#### 验收标准

- 默认配置下，现有测试与示例行为保持兼容。
- 开启自动分层后，新元素获得可预期的 `layerId` 和 `zIndex`。
- Widget、文字、连接线、普通图形重叠时，默认层级符合视觉预期。
- 批量插入元素时层级稳定，不因插入顺序产生随机结果。
- 500 元素场景下自动分层插入无明显卡顿。

### 3.4 500 元素性能优化

#### 目标

在 500 个混合元素场景下保持画布平移、缩放、选择和基础编辑流畅，降低不必要 rebuild、repaint、layout 与 Widget 构建成本。

#### 技术方案

性能优化从渲染、状态通知、空间索引、Widget snapshot、测试基准五个方向推进：

- 渲染：确保 viewport culling 在 painter 与 widget layer 都生效；避免不可见元素参与 build/paint。
- 状态：减少每次 move/preview 对全量 Widget 的重建；必要时引入分区监听或 revision 类型。
- 空间索引：维护增量更新，避免每次查询全量构建。
- Widget：默认 snapshot 渲染，选中/交互时切 live；控制 snapshot capture 频率。
- 基准：建立 example 或 test benchmark，记录 frame build/raster 耗时、命中查询耗时。

#### 任务列表

- 为 500 元素建立固定示例场景，包含绘图、文字、Widget、线条混合。
- 使用 Flutter DevTools 或 profile 日志识别 rebuild/repaint 热点。
- 优化 `CanvasWidgetLayer` 构建列表，避免无关元素反复创建 host。
- 检查 `AnimatedBuilder` 监听范围，必要时拆分背景、元素、overlay 更新。
- 优化 `SpatialIndex` 增量更新和 hitTest 查询路径。
- 增加性能测试或 debug benchmark 输出。

#### 相关文件

- `lib/src/widgets/canvas_widget_layer.dart`
- `lib/src/infinite_canvas/infinite_canvas_widget.dart`
- `lib/src/infinite_canvas/infinite_canvas_painter.dart`
- `lib/src/canvas/canvas_controller.dart`
- `lib/src/canvas/spatial_index.dart`
- `lib/src/utils/quad_tree.dart`
- `lib/src/rendering/viewport_culling.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 500 个元素加载后画布可正常显示、平移、缩放、选择。
- 视口外元素不会参与主要绘制和 Widget build。
- 常规拖拽移动期间无明显输入延迟；性能指标需在实现时结合目标设备记录。
- hitTest 在 500 元素下结果正确且耗时稳定。
- snapshot widget 在非交互状态下不会频繁重新捕获。

### 3.5 文字组件优化

#### 目标

增强 `TextElement` 和 `TextTool`，使文字支持编辑、换行、尺寸约束、样式扩展、缩放一致性与更准确命中。

#### 技术方案

当前 `TextElement` 以 position + text + TextStyle 为主，bounds 由 `TextPainter` 计算。后续建议引入文本框模型：

- 增加 `maxWidth` 或 `textBox`，支持自动换行与固定文本框。
- 增加文本编辑入口：双击或工具点击后展示 overlay editor。
- 支持字体大小、颜色、粗细、对齐、行高等可序列化样式。
- 缓存 TextPainter 布局结果，减少重复 bounds/layout。
- 统一文本缩放策略：跟随画布缩放或固定屏幕字号需明确。

#### 任务列表

- 扩展 `TextElement` 数据结构，兼容旧 JSON。
- 更新 `TextElementRenderer` 支持宽度约束、换行和对齐。
- 实现文本编辑 overlay 或复用 Widget 嵌入机制实现编辑态。
- 更新 `TextTool`，支持创建后直接进入编辑态。
- 增加文字样式更新 API。
- 增加文本序列化、命中、缩放、编辑测试。

#### 相关文件

- `lib/src/elements/text_element.dart`
- `lib/src/tools/text_tool.dart`
- `lib/src/serialization/canvas_serializer.dart`
- `lib/src/widgets/canvas_widget_layer.dart`
- `lib/src/canvas/canvas_controller.dart`
- `lib/src/rendering/selection_renderer.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 文本可创建、选中、移动、编辑、删除、撤销/重做。
- 多行文本 bounds 与视觉区域一致，命中准确。
- 字体大小、颜色、粗细、对齐等样式可保存和恢复。
- 缩放画布时文字视觉表现符合设计定义。
- 旧版本只包含 `position/text/style` 的 JSON 可以正常加载。

### 3.6 图形内嵌文字

#### 目标

支持矩形、椭圆等图形内部显示文字，并让图形与文字作为一个整体参与选择、移动、缩放、序列化和导出。

#### 技术方案

建议先支持 `RectElement` 与 `EllipseElement` 的内嵌文字，后续扩展到自定义 shape。实现方式可以有两种：

- 扩展 shape 元素：在元素中增加 `label`、`labelStyle`、`labelAlign`、`labelPadding`。
- 组合元素：引入 group/container 元素，将 shape 与 text 绑定。

短期建议采用扩展 shape 元素，改动更小；长期如需要复杂组合再引入 group。

#### 任务列表

- 扩展 `RectElement`、`EllipseElement` 的 label 字段与 copy/scale/serialize 逻辑。
- 在 renderer 中绘制 shape 后绘制内部文字，并处理 padding、对齐、溢出。
- 更新 hitTest 和 selection bounds，保持仍以图形 bounds 为准。
- 增加导出支持，PNG 天然支持，SVG 需输出 `<text>`。
- 在 example 中加入带文字图形。

#### 相关文件

- `lib/src/elements/rect_element.dart`
- `lib/src/elements/ellipse_element.dart`
- `lib/src/elements/text_element.dart`
- `lib/src/serialization/canvas_serializer.dart`
- `lib/src/serialization/exporters/svg_exporter.dart`
- `lib/src/serialization/exporters/png_exporter.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 矩形/椭圆可显示内嵌文字，文字位于图形内部并符合对齐设置。
- 移动、缩放图形时内嵌文字同步变化。
- 内嵌文字可序列化、反序列化、导出 SVG/PNG。
- 无 label 的旧图形行为不变。

### 3.7 线条磁吸效果

#### 目标

绘制或编辑线条时，端点可以自动吸附到图形、Widget、文本或其他线条的关键点，提升连线体验。

#### 技术方案

引入 snap/magnet 服务，基于当前指针世界坐标查询附近候选点：

- 候选点类型：元素中心点、边中点、四角、线段端点、线段中点、自定义锚点。
- 查询范围：屏幕像素阈值转换为世界距离，保证不同缩放率下体验一致。
- 视觉反馈：显示吸附点高亮、辅助线或端点贴合预览。
- 数据保存：线条初期可保存实际端点坐标；后续可扩展为绑定 elementId + anchor。

#### 任务列表

- 定义 `SnapPoint`、`SnapResult` 与 `SnapResolver`。
- 为基础元素提供默认锚点生成方法。
- 在 `LineTool`、`ArrowTool` 中接入吸附查询。
- 增加吸附预览渲染。
- 添加配置：开启/关闭、阈值、候选点类型。
- 增加不同缩放率下的吸附测试。

#### 相关文件

- `lib/src/tools/line_tool.dart`
- `lib/src/tools/arrow_tool.dart`
- `lib/src/elements/line_element.dart`
- `lib/src/elements/arrow_element.dart`
- `lib/src/elements/canvas_element.dart`
- `lib/src/canvas/canvas_controller.dart`
- `lib/src/rendering/selection_renderer.dart`
- `lib/src/canvas/spatial_index.dart`
- `lib/src/infinite_canvas/infinite_canvas_config.dart`
- `test/`

#### 验收标准

- 在不同缩放率下，屏幕吸附阈值体感一致。
- 线条端点靠近候选点时自动吸附，并有清晰视觉反馈。
- 关闭吸附后线条绘制恢复自由端点。
- 吸附不会错误命中隐藏或锁定不可连接元素。
- 吸附后的线条可正常选择、移动、序列化和导出。

### 3.8 线条折线算法

#### 目标

支持正交折线或多段折线连接，能够在元素之间自动生成可读性较好的路径，并支持后续拖拽调整。

#### 技术方案

在线条模型上从 `start/end` 扩展到 `points` 或新增 `PolylineElement` / `ConnectorElement`。考虑兼容性，建议新增连接线元素，保留原 `LineElement` 简单直线职责。

折线算法分阶段实现：

- V1：根据起点/终点自动生成水平-垂直-水平或垂直-水平-垂直折线。
- V2：结合元素 bounds 避障，避免穿过源/目标元素。
- V3：支持拖拽中间段、添加/删除折点。

#### 任务列表

- 设计 `PolylineElement` 或 `ConnectorElement` 数据结构。
- 实现折线路径生成器，输入起点、终点、源/目标 bounds、偏移距离。
- 实现 renderer 与 hitTest，支持多段线命中。
- 更新 line/connector tool，支持直线/折线模式切换。
- 更新序列化与 SVG 导出。
- 增加折线生成、命中、导出测试。

#### 相关文件

- `lib/src/elements/line_element.dart`
- `lib/src/elements/arrow_element.dart`
- `lib/src/elements/element_registry.dart`
- `lib/src/tools/line_tool.dart`
- `lib/src/tools/arrow_tool.dart`
- `lib/src/serialization/canvas_serializer.dart`
- `lib/src/serialization/exporters/svg_exporter.dart`
- `lib/src/utils/math_utils.dart`
- `test/`

#### 验收标准

- 可创建折线连接，视觉路径由多个正交线段组成。
- 折线路径 bounds、hitTest、选择框准确。
- 起点终点变化后可重新计算路径。
- SVG/PNG 导出结果与画布显示一致。
- 原直线功能不被破坏。

### 3.9 线条中间文字

#### 目标

支持线条或折线中间显示标签文字，标签跟随线条移动、缩放、序列化和导出。

#### 技术方案

在线条/连接线元素上增加 label 配置：

- `label`：文本内容。
- `labelStyle`：文本样式。
- `labelPosition`：沿线比例，默认 0.5。
- `labelOffset`：相对法线或屏幕方向偏移。
- `labelBackground`：可选背景色，提高可读性。

直线标签位置可用线性插值；折线标签位置按 polyline 总长度计算。旋转策略可配置为沿线旋转或保持水平。

#### 任务列表

- 扩展线条或连接线元素 label 字段。
- 实现 label 位置计算，支持直线和折线。
- 更新 renderer 绘制标签背景和文本。
- 更新 hitTest：默认线条标签不单独命中，或配置为可命中。
- 更新序列化与 SVG 导出。
- 增加 example 示例。

#### 相关文件

- `lib/src/elements/line_element.dart`
- `lib/src/elements/arrow_element.dart`
- `lib/src/elements/text_element.dart`
- `lib/src/serialization/canvas_serializer.dart`
- `lib/src/serialization/exporters/svg_exporter.dart`
- `lib/src/utils/math_utils.dart`
- `example/lib/main.dart`
- `test/`

#### 验收标准

- 线条中间可以显示文字，默认位于 50% 路径长度处。
- 移动、缩放线条时文字同步更新。
- 折线标签位于整条 polyline 的中点，而不是某个线段的局部中点。
- 标签样式可保存、恢复和导出。
- 空 label 不影响现有线条渲染性能和行为。

### 3.10 SDK 接入文档

#### 目标

形成完整 SDK 接入文档，覆盖安装、初始化、基础绘图、Widget 嵌入、图层、序列化、导出、扩展工具/元素、性能建议和常见问题。

#### 技术方案

在现有 `README.md` 与 `docs/extension_api.md` 基础上新增或扩展 SDK 文档。文档应面向接入方，而不是内部实现者，提供最小可运行示例和常见场景代码片段。

建议文档结构：

- 快速开始
- 控制器生命周期
- 画布初始化与配置
- 内置工具使用
- 元素 CRUD
- 自定义 Widget 嵌入
- 图层与层级
- 序列化/反序列化
- PNG/SVG 导出
- 性能建议
- 常见问题
- 版本兼容说明

#### 任务列表

- 新建 `docs/sdk_integration.md`。
- 更新 `README.md` 添加 SDK 文档入口。
- 将 example 中的 StickyNote/Counter 示例整理为文档片段。
- 补充 Widget 嵌入、图层、导出、序列化示例。
- 增加性能建议与限制说明。
- 检查公开 API export，确保文档示例可直接 import。

#### 相关文件

- `README.md`
- `docs/extension_api.md`
- `docs/sdk_integration.md`
- `lib/wenz_draw.dart`
- `example/lib/main.dart`
- `pubspec.yaml`

#### 验收标准

- 新用户可以只阅读 SDK 文档完成基础接入。
- 文档代码片段与当前公开 API 一致。
- Widget 嵌入、图层、序列化、导出均有独立示例。
- README 能清晰链接到 SDK 接入文档。
- 文档说明当前限制和推荐性能实践。

## 4. 推荐实施顺序

1. 绘图与 Widget 重叠
2. Widget 元素多缩放率尺寸视图自适配
3. 500 元素性能优化
4. 绘图元素与 Widget 元素自动分层算法
5. 文字组件优化
6. 图形内嵌文字
7. 线条磁吸效果
8. 线条折线算法
9. 线条中间文字
10. SDK 接入文档

排序依据：先稳定混合渲染与缩放基础，再做性能和分层策略，随后增强文字/图形/线条能力，最后沉淀接入文档。SDK 文档也可以在每个功能完成后增量更新，最终阶段做统一校对。

## 5. 总体验收

- 所有阶段任务对应测试通过，包括单元测试、Widget 测试和必要的人工 example 验证。
- 公开 API 与 `lib/wenz_draw.dart` 导出保持一致，文档示例可编译。
- 旧 JSON 文档可继续加载，新增字段具备默认值或兼容逻辑。
- 500 元素混合场景可操作，且重叠、命中、缩放、选择行为符合预期。
- README、TODO 或阶段状态文档同步更新，便于后续继续推进。
