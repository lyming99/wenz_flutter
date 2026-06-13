# Draw.io 本地图形元素收集与移植计划

> 数据来源：本机项目 `D:\project\GitHub\drawio`，目标项目：`D:\project\GitHub\wenz_flutter\wenz_draw`。
>
> 本文用于跟踪 draw.io 图形元素在 `wenz_draw` 中的迁移范围、缺口与实施顺序。

## 1. 本地 drawio 图形库概览

本地 drawio 的 stencil 根目录：

```text
D:\project\GitHub\drawio\src\main\webapp\stencils
```

扫描结果：

```text
XML stencil 文件数：203
shape 总数：8964
```

重点库：

| 文件 | 库名 | shape 数量 | 备注 |
| --- | --- | ---: | --- |
| `basic.xml` | `mxgraph.basic` | 30 | 基础符号、星形、标记、callout 等 |
| `flowchart.xml` | `mxGraph.flowchart` | 34 | 流程图完整常用符号 |
| `arrows.xml` | `mxgraph.arrows` | 34 | 块箭头、U 型箭头、双向箭头等 |
| `bpmn.xml` | `mxgraph.bpmn` | 39 | BPMN 专用符号 |
| `aws4.xml` | `mxgraph.aws4` | 1037 | 大型云厂商图标库，暂不建议第一阶段迁移 |
| `alibaba_cloud.xml` | `mxgraph.alibaba_cloud` | 310 | 大型云厂商图标库，暂不建议第一阶段迁移 |
| `gcp2.xml` | `mxgraph.gcp2` | 297 | 大型云厂商图标库，暂不建议第一阶段迁移 |
| `cisco19.xml` | `mxgraph.cisco19` | 232 | 网络设备图标库，暂不建议第一阶段迁移 |

完整库很多，建议优先迁移：

1. `flowchart.xml`
2. `basic.xml`
3. `arrows.xml`
4. 后续再考虑 `bpmn.xml`、UML、云厂商、网络设备等大型库。

## 2. wenz_draw 当前已有支持

当前主要实现位置：

```text
lib/src/elements/drawio_shape_definitions.dart
lib/src/stencils/builtin_stencils.dart
lib/src/drawio/drawio_shape_adapter.dart
example/lib/main.dart
```

### 2.1 当前手写 ShapeDefinition

```text
rectangle
roundedRectangle
ellipse
rhombus
triangle
hexagon
parallelogram
trapezoid
cylinder
doubleEllipse
actor
cloud
swimlane
document
note
callout
plus
cross
step
cube
```

### 2.2 当前别名

```text
rect -> rectangle
process -> rectangle
rounded -> roundedRectangle
circle -> ellipse
diamond -> rhombus
manualInput -> parallelogram
cylinder3 -> cylinder
isoRectangle -> cube
```

### 2.3 当前内置 stencil 子集

```text
stencil.process
stencil.roundedProcess
stencil.decision
stencil.terminator
stencil.data
stencil.document
stencil.preparation
stencil.manualInput
stencil.database
stencil.cloud
```

这些已经覆盖流程图中的少量核心元素，但离 draw.io 官方 `Flowchart` / `Basic` 面板仍有明显差距。

## 3. 本地 drawio Basic 库清单与缺口

本地 `basic.xml` 共 30 个：

```text
4 Point Star
6 Point Star
8 Point Star
Banner
Cloud Callout
Cloud Rect
Cone
Cross
Document
Flash
Half Circle
Heart
Loud Callout
Moon
No Symbol
Octagon
Orthogonal Triangle
Oval Callout
Parallelepiped
Pentagon
Pointed Oval
Rectangular Callout
Rounded Rectangular Callout
Smiley
Star
Sun
Tick
Trapezoid
Wave
X
```

当前已支持或近似支持：

| draw.io Basic | wenz_draw 当前情况 | 说明 |
| --- | --- | --- |
| Cross | `cross` | 已有，但 draw.io stencil 版本可能细节不同 |
| Document | `document` | 已有，但当前更偏流程图 document，Basic document 折角形态不同 |
| Trapezoid | `trapezoid` | 已有 |

建议补齐：

```text
4 Point Star
6 Point Star
8 Point Star
Banner
Cloud Callout
Cloud Rect
Cone
Flash
Half Circle
Heart
Loud Callout
Moon
No Symbol
Octagon
Orthogonal Triangle
Oval Callout
Parallelepiped
Pentagon
Pointed Oval
Rectangular Callout
Rounded Rectangular Callout
Smiley
Star
Sun
Tick
Wave
X
```

