import '../../codecs/document_errors.dart';
import 'rich_text_document.dart';

const Object _unset = Object();
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Immutable document version snapshot owned by application storage.
///
/// The editor core stores no snapshot list inside [RichTextDocument]. Apps can
/// persist this model next to their own version history records, then call
/// [restoreDocument] (or `WenzRichTextController.restoreVersionSnapshot`) to
/// recover the captured document value.
class DocumentVersionSnapshot {
  DocumentVersionSnapshot({
    required this.id,
    required RichTextDocument document,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.description,
    this.baseSnapshotId,
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : document = document.copy(),
        metadata = Map<String, Object?>.unmodifiable(_copyJsonMap(metadata));

  factory DocumentVersionSnapshot.fromJson(Map<String, Object?> json) {
    final rawDocument = json['document'];
    if (rawDocument is! Map) {
      throw const DocumentDecodeException(
        'Version snapshot document must be an object.',
        jsonPath: 'document',
      );
    }
    return DocumentVersionSnapshot(
      id: json['id'] as String? ?? '',
      document: RichTextDocument.fromJson(
        Map<String, Object?>.from(rawDocument),
      ),
      createdAt: _asDateTime(json['createdAt']),
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      description: json['description'] as String?,
      baseSnapshotId: json['baseSnapshotId'] as String?,
      metadata: _asJsonMap(json['metadata']),
    );
  }

  /// Application-owned snapshot id.
  final String id;

  /// Deep-copied document value captured by this snapshot.
  final RichTextDocument document;

  /// Snapshot creation time.
  final DateTime createdAt;

  /// Optional stable author id from the host application.
  final String? authorId;

  /// Optional display name for the snapshot author.
  final String? authorName;

  /// Optional human-readable snapshot note.
  final String? description;

  /// Optional parent/base snapshot id reserved for future diff flows.
  final String? baseSnapshotId;

  /// Extra JSON-compatible metadata owned by the host application.
  final Map<String, Object?> metadata;

  /// Returns a fresh document copy suitable for restoring into an editor.
  RichTextDocument restoreDocument() => document.copy();

  DocumentVersionSnapshot copyWith({
    String? id,
    RichTextDocument? document,
    DateTime? createdAt,
    Object? authorId = _unset,
    Object? authorName = _unset,
    Object? description = _unset,
    Object? baseSnapshotId = _unset,
    Map<String, Object?>? metadata,
  }) {
    return DocumentVersionSnapshot(
      id: id ?? this.id,
      document: document ?? this.document,
      createdAt: createdAt ?? this.createdAt,
      authorId:
          identical(authorId, _unset) ? this.authorId : authorId as String?,
      authorName: identical(authorName, _unset)
          ? this.authorName
          : authorName as String?,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      baseSnapshotId: identical(baseSnapshotId, _unset)
          ? this.baseSnapshotId
          : baseSnapshotId as String?,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      if (authorId != null) 'authorId': authorId,
      if (authorName != null) 'authorName': authorName,
      if (description != null) 'description': description,
      if (baseSnapshotId != null) 'baseSnapshotId': baseSnapshotId,
      if (metadata.isNotEmpty) 'metadata': _copyJsonMap(metadata),
      'document': document.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentVersionSnapshot &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.description == description &&
        other.baseSnapshotId == baseSnapshotId &&
        _jsonEquals(other.metadata, metadata) &&
        _jsonEquals(other.document.toJson(), document.toJson());
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      createdAt,
      authorId,
      authorName,
      description,
      baseSnapshotId,
      _jsonHash(metadata),
      _jsonHash(document.toJson()),
    );
  }
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? _epoch;
  }
  return _epoch;
}

Map<String, Object?> _asJsonMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return _copyJsonMap(Map<String, Object?>.from(value));
}

Map<String, Object?> _copyJsonMap(Map<String, Object?> source) {
  return <String, Object?>{
    for (final entry in source.entries) entry.key: _copyJsonValue(entry.value),
  };
}

Object? _copyJsonValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _copyJsonValue(entry.value),
      },
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_copyJsonValue));
  }
  return value;
}

bool _jsonEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_jsonEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_jsonEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _jsonHash(Object? value) {
  if (value is Map) {
    return Object.hashAll(
      value.entries
          .map((entry) => Object.hash(entry.key, _jsonHash(entry.value))),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_jsonHash));
  }
  return value.hashCode;
}
