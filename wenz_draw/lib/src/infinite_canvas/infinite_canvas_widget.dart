import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../canvas/canvas_controller.dart';
import '../elements/arrow_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/ellipse_element.dart';
import '../elements/line_element.dart';
import '../elements/line_label_painter.dart';
import '../elements/polyline_element.dart';
import '../elements/rect_element.dart';
import '../elements/shape_label_painter.dart';
import '../elements/text_element.dart';
import '../elements/widget_element.dart';
import '../history/commands/update_element_command.dart';
import '../tools/pan_tool.dart';
import '../tools/select_tool.dart';
import '../tools/text_tool.dart';
import '../widgets/canvas_widget_layer.dart';
import 'canvas_event.dart';
import 'infinite_canvas_config.dart';
import 'infinite_canvas_controller.dart';

class InfiniteCanvasWidget extends StatefulWidget {
  const InfiniteCanvasWidget({
    super.key,
    required this.controller,
    this.config = const InfiniteCanvasConfig(),
    this.clipBehavior = Clip.hardEdge,
  });

  final InfiniteCanvasController controller;
  final InfiniteCanvasConfig config;
  final Clip clipBehavior;

  @override
  State<InfiniteCanvasWidget> createState() => _InfiniteCanvasWidgetState();
}

class _InfiniteCanvasWidgetState extends State<InfiniteCanvasWidget> {
  final Map<int, Offset> _pointers = {};
  final Set<int> _widgetGesturePointers = {};
  final Map<int, _DeferredWidgetGesture> _deferredWidgetGestures = {};
  late final FocusNode _focusNode;

  Offset? _lastTapPosition;
  DateTime? _lastTapTime;