## 4. 本地 drawio Flowchart 库清单与缺口

本地 `flowchart.xml` 共 34 个：

```text
Annotation 1
Annotation 2
Card
Collate
Data
Database
Decision
Delay
Direct Data
Display
Document
Extract or Measurement
Internal Storage
Loop Limit
Manual Input
Manual Operation
Merge or Storage
Multi-Document
Off-page Reference
On-page Reference
Or
Paper Tape
Parallel Mode
Predefined Process
Preparation
Process
Sequential Data
Sort
Start 1
Start 2
Stored Data
Summing Function
Terminator
Transfer
```

当前已支持或近似支持：

| draw.io Flowchart | wenz_draw 当前情况 | 说明 |
| --- | --- | --- |
| Data | `parallelogram` / `stencil.data` | 基本覆盖 |
| Database | `cylinder` / `stencil.database` | 基本覆盖 |
| Decision | `rhombus` / `stencil.decision` | 基本覆盖 |
| Document | `document` / `stencil.document` | 基本覆盖 |
| Manual Input | `parallelogram` / `manualInput` / `stencil.manualInput` | 基本覆盖 |
| Preparation | `hexagon` / `stencil.preparation` | 基本覆盖 |
| Process | `rectangle` / `stencil.process` | 基本覆盖 |
| Terminator | `stencil.terminator` | 已有 stencil，但未必已放入 palette |
| Cloud | `cloud` / `stencil.cloud` | flowchart.xml 中没有 Cloud，此处是当前已有能力 |

建议优先补齐：

```text
Annotation 1
Annotation 2
Card
Collate
Delay
Direct Data
Display
Extract or Measurement
Internal Storage
Loop Limit
Manual Operation
Merge or Storage
Multi-Document
Off-page Reference
On-page Reference
Or
Paper Tape
Parallel Mode
Predefined Process
Sequential Data
Sort
Start 1
Start 2
Stored Data
Summing Function
Transfer
```

其中 `Card` 当前 example 中已有 palette 名称，但 `DrawioShapeDefinitions` 没有 `card`，需要确认是否实际能渲染；如果不能，应纳入缺口。

## 5. 本地 drawio Arrows 库清单与缺口

本地 `arrows.xml` 共 34 个：

```text
Arrow Down
Arrow Left
Arrow Right
Arrow Up
Bent Left Arrow
Bent Right Arrow
Bent Up Arrow
Callout Double Arrow
Callout Quad Arrow
Callout Up Arrow
Chevron Arrow
Circular Arrow
Jump-in Arrow 1
Jump-in Arrow 2
Left and Up Arrow
Left Sharp Edged Head Arrow
Notched Signal-in Arrow
Quad Arrow
Right Notched Arrow
Sharp Edged Arrow
Signal-in Arrow
Slender Left Arrow
Slender Two Way Arrow
Slender Wide Tailed Arrow
Striped Arrow
Stylised Notched Arrow
Triad Arrow
Two Way Arrow Horizontal
Two Way Arrow Vertical
U Turn Arrow
U Turn Down Arrow
U Turn Left Arrow
U Turn Right Arrow
U Turn Up Arrow
```

当前 `wenz_draw` 有 `ArrowElement` 和连接线/箭头工具，但没有 draw.io 块箭头 stencil 库。因此这些属于新库迁移。

建议作为第三批迁移，原因：

1. 与现有连接线箭头不是同一类元素；这些是可填充的块状 shape。
2. 需要明确 UI 上放在 `Arrows` palette，而不是连接线工具里。
3. 后续可能涉及方向、翻转、连接点、路由中心等兼容问题。

## 6. 当前 StencilParser 能力差距

当前 parser 支持：

```text
shape
background
foreground
path
move
line
quad
curve
arc
close
rect
roundrect
ellipse
text
include-shape
connections / constraint
```

对本地 `basic.xml` / `flowchart.xml` / `arrows.xml` 的标签扫描发现，官方 stencil 还会使用：

```text
fillstroke
stroke
save
restore
strokewidth
miterlimit
linejoin
fillcolor
```

这些目前会被解析成 `StencilUnsupportedCommand`，因此直接把完整 XML 导入进来虽然可能不会崩，但 foreground 的描边/填充语义会缺失，复杂图形会显示不完整。

### 6.1 必须优先支持的命令

第一优先级：

```text
fillstroke
stroke
```

