import 'package:flutter/widgets.dart';

import '../core/position/document_position.dart';

/// Resolves a global screen coordinate to a [DocumentPosition] across all
/// registered editable blocks.
///
/// Each [_TextSelectionSurface] registers itself (via [register]) with its
/// block id, path, text length, a [GlobalKey] on its render object, and a
/// callback that converts a *local* offset to a character offset using its
/// own [TextLayoutService]. The document-level gesture overlay queries the
/// registry during a drag to map the pointer position to a document position,
/// which may live in a different block than where the drag started — enabling
/// cross-block drag selection.
class BlockGeometryRegistry {
  BlockGeometryRegistry();

  /// Entries in block-index order, for ordered traversal (hit-testing,
  /// nearest-block clamping, average height).
  final List<BlockEntry> _entries = <BlockEntry>[];

  /// O(1) lookup by (blockId, path). Kept in sync with [_entries] on
  /// register/unregister so hot paths (caret rect, word range, vertical move —
  /// hit on every IME keystroke and every drag move) avoid a linear scan.
  final Map<String, BlockEntry> _byKey = <String, BlockEntry>{};

  /// Registers a block/path surface. Replaces any prior entry with the same
  /// [blockId] and [BlockEntry.path].
  void register(BlockEntry entry) {
    final key = _key(entry.blockId, entry.path);
    final existing = _byKey[key];
    if (existing != null) {
      final index = _entries.indexOf(existing);
      _entries[index] = entry;
    } else {
      _entries.add(entry);
      _entries.sort((a, b) {
        final blockOrder = a.blockIndex.compareTo(b.blockIndex);
        if (blockOrder != 0) {
          return blockOrder;
        }
        return a.path.compare(b.path);
      });
    }
    _byKey[key] = entry;
  }

  /// Removes the entry for [blockId] and [path], if present. When [path] is not
  /// provided, removes every surface for [blockId].
  void unregister(String blockId, [PositionPath? path]) {
    if (path != null) {
      final key = _key(blockId, path);
      final entry = _byKey.remove(key);
      if (entry != null) {
        _entries.remove(entry);
      }
      return;
    }
    _entries.removeWhere((e) {
      if (e.blockId != blockId) {
        return false;
      }
      _byKey.remove(_key(e.blockId, e.path));
      return true;
    });
  }

  static String _key(String blockId, PositionPath path) =>
      '$blockId@${path.hashCode}';

  /// All registered entries in block-index order.
  @visibleForTesting
  List<BlockEntry> get entries => List<BlockEntry>.unmodifiable(_entries);

