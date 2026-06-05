import '../elements/text_element.dart';
import '../infinite_canvas/canvas_event.dart';
import 'brush_settings.dart';
import 'canvas_tool.dart';

/// 文本工具。
///
/// 点击位置直接创建默认文本元素。
class TextTool extends CanvasTool {
  final BrushSettings Function() getBrushSettings;

  TextTool({required this.getBrushSettings});

  @override
  String get id => 'text';

  @override
  String get name => '文本';

  @override
  String get iconName => 'text_fields';

  @override
  ToolResult handleEvent(CanvasEvent event) {
    if (event is CanvasPointerDownEvent) {
      final settings = getBrushSettings();
      final element = TextElement.create(
        position: event.worldPoint,
        text: '文本',
        fontSize: 16.0,
        color: settings.color.toARGB32(),
      );
      return ToolResultElement(element);
    }

    return const ToolResultNone();
  }
}
