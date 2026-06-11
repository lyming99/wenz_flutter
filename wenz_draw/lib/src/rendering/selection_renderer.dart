import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/arrow_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
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
      _drawSnapPreview(canvas, controller, transform);
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
      if (controller.editingTextElementId == element.id ||
          controller.editingShapeLabelElementId == element.id) {
        continue;
      }
      final bounds = element.bounds.inflate(4 / transform.scale);
      canvas.drawRect(bounds, paint);
      final handlePoints = switch (element) {
        LineElement e => [e.start, e.end],
        PolylineElement e => e.points,
        ArrowElement e => [e.start, e.end],
        _ => [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomLeft,
          bounds.bottomRight,
        ],
      };
      for (final point in handlePoints) {
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
    _drawSnapPreview(canvas, controller, transform);
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

  void _drawSnapPreview(
    Canvas canvas,
    CanvasController controller,
    CanvasTransform transform,
  ) {
    final snap = controller.snapPreview;
    if (snap == null) {
      return;
    }
    final point = snap.position;
    final radius = 5 / transform.scale;
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / transform.scale;
    final fillPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final guidePaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / transform.scale;

    canvas.drawCircle(point, radius * 1.8, fillPaint);
    canvas.drawCircle(point, radius, paint);
    canvas.drawLine(
      point - Offset(radius * 2.4, 0),
      point + Offset(radius * 2.4, 0),
      guidePaint,
    );
    canvas.drawLine(
      point - Offset(0, radius * 2.4),
      point + Offset(0, radius * 2.4),
      guidePaint,
    );
  }
}
