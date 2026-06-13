import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

/// A quadratic Bézier curve defined by a start point, an end point and a
/// single control point.
@immutable
class CurveElement extends CanvasElement {
  const CurveElement({
    required this.id,
    required this.start,
    required this.end,
    required this.control,
    this.style = const PaintStyle(),
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'curve';

  @override
  final String id;

  final Offset start;
  final Offset end;
  final Offset control;
  final PaintStyle style;

  @override
  final String layerId;

  @override
  final bool visible;

  @override
  final double opacity;

  @override
  final int zIndex;

  @override
  String get type => elementType;

  /// Sample the quadratic Bézier at parameter [t] (0 → start, 1 → end).
  Offset pointAt(double t) {
    final u = 1 - t;
    return Offset(
      u * u * start.dx + 2 * u * t * control.dx + t * t * end.dx,
      u * u * start.dy + 2 * u * t * control.dy + t * t * end.dy,
    );
  }

  /// Approximate bounds by sampling the curve plus the control point.
  @override
  Rect get bounds {
    // The convex hull of start, control, end contains the curve.
    final allPoints = [start, control, end];
    return boundsForPoints(allPoints).inflate(style.strokeWidth / 2);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    final threshold = tolerance + style.strokeWidth / 2;
    // Sample the curve densely for hit testing.
    const steps = 32;
    Offset? prev;
    for (var i = 0; i <= steps; i++) {
      final p = pointAt(i / steps);
      if (prev != null && distanceToSegment(worldPoint, prev, p) <= threshold) {
        return true;
      }
      prev = p;
    }
    return false;
  }

  @override
  CurveElement copyWith({
    String? id,
    Offset? start,
    Offset? end,
    Offset? control,
    PaintStyle? style,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return CurveElement(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      control: control ?? this.control,
      style: style ?? this.style,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  CurveElement translate(Offset delta) {
    return copyWith(
      start: start + delta,
      end: end + delta,
      control: control + delta,
    );
  }

  @override
  CurveElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      start: scalePoint(start, factor, origin),
      end: scalePoint(end, factor, origin),
      control: scalePoint(control, factor, origin),
      style: style.copyWith(strokeWidth: style.strokeWidth * factor.abs()),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'layerId': layerId,
      'visible': visible,
      'opacity': opacity,
      'zIndex': zIndex,
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'control': {'x': control.dx, 'y': control.dy},
      'style': style.toJson(),
    };
  }
}

class CurveElementRenderer extends ElementRenderer<CurveElement> {
  const CurveElementRenderer();

  @override
  void render(Canvas canvas, CurveElement element) {
    if (!element.visible) return;
    final paint = element.style
        .copyWith(opacity: element.style.opacity * element.opacity)
        .toPaint();
    final path = Path()
      ..moveTo(element.start.dx, element.start.dy)
      ..quadraticBezierTo(
        element.control.dx,
        element.control.dy,
        element.end.dx,
        element.end.dy,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool hitTest(CurveElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
