import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/comment_model.dart';
import '../model/revision_model.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';

const int _atomicBlockSelectionLength = 1;

/// Moves a top-level block from [fromIndex] to [toIndex].
///
/// [toIndex] is the moved block's final index after removal/insertion. Invalid
/// indexes and same-index moves are no-op and do not record history.
class MoveBlockCommand extends EditorCommand {
  const MoveBlockCommand({required this.fromIndex, required this.toIndex});

  final int fromIndex;
  final int toIndex;

  @override
  String get description => 'moveBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final document = session.document;
    final blockCount = document.blocks.length;
    if (fromIndex < 0 ||
        fromIndex >= blockCount ||
        toIndex < 0 ||
        toIndex >= blockCount ||
        fromIndex == toIndex) {
      return const CommandResult(recordHistory: false);
    }

    final move = _moveBlocksToFinalStart(
      document,
      fromIndex: fromIndex,
      count: 1,
      finalStartIndex: toIndex,
    );
    if (move == null) {
      return const CommandResult(recordHistory: false);
    }
    session.document = move.document;
    final moved = move.movedBlocks.first;
    return CommandResult(
      selection: _selectionForMovedBlock(moved, toIndex),
      metadata: <String, Object?>{
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'blockId': moved.id,
      },
    );
  }
}

/// Moves a continuous top-level block range to an external insertion boundary.
///
/// [toIndex] is expressed in the original document as an insertion boundary in
/// the range `0..blockCount`, before the moving range is removed. The command
/// normalizes it to the moved range's final start index after removal. Targets
/// inside the moving range, empty ranges, out-of-bounds values, and same-place
/// moves are no-op and do not record history.
class MoveBlockRangeCommand extends EditorCommand {
  const MoveBlockRangeCommand({
    required this.fromIndex,
    required this.count,
    required this.toIndex,
  });

  final int fromIndex;
  final int count;
  final int toIndex;

  @override
  String get description => 'moveBlockRange';

  @override
  CommandResult execute(DocumentSession session) {
    final document = session.document;
    final normalized = _normalizeExternalInsertionBoundary(
      blockCount: document.blocks.length,
      fromIndex: fromIndex,
      count: count,
      toIndex: toIndex,
    );
    if (normalized == null) {
      return const CommandResult(recordHistory: false);
    }

    final move = _moveBlocksToFinalStart(
      document,
      fromIndex: fromIndex,
      count: count,
      finalStartIndex: normalized.finalStartIndex,
    );
    if (move == null) {
      return const CommandResult(recordHistory: false);
    }
    session.document = move.document;
    return CommandResult(
      selection: _selectionForMovedBlock(
        move.movedBlocks.first,
        normalized.finalStartIndex,
      ),
      metadata: <String, Object?>{
        'fromIndex': fromIndex,
        'count': count,
        'toIndex': toIndex,
        'finalStartIndex': normalized.finalStartIndex,
        'blockIds': List<String>.unmodifiable(
          move.movedBlocks.map((block) => block.id),
        ),
      },
    );
  }
}

_NormalizedBlockRangeMove? _normalizeExternalInsertionBoundary({
  required int blockCount,
  required int fromIndex,
  required int count,
  required int toIndex,
}) {
  if (count <= 0 ||
      fromIndex < 0 ||
      fromIndex >= blockCount ||
      toIndex < 0 ||
      toIndex > blockCount) {
    return null;
  }
  final endIndexExclusive = fromIndex + count;
  if (endIndexExclusive > blockCount) {
    return null;
  }
  if (toIndex >= fromIndex && toIndex <= endIndexExclusive) {
    return null;
  }
  final finalStartIndex = toIndex < fromIndex ? toIndex : toIndex - count;
  return _NormalizedBlockRangeMove(finalStartIndex: finalStartIndex);
}