  /// The bottom edge of the document content in global coordinates, taken from
  /// the lowest mounted block surface. Used by the editor to tell whether a
  /// page-jump target overshoots the document (a short doc paged past its end)
  /// so the caret can jump to the document boundary instead of relying on the
  /// ambiguous nearest-block clamp. Returns `null` when no surface is laid out.
  double? contentExtent() {
    double? bottom;
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null || !box.hasSize) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (bottom == null || rect.bottom > bottom) {
        bottom = rect.bottom;
      }
    }
    return bottom;
  }

  /// Average height of the currently-mounted block surfaces and the smallest
  /// block index among them. Used by the editor to estimate a scroll offset
  /// when a programmatic caret jump targets a virtualised (un-mounted) block:
  /// the stride × index gives a rough pixel offset close enough for ListView
  /// to build the target block, after which a follow-up frame pixel-aligns.
  ///
  /// Returns `null` when no surfaces are currently laid out.
  ({double meanHeight, int firstBlockIndex})? averageMountedBlockHeight() {
    var totalHeight = 0.0;
    var counted = 0;
    var firstIndex = -1;
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null || !box.hasSize) {
        continue;
      }
      if (firstIndex < 0) {
        firstIndex = entry.blockIndex;
      }
      totalHeight += box.size.height;
      counted += 1;
    }
    if (counted == 0 || firstIndex < 0) {
      return null;
    }
    return (meanHeight: totalHeight / counted, firstBlockIndex: firstIndex);
  }

  /// Resolves a global screen offset to a [DocumentPosition].
  ///
  /// If the point lands inside a registered block's hit-test box (the whole
  /// cell frame for table cells, otherwise the text surface itself), the
  /// position is computed from that block's *text-local* coordinates — the
  /// hit-test local offset is first translated through the entry's
  /// [BlockEntry.hitLocalToTextLocal] so padding/centring offsets are stripped.
  /// Otherwise the nearest block is chosen by 2-D rect proximity and the caret
  /// is clamped to that block's start or end — so a drag into the gap between
  /// blocks (or beyond the last block) still extends the selection predictably.
  DocumentPosition? positionFromGlobalOffset(Offset global) {
    BlockEntry? hitEntry;
    Offset? hitTextLocal;
    var nearestHitDelta = double.infinity;
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null) {
        continue;
      }
      final local = box.globalToLocal(global);
      if (local.dx >= 0 &&
          local.dx <= box.size.width &&
          local.dy >= 0 &&
          local.dy <= box.size.height) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final delta = (global - rect.center).distanceSquared;
        if (delta < nearestHitDelta) {
          nearestHitDelta = delta;
          hitEntry = entry;
          hitTextLocal = entry.hitLocalToTextLocal(local);
        }
      }
    }
    if (hitEntry != null && hitTextLocal != null) {
      return DocumentPosition(
        blockId: hitEntry.blockId,
        blockIndex: hitEntry.blockIndex,
        path: hitEntry.path,
        offset: hitEntry.positionFromLocal(hitTextLocal),
      );
    }
    // Missed every block: clamp to the nearest block's start/end.
    return _clampToNearest(global);
  }

  DocumentPosition? _clampToNearest(Offset global) {
    if (_entries.isEmpty) {
      return null;
    }
    BlockEntry? nearest;
    var nearestDelta = double.infinity;
    var clampToEnd = false;
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      // 2-D distance from the point to the rect (0 when inside). Using both
      // axes — not just vertical proximity — keeps a tap in a table cell's
      // padding from being mis-attributed to a neighbouring cell/column, and a
      // tap above/below a short cell from jumping to an adjacent row.
      final dx = global.dx < rect.left
          ? rect.left - global.dx
          : (global.dx > rect.right ? global.dx - rect.right : 0.0);
      final dy = global.dy < rect.top
          ? rect.top - global.dy
          : (global.dy > rect.bottom ? global.dy - rect.bottom : 0.0);
      final delta = dx * dx + dy * dy;
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearest = entry;
        // Clamp to the end when the point sits to the right of / below the
        // rect, to the start otherwise. This generalises the old vertical-only
        // rule and behaves identically for paragraph cross-block drags while
        // also handling 2-D table geometries.
        clampToEnd = global.dx > rect.right || global.dy > rect.bottom;
      }
    }
    if (nearest == null) {
      return null;
    }
    // Resolve the caret using the tap's horizontal column when it falls inside
    // the block's width. Project the point onto the block's nearest edge so it
    // lands on the block's first line (above) / last line (below), then let the
    // block's own layout map the (x, line) to a character offset. This keeps a
    // gap-tap on the 4th column landing at ~offset 4 instead of always 0/end.
    // Only when the tap is horizontally outside the block do we fall back to the
    // hard 0 / textLength edges.
    final box = nearest.hitTestBox;
    if (box != null) {
      final origin = box.localToGlobal(Offset.zero);
      if (global.dx >= origin.dx && global.dx <= origin.dx + box.size.width) {
        final rect = origin & box.size;
        final edgeY = clampToEnd ? rect.bottom - 1 : rect.top + 1;
        final clamped = Offset(global.dx, edgeY.clamp(rect.top, rect.bottom));
        final local = box.globalToLocal(clamped);
        final textLocal = nearest.hitLocalToTextLocal(local);
        return DocumentPosition(
          blockId: nearest.blockId,
          blockIndex: nearest.blockIndex,
          path: nearest.path,
          offset: nearest.positionFromLocal(textLocal),
        );
      }
    }
    final offset = clampToEnd ? nearest.textLength : 0;
    return DocumentPosition(
      blockId: nearest.blockId,
      blockIndex: nearest.blockIndex,
      path: nearest.path,
      offset: offset,
    );
  }

  /// Returns the global [Rect] of the block whose hit-test box contains
  /// [global], or the nearest block's rect if none contains it. Used by the
  /// gesture overlay to drive auto-scroll near viewport edges.
  Rect? blockRectFromGlobalOffset(Offset global) {
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null) {
        continue;
      }
      final local = box.globalToLocal(global);
      if (local.dx >= 0 &&
          local.dx <= box.size.width &&
          local.dy >= 0 &&
          local.dy <= box.size.height) {
        final origin = box.localToGlobal(Offset.zero);
        return origin & box.size;
      }
    }
    // Fall back to the 2-D-nearest block's rect.
    BlockEntry? nearest;
    var nearestDelta = double.infinity;
    for (final entry in _entries) {
      final box = entry.hitTestBox;
      if (box == null) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final dx = global.dx < rect.left
          ? rect.left - global.dx
          : (global.dx > rect.right ? global.dx - rect.right : 0.0);
      final dy = global.dy < rect.top
          ? rect.top - global.dy
          : (global.dy > rect.bottom ? global.dy - rect.bottom : 0.0);
      final delta = dx * dx + dy * dy;
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearest = entry;
      }
    }
    if (nearest == null) {
      return null;
    }
    final box = nearest.hitTestBox!;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  /// Returns the word range covering [offset] in the block/path with [blockId],
  /// for double-click selection. Returns null when no surface is registered.
  TextRange? wordRangeAt(String blockId, int offset, {PositionPath? path}) {
    final entry = _entry(blockId, path);
    return entry?.wordRangeAt(offset);
  }

  /// Returns the full editable range of the block/path with [blockId], for
  /// triple-click (select-paragraph) selection.
  TextRange? paragraphRange(String blockId, {PositionPath? path}) {
    final entry = _entry(blockId, path);
    if (entry == null) {
      return null;
    }
    return TextRange(start: 0, end: entry.textLength);
  }

  /// Returns the caret's global [Rect] for [position], or `null` when the
  /// owning block surface is not registered / not laid out. Used by the IME
  /// bridge to anchor the platform candidate window at the caret.
  Rect? caretRectForPosition(DocumentPosition position) {
    final entry = _entry(position.blockId, position.path);
    if (entry == null) {
      return null;
    }
    return entry.caretRectAt(position.offset);
  }

  /// Returns TextInput geometry for the editable surface that owns [position].
  ///
  /// The platform API mirrors [EditableText]: it expects the full editable
  /// render box size + transform, with caret/composing rects expressed in that
  /// render box's local coordinate space.
  BlockTextInputGeometry? textInputGeometryForPosition(
    DocumentPosition position, {
    TextRange? composingRange,
  }) {
    final entry = _entry(position.blockId, position.path);
    final box = entry?.renderBox;
    if (entry == null || box == null || !box.hasSize) {
      return null;
    }
    final caretRect = entry.localCaretRectAt(position.offset);
    if (caretRect == null) {
      return null;
    }
    Rect? composingRect;
    final range = composingRange;
    if (range != null &&
        range.start >= 0 &&
        range.end >= range.start &&
        !range.isCollapsed) {
      composingRect = entry.localComposingRectForRange(
        range.start,
        range.end,
      );
    }
    return BlockTextInputGeometry(
      editableSize: box.size,
      transform: box.getTransformTo(null),
      caretRect: caretRect,
      composingRect: composingRect ?? caretRect,
      globalCaretRect: box.localToGlobal(caretRect.topLeft) & caretRect.size,
    );
  }

  /// Resolves one visual-line vertical move from [position]. Returns the
  /// target offset (in the same block) when a neighbouring line exists, or a
  /// result with `targetOffset == null` when the caret is on the block's
  /// first/last line (caller should cross blocks). [preferX] is the remembered
  /// horizontal column (LOCAL coordinate space) for repeated moves; the caret's
  /// current local x is returned via [VerticalMoveResult.caretX] so the caller
  /// can seed it.
  VerticalMoveResult? verticalMoveForPosition(
    DocumentPosition position,
    bool forward, {
    double? preferX,
  }) {
    final entry = _entry(position.blockId, position.path);
    if (entry == null) {
      return null;
    }
    return entry.verticalMoveAt(position.offset, forward, preferX);
  }

  BlockEntry? _entry(String blockId, PositionPath? path) {
    if (path == null) {
      // No path disambiguator: fall back to a linear scan (rare; used only by
      // callers that don't distinguish same-block surfaces).
      for (final entry in _entries) {
        if (entry.blockId == blockId) {
          return entry;
        }
      }
      return null;
    }
    return _byKey[_key(blockId, path)];
  }
}

