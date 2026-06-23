import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../model/table_model.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'table_cell_editing.dart';

class InsertTextCommand extends EditorCommand {
  const InsertTextCommand(
    this.text, {
    this.attributes = const TextAttributes(),
  });

  final String text;
  final TextAttributes attributes;

  @override
  String get description => 'insertText';

  /// Consecutive inserts of text with identical attributes coalesce into one
  /// undo step (so undo after typing a word reverts the whole word, not one
  /// character). Contiguity of the caret position is enforced by
  /// [CommandExecutor]; here we only gate on type + attributes.
  @override
  bool canMergeWith(EditorCommand previous) {
    return previous is InsertTextCommand && previous.attributes == attributes;
  }

  @override
  CommandResult execute(DocumentSession session) {
    if (text.isEmpty || session.selection == null) {
      return const CommandResult(recordHistory: false);
    }

    if (!session.selection!.isCollapsed) {
      final deleteResult = DeleteSelectionCommand(
        session.selection!,
      ).execute(session);
      if (deleteResult.selection != null) {
        session.selection = deleteResult.selection;
      }
    }

    final position = session.selection!.extent;
    if (position.path.isTableCellText) {
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return insertTableCellInlineText(
        session,
        position.blockIndex,
        rowIndex,
        columnIndex,
        position.offset,
        text,
        attributes: attributes,
      );
    }

    final block = _blockAt(session.document, position.blockIndex);
    if (block == null) {
      return const CommandResult(recordHistory: false);
    }

    final nextOffset = position.offset + text.length;
    if (block is TextBlockNode) {
      final nextBlock = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: insertInline(block.content, position.offset, text, attributes),
      );
      _replaceBlock(session, position.blockIndex, nextBlock);
    } else if (block is CodeBlockNode) {
      final offset = position.offset.clamp(0, block.code.length);
      final nextBlock = CodeBlockNode(
        id: block.id,
        code: block.code.replaceRange(offset, offset, text),
        language: block.language,
        attributes: block.attributes,
      );
      _replaceBlock(session, position.blockIndex, nextBlock);
    } else {
      return const CommandResult(recordHistory: false);
    }

    final nextPosition = position.copyWith(offset: nextOffset);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
}

class DeleteSelectionCommand extends EditorCommand {
  const DeleteSelectionCommand([this.selection]);

  final DocumentSelection? selection;

  @override
  String get description => 'deleteSelection';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || target.isCollapsed) {
      return const CommandResult(recordHistory: false);
    }

    final tableCellRange = target.tableCellRange;
    if (tableCellRange != null && !tableCellRange.isSingleCell) {
      return clearTableCellRange(session, tableCellRange);
    }

    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex) {
      return _deleteAcrossBlocks(session, start, end);
    }
    if (start.path != end.path) {
      return const CommandResult(recordHistory: false);
    }
    if (start.path.isTableCellText) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return deleteTableCellInlineRange(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
      );
    }

    final block = _blockAt(session.document, start.blockIndex);
    if (block == null) {
      return const CommandResult(recordHistory: false);
    }

    if (block is TextBlockNode) {
      final nextBlock = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: deleteInline(block.content, start.offset, end.offset),
      );
      _replaceBlock(session, start.blockIndex, nextBlock);
    } else if (block is CodeBlockNode) {
      final startOffset = start.offset.clamp(0, block.code.length);
      final endOffset = end.offset.clamp(startOffset, block.code.length);
      final nextBlock = CodeBlockNode(
        id: block.id,
        code: block.code.replaceRange(startOffset, endOffset, ''),
        language: block.language,
        attributes: block.attributes,
      );
      _replaceBlock(session, start.blockIndex, nextBlock);
    } else if (start.path.isBlockObject) {
      // A whole object block (image/divider/video/file) is selected. Remove the
      // block and land the caret on a neighbouring editable block — the end of
      // the previous block if any, else the start of the next. When the block
      // was the only one, schema normalisation (run by the executor) re-adds an
      // empty paragraph and the caret falls there.
      return _deleteObjectBlock(session, start.blockIndex);
    } else {
      return const CommandResult(recordHistory: false);
    }

    return CommandResult(
      selection: DocumentSelection(base: start, extent: start),
    );
  }
}

