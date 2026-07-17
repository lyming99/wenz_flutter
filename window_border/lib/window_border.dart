import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/window_border_types.dart';
import 'window_border_platform_interface.dart';

export 'src/window_border_types.dart';

/// Controls the native border and state of the Flutter desktop host window.
class WindowBorder {
  factory WindowBorder() => instance;

  WindowBorder._();

  static final WindowBorder instance = WindowBorder._();

  Future<void> initialize({
    WindowBorderStyle style = const WindowBorderStyle(),
    bool enabled = true,
  }) {
    return WindowBorderPlatform.instance.initialize(style, enabled: enabled);
  }

  Future<void> setEnabled(bool enabled) {
    return WindowBorderPlatform.instance.setEnabled(enabled);
  }

  Future<void> setStyle(WindowBorderStyle style) {
    return WindowBorderPlatform.instance.setStyle(style);
  }

  Future<void> startDragging() {
    return WindowBorderPlatform.instance.startDragging();
  }

  Future<void> startResizing(WindowResizeEdge edge) {
    return WindowBorderPlatform.instance.startResizing(edge);
  }

  Future<void> minimize() => WindowBorderPlatform.instance.minimize();

  Future<void> maximize() => WindowBorderPlatform.instance.maximize();

  Future<void> restore() => WindowBorderPlatform.instance.restore();

  Future<void> toggleMaximize() {
    return WindowBorderPlatform.instance.toggleMaximize();
  }

  Future<void> close() => WindowBorderPlatform.instance.close();

  Future<bool> isMaximized() {
    return WindowBorderPlatform.instance.isMaximized();
  }

  Future<WindowState> getState() {
    return WindowBorderPlatform.instance.getState();
  }

  Stream<WindowState> get stateChanges =>
      WindowBorderPlatform.instance.stateChanges;
}

/// A non-interactive title-bar area that starts a native move operation.
///
/// Place window buttons outside this widget so their gestures remain isolated.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({
    required this.child,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final Widget child;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onPanStart: (_) => unawaited(WindowBorder.instance.startDragging()),
      onDoubleTap: () => unawaited(WindowBorder.instance.toggleMaximize()),
      child: child,
    );
  }
}
