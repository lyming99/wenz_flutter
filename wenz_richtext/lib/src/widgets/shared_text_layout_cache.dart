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
/// The cache is bounded by the number of distinct surfaces ever mounted; in
/// practice that tracks the working set a user has scrolled through. It does
/// not evict by size (a future LRU can be added if memory becomes a concern).
@internal
class SharedTextLayoutCache extends ChangeNotifier {
  final Map<String, TextLayoutService> _entries = <String, TextLayoutService>{};

  /// Cache key combining block id and path identity.
  static String _key(String blockId, String pathIdentity) {
    return '$blockId\u0000$pathIdentity';
  }

  /// Returns the [TextLayoutService] for the surface identified by
  /// [blockId] / [pathIdentity], creating it on first access. The same
  /// instance is returned across surface remounts.
  TextLayoutService entryFor(String blockId, String pathIdentity) {
    final key = _key(blockId, pathIdentity);
    return _entries.putIfAbsent(key, () => TextLayoutService());
  }

  /// Drops the entry for [blockId] / [pathIdentity] when its content changed,
  /// so a stale laid-out painter is not reused on the next layout.
  void invalidate(String blockId, String pathIdentity) {
    final key = _key(blockId, pathIdentity);
    _entries.remove(key)?.forget();
  }

  /// Drops every entry whose block id matches [blockId] (block removed).
  void removeBlock(String blockId) {
    final stale = _entries.keys
        .where((key) => key.startsWith('$blockId\u0000'))
        .toList();
    for (final key in stale) {
      _entries.remove(key)?.forget();
    }
  }

  /// Number of cached entries (for tests / observation).
  @visibleForTesting
  int get length => _entries.length;

  @override
  void dispose() {
    for (final service in _entries.values) {
      service.forget();
    }
    _entries.clear();
    super.dispose();
  }
}
