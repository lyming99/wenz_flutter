import 'package:flutter/material.dart';

import '../controller/find_replace_controller.dart';
import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import 'block_geometry_registry.dart';
import 'inline_embed_renderer.dart';
import 'media_resolver.dart';
import 'object_block_toolbar_overlay.dart';
import 'table_floating_toolbar_overlay.dart';

export 'object_block_toolbar_overlay.dart'
    show
        ObjectBlockToolbarOverlayAnchor,
        ObjectBlockToolbarOverlayController,
        ObjectBlockToolbarOverlayHost,
        ObjectBlockToolbarOverlayRequest,
        ObjectBlockToolbarOverlayRequestBuilder;

export 'table_floating_toolbar_overlay.dart'
    show
        TableFloatingToolbarOverlayAnchor,
        TableFloatingToolbarOverlayController,
        TableFloatingToolbarOverlayHost,
        TableFloatingToolbarOverlayRequest,
        TableFloatingToolbarOverlayRequestBuilder;

enum TableToolbarAction {
  insertRowAbove,
  insertRowBelow,
  deleteRow,
  insertColumnBefore,
  insertColumnAfter,
  deleteColumn,
  toggleHeader,
  setBackgroundColor,
  clearBackgroundColor,
  alignLeft,
  alignCenter,
  alignRight,
  clearAlignment,
  mergeCells,
  splitCell,
  resetColumnWidth,
}

class TableToolbarActionIntent {
  const TableToolbarActionIntent({
    required this.action,
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    this.endRowIndex,
    this.endColumnIndex,
    this.backgroundColor,
  });

  final TableToolbarAction action;
  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final int? endRowIndex;
  final int? endColumnIndex;
  final int? backgroundColor;

  int get targetEndRowIndex => endRowIndex ?? rowIndex;
  int get targetEndColumnIndex => endColumnIndex ?? columnIndex;
}

typedef TableToolbarActionHandler = void Function(
    TableToolbarActionIntent intent);

typedef TableColumnResizeHandler = void Function({
  required int blockIndex,
  required int columnIndex,
  required double width,
});

typedef ImageBlockResizeHandler = void Function({
  required int blockIndex,
  required double width,
  required double height,
});

typedef TodoCheckedChangeHandler = void Function({
  required int blockIndex,
  required bool checked,
});

enum ObjectBlockAction {
  copyContent,
  copyReference,
  duplicate,
  moveUp,
  moveDown,
  delete,
  resetImageSize,
  setImageDisplayWidth,

  /// Sets or clears an image block's alignment.
  ///
  /// The [ObjectBlockActionIntent.value] payload must be `'left'`, `'center'`,
  /// `'right'`, or `null` to clear explicit alignment. Handlers should ignore
  /// unknown values.
  setImageBlockAlignment,
  markFileUploading,
  markFileUploaded,
  markFileFailed,
}

class ObjectBlockActionIntent {
  const ObjectBlockActionIntent({
    required this.action,
    required this.blockIndex,
    this.value,
  });

  final ObjectBlockAction action;
  final int blockIndex;

  /// Optional action payload. [ObjectBlockAction.setImageDisplayWidth] uses a
  /// `double` image width. [ObjectBlockAction.setImageBlockAlignment] uses a
  /// nullable `String` image block alignment payload: `'left'`, `'center'`,
  /// or `'right'` sets explicit alignment, and `null` clears it. Handlers
  /// should ignore unknown alignment values. Move actions may carry an `int`
  /// final block index from custom renderers; the editor-owned block handle may
  /// use an internal payload so grouped heading moves can preserve the original
  /// drop insertion boundary.
  final Object? value;
}

typedef ObjectBlockActionHandler = void Function(
  ObjectBlockActionIntent intent,
);

