import 'package:flutter/material.dart';

class PopupWindow {
  String id;
  String title;
  Widget child;
  double width;
  double height;
  bool isVisible;
  Offset position;
  VoidCallback? onOpen;

  PopupWindow({
    required this.id,
    required this.title,
    required this.child,
    this.width = 800,
    this.height = 600,
    this.isVisible = false,
    this.position = const Offset(100, 100),
    this.onOpen,
  });
}

/// Enum to represent resize directions
class ResizeDirection {
  final bool isLeft;
  final bool isRight;
  final bool isTop;
  final bool isBottom;

  const ResizeDirection({
    this.isLeft = false,
    this.isRight = false,
    this.isTop = false,
    this.isBottom = false,
  });

  // Predefined directions
  static const ResizeDirection left = ResizeDirection(isLeft: true);
  static const ResizeDirection right = ResizeDirection(isRight: true);
  static const ResizeDirection top = ResizeDirection(isTop: true);
  static const ResizeDirection bottom = ResizeDirection(isBottom: true);
  static const ResizeDirection topLeft =
      ResizeDirection(isTop: true, isLeft: true);
  static const ResizeDirection topRight =
      ResizeDirection(isTop: true, isRight: true);
  static const ResizeDirection bottomLeft =
      ResizeDirection(isBottom: true, isLeft: true);
  static const ResizeDirection bottomRight =
      ResizeDirection(isBottom: true, isRight: true);
}

class MultiWindowPopupController with ChangeNotifier {
  final Map<String, PopupWindow> _windows = {};
  String? _activeWindowId;

  List<PopupWindow> get windows => _windows.values.toList();

  String? get activeWindowId => _activeWindowId;
  bool isShowFloatButton = true;

  void toggleFloatButton() {
    isShowFloatButton = !isShowFloatButton;
    notifyListeners();
  }

  void showFloatButton() {
    isShowFloatButton = true;
    notifyListeners();
  }

  void hideFloatButton() {
    isShowFloatButton = false;
    notifyListeners();
  }

  void registerWindow({
    required String id,
    required String title,
    required Widget child,
    Offset? position,
    double width = 800,
    double height = 600,
    Size? screenSize,
    VoidCallback? onOpen,
  }) {
    if (_windows.containsKey(id)) return;
    // Calculate center position if screen size is provided
    if (position == null) {
      if (screenSize != null) {
        position = Offset(
          (screenSize.width - width) / 2,
          (screenSize.height - height) / 2,
        );

        // Add slight offset for cascading effect if there are other windows
        final offset = _windows.length * 30.0;
        position = position.translate(offset, offset);
      } else {
        // Fallback to default cascading position
        final offset = _windows.length * 30.0;
        position = Offset(100 + offset, 100 + offset);
      }
    }
    _windows[id] = PopupWindow(
      id: id,
      title: title,
      child: child,
      width: width,
      height: height,
      position: position,
      onOpen: onOpen,
    );
    notifyListeners();
  }

  void unregisterWindow(String id) {
    _windows.remove(id);
    if (_activeWindowId == id) {
      _activeWindowId = null;
    }
    notifyListeners();
  }

  void showWindow(String id) {
    final window = _windows[id];
    if (window == null) return;

    window.isVisible = true;
    _activeWindowId = id;
    notifyListeners();
  }

  void hideWindow(String id) {
    final window = _windows[id];
    if (window == null) return;

    window.isVisible = false;
    if (_activeWindowId == id) {
      _activeWindowId =
          _windows.values.where((w) => w.isVisible).lastOrNull?.id;
    }
    notifyListeners();
  }

  void bringToFront(String id) {
    if (_windows.containsKey(id)) {
      _activeWindowId = id;
      notifyListeners();
    }
  }

  void updateWindowPosition(String id, Offset newPosition, Size screenSize) {
    final window = _windows[id];
    if (window == null) return;

    // 确保窗口不会超出屏幕边界
    double x = newPosition.dx.clamp(0, screenSize.width - window.width);
    double y = newPosition.dy.clamp(0, screenSize.height - window.height);

    window.position = Offset(x, y);
    notifyListeners();
  }

  /// Update window size by resizing from a specific edge or corner
  void resizeWindow(
      String id, Offset delta, ResizeDirection direction, Size screenSize) {
    final window = _windows[id];
    if (window == null) return;

    // Minimum window size constraints
    const double minWidth = 200.0;
    const double minHeight = 150.0;

    double newWidth = window.width;
    double newHeight = window.height;
    Offset newPosition = window.position;

    // Handle horizontal resizing
    if (direction.isLeft) {
      // Resize from left edge
      final double maxDeltaX = window.width - minWidth;
      final double clampedDeltaX = delta.dx.clamp(-double.infinity, maxDeltaX);
      newWidth = window.width - clampedDeltaX;
      newPosition =
          Offset(window.position.dx + clampedDeltaX, window.position.dy);
    } else if (direction.isRight) {
      // Resize from right edge
      final double maxWidth = screenSize.width - window.position.dx;
      newWidth = (window.width + delta.dx).clamp(minWidth, maxWidth);
    }

    // Handle vertical resizing
    if (direction.isTop) {
      // Resize from top edge
      final double maxDeltaY = window.height - minHeight;
      final double clampedDeltaY = delta.dy.clamp(-double.infinity, maxDeltaY);
      newHeight = window.height - clampedDeltaY;
      newPosition = Offset(newPosition.dx, window.position.dy + clampedDeltaY);
    } else if (direction.isBottom) {
      // Resize from bottom edge
      final double maxHeight = screenSize.height - window.position.dy;
      newHeight = (window.height + delta.dy).clamp(minHeight, maxHeight);
    }

    // Update window properties
    window.width = newWidth;
    window.height = newHeight;
    window.position = newPosition;

    notifyListeners();
  }

  void hideAll() {
    for (final window in _windows.values) {
      window.isVisible = false;
    }
    _activeWindowId = null;
    notifyListeners();
  }

  void updateTitle(String windowId, String title) {
    final window = _windows[windowId];
    if (window != null) {
      window.title = title;
      notifyListeners();
    }
  }

  void updateOpenButton(String windowId, VoidCallback? onOpen) {
    final window = _windows[windowId];
    if (window != null) {
      window.onOpen = onOpen;
      notifyListeners();
    }
  }
}
