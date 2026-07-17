import 'dart:ui' show ClipOp;

import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../snap/snap_resolver.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'line_arrow_style.dart';
import 'line_label_painter.dart';

@immutable
class PolylineElement extends CanvasElement {
  const PolylineElement({
    required this.id,
    required this.points,
    this.style = const PaintStyle(),
    this.startBinding,
    this.endBinding,
    LineArrowType startArrowStyle = LineArrowType.none,
    LineArrowType? endArrowStyle,
    bool endArrow = false,
    this.headSize = LineArrowStyle.defaultHeadSize,
    this.label,
    this.labelStyle = LineLabelPainter.defaultStyle,
    this.labelPosition = LineLabelPainter.defaultPosition,
    this.labelOffset = LineLabelPainter.defaultOffset,
    this.labelBackground,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
  }) : startArrowStyle = startArrowStyle,
       endArrowStyle =
           endArrowStyle ??
           (endArrow ? LineArrowType.normal : LineArrowType.none);

  static const elementType = 'polyline';

  @override
  final String id;
  final List<Offset> points;
  final PaintStyle style;
  final SnapBinding? startBinding;
  final SnapBinding? endBinding;
  final LineArrowType startArrowStyle;
  final LineArrowType endArrowStyle;
  final double headSize;
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

  @override
  final String? groupId;

  Offset get start => points.isEmpty ? Offset.zero : points.first;
  Offset get end => points.isEmpty ? Offset.zero : points.last;

  LineArrowStyle get arrowStyle => LineArrowStyle(
    startArrowStyle: startArrowStyle,
    endArrowStyle: endArrowStyle,
    headSize: headSize,
  );

  bool get endArrow => endArrowStyle.isEnabled;

  @override
  String get type => elementType;

  @override
  Rect get bounds {
    if (points.isEmpty) {
      return Rect.zero;
    }
    final lineBounds = LineArrowGeometryUtils.expandBounds(
      bounds: boundsForPoints(points),
      style: arrowStyle,
      strokeWidth: style.strokeWidth,
    );
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
    final hitTolerance = tolerance + style.strokeWidth / 2;
    for (var i = 0; i < points.length - 1; i++) {
      if (distanceToSegment(worldPoint, points[i], points[i + 1]) <=
          hitTolerance) {
        return true;
      }
    }
    return LineArrowGeometryUtils.hitTestAnyArrowForPoints(
      worldPoint: worldPoint,
      points: points,
      style: arrowStyle,
      tolerance: hitTolerance,
    );
  }

  @override
  PolylineElement copyWith({
    String? id,
    List<Offset>? points,
    PaintStyle? style,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
    LineArrowStyle? arrowStyle,
    LineArrowType? startArrowStyle,
    LineArrowType? endArrowStyle,
    bool? endArrow,
    double? headSize,
    Object? label = _unset,
    TextStyle? labelStyle,
    double? labelPosition,
    Offset? labelOffset,
    Object? labelBackground = _unset,
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
      startArrowStyle: nextArrowStyle.startArrowStyle,
      endArrowStyle: nextArrowStyle.endArrowStyle,
      headSize: nextArrowStyle.effectiveHeadSize,
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
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
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
      arrowStyle: arrowStyle.scale(factor),
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
      'groupId': groupId,
      'points': [
        for (final point in points) {'x': point.dx, 'y': point.dy},
      ],
      'style': style.toJson(),
      'arrowStyle': arrowStyle.toJson(),
      'endArrow': endArrow,
      'headSize': headSize,
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

    LineArrowGeometryUtils.drawArrowsForPoints(
      canvas,
      paint,
      points: element.points,
      style: element.arrowStyle,
    );

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
