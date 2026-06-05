import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/canvas_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';
import 'canvas_tool.dart';

/// 选择工具状态
enum _SelectState {
  idle,
  dragging,
  boxSelecting,
}

/// 选择工具。
///
/// 支持：
/// - 点击选中元素
/// - 拖拽移动选中元素
/// - 框选多个元素
/// - Shift+点击追加选择
class SelectTool extends CanvasTool {
  /// 获取 CanvasController 的回调
  final CanvasController Function() getController;

  _SelectState _state = _SelectState.idle;

  /// 拖拽起始世界坐标
  Offset _dragStartWorld = Offset.zero;

  /// 框选起始世界坐标
  Offset _boxSelectStart = Offset.zero;

  /// 框选当前世界坐标
  Offset _boxSelectCurrent = Offset.zero;

  /// 拖拽中各元素的起始位置
  final Map<String, Offset> _dragStartPositions = {};

  /// 是否在拖拽中
  bool get isDragging => _state == _SelectState.dragging;

  /// 是否在框选中
  bool get isBoxSelecting => _state == _SelectState.boxSelecting;

  /// 获取框选矩形（世界坐标）
  Rect get boxSelectRect {
    final left = math.min(_boxSelectStart.dx, _boxSelectCurrent.dx);
    final top = math.min(_boxSelectStart.dy, _boxSelectCurrent.dy);
    final right = math.max(_boxSelectStart.dx, _boxSelectCurrent.dx);
    final bottom = math.max(_boxSelectStart.dy, _boxSelectCurrent.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  SelectTool({required this.getController});

  @override
  String get id => 'select';

  @override
  String get name => '选择';

  @override
  String get iconName => 'near_me';

  @override
  void onDeactivate() {
    _resetState();
  }

  void _resetState() {
    _state = _SelectState.idle;
    _dragStartPositions.clear();
  }

  @override
  ToolResult handleEvent(CanvasEvent event) {
    final controller = getController();

    switch (event) {
      case CanvasPointerDownEvent():
        return _handlePointerDown(event, controller);
      case CanvasPointerMoveEvent():
        return _handlePointerMove(event, controller);
      case CanvasPointerUpEvent():
        return _handlePointerUp(event, controller);
      default:
        return const ToolResultNone();
    }
  }

  ToolResult _handlePointerDown(CanvasPointerDownEvent event, CanvasController controller) {
    final worldPoint = event.worldPoint;
    final hitElement = _hitTestElements(worldPoint, controller.elements);

    if (hitElement != null) {
      // 点击到元素
      final isAddToSelection = event.pointerCount == 1; // 可通过 Shift 追加
      if (!controller.selectionManager.isSelected(hitElement.id)) {
        controller.select(hitElement.id, addToSelection: false);
      }

      // 开始拖拽
      _state = _SelectState.dragging;
      _dragStartWorld = worldPoint;

      // 记录所有选中元素的当前位置
      for (final elem in controller.selectedElements) {
        _dragStartPositions[elem.id] = Offset(elem.bounds.left, elem.bounds.top);
      }

      return const ToolResultConsumed();
    } else {
      // 点击空白区域 → 开始框选
      _state = _SelectState.boxSelecting;
      _boxSelectStart = worldPoint;
      _boxSelectCurrent = worldPoint;
      controller.deselectAll();
      return const ToolResultConsumed();
    }
  }

  ToolResult _handlePointerMove(CanvasPointerMoveEvent event, CanvasController controller) {
    switch (_state) {
      case _SelectState.dragging:
        // 移动选中元素
        final delta = event.worldPoint - _dragStartWorld;
        if (delta != Offset.zero) {
          for (final elem in controller.selectedElements) {
            final startPos = _dragStartPositions[elem.id];
            if (startPos != null) {
              final translated = elem.translate(delta);
              controller.elementManager.updateElement(elem.id, translated);
            }
          }
        }
        return const ToolResultConsumed();

      case _SelectState.boxSelecting:
        _boxSelectCurrent = event.worldPoint;
        // 实时预览框选区域
        return const ToolResultConsumed();

      case _SelectState.idle:
        return const ToolResultNone();
    }
  }

  ToolResult _handlePointerUp(CanvasPointerUpEvent event, CanvasController controller) {
    switch (_state) {
      case _SelectState.dragging:
        _resetState();
        return const ToolResultConsumed();

      case _SelectState.boxSelecting:
        // 完成框选
        controller.selectInRect(boxSelectRect);
        _resetState();
        return const ToolResultConsumed();

      case _SelectState.idle:
        return const ToolResultNone();
    }
  }

  /// 命中测试：找到最上层被点击的元素。
  ///
  /// 从后往前遍历（zIndex 最大的优先）。
  CanvasElement? _hitTestElements(Offset worldPoint, List<CanvasElement> elements) {
    for (int i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      if (!element.visible) continue;
      if (element.hitTest(worldPoint, tolerance: 8.0)) {
        return element;
      }
    }
    return null;
  }

  @override
  void paintPreview(Canvas canvas, Size size, CanvasTransform transform) {
    if (_state != _SelectState.boxSelecting) return;

    final rect = boxSelectRect;

    // 绘制选择框（蓝色半透明填充 + 蓝色边框）
    final fillPaint = Paint()
      ..color = const Color(0x1A2196F3)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0x802196F3)
      ..strokeWidth = 1.0 / transform.scale
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }
}