/// Editor-owned interaction contract for the top-level block drag handle.
///
/// The handle is row chrome: it belongs to the editor's top-level block shell,
/// not to [BlockRendererBuilder] output. Keeping the contract here lets custom
/// renderers rely on the same menu/reorder surface without wrapping their own
/// handle, and keeps nested surfaces (table cells, inline embeds, object-block
/// controls) out of row-sorting hit testing.
abstract final class BlockDragHandleSpec {
  /// Reserved leading gutter for row chrome, outside the renderer's content box.
  ///
  /// Editable rows that reserve the heading-collapse slot use this full rail:
  /// [hitSize].width (28 dp) + [chromeGap] (4 dp) + the compact heading
  /// collapse hit target (24 dp) + [gapToContent] (8 dp). Non-heading rows
  /// reserve the same width while outline chrome is attached so renderer
  /// content stays aligned across headings, paragraphs, code blocks, and other
  /// top-level blocks; when such a row has no actual collapse affordance, the
  /// editor reuses the collapse slot for its drag handle.
  static const double railWidth = 64.0;

  /// Legacy reference for a collapse-only affordance plus the standard content
  /// gap: compact heading collapse hit target (24 dp) + [gapToContent] (8 dp).
  /// The editor positions collapse chrome explicitly; read-only rows do not
  /// use this value to reserve a non-existent drag handle slot.
  static const double collapseChromeOverflow = 32.0;

  /// Gap between adjacent row-chrome hit targets, currently the drag handle and
  /// heading collapse button in editable outline rows.
  static const double chromeGap = 4.0;

  /// Standard gap between editable row chrome and the renderer content edge.
  /// Compact read-only heading collapse rows keep their no-drag slot instead
  /// of reserving the editable rail.
  static const double gapToContent = 8.0;

  /// Minimum pointer/focus hit target for mouse, touch, and keyboard traversal.
  static const Size hitSize = Size.square(28.0);

  /// Visual glyph size inside [hitSize].
  static const Size visualSize = Size.square(18.0);

  /// Top inset from the block row to the handle hit target. Renderers with tall
  /// content still anchor the handle near the first visual line/control row.
  static const double topInset = 1.0;

  /// Pointer movement that turns a handle press into a reorder drag. Releasing
  /// before this distance is treated as a menu click/tap.
  static const double dragStartSlop = 6.0;

  /// Opacity when the row is not hovered/focused and no menu/drag is active.
  static const double idleOpacity = 0.0;

  /// Opacity while the row or handle rail is hovered.
  static const double hoverOpacity = 0.72;

  /// Opacity while the handle has keyboard focus, its menu is open, or it drags.
  static const double activeOpacity = 1.0;

  /// Opacity for read-only/no-edit states. Disabled handles are not focusable.
  static const double disabledOpacity = 0.0;

  /// Whether a top-level block row may expose the handle/menu surface.
  static bool canShow({
    required bool canEdit,
    required int blockIndex,
    required int blockCount,
  }) {
    return canEdit && blockIndex >= 0 && blockIndex < blockCount;
  }

  /// Whether the row can enter drag-reorder mode.
  static bool canDragSort({
    required bool canEdit,
    required int blockIndex,
    required int blockCount,
  }) {
    return canShow(
          canEdit: canEdit,
          blockIndex: blockIndex,
          blockCount: blockCount,
        ) &&
        blockCount > 1;
  }

  /// Whether a menu/keyboard move-up action is legal for the row.
  static bool canMoveUp({
    required bool canEdit,
    required int blockIndex,
    required int blockCount,
  }) {
    return canDragSort(
          canEdit: canEdit,
          blockIndex: blockIndex,
          blockCount: blockCount,
        ) &&
        blockIndex > 0;
  }

  /// Whether a menu/keyboard move-down action is legal for the row.
  static bool canMoveDown({
    required bool canEdit,
    required int blockIndex,
    required int blockCount,
  }) {
    return canDragSort(
          canEdit: canEdit,
          blockIndex: blockIndex,
          blockCount: blockCount,
        ) &&
        blockIndex < blockCount - 1;
  }
}

/// Where a quoted text block sits within a run of consecutive quoted text
/// blocks. The built-in `_QuoteBlockSurface` reads it (via
/// [BlockRenderContext.quoteGroupPosition]) to redistribute its end-side
/// rounded corners so index-adjacent quote surfaces fuse into one continuous
/// background instead of leaving an inward notch at every join.
///
/// A run is decided purely by block order and quote state — index-adjacent
/// `TextBlockNode`s with `BlockAttributes.quoted == true` or legacy
/// `BlockType.quote` neighbours belong to it. An `indent` attribute does not
/// extend or break the run; a non-quote block terminates it and the quote keeps
/// [QuoteGroupPosition.standalone]. See "Consecutive quoted text block
/// background" in `docs/rendering.md`.
enum QuoteGroupPosition {
  /// No quote neighbour above or below. Both end-side corners stay
  /// rounded — the legacy, standalone appearance.
  standalone,

