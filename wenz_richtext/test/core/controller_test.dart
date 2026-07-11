import 'package:flutter/widgets.dart';
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

  test('controller moves blocks through the command interface', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
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
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    var notifyCount = 0;
    var changedCount = 0;
    var selectionChangedCount = 0;
    EditorCommand? executedCommand;
    ChangeSet? executedChange;
    controller.addListener(() => notifyCount++);
    controller.onChanged = (_) => changedCount++;
    controller.onSelectionChanged = (_) => selectionChangedCount++;
    controller.onCommandExecuted = (command, change) {
      executedCommand = command;
      executedChange = change;
    };

    controller.moveBlock(fromIndex: 0, toIndex: 2);

    expect(controller.document.blocks.map((block) => block.id), [
      'p2',
      'p3',
      'p1',
    ]);
    expect(controller.selection, collapsedTextSelection('p1', 2, 3));
    expect(notifyCount, 1);
    expect(changedCount, 1);
    expect(selectionChangedCount, 1);
    expect(executedCommand, isA<MoveBlockCommand>());
    expect(executedChange?.metadata?['blockId'], 'p1');
    expect(controller.canUndo, isTrue);
  });

  test('controller block move no-op does not notify', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(id: 'p1', type: BlockType.paragraph),
          TextBlockNode(id: 'p2', type: BlockType.paragraph),
        ],
      ),
    );
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    final change = controller.moveBlock(fromIndex: 0, toIndex: 0);

    expect(change.isNoop, isTrue);
    expect(notifyCount, 0);
    expect(controller.canUndo, isFalse);
  });

  test('controller moves block ranges through the command interface', () {
    final controller = WenzRichTextController(
      document: _rangeMoveControllerDocument(),
      selection: collapsedTextSelection('h2', 1, 0),
    );
    var notifyCount = 0;
    var changedCount = 0;
    var selectionChangedCount = 0;
    EditorCommand? executedCommand;
    ChangeSet? executedChange;
    controller.addListener(() => notifyCount++);
    controller.onChanged = (_) => changedCount++;
    controller.onSelectionChanged = (_) => selectionChangedCount++;
    controller.onCommandExecuted = (command, change) {
      executedCommand = command;
      executedChange = change;
    };

    final change = controller.moveBlockRange(
      fromIndex: 1,
      count: 2,
      toIndex: 5,
    );

    expect(change.isNoop, isFalse);
    expect(controller.document.blocks.map((block) => block.id), <String>[
      'h1',
      'tail',
      'file',
      'h2',
      'p2',
    ]);
    expect(controller.selection, collapsedTextSelection('h2', 3, 7));
    expect(notifyCount, 1);
    expect(changedCount, 1);
    expect(selectionChangedCount, 1);
    expect(executedCommand, isA<MoveBlockRangeCommand>());
    expect(executedChange?.metadata?['blockIds'], <String>['h2', 'p2']);
    expect(executedChange?.metadata?['finalStartIndex'], 3);
    expect(controller.canUndo, isTrue);
  });

  test('controller block range move no-op does not notify', () {
    final controller = WenzRichTextController(
      document: _rangeMoveControllerDocument(),
    );
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    final change = controller.moveBlockRange(
      fromIndex: 1,
      count: 2,
      toIndex: 3,
    );

    expect(change.isNoop, isTrue);
    expect(notifyCount, 0);
    expect(controller.document.blocks.map((block) => block.id), <String>[
      'h1',
      'h2',
      'p2',
      'tail',
      'file',
    ]);
    expect(controller.canUndo, isFalse);
  });

  test('controller block range move respects edit permission', () {
    final controller = WenzRichTextController(
      document: _rangeMoveControllerDocument(),
      permission: WenzEditorPermission.read,
    );
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    final change = controller.moveBlockRange(
      fromIndex: 1,
      count: 2,
      toIndex: 5,
    );

    expect(change.isNoop, isTrue);
    expect(change.metadata, containsPair('reason', 'permissionDenied'));
    expect(change.metadata, containsPair('command', 'moveBlockRange'));
    expect(controller.document.blocks.map((block) => block.id), <String>[
      'h1',
      'h2',
      'p2',
      'tail',
      'file',
    ]);
    expect(notifyCount, 0);
    expect(controller.canUndo, isFalse);
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

  group('insert text block at selection', () {
    test('inserts above a cross-block selection and supports undo redo', () {
      final controller = WenzRichTextController(
        document: _textBlockInsertionDocument(),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 1,
          ),
          extent: DocumentPosition.text(
            blockId: 'p3',
            blockIndex: 2,
            offset: 5,
          ),
        ),
      );

      final change = controller.insertTextBlockAbove(blockId: 'new-above');

      expect(change.isNoop, isFalse);
      expect(_blockIds(controller.document), <String>[
        'new-above',
        'p1',
        'p2',
        'p3',
      ]);
      final inserted = controller.document.blocks.first as TextBlockNode;
      expect(inserted.type, BlockType.paragraph);
      expect(inserted.plainText, isEmpty);
      expect(controller.selection, collapsedTextSelection('new-above', 0, 0));
      expect(controller.canUndo, isTrue);

      expect(controller.undo(), isTrue);
      expect(_blockIds(controller.document), <String>['p1', 'p2', 'p3']);

      expect(controller.redo(), isTrue);
      expect(_blockIds(controller.document), <String>[
        'new-above',
        'p1',
        'p2',
        'p3',
      ]);
      expect(controller.selection, collapsedTextSelection('new-above', 0, 0));
    });

    test('inserts below a cross-block selection end', () {
      final controller = WenzRichTextController(
        document: _textBlockInsertionDocument(),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.text(
            blockId: 'p3',
            blockIndex: 2,
            offset: 5,
          ),
        ),
      );

      controller.insertTextBlockBelow(blockId: 'new-below');

      expect(_blockIds(controller.document), <String>[
        'p1',
        'p2',
        'p3',
        'new-below',
      ]);
      expect(controller.selection, collapsedTextSelection('new-below', 3, 0));
    });

    test('inserts below an object block selection', () {
      final controller = WenzRichTextController(
        document: _mixedInsertionDocument(),
        selection: _objectSelection('img1', 1),
      );

      controller.insertTextBlockBelow(blockId: 'after-image');

      expect(_blockIds(controller.document), <String>[
        'p1',
        'img1',
        'after-image',
        'code1',
        'table1',
        'p2',
      ]);
      final inserted = controller.document.blocks[2] as TextBlockNode;
      expect(inserted.type, BlockType.paragraph);
      expect(controller.selection, collapsedTextSelection('after-image', 2, 0));
    });

    test('inserts below a code block selection without copying code type', () {
      final controller = WenzRichTextController(
        document: _mixedInsertionDocument(),
        selection: collapsedCodeSelection('code1', 2, 2),
      );

      controller.insertTextBlockBelow(blockId: 'after-code');

      expect(_blockIds(controller.document), <String>[
        'p1',
        'img1',
        'code1',
        'after-code',
        'table1',
        'p2',
      ]);
      final inserted = controller.document.blocks[3] as TextBlockNode;
      expect(inserted.type, BlockType.paragraph);
      expect(inserted.plainText, isEmpty);
      expect(controller.selection, collapsedTextSelection('after-code', 3, 0));
    });

    test('inserts below a table cell selection at the top-level table boundary', () {
      final controller = WenzRichTextController(
        document: _mixedInsertionDocument(),
        selection: _tableCellSelection(blockIndex: 3, offset: 2),
      );

      controller.insertTextBlockBelow(blockId: 'after-table');

      expect(_blockIds(controller.document), <String>[
        'p1',
        'img1',
        'code1',
        'table1',
        'after-table',
        'p2',
      ]);
      final inserted = controller.document.blocks[4] as TextBlockNode;
      expect(inserted.type, BlockType.paragraph);
      expect(controller.selection, collapsedTextSelection('after-table', 4, 0));
    });

    test('respects edit permission', () {
      final controller = WenzRichTextController(
        document: _textBlockInsertionDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
        permission: WenzEditorPermission.read,
      );

      final change = controller.insertTextBlockBelow(blockId: 'blocked');

      expect(change.isNoop, isTrue);
      expect(change.metadata, containsPair('reason', 'permissionDenied'));
      expect(change.metadata, containsPair('command', 'insertTextBlockBelow'));
      expect(_blockIds(controller.document), <String>['p1', 'p2', 'p3']);
      expect(controller.canUndo, isFalse);
    });
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

  test('outline jump expands parent collapsed heading before selection', () {
    final controller =
        WenzRichTextController(document: _foldedOutlineDocument());
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    expect(outline.collapseByBlockId('h1'), isTrue);
    expect(outline.isBlockHidden('h2'), isTrue);

    expect(outline.selectByBlockId('h2', requestFocus: false), isTrue);

    expect(outline.isCollapsed('h1'), isFalse);
    expect(outline.isBlockHidden('h2'), isFalse);
    expect(controller.selection, collapsedTextSelection('h2', 2, 0));
  });

  test('collapsing heading moves covered selection to heading', () {
    final controller = WenzRichTextController(
      document: _foldedOutlineDocument(),
      selection: DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 1, offset: 0),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 3, offset: 6),
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    expect(outline.collapseByBlockId('h1'), isTrue);

    expect(outline.isCollapsed('h1'), isTrue);
    expect(controller.selection, collapsedTextSelection('h1', 0, 0));
  });

  test('programmatic selection expands collapsed outline ranges', () {
    final controller =
        WenzRichTextController(document: _foldedOutlineDocument());
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    expect(outline.collapseByBlockId('h2'), isTrue);
    expect(outline.collapseByBlockId('h1'), isTrue);
    expect(outline.isBlockHidden('p2'), isTrue);

    controller.setSelection(collapsedTextSelection('p2', 3, 6));

    expect(outline.collapsedBlockIds, isEmpty);
    expect(outline.isBlockHidden('p2'), isFalse);
    expect(controller.selection, collapsedTextSelection('p2', 3, 6));
  });

  test('controller sets and clears text color through public API', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Hello',
                attributes: TextAttributes(
                  background: 0xFFFFF59D,
                  bold: true,
                  url: 'https://example.com',
                ),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );

    controller.setTextColor(const Color(0xFF336699));

    var block = controller.document.blocks.single as TextBlockNode;
    var middle = block.content[1] as TextRun;
    expect(middle.attributes.color, 0xFF336699);
    expect(middle.attributes.background, 0xFFFFF59D);
    expect(middle.attributes.bold, isTrue);
    expect(middle.attributes.url, 'https://example.com');
    expect(controller.canUndo, isTrue);

    controller.clearTextColor();

    block = controller.document.blocks.single as TextBlockNode;
    final run = block.content.single as TextRun;
    expect(run.text, 'Hello');
    expect(run.attributes.color, isNull);
    expect(run.attributes.background, 0xFFFFF59D);
    expect(run.attributes.bold, isTrue);
    expect(run.attributes.url, 'https://example.com');
  });

  test('controller text color API respects edit permission', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Read only')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 4),
      permission: WenzEditorPermission.read,
    );

    final change = controller.setTextColorValue(0xFF336699);

    final block = controller.document.blocks.single as TextBlockNode;
    expect(change.isNoop, isTrue);
    expect(change.metadata, containsPair('reason', 'permissionDenied'));
    expect((block.content.single as TextRun).attributes.color, isNull);
    expect(controller.canUndo, isFalse);
  });
}

