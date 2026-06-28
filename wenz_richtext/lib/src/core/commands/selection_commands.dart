import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'block_commands.dart';
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
        CaretMovementDirection.backward => _lastNavigablePosition(
            session.document,
          ),
        CaretMovementDirection.forward => _firstNavigablePosition(
            session.document,
          ),
      };
      if (position == null) {
        return const CommandResult(recordHistory: false);
      }
      return CommandResult(
        selection: _selectionForNavigatedPosition(position),
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
      // Forward motion off a trailing object/table block: escape by appending a
      // paragraph (same escape hatch as the vertical command).
      if (direction == CaretMovementDirection.forward &&
          _isAtTrailingLeaf(session.document, selection.extent)) {
        final appended =
            _appendParagraphAfter(session, selection.extent.blockIndex);
        if (appended != null) {
          return CommandResult(selection: appended);
        }
      }
      return const CommandResult(recordHistory: false);
    }
    return CommandResult(
      selection: _selectionForNavigatedPosition(position),
      recordHistory: false,
    );
  }
}

/// Moves the caret across a block boundary vertically (Up/Down arrow).
///
/// This command handles ONLY cross-block transitions — it is the fallback the
/// widget layer invokes when visual-line motion within a block reaches the
/// block's first/last line. Semantics:
/// - **Down** from the last visual line of a block → start of the next editable
///   block.
/// - **Up** from the first visual line of a block → end of the previous editable
///   block.
/// - For a table cell on the table's last/first row, it exits the table to the
///   neighbouring block.
///
/// Intra-block visual-line motion (keeping the horizontal column across wrapped
/// lines) is resolved in the widget layer using [TextLayoutService]; this
/// command never moves within a block.
class MoveCaretVerticalCommand extends EditorCommand {
  const MoveCaretVerticalCommand(this.direction,
      {this.expandSelection = false});

  final CaretMovementDirection direction;
  final bool expandSelection;

  @override
  String get description => direction == CaretMovementDirection.forward
      ? 'moveCaretDown'
      : 'moveCaretUp';

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null) {
      return const CommandResult(recordHistory: false);
    }
    final extent = selection.extent;
    final DocumentPosition? next;
    if (extent.path.isTableCellText) {
      // Only cross out of the table when the cell is on the boundary row.
      if (!_atTableVerticalBoundary(session.document, extent, direction)) {
        return const CommandResult(recordHistory: false);
      }
      next = direction == CaretMovementDirection.forward
          ? _nextNavigablePosition(session.document, extent.blockIndex)
          : _previousNavigablePosition(session.document, extent.blockIndex);
    } else {
      // Plain text/code/callout blocks: the widget layer resolves visual-line motion
      // (keeping the horizontal column across wrapped lines) and only calls
      // this command once the caret reaches the block's first/last visual
      // line. We trust that signal and cross to the neighbouring editable
      // block unconditionally — the caret's *string* offset (e.g. mid-word on
      // the last wrapped line) must NOT gate a boundary transition, otherwise
      // a wrapped single-line block would be unreachable from above/below.
      next = direction == CaretMovementDirection.forward
          ? _nextNavigablePosition(session.document, extent.blockIndex)
          : _previousNavigablePosition(session.document, extent.blockIndex);
    }
    if (next == null || next == extent) {
      // Forward motion off a trailing object/table block would otherwise stall.
      // Escape it by appending a paragraph and landing the caret inside it
      // (mirrors the Tab-on-last-cell behaviour of MoveTableCellCommand).
      if (direction == CaretMovementDirection.forward &&
          _isAtTrailingLeaf(session.document, extent)) {
        final appended = _appendParagraphAfter(session, extent.blockIndex);
        if (appended != null) {
          if (expandSelection) {
            return CommandResult(
              selection: DocumentSelection(
                  base: selection.base, extent: appended.extent),
            );
          }
          return CommandResult(selection: appended);
        }
      }
      return const CommandResult(recordHistory: false);
    }
    if (expandSelection) {
      return CommandResult(
        selection: DocumentSelection(base: selection.base, extent: next),
        recordHistory: false,
      );
    }
    return CommandResult(
      selection: _selectionForNavigatedPosition(next),
      recordHistory: false,
    );
  }
}

