import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/table_model.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'block_commands.dart';
import 'editor_command.dart';
import 'table_cell_editing.dart';

typedef TableCellIdBuilder = String Function(
    String tableId, int rowIndex, int columnIndex);

class InsertTableCommand extends EditorCommand {
  const InsertTableCommand({
    required this.index,
    required this.tableId,
    required this.rowCount,
    required this.columnCount,
    this.selection,
    this.cellIdBuilder,
  });

  final int index;
  final String tableId;
  final int rowCount;
  final int columnCount;
  final DocumentSelection? selection;
  final TableCellIdBuilder? cellIdBuilder;

  @override
  String get description => 'insertTable';

  @override
  CommandResult execute(DocumentSession session) {
    if (rowCount <= 0 || columnCount <= 0) {
      return const CommandResult(recordHistory: false);
    }
    return InsertBlocksCommand(
      index: index,
      blocks: <BlockNode>[
        TableBlockNode(
          id: tableId,
          table: _createTable(tableId, rowCount, columnCount, cellIdBuilder),
        ),
      ],
      selection: selection,
    ).execute(session);
  }
}

class InsertTableRowCommand extends EditorCommand {
  const InsertTableRowCommand({
    required this.blockIndex,
    required this.rowIndex,
    this.cellIdBuilder,
  });

  final int blockIndex;
  final int rowIndex;
  final TableCellIdBuilder? cellIdBuilder;

  @override
  String get description => 'insertTableRow';

  @override
  CommandResult execute(DocumentSession session) {
    return insertTableRowAt(
      session,
      blockIndex,
      rowIndex,
      cellIdBuilder: cellIdBuilder,
    );
  }
}

class InsertTableColumnCommand extends EditorCommand {
  const InsertTableColumnCommand({
    required this.blockIndex,
    required this.columnIndex,
    this.cellIdBuilder,
  });

  final int blockIndex;
  final int columnIndex;
  final TableCellIdBuilder? cellIdBuilder;

  @override
  String get description => 'insertTableColumn';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null) {
      return const CommandResult(recordHistory: false);
    }
    final insertIndex =
        columnIndex.clamp(0, tableBlock.table.columnCount).toInt();
    final rows = <List<TableCellNode>>[
      for (var rowIndex = 0; rowIndex < tableBlock.table.rowCount; rowIndex++)
        <TableCellNode>[
          for (var col = 0; col < insertIndex; col++)
            copyCell(tableBlock.table.rows[rowIndex][col]),
          _emptyCell(
            _cellId(tableBlock.id, rowIndex, insertIndex, cellIdBuilder),
          ),
          for (var col = insertIndex;
              col < tableBlock.table.rows[rowIndex].length;
              col++)
            copyCell(tableBlock.table.rows[rowIndex][col]),
        ],
    ];
    // Reindex alignments so columns that were at/after the insertion point
    // keep their alignment on the shifted column index. Mirrors the reverse
    // shift done by DeleteTableColumnCommand.
    final alignments = shiftColumnMapOnInsert(
      tableBlock.table.columnAlignments,
      insertIndex,
    );
    final widths = shiftColumnMapOnInsert(
      tableBlock.table.columnWidths,
      insertIndex,
    );
    return _replaceTableWithSelection(
      session,
      blockIndex,
      tableBlock,
      rows,
      selection: _tableSelectionAfterColumnInserted(
        session.selection,
        tableBlock,
        blockIndex,
        rows,
        insertIndex,
      ),
      columnAlignments: alignments,
      columnWidths: widths,
    );
  }
}

class DeleteTableRowCommand extends EditorCommand {
  const DeleteTableRowCommand({
    required this.blockIndex,
    required this.rowIndex,
  });

  final int blockIndex;
  final int rowIndex;

  @override
  String get description => 'deleteTableRow';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null ||
        tableBlock.table.rowCount <= 1 ||
        rowIndex < 0 ||
        rowIndex >= tableBlock.table.rowCount) {
      return const CommandResult(recordHistory: false);
    }
    final rows = <List<TableCellNode>>[
      for (var i = 0; i < tableBlock.table.rowCount; i++)
        if (i != rowIndex) copyRow(tableBlock.table.rows[i]),
    ];
    return _replaceTableWithSelection(
      session,
      blockIndex,
      tableBlock,
      rows,
      selection: _tableSelectionAfterRowDeleted(
        session.selection,
        tableBlock,
        blockIndex,
        rows,
        rowIndex,
      ),
    );
  }
}