_MovedBlockRange? _moveBlocksToFinalStart(
  RichTextDocument document, {
  required int fromIndex,
  required int count,
  required int finalStartIndex,
}) {
  final blockCount = document.blocks.length;
  if (count <= 0 || fromIndex < 0 || fromIndex >= blockCount) {
    return null;
  }
  final endIndexExclusive = fromIndex + count;
  if (endIndexExclusive > blockCount) {
    return null;
  }
  final remainingCount = blockCount - count;
  if (finalStartIndex < 0 || finalStartIndex > remainingCount) {
    return null;
  }
  if (finalStartIndex == fromIndex) {
    return null;
  }

  final blocks = document.blocks.toList();
  final movedBlocks = blocks.sublist(fromIndex, endIndexExclusive);
  blocks.removeRange(fromIndex, endIndexExclusive);
  blocks.insertAll(finalStartIndex, movedBlocks);
  final blockIndexes = <String, int>{
    for (var index = 0; index < blocks.length; index++) blocks[index].id: index,
  };

  return _MovedBlockRange(
    document: RichTextDocument(
      version: document.version,
      blocks: blocks,
      comments: _retargetCommentThreads(document.comments, blockIndexes),
      revisions: _retargetRevisionChanges(document.revisions, blockIndexes),
    ),
    movedBlocks: List<BlockNode>.unmodifiable(movedBlocks),
  );
}

class _NormalizedBlockRangeMove {
  const _NormalizedBlockRangeMove({required this.finalStartIndex});

  final int finalStartIndex;
}

class _MovedBlockRange {
  const _MovedBlockRange({
    required this.document,
    required this.movedBlocks,
  });

  final RichTextDocument document;
  final List<BlockNode> movedBlocks;
}

List<CommentThread> _retargetCommentThreads(
  List<CommentThread> comments,
  Map<String, int> blockIndexes,
) {
  return comments.map((thread) {
    final nextIndex = blockIndexes[thread.anchor.blockId];
    if (nextIndex == null || nextIndex == thread.anchor.blockIndex) {
      return thread.copy();
    }
    return thread.copyWith(
      anchor: thread.anchor.copyWith(blockIndex: nextIndex),
      messages: thread.messages.map((message) => message.copy()).toList(),
    );
  }).toList();
}

List<RevisionChange> _retargetRevisionChanges(
  List<RevisionChange> revisions,
  Map<String, int> blockIndexes,
) {
  return revisions.map((revision) {
    final nextIndex = blockIndexes[revision.range.blockId];
    if (nextIndex == null || nextIndex == revision.range.blockIndex) {
      return revision.copy();
    }
    return revision.copyWith(
      range: revision.range.copyWith(blockIndex: nextIndex),
      metadata: Map<String, Object?>.from(revision.metadata),
    );
  }).toList();
}

DocumentSelection _selectionForMovedBlock(BlockNode block, int blockIndex) {
  final position = switch (block) {
    TextBlockNode() => DocumentPosition.text(
        blockId: block.id,
        blockIndex: blockIndex,
        offset: block.plainText.length,
      ),
    CodeBlockNode() => DocumentPosition.code(
        blockId: block.id,
        blockIndex: blockIndex,
        offset: block.code.length,
      ),
    TableBlockNode() => _firstTableCellPosition(block, blockIndex) ??
        DocumentPosition.object(blockId: block.id, blockIndex: blockIndex),
    _ => DocumentPosition.object(blockId: block.id, blockIndex: blockIndex),
  };
  if (position.path.isBlockObject) {
    return DocumentSelection(
      base: position,
      extent: position.copyWith(offset: _atomicBlockSelectionLength),
    );
  }
  return DocumentSelection(base: position, extent: position);
}

DocumentPosition? _firstTableCellPosition(
  TableBlockNode block,
  int blockIndex,
) {
  for (var rowIndex = 0; rowIndex < block.table.rows.length; rowIndex++) {
    final row = block.table.rows[rowIndex];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final cell = row[columnIndex];
      if (cell.covered) {
        continue;
      }
      return DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: blockIndex,
        tableRowIndex: rowIndex,
        tableColumnIndex: columnIndex,
        offset: 0,
      );
    }
  }
  return null;
}

/// Adjusts the [BlockAttributes.indent] of every text block covered by the
/// current selection by [delta] (clamped to >= 0 and the schema max). Stage 3
/// uses indent for both paragraph indentation and quote nesting depth.
class IndentCommand extends EditorCommand {
  const IndentCommand(this.delta, {this.selection});

  final int delta;
  final DocumentSelection? selection;

  @override
  String get description => delta > 0 ? 'indent' : 'outdent';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || delta == 0) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final current = block.attributes.indent ?? 0;
      final next = (current + delta).clamp(0, 8).toInt();
      if (next == current) {
        continue;
      }
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: BlockAttributes(
          level: block.attributes.level,
          indent: next,
          alignment: block.attributes.alignment,
          listType: block.attributes.listType,
          checked: block.attributes.checked,
          quoted: block.attributes.quoted,
          childNote: block.attributes.childNote,
          anchor: block.attributes.anchor,
        ),
        content: block.content,
      );
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