/// Whether [position] (a table cell) sits on the table's first row (Up) or last
/// row (Down), i.e. vertical motion should leave the table for the neighbouring
/// block.
bool _atTableVerticalBoundary(
  RichTextDocument document,
  DocumentPosition position,
  CaretMovementDirection direction,
) {
  final block = _blockAt(document, position.blockIndex);
  final rowIndex = position.path.tableRowIndex;
  if (block is! TableBlockNode || rowIndex == null) {
    return false;
  }
  if (direction == CaretMovementDirection.forward) {
    return rowIndex >= block.table.rowCount - 1;
  }
  return rowIndex <= 0;
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

/// Vertical caret motion inside a table: ArrowUp/ArrowDown move to the same
/// column in the previous/next row. Unlike [MoveTableCellCommand] (Tab), this
/// never inserts rows — at the top/bottom row it is a no-op (caret stays).
/// Crossing covered (merged-away) cells skips to the visible anchor.
class MoveTableCellVerticalCommand extends EditorCommand {
  const MoveTableCellVerticalCommand(this.direction);

  final CaretMovementDirection direction;

  @override
  String get description => direction == CaretMovementDirection.forward
      ? 'moveTableCellDown'
      : 'moveTableCellUp';

  @override
  WenzEditorPermission get requiredPermission => WenzEditorPermission.read;

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    if (selection == null || !selection.extent.path.isTableCellText) {
      return const CommandResult(recordHistory: false);
    }
    final next = _verticalTableCellPosition(
      session.document,
      selection.extent,
      direction,
    );
    if (next == null || next == selection.extent) {
      return const CommandResult(recordHistory: false);
    }
    return CommandResult(
      selection: DocumentSelection(base: next, extent: next),
      recordHistory: false,
    );
  }
}

