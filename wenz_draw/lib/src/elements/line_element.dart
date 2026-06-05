import 'dart:math' as math show sqrt, min, max;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect, StrokeCap, StrokeJoin;

import 'package:uuid/uuid.dart';

import '../canvas/paint_style.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// LineElement
// ---------------------------------------------------------------------------

/// 直线元素（不可变）。
class LineElement extends CanvasElement {
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

  @override
  String get type => 'line';

  LineElement._({
    required this.id,
    required this.start,
    required this.end,
    required this.style,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static LineElement create({
    required Offset start,
    required Offset end,
    required PaintStyle style,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return LineElement._(
      id: _uuid.v4(),
      start: start,
      end: end,
      style: style,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
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
      };

  factory LineElement.fromJson(Map<String, dynamic> json) => LineElement._(
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
        layerId: json['layerId'] as String? ?? 'default',
        visible: json['visible'] as bool? ?? true,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: json['zIndex'] as int? ?? 0,
      );

  @override
  LineElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Offset? start,
    Offset? end,
    PaintStyle? style,
  }) {
    return LineElement._(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      style: style ?? this.style,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  LineElement translate(Offset delta) {
    return LineElement._(
      id: id,
      start: start + delta,
      end: end + delta,
      style: style,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  LineElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? bounds.center;
    return LineElement._(
      id: id,
      start: effectivePivot + (start - effectivePivot) * factor,
      end: effectivePivot + (end - effectivePivot) * factor,
      style: style.copyWith(strokeWidth: style.strokeWidth * factor),
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// LineElementRenderer
// ---------------------------------------------------------------------------

/// [LineElement] 的渲染器。
class LineElementRenderer extends ElementRenderer<LineElement> {
  @override
  void render(Canvas canvas, LineElement element) {
    final paint = _buildPaint(element.style, element.opacity);
    canvas.drawLine(element.start, element.end, paint);
  }

  @override
  bool hitTest(LineElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
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