  Offset? _lastPinchCentroid;
  double? _lastPinchDistance;
  bool _toolSuppressedUntilClear = false;
  int? _editingResizePointer;
  TextElement? _editingResizeBefore;
  _EditingTextResizeHandle? _editingResizeHandle;
  Offset? _editingResizeAnchor;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'InfiniteCanvasWidget');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );
        if (size != widget.controller.viewportSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.controller.setViewportSize(size);
            }
          });
        }

        return ClipRect(
          clipBehavior: widget.clipBehavior,
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              onPointerSignal: _handlePointerSignal,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  widget.controller,
                  widget.controller.canvasController,
                ]),
                builder: (context, _) {
                  return SizedBox.expand(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CanvasWidgetLayer(
                          controller: widget.controller,
                          config: widget.config,
                        ),
                        _TextEditingOverlay(
                          key: ValueKey(
                            widget
                                .controller
                                .canvasController
                                .editingTextElementId,
                          ),
                          controller: widget.controller,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (_handleEditingPointerDown(event)) {
      return;
    }
    if (_dispatchDoubleTapIfNeeded(event)) {
      return;
    }
    if (_shouldDeferToWidget(event.localPosition)) {
      _widgetGesturePointers.add(event.pointer);
      _deferredWidgetGestures[event.pointer] = _DeferredWidgetGesture(
        screenPoint: event.localPosition,
        kind: event.kind,
        buttons: event.buttons,
        pressure: event.pressure,
      );
      return;
    }

    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length > 1) {
      _toolSuppressedUntilClear = true;
      widget.controller.canvasController.cancelCurrentInteraction();
      _updatePinchBaseline();
      return;
    }

    if (_toolSuppressedUntilClear) {
      return;
    }

    final worldPoint = widget.controller.screenToWorld(event.localPosition);
    final canvasController = widget.controller.canvasController;
    if (canvasController.currentTool?.id == TextTool.idValue) {
      final hit = canvasController.hitTest(worldPoint);
      if (hit is TextElement) {
        canvasController.beginTextEditing(hit.id);
        return;
      }
    }
    _dispatch(
      CanvasPointerDownEvent(
        screenPoint: event.localPosition,
        worldPoint: worldPoint,
        transform: widget.controller.transform,
        pointerCount: _pointers.length,
        pointer: event.pointer,
        kind: event.kind,
        buttons: event.buttons,
        pressure: event.pressure,
      ),
    );
  }

  bool _handleEditingPointerDown(PointerDownEvent event) {
    final canvasController = widget.controller.canvasController;
    final editingId = canvasController.editingTextElementId;
    final editingShapeId = canvasController.editingShapeLabelElementId;
    if (editingId == null && editingShapeId == null) {
      return false;
    }

    if (editingShapeId != null) {
      return _handleShapeLabelEditingPointerDown(event, editingShapeId);
    }

    final element = canvasController.elementById(editingId!);
    if (element is! TextElement) {
      canvasController.endTextEditing();
      return true;
    }

    final worldPoint = widget.controller.screenToWorld(event.localPosition);
    final handle = _editingResizeHandleAt(element, worldPoint);
    if (handle != null) {
      _editingResizePointer = event.pointer;
      _editingResizeBefore = element;
      _editingResizeHandle = handle;
      _editingResizeAnchor = handle.anchorFor(element.bounds);
      return true;
    }

    final toolbarRect = Rect.fromLTWH(
      element.bounds.left - 8 / widget.controller.transform.scale,
      element.bounds.top - 48 / widget.controller.transform.scale,
      element.bounds.width + 16 / widget.controller.transform.scale,
      40 / widget.controller.transform.scale,
    );

    if (toolbarRect.contains(worldPoint) ||
        element.bounds
            .inflate(14 / widget.controller.transform.scale)
            .contains(worldPoint)) {
      return true;
    }

    final hit = canvasController.hitTest(worldPoint);
    if (hit is TextElement) {
      canvasController.endTextEditing(removeIfEmpty: false);
      canvasController.beginTextEditing(hit.id);
      return true;
    }

    canvasController.endTextEditing(removeIfEmpty: false);
    return false;
  }

  bool _handleShapeLabelEditingPointerDown(
    PointerDownEvent event,
    String editingShapeId,
  ) {
    final canvasController = widget.controller.canvasController;
    final element = canvasController.elementById(editingShapeId);
    if (element is! DrawioShapeElement &&
        element is! RectElement &&
        element is! EllipseElement &&
        element is! LineElement &&
        element is! ArrowElement &&
        element is! PolylineElement) {
      canvasController.endShapeLabelEditing();
      return true;
    }

    final worldPoint = widget.controller.screenToWorld(event.localPosition);
    final bounds = _shapeLabelEditingBounds(element);
    final toolbarRect = Rect.fromLTWH(
      bounds.left - 8 / widget.controller.transform.scale,
      bounds.top - 48 / widget.controller.transform.scale,
      bounds.width + 16 / widget.controller.transform.scale,
      40 / widget.controller.transform.scale,
    );

    if (toolbarRect.contains(worldPoint) ||
        bounds
            .inflate(14 / widget.controller.transform.scale)
            .contains(worldPoint)) {
      return true;
    }

    canvasController.endShapeLabelEditing();
    return false;
  }

  Rect _shapeLabelEditingBounds(Object? element) {
    final bounds = switch (element) {
      DrawioShapeElement e => e.labelPadding.deflateRect(e.rect),
      RectElement e => e.labelPadding.deflateRect(e.rect),
      EllipseElement e => e.labelPadding.deflateRect(e.rect),
      LineElement e => LineLabelPainter.labelBounds(
        points: [e.start, e.end],
        label: e.label?.isEmpty ?? true ? ' ' : e.label,
        style: e.labelStyle,
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
        labelBackground: e.labelBackground,
      ),
      ArrowElement e => LineLabelPainter.labelBounds(
        points: [e.start, e.end],
        label: e.label?.isEmpty ?? true ? ' ' : e.label,
        style: e.labelStyle,
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
        labelBackground: e.labelBackground,
      ),
      PolylineElement e => LineLabelPainter.labelBounds(
        points: e.points,
        label: e.label?.isEmpty ?? true ? ' ' : e.label,
        style: e.labelStyle,
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
        labelBackground: e.labelBackground,
      ),
      _ => Rect.zero,
    };
    if (!bounds.isEmpty) {
      return bounds;
    }
    final center = switch (element) {
      LineElement e => LineLabelPainter.labelCenter(
        [e.start, e.end],
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
      ),
      ArrowElement e => LineLabelPainter.labelCenter(
        [e.start, e.end],
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
      ),
      PolylineElement e => LineLabelPainter.labelCenter(
        e.points,
        labelPosition: e.labelPosition,
        labelOffset: e.labelOffset,
      ),
      _ => Offset.zero,
    };
    return Rect.fromCenter(center: center, width: 80, height: 24);
  }

  _EditingTextResizeHandle? _editingResizeHandleAt(
    TextElement element,
    Offset worldPoint,
  ) {
    final tolerance = 10 / widget.controller.transform.scale;
    for (final handle in _EditingTextResizeHandle.values) {
      if ((worldPoint - handle.pointFor(element.bounds)).distance <=
          tolerance) {
        return handle;
      }
    }
    return null;
  }

  bool _handleEditingResizeMove(PointerMoveEvent event) {
    if (_editingResizePointer != event.pointer) {
      return false;
    }
    final before = _editingResizeBefore;
    final handle = _editingResizeHandle;
    final anchor = _editingResizeAnchor;
    if (before == null || handle == null || anchor == null) {
      return true;
    }

    final worldPoint = widget.controller.screenToWorld(event.localPosition);
    final rect = _constrainedResizeRect(anchor, worldPoint, handle);
    final element = widget.controller.canvasController.elementById(before.id);
    if (element is TextElement) {
      widget.controller.canvasController.updateElement(
        before.id,
        element.copyWith(
          position: rect.topLeft,
          maxWidth: rect.width,
          boxSize: rect.size,
        ),
        record: false,
      );
    }
    return true;
  }

  bool _handleEditingResizeEnd(PointerEvent event) {
    if (_editingResizePointer != event.pointer) {
      return false;
    }
    final before = _editingResizeBefore;
    final after = before == null
        ? null
        : widget.controller.canvasController.elementById(before.id);
    if (before != null &&
        after is TextElement &&
        (before.position != after.position ||
            before.boxSize != after.boxSize)) {
      widget.controller.canvasController.recordCommand(
        UpdateElementCommand(
          before: before,
          after: after,
          description: 'Resize text',
        ),
      );
    }
    _editingResizePointer = null;
    _editingResizeBefore = null;
    _editingResizeHandle = null;
    _editingResizeAnchor = null;
    return true;
  }

  Rect _constrainedResizeRect(
    Offset anchor,
    Offset worldPoint,
    _EditingTextResizeHandle handle,
  ) {
    final rawRect = Rect.fromPoints(anchor, worldPoint);
    var left = rawRect.left;
    var top = rawRect.top;
    var right = rawRect.right;
    var bottom = rawRect.bottom;
    const minWidth = 24.0;
    const minHeight = 24.0;

    if (rawRect.width < minWidth) {
      if (handle.isLeft) {
        left = right - minWidth;
      } else {
        right = left + minWidth;
      }
    }
    if (rawRect.height < minHeight) {
      if (handle.isTop) {
        top = bottom - minHeight;
      } else {
        bottom = top + minHeight;
      }
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _dispatchDoubleTapIfNeeded(PointerDownEvent event) {
    final previousPosition = _lastTapPosition;
    final previousTime = _lastTapTime;
    final now = DateTime.now();
    _lastTapPosition = event.localPosition;
    _lastTapTime = now;

    if (previousPosition == null || previousTime == null) {
      return false;
    }
    if (now.difference(previousTime) > const Duration(milliseconds: 350)) {
      return false;
    }
    if ((event.localPosition - previousPosition).distance > 8) {
      return false;
    }

    _dispatch(
      CanvasDoubleTapEvent(
        screenPoint: event.localPosition,
        worldPoint: widget.controller.screenToWorld(event.localPosition),
        transform: widget.controller.transform,
        pointerCount: _pointers.length + 1,
      ),
    );
    return widget.controller.canvasController.editingTextElementId != null;
  }

  bool _shouldDeferToWidget(Offset screenPoint) {
    final canvasController = widget.controller.canvasController;
    if (canvasController.currentTool?.id != SelectTool.idValue) {
      return false;
    }

    final worldPoint = widget.controller.screenToWorld(screenPoint);
    final hit = canvasController.hitTest(worldPoint);
    return hit is CanvasWidgetElement &&
        !hit.isLocked &&
        hit.interactive &&
        hit.hitTest(worldPoint);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_handleEditingResizeMove(event)) {
      return;
    }
    if (_widgetGesturePointers.contains(event.pointer)) {
      if (!_promoteDeferredWidgetGestureIfNeeded(event)) {
        return;
      }
    }
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }

    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length > 1) {
      _handlePinchPanZoom();
      return;
    }

    if (_toolSuppressedUntilClear) {
      return;
    }

    final shouldPan =
        widget.controller.canvasController.currentTool?.id == PanTool.idValue ||
        event.buttons == kMiddleMouseButton ||
        event.buttons == kSecondaryMouseButton;
    if (shouldPan) {
      widget.controller.pan(event.delta);
      return;
    }

    _dispatch(
      CanvasPointerMoveEvent(
        screenPoint: event.localPosition,
        worldPoint: widget.controller.screenToWorld(event.localPosition),
        transform: widget.controller.transform,
        delta: event.delta,
        pointerCount: _pointers.length,
        pointer: event.pointer,
        kind: event.kind,
        buttons: event.buttons,
        pressure: event.pressure,
      ),
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_handleEditingResizeEnd(event)) {
      return;
    }
    _deferredWidgetGestures.remove(event.pointer);
    if (_widgetGesturePointers.remove(event.pointer)) {
      return;
    }

    final shouldDispatch = _pointers.length == 1 && !_toolSuppressedUntilClear;
    if (shouldDispatch) {
      _dispatch(
        CanvasPointerUpEvent(
          screenPoint: event.localPosition,
          worldPoint: widget.controller.screenToWorld(event.localPosition),
          transform: widget.controller.transform,
          pointerCount: _pointers.length,
          pointer: event.pointer,
          kind: event.kind,
        ),
      );
    }

    _pointers.remove(event.pointer);
    _resetPinchIfNeeded();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_handleEditingResizeEnd(event)) {
      return;
    }
    _deferredWidgetGestures.remove(event.pointer);
    if (_widgetGesturePointers.remove(event.pointer)) {
      return;
    }

    _pointers.remove(event.pointer);
    widget.controller.canvasController.cancelCurrentInteraction();
    _resetPinchIfNeeded();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final factor = math.exp(
      -event.scrollDelta.dy * widget.config.scrollZoomSensitivity,
    );
    widget.controller.zoomBy(factor, focalPoint: event.localPosition);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final canvasController = widget.controller.canvasController;
    if (canvasController.editingTextElementId != null ||
        canvasController.editingShapeLabelElementId != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (canvasController.editingTextElementId != null) {
          canvasController.endTextEditing(removeIfEmpty: false);
        } else {
          canvasController.endShapeLabelEditing();
        }
      }
      return;
    }
    final key = event.logicalKey;
    final controlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (controlPressed && key == LogicalKeyboardKey.keyZ) {
      canvasController.undo();
      return;
    }
    if (controlPressed && key == LogicalKeyboardKey.keyY) {
      canvasController.redo();
      return;
    }
    if (controlPressed && key == LogicalKeyboardKey.keyA) {
      canvasController.setSelection({
        for (final element in canvasController.elements) element.id,
      });
      return;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      canvasController.removeSelected();
    }
  }

  bool _promoteDeferredWidgetGestureIfNeeded(PointerMoveEvent event) {
    final deferred = _deferredWidgetGestures[event.pointer];
    if (deferred == null) {
      _widgetGesturePointers.remove(event.pointer);
      return true;
    }

    if ((event.localPosition - deferred.screenPoint).distance < 4) {
      return false;
    }

    _deferredWidgetGestures.remove(event.pointer);
    _widgetGesturePointers.remove(event.pointer);
    _pointers[event.pointer] = deferred.screenPoint;
    _toolSuppressedUntilClear = false;

    _dispatch(
      CanvasPointerDownEvent(
        screenPoint: deferred.screenPoint,
        worldPoint: widget.controller.screenToWorld(deferred.screenPoint),
        transform: widget.controller.transform,
        pointerCount: _pointers.length,
        pointer: event.pointer,
        kind: deferred.kind,
        buttons: deferred.buttons,
        pressure: deferred.pressure,
      ),
    );
    return true;
  }

  void _handlePinchPanZoom() {
    final centroid = _centroid();
    final distance = _averageDistanceTo(centroid);
    final previousCentroid = _lastPinchCentroid;
    final previousDistance = _lastPinchDistance;

    if (previousCentroid != null) {
      widget.controller.pan(centroid - previousCentroid);
    }

    if (previousDistance != null && previousDistance > 0 && distance > 0) {
      widget.controller.zoomBy(
        distance / previousDistance,
        focalPoint: centroid,
      );
    }

    _lastPinchCentroid = centroid;
    _lastPinchDistance = distance;
  }

  void _updatePinchBaseline() {
    if (_pointers.length < 2) {
      _lastPinchCentroid = null;
      _lastPinchDistance = null;
      return;
    }
    final centroid = _centroid();
    _lastPinchCentroid = centroid;
    _lastPinchDistance = _averageDistanceTo(centroid);
  }

  void _resetPinchIfNeeded() {
    if (_pointers.isEmpty) {
      _toolSuppressedUntilClear = false;
      _lastPinchCentroid = null;
      _lastPinchDistance = null;
      return;
    }
    _updatePinchBaseline();
  }

  Offset _centroid() {
    final sum = _pointers.values.fold<Offset>(
      Offset.zero,
      (previous, point) => previous + point,
    );
    return sum / _pointers.length.toDouble();
  }

  double _averageDistanceTo(Offset point) {
    if (_pointers.isEmpty) {
      return 0;
    }
    final distance = _pointers.values.fold<double>(
      0,
      (previous, value) => previous + (value - point).distance,
    );
    return distance / _pointers.length;
  }

  void _dispatch(CanvasEvent event) {
    widget.controller.canvasController.dispatchCanvasEvent(event);
  }
}