class DeleteBackwardCommand extends EditorCommand {
  const DeleteBackwardCommand();

  @override
  String get description => 'deleteBackward';

  /// Repeated backspace coalesces into one undo step (undo after deleting a
  /// run of characters restores the whole run).
  @override
  bool canMergeWith(EditorCommand previous) =>
      previous is DeleteBackwardCommand;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!selection.isCollapsed) {
      return DeleteSelectionCommand(selection).execute(session);
    }

    final position = selection.extent;
    if (position.path.isTableCellText) {
      final target = tableCellTargetFromPosition(session, position);
      if (target == null) {
        return const CommandResult(recordHistory: false);
      }
      final offset = position.offset.clamp(0, target.textLength).toInt();
      if (offset == 0) {
        return const CommandResult(recordHistory: false);
      }
      return deleteTableCellInlineRange(
        session,
        position.blockIndex,
        position.path.tableRowIndex!,
        position.path.tableColumnIndex!,
        offset - 1,
        offset,
      );
    }
    final block = _blockAt(session.document, position.blockIndex);
    if (block is TextBlockNode) {
      final offset = position.offset.clamp(
        0,
        inlineNodesLength(block.content),
      );
      if (offset > 0) {
        return _deleteTextRange(session, position, offset - 1, offset);
      }
      return _mergeWithPreviousBlock(session, position);
    }
    if (block is CodeBlockNode) {
      final offset = position.offset.clamp(0, block.code.length);
      if (offset > 0) {
        return _deleteCodeRange(session, position, offset - 1, offset);
      }
      return _mergeWithPreviousBlock(session, position);
    }
    return const CommandResult(recordHistory: false);
  }
}

class DeleteForwardCommand extends EditorCommand {
  const DeleteForwardCommand();

  @override
  String get description => 'deleteForward';

  /// Repeated forward-delete coalesces into one undo step.
  @override
  bool canMergeWith(EditorCommand previous) => previous is DeleteForwardCommand;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!selection.isCollapsed) {
      return DeleteSelectionCommand(selection).execute(session);
    }

    final position = selection.extent;
    if (position.path.isTableCellText) {
      final target = tableCellTargetFromPosition(session, position);
      if (target == null) {
        return const CommandResult(recordHistory: false);
      }
      final offset = position.offset.clamp(0, target.textLength).toInt();
      if (offset >= target.textLength) {
        return const CommandResult(recordHistory: false);
      }
      return deleteTableCellInlineRange(
        session,
        position.blockIndex,
        position.path.tableRowIndex!,
        position.path.tableColumnIndex!,
        offset,
        offset + 1,
      );
    }
    final block = _blockAt(session.document, position.blockIndex);
    if (block is TextBlockNode) {
      final offset = position.offset.clamp(
        0,
        inlineNodesLength(block.content),
      );
      if (offset < inlineNodesLength(block.content)) {
        return _deleteTextRange(session, position, offset, offset + 1);
      }
      return _mergeWithNextBlock(session, position);
    }
    if (block is CodeBlockNode) {
      final offset = position.offset.clamp(0, block.code.length);
      if (offset < block.code.length) {
        return _deleteCodeRange(session, position, offset, offset + 1);
      }
      return _mergeWithNextBlock(session, position);
    }
    return const CommandResult(recordHistory: false);
  }
}

