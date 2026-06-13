import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/arrow_element.dart';
import '../elements/curve_element.dart';
import '../elements/drawio_shape_element.dart';
import '../elements/line_element.dart';
import '../elements/polyline_element.dart';
import '../infinite_canvas/canvas_transform.dart';
import '../utils/math_utils.dart';

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
      final selectionGeometry = _selectionGeometryFor(element, transform);
      canvas.drawPath(selectionGeometry.path, paint);
      canvas.drawLine(
        selectionGeometry.topCenter,
        selectionGeometry.rotateHandle,
        paint,
      );
      canvas.drawCircle(
        selectionGeometry.rotateHandle,
        handleSize * 0.62,
        handlePaint,
      );
      canvas.drawCircle(
        selectionGeometry.rotateHandle,
        handleSize * 0.62,
        handleBorderPaint,
      );
      final handlePoints = switch (element) {
        LineElement e => [e.start, e.end],
        CurveElement e => [e.start, e.end, e.control],
        PolylineElement e => e.points,
        ArrowElement e => [e.start, e.end],
        _ => selectionGeometry.corners,
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

  _SelectionGeometry _selectionGeometryFor(
    dynamic element,
    CanvasTransform transform,
  ) {
    final padding = 4 / transform.scale;
    if (element is DrawioShapeElement && element.rotation != 0) {
      final rect = element.rect.inflate(
        padding + element.strokeStyle.strokeWidth / 2,
      );
      final center = element.rect.center;
      final corners = [
        rotatePoint(rect.topLeft, element.rotation, center),
        rotatePoint(rect.topRight, element.rotation, center),
        rotatePoint(rect.bottomRight, element.rotation, center),
        rotatePoint(rect.bottomLeft, element.rotation, center),
      ];
      final topCenter = rotatePoint(
        Offset(rect.center.dx, rect.top),
        element.rotation,
        center,
      );
      final direction = topCenter - center;
      final distance = direction.distance;
      final normal = distance <= 0.0001
          ? const Offset(0, -1)
          : direction / distance;
      return _SelectionGeometry(
        corners: corners,
        topCenter: topCenter,
        rotateHandle: topCenter + normal * (24 / transform.scale),
      );
    }

    final bounds = element.bounds.inflate(padding);
    return _SelectionGeometry(
      corners: [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft,
      ],
      topCenter: Offset(bounds.center.dx, bounds.top),
      rotateHandle: Offset(bounds.center.dx, bounds.top - 24 / transform.scale),
    );
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

class _SelectionGeometry {
  const _SelectionGeometry({
    required this.corners,
    required this.topCenter,
    required this.rotateHandle,
  });

  final List<Offset> corners;
  final Offset topCenter;
  final Offset rotateHandle;

  Path get path {
    return Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();
  }
}