class _TextEditingOverlay extends StatefulWidget {
  const _TextEditingOverlay({super.key, required this.controller});

  final InfiniteCanvasController controller;

  @override
  State<_TextEditingOverlay> createState() => _TextEditingOverlayState();
}

class _TextEditingOverlayState extends State<_TextEditingOverlay> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode(debugLabel: 'TextEditingOverlay');
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasController = widget.controller.canvasController;
    final editingId = canvasController.editingTextElementId;
    final editingShapeId = canvasController.editingShapeLabelElementId;
    final element = editingId == null
        ? null
        : canvasController.elementById(editingId);
    final shapeLabelElement = editingShapeId == null
        ? null
        : canvasController.elementById(editingShapeId);
    if (element is! TextElement &&
        !ShapeLabelEditingTarget.canEdit(shapeLabelElement)) {
      _editingId = null;
      return const SizedBox.shrink();
    }

    final target = element is TextElement
        ? TextEditingTarget(canvasController, element)
        : ShapeLabelEditingTarget(canvasController, shapeLabelElement!);

    if (_editingId != target.id) {
      _editingId = target.id;
      _textController.text = target.text;
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }

    final transform = widget.controller.transform;
    final textRect = Rect.fromPoints(
      transform.worldToScreen(target.bounds.topLeft),
      transform.worldToScreen(target.bounds.bottomRight),
    );
    const toolbarWidth = 320.0;
    final toolbarLeft = (textRect.width - toolbarWidth) / 2;
    final rect = Rect.fromLTWH(
      textRect.left + toolbarLeft,
      textRect.top - 48,
      toolbarWidth,
      textRect.height + 48,
    );
    final fontSize = target.fontSize * transform.scale;
    final lineHeight = target.lineHeight;
    final contentPadding = 4.0 * transform.scale;
    const handleSize = 7.0;
    final textLeft = -toolbarLeft;
    const textTop = 48.0;
    final handleCenters = [
      Offset(textLeft, textTop),
      Offset(textLeft + textRect.width, textTop),
      Offset(textLeft, textTop + textRect.height),
      Offset(textLeft + textRect.width, textTop + textRect.height),
    ];
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: toolbarWidth,
            height: 40,
            child: _TextEditToolbar(
              controller: widget.controller,
              element: target,
              onInteraction: () => _focusNode.requestFocus(),
            ),
          ),
          Positioned(
            left: textLeft,
            top: textTop,
            width: textRect.width,
            height: textRect.height,
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlign: target.textAlign,
                style: target.style.copyWith(
                  fontSize: fontSize,
                  height: lineHeight,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.82),
                  contentPadding: EdgeInsets.all(contentPadding),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _commit(),
                onChanged: target.updateText,
              ),
            ),
          ),
          for (final center in handleCenters)
            Positioned(
              left: center.dx - handleSize / 2,
              top: center.dy - handleSize / 2,
              width: handleSize,
              height: handleSize,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF2563EB)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _commit() {
    final canvasController = widget.controller.canvasController;
    if (canvasController.editingTextElementId != null) {
      canvasController.endTextEditing(
        text: _textController.text,
        removeIfEmpty: false,
      );
    } else if (canvasController.editingShapeLabelElementId != null) {
      canvasController.endShapeLabelEditing(text: _textController.text);
    }
  }
}

