import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('insert text updates text block and selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand(' world'));

    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.offset, 11);
    expect(session.canUndo, isTrue);
  });

  test('insert text replaces non collapsed selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('i'));

    expect(session.document.plainText, 'Hio');
    expect(session.selection?.extent.offset, 2);
  });

  test('delete selection removes same-block text range', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello world')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 5, 11),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.plainText, 'Hello');
    expect(session.selection?.isCollapsed, isTrue);
    expect(session.selection?.extent.offset, 5);
  });

  test('delete selection merges text across blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello first')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'last world')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 5,
        ),
        extent: DocumentPosition(
          blockId: 'p3',
          blockIndex: 2,
          path: PositionPath.blockText('p3'),
          offset: 4,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.offset, 5);
  });

  test('insert and delete work for code blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'print();', language: 'dart'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 6,
        ),
        extent: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 6,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand("'hi'"));

    expect(session.document.plainText, "print('hi');");
  });

  test('delete backward removes character before collapsed selection', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.plainText, 'Hell');
    expect(session.selection?.extent.offset, 4);
  });

  test('delete backward merges text blocks at block start', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello ')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'world')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p2', 1, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteBackwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'Hello world');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 6);
  });

  test('delete forward merges code blocks at block end', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'final a = '),
          CodeBlockNode(id: 'c2', code: '1;'),
        ],
      ),
      selection: collapsedCodeSelection('c1', 0, 10),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteForwardCommand());

    expect(session.document.blocks, hasLength(1));
    expect(session.document.plainText, 'final a = 1;');
    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 10);
  });

  test('generic text commands edit table cell text', () {
    final session = DocumentSession(
      document: _tableCellDocument('Hello'),
      selection: _collapsedTableCellSelection(5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const InsertTextCommand('!'));

    var cell = _tableCellText(session.document);
    expect(cell.plainText, 'Hello!');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 6);

    executor.execute(const DeleteBackwardCommand());

    cell = _tableCellText(session.document);
    expect(cell.plainText, 'Hello');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 5);

    executor.execute(const DeleteForwardCommand());
    expect(_tableCellText(session.document).plainText, 'Hello');
  });

  test('delete selection removes table cell range', () {
    final session = DocumentSession(
      document: _tableCellDocument('Hello'),
      selection: DocumentSelection(
        base: _tableCellPosition(1),
        extent: _tableCellPosition(4),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(_tableCellText(session.document).plainText, 'Ho');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 1);
  });

  test('delete selection clears table cell range', () {
    final session = DocumentSession(
      document: _tableRangeDocument(),
      selection: _tableRangeSelection(),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final table = session.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, '');
    expect(table.table.cellAt(0, 1)!.plainText, '');
    expect(table.table.cellAt(1, 0)!.plainText, '');
    expect(table.table.cellAt(1, 1)!.plainText, '');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.path.tableRowIndex, 0);
    expect(session.selection?.extent.path.tableColumnIndex, 0);
    expect(session.selection?.extent.offset, 0);
  });
}

RichTextDocument _tableRangeDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'AA')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'BB')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'cell-c',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-c-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'CC')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-d',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-d-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'DD')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _tableRangeSelection() {
  return DocumentSelection(
    base: DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    ),
    extent: DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 1,
      offset: 0,
    ),
  );
}

RichTextDocument _tableCellDocument(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-p1',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: text)],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _collapsedTableCellSelection(int offset) {
  final position = _tableCellPosition(offset);
  return DocumentSelection(base: position, extent: position);
}

DocumentPosition _tableCellPosition(int offset) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
}

TextBlockNode _tableCellText(RichTextDocument document) {
  final table = document.blocks.single as TableBlockNode;
  return table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
}
