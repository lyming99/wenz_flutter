import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'canvas_transform.dart';

sealed class CanvasEvent {
  const CanvasEvent({
    required this.screenPoint,
    required this.worldPoint,
    required this.transform,
    this.pointerCount = 1,
  });

  final Offset screenPoint;
  final Offset worldPoint;
  final CanvasTransform transform;
  final int pointerCount;
}

class CanvasPointerDownEvent extends CanvasEvent {
  const CanvasPointerDownEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
    this.pointer,
    this.kind,
    this.buttons = 0,
    this.pressure = 0.5,
  });

  final int? pointer;
  final PointerDeviceKind? kind;
  final int buttons;
  final double pressure;
}

class CanvasPointerMoveEvent extends CanvasEvent {
  const CanvasPointerMoveEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    required this.delta,
    super.pointerCount,
    this.pointer,
    this.kind,
    this.buttons = 0,
    this.pressure = 0.5,
  });

  final Offset delta;
  final int? pointer;
  final PointerDeviceKind? kind;
  final int buttons;
  final double pressure;
}

class CanvasPointerUpEvent extends CanvasEvent {
  const CanvasPointerUpEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
    this.pointer,
    this.kind,
  });

  final int? pointer;
  final PointerDeviceKind? kind;
}

class CanvasDoubleTapEvent extends CanvasEvent {
  const CanvasDoubleTapEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
  });
}

class CanvasLongPressEvent extends CanvasEvent {
  const CanvasLongPressEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    super.pointerCount,
  });
}

class CanvasScrollEvent extends CanvasEvent {
  const CanvasScrollEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    required this.scrollDelta,
    super.pointerCount,
  });

  final Offset scrollDelta;
}

class CanvasKeyEvent extends CanvasEvent {
  const CanvasKeyEvent({
    required super.screenPoint,
    required super.worldPoint,
    required super.transform,
    required this.key,
    required this.isKeyDown,
    super.pointerCount,
  });

  final LogicalKeyboardKey key;
  final bool isKeyDown;
}
