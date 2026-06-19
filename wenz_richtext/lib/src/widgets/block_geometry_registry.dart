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
class BlockGeometryRegistry extends ChangeNotifier {
  final List<BlockEntry> _entries = <BlockEntry>[];

  /// Registers a block/path surface. Replaces any prior entry with the same
  /// [blockId] and [BlockEntry.path].
  void register(BlockEntry entry) {
    final index = _entries.indexWhere((e) => e.matches(entry.blockId, entry.path));
    if (index >= 0) {
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
  }

  /// Removes the entry for [blockId] and [path], if present. When [path] is not
  /// provided, removes every surface for [blockId].
  void unregister(String blockId, [PositionPath? path]) {
    _entries.removeWhere(
      (e) => e.blockId == blockId && (path == null || e.path == path),
    );
  }

  /// All registered entries in block-index order.
  @visibleForTesting
  List<BlockEntry> get entries => List<BlockEntry>.unmodifiable(_entries);

  /// Resolves a global screen offset to a [DocumentPosition].
  ///
  /// If the point lands inside a registered block's render box, the position
  /// is computed from that block's local coordinates. Otherwise the nearest
  /// block is chosen by vertical proximity and the caret is clamped to that
  /// block's start or end — so a drag into the gap between blocks (or beyond
  /// the last block) still extends the selection predictably.
  DocumentPosition? positionFromGlobalOffset(Offset global) {
    for (final entry in _entries) {
      final box = entry.renderBox;
      if (box == null) {
        continue;
      }
      final local = box.globalToLocal(global);
      if (local.dx >= 0 &&
          local.dx <= box.size.width &&
          local.dy >= 0 &&
          local.dy <= box.size.height) {
        return DocumentPosition(
          blockId: entry.blockId,
          blockIndex: entry.blockIndex,
          path: entry.path,
          offset: entry.positionFromLocal(local),
        );
      }
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
      final box = entry.renderBox;
      if (box == null) {
        continue;
      }
      final origin = box.localToGlobal(Offset.zero);
      final top = origin.dy;
      final bottom = origin.dy + box.size.height;
      if (global.dy < top) {
        final delta = top - global.dy;
        if (delta < nearestDelta) {
          nearestDelta = delta;
          nearest = entry;
          clampToEnd = false;
        }
      } else if (global.dy > bottom) {
        final delta = global.dy - bottom;
        if (delta < nearestDelta) {
          nearestDelta = delta;
          nearest = entry;
          clampToEnd = true;
        }
      }
    }
    if (nearest == null) {
      return null;
    }
    final offset = clampToEnd ? nearest.textLength : 0;
    return DocumentPosition(
      blockId: nearest.blockId,
      blockIndex: nearest.blockIndex,
      path: nearest.path,
      offset: offset,
    );
  }

  /// Returns the global [Rect] of the block whose render box contains [global],
  /// or the nearest block's rect if none contains it. Used by the gesture
  /// overlay to drive auto-scroll near viewport edges.
  Rect? blockRectFromGlobalOffset(Offset global) {
    for (final entry in _entries) {
      final box = entry.renderBox;
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
    // Fall back to the vertically-nearest block's rect.
    BlockEntry? nearest;
    var nearestDelta = double.infinity;
    for (final entry in _entries) {
      final box = entry.renderBox;
      if (box == null) {
        continue;
      }
      final origin = box.localToGlobal(Offset.zero);
      final top = origin.dy;
      final bottom = origin.dy + box.size.height;
      final delta = (global.dy < top
          ? top - global.dy
          : (global.dy > bottom ? global.dy - bottom : 0))
          .toDouble();
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearest = entry;
      }
    }
    if (nearest == null) {
      return null;
    }
    final box = nearest.renderBox!;
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

  BlockEntry? _entry(String blockId, PositionPath? path) {
    final index = _entries.indexWhere(
      (e) => e.blockId == blockId && (path == null || e.path == path),
    );
    return index >= 0 ? _entries[index] : null;
  }
}

/// A registered editable block's geometry and layout access.
class BlockEntry {
  BlockEntry({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.textLength,
    required this.key,
    required this.positionFromLocal,
    required this.wordRangeAt,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int textLength;
  final GlobalKey key;

  bool matches(String otherBlockId, PositionPath otherPath) {
    return blockId == otherBlockId && path == otherPath;
  }

  /// Converts a local offset (relative to this block's render box) to a
  /// character offset within the block's text.
  final int Function(Offset local) positionFromLocal;

  /// Returns the word range covering [offset] using this block's text layout.
  final TextRange Function(int offset) wordRangeAt;

  RenderBox? get renderBox {
    final context = key.currentContext;
    final object = context?.findRenderObject();
    return object is RenderBox ? object : null;
  }
}
