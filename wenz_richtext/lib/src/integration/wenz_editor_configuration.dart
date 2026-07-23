import 'package:flutter/foundation.dart';

import '../codecs/rich_text_json_codec.dart';
import '../controller/autosave_controller.dart';
import '../controller/slash_menu_controller.dart';
import '../controller/toolbar_controller.dart';
import '../core/commands/editor_command.dart';
import '../core/model/block_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';
import '../core/transaction/change_set.dart';
import '../input/clipboard_service.dart';
import '../input/external_image_insertion.dart';
import '../input/external_image_input.dart';
import '../input/shortcut_manager.dart';
import '../plugins/editor_plugin.dart';
import '../plugins/mermaid_diagram_plugin.dart';
import '../widgets/block_renderer_registry.dart';
import '../widgets/desktop_selection_toolbar_overlay.dart';
import '../widgets/editor_context_menu.dart';
import '../widgets/inline_embed_renderer.dart';
import '../widgets/media_resource_action.dart';
import '../widgets/media_resolver.dart';
import '../widgets/wenz_rich_text_editor.dart';

/// Declarative, side-effect-free description of how a host wants the editor
/// assembled.
///
/// This is one of the two types that make up the standard external interface:
/// [`WenzEditorConfiguration`] describes *intent*, and
/// [`WenzEditorBootstrap`] turns that intent into a wired-up controller, the
/// derived controllers, the registries, and the editor widget. See
/// `docs/integration_guide.md` for the full contract.
///
/// The configuration object is intentionally inert. It creates no controller,
/// builds no widget, holds no [BuildContext], and produces no side effects when
/// constructed — every field is optional with a sane default, so
/// `WenzEditorConfiguration()` is a legal, runnable configuration. Hosts pass
/// it to `WenzEditorBootstrap.create`, derive per-scenario variants with
/// [copyWith], and otherwise treat it as plain data.
///
/// Field types reuse the package's existing public types verbatim; the
/// configuration does not invent a parallel set of integration primitives. See
/// the configuration-field → extension-point map in `docs/integration_guide.md`
/// for which field each facade consumer reads.
@immutable
class WenzEditorConfiguration {
  /// Creates a configuration describing the desired editor assembly.
  ///
  /// Every parameter is optional. The defaults assemble a usable editor with
  /// [permission] set to [WenzEditorPermission.edit], the built-in derived
  /// controllers enabled, and no host-supplied extensions — so a bare
  /// `WenzEditorConfiguration()` is runnable as-is.
  const WenzEditorConfiguration({
    this.document,
    this.selection,
    this.permission = WenzEditorPermission.edit,
    this.richTextJsonCodec,
    this.mediaResolver,
    this.onMediaResourceAction,
    this.accessibility = const WenzRichTextEditorAccessibility(),
    this.shortcutConfiguration = const EditorShortcutConfiguration(),
    this.contextMenuConfiguration,
    this.pasteTransformers = const <ClipboardPasteTransformer>[],
    this.blockRenderers = const <BlockType, BlockRendererBuilder>{},
    this.blockEmbedRenderers = const <String, BlockRendererBuilder>{},
    this.inlineEmbedRenderers = const <String, InlineEmbedSpanBuilder>{},
    this.slashMenuItems = const <SlashMenuItem>[],
    this.toolbarItems = const <WenzToolbarItem>[],
    this.plugins = const <WenzRichTextPlugin>[],
    this.enableExternalImageInput = true,
    this.externalImageClipboardReader,
    this.externalImageStore,
    this.externalImageInsertionResolver,
    this.mentionSearch,
    this.onMentionTap,
    this.onOpenLink,
    this.onChanged,
    this.onSelectionChanged,
    this.onCommandExecuted,
    this.enableSlashMenu = true,
    this.enableFindReplace = true,
    this.enableOutline = true,
    this.enableStats = true,
    this.enableToolbar = true,
    this.enableAutosave = false,
    this.onAutosave,
    this.autosaveDebounce = const Duration(seconds: 2),
    this.enableMermaidDiagrams = false,
    this.layout = WenzEditorLayout.auto,
    this.desktopToolbarMode = WenzDesktopToolbarMode.fixed,
    this.enableMobileSelectionHandles = true,
    this.enableExternalDragDrop = true,
    this.mobileToolbarStyle,
  });

