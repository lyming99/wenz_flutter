import 'canvas_document.dart';

/// A persistence backend for a serialized canvas document.
///
/// The SDK never assumes where a document lives — it may be a file on disk, a
/// row in a database, or a note payload in a host app. Hosts implement this
/// interface and hand it to the editor (via `EditorContentCallbacks`) so the
/// toolbar's save/load actions route to the right place.
///
/// The contract is intentionally string-based: the SDK serializes a
/// [CanvasDocument] to JSON ([save]) and deserializes it back ([load]). This
/// keeps the store free of any Flutter/element types and trivial to back with
/// a file, `SharedPreferences`, a remote API, etc.
abstract class DocumentStore {
  /// Persists the given JSON-encoded document.
  ///
  /// Returns when the write is durable. Implementations should overwrite any
  /// previously stored document.
  Future<void> save(Map<String, dynamic> json);

  /// Reads the previously stored document, or `null` when none exists.
  Future<Map<String, dynamic>?> load();

  /// Whether a document is currently stored. Default implementation delegates
  /// to [load]; override for a cheaper existence check (e.g. a file stat).
  Future<bool> exists() async => (await load()) != null;
}

/// A trivial in-memory [DocumentStore], useful for tests and demos.
class MemoryDocumentStore implements DocumentStore {
  MemoryDocumentStore({Map<String, dynamic>? initial}) : _doc = initial;

  Map<String, dynamic>? _doc;

  @override
  Future<void> save(Map<String, dynamic> json) async {
    _doc = Map<String, dynamic>.from(json);
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final doc = _doc;
    if (doc == null) {
      return null;
    }
    return Map<String, dynamic>.from(doc);
  }

  @override
  Future<bool> exists() async => _doc != null;
}