/// Moves the caret one word at a time (Ctrl/Cmd+Left/Right). A "word" boundary
/// is a transition between character classes — ASCII word chars (letter/digit/
/// underscore), CJK ideographs, and everything else (whitespace/punctuation).
/// CJK stops on every character, matching the platform word segmentation used
/// by double-click ([TextPainter.getWordBoundary]); ASCII runs move as one
/// word. This keeps keyboard and mouse word selection consistent for mixed
/// CJK/Latin text.
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
        CaretMovementDirection.backward =>
          _lastNavigablePosition(session.document),
        CaretMovementDirection.forward =>
          _firstNavigablePosition(session.document),
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
      // Forward motion off a trailing object/table block: escape by appending a
      // paragraph (same escape hatch as the other caret commands).
      if (direction == CaretMovementDirection.forward &&
          _isAtTrailingLeaf(session.document, selection.extent)) {
        final appended =
            _appendParagraphAfter(session, selection.extent.blockIndex);
        if (appended != null) {
          return CommandResult(
            selection: DocumentSelection(base: anchor, extent: appended.extent),
          );
        }
      }
      return const CommandResult(recordHistory: false);
    }
    if (!expandSelection && next.path.isBlockObject) {
      return CommandResult(
        selection: _selectionForNavigatedPosition(next),
        recordHistory: false,
      );
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
  WenzEditorPermission get requiredPermission => WenzEditorPermission.read;

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
    final tableCellLength =
        _tableCellLength(session.document, selection.extent);
    if (tableCellLength != null) {
      final targetOffset =
          direction == CaretMovementDirection.backward ? 0 : tableCellLength;
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
  WenzEditorPermission get requiredPermission => WenzEditorPermission.read;

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final selection = session.selection;
    final target = direction == CaretMovementDirection.backward
        ? _firstNavigablePosition(session.document)
        : _lastNavigablePosition(session.document);
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (selection == null) {
      return CommandResult(
        selection: _selectionForNavigatedPosition(target),
        recordHistory: false,
      );
    }
    final anchor =
        expandSelection ? selection.base : _collapseTo(selection, direction);
    if (!expandSelection) {
      return CommandResult(
        selection: _selectionForNavigatedPosition(target),
        recordHistory: false,
      );
    }
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
  WenzEditorPermission get requiredPermission => WenzEditorPermission.read;

  @override
  bool get breaksMergeRun => true;

  @override
  CommandResult execute(DocumentSession session) {
    final start = _firstSelectablePosition(session.document);
    final end = _lastSelectablePosition(session.document);
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

DocumentSelection _selectionForNavigatedPosition(DocumentPosition position) {
  if (position.path.isBlockObject) {
    return _objectSelectionForPosition(position);
  }
  return DocumentSelection(base: position, extent: position);
}

DocumentSelection _objectSelectionForPosition(DocumentPosition position) {
  final start = DocumentPosition.object(
    blockId: position.blockId,
    blockIndex: position.blockIndex,
    offset: 0,
  );
  return DocumentSelection(
    base: start,
    extent: start.copyWith(offset: _kObjectSelectionLength),
  );
}

DocumentPosition? _moveWordFrom(
  RichTextDocument document,
  DocumentPosition position,
  CaretMovementDirection direction,
) {
  final block = _blockAt(document, position.blockIndex);
  if (block == null || !_isEditable(block)) {
    return direction == CaretMovementDirection.backward
        ? _previousNavigablePosition(document, position.blockIndex)
        : _nextNavigablePosition(document, position.blockIndex);
  }
  final text = _editablePlainText(block);
  final length = text.length;
  var offset = position.offset.clamp(0, length).toInt();
  if (direction == CaretMovementDirection.forward) {
    // Move past the current run, then past any trailing separators. CJK chars
    // each form their own one-character run, so this stops on every CJK glyph.
    final startClass = offset < length
        ? _charClass(text.codeUnitAt(offset))
        : _CharClass.separator;
    while (offset < length &&
        _charClass(text.codeUnitAt(offset)) == startClass &&
        startClass != _CharClass.separator) {
      offset += 1;
    }
    while (offset < length &&
        _charClass(text.codeUnitAt(offset)) == _CharClass.separator) {
      offset += 1;
    }
  } else {
    // Move back over separators, then back over the preceding run.
    while (offset > 0 &&
        _charClass(text.codeUnitAt(offset - 1)) == _CharClass.separator) {
      offset -= 1;
    }
    if (offset > 0) {
      final runClass = _charClass(text.codeUnitAt(offset - 1));
      // CJK: stop after one character. ASCII word run: consume the whole run.
      while (
          offset > 0 && _charClass(text.codeUnitAt(offset - 1)) == runClass) {
        offset -= 1;
        if (runClass == _CharClass.cjk) {
          break;
        }
      }
    }
  }
  if (offset == position.offset.clamp(0, length).toInt()) {
    // Did not move within the block: jump to the neighbouring editable block.
    return direction == CaretMovementDirection.backward
        ? _previousNavigablePosition(document, position.blockIndex)
        : _nextNavigablePosition(document, position.blockIndex);
  }
  return position.copyWith(offset: offset);
}

/// Character classes used by word motion. CJK ideographs each form their own
/// word (matching platform segmentation), ASCII word chars move as a run, and
/// everything else is a separator.
enum _CharClass { word, cjk, separator }

_CharClass _charClass(int codeUnit) {
  // ASCII letter / digit / underscore.
  final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
  final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
  final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
  if (isLower || isUpper || isDigit || codeUnit == 0x5F) {
    return _CharClass.word;
  }
  // Common CJK Unified Ideographs (+ extensions A/B/C/D/E/F), Hiragana,
  // Katakana, Hangul, and CJK punctuation. Each CJK glyph is its own word.
  if (_isCjkCodeUnit(codeUnit)) {
    return _CharClass.cjk;
  }
  return _CharClass.separator;
}

bool _isCjkCodeUnit(int codeUnit) {
  // CJK Unified Ideographs and adjacent blocks. Code units here are UTF-16;
  // surrogate pairs (supplementary planes) are rare in everyday CJK text and
  // are left to fall through as separators — matching TextPainter behaviour
  // closely enough for word motion.
  return (codeUnit >= 0x3400 && codeUnit <= 0x9FFF) || // CJK + Ext A
      (codeUnit >= 0xA000 && codeUnit <= 0xD7AF) || // Hangul Syllables
      (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) || // CJK Compat Ideographs
      (codeUnit >= 0xFF00 && codeUnit <= 0xFFEF) || // Halfwidth/Fullwidth
      (codeUnit >= 0x3040 && codeUnit <= 0x30FF) || // Hiragana + Katakana
      (codeUnit >= 0xAC00 && codeUnit <= 0xD7A3); // Hangul Syllables
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
        _previousNavigablePosition(document, position.blockIndex);
  }

  final block = _blockAt(document, position.blockIndex);
  if (block != null && _isKeyboardSelectableObject(block)) {
    return _previousNavigablePosition(document, position.blockIndex);
  }
  if (block == null || !_isEditable(block)) {
    return _previousNavigablePosition(document, position.blockIndex);
  }
  final offset = position.offset.clamp(0, _editableLength(block));
  if (offset > 0) {
    return position.copyWith(offset: offset - 1);
  }
  return _previousNavigablePosition(document, position.blockIndex);
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
        _nextNavigablePosition(document, position.blockIndex);
  }

  final block = _blockAt(document, position.blockIndex);
  if (block != null && _isKeyboardSelectableObject(block)) {
    return _nextNavigablePosition(document, position.blockIndex);
  }
  if (block == null || !_isEditable(block)) {
    return _nextNavigablePosition(document, position.blockIndex);
  }
  final length = _editableLength(block);
  final offset = position.offset.clamp(0, length);
  if (offset < length) {
    return position.copyWith(offset: offset + 1);
  }
  return _nextNavigablePosition(document, position.blockIndex);
}

DocumentPosition? _firstNavigablePosition(RichTextDocument document) {
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
    if (_isKeyboardSelectableObject(block)) {
      return _objectPositionFor(block, i, 0);
    }
  }
  return null;
}

