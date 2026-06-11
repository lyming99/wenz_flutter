import 'package:flutter/material.dart';

@immutable
class PaintStyle {
  const PaintStyle({
    this.color = Colors.black,
    this.strokeWidth = 2.0,
    this.opacity = 1.0,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.paintingStyle = PaintingStyle.stroke,
  });

  final Color color;
  final double strokeWidth;
  final double opacity;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final PaintingStyle paintingStyle;

  Paint toPaint() {
    return Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap
      ..strokeJoin = strokeJoin
      ..style = paintingStyle;
  }

  PaintStyle copyWith({
    Color? color,
    double? strokeWidth,
    double? opacity,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    PaintingStyle? paintingStyle,
  }) {
    return PaintStyle(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      strokeCap: strokeCap ?? this.strokeCap,
      strokeJoin: strokeJoin ?? this.strokeJoin,
      paintingStyle: paintingStyle ?? this.paintingStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'paintingStyle': paintingStyle.name,
    };
  }

  static PaintStyle fromJson(Map<String, dynamic> json) {
    return PaintStyle(
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.toARGB32()),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      paintingStyle: json['paintingStyle'] == PaintingStyle.fill.name
          ? PaintingStyle.fill
          : PaintingStyle.stroke,
    );
  }
}
