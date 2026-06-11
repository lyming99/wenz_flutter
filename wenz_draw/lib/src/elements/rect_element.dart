import 'package:flutter/widgets.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class RectElement extends CanvasElement {
  const RectElement({
    required this.id,
    required this.rect,
    this.borderRadius = 0,
    this.strokeStyle = const PaintStyle(),
    this.fillStyle,
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
  Rect get bounds => rect.inflate(strokeStyle.strokeWidth / 2);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    if (fillStyle != null && rect.contains(worldPoint)) {
      return true;
    }

    final outer = rect.inflate(tolerance + strokeStyle.strokeWidth / 2);
    final inner = rect.deflate(tolerance + strokeStyle.strokeWidth / 2);
    return outer.contains(worldPoint) && !inner.contains(worldPoint);
  }

  @override
  RectElement copyWith({
    String? id,
    Rect? rect,
    double? borderRadius,
    PaintStyle? strokeStyle,
    PaintStyle? fillStyle,
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
      fillStyle: fillStyle ?? this.fillStyle,
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
    };
  }
}

class RectElementRenderer extends ElementRenderer<RectElement> {
  const RectElementRenderer();

  @override
  void render(Canvas canvas, RectElement element) {
    if (!element.visible) {
      return;
    }

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
  }

  @override
  bool hitTest(RectElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
