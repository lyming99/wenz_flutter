import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('ToolbarController', () {
    test('reports empty state when host has no selection', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: null,
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.state.hasSelection, isFalse);
      expect(toolbar.canFormatInline, isFalse);
      expect(toolbar.canToggleMark, isFalse);
      expect(toolbar.canSetLink, isFalse);
      expect(toolbar.canSetBlockType, isFalse);
      expect(toolbar.bold, isFalse);
      expect(toolbar.uniformBlockType, isNull);

      toolbar.dispose();
      host.dispose();
    });

    test('collapsed caret inherits typing attributes from left run', () {
      final host = WenzRichTextController(
        document: _doc(),
        // "He|llo big world" — caret between He and llo, left run is bold.
        selection: collapsedTextSelection('mixed', 0, 2),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.bold, isTrue, reason: 'left run is bold');
      expect(toolbar.italic, isFalse);

      toolbar.dispose();
      host.dispose();
    });

    test('collapsed caret after the bold run drops the mark', () {
      final host = WenzRichTextController(
        document: _doc(),
        // After the bold "Hello", at offset 5 of block 0 — plain run.
        selection: collapsedTextSelection('mixed', 0, 5),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.bold, isFalse);

      toolbar.dispose();
      host.dispose();
    });

    test('range fully bold reports bold active', () {
      final host = WenzRichTextController(
        document: _doc(),
        // Only the first run 'He' (bold) is covered, range 0..2.
        selection: textSelection('mixed', 0, 0, 2),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.canToggleMark, isTrue);
      expect(toolbar.bold, isTrue);

      toolbar.dispose();
      host.dispose();
    });

    test('range half-bold reports not active (indeterminate)', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('mixed', 0, 0, 8),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.bold, isFalse, reason: 'part bold, part plain');

      toolbar.dispose();
      host.dispose();
    });

    test('range spanning two different marks reports both inactive', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('two', 1, 0, 10),
      );
      final toolbar = ToolbarController(host);

      // 'boldRun' (8 chars, bold) + 'italicRun' (9 chars, italic).
      expect(toolbar.bold, isFalse);
      expect(toolbar.italic, isFalse);

      toolbar.dispose();
      host.dispose();
    });

    test('link URL active when whole range shares the same url', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('linked', 2, 0, 3),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.linkUrl, 'https://wenz.dev');

      toolbar.dispose();
      host.dispose();
    });

    test('link URL null when range mixes URLs', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('linked', 2, 0, 7),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.linkUrl, isNull,
          reason: 'first run linked, second run not');

      toolbar.dispose();
      host.dispose();
    });

    test('link URL for collapsed caret is the left run url', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('linked', 2, 1),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.linkUrl, 'https://wenz.dev');

      toolbar.dispose();
      host.dispose();
    });

    group('block type detection', () {
      test('heading level 1', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('h1', 3, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isHeading(1), isTrue);
        expect(toolbar.isHeading(2), isFalse);
        expect(toolbar.isParagraph, isFalse);
        expect(toolbar.uniformBlockType, BlockType.heading);
        expect(toolbar.uniformHeadingLevel, 1);

        toolbar.dispose();
        host.dispose();
      });

      test('paragraph', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('para', 4, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isParagraph, isTrue);
        expect(toolbar.isHeading(1), isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('quote', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('quote', 5, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isQuoteBlock, isTrue);

        toolbar.dispose();
        host.dispose();
      });

      test('task list', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('task', 6, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isTodo, isTrue);
        expect(toolbar.isOrderedList, isFalse);
        expect(toolbar.isUnorderedList, isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('ordered list', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('ol', 7, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isOrderedList, isTrue);
        expect(toolbar.isTodo, isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('unordered list (listType null)', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('ul', 8, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isUnorderedList, isTrue);
        expect(toolbar.isOrderedList, isFalse);
        expect(toolbar.isTodo, isFalse);

        toolbar.dispose();
        host.dispose();
      });
    });

    group('enable state mirrors command noop guards', () {
      test('non-text block disables inline toggles and link', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedCodeSelection('code', 9, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canFormatInline, isFalse);
        expect(toolbar.canToggleMark, isFalse);
        expect(toolbar.canSetLink, isFalse);
        // Code block is not a text block; SetBlockTypeCommand only switches
        // text-block types, so the toolbar must refuse.
        expect(toolbar.canSetBlockType, isFalse);
        expect(toolbar.canSetCodeLanguage, isTrue);
        expect(toolbar.codeLanguage, 'dart');

        toolbar.dispose();
        host.dispose();
      });

      test(
          'cross-block range disables single-block toggles but keeps '
          'FormatTextCommand-capable read', () {
        // Range spanning paragraph (4) → quote (5), same path 'text'.
        final start = DocumentPosition.text(
          blockId: 'para',
          blockIndex: 4,
          offset: 0,
        );
        final end = DocumentPosition.text(
          blockId: 'quote',
          blockIndex: 5,
          offset: 5,
        );
        final host = WenzRichTextController(
          document: _doc(),
          selection: DocumentSelection(base: start, extent: end),
        );
        final toolbar = ToolbarController(host);

        // ToggleMarkCommand / SetLinkCommand require a single block + path.
        expect(toolbar.canToggleMark, isFalse);
        expect(toolbar.canSetLink, isFalse);
        // SetBlockTypeCommand still operates on text blocks across the range.
        expect(toolbar.canSetBlockType, isTrue);
        expect(toolbar.uniformBlockType, isNull,
            reason: 'spans paragraph + quote → no uniform type');

        toolbar.dispose();
        host.dispose();
      });

      test('range of mixed block types reports no uniform type', () {
        // Span paragraph (4) → quote (5).
        final start = DocumentPosition.text(
          blockId: 'para',
          blockIndex: 4,
          offset: 0,
        );
        final end = DocumentPosition.text(
          blockId: 'quote',
          blockIndex: 5,
          offset: 5,
        );
        final host = WenzRichTextController(
          document: _doc(),
          selection: DocumentSelection(base: start, extent: end),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.uniformBlockType, isNull);
        expect(toolbar.isParagraph, isFalse);
        expect(toolbar.isQuoteBlock, isFalse);
        expect(toolbar.canSetBlockType, isTrue,
            reason: 'both blocks are text blocks, switchable');

        toolbar.dispose();
        host.dispose();
      });
    });

    group('mutating helpers', () {
      test('toggleBold clears the mark on an all-bold range', () {
        final host = WenzRichTextController(
          document: _doc(),
          // Only the first run 'He' (bold), range 0..2.
          selection: textSelection('mixed', 0, 0, 2),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.bold, isTrue);
        toolbar.toggleBold();
        expect(toolbar.bold, isFalse, reason: 'toggled off');
        expect(
          ((host.document.blocks.first as TextBlockNode).content.first
                  as TextRun)
              .attributes
              .bold,
          isNull,
        );

        toolbar.dispose();
        host.dispose();
      });

      test('toggleBold is a no-op when selection is null', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: null,
        );
        final toolbar = ToolbarController(host);

        // Must not throw and must not mutate.
        toolbar.toggleBold();
        expect(host.document.plainText, _doc().plainText);

        toolbar.dispose();
        host.dispose();
      });

      test('setHeading(2) changes the block type', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('para', 4, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isParagraph, isTrue);
        toolbar.setHeading(2);
        expect(toolbar.isHeading(2), isTrue);
        expect(toolbar.isParagraph, isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('setParagraph reverts a heading back', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('h1', 3, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isHeading(1), isTrue);
        toolbar.setParagraph();
        expect(toolbar.isParagraph, isTrue);

        toolbar.dispose();
        host.dispose();
      });

      test('setLink writes a url and clearStyle wipes it', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: textSelection('mixed', 0, 0, 5),
        );
        final toolbar = ToolbarController(host);

        toolbar.setLink('https://x.dev');
        expect(toolbar.linkUrl, 'https://x.dev');

        toolbar.clearStyle();
        expect(toolbar.linkUrl, isNull);
        expect(toolbar.bold, isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('setCodeLanguage updates the current code block', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedCodeSelection('code', 9, 0),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canSetCodeLanguage, isTrue);
        expect(toolbar.codeLanguage, 'dart');

        toolbar.setCodeLanguage('python');

        expect(toolbar.codeLanguage, 'python');
        expect((host.document.blocks[9] as CodeBlockNode).language, 'python');
        expect(host.canUndo, isTrue);

        toolbar.dispose();
        host.dispose();
      });

      test('notifies listeners when host changes', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: collapsedTextSelection('para', 4, 0),
        );
        final toolbar = ToolbarController(host);
        var notified = 0;
        toolbar.addListener(() => notified++);

        toolbar.setHeading(2);
        expect(notified, greaterThanOrEqualTo(1));

        toolbar.dispose();
        host.dispose();
      });
    });

    group('mark active predicate', () {
      test('isMarkActive(TextMark.bold) matches the bold accessor', () {
        final host = WenzRichTextController(
          document: _doc(),
          selection: textSelection('mixed', 0, 0, 5),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.isMarkActive(TextMark.bold), toolbar.bold);
        expect(toolbar.isMarkActive(TextMark.italic), toolbar.italic);

        toolbar.dispose();
        host.dispose();
      });
    });

    group('table context', () {
      test('caret inside a table cell enables inline toggles, link and struct',
          () {
        final position = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        );
        final host = WenzRichTextController(
          document: _tableDoc(),
          selection: DocumentSelection(base: position, extent: position),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canTableStruct, isTrue);
        expect(toolbar.canFormatInline, isTrue,
            reason: 'cell text path supports inline formatting');
        expect(toolbar.canToggleMark, isTrue,
            reason: 'cell text path supports mark toggles');
        expect(toolbar.canSetLink, isTrue,
            reason: 'cell text path supports links');

        toolbar.dispose();
        host.dispose();
      });

      test('cell style selectors stay populated after style changes', () {
        final position = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        );
        final host = WenzRichTextController(
          document: _tableDoc(),
          selection: DocumentSelection(base: position, extent: position),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canTableStruct, isTrue);
        expect(toolbar.tableCellIsHeader, isFalse);
        expect(toolbar.tableCellBackgroundColor, isNull);

        host.setTableCellBackground(
          blockIndex: 0,
          rowIndex: 0,
          columnIndex: 0,
          backgroundColor: 0xFFFFEEAA,
        );
        expect(toolbar.canTableStruct, isTrue);
        expect(toolbar.tableCellBackgroundColor, 0xFFFFEEAA);
        expect(host.selection?.extent.path.isTableCellText, isTrue);

        host.setTableCellHeader(
          blockIndex: 0,
          rowIndex: 0,
          columnIndex: 0,
          isHeader: true,
        );
        expect(toolbar.tableCellIsHeader, isTrue);
        expect(toolbar.tableCellBackgroundColor, 0xFFFFEEAA);

        toolbar.dispose();
        host.dispose();
      });

      test('range inside a bold table cell reports the mark active', () {
        const document = RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c0',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c0p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(
                                text: 'cel',
                                attributes: TextAttributes(bold: true)),
                            TextRun(
                                text: 'l',
                                attributes: TextAttributes(bold: true)),
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
        final start = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        );
        final end = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 4,
        );
        final host = WenzRichTextController(
          document: document,
          selection: DocumentSelection(base: start, extent: end),
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.bold, isTrue, reason: 'every cell run is bold');

        toolbar.dispose();
        host.dispose();
      });

      test('toggleBold preserves a table cell range selection', () {
        final start = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        );
        final end = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 4,
        );
        final selection = DocumentSelection(base: start, extent: end);
        final host = WenzRichTextController(
          document: _tableDoc(),
          selection: selection,
        );
        final toolbar = ToolbarController(host);

        toolbar.toggleBold();

        expect(host.selection, selection);
        final table = host.document.blocks.single as TableBlockNode;
        final textBlock =
            table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
        expect((textBlock.content.single as TextRun).attributes.bold, isTrue);

        toolbar.dispose();
        host.dispose();
      });
    });

    test('permission state disables edit actions', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('mixed', 0, 2),
        permission: WenzEditorPermission.comment,
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.canFormatInline, isFalse);
      expect(toolbar.canToggleMark, isFalse);
      expect(toolbar.canSetLink, isFalse);
      expect(toolbar.canSetBlockType, isFalse);

      host.permission = WenzEditorPermission.edit;

      expect(toolbar.canFormatInline, isTrue);
      expect(toolbar.canToggleMark, isTrue);
      expect(toolbar.canSetLink, isTrue);
      expect(toolbar.canSetBlockType, isTrue);

      toolbar.dispose();
      host.dispose();
    });
  });
}

