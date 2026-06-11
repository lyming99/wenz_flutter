# wenz_draw 无限画布自定义 Widget 嵌入方案

## 一、需求背景

当前 `wenz_draw` 无限画布支持两大类扩展：

- **自定义元素（Custom Element）**：通过 `CanvasElement` 抽象类 + `ElementRenderer<T>` + `ElementRendererRegistry` 注册，所有内容通过 `CustomPainter` 绘制到 Canvas 上。
- **自定义工具（Custom Tool）**：通过 `CanvasTool` 抽象类 + `ToolManager` 注册，接收 `CanvasEvent` 并返回 `ToolResult`。

但上述体系**不支持在画布中嵌入真正的 Flutter Widget**（如按钮、输入框、滑块、自定义 UI 组件等），因为 `CustomPainter` 只能绘制图形，无法承载交互式 Widget。

本方案旨在为无限画布新增**自定义 Widget 嵌入能力**，使用户可以：

- 将任意 Flutter Widget 作为画布元素放置，参与平移/缩放/旋转
- 与嵌入的 Widget 进行自然交互（点击、输入、滚动等）
- 对 Widget 元素执行选择、移动、删除等标准画布操作
- 序列化/反序列化 Widget 元素数据

---

## 二、架构设计

### 2.1 方案选型：Stack 混合层方案

在三套候选方案中，选择**方案 B：Hybrid CanvasElement + WidgetBuilder + Stack 分层渲染**。

| 方案 | 描述 | 优点 | 缺点 |
|:---|:---|:---|:---|
| A: 纯 CustomPainter 内嵌 | 在 CustomPainter 中用 PictureRecorder 录制 Widget 纹理 | 统一管线 | Widget 无法交互，失去意义 |
| **B: Stack 分层（选中）** | CustomPaint 画元素 + 上层 Transform 层托管 Widget | 交互自然、实现简单、与现有体系兼容 | 两套层管理 z-order |
| C: RenderObject | 自定义 RenderObject 统一管理 | 最大灵活性 | 复杂度高、与现有架构冲突大 |

**选择理由**：

1. Widget 必须位于 Widget Tree 中才能享有交互能力（手势、焦点、输入法等），这是 Flutter 框架的硬约束。
2. Stack 分层方案最小侵入，现有绘制管线完全保留。
3. `CanvasWidgetElement` 扩展自 `CanvasElement`，无缝融入选择/移动/序列化/历史记录体系。

### 2.2 整体组件关系图

```
┌──────────────────────────────────────────────────────────────────┐
│                    InfiniteCanvasWidget (StatefulWidget)          │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                         Stack                              │  │
│  │                                                            │  │
│  │  Layer 0: CustomPaint (InfiniteCanvasPainter)              │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  绘制: 网格 + 所有非 Widget 类型的 CanvasElement      │ │  │
│  │  │  绘制: 选择框 + 预览元素                              │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  Layer 1: CanvasWidgetLayer (自定义 Widget 层)            │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  for each CanvasWidgetElement:                        │ │  │
│  │  │    Transform(transform: worldToScreenMatrix)           │ │  │
│  │  │      └─ GestureDetector / IgnorePointer               │ │  │
│  │  │           └─ WidgetElementBuilder.build(context, elem) │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                                                            │  │
│  │  Layer 2: 覆盖层 (Minimap, ZoomControls 等)               │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  Positioned Widgets (不变)                            │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### 2.3 坐标转换流程

```
Screen Space (屏幕坐标)
    │
    │  screenToWorld() / worldToScreen()
    ▼
World Space (世界坐标) ──── CanvasElement.bounds 在此空间定义
    │
    │  对于 Widget 元素:
    │  widgetElement.worldRect  →  worldToScreen()  →  Transform 矩阵
    ▼
Widget 渲染层 (通过 Transform Widget 定位到屏幕位置)
```

**关键点**：
- Widget 元素的位置和大小存储在**世界坐标系**（与普通元素一致）
- 渲染时通过 `CanvasTransform.worldToScreenMatrix()` 生成 `Matrix4`，传给 `Transform` widget
- 这样 Widget 自然跟随画布平移/缩放

---

## 三、核心 API 设计

### 3.1 CanvasWidgetElement

```dart
/// 嵌入画布的 Widget 元素
/// 
/// 继承自 CanvasElement，可被选中、移动、序列化、参与历史记录。
@immutable
class CanvasWidgetElement extends CanvasElement {
  const CanvasWidgetElement({
    required this.id,
    required this.worldRect,
    required this.widgetType,
    this.widgetData = const {},
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
    this.isLocked = false,    // 锁定后不可交互
    this.clipBehavior = Clip.hardEdge,
  });

