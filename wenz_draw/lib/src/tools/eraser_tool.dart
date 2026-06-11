import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../infinite_canvas/canvas_event.dart';
import 'canvas_tool.dart';

class EraserTool extends CanvasTool {
  const EraserTool();

  static const idValue = 'eraser';

  @override
  String get id => idValue;

  @override
  String get name => 'Eraser';

  @override
  IconData get icon => Icons.cleaning_services_outlined;

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    if (event is! CanvasPointerDownEvent && event is! CanvasPointerMoveEvent) {
      return const ToolResultNone();
    }
    final element = controller.hitTest(event.worldPoint, tolerance: 10);
    if (element != null) {
      controller.removeElement(element.id);
      return const ToolResultConsumed();
    }
    return const ToolResultNone();
  }
}
