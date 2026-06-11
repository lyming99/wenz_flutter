import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../infinite_canvas/canvas_transform.dart';

class SelectionRenderer {
  const SelectionRenderer();

  void render(
    Canvas canvas,
    CanvasController controller,
    CanvasTransform transform,
  ) {
    if (controller.selectedIds.isEmpty) {
      _drawSelectionRect(canvas, controller, transform);
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / transform.scale;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / transform.scale;
    final handleSize = 7 / transform.scale;

    for (final element in controller.elements) {
      if (!controller.selectedIds.contains(element.id)) {
        continue;
      }
      if (controller.editingTextElementId == element.id) {
        continue;
      }
      final bounds = element.bounds.inflate(4 / transform.scale);
      canvas.drawRect(bounds, paint);
      for (final point in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ]) {
        final handle = Rect.fromCenter(
          center: point,
          width: handleSize,
          height: handleSize,
        );
        canvas.drawRect(handle, handlePaint);
        canvas.drawRect(handle, handleBorderPaint);
      }
    }
    _drawSelectionRect(canvas, controller, transform);
  }

  void _drawSelectionRect(
    Canvas canvas,
    CanvasController controller,
    CanvasTransform transform,
  ) {
    final rect = controller.selectionRect;
    if (rect == null || rect.isEmpty) {
      return;
    }
    final fillPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / transform.scale;
    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }
}
