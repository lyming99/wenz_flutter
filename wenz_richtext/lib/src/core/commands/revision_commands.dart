import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/revision_model.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';

class InsertRevisionTextCommand extends EditorCommand {
  const InsertRevisionTextCommand(
    this.text, {
    required this.revisionId,
    this.attributes = const TextAttributes(),
    this.selection,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String text;
  final String revisionId;
  final TextAttributes attributes;
  final DocumentSelection? selection;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;

  @override
  String get description => 'revision.insertText';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (text.isEmpty || revisionId.isEmpty || target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!target.isCollapsed) {
      return const CommandResult(recordHistory: false);
    }
    final position = target.extent;
    if (!position.path.isBlockText) {
      return const CommandResult(recordHistory: false);
    }
    final block = _textBlockAt(session.document, position.blockIndex);
    if (block == null) {
      return const CommandResult(recordHistory: false);
    }

    final offset = position.offset.clamp(0, block.plainText.length).toInt();
    final nextOffset = offset + text.length;
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: insertInline(
        block.content,
        offset,
        text,
        _withRevisionId(attributes, revisionId),
      ),
    );
    final revision = _buildRevision(
      type: RevisionChangeType.insert,
      revisionId: revisionId,
      position: position,
      startOffset: offset,
      endOffset: nextOffset,
      authorId: authorId,
      authorName: authorName,
      createdAt: createdAt,
    );
    _replaceTextBlock(
      session,
      position.blockIndex,
      nextBlock,
      revisions: <RevisionChange>[...session.document.revisions, revision],
    );

    final nextPosition = position.copyWith(offset: nextOffset);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
      metadata: _metadataFor(revision),
    );
  }
}

class MarkDeletionRevisionCommand extends EditorCommand {
  const MarkDeletionRevisionCommand({
    required this.revisionId,
    this.selection,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String revisionId;
  final DocumentSelection? selection;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;

  @override
  String get description => 'revision.markDeletion';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    final range = _sameTextBlockRange(session.document, target);
    if (revisionId.isEmpty || range == null) {
      return const CommandResult(recordHistory: false);
    }
    final (:block, :start, :end) = range;
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: _addRevisionIdToInline(block.content, start, end, revisionId),
    );
    final revision = _buildRevision(
      type: RevisionChangeType.delete,
      revisionId: revisionId,
      position: target!.start,
      startOffset: start,
      endOffset: end,
      authorId: authorId,
      authorName: authorName,
      createdAt: createdAt,
    );
    _replaceTextBlock(
      session,
      target.start.blockIndex,
      nextBlock,
      revisions: <RevisionChange>[...session.document.revisions, revision],
    );

    final nextPosition = target.start.copyWith(offset: start);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
      metadata: _metadataFor(revision),
    );
  }
}

class MarkFormatRevisionCommand extends EditorCommand {
  const MarkFormatRevisionCommand({
    required this.revisionId,
    required this.attributes,
    this.selection,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String revisionId;
  final TextAttributes attributes;
  final DocumentSelection? selection;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;

  @override
  String get description => 'revision.markFormat';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    final range = _sameTextBlockRange(session.document, target);
    if (revisionId.isEmpty || attributes.isEmpty || range == null) {
      return const CommandResult(recordHistory: false);
    }
    final (:block, :start, :end) = range;
    final beforeAttributes = _attributesAtOffset(block.content, start);
    final formatted = formatInline(block.content, start, end, attributes);
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: _addRevisionIdToInline(formatted, start, end, revisionId),
    );
    final revision = _buildRevision(
      type: RevisionChangeType.format,
      revisionId: revisionId,
      position: target!.start,
      startOffset: start,
      endOffset: end,
      authorId: authorId,
      authorName: authorName,
      createdAt: createdAt,
      beforeAttributes: _withoutRevisionId(beforeAttributes, revisionId),
      afterAttributes: attributes,
    );
    _replaceTextBlock(
      session,
      target.start.blockIndex,
      nextBlock,
      revisions: <RevisionChange>[...session.document.revisions, revision],
    );

    return CommandResult(selection: target, metadata: _metadataFor(revision));
  }
}

class AcceptRevisionCommand extends EditorCommand {
  const AcceptRevisionCommand(this.revisionId, {this.resolvedAt});

  final String revisionId;
  final DateTime? resolvedAt;

  @override
  String get description => 'revision.accept';

