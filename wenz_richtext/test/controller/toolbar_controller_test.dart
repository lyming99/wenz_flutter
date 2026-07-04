import 'package:flutter/widgets.dart';
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

    test('text color reports uniform, mixed, and empty states', () {
      final uniformHost = WenzRichTextController(
        document: _doc(),
        selection: textSelection('colored', 10, 0, 3),
      );
      final uniformToolbar = ToolbarController(uniformHost);

      expect(uniformToolbar.textColor, 0xFF336699);
      expect(uniformToolbar.textColorMixed, isFalse);

      final mixedHost = WenzRichTextController(
        document: _doc(),
        selection: textSelection('colored', 10, 0, 8),
      );
      final mixedToolbar = ToolbarController(mixedHost);

      expect(mixedToolbar.textColor, isNull);
      expect(mixedToolbar.textColorMixed, isTrue);

      final emptyHost = WenzRichTextController(
        document: _doc(),
        selection: textSelection('para', 4, 0, 3),
      );
      final emptyToolbar = ToolbarController(emptyHost);

      expect(emptyToolbar.textColor, isNull);
      expect(emptyToolbar.textColorMixed, isFalse);

      uniformToolbar.dispose();
      uniformHost.dispose();
      mixedToolbar.dispose();
      mixedHost.dispose();
      emptyToolbar.dispose();
      emptyHost.dispose();
    });

    test('collapsed caret reports left run text color', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('colored', 10, 2),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.textColor, 0xFF336699);
      expect(toolbar.textColorMixed, isFalse);

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

      test('cell alignment helper sets and clears the selected cell', () {
        final position = DocumentPosition.tableCell(
          tableBlockId: 'table',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        );
        final selection = DocumentSelection(base: position, extent: position);
        final host = WenzRichTextController(
          document: _tableDoc(),
          selection: selection,
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canSetAlignment, isTrue);
        expect(toolbar.alignment, isNull);
        expect(toolbar.alignmentMixed, isFalse);
        expect(toolbar.isAlignment(null), isTrue);

        toolbar.setAlignment('center');

        var table = host.document.blocks.single as TableBlockNode;
        expect(table.table.cellAt(0, 0)?.alignment, 'center');
        expect(table.attributes.alignment, isNull);
        expect(table.table.columnAlignments, isEmpty);
        expect(toolbar.alignment, 'center');
        expect(toolbar.isAlignment('center'), isTrue);
        expect(host.selection, selection);

        toolbar.clearAlignment();

        table = host.document.blocks.single as TableBlockNode;
        expect(table.table.cellAt(0, 0)?.alignment, isNull);
        expect(toolbar.alignment, isNull);
        expect(toolbar.alignmentMixed, isFalse);

        toolbar.dispose();
        host.dispose();
      });

      test('multi-cell alignment reports uniform mixed and covered states', () {
        final uniformHost = WenzRichTextController(
          document: _tableAlignmentDoc(
            firstAlignment: 'center',
            secondAlignment: 'center',
          ),
          selection: _tableSelection(0, 0, 0, 1),
        );
        final uniformToolbar = ToolbarController(uniformHost);

        expect(uniformToolbar.canSetAlignment, isTrue);
        expect(uniformToolbar.alignment, 'center');
        expect(uniformToolbar.alignmentMixed, isFalse);

        final mixedHost = WenzRichTextController(
          document: _tableAlignmentDoc(
            firstAlignment: 'center',
            secondAlignment: 'right',
          ),
          selection: _tableSelection(0, 0, 0, 1),
        );
        final mixedToolbar = ToolbarController(mixedHost);

        expect(mixedToolbar.canSetAlignment, isTrue);
        expect(mixedToolbar.alignment, isNull);
        expect(mixedToolbar.alignmentMixed, isTrue);

        final coveredHost = WenzRichTextController(
          document: _tableAlignmentDoc(
            firstAlignment: 'center',
            secondAlignment: 'right',
            secondCovered: true,
          ),
          selection: _tableSelection(0, 0, 0, 1),
        );
        final coveredToolbar = ToolbarController(coveredHost);

        expect(coveredToolbar.canSetAlignment, isTrue);
        expect(coveredToolbar.alignment, 'center');
        expect(coveredToolbar.alignmentMixed, isFalse);

        uniformToolbar.dispose();
        uniformHost.dispose();
        mixedToolbar.dispose();
        mixedHost.dispose();
        coveredToolbar.dispose();
        coveredHost.dispose();
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

      test('range inside a colored table cell reports text color', () {
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

        toolbar.setTextColorValue(0xFF336699);

        expect(host.selection, selection);
        expect(toolbar.textColor, 0xFF336699);
        expect(toolbar.textColorMixed, isFalse);
        final table = host.document.blocks.single as TableBlockNode;
        final textBlock =
            table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
        expect((textBlock.content.single as TextRun).attributes.color,
            0xFF336699);

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

      test('table structure helpers insert row and column at current cell', () {
        final host = WenzRichTextController(
          document: _twoByTwoTableDoc(),
          selection: _tableSelection(0, 0, 0, 0),
        );
        final toolbar = ToolbarController(host);

        toolbar.insertTableRow();
        var table = host.document.blocks.single as TableBlockNode;
        expect(table.table.rowCount, 3);
        expect(table.table.columnCount, 2);
        expect(host.canUndo, isTrue);

        toolbar.insertTableColumn();
        table = host.document.blocks.single as TableBlockNode;
        expect(table.table.rowCount, 3);
        expect(table.table.columnCount, 3);

        toolbar.dispose();
        host.dispose();
      });

      test('table structure helpers delete row and column at current cell', () {
        final host = WenzRichTextController(
          document: _twoByTwoTableDoc(),
          selection: _tableSelection(0, 0, 0, 0),
        );
        final toolbar = ToolbarController(host);

        toolbar.deleteTableRow();
        var table = host.document.blocks.single as TableBlockNode;
        expect(table.table.rowCount, 1);
        expect(table.table.columnCount, 2);

        toolbar.deleteTableColumn();
        table = host.document.blocks.single as TableBlockNode;
        expect(table.table.rowCount, 1);
        expect(table.table.columnCount, 1);

        toolbar.dispose();
        host.dispose();
      });

      test('merge and split helpers use the selected table cell range', () {
        final host = WenzRichTextController(
          document: _twoByTwoTableDoc(),
          selection: _tableSelection(0, 0, 0, 1),
        );
        final toolbar = ToolbarController(host);

        toolbar.mergeTableCells();
        var table = host.document.blocks.single as TableBlockNode;
        expect(table.table.cellAt(0, 0)?.columnSpan, 2);
        expect(table.table.cellAt(0, 1)?.covered, isTrue);

        toolbar.splitTableCell();
        table = host.document.blocks.single as TableBlockNode;
        expect(table.table.cellAt(0, 0)?.columnSpan, 1);
        expect(table.table.cellAt(0, 1)?.covered, isFalse);

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
      expect(toolbar.canSetAlignment, isFalse);
      expect(toolbar.canInsertImage, isFalse);

      toolbar.setAlignment('center');
      expect(
        (host.document.blocks.first as TextBlockNode).attributes.alignment,
        isNull,
      );
      expect(host.canUndo, isFalse);

      host.permission = WenzEditorPermission.edit;

      expect(toolbar.canFormatInline, isTrue);
      expect(toolbar.canToggleMark, isTrue);
      expect(toolbar.canSetLink, isTrue);
      expect(toolbar.canSetBlockType, isTrue);
      expect(toolbar.canSetAlignment, isTrue);
      expect(toolbar.canInsertImage, isTrue);

      toolbar.dispose();
      host.dispose();
    });

    test('image object selection exposes alignment and preserves undo state', () {
      final selection = _objectSelection('img', 0, 1);
      final host = WenzRichTextController(
        document: _imageAlignmentDoc(imageAlignment: 'right'),
        selection: selection,
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.canSetAlignment, isTrue);
      expect(toolbar.alignment, 'right');
      expect(toolbar.alignmentMixed, isFalse);
      expect(toolbar.isAlignment('right'), isTrue);
      expect(toolbar.canFormatInline, isFalse);

      toolbar.setAlignment('left');

      var image = host.document.blocks.first as ImageBlockNode;
      expect(image.attributes.alignment, 'left');
      expect(host.selection, selection);
      expect(toolbar.alignment, 'left');
      expect(host.canUndo, isTrue);

      expect(host.undo(), isTrue);
      image = host.document.blocks.first as ImageBlockNode;
      expect(image.attributes.alignment, 'right');
      expect(host.selection, selection);

      expect(host.redo(), isTrue);
      image = host.document.blocks.first as ImageBlockNode;
      expect(image.attributes.alignment, 'left');
      expect(toolbar.alignment, 'left');

      toolbar.clearAlignment();

      image = host.document.blocks.first as ImageBlockNode;
      expect(image.attributes.alignment, isNull);
      expect(toolbar.alignment, isNull);
      expect(toolbar.alignmentMixed, isFalse);
      expect(host.selection, selection);

      toolbar.dispose();
      host.dispose();
    });

    test('image alignment reports mixed across object and text blocks', () {
      final host = WenzRichTextController(
        document: _imageAlignmentDoc(
          imageAlignment: 'center',
          paragraphAlignment: 'right',
        ),
        selection: DocumentSelection(
          base: DocumentPosition.object(blockId: 'img', blockIndex: 0),
          extent: DocumentPosition.text(
            blockId: 'caption-after',
            blockIndex: 1,
            offset: 0,
          ),
        ),
      );
      final toolbar = ToolbarController(host);

      expect(toolbar.canSetAlignment, isTrue);
      expect(toolbar.alignment, isNull);
      expect(toolbar.alignmentMixed, isTrue);
      expect(toolbar.isAlignment('center'), isFalse);

      toolbar.dispose();
      host.dispose();
    });

    test('image alignment actions are no-op without edit permission', () {
      for (final permission in <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        final host = WenzRichTextController(
          document: _imageAlignmentDoc(imageAlignment: 'center'),
          selection: _objectSelection('img', 0, 1),
          permission: permission,
        );
        final toolbar = ToolbarController(host);

        expect(toolbar.canSetAlignment, isFalse);
        expect(toolbar.alignment, 'center');
        expect(toolbar.alignmentMixed, isFalse);

        toolbar.setAlignment('left');
        toolbar.clearAlignment();

        final image = host.document.blocks.first as ImageBlockNode;
        expect(image.attributes.alignment, 'center');
        expect(host.canUndo, isFalse);

        toolbar.dispose();
        host.dispose();
      }
    });

    test('insertImage uses the current text block insertion index', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('para', 4, 0),
      );
      final toolbar = ToolbarController(host);

      toolbar.insertImage(
        blockId: 'img1',
        file: '/tmp/hero.png',
        caption: 'Hero',
        altText: 'Hero alt',
      );

      expect(host.document.blocks[4], isA<ImageBlockNode>());
      final image = host.document.blocks[4] as ImageBlockNode;
      expect(image.id, 'img1');
      expect(image.file, '/tmp/hero.png');
      expect(image.caption, 'Hero');
      expect(image.altText, 'Hero alt');
      expect(host.document.blocks[5].id, 'para');

      toolbar.dispose();
      host.dispose();
    });

    test('insertImage after a selected object block inserts after the object',
        () {
      final host = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'existing', assetId: 'asset-1'),
            TextBlockNode(
              id: 'after',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: _objectSelection('existing', 0, 1),
      );
      final toolbar = ToolbarController(host);

      toolbar.insertImage(blockId: 'img2', file: '/tmp/after-object.png');

      expect(host.document.blocks[0].id, 'existing');
      expect(host.document.blocks[1], isA<ImageBlockNode>());
      expect(host.document.blocks[1].id, 'img2');
      expect(host.document.blocks[2].id, 'after');

      toolbar.dispose();
      host.dispose();
    });

    test('insertImage from a table cell inserts after the table block', () {
      final cellPosition = DocumentPosition.tableCell(
        tableBlockId: 'table',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 2,
      );
      final host = WenzRichTextController(
        document: _tableDoc(),
        selection: DocumentSelection(base: cellPosition, extent: cellPosition),
      );
      final toolbar = ToolbarController(host);

      toolbar.insertImage(blockId: 'img3', file: '/tmp/from-cell.png');

      expect(host.document.blocks, hasLength(2));
      expect(host.document.blocks[0], isA<TableBlockNode>());
      expect(host.document.blocks[1], isA<ImageBlockNode>());
      expect(host.document.blocks[1].id, 'img3');

      toolbar.dispose();
      host.dispose();
    });

    test('default block insert helpers use current insertion semantics', () {
      final codeHost = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('para', 4, 0),
      );
      final codeToolbar = ToolbarController(codeHost);

      codeToolbar.insertCodeBlock(blockId: 'code-new', code: 'print(1);');
      expect(codeHost.document.blocks[4], isA<CodeBlockNode>());
      expect(codeHost.document.blocks[4].id, 'code-new');
      expect((codeHost.document.blocks[4] as CodeBlockNode).code, 'print(1);');
      expect(codeHost.document.blocks[5].id, 'para');

      codeToolbar.dispose();
      codeHost.dispose();

      final calloutHost = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('para', 4, 0),
      );
      final calloutToolbar = ToolbarController(calloutHost);

      calloutToolbar.insertCallout(blockId: 'callout-new', title: 'Note');
      expect(calloutHost.document.blocks[4], isA<CalloutBlockNode>());
      expect(calloutHost.document.blocks[4].id, 'callout-new');
      expect(
        (calloutHost.document.blocks[4] as CalloutBlockNode).title,
        'Note',
      );

      calloutToolbar.dispose();
      calloutHost.dispose();

      final tableHost = WenzRichTextController(
        document: _doc(),
        selection: collapsedTextSelection('para', 4, 0),
      );
      final tableToolbar = ToolbarController(tableHost);

      tableToolbar.insertTable(
        tableId: 'table-new',
        rowCount: 2,
        columnCount: 4,
      );
      expect(tableHost.document.blocks[4], isA<TableBlockNode>());
      final table = tableHost.document.blocks[4] as TableBlockNode;
      expect(table.id, 'table-new');
      expect(table.table.rowCount, 2);
      expect(table.table.columnCount, 4);

      tableToolbar.dispose();
      tableHost.dispose();
    });

    test('insertVideo uses the current object-block insertion index', () {
      final host = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'existing', assetId: 'asset-1'),
            TextBlockNode(
              id: 'after',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: _objectSelection('existing', 0, 1),
      );
      final toolbar = ToolbarController(host);

      toolbar.insertVideo(
        blockId: 'video-new',
        assetId: 'asset-video',
        file: '/tmp/video.mp4',
        title: 'Video',
      );

      expect(host.document.blocks[0].id, 'existing');
      expect(host.document.blocks[1], isA<VideoBlockNode>());
      final video = host.document.blocks[1] as VideoBlockNode;
      expect(video.id, 'video-new');
      expect(video.assetId, 'asset-video');
      expect(video.file, '/tmp/video.mp4');
      expect(video.title, 'Video');
      expect(host.document.blocks[2].id, 'after');

      toolbar.dispose();
      host.dispose();
    });

    test('set and clear text color preserve other inline attributes', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('colored', 10, 1, 3),
      );
      final toolbar = ToolbarController(host);

      toolbar.setTextColor(const Color(0xFFE91E63));

      var block = host.document.blocks[10] as TextBlockNode;
      var middle = block.content[1] as TextRun;
      expect(middle.text, 'ol');
      expect(middle.attributes.color, 0xFFE91E63);
      expect(middle.attributes.bold, isTrue);
      expect(toolbar.textColor, 0xFFE91E63);
      expect(toolbar.textColorMixed, isFalse);

      toolbar.clearTextColor();

      block = host.document.blocks[10] as TextBlockNode;
      final run = block.content.single as TextRun;
      expect(run.text, 'Colored');
      expect(run.attributes.color, isNull);
      expect(run.attributes.bold, isTrue);
      expect(toolbar.textColor, isNull);
      expect(toolbar.textColorMixed, isFalse);

      toolbar.dispose();
      host.dispose();
    });

    test('text color actions are no-op when formatting is disabled', () {
      final host = WenzRichTextController(
        document: _doc(),
        selection: textSelection('colored', 10, 0, 3),
        permission: WenzEditorPermission.comment,
      );
      final toolbar = ToolbarController(host);

      toolbar.setTextColorValue(0xFFE91E63);
      toolbar.clearTextColor();

      final block = host.document.blocks[10] as TextBlockNode;
      expect((block.content.first as TextRun).attributes.color, 0xFF336699);
      expect(host.canUndo, isFalse);

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
      // 10 — colored: 'Col' blue+bold + 'ored' plain.
      TextBlockNode(
        id: 'colored',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Col',
            attributes: TextAttributes(color: 0xFF336699, bold: true),
          ),
          TextRun(text: 'ored'),
        ],
      ),
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