CommandResult _deleteAcrossBlocks(
  DocumentSession session,
  DocumentPosition start,
  DocumentPosition end,
) {
  final leading = _leadingRemainderForPosition(session, start);
  final trailing = _trailingRemainderForPosition(session, end);

  final before = <BlockNode>[
    for (var i = 0; i < start.blockIndex; i++)
      session.document.blocks[i].copy(),
  ];
  final after = <BlockNode>[
    for (var i = end.blockIndex + 1; i < session.document.blocks.length; i++)
      session.document.blocks[i].copy(),
  ];

  final rebuilt = <BlockNode>[];
  DocumentSelection? nextSelection;
  final merged = _mergeBoundaryRemainders(leading, trailing);
  if (merged != null) {
    rebuilt.add(merged);
    nextSelection = _collapsedAfterLeading(start, leading!, before.length);
  } else {
    if (leading != null) {
      rebuilt.add(leading);
      nextSelection = _collapsedAfterLeading(start, leading, before.length);
    }
    if (trailing != null) {
      rebuilt.add(trailing);
      nextSelection ??= _collapsedAtTrailingStart(
        end,
        trailing,
        before.length + rebuilt.length - 1,
      );
    }
  }

  final blocks = <BlockNode>[
    ...before,
    ...rebuilt,
    ...after,
  ];
  if (blocks.isEmpty) {
    final paragraph = _emptyParagraphAfterDelete(start.blockId);
    final position = DocumentPosition.text(
      blockId: paragraph.id,
      blockIndex: 0,
      offset: 0,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: <BlockNode>[paragraph],
    );
    return CommandResult(
      selection: DocumentSelection(base: position, extent: position),
    );
  }
  nextSelection ??= _collapsedNearDeletion(blocks, before.length);

  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );

  return CommandResult(
    selection: nextSelection,
  );
}

TextBlockNode _emptyParagraphAfterDelete(String seedBlockId) {
  return TextBlockNode(
    id: '$seedBlockId-empty',
    type: BlockType.paragraph,
    content: const <InlineNode>[],
  );
}

DocumentSelection? _collapsedNearDeletion(
  List<BlockNode> blocks,
  int deletionIndex,
) {
  for (var i = deletionIndex; i < blocks.length; i++) {
    final selection = _caretAtBlockStartOrFirstCell(blocks[i], i);
    if (selection != null) {
      return selection;
    }
  }
  for (var i = deletionIndex - 1; i >= 0; i--) {
    final selection = _caretAtBlockEndOrLastCell(blocks[i], i);
    if (selection != null) {
      return selection;
    }
  }
  return null;
}

DocumentSelection? _caretAtBlockStartOrFirstCell(BlockNode block, int index) {
  if (block is TextBlockNode || block is CodeBlockNode) {
    return _caretAtBlockStart(block, index);
  }
  if (block is TableBlockNode && block.table.rowCount > 0) {
    final position = DocumentPosition.tableCell(
      tableBlockId: block.id,
      blockIndex: index,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    );
    return DocumentSelection(base: position, extent: position);
  }
  return null;
}

DocumentSelection? _caretAtBlockEndOrLastCell(BlockNode block, int index) {
  if (block is TextBlockNode || block is CodeBlockNode) {
    return _caretAtBlockEnd(block, index);
  }
  if (block is TableBlockNode &&
      block.table.rowCount > 0 &&
      block.table.columnCount > 0) {
    final rowIndex = block.table.rowCount - 1;
    final columnIndex = block.table.columnCount - 1;
    final position = DocumentPosition.tableCell(
      tableBlockId: block.id,
      blockIndex: index,
      tableRowIndex: rowIndex,
      tableColumnIndex: columnIndex,
      offset: _tableCellTextLength(block, rowIndex, columnIndex),
    );
    return DocumentSelection(base: position, extent: position);
  }
  return null;
}

