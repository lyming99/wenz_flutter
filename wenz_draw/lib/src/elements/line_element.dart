import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../snap/snap_resolver.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class LineElement extends CanvasElement {
  const LineElement({
    required this.id,
    required this.start,
    required this.end,
    this.style = const PaintStyle(),
    this.startBinding,
    this.endBinding,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'line';

  @override
  final String id;

  final Offset start;
  final Offset end;
  final PaintStyle style;
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
  Rect get bounds =>
      boundsForPoints([start, end]).inflate(style.strokeWidth / 2);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return distanceToSegment(worldPoint, start, end) <=
        tolerance + style.strokeWidth / 2;
  }

  @override
  LineElement copyWith({
    String? id,
    Offset? start,
    Offset? end,
    PaintStyle? style,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return LineElement(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      style: style ?? this.style,
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
  LineElement translate(Offset delta) {
    return copyWith(start: start + delta, end: end + delta);
  }

  @override
  LineElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      start: scalePoint(start, factor, origin),
      end: scalePoint(end, factor, origin),
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
      'style': style.toJson(),
      if (startBinding != null) 'startBinding': startBinding!.toJson(),
      if (endBinding != null) 'endBinding': endBinding!.toJson(),
    };
  }

  static const _unset = Object();
}

class LineElementRenderer extends ElementRenderer<LineElement> {
  const LineElementRenderer();

  @override
  void render(Canvas canvas, LineElement element) {
    if (!element.visible) {
      return;
    }
    final paint = element.style
        .copyWith(opacity: element.style.opacity * element.opacity)
        .toPaint();
    canvas.drawLine(element.start, element.end, paint);
  }

  @override
  bool hitTest(LineElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