  /// Initial document, or `null` for an empty document.
  ///
  /// Forwarded to the [WenzRichTextController] constructor; `null` lets the
  /// controller build its default empty document.
  final RichTextDocument? document;

  /// Initial selection, or `null` to leave the selection unset.
  final DocumentSelection? selection;

  /// Command permission policy. Defaults to [WenzEditorPermission.edit].
  ///
  /// Forwarded to the controller and consulted by the command gate, so setting
  /// this to [WenzEditorPermission.comment] or [WenzEditorPermission.read]
  /// rejects the matching write commands at the command layer — the gate is
  /// never bypassed.
  final WenzEditorPermission permission;

  /// Rich JSON codec used for rich-text serialization and migration.
  ///
  /// `null` (default) lets the bootstrap use the controller's default codec,
  /// which decodes documents as-is. Hosts loading legacy data should pass a
  /// codec whose [RichTextJsonCodec.migrations] lifts older schema versions,
  /// e.g. `RichTextJsonCodec(migrations: myRegistry)`.
  final RichTextJsonCodec? richTextJsonCodec;

  /// Media resolver for image/video/file blocks, or `null` to use the editor's
  /// built-in placeholders.
  final MediaResolver? mediaResolver;

  /// Optional host callback for image/video resource actions.
  ///
  /// The editor forwards this callback to media block render contexts. When it
  /// is `null`, no resource action is dispatched and existing hosts retain
  /// their previous behaviour.
  final MediaResourceActionHandler? onMediaResourceAction;

  /// Accessibility labels and high-contrast focus styling for the editor
  /// surface. Forwarded verbatim to [WenzRichTextEditor].
  final WenzRichTextEditorAccessibility accessibility;

  /// Host-level shortcut configuration.
  ///
  /// Merged **last** by the bootstrap (after plugin-contributed fragments), so
  /// host bindings always win over plugin bindings.
  final EditorShortcutConfiguration shortcutConfiguration;

  /// Optional desktop context-menu configuration forwarded to
  /// [WenzRichTextEditor].
  ///
  /// `null` keeps the editor's default menu. Pass
  /// [WenzEditorContextMenuConfiguration] to append custom items, replace the
  /// defaults, or use a builder to insert host actions at a specific position.
  /// `copyWith(contextMenuConfiguration: null)` clears a host configuration.
  final WenzEditorContextMenuConfiguration? contextMenuConfiguration;

  /// Host-supplied paste transformers, added to the editor's clipboard service
  /// alongside any transformers contributed by [plugins].
  final List<ClipboardPasteTransformer> pasteTransformers;

  /// Custom [BlockType] → builder mappings registered after the default
  /// renderers are installed. Default renderers remain available for any type
  /// not overridden here.
  final Map<BlockType, BlockRendererBuilder> blockRenderers;

  /// Custom [BlockEmbedNode] embed-type → builder mappings (for example a CRM
  /// card). Registered after the default renderers.
  final Map<String, BlockRendererBuilder> blockEmbedRenderers;

  /// Custom inline embed span builders keyed by embed type (for example a
  /// `@mention` chip).
  final Map<String, InlineEmbedSpanBuilder> inlineEmbedRenderers;

  /// Host-supplied slash-menu items, added to the slash menu registry.
  final List<SlashMenuItem> slashMenuItems;

  /// Host-supplied toolbar items, added to the toolbar item registry.
  final List<WenzToolbarItem> toolbarItems;

  /// Plugins (including [WenzPluginBundle]) installed through
  /// `installWenzRichTextPlugins` during assembly.
  final List<WenzRichTextPlugin> plugins;

  /// Whether the editor should accept platform image input from clipboard and
  /// external file drops.
  ///
  /// Defaults to `true`. Set to `false` to keep ordinary text/HTML/Markdown
  /// paste behaviour but skip image clipboard flavors and external image drop
  /// targets entirely.
  final bool enableExternalImageInput;

