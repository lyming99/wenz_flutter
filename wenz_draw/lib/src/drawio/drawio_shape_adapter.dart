import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/shape_label_painter.dart';
import 'drawio_color.dart';
import 'drawio_style.dart';
import 'drawio_style_parser.dart';

class DrawioShapeAdapter {
  const DrawioShapeAdapter._();

  static DrawioShapeElement fromStyleString({
    required String id,
    required Rect rect,
    required String style,
    String? label,
    String layerId = 'default',
    int zIndex = 0,
  }) {
    return fromStyle(
      id: id,
      rect: rect,
      style: DrawioStyleParser.parse(style),
      label: label,
      layerId: layerId,
      zIndex: zIndex,
    );
  }

  static DrawioShapeElement fromStyle({
    required String id,
    required Rect rect,
    required DrawioStyle style,
    String? label,
    String layerId = 'default',
    int zIndex = 0,
  }) {
    final shapeKey = _shapeKey(style);
    final opacity = DrawioColor.opacityFromPercent(style['opacity']);
    final fillColor = DrawioColor.parse(style['fillColor'] ?? '#ffffff');
    final strokeColor = DrawioColor.parse(style['strokeColor'] ?? '#000000');
    final strokeWidth = style.doubleValue('strokeWidth') ?? 1.0;
    final fillOpacity = DrawioColor.opacityFromPercent(
      style['fillOpacity'],
      fallback: opacity,
    );
    final strokeOpacity = DrawioColor.opacityFromPercent(
      style['strokeOpacity'],
      fallback: opacity,
    );

    return DrawioShapeElement(
      id: id,
      shapeKey: shapeKey,
      rect: rect,
      strokeStyle: PaintStyle(
        color: strokeColor ?? Colors.transparent,
        strokeWidth: strokeColor == null ? 0 : strokeWidth,
        opacity: strokeColor == null ? 0 : strokeOpacity,
      ),
      fillStyle: fillColor == null
          ? null
          : PaintStyle(
              color: fillColor,
              opacity: fillOpacity,
              paintingStyle: PaintingStyle.fill,
            ),
      properties: _properties(style),
      label: label,
      labelStyle: _labelStyle(style),
      labelAlign: _labelAlign(style),
      labelPadding: _labelPadding(style),
      layerId: layerId,
      opacity: opacity,
      zIndex: zIndex,
    );
  }

  static String _shapeKey(DrawioStyle style) {
    final raw = style['shape'];
    if (raw == null || raw.isEmpty) {
      return style.boolValue('rounded') ? 'roundedRectangle' : 'rectangle';
    }
    return switch (raw) {
      'rect' => 'rectangle',
      'process' => 'rectangle',
      'rounded' => 'roundedRectangle',
      'manualInput' => 'parallelogram',
      'isoRectangle' => 'cube',
      _ => raw,
    };
  }

  static Map<String, dynamic> _properties(DrawioStyle style) {
    final properties = <String, dynamic>{
      'drawioStyle': style.raw,
      ...style.extra,
    };
    final direction = style['direction'];
    if (direction != null && direction.isNotEmpty) {
      properties['direction'] = direction;
    }
    final arcSize = style.doubleValue('arcSize');
    if (arcSize != null) {
      properties['arcSize'] = arcSize;
    }
    if (style.boolValue('rounded')) {
      properties['rounded'] = true;
    }
    if (style.boolValue('dashed')) {
      properties['dashed'] = true;
    }
    return Map<String, dynamic>.unmodifiable(properties);
  }

  static TextStyle _labelStyle(DrawioStyle style) {
    final color = DrawioColor.parse(style['fontColor']) ?? Colors.black;
    final size =
        style.doubleValue('fontSize') ??
        ShapeLabelPainter.defaultStyle.fontSize ??
        16;
    final fontStyle = style.intValue('fontStyle') ?? 0;
    return ShapeLabelPainter.defaultStyle.copyWith(
      color: color,
      fontSize: size,
      fontWeight: (fontStyle & 1) != 0 ? FontWeight.bold : FontWeight.normal,
      fontStyle: (fontStyle & 2) != 0 ? FontStyle.italic : FontStyle.normal,
    );
  }

  static TextAlign _labelAlign(DrawioStyle style) {
    return switch (style['align']) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
  }

  static EdgeInsets _labelPadding(DrawioStyle style) {
    final base =
        style.doubleValue('spacing') ?? ShapeLabelPainter.defaultPadding.left;
    return EdgeInsets.fromLTRB(
      style.doubleValue('spacingLeft') ?? base,
      style.doubleValue('spacingTop') ?? base,
      style.doubleValue('spacingRight') ?? base,
      style.doubleValue('spacingBottom') ?? base,
    );
  }
}