abstract class _TextEditingTarget {
  String get id;
  String get text;
  Rect get bounds;
  TextStyle get style;
  TextAlign get textAlign;
  double get fontSize;
  double get lineHeight;
  void updateText(String text);
  void updateStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    double? lineHeight,
    Object? fontFamily,
  });
}

class TextEditingTarget implements _TextEditingTarget {
  TextEditingTarget(this.controller, this.element);

  final CanvasController controller;
  final TextElement element;

  @override
  String get id => element.id;
  @override
  String get text => element.text;
  @override
  Rect get bounds => element.bounds;
  @override
  TextStyle get style => element.style;
  @override
  TextAlign get textAlign => element.textAlign;
  @override
  double get fontSize => element.style.fontSize ?? 24;
  @override
  double get lineHeight => element.style.height ?? 1.2;

  @override
  void updateText(String text) {
    controller.updateEditingText(text);
  }

  @override
  void updateStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    double? lineHeight,
    Object? fontFamily,
  }) {
    controller.updateTextElementStyle(
      id,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textAlign: textAlign,
      lineHeight: lineHeight,
      fontFamily: fontFamily ?? CanvasController.unsetTextStyleValue,
      record: false,
    );
  }
}

class ShapeLabelEditingTarget implements _TextEditingTarget {
  ShapeLabelEditingTarget(this.controller, this.element);

