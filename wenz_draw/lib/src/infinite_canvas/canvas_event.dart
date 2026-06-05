import 'dart:ui' show Offset, Rect, Size;

import '../infinite_canvas/canvas_transform.dart';

/// 画布事件基类（sealed）。
///
/// 所有工具接收的事件类型。包含屏幕坐标和世界坐标。
sealed class CanvasEvent {
  /// 屏幕坐标
  final Offset screenPoint;

  /// 世界坐标
  final Offset worldPoint;

  /// 当前视图变换
  final CanvasTransform transform;

  /// 当前指针数量
  final int pointerCount;

  const CanvasEvent({
    required this.screenPoint,
    required this.worldPoint,
    required this.transform,
    this.pointerCount = 1,
  });
}

/// 指针按下
class CanvasPointerDownEvent extends CanvasEvent {
  const CanvasPointerDownEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
  });
}

/// 指针移动
class CanvasPointerMoveEvent extends CanvasEvent {
  /// 移动增量（屏幕坐标）
  final Offset delta;

  /// 移动增量（世界坐标）
  final Offset worldDelta;

  const CanvasPointerMoveEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
    this.delta = Offset.zero,
    this.worldDelta = Offset.zero,
  });
}

/// 指针抬起
class CanvasPointerUpEvent extends CanvasEvent {
  const CanvasPointerUpEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
  });
}

/// 双击
class CanvasDoubleTapEvent extends CanvasEvent {
  const CanvasDoubleTapEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
  });
}

/// 长按
class CanvasLongPressEvent extends CanvasEvent {
  const CanvasLongPressEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
  });
}

/// 滚轮事件
class CanvasScrollEvent extends CanvasEvent {
  /// 滚轮偏移
  final Offset scrollDelta;

  const CanvasScrollEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    required this.scrollDelta,
  });
}

/// 键盘事件
class CanvasKeyEvent extends CanvasEvent {
  /// 按键
  final String key;

  /// 是否按下（true=KeyDown, false=KeyUp）
  final bool isKeyDown;

  const CanvasKeyEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    required this.key,
    required this.isKeyDown,
  });
}