class DeleteTableColumnCommand extends EditorCommand {
  const DeleteTableColumnCommand({
    required this.blockIndex,
    required this.columnIndex,
  });

  final int blockIndex;
  final int columnIndex;

  @override
  String get description => 'deleteTableColumn';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null ||
        tableBlock.table.columnCount <= 1 ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount) {
      return const CommandResult(recordHistory: false);
    }
    final rows = <List<TableCellNode>>[
      for (final row in tableBlock.table.rows)
        <TableCellNode>[
          for (var i = 0; i < row.length; i++)
            if (i != columnIndex) copyCell(row[i]),
        ],
    ];
    final alignments = shiftColumnMapOnDelete(
      tableBlock.table.columnAlignments,
      columnIndex,
    );
    final widths = shiftColumnMapOnDelete(
      tableBlock.table.columnWidths,
      columnIndex,
    );
    return _replaceTableWithSelection(
      session,
      blockIndex,
      tableBlock,
      rows,
      selection: _tableSelectionAfterColumnDeleted(
        session.selection,
        tableBlock,
        blockIndex,
        rows,
        columnIndex,
      ),
      columnAlignments: alignments,
      columnWidths: widths,
    );
  }
}

class SetTableColumnAlignmentCommand extends EditorCommand {
  const SetTableColumnAlignmentCommand({
    required this.blockIndex,
    required this.columnIndex,
    required this.alignment,
  });

  final int blockIndex;
  final int columnIndex;
  final String? alignment;

  @override
  String get description => 'setTableColumnAlignment';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount) {
      return const CommandResult(recordHistory: false);
    }
    final alignments = Map<int, String>.from(tableBlock.table.columnAlignments);
    if (alignment == null) {
      alignments.remove(columnIndex);
    } else {
      alignments[columnIndex] = alignment!;
    }
    return replaceTable(
      session,
      blockIndex,
      tableBlock,
      tableBlock.table.rows.map(copyRow).toList(),
      columnAlignments: alignments,
    );
  }
}

class SetTableColumnWidthCommand extends EditorCommand {
  const SetTableColumnWidthCommand({
    required this.blockIndex,
    required this.columnIndex,
    required this.width,
  });

  final int blockIndex;
  final int columnIndex;
  final double? width;

  @override
  String get description => 'setTableColumnWidth';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount) {
      return const CommandResult(recordHistory: false);
    }
    final widths = Map<int, double>.from(tableBlock.table.columnWidths);
    if (width == null || width! <= 0) {
      widths.remove(columnIndex);
    } else {
      widths[columnIndex] = width!;
    }
    return replaceTable(
      session,
      blockIndex,
      tableBlock,
      tableBlock.table.rows.map(copyRow).toList(),
      columnWidths: widths,
    );
  }
}

class SetTableCellHeaderCommand extends EditorCommand {
  const SetTableCellHeaderCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.isHeader,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final bool isHeader;

  @override
  String get description => 'setTableCellHeader';

  @override
  CommandResult execute(DocumentSession session) {
    return updateTableCell(
      session,
      blockIndex,
      rowIndex,
      columnIndex,
      (cell) => TableCellNode(
        id: cell.id,
        blocks: cell.blocks.map((block) => block.copy()).toList(),
        rowSpan: cell.rowSpan,
        columnSpan: cell.columnSpan,
        isHeader: isHeader,
        backgroundColor: cell.backgroundColor,
        covered: cell.covered,
      ),
    );
  }
}

class SetTableCellBackgroundCommand extends EditorCommand {
  const SetTableCellBackgroundCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.backgroundColor,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final int? backgroundColor;

  @override
  String get description => 'setTableCellBackground';

  @override
  CommandResult execute(DocumentSession session) {
    return updateTableCell(
      session,
      blockIndex,
      rowIndex,
      columnIndex,
      (cell) => TableCellNode(
        id: cell.id,
        blocks: cell.blocks.map((block) => block.copy()).toList(),
        rowSpan: cell.rowSpan,
        columnSpan: cell.columnSpan,
        isHeader: cell.isHeader,
        backgroundColor: backgroundColor,
        covered: cell.covered,
      ),
    );
  }
}

class MergeTableCellsCommand extends EditorCommand {
  const MergeTableCellsCommand({
    required this.blockIndex,
    required this.startRow,
    required this.startColumn,
    required this.endRow,
    required this.endColumn,
  });

