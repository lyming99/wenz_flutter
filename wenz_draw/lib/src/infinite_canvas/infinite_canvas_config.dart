import 'package:flutter/material.dart';

enum GridType { lines, dots, none }

@immutable
class InfiniteCanvasConfig {
  const InfiniteCanvasConfig({
    this.showGrid = true,
    this.gridType = GridType.dots,
    this.backgroundColor = Colors.white,
    this.gridColor = const Color(0xFFE1E5EA),
    this.majorGridColor = const Color(0xFFC8CED8),
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.scrollZoomSensitivity = 0.0015,
    this.gridBaseSize = 50.0,
    this.enablePinch = true,
    this.enableWheelZoom = true,
    this.enableKeyboard = true,
    this.enableDoubleTapZoom = true,
    this.doubleTapZoomFactor = 2.0,
    this.flingEnabled = true,
    this.flingDecayFriction = 0.005,
  });

  final bool showGrid;
  final GridType gridType;
  final Color backgroundColor;
  final Color gridColor;
  final Color majorGridColor;
  final double minScale;
  final double maxScale;
  final double scrollZoomSensitivity;
  final double gridBaseSize;

  /// Whether two-finger pinch-to-zoom is handled by the canvas. When `false`,
  /// multi-pointer gestures are ignored (a single finger still drives the
  /// active tool). Disable on platforms where the host wants full control.
  final bool enablePinch;

  /// Whether mouse/trackpad wheel zoom is handled. When `false`, wheel events
  /// pass through (useful when the canvas is embedded in a scrollable parent).
  final bool enableWheelZoom;

  /// Whether canvas-level keyboard shortcuts (undo/redo, select-all, arrow
  /// nudge, delete, copy/paste/duplicate/group) are handled. Disable when the
  /// host wants to own keyboard input, e.g. inside a text field.
  final bool enableKeyboard;

  /// Whether double-tap zooms in (and shift/alt double-tap zooms out). When
  /// `false`, double-tap is only used for entering text editing.
  final bool enableDoubleTapZoom;

  /// Scale factor applied on a double-tap zoom-in.
  final double doubleTapZoomFactor;

  /// Whether a released pan continues with inertial fling (mobile feel). When
  /// `false`, panning stops the instant the pointer lifts (desktop feel).
  final bool flingEnabled;

  /// Friction coefficient for the fling decay. Higher = stops sooner. The
  /// default (0.005) gives a natural, slightly-resistive feel on touch.
  final double flingDecayFriction;
}
