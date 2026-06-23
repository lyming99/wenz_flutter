import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('insert table creates requested dimensions', () {
    final session = DocumentSession(document: const RichTextDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertTableCommand(
        index: 0,
        tableId: 't1',
        rowCount: 2,
        columnCount: 3,
      ),
    );

    final table = session.document.blocks.whereType<TableBlockNode>().single;
    expect(table.table.rowCount, 2);
    expect(table.table.columnCount, 3);
    expect(table.table.cellAt(1, 2)?.id, 't1-r1-c2');
    expect(session.canUndo, isTrue);
  });

  test('insert table after current empty paragraph replaces it', () {
    final position = DocumentPosition.text(
      blockId: 'p1',
      blockIndex: 0,
      offset: 0,
    );
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: DocumentSelection(base: position, extent: position),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertTableCommand(
        index: 1,
        tableId: 't1',
        rowCount: 2,
        columnCount: 2,
      ),
    );

    expect(session.document.blocks, hasLength(1));
    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 2);
    expect(table.table.columnCount, 2);
    expect(session.selection?.extent.blockId, 't1');
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
  });

  test('insert table row and column update dimensions', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(const InsertTableRowCommand(blockIndex: 0, rowIndex: 1));
    executor.execute(
      const InsertTableColumnCommand(blockIndex: 0, columnIndex: 1),
    );

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 3);
    expect(table.table.columnCount, 3);
  });

  test('delete table row and column keep at least one row and column', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(const DeleteTableRowCommand(blockIndex: 0, rowIndex: 0));
    executor.execute(
      const DeleteTableColumnCommand(blockIndex: 0, columnIndex: 1),
    );

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 1);
    expect(table.table.columnCount, 1);

    executor.execute(const DeleteTableRowCommand(blockIndex: 0, rowIndex: 0));
    executor.execute(
      const DeleteTableColumnCommand(blockIndex: 0, columnIndex: 0),
    );
    final unchanged = session.document.blocks.single as TableBlockNode;
    expect(unchanged.table.rowCount, 1);
    expect(unchanged.table.columnCount, 1);
  });

  test('set table column alignment updates and clears alignment', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const SetTableColumnAlignmentCommand(
        blockIndex: 0,
        columnIndex: 1,
        alignment: 'right',
      ),
    );
    var table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnAlignments[1], 'right');

    executor.execute(
      const SetTableColumnAlignmentCommand(
        blockIndex: 0,
        columnIndex: 1,
        alignment: null,
      ),
    );
    table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnAlignments.containsKey(1), isFalse);
  });

  test('inserting a column before an aligned column shifts its alignment', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    // Align column 1, then insert a new column at index 0 (before it).
    executor.execute(
      const SetTableColumnAlignmentCommand(
        blockIndex: 0,
        columnIndex: 1,
        alignment: 'right',
      ),
    );
    executor.execute(
      const InsertTableColumnCommand(blockIndex: 0, columnIndex: 0),
    );

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 3);
    // The previously-aligned column moved from index 1 to index 2.
    expect(table.table.columnAlignments[2], 'right');
    expect(table.table.columnAlignments.containsKey(1), isFalse);
  });

  test('inserting a column after an aligned column keeps its alignment', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const SetTableColumnAlignmentCommand(
        blockIndex: 0,
        columnIndex: 0,
        alignment: 'center',
      ),
    );
    executor.execute(
      const InsertTableColumnCommand(blockIndex: 0, columnIndex: 1),
    );

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 3);
    expect(table.table.columnAlignments[0], 'center');
  });

  test('insert table cell text edits empty cell and updates selection', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 1,
        offset: 0,
        text: 'Hello',
      ),
    );

    final textBlock = _cellTextBlock(session, 0, 1);
    expect(textBlock.plainText, 'Hello');
    expect(session.selection?.extent.offset, 5);
    expect(session.selection?.extent.path.toString(), 'block/t1/row/0/cell/1');
  });

  test('delete table cell text removes selected range', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        offset: 0,
        text: 'Hello',
      ),
    );

    executor.execute(
      const DeleteTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        startOffset: 1,
        endOffset: 4,
      ),
    );

    final textBlock = _cellTextBlock(session, 0, 0);
    expect(textBlock.plainText, 'Ho');
    expect(session.selection?.extent.offset, 1);
  });

  test('format table cell text applies inline attributes', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 1,
        columnIndex: 1,
        offset: 0,
        text: 'Hello',
      ),
    );

    executor.execute(
      const FormatTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 1,
        columnIndex: 1,
        startOffset: 1,
        endOffset: 4,
        attributes: TextAttributes(bold: true),
      ),
    );

    final textBlock = _cellTextBlock(session, 1, 1);
    expect(textBlock.content, hasLength(3));
    expect((textBlock.content[1] as TextRun).text, 'ell');
    expect((textBlock.content[1] as TextRun).attributes.bold, isTrue);
    expect(session.selection?.base.path.isTableCellText, isTrue);
    expect(session.selection?.base.offset, 1);
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 4);
  });

  test('ToggleMarkCommand toggles bold inside a table cell', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        offset: 0,
        text: 'Hello',
      ),
    );
    final selection = DocumentSelection(
      base: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 1,
      ),
      extent: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 4,
      ),
    );

    // Apply bold.
    executor.execute(ToggleMarkCommand(TextMark.bold, selection: selection));
    var textBlock = _cellTextBlock(session, 0, 0);
    expect((textBlock.content[1] as TextRun).text, 'ell');
    expect((textBlock.content[1] as TextRun).attributes.bold, isTrue);
    expect(session.selection, selection);

    // Toggle off — the whole range clears bold.
    executor.execute(ToggleMarkCommand(TextMark.bold, selection: selection));
    textBlock = _cellTextBlock(session, 0, 0);
    final runs = textBlock.content.whereType<TextRun>();
    expect(runs.every((r) => r.attributes.bold != true), isTrue);
    expect(session.selection, selection);
  });

  test('SetLinkCommand sets and clears a link inside a table cell', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        offset: 0,
        text: 'Hello',
      ),
    );
    final selection = DocumentSelection(
      base: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
      extent: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 5,
      ),
    );

    executor.execute(SetLinkCommand('https://e.co', selection: selection));
    var textBlock = _cellTextBlock(session, 0, 0);
    expect(
      (textBlock.content.whereType<TextRun>().single).attributes.url,
      'https://e.co',
    );

    executor.execute(SetLinkCommand(null, selection: selection));
    textBlock = _cellTextBlock(session, 0, 0);
    expect(
      (textBlock.content.whereType<TextRun>().single).attributes.url,
      isNull,
    );
  });

  test('InsertInlineEmbedCommand inserts an embed inside a table cell', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        offset: 0,
        text: 'Hi',
      ),
    );
    final caretPos = DocumentPosition.tableCell(
      tableBlockId: 't1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 1,
    );
    final caret = DocumentSelection(base: caretPos, extent: caretPos);
    session.selection = caret;

    executor.execute(
      const InsertInlineEmbedCommand(
        embedType: 'formula',
        data: <String, Object?>{'text': 'x^2'},
      ),
    );

    final textBlock = _cellTextBlock(session, 0, 0);
    final embed = textBlock.content.whereType<InlineEmbed>().single;
    expect(embed.embedType, 'formula');
    expect(embed.data['text'], 'x^2');
    // Caret advanced past the embed.
    expect(session.selection?.extent.offset, 2);
  });

  test('ClearStyleCommand clears inline marks inside a table cell', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);
    executor.execute(
      const InsertTableCellTextCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        offset: 0,
        text: 'Hello',
      ),
    );
    final selection = DocumentSelection(
      base: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
      extent: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 5,
      ),
    );
    // Bold + italic the whole cell, then clear.
    executor
      ..execute(ToggleMarkCommand(TextMark.bold, selection: selection))
      ..execute(ToggleMarkCommand(TextMark.italic, selection: selection))
      ..execute(ClearStyleCommand(selection: selection));

    final textBlock = _cellTextBlock(session, 0, 0);
    final run = textBlock.content.whereType<TextRun>().single;
    expect(run.attributes.bold, isNull);
    expect(run.attributes.italic, isNull);
  });

  test('set table column width updates clears and shifts width', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const SetTableColumnWidthCommand(
        blockIndex: 0,
        columnIndex: 1,
        width: 160,
      ),
    );
    executor.execute(
      const InsertTableColumnCommand(blockIndex: 0, columnIndex: 0),
    );

    var table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths[2], 160);

    executor.execute(
      const SetTableColumnWidthCommand(
        blockIndex: 0,
        columnIndex: 2,
        width: null,
      ),
    );
    table = session.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths.containsKey(2), isFalse);
  });

  test('set table cell header and background updates cell style', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const SetTableCellHeaderCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        isHeader: true,
      ),
    );
    executor.execute(
      const SetTableCellBackgroundCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        backgroundColor: 0xFFFFEEAA,
      ),
    );

    final cell =
        (session.document.blocks.single as TableBlockNode).table.cellAt(0, 0)!;
    expect(cell.isHeader, isTrue);
    expect(cell.backgroundColor, 0xFFFFEEAA);
  });

  test('set table cell style preserves the active table selection', () {
    final selection = DocumentSelection(
      base: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
      extent: DocumentPosition.tableCell(
        tableBlockId: 't1',
        blockIndex: 0,
        tableRowIndex: 1,
        tableColumnIndex: 1,
        offset: 0,
      ),
    );
    final session = DocumentSession(
      document: _tableDocument(),
      selection: selection,
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetTableCellBackgroundCommand(
        blockIndex: 0,
        rowIndex: 0,
        columnIndex: 0,
        backgroundColor: 0xFFFFEEAA,
      ),
    );

    expect(session.selection, selection);
  });

  test('merge and split table cells update spans and covered cells', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const MergeTableCellsCommand(
        blockIndex: 0,
        startRow: 0,
        startColumn: 0,
        endRow: 1,
        endColumn: 1,
      ),
    );

    var table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)?.rowSpan, 2);
    expect(table.table.cellAt(0, 0)?.columnSpan, 2);
    expect(table.table.cellAt(1, 1)?.covered, isTrue);

    executor.execute(
      const SplitTableCellCommand(blockIndex: 0, rowIndex: 0, columnIndex: 0),
    );

    table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)?.rowSpan, 1);
    expect(table.table.cellAt(0, 0)?.columnSpan, 1);
    expect(table.table.cellAt(1, 1)?.covered, isFalse);
  });

  test('merge table cells rejects existing merged ranges', () {
    final session = DocumentSession(document: _tableDocument());
    final executor = CommandExecutor(session);

    executor.execute(
      const MergeTableCellsCommand(
        blockIndex: 0,
        startRow: 0,
        startColumn: 0,
        endRow: 1,
        endColumn: 1,
      ),
    );
    final canUndoAfterFirstMerge = session.canUndo;
    executor.execute(
      const MergeTableCellsCommand(
        blockIndex: 0,
        startRow: 0,
        startColumn: 0,
        endRow: 1,
        endColumn: 1,
      ),
    );

    expect(canUndoAfterFirstMerge, isTrue);
    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)?.rowSpan, 2);
    expect(table.table.cellAt(1, 1)?.covered, isTrue);
  });
}

RichTextDocument _tableDocument() {
  const command = InsertTableCommand(
    index: 0,
    tableId: 't1',
    rowCount: 2,
    columnCount: 2,
  );
  final session = DocumentSession(document: const RichTextDocument());
  command.execute(session);
  // The session now normalises to [paragraph, table]; tests expect a single
  // table block, so return just the table.
  return RichTextDocument(
    blocks: <BlockNode>[
      session.document.blocks.whereType<TableBlockNode>().single,
    ],
  );
}

TextBlockNode _cellTextBlock(
  DocumentSession session,
  int rowIndex,
  int columnIndex,
) {
  final table = session.document.blocks.whereType<TableBlockNode>().single;
  final cell = table.table.cellAt(rowIndex, columnIndex)!;
  return cell.blocks.whereType<TextBlockNode>().first;
}