  /// Optional reader for image-capable clipboard flavors.
  ///
  /// When omitted, the editor only reads the standard Flutter plain-text
  /// clipboard unless the host supplies a platform reader here. The reader
  /// returns stable [ExternalImageClipboardData] values, keeping concrete
  /// plugin types outside the public configuration contract.
  final ExternalImageClipboardReader? externalImageClipboardReader;

  /// Optional storage/validation strategy for external image inputs.
  ///
  /// When omitted, [WenzRichTextEditor] uses its default platform store: IO
  /// builds validate file paths/file URIs and materialise in-memory images into
  /// temporary files; unsupported builds return a safe no-op failure.
  final ExternalImageStore? externalImageStore;

  /// Optional host policy for choosing the document position of prepared
  /// clipboard/drop images.
  ///
  /// Returning `null` preserves the interaction's suggested target.
  final ExternalImageInsertionSelectionResolver? externalImageInsertionResolver;

  /// Optional mention search callback used by editor mention suggestion UIs.
  ///
  /// When `null` (default), typing `@` keeps the editor's existing behaviour:
  /// no mention search overlay is requested. Hosts that provide a callback own
  /// the user directory lookup and return [WenzMentionCandidate] values for the
  /// editor to insert as `mention` inline embeds.
  final WenzMentionSearchCallback? mentionSearch;

  /// Callback invoked when a mention inline embed is activated. Forwarded to
  /// [WenzRichTextEditor] as the editor-level mention handler.
  final WenzMentionTapCallback? onMentionTap;

  /// Callback invoked when a link is opened from the editor surface. Forwarded
  /// to [WenzRichTextEditor] as the editor-level link opener.
  final WenzLinkInteractionCallback? onOpenLink;

  /// Invoked before the controller notifies listeners whenever the document
  /// content changes. Mirrors [WenzRichTextController.onChanged].
  final ValueChanged<RichTextDocument>? onChanged;

  /// Invoked before the controller notifies listeners whenever the selection
  /// changes. Mirrors [WenzRichTextController.onSelectionChanged].
  final ValueChanged<DocumentSelection?>? onSelectionChanged;

  /// Invoked before the controller notifies listeners right after a command
  /// produced a non-noop change. Mirrors
  /// [WenzRichTextController.onCommandExecuted].
  final void Function(EditorCommand command, ChangeSet change)?
      onCommandExecuted;

  /// Whether the bootstrap should create the [SlashMenuController].
  ///
  /// Defaults to `true`; the slash menu is part of the stock editing surface.
  final bool enableSlashMenu;

  /// Whether the bootstrap should create the [WenzFindReplaceController].
  ///
  /// Defaults to `true`.
  final bool enableFindReplace;

  /// Whether the bootstrap should create the [WenzOutlineController].
  ///
  /// Defaults to `true`.
  final bool enableOutline;

  /// Whether the bootstrap should create the [WenzDocumentStatsController].
  ///
  /// Defaults to `true`.
  final bool enableStats;

  /// Whether the bootstrap should create the [ToolbarController].
  ///
  /// Defaults to `true`.
  final bool enableToolbar;

  /// Whether the bootstrap should create the [WenzAutoSaveController].
  ///
  /// Defaults to `false`: autosave needs a host-supplied sink ([onAutosave]),
  /// so it is opt-in. When `true` the controller is created only if [onAutosave]
  /// is also provided.
  final bool enableAutosave;

  /// Sink the [WenzAutoSaveController] calls to persist a snapshot. Required
  /// when [enableAutosave] is `true`; ignored otherwise.
  final WenzAutoSaveCallback? onAutosave;

  /// Debounce duration applied to the [WenzAutoSaveController] when autosave is
  /// enabled. Defaults to two seconds, matching the controller default.
  final Duration autosaveDebounce;

  /// Whether the bootstrap should install the [MermaidDiagramPlugin] so that
  /// [CodeBlockNode]s with a normalized Mermaid language marker render as live
  /// diagrams.
  ///
  /// Defaults to `false` — Mermaid support is opt-in so hosts decide when
  /// code blocks should use the pure Flutter diagram preview.
  final bool enableMermaidDiagrams;

