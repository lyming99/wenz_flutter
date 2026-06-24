import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../controller/find_replace_controller.dart';
import '../controller/slash_menu_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import '../input/editor_text_input_client.dart';
import '../input/shortcut_manager.dart';
import '../rendering/text_layout_service.dart';
import 'block_geometry_registry.dart';
import 'block_renderer_registry.dart';
import 'inline_embed_renderer.dart';
import 'media_resolver.dart';
import 'selection_gesture_overlay.dart';
import 'shared_text_layout_cache.dart';
import 'slash_menu_overlay.dart';

const _caretKey = ValueKey<String>('wenz-richtext-caret');
const _selectionHighlightKey = ValueKey<String>(
  'wenz-richtext-selection-highlight',
);
const _findHighlightKey = ValueKey<String>('wenz-richtext-find-highlight');
const _accessibilityFocusHighlightKey = ValueKey<String>(
  'wenz-richtext-accessibility-focus-highlight',
);

/// Caret geometry constants — kept in one place so the painted caret, the caret
/// rect reported to the IME, and any future theming all share the same source.
const double _kCaretStrokeWidth = 1.5;
const Duration _kBlinkHalfPeriod = Duration(milliseconds: 530);
const double _kDefaultBlockExtent = 48.0;
const double _kVirtualListOverscan = 600.0;
const double _kTableResizeHandleWidth = 12.0;
const double _kTableResizeHandleTopInset = 48.0;
const double _kMinTableColumnWidth = 48.0;
const double _kMaxTableColumnWidth = 640.0;
const int _kTableToolbarBackgroundColor = 0xFFFFF3CD;

/// Minimum block height multiplier applied to the block's font size, ensuring
/// a tap target even for empty paragraphs. A single constant so the text,
/// code, and table-cell renderers stay in sync.
const double _kBlockMinHeightFactor = 1.35;

/// Atomic block-level objects (images, videos, files, dividers) occupy one
/// selectable document slot, mirroring inline embeds' object-replacement slot.
const int _kAtomicBlockSelectionLength = 1;

/// Pixels of horizontal indent per indent level.
const double _kIndentPixelsPerLevel = 24;

/// Exposes the editor's [SharedTextLayoutCache] down the subtree so each
/// [_TextSelectionSurface] can fetch (and reuse) its [TextLayoutService] across
/// remount, without threading the cache through every renderer widget.
class _SharedLayoutCacheScope extends InheritedWidget {
  const _SharedLayoutCacheScope({required this.cache, required super.child});

  final SharedTextLayoutCache cache;

  static SharedTextLayoutCache? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_SharedLayoutCacheScope>();
    return scope?.cache;
  }

  @override
  bool updateShouldNotify(_SharedLayoutCacheScope oldWidget) =>
      cache != oldWidget.cache;
}

@immutable
class WenzRichTextEditorAccessibility {
  const WenzRichTextEditorAccessibility({
    this.label = 'Rich text editor',
    this.readOnlyLabel = 'Rich text document',
    this.hint =
        'Edit rich text content with text input and keyboard shortcuts.',
    this.readOnlyHint = 'Read-only rich text document.',
    this.highContrastFocusColor,
    this.highContrastFocusWidth = 3,
  }) : assert(highContrastFocusWidth >= 0);

  /// Screen-reader label announced for an editable editor.
  final String label;

  /// Screen-reader label announced when [WenzRichTextEditor.readOnly] is true.
  final String readOnlyLabel;

  /// Screen-reader hint announced for an editable editor.
  final String hint;

  /// Screen-reader hint announced when [WenzRichTextEditor.readOnly] is true.
  final String readOnlyHint;

  /// Optional border color for the focused editor when high contrast is active.
  final Color? highContrastFocusColor;

  /// Border width for the focused editor when high contrast is active.
  final double highContrastFocusWidth;

  String effectiveLabel({required bool readOnly}) =>
      readOnly ? readOnlyLabel : label;

  String effectiveHint({required bool readOnly}) =>
      readOnly ? readOnlyHint : hint;
}

/// Public wrapper for custom atomic block renderers.
///
/// Business [BlockRendererBuilder]s can wrap their widget with this surface so
/// object-block selection, geometry registration, caret anchoring, and debug
/// overlays behave like the built-in image/video/file/embed renderers.
class WenzObjectBlockSurface extends StatelessWidget {
  const WenzObjectBlockSurface({
    super.key,
    required this.renderContext,
    required this.child,
  });

  final BlockRenderContext renderContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _withSelectableObjectBlock(
      renderContext.block,
      renderContext,
      child,
    );
  }
}

class WenzRichTextEditor extends StatefulWidget {
  const WenzRichTextEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.all(16),
    this.blockSpacing = 8,
    this.textStyle,
    this.physics,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.showDebugOverlay = false,
    this.enableIme = true,
    this.blockRenderers,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.findController,
    this.onFindRequested,
    this.onReplaceRequested,
    this.slashMenuController,
    this.accessibility = const WenzRichTextEditorAccessibility(),
  });

  final WenzRichTextController controller;
  final EdgeInsetsGeometry padding;
  final double blockSpacing;
  final TextStyle? textStyle;
  final ScrollPhysics? physics;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;

  /// When true, overlays the active block's id, index, path, and caret offset
  /// for debugging selection behaviour. Does not affect layout or offsets.
  final bool showDebugOverlay;

  /// When true (default), attaches a [TextInput] connection on focus so the
  /// platform IME drives character entry via composition deltas. Set false to
  /// fall back to direct key-event character insertion (used by headless
  /// widget tests that inject characters via [sendKeyEvent]).
  final bool enableIme;

  /// Optional [BlockRendererRegistry]. When `null`, the editor builds a fresh
  /// registry with the built-in default renderers. Pass your own to override
  /// how specific [BlockType]s render (e.g. a real image decoder for image
  /// blocks) or to register business [BlockEmbedNode.embedType] renderers. Use
  /// [installDefaultRenderers] to seed a custom registry with the built-ins
  /// before overriding individual types.
  final BlockRendererRegistry? blockRenderers;

  /// Optional [MediaResolver] that takes over rendering for image/video/file
  /// blocks. The built-in media renderers ask the resolver first and fall back
  /// to the placeholder when it returns `null` (or when no resolver is set).
  /// This is the quick path for real media rendering; for finer control
  /// (e.g. swapping the whole block widget) use [blockRenderers] instead.
  /// Throwing from the resolver is tolerated — the editor falls back to the
  /// placeholder rather than crashing.
  final MediaResolver? mediaResolver;

  /// Optional renderer for inline embeds such as formula / mention. The
  /// built-in text renderers ask this first and use their compact fallback
  /// labels when it returns `null`.
  final InlineEmbedRenderer? inlineEmbedRenderer;

  /// Optional find/replace controller. When provided, the editor paints all
  /// current matches and enables Ctrl/Cmd+F/H shortcut dispatch.
  final WenzFindReplaceController? findController;

  /// Called for Ctrl/Cmd+F when a find surface is available.
  final VoidCallback? onFindRequested;

  /// Called for Ctrl/Cmd+H when a replace surface is available.
  final VoidCallback? onReplaceRequested;

  /// Optional slash-menu controller. When provided, the editor shows the
  /// built-in slash overlay and routes ArrowUp/ArrowDown/Enter/Escape to it
  /// while the menu is open.
  final SlashMenuController? slashMenuController;

  /// Accessibility labels, hints, and high-contrast focus styling.
  final WenzRichTextEditorAccessibility accessibility;

  /// Seeds [registry] with the built-in block renderers for every [BlockType].
  /// Call this on a freshly constructed [BlockRendererRegistry] when you want
  /// to override only a few types while keeping the defaults for the rest:
  ///
  /// ```dart
  /// final registry = BlockRendererRegistry();
  /// WenzRichTextEditor.installDefaultRenderers(registry);
  /// registry.register(BlockType.image, myImageRenderer);
  /// ```
  static void installDefaultRenderers(BlockRendererRegistry registry) {
    registry
      ..register(BlockType.paragraph, _defaultTextBlockRenderer)
      ..register(BlockType.heading, _defaultTextBlockRenderer)
      ..register(BlockType.quote, _defaultTextBlockRenderer)
      ..register(BlockType.listItem, _defaultTextBlockRenderer)
      ..register(BlockType.code, _defaultCodeBlockRenderer)
      ..register(BlockType.image, _defaultImageBlockRenderer)
      ..register(BlockType.table, _defaultTableBlockRenderer)
      ..register(BlockType.divider, _defaultDividerBlockRenderer)
      ..register(BlockType.video, _defaultVideoBlockRenderer)
      ..register(BlockType.embed, _defaultBlockEmbedRenderer)
      ..register(BlockType.callout, _defaultCalloutBlockRenderer)
      ..register(BlockType.file, _defaultFileBlockRenderer);
  }

  @override
  State<WenzRichTextEditor> createState() => _WenzRichTextEditorState();
}

class _WenzRichTextEditorState extends State<WenzRichTextEditor> {
  FocusNode? _internalFocusNode;
  FocusNode? _listenedFocusNode;

  /// The focus node currently registered with the controller, tracked so we can
  /// detect swaps and clear it cleanly on dispose.
  FocusNode? _controllerAttachedFocusNode;

  /// Remembered horizontal column for repeated Up/Down moves, so the caret
  /// keeps its column across multiple line jumps. Cleared on Left/Right/Home/
  /// End/clicks (any horizontal repositioning).
  double? _verticalPreferX;
  int _generatedBlockCount = 0;
  late final EditorTextInputClient _inputClient;
  late final EditorShortcutManager _shortcutManager =
      const EditorShortcutManager();
  late final BlockGeometryRegistry _registry = BlockGeometryRegistry();
  late final ScrollController _scrollController = ScrollController();
  late final SharedTextLayoutCache _layoutCache = SharedTextLayoutCache();
  final GlobalKey _editorOverlayKey = GlobalKey();
  final _BlockExtentCache _extentCache = _BlockExtentCache();
  BlockRendererRegistry? _ownedBlockRenderers;

  /// Guards [_scrollCaretIntoView]'s virtualised estimate-and-realign loop.
  /// Each estimate-driven re-arm increments this; once it exceeds
  /// [_maxScrollRealignFrames] we stop, so a persistently mis-estimated block
  /// height cannot spin the viewport indefinitely.
  int _scrollRealignDepth = 0;
  static const int _maxScrollRealignFrames = 4;

  /// The caret position (block index + offset) at the last scroll-into-view
  /// check. IME composition updates call `notifyListeners` without moving the
  /// caret; remembering the last-checked position lets us skip the (layout +
  /// localToGlobal) scroll check when the caret hasn't moved — a hot path
  /// during pinyin/japanese input.
  _CaretKey? _lastScrollCheckedCaret;
  bool _skipNextCaretScrollIntoView = false;
  bool _inputGeometrySyncPending = false;

  /// The active block renderer registry. When the widget supplies one it is
  /// used as-is; otherwise a private registry with built-in defaults is lazily
  /// created and kept for the widget's lifetime.
  BlockRendererRegistry get _blockRenderers {
    if (widget.blockRenderers != null) {
      return widget.blockRenderers!;
    }
    return _ownedBlockRenderers ??= () {
      final registry = BlockRendererRegistry();
      WenzRichTextEditor.installDefaultRenderers(registry);
      return registry;
    }();
  }

  @override
  void initState() {
    super.initState();
    _inputClient = EditorTextInputClient(widget.controller);
    // The IME bridge asks the widget layer for the caret's global rect so the
    // platform can position its candidate window (e.g. pinyin) at the caret.
    _inputClient.caretRectProvider = () {
      final selection = widget.controller.selection;
      if (selection == null || !selection.isCollapsed) {
        return null;
      }
      return _registry.caretRectForPosition(selection.extent);
    };
    _inputClient.textInputGeometryProvider = () {
      final selection = widget.controller.selection;
      if (selection == null || !selection.isCollapsed) {
        return null;
      }
      final position = selection.extent;
      final composition = widget.controller.compositionState;
      final composingRange = composition != null &&
              composition.blockId == position.blockId &&
              composition.blockIndex == position.blockIndex &&
              composition.path == position.path &&
              !composition.isEmpty
          ? TextRange(
              start: composition.startOffset,
              end: composition.endOffset,
            )
          : null;
      final geometry = _registry.textInputGeometryForPosition(
        position,
        composingRange: composingRange,
      );
      if (geometry == null) {
        return null;
      }
      return EditorTextInputGeometry(
        editableSize: geometry.editableSize,
        transform: geometry.transform,
        caretRect: geometry.caretRect,
        composingRect: geometry.composingRect,
        globalCaretRect: geometry.globalCaretRect,
      );
    };
    // The platform text-input engine rejects a client whose configuration has
    // no viewId (Android throws "view ID is null"). We resolve the current view
    // lazily via the mounted BuildContext so the id stays correct across view
    // reparenting / multi-window.
    _inputClient.viewIdProvider = _resolveViewId;
    _inputClient.performSelectorHandler = _handlePlatformSelector;
    widget.controller.addListener(_handleControllerChanged);
    widget.findController?.addListener(_handleFindControllerChanged);
    widget.slashMenuController?.attachEditor(widget.controller);
    widget.slashMenuController?.addListener(_handleSlashMenuChanged);
    // Expose the focus node to the controller so controller.requestFocus() can
    // drive focus. Updated in _syncFocusListener (which runs each build and on
    // controller/focusNode change).
    final focusNode = _effectiveFocusNode;
    widget.controller.attachFocusNode(focusNode);
    _controllerAttachedFocusNode = focusNode;
    // Ensure owned defaults are installed eagerly when no external registry is
    // provided, mirroring the lazy getter above.
    _blockRenderers;
  }