/// A document exercising the interesting toolbar inputs. Block ids are the
/// labels the tests reference via [collapsedTextSelection]/[textSelection];
/// the `blockIndex` arguments match the order below.
RichTextDocument _doc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      // 0 — mixed: 'He' bold + 'llo big world' plain.
      TextBlockNode(
        id: 'mixed',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'He', attributes: TextAttributes(bold: true)),
          TextRun(text: 'llo big world'),
        ],
      ),
      // 1 — two runs of different marks: 'boldRun' bold + 'italicRun' italic.
      TextBlockNode(
        id: 'two',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'boldRun', attributes: TextAttributes(bold: true)),
          TextRun(text: 'italicRun', attributes: TextAttributes(italic: true)),
        ],
      ),
      // 2 — linked: 'abc' link + 'defg' plain.
      TextBlockNode(
        id: 'linked',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'abc',
            attributes: TextAttributes(url: 'https://wenz.dev'),
          ),
          TextRun(text: 'defg'),
        ],
      ),
      // 3 — heading level 1.
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Title')],
      ),
      // 4 — plain paragraph.
      TextBlockNode(
        id: 'para',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'A paragraph.')],
      ),
      // 5 — quote.
      TextBlockNode(
        id: 'quote',
        type: BlockType.quote,
        content: <InlineNode>[TextRun(text: 'Quoted text')],
      ),
      // 6 — task list item.
      TextBlockNode(
        id: 'task',
        type: BlockType.listItem,
        attributes: BlockAttributes(listType: 'task', checked: false),
        content: <InlineNode>[TextRun(text: 'Task')],
      ),
      // 7 — ordered list item.
      TextBlockNode(
        id: 'ol',
        type: BlockType.listItem,
        attributes: BlockAttributes(listType: 'ordered'),
        content: <InlineNode>[TextRun(text: 'Ordered')],
      ),
      // 8 — unordered list item (listType null = canonical unordered).
      TextBlockNode(
        id: 'ul',
        type: BlockType.listItem,
        content: <InlineNode>[TextRun(text: 'Unordered')],
      ),
      // 9 — code block.
      CodeBlockNode(id: 'code', language: 'dart', code: 'final x = 1;'),
    ],
  );
}

RichTextDocument _tableDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'c0',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c0p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'cell')],
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
