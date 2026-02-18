# Perfect Freehand Flutter 移植指南

> 自由绘制平滑算法移植完整方案
> 更新日期: 2026-01-30

---

## 目录

1. [方案概述](#方案概述)
2. [方案一：使用现成的 Dart 包](#方案一使用现成的-dart-包)
3. [方案二：自己移植 Perfect Freehand](#方案二自己移植-perfect-freehand)
4. [核心算法解析](#核心算法解析)
5. [完整实现示例](#完整实现示例)

---

## 方案概述

Perfect Freehand 是 Excalidraw 自由绘制的核心库，用于将用户输入的点列转换为平滑的手绘线条。

```
输入点列 → Perfect Freehand → 轮廓多边形 → Canvas 渲染
```

### 可选方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 使用 `perfect_freehand` 包 | 开箱即用，官方维护 | 功能可能不如原版完整 | ⭐⭐⭐⭐⭐ |
| 使用 `freehand` 包 | 轻量级 | 维护较少 | ⭐⭐⭐ |
| 自己移植算法 | 完全控制，学习价值高 | 工作量大 | ⭐⭐⭐⭐ |
| JS 互操作 | 功能完整 | 性能开销大 | ⭐⭐ |

---

## 方案一：使用现成的 Dart 包

### 1.1 perfect_freehand 包

**GitHub**: https://github.com/steveruizok/perfect-freehand-dart
**pub.dev**: https://pub.dev/packages/perfect_freehand

#### 安装

```yaml
dependencies:
  perfect_freehand: ^2.5.2
```

#### 基础用法

```dart
import 'package:perfect_freehand/perfect_freehand.dart';

// 定义输入点（每个点包含 x, y 坐标和可选的压力值）
final List<Point> inputPoints = [
  Point(0, 0, 0.5),
  Point(10, 5, 0.6),
  Point(20, 8, 0.7),
  Point(30, 12, 0.8),
  // ... 更多点
];

// 配置选项
final options = StrokeOptions(
  size: 16,           // 基础大小
  thinning: 0.5,      // 压力影响 (0-1)
  smoothing: 0.5,     // 平滑度 (0-1)
  streamline: 0.5,    // 流畅度 (0-1)
  start: StrokeCap.round,  // 起点样式
  end: StrokeCap.round,    // 终点样式
);

// 生成笔触轮廓点
final List<Point> strokePoints = getStroke(inputPoints, options: options);
```

#### 与 CustomPainter 集成

```dart
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class FreehandPainter extends CustomPainter {
  final List<Point> strokePoints;
  final Color color;

  FreehandPainter({
    required this.strokePoints,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokePoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 将点转换为 Offset 列表
    final offsets = strokePoints.map((p) => Offset(p.x, p.y)).toList();

    // 创建路径
    final path = Path()..addPolygon(offsets, true);

    // 绘制填充
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FreehandPainter oldDelegate) {
    return strokePoints != oldDelegate.strokePoints || color != oldDelegate.color;
  }
}
```

#### 完整的绘画组件

```dart
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class FreehandCanvas extends StatefulWidget {
  const FreehandCanvas({super.key});

  @override
  State<FreehandCanvas> createState() => _FreehandCanvasState();
}

class _FreehandCanvasState extends State<FreehandCanvas> {
  final List<List<Point>> _strokes = [];
  List<Point> _currentStroke = [];

  StrokeOptions _options = StrokeOptions(
    size: 16,
    thinning: 0.5,
    smoothing: 0.5,
    streamline: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _currentStroke = [Point(
            details.localPosition.dx,
            details.localPosition.dy,
            0.5, // 压力值（如果支持）
          )];
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _currentStroke.add(Point(
            details.localPosition.dx,
            details.localPosition.dy,
            0.5,
          ));
        });
      },
      onPanEnd: (_) {
        if (_currentStroke.isNotEmpty) {
          final strokePoints = getStroke(_currentStroke, options: _options);
          setState(() {
            _strokes.add(strokePoints);
            _currentStroke = [];
          });
        }
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _FreehandPainter(
          strokes: _strokes,
          currentStroke: _currentStroke,
          options: _options,
        ),
      ),
    );
  }
}

class _FreehandPainter extends CustomPainter {
  final List<List<Point>> strokes;
  final List<Point> currentStroke;
  final StrokeOptions options;

  _FreehandPainter({
    required this.strokes,
    required this.currentStroke,
    required this.options,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制已完成的笔画
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 绘制当前笔画（实时预览）
    if (currentStroke.length > 1) {
      final previewStroke = getStroke(currentStroke, options: options);
      _drawStroke(canvas, previewStroke);
    }
  }

  void _drawStroke(Canvas canvas, List<Point> points) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..antiAlias = true;

    final path = Path();
    final offsets = points.map((p) => Offset(p.x, p.y)).toList();
    path.addPolygon(offsets, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FreehandPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}
```

---

## 方案二：自己移植 Perfect Freehand

如果现成包不能满足需求，可以自己移植原算法。

### 2.1 算法原理

Perfect Freehand 的核心流程：

```
1. 输入点列采样与简化
   ↓
2. 生成样条曲线 (Spline Interpolation)
   ↓
3. 计算轮廓点 (Outline Points)
   ↓
4. 返回多边形顶点
```

### 2.2 核心数据结构

```dart
/// 输入点
class InputPoint {
  final double x;
  final double y;
  final double pressure; // 0-1，可选

  InputPoint(this.x, this.y, [this.pressure = 0.5]);
}

/// 笔触选项
class StrokeOptions {
  final double size;           // 笔触基础大小
  final double thinning;       // 压力对粗细的影响 (0-1)
  final double smoothing;      // 平滑度 (0-1)
  final double streamline;     // 流畅度 (0-1)
  final bool simulatePressure; // 是否模拟压力

  const StrokeOptions({
    this.size = 16,
    this.thinning = 0.5,
    this.smoothing = 0.5,
    this.streamline = 0.5,
    this.simulatePressure = false,
  });
}

/// 轮廓点
class OutlinePoint {
  final double x;
  final double y;

  OutlinePoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);
}
```

### 2.3 核心算法实现

```dart
import 'dart:math' as math;

class PerfectFreehand {
  const PerfectFreehand();

  /// 主函数：生成笔触轮廓
  List<OutlinePoint> getStroke(
    List<InputPoint> points, {
    StrokeOptions options = const StrokeOptions(),
  }) {
    if (points.length < 2) return [];

    // 1. 采样和简化点列
    final sampled = _samplePoints(points, options);

    // 2. 生成样条曲线点
    final splinePoints = _generateSpline(sampled, options);

    // 3. 计算轮廓
    final outline = _generateOutline(splinePoints, options);

    return outline;
  }

  /// 采样点列 - 根据速度/压力调整密度
  List<InputPoint> _samplePoints(
    List<InputPoint> points,
    StrokeOptions options,
  ) {
    if (points.length < 3) return points;

    final result = <InputPoint>[];
    result.add(points.first);

    double lastDistance = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      // 计算点到点的距离
      final distance = _distance(prev, curr);

      // 根据 streamline 参数决定是否添加这个点
      final shouldAdd = _shouldAddPoint(
        distance,
        lastDistance,
        options.streamline,
      );

      if (shouldAdd) {
        // 如果没有压力信息，模拟压力
        final pressure = curr.pressure > 0
            ? curr.pressure
            : (options.simulatePressure
                ? _simulatePressure(distance, lastDistance)
                : 0.5);

        result.add(InputPoint(curr.x, curr.y, pressure));
        lastDistance = distance;
      }
    }

    result.add(points.last);
    return result;
  }

  /// 生成样条曲线 - 使用三次贝塞尔曲线
  List<SplinePoint> _generateSpline(
    List<InputPoint> points,
    StrokeOptions options,
  ) {
    if (points.length < 2) return [];

    final result = <SplinePoint>[];

    // 为每个点计算控制点
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final prev = i > 0 ? points[i - 1] : point;
      final next = i < points.length - 1 ? points[i + 1] : point;

      // 计算切线向量
      final tangent = _computeTangent(prev, point, next);

      // 计算前后控制点
      final cp1 = _computeControlPoint(point, tangent, -1, options);
      final cp2 = _computeControlPoint(point, tangent, 1, options);

      result.add(SplinePoint(
        point: point,
        controlPoint1: cp1,
        controlPoint2: cp2,
      ));
    }

    return result;
  }

  /// 生成轮廓 - 在曲线两侧生成多边形顶点
  List<OutlinePoint> _generateOutline(
    List<SplinePoint> splinePoints,
    StrokeOptions options,
  ) {
    if (splinePoints.isEmpty) return [];

    final leftOutline = <OutlinePoint>[];
    final rightOutline = <OutlinePoint>[];

    for (int i = 0; i < splinePoints.length; i++) {
      final sp = splinePoints[i];
      final prev = i > 0 ? splinePoints[i - 1] : sp;
      final next = i < splinePoints.length - 1 ? splinePoints[i + 1] : sp;

      // 计算当前点的笔触大小
      final size = _computeSize(sp.point.pressure, options);

      // 计算法向量
      final normal = _computeNormal(prev.point, sp.point, next.point);

      // 生成左右轮廓点
      leftOutline.add(OutlinePoint(
        sp.point.x + normal.x * size / 2,
        sp.point.y + normal.y * size / 2,
      ));

      rightOutline.add(OutlinePoint(
        sp.point.x - normal.x * size / 2,
        sp.point.y - normal.y * size / 2,
      ));
    }

    // 连接左右轮廓（右侧需要反向）
    return [...leftOutline, ...rightOutline.reversed];
  }

  // ==================== 辅助方法 ====================

  double _distance(InputPoint a, InputPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _shouldAddPoint(
    double distance,
    double lastDistance,
    double streamline,
  ) {
    if (streamline >= 1) return true;
    if (streamline <= 0) return distance > 1;

    final threshold = 1 + (1 - streamline) * 10;
    return distance > threshold || (distance / lastDistance) > 1.5;
  }

  double _simulatePressure(double distance, double lastDistance) {
    // 速度越快，压力越小
    final speed = distance;
    final pressure = 1 - math.min(speed / 50, 0.6);
    return pressure.clamp(0.2, 1.0);
  }

  math.Point<double> _computeTangent(
    InputPoint prev,
    InputPoint curr,
    InputPoint next,
  ) {
    final dx1 = curr.x - prev.x;
    final dy1 = curr.y - prev.y;
    final dx2 = next.x - curr.x;
    final dy2 = next.y - curr.y;

    return math.Point<double>(
      (dx1 + dx2) / 2,
      (dy1 + dy2) / 2,
    );
  }

  math.Point<double> _computeControlPoint(
    InputPoint point,
    math.Point<double> tangent,
    int direction,
    StrokeOptions options,
  ) {
    final smoothing = options.smoothing;
    final scale = smoothing * 0.2;

    return math.Point<double>(
      point.x + tangent.x * scale * direction,
      point.y + tangent.y * scale * direction,
    );
  }

  math.Point<double> _computeNormal(
    InputPoint prev,
    InputPoint curr,
    InputPoint next,
  ) {
    // 计算切线方向
    final dx = next.x - prev.x;
    final dy = next.y - prev.y;

    // 法线是切线的垂直方向
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return math.Point(0, 1);

    return math.Point<double>(-dy / len, dx / len);
  }

  double _computeSize(double pressure, StrokeOptions options) {
    // 根据 thinning 参数调整大小
    final thinning = options.thinning;
    final baseSize = options.size;

    if (thinning <= 0) return baseSize;
    if (thinning >= 1) return baseSize * (1 - pressure * 0.8);

    return baseSize * (1 - pressure * thinning * 0.8);
  }
}

/// 样条点（包含控制点）
class SplinePoint {
  final InputPoint point;
  final math.Point<double> controlPoint1;
  final math.Point<double> controlPoint2;

  SplinePoint({
    required this.point,
    required this.controlPoint1,
    required this.controlPoint2,
  });
}
```

### 2.4 使用自定义实现

```dart
import 'package:flutter/material.dart';

class CustomFreehandPainter extends CustomPainter {
  final List<List<InputPoint>> strokes;
  final StrokeOptions options;

  CustomFreehandPainter({
    required this.strokes,
    required this.options,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pf = PerfectFreehand();

    for (final stroke in strokes) {
      final outline = pf.getStroke(stroke, options: options);

      if (outline.isEmpty) continue;

      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill
        ..antiAlias = true;

      final path = Path();
      final offsets = outline.map((p) => p.toOffset()).toList();
      path.addPolygon(offsets, true);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomFreehandPainter oldDelegate) {
    return strokes != oldDelegate.strokes;
  }
}
```

---

## 核心算法解析

### 样条插值算法

Perfect Freehand 使用**三次贝塞尔样条**来平滑曲线：

```
P0 --- P1 --- P2 --- P3
  \    |    /    样条曲线
   C1--C2
```

每个输入点 P 会生成两个控制点 C1 和 C2：

```dart
// 控制点计算公式
controlPoint = point + tangent * smoothing * 0.2 * direction

其中：
- tangent: (prev→point + point→next) / 2  // 平均切线
- direction: -1 或 1，表示前后方向
- smoothing: 平滑参数
```

### 轮廓生成算法

对于每个样条点，计算其**法向量**并沿法线方向偏移：

```dart
// 1. 计算切线方向
tangent = nextPoint - prevPoint

// 2. 法线是切线的垂直旋转
normal = (-tangent.y, tangent.x) / length

// 3. 根据压力计算笔触大小
size = baseSize * (1 - pressure * thinning)

// 4. 生成左右轮廓点
leftPoint = point + normal * size / 2
rightPoint = point - normal * size / 2
```

---

## 完整实现示例

### 带压力感应的绘画板

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PressureSensitiveCanvas extends StatefulWidget {
  const PressureSensitiveCanvas({super.key});

  @override
  State<PressureSensitiveCanvas> createState() => _PressureSensitiveCanvasState();
}

class _PressureSensitiveCanvasState extends State<PressureSensitiveCanvas> {
  final List<List<InputPoint>> _strokes = [];
  List<InputPoint> _currentStroke = [];

  final PerfectFreehand _pf = const PerfectFreehand();

  StrokeOptions _options = const StrokeOptions(
    size: 24,
    thinning: 0.7,
    smoothing: 0.6,
    streamline: 0.5,
    simulatePressure: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freehand Drawing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (event) {
          setState(() {
            _currentStroke = [InputPoint(
              event.position.dx,
              event.position.dy,
              _getPressure(event),
            )];
          });
        },
        onPointerMove: (event) {
          setState(() {
            _currentStroke.add(InputPoint(
              event.position.dx,
              event.position.dy,
              _getPressure(event),
            ));
          });
        },
        onPointerUp: (_) {
          if (_currentStroke.isNotEmpty) {
            setState(() {
              _strokes.add(_currentStroke);
              _currentStroke = [];
            });
          }
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _FreehandPainter(
            strokes: _strokes,
            currentStroke: _currentStroke,
            options: _options,
            perfectFreehand: _pf,
          ),
        ),
      ),
      bottomNavigationBar: _buildControls(),
    );
  }

  double _getPressure(PointerEvent event) {
    // 尝试获取压力值（Apple Pencil 等）
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      return event.pressure.clamp(0.0, 1.0);
    }
    return 0.5;
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('Size:'),
          Slider(
            value: _options.size,
            min: 4,
            max: 64,
            onChanged: (v) => setState(() => _options = StrokeOptions(
              size: v,
              thinning: _options.thinning,
              smoothing: _options.smoothing,
              streamline: _options.streamline,
            )),
          ),
          const Text('Thinning:'),
          Slider(
            value: _options.thinning,
            min: 0,
            max: 1,
            onChanged: (v) => setState(() => _options = StrokeOptions(
              size: _options.size,
              thinning: v,
              smoothing: _options.smoothing,
              streamline: _options.streamline,
            )),
          ),
        ],
      ),
    );
  }
}

