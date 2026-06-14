import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';
import 'shape_label_painter.dart';

@immutable
class RectElement extends CanvasElement {
  const RectElement({
    required this.id,
    required this.rect,
    this.borderRadius = 0,
    this.strokeStyle = const PaintStyle(),
    this.fillStyle,
    this.label,
    this.labelStyle = ShapeLabelPainter.defaultStyle,
    this.labelAlign = TextAlign.center,
    this.labelPadding = ShapeLabelPainter.defaultPadding,
    this.rotation = 0,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'rect';

  @override
  final String id;

  final Rect rect;
  final double borderRadius;
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
  String get type => elementType;

  @override
  Rect get bounds =>
      rotatedRectBounds(rect.inflate(strokeStyle.strokeWidth / 2), rotation);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    final localPoint = rotation != 0
        ? inverseRotatePoint(worldPoint, rotation, rect.center)
        : worldPoint;
    if (fillStyle != null && rect.contains(localPoint)) {
      return true;
    }

    final outer = rect.inflate(tolerance + strokeStyle.strokeWidth / 2);
    final inner = rect.deflate(tolerance + strokeStyle.strokeWidth / 2);
    return outer.contains(localPoint) && !inner.contains(localPoint);
  }

  @override
  RectElement copyWith({
    String? id,
    Rect? rect,
    double? borderRadius,
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
  }) {
    return RectElement(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      borderRadius: borderRadius ?? this.borderRadius,
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
    );
  }

  @override
  RectElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  RectElement scaleElement(double factor, {Offset? pivot}) {
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
  RectElement rotateElement(double radians, {Offset? pivot}) {
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
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      },
      'borderRadius': borderRadius,
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

class RectElementRenderer extends ElementRenderer<RectElement> {
  const RectElementRenderer();

  @override
  void render(Canvas canvas, RectElement element) {
    if (!element.visible) {
      return;
    }

    canvas.save();
    canvas.translate(element.rect.center.dx, element.rect.center.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-element.rect.center.dx, -element.rect.center.dy);

    final rrect = RRect.fromRectAndRadius(
      element.rect,
      Radius.circular(element.borderRadius),
    );

    final fillStyle = element.fillStyle;
    if (fillStyle != null) {
      canvas.drawRRect(
        rrect,
        fillStyle
            .copyWith(
              opacity: fillStyle.opacity * element.opacity,
              paintingStyle: PaintingStyle.fill,
            )
            .toPaint(),
      );
    }

    canvas.drawRRect(
      rrect,
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
  bool hitTest(RectElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