BlockNode? _leadingRemainderForPosition(
  DocumentSession session,
  DocumentPosition position,
) {
  final block = _blockAt(session.document, position.blockIndex);
  if (block is TextBlockNode && position.path.isBlockText) {
    final split = splitInline(block.content, position.offset);
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: split.before,
    );
  }
  if (block is CodeBlockNode && position.path.isBlockCode) {
    final offset = position.offset.clamp(0, block.code.length).toInt();
    return CodeBlockNode(
      id: block.id,
      code: block.code.substring(0, offset),
      language: block.language,
      attributes: block.attributes,
    );
  }
  if (block is TableBlockNode && position.path.isTableCellText) {
    return _trimTableAroundPosition(block, position, keepBefore: true);
  }
  return null;
}

BlockNode? _trailingRemainderForPosition(
  DocumentSession session,
  DocumentPosition position,
) {
  final block = _blockAt(session.document, position.blockIndex);
  if (block is TextBlockNode && position.path.isBlockText) {
    final split = splitInline(block.content, position.offset);
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: split.after,
    );
  }
  if (block is CodeBlockNode && position.path.isBlockCode) {
    final offset = position.offset.clamp(0, block.code.length).toInt();
    return CodeBlockNode(
      id: block.id,
      code: block.code.substring(offset),
      language: block.language,
      attributes: block.attributes,
    );
  }
  if (block is TableBlockNode && position.path.isTableCellText) {
    return _trimTableAroundPosition(block, position, keepBefore: false);
  }
  return null;
}

BlockNode? _mergeBoundaryRemainders(BlockNode? leading, BlockNode? trailing) {
  if (leading is TextBlockNode && trailing is TextBlockNode) {
    return TextBlockNode(
      id: leading.id,
      type: leading.type,
      attributes: leading.attributes,
      content: mergeTextRuns(<InlineNode>[
        ...leading.content.map((node) => node.copy()),
        ...trailing.content.map((node) => node.copy()),
      ]),
    );
  }
  if (leading is CodeBlockNode && trailing is CodeBlockNode) {
    return CodeBlockNode(
      id: leading.id,
      code: leading.code + trailing.code,
      language: leading.language,
      attributes: leading.attributes,
    );
  }
  return null;
}

DocumentSelection? _collapsedAfterLeading(
  DocumentPosition originalStart,
  BlockNode block,
  int blockIndex,
) {
  DocumentPosition? position;
  if (block is TextBlockNode && originalStart.path.isBlockText) {
    position = DocumentPosition.text(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: inlineNodesLength(block.content),
    );
  } else if (block is CodeBlockNode && originalStart.path.isBlockCode) {
    position = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: block.code.length,
    );
  } else if (block is TableBlockNode && originalStart.path.isTableCellText) {
    final rowIndex = originalStart.path.tableRowIndex;
    final columnIndex = originalStart.path.tableColumnIndex;
    if (rowIndex != null && columnIndex != null) {
      final length = _tableCellTextLength(block, rowIndex, columnIndex);
      position = DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: blockIndex,
        tableRowIndex: rowIndex,
        tableColumnIndex: columnIndex,
        offset: originalStart.offset.clamp(0, length).toInt(),
      );
    }
  }
  return position == null
      ? null
      : DocumentSelection(base: position, extent: position);
}

DocumentSelection? _collapsedAtTrailingStart(
  DocumentPosition originalEnd,
  BlockNode block,
  int blockIndex,
) {
  DocumentPosition? position;
  if (block is TextBlockNode && originalEnd.path.isBlockText) {
    position = DocumentPosition.text(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
  } else if (block is CodeBlockNode && originalEnd.path.isBlockCode) {
    position = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
  } else if (block is TableBlockNode && originalEnd.path.isTableCellText) {
    final rowIndex = originalEnd.path.tableRowIndex;
    final columnIndex = originalEnd.path.tableColumnIndex;
    if (rowIndex != null && columnIndex != null) {
      position = DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: blockIndex,
        tableRowIndex: rowIndex,
        tableColumnIndex: columnIndex,
        offset: 0,
      );
    }
  }
  return position == null
      ? null
      : DocumentSelection(base: position, extent: position);
}

