import 'dart:ui' show Canvas, Color, Offset, Rect, TextDirection;

import 'package:flutter/material.dart' show FontWeight, TextPainter, TextStyle, TextSpan;
import 'package:uuid/uuid.dart';

import 'canvas_element.dart';
import 'element_renderer.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// TextElement
// ---------------------------------------------------------------------------

/// 文本元素（不可变）。
class TextElement extends CanvasElement {
  @override
  final String id;
  @override
  final String layerId;
  @override
  final bool visible;
  @override
  final double opacity;
  @override
  final int zIndex;

  /// 文本位置（左上角）
  final Offset position;

  /// 文本内容
  final String text;

  /// 字号
  final double fontSize;

  /// 颜色（ARGB 32-bit）
  final int color;

  /// 是否加粗
  final bool bold;

  @override
  String get type => 'text';

  TextElement._({
    required this.id,
    required this.position,
    required this.text,
    this.fontSize = 16.0,
    this.color = 0xFF000000,
    this.bold = false,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1.0,
    this.zIndex = 0,
  });

  /// 工厂创建方法（内部生成 UUID）。
  static TextElement create({
    required Offset position,
    required String text,
    double fontSize = 16.0,
    int color = 0xFF000000,
    bool bold = false,
    String layerId = 'default',
    bool visible = true,
    double opacity = 1.0,
    int zIndex = 0,
  }) {
    return TextElement._(
      id: _uuid.v4(),
      position: position,
      text: text,
      fontSize: fontSize,
      color: color,
      bold: bold,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  Rect get bounds {
    final width = fontSize * text.length * 0.6;
    final height = fontSize * 1.2;
    return Rect.fromLTWH(position.dx, position.dy, width, height);
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return bounds.contains(worldPoint);
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layerId': layerId,
        'visible': visible,
        'opacity': opacity,
        'zIndex': zIndex,
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'fontSize': fontSize,
        'color': color,
        'bold': bold,
      };

  factory TextElement.fromJson(Map<String, dynamic> json) => TextElement._(
        id: json['id'] as String,
        position: Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
        text: json['text'] as String,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
        color: json['color'] as int? ?? 0xFF000000,
        bold: json['bold'] as bool? ?? false,
        layerId: json['layerId'] as String? ?? 'default',
        visible: json['visible'] as bool? ?? true,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: json['zIndex'] as int? ?? 0,
      );

  @override
  TextElement copyWith({
    String? id,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Offset? position,
    String? text,
    double? fontSize,
    int? color,
    bool? bold,
  }) {
    return TextElement._(
      id: id ?? this.id,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  TextElement translate(Offset delta) {
    return TextElement._(
      id: id,
      position: position + delta,
      text: text,
      fontSize: fontSize,
      color: color,
      bold: bold,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  @override
  TextElement scaleElement(double factor, {Offset? pivot}) {
    final effectivePivot = pivot ?? bounds.center;
    return TextElement._(
      id: id,
      position: effectivePivot + (position - effectivePivot) * factor,
      text: text,
      fontSize: fontSize * factor,
      color: color,
      bold: bold,
      layerId: layerId,
      visible: visible,
      opacity: opacity,
      zIndex: zIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// TextElementRenderer
// ---------------------------------------------------------------------------

/// [TextElement] 的渲染器。
class TextElementRenderer extends ElementRenderer<TextElement> {
  @override
  void render(Canvas canvas, TextElement element) {
    if (element.text.isEmpty) return;

    final alpha =
        ((element.opacity * 255).round()).clamp(0, 255);
    final colorValue = (element.color & 0x00FFFFFF) | (alpha << 24);

    final textStyle = TextStyle(
      fontSize: element.fontSize,
      color: Color(colorValue),
      fontWeight:
          element.bold ? FontWeight.bold : FontWeight.normal,
    );

    final textSpan = TextSpan(text: element.text, style: textStyle);

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(canvas, element.position);
  }

  @override
  bool hitTest(TextElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