  final int blockIndex;
  final int startRow;
  final int startColumn;
  final int endRow;
  final int endColumn;

  @override
  String get description => 'mergeTableCells';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    if (tableBlock == null) {
      return const CommandResult(recordHistory: false);
    }
    final top = startRow <= endRow ? startRow : endRow;
    final bottom = startRow <= endRow ? endRow : startRow;
    final left = startColumn <= endColumn ? startColumn : endColumn;
    final right = startColumn <= endColumn ? endColumn : startColumn;
    if (top < 0 ||
        left < 0 ||
        bottom >= tableBlock.table.rowCount ||
        right >= tableBlock.table.columnCount ||
        (top == bottom && left == right)) {
      return const CommandResult(recordHistory: false);
    }
    for (var row = top; row <= bottom; row++) {
      for (var column = left; column <= right; column++) {
        final cell = tableBlock.table.cellAt(row, column);
        if (cell == null ||
            cell.covered ||
            cell.rowSpan != 1 ||
            cell.columnSpan != 1) {
          return const CommandResult(recordHistory: false);
        }
      }
    }
    final rows = tableBlock.table.rows.map(copyRow).toList();
    for (var row = top; row <= bottom; row++) {
      for (var column = left; column <= right; column++) {
        final cell = rows[row][column];
        rows[row][column] = TableCellNode(
          id: cell.id,
          blocks: cell.blocks.map((block) => block.copy()).toList(),
          rowSpan: row == top && column == left ? bottom - top + 1 : 1,
          columnSpan: row == top && column == left ? right - left + 1 : 1,
          isHeader: cell.isHeader,
          backgroundColor: cell.backgroundColor,
          covered: !(row == top && column == left),
        );
      }
    }
    return _replaceTableWithSelection(
      session,
      blockIndex,
      tableBlock,
      rows,
      selection: cellSelection(tableBlock.id, blockIndex, top, left, 0),
      columnAlignments: tableBlock.table.columnAlignments,
      columnWidths: tableBlock.table.columnWidths,
    );
  }
}

class SplitTableCellCommand extends EditorCommand {
  const SplitTableCellCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;

  @override
  String get description => 'splitTableCell';

  @override
  CommandResult execute(DocumentSession session) {
    final tableBlock = tableAt(session, blockIndex);
    final anchor = tableBlock?.table.cellAt(rowIndex, columnIndex);
    if (tableBlock == null ||
        anchor == null ||
        anchor.covered ||
        (anchor.rowSpan == 1 && anchor.columnSpan == 1)) {
      return const CommandResult(recordHistory: false);
    }
    final bottom = rowIndex + anchor.rowSpan - 1;
    final right = columnIndex + anchor.columnSpan - 1;
    if (bottom >= tableBlock.table.rowCount ||
        right >= tableBlock.table.columnCount) {
      return const CommandResult(recordHistory: false);
    }
    final rows = tableBlock.table.rows.map(copyRow).toList();
    for (var row = rowIndex; row <= bottom; row++) {
      for (var column = columnIndex; column <= right; column++) {
        final cell = rows[row][column];
        rows[row][column] = TableCellNode(
          id: cell.id,
          blocks: cell.blocks.map((block) => block.copy()).toList(),
          isHeader: cell.isHeader,
          backgroundColor: cell.backgroundColor,
        );
      }
    }
    return _replaceTableWithSelection(
      session,
      blockIndex,
      tableBlock,
      rows,
      selection:
          cellSelection(tableBlock.id, blockIndex, rowIndex, columnIndex, 0),
      columnAlignments: tableBlock.table.columnAlignments,
      columnWidths: tableBlock.table.columnWidths,
    );
  }
}

class InsertTableCellTextCommand extends EditorCommand {
  const InsertTableCellTextCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.offset,
    required this.text,
    this.attributes = const TextAttributes(),
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final int offset;
  final String text;
  final TextAttributes attributes;

  @override
  String get description => 'insertTableCellText';

  @override
  CommandResult execute(DocumentSession session) {
    return insertTableCellInlineText(
      session,
      blockIndex,
      rowIndex,
      columnIndex,
      offset,
      text,
      attributes: attributes,
    );
  }
}

class DeleteTableCellTextCommand extends EditorCommand {
  const DeleteTableCellTextCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.startOffset,
    required this.endOffset,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final int startOffset;
  final int endOffset;

  @override
  String get description => 'deleteTableCellText';