  /// Which form-factor UI the host wants assembled.
  ///
  /// Defaults to [WenzEditorLayout.auto], whose resolved value is intended to
  /// follow the platform-aware mobile UI decision exposed by
  /// [EditorTokens.shouldUseMobileSelectionUi]: desktop platforms remain on
  /// desktop UI in narrow windows, while compact Android/iOS-style surfaces can
  /// use mobile UI. Set [WenzEditorLayout.desktop] /
  /// [WenzEditorLayout.mobile] to force one regardless of screen size or
  /// platform. The bootstrap exposes the resolved value via
  /// `WenzEditorBootstrap.resolveEditorLayout`.
  final WenzEditorLayout layout;

  /// How the desktop formatting toolbar is presented.
  ///
  /// Defaults to [WenzDesktopToolbarMode.fixed], preserving the existing
  /// host-rendered toolbar. Selection-floating mode is assembled by
  /// [WenzEditorBootstrap.buildEditor] when the toolbar controller is enabled.
  final WenzDesktopToolbarMode desktopToolbarMode;

  /// Whether touch selection handles may mount on mobile surfaces.
  ///
  /// Defaults to `true`; this is the final switch after the editor checks
  /// [EditorTokens.shouldUseMobileSelectionUi]. Desktop platforms are not
  /// eligible for phone-style selection handles merely because the window is
  /// narrow. Forwarded for the editor overlay to consume.
  final bool enableMobileSelectionHandles;

  /// Whether the external drag-and-drop surface (the `super_drag` `DropRegion`)
  /// is mounted on mouse-driven surfaces.
  ///
  /// Defaults to `true`. Touch form factors always skip the `DropRegion`
  /// (handled in [WenzRichTextEditor]), so this only takes effect on desktop;
  /// hosts that never want drag-and-drop can disable it here. Forwarded to
  /// [WenzRichTextEditor.enableExternalDragDrop] by the bootstrap.
  final bool enableExternalDragDrop;

  /// Optional chrome for the default mobile toolbar ([WenzDefaultMobileToolbar]).
  ///
  /// When `null` the toolbar uses its built-in defaults. Hosts can pre-configure
  /// it (for example the keyboard-collaboration strategy) through the
  /// configuration so assembly does not need to pass it at build time.
  final WenzMobileToolbarStyle? mobileToolbarStyle;