/// A registered editable block's geometry and layout access.
///
/// Each entry tracks **two** render boxes:
/// - [renderBox] (via [key]) is the *text surface* — the box the laid-out
///   [TextPainter] is painted into. It anchors caret/selection painting and
///   [caretRectAt] global positioning, so it must be the box whose local
///   coordinate space matches the painter's.
/// - [hitTestBox] (via [hitTestKey]) is the *hit-test frame* — the box used for
///   [BlockGeometryRegistry.positionFromGlobalOffset] containment and
///   nearest-block clamping. For plain surfaces these are the same box; for
///   table cells the hit-test frame is the whole cell (padding + centred text)
///   while the text surface is only the centred text region. [hitLocalToTextLocal]
///   translates a hit-test-local offset back into the text surface's local
///   space so [positionFromLocal] receives the coordinate the painter expects.
class BlockEntry {
  BlockEntry({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.textLength,
    required this.key,
    required this.positionFromLocal,
    required this.wordRangeAt,
    required this.caretRectAt,
    required this.localCaretRectAt,
    required this.localComposingRectForRange,
    required this.verticalMoveAt,
    this.hitTestKey,
    Offset Function(Offset)? hitLocalToTextLocal,
  }) : _hitLocalToTextLocal = hitLocalToTextLocal;

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int textLength;

