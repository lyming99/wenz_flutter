import '../model/block_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'table_commands.dart';
import 'inline_editing.dart';
import 'table_cell_editing.dart';

enum CaretMovementDirection { backward, forward }

class MoveCaretCommand extends EditorCommand {
  const MoveCaretCommand(this.direction, {this.expandSelection = false});

  final CaretMovementDirection direction;
  final bool expandSelection;

  @override
  String get description {
    if (expandSelection) {
      return switch (direction) {
        CaretMovementDirection.backward => 'extendSelectionBackward',
        CaretMovementDirection.forward => 'extendSelectionForward',
      };
    }
    return switch (direction) {
      CaretMovementDirection.backward => 'moveCaretBackward',
      CaretMovementDirection.forward => 'moveCaretForward',
    };
  }

  /// Caret movement never records history, but it must still break an active
  /// coalesce run so typing after moving the caret starts a fresh undo step.
  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      final position = switch (direction) {
        CaretMovementDirection.backward => _lastEditablePosition(
            session.document,
          ),
        CaretMovementDirection.forward => _firstEditablePosition(
            session.document,
          ),
      };
      if (position == null) {
        return const CommandResult(recordHistory: false);
      }
      return CommandResult(
        selection: DocumentSelection(base: position, extent: position),
        recordHistory: false,
      );
    }

    if (expandSelection) {
      final nextExtent = _moveFrom(
        session.document,
        selection.extent,
        direction,
      );
      if (nextExtent == null || nextExtent == selection.extent) {
        return const CommandResult(recordHistory: false);
      }
      return CommandResult(
        selection: DocumentSelection(base: selection.base, extent: nextExtent),
        recordHistory: false,
      );
    }

    if (!selection.isCollapsed) {
      final position = switch (direction) {
        CaretMovementDirection.backward => selection.start,
        CaretMovementDirection.forward => selection.end,
      };
      return CommandResult(
        selection: DocumentSelection(base: position, extent: position),
        recordHistory: false,
      );
    }

    final position = _moveFrom(session.document, selection.extent, direction);
    if (position == null || position == selection.extent) {
      return const CommandResult(recordHistory: false);
    }
    return CommandResult(
      selection: DocumentSelection(base: position, extent: position),
      recordHistory: false,
    );
  }
}

class MoveTableCellCommand extends EditorCommand {
  const MoveTableCellCommand(this.direction);

  final CaretMovementDirection direction;

  @override
  String get description => direction == CaretMovementDirection.forward
      ? 'moveTableCellForward'
      : 'moveTableCellBackward';

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null || !selection.extent.path.isTableCellText) {
      return const CommandResult(recordHistory: false);
    }
    final next = _adjacentTableCellPosition(
      session.document,
      selection.extent,
      direction,
    );
    if (next == null || next == selection.extent) {
      if (direction != CaretMovementDirection.forward) {
        return const CommandResult(recordHistory: false);
      }
      final inserted = _insertRowAfterLastCell(session, selection.extent);
      if (inserted == null) {
        return const CommandResult(recordHistory: false);
      }
      return CommandResult(selection: inserted);
    }
    return CommandResult(
      selection: DocumentSelection(base: next, extent: next),
      recordHistory: false,
    );
  }
}

/// Moves the caret one word at a time (Ctrl/Cmd+Left/Right). A "word" boundary
/// is a transition between whitespace/punctuation and word characters, using a
/// simple C0/ASCII rule. Good enough for stage 1; Unicode segmentation can
/// refine this later.
class MoveCaretByWordCommand extends EditorCommand {
  const MoveCaretByWordCommand(this.direction, {this.expandSelection = false});

  final CaretMovementDirection direction;
  final bool expandSelection;

  @override
  String get description => expandSelection
      ? (direction == CaretMovementDirection.backward
          ? 'extendSelectionByWordBackward'
          : 'extendSelectionByWordForward')
      : 'moveCaretByWord';

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      final position = switch (direction) {
        CaretMovementDirection.backward => _lastEditablePosition(session.document),
        CaretMovementDirection.forward => _firstEditablePosition(session.document),
      };
      if (position == null) {
        return const CommandResult(recordHistory: false);
      }
      return CommandResult(
        selection: DocumentSelection(base: position, extent: position),
        recordHistory: false,
      );
    }

    final anchor =
        expandSelection ? selection.base : _collapseTo(selection, direction);
    final next = _moveWordFrom(session.document, selection.extent, direction);
    if (next == null || next == selection.extent) {
      return const CommandResult(recordHistory: false);
    }
    return CommandResult(
      selection: DocumentSelection(base: anchor, extent: next),
      recordHistory: false,
    );
  }
}