TableBlockNode _trimTableAroundPosition(
  TableBlockNode tableBlock,
  DocumentPosition position, {
  required bool keepBefore,
}) {
  final rows = <List<TableCellNode>>[];
  for (var rowIndex = 0; rowIndex < tableBlock.table.rows.length; rowIndex++) {
    final row = tableBlock.table.rows[rowIndex];
    final nextRow = <TableCellNode>[];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final cell = row[columnIndex];
      final cellPath = PositionPath.tableCellText(
        tableBlock.id,
        rowIndex,
        columnIndex,
      );
      final compare = cellPath.compare(position.path);
      if (compare == 0) {
        nextRow.add(
          _trimTableCellText(cell, position.offset, keepBefore: keepBefore),
        );
      } else if ((keepBefore && compare < 0) || (!keepBefore && compare > 0)) {
        nextRow.add(copyCell(cell));
      } else {
        nextRow.add(_clearTableCell(cell));
      }
    }
    rows.add(nextRow);
  }
  return TableBlockNode(
    id: tableBlock.id,
    attributes: tableBlock.attributes,
    table: TableModel(
      rows: rows,
      columnAlignments: Map<int, String>.from(
        tableBlock.table.columnAlignments,
      ),
      columnWidths: Map<int, double>.from(tableBlock.table.columnWidths),
    ),
  );
}

TableCellNode _trimTableCellText(
  TableCellNode cell,
  int offset, {
  required bool keepBefore,
}) {
  final textBlock = cellTextBlock(cell);
  final length = inlineNodesLength(textBlock.content);
  final safeOffset = offset.clamp(0, length).toInt();
  final split = splitInline(textBlock.content, safeOffset);
  final nextContent = keepBefore ? split.before : split.after;
  return TableCellNode(
    id: cell.id,
    blocks: <BlockNode>[
      TextBlockNode(
        id: textBlock.id,
        type: textBlock.type,
        attributes: textBlock.attributes,
        content: nextContent,
      ),
    ],
    rowSpan: cell.rowSpan,
    columnSpan: cell.columnSpan,
    isHeader: cell.isHeader,
    backgroundColor: cell.backgroundColor,
    covered: cell.covered,
  );
}

TableCellNode _clearTableCell(TableCellNode cell) {
  final textBlock = cellTextBlock(cell);
  return TableCellNode(
    id: cell.id,
    blocks: <BlockNode>[
      TextBlockNode(
        id: textBlock.id,
        type: textBlock.type,
        attributes: textBlock.attributes,
        content: const <InlineNode>[],
      ),
    ],
    rowSpan: cell.rowSpan,
    columnSpan: cell.columnSpan,
    isHeader: cell.isHeader,
    backgroundColor: cell.backgroundColor,
    covered: cell.covered,
  );
}

int _tableCellTextLength(
  TableBlockNode tableBlock,
  int rowIndex,
  int columnIndex,
) {
  final cell = tableBlock.table.cellAt(rowIndex, columnIndex);
  if (cell == null) {
    return 0;
  }
  return inlineNodesLength(cellTextBlock(cell).content);
}

CommandResult _deleteTextRange(
  DocumentSession session,
  DocumentPosition position,
  int start,
  int end,
) {
  final block = _blockAt(session.document, position.blockIndex);
  if (block is! TextBlockNode) {
    return const CommandResult(recordHistory: false);
  }
  final length = inlineNodesLength(block.content);
  final startOffset = start.clamp(0, length);
  final endOffset = end.clamp(startOffset, length);
  if (startOffset == endOffset) {
    return const CommandResult(recordHistory: false);
  }
  final nextBlock = TextBlockNode(
    id: block.id,
    type: block.type,
    attributes: block.attributes,
    content: deleteInline(block.content, startOffset, endOffset),
  );
  _replaceBlock(session, position.blockIndex, nextBlock);
  final nextPosition = position.copyWith(offset: startOffset);
  return CommandResult(
    selection: DocumentSelection(base: nextPosition, extent: nextPosition),
  );
}

