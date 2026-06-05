import 'dart:math' as math show sqrt;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect, StrokeCap, StrokeJoin;

import 'package:uuid/uuid.dart';

import '../canvas/paint_style.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// EllipseElement
// ---------------------------------------------------------------------------

/// 椭圆元素（不可变）。
class EllipseElement extends CanvasElement {
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

  /// 椭圆的外接矩形
  final Rect rect;

  /// 描边样式
  final PaintStyle stroke;

  /// 填充样式（null 表示不填充）
  final PaintStyle? fill;

  @override
  String get type => 'ellipse';

  EllipseElement._({
    required this.id,
    required this.rect,
    required this.stroke,
    this.fill,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static EllipseElement create({
    required Rect rect,
    required PaintStyle stroke,
    PaintStyle? fill,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return EllipseElement._(
      id: _uuid.v4(),
      rect: rect,
      stroke: stroke,
      fill: fill,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds => rect;

  /// 椭圆中心
  Offset get center => rect.center;

  /// 半长轴（水平）
  double get a => rect.width / 2;

  /// 半短轴（垂直）
  double get b => rect.height / 2;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    // 标准椭圆方程: ((x-cx)/a)^2 + ((y-cy)/b)^2 <= 1
    // 加上 tolerance 容差
    final cx = center.dx;
    final cy = center.dy;
    final halfA = a;
    final halfB = b;
    if (halfA == 0 || halfB == 0) return false;

    final dx = worldPoint.dx - cx;
    final dy = worldPoint.dy - cy;
    final value = (dx * dx) / (halfA * halfA) + (dy * dy) / (halfB * halfB);

    // 点在椭圆内或距离椭圆边 < tolerance
    if (value <= 1.0) return true;

    // 计算点到椭圆边的近似距离
    // 简化：使用 sqrt(value) - 1 作为归一化距离因子
    final dist = (math.sqrt(value) - 1.0) * math.sqrt(halfA * halfA + halfB * halfB) / math.sqrt(2);
    return dist <= tolerance;
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
        'stroke': stroke.toJson(),
        'fill': fill?.toJson(),
      };

  factory EllipseElement.fromJson(Map<String, dynamic> json) {
    final r = json['rect'] as Map<String, dynamic>;
    return EllipseElement._(
      id: json['id'] as String,
      rect: Rect.fromLTRB(
        (r['left'] as num).toDouble(),
        (r['top'] as num).toDouble(),
        (r['right'] as num).toDouble(),
        (r['bottom'] as num).toDouble(),
      ),
      stroke: PaintStyle.fromJson(json['stroke'] as Map<String, dynamic>),
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
  EllipseElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Rect? rect,
    PaintStyle? stroke,
    PaintStyle? fill,
    bool clearFill = false,
  }) {
    return EllipseElement._(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      stroke: stroke ?? this.stroke,
      fill: clearFill ? null : (fill ?? this.fill),
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  EllipseElement translate(Offset delta) {
    return EllipseElement._(
      id: id,
      rect: rect.translate(delta.dx, delta.dy),
      stroke: stroke,
      fill: fill,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  EllipseElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? rect.center;
    final cx = effectivePivot.dx;
    final cy = effectivePivot.dy;
    final newRect = Rect.fromLTRB(
      cx + (rect.left - cx) * factor,
      cy + (rect.top - cy) * factor,
      cx + (rect.right - cx) * factor,
      cy + (rect.bottom - cy) * factor,
    );
    return EllipseElement._(
      id: id,
      rect: newRect,
      stroke: stroke.copyWith(strokeWidth: stroke.strokeWidth * factor),
      fill: fill?.copyWith(strokeWidth: fill!.strokeWidth * factor),
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// EllipseElementRenderer
// ---------------------------------------------------------------------------

/// [EllipseElement] 的渲染器。
class EllipseElementRenderer extends ElementRenderer<EllipseElement> {
  @override
  void render(Canvas canvas, EllipseElement element) {
    // 填充
    if (element.fill != null) {
      final fillPaint = _buildPaintFromStyle(
          element.fill!, element.opacity,
          styleType: PaintingStyle.fill);
      canvas.drawOval(element.rect, fillPaint);
    }

    // 描边
    final strokePaint =
        _buildPaintFromStyle(element.stroke, element.opacity);
    canvas.drawOval(element.rect, strokePaint);
  }

  @override
  bool hitTest(EllipseElement element, Offset worldPoint, double tolerance) {
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
