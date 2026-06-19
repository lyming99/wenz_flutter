import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../model/table_model.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';

TableCellEditTarget? tableCellTarget(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
) {
  final tableBlock = tableAt(session, blockIndex);
  final cell = tableBlock?.table.cellAt(rowIndex, columnIndex);
  if (tableBlock == null || cell == null) {
    return null;
  }
  return TableCellEditTarget(
    tableBlock: tableBlock,
    cell: cell,
    textBlock: cellTextBlock(cell),
  );
}

TableCellEditTarget? tableCellTargetFromPosition(
  DocumentSession session,
  DocumentPosition position,
) {
  final path = position.path;
  if (!path.isTableCellText) {
    return null;
  }
  final rowIndex = path.tableRowIndex;
  final columnIndex = path.tableColumnIndex;
  if (rowIndex == null || columnIndex == null) {
    return null;
  }
  return tableCellTarget(session, position.blockIndex, rowIndex, columnIndex);
}

class TableCellEditTarget {
  const TableCellEditTarget({
    required this.tableBlock,
    required this.cell,
    required this.textBlock,
  });

  final TableBlockNode tableBlock;
  final TableCellNode cell;
  final TextBlockNode textBlock;

  int get textLength => inlineNodesLength(textBlock.content);

  String get plainText => textBlock.plainText;
}

CommandResult insertTableCellInlineText(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  int offset,
  String text, {
  TextAttributes attributes = const TextAttributes(),
}) {
  if (text.isEmpty) {
    return const CommandResult(recordHistory: false);
  }
  final target = tableCellTarget(session, blockIndex, rowIndex, columnIndex);
  if (target == null) {
    return const CommandResult(recordHistory: false);
  }
  final safeOffset = offset.clamp(0, target.textLength).toInt();
  final nextTextBlock = TextBlockNode(
    id: target.textBlock.id,
    type: target.textBlock.type,
    attributes: target.textBlock.attributes,
    content: insertInline(
      target.textBlock.content,
      safeOffset,
      text,
      attributes,
    ),
  );
  return replaceCellTextBlock(
    session,
    blockIndex,
    target.tableBlock,
    rowIndex,
    columnIndex,
    target.cell,
    nextTextBlock,
    cellSelection(
      target.tableBlock.id,
      blockIndex,
      rowIndex,
      columnIndex,
      safeOffset + text.length,
    ),
  );
}

CommandResult deleteTableCellInlineRange(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  int startOffset,
  int endOffset,
) {
  if (endOffset <= startOffset) {
    return const CommandResult(recordHistory: false);
  }
  final target = tableCellTarget(session, blockIndex, rowIndex, columnIndex);
  if (target == null) {
    return const CommandResult(recordHistory: false);
  }
  final safeStart = startOffset.clamp(0, target.textLength).toInt();
  final safeEnd = endOffset.clamp(safeStart, target.textLength).toInt();
  if (safeStart == safeEnd) {
    return const CommandResult(recordHistory: false);
  }
  final nextTextBlock = TextBlockNode(
    id: target.textBlock.id,
    type: target.textBlock.type,
    attributes: target.textBlock.attributes,
    content: deleteInline(target.textBlock.content, safeStart, safeEnd),
  );
  return replaceCellTextBlock(
    session,
    blockIndex,
    target.tableBlock,
    rowIndex,
    columnIndex,
    target.cell,
    nextTextBlock,
    cellSelection(
      target.tableBlock.id,
      blockIndex,
      rowIndex,
      columnIndex,
      safeStart,
    ),
  );
}

CommandResult formatTableCellInlineRange(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  int startOffset,
  int endOffset,
  TextAttributes attributes,
) {
  if (endOffset <= startOffset || attributes.isEmpty) {
    return const CommandResult(recordHistory: false);
  }
  final target = tableCellTarget(session, blockIndex, rowIndex, columnIndex);
  if (target == null) {
    return const CommandResult(recordHistory: false);
  }
  final safeStart = startOffset.clamp(0, target.textLength).toInt();
  final safeEnd = endOffset.clamp(safeStart, target.textLength).toInt();
  if (safeStart == safeEnd) {
    return const CommandResult(recordHistory: false);
  }
  final nextTextBlock = TextBlockNode(
    id: target.textBlock.id,
    type: target.textBlock.type,
    attributes: target.textBlock.attributes,
    content: formatInline(
      target.textBlock.content,
      safeStart,
      safeEnd,
      attributes,
    ),
  );
  return replaceCellTextBlock(
    session,
    blockIndex,
    target.tableBlock,
    rowIndex,
    columnIndex,
    target.cell,
    nextTextBlock,
    cellSelection(target.tableBlock.id, blockIndex, rowIndex, columnIndex, safeEnd),
  );
}