  @override
  void didUpdateWidget(covariant WenzRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      oldWidget.controller.attachFocusNode(null);
      widget.controller.addListener(_handleControllerChanged);
      _extentCache.clear();
    } else if (oldWidget.textStyle != widget.textStyle ||
        oldWidget.blockRenderers != widget.blockRenderers ||
        oldWidget.mediaResolver != widget.mediaResolver ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
        oldWidget.findController != widget.findController ||
        oldWidget.slashMenuController != widget.slashMenuController) {
      _extentCache.clear();
    }
    if (oldWidget.findController != widget.findController) {
      oldWidget.findController?.removeListener(_handleFindControllerChanged);
      widget.findController?.addListener(_handleFindControllerChanged);
    }
    if (oldWidget.slashMenuController != widget.slashMenuController) {
      oldWidget.slashMenuController?.removeListener(_handleSlashMenuChanged);
      widget.slashMenuController?.attachEditor(widget.controller);
      widget.slashMenuController?.addListener(_handleSlashMenuChanged);
    } else if (oldWidget.controller != widget.controller) {
      widget.slashMenuController?.attachEditor(widget.controller);
    }
    // The effective focus node may change when the caller swaps focusNode or
    // controller; re-inject so controller.requestFocus() targets the right node.
    final focusNode = _effectiveFocusNode;
    if (focusNode != _controllerAttachedFocusNode) {
      widget.controller.attachFocusNode(focusNode);
      _controllerAttachedFocusNode = focusNode;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.findController?.removeListener(_handleFindControllerChanged);
    widget.slashMenuController?.removeListener(_handleSlashMenuChanged);
    // Release the focus node from the controller so a later requestFocus() on
    // a disposed editor is a safe no-op. Only clear when this widget was the
    // one that injected it.
    if (_controllerAttachedFocusNode != null) {
      widget.controller.attachFocusNode(null);
    }
    _controllerAttachedFocusNode = null;
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    _inputClient.performSelectorHandler = null;
    _inputClient.detach();
    _scrollController.dispose();
    // BlockGeometryRegistry holds no native resources; clearing its maps is
    // unnecessary once the editor is gone.
    _layoutCache.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFindControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSlashMenuChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleControllerChanged() {
    if (mounted) {
      // Drop the cached laid-out painter for blocks whose content changed so a
      // stale painter is not reused on the next build. Selection-only /
      // composition-only changes (empty set) do not invalidate anything.
      //
      // The block *extent* cache is intentionally NOT invalidated here. While a
      // block's text is being edited (most acutely during IME composition such
      // as pinyin input) its content mutates on every keystroke, but its height
      // barely changes. Dropping the cached height mid-edit would fall back to
      // the document-wide average height for one frame, repositioning every
      // following block — a visible flicker of the content below the caret. The
      // real (possibly unchanged) height is reconciled on the next frame by the
      // measured-block widget, so leaving the stale value yields one frame of a
      // near-correct height instead of one frame of a wrong average.
      final dirty = widget.controller.lastChangedBlockIds;
      if (dirty == null) {
        _extentCache.clear();
      } else if (dirty.isNotEmpty) {
        for (final id in dirty) {
          _layoutCache.removeBlock(id);
        }
      }
      // Keep the platform IME candidate window anchored at the caret, and
      // scroll a programmatically-moved caret back into view. Both run in a
      // post-frame callback so the caret's render box reflects the latest
      // selection (and any keep-alive mount) before we read its global rect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_inputClient.isAttached) {
          _inputClient.syncBuffer();
        }
        // Bring an off-screen caret into view — but only when it actually
        // moved. IME composition updates fire notifyListeners without changing
        // the caret's position; skipping the scroll check there avoids a
        // layout + localToGlobal round-trip per composition keystroke.
        final selection = widget.controller.selection;
        if (selection?.isCollapsed == true) {
          final skipCaretScroll = _skipNextCaretScrollIntoView;
          _skipNextCaretScrollIntoView = false;
          final caretKey = _CaretKey(
            selection!.extent.blockIndex,
            selection.extent.offset,
          );
          if (caretKey != _lastScrollCheckedCaret) {
            _lastScrollCheckedCaret = caretKey;
            if (!skipCaretScroll) {
              _scrollCaretIntoView();
            }
          }
        } else {
          _skipNextCaretScrollIntoView = false;
          _lastScrollCheckedCaret = null;
        }
      });
      setState(() {});
    }
  }

  void _handleFocusChanged() {
    if (!mounted) {
      return;
    }
    final focusNode = _effectiveFocusNode;
    if (widget.enableIme && focusNode.hasFocus && !widget.readOnly) {
      _inputClient.attach();
    } else {
      _inputClient.detach();
    }
    setState(() {});
  }

  /// Resolves the [FlutterView.viewId] backing this editor for the IME bridge.
  /// Returns `null` when not yet mounted (no [BuildContext]); callers must
  /// tolerate that — the attach path still works on platforms that do not
  /// enforce the viewId contract.
  int? _resolveViewId() {
    if (!mounted) {
      return null;
    }
    final context = this.context;
    return View.maybeOf(context)?.viewId;
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = _effectiveFocusNode;
    _syncFocusListener(focusNode);
    final blocks = widget.controller.document.blocks;
    if (blocks.isEmpty) {
      return _buildEditorShell(
        context,
        focusNode,
        const SizedBox.shrink(),
      );
    }

    // Show a caret only in editable mode. Read-only mode still allows
    // selection (see _handleSelectionChanged) but has no editing caret.
    final showCaret = !widget.readOnly &&
        focusNode.hasFocus &&
        widget.controller.selection?.isCollapsed == true;
    // Blocks that must stay mounted even when scrolled out of view: the caret
    // (collapsed selection) and the selection endpoints. Keeping these alive
    // means the caret and selection highlight always paint and the geometry
    // registry always knows their box, so cross-block selection / caret do not
    // break under virtualisation. Usually resolves to 1-2 ids.
    final keepAliveIds = _keepAliveBlockIds(widget.controller.selection);
    // Block ids whose content changed in the most recent controller mutation.
    // null = treat every block as changed (full rebuild), e.g. after a document
    // replace where no diff was available. Used by _KeepAliveBlock to skip
    // re-rendering blocks whose content + selection-relevance did not change.
    final dirtyIds = widget.controller.lastChangedBlockIds;
    final findMatches =
        widget.findController?.matches ?? const <FindReplaceMatch>[];
    final currentFindMatch = widget.findController?.currentMatch;

    _extentCache.retainBlocks(blocks);

    final editor = _MeasuredVirtualBlockList(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      blocks: blocks,
      blockSpacing: widget.blockSpacing,
      extentCache: _extentCache,
      keepAliveIds: keepAliveIds,
      onExtentUpdated: _scrollCaretIntoViewIfNeeded,
      itemBuilder: (context, i) => _KeepAliveBlock(
        key: ValueKey<String>(blocks[i].id),
        block: blocks[i],
        blockIndex: i,
        keepAlive: keepAliveIds.contains(blocks[i].id),
        blockChanged: dirtyIds == null || dirtyIds.contains(blocks[i].id),
        selection: widget.controller.selection,
        compositionState: widget.controller.compositionState,
        registry: _registry,
        blockRenderers: _blockRenderers,
        showCaret: showCaret,
        textStyle: widget.textStyle,
        showDebugOverlay: widget.showDebugOverlay,
        mediaResolver: widget.mediaResolver,
        inlineEmbedRenderer: widget.inlineEmbedRenderer,
        onCodeLanguageChanged: widget.readOnly
            ? null
            : (language) {
                widget.controller.setCodeLanguage(language, blockIndex: i);
              },
        onCodeCopied: _copyTextToClipboard,
        onCalloutVariantChanged: widget.readOnly
            ? null
            : (variant) {
                widget.controller.setCalloutVariant(variant, blockIndex: i);
              },
        onTableToolbarAction:
            widget.readOnly ? null : _handleTableToolbarAction,
        onTableColumnResize: widget.readOnly ? null : _handleTableColumnResize,
        findMatches: findMatches,
        currentFindMatch: currentFindMatch,
      ),
    );
    return _buildEditorShell(
      context,
      focusNode,
      Stack(
        key: _editorOverlayKey,
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          SelectionGestureOverlay(
            registry: _registry,
            scrollController: _scrollController,
            focusNode: focusNode,
            readOnly: widget.readOnly,
            onSelectionChanged: _handleSelectionChanged,
            onTapBeyondContent: _handleTapBeyondContent,
            child: editor,
          ),
          if (widget.slashMenuController?.isOpen == true)
            Positioned(
              left: _slashMenuOffset().dx,
              top: _slashMenuOffset().dy,
              child: WenzSlashMenuOverlay(
                controller: widget.slashMenuController!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorShell(
    BuildContext context,
    FocusNode focusNode,
    Widget child,
  ) {
    return _SharedLayoutCacheScope(
      cache: _layoutCache,
      child: Focus(
        focusNode: focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _handleKeyEvent,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          enabled: true,
          textField: true,
          readOnly: widget.readOnly,
          focusable: true,
          focused: focusNode.hasFocus,
          multiline: true,
          label: widget.accessibility.effectiveLabel(readOnly: widget.readOnly),
          hint: widget.accessibility.effectiveHint(readOnly: widget.readOnly),
          onTap: () => focusNode.requestFocus(),
          onFocus: () => focusNode.requestFocus(),
          child: _withHighContrastFocusHighlight(context, focusNode, child),
        ),
      ),
    );
  }

  Widget _withHighContrastFocusHighlight(
    BuildContext context,
    FocusNode focusNode,
    Widget child,
  ) {
    final accessibility = widget.accessibility;
    if (!focusNode.hasFocus ||
        !(MediaQuery.maybeHighContrastOf(context) ?? false) ||
        accessibility.highContrastFocusWidth == 0) {
      return child;
    }
    return DecoratedBox(
      key: _accessibilityFocusHighlightKey,
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: accessibility.highContrastFocusColor ??
              Theme.of(context).colorScheme.primary,
          width: accessibility.highContrastFocusWidth,
        ),
      ),
      child: child,
    );
  }

  Offset _slashMenuOffset() {
    final fallback = widget.padding.resolve(TextDirection.ltr).topLeft;
    final selection = widget.controller.selection;
    final overlayContext = _editorOverlayKey.currentContext;
    final overlayBox = overlayContext?.findRenderObject();
    if (selection == null ||
        !selection.isCollapsed ||
        overlayBox is! RenderBox ||
        !overlayBox.hasSize) {
      return fallback;
    }
    final caret = _registry.caretRectForPosition(selection.extent);
    if (caret == null) {
      return fallback;
    }
    final local = overlayBox.globalToLocal(caret.bottomLeft);
    final maxLeft = overlayBox.size.width - 280;
    return Offset(
      local.dx.clamp(0, maxLeft > 0 ? maxLeft : 0).toDouble(),
      (local.dy + 6).clamp(0, overlayBox.size.height).toDouble(),
    );
  }

  void _handleSelectionChanged(DocumentSelection selection) {
    _skipNextCaretScrollIntoView = true;
    widget.controller.setSelection(selection);
    // A selection change from the gesture overlay repositions the caret, so
    // refresh the IME buffer so the platform input follows the new location.
    _inputClient.syncBuffer();
  }

  bool _handleTapBeyondContent(Offset _) {
    if (widget.readOnly) {
      return false;
    }
    final blocks = widget.controller.document.blocks;
    if (blocks.isEmpty) {
      return false;
    }
    final last = blocks.last;
    if (last is TextBlockNode || last is CodeBlockNode) {
      return false;
    }

    final nextBlockId = _nextBlockId();
    final nextBlockIndex = blocks.length;
    final nextPosition = DocumentPosition.text(
      blockId: nextBlockId,
      blockIndex: nextBlockIndex,
      offset: 0,
    );
    final nextSelection =
        DocumentSelection(base: nextPosition, extent: nextPosition);
    _skipNextCaretScrollIntoView = true;
    widget.controller.insertBlocks(
      index: nextBlockIndex,
      blocks: <BlockNode>[
        TextBlockNode(
          id: nextBlockId,
          type: BlockType.paragraph,
          content: const <InlineNode>[],
        ),
      ],
      selection: nextSelection,
    );
    _inputClient.syncBuffer();
    return true;
  }

  void _handleTableToolbarAction(TableToolbarActionIntent intent) {
    final tableBlock = _tableBlockAt(intent.blockIndex);
    if (tableBlock == null) {
      return;
    }

    final range = _currentTableRange(tableBlock, intent) ??
        TableCellRange(
          tableBlockId: tableBlock.id,
          blockIndex: intent.blockIndex,
          startRow: intent.rowIndex,
          endRow: intent.targetEndRowIndex,
          startColumn: intent.columnIndex,
          endColumn: intent.targetEndColumnIndex,
        );

    switch (intent.action) {
      case TableToolbarAction.insertRowAbove:
        widget.controller.insertTableRow(
          blockIndex: intent.blockIndex,
          rowIndex: range.startRow,
        );
        return;
      case TableToolbarAction.insertRowBelow:
        widget.controller.insertTableRow(
          blockIndex: intent.blockIndex,
          rowIndex: range.endRow + 1,
        );
        return;
      case TableToolbarAction.deleteRow:
        for (var row = range.endRow; row >= range.startRow; row--) {
          final current = _tableBlockAt(intent.blockIndex);
          if (current == null || current.table.rowCount <= 1) {
            break;
          }
          widget.controller.deleteTableRow(
            blockIndex: intent.blockIndex,
            rowIndex: row,
          );
        }
        return;
      case TableToolbarAction.insertColumnBefore:
        widget.controller.insertTableColumn(
          blockIndex: intent.blockIndex,
          columnIndex: range.startColumn,
        );
        return;
      case TableToolbarAction.insertColumnAfter:
        widget.controller.insertTableColumn(
          blockIndex: intent.blockIndex,
          columnIndex: range.endColumn + 1,
        );
        return;
      case TableToolbarAction.deleteColumn:
        for (var column = range.endColumn;
            column >= range.startColumn;
            column--) {
          final current = _tableBlockAt(intent.blockIndex);
          if (current == null || current.table.columnCount <= 1) {
            break;
          }
          widget.controller.deleteTableColumn(
            blockIndex: intent.blockIndex,
            columnIndex: column,
          );
        }
        return;
      case TableToolbarAction.toggleHeader:
        final anchor = _firstVisibleTableCell(tableBlock, range);
        if (anchor == null) {
          return;
        }
        final nextHeader = !anchor.isHeader;
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellHeader(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            isHeader: nextHeader,
          );
        });
        return;
      case TableToolbarAction.setBackgroundColor:
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellBackground(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            backgroundColor: intent.backgroundColor,
          );
        });
        return;
      case TableToolbarAction.clearBackgroundColor:
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellBackground(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            backgroundColor: null,
          );
        });
        return;
      case TableToolbarAction.alignLeft:
        _setTableColumnAlignment(intent.blockIndex, range, 'left');
        return;
      case TableToolbarAction.alignCenter:
        _setTableColumnAlignment(intent.blockIndex, range, 'center');
        return;
      case TableToolbarAction.alignRight:
        _setTableColumnAlignment(intent.blockIndex, range, 'right');
        return;
      case TableToolbarAction.clearAlignment:
        _setTableColumnAlignment(intent.blockIndex, range, null);
        return;
      case TableToolbarAction.mergeCells:
        if (!range.isSingleCell) {
          widget.controller.mergeTableCells(
            blockIndex: intent.blockIndex,
            startRow: range.startRow,
            startColumn: range.startColumn,
            endRow: range.endRow,
            endColumn: range.endColumn,
          );
        }
        return;
      case TableToolbarAction.splitCell:
        widget.controller.splitTableCell(
          blockIndex: intent.blockIndex,
          rowIndex: range.startRow,
          columnIndex: range.startColumn,
        );
        return;
      case TableToolbarAction.resetColumnWidth:
        for (var column = range.startColumn;
            column <= range.endColumn;
            column++) {
          widget.controller.setTableColumnWidth(
            blockIndex: intent.blockIndex,
            columnIndex: column,
            width: null,
          );
        }
        return;
    }
  }

  void _handleTableColumnResize({
    required int blockIndex,
    required int columnIndex,
    required double width,
  }) {
    final tableBlock = _tableBlockAt(blockIndex);
    if (tableBlock == null ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount) {
      return;
    }
    widget.controller.setTableColumnWidth(
      blockIndex: blockIndex,
      columnIndex: columnIndex,
      width:
          width.clamp(_kMinTableColumnWidth, _kMaxTableColumnWidth).toDouble(),
    );
  }

  TableBlockNode? _tableBlockAt(int blockIndex) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    final block = blocks[blockIndex];
    return block is TableBlockNode ? block : null;
  }

  TableCellRange? _currentTableRange(
    TableBlockNode tableBlock,
    TableToolbarActionIntent intent,
  ) {
    final range = widget.controller.selection?.tableCellRange;
    if (range == null ||
        range.blockIndex != intent.blockIndex ||
        range.tableBlockId != tableBlock.id) {
      return null;
    }
    return range;
  }

  void _forEachVisibleTableCell(
    TableBlockNode tableBlock,
    TableCellRange range,
    void Function(int row, int column) visit,
  ) {
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = tableBlock.table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        visit(row, column);
      }
    }
  }

  TableCellNode? _firstVisibleTableCell(
    TableBlockNode tableBlock,
    TableCellRange range,
  ) {
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = tableBlock.table.cellAt(row, column);
        if (cell != null && !cell.covered) {
          return cell;
        }
      }
    }
    return null;
  }

  void _setTableColumnAlignment(
    int blockIndex,
    TableCellRange range,
    String? alignment,
  ) {
    for (var column = range.startColumn; column <= range.endColumn; column++) {
      widget.controller.setTableColumnAlignment(
        blockIndex: blockIndex,
        columnIndex: column,
        alignment: alignment,
      );
    }
  }

  /// Block ids that must stay mounted under virtualisation: the caret block
  /// (collapsed selection) and the selection endpoints. Keeping these alive
  /// guarantees the caret/selection highlight always paint and the geometry
  /// registry always knows their box. Returns an empty set when there is no
  /// selection.
  Set<String> _keepAliveBlockIds(DocumentSelection? selection) {
    if (selection == null) {
      return <String>{};
    }
    return <String>{
      selection.base.blockId,
      selection.extent.blockId,
    };
  }

  FocusNode get _effectiveFocusNode {
    return widget.focusNode ??
        (_internalFocusNode ??= FocusNode(debugLabel: 'WenzRichTextEditor'));
  }

  void _syncFocusListener(FocusNode focusNode) {
    if (_listenedFocusNode == focusNode) {
      return;
    }
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    focusNode.addListener(_handleFocusChanged);
    _listenedFocusNode = focusNode;
    // Keep the controller's injected node in sync so requestFocus() targets the
    // currently effective focus node even after a swap.
    widget.controller.attachFocusNode(focusNode);
    _controllerAttachedFocusNode = focusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _listenedFocusNode == focusNode) {
        _handleFocusChanged();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_handleSlashMenuKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    if (_handleCodeBlockTabKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final resolution = _shortcutManager.resolve(
      event,
      shiftPressed: keyboard.isShiftPressed,
      primaryPressed: keyboard.isControlPressed || keyboard.isMetaPressed,
      readOnly: widget.readOnly,
      imeEnabled: widget.enableIme,
      inputClientAttached: _inputClient.isAttached,
      findEnabled:
          widget.findController != null || widget.onFindRequested != null,
      replaceEnabled:
          widget.findController != null || widget.onReplaceRequested != null,
    );
    if (resolution.disposition == EditorShortcutDisposition.handled) {
      _performShortcut(resolution);
      return KeyEventResult.handled;
    }
    if (resolution.disposition == EditorShortcutDisposition.ignored) {
      return KeyEventResult.ignored;
    }
    // Unrecognised Ctrl/Cmd combo: let it propagate (e.g. browser Ctrl+S,
    // dev tools) rather than swallowing everything.
    return KeyEventResult.ignored;
  }

  bool _handleCodeBlockTabKeyEvent(KeyEvent event) {
    if (widget.readOnly ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return false;
    }
    final selection = widget.controller.selection;
    if (selection == null ||
        selection.start.blockIndex != selection.end.blockIndex ||
        selection.start.path != selection.end.path ||
        !selection.start.path.isBlockCode) {
      return false;
    }
    if (selection.start.blockIndex < 0 ||
        selection.start.blockIndex >=
            widget.controller.document.blocks.length) {
      return false;
    }
    final block = widget.controller.document.blocks[selection.start.blockIndex];
    if (block is! CodeBlockNode) {
      return false;
    }
    widget.controller.indentCodeBlock(
      outdent: HardwareKeyboard.instance.isShiftPressed,
    );
    return true;
  }

  bool _handleSlashMenuKeyEvent(KeyEvent event) {
    final slashMenu = widget.slashMenuController;
    if (slashMenu == null || !slashMenu.isOpen) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      slashMenu.moveHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      slashMenu.moveHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      slashMenu.activateHighlighted();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      slashMenu.close();
      return true;
    }
    return false;
  }

  void _performShortcut(EditorShortcutResolution resolution) {
    final controller = widget.controller;
    switch (resolution.intent) {
      case EditorShortcutIntent.selectAll:
        controller.selectAll();
        return;
      case EditorShortcutIntent.undo:
        controller.undo();
        return;
      case EditorShortcutIntent.redo:
        controller.redo();
        return;
      case EditorShortcutIntent.copy:
        _handleCopy();
        return;
      case EditorShortcutIntent.cut:
        _handleCut();
        return;
      case EditorShortcutIntent.paste:
        _handlePaste();
        return;
      case EditorShortcutIntent.find:
        widget.onFindRequested?.call();
        widget.findController?.next();
        return;
      case EditorShortcutIntent.replace:
        widget.onReplaceRequested?.call();
        return;
      case EditorShortcutIntent.moveTableCellBackward:
        controller.moveTableCell(forward: false);
        return;
      case EditorShortcutIntent.moveTableCellForward:
        controller.moveTableCell(forward: true);
        return;
      case EditorShortcutIntent.moveCaretBackward:
        _verticalPreferX = null;
        controller.moveCaretBackward(
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretForward:
        _verticalPreferX = null;
        controller.moveCaretForward(
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretUp:
        _handleVerticalKey(false, resolution.expandSelection);
        return;
      case EditorShortcutIntent.moveCaretDown:
        _handleVerticalKey(true, resolution.expandSelection);
        return;
      case EditorShortcutIntent.moveCaretToBlockStart:
        controller.moveCaretToBlockBoundary(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToBlockEnd:
        controller.moveCaretToBlockBoundary(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretByWordBackward:
        controller.moveCaretByWord(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretByWordForward:
        controller.moveCaretByWord(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToDocumentStart:
        controller.moveCaretToDocumentBoundary(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToDocumentEnd:
        controller.moveCaretToDocumentBoundary(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.pageUp:
        _handlePageKey(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.pageDown:
        _handlePageKey(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.deleteBackward:
        if (!_deleteActiveSelectionIfAny()) {
          controller.deleteBackward();
        }
        return;
      case EditorShortcutIntent.deleteForward:
        if (!_deleteActiveSelectionIfAny()) {
          controller.deleteForward();
        }
        return;
      case EditorShortcutIntent.enter:
        controller.enter(newBlockId: _nextBlockId());
        return;
      case EditorShortcutIntent.insertCharacter:
        final character = resolution.character;
        if (character != null) {
          controller.insertText(character);
        }
        return;
      case null:
        return;
    }
  }

  /// Handles PageUp/PageDown: scrolls the content by exactly one viewport (a
  /// "page") and moves the caret by the same amount through the document, so
  /// repeated paging advances one page each press and the caret keeps both its
  /// horizontal column and its relative screen position.
  ///
  /// `forward` = true → PageDown, false → PageUp. When [expandSelection] is
  /// true the anchor stays put and only the extent moves. Falls back to
  /// block-boundary motion when no viewport / caret geometry is available
  /// (e.g. headless tests).
  ///
  /// The caret target is measured in the document's content (scroll) space —
  /// caret Y ± one viewport — and is *not* clamped to the current viewport.
  /// Clamping there was the old bug: it pinned the caret at the viewport edge
  /// and then jumped to the document end on the next press.
  ///
  /// Resolution is split in two:
  /// 1. When the target lands inside the currently-mounted content (the common
  ///    case — a short doc, or a page that stays within the built range) the
  ///    caret is placed synchronously right after the one-page scroll jump.
  /// 2. When the target overshoots the mounted range (a tall, virtualised
  ///    document) the one-page scroll is applied first and the caret is placed
  ///    on the next frame, once the target block is built. Only an actual
  ///    scroll change schedules that frame, so there is always a frame to run
  ///    the deferred place.
  void _handlePageKey({required bool forward, required bool expandSelection}) {
    final controller = widget.controller;
    final selection = controller.selection;
    if (selection == null) {
      controller.moveCaretToBlockBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
      return;
    }
    final caretRect = _registry.caretRectForPosition(selection.extent);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (caretRect == null ||
        renderBox == null ||
        !renderBox.hasSize ||
        !_scrollController.hasClients) {
      // No layout/viewport available: fall back to block-boundary motion so
      // the key still does something predictable (matches prior behaviour).
      controller.moveCaretToBlockBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
      return;
    }
    final scrollPosition = _scrollController.position;
    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    final viewportHeight = renderBox.size.height;
    // Preserve the caret's horizontal column across the page jump so repeated
    // PageUp/PageDown keep the same x position.
    final caretX = caretRect.left;
    // Caret Y in the document's content (scroll) coordinate space: pixels from
    // the top of the full scrollable content.
    final caretContentY = caretRect.top - viewportTop + scrollPosition.pixels;
    // Move exactly one viewport ("page") through the content in the travel
    // direction. Measured in content space, so it is independent of where the
    // viewport currently sits.
    final targetContentY = forward
        ? caretContentY + viewportHeight
        : caretContentY - viewportHeight;

    // The document's content extent in content space: the bottom of the last
    // mounted block. When a page jump overshoots this the caret should go to
    // the document end rather than the (ambiguous) nearest block.
    final globalBottom = _registry.contentExtent();
    final contentExtent = globalBottom == null
        ? null
        : globalBottom - viewportTop + scrollPosition.pixels;
    final beyondDocument = contentExtent == null ||
        (forward && targetContentY >= contentExtent) ||
        (!forward && targetContentY <= 0);

    // Scroll one page so the caret target stays at the same screen offset and
    // the surrounding context stays visible across the jump.
    final pageScroll = (forward
            ? scrollPosition.pixels + viewportHeight
            : scrollPosition.pixels - viewportHeight)
        .clamp(0.0, scrollPosition.maxScrollExtent);
    final scrollChanged = _jumpToScrollOffset(pageScroll.toDouble());

    if (beyondDocument) {
      // A page that overshoots the document: place the caret at the document
      // boundary. Resolve the boundary position via the registry so a plain
      // page yields a collapsed caret (moveCaretToDocumentBoundary would keep
      // the pre-move range end as the anchor, producing a selection range).
      final boundaryContentY =
          forward ? (contentExtent ?? targetContentY) : 0.0;
      final boundaryGlobalY =
          boundaryContentY - scrollPosition.pixels + viewportTop;
      final boundary = _registry.positionFromGlobalOffset(
        Offset(caretX, boundaryGlobalY),
      );
      if (boundary == null) {
        controller.moveCaretToDocumentBoundary(
          forward: forward,
          expandSelection: expandSelection,
        );
      } else {
        final next = expandSelection
            ? DocumentSelection(base: selection.base, extent: boundary)
            : DocumentSelection(base: boundary, extent: boundary);
        controller.setSelection(next);
      }
      _scrollCaretIntoView();
      return;
    }

    if (!scrollChanged) {
      // The scroll did not move (nothing to scroll): the target block is
      // already mounted, so resolve and place the caret synchronously.
      _placeCaretAtContentY(
        caretX: caretX,
        contentY: targetContentY,
        forward: forward,
        expandSelection: expandSelection,
        base: selection.base,
        previousExtent: selection.extent,
      );
      return;
    }
    // The scroll moved — under virtualisation the target block mounts on the
    // next frame, so place the caret then. Only an actual scroll schedules a
    // frame, guaranteeing the deferred place runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _placeCaretAtContentY(
        caretX: caretX,
        contentY: targetContentY,
        forward: forward,
        expandSelection: expandSelection,
        base: selection.base,
        previousExtent: selection.extent,
      );
    });
  }

  /// Resolves the caret position at content-space Y [contentY] (pixels from the
  /// top of the full scrollable content), sets the selection, then pixel-realigns
  /// the scroll. Used by [_handlePageKey] either synchronously (short doc /
  /// target within the mounted range) or on the frame after a one-page scroll
  /// (tall, virtualised document whose target block needs building).
  void _placeCaretAtContentY({
    required double caretX,
    required double contentY,
    required bool forward,
    required bool expandSelection,
    required DocumentPosition base,
    required DocumentPosition previousExtent,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final position = _scrollController.position;
    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    // Content Y → global Y under the current scroll offset.
    final globalY = contentY - position.pixels + viewportTop;
    final target = _registry.positionFromGlobalOffset(Offset(caretX, globalY));
    if (target == null || target == previousExtent) {
      // Target off the mounted range or already there: move to the document
      // boundary so the caret still advances as far as it can.
      widget.controller.moveCaretToDocumentBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
    } else {
      final next = expandSelection
          ? DocumentSelection(base: base, extent: target)
          : DocumentSelection(base: target, extent: target);
      widget.controller.setSelection(next);
    }
    _scrollCaretIntoView();
  }

  /// Re-evaluates whether the caret needs to be scrolled into view after a
  /// block's measured extent was updated. When content grows (e.g. pasting
  /// several lines), the mutation frame still carries the pre-edit block
  /// height, so the caret-into-view check run then may decide "already visible"
  /// and record the position as handled. Once the real height lands a frame
  /// later, the caret may have ended up off-screen; this re-arms the check so
  /// it runs again against the accurate layout.
  ///
  /// The check is deferred to a post-frame callback because the extent update
  /// arrives via a `setState` in the virtual list, whose re-layout (which
  /// updates `maxScrollExtent` and caret geometry) only completes on the next
  /// frame. Running it synchronously would observe the pre-update layout.
  void _scrollCaretIntoViewIfNeeded() {
    if (!mounted) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection?.isCollapsed != true) {
      return;
    }
    _lastScrollCheckedCaret = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollCaretIntoView();
      }
    });
  }

  /// Scrolls the scrollable just enough to bring the current caret into view.
  /// Used after PageUp/PageDown jumps and after programmatic selection
  /// changes. No-op when the caret is already visible or no scroll client is
  /// attached.
  ///
  /// Under virtualisation the caret's block may not be mounted yet (it has
  /// never entered the viewport), in which case we cannot read its pixel
  /// position. We fall back to an estimate — mean block height × target block
  /// index — to jump the viewport close enough for ListView to build the
  /// block; a follow-up frame then pixel-aligns via the now-available rect.
  void _scrollCaretIntoView() {
    if (!_scrollController.hasClients) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final caretRect = _registry.caretRectForPosition(selection.extent);
    final position = _scrollController.position;
    final viewportHeight = renderBox.size.height;

    if (caretRect == null) {
      // The caret's block is not laid out (virtualised out of view). Estimate
      // the scroll offset from the average built-block height so the viewport
      // jumps near the target; the next frame will pixel-align once the block
      // is mounted.
      final estimated = _estimateOffsetForBlock(
        selection.extent.blockIndex,
        viewportHeight: viewportHeight,
      );
      if (estimated != null && (estimated - position.pixels).abs() > 1) {
        _jumpToScrollOffset(estimated);
        // Re-run on the next frame so the freshly-mounted block's rect is
        // available for pixel-accurate alignment. Bound the re-arm depth so a
        // persistently mis-estimated block height cannot loop forever.
        _scrollRealignDepth += 1;
        if (_scrollRealignDepth <= _maxScrollRealignFrames) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollCaretIntoView();
            }
          });
        }
      }
      return;
    }
    // A real rect resolved — the estimate loop has converged (or was never
    // needed). Reset the guard for the next programmatic jump.
    _scrollRealignDepth = 0;

    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    // Convert the caret's global Y into the scrollable's content coordinate
    // (pixels from the top of the full content).
    final caretTopInContent = caretRect.top - viewportTop + position.pixels;
    final caretBottomInContent = caretTopInContent + caretRect.height;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + viewportHeight;
    if (caretTopInContent >= visibleTop &&
        caretBottomInContent <= visibleBottom) {
      return;
    }
    double target;
    if (caretTopInContent < visibleTop) {
      // Caret is above the viewport: align it with the top edge.
      target = caretTopInContent;
    } else {
      // Caret is below the viewport: align its bottom with the viewport's
      // bottom edge.
      target = caretBottomInContent - viewportHeight;
    }
    _jumpToScrollOffset(target);
  }

  /// Estimates the scroll offset that brings [blockIndex] into view, using the
  /// cached measured height for each block when available and a measured
  /// average for blocks the user has not visited yet.
  double? _estimateOffsetForBlock(
    int blockIndex, {
    required double viewportHeight,
  }) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    // Offset so the target block sits near the top of the viewport. We aim
    // one third down from the top so the surrounding context is visible.
    final targetBlockTop =
        _extentCache.offsetFor(blocks, blockIndex, widget.blockSpacing);
    return targetBlockTop - viewportHeight / 3;
  }

  /// Handles Up/Down arrow keys: visual-line motion within a block (keeping the
  /// horizontal column), crossing to the neighbouring block at a boundary, and
  /// exiting a table cell at the table's first/last row.
  void _handleVerticalKey(bool forward, bool shift) {
    final controller = widget.controller;
    final selection = controller.selection;
    if (selection == null) {
      return;
    }
    final extent = selection.extent;

    // Table cells: try intra-table row navigation first.
    if (extent.path.isTableCellText && !shift) {
      final before = controller.selection;
      controller.moveTableCellVertical(forward: forward);
      if (controller.selection != before) {
        // Moved within the table.
        return;
      }
      // On the table boundary row: fall through to cross-block exit.
      controller.moveCaretVertical(forward: forward, expandSelection: shift);
      _verticalPreferX = null;
      return;
    }

    // Plain text/code blocks: visual-line motion via the layout service.
    // preferX is in the block's LOCAL coordinate space; null lets the layout
    // use the caret's own local x on the first press.
    final result = _registry.verticalMoveForPosition(
      extent,
      forward,
      preferX: _verticalPreferX,
    );
    final target = result?.targetOffset;
    if (target != null) {
      // Remember the local column for repeated vertical moves.
      _verticalPreferX = result?.caretX ?? _verticalPreferX;
      final next = extent.copyWith(offset: target);
      controller.setSelection(
        shift
            ? DocumentSelection(base: selection.base, extent: next)
            : DocumentSelection(base: next, extent: next),
      );
      return;
    }
    // At the block's first/last visual line: cross to the neighbour.
    _verticalPreferX = null;
    controller.moveCaretVertical(forward: forward, expandSelection: shift);
  }

  void _handlePlatformSelector(String selectorName) {
    final syncAfter = _performPlatformSelector(selectorName);
    if (syncAfter) {
      _inputClient.syncBuffer();
    }
  }

  bool _performPlatformSelector(String selectorName) {
    final controller = widget.controller;
    switch (selectorName) {
      case 'copy:':
        _runSelectorFuture(_handleCopy());
        return true;
      case 'selectAll:':
        controller.selectAll();
        return true;
      case 'moveLeft:':
      case 'moveBackward:':
        _verticalPreferX = null;
        controller.moveCaretBackward();
        return true;
      case 'moveRight:':
      case 'moveForward:':
        _verticalPreferX = null;
        controller.moveCaretForward();
        return true;
      case 'moveLeftAndModifySelection:':
      case 'moveBackwardAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretBackward(expandSelection: true);
        return true;
      case 'moveRightAndModifySelection:':
      case 'moveForwardAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretForward(expandSelection: true);
        return true;
      case 'moveUp:':
        _handleVerticalKey(false, false);
        return true;
      case 'moveDown:':
        _handleVerticalKey(true, false);
        return true;
      case 'moveUpAndModifySelection:':
        _handleVerticalKey(false, true);
        return true;
      case 'moveDownAndModifySelection:':
        _handleVerticalKey(true, true);
        return true;
      case 'moveWordLeft:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: false);
        return true;
      case 'moveWordRight:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: true);
        return true;
      case 'moveWordLeftAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: false, expandSelection: true);
        return true;
      case 'moveWordRightAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: true, expandSelection: true);
        return true;
      case 'moveToBeginningOfParagraph:':
      case 'moveToLeftEndOfLine:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(forward: false);
        return true;
      case 'moveToEndOfParagraph:':
      case 'moveToRightEndOfLine:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(forward: true);
        return true;
      case 'moveParagraphBackwardAndModifySelection:':
      case 'moveToLeftEndOfLineAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(
          forward: false,
          expandSelection: true,
        );
        return true;
      case 'moveParagraphForwardAndModifySelection:':
      case 'moveToRightEndOfLineAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(
          forward: true,
          expandSelection: true,
        );
        return true;
      case 'moveToBeginningOfDocument:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(forward: false);
        return true;
      case 'moveToEndOfDocument:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(forward: true);
        return true;
      case 'moveToBeginningOfDocumentAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(
          forward: false,
          expandSelection: true,
        );
        return true;
      case 'moveToEndOfDocumentAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(
          forward: true,
          expandSelection: true,
        );
        return true;
      case 'scrollToBeginningOfDocument:':
        _scrollToDocumentBoundary(forward: false);
        return false;
      case 'scrollToEndOfDocument:':
        _scrollToDocumentBoundary(forward: true);
        return false;
      case 'scrollPageUp:':
        _scrollPage(forward: false);
        return false;
      case 'scrollPageDown:':
        _scrollPage(forward: true);
        return false;
      case 'pageUpAndModifySelection:':
        _handlePageKey(forward: false, expandSelection: true);
        return true;
      case 'pageDownAndModifySelection:':
        _handlePageKey(forward: true, expandSelection: true);
        return true;
      case 'cancelOperation:':
        controller.setCompositionState(null);
        return true;
    }

    if (widget.readOnly) {
      return false;
    }
    switch (selectorName) {
      case 'deleteBackward:':
        if (!_deleteActiveSelectionIfAny()) {
          controller.deleteBackward();
        }
        return true;
      case 'deleteForward:':
        if (!_deleteActiveSelectionIfAny()) {
          controller.deleteForward();
        }
        return true;
      case 'deleteWordBackward:':
        _deleteByWord(forward: false);
        return true;
      case 'deleteWordForward:':
        _deleteByWord(forward: true);
        return true;
      case 'deleteToBeginningOfLine:':
        _deleteToBlockBoundary(forward: false);
        return true;
      case 'deleteToEndOfLine:':
        _deleteToBlockBoundary(forward: true);
        return true;
      case 'cut:':
        _runSelectorFuture(_handleCut());
        return true;
      case 'paste:':
        _runSelectorFuture(_handlePaste());
        return true;
      case 'insertTab:':
        controller.moveTableCell(forward: true);
        return true;
      case 'insertBacktab:':
        controller.moveTableCell(forward: false);
        return true;
    }
    return false;
  }

  bool _deleteActiveSelectionIfAny() {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      return false;
    }
    widget.controller.deleteSelection(selection);
    _inputClient.syncBuffer();
    return true;
  }

  void _deleteByWord({required bool forward}) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    if (!selection.isCollapsed) {
      widget.controller.deleteSelection();
      return;
    }
    widget.controller.moveCaretByWord(
      forward: forward,
      expandSelection: true,
    );
    widget.controller.deleteSelection();
  }

  void _deleteToBlockBoundary({required bool forward}) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    if (!selection.isCollapsed) {
      widget.controller.deleteSelection();
      return;
    }
    widget.controller.moveCaretToBlockBoundary(
      forward: forward,
      expandSelection: true,
    );
    widget.controller.deleteSelection();
  }

  void _scrollToDocumentBoundary({required bool forward}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    _jumpToScrollOffset(forward ? position.maxScrollExtent : 0);
  }

  void _scrollPage({required bool forward}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final delta = position.viewportDimension;
    final target = position.pixels + (forward ? delta : -delta);
    _jumpToScrollOffset(target);
  }

  bool _jumpToScrollOffset(double target) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    final next = target.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((next - position.pixels).abs() <= 0.5) {
      return false;
    }
    position.jumpTo(next);
    _scheduleInputGeometrySync();
    return true;
  }

  void _scheduleInputGeometrySync() {
    if (_inputGeometrySyncPending) {
      return;
    }
    _inputGeometrySyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputGeometrySyncPending = false;
      if (!mounted || !_inputClient.isAttached) {
        return;
      }
      _inputClient.syncBuffer();
    });
  }

  void _runSelectorFuture(Future<void> future) {
    unawaited(
      future.whenComplete(() {
        if (mounted) {
          _inputClient.syncBuffer();
        }
      }),
    );
  }

  Future<void> _handleCopy() async {
    final payload = widget.controller.copySelection();
    if (payload == null) {
      return;
    }
    await _copyTextToClipboard(payload);
  }

  Future<void> _handleCut() async {
    final payload = widget.controller.cutSelection();
    if (payload == null) {
      return;
    }
    await _copyTextToClipboard(payload);
  }

  Future<void> _copyTextToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    widget.controller.pasteText(text);
  }

  String _nextBlockId() {
    _generatedBlockCount += 1;
    return 'block-${DateTime.now().microsecondsSinceEpoch}-$_generatedBlockCount';
  }
}

