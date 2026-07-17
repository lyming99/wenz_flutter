import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/drawio_shape_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/math_utils.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class ShapeTool extends CanvasTool {
  ShapeTool({
    required this.shapeKey,
    String? id,
    String? name,
    IconData? icon,
    this.defaultProperties = const <String, dynamic>{},
  }) : _id = id ?? idFor(shapeKey),
       _name = name ?? shapeKey,
       _icon = icon ?? Icons.category_outlined;

  static const idPrefix = 'shape:';

  static String idFor(String shapeKey) => '$idPrefix$shapeKey';

  final String shapeKey;
  final Map<String, dynamic> defaultProperties;
  final String _id;
  final String _name;
  final IconData _icon;

  Offset? _start;
  Offset? _current;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  IconData get icon => _icon;

  @override
  void cancel(CanvasController controller) {
    _start = null;
    _current = null;
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        _start = event.worldPoint;
        _current = event.worldPoint;
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerMoveEvent():
        if (_start == null) {
          return const ToolResultNone();
        }
        _current = event.worldPoint;
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerUpEvent():
        final start = _start;
        final end = event.worldPoint;
        _start = null;
        _current = null;
        if (start == null || (start - end).distance < 1) {
          return const ToolResultNone();
        }
        return ToolResultElement(
          _buildElement(controller, UuidGenerator.create(), start, end),
        );
      default:
        return const ToolResultNone();
    }
  }

  DrawioShapeElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    return _buildElement(
      controller,
      '__preview_${shapeKey}_shape__',
      start,
      _current ?? start,
      preview: true,
    );
  }

  DrawioShapeElement _buildElement(
    CanvasController controller,
    String id,
    Offset start,
    Offset end, {
    bool preview = false,
  }) {
    final strokeStyle = controller.brushSettings.strokeStyle;
    return DrawioShapeElement(
      id: id,
      shapeKey: shapeKey,
      rect: normalizedRectFromPoints(start, end),
      strokeStyle: preview
          ? strokeStyle.copyWith(opacity: strokeStyle.opacity * 0.72)
          : strokeStyle,
      fillStyle: controller.brushSettings.fillStyle,
      properties: Map<String, dynamic>.unmodifiable(defaultProperties),
    );
  }
}
