import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/line_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class LineTool extends CanvasTool {
  LineTool();

  static const idValue = 'line';

  Offset? _start;
  Offset? _current;

  @override
  String get id => idValue;

  @override
  String get name => 'Line';

  @override
  IconData get icon => Icons.show_chart;

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
          LineElement(
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

  LineElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    return LineElement(
      id: '__preview_line__',
      start: start,
      end: _current ?? start,
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }
}
