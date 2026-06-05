import 'dart:ui' show Canvas, Size;

import '../elements/path_element.dart';
import '../elements/path_point.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';
import '../utils/path_simplifier.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

/// 自由画笔工具。
///
/// 按下拖动绘制自由路径，松手后通过 [PathSimplifier] 简化路径并提交。
class PenTool extends CanvasTool {
  final BrushSettings Function() getBrushSettings;

  bool _isDrawing = false;
  List<PathPoint> _points = [];
  PathElement? _previewElement;

  final PathElementRenderer _renderer = PathElementRenderer();

  PenTool({required this.getBrushSettings});

  @override
  String get id => 'pen';

  @override
  String get name => '画笔';

  @override
  String get iconName => 'edit';

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
      _isDrawing = true;
      _points = [
        PathPoint(position: event.worldPoint),
      ];
      _previewElement = null;
      return const ToolResultConsumed();
    }

    if (event is CanvasPointerMoveEvent && _isDrawing) {
      _points.add(PathPoint(position: event.worldPoint));
      _previewElement = PathElement.create(
        points: _points,
        style: getBrushSettings().toPaintStyle(),
        opacity: 0.7,
      );
      return ToolResultPreview(_previewElement!);
    }

    if (event is CanvasPointerUpEvent && _isDrawing) {
      _isDrawing = false;

      if (_points.length < 2) {
        _previewElement = null;
        return const ToolResultNone();
      }

      // 简化路径
      final simplified = PathSimplifier.simplify(_points, epsilon: 2.0);
      final element = PathElement.create(
        points: simplified,
        style: getBrushSettings().toPaintStyle(),
      );

      _previewElement = null;
      _points = [];
      return ToolResultElement(element);
    }

    return const ToolResultNone();
  }

  @override
  void paintPreview(Canvas canvas, Size size, CanvasTransform transform) {
    if (_previewElement != null) {
      _renderer.render(canvas, _previewElement!);
    }
  }

  void _reset() {
    _isDrawing = false;
    _points = [];
    _previewElement = null;
  }
}
