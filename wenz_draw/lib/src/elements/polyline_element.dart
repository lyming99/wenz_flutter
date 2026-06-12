import 'dart:ui' show ClipOp;

import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../snap/snap_resolver.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'line_label_painter.dart';

@immutable
class PolylineElement extends CanvasElement {
  const PolylineElement({
    required this.id,
    required this.points,
    this.style = const PaintStyle(),
    this.startBinding,
    this.endBinding,
    this.label,
    this.labelStyle = LineLabelPainter.defaultStyle,
    this.labelPosition = LineLabelPainter.defaultPosition,
    this.labelOffset = LineLabelPainter.defaultOffset,
    this.labelBackground,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'polyline';

  @override
  final String id;
  final List<Offset> points;
  final PaintStyle style;
  final SnapBinding? startBinding;
  final SnapBinding? endBinding;
  final String? label;
  final TextStyle labelStyle;
  final double labelPosition;
  final Offset labelOffset;
  final Color? labelBackground;

  @override
  final String layerId;
  @override
  final bool visible;
  @override
  final double opacity;
  @override
  final int zIndex;

  Offset get start => points.isEmpty ? Offset.zero : points.first;
  Offset get end => points.isEmpty ? Offset.zero : points.last;

  @override
  String get type => elementType;

  @override
  Rect get bounds {
    if (points.isEmpty) {
      return Rect.zero;
    }
    final lineBounds = boundsForPoints(points).inflate(style.strokeWidth / 2);
    final labelBounds = LineLabelPainter.labelBounds(
      points: points,
      label: label,
      style: labelStyle,
      labelPosition: labelPosition,
      labelOffset: labelOffset,
      labelBackground: labelBackground,
    );
    return labelBounds.isEmpty
        ? lineBounds
        : lineBounds.expandToInclude(labelBounds);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    if (points.length < 2) {
      return false;
    }
    for (var i = 0; i < points.length - 1; i++) {
      if (distanceToSegment(worldPoint, points[i], points[i + 1]) <=
          tolerance + style.strokeWidth / 2) {
        return true;
      }
    }
    return false;
  }

  @override
  PolylineElement copyWith({
    String? id,
    List<Offset>? points,
    PaintStyle? style,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    Object? label = _unset,
    TextStyle? labelStyle,
    double? labelPosition,
    Offset? labelOffset,
    Object? labelBackground = _unset,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return PolylineElement(
      id: id ?? this.id,
      points: List<Offset>.unmodifiable(points ?? this.points),
      style: style ?? this.style,
      startBinding: identical(startBinding, _unset)
          ? this.startBinding
          : startBinding as SnapBinding?,
      endBinding: identical(endBinding, _unset)
          ? this.endBinding
          : endBinding as SnapBinding?,
      label: identical(label, _unset) ? this.label : label as String?,
      labelStyle: labelStyle ?? this.labelStyle,
      labelPosition: labelPosition ?? this.labelPosition,
      labelOffset: labelOffset ?? this.labelOffset,
      labelBackground: identical(labelBackground, _unset)
          ? this.labelBackground
          : labelBackground as Color?,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  PolylineElement translate(Offset delta) {
    return copyWith(points: [for (final point in points) point + delta]);
  }

  @override
  PolylineElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      points: [for (final point in points) scalePoint(point, factor, origin)],
      style: style.copyWith(strokeWidth: style.strokeWidth * factor.abs()),
      labelStyle: labelStyle.copyWith(
        fontSize: (labelStyle.fontSize ?? 14) * factor.abs(),
      ),
      labelOffset: labelOffset * factor.abs(),
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
      'points': [
        for (final point in points) {'x': point.dx, 'y': point.dy},
      ],
      'style': style.toJson(),
      if (startBinding != null) 'startBinding': startBinding!.toJson(),
      if (endBinding != null) 'endBinding': endBinding!.toJson(),
      if (label != null) 'label': label,
      'labelStyle': LineLabelPainter.styleToJson(labelStyle),
      'labelPosition': labelPosition,
      'labelOffset': LineLabelPainter.offsetToJson(labelOffset),
      if (labelBackground != null)
        'labelBackground': labelBackground!.toARGB32(),
    };
  }

  static const _unset = Object();
}

class PolylineElementRenderer extends ElementRenderer<PolylineElement> {
  const PolylineElementRenderer();

  @override
  void render(Canvas canvas, PolylineElement element) {
    if (!element.visible || element.points.length < 2) {
      return;
    }
    final path = Path()
      ..moveTo(element.points.first.dx, element.points.first.dy);
    for (final point in element.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = element.style
        .copyWith(opacity: element.style.opacity * element.opacity)
        .toPaint();
    final labelBounds = LineLabelPainter.labelBounds(
      points: element.points,
      label: element.label,
      style: element.labelStyle,
      labelPosition: element.labelPosition,
      labelOffset: element.labelOffset,
      labelBackground: element.labelBackground,
    );
    if (labelBounds.isEmpty) {
      canvas.drawPath(path, paint);
    } else {
      canvas.save();
      canvas.clipRect(labelBounds.inflate(2), clipOp: ClipOp.difference);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    LineLabelPainter.paint(
      canvas,
      points: element.points,
      label: element.label,
      style: element.labelStyle,
      labelPosition: element.labelPosition,
      labelOffset: element.labelOffset,
      labelBackground: element.labelBackground,
      opacity: element.opacity,
    );
  }

  @override
  bool hitTest(PolylineElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
