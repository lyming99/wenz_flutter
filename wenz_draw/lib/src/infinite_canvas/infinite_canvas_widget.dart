import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../elements/canvas_element.dart';
import '../gestures/canvas_gesture_handler.dart';
import '../gestures/gesture_resolver.dart';
import '../tools/canvas_tool.dart';
import 'canvas_event.dart';
import 'infinite_canvas_controller.dart';
import 'infinite_canvas_painter.dart';

/// 无限画布 Widget。
///
/// 使用方式：
/// ```dart
/// final controller = InfiniteCanvasController();
/// InfiniteCanvasWidget(
///   controller: controller,
///   config: const InfiniteCanvasConfig(),
/// )
/// ```
class InfiniteCanvasWidget extends StatefulWidget {
  /// 视图变换控制器
  final InfiniteCanvasController controller;

  /// 画布配置
  final InfiniteCanvasConfig config;

  const InfiniteCanvasWidget({
    super.key,
    required this.controller,
    this.config = const InfiniteCanvasConfig(),
  });

  @override
  State<InfiniteCanvasWidget> createState() => _InfiniteCanvasWidgetState();
}

class _InfiniteCanvasWidgetState extends State<InfiniteCanvasWidget>
    with SingleTickerProviderStateMixin {
  late CanvasGestureHandler _gestureHandler;
  late GestureResolver _gestureResolver;

  /// 用于接收 ScaleGestureRecognizer 的手势
  late final ScaleGestureRecognizer _scaleRecognizer;

  /// 双指缩放是否激活
  bool _isScaling = false;

  /// 当前工具预览元素
  CanvasElement? _previewElement;

  /// 上一次指针位置（用于计算 delta）
  Offset _lastScreenPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _gestureResolver = GestureResolver();
    _gestureHandler = CanvasGestureHandler(
      controller: widget.controller,
      resolver: _gestureResolver,
    );

    _scaleRecognizer = ScaleGestureRecognizer()
      ..onStart = _handleScaleStart
      ..onUpdate = _handleScaleUpdate
      ..onEnd = _handleScaleEnd;

    // 监听画布控制器变更（元素增删等）
    widget.controller.canvasController.addListener(_onCanvasChanged);
    widget.controller.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCanvasChanged);
    widget.controller.canvasController.removeListener(_onCanvasChanged);
    _scaleRecognizer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InfiniteCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCanvasChanged);
      oldWidget.controller.canvasController.removeListener(_onCanvasChanged);
      widget.controller.addListener(_onCanvasChanged);
      widget.controller.canvasController.addListener(_onCanvasChanged);
      _gestureHandler = CanvasGestureHandler(
        controller: widget.controller,
        resolver: _gestureResolver,
      );
    }
  }

  void _onCanvasChanged() {
    setState(() {});
  }

  // ─── 工具事件分发 ─────────────────────────────────────────

  /// 将 PointerEvent 转为 CanvasEvent 并分发到当前工具。
  ToolResult _dispatchToTool(CanvasEvent canvasEvent) {
    final tool = widget.controller.canvasController.currentTool;
    if (tool == null) return const ToolResultNone();

    final result = tool.handleEvent(canvasEvent);

    // 处理结果
    switch (result) {
      case ToolResultPreview(:final preview):
        setState(() {
          _previewElement = preview;
        });
      case ToolResultElement(:final element):
        widget.controller.canvasController.addElement(element);
        setState(() {
          _previewElement = null;
        });
      case ToolResultNone():
        break;
      case ToolResultConsumed():
        break;
      case ToolResultSelect():
        break;
    }

    return result;
  }

  // ─── 手势回调 ─────────────────────────────────────────────

  void _handleScaleStart(ScaleStartDetails details) {
    _isScaling = true;
    _gestureHandler.handleScaleStart(details.focalPoint);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      _gestureHandler.handleScaleUpdate(details.scale, details.focalPoint);
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isScaling = false;
    if (details.velocity.pixelsPerSecond.distanceSquared > 100) {
      widget.controller.startFling(details.velocity.pixelsPerSecond * 0.016);
    }
  }

  // ─── 指针事件 ─────────────────────────────────────────────

  void _handlePointerDown(PointerDownEvent event) {
    _lastScreenPoint = event.position;
    _gestureHandler.handlePointerDown(event);
    _scaleRecognizer.addPointer(event);

    // 分发到工具
    final canvasEvent = CanvasPointerDownEvent(
      screenPoint: event.position,
      worldPoint: widget.controller.screenToWorld(event.position),
      transform: widget.controller.transform,
    );
    _dispatchToTool(canvasEvent);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isScaling) return;

    final delta = event.position - _lastScreenPoint;
    _lastScreenPoint = event.position;

    // 先分发到工具
    final canvasEvent = CanvasPointerMoveEvent(
      screenPoint: event.position,
      worldPoint: widget.controller.screenToWorld(event.position),
      transform: widget.controller.transform,
      delta: delta,
      worldDelta: Offset(delta.dx, delta.dy) / widget.controller.transform.scale,
    );
    final result = _dispatchToTool(canvasEvent);

    // 如果工具没有消费事件，交给手势处理器（画布平移）
    if (result is ToolResultNone) {
      _gestureHandler.handlePointerMove(event);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _gestureHandler.handlePointerUp(event);

    // 分发到工具
    final canvasEvent = CanvasPointerUpEvent(
      screenPoint: event.position,
      worldPoint: widget.controller.screenToWorld(event.position),
      transform: widget.controller.transform,
    );
    _dispatchToTool(canvasEvent);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _gestureHandler.handlePointerUp(
      PointerUpEvent(
        pointer: event.pointer,
        position: event.position,
      ),
    );

    // 清除预览
    setState(() {
      _previewElement = null;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _gestureHandler.handleScroll(event);
    }
  }

  // ─── 键盘事件 ─────────────────────────────────────────────

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return; // 只处理 KeyDown

    final ctrl = widget.controller.canvasController;

    // 空格 → 临时平移
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _gestureResolver.setSpacePressed(true);
      return;
    }

    // Ctrl+Z → undo
    if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      ctrl.undo();
      return;
    }

    // Ctrl+Y / Ctrl+Shift+Z → redo
    if ((event.logicalKey == LogicalKeyboardKey.keyY ||
            event.logicalKey == LogicalKeyboardKey.keyZ) &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) &&
        HardwareKeyboard.instance.isShiftPressed) {
      ctrl.redo();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      ctrl.redo();
      return;
    }

    // Delete / Backspace → 删除选中
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      ctrl.deleteSelected();
      setState(() {});
      return;
    }

    // Ctrl+A → 全选
    if (event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      ctrl.selectAll();
      setState(() {});
      return;
    }

    // Escape → 取消选择
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      ctrl.deselectAll();
      setState(() {});
      return;
    }
  }

  // 处理 KeyUp 事件（空格释放）
  void _handleKeyUp(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _gestureResolver.setSpacePressed(false);
    }
  }

  // ─── 构建 ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          _handleKeyEvent(event);
        } else if (event is KeyUpEvent) {
          _handleKeyUp(event);
        }
      },
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerSignal: _handlePointerSignal,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            // 延迟注入视口尺寸，避免在 build 中触发 setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.controller.updateViewportSize(size);
            });

            return RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: InfiniteCanvasPainter(
                  controller: widget.controller,
                  previewElement: _previewElement,
                  config: widget.config,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
