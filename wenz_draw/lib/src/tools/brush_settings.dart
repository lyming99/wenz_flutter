import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';

@immutable
class BrushSettings {
  const BrushSettings({
    this.color = Colors.black,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.fillColor,
  });

  final Color color;
  final double strokeWidth;
  final double opacity;
  final Color? fillColor;

  PaintStyle get strokeStyle {
    return PaintStyle(
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      paintingStyle: PaintingStyle.stroke,
    );
  }

  PaintStyle? get fillStyle {
    final fill = fillColor;
    if (fill == null) {
      return null;
    }
    return PaintStyle(
      color: fill,
      strokeWidth: 0,
      opacity: opacity,
      paintingStyle: PaintingStyle.fill,
    );
  }

  BrushSettings copyWith({
    Color? color,
    double? strokeWidth,
    double? opacity,
    Color? fillColor,
    bool clearFill = false,
  }) {
    return BrushSettings(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      fillColor: clearFill ? null : fillColor ?? this.fillColor,
    );
  }
}
