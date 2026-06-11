import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../elements/line_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../snap/snap_resolver.dart';
import '../utils/uuid_generator.dart';
import 'canvas_tool.dart';

class LineTool extends CanvasTool {
  LineTool();

  static const idValue = 'line';

  Offset? _start;
  Offset? _current;
  SnapResult? _startSnap;
  SnapResult? _currentSnap;

  @override
  String get id => idValue;

  @override
  String get name => 'Line';

  @override
  IconData get icon => Icons.show_chart;

  @override
  void cancel(CanvasController controller) {
    _start = null;
    _current = null;
    _startSnap = null;
    _currentSnap = null;
    controller.setSnapPreview(null);
  }

  @override
  ToolResult handleEvent(CanvasEvent event, CanvasController controller) {
    switch (event) {
      case CanvasPointerDownEvent():
        _startSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        _start = _startSnap?.position ?? event.worldPoint;
        _currentSnap = _startSnap;
        _current = _start;
        controller.setSnapPreview(_currentSnap);
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerMoveEvent():
        if (_start == null) {
          return const ToolResultNone();
        }
        _currentSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        _current = _currentSnap?.position ?? event.worldPoint;
        controller.setSnapPreview(_currentSnap);
        return ToolResultPreview(_buildPreview(controller));
      case CanvasPointerUpEvent():
        final start = _start;
        final endSnap = _resolveSnap(
          controller,
          event.worldPoint,
          event.transform.scale,
        );
        final end = endSnap?.position ?? event.worldPoint;
        final startBinding = _startSnap?.binding;
        final endBinding = endSnap?.binding;
        _start = null;
        _current = null;
        _startSnap = null;
        _currentSnap = null;
        controller.setSnapPreview(null);
        if (start == null || (start - end).distance < 1) {
          return const ToolResultNone();
        }
        return ToolResultElement(
          LineElement(
            id: UuidGenerator.create(),
            start: start,
            end: end,
            style: controller.brushSettings.strokeStyle,
            startBinding: startBinding,
            endBinding: endBinding,
          ),
        );
      default:
        return const ToolResultNone();
    }
  }

  LineElement _buildPreview(CanvasController controller) {
    final start = _start ?? Offset.zero;
    return LineElement(
      id: '__preview_line__',
      start: start,
      end: _current ?? start,
      style: controller.brushSettings.strokeStyle.copyWith(opacity: 0.72),
    );
  }

  SnapResult? _resolveSnap(
    CanvasController controller,
    Offset worldPoint,
    double scale,
  ) {
    return controller.snapResolver.resolve(
      controller,
      worldPoint,
      scale: scale,
    );
  }
}
