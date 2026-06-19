import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
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
      return _deleteAcrossTextBlocks(session, start, end);
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
  bool canMergeWith(EditorCommand previous) =>
      previous is DeleteForwardCommand;

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

CommandResult _deleteAcrossTextBlocks(
  DocumentSession session,
  DocumentPosition start,
  DocumentPosition end,
) {
  final startBlock = _blockAt(session.document, start.blockIndex);
  final endBlock = _blockAt(session.document, end.blockIndex);
  if (startBlock is! TextBlockNode || endBlock is! TextBlockNode) {
    return const CommandResult(recordHistory: false);
  }

  final startSplit = splitInline(startBlock.content, start.offset);
  final endSplit = splitInline(endBlock.content, end.offset);
  final mergedStartBlock = TextBlockNode(
    id: startBlock.id,
    type: startBlock.type,
    attributes: startBlock.attributes,
    content: mergeTextRuns(<InlineNode>[
      ...startSplit.before,
      ...endSplit.after,
    ]),
  );
  final blocks = <BlockNode>[
    for (var i = 0; i < start.blockIndex; i++)
      session.document.blocks[i].copy(),
    mergedStartBlock,
    for (var i = end.blockIndex + 1; i < session.document.blocks.length; i++)
      session.document.blocks[i].copy(),
  ];
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );

  return CommandResult(
    selection: DocumentSelection(base: start, extent: start),
  );
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
