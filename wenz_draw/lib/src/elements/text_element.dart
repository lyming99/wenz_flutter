import 'package:flutter/material.dart';

import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'element_renderer.dart';

@immutable
class TextElement extends CanvasElement {
  const TextElement({
    required this.id,
    required this.position,
    required this.text,
    this.style = const TextStyle(
      color: Colors.black,
      fontSize: 24,
      height: 1.2,
    ),
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'text';

  @override
  final String id;
  final Offset position;
  final String text;
  final TextStyle style;

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
  Rect get bounds {
    final painter = _textPainter();
    return position & painter.size;
  }

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    return bounds.inflate(tolerance).contains(worldPoint);
  }

  @override
  TextElement copyWith({
    String? id,
    Offset? position,
    String? text,
    TextStyle? style,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return TextElement(
      id: id ?? this.id,
      position: position ?? this.position,
      text: text ?? this.text,
      style: style ?? this.style,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  TextElement translate(Offset delta) {
    return copyWith(position: position + delta);
  }

  @override
  TextElement scaleElement(double factor, {Offset? pivot}) {
    final origin = pivot ?? bounds.center;
    return copyWith(
      position: scalePoint(position, factor, origin),
      style: style.copyWith(fontSize: (style.fontSize ?? 24) * factor.abs()),
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
      'position': {'x': position.dx, 'y': position.dy},
      'text': text,
      'style': {
        'color': (style.color ?? Colors.black).toARGB32(),
        'fontSize': style.fontSize ?? 24,
      },
    };
  }

  TextPainter _textPainter() {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  }
}

class TextElementRenderer extends ElementRenderer<TextElement> {
  const TextElementRenderer();

  @override
  void render(Canvas canvas, TextElement element) {
    if (!element.visible || element.text.isEmpty) {
      return;
    }
    final color = element.style.color ?? Colors.black;
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: element.style.copyWith(
          color: color.withValues(alpha: element.opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, element.position);
  }

  @override
  bool hitTest(TextElement element, Offset worldPoint, double tolerance) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}
