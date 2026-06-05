import 'dart:math' as math show cos, min, max, pi, sin, sqrt;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect, StrokeCap, StrokeJoin;

import 'package:uuid/uuid.dart';

import '../canvas/paint_style.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// ArrowElement
// ---------------------------------------------------------------------------

/// 箭头元素（不可变）。
class ArrowElement extends CanvasElement {
  @override
  final String id;
  @override
  final String layerId;
  @override
  final bool visible;
  @override
  final double opacity;
  @override
  final int zIndex;

  /// 起点
  final Offset start;

  /// 终点
  final Offset end;

  /// 画笔样式
  final PaintStyle style;

  /// 箭头头部大小
  final double arrowHeadSize;

  @override
  String get type => 'arrow';

  ArrowElement._({
    required this.id,
    required this.start,
    required this.end,
    required this.style,
    this.arrowHeadSize = 12.0,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static ArrowElement create({
    required Offset start,
    required Offset end,
    required PaintStyle style,
    double arrowHeadSize = 12.0,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return ArrowElement._(
      id: _uuid.v4(),
      start: start,
      end: end,
      style: style,
      arrowHeadSize: arrowHeadSize,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds {
    final half = arrowHeadSize;
    final left = math.min(start.dx, end.dx) - half;
    final top = math.min(start.dy, end.dy) - half;
    final right = math.max(start.dx, end.dx) + half;
    final bottom = math.max(start.dy, end.dy) + half;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return _pointToSegmentDistance(worldPoint, start, end) <= tolerance;
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layerId': layerId,
        'visible': visible,
        'opacity': opacity,
        'zIndex': zIndex,
        'startX': start.dx,
        'startY': start.dy,
        'endX': end.dx,
        'endY': end.dy,
        'style': style.toJson(),
        'arrowHeadSize': arrowHeadSize,
      };

  factory ArrowElement.fromJson(Map<String, dynamic> json) => ArrowElement._(
        id: json['id'] as String,
        start: Offset(
          (json['startX'] as num).toDouble(),
          (json['startY'] as num).toDouble(),
        ),
        end: Offset(
          (json['endX'] as num).toDouble(),
          (json['endY'] as num).toDouble(),
        ),
        style: PaintStyle.fromJson(json['style'] as Map<String, dynamic>),
        arrowHeadSize:
            (json['arrowHeadSize'] as num?)?.toDouble() ?? 12.0,
        layerId: json['layerId'] as String? ?? 'default',
        visible: json['visible'] as bool? ?? true,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: json['zIndex'] as int? ?? 0,
      );

  @override
  ArrowElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Offset? start,
    Offset? end,
    PaintStyle? style,
    double? arrowHeadSize,
  }) {
    return ArrowElement._(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      style: style ?? this.style,
      arrowHeadSize: arrowHeadSize ?? this.arrowHeadSize,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  ArrowElement translate(Offset delta) {
    return ArrowElement._(
      id: id,
      start: start + delta,
      end: end + delta,
      style: style,
      arrowHeadSize: arrowHeadSize,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  ArrowElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? bounds.center;
    return ArrowElement._(
      id: id,
      start: effectivePivot + (start - effectivePivot) * factor,
      end: effectivePivot + (end - effectivePivot) * factor,
      style: style.copyWith(strokeWidth: style.strokeWidth * factor),
      arrowHeadSize: arrowHeadSize * factor,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// ArrowElementRenderer
// ---------------------------------------------------------------------------

/// [ArrowElement] 的渲染器。
class ArrowElementRenderer extends ElementRenderer<ArrowElement> {
  @override
  void render(Canvas canvas, ArrowElement element) {
    final paint = _buildPaint(element.style, element.opacity);
    canvas.drawLine(element.start, element.end, paint);

    // 绘制箭头头部（三角形填充）
    final arrowPath = _buildArrowHead(
      element.end,
      element.start,
      element.arrowHeadSize,
    );
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool hitTest(ArrowElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }

  /// 构建箭头头部三角形路径。
  ///
  /// [tip] 箭头尖端（终点）。
  /// [from] 箭头尾部方向点（起点）。
  /// [size] 箭头大小。
  Path _buildArrowHead(Offset tip, Offset from, double size) {
    final direction = tip - from;
    final length = direction.distance;
    if (length == 0) return Path();

    final unitDir = direction / length;
    // 箭头两条边与主轴夹角约 25 度
    const angle = 25.0 * math.pi / 180.0;

    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    // 旋转 unitDir ±angle 得到两条边的方向（指向 tip 方向）
    final dir1 = Offset(
      unitDir.dx * cosA - unitDir.dy * sinA,
      unitDir.dx * sinA + unitDir.dy * cosA,
    );
    final dir2 = Offset(
      unitDir.dx * cosA + unitDir.dy * sinA,
      -unitDir.dx * sinA + unitDir.dy * cosA,
    );

    final p1 = tip - dir1 * size;
    final p2 = tip - dir2 * size;

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.close();
    return path;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// 从 [PaintStyle] 构建 [Paint]。
Paint _buildPaint(PaintStyle style, double elementOpacity) {
  final alpha =
      ((style.opacity * elementOpacity * 255).round()).clamp(0, 255);
  final colorValue = (style.color & 0x00FFFFFF) | (alpha << 24);
  return Paint()
    ..color = Color(colorValue)
    ..strokeWidth = style.strokeWidth
    ..strokeCap = StrokeCap.values[style.strokeCap.clamp(0, 2)]
    ..strokeJoin = StrokeJoin.values[style.strokeJoin.clamp(0, 2)]
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
}

/// 点到线段的距离。
double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distance;
  final t =
      (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq).clamp(0.0, 1.0);
  final projX = a.dx + t * dx;
  final projY = a.dy + t * dy;
  final ddx = p.dx - projX;
  final ddy = p.dy - projY;
  return math.sqrt(ddx * ddx + ddy * ddy);
}
