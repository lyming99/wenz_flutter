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
    this.rotation = 0,
    this.layerId = 'default',
    this.visible = true,
    this.opacity = 1,
    this.zIndex = 0,
    this.groupId,
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
  final double rotation;

  @override
  final String layerId;

  @override
  final bool visible;

  @override
  final double opacity;

  @override
  final int zIndex;

  @override
  final String? groupId;

  @override
  String get type => elementType;

  @override
  Rect get bounds =>
      rotatedRectBounds(rect.inflate(strokeStyle.strokeWidth / 2), rotation);

  @override
  bool hitTest(Offset worldPoint, {double tolerance = 5.0}) {
    ensureDrawioShapeDefinitionsRegistered();
    var localPoint = inverseRotatePoint(worldPoint, rotation, rect.center);
    localPoint = _inverseFlipPoint(localPoint);
    return ShapeDefinitionRegistry.definitionFor(shapeKey).hitTest(
      rect,
      properties,
      localPoint,
      strokeStyle: strokeStyle,
      fillStyle: fillStyle,
      tolerance: tolerance,
    );
  }

  Offset _inverseFlipPoint(Offset point) {
    final flipH = _propertyBool(properties['flipH']);
    final flipV = _propertyBool(properties['flipV']);
    if (!flipH && !flipV) {
      return point;
    }
    return Offset(
      flipH ? rect.left + rect.right - point.dx : point.dx,
      flipV ? rect.top + rect.bottom - point.dy : point.dy,
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
    double? rotation,
    EdgeInsets? labelPadding,
    String? layerId,
    bool? visible,
    double? opacity,
    int? zIndex,
    Object? groupId = _unset,
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
      rotation: rotation ?? this.rotation,
      layerId: layerId ?? this.layerId,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      groupId: identical(groupId, _unset)
          ? this.groupId
          : groupId as String?,
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
      'groupId': groupId,
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
      if (rotation != 0) 'rotation': rotation,
    };
  }

  @override
  DrawioShapeElement rotateElement(double radians, {Offset? pivot}) {
    final origin = pivot ?? rect.center;
    final nextCenter = rotatePoint(rect.center, radians, origin);
    return copyWith(
      rect: Rect.fromCenter(
        center: nextCenter,
        width: rect.width,
        height: rect.height,
      ),
      rotation: rotation + radians,
    );
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
    canvas.save();
    canvas.translate(element.rect.center.dx, element.rect.center.dy);
    canvas.rotate(element.rotation);
    if (_propertyBool(element.properties['flipH']) ||
        _propertyBool(element.properties['flipV'])) {
      canvas.scale(
        _propertyBool(element.properties['flipH']) ? -1.0 : 1.0,
        _propertyBool(element.properties['flipV']) ? -1.0 : 1.0,
      );
    }
    canvas.translate(-element.rect.center.dx, -element.rect.center.dy);
    definition.paint(
      canvas,
      element.rect,
      element.properties,
      strokeStyle: element.strokeStyle,
      fillStyle: element.fillStyle,
      opacity: element.opacity,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(element.rect.center.dx, element.rect.center.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-element.rect.center.dx, -element.rect.center.dy);
    ShapeLabelPainter.paint(
      canvas,
      rect: definition.labelRectFor(element.rect, element.properties),
      label: element.label,
      style: element.labelStyle,
      textAlign: element.labelAlign,
      padding: element.labelPadding,
      opacity: element.opacity,
      verticalAlign: element.properties['verticalAlign'] as String?,
      labelPosition: element.properties['labelPosition'] as String?,
      verticalLabelPosition:
          element.properties['verticalLabelPosition'] as String?,
    );
    canvas.restore();
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

bool _propertyBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return false;
  }
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true';
}

void ensureDrawioShapeDefinitionsRegistered() {
  if (_shapeDefinitionsRegistered) {
    return;
  }
  _shapeDefinitionsRegistered = true;
  DrawioShapeDefinitions.registerAll();
  BuiltinStencils.registerAll();
}
