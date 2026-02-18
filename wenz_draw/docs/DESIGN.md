# Wenz Draw - 架构设计文档

## 概述

本文档描述 Wenz Draw 绘图白板组件的架构设计，包括核心类结构、数据模型和交互逻辑。

## 架构设计

### 核心类结构

```
┌─────────────────────────────────────────────────────────────┐
│                      WenzDrawCanvas                          │
│                    (主画布组件)                               │
├─────────────────────────────────────────────────────────────┤
│  - painter: WenzDrawPainter                                  │
│  - controller: WenzDrawController                            │
│  - gestureDetector: GestureDetector                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    WenzDrawController                        │
│                  (画布控制器)                                 │
├─────────────────────────────────────────────────────────────┤
│  - currentTool: DrawTool                                     │
│  - brushSettings: BrushSettings                              │
│  - drawingHistory: List<DrawingElement>                      │
│  - historyManager: HistoryManager                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    WenzDrawPainter                           │
│                  (自定义画布绘制器)                           │
├─────────────────────────────────────────────────────────────┤
│  + paint(Canvas canvas, Size size)                           │
│  + shouldRepaint() → bool                                   │
└─────────────────────────────────────────────────────────────┘
```

## 数据模型

### DrawTool (绘图工具枚举)

```dart
enum DrawTool {
  pen,        // 画笔
  line,       // 直线
  rectangle,  // 矩形
  circle,     // 圆形
  eraser,     // 橡皮擦
  text,       // 文本
}
```

### BrushSettings (画笔设置)

```dart
class BrushSettings {
  final Color color;      // 画笔颜色
  final double size;      // 画笔粗细
  final bool isFill;      // 是否填充

  const BrushSettings({
    required this.color,
    required this.size,
    this.isFill = false,
  });
}
```

### DrawingElement (绘图元素基类)

```dart
abstract class DrawingElement {
  final DrawTool tool;
  final BrushSettings settings;

  const DrawingElement({
    required this.tool,
    required this.settings,
  });

  void draw(Canvas canvas);
}
```

### 具体绘图元素

```dart
// 自由路径元素
class PathElement extends DrawingElement {
  final List<Offset> points;

  const PathElement({
    required super.tool,
    required super.settings,
    required this.points,
  });
}

// 直线元素
class LineElement extends DrawingElement {
  final Offset start;
  final Offset end;

  const LineElement({
    required super.tool,
    required super.settings,
    required this.start,
    required this.end,
  });
}

// 矩形元素
class RectangleElement extends DrawingElement {
  final Rect rect;

  const RectangleElement({
    required super.tool,
    required super.settings,
    required this.rect,
  });
}

// 圆形元素
class CircleElement extends DrawingElement {
  final Offset center;
  final double radius;

  const CircleElement({
    required super.tool,
    required super.settings,
    required this.center,
    required this.radius,
  });
}

// 文本元素
class TextElement extends DrawingElement {
  final String text;
  final Offset position;

  const TextElement({
    required super.tool,
    required super.settings,
    required this.text,
    required this.position,
  });
}
```

## 状态管理

### 绘图状态

```dart
enum DrawingState {
  idle,       // 空闲
  drawing,    // 绘制中
  panning,    // 平移中
  zooming,    // 缩放中
}
```

### WenzDrawController

```dart
class WenzDrawController extends ChangeNotifier {
  // 当前工具
  DrawTool _currentTool = DrawTool.pen;
  DrawTool get currentTool => _currentTool;

  // 画笔设置
  BrushSettings _brushSettings = const BrushSettings(
    color: Colors.black,
    size: 5.0,
  );
  BrushSettings get brushSettings => _brushSettings;

  // 绘图元素列表
  final List<DrawingElement> _elements = [];
  List<DrawingElement> get elements => List.unmodifiable(_elements);

  // 历史记录管理
  final HistoryManager _historyManager = HistoryManager();
  bool get canUndo => _historyManager.canUndo;
  bool get canRedo => _historyManager.canRedo;

  // 画布变换
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // 方法
  void setTool(DrawTool tool);
  void setBrushColor(Color color);
  void setBrushSize(double size);
  void undo();
  void redo();
  void clear();
  void exportToImage();
}
```

## 手势处理

### 手势识别器配置

```dart
GestureDetector(
  // 单指触摸 - 绘图
  onPanStart: _handlePanStart,
  onPanUpdate: _handlePanUpdate,
  onPanEnd: _handlePanEnd,

  // 双指缩放
  onScaleStart: _handleScaleStart,
  onScaleUpdate: _handleScaleUpdate,
  onScaleEnd: _handleScaleEnd,

  // 长按
  onLongPress: _handleLongPress,
)
```

### 手势状态机

```
                    ┌─────────┐
                    │  Idle   │
                    └────┬────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    Single tap      Two finger      Long press
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ Drawing │    │ Zooming │    │ Panning │
    └────┬────┘    └────┬────┘    └────┬────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
                        ▼
                   ┌─────────┐
                   │  Idle   │
                   └─────────┘
```

## 渲染流程

```dart
// WenzDrawPainter.paint() 方法流程
void paint(Canvas canvas, Size size) {
  // 1. 绘制背景
  _drawBackground(canvas, size);

  // 2. 应用变换（缩放、平移）
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  canvas.scale(scale);

  // 3. 绘制所有已保存的绘图元素
  for (var element in elements) {
    element.draw(canvas);
  }

  // 4. 绘制当前正在绘制的元素（预览）
  if (currentElement != null) {
    currentElement!.draw(canvas);
  }

  // 5. 恢复画布状态
  canvas.restore();
}
```

## 性能优化

### 优化策略

1. **局部重绘** - 使用 `shouldRepaint` 只在必要时重绘
2. **图层缓存** - 复杂元素可缓存为图片
3. **元素分层** - 背景层、绘图层、预览层分离
4. **历史记录限制** - 限制撤销历史数量

### 实现要点

```dart
@override
bool shouldRepaint(WenzDrawPainter oldDelegate) {
  return oldDelegate.elements != elements ||
         oldDelegate.currentElement != currentElement ||
         oldDelegate.scale != scale ||
         oldDelegate.offset != offset;
}
```

## 平台实现

### 平台通道定义

```dart
// 用于平台特定功能的通道
static const MethodChannel _channel = MethodChannel('wenz_draw');

// 平台方法
Future<Uint8List?> exportToImage() async {
  return await _channel.invokeMethod('exportToImage');
}
```

### 各平台职责

| 平台 | 功能 |
|------|------|
| Dart | 核心绘图逻辑、UI 组件 |
| Android | 原生图片导出、文件存储 |
| iOS | 原生图片导出、文件存储 |
| Web | Canvas 优化、图片导出 |
| Windows | 原生图片导出、文件存储 |
