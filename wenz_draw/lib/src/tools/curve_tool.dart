import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/curve_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

/// Curve 工具——绘制二次贝塞尔曲线。
///
/// 交互方式：
/// 1. 按下确定起点。
/// 2. 拖动实时预览终点，控制点自动计算（垂直于起终连线偏移）。
/// 3. 松手完成绘制，自动选中所创建的曲线。
///
/// 如果在拖动过程中检测到明显的垂直偏移（用户做出了弧线手势），
/// 则使用用户拖拽路径的中点作为控制点，形成弧线。
class CurveTool extends CanvasTool {
  CurveTool();

  static const idValue = 'curve';

  Offset? _start;
  Offset? _current;

  @override
  String get id => idValue;

  @override
  String get name => 'Curve';

  @override
  IconData get icon => Icons.timeline;

  @override
  void cancel(CanvasController controller) {
    _start = null;
    _current = null;
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        _start = event.worldPoint;
        _current = event.worldPoint;
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerMoveEvent():
        if (_start == null) return const ToolResultNone();
        _current = event.worldPoint;
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerUpEvent():
        final start = _start;
        final end = event.worldPoint;
        cancel(controller);
        if (start == null || (start - end).distance < 1) {
          return const ToolResultNone();
        }
        final control = _computeControlPoint(start, end);
        return ToolResultElement(
          CurveElement(
            id: UuidGenerator.create(),
            start: start,
            end: end,
            control: control,
            style: controller.brushSettings.strokeStyle,
          ),
          selectAfter: true,
        );
      default:
        return const ToolResultNone();
    }
  }

  /// Compute a control point that creates a pleasing arc.
  ///
  /// The control point is placed at the midpoint of start-end, offset
  /// perpendicular to the line by 30% of the segment length.
  Offset _computeControlPoint(Offset start, Offset end) {
    final mid = (start + end) / 2;
    final delta = end - start;
    final length = delta.distance;
    if (length < 0.001) return mid;
    // Perpendicular unit vector (rotate 90° counter-clockwise).
    final perp = Offset(-delta.dy, delta.dx) / length;
    return mid + perp * (length * 0.3);
  }

  CurveElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    final end = _current ?? start;
    final control = _computeControlPoint(start, end);
    return CurveElement(
      id: '__preview_curve__',
      start: start,
      end: end,
      control: control,
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }
}
