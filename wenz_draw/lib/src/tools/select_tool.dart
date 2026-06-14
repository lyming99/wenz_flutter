import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/image_element.dart';
import '../elements/line_element.dart';
import '../elements/curve_element.dart';
import '../elements/polyline_element.dart';
import '../elements/rect_element.dart';
import '../elements/text_element.dart';
import '../elements/arrow_element.dart';
import '../elements/widget_element.dart';
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
  bool _stretchingElement = false;
  bool _rotatingSelection = false;
  bool _draggingLineEndpoint = false;
  bool _draggingPolylinePoint = false;
  bool _draggingPolylineSegment = false;
  bool _draggingCurveControl = false;
  _SelectionResizeHandle? _resizeHandle;
  _LineEndpoint? _lineEndpoint;
  int? _polylinePointIndex;
  int? _polylineSegmentIndex;
  TextElement? _resizeBefore;
  CanvasElement? _scaleBefore;
  CanvasElement? _stretchBefore;
  CanvasElement? _lineEndpointBefore;
  Offset? _resizeAnchor;
  static const double _minTextBoxWidth = 24;
  static const double _minTextBoxHeight = 24;
  Map<String, CanvasElement> _moveBefore = const {};
  Map<String, CanvasElement> _rotateBefore = const {};
  Offset? _rotationCenter;
  double? _rotationStartAngle;

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
    _stretchingElement = false;
    _rotatingSelection = false;
    _draggingLineEndpoint = false;
    _draggingPolylinePoint = false;
    _draggingPolylineSegment = false;
    _draggingCurveControl = false;
    _resizeHandle = null;
    _lineEndpoint = null;
    _polylinePointIndex = null;
    _polylineSegmentIndex = null;
    _resizeBefore = null;
    _scaleBefore = null;
    _stretchBefore = null;
    _lineEndpointBefore = null;
    _resizeAnchor = null;
    _moveBefore = const {};
    _rotateBefore = const {};
    _rotationCenter = null;
    _rotationStartAngle = null;
    controller.setSelectionRect(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        final curveControlTarget = _curveControlTargetAt(controller, event);
        final polylinePointTarget = _polylinePointTargetAt(controller, event);
        final lineEndpointTarget =
            polylinePointTarget == null && curveControlTarget == null
            ? _lineEndpointTargetAt(controller, event)
            : null;
        final polylineSegmentTarget =
            polylinePointTarget == null &&
                lineEndpointTarget == null &&
                curveControlTarget == null
            ? _polylineSegmentTargetAt(controller, event)
            : null;
        final rotateTarget =
            lineEndpointTarget == null &&
                polylinePointTarget == null &&
                polylineSegmentTarget == null &&
                curveControlTarget == null
            ? _rotateTargetAt(controller, event)
            : null;
        final resizeTarget =
            rotateTarget == null &&
                lineEndpointTarget == null &&
                polylinePointTarget == null &&
                polylineSegmentTarget == null &&
                curveControlTarget == null
            ? _resizeTargetAt(controller, event)
            : null;
        _dragStart = event.worldPoint;
        _lastPoint = event.worldPoint;
        if (curveControlTarget != null) {
          controller.setSelection({curveControlTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = false;
          _draggingPolylinePoint = false;
          _draggingPolylineSegment = false;
          _draggingCurveControl = true;
          _lineEndpointBefore = curveControlTarget.element;
          return const ToolResultConsumed();
        }
        if (polylinePointTarget != null) {
          controller.setSelection({polylinePointTarget.element.id});
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _draggingLineEndpoint = false;
          _draggingPolylinePoint = true;
          _draggingPolylineSegment = false;
          _draggingCurveControl = false;
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
          _draggingCurveControl = false;
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
          _draggingCurveControl = false;
          _polylineSegmentIndex = polylineSegmentTarget.segmentIndex;
          _lineEndpointBefore = polylineSegmentTarget.element;
          return const ToolResultConsumed();
        }
        if (rotateTarget != null) {
          _movingSelection = false;
          _resizingText = false;
          _scalingElement = false;
          _rotatingSelection = true;
          _draggingLineEndpoint = false;
          _draggingPolylinePoint = false;
          _draggingPolylineSegment = false;
          _draggingCurveControl = false;
          _rotationCenter = rotateTarget.center;
          _rotationStartAngle = _angle(rotateTarget.center, event.worldPoint);
          _rotateBefore = {
            for (final element in controller.selectedElements)
              element.id: element,
          };
          return const ToolResultConsumed();
        }
        if (resizeTarget != null) {
          controller.setSelection({resizeTarget.element.id});
          _movingSelection = false;
          _resizeHandle = resizeTarget.handle;
          _resizeAnchor = _localAnchorFor(
            resizeTarget.element,
            resizeTarget.handle,
          );
          if (resizeTarget.handle.isEdge &&
              _canStretch(resizeTarget.element)) {
            _stretchingElement = true;
            _resizingText = false;
            _scalingElement = false;
            _stretchBefore = resizeTarget.element;
            _resizeBefore = null;
            _scaleBefore = null;
          } else if (resizeTarget.element is TextElement &&
              (resizeTarget.element as TextElement).boxSize != null) {
            _resizingText = true;
            _scalingElement = false;
            _stretchingElement = false;
            _resizeBefore = resizeTarget.element as TextElement;
            _scaleBefore = null;
            _stretchBefore = null;
          } else {
            _resizingText = false;
            _scalingElement = true;
            _stretchingElement = false;
            _resizeBefore = null;
            _scaleBefore = resizeTarget.element;
            _stretchBefore = null;
          }
          return const ToolResultConsumed();
        }

        final selectionBounds = _selectionBounds(controller);
        if (selectionBounds != null &&
            selectionBounds.contains(event.worldPoint)) {
          _movingSelection = true;
          _moveBefore = {
            for (final element in controller.selectedElements)
              element.id: element,
          };
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
        if (_rotatingSelection) {
          _rotateSelection(controller, event.worldPoint);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
        }
        if (_resizingText) {
          _resizeText(controller, event.worldPoint);
          _lastPoint = event.worldPoint;
          return const ToolResultConsumed();
        }
        if (_stretchingElement) {
          _stretchElement(controller, event.worldPoint);
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
        if (_draggingCurveControl) {
          _dragCurveControl(controller, event.worldPoint);
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
        if (_rotatingSelection) {
          _recordRotation(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
        if (_resizingText) {
          _recordResize(controller);
          cancel(controller);
          return const ToolResultConsumed();
        }
        if (_stretchingElement) {
          _recordStretch(controller);
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
        if (_draggingCurveControl) {
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
        final labelTarget =
            hit ?? _labelEditableElementAt(controller, event.worldPoint);
        if (labelTarget is TextElement) {
          controller.beginTextEditing(labelTarget.id);
          return const ToolResultConsumed();
        }
        if (labelTarget
            case DrawioShapeElement(:final id) ||
                RectElement(:final id) ||
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

  CanvasElement? _labelEditableElementAt(
    CanvasController controller,
    Offset worldPoint,
  ) {
    for (final element in controller.orderedElements().toList().reversed) {
      if (!element.visible ||
          !controller.isLayerVisible(element.layerId) ||
          controller.isLayerLocked(element.layerId)) {
        continue;
      }
      if (element is DrawioShapeElement && element.rect.contains(worldPoint)) {
        return element;
      }
      if (element is RectElement && element.rect.contains(worldPoint)) {
        return element;
      }
      if (element is EllipseElement && element.rect.contains(worldPoint)) {
        return element;
      }
    }
    return null;
  }

  Rect? _selectionBounds(CanvasController controller) {
    Rect? bounds;
    for (final element in controller.selectedElements) {
      bounds = bounds == null
          ? element.bounds
          : bounds.expandToInclude(element.bounds);
    }
    return bounds;
  }

  _CurveControlTarget? _curveControlTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      if (element is CurveElement) {
        if ((event.worldPoint - element.control).distance <= tolerance) {
          return _CurveControlTarget(element);
        }
      }
    }
    return null;
  }

  void _dragCurveControl(CanvasController controller, Offset worldPoint) {
    final before = _lineEndpointBefore;
    if (before is! CurveElement) {
      return;
    }
    final current = controller.elementById(before.id);
    if (current is! CurveElement) {
      return;
    }
    controller.updateElement(
      before.id,
      current.copyWith(control: worldPoint),
      record: false,
    );
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
      } else if (element is CurveElement) {
        for (final endpoint in _LineEndpoint.values) {
          if ((event.worldPoint - endpoint.pointForCurve(element)).distance <=
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

  _RotateTarget? _rotateTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final geometry = _rotateHandleGeometry(controller, event.transform.scale);
    if (geometry == null) {
      return null;
    }
    final tolerance = 12 / event.transform.scale;
    final handleRect = Rect.fromCenter(
      center: geometry.handle,
      width: 28 / event.transform.scale,
      height: 28 / event.transform.scale,
    );
    // Exclude a zone near the anchor (top edge center) so the stretch handle
    // there takes priority over the rotation connector line.
    final anchorZone = Rect.fromCenter(
      center: geometry.anchor,
      width: 16 / event.transform.scale,
      height: 16 / event.transform.scale,
    );
    if (anchorZone.contains(event.worldPoint)) {
      return null;
    }
    if (handleRect.contains(event.worldPoint) ||
        distanceToSegment(event.worldPoint, geometry.anchor, geometry.handle) <=
            tolerance) {
      return _RotateTarget(geometry.center);
    }
    return null;
  }

  _RotateHandleGeometry? _rotateHandleGeometry(
    CanvasController controller,
    double scale,
  ) {
    if (controller.selectedIds.isEmpty) {
      return null;
    }
    // Widget elements (mind map nodes, sticky notes, ...) can't be rotated —
    // their `rotateElement` is a no-op. Suppress the rotation handle entirely
    // when the selection contains only widget elements.
    final selectable = controller.selectedElements;
    if (selectable.isNotEmpty &&
        selectable.every((e) => e is CanvasWidgetElement)) {
      return null;
    }
    if (controller.selectedElements.length == 1) {
      final element = controller.selectedElements.first;
      final rotAngle = _rotationOf(element);
      if (rotAngle != 0) {
        final rect = _localRectPadded(element, 4 / scale);
        final center = _centerOf(element);
        final anchor = rotatePoint(
          Offset(rect.center.dx, rect.top),
          rotAngle,
          center,
        );
        final direction = anchor - center;
        final distance = direction.distance;
        final normal = distance <= 0.0001
            ? const Offset(0, -1)
            : direction / distance;
        return _RotateHandleGeometry(
          center: center,
          anchor: anchor,
          handle: anchor + normal * (24 / scale),
        );
      }
    }

    final bounds = _selectionBounds(controller)?.inflate(4 / scale);
    if (bounds == null) {
      return null;
    }
    final center = bounds.center;
    final anchor = Offset(center.dx, bounds.top);
    return _RotateHandleGeometry(
      center: center,
      anchor: anchor,
      handle: Offset(center.dx, bounds.top - 24 / scale),
    );
  }

  _ResizeTarget? _resizeTargetAt(
    CanvasController controller,
    CanvasPointerDownEvent event,
  ) {
    final tolerance = 10 / event.transform.scale;
    for (final element in controller.selectedElements.reversed) {
      final rotAngle = _rotationOf(element);
      final center = _centerOf(element);
      final localRect = _localRectPadded(element, 0);
      final canStretch = _canStretch(element);
      // Check corners first (all elements with resize handles),
      // then edges (only stretchable elements).
      final handles = canStretch
          ? _SelectionResizeHandle.values
          : _SelectionResizeHandle.values.where((h) => h.isCorner);
      for (final handle in handles) {
        final localCorner = handle.pointFor(localRect);
        final worldCorner = rotAngle != 0
            ? rotatePoint(localCorner, rotAngle, center)
            : localCorner;
        if ((event.worldPoint - worldCorner).distance <= tolerance) {
          return _ResizeTarget(element, handle);
        }
      }
    }
    return null;
  }

  void _rotateSelection(CanvasController controller, Offset worldPoint) {
    final center = _rotationCenter;
    final startAngle = _rotationStartAngle;
    if (center == null || startAngle == null || _rotateBefore.isEmpty) {
      return;
    }
    final radians = _angle(center, worldPoint) - startAngle;
    for (final before in _rotateBefore.values) {
      final next = before.rotateElement(radians, pivot: center);
      controller.updateElement(before.id, next, record: false);
    }
  }

  double _angle(Offset center, Offset point) {
    final vector = point - center;
    return math.atan2(vector.dy, vector.dx);
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

  /// Get the rotation angle for an element (0 for non-rotatable types).
  double _rotationOf(CanvasElement element) {
    if (element is DrawioShapeElement ||
        element is RectElement ||
        element is EllipseElement ||
        element is TextElement ||
        element is ImageElement) {
      return element.rotation;
    }
    return 0;
  }

  /// Get the element's geometric center (rect.center for rotatable shapes).
  Offset _centerOf(CanvasElement element) {
    if (element is DrawioShapeElement) {
      return element.rect.center;
    }
    if (element is RectElement) {
      return element.rect.center;
    }
    if (element is EllipseElement) {
      return element.rect.center;
    }
    if (element is TextElement) {
      return element.localBounds.center;
    }
    if (element is ImageElement) {
      return element.rect.center;
    }
    return element.bounds.center;
  }

  /// Get the element's local (un-rotated) rect with stroke padding.
  Rect _localRectPadded(CanvasElement element, double padding) {
    if (element is DrawioShapeElement) {
      return element.rect.inflate(
        padding + element.strokeStyle.strokeWidth / 2,
      );
    }
    if (element is RectElement) {
      return element.rect.inflate(
        padding + element.strokeStyle.strokeWidth / 2,
      );
    }
    if (element is EllipseElement) {
      return element.rect.inflate(
        padding + element.strokeStyle.strokeWidth / 2,
      );
    }
    if (element is TextElement) {
      return element.localBounds.inflate(padding);
    }
    if (element is ImageElement) {
      return element.rect.inflate(padding);
    }
    return element.bounds.inflate(padding);
  }

  /// The local-space anchor (opposite corner) for a resize handle.
  /// This is always in the element's local coordinate system (no rotation).
  Offset _localAnchorFor(
    CanvasElement element,
    _SelectionResizeHandle handle,
  ) {
    return handle.anchorFor(_localRectPadded(element, 0));
  }

  void _scaleElement(CanvasController controller, Offset worldPoint) {
    final before = _scaleBefore;
    final anchor = _resizeAnchor;
    if (before == null || anchor == null) {
      return;
    }

    final rotAngle = _rotationOf(before);
    final center = _centerOf(before);

    // Work in local (un-rotated) space.
    final localMouse = rotAngle != 0
        ? inverseRotatePoint(worldPoint, rotAngle, center)
        : worldPoint;

    final localRect = _localRectPadded(before, 0);
    final draggedCorner = _resizeHandle!.pointFor(localRect);
    final beforeDistance = (draggedCorner - anchor).distance;
    if (beforeDistance <= 0.0001) {
      return;
    }
    final nextDistance = (localMouse - anchor).distance;
    final factor = (nextDistance / beforeDistance).clamp(0.05, 100.0);
    final scaled = before.scaleElement(factor, pivot: anchor);
    if (scaled.bounds.width < _minTextBoxWidth ||
        scaled.bounds.height < _minTextBoxHeight) {
      return;
    }
    controller.updateElement(before.id, scaled, record: false);
  }

  /// Whether an element supports non-uniform stretch.
  bool _canStretch(CanvasElement element) {
    return element is DrawioShapeElement ||
        element is RectElement ||
        element is EllipseElement ||
        element is ImageElement ||
        element is TextElement;
  }

  /// Stretch (non-uniform resize) an element via an edge handle.
  void _stretchElement(CanvasController controller, Offset worldPoint) {
    final before = _stretchBefore;
    final handle = _resizeHandle;
    final anchor = _resizeAnchor;
    if (before == null || handle == null || anchor == null) {
      return;
    }

    final rotAngle = _rotationOf(before);
    final center = _centerOf(before);

    // Work in local (un-rotated) space.
    final localMouse = rotAngle != 0
        ? inverseRotatePoint(worldPoint, rotAngle, center)
        : worldPoint;

    final localRect = _localRectPadded(before, 0);

    double newLeft = localRect.left;
    double newTop = localRect.top;
    double newRight = localRect.right;
    double newBottom = localRect.bottom;

    if (handle.isLeft) {
      newLeft = localMouse.dx.clamp(newRight - 10000, newRight - 1);
    }
    if (handle.isRight) {
      newRight = localMouse.dx.clamp(newLeft + 1, newLeft + 10000);
    }
    if (handle.isTop) {
      newTop = localMouse.dy.clamp(newBottom - 10000, newBottom - 1);
    }
    if (handle.isBottom) {
      newBottom = localMouse.dy.clamp(newTop + 1, newTop + 10000);
    }

    final newRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    if (newRect.width < 1 || newRect.height < 1) {
      return;
    }

    final stretched = _applyNewRect(before, newRect);
    controller.updateElement(before.id, stretched, record: false);
  }

  /// Apply a new unrotated rect to an element (non-uniform resize).
  CanvasElement _applyNewRect(CanvasElement element, Rect newRect) {
    if (element is DrawioShapeElement) {
      return element.copyWith(rect: newRect);
    }
    if (element is RectElement) {
      return element.copyWith(rect: newRect);
    }
    if (element is EllipseElement) {
      return element.copyWith(rect: newRect);
    }
    if (element is ImageElement) {
      return element.copyWith(rect: newRect);
    }
    if (element is TextElement) {
      return element.copyWith(
        position: newRect.topLeft,
        maxWidth: newRect.width,
        boxSize: newRect.size,
      );
    }
    return element;
  }

  void _recordStretch(CanvasController controller) {
    final before = _stretchBefore;
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
        description: 'Stretch ${after.type}',
      ),
    );
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
    if (before is CurveElement) {
      final current = controller.elementById(before.id);
      if (current is! CurveElement) {
        return;
      }
      controller.updateElement(
        before.id,
        endpoint.applyToCurve(current, nextPoint),
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

  void _recordRotation(CanvasController controller) {
    final commands = <UpdateElementCommand>[];
    for (final after in controller.selectedElements) {
      final before = _rotateBefore[after.id];
      if (before != null &&
          before.toJson().toString() != after.toJson().toString()) {
        commands.add(
          UpdateElementCommand(
            before: before,
            after: after,
            description: 'Rotate ${after.type}',
          ),
        );
      }
    }
    if (commands.isEmpty) {
      return;
    }
    controller.recordCommand(
      BatchCommand(commands: commands, description: 'Rotate selection'),
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
  bottomRight,
  top,
  bottom,
  left,
  right;

  bool get isCorner =>
      this == topLeft ||
      this == topRight ||
      this == bottomLeft ||
      this == bottomRight;
  bool get isEdge =>
      this == top || this == bottom || this == left || this == right;
  bool get isLeft => this == topLeft || this == bottomLeft || this == left;
  bool get isRight => this == topRight || this == bottomRight || this == right;
  bool get isTop => this == topLeft || this == topRight || this == top;
  bool get isBottom =>
      this == bottomLeft || this == bottomRight || this == bottom;

  Offset pointFor(Rect rect) {
    return switch (this) {
      topLeft => rect.topLeft,
      topRight => rect.topRight,
      bottomLeft => rect.bottomLeft,
      bottomRight => rect.bottomRight,
      top => Offset(rect.center.dx, rect.top),
      bottom => Offset(rect.center.dx, rect.bottom),
      left => Offset(rect.left, rect.center.dy),
      right => Offset(rect.right, rect.center.dy),
    };
  }

  Offset anchorFor(Rect rect) {
    return switch (this) {
      topLeft => rect.bottomRight,
      topRight => rect.bottomLeft,
      bottomLeft => rect.topRight,
      bottomRight => rect.topLeft,
      top => rect.bottomCenter,
      bottom => rect.topCenter,
      left => rect.centerRight,
      right => rect.centerLeft,
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

  Offset pointForCurve(CurveElement element) {
    return switch (this) {
      _LineEndpoint.start => element.start,
      _LineEndpoint.end => element.end,
    };
  }

  CurveElement applyToCurve(CurveElement element, Offset point) {
    return switch (this) {
      _LineEndpoint.start => element.copyWith(start: point),
      _LineEndpoint.end => element.copyWith(end: point),
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

class _CurveControlTarget {
  const _CurveControlTarget(this.element);

  final CurveElement element;
}

class _RotateHandleGeometry {
  const _RotateHandleGeometry({
    required this.center,
    required this.anchor,
    required this.handle,
  });

  final Offset center;
  final Offset anchor;
  final Offset handle;
}

class _RotateTarget {
  const _RotateTarget(this.center);

  final Offset center;
}

class _ResizeTarget {
  const _ResizeTarget(this.element, this.handle);

  final CanvasElement element;
  final _SelectionResizeHandle handle;
}
