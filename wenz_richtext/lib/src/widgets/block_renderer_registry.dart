import 'package:flutter/material.dart';

import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import 'block_geometry_registry.dart';
import 'inline_embed_renderer.dart';
import 'media_resolver.dart';

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

/// Maps [BlockType]s to [BlockRendererBuilder]s. The editor consults this
/// registry to paint each block; built-in types ship with default builders, and
/// plugins override or extend them via [register].
///
/// The registry is an indirection point: it lets a consumer replace how a given
/// block type renders (e.g. a custom image block with a real decoder) without
/// forking the editor widget.
///
/// To start from the built-in defaults, construct the registry and then call
/// [WenzRichTextEditor.installDefaultRenderers]; or use the editor's
/// [WenzRichTextEditor.blockRenderers] parameter — when omitted the editor
/// builds a private registry with the defaults already installed.
class BlockRendererRegistry {
  BlockRendererRegistry();

  final Map<BlockType, BlockRendererBuilder> _builders =
      <BlockType, BlockRendererBuilder>{};

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
}
