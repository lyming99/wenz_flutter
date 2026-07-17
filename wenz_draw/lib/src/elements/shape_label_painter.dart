import 'package:flutter/material.dart';

class ShapeLabelPainter {
  const ShapeLabelPainter._();

  static const defaultStyle = TextStyle(
    color: Colors.black,
    fontSize: 16,
    height: 1.2,
  );

  static const defaultPadding = EdgeInsets.all(8);

  static void paint(
    Canvas canvas, {
    required Rect rect,
    required String? label,
    required TextStyle style,
    required TextAlign textAlign,
    required EdgeInsets padding,
    required double opacity,
    String? verticalAlign,
    String? labelPosition,
    String? verticalLabelPosition,
  }) {
    if (label == null || label.isEmpty || rect.isEmpty) {
      return;
    }

    final contentRect = padding.deflateRect(rect);
    if (contentRect.width <= 0 || contentRect.height <= 0) {
      return;
    }

    final color = style.color ?? Colors.black;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: style.copyWith(
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: null,
      ellipsis: '...',
    )..layout(maxWidth: contentRect.width);

    final horizontal = labelPosition ?? textAlign.name;
    final dx = switch (horizontal) {
      'right' => contentRect.right - textPainter.width,
      'left' => contentRect.left,
      _ => switch (textAlign) {
        TextAlign.right ||
        TextAlign.end => contentRect.right - textPainter.width,
        TextAlign.left || TextAlign.start => contentRect.left,
        _ => contentRect.left + (contentRect.width - textPainter.width) / 2,
      },
    };
    final vertical = verticalAlign ?? verticalLabelPosition;
    final dy = switch (vertical) {
      'top' => contentRect.top,
      'bottom' => contentRect.bottom - textPainter.height,
      _ => contentRect.top + (contentRect.height - textPainter.height) / 2,
    };

    canvas.save();
    canvas.clipRect(contentRect);
    textPainter.paint(canvas, Offset(dx, dy));
    canvas.restore();
  }

  static Map<String, dynamic> styleToJson(TextStyle style) {
    return {
      'color': (style.color ?? Colors.black).toARGB32(),
      'fontSize': style.fontSize ?? 16,
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
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      fontWeight: _fontWeight(json['fontWeight']),
      height: (json['height'] as num?)?.toDouble() ?? 1.2,
      fontFamily: json['fontFamily'] as String?,
    );
  }

  static Map<String, double> paddingToJson(EdgeInsets padding) {
    return {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    };
  }

  static EdgeInsets paddingFromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return defaultPadding;
    }
    return EdgeInsets.fromLTRB(
      (json['left'] as num?)?.toDouble() ?? defaultPadding.left,
      (json['top'] as num?)?.toDouble() ?? defaultPadding.top,
      (json['right'] as num?)?.toDouble() ?? defaultPadding.right,
      (json['bottom'] as num?)?.toDouble() ?? defaultPadding.bottom,
    );
  }

  static TextAlign textAlignFromString(String? value) {
    for (final align in TextAlign.values) {
      if (align.name == value) {
        return align;
      }
    }
    return TextAlign.center;
  }

  static FontWeight _fontWeight(Object? value) {
    final weight = value is num ? value.toInt() : FontWeight.normal.value;
    return FontWeight.values.reduce((previous, current) {
      return (current.value - weight).abs() < (previous.value - weight).abs()
          ? current
          : previous;
    });
  }
}