  /// GlobalKey on the text surface render box (painter's local space).
  final GlobalKey key;

  /// GlobalKey on the hit-test frame render box. When `null`, [key] is used.
  /// Set for table cells where the hit-test frame (whole cell) differs from
  /// the text surface (centred text).
  final GlobalKey? hitTestKey;

  bool matches(String otherBlockId, PositionPath otherPath) {
    return blockId == otherBlockId && path == otherPath;
  }

  /// Converts a local offset in the text surface's coordinate space to a
  /// character offset within the block's text.
  final int Function(Offset local) positionFromLocal;

  /// Returns the word range covering [offset] using this block's text layout.
  final TextRange Function(int offset) wordRangeAt;

  /// Returns the caret's global [Rect] (top-left + height) for the given
  /// character [offset] in this block, or `null` when unavailable. Used by the
  /// IME bridge to position the platform candidate window at the caret.
  final Rect? Function(int offset) caretRectAt;

  /// Returns the caret rect in the text surface's local coordinate space.
  final Rect? Function(int offset) localCaretRectAt;

  /// Returns the composing text rect in the text surface's local coordinate
  /// space for [start, end), or `null` when the layout cannot resolve it.
  final Rect? Function(int start, int end) localComposingRectForRange;

  /// Moves [offset] one visual line down ([forward]=true) or up within this
  /// block, keeping the horizontal column at [preferX] (in the block's LOCAL
  /// coordinate space) when provided (for repeated vertical moves). Returns
  /// the target offset (or `null` at a block boundary) plus the caret's local
  /// x so the caller can remember the column.
  final VerticalMoveResult Function(int offset, bool forward, double? preferX)
      verticalMoveAt;

  /// Translates an offset in the hit-test frame's local space into the text
  /// surface's local space. Defaults to identity when [hitTestKey] == [key]
  /// (plain paragraph/code surfaces). For table cells it strips the cell
  /// padding and re-centres the point onto the laid-out text region.
  final Offset Function(Offset)? _hitLocalToTextLocal;

  /// The text surface render box (painter's local space). Null until laid out.
  RenderBox? get renderBox {
    final context = key.currentContext;
    final object = context?.findRenderObject();
    return object is RenderBox ? object : null;
  }

  /// The hit-test frame render box. Falls back to [renderBox] when no separate
  /// [hitTestKey] is registered (the common case).
  RenderBox? get hitTestBox {
    final hitKey = hitTestKey;
    if (hitKey == null) {
      return renderBox;
    }
    final context = hitKey.currentContext;
    final object = context?.findRenderObject();
    return object is RenderBox ? object : null;
  }

  /// Translates a hit-test-local offset to a text-local offset, applying the
  /// registered transform or identity when none was provided.
  Offset hitLocalToTextLocal(Offset local) =>
      (_hitLocalToTextLocal ?? _identity)(local);

  static Offset _identity(Offset local) => local;
}

/// Outcome of a vertical (Up/Down) move query.
class VerticalMoveResult {
  const VerticalMoveResult({this.targetOffset, this.caretX});

  /// The offset one line up/down within the same block, or `null` when the
  /// caret is on the block boundary (caller crosses blocks).
  final int? targetOffset;

  /// The caret's current horizontal position, to remember across repeated
  /// vertical moves. `null` when unavailable.
  final double? caretX;
}

class BlockTextInputGeometry {
  const BlockTextInputGeometry({
    required this.editableSize,
    required this.transform,
    required this.caretRect,
    required this.composingRect,
    required this.globalCaretRect,
  });

  final Size editableSize;
  final Matrix4 transform;
  final Rect caretRect;
  final Rect composingRect;
  final Rect globalCaretRect;
}