/// Moves the caret to the start (Home) or end (End) of the current editable
/// block.
class MoveCaretToBlockBoundaryCommand extends EditorCommand {
  const MoveCaretToBlockBoundaryCommand(this.direction,
      {this.expandSelection = false});

  final CaretMovementDirection direction;
  final bool expandSelection;

  @override
  String get description => expandSelection
      ? (direction == CaretMovementDirection.backward
          ? 'extendSelectionToBlockStart'
          : 'extendSelectionToBlockEnd')
      : (direction == CaretMovementDirection.backward
          ? 'moveCaretToBlockStart'
          : 'moveCaretToBlockEnd');

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      return const CommandResult(recordHistory: false);
    }
    final anchor =
        expandSelection ? selection.base : _collapseTo(selection, direction);
    final tableCellLength = _tableCellLength(session.document, selection.extent);
    if (tableCellLength != null) {
      final targetOffset = direction == CaretMovementDirection.backward
          ? 0
          : tableCellLength;
      final next = selection.extent.copyWith(offset: targetOffset);
      return CommandResult(
        selection: DocumentSelection(base: anchor, extent: next),
        recordHistory: false,
      );
    }
    final block = _blockAt(session.document, selection.extent.blockIndex);
    if (block == null || !_isEditable(block)) {
      return const CommandResult(recordHistory: false);
    }
    final targetOffset = direction == CaretMovementDirection.backward
        ? 0
        : _editableLength(block);
    final next = selection.extent.copyWith(offset: targetOffset);
    return CommandResult(
      selection: DocumentSelection(base: anchor, extent: next),
      recordHistory: false,
    );
  }
}

/// Moves the caret to the first (Ctrl+Home) or last (Ctrl+End) editable
/// position in the document.
class MoveCaretToDocumentBoundaryCommand extends EditorCommand {
  const MoveCaretToDocumentBoundaryCommand(this.direction,
      {this.expandSelection = false});

  final CaretMovementDirection direction;
  final bool expandSelection;

  @override
  String get description => expandSelection
      ? (direction == CaretMovementDirection.backward
          ? 'extendSelectionToDocumentStart'
          : 'extendSelectionToDocumentEnd')
      : (direction == CaretMovementDirection.backward
          ? 'moveCaretToDocumentStart'
          : 'moveCaretToDocumentEnd');

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    final target = direction == CaretMovementDirection.backward
        ? _firstEditablePosition(session.document)
        : _lastEditablePosition(session.document);
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (selection == null) {
      return CommandResult(
        selection: DocumentSelection(base: target, extent: target),
        recordHistory: false,
      );
    }
    final anchor =
        expandSelection ? selection.base : _collapseTo(selection, direction);
    return CommandResult(
      selection: DocumentSelection(base: anchor, extent: target),
      recordHistory: false,
    );
  }
}

/// Selects the whole editable range of the document (Ctrl/Cmd+A).
class SelectAllCommand extends EditorCommand {
  const SelectAllCommand();

  @override
  String get description => 'selectAll';

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final start = _firstEditablePosition(session.document);
    final end = _lastEditablePosition(session.document);
    if (start == null || end == null || start == end) {
      return const CommandResult(recordHistory: false);
    }
    return CommandResult(
      selection: DocumentSelection(base: start, extent: end),
      recordHistory: false,
    );
  }
}

DocumentPosition _collapseTo(
  DocumentSelection selection,
  CaretMovementDirection direction,
) {
  return direction == CaretMovementDirection.backward
      ? selection.start
      : selection.end;
}

DocumentPosition? _moveWordFrom(
  RichTextDocument document,
  DocumentPosition position,
  CaretMovementDirection direction,
) {
  final block = _blockAt(document, position.blockIndex);
  if (block == null || !_isEditable(block)) {
    return direction == CaretMovementDirection.backward
        ? _previousEditablePosition(document, position.blockIndex)
        : _nextEditablePosition(document, position.blockIndex);
  }
  final text = block.plainText;
  final length = text.length;
  var offset = position.offset.clamp(0, length).toInt();
  if (direction == CaretMovementDirection.forward) {
    // Skip the current word run, then skip following whitespace.
    while (offset < length && _isWordChar(text.codeUnitAt(offset))) {
      offset += 1;
    }
    while (offset < length && !_isWordChar(text.codeUnitAt(offset))) {
      offset += 1;
    }
  } else {
    // Move back over whitespace, then back over the preceding word run.
    while (offset > 0 && !_isWordChar(text.codeUnitAt(offset - 1))) {
      offset -= 1;
    }
    while (offset > 0 && _isWordChar(text.codeUnitAt(offset - 1))) {
      offset -= 1;
    }
  }
  if (offset == position.offset.clamp(0, length).toInt()) {
    // Did not move within the block: jump to the neighbouring editable block.
    return direction == CaretMovementDirection.backward
        ? _previousEditablePosition(document, position.blockIndex)
        : _nextEditablePosition(document, position.blockIndex);
  }
  return position.copyWith(offset: offset);
}