RichTextDocument _textBlockInsertionDocument() {
  return const RichTextDocument(
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
}

RichTextDocument _mixedInsertionDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'one')],
      ),
      ImageBlockNode(id: 'img1', assetId: 'asset1'),
      CodeBlockNode(id: 'code1', code: 'code'),
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
                    content: <InlineNode>[TextRun(text: 'cell')],
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
        content: <InlineNode>[TextRun(text: 'two')],
      ),
    ],
  );
}

DocumentSelection _objectSelection(String blockId, int blockIndex) {
  final start = DocumentPosition.object(
    blockId: blockId,
    blockIndex: blockIndex,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
}

DocumentSelection _tableCellSelection({
  required int blockIndex,
  int offset = 0,
}) {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: blockIndex,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

List<String> _blockIds(RichTextDocument document) {
  return document.blocks.map((block) => block.id).toList();
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

RichTextDocument _rangeMoveControllerDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Chapter')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Section')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body')],
      ),
      TextBlockNode(
        id: 'tail',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Tail')],
      ),
      FileBlockNode(
        id: 'file',
        assetId: 'asset-file',
        name: 'brief.pdf',
      ),
    ],
  );
}

RichTextDocument _foldedOutlineDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Chapter')],
      ),
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Section')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Nested body')],
      ),
      TextBlockNode(
        id: 'h3',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Next')],
      ),
    ],
  );
}