class _BlockExtentCache {
  final Map<String, double> _extents = <String, double>{};
  final Map<String, int> _blockVersions = <String, int>{};
  Set<String> _knownBlockIds = <String>{};
  int _epoch = 0;
  double? _contentWidth;

  void clear() {
    _epoch += 1;
    _extents.clear();
  }

  void updateContentWidth(double? width) {
    if (width == null || !width.isFinite || width < 0) {
      return;
    }
    final previous = _contentWidth;
    if (previous != null && (previous - width).abs() <= 0.5) {
      return;
    }
    _contentWidth = width;
    clear();
  }

  void removeBlock(String blockId) {
    _extents.remove(blockId);
    _blockVersions[blockId] = (_blockVersions[blockId] ?? 0) + 1;
  }

  void retainBlocks(List<BlockNode> blocks) {
    final ids = blocks.map((block) => block.id).toSet();
    for (final id in _knownBlockIds.difference(ids)) {
      removeBlock(id);
    }
    _knownBlockIds = ids;
    _extents.removeWhere((id, _) => !ids.contains(id));
  }

  int tokenFor(String blockId) {
    return Object.hash(_epoch, _blockVersions[blockId] ?? 0);
  }

  bool record(String blockId, int token, double extent) {
    if (token != tokenFor(blockId)) {
      return false;
    }
    if (!extent.isFinite || extent <= 0) {
      return false;
    }
    final previous = _extents[blockId];
    if (previous != null && (previous - extent).abs() <= 0.5) {
      return false;
    }
    _extents[blockId] = extent;
    return true;
  }

