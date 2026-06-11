import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class ImageElement extends CanvasElement {
  const ImageElement({
    required this.id,
    required this.rect,
    this.image,
    this.fit = BoxFit.contain,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'image';

  @override
  final String id;
  final Rect rect;
  final ui.Image? image;
  final BoxFit fit;

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
  Rect get bounds => rect;

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return rect.inflate(tolerance).contains(worldPoint);
  }

  @override
  ImageElement copyWith({
    String? id,
    Rect? rect,
    ui.Image? image,
    BoxFit? fit,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return ImageElement(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      image: image ?? this.image,
      fit: fit ?? this.fit,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  ImageElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  ImageElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    return copyWith(
      rect: Rect.fromPoints(
        scalePoint(rect.topLeft, factor, origin),
        scalePoint(rect.bottomRight, factor, origin),
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
      'fit': fit.name,
    };
  }
}

class ImageElementRenderer extends ElementRenderer<ImageElement> {
  const ImageElementRenderer();

  @override
  void render(Canvas canvas, ImageElement element) {
    if (!element.visible) {
      return;
    }

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: element.opacity);
    final image = element.image;
    if (image == null) {
      canvas.drawRect(
        element.rect,
        Paint()
          ..color = const Color(0xFFE5E7EB).withValues(alpha: element.opacity),
      );
      canvas.drawRect(
        element.rect,
        Paint()
          ..color = const Color(0xFF64748B).withValues(alpha: element.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }

    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, source, element.rect, paint);
  }

  @override
  bool hitTest(ImageElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
