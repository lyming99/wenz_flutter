import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('controller executes commands and notifies listeners', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    controller.insertText('!');

    expect(controller.document.plainText, 'Hi!');
    expect(controller.selection?.extent.offset, 3);
    expect(notifyCount, 1);
    expect(controller.canUndo, isTrue);
  });

  test('controller undo and redo notify and restore document', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    controller.insertText('!');
    expect(controller.undo(), isTrue);
    expect(controller.document.plainText, 'Hi');
    expect(controller.redo(), isTrue);
    expect(controller.document.plainText, 'Hi!');
    expect(notifyCount, 3);
  });

  test('controller loads rich text json and legacy json', () {
    final controller = WenzRichTextController();
    const richCodec = RichTextJsonCodec();
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Rich')],
        ),
      ],
    );

    controller.loadJson(richCodec.encode(document));
    expect(controller.document.plainText, 'Rich');

    controller.loadJson(
      '[{"type":"text","children":[{"type":"text","text":"Legacy"}]}]',
      legacy: true,
    );
    expect(controller.document.plainText, 'Legacy');
    expect(controller.canUndo, isFalse);
  });

  test('controller wraps table cell text commands', () {
    final controller = WenzRichTextController();

    controller.insertTable(
      index: 0,
      tableId: 't1',
      rowCount: 1,
      columnCount: 1,
    );
    controller.insertTableCellText(
      blockIndex: 0,
      rowIndex: 0,
      columnIndex: 0,
      offset: 0,
      text: 'Cell',
    );

    final table = controller.document.blocks.whereType<TableBlockNode>().single;
    final cellText = table.table.cellAt(0, 0)!.plainText;
    expect(cellText, 'Cell');
    expect(
      controller.selection?.extent.path.toString(),
      'block/t1/row/0/cell/0',
    );
  });

  test('controller wraps table row and column structure commands', () {
    final controller = WenzRichTextController(document: _tableDocument());

    controller.insertTableRow(blockIndex: 0, rowIndex: 1);
    var table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 3);

    controller.insertTableColumn(blockIndex: 0, columnIndex: 1);
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 4);

    controller.deleteTableRow(blockIndex: 0, rowIndex: 1);
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 2);

    controller.deleteTableColumn(blockIndex: 0, columnIndex: 1);
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 3);
  });

  test('controller selects table row column and whole table', () {
    final controller = WenzRichTextController(document: _tableDocument());

    controller.selectTableRow(blockIndex: 0, rowIndex: 1);
    var range = controller.selection?.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 1);
    expect(range.endRow, 1);
    expect(range.startColumn, 0);
    expect(range.endColumn, 2);
    expect(controller.copySelection(), 'R1C0\tR1C1\tR1C2');

    controller.selectTableColumn(blockIndex: 0, columnIndex: 2);
    range = controller.selection?.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 0);
    expect(range.endRow, 1);
    expect(range.startColumn, 2);
    expect(range.endColumn, 2);
    expect(controller.copySelection(), 'R0C2\nR1C2');

    controller.selectTable(blockIndex: 0);
    range = controller.selection?.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 0);
    expect(range.endRow, 1);
    expect(range.startColumn, 0);
    expect(range.endColumn, 2);
  });

  group('lastChangedBlockIds', () {
    RichTextDocument multiBlockDoc() => const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'one')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'two')],
            ),
            TextBlockNode(
              id: 'p3',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'three')],
            ),
          ],
        );

    test('insert text marks only the edited block dirty', () {
      final controller = WenzRichTextController(
        document: multiBlockDoc(),
        selection: collapsedTextSelection('p2', 1, 3),
      );
      controller.insertText('!');

      expect(controller.lastChangedBlockIds, {'p2'});
    });

    test('enter splitting a block marks the original and new block dirty', () {
      final controller = WenzRichTextController(
        document: multiBlockDoc(),
        selection: collapsedTextSelection('p2', 1, 1),
      );
      controller.enter(newBlockId: 'p2-next');

      // p2 content changed and p2-next was added; p1/p3 untouched.
      expect(controller.lastChangedBlockIds, {'p2', 'p2-next'});
    });

    test('a no-op text insert does not notify and leaves the set stale', () {
      final controller = WenzRichTextController(
        document: multiBlockDoc(),
        selection: collapsedTextSelection('p1', 0, 3),
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.insertText('');

      // A no-op does not notify; lastChangedBlockIds is untouched.
      expect(notifyCount, 0);
      expect(controller.lastChangedBlockIds, isNull);
    });

    test('selection-only change marks no block dirty', () {
      final controller = WenzRichTextController(
        document: multiBlockDoc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      controller.setSelection(collapsedTextSelection('p3', 2, 5));

      expect(controller.lastChangedBlockIds, <String>{});
    });

    test('undo / redo mark changed blocks dirty', () {
      final controller = WenzRichTextController(
        document: multiBlockDoc(),
        selection: collapsedTextSelection('p2', 1, 3),
      );
      controller.insertText('!');
      // Undo restores the document; p2 changed back.
      controller.undo();
      expect(controller.lastChangedBlockIds, {'p2'});
      // Redo reapplies; p2 changed again.
      controller.redo();
      expect(controller.lastChangedBlockIds, {'p2'});
    });

    test('replaceDocument marks the changed blocks dirty', () {
      final controller = WenzRichTextController(document: multiBlockDoc());
      controller.replaceDocument(
        const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'one')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'TWO-changed')],
            ),
          ],
        ),
      );
      // p2 changed, p3 removed (not in the set), p1 unchanged.
      expect(controller.lastChangedBlockIds, {'p2'});
    });
  });
}

RichTextDocument _tableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-00',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-00-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R0C0')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-01',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-01-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R0C1')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-02',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-02-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R0C2')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'cell-10',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-10-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R1C0')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-11',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-11-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R1C1')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-12',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-12-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'R1C2')],
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
