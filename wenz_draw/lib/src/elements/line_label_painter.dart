import 'dart:math' as math;

import 'package:flutter/material.dart';

class LineLabelPainter {
  const LineLabelPainter._();

  static const defaultStyle = TextStyle(
    color: Colors.black,
    fontSize: 14,
    height: 1.2,
  );

  static const defaultPosition = 0.5;
  static const defaultOffset = Offset.zero;
  static const backgroundPadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 2,
  );

  static bool hasLabel(String? label) => label != null && label.isNotEmpty;

  static void paint(
    Canvas canvas, {
    required List<Offset> points,
    required String? label,
    required TextStyle style,
    required double labelPosition,
    required Offset labelOffset,
    required Color? labelBackground,
    required double opacity,
  }) {
    if (!hasLabel(label) || points.isEmpty) {
      return;
    }

    final textPainter = _textPainter(label!, style, opacity)..layout();
    final center = labelCenter(
      points,
      labelPosition: labelPosition,
      labelOffset: labelOffset,
    );
    final textOffset =
        center - Offset(textPainter.width / 2, textPainter.height / 2);

    if (labelBackground != null) {
      final backgroundRect = (textOffset & textPainter.size).inflate(4);
      final color = labelBackground.withValues(
        alpha: (labelBackground.a * opacity).clamp(0.0, 1.0),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(3)),
        Paint()..color = color,
      );
    }

    textPainter.paint(canvas, textOffset);
  }

  static Rect labelBounds({
    required List<Offset> points,
    required String? label,
    required TextStyle style,
    required double labelPosition,
    required Offset labelOffset,
    required Color? labelBackground,
  }) {
    if (!hasLabel(label) || points.isEmpty) {
      return Rect.zero;
    }
    final textPainter = _textPainter(label!, style, 1)..layout();
    final center = labelCenter(
      points,
      labelPosition: labelPosition,
      labelOffset: labelOffset,
    );
    var rect = Rect.fromCenter(
      center: center,
      width: textPainter.width,
      height: textPainter.height,
    );
    if (labelBackground != null) {
      rect = rect.inflate(4);
    }
    return rect;
  }

  static Offset labelCenter(
    List<Offset> points, {
    required double labelPosition,
    required Offset labelOffset,
  }) {
    final placement = pointAlongPath(points, labelPosition);
    final tangent = placement.tangent;
    final normal = Offset(-tangent.dy, tangent.dx);
    return placement.point + tangent * labelOffset.dx + normal * labelOffset.dy;
  }

  static LineLabelPlacement pointAlongPath(
    List<Offset> points,
    double labelPosition,
  ) {
    if (points.isEmpty) {
      return const LineLabelPlacement(Offset.zero, Offset(1, 0));
    }
    if (points.length == 1) {
      return LineLabelPlacement(points.first, const Offset(1, 0));
    }

    final targetRatio = labelPosition.clamp(0.0, 1.0);
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    if (total <= 0) {
      return LineLabelPlacement(points.first, const Offset(1, 0));
    }

    final target = total * targetRatio;
    var walked = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segment = b - a;
      final length = segment.distance;
      if (length <= 0) {
        continue;
      }
      if (walked + length >= target || i == points.length - 2) {
        final localT = ((target - walked) / length).clamp(0.0, 1.0);
        return LineLabelPlacement(a + segment * localT, segment / length);
      }
      walked += length;
    }

    final lastSegment = points.last - points[points.length - 2];
    final lastLength = math.max(lastSegment.distance, 0.0001);
    return LineLabelPlacement(points.last, lastSegment / lastLength);
  }

  static Map<String, dynamic> styleToJson(TextStyle style) {
    return {
      'color': (style.color ?? Colors.black).toARGB32(),
      'fontSize': style.fontSize ?? 14,
      'fontWeight': style.fontWeight?.value ?? FontWeight.normal.value,
      'height': style.height ?? 1.2,
      if (style.fontFamily != null) 'fontFamily': style.fontFamily,
    };
  }

  static TextStyle styleFromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return defaultStyle;
    }
    return TextStyle(
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.toARGB32()),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
      fontWeight: _fontWeight(json['fontWeight']),
      height: (json['height'] as num?)?.toDouble() ?? 1.2,
      fontFamily: json['fontFamily'] as String?,
    );
  }

  static Map<String, double> offsetToJson(Offset offset) {
    return {'dx': offset.dx, 'dy': offset.dy};
  }

  static Offset offsetFromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return Offset(
        (json['dx'] as num?)?.toDouble() ?? 0,
        (json['dy'] as num?)?.toDouble() ?? 0,
      );
    }
    return defaultOffset;
  }

  static FontWeight _fontWeight(Object? value) {
    final weight = value is num ? value.toInt() : FontWeight.normal.value;
    return FontWeight.values.reduce((previous, current) {
      return (current.value - weight).abs() < (previous.value - weight).abs()
          ? current
          : previous;
    });
  }

  static TextPainter _textPainter(
    String label,
    TextStyle style,
    double opacity,
  ) {
    final color = style.color ?? Colors.black;
    return TextPainter(
      text: TextSpan(
        text: label,
        style: style.copyWith(
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
  }
}

@immutable
class LineLabelPlacement {
  const LineLabelPlacement(this.point, this.tangent);

  final Offset point;
  final Offset tangent;
}