  static const elementType = 'widget';

  @override final String id;
  @override String get type => elementType;
  @override final String layerId;
  @override final bool visible;
  @override final double opacity;
  @override final int zIndex;

  /// Widget 在世界坐标系中的包围矩形
  final Rect worldRect;

  /// 自定义 Widget 类型标识符（用于 WidgetElementRegistry 查找 builder）
  final String widgetType;

  /// Widget 的自定义数据（序列化用）
  final Map<String, dynamic> widgetData;

  /// 是否锁定（true 时不响应画布选择/移动操作，仅响应用户交互）
  final bool isLocked;

  /// 裁剪行为
  final Clip clipBehavior;

  @override
  Rect get bounds => worldRect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return worldRect.inflate(tolerance).contains(worldPoint);
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'widgetType': widgetType,
    'layerId': layerId,
    'visible': visible,
    'opacity': opacity,
    'zIndex': zIndex,
    'isLocked': isLocked,
    'worldRect': {
      'left': worldRect.left,
      'top': worldRect.top,
      'right': worldRect.right,
      'bottom': worldRect.bottom,
    },
    'widgetData': widgetData,
  };

  @override
  CanvasWidgetElement copyWith({...}) => CanvasWidgetElement(...);

  @override
  CanvasWidgetElement translate(Offset delta) =>
      copyWith(worldRect: worldRect.shift(delta));

  @override
  CanvasWidgetElement scaleElement(double factor, {Offset? pivot}) =>
      copyWith(worldRect: /* 以 pivot 缩放 worldRect */);
}
```

### 3.2 WidgetElementBuilder

```dart
/// 自定义 Widget 构建器（类似 ElementRenderer 的角色）
/// 
/// 对于每种 widgetType，注册一个 builder 到 WidgetElementRegistry。
abstract class WidgetElementBuilder {
  const WidgetElementBuilder();

/// 根据元素数据构建 Widget
/// 
/// [element] 包含 worldRect 和 widgetData
/// [canvas] 提供选中状态、缩放比例、控制器和 updateProps/requestSelect 等方法
Widget build(
  BuildContext context,
  CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
});
}
```

### 3.3 WidgetElementRegistry

```dart
/// Widget 构建器注册表（单例模式）
class WidgetElementRegistry {
  WidgetElementRegistry._();

  static final Map<String, WidgetElementBuilder> _builders = {};

  /// 注册自定义 Widget 构建器
  static void register(String widgetType, WidgetElementBuilder builder) {
    _builders[widgetType] = builder;
  }

  /// 获取构建器
  static WidgetElementBuilder? getBuilder(String widgetType) {
    return _builders[widgetType];
  }

  /// 是否已注册
  static bool hasBuilder(String widgetType) {
    return _builders.containsKey(widgetType);
  }

  /// 取消注册
  static void unregister(String widgetType) {
    _builders.remove(widgetType);
  }

  /// 所有已注册的 widgetType
  static Iterable<String> get registeredTypes => _builders.keys;

  /// 清空注册表，主要用于测试
  static void clear() {
    _builders.clear();
  }
}
```

### 3.4 CanvasWidgetLayer

```dart
/// Widget 元素渲染层
/// 
/// 遍历所有 CanvasWidgetElement，使用 Transform Widget 将其
/// 定位到屏幕空间，并调用对应的 WidgetElementBuilder 构建 UI。
class CanvasWidgetLayer extends StatelessWidget {
  const CanvasWidgetLayer({
    super.key,
    required this.controller,
  });

  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    // 获取所有 widget 类型的元素
    final widgetElements = controller.canvasController.elements
        .whereType<CanvasWidgetElement>()
        .where((e) => e.visible)
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // 视口裁剪：只渲染可见范围内的 Widget
    final visibleRect = controller.visibleWorldRect();
    final visible = widgetElements.where(
      (e) => e.worldRect.overlaps(visibleRect),
    );

