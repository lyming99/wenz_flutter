import 'dart:math' as math show min, max;
import 'dart:ui' show Canvas, Offset, Rect, Size;

import '../elements/rect_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

/// 矩形工具。
///
/// 按下记录起点，拖动预览矩形，松手提交最终矩形元素。
/// 支持任意方向拖动（自动处理负方向）。
class RectTool extends CanvasTool {
  final BrushSettings Function() getBrushSettings;

  bool _isDrawing = false;
  Offset? _startPoint;
  RectElement? _previewElement;

  final RectElementRenderer _renderer = RectElementRenderer();

  RectTool({required this.getBrushSettings});

  @override
  String get id => 'rect';

  @override
  String get name => '矩形';

  @override
  String get iconName => 'crop_square';

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
      _startPoint = event.worldPoint;
      _previewElement = null;
      return const ToolResultConsumed();
    }

    if (event is CanvasPointerMoveEvent && _isDrawing && _startPoint != null) {
      final rect = _buildRect(_startPoint!, event.worldPoint);
      _previewElement = RectElement.create(
        rect: rect,
        stroke: getBrushSettings().toPaintStyle(),
        opacity: 0.7,
      );
      return ToolResultPreview(_previewElement!);
    }

    if (event is CanvasPointerUpEvent && _isDrawing && _startPoint != null) {
      _isDrawing = false;

      final rect = _buildRect(_startPoint!, event.worldPoint);
      _previewElement = null;
      _startPoint = null;

      // 矩形太小则忽略
      if (rect.width < 1.0 || rect.height < 1.0) {
        return const ToolResultNone();
      }

      final element = RectElement.create(
        rect: rect,
        stroke: getBrushSettings().toPaintStyle(),
      );
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

  /// 从两个对角点构建标准化矩形（处理负方向）。
  Rect _buildRect(Offset p1, Offset p2) {
    return Rect.fromLTRB(
      math.min(p1.dx, p2.dx),
      math.min(p1.dy, p2.dy),
      math.max(p1.dx, p2.dx),
      math.max(p1.dy, p2.dy),
    );
  }

  void _reset() {
    _isDrawing = false;
    _startPoint = null;
    _previewElement = null;
  }
}