bool _isWordChar(int codeUnit) {
  // ASCII letter / digit / underscore. Treat everything else (whitespace,
  // punctuation, and non-ASCII which IME commonly emits as its own tokens) as
  // a separator. This keeps word motion predictable; Unicode word segmentation
  // can refine it later.
  final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
  final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
  final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
  return isLower || isUpper || isDigit || codeUnit == 0x5F;
}

DocumentPosition? _moveFrom(
  RichTextDocument document,
  DocumentPosition position,
  CaretMovementDirection direction,
) {
  return switch (direction) {
    CaretMovementDirection.backward => _moveBackward(document, position),
    CaretMovementDirection.forward => _moveForward(document, position),
  };
}

DocumentPosition? _moveBackward(
  RichTextDocument document,
  DocumentPosition position,
) {
  final tableCellLength = _tableCellLength(document, position);
  if (tableCellLength != null) {
    final offset = position.offset.clamp(0, tableCellLength).toInt();
    if (offset > 0) {
      return position.copyWith(offset: offset - 1);
    }
    return _adjacentTableCellPosition(
          document,
          position,
          CaretMovementDirection.backward,
        ) ??
        _previousEditablePosition(document, position.blockIndex);
  }

  final block = _blockAt(document, position.blockIndex);
  if (block == null || !_isEditable(block)) {
    return _previousEditablePosition(document, position.blockIndex);
  }
  final offset = position.offset.clamp(0, _editableLength(block));
  if (offset > 0) {
    return position.copyWith(offset: offset - 1);
  }
  return _previousEditablePosition(document, position.blockIndex);
}

DocumentPosition? _moveForward(
  RichTextDocument document,
  DocumentPosition position,
) {
  final tableCellLength = _tableCellLength(document, position);
  if (tableCellLength != null) {
    final offset = position.offset.clamp(0, tableCellLength).toInt();
    if (offset < tableCellLength) {
      return position.copyWith(offset: offset + 1);
    }
    return _adjacentTableCellPosition(
          document,
          position,
          CaretMovementDirection.forward,
        ) ??
        _nextEditablePosition(document, position.blockIndex);
  }

  final block = _blockAt(document, position.blockIndex);
  if (block == null || !_isEditable(block)) {
    return _nextEditablePosition(document, position.blockIndex);
  }
  final length = _editableLength(block);
  final offset = position.offset.clamp(0, length);
  if (offset < length) {
    return position.copyWith(offset: offset + 1);
  }
  return _nextEditablePosition(document, position.blockIndex);
}

DocumentPosition? _firstEditablePosition(RichTextDocument document) {
  for (var i = 0; i < document.blocks.length; i++) {
    final block = document.blocks[i];
    if (_isEditable(block)) {
      return _positionFor(block, i, 0);
    }
    if (block is TableBlockNode) {
      final firstCell = _firstTableCellPosition(block, i);
      if (firstCell != null) {
        return firstCell;
      }
    }
  }
  return null;
}

DocumentPosition? _lastEditablePosition(RichTextDocument document) {
  for (var i = document.blocks.length - 1; i >= 0; i--) {
    final block = document.blocks[i];
    if (_isEditable(block)) {
      return _positionFor(block, i, _editableLength(block));
    }
    if (block is TableBlockNode) {
      final lastCell = _lastTableCellPosition(block, i);
      if (lastCell != null) {
        return lastCell;
      }
    }
  }
  return null;
}

DocumentPosition? _previousEditablePosition(
  RichTextDocument document,
  int fromIndex,
) {
  for (var i = fromIndex - 1; i >= 0; i--) {
    final block = document.blocks[i];
    if (_isEditable(block)) {
      return _positionFor(block, i, _editableLength(block));
    }
    if (block is TableBlockNode) {
      final position = _lastTableCellPosition(block, i);
      if (position != null) {
        return position;
      }
    }
  }
  return null;
}

DocumentPosition? _nextEditablePosition(
  RichTextDocument document,
  int fromIndex,
) {
  for (var i = fromIndex + 1; i < document.blocks.length; i++) {
    final block = document.blocks[i];
    if (_isEditable(block)) {
      return _positionFor(block, i, 0);
    }
    if (block is TableBlockNode) {
      final position = _firstTableCellPosition(block, i);
      if (position != null) {
        return position;
      }
    }
  }
  return null;
}

