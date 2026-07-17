/// Optional mind map module for the wenz_draw infinite canvas SDK.
///
/// Import this barrel (not the internal `src/mindmap/` files) to use mind maps.
/// Register the module once during app init:
///
/// ```dart
/// import 'package:wenz_draw/wenz_draw.dart';
/// import 'package:wenz_draw/wenz_draw_mindmap.dart';
///
/// void main() {
///   registerMindmapModule(linkOpener: myLinkOpener);
///   runApp(const MyApp());
/// }
/// ```
///
/// The mind map module builds on the SDK's standard extension points
/// (`CanvasWidgetElement` + `WidgetElementBuilder`), so it adds no new kernel
/// surface — hosts that do not need mind maps simply never call
/// [registerMindmapModule].
library wenz_draw_mindmap;

export 'src/mindmap/mindmap_actions.dart';
export 'src/mindmap/mindmap_connection_layer.dart';
export 'src/mindmap/mindmap_drag_session.dart';
export 'src/mindmap/mindmap_layout_engine.dart';
export 'src/mindmap/mindmap_link_opener.dart';
export 'src/mindmap/mindmap_module.dart';
export 'src/mindmap/mindmap_node.dart';
export 'src/mindmap/mindmap_node_builder.dart';
export 'src/mindmap/mindmap_node_data.dart';
export 'src/mindmap/mindmap_node_metrics.dart';
export 'src/mindmap/mindmap_sync_controller.dart';
export 'src/mindmap/mindmap_theme.dart';
export 'src/mindmap/mindmap_tree.dart';
