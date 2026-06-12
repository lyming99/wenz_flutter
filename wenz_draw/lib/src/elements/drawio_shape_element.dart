import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../utils/math_utils.dart';
import 'canvas_element.dart';
import 'drawio_shape_definitions.dart';
import 'element_renderer.dart';
import 'shape_label_painter.dart';
import 'shape_definition_registry.dart';
import '../stencils/builtin_stencils.dart';

@immutable
class DrawioShapeElement extends CanvasElement {
  const DrawioShapeElement({
    required this.id,
    required this.shapeKey,
    required this.rect,
    this.strokeStyle = const PaintStyle(),
    this.fillStyle,
    this.properties = const <String, dynamic>{},
    this.label,
    this.labelStyle = ShapeLabelPainter.defaultStyle,
    this.labelAlign = TextAlign.center,
    this.labelPadding = ShapeLabelPainter.defaultPadding,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
  });

  static const elementType = 'drawioShape';

  @override
  final String id;

  final String shapeKey;
  final Rect rect;
  final PaintStyle strokeStyle;
  final PaintStyle? fillStyle;
  final Map<String, dynamic> properties;
  final String? label;
  final TextStyle labelStyle;
  final TextAlign labelAlign;
  final EdgeInsets labelPadding;

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
    ensureDrawioShapeDefinitionsRegistered();
    return ShapeDefinitionRegistry.definitionFor(shapeKey).hitTest(
      rect,
      properties,
      worldPoint,
      strokeStyle: strokeStyle,
      fillStyle: fillStyle,
      tolerance: tolerance,
    );
  }

  @override
  DrawioShapeElement copyWith({
    String? id,
    String? shapeKey,
    Rect? rect,
    PaintStyle? strokeStyle,
    Object? fillStyle = _unset,
    Map<String, dynamic>? properties,
    Object? label = _unset,
    TextStyle? labelStyle,
    TextAlign? labelAlign,
    EdgeInsets? labelPadding,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
  }) {
    return DrawioShapeElement(
      id: id ?? this.id,
      shapeKey: shapeKey ?? this.shapeKey,
      rect: rect ?? this.rect,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      fillStyle: identical(fillStyle, _unset)
          ? this.fillStyle
          : fillStyle as PaintStyle?,
      properties: Map<String, dynamic>.unmodifiable(
        properties ?? this.properties,
      ),
      label: identical(label, _unset) ? this.label : label as String?,
      labelStyle: labelStyle ?? this.labelStyle,
      labelAlign: labelAlign ?? this.labelAlign,
      labelPadding: labelPadding ?? this.labelPadding,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  @override
  DrawioShapeElement translate(Offset delta) {
    return copyWith(rect: rect.shift(delta));
  }

  @override
  DrawioShapeElement scaleElement(double factor, {Offset? pivot}) {
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
      properties: _scaledProperties(factor.abs()),
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
      'shapeKey': shapeKey,
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      },
      'strokeStyle': strokeStyle.toJson(),
      'fillStyle': fillStyle?.toJson(),
      if (properties.isNotEmpty) 'properties': properties,
      if (label != null) 'label': label,
      'labelStyle': ShapeLabelPainter.styleToJson(labelStyle),
      'labelAlign': labelAlign.name,
      'labelPadding': ShapeLabelPainter.paddingToJson(labelPadding),
    };
  }

  Map<String, dynamic> _scaledProperties(double factor) {
    if (properties.isEmpty) {
      return properties;
    }
    final scaled = Map<String, dynamic>.of(properties);
    for (final key in const ['radius', 'capHeight', 'inset']) {
      final value = scaled[key];
      if (value is num) {
        scaled[key] = value.toDouble() * factor;
      }
    }
    return scaled;
  }

  static const _unset = Object();
}

class DrawioShapeElementRenderer extends ElementRenderer<DrawioShapeElement> {
  const DrawioShapeElementRenderer();

  @override
  void render(Canvas canvas, DrawioShapeElement element) {
    if (!element.visible) {
      return;
    }
    ensureDrawioShapeDefinitionsRegistered();
    final definition = ShapeDefinitionRegistry.definitionFor(element.shapeKey);
    definition.paint(
      canvas,
      element.rect,
      element.properties,
      strokeStyle: element.strokeStyle,
      fillStyle: element.fillStyle,
      opacity: element.opacity,
    );

    ShapeLabelPainter.paint(
      canvas,
      rect: definition.labelRectFor(element.rect, element.properties),
      label: element.label,
      style: element.labelStyle,
      textAlign: element.labelAlign,
      padding: element.labelPadding,
      opacity: element.opacity,
    );
  }

  @override
  bool hitTest(
    DrawioShapeElement element,
    Offset worldPoint,
    double tolerance,
  ) {
    return element.hitTest(worldPoint, tolerance: tolerance);
  }
}

bool _shapeDefinitionsRegistered = false;

void ensureDrawioShapeDefinitionsRegistered() {
  if (_shapeDefinitionsRegistered) {
    return;
  }
  _shapeDefinitionsRegistered = true;
  DrawioShapeDefinitions.registerAll();
  BuiltinStencils.registerAll();
}
