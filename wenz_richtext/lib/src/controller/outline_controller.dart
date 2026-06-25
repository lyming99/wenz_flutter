import 'package:flutter/foundation.dart';

import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

/// A heading entry derived from the current document.
///
/// Outline items are not stored in the document. They are recomputed from
/// heading blocks, carrying the heading's block id, index, level, visible title,
/// and optional explicit block anchor.
///
/// Heading collapse uses the same top-level heading source but remains view
/// state: paragraphs, quotes, lists, code, tables, media blocks, and object
/// blocks never own a collapse entry themselves.
class OutlineItem {
  const OutlineItem({
    required this.blockId,
    required this.blockIndex,
    required this.level,
    required this.title,
    this.anchor,
    this.collapseRange = OutlineCollapseRange.empty,
    this.isCollapsed = false,
  });

  final String blockId;
  final int blockIndex;
  final int level;
  final String title;
  final String? anchor;
  final OutlineCollapseRange collapseRange;
  final bool isCollapsed;

  /// Whether this heading currently has child blocks that can be hidden.
  bool get canCollapse => collapseRange.isNotEmpty;

  /// Top-level block ids covered when this heading is collapsed.
  List<String> get coveredBlockIds => collapseRange.blockIds;

  /// Top-level block indexes covered when this heading is collapsed.
  List<int> get coveredBlockIndexes => collapseRange.blockIndexes;

  /// Inclusive start index of covered blocks, or the insertion point after the
  /// heading when the range is empty.
  int get collapseStartBlockIndex => collapseRange.startBlockIndex;

  /// Exclusive end index of covered blocks.
  int get collapseEndBlockIndexExclusive =>
      collapseRange.endBlockIndexExclusive;

  /// Stable jump target exposed to business UIs. Explicit anchors win; block id
  /// remains a safe fallback for documents that have not assigned anchors yet.
  String get target => anchor?.isNotEmpty == true ? anchor! : blockId;

  bool get hasAnchor => anchor?.isNotEmpty == true;

  @override
  bool operator ==(Object other) {
    return other is OutlineItem &&
        other.blockId == blockId &&
        other.blockIndex == blockIndex &&
        other.level == level &&
        other.title == title &&
        other.anchor == anchor &&
        other.collapseRange == collapseRange &&
        other.isCollapsed == isCollapsed;
  }

  @override
  int get hashCode => Object.hash(
        blockId,
        blockIndex,
        level,
        title,
        anchor,
        collapseRange,
        isCollapsed,
      );
}

/// The top-level block range hidden by a collapsed outline heading.
class OutlineCollapseRange {
  const OutlineCollapseRange({
    required this.startBlockIndex,
    required this.endBlockIndexExclusive,
    this.blockIds = const <String>[],
  });

  static const OutlineCollapseRange empty = OutlineCollapseRange(
    startBlockIndex: 0,
    endBlockIndexExclusive: 0,
  );

  /// Inclusive start index in [WenzRichTextController.document.blocks].
  final int startBlockIndex;

  /// Exclusive end index in [WenzRichTextController.document.blocks].
  final int endBlockIndexExclusive;

  /// Top-level block ids in the covered range.
  final List<String> blockIds;

  int get length => endBlockIndexExclusive - startBlockIndex;
  bool get isEmpty => length <= 0;
  bool get isNotEmpty => !isEmpty;

  /// Inclusive end index, or `null` when the range is empty.
  int? get endBlockIndex => isEmpty ? null : endBlockIndexExclusive - 1;

  List<int> get blockIndexes {
    return List<int>.unmodifiable(
      Iterable<int>.generate(length, (offset) => startBlockIndex + offset),
    );
  }

  bool containsBlockId(String blockId) => blockIds.contains(blockId);

  bool containsBlockIndex(int blockIndex) {
    return blockIndex >= startBlockIndex && blockIndex < endBlockIndexExclusive;
  }

  @override
  bool operator ==(Object other) {
    return other is OutlineCollapseRange &&
        other.startBlockIndex == startBlockIndex &&
        other.endBlockIndexExclusive == endBlockIndexExclusive &&
        listEquals(other.blockIds, blockIds);
  }

  @override
  int get hashCode => Object.hash(
        startBlockIndex,
        endBlockIndexExclusive,
        Object.hashAll(blockIds),
      );
}

