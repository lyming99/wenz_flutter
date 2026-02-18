# 无限画布与缩放功能 - 需求对齐文档

## 一、功能概述

### 无限画布
画布没有固定边界，用户可以向任意方向（上下左右）自由移动和绘制，理论上画布大小无限。

### 缩放功能
- 支持以画布中心或手势焦点为中心进行缩放
- 支持双指捏合缩放（移动端）
- 支持鼠标滚轮缩放（桌面端）
- 提供缩放级别限制（最小/最大倍数）

## 二、核心概念

### 2.1 坐标系统

```
屏幕坐标系 (Screen Coordinates)
    │
    │ 转换矩阵 (Transform)
    ▼
画布坐标系 (Canvas Coordinates)
    │
    │ 绘制变换 (Draw Transform)
    ▼
世界坐标系 (World Coordinates)
    │
    │ 内容层
    ▼
绘图元素 (Drawing Elements)
```

**坐标转换关系：**
```
屏幕坐标 = (世界坐标 × 缩放比例) + 平移偏移
世界坐标 = (屏幕坐标 - 平移偏移) / 缩放比例
```

### 2.2 变换矩阵

```dart
class CanvasTransform {
  final double scale;      // 缩放比例
  final Offset offset;     // 平移偏移
  final Offset focalPoint; // 缩放焦点

  const CanvasTransform({
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.focalPoint = Offset.zero,
  });

  // 应用变换
  Matrix4 toMatrix4() {
    return Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(scale, scale);
  }
}
```

## 三、交互设计

### 3.1 手势操作

| 操作 | 触发方式 | 功能 |
|------|----------|------|
| 绘制 | 单指拖动 | 在当前工具下绘制 |
| 平移 | 双指拖动 | 移动画布视角 |
| 缩放 | 双指捏合 | 以手势中心缩放 |
| 缩放 | 鼠标滚轮 | 以鼠标位置缩放 |
| 缩放 | 缩放按钮 | 以画布中心缩放 |

### 3.2 操作模式

**模式1：工具优先模式**
- 默认状态下，单指操作为绘制
- 空格键+拖动 或 中键拖动 为平移
- 双指操作自动为缩放/平移

**模式2：分离模式**
- 切换到"平移工具"时，所有拖动都是平移
- 切换到"绘制工具"时，单指拖动是绘制
- 双指缩放始终可用

### 3.3 缩放级别

```dart
class ZoomLevels {
  static const double min = 0.1;   // 最小 10%
  static const double max = 10.0;  // 最大 1000%
  static const double default_ = 1.0;

  // 预设缩放级别
  static const List<double> presets = [
    0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0
  ];
}
```

## 四、实现方案

### 4.1 核心类设计

```dart
/// 无限画布控制器
class InfiniteCanvasController extends ChangeNotifier {
  // 当前变换
  CanvasTransform _transform = CanvasTransform();
  CanvasTransform get transform => _transform;

  // 最小/最大缩放
  double _minScale = 0.1;
  double _maxScale = 10.0;

  // 操作模式
  CanvasOperationMode _mode = CanvasOperationMode.tool;

  // 方法
  void pan(Offset delta);
  void zoom(double scale, {Offset? focalPoint});
  void zoomToFit(List<DrawingElement> elements);
  void resetView();
  Offset screenToWorld(Offset screenPoint);
  Offset worldToScreen(Offset worldPoint);
}

/// 操作模式
enum CanvasOperationMode {
  tool,   // 工具模式（可绘制）
  pan,    // 平移模式
}

/// 手势状态
enum GestureState {
  idle,       // 空闲
  drawing,    // 绘制中
  panning,    // 平移中
  zooming,    // 缩放中
}
```

### 4.2 手势处理流程

```
┌─────────────────────────────────────────────────────────────────┐
│                     GestureDetector                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐│
│  │   onPanStart     │  │  onScaleStart    │  │ onLongPressStart││
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬────────┘│
│           │                     │                      │         │
│           ▼                     ▼                      ▼         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    GestureRecognizer                         ││
│  │  判断：单指/双指 + 当前模式 → 确定操作类型                    ││
│  └─────────────────────────────────────────────────────────────┘│
│           │                     │                      │         │
│           ▼                     ▼                      ▼         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │ 绘制处理器   │    │ 缩放处理器   │    │  平移处理器      │   │
│  │ DrawHandler  │    │ ZoomHandler  │    │  PanHandler      │   │
│  └──────────────┘    └──────────────┘    └──────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 绘制流程

```dart
// InfiniteCanvasPainter
@override
void paint(Canvas canvas, Size size) {
  // 1. 绘制背景（无限网格）
  _drawGrid(canvas, size);

  // 2. 应用变换
  canvas.save();
  _applyTransform(canvas);

  // 3. 绘制所有元素
  for (var element in elements) {
    // 只绘制在视口内的元素（视锥剔除）
    if (_isInViewport(element)) {
      element.draw(canvas);
    }
  }

  // 4. 绘制当前正在绘制的元素
  if (currentElement != null) {
    currentElement!.draw(canvas);
  }

  // 5. 绘制边界指示（可选，显示画布原点等）
  _drawIndicators(canvas);

  canvas.restore();
}

