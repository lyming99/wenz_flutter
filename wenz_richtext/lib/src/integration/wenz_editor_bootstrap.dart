import 'package:flutter/widgets.dart';

import '../codecs/rich_text_json_codec.dart';
import '../controller/autosave_controller.dart';
import '../controller/document_stats_controller.dart';
import '../controller/find_replace_controller.dart';
import '../controller/outline_controller.dart';
import '../controller/slash_menu_controller.dart';
import '../controller/toolbar_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/editor_command.dart';
import '../core/model/document_version_snapshot.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import '../input/clipboard_service.dart';
import '../input/shortcut_manager.dart';
import '../plugins/editor_plugin.dart';
import '../plugins/mermaid_diagram_plugin.dart';
import '../widgets/block_renderer_registry.dart';
import '../widgets/default_desktop_toolbar.dart';
import '../widgets/default_mobile_toolbar.dart';
import '../widgets/editor_context_menu.dart';
import '../widgets/editor_tokens.dart';
import '../widgets/inline_embed_renderer.dart';
import '../widgets/wenz_rich_text_editor.dart';

import 'wenz_editor_configuration.dart';

/// Assembles a fully wired editor from a [WenzEditorConfiguration] and exposes
/// a single lifecycle surface — the recommended entry point for host apps.
///
/// This is the second of the two types that make up the standard external
/// interface: [WenzEditorConfiguration] describes *intent*, and
/// [WenzEditorBootstrap] turns that intent into a live
/// [WenzRichTextController], the extension registries, the derived controllers,
/// and (in [buildEditor]) the editor widget. Hosts call
/// [WenzEditorBootstrap.create] once, read state through the getters and data
/// I/O delegates, render [buildEditor], and release everything with
/// [dispose]. See `docs/integration_guide.md` for the full contract.
///
/// The bootstrap does **not** invent new semantics: every delegate forwards to
/// the matching [WenzRichTextController] method verbatim, the registries reuse
/// the package's existing assembly helpers ([installDefaultRenderers],
/// [installWenzRichTextPlugins]), and the assembly order mirrors the existing
/// example so behaviour is identical to wiring the pieces by hand. Advanced
/// users may still construct [WenzRichTextController] / [WenzRichTextEditor]
/// directly; the bootstrap is the convenience path, not a replacement.
class WenzEditorBootstrap {
  WenzEditorBootstrap._({
    required this.configuration,
    required this.controller,
    required this.blockRendererRegistry,
    required this.inlineEmbedRendererRegistry,
    required this.slashMenuRegistry,
    required this.toolbarItemRegistry,
    required this.pluginShortcutConfigurations,
    required this.toolbarController,
    required this.slashMenuController,
    required this.findReplaceController,
    required this.outlineController,
    required this.statsController,
    required this.autosaveController,
  });