/// View-only projection of [RichTextDocument.blocks] after applying collapsed
/// outline ranges.
///
/// The projection never rewrites block ids or document indexes. Visible blocks
/// keep their original [BlockNode] instances and their indexes in the source
/// document are exposed through [visibleBlockIndexes].
class OutlineBlockProjection {
  const OutlineBlockProjection._({
    required this.sourceBlockCount,
    required this.visibleBlocks,
    required this.visibleBlockIndexes,
    required this.visibleBlockIds,
    required this.hiddenBlockIds,
    required this.hiddenBlockIndexes,
  });

  factory OutlineBlockProjection.all(List<BlockNode> blocks) {
    return OutlineBlockProjection._(
      sourceBlockCount: blocks.length,
      visibleBlocks: List<BlockNode>.unmodifiable(blocks),
      visibleBlockIndexes: List<int>.unmodifiable(
        Iterable<int>.generate(blocks.length),
      ),
      visibleBlockIds: Set<String>.unmodifiable(
        blocks.map((block) => block.id),
      ),
      hiddenBlockIds: const <String>{},
      hiddenBlockIndexes: const <int>{},
    );
  }

  factory OutlineBlockProjection.fromCollapsedItems({
    required List<BlockNode> blocks,
    required Iterable<OutlineItem> items,
  }) {
    if (blocks.isEmpty) {
      return OutlineBlockProjection.all(blocks);
    }

    final hiddenIndexes = <int>{};
    for (final item in items) {
      if (!item.isCollapsed || !item.canCollapse) {
        continue;
      }
      final start = item.collapseStartBlockIndex.clamp(0, blocks.length);
      final end = item.collapseEndBlockIndexExclusive.clamp(0, blocks.length);
      for (var index = start; index < end; index++) {
        hiddenIndexes.add(index);
      }
    }

    if (hiddenIndexes.isEmpty) {
      return OutlineBlockProjection.all(blocks);
    }

    final visibleBlocks = <BlockNode>[];
    final visibleIndexes = <int>[];
    final visibleIds = <String>{};
    final hiddenIds = <String>{};
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (hiddenIndexes.contains(index)) {
        hiddenIds.add(block.id);
        continue;
      }
      visibleBlocks.add(block);
      visibleIndexes.add(index);
      visibleIds.add(block.id);
    }

    return OutlineBlockProjection._(
      sourceBlockCount: blocks.length,
      visibleBlocks: List<BlockNode>.unmodifiable(visibleBlocks),
      visibleBlockIndexes: List<int>.unmodifiable(visibleIndexes),
      visibleBlockIds: Set<String>.unmodifiable(visibleIds),
      hiddenBlockIds: Set<String>.unmodifiable(hiddenIds),
      hiddenBlockIndexes: Set<int>.unmodifiable(hiddenIndexes),
    );
  }

  final int sourceBlockCount;
  final List<BlockNode> visibleBlocks;
  final List<int> visibleBlockIndexes;
  final Set<String> visibleBlockIds;
  final Set<String> hiddenBlockIds;
  final Set<int> hiddenBlockIndexes;

  bool get hasHiddenBlocks => hiddenBlockIds.isNotEmpty;

  bool isBlockHidden(String blockId) => hiddenBlockIds.contains(blockId);

  bool isBlockIndexHidden(int blockIndex) {
    return hiddenBlockIndexes.contains(blockIndex);
  }

  int? visibleIndexForBlockIndex(int blockIndex) {
    final visibleIndex = visibleBlockIndexes.indexOf(blockIndex);
    return visibleIndex < 0 ? null : visibleIndex;
  }

  int? nearestVisibleIndexForBlockIndex(int blockIndex) {
    if (visibleBlockIndexes.isEmpty) {
      return null;
    }
    var nearest = 0;
    for (var index = 0; index < visibleBlockIndexes.length; index++) {
      final documentIndex = visibleBlockIndexes[index];
      if (documentIndex == blockIndex) {
        return index;
      }
      if (documentIndex > blockIndex) {
        return index == 0 ? 0 : nearest;
      }
      nearest = index;
    }
    return nearest;
  }
}

