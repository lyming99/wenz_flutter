import 'package:flutter/material.dart';

import '../controller/find_replace_controller.dart';
import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import 'block_geometry_registry.dart';
import 'inline_embed_renderer.dart';
import 'media_resolver.dart';

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

/// Bundles everything a block renderer needs to paint a block. Passed to every
/// [BlockRendererBuilder] so custom renderers get the same surface as the
/// built-in ones (selection, caret, geometry, IME composition, debug overlay).
///
/// Fields are intentionally the union of what each built-in renderer consumes;
/// a renderer is free to ignore the ones it does not need.
class BlockRenderContext {
  const BlockRenderContext({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
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
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;

  /// Optional [MediaResolver] injected via the editor. The built-in
  /// image/video/file renderers consult it before falling back to the
  /// placeholder. `null` when no resolver is injected. Custom renderers may
  /// read it too if they want to share the same resolution logic.
  final MediaResolver? mediaResolver;

  /// Optional inline embed renderer injected via the editor. The built-in text
  /// renderers consult it for [InlineEmbed]s before falling back to their
  /// default formula / mention / image labels.
  final InlineEmbedRenderer? inlineEmbedRenderer;

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

  /// Optional callback used by table renderers to persist drag-resized column
  /// widths through the host controller.
  final TableColumnResizeHandler? onTableColumnResize;

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

/// Builds a [Widget] for a single [BlockNode]. Registered per [BlockType] in a
/// [BlockRendererRegistry]. Custom renderers receive the same
/// [BlockRenderContext] the built-in ones do, so they can participate in
/// selection/caret/debug behaviour.
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