  @override
  CommandResult execute(DocumentSession session) {
    return _resolveRevision(
      session,
      revisionId,
      accepted: true,
      resolvedAt: resolvedAt,
    );
  }
}

class RejectRevisionCommand extends EditorCommand {
  const RejectRevisionCommand(this.revisionId, {this.resolvedAt});

  final String revisionId;
  final DateTime? resolvedAt;

  @override
  String get description => 'revision.reject';

  @override
  CommandResult execute(DocumentSession session) {
    return _resolveRevision(
      session,
      revisionId,
      accepted: false,
      resolvedAt: resolvedAt,
    );
  }
}

CommandResult _resolveRevision(
  DocumentSession session,
  String revisionId, {
  required bool accepted,
  DateTime? resolvedAt,
}) {
  final index = session.document.revisions.indexWhere(
    (revision) => revision.id == revisionId,
  );
  if (revisionId.isEmpty || index < 0) {
    return const CommandResult(recordHistory: false);
  }
  final revision = session.document.revisions[index];
  if (!revision.isPending || !revision.range.path.isBlockText) {
    return const CommandResult(recordHistory: false);
  }
  final block = _textBlockAt(session.document, revision.range.blockIndex);
  if (block == null) {
    return const CommandResult(recordHistory: false);
  }

  final start =
      revision.range.startOffset.clamp(0, block.plainText.length).toInt();
  final end =
      revision.range.endOffset.clamp(start, block.plainText.length).toInt();
  if (end <= start) {
    return const CommandResult(recordHistory: false);
  }

  final nextContent = switch ((revision.type, accepted)) {
    (RevisionChangeType.insert, true) =>
      _removeRevisionIdFromInline(block.content, start, end, revisionId),
    (RevisionChangeType.insert, false) =>
      deleteInline(block.content, start, end),
    (RevisionChangeType.delete, true) =>
      deleteInline(block.content, start, end),
    (RevisionChangeType.delete, false) =>
      _removeRevisionIdFromInline(block.content, start, end, revisionId),
    (RevisionChangeType.format, true) =>
      _removeRevisionIdFromInline(block.content, start, end, revisionId),
    (RevisionChangeType.format, false) => _replaceAttributesInline(
        block.content,
        start,
        end,
        _withoutRevisionId(
          revision.beforeAttributes ?? const TextAttributes(),
          revisionId,
        ),
      ),
  };
  final nextBlock = TextBlockNode(
    id: block.id,
    type: block.type,
    attributes: block.attributes,
    content: nextContent,
  );
  final resolvedRevision = accepted
      ? revision.accept(acceptedAt: resolvedAt)
      : revision.reject(rejectedAt: resolvedAt);
  final revisions = session.document.revisions.toList()
    ..[index] = resolvedRevision;
  _replaceTextBlock(
    session,
    revision.range.blockIndex,
    nextBlock,
    revisions: revisions,
  );

  final nextPosition = revision.range.selection.start.copyWith(offset: start);
  return CommandResult(
    selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    metadata: _metadataFor(resolvedRevision),
  );
}

({TextBlockNode block, int start, int end})? _sameTextBlockRange(
  RichTextDocument document,
  DocumentSelection? selection,
) {
  if (selection == null || selection.isCollapsed) {
    return null;
  }
  final startPosition = selection.start;
  final endPosition = selection.end;
  if (startPosition.blockIndex != endPosition.blockIndex ||
      startPosition.path != endPosition.path ||
      !startPosition.path.isBlockText) {
    return null;
  }
  final block = _textBlockAt(document, startPosition.blockIndex);
  if (block == null) {
    return null;
  }
  final start = startPosition.offset.clamp(0, block.plainText.length).toInt();
  final end = endPosition.offset.clamp(start, block.plainText.length).toInt();
  if (end <= start) {
    return null;
  }
  return (block: block, start: start, end: end);
}

TextBlockNode? _textBlockAt(RichTextDocument document, int blockIndex) {
  if (blockIndex < 0 || blockIndex >= document.blocks.length) {
    return null;
  }
  final block = document.blocks[blockIndex];
  return block is TextBlockNode ? block : null;
}

void _replaceTextBlock(
  DocumentSession session,
  int blockIndex,
  TextBlockNode block, {
  required List<RevisionChange> revisions,
}) {
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: session.document.replaceBlockAt(blockIndex, block).blocks,
    comments: session.document.comments,
    revisions: revisions,
  );
}