  double get averageExtent {
    if (_extents.isEmpty) {
      return _kDefaultBlockExtent;
    }
    final total = _extents.values.fold<double>(0, (sum, h) => sum + h);
    return total / _extents.length;
  }

  double extentFor(BlockNode block) {
    return _extents[block.id] ?? averageExtent;
  }

  double offsetFor(List<BlockNode> blocks, int blockIndex, double spacing) {
    var offset = 0.0;
    final safeIndex = blockIndex.clamp(0, blocks.length).toInt();
    for (var i = 0; i < safeIndex; i++) {
      offset += extentFor(blocks[i]);
      if (i < blocks.length - 1) {
        offset += spacing;
      }
    }
    return offset;
  }

  _BlockLayoutMetrics layoutFor(List<BlockNode> blocks, double spacing) {
    final offsets = <double>[];
    var offset = 0.0;
    for (var i = 0; i < blocks.length; i++) {
      offsets.add(offset);
      offset += extentFor(blocks[i]);
      if (i < blocks.length - 1) {
        offset += spacing;
      }
    }
    return _BlockLayoutMetrics(
      blocks: blocks,
      offsets: offsets,
      totalExtent: offset,
      cache: this,
    );
  }
}

class _BlockLayoutMetrics {
  const _BlockLayoutMetrics({
    required this.blocks,
    required this.offsets,
    required this.totalExtent,
    required this.cache,
  });

  final List<BlockNode> blocks;
  final List<double> offsets;
  final double totalExtent;
  final _BlockExtentCache cache;

  double topFor(int index) => offsets[index];

  double bottomFor(int index) => topFor(index) + cache.extentFor(blocks[index]);

  List<int> visibleIndices(double visibleTop, double visibleBottom) {
    if (blocks.isEmpty) {
      return const <int>[];
    }
    final start = _firstIndexWithBottomAtOrAfter(visibleTop);
    if (start >= blocks.length) {
      return <int>[blocks.length - 1];
    }
    final endExclusive = _firstIndexWithTopAfter(visibleBottom);
    final end = endExclusive <= start ? start + 1 : endExclusive;
    return <int>[
      for (var i = start; i < end && i < blocks.length; i++) i,
    ];
  }

  int _firstIndexWithBottomAtOrAfter(double y) {
    var low = 0;
    var high = blocks.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (bottomFor(mid) < y) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _firstIndexWithTopAfter(double y) {
    var low = 0;
    var high = offsets.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (offsets[mid] <= y) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

class _MeasuredVirtualBlockList extends StatefulWidget {
  const _MeasuredVirtualBlockList({
    required this.controller,
    required this.blocks,
    required this.blockSpacing,
    required this.extentCache,
    required this.keepAliveIds,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.onExtentUpdated,
  });

  final ScrollController controller;
  final List<BlockNode> blocks;
  final double blockSpacing;
  final _BlockExtentCache extentCache;
  final Set<String> keepAliveIds;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  /// Invoked after a block's measured extent was actually updated in the cache
  /// (i.e. its height changed). The editor uses it to re-run caret-into-view
  /// logic that depends on accurate block heights, which only becomes available
  /// a frame after the content mutation (the mutation frame still carried the
  /// pre-edit height).
  final void Function()? onExtentUpdated;

  @override
  State<_MeasuredVirtualBlockList> createState() =>
      _MeasuredVirtualBlockListState();
}

class _MeasuredVirtualBlockListState extends State<_MeasuredVirtualBlockList> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _MeasuredVirtualBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleExtentChanged(String blockId, int measureToken, double extent) {
    if (widget.extentCache.record(blockId, measureToken, extent) && mounted) {
      setState(() {});
      // A real height change may unlock a caret-into-view that the content
      // mutation frame could not perform (it ran with the pre-edit height).
      // Notify the editor so it can retry the scroll against the now-accurate
      // layout.
      widget.onExtentUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding.resolve(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - padding.horizontal)
                .clamp(0.0, double.infinity)
                .toDouble()
            : null;
        widget.extentCache.updateContentWidth(contentWidth);
        final metrics = widget.extentCache.layoutFor(
          widget.blocks,
          widget.blockSpacing,
        );
        final viewportHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final scrollOffset =
            widget.controller.hasClients ? widget.controller.offset : 0.0;
        final contentTop = (scrollOffset - padding.top - _kVirtualListOverscan)
            .clamp(0.0, double.infinity)
            .toDouble();
        final contentBottom =
            scrollOffset - padding.top + viewportHeight + _kVirtualListOverscan;
        final visible = metrics.visibleIndices(contentTop, contentBottom);
        final indices = <int>{...visible};
        for (var i = 0; i < widget.blocks.length; i++) {
          if (widget.keepAliveIds.contains(widget.blocks[i].id)) {
            indices.add(i);
          }
        }
        final sortedIndices = indices.toList()..sort();
        final height = padding.vertical + metrics.totalExtent;
        return SingleChildScrollView(
          controller: widget.controller,
          physics: widget.physics,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final index in sortedIndices)
                  Positioned(
                    key: ValueKey<String>(
                      'wenz-richtext-positioned-${widget.blocks[index].id}',
                    ),
                    top: padding.top + metrics.topFor(index),
                    left: padding.left,
                    right: padding.right,
                    child: _MeasuredBlockExtent(
                      key: ValueKey<String>(
                        'wenz-richtext-measure-${widget.blocks[index].id}',
                      ),
                      blockId: widget.blocks[index].id,
                      measureToken: widget.extentCache.tokenFor(
                        widget.blocks[index].id,
                      ),
                      onChanged: _handleExtentChanged,
                      child: widget.itemBuilder(context, index),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeasuredBlockExtent extends SingleChildRenderObjectWidget {
  const _MeasuredBlockExtent({
    super.key,
    required this.blockId,
    required this.measureToken,
    required this.onChanged,
    required super.child,
  });

  final String blockId;
  final int measureToken;
  final void Function(String blockId, int measureToken, double extent)
      onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredBlockExtent(
      blockId: blockId,
      measureToken: measureToken,
      onChanged: onChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasuredBlockExtent renderObject,
  ) {
    renderObject
      ..blockId = blockId
      ..measureToken = measureToken
      ..onChanged = onChanged;
  }
}

class _RenderMeasuredBlockExtent extends RenderProxyBox {
  _RenderMeasuredBlockExtent({
    required String blockId,
    required int measureToken,
    required void Function(String blockId, int measureToken, double extent)
        onChanged,
  })  : _blockId = blockId,
        _measureToken = measureToken,
        _onChanged = onChanged;

  String _blockId;
  int _measureToken;
  void Function(String blockId, int measureToken, double extent) _onChanged;
  double? _lastReportedExtent;

  set blockId(String value) {
    if (_blockId == value) {
      return;
    }
    _blockId = value;
    _lastReportedExtent = null;
  }

  set measureToken(int value) {
    if (_measureToken == value) {
      return;
    }
    _measureToken = value;
    _lastReportedExtent = null;
  }

  set onChanged(
    void Function(String blockId, int measureToken, double extent) value,
  ) {
    _onChanged = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    final extent = size.height;
    final previous = _lastReportedExtent;
    if (previous != null && (previous - extent).abs() <= 0.5) {
      return;
    }
    _lastReportedExtent = extent;
    final reportedBlockId = _blockId;
    final reportedToken = _measureToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) {
        _onChanged(reportedBlockId, reportedToken, extent);
      }
    });
  }
}

/// Wraps a [_BlockRenderer] so that the underlying block widget (and its
/// [_TextSelectionSurface] children, geometry registration, and text-layout
/// cache) stay mounted even when scrolled out of the viewport — but only when
/// [keepAlive] is true. Used to keep the caret block and selection endpoints
/// alive under editor virtualisation, so the caret and selection
/// highlight always paint and the geometry registry always knows their box.
///
/// Also drives incremental rebuild: a block is only re-rendered when its
/// content changed ([blockChanged]) *or* when the selection / caret / IME
/// composition touches it. A pure caret move inside a different block leaves
/// this block's cached child intact, avoiding the inline-span rebuild that
/// would otherwise run for every block on every keystroke.
class _KeepAliveBlock extends StatefulWidget {
  const _KeepAliveBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.keepAlive,
    required this.blockChanged,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.blockRenderers,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.onTableColumnResize,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final bool keepAlive;
  final bool blockChanged;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final BlockRendererRegistry blockRenderers;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final MediaResolver? mediaResolver;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableColumnResizeHandler? onTableColumnResize;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  State<_KeepAliveBlock> createState() => _KeepAliveBlockState();
}

class _KeepAliveBlockState extends State<_KeepAliveBlock>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  /// Cached child from the last build that actually rendered. Reused when the
  /// block's content and selection-relevance are unchanged.
  Widget? _cachedChild;

  @override
  void didUpdateWidget(covariant _KeepAliveBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
    // Invalidate the cache when something this block renders depends on
    // changed. Content change, selection/caret/composition touching this block,
    // or ambient style/debug toggles all force a fresh render.
    //
    // Selection requires care: a block that stays selected while the selection
    // extent moves within it (e.g. dragging to resize a range) does not flip
    // the boolean "touches" flag, but the rendered highlight/caret offset DID
    // change. So when this block is touched by the selection, a different
    // selection object must also invalidate the cache.
    final selectionTouchedChanged =
        _selectionTouchesBlock(oldWidget) != _selectionTouchesBlock(widget);
    final selectionShiftedWhileTouched = _selectionTouchesBlock(widget) &&
        oldWidget.selection != widget.selection;
    if (widget.blockChanged ||
        selectionTouchedChanged ||
        selectionShiftedWhileTouched ||
        oldWidget.showCaret != widget.showCaret ||
        oldWidget.showDebugOverlay != widget.showDebugOverlay ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
        oldWidget.onCodeLanguageChanged != widget.onCodeLanguageChanged ||
        oldWidget.onCodeCopied != widget.onCodeCopied ||
        oldWidget.onCalloutVariantChanged != widget.onCalloutVariantChanged ||
        oldWidget.onTableToolbarAction != widget.onTableToolbarAction ||
        oldWidget.onTableColumnResize != widget.onTableColumnResize ||
        oldWidget.findMatches != widget.findMatches ||
        oldWidget.currentFindMatch != widget.currentFindMatch ||
        _compositionTouchesBlock(oldWidget) !=
            _compositionTouchesBlock(widget) ||
        oldWidget.blockRenderers != widget.blockRenderers) {
      _cachedChild = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cached = _cachedChild;
    if (cached != null) {
      return cached;
    }
    final child = _BlockRenderer(
      block: widget.block,
      blockIndex: widget.blockIndex,
      selection: widget.selection,
      compositionState: widget.compositionState,
      registry: widget.registry,
      blockRenderers: widget.blockRenderers,
      showCaret: widget.showCaret,
      textStyle: widget.textStyle,
      showDebugOverlay: widget.showDebugOverlay,
      mediaResolver: widget.mediaResolver,
      inlineEmbedRenderer: widget.inlineEmbedRenderer,
      onCodeLanguageChanged: widget.onCodeLanguageChanged,
      onCodeCopied: widget.onCodeCopied,
      onCalloutVariantChanged: widget.onCalloutVariantChanged,
      onTableToolbarAction: widget.onTableToolbarAction,
      onTableColumnResize: widget.onTableColumnResize,
      findMatches: widget.findMatches,
      currentFindMatch: widget.currentFindMatch,
    );
    _cachedChild = child;
    return child;
  }

  /// Whether the current selection could affect this block's rendering: it is
  /// an endpoint, or it lies strictly between the selection's start and end
  /// (so it would be fully highlighted), or the selection is collapsed inside
  /// it (the caret).
  bool _selectionTouchesBlock(_KeepAliveBlock w) {
    final selection = w.selection;
    if (selection == null) {
      return false;
    }
    final index = w.blockIndex;
    final start = selection.start;
    final end = selection.end;
    if (start.blockIndex == index || end.blockIndex == index) {
      return true;
    }
    // Interior block of a multi-block range is fully highlighted.
    return index > start.blockIndex && index < end.blockIndex;
  }

  /// Whether an active IME composition affects this block (composition lives in
  /// the caret's block). Only that block needs to repaint the underline span.
  bool _compositionTouchesBlock(_KeepAliveBlock w) {
    final composition = w.compositionState;
    if (composition == null) {
      return false;
    }
    final selection = w.selection;
    return selection != null && selection.extent.blockIndex == w.blockIndex;
  }
}

class _BlockRenderer extends StatelessWidget {
  const _BlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.blockRenderers,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.onTableColumnResize,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final BlockRendererRegistry blockRenderers;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final MediaResolver? mediaResolver;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableColumnResizeHandler? onTableColumnResize;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final renderContext = BlockRenderContext(
      block: block,
      blockIndex: blockIndex,
      selection: selection,
      compositionState: compositionState,
      registry: registry,
      showCaret: showCaret,
      textStyle: textStyle,
      showDebugOverlay: showDebugOverlay,
      mediaResolver: mediaResolver,
      inlineEmbedRenderer: inlineEmbedRenderer,
      onCodeLanguageChanged: onCodeLanguageChanged,
      onCodeCopied: onCodeCopied,
      onCalloutVariantChanged: onCalloutVariantChanged,
      onTableToolbarAction: onTableToolbarAction,
      onTableColumnResize: onTableColumnResize,
      findMatches: _matchesForBlock(findMatches, blockIndex),
      currentFindMatch:
          currentFindMatch?.blockIndex == blockIndex ? currentFindMatch : null,
    );
    final builder = blockRenderers.resolveForBlock(
      block,
      fallback: _defaultBlockFallback,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: (block.attributes.indent ?? 0) * _kIndentPixelsPerLevel,
      ),
      child: builder(context, renderContext),
    );
  }
}

/// Plain-text fallback used when no renderer is registered for a block type.
/// Guarantees every block paints *something*.
Widget _defaultBlockFallback(
  BuildContext context,
  BlockRenderContext renderContext,
) {
  return Text(renderContext.block.plainText);
}

/// Installs the built-in block renderers onto [registry]. Exposed so the editor
/// can wire defaults into a caller-supplied registry without duplicating the
/// dispatch table.
extension BlockRendererRegistryDefaults on BlockRendererRegistry {
  void installDefaultBuilders() {
    register(BlockType.paragraph, _defaultTextBlockRenderer);
    register(BlockType.heading, _defaultTextBlockRenderer);
    register(BlockType.quote, _defaultTextBlockRenderer);
    register(BlockType.listItem, _defaultTextBlockRenderer);
    register(BlockType.code, _defaultCodeBlockRenderer);
    register(BlockType.image, _defaultImageBlockRenderer);
    register(BlockType.table, _defaultTableBlockRenderer);
    register(BlockType.divider, _defaultDividerBlockRenderer);
    register(BlockType.video, _defaultVideoBlockRenderer);
    register(BlockType.embed, _defaultBlockEmbedRenderer);
    register(BlockType.callout, _defaultCalloutBlockRenderer);
    register(BlockType.file, _defaultFileBlockRenderer);
  }
}

Widget _defaultTextBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _TextBlockRenderer(
    block: rc.block as TextBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    textStyle: rc.textStyle,
    showDebugOverlay: rc.showDebugOverlay,
    inlineEmbedRenderer: rc.inlineEmbedRenderer,
    onToolbarAction: rc.onTableToolbarAction,
    onColumnResize: rc.onTableColumnResize,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultCodeBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _CodeBlockRenderer(
    block: rc.block as CodeBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    showDebugOverlay: rc.showDebugOverlay,
    onLanguageChanged: rc.onCodeLanguageChanged,
    onCodeCopied: rc.onCodeCopied,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultImageBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final image = rc.block as ImageBlockNode;
  final resolved = _resolveMedia(context, rc);
  final media = resolved ??
      _MediaPlaceholder(
        label: 'image',
        value: _assetLabel(image.assetId, image.file),
      );
  return _withSelectableObjectBlock(
    image,
    rc,
    _ImageBlockContent(block: image, child: media),
  );
}

Widget _defaultTableBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _TableBlockRenderer(
    block: rc.block as TableBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    textStyle: rc.textStyle,
    showDebugOverlay: rc.showDebugOverlay,
    inlineEmbedRenderer: rc.inlineEmbedRenderer,
    onToolbarAction: rc.onTableToolbarAction,
    onColumnResize: rc.onTableColumnResize,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultDividerBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _withSelectableObjectBlock(
    rc.block,
    rc,
    const Divider(height: 1),
  );
}

Widget _defaultVideoBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final video = rc.block as VideoBlockNode;
  final resolved = _resolveMedia(context, rc);
  if (resolved != null) {
    return _withSelectableObjectBlock(video, rc, resolved);
  }
  return _withSelectableObjectBlock(
    video,
    rc,
    _MediaPlaceholder(
      label: 'video',
      value: _assetLabel(video.assetId, video.file),
    ),
  );
}

Widget _defaultBlockEmbedRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final embed = rc.block as BlockEmbedNode;
  return WenzObjectBlockSurface(
    renderContext: rc,
    child: _BlockEmbedContent(block: embed),
  );
}

Widget _defaultCalloutBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final block = rc.block as CalloutBlockNode;
  return _withBlockSemantics(
    block,
    _CalloutRenderer(
      block: block,
      textStyle: rc.textStyle,
      inlineEmbedRenderer: rc.inlineEmbedRenderer,
      onVariantChanged: rc.onCalloutVariantChanged,
    ),
  );
}