/// Toggles todo mode for the selected text blocks.
///
/// When every selected text block is already a todo, unordered task items are
/// converted back to paragraphs and ordered items keep their numbering while
/// losing todo state. Otherwise todo mode is applied to every non-todo text
/// block without changing the completion state of existing todo items.
class ToggleTodoCommand extends EditorCommand {
  const ToggleTodoCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleTodo';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.toList();
    final removeTodo = _allTextBlocksAreTodo(target, blocks);
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final isListItem = block.type == BlockType.listItem;
      final isTodo = _isTodoBlock(block);
      if (removeTodo) {
        blocks[i] = _textBlockWithoutTodo(block);
      } else if (isTodo) {
        continue;
      } else if (isListItem) {
        blocks[i] = _textBlockWithChecked(block, false);
      } else {
        blocks[i] = TextBlockNode(
          id: block.id,
          type: BlockType.listItem,
          attributes: BlockAttributes(
            indent: block.attributes.indent,
            alignment: block.attributes.alignment,
            listType: 'task',
            checked: false,
            quoted: block.attributes.quoted,
            childNote: block.attributes.childNote,
            anchor: block.attributes.anchor,
          ),
          content: block.content,
        );
      }
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

bool _allTextBlocksAreTodo(
  DocumentSelection target,
  List<BlockNode> blocks,
) {
  var sawTextBlock = false;
  for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
    if (i < 0 || i >= blocks.length) {
      continue;
    }
    final block = blocks[i];
    if (block is! TextBlockNode) {
      continue;
    }
    sawTextBlock = true;
    if (!_isTodoBlock(block)) {
      return false;
    }
  }
  return sawTextBlock;
}

bool _isTodoBlock(TextBlockNode block) {
  return block.type == BlockType.listItem &&
      (block.attributes.listType == 'task' || block.attributes.checked != null);
}

TextBlockNode _textBlockWithoutTodo(TextBlockNode block) {
  final attributes = block.attributes;
  if (attributes.listType != 'task') {
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: BlockAttributes(
        level: attributes.level,
        indent: attributes.indent,
        alignment: attributes.alignment,
        listType: attributes.listType,
        quoted: attributes.quoted,
        childNote: attributes.childNote,
        anchor: attributes.anchor,
      ),
      content: block.content,
    );
  }
  return TextBlockNode(
    id: block.id,
    type: BlockType.paragraph,
    attributes: BlockAttributes(
      indent: attributes.indent,
      alignment: attributes.alignment,
      quoted: attributes.quoted,
      childNote: attributes.childNote,
      anchor: attributes.anchor,
    ),
    content: block.content,
  );
}

/// Sets the checked state of an existing task list item without moving the
/// current selection.
class SetTodoCheckedCommand extends EditorCommand {
  const SetTodoCheckedCommand({
    required this.blockIndex,
    required this.checked,
  });

  final int blockIndex;
  final bool checked;

  @override
  String get description => 'setTodoChecked';

  @override
  CommandResult execute(DocumentSession session) {
    if (blockIndex < 0 || blockIndex >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[blockIndex];
    if (block is! TextBlockNode ||
        block.type != BlockType.listItem ||
        (block.attributes.listType != 'task' &&
            block.attributes.checked == null) ||
        block.attributes.checked == checked) {
      return const CommandResult(recordHistory: false);
    }
    session.document = session.document.replaceBlockAt(
      blockIndex,
      _textBlockWithChecked(block, checked),
    );
    return const CommandResult();
  }
}

TextBlockNode _textBlockWithChecked(TextBlockNode block, bool checked) {
  return TextBlockNode(
    id: block.id,
    type: block.type,
    attributes: BlockAttributes(
      level: block.attributes.level,
      indent: block.attributes.indent,
      alignment: block.attributes.alignment,
      listType: block.attributes.listType,
      checked: checked,
      quoted: block.attributes.quoted,
      childNote: block.attributes.childNote,
      anchor: block.attributes.anchor,
    ),
    content: block.content,
  );
}

/// Sets the [CodeBlockNode.language] of the code block at the caret.
class SetCodeLanguageCommand extends EditorCommand {
  const SetCodeLanguageCommand(this.language, {this.blockIndex});

  final String language;
  final int? blockIndex;

