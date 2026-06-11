import 'package:flutter/material.dart';

import '../canvas/paint_style.dart';
import '../canvas/canvas_controller.dart';
import '../elements/path_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../utils/path_simplifier.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class HighlighterTool extends CanvasTool {
  HighlighterTool();

  static const idValue = 'highlighter';

  final List<PathPoint> _points = [];

  @override
  String get id => idValue;

  @override
  String get name => 'Highlighter';

  @override
  IconData get icon => Icons.brush_outlined;

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
            PathPoint(position: event.worldPoint, pressure: event.pressure),
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
          PathPoint(position: event.worldPoint, pressure: event.pressure),
        );
        return ToolResultPreview(_preview(controller));
      case CanvasPointerUpEvent():
        if (_points.length < 2) {
          cancel(controller);
          return const ToolResultPreview(null);
        }
        final simplified = PathSimplifier.simplify([
          for (final point in _points) point.position,
        ], tolerance: 0.8);
        final element = PathElement(
          id: UuidGenerator.create(),
          points: [for (final point in simplified) PathPoint(position: point)],
          style: _style(controller),
        );
        cancel(controller);
        return ToolResultElement(element);
      default:
        return const ToolResultNone();
    }
  }

  PathElement _preview(CanvasController controller) {
    return PathElement(
      id: '__preview_highlighter__',
      points: _points,
      style: _style(controller).copyWith(opacity: 0.25),
    );
  }

  PaintStyle _style(CanvasController controller) {
    return controller.brushSettings.strokeStyle.copyWith(
      strokeWidth: controller.brushSettings.strokeWidth * 3,
      opacity: 0.35,
    );
  }
}