Widget _defaultFileBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final file = rc.block as FileBlockNode;
  final resolved = _resolveMedia(context, rc);
  if (resolved != null) {
    return _withSelectableObjectBlock(file, rc, resolved);
  }
  return _withSelectableObjectBlock(
    file,
    rc,
    _FileBlockContent(block: file),
  );
}

/// Asks the injected [MediaResolver] (if any) to render [rc.block]. Returns
/// `null` when no resolver is injected, the resolver declines (`null`), or the
/// resolver throws — in all those cases the caller falls back to the built-in
/// placeholder. The try/catch keeps a faulty resolver from crashing the editor
/// (see `docs/schema_and_commands.md` §Error handling).
Widget? _resolveMedia(BuildContext context, BlockRenderContext rc) {
  final resolver = rc.mediaResolver;
  if (resolver == null) {
    return null;
  }
  try {
    return resolver.resolve(context, rc.block);
  } on Object catch (error) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      library: 'wenz_richtext',
      context: ErrorDescription('MediaResolver.resolve threw for block '
          '${rc.block.id} (${rc.block.type}); falling back to placeholder.'),
    ));
    return null;
  }
}

Widget _withSelectableObjectBlock(
  BlockNode block,
  BlockRenderContext rc,
  Widget child,
) {
  final path = PositionPath.blockObject(block.id);
  final selected = _selectionTouchesPath(
    rc.selection,
    rc.blockIndex,
    block.id,
    path,
    _kAtomicBlockSelectionLength,
  );
  return _withBlockSemantics(
    block,
    _BlockObjectSelectionSurface(
      blockId: block.id,
      blockIndex: rc.blockIndex,
      path: path,
      selection: rc.selection,
      registry: rc.registry,
      showDebugOverlay: rc.showDebugOverlay,
      child: child,
    ),
    selected: selected,
  );
}

class _TextBlockRenderer extends StatelessWidget {
  const _TextBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.inlineEmbedRenderer,
    this.onToolbarAction,
    this.onColumnResize,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TextBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final TableToolbarActionHandler? onToolbarAction;
  final TableColumnResizeHandler? onColumnResize;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = _blockTextStyle(
      context,
      block,
      textStyle ?? DefaultTextStyle.of(context).style,
    );
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockText(block.id),
    );
    final path = PositionPath.blockText(block.id);
    final textLength = inlineNodesLength(block.content);
    final selected = _selectionRangeForPath(
          selection,
          blockIndex,
          path,
          textLength,
        ) !=
        null;
    final text = _TextSelectionSurface(
      blockId: block.id,
      blockIndex: blockIndex,
      path: path,
      textLength: textLength,
      textSpan: TextSpan(
        style: effectiveStyle,
        children: _inlineSpansFor(
          context,
          block.content,
          effectiveStyle,
          compositionRange,
          inlineEmbedRenderer,
        ),
      ),
      textAlign: _textAlign(block.attributes.alignment),
      minHeight: (effectiveStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
      selection: selection,
      showCaret: showCaret,
      registry: registry,
      showDebugOverlay: showDebugOverlay,
      findRanges: _findRangesForPath(
        findMatches,
        currentFindMatch,
        blockIndex,
        path,
        textLength,
      ),
    );
    final prefix = _prefixFor(block);
    if (prefix == null) {
      return _withBlockSemantics(block, text, selected: selected);
    }
    return _withBlockSemantics(
      block,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 32,
            child:
                Text(prefix, style: effectiveStyle, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 8),
          Expanded(child: text),
        ],
      ),
      selected: selected,
    );
  }
}

class _CodeBlockRenderer extends StatelessWidget {
  const _CodeBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.showDebugOverlay = false,
    this.onLanguageChanged,
    this.onCodeCopied,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final CodeBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool showDebugOverlay;
  final ValueChanged<String>? onLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ) ??
        const TextStyle(fontFamily: 'monospace', fontSize: 13);
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockCode(block.id),
    );
    final path = PositionPath.blockCode(block.id);
    final selected = _selectionRangeForPath(
          selection,
          blockIndex,
          path,
          block.code.length,
        ) !=
        null;
    return _withBlockSemantics(
      block,
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CodeBlockToolbar(
              language: block.language,
              onLanguageChanged: onLanguageChanged,
              onCopyPressed: onCodeCopied == null
                  ? null
                  : () {
                      unawaited(onCodeCopied!(block.code));
                    },
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _TextSelectionSurface(
                blockId: block.id,
                blockIndex: blockIndex,
                path: path,
                textLength: block.code.length,
                textSpan: _codeSpan(block.code, codeStyle, compositionRange),
                textAlign: TextAlign.start,
                minHeight: (codeStyle.fontSize ?? 13) * _kBlockMinHeightFactor,
                selection: selection,
                showCaret: showCaret,
                registry: registry,
                showDebugOverlay: showDebugOverlay,
                findRanges: _findRangesForPath(
                  findMatches,
                  currentFindMatch,
                  blockIndex,
                  path,
                  block.code.length,
                ),
              ),
            ),
          ],
        ),
      ),
      selected: selected,
    );
  }
}

class _CodeBlockToolbar extends StatelessWidget {
  const _CodeBlockToolbar({
    required this.language,
    this.onLanguageChanged,
    this.onCopyPressed,
  });

