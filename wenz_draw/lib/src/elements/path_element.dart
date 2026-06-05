import 'dart:math' as math show sqrt;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect, StrokeCap, StrokeJoin;

import 'package:uuid/uuid.dart';

import '../canvas/paint_style.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'path_point.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// PathElement
// ---------------------------------------------------------------------------

/// 自由路径元素（不可变）。
///
/// 由一系列 [PathPoint] 连接而成的自由绘制路径。
class PathElement extends CanvasElement {
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

  /// 路径点序列
  final List<PathPoint> points;

  /// 画笔样式
  final PaintStyle style;

  @override
  String get type => 'path';

  PathElement._({
    required this.id,
    required this.points,
    required this.style,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static PathElement create({
    required List<PathPoint> points,
    required PaintStyle style,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return PathElement._(
      id: _uuid.v4(),
      points: List.unmodifiable(points),
      style: style,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final p in points) {
      final dx = p.position.dx;
      final dy = p.position.dy;
      if (dx < minX) minX = dx;
      if (dy < minY) minY = dy;
      if (dx > maxX) maxX = dx;
      if (dy > maxY) maxY = dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    if (points.length < 2) return false;
    for (int i = 0; i < points.length - 1; i++) {
      final dist = _pointToSegmentDistance(
        worldPoint,
        points[i].position,
        points[i + 1].position,
      );
      if (dist <= tolerance) return true;
    }
    return false;
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layerId': layerId,
        'visible': visible,
        'opacity': opacity,
        'zIndex': zIndex,
        'points': points.map((p) => p.toJson()).toList(),
        'style': style.toJson(),
      };

  factory PathElement.fromJson(Map<String, dynamic> json) => PathElement._(
        id: json['id'] as String,
        points: (json['points'] as List)
            .map((e) => PathPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        style: PaintStyle.fromJson(json['style'] as Map<String, dynamic>),
        layerId: json['layerId'] as String? ?? 'default',
        visible: json['visible'] as bool? ?? true,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: json['zIndex'] as int? ?? 0,
      );

  @override
  PathElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    List<PathPoint>? points,
    PaintStyle? style,
  }) {
    return PathElement._(
      id: id ?? this.id,
      points: points != null ? List.unmodifiable(points) : this.points,
      style: style ?? this.style,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  PathElement translate(Offset delta) {
    return PathElement._(
      id: id,
      points: List.unmodifiable(
        points.map((p) => p.copyWith(position: p.position + delta)),
      ),
      style: style,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  PathElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? bounds.center;
    return PathElement._(
      id: id,
      points: List.unmodifiable(
        points.map(
          (p) => p.copyWith(
            position:
                effectivePivot + (p.position - effectivePivot) * factor,
          ),
        ),
      ),
      style: style.copyWith(
        strokeWidth: style.strokeWidth * factor,
      ),
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// PathElementRenderer
// ---------------------------------------------------------------------------

/// [PathElement] 的渲染器。
class PathElementRenderer extends ElementRenderer<PathElement> {
  @override
  void render(Canvas canvas, PathElement element) {
    final pts = element.points;
    if (pts.length < 2) return;

    final paint = _buildPaint(element.style, element.opacity);
    for (int i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i].position, pts[i + 1].position, paint);
    }
  }

  @override
  bool hitTest(PathElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// 从 [PaintStyle] 构建 [Paint]。
Paint _buildPaint(PaintStyle style, double elementOpacity) {
  final alpha = ((style.opacity * elementOpacity * 255).round())
      .clamp(0, 255);
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
  if (lenSq == 0) {
    // 退化为点
    return (p - a).distance;
  }
  final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq)
      .clamp(0.0, 1.0);
  final projX = a.dx + t * dx;
  final projY = a.dy + t * dy;
  final ddx = p.dx - projX;
  final ddy = p.dy - projY;
  return math.sqrt(ddx * ddx + ddy * ddy);
}
