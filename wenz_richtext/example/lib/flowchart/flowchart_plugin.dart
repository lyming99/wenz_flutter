import 'package:wenz_richtext/wenz_richtext.dart';

import 'flowchart_model.dart';
import 'flowchart_view.dart';

/// Reusable flowchart integration packaged as a [WenzRichTextPlugin].
///
/// [install] registers the `flowchart` block embed renderer, the `/流程图`
/// slash-menu item, and the toolbar descriptor in one step, reusing the
/// builders/descriptors from `flowchart_view.dart`. A host gains the complete
/// flowchart surface — renderer + slash entry + toolbar item — by adding
/// `FlowchartPlugin()` to [WenzEditorConfiguration.plugins], with no edits to
/// its own configuration maps. This is the reusable-plugin path, contrasted
/// with the one-off config-injection path (`blockEmbedRenderers` /
/// `slashMenuItems` / `toolbarItems`).
///
/// Node-drag write-back goes through
/// `WenzPluginContext.controller.updateBlockEmbed`, so history, change
/// callbacks, and the permission gate behave identically to the config-injection
/// path.
///
/// Merge order (see `WenzEditorBootstrap.create`): defaults → plugins → host
/// configuration. The contributions installed here are therefore overridden by
/// a host that registers the same [kFlowchartEmbedType] / slash id / toolbar id
/// in its own configuration maps, and they override the built-in defaults
/// themselves.
class FlowchartPlugin extends WenzRichTextPlugin {
  const FlowchartPlugin();

  @override
  String get id => 'wenz.example.flowchart';

  /// Reference implementation that lives in the example app, not the core
  /// package, so its integration contract is not stabilized.
  @override
  WenzPluginApiStatus get apiStatus => WenzPluginApiStatus.experimental;

  @override
  void install(WenzPluginContext context) {
    context.registerBlockEmbedRenderer(
      kFlowchartEmbedType,
      flowchartRendererBuilder(
        onWriteBack: (blockId, data) => context.controller.updateBlockEmbed(
          blockId: blockId,
          data: data,
        ),
      ),
    );
    context.registerSlashMenuItem(flowchartSlashMenuItem());
    context.registerToolbarItem(flowchartToolbarItem());
  }
}
