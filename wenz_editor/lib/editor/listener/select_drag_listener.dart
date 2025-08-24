import 'package:flutter/material.dart';

/// 选择拖动事件，通知select drag更新，需要屏蔽上层的滚动，而优先拖拽滚动
class SelectDragListener extends StatelessWidget {
  final VoidCallback? onStatusChanged;
  final Widget child;

  const SelectDragListener({
    super.key,
    this.onStatusChanged,
    required this.child,
  });

  static void emitChange(BuildContext context) {
    context.visitAncestorElements((element) {
      if (element.widget.runtimeType == SelectDragListener) {
        (element.widget as SelectDragListener).onStatusChanged?.call();
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