CommandResult clearTableCellRange(
  DocumentSession session,
  TableCellRange range,
) {
  final tableBlock = tableAt(session, range.blockIndex);
  if (tableBlock == null) {
    return const CommandResult(recordHistory: false);
  }
  final rows = tableBlock.table.rows.map(copyRow).toList();
  var changed = false;
  for (var rowIndex = range.startRow; rowIndex <= range.endRow; rowIndex++) {
    if (rowIndex < 0 || rowIndex >= rows.length) {
      continue;
    }
    final row = rows[rowIndex];
    for (var columnIndex = range.startColumn;
        columnIndex <= range.endColumn;
        columnIndex++) {
      if (columnIndex < 0 || columnIndex >= row.length) {
        continue;
      }
      final cell = row[columnIndex];
      final textBlock = cellTextBlock(cell);
      final alreadyEmpty = textBlock.content.isEmpty && cell.blocks.length == 1;
      if (alreadyEmpty) {
        continue;
      }
      row[columnIndex] = TableCellNode(
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
      changed = true;
    }
  }
  if (!changed) {
    return const CommandResult(recordHistory: false);
  }
  replaceTable(session, range.blockIndex, tableBlock, rows);
  return CommandResult(
    selection: cellSelection(
      tableBlock.id,
      range.blockIndex,
      range.startRow,
      range.startColumn,
      0,
    ),
  );
}

TableBlockNode? tableAt(DocumentSession session, int blockIndex) {
  if (blockIndex < 0 || blockIndex >= session.document.blocks.length) {
    return null;
  }
  final block = session.document.blocks[blockIndex];
  return block is TableBlockNode ? block : null;
}

TextBlockNode cellTextBlock(TableCellNode cell) {
  for (final block in cell.blocks) {
    if (block is TextBlockNode) {
      return block;
    }
  }
  return TextBlockNode(
    id: '${cell.id}-text',
    type: BlockType.paragraph,
    content: const <InlineNode>[],
  );
}

CommandResult replaceTable(
  DocumentSession session,
  int blockIndex,
  TableBlockNode original,
  List<List<TableCellNode>> rows, {
  Map<int, String>? columnAlignments,
  Map<int, double>? columnWidths,
}) {
  final blocks = session.document.blocks.map((block) => block.copy()).toList();
  blocks[blockIndex] = TableBlockNode(
    id: original.id,
    attributes: original.attributes,
    table: TableModel(
      rows: rows,
      columnAlignments: columnAlignments ??
          Map<int, String>.from(original.table.columnAlignments),
      columnWidths:
          columnWidths ?? Map<int, double>.from(original.table.columnWidths),
    ),
  );
  session.document = RichTextDocument(
    version: session.document.version,
    blocks: blocks,
  );
  return const CommandResult();
}

CommandResult replaceCellTextBlock(
  DocumentSession session,
  int blockIndex,
  TableBlockNode tableBlock,
  int rowIndex,
  int columnIndex,
  TableCellNode cell,
  TextBlockNode nextTextBlock,
  DocumentSelection selection,
) {
  final rows = tableBlock.table.rows.map(copyRow).toList();
  final existingBlocks = cell.blocks;
  final nextCellBlocks = <BlockNode>[];
  var replaced = false;
  for (final block in existingBlocks) {
    if (!replaced && block is TextBlockNode) {
      nextCellBlocks.add(nextTextBlock);
      replaced = true;
    } else {
      nextCellBlocks.add(block.copy());
    }
  }
  if (!replaced) {
    nextCellBlocks.insert(0, nextTextBlock);
  }
  rows[rowIndex][columnIndex] = TableCellNode(
    id: cell.id,
    blocks: nextCellBlocks,
    rowSpan: cell.rowSpan,
    columnSpan: cell.columnSpan,
    isHeader: cell.isHeader,
    backgroundColor: cell.backgroundColor,
    covered: cell.covered,
  );
  replaceTable(session, blockIndex, tableBlock, rows);
  return CommandResult(selection: selection);
}

DocumentSelection cellSelection(
  String tableId,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  int offset,
) {
  final position = DocumentPosition.tableCell(
    tableBlockId: tableId,
    blockIndex: blockIndex,
    tableRowIndex: rowIndex,
    tableColumnIndex: columnIndex,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

List<TableCellNode> copyRow(List<TableCellNode> row) {
  return row.map(copyCell).toList();
}

TableCellNode copyCell(TableCellNode cell) {
  return TableCellNode(
    id: cell.id,
    blocks: cell.blocks.map((block) => block.copy()).toList(),
    rowSpan: cell.rowSpan,
    columnSpan: cell.columnSpan,
    isHeader: cell.isHeader,
    backgroundColor: cell.backgroundColor,
    covered: cell.covered,
  );
}
