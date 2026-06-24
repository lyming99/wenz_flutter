import '../position/document_position.dart';
import 'attributes.dart';

enum RevisionChangeType {
  insert('insert'),
  delete('delete'),
  format('format');

  const RevisionChangeType(this.name);

  final String name;

  static RevisionChangeType parse(Object? value) {
    final text = value?.toString();
    return RevisionChangeType.values.firstWhere(
      (type) => type.name == text,
      orElse: () => RevisionChangeType.insert,
    );
  }
}

enum RevisionChangeStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const RevisionChangeStatus(this.name);

  final String name;

  static RevisionChangeStatus parse(Object? value) {
    final text = value?.toString();
    return RevisionChangeStatus.values.firstWhere(
      (status) => status.name == text,
      orElse: () => RevisionChangeStatus.pending,
    );
  }
}

class RevisionRange {
  const RevisionRange({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.startOffset,
    required this.endOffset,
  });

  factory RevisionRange.fromSelection(DocumentSelection selection) {
    return RevisionRange(
      blockId: selection.start.blockId,
      blockIndex: selection.start.blockIndex,
      path: selection.start.path,
      startOffset: selection.start.offset,
      endOffset: selection.end.offset,
    );
  }

  factory RevisionRange.fromJson(Map<String, Object?> json) {
    final blockId = json['blockId'] as String? ?? '';
    return RevisionRange(
      blockId: blockId,
      blockIndex: _asInt(json['blockIndex']),
      path: _positionPathFromJson(json['path'], fallbackBlockId: blockId),
      startOffset: _asInt(json['startOffset']),
      endOffset: _asInt(json['endOffset']),
    );
  }

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int startOffset;
  final int endOffset;

  DocumentSelection get selection {
    return DocumentSelection(
      base: DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: path,
        offset: startOffset,
      ),
      extent: DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: path,
        offset: endOffset,
      ),
    );
  }

  RevisionRange copyWith({
    String? blockId,
    int? blockIndex,
    PositionPath? path,
    int? startOffset,
    int? endOffset,
  }) {
    return RevisionRange(
      blockId: blockId ?? this.blockId,
      blockIndex: blockIndex ?? this.blockIndex,
      path: path ?? this.path,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
    );
  }

  RevisionRange copy() => copyWith();

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'blockId': blockId,
      'blockIndex': blockIndex,
      'path': path.segments,
      'startOffset': startOffset,
      'endOffset': endOffset,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RevisionRange &&
        other.blockId == blockId &&
        other.blockIndex == blockIndex &&
        other.path == path &&
        other.startOffset == startOffset &&
        other.endOffset == endOffset;
  }

  @override
  int get hashCode {
    return Object.hash(blockId, blockIndex, path, startOffset, endOffset);
  }
}

class RevisionChange {
  const RevisionChange({
    required this.id,
    required this.type,
    required this.range,
    required this.createdAt,
    this.status = RevisionChangeStatus.pending,
    this.authorId,
    this.authorName,
    this.acceptedAt,
    this.rejectedAt,
    this.beforeAttributes,
    this.afterAttributes,
    this.metadata = const <String, Object?>{},
  });

  factory RevisionChange.fromJson(Map<String, Object?> json) {
    final rawRange = json['range'];
    final rawBeforeAttributes = json['beforeAttrs'];
    final rawAfterAttributes = json['afterAttrs'];
    final rawMetadata = json['metadata'];
    return RevisionChange(
      id: json['id'] as String? ?? '',
      type: RevisionChangeType.parse(json['type']),
      status: RevisionChangeStatus.parse(json['status']),
      range: rawRange is Map
          ? RevisionRange.fromJson(Map<String, Object?>.from(rawRange))
          : RevisionRange(
              blockId: '',
              blockIndex: 0,
              path: PositionPath.blockText(''),
              startOffset: 0,
              endOffset: 0,
            ),
      createdAt: _asDateTime(json['createdAt']) ?? _epoch,
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String?,
      acceptedAt: _asDateTime(json['acceptedAt']),
      rejectedAt: _asDateTime(json['rejectedAt']),
      beforeAttributes: rawBeforeAttributes is Map
          ? TextAttributes.fromJson(
              Map<String, Object?>.from(rawBeforeAttributes),
            )
          : null,
      afterAttributes: rawAfterAttributes is Map
          ? TextAttributes.fromJson(
              Map<String, Object?>.from(rawAfterAttributes),
            )
          : null,
      metadata: rawMetadata is Map
          ? Map<String, Object?>.from(rawMetadata)
          : const <String, Object?>{},
    );
  }

