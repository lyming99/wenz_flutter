import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../snap/snap_resolver.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'line_arrow_style.dart';

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
    LineArrowType startArrowStyle = LineArrowType.none,
    LineArrowType? endArrowStyle,
    bool endArrow = false,
    this.headSize = LineArrowStyle.defaultHeadSize,
    this.startBinding,
    this.endBinding,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  }) : startArrowStyle = startArrowStyle,
       endArrowStyle =
           endArrowStyle ??
           (endArrow ? LineArrowType.normal : LineArrowType.none);

  static const elementType = 'curve';

  @override
  final String id;

  final Offset start;
  final Offset end;
  final Offset control;
  final PaintStyle style;
  final LineArrowType startArrowStyle;
  final LineArrowType endArrowStyle;
  final double headSize;
  final SnapBinding? startBinding;
  final SnapBinding? endBinding;

  @override
  final String layerId;

  @override
  final bool visible;

  @override
  final double opacity;

  @override
  final int zIndex;

  @override
  final String? groupId;

  @override
  String get type => elementType;

  LineArrowStyle get arrowStyle => LineArrowStyle(
    startArrowStyle: startArrowStyle,
    endArrowStyle: endArrowStyle,
    headSize: headSize,
  );

  bool get endArrow => endArrowStyle.isEnabled;

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
    return LineArrowGeometryUtils.expandBounds(
      bounds: boundsForPoints(allPoints),
      style: arrowStyle,
      strokeWidth: style.strokeWidth,
    );
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
    return LineArrowEndpoint.values.any(
      (endpoint) => LineArrowGeometryUtils.hitTestArrow(
        worldPoint: worldPoint,
        type: arrowStyle.typeFor(endpoint),
        tip: endpoint == LineArrowEndpoint.start ? start : end,
        direction: tangentDirection(endpoint),
        headSize: arrowStyle.effectiveHeadSize,
        tolerance: threshold,
      ),
    );
  }

  Offset? tangentDirection(LineArrowEndpoint endpoint) {
    final tip = endpoint == LineArrowEndpoint.start ? start : end;
    final direct = tip - control;
    if (direct.distance >= 0.1) {
      return direct;
    }
    const steps = 32;
    final indices = endpoint == LineArrowEndpoint.start
        ? Iterable<int>.generate(steps, (i) => i + 1)
        : Iterable<int>.generate(steps, (i) => steps - 1 - i);
    for (final i in indices) {
      final candidate = pointAt(i / steps);
      final direction = tip - candidate;
      if (direction.distance >= 0.1) {
        return direction;
      }
    }
    return null;
  }

  Offset? get endTangentDirection => tangentDirection(LineArrowEndpoint.end);

  @override
  CurveElement copyWith({
    String? id,
    Offset? start,
    Offset? end,
    Offset? control,
    PaintStyle? style,
    LineArrowStyle? arrowStyle,
    LineArrowType? startArrowStyle,
    LineArrowType? endArrowStyle,
    bool? endArrow,
    double? headSize,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
  }) {
    final currentArrowStyle = arrowStyle ?? this.arrowStyle;
    final nextArrowStyle = currentArrowStyle.copyWith(
      startArrowStyle: startArrowStyle,
      endArrowStyle:
          endArrowStyle ??
          (endArrow == null
              ? null
              : endArrow
              ? LineArrowType.normal
              : LineArrowType.none),
      headSize: headSize,
    );
    return CurveElement(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      control: control ?? this.control,
      style: style ?? this.style,
      startArrowStyle: nextArrowStyle.startArrowStyle,
      endArrowStyle: nextArrowStyle.endArrowStyle,
      headSize: nextArrowStyle.effectiveHeadSize,
      startBinding: identical(startBinding, _unset)
          ? this.startBinding
          : startBinding as SnapBinding?,
      endBinding: identical(endBinding, _unset)
          ? this.endBinding
          : endBinding as SnapBinding?,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
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
      arrowStyle: arrowStyle.scale(factor),
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
      'groupId': groupId,
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'control': {'x': control.dx, 'y': control.dy},
      'style': style.toJson(),
      'arrowStyle': arrowStyle.toJson(),
      'endArrow': endArrow,
      'headSize': headSize,
      if (startBinding != null) 'startBinding': startBinding!.toJson(),
      if (endBinding != null) 'endBinding': endBinding!.toJson(),
    };
  }

  static const _unset = Object();
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
    for (final endpoint in LineArrowEndpoint.values) {
      LineArrowGeometryUtils.drawArrow(
        canvas,
        paint,
        type: element.arrowStyle.typeFor(endpoint),
        tip: endpoint == LineArrowEndpoint.start ? element.start : element.end,
        direction: element.tangentDirection(endpoint),
        headSize: element.arrowStyle.effectiveHeadSize,
      );
    }
  }

  @override
  bool hitTest(CurveElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
