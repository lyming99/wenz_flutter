import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
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
  bool _draggingPolylinePoint = false;
  bool _draggingPolylineSegment = false;
  _SelectionResizeHandle? _resizeHandle;
  _LineEndpoint? _lineEndpoint;
  int? _polylinePointIndex;
  int? _polylineSegmentIndex;
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
    _draggingPolylinePoint = false;
    _draggingPolylineSegment = false;
    _resizeHandle = null;
    _lineEndpoint = null;
    _polylinePointIndex = null;
    _polylineSegmentIndex = null;
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
        final polylinePointTarget = _polylinePointTargetAt(controller, event);
        final lineEndpointTarget = polylinePointTarget == null
            ? _lineEndpointTargetAt(controller, event)
            : null;
        final polylineSegmentTarget =
            polylinePointTarget == null && lineEndpointTarget == null
            ? _polylineSegmentTargetAt(controller, event)
            : null;
        final resizeTarget =
            lineEndpointTarget == null &&
                polylinePointTarget == null &&
                polylineSegmentTarget == null
            ? _resizeTargetAt(controller, event)
            : null;
        _dragStart = event.worldPoint;
        _lastPoint = event.worldPoint;
        if (polylinePointTarget != null) {
          controller.setSelection({polylinePointTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = false;
          _draggingPolylinePoint = true;
          _draggingPolylineSegment = false;
          _polylinePointIndex = polylinePointTarget.pointIndex;
          _lineEndpointBefore = polylinePointTarget.element;
          return const ToolResultConsumed();
        }
        if (lineEndpointTarget != null) {
          controller.setSelection({lineEndpointTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = true;
          _draggingPolylinePoint = false;
          _draggingPolylineSegment = false;
          _lineEndpoint = lineEndpointTarget.endpoint;
          _lineEndpointBefore = lineEndpointTarget.element;
          return const ToolResultConsumed();
        }
        if (polylineSegmentTarget != null) {
          controller.setSelection({polylineSegmentTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = false;
          _draggingPolylinePoint = false;
          _draggingPolylineSegment = true;
          _polylineSegmentIndex = polylineSegmentTarget.segmentIndex;
          _lineEndpointBefore = polylineSegmentTarget.element;
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
        if (_draggingPolylinePoint) {
          _dragPolylinePoint(controller, event.worldPoint);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
        }
        if (_draggingPolylineSegment) {
          _dragPolylineSegment(controller, event.worldPoint);
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
        if (_draggingPolylinePoint) {
          _recordLineEndpointDrag(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
        if (_draggingPolylineSegment) {
          _recordLineEndpointDrag(controller);
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
        if (hit
            case RectElement(:final id) ||
                EllipseElement(:final id) ||
                LineElement(:final id) ||
                ArrowElement(:final id) ||
                PolylineElement(:final id)) {
          controller.beginShapeLabelEditing(id);
          return const ToolResultConsumed();
        }
        return const ToolResultNone();
      default:
        return const ToolResultNone();
    }
  }

  _PolylinePointTarget? _polylinePointTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      if (element is! PolylineElement || element.points.length <= 2) {
        continue;
      }
      for (var i = 1; i < element.points.length - 1; i++) {
        if ((event.worldPoint - element.points[i]).distance <= tolerance) {
          return _PolylinePointTarget(element, i);
        }
      }
    }
    return null;
  }

  _PolylineSegmentTarget? _polylineSegmentTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 8 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      if (element is! PolylineElement || element.points.length < 2) {
        continue;
      }
      for (var i = 0; i < element.points.length - 1; i++) {
        final a = element.points[i];
        final b = element.points[i + 1];
        if ((b - a).distance <= 0.0001) {
          continue;
        }
        if (distanceToSegment(event.worldPoint, a, b) <= tolerance) {
          return _PolylineSegmentTarget(element, i);
        }
      }
    }
    return null;
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
      } else if (element is PolylineElement) {
        for (final endpoint in _LineEndpoint.values) {
          if ((event.worldPoint - endpoint.pointForPolyline(element))
                  .distance <=
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
    if (before is PolylineElement) {
      final current = controller.elementById(before.id);
      if (current is! PolylineElement) {
        return;
      }
      controller.updateElement(
        before.id,
        endpoint.applyToPolylineLocally(current, nextPoint, binding),
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

  void _dragPolylinePoint(CanvasController controller, Offset worldPoint) {
    final before = _lineEndpointBefore;
    final index = _polylinePointIndex;
    if (before is! PolylineElement || index == null) {
      return;
    }
    final current = controller.elementById(before.id);
    if (current is! PolylineElement ||
        index <= 0 ||
        index >= current.points.length - 1) {
      return;
    }
    final points = List<Offset>.of(current.points);
    final fixedStart = current.points.first;
    final fixedEnd = current.points.last;
    final previous = points[index - 1];
    final currentPoint = points[index];
    final next = points[index + 1];
    final previousHorizontal = _isHorizontal(previous, currentPoint);
    final nextHorizontal = _isHorizontal(currentPoint, next);
    final previousVertical = _isVertical(previous, currentPoint);
    final nextVertical = _isVertical(currentPoint, next);

    if (previousHorizontal && nextVertical) {
      final x = worldPoint.dx;
      final y = index - 1 == 0 ? previous.dy : worldPoint.dy;
      if (index - 1 != 0) {
        points[index - 1] = Offset(previous.dx, y);
      }
      points[index] = Offset(x, y);
      if (index + 1 == points.length - 1) {
        points.insert(index + 1, Offset(x, next.dy));
      } else {
        points[index + 1] = Offset(x, next.dy);
      }
    } else if (previousVertical && nextHorizontal) {
      final x = index - 1 == 0 ? previous.dx : worldPoint.dx;
      final y = worldPoint.dy;
      if (index - 1 != 0) {
        points[index - 1] = Offset(x, previous.dy);
      }
      points[index] = Offset(x, y);
      if (index + 1 == points.length - 1) {
        points.insert(index + 1, Offset(next.dx, y));
      } else {
        points[index + 1] = Offset(next.dx, y);
      }
    } else if (previousHorizontal && nextHorizontal) {
      points[index - 1] = Offset(previous.dx, worldPoint.dy);
      points[index] = Offset(worldPoint.dx, worldPoint.dy);
      points[index + 1] = Offset(next.dx, worldPoint.dy);
    } else if (previousVertical && nextVertical) {
      points[index - 1] = Offset(worldPoint.dx, previous.dy);
      points[index] = Offset(worldPoint.dx, worldPoint.dy);
      points[index + 1] = Offset(worldPoint.dx, next.dy);
    } else if (previousHorizontal) {
      points[index] = Offset(worldPoint.dx, previous.dy);
      points[index + 1] = Offset(worldPoint.dx, next.dy);
    } else if (nextHorizontal) {
      points[index - 1] = Offset(worldPoint.dx, previous.dy);
      points[index] = Offset(worldPoint.dx, next.dy);
    } else {
      points[index] = worldPoint;
    }

    points[0] = fixedStart;
    points[points.length - 1] = fixedEnd;

    controller.updateElement(
      before.id,
      current.copyWith(points: _simplifyPolylinePoints(points)),
      record: false,
    );
  }

  void _dragPolylineSegment(CanvasController controller, Offset worldPoint) {
    final before = _lineEndpointBefore;
    final start = _dragStart;
    final index = _polylineSegmentIndex;
    if (before is! PolylineElement || start == null || index == null) {
      return;
    }
    final current = controller.elementById(before.id);
    if (current is! PolylineElement || index >= before.points.length - 1) {
      return;
    }

    final points = List<Offset>.of(before.points);
    final fixedStart = before.points.first;
    final fixedEnd = before.points.last;
    final a = before.points[index];
    final b = before.points[index + 1];
    if (_isHorizontal(a, b)) {
      final dy = worldPoint.dy - start.dy;
      final movedA = Offset(a.dx, a.dy + dy);
      final movedB = Offset(b.dx, b.dy + dy);
      if (index == 0) {
        points[0] = fixedStart;
        points[1] = movedB;
        points.insert(1, Offset(fixedStart.dx, movedB.dy));
      } else if (index + 1 == before.points.length - 1) {
        points[index] = movedA;
        points.insert(index + 1, Offset(fixedEnd.dx, movedA.dy));
        points[points.length - 1] = fixedEnd;
      } else {
        points[index] = movedA;
        points[index + 1] = movedB;
      }
    } else if (_isVertical(a, b)) {
      final dx = worldPoint.dx - start.dx;
      final movedA = Offset(a.dx + dx, a.dy);
      final movedB = Offset(b.dx + dx, b.dy);
      if (index == 0) {
        points[0] = fixedStart;
        points[1] = movedB;
        points.insert(1, Offset(movedB.dx, fixedStart.dy));
      } else if (index + 1 == before.points.length - 1) {
        points[index] = movedA;
        points.insert(index + 1, Offset(movedA.dx, fixedEnd.dy));
        points[points.length - 1] = fixedEnd;
      } else {
        points[index] = movedA;
        points[index + 1] = movedB;
      }
    } else {
      final delta = worldPoint - start;
      points[index] = a + delta;
      points[index + 1] = b + delta;
      points[0] = fixedStart;
      points[points.length - 1] = fixedEnd;
    }

    controller.updateElement(
      before.id,
      current.copyWith(points: _simplifyPolylinePoints(points)),
      record: false,
    );
  }

  bool _isHorizontal(Offset a, Offset b) => (a.dy - b.dy).abs() < 0.0001;

  bool _isVertical(Offset a, Offset b) => (a.dx - b.dx).abs() < 0.0001;

  List<Offset> _simplifyPolylinePoints(List<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isEmpty || (result.last - point).distance > 0.0001) {
        result.add(point);
      }
    }
    if (result.length <= 2) {
      return result;
    }
    final simplified = <Offset>[];
    for (final point in result) {
      simplified.add(point);
      while (simplified.length >= 3) {
        final a = simplified[simplified.length - 3];
        final b = simplified[simplified.length - 2];
        final c = simplified[simplified.length - 1];
        final sameX =
            (a.dx - b.dx).abs() < 0.0001 && (b.dx - c.dx).abs() < 0.0001;
        final sameY =
            (a.dy - b.dy).abs() < 0.0001 && (b.dy - c.dy).abs() < 0.0001;
        if (!sameX && !sameY) {
          break;
        }
        simplified.removeAt(simplified.length - 2);
      }
    }
    return simplified;
  }

  void _recordLineEndpointDrag(CanvasController controller) {
    controller.setSnapPreview(null);
    final before = _lineEndpointBefore;
    if (before == null) {
      return;
    }
    final endpoint = _lineEndpoint;
    if (before is PolylineElement && endpoint != null) {
      final current = controller.elementById(before.id);
      if (current is PolylineElement) {
        final point = endpoint.pointForPolyline(current);
        final binding = endpoint == _LineEndpoint.start
            ? current.startBinding
            : current.endBinding;
        controller.updateElement(
          before.id,
          endpoint.applyToPolyline(controller, current, point, binding),
          record: false,
        );
      }
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

  Offset pointForPolyline(PolylineElement element) {
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

  PolylineElement applyToPolylineLocally(
    PolylineElement element,
    Offset point,
    SnapBinding? binding,
  ) {
    if (element.points.length < 2) {
      return element;
    }
    final points = List<Offset>.of(element.points);
    if (this == _LineEndpoint.start) {
      points[0] = point;
      final next = points[1];
      final horizontal = (next.dy - element.start.dy).abs() < 0.0001;
      points[1] = horizontal
          ? Offset(next.dx, point.dy)
          : Offset(point.dx, next.dy);
      return element.copyWith(
        points: _simplifyEndpointPoints(points),
        startBinding: binding,
      );
    }
    points[points.length - 1] = point;
    final previous = points[points.length - 2];
    final horizontal = (previous.dy - element.end.dy).abs() < 0.0001;
    points[points.length - 2] = horizontal
        ? Offset(previous.dx, point.dy)
        : Offset(point.dx, previous.dy);
    return element.copyWith(
      points: _simplifyEndpointPoints(points),
      endBinding: binding,
    );
  }

  PolylineElement applyToPolyline(
    CanvasController controller,
    PolylineElement element,
    Offset point,
    SnapBinding? binding,
  ) {
    if (element.points.isEmpty) {
      return element;
    }
    final startBinding = this == _LineEndpoint.start
        ? binding
        : element.startBinding;
    final endBinding = this == _LineEndpoint.end ? binding : element.endBinding;
    final start = this == _LineEndpoint.start ? point : element.start;
    final end = this == _LineEndpoint.end ? point : element.end;
    final nextPoints = binding == null
        ? _replaceDraggedEndpoint(element, point)
        : controller.routeConnector(
            start: start,
            end: end,
            startBinding: startBinding,
            endBinding: endBinding,
            connectorId: element.id,
            previousRoute: element.points,
            quality: controller.connectorRoutingOptions.finalQuality,
          );
    return switch (this) {
      _LineEndpoint.start => element.copyWith(
        points: nextPoints,
        startBinding: binding,
      ),
      _LineEndpoint.end => element.copyWith(
        points: nextPoints,
        endBinding: binding,
      ),
    };
  }

  List<Offset> _replaceDraggedEndpoint(PolylineElement element, Offset point) {
    final points = List<Offset>.of(element.points);
    if (this == _LineEndpoint.start) {
      points[0] = point;
    } else {
      points[points.length - 1] = point;
    }
    return _simplifyEndpointPoints(points);
  }

  List<Offset> _simplifyEndpointPoints(List<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isEmpty || (result.last - point).distance > 0.0001) {
        result.add(point);
      }
    }
    if (result.length <= 2) {
      return result;
    }
    final simplified = <Offset>[];
    for (final point in result) {
      simplified.add(point);
      while (simplified.length >= 3) {
        final a = simplified[simplified.length - 3];
        final b = simplified[simplified.length - 2];
        final c = simplified[simplified.length - 1];
        final sameX =
            (a.dx - b.dx).abs() < 0.0001 && (b.dx - c.dx).abs() < 0.0001;
        final sameY =
            (a.dy - b.dy).abs() < 0.0001 && (b.dy - c.dy).abs() < 0.0001;
        if (!sameX && !sameY) {
          break;
        }
        simplified.removeAt(simplified.length - 2);
      }
    }
    return simplified;
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

class _PolylinePointTarget {
  const _PolylinePointTarget(this.element, this.pointIndex);

  final PolylineElement element;
  final int pointIndex;
}

class _PolylineSegmentTarget {
  const _PolylineSegmentTarget(this.element, this.segmentIndex);

  final PolylineElement element;
  final int segmentIndex;
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
