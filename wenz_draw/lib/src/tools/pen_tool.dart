import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/path_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/path_simplifier.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class PenTool extends CanvasTool {
  PenTool();

  static const idValue = 'pen';

  final List<PathPoint> _points = [];

  @override
  String get id => idValue;

  @override
  String get name => 'Pen';

  @override
  IconData get icon => Icons.edit;

  @override
  void cancel(CanvasController controller) {
    _points.clear();
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        _points
          ..clear()
          ..add(
            PathPoint(
              position: event.worldPoint,
              pressure: event.pressure,
              timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
            ),
          );
        return ToolResultPreview(_preview(controller));
      case CanvasPointerMoveEvent():
        if (_points.isEmpty) {
          return const ToolResultNone();
        }
        if ((_points.last.position - event.worldPoint).distance < 0.5) {
          return const ToolResultConsumed();
        }
        _points.add(
          PathPoint(
            position: event.worldPoint,
            pressure: event.pressure,
            timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
          ),
        );
        return ToolResultPreview(_preview(controller));
      case CanvasPointerUpEvent():
        if (_points.length < 2) {
          _points.clear();
          return const ToolResultPreview(null);
        }
        final simplified = PathSimplifier.simplify([
          for (final point in _points) point.position,
        ], tolerance: 0.8);
        final pressureByIndex = _points.isEmpty ? 0.5 : _points.last.pressure;
        final element = PathElement(
          id: UuidGenerator.create(),
          points: [
            for (final point in simplified)
              PathPoint(position: point, pressure: pressureByIndex),
          ],
          style: controller.brushSettings.strokeStyle,
        );
        _points.clear();
        return ToolResultElement(element, selectAfter: false);
      default:
        return const ToolResultNone();
    }
  }

  PathElement _preview(CanvasController controller) {
    return PathElement(
      id: '__preview_path__',
      points: _points,
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }
}
