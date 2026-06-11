import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';

abstract class CanvasTool {
  const CanvasTool();

  String get id;
  String get name;
  IconData get icon;

  void onActivate(CanvasController controller) {}

  void onDeactivate(CanvasController controller) {}

  void cancel(CanvasController controller) {}

  ToolResult handleEvent(CanvasEvent event, CanvasController controller);

  void paintPreview(
    Canvas canvas,
    Size size,
    CanvasTransform transform,
    CanvasController controller,
  ) {}
}

sealed class ToolResult {
  const ToolResult();
}

class ToolResultNone extends ToolResult {
  const ToolResultNone();
}

class ToolResultConsumed extends ToolResult {
  const ToolResultConsumed();
}

class ToolResultElement extends ToolResult {
  const ToolResultElement(this.element);

  final CanvasElement element;
}

class ToolResultPreview extends ToolResult {
  const ToolResultPreview(this.preview);

  final CanvasElement? preview;
}

class ToolResultSelect extends ToolResult {
  const ToolResultSelect(this.selectedIds);

  final Set<String> selectedIds;
}