    return Stack(
      children: [
        for (final element in visible)
          _WidgetElementWrapper(
            element: element,
            controller: controller,
          ),
      ],
    );
  }
}

class _WidgetElementWrapper extends StatelessWidget {
  // 使用 AnimatedBuilder 监听 controller 变化
  // 通过 Transform 将世界坐标映射到屏幕坐标
  // 处理选择状态、交互屏蔽等
}
```

---

## 四、手势冲突处理机制

这是 Widget 嵌入方案的核心难点。画布本身需要处理平移/缩放手势和工具手势，而嵌入的 Widget 也需要自己的手势（点击按钮、滑动列表等）。需要设计一套**手势优先级规则**：

### 4.1 手势优先级规则

```
优先级从高到低:
1. 嵌入 Widget 的手势（当 SelectTool 激活且 Widget 未锁定时）
2. 画布工具手势（当非 SelectTool 激活时，屏蔽 Widget 手势）
3. 画布平移/缩放手势（始终响应，除非 Widget 消费了指针）
```

### 4.2 实现策略

```
策略 A: IgnorePointer 动态切换
  - 当 currentTool != SelectTool 时，用 IgnorePointer 包裹所有 Widget 元素
  - 当 currentTool == SelectTool 时，Widget 正常接收手势

策略 B: 手势竞技场 (Gesture Arena)
  - 在 Widget 外层包裹 GestureDetector，在 onPointerDown 中判断
  - Widget 内部使用 AbsorbPointer 根据条件屏蔽

策略 C: 混合策略（推荐）
  - 默认使用 IgnorePointer，根据工具状态切换
  - PanTool 激活时：Ignoring=true（Widget 不响应）
  - SelectTool 激活时：Ignoring=false（Widget 正常交互）
  - 绘制工具激活时：Ignoring=true（防止绘制到 Widget 上）
  - Widget 的 isLocked=true 时：永远 Ignoring=true
```

### 4.3 选择/移动 Widget 元素

当 `SelectTool` 激活时：
- 点击 Widget 元素区域 → Widget 正常响应点击（如按钮点击）
- 点击 Widget 元素边框/边缘 → 触发画布选择/移动（通过 `GestureDetector` 外层包装）
- 可提供一个"编辑模式切换"：双击 Widget 进入编辑（Widget 交互），单击空白退出编辑（画布操作）

---

## 五、序列化设计

### 5.1 CanvasSerializer 扩展

在 `elementFromJson` 的 `switch` 中增加：

```dart
case CanvasWidgetElement.elementType:
  return CanvasWidgetElement(
    id: id,
    worldRect: _rect(json['worldRect']),
    widgetType: json['widgetType'] as String? ?? '',
    widgetData: json['widgetData'] as Map<String, dynamic>? ?? {},
    layerId: layerId,
    visible: visible,
    opacity: opacity,
    zIndex: zIndex,
    isLocked: json['isLocked'] as bool? ?? false,
  );
