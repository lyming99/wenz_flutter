import 'dart:ui' show Canvas, Size;

import '../canvas/paint_style.dart';
import '../elements/path_element.dart';
import '../elements/path_point.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';
import '../utils/path_simplifier.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

/// 荧光笔工具。
///
/// 和 [PenTool] 类似，但默认宽度更大、透明度更低，模拟荧光笔效果。
class HighlighterTool extends CanvasTool {
  final BrushSettings Function() getBrushSettings;

  bool _isDrawing = false;
  List<PathPoint> _points = [];
  PathElement? _previewElement;

  final PathElementRenderer _renderer = PathElementRenderer();

  HighlighterTool({required this.getBrushSettings});

  @override
  String get id => 'highlighter';

  @override
  String get name => '荧光笔';

  @override
  String get iconName => 'highlight';

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
        style: _highlighterStyle(),
        opacity: 0.3,
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
        style: _highlighterStyle(),
        opacity: 0.3,
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

  /// 构建荧光笔样式：宽度更大，透明度更低。
  PaintStyle _highlighterStyle() {
    final settings = getBrushSettings();
    return settings.toPaintStyle().copyWith(
          strokeWidth: 16.0,
          opacity: 0.3,
        );
  }

  void _reset() {
    _isDrawing = false;
    _points = [];
    _previewElement = null;
  }
}
