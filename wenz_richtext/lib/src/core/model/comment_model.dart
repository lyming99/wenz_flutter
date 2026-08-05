import '../position/document_position.dart';

enum CommentThreadStatus { open, resolved }

class CommentAnchor {
  const CommentAnchor({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.startOffset,
    required this.endOffset,
  });

  factory CommentAnchor.fromSelection(DocumentSelection selection) {
    return CommentAnchor(
      blockId: selection.start.blockId,
      blockIndex: selection.start.blockIndex,
      path: selection.start.path,
      startOffset: selection.start.offset,
      endOffset: selection.end.offset,
    );
  }

  factory CommentAnchor.fromJson(Map<String, Object?> json) {
    final blockId = json['blockId'] as String? ?? '';
    return CommentAnchor(
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

  CommentAnchor copyWith({
    String? blockId,
    int? blockIndex,
    PositionPath? path,
    int? startOffset,
    int? endOffset,
  }) {
    return CommentAnchor(
      blockId: blockId ?? this.blockId,
      blockIndex: blockIndex ?? this.blockIndex,
      path: path ?? this.path,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
    );
  }

  CommentAnchor copy() => copyWith();

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
    return other is CommentAnchor &&
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

class CommentEntry {
  const CommentEntry({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorId,
    this.updatedAt,
  });

  factory CommentEntry.fromJson(Map<String, Object?> json) {
    final createdAt = _asDateTime(json['createdAt']) ?? _epoch;
    return CommentEntry(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String?,
      authorName: json['authorName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  final String id;
  final String? authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isEdited => updatedAt != null && updatedAt != createdAt;

  CommentEntry copyWith({
    String? id,
    Object? authorId = _unset,
    String? authorName,
    String? text,
    DateTime? createdAt,
    Object? updatedAt = _unset,
  }) {
    return CommentEntry(
      id: id ?? this.id,
      authorId:
          identical(authorId, _unset) ? this.authorId : authorId as String?,
      authorName: authorName ?? this.authorName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  CommentEntry copy() => copyWith();

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      if (authorId != null) 'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CommentEntry &&
        other.id == id &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.text == text &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, authorId, authorName, text, createdAt, updatedAt);
  }
}

class CommentThread {
  const CommentThread({
    required this.id,
    required this.anchor,
    required this.messages,
    required this.createdAt,
    this.status = CommentThreadStatus.open,
    this.updatedAt,
    this.resolvedAt,
  });

  factory CommentThread.fromJson(Map<String, Object?> json) {
    final rawAnchor = json['anchor'];
    final rawMessages = json['messages'];
    final createdAt = _asDateTime(json['createdAt']) ?? _epoch;
    return CommentThread(
      id: json['id'] as String? ?? '',
      anchor: rawAnchor is Map
          ? CommentAnchor.fromJson(Map<String, Object?>.from(rawAnchor))
          : _emptyAnchor,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((message) => CommentEntry.fromJson(
                    Map<String, Object?>.from(message),
                  ))
              .toList()
          : const <CommentEntry>[],
      createdAt: createdAt,
      status: _commentThreadStatusFromJson(json['status']),
      updatedAt: _asDateTime(json['updatedAt']),
      resolvedAt: _asDateTime(json['resolvedAt']),
    );
  }

  final String id;
  final CommentAnchor anchor;
  final List<CommentEntry> messages;
  final DateTime createdAt;
  final CommentThreadStatus status;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  bool get isOpen => status == CommentThreadStatus.open;

  bool get isResolved => status == CommentThreadStatus.resolved;

  CommentEntry? get firstMessage => messages.isEmpty ? null : messages.first;

  CommentEntry? get lastMessage => messages.isEmpty ? null : messages.last;

  CommentThread copyWith({
    String? id,
    CommentAnchor? anchor,
    List<CommentEntry>? messages,
    DateTime? createdAt,
    CommentThreadStatus? status,
    Object? updatedAt = _unset,
    Object? resolvedAt = _unset,
  }) {
    return CommentThread(
      id: id ?? this.id,
      anchor: anchor ?? this.anchor,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
      resolvedAt: identical(resolvedAt, _unset)
          ? this.resolvedAt
          : resolvedAt as DateTime?,
    );
  }

  CommentThread copy() {
    return copyWith(
      anchor: anchor.copy(),
      messages: messages.map((message) => message.copy()).toList(),
    );
  }

  CommentThread addReply(CommentEntry entry) {
    return copyWith(
      messages: <CommentEntry>[...messages, entry],
      updatedAt: entry.createdAt,
    );
  }

  CommentThread resolve({DateTime? resolvedAt}) {
    final resolvedTime = resolvedAt ?? DateTime.now().toUtc();
    return copyWith(
      status: CommentThreadStatus.resolved,
      updatedAt: resolvedTime,
      resolvedAt: resolvedTime,
    );
  }

  CommentThread reopen({DateTime? updatedAt}) {
    return copyWith(
      status: CommentThreadStatus.open,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      resolvedAt: null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'anchor': anchor.toJson(),
      'messages': messages.map((message) => message.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CommentThread &&
        other.id == id &&
        other.anchor == anchor &&
        _listEquals(other.messages, messages) &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.updatedAt == updatedAt &&
        other.resolvedAt == resolvedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      anchor,
      Object.hashAll(messages),
      createdAt,
      status,
      updatedAt,
      resolvedAt,
    );
  }
}

const Object _unset = Object();

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

final CommentAnchor _emptyAnchor = CommentAnchor(
  blockId: '',
  blockIndex: 0,
  path: PositionPath.blockText(''),
  startOffset: 0,
  endOffset: 0,
);

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

PositionPath _positionPathFromJson(Object? value,
    {required String fallbackBlockId}) {
  if (value is List) {
    return PositionPath(<Object>[
      for (final segment in value)
        if (segment is int)
          segment
        else if (segment is num)
          segment.toInt()
        else
          segment.toString(),
    ]);
  }
  return PositionPath.blockText(fallbackBlockId);
}

CommentThreadStatus _commentThreadStatusFromJson(Object? value) {
  if (value == CommentThreadStatus.resolved.name) {
    return CommentThreadStatus.resolved;
  }
  return CommentThreadStatus.open;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