  @override
  String get description => 'setCodeLanguage';

  @override
  CommandResult execute(DocumentSession session) {
    final nextLanguage = _normalizeCodeLanguage(language);
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CodeBlockNode || block.language == nextLanguage) {
      return const CommandResult(recordHistory: false);
    }
    final nextBlock = CodeBlockNode(
      id: block.id,
      code: block.code,
      language: nextLanguage,
      attributes: block.attributes,
    );
    session.document = session.document.replaceBlockAt(index, nextBlock);
    return const CommandResult();
  }
}

const String _mermaidLanguage = 'mermaid';

String _normalizeCodeLanguage(String language) {
  final trimmed = language.trim();
  return _isMermaidCodeLanguage(trimmed) ? _mermaidLanguage : trimmed;
}

bool _isMermaidCodeLanguage(String language) {
  final firstToken = _firstCodeLanguageToken(language);
  return firstToken.toLowerCase() == _mermaidLanguage;
}

String _firstCodeLanguageToken(String language) {
  if (language.isEmpty) {
    return '';
  }
  final whitespace = RegExp(r'\s+').firstMatch(language);
  if (whitespace == null) {
    return language;
  }
  return language.substring(0, whitespace.start);
}

/// Sets the [CalloutBlockNode.variant] of the callout block at the caret.
class SetCalloutVariantCommand extends EditorCommand {
  const SetCalloutVariantCommand(this.variant, {this.blockIndex});

  final String variant;
  final int? blockIndex;

  @override
  String get description => 'setCalloutVariant';

  @override
  CommandResult execute(DocumentSession session) {
    final nextVariant = CalloutBlockNode.normalizeVariant(variant);
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CalloutBlockNode || block.normalizedVariant == nextVariant) {
      return const CommandResult(recordHistory: false);
    }
    session.document = session.document.replaceBlockAt(
      index,
      block.copyWith(variant: nextVariant),
    );
    return const CommandResult();
  }
}

/// Updates the metadata of the callout block at [blockIndex] or the caret.
///
/// Empty [title] or [icon] values clear the custom value, allowing the block to
/// fall back to the default title/icon for its current variant.
class UpdateCalloutBlockCommand extends EditorCommand {
  const UpdateCalloutBlockCommand({
    this.blockIndex,
    this.variant,
    this.title,
    this.icon,
  });

  final int? blockIndex;
  final String? variant;
  final String? title;
  final String? icon;

  @override
  String get description => 'updateCalloutBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CalloutBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final nextVariant = variant == null
        ? CalloutBlockNode.normalizeVariant(block.variant)
        : CalloutBlockNode.normalizeVariant(variant);
    final nextTitle = title == null ? block.title : title!.trim();
    final nextIcon = icon == null ? block.icon : icon!.trim();
    if (block.variant == nextVariant &&
        block.title == nextTitle &&
        block.icon == nextIcon) {
      return const CommandResult(recordHistory: false);
    }

    final nextBlock = block.copyWith(
      variant: nextVariant,
      title: nextTitle,
      icon: nextIcon,
    );
    session.document = session.document.replaceBlockAt(index, nextBlock);
    return const CommandResult();
  }
}

/// Indents or outdents every code line touched by the current code selection.
class IndentCodeBlockCommand extends EditorCommand {
  const IndentCodeBlockCommand({
    this.selection,
    this.indent = '  ',
    this.outdent = false,
  });

  final DocumentSelection? selection;
  final String indent;
  final bool outdent;

