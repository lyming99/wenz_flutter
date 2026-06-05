import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Radius, RRect, Rect, StrokeCap, StrokeJoin;

import 'package:uuid/uuid.dart';

import '../canvas/paint_style.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// RectElement
// ---------------------------------------------------------------------------

/// 矩形元素（不可变）。
class RectElement extends CanvasElement {
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

  /// 矩形区域
  final Rect rect;

  /// 圆角半径（默认 0）
  final double borderRadius;

  /// 描边样式
  final PaintStyle stroke;

  /// 填充样式（null 表示不填充）
  final PaintStyle? fill;

  @override
  String get type => 'rect';

  RectElement._({
    required this.id,
    required this.rect,
    required this.stroke,
    this.borderRadius = 0,
    this.fill,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static RectElement create({
    required Rect rect,
    required PaintStyle stroke,
    double borderRadius = 0,
    PaintStyle? fill,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return RectElement._(
      id: _uuid.v4(),
      rect: rect,
      stroke: stroke,
      borderRadius: borderRadius,
      fill: fill,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds => rect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    // 点在矩形内部
    if (rect.contains(worldPoint)) return true;
    // 点距离矩形边框 < tolerance
    final inflated = rect.inflate(tolerance);
    final deflated = rect.deflate(tolerance);
    return inflated.contains(worldPoint) && !deflated.contains(worldPoint);
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layerId': layerId,
        'visible': visible,
        'opacity': opacity,
        'zIndex': zIndex,
        'rect': {
          'left': rect.left,
          'top': rect.top,
          'right': rect.right,
          'bottom': rect.bottom,
        },
        'borderRadius': borderRadius,
        'stroke': stroke.toJson(),
        'fill': fill?.toJson(),
      };

  factory RectElement.fromJson(Map<String, dynamic> json) {
    final r = json['rect'] as Map<String, dynamic>;
    return RectElement._(
      id: json['id'] as String,
      rect: Rect.fromLTRB(
        (r['left'] as num).toDouble(),
        (r['top'] as num).toDouble(),
        (r['right'] as num).toDouble(),
        (r['bottom'] as num).toDouble(),
      ),
      stroke: PaintStyle.fromJson(json['stroke'] as Map<String, dynamic>),
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0,
      fill: json['fill'] != null
          ? PaintStyle.fromJson(json['fill'] as Map<String, dynamic>)
          : null,
      layerId: json['layerId'] as String? ?? 'default',
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      zIndex: json['zIndex'] as int? ?? 0,
    );
  }

  @override
  RectElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Rect? rect,
    double? borderRadius,
    PaintStyle? stroke,
    PaintStyle? fill,
    bool clearFill = false,
  }) {
    return RectElement._(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      stroke: stroke ?? this.stroke,
      borderRadius: borderRadius ?? this.borderRadius,
      fill: clearFill ? null : (fill ?? this.fill),
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  RectElement translate(Offset delta) {
    return RectElement._(
      id: id,
      rect: rect.translate(delta.dx, delta.dy),
      stroke: stroke,
      borderRadius: borderRadius,
      fill: fill,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  RectElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? rect.center;
    final newRect = _scaleRect(rect, factor, effectivePivot);
    return RectElement._(
      id: id,
      rect: newRect,
      stroke: stroke.copyWith(strokeWidth: stroke.strokeWidth * factor),
      borderRadius: borderRadius * factor,
      fill: fill?.copyWith(strokeWidth: fill!.strokeWidth * factor),
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// RectElementRenderer
// ---------------------------------------------------------------------------

/// [RectElement] 的渲染器。
class RectElementRenderer extends ElementRenderer<RectElement> {
  @override
  void render(Canvas canvas, RectElement element) {
    final el = element;

    // 填充
    if (el.fill != null) {
      final fillPaint = _buildPaintFromStyle(el.fill!, el.opacity,
          styleType: PaintingStyle.fill);
      if (el.borderRadius > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(el.rect,
              Radius.circular(el.borderRadius)),
          fillPaint,
        );
      } else {
        canvas.drawRect(el.rect, fillPaint);
      }
    }

    // 描边
    final strokePaint = _buildPaintFromStyle(el.stroke, el.opacity);
    if (el.borderRadius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            el.rect, Radius.circular(el.borderRadius)),
        strokePaint,
      );
    } else {
      canvas.drawRect(el.rect, strokePaint);
    }
  }

  @override
  bool hitTest(RectElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// 从 [PaintStyle] 构建 [Paint]。
Paint _buildPaintFromStyle(PaintStyle style, double elementOpacity,
    {PaintingStyle styleType = PaintingStyle.stroke}) {
  final alpha =
      ((style.opacity * elementOpacity * 255).round()).clamp(0, 255);
  final colorValue = (style.color & 0x00FFFFFF) | (alpha << 24);
  return Paint()
    ..color = Color(colorValue)
    ..strokeWidth = style.strokeWidth
    ..strokeCap = StrokeCap.values[style.strokeCap.clamp(0, 2)]
    ..strokeJoin = StrokeJoin.values[style.strokeJoin.clamp(0, 2)]
    ..style = styleType
    ..isAntiAlias = true;
}

/// 缩放 [Rect] 相对于 [pivot]。
Rect _scaleRect(Rect r, double factor, Offset pivot) {
  final newLeft = pivot.dx + (r.left - pivot.dx) * factor;
  final newTop = pivot.dy + (r.top - pivot.dy) * factor;
  final newRight = pivot.dx + (r.right - pivot.dx) * factor;
  final newBottom = pivot.dy + (r.bottom - pivot.dy) * factor;
  return Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
}