/// Derives a document outline from heading blocks.
///
/// The controller listens to a [WenzRichTextController] and emits immutable
/// [OutlineItem] snapshots. Calling [select], [selectByBlockId], or
/// [selectByAnchor] moves the host selection to the heading start; a mounted
/// [WenzRichTextEditor] will then scroll the caret into view via its existing
/// selection handling.
///
/// Heading collapse interaction contract:
/// * A collapse handle is eligible only for a non-empty top-level
///   [TextBlockNode] whose [TextBlockNode.type] is [BlockType.heading].
/// * The covered range starts after that heading and stops before the next
///   heading whose normalized level is less than or equal to the current level;
///   lower-level headings and ordinary blocks stay inside the range.
/// * Empty headings or headings without covered child blocks should be treated
///   as non-collapsible or disabled.
/// * Toggling collapse is editor view state. It must not mutate document
///   content or enter undo/redo history, and read-only editors may still toggle
///   this view state.
///
/// Fold state is keyed by heading block id and remains independent from the
/// document model/history. Visible-block projection is layered on top of this
/// model by the widget layer.
class WenzOutlineController extends ChangeNotifier {
  WenzOutlineController({required WenzRichTextController editor})
      : _host = editor {
    _host.addListener(_handleHostChanged);
    _recompute();
  }

  final WenzRichTextController _host;

  WenzRichTextController get editor => _host;

  List<OutlineItem> _items = const <OutlineItem>[];
  List<OutlineItem> get items => _items;

  Set<String> _collapsedBlockIds = const <String>{};
  Set<String> get collapsedBlockIds =>
      Set<String>.unmodifiable(_collapsedBlockIds);

  OutlineBlockProjection visibleBlockProjection() {
    return OutlineBlockProjection.fromCollapsedItems(
      blocks: _host.document.blocks,
      items: _items,
    );
  }

  Set<String> get hiddenBlockIds => visibleBlockProjection().hiddenBlockIds;

  bool isBlockHidden(String blockId) {
    return visibleBlockProjection().isBlockHidden(blockId);
  }

  bool isBlockIndexHidden(int blockIndex) {
    return visibleBlockProjection().isBlockIndexHidden(blockIndex);
  }

  bool expandToRevealBlockId(String blockId) {
    final collapsedItems = _collapsedItemsCoveringBlockId(blockId);
    if (collapsedItems.isEmpty) {
      return false;
    }
    final next = Set<String>.of(_collapsedBlockIds);
    for (final item in collapsedItems) {
      next.remove(item.blockId);
    }
    _collapsedBlockIds = Set<String>.unmodifiable(next);
    _recompute();
    return true;
  }