DocumentPosition? _firstTableCellPosition(TableBlockNode block, int blockIndex) {
  if (block.table.rowCount == 0 || block.table.columnCount == 0) {
    return null;
  }
  return DocumentPosition.tableCell(
    tableBlockId: block.id,
    blockIndex: blockIndex,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: 0,
  );
}

DocumentPosition? _lastTableCellPosition(TableBlockNode block, int blockIndex) {
  if (block.table.rowCount == 0 || block.table.columnCount == 0) {
    return null;
  }
  final rowIndex = block.table.rowCount - 1;
  final columnIndex = block.table.columnCount - 1;
  final length = _tableCellLengthAt(block, rowIndex, columnIndex);
  return DocumentPosition.tableCell(
    tableBlockId: block.id,
    blockIndex: blockIndex,
    tableRowIndex: rowIndex,
    tableColumnIndex: columnIndex,
    offset: length,
  );
}

DocumentPosition? _adjacentTableCellPosition(
  RichTextDocument document,
  DocumentPosition position,
  CaretMovementDirection direction,
) {
  final block = _blockAt(document, position.blockIndex);
  final rowIndex = position.path.tableRowIndex;
  final columnIndex = position.path.tableColumnIndex;
  if (block is! TableBlockNode || rowIndex == null || columnIndex == null) {
    return null;
  }
  var nextRow = rowIndex;
  var nextColumn = columnIndex;
  if (direction == CaretMovementDirection.forward) {
    nextColumn += 1;
    if (nextColumn >= block.table.columnCount) {
      nextColumn = 0;
      nextRow += 1;
    }
    if (nextRow >= block.table.rowCount) {
      return null;
    }
    return DocumentPosition.tableCell(
      tableBlockId: block.id,
      blockIndex: position.blockIndex,
      tableRowIndex: nextRow,
      tableColumnIndex: nextColumn,
      offset: 0,
    );
  }

  nextColumn -= 1;
  if (nextColumn < 0) {
    nextRow -= 1;
    if (nextRow < 0) {
      return null;
    }
    nextColumn = block.table.columnCount - 1;
  }
  final length = _tableCellLengthAt(block, nextRow, nextColumn);
  return DocumentPosition.tableCell(
    tableBlockId: block.id,
    blockIndex: position.blockIndex,
    tableRowIndex: nextRow,
    tableColumnIndex: nextColumn,
    offset: length,
  );
}

DocumentSelection? _insertRowAfterLastCell(
  DocumentSession session,
  DocumentPosition position,
) {
  final block = _blockAt(session.document, position.blockIndex);
  final rowIndex = position.path.tableRowIndex;
  final columnIndex = position.path.tableColumnIndex;
  if (block is! TableBlockNode || rowIndex == null || columnIndex == null) {
    return null;
  }
  final isLastRow = rowIndex == block.table.rowCount - 1;
  final isLastColumn = columnIndex == block.table.columnCount - 1;
  if (!isLastRow || !isLastColumn) {
    return null;
  }
  final result = insertTableRowAt(session, position.blockIndex, block.table.rowCount);
  if (!result.recordHistory) {
    return null;
  }
  final next = DocumentPosition.tableCell(
    tableBlockId: block.id,
    blockIndex: position.blockIndex,
    tableRowIndex: block.table.rowCount,
    tableColumnIndex: 0,
    offset: 0,
  );
  return DocumentSelection(base: next, extent: next);
}

int? _tableCellLength(RichTextDocument document, DocumentPosition position) {
  final block = _blockAt(document, position.blockIndex);
  final rowIndex = position.path.tableRowIndex;
  final columnIndex = position.path.tableColumnIndex;
  if (block is! TableBlockNode || rowIndex == null || columnIndex == null) {
    return null;
  }
  return _tableCellLengthAt(block, rowIndex, columnIndex);
}

int _tableCellLengthAt(
  TableBlockNode block,
  int rowIndex,
  int columnIndex,
) {
  final cell = block.table.cellAt(rowIndex, columnIndex);
  if (cell == null) {
    return 0;
  }
  return inlineNodesLength(cellTextBlock(cell).content);
}

DocumentPosition _positionFor(BlockNode block, int blockIndex, int offset) {
  if (block is CodeBlockNode) {
    return DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: offset,
    );
  }
  return DocumentPosition.text(
    blockId: block.id,
    blockIndex: blockIndex,
    offset: offset,
  );
}

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

bool _isEditable(BlockNode block) {
  return block is TextBlockNode || block is CodeBlockNode;
}

int _editableLength(BlockNode block) {
  if (block is TextBlockNode) {
    return inlineNodesLength(block.content);
  }
  if (block is CodeBlockNode) {
    return block.code.length;
  }
  return 0;
}