  final String id;
  final RevisionChangeType type;
  final RevisionChangeStatus status;
  final RevisionRange range;
  final DateTime createdAt;
  final String? authorId;
  final String? authorName;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final TextAttributes? beforeAttributes;
  final TextAttributes? afterAttributes;
  final Map<String, Object?> metadata;

  bool get isPending => status == RevisionChangeStatus.pending;

  bool get isAccepted => status == RevisionChangeStatus.accepted;

  bool get isRejected => status == RevisionChangeStatus.rejected;

  RevisionChange accept({DateTime? acceptedAt}) {
    return copyWith(
      status: RevisionChangeStatus.accepted,
      acceptedAt: acceptedAt ?? DateTime.now(),
      rejectedAt: null,
    );
  }

  RevisionChange reject({DateTime? rejectedAt}) {
    return copyWith(
      status: RevisionChangeStatus.rejected,
      acceptedAt: null,
      rejectedAt: rejectedAt ?? DateTime.now(),
    );
  }

  RevisionChange copyWith({
    String? id,
    RevisionChangeType? type,
    RevisionChangeStatus? status,
    RevisionRange? range,
    DateTime? createdAt,
    Object? authorId = _unset,
    Object? authorName = _unset,
    Object? acceptedAt = _unset,
    Object? rejectedAt = _unset,
    Object? beforeAttributes = _unset,
    Object? afterAttributes = _unset,
    Map<String, Object?>? metadata,
  }) {
    return RevisionChange(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      range: range ?? this.range,
      createdAt: createdAt ?? this.createdAt,
      authorId:
          identical(authorId, _unset) ? this.authorId : authorId as String?,
      authorName: identical(authorName, _unset)
          ? this.authorName
          : authorName as String?,
      acceptedAt: identical(acceptedAt, _unset)
          ? this.acceptedAt
          : acceptedAt as DateTime?,
      rejectedAt: identical(rejectedAt, _unset)
          ? this.rejectedAt
          : rejectedAt as DateTime?,
      beforeAttributes: identical(beforeAttributes, _unset)
          ? this.beforeAttributes
          : beforeAttributes as TextAttributes?,
      afterAttributes: identical(afterAttributes, _unset)
          ? this.afterAttributes
          : afterAttributes as TextAttributes?,
      metadata: metadata ?? this.metadata,
    );
  }

  RevisionChange copy() => copyWith(
        range: range.copy(),
        metadata: Map<String, Object?>.from(metadata),
      );

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'status': status.name,
      'range': range.toJson(),
      'createdAt': createdAt.toIso8601String(),
      if (authorId != null) 'authorId': authorId,
      if (authorName != null) 'authorName': authorName,
      if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
      if (beforeAttributes != null && !beforeAttributes!.isEmpty)
        'beforeAttrs': beforeAttributes!.toJson(),
      if (afterAttributes != null && !afterAttributes!.isEmpty)
        'afterAttrs': afterAttributes!.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RevisionChange &&
        other.id == id &&
        other.type == type &&
        other.status == status &&
        other.range == range &&
        other.createdAt == createdAt &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.acceptedAt == acceptedAt &&
        other.rejectedAt == rejectedAt &&
        other.beforeAttributes == beforeAttributes &&
        other.afterAttributes == afterAttributes &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      status,
      range,
      createdAt,
      authorId,
      authorName,
      acceptedAt,
      rejectedAt,
      beforeAttributes,
      afterAttributes,
      Object.hashAll(
        metadata.entries.map((entry) => Object.hash(entry.key, entry.value)),
      ),
    );
  }
}

const Object _unset = Object();
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

PositionPath _positionPathFromJson(
  Object? value, {
  required String fallbackBlockId,
}) {
  if (value is List) {
    return PositionPath(
      value
          .where((segment) => segment is String || segment is num)
          .map<Object>((segment) => segment is num ? segment.toInt() : segment)
          .toList(),
    );
  }
  return PositionPath.blockText(fallbackBlockId);
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
