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
import '../input/external_image_input.dart';
import '../input/shortcut_manager.dart';
import '../plugins/editor_plugin.dart';
import '../plugins/mermaid_diagram_plugin.dart';
import '../widgets/block_renderer_registry.dart';
import '../widgets/inline_embed_renderer.dart';
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
    this.accessibility = const WenzRichTextEditorAccessibility(),
    this.shortcutConfiguration = const EditorShortcutConfiguration(),
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
    this.mentionSearch,
    this.onMentionTap,
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
    this.diagramSvgSurface,
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

  /// Accessibility labels and high-contrast focus styling for the editor
  /// surface. Forwarded verbatim to [WenzRichTextEditor].
  final WenzRichTextEditorAccessibility accessibility;

  /// Host-level shortcut configuration.
  ///
  /// Merged **last** by the bootstrap (after plugin-contributed fragments), so
  /// host bindings always win over plugin bindings.
  final EditorShortcutConfiguration shortcutConfiguration;

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
  /// [CodeBlockNode]s with `language == 'mermaid'` render as live diagrams.
  ///
  /// Defaults to `false` — mermaid support is opt-in because it requires the
  /// `merman` native library at runtime.
  final bool enableMermaidDiagrams;

  /// The SVG surface used by [MermaidDiagramPlugin] to paint diagram output.
  ///
  /// When `null` (default) the plugin uses [VectorGraphicsDiagramSurface].
  /// Host apps that need pixel-perfect rendering can inject a WebView-based
  /// surface instead.
  final DiagramSvgSurface? diagramSvgSurface;

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
    WenzRichTextEditorAccessibility? accessibility,
    EditorShortcutConfiguration? shortcutConfiguration,
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
    Object? mentionSearch = _unset,
    Object? onMentionTap = _unset,
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
    Object? diagramSvgSurface = _unset,
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
      accessibility: accessibility ?? this.accessibility,
      shortcutConfiguration: shortcutConfiguration ?? this.shortcutConfiguration,
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
      mentionSearch: identical(mentionSearch, _unset)
          ? this.mentionSearch
          : mentionSearch as WenzMentionSearchCallback?,
      onMentionTap: identical(onMentionTap, _unset)
          ? this.onMentionTap
          : onMentionTap as WenzMentionTapCallback?,
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
      diagramSvgSurface: identical(diagramSvgSurface, _unset)
          ? this.diagramSvgSurface
          : diagramSvgSurface as DiagramSvgSurface?,
    );
  }
}

/// Sentinel used by [WenzEditorConfiguration.copyWith] to distinguish an
/// omitted nullable argument (leave unchanged) from an explicit `null` (clear).
const Object _unset = Object();