  final CanvasController controller;
  final Object element;

  static bool canEdit(Object? element) {
    return element is DrawioShapeElement ||
        element is RectElement ||
        element is EllipseElement ||
        element is LineElement ||
        element is ArrowElement ||
        element is PolylineElement;
  }

  @override
  String get id => switch (element) {
    DrawioShapeElement e => e.id,
    RectElement e => e.id,
    EllipseElement e => e.id,
    LineElement e => e.id,
    ArrowElement e => e.id,
    PolylineElement e => e.id,
    _ => '',
  };

  @override
  String get text => switch (element) {
    DrawioShapeElement e => e.label ?? '',
    RectElement e => e.label ?? '',
    EllipseElement e => e.label ?? '',
    LineElement e => e.label ?? '',
    ArrowElement e => e.label ?? '',
    PolylineElement e => e.label ?? '',
    _ => '',
  };

  @override
  Rect get bounds => switch (element) {
    DrawioShapeElement e => e.labelPadding.deflateRect(e.rect),
    RectElement e => e.labelPadding.deflateRect(e.rect),
    EllipseElement e => e.labelPadding.deflateRect(e.rect),
    LineElement e => _lineLabelBounds(
      [e.start, e.end],
      e.label,
      e.labelStyle,
      e.labelPosition,
      e.labelOffset,
      e.labelBackground,
    ),
    ArrowElement e => _lineLabelBounds(
      [e.start, e.end],
      e.label,
      e.labelStyle,
      e.labelPosition,
      e.labelOffset,
      e.labelBackground,
    ),
    PolylineElement e => _lineLabelBounds(
      e.points,
      e.label,
      e.labelStyle,
      e.labelPosition,
      e.labelOffset,
      e.labelBackground,
    ),
    _ => Rect.zero,
  };