RichTextDocument _twoByTwoTableDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'c00',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c00p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c01',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c01p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'c10',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c10p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'C')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c11',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c11p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'D')],
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

DocumentSelection _tableSelection(
  int startRow,
  int startColumn,
  int endRow,
  int endColumn,
) {
  return DocumentSelection(
    base: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: startRow,
      tableColumnIndex: startColumn,
      offset: 0,
    ),
    extent: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: endRow,
      tableColumnIndex: endColumn,
      offset: 0,
    ),
  );
}

RichTextDocument _tableAlignmentDoc({
  String? firstAlignment,
  String? secondAlignment,
  bool secondCovered = false,
}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'c0',
                alignment: firstAlignment,
                blocks: const <BlockNode>[
                  TextBlockNode(
                    id: 'c0p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'left')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c1',
                alignment: secondAlignment,
                covered: secondCovered,
                blocks: const <BlockNode>[
                  TextBlockNode(
                    id: 'c1p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'right')],
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

RichTextDocument _imageAlignmentDoc({
  String? imageAlignment,
  String? paragraphAlignment,
}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      ImageBlockNode(
        id: 'img',
        assetId: 'asset',
        width: 320,
        height: 180,
        attributes: BlockAttributes(alignment: imageAlignment),
      ),
      TextBlockNode(
        id: 'caption-after',
        type: BlockType.paragraph,
        attributes: BlockAttributes(alignment: paragraphAlignment),
        content: const <InlineNode>[TextRun(text: 'after image')],
      ),
    ],
  );
}

DocumentSelection _objectSelection(
  String blockId,
  int blockIndex,
  int offset,
) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}
