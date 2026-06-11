import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/line_element.dart';
import '../elements/rect_element.dart';
import '../elements/text_element.dart';
import '../elements/arrow_element.dart';
import '../history/commands/batch_command.dart';
import '../history/commands/update_element_command.dart';
import '../infinite_canvas/canvas_event.dart';
import '../snap/snap_resolver.dart';
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
  bool _scalingElement = false;
  bool _draggingLineEndpoint = false;
  _SelectionResizeHandle? _resizeHandle;
  _LineEndpoint? _lineEndpoint;
  TextElement? _resizeBefore;
  CanvasElement? _scaleBefore;
  CanvasElement? _lineEndpointBefore;
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
    _scalingElement = false;
    _draggingLineEndpoint = false;
    _resizeHandle = null;
    _lineEndpoint = null;
    _resizeBefore = null;
    _scaleBefore = null;
    _lineEndpointBefore = null;
    _resizeAnchor = null;
    _moveBefore = const {};
    controller.setSelectionRect(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        final lineEndpointTarget = _lineEndpointTargetAt(controller, event);
        final resizeTarget = lineEndpointTarget == null
            ? _resizeTargetAt(controller, event)
            : null;
        _dragStart = event.worldPoint;
        _lastPoint = event.worldPoint;
        if (lineEndpointTarget != null) {
          controller.setSelection({lineEndpointTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = true;
          _lineEndpoint = lineEndpointTarget.endpoint;
          _lineEndpointBefore = lineEndpointTarget.element;
          return const ToolResultConsumed();
        }
        if (resizeTarget != null) {
          controller.setSelection({resizeTarget.element.id});
          _movingSelection = false;
          _resizeHandle = resizeTarget.handle;
          _resizeAnchor = resizeTarget.handle.anchorFor(
            resizeTarget.element.bounds,
          );
          if (resizeTarget.element is TextElement &&
              (resizeTarget.element as TextElement).boxSize != null) {
            _resizingText = true;
            _scalingElement = false;
            _resizeBefore = resizeTarget.element as TextElement;
            _scaleBefore = null;
          } else {
            _resizingText = false;
            _scalingElement = true;
            _resizeBefore = null;
            _scaleBefore = resizeTarget.element;
          }
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
        if (_scalingElement) {
          _scaleElement(controller, event.worldPoint);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
        }
        if (_draggingLineEndpoint) {
          _dragLineEndpoint(
            controller,
            event.worldPoint,
            event.transform.scale,
          );
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
        if (_scalingElement) {
          _recordScale(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
        if (_draggingLineEndpoint) {
          _recordLineEndpointDrag(controller);
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
        if (hit case RectElement(:final id) || EllipseElement(:final id)) {
          controller.beginShapeLabelEditing(id);
          return const ToolResultConsumed();
        }
        return const ToolResultNone();
      default:
        return const ToolResultNone();
    }
  }

  _LineEndpointTarget? _lineEndpointTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      if (element is LineElement) {
        for (final endpoint in _LineEndpoint.values) {
          if ((event.worldPoint - endpoint.pointForLine(element)).distance <=
              tolerance) {
            return _LineEndpointTarget(element, endpoint);
          }
        }
      } else if (element is ArrowElement) {
        for (final endpoint in _LineEndpoint.values) {
          if ((event.worldPoint - endpoint.pointForArrow(element)).distance <=
              tolerance) {
            return _LineEndpointTarget(element, endpoint);
          }
        }
      }
    }
    return null;
  }

  _ResizeTarget? _resizeTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      for (final handle in _SelectionResizeHandle.values) {
        if ((event.worldPoint - handle.pointFor(element.bounds)).distance <=
            tolerance) {
          return _ResizeTarget(element, handle);
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

  void _scaleElement(CanvasController controller, Offset worldPoint) {
    final before = _scaleBefore;
    final anchor = _resizeAnchor;
    if (before == null || anchor == null) {
      return;
    }

    final beforePoint = _oppositePoint(before.bounds, anchor);
    final beforeDistance = (beforePoint - anchor).distance;
    if (beforeDistance <= 0.0001) {
      return;
    }
    final nextDistance = (worldPoint - anchor).distance;
    final factor = (nextDistance / beforeDistance).clamp(0.05, 100.0);
    final scaled = before.scaleElement(factor, pivot: anchor);
    if (scaled.bounds.width < _minTextBoxWidth ||
        scaled.bounds.height < _minTextBoxHeight) {
      return;
    }
    controller.updateElement(before.id, scaled, record: false);
  }

  Offset _oppositePoint(Rect rect, Offset anchor) {
    if (anchor == rect.topLeft) {
      return rect.bottomRight;
    }
    if (anchor == rect.topRight) {
      return rect.bottomLeft;
    }
    if (anchor == rect.bottomLeft) {
      return rect.topRight;
    }
    return rect.topLeft;
  }

  void _dragLineEndpoint(
    CanvasController controller,
    Offset worldPoint,
    double scale,
  ) {
    final before = _lineEndpointBefore;
    final endpoint = _lineEndpoint;
    if (before == null || endpoint == null) {
      return;
    }
    final snap = controller.snapResolver.resolve(
      controller,
      worldPoint,
      scale: scale,
      excludeElementIds: {before.id},
    );
    controller.setSnapPreview(snap);
    final nextPoint = snap?.position ?? worldPoint;
    final binding = snap?.binding;

    if (before is LineElement) {
      final current = controller.elementById(before.id);
      if (current is! LineElement) {
        return;
      }
      controller.updateElement(
        before.id,
        endpoint.applyToLine(current, nextPoint, binding),
        record: false,
      );
      return;
    }
    if (before is ArrowElement) {
      final current = controller.elementById(before.id);
      if (current is! ArrowElement) {
        return;
      }
      controller.updateElement(
        before.id,
        endpoint.applyToArrow(current, nextPoint, binding),
        record: false,
      );
    }
  }

  void _recordLineEndpointDrag(CanvasController controller) {
    controller.setSnapPreview(null);
    final before = _lineEndpointBefore;
    if (before == null) {
      return;
    }
    final after = controller.elementById(before.id);
    if (after == null ||
        after.toJson().toString() == before.toJson().toString()) {
      return;
    }
    controller.recordCommand(
      UpdateElementCommand(
        before: before,
        after: after,
        description: 'Edit ${after.type} endpoint',
      ),
    );
  }

  void _recordScale(CanvasController controller) {
    final before = _scaleBefore;
    if (before == null) {
      return;
    }
    final after = controller.elementById(before.id);
    if (after == null ||
        after.toJson().toString() == before.toJson().toString()) {
      return;
    }
    controller.recordCommand(
      UpdateElementCommand(
        before: before,
        after: after,
        description: 'Scale ${after.type}',
      ),
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

enum _SelectionResizeHandle {
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

enum _LineEndpoint { start, end }

extension on _LineEndpoint {
  Offset pointForLine(LineElement element) {
    return switch (this) {
      _LineEndpoint.start => element.start,
      _LineEndpoint.end => element.end,
    };
  }

  Offset pointForArrow(ArrowElement element) {
    return switch (this) {
      _LineEndpoint.start => element.start,
      _LineEndpoint.end => element.end,
    };
  }

  LineElement applyToLine(
    LineElement element,
    Offset point,
    SnapBinding? binding,
  ) {
    return switch (this) {
      _LineEndpoint.start => element.copyWith(
        start: point,
        startBinding: binding,
      ),
      _LineEndpoint.end => element.copyWith(end: point, endBinding: binding),
    };
  }

  ArrowElement applyToArrow(
    ArrowElement element,
    Offset point,
    SnapBinding? binding,
  ) {
    return switch (this) {
      _LineEndpoint.start => element.copyWith(
        start: point,
        startBinding: binding,
      ),
      _LineEndpoint.end => element.copyWith(end: point, endBinding: binding),
    };
  }
}

class _LineEndpointTarget {
  const _LineEndpointTarget(this.element, this.endpoint);

  final CanvasElement element;
  final _LineEndpoint endpoint;
}

class _ResizeTarget {
  const _ResizeTarget(this.element, this.handle);

  final CanvasElement element;
  final _SelectionResizeHandle handle;
}