void _applyTransform(Canvas canvas) {
  canvas.translate(transform.offset.dx, transform.offset.dy);
  canvas.scale(transform.scale, transform.scale);
}
```

### 4.4 无限网格背景

```dart
void _drawGrid(Canvas canvas, Size size) {
  // 计算网格参数
  final gridSize = _getGridSizeForScale(transform.scale);

  // 计算可见区域的起始网格位置
  final startCol = (transform.offset.dx / gridSize).floor() - 1;
  final startRow = (transform.offset.dy / gridSize).floor() - 1;
  final endCol = ((transform.offset.dx + size.width) / gridSize).ceil() + 1;
  final endRow = ((transform.offset.dy + size.height) / gridSize).ceil() + 1;

  // 绘制网格线
  final paint = Paint()
    ..color = Colors.grey.withOpacity(0.3)
    ..strokeWidth = 1.0 / transform.scale;

  // 绘制主网格线和子网格线
  for (int col = startCol; col <= endCol; col++) {
    final x = col * gridSize;
    canvas.drawLine(Offset(x, startRow * gridSize), Offset(x, endRow * gridSize), paint);
  }

  for (int row = startRow; row <= endRow; row++) {
    final y = row * gridSize;
    canvas.drawLine(Offset(startCol * gridSize, y), Offset(endCol * gridSize, y), paint);
  }

  // 绘制原点十字
  _drawOrigin(canvas);
}

double _getGridSizeForScale(double scale) {
  // 根据缩放级别调整网格大小，保持视觉一致性
  const baseGridSize = 50.0;
  if (scale < 0.5) return baseGridSize * 4;
  if (scale < 1.0) return baseGridSize * 2;
  if (scale < 2.0) return baseGridSize;
  if (scale < 4.0) return baseGridSize / 2;
  return baseGridSize / 4;
}
```

## 五、关键算法

### 5.1 以指定点为中心缩放

```dart
void zoom(double newScale, {Offset? focalPoint}) {
  focalPoint ??= _getCanvasCenter();

  // 限制缩放范围
  newScale = newScale.clamp(_minScale, _maxScale);

  // 计算缩放前的世界坐标
  final worldPoint = screenToWorld(focalPoint);

  // 应用新缩放
  _transform = CanvasTransform(
    scale: newScale,
    offset: _calculateOffsetForZoom(newScale, focalPoint, worldPoint),
  );

  notifyListeners();
}

Offset _calculateOffsetForZoom(double newScale, Offset focalPoint, Offset worldPoint) {
  // 新的偏移 = 焦点 - (世界坐标 × 新缩放)
  return Offset(
    focalPoint.dx - worldPoint.dx * newScale,
    focalPoint.dy - worldPoint.dy * newScale,
  );
}
```

### 5.2 平滑惯性滚动

```dart
class FlingGesture {
  Timer? _timer;
  Offset _velocity = Offset.zero;

  void start(Offset velocity) {
    _velocity = velocity;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _update);
  }

  void _update(Timer timer) {
    if (_velocity.distance < 0.1) {
      timer.cancel();
      return;
    }

    controller.pan(_velocity);
    _velocity *= 0.95; // 摩擦系数
  }
}
```

### 5.3 视锥剔除优化

```dart
bool _isInViewport(DrawingElement element, Canvas canvas) {
  final viewport = Rect.fromLTWH(
    -transform.offset.dx / transform.scale,
    -transform.offset.dy / transform.scale,
    canvasSize.width / transform.scale,
    canvasSize.height / transform.scale,
  );

  return element.bounds.overlaps(viewport);
}
```

## 六、UI 组件

### 6.1 缩放控制面板

```dart
class ZoomControls extends StatelessWidget {
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(blurRadius: 4)],
        ),
        child: Column(
          children: [
            IconButton(icon: Icon(Icons.add), onPressed: () => controller.zoomIn()),
            Text('${(controller.scale * 100).toInt()}%'),
            IconButton(icon: Icon(Icons.remove), onPressed: () => controller.zoomOut()),
            IconButton(icon: Icon(Icons.fit_screen), onPressed: () => controller.zoomToFit()),
            IconButton(icon: Icon(Icons.center_focus_strong), onPressed: () => controller.resetView()),
          ],
        ),
      ),
    );
  }
}
```

### 6.2 小地图（Minimap）

```dart
class Minimap extends StatelessWidget {
  final InfiniteCanvasController controller;
  final List<DrawingElement> elements;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
        ),
        child: CustomPaint(
          painter: MinimapPainter(
            elements: elements,
            viewport: controller.viewportRect,
            transform: controller.transform,
          ),
        ),
      ),
    );
  }
}
```

## 七、开发任务清单

### Phase 1: 基础无限画布
- [ ] 实现 `CanvasTransform` 数据结构
- [ ] 实现 `InfiniteCanvasController`
- [ ] 实现坐标转换方法（screenToWorld / worldToScreen）
- [ ] 实现无限网格背景绘制

### Phase 2: 手势交互
- [ ] 实现双指拖动平移
- [ ] 实现双指捏合缩放
- [ ] 实现鼠标滚轮缩放
- [ ] 实现模式切换（工具/平移）

### Phase 3: 缩放功能
- [ ] 实现以点为中心的缩放
- [ ] 实现缩放级别限制
- [ ] 实现缩放控制面板UI
- [ ] 实现"适合屏幕"功能

### Phase 4: 高级功能
- [ ] 实现平滑惯性滚动
- [ ] 实现视锥剔除优化
- [ ] 实现小地图（Minimap）
- [ ] 实现原点复位功能

### Phase 5: 细节完善
- [ ] 添加键盘快捷键（空格+拖动平移）
- [ ] 添加缩放动画
- [ ] 性能优化（大型画布）
- [ ] 单元测试

## 八、参考资源

- Flutter CustomPainter: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- Interactive Viewer: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
- 无限画布实现参考：Figma, Miro, Excalidraw