  @override
  String get description => outdent ? 'outdentCodeBlock' : 'indentCodeBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || indent.isEmpty) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex ||
        start.path != end.path ||
        !start.path.isBlockCode) {
      return const CommandResult(recordHistory: false);
    }
    final index = start.blockIndex;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CodeBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final code = block.code;
    final rangeStart = start.offset.clamp(0, code.length).toInt();
    final rangeEnd = end.offset.clamp(rangeStart, code.length).toInt();
    final lineStarts = _codeLineStartsForRange(code, rangeStart, rangeEnd);
    if (lineStarts.isEmpty) {
      return const CommandResult(recordHistory: false);
    }

    var nextCode = code;
    var baseOffset = target.base.offset.clamp(0, code.length).toInt();
    var extentOffset = target.extent.offset.clamp(0, code.length).toInt();
    var changed = false;

    for (final lineStart in lineStarts.reversed) {
      final removedLength =
          outdent ? _codeOutdentLength(nextCode, lineStart, indent) : 0;
      final inserted = outdent ? '' : indent;
      if (outdent && removedLength == 0) {
        continue;
      }
      nextCode = nextCode.replaceRange(
        lineStart,
        lineStart + removedLength,
        inserted,
      );
      baseOffset = _transformCodeOffset(
        baseOffset,
        lineStart,
        removedLength,
        inserted.length,
      );
      extentOffset = _transformCodeOffset(
        extentOffset,
        lineStart,
        removedLength,
        inserted.length,
      );
      changed = true;
    }

    if (!changed || nextCode == code) {
      return const CommandResult(recordHistory: false);
    }

    final nextBlock = CodeBlockNode(
      id: block.id,
      code: nextCode,
      language: block.language,
      attributes: block.attributes,
    );
    session.document = session.document.replaceBlockAt(index, nextBlock);
    final base = target.base.copyWith(offset: baseOffset);
    final extent = target.extent.copyWith(offset: extentOffset);
    return CommandResult(
        selection: DocumentSelection(base: base, extent: extent));
  }
}

List<int> _codeLineStartsForRange(String code, int start, int end) {
  if (code.isEmpty) {
    return const <int>[0];
  }
  final effectiveEnd =
      start == end || end == 0 || code.codeUnitAt(end - 1) != 0x0A
          ? end
          : end - 1;
  final firstLineStart = _codeLineStart(code, start);
  final lastLineStart = _codeLineStart(code, effectiveEnd);
  final starts = <int>[];
  var current = firstLineStart;
  while (current <= lastLineStart && current <= code.length) {
    starts.add(current);
    final nextBreak = code.indexOf('\n', current);
    if (nextBreak < 0) {
      break;
    }
    current = nextBreak + 1;
  }
  return starts;
}

int _codeLineStart(String code, int offset) {
  if (code.isEmpty) {
    return 0;
  }
  final clamped = offset.clamp(0, code.length).toInt();
  if (clamped == 0) {
    return 0;
  }
  final newline = code.lastIndexOf('\n', clamped - 1);
  return newline < 0 ? 0 : newline + 1;
}

int _codeOutdentLength(String code, int lineStart, String indent) {
  if (lineStart >= code.length) {
    return 0;
  }
  if (code.startsWith(indent, lineStart)) {
    return indent.length;
  }
  if (code.codeUnitAt(lineStart) == 0x09) {
    return 1;
  }
  var spaces = 0;
  while (spaces < indent.length &&
      lineStart + spaces < code.length &&
      code.codeUnitAt(lineStart + spaces) == 0x20) {
    spaces += 1;
  }
  return spaces;
}

int _transformCodeOffset(
  int offset,
  int changeStart,
  int removedLength,
  int insertedLength,
) {
  if (removedLength == 0) {
    return offset < changeStart ? offset : offset + insertedLength;
  }
  if (offset <= changeStart) {
    return offset;
  }
  final changeEnd = changeStart + removedLength;
  if (offset <= changeEnd) {
    return changeStart + insertedLength;
  }
  return offset + insertedLength - removedLength;
}

/// Toggles the quote decoration of text blocks at the caret. Quote is stored as
/// a block attribute, so heading, list, todo, indent, and alignment semantics
/// are preserved while the quote surface is toggled.
class ToggleQuoteCommand extends EditorCommand {
  const ToggleQuoteCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleQuote';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.toList();
    final quoted = !_allTextBlocksQuoted(target, blocks);
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      blocks[i] = _convert(block, quoted: quoted);
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }

  bool _allTextBlocksQuoted(DocumentSelection target, List<BlockNode> blocks) {
    var sawTextBlock = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      sawTextBlock = true;
      if (block.type != BlockType.quote && !block.attributes.isQuoted) {
        return false;
      }
    }
    return sawTextBlock;
  }

  TextBlockNode _convert(TextBlockNode block, {required bool quoted}) {
    return TextBlockNode(
      id: block.id,
      type: block.type == BlockType.quote ? BlockType.paragraph : block.type,
      attributes: BlockAttributes(
        level: block.attributes.level,
        indent: block.attributes.indent,
        alignment: block.attributes.alignment,
        listType: block.attributes.listType,
        checked: block.attributes.checked,
        quoted: quoted ? true : null,
        childNote: block.attributes.childNote,
        anchor: block.attributes.anchor,
      ),
      content: block.content,
    );
  }
}
