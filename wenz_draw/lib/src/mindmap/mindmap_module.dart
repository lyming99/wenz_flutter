import 'package:wenz_draw/wenz_draw.dart';

import 'mindmap_link_opener.dart';
import 'mindmap_node_builder.dart';
import 'mindmap_tree.dart';

/// Registers the mind map module with the SDK so `CanvasWidgetElement`s with
/// `widgetType == 'mindmap_node'` render and behave correctly.
///
/// Call this once during app initialization, before adding any mind map
/// elements to a canvas:
///
/// ```dart
/// registerMindmapModule(
///   linkOpener: UrlLauncherLinkOpener(), // your implementation
/// );
/// ```
///
/// The module keeps no global canvas state: per-canvas state (layout, drag
/// sessions, theme controller) lives in [MindmapActions], which you obtain via
/// `MindmapActions.attach(controller)` (typically wrapped in a
/// [MindmapSyncController] alongside an [InfiniteCanvasController]).
void registerMindmapModule({MindmapLinkOpener? linkOpener}) {
  if (linkOpener != null) {
    MindmapLinkOpenerHolder.set(linkOpener);
  }
  WidgetElementRegistry.register(
    kMindmapNodeWidgetType,
    const MindmapNodeBuilder(),
  );
}

/// Removes the mind map node builder from the widget registry and resets the
/// link opener. Mainly useful in tests or when a host fully tears the module
/// down.
void unregisterMindmapModule() {
  WidgetElementRegistry.unregister(kMindmapNodeWidgetType);
  MindmapLinkOpenerHolder.reset();
}