  /// Assembles a bootstrap from [configuration].
  ///
  /// Creates the [WenzRichTextController] (forwarding the initial document,
  /// selection, permission, codec, and media resolver), seeds the extension
  /// registries with their built-in defaults, installs [WenzPluginBundle] /
  /// [WenzRichTextPlugin] contributions via [installWenzRichTextPlugins],
  /// layers host-supplied renderers / slash items / toolbar items on top, and
  /// finally constructs the derived controllers selected by the configuration
  /// flags. Assembly order matches the existing example; default registry
  /// entries are installed once and never re-registered.
  factory WenzEditorBootstrap.create(WenzEditorConfiguration configuration) {
    // Paste transformers live in a single growable list shared by the
    // controller's clipboard service and the plugin context, so host and
    // plugin transformers land in one ordered pipeline.
    final pasteTransformers = <ClipboardPasteTransformer>[
      ...configuration.pasteTransformers,
    ];

    final controller = WenzRichTextController(
      document: configuration.document,
      selection: configuration.selection,
      richTextJsonCodec:
          configuration.richTextJsonCodec ?? const RichTextJsonCodec(),
      mediaResolver: configuration.mediaResolver,
      clipboardService: ClipboardService(pasteTransformers: pasteTransformers),
      permission: configuration.permission,
    );

    // Wire the host callbacks before any mutation can fire them.
    controller.onChanged = configuration.onChanged;
    controller.onSelectionChanged = configuration.onSelectionChanged;
    controller.onCommandExecuted = configuration.onCommandExecuted;

    // Block renderer registry: built-in defaults first so host overrides and
    // business embeds layer on top of a complete default set.
    final blockRendererRegistry = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(blockRendererRegistry);

    // Inline embed renderer registry: starts empty; host and plugin builders
    // are layered in below so the built-in fallback remains the last resort.
    final inlineEmbedRendererRegistry = InlineEmbedRendererRegistry();

    // Slash-menu and toolbar item registries: built-in slash items are seeded
    // via `defaults()` so plugins/hosts only contribute additions.
    final slashMenuRegistry = SlashMenuRegistry.defaults();
    final toolbarItemRegistry = WenzToolbarItemRegistry();

    // Plugin shortcut fragments accumulate here; the editor merges them with
    // the host configuration (host wins) when the widget is built.
    final pluginShortcutConfigurations = <EditorShortcutConfiguration>[];

    final context = WenzPluginContext(
      controller: controller,
      blockRenderers: blockRendererRegistry,
      inlineEmbedRenderers: inlineEmbedRendererRegistry,
      slashMenuRegistry: slashMenuRegistry,
      toolbarItems: toolbarItemRegistry,
      shortcutConfigurations: pluginShortcutConfigurations,
      pasteTransformers: pasteTransformers,
    );
    // Mermaid remains opt-in: disabled hosts keep ordinary code block
    // rendering, while enabled hosts can provide the SVG surface forwarded
    // into MermaidDiagramConfig.
    final plugins = <WenzRichTextPlugin>[
      ...configuration.plugins,
      if (configuration.enableMermaidDiagrams)
        MermaidDiagramPlugin(
          config: MermaidDiagramConfig(
            svgSurface: configuration.diagramSvgSurface,
          ),
        ),
    ];
    installWenzRichTextPlugins(
      plugins: plugins,
      context: context,
    );

    // Host contributions are applied after plugins so host overrides win on id
    // collisions — matching the host-wins merge rule used for shortcuts.
    for (final entry in configuration.blockRenderers.entries) {
      blockRendererRegistry.register(entry.key, entry.value);
    }
    for (final entry in configuration.blockEmbedRenderers.entries) {
      blockRendererRegistry.registerEmbed(entry.key, entry.value);
    }
    for (final entry in configuration.inlineEmbedRenderers.entries) {
      inlineEmbedRendererRegistry.register(entry.key, entry.value);
    }
    slashMenuRegistry.registerAll(configuration.slashMenuItems);
    for (final item in configuration.toolbarItems) {
      toolbarItemRegistry.register(item);
    }

    // Derived controllers, gated by the configuration flags. Outline is built
    // before find/replace so the find controller can reveal folded headings.
    final outlineController = configuration.enableOutline
        ? WenzOutlineController(editor: controller)
        : null;
    final findReplaceController = configuration.enableFindReplace
        ? WenzFindReplaceController(
            editor: controller,
            outlineController: outlineController,
          )
        : null;
    final toolbarController = configuration.enableToolbar
        ? ToolbarController(controller)
        : null;
    final statsController = configuration.enableStats
        ? WenzDocumentStatsController(editor: controller)
        : null;
    // The slash-menu controller shares the assembled registry so host/plugin
    // slash items appear in the built-in overlay.
    final slashMenuController = configuration.enableSlashMenu
        ? SlashMenuController(editor: controller, registry: slashMenuRegistry)
        : null;
    // Autosave is opt-in and needs a host-supplied sink; the controller is
    // created only when both the flag and the callback are present.
    final autosaveController =
        configuration.enableAutosave && configuration.onAutosave != null
            ? WenzAutoSaveController(
                editor: controller,
                onSave: configuration.onAutosave!,
                debounceDuration: configuration.autosaveDebounce,
              )
            : null;

    return WenzEditorBootstrap._(
      configuration: configuration,
      controller: controller,
      blockRendererRegistry: blockRendererRegistry,
      inlineEmbedRendererRegistry: inlineEmbedRendererRegistry,
      slashMenuRegistry: slashMenuRegistry,
      toolbarItemRegistry: toolbarItemRegistry,
      pluginShortcutConfigurations: pluginShortcutConfigurations,
      toolbarController: toolbarController,
      slashMenuController: slashMenuController,
      findReplaceController: findReplaceController,
      outlineController: outlineController,
      statsController: statsController,
      autosaveController: autosaveController,
    );
  }

