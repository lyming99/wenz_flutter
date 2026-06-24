import '../controller/slash_menu_controller.dart';
import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/command_registry.dart';
import '../core/commands/editor_command.dart';
import '../core/model/block_node.dart';
import '../input/clipboard_service.dart';
import '../widgets/block_renderer_registry.dart';
import '../widgets/inline_embed_renderer.dart';

/// Stability marker for plugin-facing API surface.
enum WenzPluginApiStatus {
  stable,
  stabilising,
  experimental,
}

/// A package or app module that contributes editor behaviour through the
/// supported extension registries.
abstract class WenzRichTextPlugin {
  const WenzRichTextPlugin();

  /// Unique plugin id, usually reverse-domain or package-scoped.
  String get id;

  /// Stability of the plugin's own integration contract.
  WenzPluginApiStatus get apiStatus => WenzPluginApiStatus.stabilising;

  /// Installs commands, renderers, menu items, toolbar items, middleware, or
  /// paste transformers into [context].
  void install(WenzPluginContext context);
}

/// Context passed to [WenzRichTextPlugin.install].
///
/// Core command APIs are always available through [controller]. Widget/input UI
/// registries are optional because a host may choose to render its own toolbar,
/// slash surface, or block widgets.
class WenzPluginContext {
  WenzPluginContext({
    required this.controller,
    this.blockRenderers,
    this.inlineEmbedRenderers,
    this.slashMenuRegistry,
    this.toolbarItems,
    List<ClipboardPasteTransformer>? pasteTransformers,
  }) : pasteTransformers =
            pasteTransformers ?? controller.clipboardService.pasteTransformers;

  final WenzRichTextController controller;
  final BlockRendererRegistry? blockRenderers;
  final InlineEmbedRendererRegistry? inlineEmbedRenderers;
  final SlashMenuRegistry? slashMenuRegistry;
  final WenzToolbarItemRegistry? toolbarItems;

  /// Paste transformers used by [ClipboardService]. Pass a growable list to
  /// [ClipboardService.pasteTransformers] when plugins install after controller
  /// construction.
  final List<ClipboardPasteTransformer> pasteTransformers;

  CommandRegistry get commandRegistry => controller.registry;

  List<CommandMiddleware> get middlewares => controller.middlewares;

  void registerCommand(CommandDescriptor descriptor) {
    commandRegistry.register(descriptor);
  }

  void addMiddleware(CommandMiddleware middleware) {
    middlewares.add(middleware);
  }

  BlockRendererBuilder? registerBlockRenderer(
    BlockType type,
    BlockRendererBuilder builder,
  ) {
    final registry = blockRenderers;
    if (registry == null) {
      throw StateError('No BlockRendererRegistry was provided for plugins.');
    }
    return registry.register(type, builder);
  }

  BlockRendererBuilder? registerBlockEmbedRenderer(
    String embedType,
    BlockRendererBuilder builder,
  ) {
    final registry = blockRenderers;
    if (registry == null) {
      throw StateError('No BlockRendererRegistry was provided for plugins.');
    }
    return registry.registerEmbed(embedType, builder);
  }

  InlineEmbedSpanBuilder? registerInlineEmbedRenderer(
    String embedType,
    InlineEmbedSpanBuilder builder,
  ) {
    final registry = inlineEmbedRenderers;
    if (registry == null) {
      throw StateError(
        'No InlineEmbedRendererRegistry was provided for plugins.',
      );
    }
    return registry.register(embedType, builder);
  }

  void registerSlashMenuItem(SlashMenuItem item) {
    final registry = slashMenuRegistry;
    if (registry == null) {
      throw StateError('No SlashMenuRegistry was provided for plugins.');
    }
    registry.register(item);
  }

  void registerToolbarItem(WenzToolbarItem item) {
    final registry = toolbarItems;
    if (registry == null) {
      throw StateError('No WenzToolbarItemRegistry was provided for plugins.');
    }
    registry.register(item);
  }

  void registerPasteTransformer(ClipboardPasteTransformer transformer) {
    try {
      pasteTransformers.add(transformer);
    } on UnsupportedError catch (error) {
      throw StateError(
        'Clipboard paste transformers are immutable. Pass a growable list to '
        'ClipboardService(pasteTransformers: <ClipboardPasteTransformer>[]). '
        'Original error: $error',
      );
    }
  }
}

/// Declarative plugin implementation for common extension contributions.
class WenzPluginBundle extends WenzRichTextPlugin {
  const WenzPluginBundle({
    required this.id,
    this.apiStatus = WenzPluginApiStatus.stabilising,
    this.commands = const <CommandDescriptor>[],
    this.middlewares = const <CommandMiddleware>[],
    this.blockRenderers = const <BlockType, BlockRendererBuilder>{},
    this.blockEmbedRenderers = const <String, BlockRendererBuilder>{},
    this.inlineEmbedRenderers = const <String, InlineEmbedSpanBuilder>{},
    this.slashMenuItems = const <SlashMenuItem>[],
    this.toolbarItems = const <WenzToolbarItem>[],
    this.pasteTransformers = const <ClipboardPasteTransformer>[],
  });

  @override
  final String id;

  @override
  final WenzPluginApiStatus apiStatus;

  final List<CommandDescriptor> commands;
  final List<CommandMiddleware> middlewares;
  final Map<BlockType, BlockRendererBuilder> blockRenderers;
  final Map<String, BlockRendererBuilder> blockEmbedRenderers;
  final Map<String, InlineEmbedSpanBuilder> inlineEmbedRenderers;
  final List<SlashMenuItem> slashMenuItems;
  final List<WenzToolbarItem> toolbarItems;
  final List<ClipboardPasteTransformer> pasteTransformers;

  @override
  void install(WenzPluginContext context) {
    for (final descriptor in commands) {
      context.registerCommand(descriptor);
    }
    for (final middleware in middlewares) {
      context.addMiddleware(middleware);
    }
    for (final entry in blockRenderers.entries) {
      context.registerBlockRenderer(entry.key, entry.value);
    }
    for (final entry in blockEmbedRenderers.entries) {
      context.registerBlockEmbedRenderer(entry.key, entry.value);
    }
    for (final entry in inlineEmbedRenderers.entries) {
      context.registerInlineEmbedRenderer(entry.key, entry.value);
    }
    for (final item in slashMenuItems) {
      context.registerSlashMenuItem(item);
    }
    for (final item in toolbarItems) {
      context.registerToolbarItem(item);
    }
    for (final transformer in pasteTransformers) {
      context.registerPasteTransformer(transformer);
    }
  }
}

/// Installs a batch of plugins and rejects duplicate ids within that batch.
void installWenzRichTextPlugins({
  required Iterable<WenzRichTextPlugin> plugins,
  required WenzPluginContext context,
}) {
  final seen = <String>{};
  for (final plugin in plugins) {
    if (!seen.add(plugin.id)) {
      throw StateError('Duplicate WenzRichTextPlugin id: ${plugin.id}');
    }
    plugin.install(context);
  }
}
