import 'package:flutter/foundation.dart';

/// Opens a URL when the user taps a mind map node's link.
///
/// The mind map module does not depend on `url_launcher` (or any other
/// platform plugin), so opening a link is delegated to the host application.
/// Register an implementation via [registerMindmapModule]; when none is
/// registered, link taps are a no-op.
abstract class MindmapLinkOpener {
  /// Opens [uri]. Returns whether the OS reported success.
  Future<bool> open(Uri uri);
}

/// A [MindmapLinkOpener] that does nothing. Used as the default until a host
/// registers a real implementation.
class _NoopLinkOpener implements MindmapLinkOpener {
  const _NoopLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    if (kDebugMode) {
      debugPrint('MindmapLinkOpener not registered — ignoring open($uri).');
    }
    return false;
  }
}

/// Module-level holder for the active link opener. Set by
/// `registerMindmapModule`; defaults to a no-op so nodes never crash when no
/// host integration is wired up.
class MindmapLinkOpenerHolder {
  MindmapLinkOpenerHolder._();

  static MindmapLinkOpener _current = const _NoopLinkOpener();

  /// The currently registered link opener.
  static MindmapLinkOpener get current => _current;

  /// Sets the active link opener. Called by `registerMindmapModule`.
  static void set(MindmapLinkOpener opener) {
    _current = opener;
  }

  /// Resets to the no-op default. Called by `unregisterMindmapModule`; also
  /// useful in tests between cases.
  static void reset() {
    _current = const _NoopLinkOpener();
  }
}
