import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../infinite_canvas/canvas_event.dart';
import 'canvas_tool.dart';

class PanTool extends CanvasTool {
  const PanTool();

  static const idValue = 'pan';

  @override
  String get id => idValue;

  @override
  String get name => 'Pan';

  @override
  IconData get icon => Icons.pan_tool_alt;

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    return const ToolResultConsumed();
  }
}
