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
  /// committed as a single [BatchCommand] when the session finishes.
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
      // A replacement pointer-down can arrive without a corresponding up
      // event. Preserve any deletion already applied by committing it first.
      commitPendingChanges(controller);
      _eraseAt(event.worldPoint, controller);
      return const ToolResultConsumed();
    }
    if (event is CanvasPointerMoveEvent) {
      _eraseAt(event.worldPoint, controller);
      return const ToolResultConsumed();
    }
    if (event is CanvasPointerUpEvent) {
      commitPendingChanges(controller);
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

  @override
  void commitPendingChanges(CanvasController controller) {
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
  void onDeactivate(CanvasController controller) {
    commitPendingChanges(controller);
  }

  @override
  void cancel(CanvasController controller) {
    // Erasing is applied immediately, so cancellation must retain a
    // reversible command instead of discarding the session.
    commitPendingChanges(controller);
  }
}