  /// Top of a run: keeps the top-end corner, squares the bottom edge so the
  /// quote directly below joins without a seam.
  first,

  /// Middle of a run: both vertical edges square so it bridges the quotes
  /// above and below without an inward notch.
  interior,

  /// Bottom of a run: keeps the bottom-end corner, squares the top edge so the
  /// quote directly above joins without a seam.
  last,
}

/// Bundles everything a block renderer needs to paint a block. Passed to every
/// [BlockRendererBuilder] so custom renderers get the same surface as the
/// built-in ones (selection, caret, geometry, IME composition, debug overlay).
///
/// Fields are intentionally the union of what each built-in renderer consumes;
/// a renderer is free to ignore the ones it does not need.
///
/// Row-level chrome such as the [BlockDragHandleSpec] surface is deliberately
/// editor-owned and sits outside renderer output. Renderers paint block content
/// only, which keeps default drag handles available to custom renderers and
/// prevents nested table-cell text or inline/object controls from becoming
/// sortable rows.
class BlockRenderContext {
  const BlockRenderContext({
    required this.block,
    required this.blockIndex,
    this.blockCount = 1,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.canEdit = true,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.listMarker,
    this.quoteGroupPosition = QuoteGroupPosition.standalone,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.tableToolbarOverlayController,
    this.objectBlockToolbarOverlayController,
    this.onTableColumnResize,
    this.onImageBlockResize,
    this.onTodoCheckedChanged,
    this.onObjectBlockAction,
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;

  /// Number of top-level blocks in the host editor. Defaults to one for
  /// hand-built contexts so boundary-sensitive actions stay disabled unless the
  /// host supplies the actual count.
  final int blockCount;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;

  /// Whether renderers should expose mutating controls. Read-only editors can
  /// still offer copy-style object actions through [onObjectBlockAction].
  final bool canEdit;

  /// Optional [MediaResolver] injected via the editor. The built-in
  /// image/video/file renderers consult it before falling back to the
  /// placeholder. `null` when no resolver is injected. Custom renderers may
  /// read it too if they want to share the same resolution logic.
  final MediaResolver? mediaResolver;

  /// Optional inline embed renderer injected via the editor. The built-in text
  /// renderers consult it for [InlineEmbed]s before falling back to their
  /// default formula / mention / image labels.
  final InlineEmbedRenderer? inlineEmbedRenderer;

  /// Optional list marker precomputed by the host editor for list item blocks.
  /// Ordered markers depend on sibling blocks, so the editor supplies them here
  /// instead of making renderers inspect the whole document.
  ///
  /// Convention: any rendering detail that depends on a block's siblings — not
  /// just list markers — is precomputed by the host from the block list and
  /// exposed here as an optional, nullable field that defaults to a standalone
  /// value when the host (or a hand-built context) omits it. Consecutive quoted
  /// background continuity uses the same pattern: the host derives each quoted
  /// text block's position in its continuous-quote group (first / interior /
  /// last) and supplies it here so `_QuoteBlockSurface` can fuse neighbours. See
  /// "Consecutive quoted text block background" in `docs/rendering.md`.
  final String? listMarker;

  /// Position of this quoted text block within its run of consecutive quoted
  /// text blocks, precomputed by the host editor. The built-in
  /// `_QuoteBlockSurface` reads it to fuse neighbours into one continuous
  /// background (corners, padding, accent bar redistribute by group position).
  ///
  /// Follows the same convention as [listMarker]: any rendering detail that
  /// depends on a block's siblings is precomputed by the host and supplied
  /// here. A run is decided purely by block order and quote state — an `indent`
  /// attribute does not extend or break it — so non-quote blocks and
  /// hand-built contexts default to [QuoteGroupPosition.standalone],
  /// preserving the legacy single-block appearance and leaving custom
  /// renderers unaffected. See "Consecutive quoted text block background" in
  /// `docs/rendering.md`.
  final QuoteGroupPosition quoteGroupPosition;

  /// Optional callback used by code block renderers to change the block's
  /// language through the host controller.
  final ValueChanged<String>? onCodeLanguageChanged;

  /// Optional callback used by code block renderers to copy the code text.
  final Future<void> Function(String code)? onCodeCopied;

  /// Optional callback used by callout renderers to change the block variant
  /// through the host controller.
  final ValueChanged<String>? onCalloutVariantChanged;

  /// Optional callback used by table renderers to route floating-toolbar table
  /// actions through the host controller.
  final TableToolbarActionHandler? onTableToolbarAction;

  /// Editor-owned overlay controller used by table renderers to publish toolbar
  /// requests without owning [OverlayEntry] / [OverlayPortal] lifecycle.
  final TableFloatingToolbarOverlayController? tableToolbarOverlayController;

  /// Editor-owned overlay controller used by object-block renderers to publish
  /// floating toolbar requests without owning [OverlayEntry] / [OverlayPortal]
  /// lifecycle. `null` for hand-built/custom contexts that do not opt in.
  final ObjectBlockToolbarOverlayController?
      objectBlockToolbarOverlayController;

  /// Optional callback used by table renderers to persist drag-resized column
  /// widths through the host controller.
  final TableColumnResizeHandler? onTableColumnResize;

  /// Optional callback used by image renderers to persist drag-resized display
  /// dimensions through the host controller.
  final ImageBlockResizeHandler? onImageBlockResize;

  /// Optional callback used by task-list renderers to persist checkbox changes.
  final TodoCheckedChangeHandler? onTodoCheckedChanged;

  /// Optional callback used by object-block renderers (image/video/file/embed
  /// and divider) to route quick actions through the host editor/controller.
  final ObjectBlockActionHandler? onObjectBlockAction;

  /// Optional view-state for a top-level heading's collapse affordance. `null`
  /// means the host editor is not exposing heading collapse for this block.
  ///
  /// The built-in editor paints the affordance in row chrome outside the
  /// renderer content box so heading text aligns with ordinary body text.
  final HeadingCollapseState? headingCollapseState;

  /// Optional callback used to toggle heading collapse view-state.
  final ValueChanged<String>? onHeadingCollapseToggled;

  /// Find/replace matches currently visible for this block renderer. Built-in
  /// text renderers paint them as non-destructive highlights; custom renderers
  /// can opt in by mapping these ranges onto their own text surfaces.
  final List<FindReplaceMatch> findMatches;

  /// The active find match, if any. It is also present in [findMatches].
  final FindReplaceMatch? currentFindMatch;

  /// Whether the active (collapsed) selection sits inside [block], i.e. this
  /// block owns the caret. Convenience for caret-aware renderers.
  bool get ownsCaret {
    final sel = selection;
    if (sel == null || !sel.isCollapsed) {
      return false;
    }
    return sel.extent.blockIndex == blockIndex &&
        sel.extent.blockId == block.id;
  }
}

/// Presentation-only collapse state for a top-level heading block.
class HeadingCollapseState {
  const HeadingCollapseState({
    required this.canCollapse,
    required this.isCollapsed,
    required this.hiddenBlockCount,
  });

  final bool canCollapse;
  final bool isCollapsed;
  final int hiddenBlockCount;

  bool get hasHiddenBlocks => hiddenBlockCount > 0;

  @override
  bool operator ==(Object other) {
    return other is HeadingCollapseState &&
        other.canCollapse == canCollapse &&
        other.isCollapsed == isCollapsed &&
        other.hiddenBlockCount == hiddenBlockCount;
  }

  @override
  int get hashCode => Object.hash(canCollapse, isCollapsed, hiddenBlockCount);
}

/// Builds a [Widget] for a single [BlockNode]. Registered per [BlockType] in a
/// [BlockRendererRegistry]. Custom renderers receive the same
/// [BlockRenderContext] the built-in ones do, so they can participate in
/// selection/caret/debug behaviour.
///
/// The editor invokes builders for the current visible block projection only.
/// Blocks hidden by heading collapse do not receive a render context, do not
/// trigger resolver work, and have their geometry retained only after they are
/// expanded again.
typedef BlockRendererBuilder = Widget Function(
  BuildContext context,
  BlockRenderContext renderContext,
);

/// Maps [BlockType]s and custom [BlockEmbedNode.embedType]s to
/// [BlockRendererBuilder]s. The editor consults this registry to paint each
/// block; built-in types ship with default builders, and plugins override or
/// extend them via [register] / [registerEmbed].
///
/// The registry is an indirection point: it lets a consumer replace how a given
/// block type renders (e.g. a custom image block with a real decoder) or how a
/// business embed type renders without forking the editor widget.
///
/// To start from the built-in defaults, construct the registry and then call
/// [WenzRichTextEditor.installDefaultRenderers]; or use the editor's
/// [WenzRichTextEditor.blockRenderers] parameter — when omitted the editor
/// builds a private registry with the defaults already installed.
class BlockRendererRegistry {
  BlockRendererRegistry({
    Map<BlockType, BlockRendererBuilder> builders =
        const <BlockType, BlockRendererBuilder>{},
    Map<String, BlockRendererBuilder> embedBuilders =
        const <String, BlockRendererBuilder>{},
  }) {
    _builders.addAll(builders);
    _embedBuilders.addAll(embedBuilders);
  }

  final Map<BlockType, BlockRendererBuilder> _builders =
      <BlockType, BlockRendererBuilder>{};
  final Map<String, BlockRendererBuilder> _embedBuilders =
      <String, BlockRendererBuilder>{};

  /// Registered block types in insertion order.
  Iterable<BlockType> get blockTypes => _builders.keys;

  /// Registered custom block embed types in insertion order.
  Iterable<String> get embedTypes => _embedBuilders.keys;

  /// Registers [builder] for [type], replacing any existing builder for that
  /// type. Returning the previous builder (if any) lets callers chain or wrap
  /// the default renderer.
  BlockRendererBuilder? register(BlockType type, BlockRendererBuilder builder) {
    final previous = _builders[type];
    _builders[type] = builder;
    return previous;
  }

  /// Removes the builder for [type], if any. The editor falls back to its
  /// plain-text default for that type.
  void unregister(BlockType type) {
    _builders.remove(type);
  }

  /// Returns the builder for [type], falling back to [fallback] when none is
  /// registered. The editor passes a plain-text fallback so unknown block types
  /// always render *something*.
  BlockRendererBuilder resolve(
    BlockType type, {
    required BlockRendererBuilder fallback,
  }) {
    return _builders[type] ?? fallback;
  }

  /// Whether a builder is registered for [type].
  bool has(BlockType type) => _builders.containsKey(type);

  /// Registers [builder] for a custom [BlockEmbedNode.embedType]. Returning the
  /// previous builder lets callers chain or wrap an existing business renderer.
  BlockRendererBuilder? registerEmbed(
    String embedType,
    BlockRendererBuilder builder,
  ) {
    final previous = _embedBuilders[embedType];
    _embedBuilders[embedType] = builder;
    return previous;
  }

  /// Removes the builder for [embedType], if any. The editor then falls back to
  /// the generic [BlockType.embed] renderer.
  void unregisterEmbed(String embedType) {
    _embedBuilders.remove(embedType);
  }

  /// Whether a builder is registered for [embedType].
  bool hasEmbed(String embedType) => _embedBuilders.containsKey(embedType);

  /// Resolves the best builder for [block]. Custom [BlockEmbedNode.embedType]
  /// builders win over the generic [BlockType.embed] builder; all other blocks
  /// use their [BlockType] mapping.
  BlockRendererBuilder resolveForBlock(
    BlockNode block, {
    required BlockRendererBuilder fallback,
  }) {
    if (block is BlockEmbedNode) {
      final embedBuilder = _embedBuilders[block.normalizedEmbedType] ??
          _embedBuilders[block.embedType];
      if (embedBuilder != null) {
        return embedBuilder;
      }
    }
    return resolve(block.type, fallback: fallback);
  }
}
