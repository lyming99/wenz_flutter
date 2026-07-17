import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../rendering/text_layout_service.dart';

/// Document-level cache of [TextLayoutService] instances keyed by a surface's
/// `(blockId, path)` identity.
///
/// Each [_TextSelectionSurface] used to own a private [TextLayoutService] that
/// was discarded on dispose. Under virtualisation a block scrolled out of view
/// unmounts its surface, so the next time it scrolled back it had to rebuild
/// and re-lay-out its [TextPainter] from scratch. This cache keeps the
/// laid-out painter alive across remount, so returning a block into view skips
/// the re-measure.
///
/// Lifecycle:
/// - [entryFor] lazily creates / returns the [TextLayoutService] for a surface.
///   It must not be disposed on surface unmount; the cache owns it.
/// - [invalidate] drops a surface's entry when its content changed (signalled
///   by `WenzRichTextController.lastChangedBlockIds`) so a stale painter is not
///   reused.
/// - [removeBlock] drops all entries for a removed block id.
/// - [dispose] releases every entry (editor teardown).
///
/// Entries use access-order LRU eviction and both an entry cap and an estimated
/// byte budget. The byte estimate is intentionally conservative because
/// Flutter does not expose the retained size of a [TextPainter].
@internal
class SharedTextLayoutCache extends ChangeNotifier {
  SharedTextLayoutCache({
    this.maxEntries = 256,
    this.maxEstimatedBytes = 16 * 1024 * 1024,
    this.estimatedBytesPerEntry = 64 * 1024,
  })  : assert(maxEntries > 0),
        assert(maxEstimatedBytes > 0),
        assert(estimatedBytesPerEntry > 0);

  final int maxEntries;
  final int maxEstimatedBytes;
  final int estimatedBytesPerEntry;
  final LinkedHashMap<String, TextLayoutService> _entries =
      LinkedHashMap<String, TextLayoutService>();
  int _evictionCount = 0;

  /// Cache key combining block id and path identity.
  static String _key(String blockId, String pathIdentity) {
    return '$blockId\u0000$pathIdentity';
  }

  /// Returns the [TextLayoutService] for the surface identified by
  /// [blockId] / [pathIdentity], creating it on first access. The same
  /// instance is returned across surface remounts.
  TextLayoutService entryFor(String blockId, String pathIdentity) {
    final key = _key(blockId, pathIdentity);
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing;
      return existing;
    }
    final created = TextLayoutService();
    _entries[key] = created;
    _trimToBudget();
    return created;
  }

  /// Drops the entry for [blockId] / [pathIdentity] when its content changed,
  /// so a stale laid-out painter is not reused on the next layout.
  void invalidate(String blockId, String pathIdentity) {
    final key = _key(blockId, pathIdentity);
    _entries.remove(key)?.forget();
  }

  /// Drops every entry whose block id matches [blockId] (block removed).
  void removeBlock(String blockId) {
    final stale =
        _entries.keys.where((key) => key.startsWith('$blockId\u0000')).toList();
    for (final key in stale) {
      _entries.remove(key)?.forget();
    }
  }

  /// Drops every cached layout entry. Use when global render inputs such as the
  /// editor default text color or base text style change.
  void clear() {
    for (final service in _entries.values) {
      service.forget();
    }
    _entries.clear();
  }

  /// Number of cached entries (for tests / observation).
  @visibleForTesting
  int get length => _entries.length;

  @visibleForTesting
  int get evictionCount => _evictionCount;

  @visibleForTesting
  int get estimatedRetainedBytes => length * estimatedBytesPerEntry;

  void _trimToBudget() {
    while (_entries.length > 1 &&
        (_entries.length > maxEntries ||
            estimatedRetainedBytes > maxEstimatedBytes)) {
      final leastRecentlyUsedKey = _entries.keys.first;
      _entries.remove(leastRecentlyUsedKey)?.forget();
      _evictionCount++;
    }
  }

  @override
  void dispose() {
    for (final service in _entries.values) {
      service.forget();
    }
    _entries.clear();
    super.dispose();
  }
}