  bool expandToRevealBlockIndex(int blockIndex) {
    final blocks = _host.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return false;
    }
    return expandToRevealBlockId(blocks[blockIndex].id);
  }

  bool expandToRevealBlockRange(int startBlockIndex, int endBlockIndex) {
    if (_collapsedBlockIds.isEmpty) {
      return false;
    }
    final start =
        startBlockIndex <= endBlockIndex ? startBlockIndex : endBlockIndex;
    final end =
        startBlockIndex <= endBlockIndex ? endBlockIndex : startBlockIndex;
    final blocks = _host.document.blocks;
    if (blocks.isEmpty) {
      return false;
    }
    final clampedStart = start.clamp(0, blocks.length - 1).toInt();
    final clampedEnd = end.clamp(0, blocks.length - 1).toInt();
    if (clampedStart > clampedEnd) {
      return false;
    }
    final next = Set<String>.of(_collapsedBlockIds);
    for (final item in _items) {
      if (!item.isCollapsed || !item.canCollapse) {
        continue;
      }
      final rangeStart = item.collapseStartBlockIndex;
      final rangeEnd = item.collapseEndBlockIndexExclusive - 1;
      if (rangeStart <= clampedEnd && rangeEnd >= clampedStart) {
        next.remove(item.blockId);
      }
    }
    if (setEquals(next, _collapsedBlockIds)) {
      return false;
    }
    _collapsedBlockIds = Set<String>.unmodifiable(next);
    _recompute();
    return true;
  }

  bool expandToRevealSelection(DocumentSelection? selection) {
    if (selection == null) {
      return false;
    }
    return expandToRevealBlockRange(
      selection.start.blockIndex,
      selection.end.blockIndex,
    );
  }

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  OutlineItem? itemForBlockId(String blockId) {
    for (final item in _items) {
      if (item.blockId == blockId) {
        return item;
      }
    }
    return null;
  }

  OutlineItem? itemForAnchor(String anchor) {
    final normalized = _normalizeAnchor(anchor);
    if (normalized == null) {
      return null;
    }
    for (final item in _items) {
      if (item.anchor == normalized) {
        return item;
      }
    }
    return null;
  }

  bool canCollapseByBlockId(String blockId) {
    return itemForBlockId(blockId)?.canCollapse ?? false;
  }

  bool canCollapseByAnchor(String anchor) {
    return itemForAnchor(anchor)?.canCollapse ?? false;
  }

  bool isCollapsed(String blockId) {
    final item = itemForBlockId(blockId);
    return item != null &&
        item.canCollapse &&
        _collapsedBlockIds.contains(blockId);
  }

  bool isCollapsedByAnchor(String anchor) {
    final item = itemForAnchor(anchor);
    return item != null && isCollapsed(item.blockId);
  }

  bool isCollapsedItem(OutlineItem item) => isCollapsed(item.blockId);

  OutlineCollapseRange? collapseRangeForBlockId(String blockId) {
    return itemForBlockId(blockId)?.collapseRange;
  }

  bool collapse(OutlineItem item) => collapseByBlockId(item.blockId);

  bool collapseByBlockId(String blockId) {
    return _setCollapsed(blockId: blockId, collapsed: true);
  }

  bool collapseByAnchor(String anchor) {
    final item = itemForAnchor(anchor);
    return item != null && collapse(item);
  }

  bool expand(OutlineItem item) => expandByBlockId(item.blockId);

  bool expandByBlockId(String blockId) {
    return _setCollapsed(blockId: blockId, collapsed: false);
  }

  bool expandByAnchor(String anchor) {
    final item = itemForAnchor(anchor);
    return item != null && expand(item);
  }

  bool toggle(OutlineItem item) => toggleByBlockId(item.blockId);

  bool toggleByBlockId(String blockId) {
    final item = itemForBlockId(blockId);
    if (item == null || !item.canCollapse) {
      return false;
    }
    return _setCollapsed(
      blockId: blockId,
      collapsed: !_collapsedBlockIds.contains(blockId),
    );
  }

  bool toggleByAnchor(String anchor) {
    final item = itemForAnchor(anchor);
    return item != null && toggle(item);
  }

  bool expandAll() {
    if (_collapsedBlockIds.isEmpty) {
      return false;
    }
    _collapsedBlockIds = const <String>{};
    _recompute();
    return true;
  }

  bool select(
    OutlineItem item, {
    bool requestFocus = true,
  }) {
    return selectByBlockId(item.blockId, requestFocus: requestFocus);
  }

  bool selectByBlockId(
    String blockId, {
    bool requestFocus = true,
  }) {
    final index = _host.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (index < 0) {
      return false;
    }
    final block = _host.document.blocks[index];
    if (block is! TextBlockNode || block.type != BlockType.heading) {
      return false;
    }
    expandToRevealBlockId(blockId);
    final position = DocumentPosition.text(
      blockId: block.id,
      blockIndex: index,
      offset: 0,
    );
    _host.setSelection(DocumentSelection(base: position, extent: position));
    if (requestFocus) {
      _host.requestFocus();
    }
    return true;
  }

  bool selectByAnchor(
    String anchor, {
    bool requestFocus = true,
  }) {
    final item = itemForAnchor(anchor);
    if (item == null) {
      return false;
    }
    return select(item, requestFocus: requestFocus);
  }

  @override
  void dispose() {
    _host.removeListener(_handleHostChanged);
    super.dispose();
  }

  void _handleHostChanged() {
    _recompute();
  }

  void _recompute() {
    final drafts = <_OutlineItemDraft>[];
    final collapsibleIds = <String>{};
    final blocks = _host.document.blocks;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block is! TextBlockNode || block.type != BlockType.heading) {
        continue;
      }
      final title = _normalizeTitle(block.plainText);
      if (title.isEmpty) {
        continue;
      }
      final rawLevel = block.attributes.level ?? 1;
      final level = rawLevel.clamp(1, 6).toInt();
      final collapseRange = _collapseRangeForHeading(
        blocks: blocks,
        headingIndex: i,
        headingLevel: level,
      );
      if (collapseRange.isNotEmpty) {
        collapsibleIds.add(block.id);
      }
      drafts.add(
        _OutlineItemDraft(
          blockId: block.id,
          blockIndex: i,
          level: level,
          title: title,
          anchor: _normalizeAnchor(block.attributes.anchor),
          collapseRange: collapseRange,
        ),
      );
    }

    final nextCollapsedBlockIds = Set<String>.unmodifiable(
      _collapsedBlockIds.where(collapsibleIds.contains),
    );
    final next = List<OutlineItem>.unmodifiable(
      drafts.map(
        (draft) => draft.toItem(
          isCollapsed: nextCollapsedBlockIds.contains(draft.blockId),
        ),
      ),
    );

    final itemsChanged = !listEquals(_items, next);
    final collapseStateChanged =
        !setEquals(_collapsedBlockIds, nextCollapsedBlockIds);
    if (!itemsChanged && !collapseStateChanged) {
      return;
    }
    _items = next;
    _collapsedBlockIds = nextCollapsedBlockIds;
    notifyListeners();
  }

  bool _setCollapsed({
    required String blockId,
    required bool collapsed,
  }) {
    final item = itemForBlockId(blockId);
    if (item == null || !item.canCollapse) {
      return false;
    }
    final next = Set<String>.of(_collapsedBlockIds);
    final changed = collapsed ? next.add(blockId) : next.remove(blockId);
    if (!changed) {
      return false;
    }
    if (collapsed) {
      _moveSelectionToHeadingIfCovered(item);
    }
    _collapsedBlockIds = Set<String>.unmodifiable(next);
    _recompute();
    return true;
  }

  void _moveSelectionToHeadingIfCovered(OutlineItem item) {
    final selection = _host.selection;
    if (selection == null || !item.canCollapse) {
      return;
    }
    final selectionStart = selection.start.blockIndex;
    final selectionEnd = selection.end.blockIndex;
    final rangeStart = item.collapseStartBlockIndex;
    final rangeEnd = item.collapseEndBlockIndexExclusive - 1;
    if (rangeStart > selectionEnd || rangeEnd < selectionStart) {
      return;
    }
    final position = DocumentPosition.text(
      blockId: item.blockId,
      blockIndex: item.blockIndex,
      offset: 0,
    );
    _host.setSelection(DocumentSelection(base: position, extent: position));
  }

  List<OutlineItem> _collapsedItemsCoveringBlockId(String blockId) {
    if (_collapsedBlockIds.isEmpty) {
      return const <OutlineItem>[];
    }
    final collapsedItems = <OutlineItem>[];
    for (final item in _items) {
      if (!item.isCollapsed || !item.canCollapse) {
        continue;
      }
      if (item.collapseRange.containsBlockId(blockId)) {
        collapsedItems.add(item);
      }
    }
    return collapsedItems;
  }
}

