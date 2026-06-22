import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/keyboard_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A 2x2 table whose cells each hold a single text block, used as the
  /// starting document for the table editing scenarios.
  const tableDocument = RichTextDocument(
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

  /// Collapsed caret inside table cell (row, column) at [offset].
  DocumentSelection cellCaret(int row, int column, int offset) {
    final pos = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: row,
      tableColumnIndex: column,
      offset: offset,
    );
    return DocumentSelection(base: pos, extent: pos);
  }

  String cellText(WenzRichTextController c, int row, int column) {
    final table = c.document.blocks.single as TableBlockNode;
    return table.table.cellAt(row, column)!.plainText;
  }

  group('table editing', () {
    testWidgets('typing inserts text inside the focused cell', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(0, 0, 2),
      );
      final controller = workbench.controller;

      await typeText(tester, controller, 'X');

      expect(cellText(controller, 0, 0), 'AAX');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    testWidgets('backspace deletes a character inside the cell', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(0, 0, 2),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.backspace);

      expect(cellText(controller, 0, 0), 'A');
      expect(controller.selection?.extent.offset, 1);
    });

    testWidgets('Tab moves the caret to the next cell', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(0, 0, 1),
      );
      final controller = workbench.controller;

      // Tab jumps directly from (0,0) to (0,1).
      await sendKey(tester, LogicalKeyboardKey.tab);
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 1);

      // A second Tab descends to the next row's first cell (1,0).
      await sendKey(tester, LogicalKeyboardKey.tab);
      expect(controller.selection?.extent.path.tableRowIndex, 1);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    testWidgets('Tab on the last cell inserts a new row', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(1, 1, 1),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.tab);

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.rowCount, 3);
      // Caret lands in the first column of the freshly added row.
      expect(controller.selection?.extent.path.tableRowIndex, 2);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    testWidgets('arrow up/down navigate across rows in the same column', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(0, 0, 1),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.selection?.extent.path.tableRowIndex, 1);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
      expect(controller.selection?.extent.offset, 1);

      await sendKey(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    testWidgets('enter inserts a newline inside the cell, not a new block', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: tableDocument,
        selection: cellCaret(0, 0, 1),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.enter);

      // Still a single block (the table); the cell text gained a newline.
      expect(controller.document.blocks, hasLength(1));
      expect(cellText(controller, 0, 0), 'A\nA');
    });

    testWidgets('select-all covers table cell content for copy', (tester) async {
      // A document mixing a paragraph and a table. selectAll should select a
      // range whose copy payload includes the table cell text, so the whole
      // document is selectable end-to-end.
      const mixedDocument = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'intro')],
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
                ],
              ],
            ),
          ),
        ],
      );
      final workbench = await pumpWorkbench(tester, document: mixedDocument);
      final controller = workbench.controller;

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);

      // The selection must span the whole document (paragraph + table).
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      // Copy the selection; the payload must include both the paragraph text
      // and the table cell text.
      final payload = controller.copySelection();
      expect(payload, isNotNull);
      expect(payload, contains('intro'));
      expect(payload, contains('AA'));
      // The table cell must show a selection highlight, not just the paragraph.
      expect(isSelectionHighlightVisible(tester), isTrue);
    });

    testWidgets('clicking inside a non-empty cell places the caret at the '
        'tapped offset', (tester) async {
      // A cell with enough text that distinct x-coordinates resolve to distinct
      // caret offsets. The click must land near the tapped character, not jump
      // to the cell start/end.
      const cellDoc = RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'abcdefghij')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      await pumpWorkbench(tester, document: cellDoc);

      // Tap around the middle of the cell text (offset ~5).
      await tapAtTextOffset(tester, 'abcdefghij', 5);

      final controller = workbenchControllerOf(tester);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      // The resolved offset must be near 5 — not clamped to 0 or the cell end.
      expect(controller.selection?.extent.offset, inInclusiveRange(4, 6));
    });

    testWidgets('clicking an empty cell places the caret at offset 0', (
      tester,
    ) async {
      // An empty cell renders a placeholder space so it has height, but the
      // registered text length is 0. A click anywhere in the cell must resolve
      // to a valid collapsed caret at offset 0, not an out-of-range offset.
      const emptyCellDoc = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-empty',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-empty-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      await pumpWorkbench(tester, document: emptyCellDoc);

      // The empty cell renders a single-space placeholder RichText.
      await tapAtTextOffset(tester, ' ', 0);

      final controller = workbenchControllerOf(tester);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 0);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('clicking a cell in a multi-cell table lands in the right '
        'cell', (tester) async {
      // A 2x2 table. Clicking the bottom-right cell must resolve the caret to
      // THAT cell, not a neighbour — the hit-test must pick the cell whose
      // render box contains the click, accounting for padding/borders.
      await pumpWorkbench(tester, document: tableDocument);

      // 'DD' lives in cell (1,1). Tap its middle.
      await tapAtTextOffset(tester, 'DD', 1);

      final controller = workbenchControllerOf(tester);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.path.tableRowIndex, 1,
          reason: 'click on DD must land in row 1');
      expect(controller.selection?.extent.path.tableColumnIndex, 1,
          reason: 'click on DD must land in column 1');
      expect(controller.selection?.extent.offset, inInclusiveRange(0, 2));
    });

    testWidgets('successive clicks on different cells each land correctly', (
      tester,
    ) async {
      // Click cell (0,0)=AA, then cell (1,1)=DD. Each click must reposition the
      // caret into the clicked cell — a stale drag/multi-click state must not
      // make the second click resolve to the first cell or clamp wrongly.
      await pumpWorkbench(tester, document: tableDocument);

      await tapAtTextOffset(tester, 'AA', 1);
      var controller = workbenchControllerOf(tester);
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);

      await tapAtTextOffset(tester, 'DD', 1);
      controller = workbenchControllerOf(tester);
      expect(controller.selection?.extent.path.tableRowIndex, 1,
          reason: 'second click must move into row 1');
      expect(controller.selection?.extent.path.tableColumnIndex, 1,
          reason: 'second click must move into column 1');
    });
  });
}

/// Resolves the active controller from the editor widget under test.
WenzRichTextController workbenchControllerOf(WidgetTester tester) {
  final widget = tester.widget<WenzRichTextEditor>(
    find.byType(WenzRichTextEditor),
  );
  return widget.controller;
}
