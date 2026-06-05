import 'dart:ui' show Canvas, Offset, Size;

import '../elements/arrow_element.dart';
import '../infinite_canvas/canvas_event.dart';
import '../infinite_canvas/canvas_transform.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

/// 箭头工具。
///
/// 按下记录起点，拖动预览箭头，松手提交最终箭头元素。
class ArrowTool extends CanvasTool {
  final BrushSettings Function() getBrushSettings;

  bool _isDrawing = false;
  Offset? _startPoint;
  ArrowElement? _previewElement;

  final ArrowElementRenderer _renderer = ArrowElementRenderer();

  ArrowTool({required this.getBrushSettings});

  @override
  String get id => 'arrow';

  @override
  String get name => '箭头';

  @override
  String get iconName => 'arrow_forward';

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
      _previewElement = ArrowElement.create(
        start: _startPoint!,
        end: event.worldPoint,
        style: getBrushSettings().toPaintStyle(),
        opacity: 0.7,
      );
      return ToolResultPreview(_previewElement!);
    }

    if (event is CanvasPointerUpEvent && _isDrawing && _startPoint != null) {
      _isDrawing = false;

      final start = _startPoint!;
      final end = event.worldPoint;

      _previewElement = null;
      _startPoint = null;

      // 起点终点重合则忽略
      if ((start - end).distance < 1.0) {
        return const ToolResultNone();
      }

      final element = ArrowElement.create(
        start: start,
        end: end,
        style: getBrushSettings().toPaintStyle(),
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

  void _reset() {
    _isDrawing = false;
    _startPoint = null;
    _previewElement = null;
  }
}