  /// Returns a copy of this configuration with the given fields replaced.
  ///
  /// Nullable fields use an internal sentinel so that explicitly passing `null`
  /// (for example to clear [document] or [mediaResolver]) is respected rather
  /// than treated as "leave unchanged".
  WenzEditorConfiguration copyWith({
    Object? document = _unset,
    Object? selection = _unset,
    WenzEditorPermission? permission,
    Object? richTextJsonCodec = _unset,
    Object? mediaResolver = _unset,
    Object? onMediaResourceAction = _unset,
    WenzRichTextEditorAccessibility? accessibility,
    EditorShortcutConfiguration? shortcutConfiguration,
    Object? contextMenuConfiguration = _unset,
    List<ClipboardPasteTransformer>? pasteTransformers,
    Map<BlockType, BlockRendererBuilder>? blockRenderers,
    Map<String, BlockRendererBuilder>? blockEmbedRenderers,
    Map<String, InlineEmbedSpanBuilder>? inlineEmbedRenderers,
    List<SlashMenuItem>? slashMenuItems,
    List<WenzToolbarItem>? toolbarItems,
    List<WenzRichTextPlugin>? plugins,
    bool? enableExternalImageInput,
    Object? externalImageClipboardReader = _unset,
    Object? externalImageStore = _unset,
    Object? externalImageInsertionResolver = _unset,
    Object? mentionSearch = _unset,
    Object? onMentionTap = _unset,
    Object? onOpenLink = _unset,
    Object? onChanged = _unset,
    Object? onSelectionChanged = _unset,
    Object? onCommandExecuted = _unset,
    bool? enableSlashMenu,
    bool? enableFindReplace,
    bool? enableOutline,
    bool? enableStats,
    bool? enableToolbar,
    bool? enableAutosave,
    Object? onAutosave = _unset,
    Duration? autosaveDebounce,
    bool? enableMermaidDiagrams,
    WenzEditorLayout? layout,
    WenzDesktopToolbarMode? desktopToolbarMode,
    bool? enableMobileSelectionHandles,
    bool? enableExternalDragDrop,
    Object? mobileToolbarStyle = _unset,
  }) {
    return WenzEditorConfiguration(
      document: identical(document, _unset)
          ? this.document
          : document as RichTextDocument?,
      selection: identical(selection, _unset)
          ? this.selection
          : selection as DocumentSelection?,
      permission: permission ?? this.permission,
      richTextJsonCodec: identical(richTextJsonCodec, _unset)
          ? this.richTextJsonCodec
          : richTextJsonCodec as RichTextJsonCodec?,
      mediaResolver: identical(mediaResolver, _unset)
          ? this.mediaResolver
          : mediaResolver as MediaResolver?,
      onMediaResourceAction: identical(onMediaResourceAction, _unset)
          ? this.onMediaResourceAction
          : onMediaResourceAction as MediaResourceActionHandler?,
      accessibility: accessibility ?? this.accessibility,
      shortcutConfiguration: shortcutConfiguration ?? this.shortcutConfiguration,
      contextMenuConfiguration: identical(contextMenuConfiguration, _unset)
          ? this.contextMenuConfiguration
          : contextMenuConfiguration as WenzEditorContextMenuConfiguration?,
      pasteTransformers: pasteTransformers ?? this.pasteTransformers,
      blockRenderers: blockRenderers ?? this.blockRenderers,
      blockEmbedRenderers: blockEmbedRenderers ?? this.blockEmbedRenderers,
      inlineEmbedRenderers: inlineEmbedRenderers ?? this.inlineEmbedRenderers,
      slashMenuItems: slashMenuItems ?? this.slashMenuItems,
      toolbarItems: toolbarItems ?? this.toolbarItems,
      plugins: plugins ?? this.plugins,
      enableExternalImageInput:
          enableExternalImageInput ?? this.enableExternalImageInput,
      externalImageClipboardReader:
          identical(externalImageClipboardReader, _unset)
              ? this.externalImageClipboardReader
              : externalImageClipboardReader as ExternalImageClipboardReader?,
      externalImageStore: identical(externalImageStore, _unset)
          ? this.externalImageStore
          : externalImageStore as ExternalImageStore?,
      externalImageInsertionResolver:
          identical(externalImageInsertionResolver, _unset)
              ? this.externalImageInsertionResolver
              : externalImageInsertionResolver
                  as ExternalImageInsertionSelectionResolver?,
      mentionSearch: identical(mentionSearch, _unset)
          ? this.mentionSearch
          : mentionSearch as WenzMentionSearchCallback?,
      onMentionTap: identical(onMentionTap, _unset)
          ? this.onMentionTap
          : onMentionTap as WenzMentionTapCallback?,
      onOpenLink: identical(onOpenLink, _unset)
          ? this.onOpenLink
          : onOpenLink as WenzLinkInteractionCallback?,
      onChanged: identical(onChanged, _unset)
          ? this.onChanged
          : onChanged as ValueChanged<RichTextDocument>?,
      onSelectionChanged: identical(onSelectionChanged, _unset)
          ? this.onSelectionChanged
          : onSelectionChanged as ValueChanged<DocumentSelection?>?,
      onCommandExecuted: identical(onCommandExecuted, _unset)
          ? this.onCommandExecuted
          : onCommandExecuted
              as void Function(EditorCommand command, ChangeSet change)?,
      enableSlashMenu: enableSlashMenu ?? this.enableSlashMenu,
      enableFindReplace: enableFindReplace ?? this.enableFindReplace,
      enableOutline: enableOutline ?? this.enableOutline,
      enableStats: enableStats ?? this.enableStats,
      enableToolbar: enableToolbar ?? this.enableToolbar,
      enableAutosave: enableAutosave ?? this.enableAutosave,
      onAutosave: identical(onAutosave, _unset)
          ? this.onAutosave
          : onAutosave as WenzAutoSaveCallback?,
      autosaveDebounce: autosaveDebounce ?? this.autosaveDebounce,
      enableMermaidDiagrams:
          enableMermaidDiagrams ?? this.enableMermaidDiagrams,
      layout: layout ?? this.layout,
      desktopToolbarMode: desktopToolbarMode ?? this.desktopToolbarMode,
      enableMobileSelectionHandles:
          enableMobileSelectionHandles ?? this.enableMobileSelectionHandles,
      enableExternalDragDrop:
          enableExternalDragDrop ?? this.enableExternalDragDrop,
      mobileToolbarStyle: identical(mobileToolbarStyle, _unset)
          ? this.mobileToolbarStyle
          : mobileToolbarStyle as WenzMobileToolbarStyle?,
    );
  }
}