class _FreehandPainter extends CustomPainter {
  final List<List<InputPoint>> strokes;
  final List<InputPoint> currentStroke;
  final StrokeOptions options;
  final PerfectFreehand perfectFreehand;

  _FreehandPainter({
    required this.strokes,
    required this.currentStroke,
    required this.options,
    required this.perfectFreehand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制已完成的笔画
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 绘制当前笔画
    if (currentStroke.length > 1) {
      _drawStroke(canvas, currentStroke);
    }
  }

  void _drawStroke(Canvas canvas, List<InputPoint> points) {
    final outline = perfectFreehand.getStroke(points, options: options);
    if (outline.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill
      ..antiAlias = true;

    final path = Path();
    final offsets = outline.map((p) => p.toOffset()).toList();
    path.addPolygon(offsets, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FreehandPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}
```

---

## 性能优化

### 1. 点列简化

```dart
// 在输入阶段就减少点的数量
List<InputPoint> simplifyPoints(List<InputPoint> points, double tolerance) {
  if (points.length < 3) return points;

  final result = <InputPoint>[points.first];

  for (int i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];

    if (_distance(prev, curr) > tolerance) {
      result.add(curr);
    }
  }

  result.add(points.last);
  return result;
}
```

### 2. 分段渲染

```dart
// 对于长笔画，分段渲染
void drawLongStroke(Canvas canvas, List<OutlinePoint> outline) {
  const segmentSize = 500;

  for (int i = 0; i < outline.length; i += segmentSize - 50) {
    final end = math.min(i + segmentSize, outline.length);
    final segment = outline.sublist(i, end);

    final path = Path();
    path.addPolygon(segment.map((p) => p.toOffset()).toList(), true);
    canvas.drawPath(path, _paint);
  }
}
```

### 3. 缓存机制

```dart
class StrokeCache {
  final Map<String, List<OutlinePoint>> _cache = {};

  List<OutlinePoint>? get(List<InputPoint> stroke, StrokeOptions options) {
    final key = _computeKey(stroke, options);
    return _cache[key];
  }

  void put(List<InputPoint> stroke, StrokeOptions options, List<OutlinePoint> outline) {
    final key = _computeKey(stroke, options);
    _cache[key] = outline;
  }

  String _computeKey(List<InputPoint> stroke, StrokeOptions options) {
    // 简单的哈希策略
    return '${stroke.length}_${options.size}_${options.thinning}';
  }
}
```

---

## 总结

### 推荐方案

1. **快速开发**: 使用 `perfect_freehand` 包
2. **完全控制**: 自己移植算法
3. **性能优先**: 自己移植 + 优化

### 关键点

- Perfect Freehand **只计算几何**，不负责渲染
- 使用 `CustomPainter` + `Canvas` 绘制轮廓多边形
- 核心是样条插值 + 轮廓生成算法
- 支持压力感应可获得更好效果

---

## 参考资料

- [perfect-freehand GitHub](https://github.com/steveruizok/perfect-freehand)
- [perfect-freehand-dart GitHub](https://github.com/steveruizok/perfect-freehand-dart)
- [perfect_freehand pub.dev](https://pub.dev/packages/perfect_freehand)
- [Excalidraw Architecture](https://github.com/excalidraw/excalidraw)
- [Bézier Curve - Wikipedia](https://en.wikipedia.org/wiki/B%C3%A9zier_curve)
