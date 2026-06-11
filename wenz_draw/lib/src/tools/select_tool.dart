import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/update_element_command.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/math_utils.dart';
import 'canvas_tool.dart';

class SelectTool extends CanvasTool {
  SelectTool();

  static const idValue = 'select';

  Offset? _dragStart;
  Offset? _lastPoint;
  Rect? _selectionRect;
  bool _movingSelection = false;
  Map<String, CanvasElement> _moveBefore = const {};

  @override
  String get id => idValue;

  @override
  String get name => 'Select';

  @override
  IconData get icon => Icons.near_me_outlined;

  @override
  void cancel(CanvasController controller) {
    _dragStart = null;
    _lastPoint = null;
    _selectionRect = null;
    _movingSelection = false;
    _moveBefore = const {};
    controller.setSelectionRect(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        final hit = controller.hitTest(event.worldPoint);
        _dragStart = event.worldPoint;
        _lastPoint = event.worldPoint;
        if (hit != null) {
          if (!controller.selectedIds.contains(hit.id)) {
            controller.setSelection({hit.id});
          }
          _movingSelection = true;
          _moveBefore = {
            for (final element in controller.selectedElements)
              element.id: element,
          };
          return const ToolResultConsumed();
        }
        _movingSelection = false;
        _selectionRect = Rect.fromPoints(event.worldPoint, event.worldPoint);
        controller.setSelection(const <String>{});
        controller.setSelectionRect(_selectionRect);
        return const ToolResultConsumed();
      case CanvasPointerMoveEvent():
        final start = _dragStart;
        final last = _lastPoint;
        if (start == null || last == null) {
          return const ToolResultNone();
        }
        if (_movingSelection) {
          final delta = event.worldPoint - last;
          controller.moveSelected(delta, record: false);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
        }
        _selectionRect = normalizedRectFromPoints(start, event.worldPoint);
        controller.setSelectionRect(_selectionRect);
        return const ToolResultConsumed();
      case CanvasPointerUpEvent():
        if (_movingSelection) {
          _recordMove(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
        final rect = _selectionRect;
        if (rect != null) {
          controller.selectInRect(rect);
        }
        cancel(controller);
        return const ToolResultConsumed();
      default:
        return const ToolResultNone();
    }
  }

  void _recordMove(CanvasController controller) {
    final commands = <UpdateElementCommand>[];
    for (final after in controller.selectedElements) {
      final before = _moveBefore[after.id];
      if (before != null && before.bounds != after.bounds) {
        commands.add(
          UpdateElementCommand(
            before: before,
            after: after,
            description: 'Move ${after.type}',
          ),
        );
      }
    }
    if (commands.isEmpty) {
      return;
    }
    controller.recordCommand(
      BatchCommand(commands: commands, description: 'Move selection'),
    );
  }
}