  @override
  CommandResult execute(DocumentSession session) {
    return deleteTableCellInlineRange(
      session,
      blockIndex,
      rowIndex,
      columnIndex,
      startOffset,
      endOffset,
    );
  }
}

class FormatTableCellTextCommand extends EditorCommand {
  const FormatTableCellTextCommand({
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.startOffset,
    required this.endOffset,
    required this.attributes,
  });

  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final int startOffset;
  final int endOffset;
  final TextAttributes attributes;

  @override
  String get description => 'formatTableCellText';

  @override
  CommandResult execute(DocumentSession session) {
    return formatTableCellInlineRange(
      session,
      blockIndex,
      rowIndex,
      columnIndex,
      startOffset,
      endOffset,
      attributes,
    );
  }
}

CommandResult insertTableRowAt(
  DocumentSession session,
  int blockIndex,
  int rowIndex, {
  TableCellIdBuilder? cellIdBuilder,
}) {
  final tableBlock = tableAt(session, blockIndex);
  if (tableBlock == null) {
    return const CommandResult(recordHistory: false);
  }
  final insertIndex = rowIndex.clamp(0, tableBlock.table.rowCount).toInt();
  final rows = <List<TableCellNode>>[
    for (var i = 0; i < insertIndex; i++) copyRow(tableBlock.table.rows[i]),
    _createRow(
      tableBlock.id,
      insertIndex,
      tableBlock.table.columnCount,
      cellIdBuilder,
    ),
    for (var i = insertIndex; i < tableBlock.table.rowCount; i++)
      copyRow(tableBlock.table.rows[i]),
  ];
  return _replaceTableWithSelection(
    session,
    blockIndex,
    tableBlock,
    rows,
    selection: _tableSelectionAfterRowInserted(
      session.selection,
      tableBlock,
      blockIndex,
      rows,
      insertIndex,
    ),
  );
}

CommandResult updateTableCell(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  TableCellNode Function(TableCellNode cell) update,
) {
  final tableBlock = tableAt(session, blockIndex);
  final cell = tableBlock?.table.cellAt(rowIndex, columnIndex);
  if (tableBlock == null || cell == null) {
    return const CommandResult(recordHistory: false);
  }
  final selection = session.selection;
  final rows = tableBlock.table.rows.map(copyRow).toList();
  rows[rowIndex][columnIndex] = update(cell);
  final result = replaceTable(session, blockIndex, tableBlock, rows);
  if (selection == null) {
    return result;
  }
  return CommandResult(
    selection: selection,
    recordHistory: result.recordHistory,
    metadata: result.metadata,
  );
}

CommandResult _replaceTableWithSelection(
  DocumentSession session,
  int blockIndex,
  TableBlockNode tableBlock,
  List<List<TableCellNode>> rows, {
  DocumentSelection? selection,
  Map<int, String>? columnAlignments,
  Map<int, double>? columnWidths,
}) {
  final result = replaceTable(
    session,
    blockIndex,
    tableBlock,
    rows,
    columnAlignments: columnAlignments,
    columnWidths: columnWidths,
  );
  if (selection == null) {
    return result;
  }
  return CommandResult(
    selection: selection,
    recordHistory: result.recordHistory,
    metadata: result.metadata,
  );
}

DocumentSelection? _tableSelectionAfterRowInserted(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows,
  int insertIndex,
) {
  return _mapTableSelection(
    selection,
    tableBlock,
    blockIndex,
    rows,
    mapRow: (rowIndex) => rowIndex >= insertIndex ? rowIndex + 1 : rowIndex,
    mapColumn: (columnIndex) => columnIndex,
  );
}

DocumentSelection? _tableSelectionAfterColumnInserted(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows,
  int insertIndex,
) {
  return _mapTableSelection(
    selection,
    tableBlock,
    blockIndex,
    rows,
    mapRow: (rowIndex) => rowIndex,
    mapColumn: (columnIndex) =>
        columnIndex >= insertIndex ? columnIndex + 1 : columnIndex,
  );
}

DocumentSelection? _tableSelectionAfterRowDeleted(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows,
  int deletedRowIndex,
) {
  return _mapTableSelection(
    selection,
    tableBlock,
    blockIndex,
    rows,
    mapRow: (rowIndex) => rowIndex > deletedRowIndex ? rowIndex - 1 : rowIndex,
    mapColumn: (columnIndex) => columnIndex,
  );
}