class _OutlineItemDraft {
  const _OutlineItemDraft({
    required this.blockId,
    required this.blockIndex,
    required this.level,
    required this.title,
    required this.anchor,
    required this.collapseRange,
  });

  final String blockId;
  final int blockIndex;
  final int level;
  final String title;
  final String? anchor;
  final OutlineCollapseRange collapseRange;

  OutlineItem toItem({required bool isCollapsed}) {
    return OutlineItem(
      blockId: blockId,
      blockIndex: blockIndex,
      level: level,
      title: title,
      anchor: anchor,
      collapseRange: collapseRange,
      isCollapsed: isCollapsed,
    );
  }
}

OutlineCollapseRange _collapseRangeForHeading({
  required List<BlockNode> blocks,
  required int headingIndex,
  required int headingLevel,
}) {
  final start = headingIndex + 1;
  var end = start;
  while (end < blocks.length) {
    final block = blocks[end];
    if (block is TextBlockNode && block.type == BlockType.heading) {
      final level = (block.attributes.level ?? 1).clamp(1, 6).toInt();
      if (level <= headingLevel) {
        break;
      }
    }
    end++;
  }
  return OutlineCollapseRange(
    startBlockIndex: start,
    endBlockIndexExclusive: end,
    blockIds: List<String>.unmodifiable(
      blocks.sublist(start, end).map((block) => block.id),
    ),
  );
}

String _normalizeTitle(String title) {
  return title.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _normalizeAnchor(String? anchor) {
  final trimmed = anchor?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
