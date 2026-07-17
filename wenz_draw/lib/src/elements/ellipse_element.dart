import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'shape_label_painter.dart';

@immutable
class EllipseElement extends CanvasElement {
  const EllipseElement({
    required this.id,
    required this.rect,
    this.strokeStyle = const PaintStyle(),
    this.fillStyle,
    this.label,
    this.labelStyle = ShapeLabelPainter.defaultStyle,
    this.labelAlign = TextAlign.center,
    this.labelPadding = ShapeLabelPainter.defaultPadding,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.rotation = 0,
    this.groupId,
  });

  static const elementType = 'ellipse';

  @override
  final String id;

  final Rect rect;
  final PaintStyle strokeStyle;
  final PaintStyle? fillStyle;
  final String? label;
  final TextStyle labelStyle;
  final TextAlign labelAlign;
  final EdgeInsets labelPadding;
  @override
  final double rotation;

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

  @override
  Rect get bounds =>
      rotatedRectBounds(rect.inflate(strokeStyle.strokeWidth / 2), rotation);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    final localPoint = rotation != 0
        ? inverseRotatePoint(worldPoint, rotation, rect.center)
        : worldPoint;
    if (!rect.inflate(tolerance).contains(localPoint)) {
      return false;
    }

    final rx = math.max(rect.width / 2, 0.0001);
    final ry = math.max(rect.height / 2, 0.0001);
    final dx = (localPoint.dx - rect.center.dx) / rx;
    final dy = (localPoint.dy - rect.center.dy) / ry;
    final normalized = dx * dx + dy * dy;

    if (fillStyle != null) {
      return normalized <= 1.0;
    }

    final averageRadius = (rx + ry) / 2;
    final threshold =
        (tolerance + strokeStyle.strokeWidth / 2) /
        math.max(averageRadius, 0.0001);
    return (math.sqrt(normalized) - 1).abs() <= threshold;
  }

  @override
  EllipseElement copyWith({
    String? id,
    Rect? rect,
    PaintStyle? strokeStyle,
    Object? fillStyle = _unset,
    Object? label = _unset,
    TextStyle? labelStyle,
    TextAlign? labelAlign,
    EdgeInsets? labelPadding,
    double? rotation,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
  }) {
    return EllipseElement(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      fillStyle: identical(fillStyle, _unset)
          ? this.fillStyle
          : fillStyle as PaintStyle?,
      label: identical(label, _unset) ? this.label : label as String?,
      labelStyle: labelStyle ?? this.labelStyle,
      labelAlign: labelAlign ?? this.labelAlign,
      labelPadding: labelPadding ?? this.labelPadding,
      rotation: rotation ?? this.rotation,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset)
          ? this.groupId
          : groupId as String?,
    );
  }

  @override
  EllipseElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  EllipseElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    return copyWith(
      rect: Rect.fromPoints(
        scalePoint(rect.topLeft, factor, origin),
        scalePoint(rect.bottomRight, factor, origin),
      ),
      strokeStyle: strokeStyle.copyWith(
        strokeWidth: strokeStyle.strokeWidth * factor.abs(),
      ),
      labelStyle: labelStyle.copyWith(
        fontSize: (labelStyle.fontSize ?? 16) * factor.abs(),
      ),
      labelPadding: labelPadding * factor.abs(),
    );
  }

  @override
  EllipseElement rotateElement(double radians, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    final nextCenter = rotatePoint(rect.center, radians, origin);
    return copyWith(
      rect: Rect.fromCenter(
        center: nextCenter,
        width: rect.width,
        height: rect.height,
      ),
      rotation: rotation + radians,
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
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      },
      'strokeStyle': strokeStyle.toJson(),
      'fillStyle': fillStyle?.toJson(),
      if (label != null) 'label': label,
      'labelStyle': ShapeLabelPainter.styleToJson(labelStyle),
      'labelAlign': labelAlign.name,
      'labelPadding': ShapeLabelPainter.paddingToJson(labelPadding),
      if (rotation != 0) 'rotation': rotation,
    };
  }

  static const _unset = Object();
}

class EllipseElementRenderer extends ElementRenderer<EllipseElement> {
  const EllipseElementRenderer();

  @override
  void render(Canvas canvas, EllipseElement element) {
    if (!element.visible) {
      return;
    }

    canvas.save();
    canvas.translate(element.rect.center.dx, element.rect.center.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-element.rect.center.dx, -element.rect.center.dy);

    final fillStyle = element.fillStyle;
    if (fillStyle != null) {
      canvas.drawOval(
        element.rect,
        fillStyle
            .copyWith(
              opacity: fillStyle.opacity * element.opacity,
              paintingStyle: PaintingStyle.fill,
            )
            .toPaint(),
      );
    }

    canvas.drawOval(
      element.rect,
      element.strokeStyle
          .copyWith(opacity: element.strokeStyle.opacity * element.opacity)
          .toPaint(),
    );

    ShapeLabelPainter.paint(
      canvas,
      rect: element.rect,
      label: element.label,
      style: element.labelStyle,
      textAlign: element.labelAlign,
      padding: element.labelPadding,
      opacity: element.opacity,
    );

    canvas.restore();
  }

  @override
  bool hitTest(EllipseElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