DocumentPosition? _firstSelectablePosition(RichTextDocument document) {
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
    if (_isSelectableObject(block)) {
      return _objectPositionFor(block, i, 0);
    }
  }
  return null;
}

DocumentPosition? _lastNavigablePosition(RichTextDocument document) {
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
    if (_isKeyboardSelectableObject(block)) {
      return _objectPositionFor(block, i, _kObjectSelectionLength);
    }
  }
  return null;
}

DocumentPosition? _lastSelectablePosition(RichTextDocument document) {
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
    if (_isSelectableObject(block)) {
      return _objectPositionFor(block, i, _kObjectSelectionLength);
    }
  }
  return null;
}

DocumentPosition? _previousNavigablePosition(
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
    if (_isKeyboardSelectableObject(block)) {
      return _objectPositionFor(block, i, 0);
    }
  }
  return null;
}

DocumentPosition? _nextNavigablePosition(
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
    if (_isKeyboardSelectableObject(block)) {
      return _objectPositionFor(block, i, _kObjectSelectionLength);
    }
  }
  return null;
}

DocumentPosition? _firstTableCellPosition(
    TableBlockNode block, int blockIndex) {
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

/// Vertical (ArrowUp/ArrowDown) motion within a table. Moves to the same
/// column one row up/down, preserving the caret offset clamped to the target
/// cell's length. When the target cell is `covered` (hidden behind a merged
/// anchor), walks further until a visible cell is found; if none exists before
/// the table edge, returns `null` (caret stays put).
DocumentPosition? _verticalTableCellPosition(
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
  final step = direction == CaretMovementDirection.forward ? 1 : -1;
  var nextRow = rowIndex + step;
  while (nextRow >= 0 && nextRow < block.table.rowCount) {
    final cell = block.table.cellAt(nextRow, columnIndex);
    if (cell != null && !cell.covered) {
      final length = _tableCellLengthAt(block, nextRow, columnIndex);
      final offset = position.offset.clamp(0, length).toInt();
      return DocumentPosition.tableCell(
        tableBlockId: block.id,
        blockIndex: position.blockIndex,
        tableRowIndex: nextRow,
        tableColumnIndex: columnIndex,
        offset: offset,
      );
    }
    nextRow += step;
  }
  return null;
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
  final result =
      insertTableRowAt(session, position.blockIndex, block.table.rowCount);
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

DocumentPosition _objectPositionFor(
  BlockNode block,
  int blockIndex,
  int offset,
) {
  return DocumentPosition.object(
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
  return block is TextBlockNode ||
      block is CodeBlockNode ||
      block is CalloutBlockNode;
}

bool _isSelectableObject(BlockNode block) {
  return !_isEditable(block) && block is! TableBlockNode;
}

bool _isKeyboardSelectableObject(BlockNode block) {
  return block is ImageBlockNode ||
      block is VideoBlockNode ||
      block is BlockEmbedNode ||
      block is FileBlockNode;
}

const int _kObjectSelectionLength = 1;

/// Whether [position] sits on a non-editable leaf that is the document's last
/// block, so forward caret motion should escape it by appending a paragraph.
///
/// Two cases:
/// - An object block (image/divider/video/file) that is the final block. The
///   caret cannot live "inside" it, so Down/Right off it would otherwise stall.
/// - A table cell on the table's last row *and* last column when the table is
///   the final block.
///
/// Editable blocks (paragraph/code/callout) are excluded on purpose: Enter or
/// typing already adds content there, and we must not auto-append a paragraph
/// just because the user arrowed off the end of a normal text block.
bool _isAtTrailingLeaf(RichTextDocument document, DocumentPosition position) {
  final block = _blockAt(document, position.blockIndex);
  if (block == null) {
    return false;
  }
  final isLastBlock = position.blockIndex == document.blocks.length - 1;
  if (position.path.isBlockObject) {
    return isLastBlock;
  }
  if (position.path.isTableCellText && block is TableBlockNode) {
    final rowIndex = position.path.tableRowIndex;
    final columnIndex = position.path.tableColumnIndex;
    if (rowIndex == null || columnIndex == null) {
      return false;
    }
    return isLastBlock &&
        rowIndex == block.table.rowCount - 1 &&
        columnIndex == block.table.columnCount - 1;
  }
  return false;
}

/// Appends an empty paragraph after [afterBlockIndex] and returns a collapsed
/// selection inside it. Used as the escape hatch when forward caret motion runs
/// off the end of a trailing object/table block (mirrors the
/// `_insertRowAfterLastCell` pattern for Tab on the last table cell). Returns
/// `null` when there is no block to append after.
DocumentSelection? _appendParagraphAfter(
  DocumentSession session,
  int afterBlockIndex,
) {
  if (afterBlockIndex < 0 ||
      afterBlockIndex >= session.document.blocks.length) {
    return null;
  }
  final afterBlock = session.document.blocks[afterBlockIndex];
  final nextBlockId = '${afterBlock.id}-next';
  final nextBlockIndex = afterBlockIndex + 1;
  final nextPosition = DocumentPosition.text(
    blockId: nextBlockId,
    blockIndex: nextBlockIndex,
    offset: 0,
  );
  InsertBlocksCommand(
    index: nextBlockIndex,
    blocks: <BlockNode>[
      TextBlockNode(
        id: nextBlockId,
        type: BlockType.paragraph,
        content: const <InlineNode>[],
      ),
    ],
    selection: DocumentSelection(base: nextPosition, extent: nextPosition),
  ).execute(session);
  // InsertBlocksCommand does not set session.selection itself (only the
  // executor does), so set it here so the caller's returned selection is real.
  session.selection =
      DocumentSelection(base: nextPosition, extent: nextPosition);
  return session.selection;
}

int _editableLength(BlockNode block) {
  if (block is TextBlockNode) {
    return inlineNodesLength(block.content);
  }
  if (block is CalloutBlockNode) {
    return inlineNodesLength(block.content);
  }
  if (block is CodeBlockNode) {
    return block.code.length;
  }
  return 0;
}

String _editablePlainText(BlockNode block) {
  if (block is TextBlockNode) {
    return block.plainText;
  }
  if (block is CalloutBlockNode) {
    return block.content.map((node) => node.plainText).join();
  }
  return block.plainText;
}