  Rect _lineLabelBounds(
    List<Offset> points,
    String? label,
    TextStyle style,
    double labelPosition,
    Offset labelOffset,
    Color? labelBackground,
  ) {
    final bounds = LineLabelPainter.labelBounds(
      points: points,
      label: label?.isEmpty ?? true ? ' ' : label,
      style: style,
      labelPosition: labelPosition,
      labelOffset: labelOffset,
      labelBackground: labelBackground,
    );
    if (!bounds.isEmpty) {
      return bounds;
    }
    final center = LineLabelPainter.labelCenter(
      points,
      labelPosition: labelPosition,
      labelOffset: labelOffset,
    );
    return Rect.fromCenter(center: center, width: 80, height: 24);
  }

  @override
  TextStyle get style => switch (element) {
    DrawioShapeElement e => e.labelStyle,
    RectElement e => e.labelStyle,
    EllipseElement e => e.labelStyle,
    LineElement e => e.labelStyle,
    ArrowElement e => e.labelStyle,
    PolylineElement e => e.labelStyle,
    _ => ShapeLabelPainter.defaultStyle,
  };

  @override
  TextAlign get textAlign => switch (element) {
    DrawioShapeElement e => e.labelAlign,
    RectElement e => e.labelAlign,
    EllipseElement e => e.labelAlign,
    _ => TextAlign.center,
  };