DocumentSelection? _tableSelectionAfterColumnDeleted(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows,
  int deletedColumnIndex,
) {
  return _mapTableSelection(
    selection,
    tableBlock,
    blockIndex,
    rows,
    mapRow: (rowIndex) => rowIndex,
    mapColumn: (columnIndex) =>
        columnIndex > deletedColumnIndex ? columnIndex - 1 : columnIndex,
  );
}

DocumentSelection? _mapTableSelection(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows, {
  required int Function(int rowIndex) mapRow,
  required int Function(int columnIndex) mapColumn,
}) {
  final range = selection?.tableCellRange;
  if (selection == null ||
      range == null ||
      range.tableBlockId != tableBlock.id ||
      range.blockIndex != blockIndex) {
    return null;
  }
  final base = _mapTablePosition(
    selection.base,
    tableBlock,
    blockIndex,
    rows,
    mapRow: mapRow,
    mapColumn: mapColumn,
  );
  final extent = _mapTablePosition(
    selection.extent,
    tableBlock,
    blockIndex,
    rows,
    mapRow: mapRow,
    mapColumn: mapColumn,
  );
  if (base == null || extent == null) {
    return null;
  }
  return DocumentSelection(base: base, extent: extent);
}

DocumentPosition? _mapTablePosition(
  DocumentPosition position,
  TableBlockNode tableBlock,
  int blockIndex,
  List<List<TableCellNode>> rows, {
  required int Function(int rowIndex) mapRow,
  required int Function(int columnIndex) mapColumn,
}) {
  final sourceRowIndex = position.path.tableRowIndex;
  final sourceColumnIndex = position.path.tableColumnIndex;
  if (position.blockId != tableBlock.id ||
      position.blockIndex != blockIndex ||
      sourceRowIndex == null ||
      sourceColumnIndex == null ||
      rows.isEmpty) {
    return null;
  }
  final rowIndex = mapRow(sourceRowIndex).clamp(0, rows.length - 1).toInt();
  final row = rows[rowIndex];
  if (row.isEmpty) {
    return null;
  }
  final columnIndex =
      mapColumn(sourceColumnIndex).clamp(0, row.length - 1).toInt();
  final textLength = cellTextBlock(row[columnIndex]).plainText.length;
  return DocumentPosition.tableCell(
    tableBlockId: tableBlock.id,
    blockIndex: blockIndex,
    tableRowIndex: rowIndex,
    tableColumnIndex: columnIndex,
    offset: position.offset.clamp(0, textLength).toInt(),
  );
}

Map<int, T> shiftColumnMapOnInsert<T>(Map<int, T> values, int insertIndex) {
  return <int, T>{
    for (final entry in values.entries)
      if (entry.key < insertIndex)
        entry.key: entry.value
      else
        entry.key + 1: entry.value,
  };
}

Map<int, T> shiftColumnMapOnDelete<T>(Map<int, T> values, int deleteIndex) {
  return <int, T>{
    for (final entry in values.entries)
      if (entry.key < deleteIndex)
        entry.key: entry.value
      else if (entry.key > deleteIndex)
        entry.key - 1: entry.value,
  };
}

TableModel _createTable(
  String tableId,
  int rowCount,
  int columnCount,
  TableCellIdBuilder? cellIdBuilder,
) {
  return TableModel(
    rows: <List<TableCellNode>>[
      for (var row = 0; row < rowCount; row++)
        _createRow(tableId, row, columnCount, cellIdBuilder),
    ],
  );
}

List<TableCellNode> _createRow(
  String tableId,
  int rowIndex,
  int columnCount,
  TableCellIdBuilder? cellIdBuilder,
) {
  return <TableCellNode>[
    for (var column = 0; column < columnCount; column++)
      _emptyCell(_cellId(tableId, rowIndex, column, cellIdBuilder)),
  ];
}

String _cellId(
  String tableId,
  int rowIndex,
  int columnIndex,
  TableCellIdBuilder? cellIdBuilder,
) {
  return cellIdBuilder?.call(tableId, rowIndex, columnIndex) ??
      '$tableId-r$rowIndex-c$columnIndex';
}

TableCellNode _emptyCell(String id) {
  return TableCellNode(
    id: id,
    blocks: <BlockNode>[
      TextBlockNode(
        id: '$id-text',
        type: BlockType.paragraph,
        content: const <InlineNode>[],
      ),
    ],
  );
}
