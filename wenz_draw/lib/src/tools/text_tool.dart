import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/text_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class TextTool extends CanvasTool {
  const TextTool({this.defaultText = 'Text'});

  static const idValue = 'text';

  final String defaultText;

  @override
  String get id => idValue;

  @override
  String get name => 'Text';

  @override
  IconData get icon => Icons.text_fields;

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    if (event is! CanvasPointerDownEvent) {
      return const ToolResultNone();
    }
    return ToolResultElement(
      TextElement(
        id: UuidGenerator.create(),
        position: event.worldPoint,
        text: defaultText,
        maxWidth: 240,
        boxSize: const Size(240, 96),
        style: TextStyle(
          color: controller.brushSettings.color,
          fontSize: controller.brushSettings.strokeWidth * 8,
          height: 1.2,
        ),
      ),
    );
  }
}
