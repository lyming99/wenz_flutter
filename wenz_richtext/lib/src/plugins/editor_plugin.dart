import '../controller/slash_menu_controller.dart';
import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/command_registry.dart';
import '../core/commands/editor_command.dart';
import '../core/model/block_node.dart';
import '../input/clipboard_service.dart';
import '../input/shortcut_manager.dart';
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

  /// Releases resources owned by this plugin. The default is a no-op.
  void dispose() {}
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
    List<EditorShortcutConfiguration>? shortcutConfigurations,
    List<ClipboardPasteTransformer>? pasteTransformers,
  })  : shortcutConfigurations =
            shortcutConfigurations ?? <EditorShortcutConfiguration>[],
        pasteTransformers =
            pasteTransformers ?? controller.clipboardService.pasteTransformers;

  final WenzRichTextController controller;
  final BlockRendererRegistry? blockRenderers;
  final InlineEmbedRendererRegistry? inlineEmbedRenderers;
  final SlashMenuRegistry? slashMenuRegistry;
  final WenzToolbarItemRegistry? toolbarItems;

  /// Shortcut configuration fragments contributed by plugins. Merge these
  /// before the editor's explicit configuration so app-level bindings win.
  final List<EditorShortcutConfiguration> shortcutConfigurations;

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

  void registerSlashMenuItems(Iterable<SlashMenuItem> items) {
    final registry = slashMenuRegistry;
    if (registry == null) {
      throw StateError('No SlashMenuRegistry was provided for plugins.');
    }
    registry.registerAll(items);
  }

  void addSlashMenuFilter(SlashMenuItemFilter filter) {
    final registry = slashMenuRegistry;
    if (registry == null) {
      throw StateError('No SlashMenuRegistry was provided for plugins.');
    }
    registry.addFilter(filter);
  }

  void setSlashMenuSorter(SlashMenuItemSorter? sorter) {
    final registry = slashMenuRegistry;
    if (registry == null) {
      throw StateError('No SlashMenuRegistry was provided for plugins.');
    }
    registry.setSorter(sorter);
  }

  void registerToolbarItem(WenzToolbarItem item) {
    final registry = toolbarItems;
    if (registry == null) {
      throw StateError('No WenzToolbarItemRegistry was provided for plugins.');
    }
    registry.register(item);
  }

  void registerShortcutConfiguration(
      EditorShortcutConfiguration configuration) {
    try {
      shortcutConfigurations.add(configuration);
    } on UnsupportedError catch (error) {
      throw StateError(
        'Shortcut configurations are immutable. Pass a growable list to '
        'WenzPluginContext(shortcutConfigurations: '
        '<EditorShortcutConfiguration>[]). Original error: $error',
      );
    }
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
    this.slashMenuFilters = const <SlashMenuItemFilter>[],
    this.slashMenuSorter,
    this.toolbarItems = const <WenzToolbarItem>[],
    this.shortcutConfigurations = const <EditorShortcutConfiguration>[],
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
  final List<SlashMenuItemFilter> slashMenuFilters;
  final SlashMenuItemSorter? slashMenuSorter;
  final List<WenzToolbarItem> toolbarItems;
  final List<EditorShortcutConfiguration> shortcutConfigurations;
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
    for (final filter in slashMenuFilters) {
      context.addSlashMenuFilter(filter);
    }
    if (slashMenuSorter != null) {
      context.setSlashMenuSorter(slashMenuSorter);
    }
    for (final item in toolbarItems) {
      context.registerToolbarItem(item);
    }
    for (final configuration in shortcutConfigurations) {
      context.registerShortcutConfiguration(configuration);
    }
    for (final transformer in pasteTransformers) {
      context.registerPasteTransformer(transformer);
    }
  }
}

/// Merges plugin shortcut fragments before the editor's explicit configuration.
///
/// This keeps priority deterministic: built-in shortcuts are resolved by
/// [EditorShortcutManager], plugin fragments are applied in installation order,
/// and the editor-level configuration is appended last so host apps can override
/// plugins without editing them.
EditorShortcutConfiguration mergeWenzShortcutConfigurations({
  Iterable<EditorShortcutConfiguration> pluginConfigurations =
      const <EditorShortcutConfiguration>[],
  EditorShortcutConfiguration editorConfiguration =
      const EditorShortcutConfiguration(),
}) {
  return EditorShortcutConfiguration.merge(<EditorShortcutConfiguration>[
    ...pluginConfigurations,
    editorConfiguration,
  ]);
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
