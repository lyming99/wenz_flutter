import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/text_element.dart';
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
  bool _resizingText = false;
  _TextResizeHandle? _resizeHandle;
  TextElement? _resizeBefore;
  Offset? _resizeAnchor;
  static const double _minTextBoxWidth = 24;
  static const double _minTextBoxHeight = 24;
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
    _resizingText = false;
    _resizeHandle = null;
    _resizeBefore = null;
    _resizeAnchor = null;
    _moveBefore = const {};
    controller.setSelectionRect(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        final resizeTarget = _resizeTargetAt(controller, event);
        _dragStart = event.worldPoint;
        _lastPoint = event.worldPoint;
        if (resizeTarget != null) {
          controller.setSelection({resizeTarget.element.id});
          _resizingText = true;
          _movingSelection = false;
          _resizeHandle = resizeTarget.handle;
          _resizeBefore = resizeTarget.element;
          _resizeAnchor = resizeTarget.handle.anchorFor(
            resizeTarget.element.bounds,
          );
          return const ToolResultConsumed();
        }

        final hit = controller.hitTest(event.worldPoint);
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
        if (_resizingText) {
          _resizeText(controller, event.worldPoint);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
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
        if (_resizingText) {
          _recordResize(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
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
      case CanvasDoubleTapEvent():
        final hit = controller.hitTest(event.worldPoint);
        if (hit is TextElement) {
          controller.beginTextEditing(hit.id);
          return const ToolResultConsumed();
        }
        return const ToolResultNone();
      default:
        return const ToolResultNone();
    }
  }

  _TextResizeTarget? _resizeTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      if (element is! TextElement || element.boxSize == null) {
        continue;
      }
      for (final handle in _TextResizeHandle.values) {
        if ((event.worldPoint - handle.pointFor(element.bounds)).distance <=
            tolerance) {
          return _TextResizeTarget(element, handle);
        }
      }
    }
    return null;
  }

  void _resizeText(CanvasController controller, Offset worldPoint) {
    final before = _resizeBefore;
    final handle = _resizeHandle;
    final anchor = _resizeAnchor;
    if (before == null || handle == null || anchor == null) {
      return;
    }

    final rawRect = Rect.fromPoints(anchor, worldPoint);
    var left = rawRect.left;
    var top = rawRect.top;
    var right = rawRect.right;
    var bottom = rawRect.bottom;

    if (rawRect.width < _minTextBoxWidth) {
      if (handle.isLeft) {
        left = right - _minTextBoxWidth;
      } else {
        right = left + _minTextBoxWidth;
      }
    }
    if (rawRect.height < _minTextBoxHeight) {
      if (handle.isTop) {
        top = bottom - _minTextBoxHeight;
      } else {
        bottom = top + _minTextBoxHeight;
      }
    }

    final rect = Rect.fromLTRB(left, top, right, bottom);
    controller.updateElement(
      before.id,
      before.copyWith(
        position: rect.topLeft,
        maxWidth: rect.width,
        boxSize: rect.size,
      ),
      record: false,
    );
  }

  void _recordResize(CanvasController controller) {
    final before = _resizeBefore;
    if (before == null) {
      return;
    }
    final after = controller.elementById(before.id);
    if (after is! TextElement ||
        (after.position == before.position &&
            after.boxSize == before.boxSize)) {
      return;
    }
    controller.recordCommand(
      UpdateElementCommand(
        before: before,
        after: after,
        description: 'Resize text',
      ),
    );
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

enum _TextResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get isLeft => this == topLeft || this == bottomLeft;
  bool get isTop => this == topLeft || this == topRight;

  Offset pointFor(Rect rect) {
    return switch (this) {
      topLeft => rect.topLeft,
      topRight => rect.topRight,
      bottomLeft => rect.bottomLeft,
      bottomRight => rect.bottomRight,
    };
  }

  Offset anchorFor(Rect rect) {
    return switch (this) {
      topLeft => rect.bottomRight,
      topRight => rect.bottomLeft,
      bottomLeft => rect.topRight,
      bottomRight => rect.topLeft,
    };
  }
}

class _TextResizeTarget {
  const _TextResizeTarget(this.element, this.handle);

  final TextElement element;
  final _TextResizeHandle handle;
}
