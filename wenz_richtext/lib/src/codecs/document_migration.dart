import 'dart:convert';

import 'document_errors.dart';

/// A one-step schema migration between two document JSON versions.
///
/// Migrations operate on the **raw decoded JSON map** (the shape
/// `RichTextDocument.toJson` produces), before it is inflated into a
/// [RichTextDocument]. Each migration lifts a document from
/// [fromVersion] to `fromVersion + 1`. Register them on a
/// [DocumentMigrationRegistry], which walks the chain from a document's
/// declared version up to the current schema version.
///
/// Why JSON-level: migrations must run *before* model inflation so that
/// removed/renamed fields never reach `fromJson` (which would throw). Keeping
/// them as pure JSON transforms also makes them trivial to unit-test against
/// fixture maps.
abstract class DocumentMigration {
  const DocumentMigration();

  /// The version this migration reads as input. The output is implicitly
  /// `fromVersion + 1`.
  int get fromVersion;

  /// Transforms [json] (a mutable copy) in place from [fromVersion] to
  /// `fromVersion + 1` and returns it. Implementations MUST bump the
  /// `version` field and leave unrecognised fields untouched (forward
  /// compatibility).
  Map<String, Object?> migrate(Map<String, Object?> json);
}

/// Registry of [DocumentMigration]s. Use [migrateToCurrent] to walk a decoded
/// document from its declared version up to [currentVersion], applying each
/// step in order.
///
/// Example:
///
/// ```dart
/// final registry = DocumentMigrationRegistry()
///   ..register(const V1ToV2Migration());
/// final json = jsonDecode(source) as Map<String, Object?>;
/// final migrated = registry.migrateToCurrent(json);
/// final document = RichTextDocument.fromJson(migrated);
/// ```
class DocumentMigrationRegistry {
  DocumentMigrationRegistry({this.currentVersion = 2});

  /// The schema version produced by the latest code. Documents below this
  /// version are migrated up; documents at or above it are returned as-is
  /// (forward-compatible — unknown future fields pass through untouched).
  final int currentVersion;

  final Map<int, DocumentMigration> _migrations = <int, DocumentMigration>{};

  /// Registers [migration]. Re-registering the same [DocumentMigration.fromVersion]
  /// replaces the prior entry.
  void register(DocumentMigration migration) {
    _migrations[migration.fromVersion] = migration;
  }

  /// Whether a migration step exists from [version] to `version + 1`.
  bool handles(int version) => _migrations.containsKey(version);

  /// Walks [json] from its declared `version` up to [currentVersion],
  /// applying each registered migration step in order. Throws a
  /// [StateError] when an intermediate step is missing (the chain is
  /// incomplete).
  Map<String, Object?> migrateToCurrent(Map<String, Object?> json) {
    var version = _readVersion(json);
    if (version >= currentVersion) {
      return json;
    }
    var current = Map<String, Object?>.from(json);
    while (version < currentVersion) {
      final step = _migrations[version];
      if (step == null) {
        throw StateError(
          'No document migration registered from version $version '
          '(needed to reach $currentVersion).',
        );
      }
      current = step.migrate(current);
      version = _readVersion(current);
    }
    return current;
  }

  int _readVersion(Map<String, Object?> json) {
    final raw = json['version'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    // Pre-version documents are treated as version 1 (the first schema).
    return 1;
  }
}

/// Example migration: v1 → v2.
///
/// v1 documents could legally omit a block `id` (the model generated one on
/// decode). v2 requires every block to carry a stable id so that incremental
/// rebuild, copy/paste, and collaborative addressing all have a deterministic
/// key. This migration back-fills missing ids with a deterministic scheme
/// (`block-<index>`) and bumps the version.
///
/// It also canonicalises legacy `listType` values that the v1 schema accepted
/// (`'unordered'`) into the v2 canonical form (omitted = unordered), matching
/// what [DocumentSchema] now enforces on the model side.
class V1ToV2DocumentMigration extends DocumentMigration {
  const V1ToV2DocumentMigration();

  @override
  int get fromVersion => 1;

  @override
  Map<String, Object?> migrate(Map<String, Object?> json) {
    final result = Map<String, Object?>.from(json);
    final blocks = result['blocks'];
    if (blocks is List) {
      result['blocks'] = <Object?>[
        for (var i = 0; i < blocks.length; i++) _migrateBlock(blocks[i], i),
      ];
    }
    result['version'] = 2;
    return result;
  }

  Map<String, Object?> _migrateBlock(Object? raw, int index) {
    if (raw is! Map) {
      return <String, Object?>{'id': 'block-$index', 'type': 'paragraph'};
    }
    final block = Map<String, Object?>.from(raw);
    // Back-fill missing id with a deterministic, index-based key.
    if (block['id'] is! String || (block['id'] as String).isEmpty) {
      block['id'] = 'block-$index';
    }
    // Canonicalise legacy listType values on the block attrs.
    final attrs = block['attrs'];
    if (attrs is Map) {
      final migrated = Map<String, Object?>.from(attrs);
      final listType = migrated['listType'];
      if (listType == 'unordered' || listType == 'li') {
        migrated.remove('listType');
      }
      block['attrs'] = migrated;
    }
    return block;
  }
}

/// Convenience helper: decodes [source] as JSON, runs it through [registry]
/// up to its [DocumentMigrationRegistry.currentVersion], and returns the
/// migrated JSON map. Throws [DocumentDecodeException] when [source] is not a
/// JSON object or is otherwise malformed.
Map<String, Object?> decodeWithMigrations(
  String source,
  DocumentMigrationRegistry registry,
) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw DocumentDecodeException('Source is not valid JSON.', raw: error);
  }
  if (decoded is! Map) {
    throw const DocumentDecodeException('Document JSON must be an object.');
  }
  try {
    return registry.migrateToCurrent(Map<String, Object?>.from(decoded));
  } on DocumentDecodeException {
    rethrow;
  } on Object catch (error) {
    throw DocumentDecodeException(
      'Schema migration failed: $error',
      raw: error,
    );
  }
}