CommandResult _deleteCodeRange(
  DocumentSession session,
  DocumentPosition position,
  int start,
  int end,
) {
  final block = _blockAt(session.document, position.blockIndex);
  if (block is! CodeBlockNode) {
    return const CommandResult(recordHistory: false);
  }
  final startOffset = start.clamp(0, block.code.length);
  final endOffset = end.clamp(startOffset, block.code.length);
  if (startOffset == endOffset) {
    return const CommandResult(recordHistory: false);
  }
  final nextBlock = CodeBlockNode(
    id: block.id,
    code: block.code.replaceRange(startOffset, endOffset, ''),
    language: block.language,
    attributes: block.attributes,
  );
  _replaceBlock(session, position.blockIndex, nextBlock);
  final nextPosition = position.copyWith(offset: startOffset);
  return CommandResult(
    selection: DocumentSelection(base: nextPosition, extent: nextPosition),
  );
}

CommandResult _mergeWithPreviousBlock(
  DocumentSession session,
  DocumentPosition position,
) {
  if (position.blockIndex <= 0) {
    return const CommandResult(recordHistory: false);
  }
  final previousIndex = position.blockIndex - 1;
  final previous = _blockAt(session.document, previousIndex);
  final current = _blockAt(session.document, position.blockIndex);
  if (previous is TextBlockNode && current is TextBlockNode) {
    final previousLength = inlineNodesLength(previous.content);
    final mergedBlock = TextBlockNode(
      id: previous.id,
      type: previous.type,
      attributes: previous.attributes,
      content: mergeTextRuns(<InlineNode>[
        ...previous.content.map((node) => node.copy()),
        ...current.content.map((node) => node.copy()),
      ]),
    );
    _replaceBlocks(session, previousIndex, 2, <BlockNode>[mergedBlock]);
    final nextPosition = DocumentPosition.text(
      blockId: previous.id,
      blockIndex: previousIndex,
      offset: previousLength,
    );
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
  if (previous is CodeBlockNode && current is CodeBlockNode) {
    final previousLength = previous.code.length;
    final mergedBlock = CodeBlockNode(
      id: previous.id,
      code: previous.code + current.code,
      language: previous.language,
      attributes: previous.attributes,
    );
    _replaceBlocks(session, previousIndex, 2, <BlockNode>[mergedBlock]);
    final nextPosition = DocumentPosition.code(
      blockId: previous.id,
      blockIndex: previousIndex,
      offset: previousLength,
    );
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
  return const CommandResult(recordHistory: false);
}

CommandResult _mergeWithNextBlock(
  DocumentSession session,
  DocumentPosition position,
) {
  final nextIndex = position.blockIndex + 1;
  if (nextIndex >= session.document.blocks.length) {
    return const CommandResult(recordHistory: false);
  }
  final current = _blockAt(session.document, position.blockIndex);
  final next = _blockAt(session.document, nextIndex);
  if (current is TextBlockNode && next is TextBlockNode) {
    final currentLength = inlineNodesLength(current.content);
    final mergedBlock = TextBlockNode(
      id: current.id,
      type: current.type,
      attributes: current.attributes,
      content: mergeTextRuns(<InlineNode>[
        ...current.content.map((node) => node.copy()),
        ...next.content.map((node) => node.copy()),
      ]),
    );
    _replaceBlocks(session, position.blockIndex, 2, <BlockNode>[mergedBlock]);
    final nextPosition = position.copyWith(offset: currentLength);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
  if (current is CodeBlockNode && next is CodeBlockNode) {
    final currentLength = current.code.length;
    final mergedBlock = CodeBlockNode(
      id: current.id,
      code: current.code + next.code,
      language: current.language,
      attributes: current.attributes,
    );
    _replaceBlocks(session, position.blockIndex, 2, <BlockNode>[mergedBlock]);
    final nextPosition = position.copyWith(offset: currentLength);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
  return const CommandResult(recordHistory: false);
}

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

void _replaceBlock(DocumentSession session, int index, BlockNode block) {
  final blocks = session.document.blocks.map((node) => node.copy()).toList();
  blocks[index] = block;
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );
}

/// Removes the object block at [index] (image/divider/video/file) and lands the
/// caret on a neighbouring editable block — the end of the previous text/code
/// block if one exists, otherwise the start of the first editable block in the
/// resulting document. The schema normalise pass (run by the executor after the
/// command) re-adds an empty paragraph when the removed block was the only one.
CommandResult _deleteObjectBlock(DocumentSession session, int index) {
  final blocks = session.document.blocks;
  if (index < 0 || index >= blocks.length) {
    return const CommandResult(recordHistory: false);
  }
  final removedBlockId = blocks[index].id;
  // Snapshot the previous editable block BEFORE removal so we can prefer it
  // (Backspace semantics: caret lands where the deleted block was, in the
  // preceding text).
  BlockNode? previousEditable;
  var previousIndex = -1;
  for (var i = index - 1; i >= 0; i--) {
    if (blocks[i] is TextBlockNode || blocks[i] is CodeBlockNode) {
      previousEditable = blocks[i];
      previousIndex = i;
      break;
    }
  }

  _replaceBlocks(session, index, 1, const <BlockNode>[]);
  if (session.document.blocks.isEmpty) {
    final paragraph = _emptyParagraphAfterDelete(removedBlockId);
    final position = DocumentPosition.text(
      blockId: paragraph.id,
      blockIndex: 0,
      offset: 0,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: <BlockNode>[paragraph],
    );
    return CommandResult(
      selection: DocumentSelection(base: position, extent: position),
    );
  }

  if (previousEditable != null) {
    // Index unchanged (the removed block was after it).
    return CommandResult(
      selection: _caretAtBlockEnd(previousEditable, previousIndex),
    );
  }
  // No previous editable block: land at the start of the first editable block
  // in the new document.
  final next = session.document.blocks;
  for (var i = 0; i < next.length; i++) {
    final block = next[i];
    if (block is TextBlockNode || block is CodeBlockNode) {
      return CommandResult(selection: _caretAtBlockStart(block, i));
    }
  }
  return const CommandResult();
}

DocumentSelection _caretAtBlockEnd(BlockNode block, int blockIndex) {
  if (block is TextBlockNode) {
    final end = inlineNodesLength(block.content);
    final pos = DocumentPosition.text(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: end,
    );
    return DocumentSelection(base: pos, extent: pos);
  }
  // CodeBlockNode.
  final end = (block as CodeBlockNode).code.length;
  final pos = DocumentPosition.code(
    blockId: block.id,
    blockIndex: blockIndex,
    offset: end,
  );
  return DocumentSelection(base: pos, extent: pos);
}

DocumentSelection _caretAtBlockStart(BlockNode block, int blockIndex) {
  if (block is CodeBlockNode) {
    final pos = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
    return DocumentSelection(base: pos, extent: pos);
  }
  final pos = DocumentPosition.text(
    blockId: (block as TextBlockNode).id,
    blockIndex: blockIndex,
    offset: 0,
  );
  return DocumentSelection(base: pos, extent: pos);
}

void _replaceBlocks(
  DocumentSession session,
  int index,
  int deleteCount,
  List<BlockNode> nextBlocks,
) {
  final blocks = <BlockNode>[
    for (var i = 0; i < index; i++) session.document.blocks[i].copy(),
    ...nextBlocks.map((block) => block.copy()),
    for (var i = index + deleteCount; i < session.document.blocks.length; i++)
      session.document.blocks[i].copy(),
  ];
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );
}