```

### 5.2 自定义 Widget 的数据序列化

`widgetData` 是一个自由的 `Map<String, dynamic>`，由各 `WidgetElementBuilder` 自行定义格式。用户负责保证其 JSON 兼容性。

示例（嵌入一个计数器按钮）：

```json
{
  "id": "widget-001",
  "type": "widget",
  "widgetType": "counter_button",
  "worldRect": { "left": 200, "top": 150, "right": 360, "bottom": 210 },
  "widgetData": {
    "count": 5,
    "label": "点击次数"
  }
}
```

---

## 六、实现规划（分 Phase 执行）

### Phase W1: 核心数据模型 + 注册表（0.5 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| W1-1 | 创建 `CanvasWidgetElement` 不可变数据类（`lib/src/elements/widget_element.dart`） | 现有 `CanvasElement` |
| W1-2 | 创建 `WidgetElementBuilder` 抽象类（`lib/src/widgets/widget_element_builder.dart`） | W1-1 |
| W1-3 | 创建 `WidgetElementRegistry` 注册表（`lib/src/widgets/widget_element_registry.dart`） | W1-2 |
| W1-4 | 在 `CanvasSerializer.elementFromJson` 中增加 `widget` 类型反序列化 | W1-1 |

**验收**：可创建 `CanvasWidgetElement` 实例，序列化/反序列化正常。

### Phase W2: Widget 渲染层（0.5 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| W2-1 | 实现 `CanvasWidgetLayer` StatelessWidget（`lib/src/infinite_canvas/canvas_widget_layer.dart`） | W1-1 |
| W2-2 | 在 `InfiniteCanvasWidget.build` 的 `Stack` 中集成 `CanvasWidgetLayer` | W2-1 |
| W2-3 | 实现 `_WidgetElementWrapper`：Transform 变换 + IgnorePointer 控制 + 选中边框 | W2-1 |

**验收**：嵌入的 Widget 可见，跟随画布平移/缩放。

### Phase W3: 手势冲突处理（0.5 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| W3-1 | 在 `CanvasWidgetLayer` 中根据 `currentTool` 动态切换 `IgnorePointer` | W2-2 |
| W3-2 | SelectTool 激活时 Widget 可正常交互，绘制工具激活时屏蔽 | W3-1 |
| W3-3 | 测试 Widget 选择/移动：外层 `GestureDetector` 处理选中和拖拽 | W3-2 |

**验收**：绘制时 Widget 不干扰，选择时 Widget 可交互。

### Phase W4: Editor 模式 + 完善（0.5 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| W4-1 | 实现"编辑模式"切换：双击进入编辑、ESC 退出编辑 | W3-2 |
| W4-2 | Widget 元素选中态渲染（蓝色边框 + 调整手柄） | W4-1 |
| W4-3 | 内置示例 Widget builder：`sticky_note`（便签） | W1-3 |
| W4-4 | 更新 `example/lib/main.dart` 演示自定义 Widget 嵌入 | W4-3 |

**验收**：端到端可用，Example 可运行。

### Phase W5: 文档 + 测试（0.5 周）

| 编号 | 任务 | 依赖 |
|:---|:---|:---|
| W5-1 | 单元测试：`CanvasWidgetElement` 序列化/反序列化 | W1-4 |
| W5-2 | Widget 测试：`CanvasWidgetLayer` 渲染 | W2-3 |
| W5-3 | 更新 `docs/extension_api.md`：添加 Widget 扩展 API 文档 | Phase W4 |
| W5-4 | 更新 `wenz_draw.dart` 导出清单 | W1-3 |

**验收**：测试通过，文档完整。

---

## 七、API 使用示例

### 7.1 注册自定义 Widget

```dart
import 'package:wenz_draw/wenz_draw.dart';