  @override
  double get fontSize => style.fontSize ?? 14;

  @override
  double get lineHeight => style.height ?? 1.2;

  @override
  void updateText(String text) {
    controller.updateEditingShapeLabel(text);
  }

  @override
  void updateStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    double? lineHeight,
    Object? fontFamily,
  }) {
    controller.updateShapeLabelStyle(
      id,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textAlign: textAlign,
      lineHeight: lineHeight,
      fontFamily: fontFamily ?? CanvasController.unsetTextStyleValue,
      record: false,
    );
  }
}

class _TextEditToolbar extends StatelessWidget {
  const _TextEditToolbar({
    required this.controller,
    required this.element,
    required this.onInteraction,
  });

  final InfiniteCanvasController controller;
  final _TextEditingTarget element;
  final VoidCallback onInteraction;

  static const _defaultColors = <Color>[
    Colors.black,
    Colors.white,
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
  ];

  static const _colors = <Color>[
    Colors.black,
    Colors.white,
    Color(0xFF6B7280),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF22C55E),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
    Color(0xFF0EA5E9),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFA855F7),
    Color(0xFFD946EF),
    Color(0xFFEC4899),
    Color(0xFFF43F5E),
  ];

  static const _fontSizes = <double>[14, 18, 24, 32, 48];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in _defaultColors)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkResponse(
                    radius: 13,
                    onTap: () => _update(color: color),
                    child: _ColorDot(
                      color: color,
                      selected: (element.style.color ?? Colors.black) == color,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Custom color',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.palette_outlined, size: 20),
                onPressed: () => _showColorPicker(context),
              ),
              const VerticalDivider(width: 10),
              DropdownButton<double>(
                value: _nearestFontSize(element.style.fontSize ?? 24),
                underline: const SizedBox.shrink(),
                items: [
                  for (final size in _fontSizes)
                    DropdownMenuItem(
                      value: size,
                      child: Text(size.round().toString()),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(fontSize: value);
                  }
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _fontFamilyValue(element.style.fontFamily),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'sans', child: Text('Sans')),
                  DropdownMenuItem(value: 'serif', child: Text('Serif')),
                  DropdownMenuItem(value: 'mono', child: Text('Mono')),
                ],
                onChanged: (value) => _update(
                  fontFamily: switch (value) {
                    'serif' => 'Times New Roman',
                    'mono' => 'Consolas',
                    _ => null,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fontFamilyValue(String? fontFamily) {
    return switch (fontFamily) {
      'Times New Roman' => 'serif',
      'Consolas' => 'mono',
      _ => 'sans',
    };
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: element.style.color ?? Colors.black,
        swatches: _colors,
      ),
    );
    if (color != null) {
      _update(color: color);
    } else {
      onInteraction();
    }
  }

  double _nearestFontSize(double size) {
    return _fontSizes.reduce((previous, current) {
      return (current - size).abs() < (previous - size).abs()
          ? current
          : previous;
    });
  }

  void _update({Color? color, double? fontSize, String? fontFamily}) {
    element.updateStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    onInteraction();
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: const SizedBox.square(dimension: 22),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initialColor,
    required this.swatches,
  });

  final Color initialColor;
  final List<Color> swatches;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _hexFor(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text color'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in widget.swatches)
                  InkResponse(
                    radius: 14,
                    onTap: () => _setColor(color),
                    child: _ColorDot(color: color, selected: color == _color),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _RgbSpectrumPicker(
              hue: _hue,
              saturation: _saturation,
              value: _value,
              onChanged: _setSpectrumColor,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ColorDot(color: _color, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      isDense: true,
                    ),
                    onChanged: _setHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _setColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setSpectrumColor(double hue, double saturation, double value) {
    setState(() {
      _hue = hue;
      _saturation = saturation;
      _value = value;
      _hexController.text = _hexFor(_color);
    });
  }

  void _setHex(String value) {
    final color = _parseHex(value);
    if (color != null) {
      _setColor(color);
    }
  }

  static String _hexFor(Color color) {
    return (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
  }

  static Color? _parseHex(String value) {
    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class _RgbSpectrumPicker extends StatelessWidget {
  const _RgbSpectrumPicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;
  final double saturation;
  final double value;
  final void Function(double hue, double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RGB spectrum', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        GestureDetector(
          onPanDown: (details) => _pickSv(details.localPosition),
          onPanUpdate: (details) => _pickSv(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 150,
            child: CustomPaint(
              painter: _RgbSpectrumPainter(hue: hue),
              foregroundPainter: _SpectrumThumbPainter(
                x: saturation,
                y: 1 - value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onPanDown: (details) => _pickHue(details.localPosition),
          onPanUpdate: (details) => _pickHue(details.localPosition),
          child: SizedBox(
            width: 240,
            height: 18,
            child: CustomPaint(
              painter: const _HueBarPainter(),
              foregroundPainter: _HueThumbPainter(hue: hue),
            ),
          ),
        ),
      ],
    );
  }

  void _pickSv(Offset localPosition) {
    final nextSaturation = (localPosition.dx / 240).clamp(0.0, 1.0).toDouble();
    final nextValue = (1 - localPosition.dy / 150).clamp(0.0, 1.0).toDouble();
    onChanged(hue, nextSaturation, nextValue);
  }

  void _pickHue(Offset localPosition) {
    final nextHue = (localPosition.dx / 240 * 360).clamp(0.0, 360.0).toDouble();
    onChanged(nextHue, saturation, value);
  }
}

class _RgbSpectrumPainter extends CustomPainter {
  const _RgbSpectrumPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant _RgbSpectrumPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class _SpectrumThumbPainter extends CustomPainter {
  const _SpectrumThumbPainter({required this.x, required this.y});

  final double x;
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(x * size.width, y * size.height);
    canvas
      ..drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      )
      ..drawCircle(
        center,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black,
      );
  }

  @override
  bool shouldRepaint(covariant _SpectrumThumbPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

class _HueBarPainter extends CustomPainter {
  const _HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF9CA3AF),
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter oldDelegate) => false;
}

class _HueThumbPainter extends CustomPainter {
  const _HueThumbPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final x = hue / 360 * size.width;
    final rect = Rect.fromCenter(
      center: Offset(x, size.height / 2),
      width: 6,
      height: size.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HueThumbPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

enum _EditingTextResizeHandle {
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

class _DeferredWidgetGesture {
  const _DeferredWidgetGesture({
    required this.screenPoint,
    required this.kind,
    required this.buttons,
    required this.pressure,
  });

  final Offset screenPoint;
  final PointerDeviceKind kind;
  final int buttons;
  final double pressure;
}