  final String language;
  final ValueChanged<String>? onLanguageChanged;
  final VoidCallback? onCopyPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final languages = _codeLanguageOptions(language);
    final value = languages.contains(language) ? language : '';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 6, 4),
      child: Row(
        children: <Widget>[
          Icon(Icons.code, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(6),
              style: labelStyle,
              iconSize: 18,
              onChanged: onLanguageChanged == null
                  ? null
                  : (value) {
                      if (value != null) {
                        onLanguageChanged!(value);
                      }
                    },
              items: <DropdownMenuItem<String>>[
                for (final option in languages)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(_codeLanguageLabel(option)),
                  ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Copy code',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onCopyPressed,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}

class _TableBlockRenderer extends StatelessWidget {
  const _TableBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.inlineEmbedRenderer,
    this.onToolbarAction,
    this.onColumnResize,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TableBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final TableToolbarActionHandler? onToolbarAction;
  final TableColumnResizeHandler? onColumnResize;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final table = block.table;
    final columnCount = table.columnCount;
    if (table.rowCount == 0 || columnCount == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    return _withBlockSemantics(
      block,
      LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _TableGridMetrics.compute(
            table: table,
            maxWidth: _tableMaxWidth(constraints, columnCount),
            textStyle: effectiveStyle,
            textDirection: Directionality.of(context),
          );
          final activeRange =
              _activeTableRange(selection, block.id, blockIndex);
          final resizeTop = activeRange != null && onToolbarAction != null
              ? _kTableResizeHandleTopInset
              : 0.0;
          final resizeHeight = metrics.height - resizeTop;
          return SizedBox(
            width: metrics.width,
            height: metrics.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final cell in metrics.cells)
                  Positioned(
                    left: cell.left,
                    top: cell.top,
                    width: cell.width,
                    height: cell.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: _TableCellSurface(
                        tableBlock: block,
                        blockIndex: blockIndex,
                        rowIndex: cell.rowIndex,
                        columnIndex: cell.columnIndex,
                        cell: cell.cell,
                        textStyle: effectiveStyle,
                        textAlign: _textAlign(
                          table.columnAlignments[cell.columnIndex],
                        ),
                        selection: selection,
                        compositionState: compositionState,
                        registry: registry,
                        showCaret: showCaret,
                        highlightWholeCell: _shouldHighlightTableCell(
                          selection,
                          block.id,
                          blockIndex,
                          cell.rowIndex,
                          cell.columnIndex,
                        ),
                        showDebugOverlay: showDebugOverlay,
                        inlineEmbedRenderer: inlineEmbedRenderer,
                        findMatches: findMatches,
                        currentFindMatch: currentFindMatch,
                      ),
                    ),
                  ),
                if (activeRange != null &&
                    onColumnResize != null &&
                    resizeHeight > 0)
                  for (var column = 0;
                      column < metrics.columnWidths.length;
                      column++)
                    Positioned(
                      left: metrics.columnLefts[column] +
                          metrics.columnWidths[column] -
                          (_kTableResizeHandleWidth / 2),
                      top: resizeTop,
                      width: _kTableResizeHandleWidth,
                      height: resizeHeight,
                      child: _TableColumnResizeHandle(
                        key: ValueKey<String>(
                          'table-resize-${block.id}-$column',
                        ),
                        columnIndex: column,
                        width: metrics.columnWidths[column],
                        onResize: (width) {
                          onColumnResize!(
                            blockIndex: blockIndex,
                            columnIndex: column,
                            width: width,
                          );
                        },
                      ),
                    ),
                if (activeRange != null && onToolbarAction != null)
                  PositionedDirectional(
                    top: 4,
                    start: 4,
                    end: 4,
                    child: _TableFloatingToolbar(
                      block: block,
                      blockIndex: blockIndex,
                      range: activeRange,
                      onAction: onToolbarAction!,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

TableCellRange? _activeTableRange(
  DocumentSelection? selection,
  String tableBlockId,
  int blockIndex,
) {
  final range = selection?.tableCellRange;
  if (range == null ||
      range.tableBlockId != tableBlockId ||
      range.blockIndex != blockIndex) {
    return null;
  }
  return range;
}

class _TableFloatingToolbar extends StatelessWidget {
  const _TableFloatingToolbar({
    required this.block,
    required this.blockIndex,
    required this.range,
    required this.onAction,
  });

  final TableBlockNode block;
  final int blockIndex;
  final TableCellRange range;
  final TableToolbarActionHandler onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = block.table.cellAt(range.startRow, range.startColumn);
    final canDeleteRow = block.table.rowCount > 1;
    final canDeleteColumn = block.table.columnCount > 1;
    final canMerge = !range.isSingleCell;
    final canSplit = cell != null &&
        !cell.covered &&
        (cell.rowSpan > 1 || cell.columnSpan > 1);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 3,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor.withAlpha(160)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              children: <Widget>[
                _button(
                  icon: Icons.keyboard_arrow_up,
                  tooltip: 'Insert table row above',
                  action: TableToolbarAction.insertRowAbove,
                ),
                _button(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: 'Insert table row below',
                  action: TableToolbarAction.insertRowBelow,
                ),
                _button(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete table row',
                  action: TableToolbarAction.deleteRow,
                  enabled: canDeleteRow,
                ),
                _divider(theme),
                _button(
                  icon: Icons.keyboard_arrow_left,
                  tooltip: 'Insert table column before',
                  action: TableToolbarAction.insertColumnBefore,
                ),
                _button(
                  icon: Icons.keyboard_arrow_right,
                  tooltip: 'Insert table column after',
                  action: TableToolbarAction.insertColumnAfter,
                ),
                _button(
                  icon: Icons.delete_forever_outlined,
                  tooltip: 'Delete table column',
                  action: TableToolbarAction.deleteColumn,
                  enabled: canDeleteColumn,
                ),
                _divider(theme),
                _button(
                  icon: Icons.title,
                  tooltip: 'Toggle table header cell',
                  action: TableToolbarAction.toggleHeader,
                ),
                _button(
                  icon: Icons.format_color_fill,
                  tooltip: 'Set table cell background',
                  action: TableToolbarAction.setBackgroundColor,
                  backgroundColor: _kTableToolbarBackgroundColor,
                ),
                _button(
                  icon: Icons.format_color_reset,
                  tooltip: 'Clear table cell background',
                  action: TableToolbarAction.clearBackgroundColor,
                ),
                _divider(theme),
                _button(
                  icon: Icons.format_align_left,
                  tooltip: 'Align table column left',
                  action: TableToolbarAction.alignLeft,
                ),
                _button(
                  icon: Icons.format_align_center,
                  tooltip: 'Align table column center',
                  action: TableToolbarAction.alignCenter,
                ),
                _button(
                  icon: Icons.format_align_right,
                  tooltip: 'Align table column right',
                  action: TableToolbarAction.alignRight,
                ),
                _button(
                  icon: Icons.format_align_justify,
                  tooltip: 'Clear table column alignment',
                  action: TableToolbarAction.clearAlignment,
                ),
                _divider(theme),
                _button(
                  icon: Icons.call_merge,
                  tooltip: 'Merge selected table cells',
                  action: TableToolbarAction.mergeCells,
                  enabled: canMerge,
                ),
                _button(
                  icon: Icons.call_split,
                  tooltip: 'Split table cell',
                  action: TableToolbarAction.splitCell,
                  enabled: canSplit,
                ),
                _button(
                  icon: Icons.swap_horiz,
                  tooltip: 'Reset table column width',
                  action: TableToolbarAction.resetColumnWidth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required TableToolbarAction action,
    bool enabled = true,
    int? backgroundColor,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 18,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: enabled
          ? () {
              onAction(
                TableToolbarActionIntent(
                  action: action,
                  blockIndex: blockIndex,
                  rowIndex: range.startRow,
                  columnIndex: range.startColumn,
                  endRowIndex: range.endRow,
                  endColumnIndex: range.endColumn,
                  backgroundColor: backgroundColor,
                ),
              );
            }
          : null,
    );
  }

  Widget _divider(ThemeData theme) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        width: 6,
        thickness: 1,
        color: theme.dividerColor.withAlpha(160),
      ),
    );
  }
}

class _TableColumnResizeHandle extends StatefulWidget {
  const _TableColumnResizeHandle({
    super.key,
    required this.columnIndex,
    required this.width,
    required this.onResize,
  });

  final int columnIndex;
  final double width;
  final ValueChanged<double> onResize;

  @override
  State<_TableColumnResizeHandle> createState() =>
      _TableColumnResizeHandleState();
}

class _TableColumnResizeHandleState extends State<_TableColumnResizeHandle> {
  late double _dragWidth;

  @override
  void initState() {
    super.initState();
    _dragWidth = widget.width;
  }

  @override
  void didUpdateWidget(_TableColumnResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _dragWidth = widget.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Resize table column ${widget.columnIndex + 1}',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            _dragWidth = widget.width;
          },
          onHorizontalDragUpdate: (details) {
            _dragWidth = (_dragWidth + details.delta.dx)
                .clamp(_kMinTableColumnWidth, _kMaxTableColumnWidth)
                .toDouble();
            widget.onResize(_dragWidth);
          },
          child: Center(
            child: SizedBox(
              width: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _withBlockSemantics(
  BlockNode block,
  Widget child, {
  bool selected = false,
}) {
  final label = selected
      ? '${_blockSemanticsLabel(block)}, selected'
      : _blockSemanticsLabel(block);
  final headingLevel = block is TextBlockNode && block.type == BlockType.heading
      ? (block.attributes.level ?? 1).clamp(1, 6).toInt()
      : null;
  return Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    selected: selected,
    header: headingLevel != null,
    headingLevel: headingLevel,
    image: block is ImageBlockNode,
    child: child,
  );
}

String _blockSemanticsLabel(BlockNode block) {
  return switch (block) {
    TextBlockNode(type: BlockType.heading) =>
      'Heading block level ${block.attributes.level}',
    TextBlockNode(type: BlockType.quote) => 'Quote block',
    TextBlockNode(type: BlockType.listItem) => 'List item block',
    TextBlockNode() => 'Paragraph block',
    CodeBlockNode() => 'Code block',
    TableBlockNode() =>
      'Table block, ${block.table.rowCount} rows, ${block.table.columnCount} columns',
    ImageBlockNode() => 'Image block ${_imageAccessibleLabel(block)}',
    VideoBlockNode() => 'Video block ${_assetLabel(block.assetId, block.file)}',
    BlockEmbedNode() =>
      'Embed block ${block.normalizedEmbedType}: ${block.displayText}',
    FileBlockNode() => 'File block ${_fileAccessibleLabel(block)}',
    DividerBlockNode() => 'Divider block',
    CalloutBlockNode() =>
      'Callout block ${block.normalizedVariant}: ${block.effectiveTitle}',
    BlockNode() => '${block.type.name} block',
  };
}

double _tableMaxWidth(BoxConstraints constraints, int columnCount) {
  if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
    return constraints.maxWidth;
  }
  return columnCount * 120;
}

class _TableGridMetrics {
  const _TableGridMetrics({
    required this.width,
    required this.height,
    required this.columnWidths,
    required this.columnLefts,
    required this.cells,
  });

  final double width;
  final double height;
  final List<double> columnWidths;
  final List<double> columnLefts;
  final List<_TableGridCell> cells;

  static _TableGridMetrics compute({
    required TableModel table,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
  }) {
    final columnCount = table.columnCount;
    final rowCount = table.rowCount;
    final columnWidths = _resolveTableColumnWidths(table, maxWidth);
    final rowHeights = List<double>.filled(
      rowCount,
      _minimumTableCellHeight(textStyle),
    );

    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final cell = table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        final columnSpan = _clampedTableSpan(
          cell.columnSpan,
          column,
          columnCount,
        );
        final rowSpan = _clampedTableSpan(cell.rowSpan, row, rowCount);
        final cellWidth = _sumTableRange(columnWidths, column, columnSpan);
        final desiredHeight = _measureTableCellHeight(
          cell,
          textStyle,
          textDirection,
          cellWidth,
        );
        final currentHeight = _sumTableRange(rowHeights, row, rowSpan);
        if (desiredHeight > currentHeight) {
          final extra = (desiredHeight - currentHeight) / rowSpan;
          for (var i = 0; i < rowSpan; i++) {
            rowHeights[row + i] += extra;
          }
        }
      }
    }

    final lefts = _tableOffsets(columnWidths);
    final tops = _tableOffsets(rowHeights);
    final cells = <_TableGridCell>[];
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final cell = table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        final columnSpan = _clampedTableSpan(
          cell.columnSpan,
          column,
          columnCount,
        );
        final rowSpan = _clampedTableSpan(cell.rowSpan, row, rowCount);
        cells.add(
          _TableGridCell(
            rowIndex: row,
            columnIndex: column,
            cell: cell,
            left: lefts[column],
            top: tops[row],
            width: _sumTableRange(columnWidths, column, columnSpan),
            height: _sumTableRange(rowHeights, row, rowSpan),
          ),
        );
      }
    }

    return _TableGridMetrics(
      width: _sumTableRange(columnWidths, 0, columnWidths.length),
      height: _sumTableRange(rowHeights, 0, rowHeights.length),
      columnWidths: columnWidths,
      columnLefts: lefts,
      cells: cells,
    );
  }
}

class _TableGridCell {
  const _TableGridCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.cell,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int rowIndex;
  final int columnIndex;
  final TableCellNode cell;
  final double left;
  final double top;
  final double width;
  final double height;
}

List<double> _resolveTableColumnWidths(TableModel table, double maxWidth) {
  final columnCount = table.columnCount;
  final widths = List<double>.filled(columnCount, 0);
  var fixedWidth = 0.0;
  var flexCount = 0;
  for (var i = 0; i < columnCount; i++) {
    final explicit = table.columnWidths[i];
    if (explicit != null && explicit > 0) {
      widths[i] = explicit;
      fixedWidth += explicit;
    } else {
      flexCount += 1;
    }
  }
  if (flexCount == 0) {
    return widths;
  }
  final remaining = maxWidth - fixedWidth;
  final flexWidth = remaining > 0 ? remaining / flexCount : 80.0;
  for (var i = 0; i < columnCount; i++) {
    if (widths[i] == 0) {
      widths[i] = flexWidth;
    }
  }
  return widths;
}

double _measureTableCellHeight(
  TableCellNode cell,
  TextStyle textStyle,
  TextDirection textDirection,
  double cellWidth,
) {
  final effectiveTextStyle = cell.isHeader
      ? textStyle.copyWith(fontWeight: FontWeight.w600)
      : textStyle;
  final text = _tableCellDisplayText(cell);
  final displayText = text.isEmpty ? ' ' : text;
  final innerWidth = cellWidth - 16;
  final painter = TextPainter(
    text: TextSpan(text: displayText, style: effectiveTextStyle),
    textAlign: TextAlign.start,
    textDirection: textDirection,
  )..layout(maxWidth: innerWidth > 0 ? innerWidth : 0);
  final height = painter.height + 16;
  painter.dispose();
  final minimum = _minimumTableCellHeight(textStyle);
  return height > minimum ? height : minimum;
}

List<InlineNode> _tableCellInlineContent(TableCellNode? cell) {
  if (cell == null) {
    return const <InlineNode>[];
  }
  for (final block in cell.blocks) {
    if (block is TextBlockNode) {
      return block.content;
    }
  }
  return <InlineNode>[TextRun(text: cell.plainText)];
}

String _tableCellDisplayText(TableCellNode cell) {
  final inline = _tableCellInlineContent(cell);
  if (inline.isEmpty) {
    return cell.plainText;
  }
  return inline.map(_inlineDisplayText).join();
}

double _minimumTableCellHeight(TextStyle textStyle) {
  return ((textStyle.fontSize ?? 14) * _kBlockMinHeightFactor) + 16;
}

int _clampedTableSpan(int span, int start, int count) {
  final normalized = span < 1 ? 1 : span;
  final available = count - start;
  if (available <= 0) {
    return 1;
  }
  return normalized > available ? available : normalized;
}

List<double> _tableOffsets(List<double> sizes) {
  var offset = 0.0;
  final offsets = <double>[];
  for (final size in sizes) {
    offsets.add(offset);
    offset += size;
  }
  return offsets;
}

double _sumTableRange(List<double> values, int start, int count) {
  var result = 0.0;
  final end = start + count;
  for (var i = start; i < end && i < values.length; i++) {
    result += values[i];
  }
  return result;
}

bool _shouldHighlightTableCell(
  DocumentSelection? selection,
  String tableBlockId,
  int blockIndex,
  int rowIndex,
  int columnIndex,
) {
  if (selection == null || selection.isCollapsed) {
    return false;
  }
  // Intra-table cell range (drag within the table): highlight cells inside the
  // range via the structured TableCellRange.
  final range = selection.tableCellRange;
  if (range != null) {
    if (range.isSingleCell) {
      return false;
    }
    return range.tableBlockId == tableBlockId &&
        range.blockIndex == blockIndex &&
        range.containsCell(rowIndex, columnIndex);
  }
  // Cross-block selection that spans this table block (e.g. select-all across
  // a paragraph + table): when the table block sits strictly between the
  // selection endpoints, every cell is part of the selection and highlights.
  final start = selection.start;
  final end = selection.end;
  final tableCovered =
      start.blockIndex < blockIndex && end.blockIndex > blockIndex;
  if (tableCovered) {
    return true;
  }
  final cellPath = PositionPath.tableCellText(
    tableBlockId,
    rowIndex,
    columnIndex,
  );
  if (start.blockIndex == blockIndex &&
      start.path.isTableCellText &&
      end.blockIndex > blockIndex) {
    return start.blockId == tableBlockId && cellPath.compare(start.path) > 0;
  }
  if (end.blockIndex == blockIndex &&
      end.path.isTableCellText &&
      start.blockIndex < blockIndex) {
    return end.blockId == tableBlockId && cellPath.compare(end.path) < 0;
  }
  return false;
}

class _TableCellSurface extends StatefulWidget {
  const _TableCellSurface({
    required this.tableBlock,
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.cell,
    required this.textStyle,
    required this.textAlign,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    required this.highlightWholeCell,
    required this.showDebugOverlay,
    this.inlineEmbedRenderer,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TableBlockNode tableBlock;
  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final TableCellNode? cell;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool highlightWholeCell;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  State<_TableCellSurface> createState() => _TableCellSurfaceState();
}

class _TableCellSurfaceState extends State<_TableCellSurface> {
  /// GlobalKey on the cell's outer frame — the whole cell (background +
  /// padding + centred text). Registered as the hit-test box so a tap anywhere
  /// inside the visible cell resolves to this cell, not a neighbour. The
  /// text-local surface is registered separately by [_TextSelectionSurface].
  final GlobalKey _cellFrameKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    if (cell?.covered ?? false) {
      return const SizedBox.shrink();
    }
    final tableBlock = widget.tableBlock;
    final blockIndex = widget.blockIndex;
    final path = PositionPath.tableCellText(
      tableBlock.id,
      widget.rowIndex,
      widget.columnIndex,
    );
    final compositionRange = _localCompositionRange(
      widget.compositionState,
      tableBlock.id,
      blockIndex,
      path,
    );
    final inlineContent = _tableCellInlineContent(cell);
    final textLength = inlineNodesLength(inlineContent);
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final effectiveTextStyle = (cell?.isHeader ?? false)
        ? widget.textStyle.copyWith(fontWeight: FontWeight.w600)
        : widget.textStyle;
    final backgroundColor =
        cell?.backgroundColor == null ? null : Color(cell!.backgroundColor!);
    final surface = _TextSelectionSurface(
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
      textLength: textLength,
      textSpan: TextSpan(
        style: effectiveTextStyle,
        children: textLength == 0
            ? const <InlineSpan>[TextSpan(text: ' ')]
            : _inlineSpansFor(
                context,
                inlineContent,
                effectiveTextStyle,
                compositionRange,
                widget.inlineEmbedRenderer,
              ),
      ),
      textAlign: widget.textAlign,
      minHeight: (widget.textStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
      selection: widget.selection,
      showCaret: widget.showCaret,
      registry: widget.registry,
      showDebugOverlay: widget.showDebugOverlay,
      findRanges: _findRangesForPath(
        widget.findMatches,
        widget.currentFindMatch,
        blockIndex,
        path,
        textLength,
      ),
      // The cell frame — not the centred text surface — is the hit-test box.
      // The surface resolves the cell→text-local offset itself (it owns the
      // text-surface render box via its own key), stripping the padding and
      // the vertical centring gap that TableCellVerticalAlignment.middle
      // introduces for short cells.
      hitTestKey: _cellFrameKey,
    );
    final selected = widget.highlightWholeCell ||
        _selectionRangeForPath(
              widget.selection,
              blockIndex,
              path,
              textLength,
            ) !=
            null;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _tableCellSemanticsLabel(
        tableBlock: tableBlock,
        cell: cell,
        rowIndex: widget.rowIndex,
        columnIndex: widget.columnIndex,
        selected: selected,
      ),
      selected: selected,
      child: DecoratedBox(
        key: _cellFrameKey,
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: <Widget>[
              if (widget.highlightWholeCell)
                Positioned.fill(
                  child: DecoratedBox(
                    key: _selectionHighlightKey,
                    decoration: BoxDecoration(color: highlightColor),
                  ),
                ),
              surface,
            ],
          ),
        ),
      ),
    );
  }
}

String _tableCellSemanticsLabel({
  required TableBlockNode tableBlock,
  required TableCellNode? cell,
  required int rowIndex,
  required int columnIndex,
  required bool selected,
}) {
  final parts = <String>[
    'Table cell row ${rowIndex + 1} column ${columnIndex + 1}',
  ];
  if (cell?.isHeader ?? false) {
    parts.add('header');
  }
  if (cell != null) {
    final rowSpan = _clampedTableSpan(
      cell.rowSpan,
      rowIndex,
      tableBlock.table.rowCount,
    );
    final columnSpan = _clampedTableSpan(
      cell.columnSpan,
      columnIndex,
      tableBlock.table.columnCount,
    );
    if (rowSpan > 1) {
      parts.add('spans $rowSpan rows');
    }
    if (columnSpan > 1) {
      parts.add('spans $columnSpan columns');
    }
  }
  if (selected) {
    parts.add('selected');
  }
  return parts.join(', ');
}

class _BlockObjectSelectionSurface extends StatefulWidget {
  const _BlockObjectSelectionSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.selection,
    required this.registry,
    required this.showDebugOverlay,
    required this.child,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final DocumentSelection? selection;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;
  final Widget child;

  @override
  State<_BlockObjectSelectionSurface> createState() =>
      _BlockObjectSelectionSurfaceState();
}

class _BlockObjectSelectionSurfaceState
    extends State<_BlockObjectSelectionSurface> {
  final GlobalKey _surfaceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _BlockObjectSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.path != widget.path) {
      oldWidget.registry.unregister(oldWidget.blockId, oldWidget.path);
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.path != widget.path) {
      _register();
    }
  }

  @override
  void dispose() {
    widget.registry.unregister(widget.blockId, widget.path);
    super.dispose();
  }

  void _register() {
    widget.registry.register(
      BlockEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        path: widget.path,
        textLength: _kAtomicBlockSelectionLength,
        key: _surfaceKey,
        positionFromLocal: _offsetForLocalPosition,
        wordRangeAt: (_) => const TextRange(
          start: 0,
          end: _kAtomicBlockSelectionLength,
        ),
        caretRectAt: _caretRectAt,
        localCaretRectAt: _localCaretRectAt,
        localComposingRectForRange: _localComposingRectForRange,
        verticalMoveAt: _verticalMoveAt,
      ),
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    final width = box is RenderBox && box.hasSize ? box.size.width : 0.0;
    if (width <= 0) {
      return 0;
    }
    final after = switch (Directionality.of(context)) {
      TextDirection.ltr => localPosition.dx >= width / 2,
      TextDirection.rtl => localPosition.dx < width / 2,
    };
    return after ? _kAtomicBlockSelectionLength : 0;
  }

  Rect? _caretRectAt(int offset) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final localRect = _localCaretRectAt(offset);
    if (localRect == null) {
      return null;
    }
    return box.localToGlobal(localRect.topLeft) & localRect.size;
  }

  Rect? _localCaretRectAt(int offset) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final safeOffset = offset.clamp(0, _kAtomicBlockSelectionLength).toInt();
    final x = safeOffset == 0 ? 0.0 : box.size.width;
    return Rect.fromLTWH(
      x,
      0,
      _kCaretStrokeWidth,
      box.size.height,
    );
  }

  Rect? _localComposingRectForRange(int start, int end) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final safeStart = start.clamp(0, _kAtomicBlockSelectionLength).toInt();
    final safeEnd = end.clamp(safeStart, _kAtomicBlockSelectionLength).toInt();
    if (safeStart == safeEnd) {
      return _localCaretRectAt(safeStart);
    }
    return Offset.zero & box.size;
  }

  VerticalMoveResult _verticalMoveAt(
    int offset,
    bool forward,
    double? preferX,
  ) {
    return const VerticalMoveResult();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectionTouchesPath(
      widget.selection,
      widget.blockIndex,
      widget.blockId,
      widget.path,
      _kAtomicBlockSelectionLength,
    );
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final debugOffset = _debugOffsetForPath(
      widget.selection,
      widget.blockId,
      widget.path,
      _kAtomicBlockSelectionLength,
    );
    return Stack(
      key: _surfaceKey,
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        if (selected)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: _selectionHighlightKey,
                decoration: BoxDecoration(
                  color: selectedColor.withAlpha(24),
                  border: Border.all(color: selectedColor, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        if (widget.showDebugOverlay)
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: _DebugSelectionTag(
                blockId: widget.blockId,
                blockIndex: widget.blockIndex,
                path: widget.path,
                offset: debugOffset,
              ),
            ),
          ),
      ],
    );
  }
}

class _TextSelectionSurface extends StatefulWidget {
  const _TextSelectionSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.textLength,
    required this.textSpan,
    required this.textAlign,
    required this.minHeight,
    required this.selection,
    required this.showCaret,
    required this.registry,
    required this.showDebugOverlay,
    this.findRanges = const <_FindHighlightRange>[],
    this.hitTestKey,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int textLength;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final double minHeight;
  final DocumentSelection? selection;
  final bool showCaret;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;
  final List<_FindHighlightRange> findRanges;

