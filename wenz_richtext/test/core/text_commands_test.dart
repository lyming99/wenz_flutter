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

  test('delete selection spans code block boundary into text block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'final value = 1;'),
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
                ],
              ],
            ),
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'tail text')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.code(
          blockId: 'c1',
          blockIndex: 0,
          offset: 6,
        ),
        extent: DocumentPosition.text(
          blockId: 'p2',
          blockIndex: 2,
          offset: 5,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    expect((session.document.blocks[0] as CodeBlockNode).code, 'final ');
    expect((session.document.blocks[1] as TextBlockNode).plainText, 'text');
    expect(session.selection?.extent.blockId, 'c1');
    expect(session.selection?.extent.offset, 6);
  });

  test('delete selection spans text block into code block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello start')],
          ),
          DividerBlockNode(id: 'divider1'),
          CodeBlockNode(id: 'c2', code: 'print("tail");'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 5,
        ),
        extent: DocumentPosition.code(
          blockId: 'c2',
          blockIndex: 2,
          offset: 6,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(2));
    expect((session.document.blocks[0] as TextBlockNode).plainText, 'hello');
    expect((session.document.blocks[1] as CodeBlockNode).code, '"tail");');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 5);
  });

  test('delete selection from table cell into later text block', () {
    final session = DocumentSession(
      document: const RichTextDocument(
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
              ],
            ),
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'tail')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.text(
          blockId: 'p2',
          blockIndex: 1,
          offset: 2,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    final table = session.document.blocks[0] as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, 'A');
    expect(table.table.cellAt(0, 1)!.plainText, '');
    expect((session.document.blocks[1] as TextBlockNode).plainText, 'il');
    expect(session.selection?.extent.path.isTableCellText, isTrue);
    expect(session.selection?.extent.offset, 1);
  });

  test('delete selection from text block into later table cell', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'head')],
          ),
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
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 2,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 1,
          tableRowIndex: 0,
          tableColumnIndex: 1,
          offset: 1,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const DeleteSelectionCommand());

    expect((session.document.blocks[0] as TextBlockNode).plainText, 'he');
    final table = session.document.blocks[1] as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, '');
    expect(table.table.cellAt(0, 1)!.plainText, 'B');
    expect(session.selection?.extent.blockId, 'p1');
    expect(session.selection?.extent.offset, 2);
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

  test('delete all selected content leaves one empty paragraph', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'a1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          ImageBlockNode(id: 'img2', assetId: 'a2'),
        ],
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SelectAllCommand());
    executor.execute(const DeleteSelectionCommand());

    expect(session.document.blocks, hasLength(1));
    final block = session.document.blocks.single;
    expect(block, isA<TextBlockNode>());
    expect((block as TextBlockNode).content, isEmpty);
    expect(block.type, BlockType.paragraph);
    expect(session.selection?.extent.blockIndex, 0);
    expect(session.selection?.extent.path.isBlockText, isTrue);
    expect(session.selection?.extent.offset, 0);
  });

  group('delete object block', () {
    DocumentSelection objectSelection(String blockId, int blockIndex) {
      final start = DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: PositionPath.blockObject(blockId),
        offset: 0,
      );
      final end = DocumentPosition(
        blockId: blockId,
        blockIndex: blockIndex,
        path: PositionPath.blockObject(blockId),
        offset: 1,
      );
      return DocumentSelection(base: start, extent: end);
    }

    test('deleting a selected image lands the caret in the previous block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: objectSelection('img1', 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(1));
      expect(session.document.blocks.single, isA<TextBlockNode>());
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 6); // end of "before"
      expect(session.canUndo, isTrue);
    });

    test('deleting an image with no previous block lands at the next block',
        () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: objectSelection('img1', 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(1));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 0);
    });

    test('deleting the only image leaves a normalised empty paragraph', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'img1', assetId: 'a1'),
          ],
        ),
        selection: objectSelection('img1', 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      // The command re-adds a paragraph so the caret can land in valid text.
      expect(session.document.blocks, hasLength(1));
      expect(session.document.blocks.single, isA<TextBlockNode>());
      expect(session.selection?.extent.blockIndex, 0);
      expect(session.selection?.extent.path.isBlockText, isTrue);
      expect(session.selection?.extent.offset, 0);
    });

    test('deleting a selected divider works', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'x')],
            ),
            DividerBlockNode(id: 'd1'),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'y')],
            ),
          ],
        ),
        selection: objectSelection('d1', 1),
      );
      final executor = CommandExecutor(session);

      executor.execute(const DeleteSelectionCommand());

      expect(session.document.blocks, hasLength(2));
      expect(session.selection?.extent.blockId, 'p1');
      expect(session.selection?.extent.offset, 1);
    });
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