  /// The configuration this bootstrap was assembled from.
  final WenzEditorConfiguration configuration;

  /// Optional mention search callback supplied by
  /// [WenzEditorConfiguration.mentionSearch].
  ///
  /// A `null` value means the assembled editor should keep the existing
  /// behaviour and not open a mention search surface for `@` input.
  WenzMentionSearchCallback? get mentionSearch => configuration.mentionSearch;

  /// The assembled editor controller.
  final WenzRichTextController controller;

  /// Block renderer registry seeded with the built-in defaults and layered with
  /// plugin + host block/embed renderers. Pass this to
  /// [WenzRichTextEditor.blockRenderers] (or let [buildEditor] do it).
  final BlockRendererRegistry blockRendererRegistry;

  /// Inline embed renderer registry holding plugin + host span builders.
  final InlineEmbedRendererRegistry inlineEmbedRendererRegistry;

  /// Slash-menu registry seeded with the built-in items and layered with
  /// plugin + host contributions.
  final SlashMenuRegistry slashMenuRegistry;

  /// Toolbar item registry holding plugin + host toolbar descriptors.
  final WenzToolbarItemRegistry toolbarItemRegistry;

  /// Shortcut fragments contributed by plugins during assembly. Merged with the
  /// host [WenzEditorConfiguration.shortcutConfiguration] (host wins) when the
  /// editor widget is built.
  final List<EditorShortcutConfiguration> pluginShortcutConfigurations;

  /// The derived toolbar controller, or `null` when
  /// [WenzEditorConfiguration.enableToolbar] is `false`.
  final ToolbarController? toolbarController;

  /// The derived slash-menu controller, or `null` when
  /// [WenzEditorConfiguration.enableSlashMenu] is `false`.
  final SlashMenuController? slashMenuController;

  /// The derived find/replace controller, or `null` when
  /// [WenzEditorConfiguration.enableFindReplace] is `false`.
  final WenzFindReplaceController? findReplaceController;

  /// The derived outline controller, or `null` when
  /// [WenzEditorConfiguration.enableOutline] is `false`.
  final WenzOutlineController? outlineController;

  /// The derived document-stats controller, or `null` when
  /// [WenzEditorConfiguration.enableStats] is `false`.
  final WenzDocumentStatsController? statsController;

  /// The derived autosave controller, or `null` when autosave is disabled or no
  /// [WenzEditorConfiguration.onAutosave] sink was supplied.
  final WenzAutoSaveController? autosaveController;

  /// The current document. Convenience alias for [controller.document].
  RichTextDocument get document => controller.document;

  /// The current selection, or `null`. Convenience alias for
  /// [controller.selection].
  DocumentSelection? get selection => controller.selection;

  // ---- Data I/O delegates ---------------------------------------------------
  //
  // Each method forwards verbatim to the controller so the bootstrap is the
  // single read/write surface. No new serialisation semantics are introduced;
  // see [WenzRichTextController] for the authoritative behaviour.

  /// See [WenzRichTextController.toJson].
  String toJson() => controller.toJson();

  /// See [WenzRichTextController.toMarkdown].
  String toMarkdown() => controller.toMarkdown();

  /// See [WenzRichTextController.toHtml].
  String toHtml() => controller.toHtml();

  /// See [WenzRichTextController.toPlainText].
  String toPlainText() => controller.toPlainText();

  /// See [WenzRichTextController.loadJson].
  void loadJson(
    String source, {
    bool legacy = false,
    DocumentSelection? selection,
  }) {
    controller.loadJson(source, legacy: legacy, selection: selection);
  }

  /// See [WenzRichTextController.tryLoadJson].
  TryLoadResult tryLoadJson(
    String source, {
    bool legacy = false,
    DocumentSelection? selection,
  }) {
    return controller.tryLoadJson(
      source,
      legacy: legacy,
      selection: selection,
    );
  }

