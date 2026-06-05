// wenz_draw — 跨平台 Flutter 高性能无限画布绘图 SDK
//
// 提供类 Excalidraw 风格的无限画布体验，支持无限平移/缩放、
// 多元素绘制、图层管理、撤销重做。
//
// 基本用法：
// ```dart
// final controller = InfiniteCanvasController();
//
// Scaffold(
//   body: InfiniteCanvasWidget(
//     controller: controller,
//     config: const InfiniteCanvasConfig(
//       showGrid: true,
//       gridType: GridType.dots,
//     ),
//   ),
// );
// ```

// === 核心 Widget ===
export 'src/infinite_canvas/infinite_canvas_widget.dart';
export 'src/infinite_canvas/infinite_canvas_painter.dart'
    show InfiniteCanvasConfig;

// === 控制器 ===
export 'src/infinite_canvas/infinite_canvas_controller.dart';
export 'src/canvas/canvas_controller.dart';

// === 变换 ===
export 'src/infinite_canvas/canvas_transform.dart';

// === 事件 ===
export 'src/infinite_canvas/canvas_event.dart';

// === 状态 ===
export 'src/canvas/canvas_state.dart';

// === 选择 ===
export 'src/canvas/selection_manager.dart';

// === 元素 ===
export 'src/elements/canvas_element.dart';
export 'src/elements/path_point.dart';
export 'src/elements/path_element.dart';
export 'src/elements/line_element.dart';
export 'src/elements/rect_element.dart';
export 'src/elements/ellipse_element.dart';
export 'src/elements/arrow_element.dart';
export 'src/elements/text_element.dart';
export 'src/elements/element_renderer.dart';
export 'src/elements/element_registry.dart';

// === 工具 ===
export 'src/tools/canvas_tool.dart';
export 'src/tools/tool_manager.dart';
export 'src/tools/brush_settings.dart';
export 'src/tools/pen_tool.dart';
export 'src/tools/line_tool.dart';
export 'src/tools/rect_tool.dart';
export 'src/tools/ellipse_tool.dart';
export 'src/tools/select_tool.dart';
export 'src/tools/arrow_tool.dart';
export 'src/tools/text_tool.dart';
export 'src/tools/eraser_tool.dart';
export 'src/tools/highlighter_tool.dart';

// === 样式 ===
export 'src/canvas/paint_style.dart';

// === 渲染 ===
export 'src/rendering/grid_renderer.dart' show GridType;
export 'src/rendering/selection_renderer.dart';

// === 手势 ===
export 'src/gestures/gesture_resolver.dart' show GestureType;
export 'src/gestures/inertia_scroll.dart';

// === 序列化 ===
export 'src/serialization/canvas_serializer.dart';
export 'src/serialization/exporters/png_exporter.dart';
export 'src/serialization/exporters/svg_exporter.dart';

// === 小地图 ===
export 'src/infinite_canvas/minimap_widget.dart';

// === 图层 ===
export 'src/layers/canvas_layer.dart';
export 'src/layers/layer_manager.dart';

// === 历史 ===
export 'src/history/canvas_command.dart';
export 'src/history/history_manager.dart';

// === 工具类 ===
export 'src/utils/path_simplifier.dart';
export 'src/utils/quad_tree.dart';

// === 原有平台接口 ===
export 'wenz_draw_platform_interface.dart';

import 'src/elements/element_registry.dart';
import 'src/elements/path_element.dart';
import 'src/elements/line_element.dart';
import 'src/elements/rect_element.dart';
import 'src/elements/ellipse_element.dart';
import 'src/elements/arrow_element.dart';
import 'src/elements/text_element.dart';

/// 注册所有内置元素渲染器。
///
/// 在使用画布前调用一次。通常在 main() 中：
/// ```dart
/// void main() {
///   WenzDraw.registerBuiltinRenderers();
///   runApp(MyApp());
/// }
/// ```
class WenzDraw {
  static void registerBuiltinRenderers() {
    ElementRendererRegistry.register<PathElement>('path', PathElementRenderer());
    ElementRendererRegistry.register<LineElement>('line', LineElementRenderer());
    ElementRendererRegistry.register<RectElement>('rect', RectElementRenderer());
    ElementRendererRegistry.register<EllipseElement>('ellipse', EllipseElementRenderer());
    ElementRendererRegistry.register<ArrowElement>('arrow', ArrowElementRenderer());
    ElementRendererRegistry.register<TextElement>('text', TextElementRenderer());
  }
}
