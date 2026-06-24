import 'package:flutter/foundation.dart';

import '../core/model/block_node.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

/// A heading entry derived from the current document.
///
/// Outline items are not stored in the document. They are recomputed from
/// heading blocks, carrying the heading's block id, index, level, visible title,
/// and optional explicit block anchor.
class OutlineItem {
  const OutlineItem({
    required this.blockId,
    required this.blockIndex,
    required this.level,
    required this.title,
    this.anchor,
  });

  final String blockId;
  final int blockIndex;
  final int level;
  final String title;
  final String? anchor;

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
        other.anchor == anchor;
  }

  @override
  int get hashCode => Object.hash(blockId, blockIndex, level, title, anchor);
}

/// Derives a document outline from heading blocks.
///
/// The controller listens to a [WenzRichTextController] and emits immutable
/// [OutlineItem] snapshots. Calling [select], [selectByBlockId], or
/// [selectByAnchor] moves the host selection to the heading start; a mounted
/// [WenzRichTextEditor] will then scroll the caret into view via its existing
/// selection handling.
class WenzOutlineController extends ChangeNotifier {
  WenzOutlineController({required WenzRichTextController editor})
      : _host = editor {
    _host.addListener(_handleHostChanged);
    _recompute();
  }

  final WenzRichTextController _host;

  List<OutlineItem> _items = const <OutlineItem>[];
  List<OutlineItem> get items => _items;

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
    final next = <OutlineItem>[];
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
      next.add(
        OutlineItem(
          blockId: block.id,
          blockIndex: i,
          level: rawLevel.clamp(1, 6).toInt(),
          title: title,
          anchor: _normalizeAnchor(block.attributes.anchor),
        ),
      );
    }

    if (listEquals(_items, next)) {
      return;
    }
    _items = List<OutlineItem>.unmodifiable(next);
    notifyListeners();
  }
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
