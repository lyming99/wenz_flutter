import 'canvas_document.dart';

/// Upgrades a deserialized document map from its recorded [schemaVersion] to
/// [DocumentSchema.current].
///
/// Each registered step takes the raw JSON map and returns a mutated copy.
/// Steps are applied in order; an unknown or future version passes through
/// unchanged (the data is preserved, but no upgrade is attempted). This keeps
/// older apps from crashing on newer documents and newer apps from dropping
/// older ones.
class DocumentMigrator {
  const DocumentMigrator._();

  /// Applies every applicable migration to [json] in place and returns it.
  static Map<String, dynamic> migrate(Map<String, dynamic> json) {
    final version = _readVersion(json);
    switch (version) {
      case '1.0':
      case '1.1':
        _migrate1xTo2(json);
      // Fall through: a 1.x doc becomes 2.0; no further steps yet.
      case '2.0':
        break;
      default:
        // Unknown (likely future) version: leave as-is to avoid corrupting it.
        break;
    }
    return json;
  }

  static String _readVersion(Map<String, dynamic> json) {
    final explicit = json['schemaVersion'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    // Pre-2.0 documents used a `version` field.
    final legacy = json['version'];
    if (legacy is String && legacy.isNotEmpty) return legacy;
    return DocumentSchema.current;
  }

  /// 1.x → 2.0: rename `version` → `schemaVersion` and ensure the new
  /// top-level sections exist. Element-level data is unchanged; the only
  /// breaking change at this step is the version key and the introduction of
  /// optional metadata/viewport/assets sections.
  static void _migrate1xTo2(Map<String, dynamic> json) {
    // `version` (1.x) is renamed to `schemaVersion` (2.0). The old value is
    // discarded — schemaVersion is authoritative going forward.
    json.remove('version');
    json['schemaVersion'] = '2.0';
    json.putIfAbsent('metadata', () => <String, dynamic>{});
    json.putIfAbsent('viewport', () => <String, dynamic>{});
    json.putIfAbsent('assets', () => <dynamic>[]);
  }
}