RevisionChange _buildRevision({
  required RevisionChangeType type,
  required String revisionId,
  required DocumentPosition position,
  required int startOffset,
  required int endOffset,
  required String? authorId,
  required String? authorName,
  required DateTime? createdAt,
  TextAttributes? beforeAttributes,
  TextAttributes? afterAttributes,
}) {
  return RevisionChange(
    id: revisionId,
    type: type,
    range: RevisionRange(
      blockId: position.blockId,
      blockIndex: position.blockIndex,
      path: position.path,
      startOffset: startOffset,
      endOffset: endOffset,
    ),
    createdAt: createdAt ?? DateTime.now(),
    authorId: authorId,
    authorName: authorName,
    beforeAttributes: beforeAttributes,
    afterAttributes: afterAttributes,
  );
}

Map<String, Object?> _metadataFor(RevisionChange revision) {
  return <String, Object?>{
    'revisionId': revision.id,
    'revisionType': revision.type.name,
    'revisionStatus': revision.status.name,
  };
}

List<InlineNode> _addRevisionIdToInline(
  List<InlineNode> nodes,
  int start,
  int end,
  String revisionId,
) {
  return _mapInlineRange(
    nodes,
    start,
    end,
    (attributes) => _withRevisionId(attributes, revisionId),
  );
}

List<InlineNode> _removeRevisionIdFromInline(
  List<InlineNode> nodes,
  int start,
  int end,
  String revisionId,
) {
  return _mapInlineRange(
    nodes,
    start,
    end,
    (attributes) => _withoutRevisionId(attributes, revisionId),
  );
}

List<InlineNode> _replaceAttributesInline(
  List<InlineNode> nodes,
  int start,
  int end,
  TextAttributes attributes,
) {
  return _mapInlineRange(nodes, start, end, (_) => attributes);
}

List<InlineNode> _mapInlineRange(
  List<InlineNode> nodes,
  int start,
  int end,
  TextAttributes Function(TextAttributes attributes) transform,
) {
  if (end <= start) {
    return nodes.map((node) => node.copy()).toList();
  }

  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;
    if (nodeEnd <= start || nodeStart >= end) {
      result.add(node.copy());
      continue;
    }
    if (node is TextRun) {
      final localStart = start > nodeStart ? start - nodeStart : 0;
      final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
      final before = node.text.substring(0, localStart);
      final middle = node.text.substring(localStart, localEnd);
      final after = node.text.substring(localEnd);
      if (before.isNotEmpty) {
        result.add(TextRun(text: before, attributes: node.attributes));
      }
      if (middle.isNotEmpty) {
        result
            .add(TextRun(text: middle, attributes: transform(node.attributes)));
      }
      if (after.isNotEmpty) {
        result.add(TextRun(text: after, attributes: node.attributes));
      }
    } else if (node is InlineEmbed) {
      result.add(
        InlineEmbed(
          embedType: node.embedType,
          data: node.data,
          attributes: transform(node.attributes),
        ),
      );
    }
  }
  return mergeTextRuns(result);
}

TextAttributes _attributesAtOffset(List<InlineNode> nodes, int offset) {
  var cursor = 0;
  for (final node in nodes) {
    final nodeEnd = cursor + inlineLength(node);
    if (offset >= cursor && offset < nodeEnd) {
      return switch (node) {
        TextRun(:final attributes) => attributes,
        InlineEmbed(:final attributes) => attributes,
        _ => const TextAttributes(),
      };
    }
    cursor = nodeEnd;
  }
  if (nodes.isNotEmpty) {
    final last = nodes.last;
    return switch (last) {
      TextRun(:final attributes) => attributes,
      InlineEmbed(:final attributes) => attributes,
      _ => const TextAttributes(),
    };
  }
  return const TextAttributes();
}

TextAttributes _withRevisionId(TextAttributes attributes, String revisionId) {
  return attributes.copyWith(
    revisionIds: _appendUnique(attributes.revisionIds, revisionId),
  );
}

TextAttributes _withoutRevisionId(
    TextAttributes attributes, String revisionId) {
  return attributes.copyWith(
    revisionIds:
        attributes.revisionIds.where((id) => id != revisionId).toList(),
  );
}

List<String> _appendUnique(List<String> ids, String id) {
  if (ids.contains(id)) {
    return ids;
  }
  return <String>[...ids, id];
}
