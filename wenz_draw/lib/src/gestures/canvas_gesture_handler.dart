import 'package:flutter/gestures.dart';

import '../infinite_canvas/canvas_transform.dart';
import '../infinite_canvas/infinite_canvas_controller.dart';
import 'gesture_resolver.dart';

/// 统一画布手势处理器。
///
/// 接收原始 PointerEvent，通过 GestureResolver 判断手势类型，
/// 然后分发到对应的处理逻辑。
class CanvasGestureHandler {
  final InfiniteCanvasController controller;
  final GestureResolver resolver;

  /// 双指缩放的初始 scale
  double _initialPinchScale = 1.0;

  /// 上一次指针位置（用于计算平移增量）
  Offset _lastPointerPosition = Offset.zero;

  /// 是否处于拖拽状态
  bool _isDragging = false;

  CanvasGestureHandler({
    required this.controller,
    GestureResolver? resolver,
  }) : resolver = resolver ?? GestureResolver();

  /// 处理指针按下事件。
  void handlePointerDown(PointerDownEvent event) {
    resolver.addPointer(event.pointer);
    _lastPointerPosition = event.position;

    if (resolver.pointerCount >= 2) {
      // 双指操作开始，记录初始状态
      _isDragging = false;
      controller.cancelFling();
    } else {
      _isDragging = true;
    }
  }

  /// 处理指针移动事件。
  void handlePointerMove(PointerMoveEvent event) {
    final gestureType = resolver.resolve(event);

    switch (gestureType) {
      case GestureType.pinchZoomPan:
        // 双指缩放平移由 handleScaleUpdate 处理
        break;
      case GestureType.temporaryPan:
        // 空格+拖拽 → 临时平移
        final delta = event.position - _lastPointerPosition;
        controller.pan(delta);
        _lastPointerPosition = event.position;
        break;
      case GestureType.tool:
        // 单指拖拽 → 画布平移（Phase 1 默认行为）
        if (_isDragging) {
          final delta = event.position - _lastPointerPosition;
          controller.pan(delta);
          _lastPointerPosition = event.position;
        }
        break;
      case GestureType.wheelZoom:
        // 滚轮缩放由 handleScroll 单独处理
        break;
    }
  }

  /// 处理指针抬起事件。
  void handlePointerUp(PointerUpEvent event) {
    if (_isDragging && resolver.pointerCount == 1) {
      // 单指抬起，不启动惯性（需要速度信息，简化处理）
    }
    resolver.removePointer(event.pointer);
    _isDragging = resolver.pointerCount > 0;
  }

  /// 处理滚轮事件 → 缩放。
  void handleScroll(PointerScrollEvent event) {
    // 滚轮向上 → 放大，向下 → 缩小
    final double scrollDelta = event.scrollDelta.dy;
    if (scrollDelta == 0) return;

    // 使用指数缩放，滚轮每单位对应固定比例
    final double factor = scrollDelta > 0 ? 1.0 / 1.1 : 1.1;
    controller.zoomBy(factor, focalPoint: event.position);
  }

  /// 处理缩放更新（双指缩放）。
  ///
  /// [scale] 是相对于手势开始时的累计缩放比。
  /// [focalPoint] 是双指中点（屏幕坐标）。
  void handleScaleUpdate(double scale, Offset focalPoint) {
    // scale 是累计值（相对于手势开始时的比例）
    final double newScale = (_initialPinchScale * scale)
        .clamp(CanvasTransform.minScale, CanvasTransform.maxScale);

    // 以双指中点为焦点进行缩放
    final worldPoint = controller.screenToWorld(focalPoint);
    final newOffset = Offset(
      focalPoint.dx - worldPoint.dx * newScale,
      focalPoint.dy - worldPoint.dy * newScale,
    );

    // 直接设置 transform（绕过 zoomTo 以保留双指平移）
    controller.setTransform(CanvasTransform(
      scale: newScale,
      offset: newOffset,
    ));
  }

  /// 双指缩放开始。
  void handleScaleStart(Offset focalPoint) {
    _initialPinchScale = controller.transform.scale;
  }

  /// 重置状态。
  void reset() {
    resolver.reset();
    _isDragging = false;
    _lastPointerPosition = Offset.zero;
    _initialPinchScale = 1.0;
  }
}
