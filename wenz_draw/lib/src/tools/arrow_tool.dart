import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/arrow_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class ArrowTool extends CanvasTool {
  ArrowTool();

  static const idValue = 'arrow';

  Offset? _start;
  Offset? _current;

  @override
  String get id => idValue;

  @override
  String get name => 'Arrow';

  @override
  IconData get icon => Icons.arrow_outward;

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
        cancel(controller);
        if (start == null || (start - end).distance < 1) {
          return const ToolResultNone();
        }
        return ToolResultElement(
          ArrowElement(
            id: UuidGenerator.create(),
            start: start,
            end: end,
            style: controller.brushSettings.strokeStyle,
          ),
        );
      default:
        return const ToolResultNone();
    }
  }

  ArrowElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    return ArrowElement(
      id: '__preview_arrow__',
      start: start,
      end: _current ?? start,
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }
}