// 1. 创建 Widget Builder
class CounterButtonBuilder extends WidgetElementBuilder {
  const CounterButtonBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final count = element.widgetData['count'] as int? ?? 0;
    return Container(
      width: element.worldRect.width,
      height: element.worldRect.height,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
        border: canvas.selected
            ? Border.all(color: Colors.blueAccent, width: 2)
            : null,
      ),
      child: TextButton(
        onPressed: () {
          canvas.updateProps(element.id, {
            ...element.widgetData,
            'count': count + 1,
          });
        },
        child: Text('Count: $count', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// 2. 注册
WidgetElementRegistry.register('counter_button', const CounterButtonBuilder());
```

### 7.2 在画布上添加 Widget 元素

```dart
final controller = CanvasController();

final widgetElement = CanvasWidgetElement(
  id: 'widget-001',
  worldRect: Rect.fromLTWH(200, 150, 160, 60),
  widgetType: 'counter_button',
  widgetData: {'count': 0},
);

controller.addElement(widgetElement);
```

### 7.3 完整 Example 集成

```dart
// 在 CanvasDemoPage.initState 中
@override
void initState() {
  super.initState();
  // 注册自定义 Widget
  WidgetElementRegistry.register('sticky_note', const StickyNoteBuilder());
  WidgetElementRegistry.register('counter_button', const CounterButtonBuilder());

  _canvasController = CanvasController();
  _viewController = InfiniteCanvasController(
    canvasController: _canvasController,
  );

  // 添加一个示例 Widget
  _canvasController.addElement(
    CanvasWidgetElement(
      id: 'demo-widget',
      worldRect: Rect.fromLTWH(100, 100, 200, 120),
      widgetType: 'sticky_note',
      widgetData: {'text': 'Hello Canvas!', 'color': '#FFEB3B'},
    ),
  );
}
```

---

## 八、内置 Widget 类型（建议提供）

SDK 可以内置几个常用的 Widget 类型作为参考实现和开箱即用组件：

| widgetType | 描述 | 用途 |
|:---|:---|:---|
| `sticky_note` | 便签 | 文本框 + 背景色，可编辑文字 |
| `image_embed` | 图片嵌入 | 比 ImageElement 更丰富的交互（缩放/旋转） |
| `web_frame` | 网页嵌入 | 嵌入 iframe（Web 平台） |
| `shape_label` | 图形标签 | 附加到元素的文字标签 |

> 注：内置 Widget 按需实现，不作为 Phase 必要条件。

---

## 九、技术限制与注意事项

### 9.1 性能

- Widget 元素不宜过多。建议**同一视口内 Widget 元素不超过 20 个**。
- Widget 元素在视口外时会被裁剪（不渲染），通过 `visibleWorldRect` 过滤。
- 大量普通绘制的元素不受影响（仍然走 CustomPainter 管线）。

### 9.2 缩放时的 Widget 行为

- Widget 随画布缩放而缩放（通过 `Transform.scale` 实现），这可能导致文字模糊或布局异常。
- 建议：Widget 元素在极端缩放比例下（<0.3x 或 >5x）降级为占位矩形（skeleton），仅在合理范围内渲染真实 Widget。
- 可在 `CanvasWidgetLayer` 中实现此逻辑。

### 9.3 文本输入

- 包含 `TextField` / `TextFormField` 的 Widget 需要管理焦点。
- 画布手势（平移、缩放）不应抢夺输入焦点。
- 建议：输入框获得焦点时自动锁定画布平移。

### 9.4 平台兼容性

- 所有平台均支持 Transform Widget，无特殊限制。
- Web 平台注意 iframe 嵌入的跨域问题。

---

## 十、文件变更清单

```
lib/src/elements/
  + widget_element.dart              # CanvasWidgetElement

lib/src/widgets/
  + widget_element_builder.dart       # WidgetElementBuilder + CanvasWidgetBuildContext
  + widget_element_registry.dart      # WidgetElementRegistry

lib/src/widgets/
  + canvas_widget_layer.dart          # CanvasWidgetLayer + _WidgetElementWrapper

lib/src/infinite_canvas/
  ~ infinite_canvas_widget.dart       # 集成 CanvasWidgetLayer 到 Stack

lib/src/serialization/
  ~ canvas_serializer.dart            # 增加 widget 类型反序列化

lib/
  ~ wenz_draw.dart                    # 导出新文件

docs/
  ~ extension_api.md                  # 更新扩展文档

spec/
  + custom_widget_support.md          # 本方案文档（即此文件）
```

---

## 十一、未来扩展方向

1. **Widget 模板库**：预置常用 Widget（便签、图表、表格等）
2. **Widget 连线**：支持 Widget 之间的箭头连线
3. **Widget 组合**：多个 Widget 组合为 Group，统一操作
4. **Widget 动画**：入场/退场动画
5. **Web 嵌入**：Web 平台支持 iframe 嵌入
6. **实时协作 Widget**：多人同时编辑同一个 Widget 元素

---

## 十二、技术决策记录

| 决策 | 选项 | 选择 | 理由 |
|:---|:---|:---|:---|
| 渲染方案 | CustomPainter 内嵌 / Stack 分层 / RenderObject | **Stack 分层** | Widget 必须处于 Widget Tree 才能交互 |
| 坐标转换 | 手动计算 / Transform Widget | **Transform Widget** | 利用 Flutter 内建能力，减少计算错误 |
| 手势冲突 | IgnorePointer / 手势竞技场 / 混合 | **混合（IgnorePointer + 编辑模式）** | 简单可靠，用户体验清晰 |
| 数据模型 | 新建独立类 / 扩展 CanvasElement | **扩展 CanvasElement** | 复用选择/移动/历史等全部能力 |
| 序列化 | 固定 schema / 自由 Map | **自由 Map (widgetData)** | 最大灵活性，由用户定义格式 |
