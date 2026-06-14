import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/remove_element_command.dart';
import '../infinite_canvas/canvas_event.dart';
import 'canvas_tool.dart';

class EraserTool extends CanvasTool {
  EraserTool();

  static const idValue = 'eraser';

  /// Elements collected during the current drag session. Each is removed
  /// immediately from the canvas (without individual history entries) and then
  /// flushed as a single [BatchCommand] when the pointer lifts.
  final List<CanvasElement> _sessionDeleted = [];

  @override
  String get id => idValue;

  @override
  String get name => 'Eraser';

  @override
  IconData get icon => Icons.cleaning_services_outlined;

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    if (event is CanvasPointerDownEvent) {
      _sessionDeleted.clear();
      _eraseAt(event.worldPoint, controller);
      return const ToolResultConsumed();
    }
    if (event is CanvasPointerMoveEvent) {
      _eraseAt(event.worldPoint, controller);
      return const ToolResultConsumed();
    }
    if (event is CanvasPointerUpEvent) {
      _flushSession(controller);
      return const ToolResultConsumed();
    }
    return const ToolResultNone();
  }

  void _eraseAt(Offset worldPoint, CanvasController controller) {
    final element = controller.hitTest(worldPoint, tolerance: 10);
    if (element == null) {
      return;
    }
    _sessionDeleted.add(element);
    controller.removeElement(element.id, record: false);
  }

  void _flushSession(CanvasController controller) {
    if (_sessionDeleted.isEmpty) {
      return;
    }
    controller.recordCommand(
      BatchCommand(
        commands: [
          for (final element in _sessionDeleted) RemoveElementCommand(element),
        ],
        description:
            _sessionDeleted.length == 1
                ? 'Erase element'
                : 'Erase ${_sessionDeleted.length} elements',
      ),
    );
    _sessionDeleted.clear();
  }

  @override
  void cancel(CanvasController controller) {
    _sessionDeleted.clear();
  }
}