  /// Optional GlobalKey on a wider hit-test frame (e.g. a table cell's whole
  /// frame) whose local space differs from this surface's text-local space.
  /// When null the surface's own [_surfaceKey] is used for hit-testing. When
  /// set, the State registers a transform that maps hit-local offsets onto
  /// this surface's text-local space (see [_hitLocalToTextLocal]).
  final GlobalKey? hitTestKey;

  @override
  State<_TextSelectionSurface> createState() => _TextSelectionSurfaceState();
}

class _TextSelectionSurfaceState extends State<_TextSelectionSurface> {
  TextLayoutService? _ownedLayoutService;
  final GlobalKey _surfaceKey = GlobalKey();
  double _lastMaxWidth = 0;

  /// Drives the caret blink. Period ~530ms, toggling [value] between 0 and 1.
  /// Uses a real [Timer] rather than an [AnimationController]+ticker so the
  /// repeating blink does not keep the frame scheduler busy — this lets tests
  /// (and idle frames) settle. The timer only fires on real time progress, so
  /// headless `pump()`/`pumpAndSettle()` without a duration are not blocked.
  Timer? _blinkTimer;

  /// Current blink phase: 1.0 = caret visible, 0.0 = caret hidden. Toggled by
  /// [_blinkTimer]; defaults to visible so the caret shows immediately on focus.
  double _blinkValue = 1.0;
  bool _blinkActive = false;

  /// True while a post-frame [_syncBlink] is scheduled but not yet fired.
  /// Prevents stacking multiple syncs across rapid rebuilds within one frame.
  bool _blinkSyncPending = false;

  /// The layout service for this surface. Prefers the editor-level
  /// [SharedTextLayoutCache] (so the laid-out painter survives a virtualised
  /// remount); falls back to a private instance when no scope is present (e.g.
  /// in tests that mount the surface in isolation).
  TextLayoutService get _layoutService {
    final shared = _SharedLayoutCacheScope.of(context);
    if (shared != null) {
      return shared.entryFor(widget.blockId, widget.path.toString());
    }
    return _ownedLayoutService ??= TextLayoutService();
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _TextSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockId != widget.blockId || oldWidget.path != widget.path) {
      widget.registry.unregister(oldWidget.blockId, oldWidget.path);
    }
    if (oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.path != widget.path ||
        oldWidget.textLength != widget.textLength ||
        oldWidget.textSpan != widget.textSpan) {
      _register();
    }
    // When the caret stays visible but its position changes (typing, arrow
    // keys, programmatic moves), reset the blink phase so the caret is shown
    // immediately rather than possibly landing in its hidden half-cycle —
    // matching the platform EditableText behaviour where every selection
    // change makes the caret snap back to visible.
    if (oldWidget.selection != widget.selection) {
      _resetBlinkPhase();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    widget.registry.unregister(widget.blockId, widget.path);
    // Only forget the private fallback; shared-cache entries are owned by the
    // cache and survive this surface's unmount so the painter is reused on the
    // next remount.
    _ownedLayoutService?.forget();
    super.dispose();
  }

  /// Starts or stops the blink timer to match [caretVisible]. Idempotent so it
  /// is safe to call from build.
  void _syncBlink(bool caretVisible) {
    if (caretVisible && !_blinkActive) {
      _startBlinkTimer();
    } else if (!caretVisible && _blinkActive) {
      _blinkActive = false;
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _blinkValue = 1.0;
    }
  }

  /// (Re)arms the blink timer with the caret forced visible. Called when the
  /// caret first becomes visible, and again on every selection change while it
  /// stays visible, so the caret snaps back to its visible phase instead of
  /// possibly lingering in the hidden half-cycle.
  void _startBlinkTimer() {
    _blinkActive = true;
    _blinkValue = 1.0;
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(
      _kBlinkHalfPeriod,
      (_) {
        _blinkValue = _blinkValue == 1.0 ? 0.0 : 1.0;
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  /// Resets the blink phase to visible and restarts the timer, so a caret that
  /// is mid-hidden-phase snaps back into view immediately. No-op when the
  /// caret is not currently blinking.
  void _resetBlinkPhase() {
    if (!_blinkActive) {
      return;
    }
    _startBlinkTimer();
    if (mounted) {
      setState(() {});
    }
  }

  void _register() {
    widget.registry.register(
      BlockEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        path: widget.path,
        textLength: widget.textLength,
        key: _surfaceKey,
        positionFromLocal: _offsetForLocalPosition,
        wordRangeAt: _wordRangeAt,
        caretRectAt: _caretRectAt,
        localCaretRectAt: _localCaretRectAt,
        localComposingRectForRange: _localComposingRectForRange,
        verticalMoveAt: _verticalMoveAt,
        hitTestKey: widget.hitTestKey,
        hitLocalToTextLocal:
            widget.hitTestKey == null ? null : _hitLocalToTextLocal,
      ),
    );
  }

  /// Maps a tap offset in the registered hit-test frame's local space into
  /// this surface's text-local space. Only used when a separate [hitTestKey]
  /// was provided (table cells); otherwise the registry treats the text
  /// surface itself as the hit-test box and this is never called.
  ///
  /// Resolves both render boxes at hit-test time and adds the global delta
  /// between them — robust to padding and to the vertical centring gap that
  /// `TableCellVerticalAlignment.middle` introduces for short cells.
  Offset _hitLocalToTextLocal(Offset hitLocal) {
    final hitKey = widget.hitTestKey;
    if (hitKey == null) {
      return hitLocal;
    }
    final cellBox = hitKey.currentContext?.findRenderObject();
    final textBox = _surfaceKey.currentContext?.findRenderObject();
    if (cellBox is! RenderBox || textBox is! RenderBox) {
      // Layout not ready: fall back to stripping the known 8px cell padding.
      // There is no centring correction here, but this path is only hit
      // before first layout and is strictly better than the raw offset.
      return hitLocal - const Offset(8, 8);
    }
    final cellOrigin = cellBox.localToGlobal(Offset.zero);
    final textOrigin = textBox.localToGlobal(Offset.zero);
    // hitLocal is cell-relative; convert to text-surface-relative. Since both
    // boxes share global space: textLocal = hitLocal + (cellOrigin - textOrigin).
    // (cellOrigin < textOrigin because the text sits inside the padding, so this
    // subtracts the padding/centring offset, landing the tap on the text.)
    final textLocal = hitLocal +
        Offset(cellOrigin.dx - textOrigin.dx, cellOrigin.dy - textOrigin.dy);
    // Clamp into the text surface so an off-text tap (e.g. a bottom gutter
    // below a centred short cell) maps to the nearest caret edge rather than a
    // point outside the painter's line metrics.
    return Offset(
      textLocal.dx.clamp(0, textBox.size.width),
      textLocal.dy.clamp(0, textBox.size.height),
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    return _layoutService.offsetAt(painter, localPosition, widget.textLength);
  }

  TextRange _wordRangeAt(int offset) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    return _layoutService.wordRangeAt(painter, offset);
  }

  /// Returns the caret's global [Rect] for [offset] in this block. Translates
  /// the laid-out caret's local top-left + height into screen coordinates via
  /// the surface render box.
  Rect? _caretRectAt(int offset) {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final localRect = _localCaretRectAt(offset);
    if (localRect == null) {
      return null;
    }
    return renderObject.localToGlobal(localRect.topLeft) & localRect.size;
  }

  Rect? _localCaretRectAt(int offset) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    final clamped = offset.clamp(0, widget.textLength).toInt();
    final local = _layoutService.caretOffset(painter, clamped);
    final height = _layoutService.caretHeight(painter, clamped) ??
        painter.preferredLineHeight;
    // Width matches the painted stroke so the IME candidate window is anchored
    // to the caret the user actually sees.
    return Rect.fromLTWH(
      local.dx,
      local.dy,
      _kCaretStrokeWidth,
      height,
    );
  }

  Rect? _localComposingRectForRange(int start, int end) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    final safeStart = start.clamp(0, widget.textLength).toInt();
    final safeEnd = end.clamp(safeStart, widget.textLength).toInt();
    if (safeStart == safeEnd) {
      return _localCaretRectAt(safeStart);
    }
    final boxes = _layoutService.selectionBoxes(painter, safeStart, safeEnd);
    if (boxes.isEmpty) {
      return _localCaretRectAt(safeStart);
    }
    var rect = boxes.first.toRect();
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return rect;
  }

  /// Resolves one visual-line vertical move within this block, keeping the
  /// horizontal column at [preferX] (LOCAL coordinate space). Returns the new
  /// offset (or `null` at a block boundary) plus the caret's local x.
  VerticalMoveResult _verticalMoveAt(
      int offset, bool forward, double? preferX) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      maxWidth: _lastMaxWidth,
    );
    final target = _layoutService.verticalMoveOffset(
      painter,
      offset,
      forward,
      preferX: preferX,
    );
    return VerticalMoveResult(
      targetOffset: target,
      caretX: _layoutService.caretLocalX(painter, offset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final selectionRange = _selectionRangeForPath(
      widget.selection,
      widget.blockIndex,
      widget.path,
      widget.textLength,
    );
    final caretOffset = _caretOffsetForPath(
      widget.selection,
      widget.showCaret,
      widget.blockId,
      widget.path,
      widget.textLength,
    );
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final findHighlightColor = theme.colorScheme.tertiaryContainer.withAlpha(
      150,
    );
    final activeFindHighlightColor = theme.colorScheme.tertiary.withAlpha(120);
    final caretColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        _lastMaxWidth = maxWidth;
        // Warm the layout cache so painters and hit-testing reuse the same
        // laid-out TextPainter this frame.
        _layoutService.layout(
          span: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: direction,
          maxWidth: maxWidth,
        );
        // The caret's opacity is driven by the blink timer; while blinking it
        // toggles between fully visible (1.0) and hidden (0.0).
        final caretOpacity = caretOffset == null ? 1.0 : _blinkValue;
        // The caret is painted on its own CustomPaint, wrapped in a
        // RepaintBoundary. Blinking toggles opacity via setState, which would
        // otherwise dirty the whole surface — including the RichText child —
        // every half second. The boundary confines the repaint to the caret
        // layer, so the (much heavier) text layout/paint is untouched.
        final caretPainter = _CaretPainter(
          layoutService: _layoutService,
          textSpan: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: direction,
          maxWidth: maxWidth,
          caretOffset: caretOffset,
          color: caretColor,
          textLength: widget.textLength,
          opacity: caretOpacity,
        );
        final text = CustomPaint(
          painter: _FindHighlightPainter(
            layoutService: _layoutService,
            textSpan: widget.textSpan,
            textAlign: widget.textAlign,
            textDirection: direction,
            maxWidth: maxWidth,
            ranges: widget.findRanges,
            color: findHighlightColor,
            activeColor: activeFindHighlightColor,
          ),
          child: CustomPaint(
            painter: _SelectionHighlightPainter(
              layoutService: _layoutService,
              textSpan: widget.textSpan,
              textAlign: widget.textAlign,
              textDirection: direction,
              maxWidth: maxWidth,
              range: selectionRange,
              color: highlightColor,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              child: RichText(
                text: widget.textSpan,
                textAlign: widget.textAlign,
                textDirection: direction,
              ),
            ),
          ),
        );
        // Keep the blink timer in step with whether the caret is showing.
        // Deferred to post-frame so we do not mutate timer state mid-build.
        // Guarded by [_blinkSyncPending] so repeated builds within the same
        // frame (or callbacks that have not fired yet) schedule at most one
        // sync, avoiding timer churn on rapid rebuilds.
        final caretVisible = caretOffset != null;
        if (caretVisible != _blinkActive && !_blinkSyncPending) {
          _blinkSyncPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _blinkSyncPending = false;
            if (mounted) {
              _syncBlink(caretVisible);
            }
          });
        }

        // Gestures live in the document-level SelectionGestureOverlay; the
        // surface only renders text, highlight, caret, and registers its
        // geometry for cross-block hit-testing.
        return Stack(
          key: _surfaceKey,
          children: <Widget>[
            text,
            if (selectionRange != null)
              const Positioned.fill(
                child: IgnorePointer(
                  child: SizedBox(key: _selectionHighlightKey),
                ),
              ),
            if (widget.findRanges.isNotEmpty)
              const Positioned.fill(
                child: IgnorePointer(
                  child: SizedBox(key: _findHighlightKey),
                ),
              ),
            // Caret lives in its own layer inside a RepaintBoundary so blink
            // repaints never reach the RichText below.
            if (caretOffset != null) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: _caretKey,
                      foregroundPainter: caretPainter,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.showDebugOverlay)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: _DebugSelectionTag(
                    blockId: widget.blockId,
                    blockIndex: widget.blockIndex,
                    path: widget.path,
                    offset: caretOffset ?? selectionRange?.end,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DebugSelectionTag extends StatelessWidget {
  const _DebugSelectionTag({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.offset,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int? offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(220),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$blockIndex ${blockId.isEmpty ? "<blockId>" : blockId}\n'
        '${path.toString()}\n'
        'offset=${offset ?? "-"}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _LocalSelectionRange {
  const _LocalSelectionRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _FindHighlightRange extends _LocalSelectionRange {
  const _FindHighlightRange({
    required super.start,
    required super.end,
    required this.active,
  });

  final bool active;
}

class _FindHighlightPainter extends CustomPainter {
  const _FindHighlightPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.ranges,
    required this.color,
    required this.activeColor,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final List<_FindHighlightRange> ranges;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
    );
    for (final range in ranges) {
      if (range.start == range.end) {
        continue;
      }
      final paint = Paint()..color = range.active ? activeColor : color;
      final boxes = layoutService.selectionBoxes(
        painter,
        range.start,
        range.end,
      );
      for (final box in boxes) {
        canvas.drawRect(box.toRect(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FindHighlightPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.ranges != ranges ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor;
  }
}

class _SelectionHighlightPainter extends CustomPainter {
  const _SelectionHighlightPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.range,
    required this.color,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final _LocalSelectionRange? range;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final range = this.range;
    if (range == null || range.start == range.end) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
    );
    final boxes = layoutService.selectionBoxes(painter, range.start, range.end);
    final paint = Paint()..color = color;
    for (final box in boxes) {
      canvas.drawRect(box.toRect(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHighlightPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.range?.start != range?.start ||
        oldDelegate.range?.end != range?.end ||
        oldDelegate.color != color;
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.caretOffset,
    required this.color,
    required this.textLength,
    this.opacity = 1.0,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final int? caretOffset;
  final Color color;
  final int textLength;

  /// Caret alpha multiplier driven by the blink animation (1.0 = fully visible,
  /// 0.0 = hidden).
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final caretOffset = this.caretOffset;
    if (caretOffset == null) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
    );
    final safeOffset = caretOffset.clamp(0, textLength).toInt();
    final caretTop = layoutService.caretOffset(painter, safeOffset);
    // Fall back to preferredLineHeight (matching _caretRectAt) so the caret is
    // always drawn with a sensible height even when getFullHeightForCaret
    // returns null (e.g. at empty/whitespace runs).
    final height = layoutService.caretHeight(painter, safeOffset) ??
        painter.preferredLineHeight;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = _kCaretStrokeWidth;
    canvas.drawLine(caretTop, caretTop.translate(0, height), paint);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.caretOffset != caretOffset ||
        oldDelegate.color != color ||
        oldDelegate.textLength != textLength ||
        oldDelegate.opacity != opacity;
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('[$label: $value]'),
      ),
    );
  }
}

class _BlockEmbedContent extends StatelessWidget {
  const _BlockEmbedContent({required this.block});

  final BlockEmbedNode block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.extension_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    block.normalizedEmbedType,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    block.displayText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileBlockContent extends StatelessWidget {
  const _FileBlockContent({required this.block});

  final FileBlockNode block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _fileMetadata(block);
    final error = block.uploadError.trim();
    final failed = block.uploadStatus == FileUploadStatus.failed;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              failed ? Icons.error_outline : Icons.insert_drive_file_outlined,
              color: failed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    block.displayName.isEmpty
                        ? 'Untitled file'
                        : block.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (metadata.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      metadata,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (failed && error.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (block.uploadStatus == FileUploadStatus.uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageBlockContent extends StatelessWidget {
  const _ImageBlockContent({
    required this.block,
    required this.child,
  });

  final ImageBlockNode block;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget media = child;
    if (block.showWidth != null || block.showHeight != null) {
      media = SizedBox(
        width: block.showWidth,
        height: block.showHeight,
        child: child,
      );
    }
    if (block.caption.isEmpty) {
      return media;
    }
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        media,
        const SizedBox(height: 6),
        Text(block.caption, style: captionStyle),
      ],
    );
  }
}

class _CalloutRenderer extends StatelessWidget {
  const _CalloutRenderer({
    required this.block,
    this.textStyle,
    this.inlineEmbedRenderer,
    this.onVariantChanged,
  });

  final CalloutBlockNode block;
  final TextStyle? textStyle;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final ValueChanged<String>? onVariantChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = textStyle ?? DefaultTextStyle.of(context).style;
    final variant = block.normalizedVariant;
    final tint = _calloutTint(theme, variant);
    final foreground = _calloutForeground(theme, variant);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ) ??
        base.copyWith(color: foreground, fontWeight: FontWeight.w700);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: _calloutBorder(theme, variant)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CalloutIcon(icon: block.effectiveIcon, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(block.effectiveTitle, style: titleStyle),
                      ),
                      _CalloutVariantMenu(
                        variant: variant,
                        foreground: foreground,
                        onChanged: onVariantChanged,
                      ),
                    ],
                  ),
                  if (block.content.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: base,
                        children: block.content
                            .map(
                              (node) => _inlineSpanFor(
                                context,
                                node,
                                base,
                                inlineEmbedRenderer,
                                decorate: false,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalloutIcon extends StatelessWidget {
  const _CalloutIcon({required this.icon, required this.color});

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        icon,
        style: TextStyle(fontSize: 18, color: color),
      ),
    );
  }
}

class _CalloutVariantMenu extends StatelessWidget {
  const _CalloutVariantMenu({
    required this.variant,
    required this.foreground,
    this.onChanged,
  });

  final String variant;
  final Color foreground;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Callout type',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: variant,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          iconSize: 18,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ) ??
              TextStyle(color: foreground, fontWeight: FontWeight.w600),
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null && value != variant) {
                    onChanged!(value);
                  }
                },
          items: <DropdownMenuItem<String>>[
            for (final option in CalloutBlockNode.supportedVariants)
              DropdownMenuItem<String>(
                value: option,
                child: Text(_calloutVariantLabel(option)),
              ),
          ],
        ),
      ),
    );
  }
}

