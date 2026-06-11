import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../snap/snap_resolver.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class ArrowElement extends CanvasElement {
  const ArrowElement({
    required this.id,
    required this.start,
    required this.end,
    this.style = const PaintStyle(),
    this.headSize = 14,
    this.startBinding,
    this.endBinding,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'arrow';

  @override
  final String id;
  final Offset start;
  final Offset end;
  final PaintStyle style;
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
  String get type => elementType;

  @override
  Rect get bounds => boundsForPoints([start, end]).inflate(headSize);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return distanceToSegment(worldPoint, start, end) <=
        tolerance + style.strokeWidth / 2;
  }

  @override
  ArrowElement copyWith({
    String? id,
    Offset? start,
    Offset? end,
    PaintStyle? style,
    double? headSize,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return ArrowElement(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      style: style ?? this.style,
      headSize: headSize ?? this.headSize,
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
    );
  }

  @override
  ArrowElement translate(Offset delta) {
    return copyWith(start: start + delta, end: end + delta);
  }

  @override
  ArrowElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      start: scalePoint(start, factor, origin),
      end: scalePoint(end, factor, origin),
      headSize: headSize * factor.abs(),
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
      'headSize': headSize,
      'style': style.toJson(),
      if (startBinding != null) 'startBinding': startBinding!.toJson(),
      if (endBinding != null) 'endBinding': endBinding!.toJson(),
    };
  }

  static const _unset = Object();
}

class ArrowElementRenderer extends ElementRenderer<ArrowElement> {
  const ArrowElementRenderer();

  @override
  void render(Canvas canvas, ArrowElement element) {
    if (!element.visible) {
      return;
    }

    final paint = element.style
        .copyWith(opacity: element.style.opacity * element.opacity)
        .toPaint();
    canvas.drawLine(element.start, element.end, paint);

    final direction = element.end - element.start;
    if (direction.distance < 0.1) {
      return;
    }
    final angle = math.atan2(direction.dy, direction.dx);
    final wingA = angle + math.pi * 0.82;
    final wingB = angle - math.pi * 0.82;
    final p1 =
        element.end +
        Offset(math.cos(wingA), math.sin(wingA)) * element.headSize;
    final p2 =
        element.end +
        Offset(math.cos(wingB), math.sin(wingB)) * element.headSize;

    final path = Path()
      ..moveTo(element.end.dx, element.end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(element.end.dx, element.end.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool hitTest(ArrowElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
