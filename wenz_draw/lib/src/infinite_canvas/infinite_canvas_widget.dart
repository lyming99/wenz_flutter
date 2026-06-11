import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../elements/widget_element.dart';
import '../tools/pan_tool.dart';
import '../tools/select_tool.dart';
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

  Offset? _lastPinchCentroid;
  double? _lastPinchDistance;
  bool _toolSuppressedUntilClear = false;

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
                    child: CanvasWidgetLayer(
                      controller: widget.controller,
                      config: widget.config,
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

    _dispatch(
      CanvasPointerDownEvent(
        screenPoint: event.localPosition,
        worldPoint: widget.controller.screenToWorld(event.localPosition),
        transform: widget.controller.transform,
        pointerCount: _pointers.length,
        pointer: event.pointer,
        kind: event.kind,
        buttons: event.buttons,
        pressure: event.pressure,
      ),
    );
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
