import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/ellipse_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/math_utils.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class EllipseTool extends CanvasTool {
  EllipseTool();

  static const idValue = 'ellipse';

  Offset? _start;
  Offset? _current;

  @override
  String get id => idValue;

  @override
  String get name => 'Ellipse';

  @override
  IconData get icon => Icons.circle_outlined;

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
          EllipseElement(
            id: UuidGenerator.create(),
            rect: normalizedRectFromPoints(start, end),
            strokeStyle: controller.brushSettings.strokeStyle,
            fillStyle: controller.brushSettings.fillStyle,
          ),
        );
      default:
        return const ToolResultNone();
    }
  }

  EllipseElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    return EllipseElement(
      id: '__preview_ellipse__',
      rect: normalizedRectFromPoints(start, _current ?? start),
      strokeStyle: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
      fillStyle: controller.brushSettings.fillStyle,
    );
  }
}