  /// See [WenzRichTextController.loadMarkdown].
  void loadMarkdown(String source, {DocumentSelection? selection}) {
    controller.loadMarkdown(source, selection: selection);
  }

  /// See [WenzRichTextController.tryLoadMarkdown].
  TryLoadResult tryLoadMarkdown(String source, {DocumentSelection? selection}) {
    return controller.tryLoadMarkdown(source, selection: selection);
  }

  /// See [WenzRichTextController.loadHtml].
  void loadHtml(String source, {DocumentSelection? selection}) {
    controller.loadHtml(source, selection: selection);
  }

  /// See [WenzRichTextController.tryLoadHtml].
  TryLoadResult tryLoadHtml(String source, {DocumentSelection? selection}) {
    return controller.tryLoadHtml(source, selection: selection);
  }

  /// See [WenzRichTextController.createVersionSnapshot].
  DocumentVersionSnapshot createVersionSnapshot({
    required String id,
    DateTime? createdAt,
    String? authorId,
    String? authorName,
    String? description,
    String? baseSnapshotId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return controller.createVersionSnapshot(
      id: id,
      createdAt: createdAt,
      authorId: authorId,
      authorName: authorName,
      description: description,
      baseSnapshotId: baseSnapshotId,
      metadata: metadata,
    );
  }

  /// See [WenzRichTextController.restoreVersionSnapshot].
  void restoreVersionSnapshot(
    DocumentVersionSnapshot snapshot, {
    DocumentSelection? selection,
    bool clearHistory = true,
  }) {
    controller.restoreVersionSnapshot(
      snapshot,
      selection: selection,
      clearHistory: clearHistory,
    );
  }

  /// See [WenzRichTextController.setSelection].
  void setSelection(DocumentSelection? selection) =>
      controller.setSelection(selection);

  /// See [WenzRichTextController.requestFocus].
  bool requestFocus() => controller.requestFocus();

  // ---- Lifecycle: build + dispose -------------------------------------------

  /// Builds the optional default desktop toolbar from this bootstrap's
  /// assembled editor controller, toolbar controller, and toolbar registry.
  ///
  /// The returned [WenzDefaultDesktopToolbar] is a plain widget. It does not
  /// create or dispose any controller; lifecycle remains owned by this
  /// bootstrap and [dispose]. Host-owned resource actions such as image/video
  /// picking are passed through [actions], and additional host toolbar
  /// descriptors can be appended through [toolbarItems]. [style] controls the
  /// optional toolbar chrome without changing command behaviour.
  ///
  /// Throws a [StateError] when this bootstrap was created with
  /// [WenzEditorConfiguration.enableToolbar] set to `false`, because no
  /// [ToolbarController] exists for the toolbar to observe.
  WenzDefaultDesktopToolbar buildDefaultDesktopToolbar({
    Key? key,
    WenzDefaultDesktopToolbarActions actions =
        const WenzDefaultDesktopToolbarActions(),
    WenzDefaultDesktopToolbarStyle style =
        const WenzDefaultDesktopToolbarStyle(),
    WenzToolbarItemRegistry? toolbarItemRegistry,
    Iterable<WenzToolbarItem> toolbarItems = const <WenzToolbarItem>[],
    bool includeRegistryItems = true,
  }) {
    final toolbar = toolbarController;
    if (toolbar == null) {
      throw StateError(
        'WenzEditorBootstrap.buildDefaultDesktopToolbar requires '
        'WenzEditorConfiguration.enableToolbar=true. This bootstrap was '
        'created with enableToolbar=false, so no ToolbarController is '
        'available.',
      );
    }
    return WenzDefaultDesktopToolbar(
      key: key,
      controller: controller,
      toolbar: toolbar,
      toolbarItemRegistry: toolbarItemRegistry ?? this.toolbarItemRegistry,
      toolbarItems: toolbarItems,
      includeRegistryItems: includeRegistryItems,
      actions: actions,
      style: style,
    );
  }

  /// Builds the optional default mobile toolbar from this bootstrap's assembled
  /// editor controller, toolbar controller, and toolbar registry.
  ///
  /// Mirrors [buildDefaultDesktopToolbar]: the signature is aligned field for
  /// field, it reuses the same [ToolbarController] and [WenzToolbarItemRegistry]
  /// (no parallel item system), and it throws a [StateError] when this bootstrap
  /// was created with [WenzEditorConfiguration.enableToolbar] set to `false`.
  /// Host-owned resource actions pass through [actions]; the chrome comes from
  /// [style] (falling back to [WenzEditorConfiguration.mobileToolbarStyle], then
  /// the toolbar's built-in defaults). The mobile toolbar reads its touch
  /// sizing tokens from [EditorTokens] at build time.
  WenzDefaultMobileToolbar buildDefaultMobileToolbar({
    Key? key,
    WenzDefaultMobileToolbarActions actions =
        const WenzDefaultMobileToolbarActions(),
    WenzMobileToolbarStyle? style,
    WenzToolbarItemRegistry? toolbarItemRegistry,
    Iterable<WenzToolbarItem> toolbarItems = const <WenzToolbarItem>[],
    bool includeRegistryItems = true,
  }) {
    final toolbar = toolbarController;
    if (toolbar == null) {
      throw StateError(
        'WenzEditorBootstrap.buildDefaultMobileToolbar requires '
        'WenzEditorConfiguration.enableToolbar=true. This bootstrap was '
        'created with enableToolbar=false, so no ToolbarController is '
        'available.',
      );
    }
    return WenzDefaultMobileToolbar(
      key: key,
      controller: controller,
      toolbar: toolbar,
      toolbarItemRegistry: toolbarItemRegistry ?? this.toolbarItemRegistry,
      toolbarItems: toolbarItems,
      includeRegistryItems: includeRegistryItems,
      actions: actions,
      style: style ??
          configuration.mobileToolbarStyle ??
          const WenzMobileToolbarStyle(),
    );
  }

  /// Resolves the effective layout for [context] by folding
  /// [WenzEditorConfiguration.layout] together with the running [MediaQuery]
  /// shortestSide.
  ///
  /// [WenzEditorLayout.auto] (the default) returns mobile below the 600px
  /// shortestSide breakpoint and desktop otherwise — the same split
  /// [EditorTokens] uses internally. The explicit [WenzEditorLayout.desktop] /
  /// [WenzEditorLayout.mobile] values force one regardless of screen size, so a
  /// host can override the auto decision. Use this to pick which toolbar to
  /// render (e.g. [buildDefaultMobileToolbar] vs [buildDefaultDesktopToolbar]).
  WenzEditorLayout resolveEditorLayout(BuildContext context) {
    switch (configuration.layout) {
      case WenzEditorLayout.desktop:
        return WenzEditorLayout.desktop;
      case WenzEditorLayout.mobile:
        return WenzEditorLayout.mobile;
      case WenzEditorLayout.auto:
        return EditorTokens.resolve(context).isMobile
            ? WenzEditorLayout.mobile
            : WenzEditorLayout.desktop;
    }
  }

  /// Convenience for [resolveEditorLayout] == [WenzEditorLayout.mobile].
  bool shouldUseMobileLayout(BuildContext context) =>
      resolveEditorLayout(context) == WenzEditorLayout.mobile;

  /// Builds and returns the [WenzRichTextEditor] wired to this bootstrap's
  /// assembled controller, registries, and derived controllers.
  ///
  /// This is the rendering half of the standard lifecycle: call it from a
  /// `build` method and keep the returned widget in the tree for as long as the
  /// editor should be live. Every assembly-time concern — [controller],
  /// [blockRendererRegistry], [inlineEmbedRendererRegistry],
  /// [slashMenuController], [findReplaceController], [outlineController],
  /// the host [WenzEditorConfiguration.onMentionTap],
  /// [WenzEditorConfiguration.onOpenLink], the merged shortcut configuration,
  /// context-menu configuration, external image-input settings, and
  /// [WenzEditorConfiguration.accessibility] — is injected automatically. The
  /// named parameters are appearance overrides a host may pass through; each
  /// forwards verbatim to the [WenzRichTextEditor]
  /// constructor.
  ///
  /// The shortcut configuration merges plugin-contributed fragments first and
  /// the host [WenzEditorConfiguration.shortcutConfiguration] last, so host
  /// bindings win on collision (the resolver checks bindings in reverse order).
  ///
  /// The returned widget is a plain [WenzRichTextEditor]: no wrapper, theme
  /// object, or new widget type is introduced, so behaviour is identical to
  /// constructing [WenzRichTextEditor] by hand. Read/comment/edit mode is
  /// governed by [WenzEditorConfiguration.permission] on the controller's
  /// command gate; [readOnly] only defaults to `true` when that permission is
  /// [WenzEditorPermission.read], and may be overridden explicitly.
  WenzRichTextEditor buildEditor({
    Key? key,
    EdgeInsetsGeometry? padding,
    double? blockSpacing,
    TextStyle? textStyle,
    Color? defaultTextColor,
    ScrollPhysics? physics,
    FocusNode? focusNode,
    bool autofocus = false,
    bool? readOnly,
    bool showDebugOverlay = false,
    bool enableIme = true,
    VoidCallback? onFindRequested,
    VoidCallback? onReplaceRequested,
    WenzLinkInteractionCallback? onOpenLink,
  }) {
    final shortcutConfiguration = EditorShortcutConfiguration.merge(
      <EditorShortcutConfiguration>[
        ...pluginShortcutConfigurations,
        configuration.shortcutConfiguration,
      ],
    );

    return WenzRichTextEditor(
      key: key,
      controller: controller,
      padding: padding ?? const EdgeInsets.all(16),
      blockSpacing: blockSpacing ?? _kEditorDefaultBlockSpacing,
      textStyle: textStyle,
      defaultTextColor: defaultTextColor,
      physics: physics,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly ??
          (configuration.permission == WenzEditorPermission.read),
      showDebugOverlay: showDebugOverlay,
      enableIme: enableIme,
      shortcutConfiguration: shortcutConfiguration,
      contextMenuConfiguration: configuration.contextMenuConfiguration ??
          const WenzEditorContextMenuConfiguration(),
      blockRenderers: blockRendererRegistry,
      mediaResolver: configuration.mediaResolver,
      inlineEmbedRenderer: inlineEmbedRendererRegistry,
      onMentionTap: configuration.onMentionTap,
      onOpenLink: onOpenLink ?? configuration.onOpenLink,
      findController: findReplaceController,
      onFindRequested: onFindRequested,
      onReplaceRequested: onReplaceRequested,
      slashMenuController: slashMenuController,
      outlineController: outlineController,
      enableExternalImageInput: configuration.enableExternalImageInput,
      enableExternalDragDrop: configuration.enableExternalDragDrop,
      enableMobileSelectionHandles:
          configuration.enableMobileSelectionHandles,
      externalImageClipboardReader: configuration.externalImageClipboardReader,
      externalImageStore: configuration.externalImageStore,
      accessibility: configuration.accessibility,
    );
  }

  bool _isDisposed = false;

  /// Releases the derived controllers and the controller in reverse dependency
  /// order.
  ///
  /// Every derived controller removes its own listener from the editor inside
  /// its `dispose`, so all of them are released **before** [controller] —
  /// matching the existing example, which notes that a listener such as
  /// [SlashMenuController] must unbind from the editor while the editor is
  /// still alive. The registries own no disposable resources and need no
  /// teardown. Calling [dispose] more than once is a no-op.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    // Listeners of the editor first, editor last.
    toolbarController?.dispose();
    statsController?.dispose();
    autosaveController?.dispose();
    findReplaceController?.dispose();
    outlineController?.dispose();
    slashMenuController?.dispose();
    controller.dispose();
  }
}

/// Mirrors [WenzRichTextEditor]'s private default block spacing (body font
/// size × paragraph margin) so hosts that omit [WenzEditorBootstrap.buildEditor]'s
/// `blockSpacing` get the exact editor default rather than a bootstrap-imposed
/// value. If the editor default changes, update this constant to match.
const double _kEditorDefaultBlockSpacing = 16.0 * 0.55;