Color _calloutTint(ThemeData theme, String variant) {
  final scheme = theme.colorScheme;
  switch (CalloutBlockNode.normalizeVariant(variant)) {
    case CalloutBlockNode.successVariant:
      return scheme.tertiaryContainer.withAlpha(90);
    case 'warning':
      return Colors.amber
          .withAlpha(theme.brightness == Brightness.dark ? 64 : 48);
    case CalloutBlockNode.dangerVariant:
      return scheme.errorContainer.withAlpha(90);
    case CalloutBlockNode.infoVariant:
    default:
      return scheme.surfaceContainerHighest;
  }
}

Color _calloutForeground(ThemeData theme, String variant) {
  final scheme = theme.colorScheme;
  switch (CalloutBlockNode.normalizeVariant(variant)) {
    case CalloutBlockNode.successVariant:
      return scheme.onTertiaryContainer;
    case CalloutBlockNode.warningVariant:
      return theme.brightness == Brightness.dark
          ? Colors.amber.shade200
          : Colors.amber.shade900;
    case CalloutBlockNode.dangerVariant:
      return scheme.onErrorContainer;
    case CalloutBlockNode.infoVariant:
    default:
      return scheme.onSurfaceVariant;
  }
}

Color _calloutBorder(ThemeData theme, String variant) {
  return _calloutForeground(theme, variant).withAlpha(80);
}

String _calloutVariantLabel(String variant) {
  return CalloutBlockNode.defaultTitleFor(variant);
}

TextStyle _blockTextStyle(
  BuildContext context,
  TextBlockNode block,
  TextStyle baseStyle,
) {
  final theme = Theme.of(context);
  return switch (block.type) {
    BlockType.heading => baseStyle.merge(
        theme.textTheme.titleLarge?.copyWith(
          fontSize: _headingSize(block.attributes.level),
          fontWeight: FontWeight.w700,
        ),
      ),
    BlockType.quote => baseStyle.merge(
        theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    _ => baseStyle.merge(theme.textTheme.bodyMedium),
  };
}

/// Builds the inline spans for a text block, overlaying the IME composition
/// decoration (underline) on the runs that fall inside [compositionRange].
List<InlineSpan> _inlineSpansFor(
  BuildContext context,
  List<InlineNode> nodes,
  TextStyle baseStyle,
  _LocalSelectionRange? compositionRange,
  InlineEmbedRenderer? inlineEmbedRenderer,
) {
  if (compositionRange == null) {
    return nodes
        .map(
          (node) => _inlineSpanFor(
            context,
            node,
            baseStyle,
            inlineEmbedRenderer,
            decorate: false,
          ),
        )
        .toList();
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final node in nodes) {
    final length = inlineLength(node);
    final nodeStart = cursor;
    final nodeEnd = cursor + length;
    cursor = nodeEnd;
    final overlapStart =
        nodeStart < compositionRange.start ? compositionRange.start : nodeStart;
    final overlapEnd =
        nodeEnd > compositionRange.end ? compositionRange.end : nodeEnd;
    if (overlapStart < overlapEnd) {
      spans.addAll(
        _inlineSpansForNodeWithComposition(
          context,
          node,
          baseStyle,
          inlineEmbedRenderer,
          start: overlapStart - nodeStart,
          end: overlapEnd - nodeStart,
        ),
      );
    } else {
      spans.add(
        _inlineSpanFor(
          context,
          node,
          baseStyle,
          inlineEmbedRenderer,
          decorate: false,
        ),
      );
    }
  }
  return spans;
}

List<InlineSpan> _inlineSpansForNodeWithComposition(
  BuildContext context,
  InlineNode node,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  required int start,
  required int end,
}) {
  if (node is TextRun) {
    final text = node.text;
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(safeStart, text.length).toInt();
    final style = _textStyleForAttributes(baseStyle, node.attributes);
    return <InlineSpan>[
      if (safeStart > 0)
        TextSpan(text: text.substring(0, safeStart), style: style),
      if (safeStart < safeEnd)
        TextSpan(
          text: text.substring(safeStart, safeEnd),
          style: _compositionTextStyle(style),
        ),
      if (safeEnd < text.length)
        TextSpan(text: text.substring(safeEnd), style: style),
    ];
  }

  if (node is InlineEmbed) {
    return <InlineSpan>[
      _inlineEmbedSpanFor(
        context,
        node,
        baseStyle,
        inlineEmbedRenderer,
        decorate: true,
      ),
    ];
  }

  final text = node.plainText;
  final safeStart = start.clamp(0, text.length).toInt();
  final safeEnd = end.clamp(safeStart, text.length).toInt();
  return <InlineSpan>[
    if (safeStart > 0)
      TextSpan(text: text.substring(0, safeStart), style: baseStyle),
    if (safeStart < safeEnd)
      TextSpan(
        text: text.substring(safeStart, safeEnd),
        style: _compositionTextStyle(baseStyle),
      ),
    if (safeEnd < text.length)
      TextSpan(text: text.substring(safeEnd), style: baseStyle),
  ];
}

TextSpan _inlineSpanFor(
  BuildContext context,
  InlineNode node,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  bool decorate = false,
}) {
  final undecoratedStyle = switch (node) {
    final TextRun textRun =>
      _textStyleForAttributes(baseStyle, textRun.attributes),
    final InlineEmbed embed =>
      _textStyleForAttributes(baseStyle, embed.attributes),
    _ => baseStyle,
  };
  final style =
      decorate ? _compositionTextStyle(undecoratedStyle) : undecoratedStyle;
  return switch (node) {
    final TextRun textRun => TextSpan(text: textRun.text, style: style),
    final InlineEmbed embed => _inlineEmbedSpanFor(
        context,
        embed,
        baseStyle,
        inlineEmbedRenderer,
        decorate: decorate,
      ),
    _ => TextSpan(text: node.plainText, style: style),
  };
}

TextSpan _inlineEmbedSpanFor(
  BuildContext context,
  InlineEmbed embed,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  bool decorate = false,
}) {
  final base = _textStyleForAttributes(baseStyle, embed.attributes);
  final style = decorate ? _compositionTextStyle(base) : base;
  final custom = inlineEmbedRenderer?.buildTextSpan(context, embed, style);
  if (custom != null) {
    return custom;
  }
  return TextSpan(
    text: _embedDisplayText(embed),
    style: _defaultInlineEmbedStyle(context, embed, style),
  );
}

TextStyle _defaultInlineEmbedStyle(
  BuildContext context,
  InlineEmbed embed,
  TextStyle style,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (embed.embedType) {
    'mention' => style.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
        backgroundColor: scheme.primaryContainer.withAlpha(80),
      ),
    'formula' => style.copyWith(
        color: scheme.onSecondaryContainer,
        backgroundColor: scheme.secondaryContainer.withAlpha(90),
        fontFamily: 'monospace',
      ),
    'emoji' => style,
    _ => style.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
  };
}

TextStyle _compositionTextStyle(TextStyle style) {
  final decoration = style.decoration;
  return style.copyWith(
    decoration: decoration == null
        ? TextDecoration.underline
        : TextDecoration.combine(<TextDecoration>[
            decoration,
            TextDecoration.underline,
          ]),
  );
}

String _embedDisplayText(InlineEmbed embed) {
  return switch (embed.embedType) {
    'mention' => _mentionDisplayText(embed),
    'image' => '[img]',
    'formula' => _formulaDisplayText(embed),
    'emoji' => _emojiDisplayText(embed),
    _ => '[${embed.embedType}]',
  };
}

String _inlineDisplayText(InlineNode node) {
  return switch (node) {
    TextRun() => node.text,
    InlineEmbed() => _embedDisplayText(node),
    _ => node.plainText,
  };
}

String _mentionDisplayText(InlineEmbed embed) {
  final raw = embed.data['label'] ?? embed.data['id'];
  final label = raw?.toString() ?? '';
  return label.isEmpty ? '@mention' : '@$label';
}

String _formulaDisplayText(InlineEmbed embed) {
  final raw = embed.data['text'] ?? embed.data['latex'] ?? embed.data['value'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[formula]' : text;
}

String _emojiDisplayText(InlineEmbed embed) {
  final raw = embed.data['emoji'] ??
      embed.data['text'] ??
      embed.data['value'] ??
      embed.data['shortName'] ??
      embed.data['label'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[emoji]' : text;
}

/// Splits a code string into up to three spans, underlining the composition
/// region.
TextSpan _codeSpan(
  String code,
  TextStyle codeStyle,
  _LocalSelectionRange? compositionRange,
) {
  if (compositionRange == null ||
      compositionRange.start == compositionRange.end) {
    return TextSpan(text: code, style: codeStyle);
  }
  final start = compositionRange.start.clamp(0, code.length).toInt();
  final end = compositionRange.end.clamp(start, code.length).toInt();
  final children = <TextSpan>[
    if (start > 0) TextSpan(text: code.substring(0, start), style: codeStyle),
    TextSpan(
      text: code.substring(start, end),
      style: codeStyle.copyWith(decoration: TextDecoration.underline),
    ),
    if (end < code.length)
      TextSpan(text: code.substring(end), style: codeStyle),
  ];
  return TextSpan(style: codeStyle, children: children);
}

const List<String> _kDefaultCodeLanguages = <String>[
  '',
  'dart',
  'javascript',
  'typescript',
  'python',
  'java',
  'kotlin',
  'swift',
  'go',
  'rust',
  'sql',
  'json',
  'yaml',
  'html',
  'css',
  'markdown',
  'bash',
];

List<String> _codeLanguageOptions(String current) {
  if (current.isEmpty || _kDefaultCodeLanguages.contains(current)) {
    return _kDefaultCodeLanguages;
  }
  return <String>[current, ..._kDefaultCodeLanguages];
}

String _codeLanguageLabel(String language) {
  return language.isEmpty ? 'Plain text' : language;
}

/// Maps a [CompositionState] to a local offset range when it targets the given
/// block/path, otherwise returns null.
_LocalSelectionRange? _localCompositionRange(
  CompositionState? state,
  String blockId,
  int blockIndex,
  PositionPath path,
) {
  if (state == null ||
      state.blockId != blockId ||
      state.blockIndex != blockIndex ||
      state.path != path ||
      state.isEmpty) {
    return null;
  }
  return _LocalSelectionRange(
    start: state.startOffset,
    end: state.endOffset,
  );
}

int? _caretOffsetForPath(
  DocumentSelection? selection,
  bool showCaret,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (!showCaret || selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId != blockId || position.path != path) {
    return null;
  }
  return position.offset.clamp(0, textLength).toInt();
}

bool _selectionTouchesPath(
  DocumentSelection? selection,
  int blockIndex,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (selection == null) {
    return false;
  }
  if (_selectionRangeForPath(selection, blockIndex, path, textLength) != null) {
    return true;
  }
  if (!selection.isCollapsed) {
    return false;
  }
  final position = selection.extent;
  return position.blockId == blockId && position.path == path;
}

List<FindReplaceMatch> _matchesForBlock(
  List<FindReplaceMatch> matches,
  int blockIndex,
) {
  if (matches.isEmpty) {
    return const <FindReplaceMatch>[];
  }
  return <FindReplaceMatch>[
    for (final match in matches)
      if (match.blockIndex == blockIndex) match,
  ];
}

List<_FindHighlightRange> _findRangesForPath(
  List<FindReplaceMatch> matches,
  FindReplaceMatch? current,
  int blockIndex,
  PositionPath path,
  int textLength,
) {
  if (matches.isEmpty) {
    return const <_FindHighlightRange>[];
  }
  return <_FindHighlightRange>[
    for (final match in matches)
      if (match.containsPath(path, blockIndex))
        _FindHighlightRange(
          start: match.start.clamp(0, textLength).toInt(),
          end: match.end.clamp(0, textLength).toInt(),
          active: match == current,
        ),
  ];
}

int? _debugOffsetForPath(
  DocumentSelection? selection,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (selection == null) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId != blockId || position.path != path) {
    return null;
  }
  return position.offset.clamp(0, textLength).toInt();
}

_LocalSelectionRange? _selectionRangeForPath(
  DocumentSelection? selection,
  int blockIndex,
  PositionPath path,
  int textLength,
) {
  if (selection == null || selection.isCollapsed) {
    return null;
  }
  final start = selection.start;
  final end = selection.end;
  int? localStart;
  int? localEnd;

  if (start.blockIndex == blockIndex) {
    final pathCompare = path.compare(start.path);
    if (pathCompare == 0) {
      localStart = start.offset;
    } else if (pathCompare > 0) {
      localStart = 0;
    }
  } else if (blockIndex > start.blockIndex) {
    localStart = 0;
  }

  if (end.blockIndex == blockIndex) {
    final pathCompare = path.compare(end.path);
    if (pathCompare == 0) {
      localEnd = end.offset;
    } else if (pathCompare < 0) {
      localEnd = textLength;
    }
  } else if (blockIndex < end.blockIndex) {
    localEnd = textLength;
  }

  if (localStart == null || localEnd == null) {
    return null;
  }
  final safeStart = localStart.clamp(0, textLength).toInt();
  final safeEnd = localEnd.clamp(0, textLength).toInt();
  if (safeStart == safeEnd) {
    return null;
  }
  return _LocalSelectionRange(
    start: safeStart < safeEnd ? safeStart : safeEnd,
    end: safeStart < safeEnd ? safeEnd : safeStart,
  );
}

TextStyle _textStyleForAttributes(TextStyle baseStyle, TextAttributes attrs) {
  final decorations = <TextDecoration>[
    if (attrs.underline == true || attrs.url != null) TextDecoration.underline,
    if (attrs.lineThrough == true) TextDecoration.lineThrough,
  ];
  return baseStyle.copyWith(
    color: attrs.color != null
        ? Color(attrs.color!)
        : attrs.url != null
            ? Colors.blue
            : null,
    backgroundColor: attrs.background != null ? Color(attrs.background!) : null,
    fontWeight: attrs.bold == true ? FontWeight.w700 : null,
    fontStyle: attrs.italic == true ? FontStyle.italic : null,
    fontSize: attrs.fontSize,
    fontFamily: attrs.fontFamily,
    decoration:
        decorations.isEmpty ? null : TextDecoration.combine(decorations),
  );
}

TextAlign _textAlign(String? alignment) {
  return switch (alignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

double _headingSize(int? level) {
  return switch (level) {
    1 => 24,
    2 => 21,
    3 => 18,
    _ => 16,
  };
}

String? _prefixFor(TextBlockNode block) {
  return switch (block.type) {
    BlockType.quote => '|',
    BlockType.listItem => switch (block.attributes.listType) {
        'ordered' => '1.',
        'task' => block.attributes.checked == true ? '[x]' : '[ ]',
        _ => '-',
      },
    _ => null,
  };
}

String _assetLabel(String assetId, String file) {
  if (file.isNotEmpty) {
    return file;
  }
  if (assetId.isNotEmpty) {
    return assetId;
  }
  return 'unknown';
}

String _imageAccessibleLabel(ImageBlockNode image) {
  if (image.altText.isNotEmpty) {
    return image.altText;
  }
  if (image.caption.isNotEmpty) {
    return image.caption;
  }
  return _assetLabel(image.assetId, image.file);
}

String _fileAccessibleLabel(FileBlockNode file) {
  final parts = <String>[
    file.displayName.isEmpty ? 'untitled file' : file.displayName,
  ];
  final metadata = _fileMetadata(file);
  if (metadata.isNotEmpty) {
    parts.add(metadata);
  }
  if (file.uploadStatus == FileUploadStatus.failed &&
      file.uploadError.isNotEmpty) {
    parts.add(file.uploadError);
  }
  return parts.join(', ');
}

String _fileMetadata(FileBlockNode file) {
  final parts = <String>[];
  if (file.size > 0) {
    parts.add(_formatFileSize(file.size));
  }
  if (file.mimeType.isNotEmpty) {
    parts.add(file.mimeType);
  }
  if (file.uploadStatus != FileUploadStatus.none) {
    parts.add(_fileUploadStatusLabel(file.uploadStatus));
  }
  return parts.join(' · ');
}

String _fileUploadStatusLabel(FileUploadStatus status) {
  return switch (status) {
    FileUploadStatus.none => '',
    FileUploadStatus.pending => 'Pending upload',
    FileUploadStatus.uploading => 'Uploading',
    FileUploadStatus.uploaded => 'Uploaded',
    FileUploadStatus.failed => 'Upload failed',
  };
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = -1;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fixed = value >= 10 || value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$fixed ${units[unit]}';
}

/// A lightweight identity for a caret position, used to detect "the caret
/// hasn't moved" between controller notifications (e.g. IME composition updates
/// that leave the caret's block and offset unchanged) and skip redundant work.
class _CaretKey {
  const _CaretKey(this.blockIndex, this.offset);

  final int blockIndex;
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CaretKey &&
          other.blockIndex == blockIndex &&
          other.offset == offset);

  @override
  int get hashCode => Object.hash(blockIndex, offset);
}