/// Sentinel used by [WenzEditorConfiguration.copyWith] to distinguish an
/// omitted nullable argument (leave unchanged) from an explicit `null` (clear).
const Object _unset = Object();

/// Selects which form-factor UI the host wants the bootstrap to assemble.
///
/// The editor widget itself adapts density via [EditorTokens.resolve], while
/// phone-specific interaction chrome uses
/// [EditorTokens.shouldUseMobileSelectionUi]. This field is the host-level
/// override that drives tooling decisions the editor does not own — chiefly
/// which default toolbar ([WenzDefaultDesktopToolbar] vs
/// [WenzDefaultMobileToolbar]) the host renders.
/// [WenzEditorBootstrap.resolveEditorLayout] folds this preference together
/// with the platform-aware mobile UI decision into a concrete choice.
enum WenzEditorLayout {
  /// Auto-detect: compact mobile platforms use mobile UI; desktop platforms
  /// keep desktop UI even in narrow windows.
  auto,

  /// Force the desktop UI regardless of screen size or platform.
  desktop,

  /// Force the mobile UI regardless of screen size or platform.
  mobile,
}

/// Chrome for the default mobile toolbar ([WenzDefaultMobileToolbar]).
///
/// Button/icon/radius sizing follows the mobile toolbar tokens, while this
/// style carries bottom-toolbar behaviour and host-tunable frame dimensions.
/// Kept here so hosts can pre-configure it via
/// [WenzEditorConfiguration.mobileToolbarStyle] before assembly.
@immutable
class WenzMobileToolbarStyle {
  const WenzMobileToolbarStyle({
    this.aboveKeyboard = true,
    this.mainBarHeight = 52.0,
    this.panelHeight = 260.0,
    this.dismissKeyboardOnPanelOpen = true,
    this.restoreFocusOnPanelClose = true,
    this.animationDuration = const Duration(milliseconds: 180),
    this.elevation = 0.0,
  })  : assert(mainBarHeight >= 44.0),
        assert(panelHeight >= 120.0),
        assert(elevation >= 0.0);

  /// Whether the toolbar follows the soft keyboard's top edge (`true`, the
  /// default) or stays at the host-provided layout position (`false`).
  ///
  /// When a panel replaces a dismissed keyboard, its stable cached occupancy
  /// is used instead of applying the keyboard inset a second time.
  final bool aboveKeyboard;

  /// Fixed height for the always-visible bottom command bar.
  final double mainBarHeight;

  /// Fallback height for an insert/format panel when no recent non-zero soft
  /// keyboard height is available.
  ///
  /// A panel replacing the keyboard uses the most recently observed keyboard
  /// height. Both values are clamped to the viewport space remaining after the
  /// main bar, and panel contents remain scrollable on compact viewports.
  final double panelHeight;

  /// Whether opening an insert/format panel replaces the platform input method.
  ///
  /// The panel is committed before the keyboard is dismissed, so its cached
  /// occupancy takes over atomically. When `false`, the keyboard inset remains
  /// applied and the panel uses its fallback height instead of replacing it.
  final bool dismissKeyboardOnPanelOpen;

  /// Whether closing an active panel should restore editor focus and the input
  /// method. The panel occupancy is retained until the keyboard has reclaimed
  /// it (or the bounded focus-recovery fallback expires).
  final bool restoreFocusOnPanelClose;

  /// Duration used for fallback panel-size transitions when there is no cached
  /// keyboard occupancy. Keyboard-to-panel replacement itself is atomic.
  final Duration animationDuration;

  /// Material elevation for the toolbar surface.
  final double elevation;
}
