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
class LineElement extends CanvasElement {
  const LineElement({
    required this.id,
    required this.start,
    required this.end,
    this.style = const PaintStyle(),
    LineArrowType startArrowStyle = LineArrowType.none,
    LineArrowType? endArrowStyle,
    bool endArrow = false,
    this.headSize = LineArrowStyle.defaultHeadSize,
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
    this.groupId,
  }) : startArrowStyle = startArrowStyle,
       endArrowStyle =
           endArrowStyle ??
           (endArrow ? LineArrowType.normal : LineArrowType.none);

  static const elementType = 'line';

  @override
  final String id;

  final Offset start;
  final Offset end;
  final PaintStyle style;
  final LineArrowType startArrowStyle;
  final LineArrowType endArrowStyle;
  final double headSize;
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

  @override
  Rect get bounds {
    final lineBounds = LineArrowGeometryUtils.expandBounds(
      bounds: boundsForPoints([start, end]),
      style: arrowStyle,
      strokeWidth: style.strokeWidth,
    );
    final labelBounds = LineLabelPainter.labelBounds(
      points: [start, end],
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
    final threshold = tolerance + style.strokeWidth / 2;
    if (distanceToSegment(worldPoint, start, end) <= threshold) {
      return true;
    }
    return LineArrowGeometryUtils.hitTestAnyArrowForPoints(
      worldPoint: worldPoint,
      points: [start, end],
      style: arrowStyle,
      tolerance: threshold,
    );
  }

  @override
  LineElement copyWith({
    String? id,
    Offset? start,
    Offset? end,
    PaintStyle? style,
    LineArrowStyle? arrowStyle,
    LineArrowType? startArrowStyle,
    LineArrowType? endArrowStyle,
    bool? endArrow,
    double? headSize,
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
    return LineElement(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
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
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'style': style.toJson(),
      'arrowStyle': arrowStyle.toJson(),
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
    final labelBounds = LineLabelPainter.labelBounds(
      points: [element.start, element.end],
      label: element.label,
      style: element.labelStyle,
      labelPosition: element.labelPosition,
      labelOffset: element.labelOffset,
      labelBackground: element.labelBackground,
    );
    if (labelBounds.isEmpty) {
      canvas.drawLine(element.start, element.end, paint);
    } else {
      canvas.save();
      canvas.clipRect(labelBounds.inflate(2), clipOp: ClipOp.difference);
      canvas.drawLine(element.start, element.end, paint);
      canvas.restore();
    }
    LineArrowGeometryUtils.drawArrowsForPoints(
      canvas,
      paint,
      points: [element.start, element.end],
      style: element.arrowStyle,
    );
    LineLabelPainter.paint(
      canvas,
      points: [element.start, element.end],
      label: element.label,
      style: element.labelStyle,
      labelPosition: element.labelPosition,
      labelOffset: element.labelOffset,
      labelBackground: element.labelBackground,
      opacity: element.opacity,
    );
  }

  @override
  bool hitTest(LineElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
