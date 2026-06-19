import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  const service = ClipboardService();

  group('ClipboardService.copy', () {
    test('returns null for a collapsed selection', () {
      final doc = _doc('Hello');
      expect(service.copy(doc, collapsedTextSelection('p1', 0, 0)), isNull);
    });

    test('same-block range produces a rich payload with the magic prefix', () {
      final doc = _doc('Hello');
      final sel = textSelection('p1', 0, 1, 4);
      final payload = service.copy(doc, sel);

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      // The payload parses back to the selected slice 'ell'.
      expect(service.parse(payload).text, 'ell');
    });

    test('same-block range preserves run attributes on parse', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'He', attributes: TextAttributes(bold: true)),
              TextRun(text: 'llo'),
            ],
          ),
        ],
      );
      final sel = textSelection('p1', 0, 1, 4); // 'ell'
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'ell');
      // The slice crosses the bold/plain boundary: 'e' (bold) + 'll' (plain).
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
    });

    test('cross-block range falls back to plain text joined by newlines', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'def')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'p2',
          blockIndex: 1,
          path: PositionPath.blockText('p2'),
          offset: 2,
        ),
      );
      final payload = service.copy(doc, sel);

      expect(payload, 'bc\nde');
    });

    test('code block range copies plain text slice', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'abcdef'),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 4,
        ),
      );
      expect(service.copy(doc, sel), 'bcd');
    });

    test('table cell range produces a rich payload from the selected cell', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(1, 4));

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      expect(service.parse(payload).text, 'ell');
    });

    test('table cell range preserves run attributes on parse', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(0, 4))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hell');
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
    });

    test('table cell range copies as TSV plain text', () {
      final doc = _tableRangeDoc();

      expect(service.copy(doc, _tableRangeSelection()), 'AA\tBB\nCC\tDD');
      expect(service.copy(doc, _reversedTableRangeSelection()), 'AA\tBB\nCC\tDD');
    });
  });

  group('ClipboardService.parse', () {
    test('rich payload round-trips through parse', () {
      final doc = _doc('Hello');
      final payload = service.copy(doc, textSelection('p1', 0, 0, 5))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hello');
    });

    test('plain text is parsed as plain', () {
      final paste = service.parse('just text');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'just text');
    });

    test('plain text preserves newlines for multi-line paste', () {
      final paste = service.parse('line one\nline two\nline three');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'line one\nline two\nline three');
    });
  });

  group('controller paste integration', () {
    test('paste plain single line inserts at caret', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('XY');

      expect(controller.document.plainText, 'aXYb');
      expect(controller.selection?.extent.offset, 3);
    });

    test('paste plain multi-line splits into blocks', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('X\nYY\nZ');

      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.plainText, 'aX\nYY\nZb');
    });

    test('paste rich payload preserves attributes', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'bold', attributes: TextAttributes(bold: true)),
            ],
          ),
        ],
      );
      final payload = service.copy(
        source,
        textSelection('p1', 0, 0, 4),
      )!;

      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      final block = controller.document.blocks.single as TextBlockNode;
      final pastedRun =
          block.content.whereType<TextRun>().firstWhere((r) => r.text == 'bold');
      expect(pastedRun.attributes.bold, isTrue);
    });

    test('cut deletes the selection and returns the payload', () {
      final controller = WenzRichTextController(
        document: _doc('abcdef'),
        selection: textSelection('p1', 0, 1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(controller.document.plainText, 'aef');
    });

    test('cut deletes a table cell selection and returns its payload', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _tableCellSelection(1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(service.parse(payload!).text, 'ell');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'Ho');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 1);
    });

    test('cut clears a table cell range and returns TSV', () {
      final controller = WenzRichTextController(
        document: _tableRangeDoc(),
        selection: _tableRangeSelection(),
      );

      final payload = controller.cutSelection();

      expect(payload, 'AA\tBB\nCC\tDD');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, '');
      expect(table.table.cellAt(0, 1)!.plainText, '');
      expect(table.table.cellAt(1, 0)!.plainText, '');
      expect(table.table.cellAt(1, 1)!.plainText, '');
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    test('paste plain single line inserts into table cell', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _collapsedTableCellSelection(2),
      );

      controller.pasteText('XY');

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'HeXYllo');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 4);
    });

    test('paste rich payload preserves attributes inside table cell', () {
      final payload = service.copy(_tableDoc(), _tableCellSelection(0, 2))!;
      final controller = WenzRichTextController(
        document: _plainTableDoc('ab'),
        selection: _collapsedTableCellSelection(1),
      );

      controller.pasteText(payload);

      final table = controller.document.blocks.single as TableBlockNode;
      final cellBlock = table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
      final pastedRun = cellBlock.content
          .whereType<TextRun>()
          .firstWhere((run) => run.text.contains('He'));
      expect(table.table.cellAt(0, 0)!.plainText, 'aHeb');
      expect(pastedRun.text, 'He');
      expect(pastedRun.attributes.bold, isTrue);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
    });
  });
}

RichTextDocument _doc(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}

RichTextDocument _tableDoc([String plainTail = 'llo']) {
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
                    content: <InlineNode>[
                      const TextRun(
                        text: 'He',
                        attributes: TextAttributes(bold: true),
                      ),
                      TextRun(text: plainTail),
                    ],
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

RichTextDocument _plainTableDoc(String text) {
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

RichTextDocument _tableRangeDoc() {
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
    base: _tableCellPositionAt(row: 0, column: 0),
    extent: _tableCellPositionAt(row: 1, column: 1),
  );
}

DocumentSelection _reversedTableRangeSelection() {
  return DocumentSelection(
    base: _tableCellPositionAt(row: 1, column: 1),
    extent: _tableCellPositionAt(row: 0, column: 0),
  );
}

DocumentPosition _tableCellPositionAt({required int row, required int column}) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: row,
    tableColumnIndex: column,
    offset: 0,
  );
}

DocumentSelection _tableCellSelection(int start, int end) {
  return DocumentSelection(
    base: _tableCellPosition(start),
    extent: _tableCellPosition(end),
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
