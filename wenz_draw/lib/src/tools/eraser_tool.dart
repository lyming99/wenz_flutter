import 'dart:ui' show Offset;

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../infinite_canvas/canvas_event.dart';
import 'canvas_tool.dart';

/// 橡皮擦工具。
///
/// 按下后拖动，实时检测并移除当前位置附近的元素。
class EraserTool extends CanvasTool {
  final CanvasController Function() getController;

  bool _isErasing = false;

  EraserTool({required this.getController});

  @override
  String get id => 'eraser';

  @override
  String get name => '橡皮擦';

  @override
  String get iconName => 'auto_fix_high';

  @override
  void onActivate() {
    _reset();
  }

  @override
  void onDeactivate() {
    _reset();
  }

  @override
  ToolResult handleEvent(CanvasEvent event) {
    if (event is CanvasPointerDownEvent) {
      _isErasing = true;
      _eraseAt(event.worldPoint);
      return const ToolResultConsumed();
    }

    if (event is CanvasPointerMoveEvent && _isErasing) {
      _eraseAt(event.worldPoint);
      return const ToolResultConsumed();
    }

    if (event is CanvasPointerUpEvent && _isErasing) {
      _isErasing = false;
      return const ToolResultConsumed();
    }

    return const ToolResultNone();
  }

  /// 在指定位置擦除元素。
  void _eraseAt(Offset worldPoint) {
    final controller = getController();
    // 复制列表避免并发修改
    final elements = List<CanvasElement>.from(controller.elements);
    for (final element in elements.reversed) {
      if (!element.visible) continue;
      if (element.hitTest(worldPoint, tolerance: 10.0)) {
        controller.removeElement(element.id);
      }
    }
  }

  void _reset() {
    _isErasing = false;
  }
}
