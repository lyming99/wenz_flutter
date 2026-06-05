import 'package:flutter/gestures.dart';

/// 手势类型
enum GestureType {
  /// 鼠标滚轮缩放
  wheelZoom,

  /// 双指缩放+平移
  pinchZoomPan,

  /// 空格+拖拽临时平移
  temporaryPan,

  /// 交给当前工具处理
  tool,
}

/// 手势冲突解决器。
///
/// 根据当前输入状态（按键、指针数量等）判断应该执行哪种手势操作。
class GestureResolver {
  bool _isSpacePressed = false;
  final Set<int> _activePointers = {};

  /// 空格键是否按下
  bool get isSpacePressed => _isSpacePressed;

  /// 当前活跃指针数量
  int get pointerCount => _activePointers.length;

  /// 设置空格键状态
  void setSpacePressed(bool pressed) {
    _isSpacePressed = pressed;
  }

  /// 添加活跃指针
  void addPointer(int pointerId) {
    _activePointers.add(pointerId);
  }

  /// 移除活跃指针
  void removePointer(int pointerId) {
    _activePointers.remove(pointerId);
  }

  /// 清除所有活跃指针
  void clearPointers() {
    _activePointers.clear();
  }

  /// 根据当前输入状态判断手势类型。
  ///
  /// 优先级：
  /// 1. 双指 → 缩放+平移
  /// 2. 空格+拖拽 → 临时平移
  /// 3. 交给当前工具
  GestureType resolve(PointerEvent event) {
    // 双指 → 缩放+平移
    if (_activePointers.length >= 2) {
      return GestureType.pinchZoomPan;
    }
    // 空格+拖拽 → 临时平移
    if (_isSpacePressed && event is PointerMoveEvent) {
      return GestureType.temporaryPan;
    }
    // 交给当前工具
    return GestureType.tool;
  }

  /// 判断滚轮事件是否应触发缩放。
  ///
  /// 滚轮事件始终触发缩放。
  GestureType resolveScroll(PointerScrollEvent event) {
    return GestureType.wheelZoom;
  }

  /// 重置所有状态
  void reset() {
    _isSpacePressed = false;
    _activePointers.clear();
  }
}