原因：几乎所有官方 stencil 都依赖它们标记路径的绘制行为。

第二优先级：

```text
save
restore
strokewidth
fillcolor
```

原因：`Parallel Mode`、`Smiley`、`Cloud Callout`、`Sun` 等复杂图形依赖局部样式栈或局部颜色。

第三优先级：

```text
miterlimit
linejoin
```

原因：影响细节，但不影响基础轮廓显示。

## 7. 推荐迁移架构

不要继续把所有 XML 字符串堆在 `builtin_stencils.dart` 中。建议拆成库级文件：

```text
lib/src/stencils/libraries/basic_stencils.dart
lib/src/stencils/libraries/flowchart_stencils.dart
lib/src/stencils/libraries/arrow_stencils.dart
lib/src/stencils/stencil_library_registry.dart
```

建议 key 规范：

```text
basic.star
basic.heart
basic.octagon
flowchart.decision
flowchart.terminator
flowchart.internalStorage
arrows.arrowRight
arrows.uTurnArrow
```

同时保留 draw.io 原始 style 兼容别名：

```text
mxgraph.basic.star -> basic.star
mxgraph.flowchart.decision -> flowchart.decision
mxgraph.arrows.arrowRight -> arrows.arrowRight
stencil.decision -> flowchart.decision 或继续映射到现有 stencil.decision
```

## 8. 分阶段实施计划

### 阶段一：补 Flowchart 核心缺口

目标：让流程图常用面板基本可用。

任务：

1. 扩展 `StencilParser`，至少支持：
   - `fillstroke`
   - `stroke`
2. 从本地 `flowchart.xml` 抽取并注册 34 个 shape。
3. 对已经有手写实现的元素建立别名或覆盖策略。
4. 更新 example 左侧 palette：新增完整 `Flowchart` 分组。
5. 增加测试：
   - 所有 flowchart shape 可注册。
   - 每个 shape 可创建 `DrawioShapeElement`。
   - SVG export 不为空。

优先元素：

```text
Terminator
Delay
Display
Direct Data
Internal Storage
Predefined Process
Multi-Document
Off-page Reference
On-page Reference
Stored Data
Sort
Start 1
Start 2
Transfer
```

### 阶段二：补 Basic 常用符号

目标：让 Basic 面板接近 draw.io。

任务：

1. 从本地 `basic.xml` 抽取并注册 30 个 shape。
2. 对 `Cross`、`Trapezoid`、`Document` 与已有实现做去重/别名策略。
3. 更新 example 左侧 palette：新增 `Basic Symbols` 或补全 `Basic`。
4. 增加视觉回归或 SVG 快照测试。

优先元素：

```text
Star
Octagon
Pentagon
Heart
Moon
Tick
X
No Symbol
Wave
Half Circle
Cone
Rectangular Callout
Rounded Rectangular Callout
```

### 阶段三：补 Arrows 块箭头库

目标：支持 draw.io 的 `Arrows` stencil palette。

任务：

1. 从本地 `arrows.xml` 抽取并注册 34 个块箭头。
2. 新增 example `Arrows` 分组。
3. 明确这些是 shape 元素，不是连接线箭头。
4. 增加方向、连接点和 SVG 测试。

### 阶段四：高级库预研

候选：

```text
bpmn.xml
uml 相关库
aws4.xml
gcp2.xml
alibaba_cloud.xml
cisco19.xml
```

建议暂缓，原因：数量很大，且很多图标库可能涉及更复杂样式、品牌授权、图标显示策略、搜索面板和性能问题。

## 9. 验收标准

每一批迁移完成后，应满足：

1. shape 注册表能查到所有新增 key。
2. `DrawioShapeAdapter.fromStyleString` 能识别 draw.io style 中的 shape key。
3. example palette 能创建对应元素。
4. 元素支持：
   - canvas 渲染
   - 选中/移动/缩放
   - label 显示
   - snapping / connection points
   - JSON 序列化与反序列化
   - SVG export
5. 不影响现有 `RectElement`、`EllipseElement`、`ArrowElement`、`DrawioShapeElement` 测试。

## 10. 近期建议执行项

建议下一步直接做阶段一：

```text
1. 扩展 stencil command：fillstroke / stroke。
2. 新建 flowchart stencil 库文件。
3. 从本地 drawio flowchart.xml 抽取 34 个 shape。
4. 注册为 flowchart.* key，并兼容 mxgraph.flowchart.* key。
5. 更新 example palette。
6. 增加注册和 SVG export 测试。
```
