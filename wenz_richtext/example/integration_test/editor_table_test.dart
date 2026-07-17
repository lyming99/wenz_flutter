import 'package:flutter/material.dart';
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

  RichTextDocument scrollingTableDocument() {
    return RichTextDocument(
      blocks: <BlockNode>[
        for (var i = 0; i < 4; i++)
          TextBlockNode(
            id: 'before-table-$i',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before table $i')],
          ),
        tableDocument.blocks.single,
        for (var i = 0; i < 16; i++)
          TextBlockNode(
            id: 'after-table-$i',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After table $i')],
          ),
      ],
    );
  }

  DocumentSelection scrollingTableCellCaret() {
    final pos = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 4,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    );
    return DocumentSelection(base: pos, extent: pos);
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

    testWidgets('toolbar alignment entry sets selected table cell alignment', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: tableDocument,
        selection: cellCaret(0, 0, 0),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                IconButton(
                  tooltip: '单元格居中对齐',
                  onPressed: toolbar.canSetAlignment
                      ? () => toolbar.setAlignment('center')
                      : null,
                  icon: const Icon(Icons.format_align_center),
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('单元格居中对齐'));
      await tester.pump();

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.attributes.alignment, isNull);
      expect(table.table.columnAlignments, isEmpty);
      expect(table.table.cellAt(0, 0)!.alignment, 'center');
      expect(table.table.cellAt(0, 1)!.alignment, isNull);
      expect(toolbar.alignment, 'center');
      expect(toolbar.alignmentMixed, isFalse);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(_richTextAlign(tester, 'AA'), TextAlign.center);
    });

    testWidgets('toolbar alignment cycles through left center right justify', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: tableDocument,
        selection: cellCaret(0, 0, 0),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: '左对齐',
                      onPressed: toolbar.canSetAlignment
                          ? () => toolbar.setAlignment('left')
                          : null,
                      icon: const Icon(Icons.format_align_left),
                    ),
                    IconButton(
                      tooltip: '居中对齐',
                      onPressed: toolbar.canSetAlignment
                          ? () => toolbar.setAlignment('center')
                          : null,
                      icon: const Icon(Icons.format_align_center),
                    ),
                    IconButton(
                      tooltip: '右对齐',
                      onPressed: toolbar.canSetAlignment
                          ? () => toolbar.setAlignment('right')
                          : null,
                      icon: const Icon(Icons.format_align_right),
                    ),
                    IconButton(
                      tooltip: '两端对齐',
                      onPressed: toolbar.canSetAlignment
                          ? () => toolbar.setAlignment('justify')
                          : null,
                      icon: const Icon(Icons.format_align_justify),
                    ),
                    IconButton(
                      tooltip: '清除对齐',
                      onPressed: toolbar.canSetAlignment
                          ? () => toolbar.clearAlignment()
                          : null,
                      icon: const Icon(Icons.format_clear),
                    ),
                  ],
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      TableBlockNode table() =>
          controller.document.blocks.single as TableBlockNode;

      // 'left' alignment: cell alignment stored; rendering follows.
      await tester.tap(find.byTooltip('左对齐'));
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'left');
      expect(_richTextAlign(tester, 'AA'), TextAlign.start);
      expect(toolbar.alignment, 'left');

      // 'center' alignment.
      await tester.tap(find.byTooltip('居中对齐'));
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'center');
      expect(_richTextAlign(tester, 'AA'), TextAlign.center);
      expect(toolbar.alignment, 'center');

      // 'right' alignment.
      await tester.tap(find.byTooltip('右对齐'));
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'right');
      expect(_richTextAlign(tester, 'AA'), TextAlign.right);
      expect(toolbar.alignment, 'right');

      // 'justify' alignment.
      await tester.tap(find.byTooltip('两端对齐'));
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'justify');
      expect(_richTextAlign(tester, 'AA'), TextAlign.justify);
      expect(toolbar.alignment, 'justify');
    });

    testWidgets('toolbar clears cell alignment restoring column fallback', (
      tester,
    ) async {
      // Document where column 0 has a column-level alignment of 'right'.
      const columnAlignedDoc = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              columnAlignments: <int, String>{0: 'right'},
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a',
                    alignment: 'center', // Cell-level overrides column.
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b',
                    // No cell alignment — falls back to column.
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellB')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );

      final controller = WenzRichTextController(
        document: columnAlignedDoc,
        selection: DocumentSelection(
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
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
        ),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                IconButton(
                  tooltip: '清除对齐',
                  onPressed: toolbar.canSetAlignment
                      ? () => toolbar.clearAlignment()
                      : null,
                  icon: const Icon(Icons.format_clear),
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      TableBlockNode table() =>
          controller.document.blocks.single as TableBlockNode;

      // Cell (0,0) has explicit 'center' overriding column 'right'.
      expect(_richTextAlign(tester, 'CellA'), TextAlign.center);
      // Cell (0,1) has no explicit alignment, falls back to column 'right'.
      expect(_richTextAlign(tester, 'CellB'), TextAlign.right);

      // Clear alignment on cell (0,0).
      await tester.tap(find.byTooltip('清除对齐'));
      await tester.pump();

      expect(table().table.cellAt(0, 0)!.alignment, isNull);
      // After clearing, falls back to column alignment 'right'.
      expect(_richTextAlign(tester, 'CellA'), TextAlign.right);
      expect(toolbar.alignment, isNull);
    });

    testWidgets('toolbar alignment applies to multi-cell rectangular selection', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: tableDocument,
        selection: DocumentSelection(
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
        ),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                IconButton(
                  tooltip: '单元格右对齐',
                  onPressed: toolbar.canSetAlignment
                      ? () => toolbar.setAlignment('right')
                      : null,
                  icon: const Icon(Icons.format_align_right),
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('单元格右对齐'));
      await tester.pump();

      final table = controller.document.blocks.single as TableBlockNode;
      // Every cell in the 2×2 rectangle should now be right-aligned.
      expect(table.table.cellAt(0, 0)!.alignment, 'right');
      expect(table.table.cellAt(0, 1)!.alignment, 'right');
      expect(table.table.cellAt(1, 0)!.alignment, 'right');
      expect(table.table.cellAt(1, 1)!.alignment, 'right');
      // Column alignment is never mutated by cell alignment actions.
      expect(table.attributes.alignment, isNull);
      expect(table.table.columnAlignments, isEmpty);
      // Visual rendering: each cell's RichText uses TextAlign.right.
      expect(_richTextAlign(tester, 'AA'), TextAlign.right);
      expect(_richTextAlign(tester, 'BB'), TextAlign.right);
      expect(_richTextAlign(tester, 'CC'), TextAlign.right);
      expect(_richTextAlign(tester, 'DD'), TextAlign.right);
    });

    testWidgets('cell alignment persists across Tab navigation and back', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: tableDocument,
        selection: cellCaret(0, 0, 0),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                IconButton(
                  tooltip: '单元格居中对齐',
                  onPressed: toolbar.canSetAlignment
                      ? () => toolbar.setAlignment('center')
                      : null,
                  icon: const Icon(Icons.format_align_center),
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Set alignment on cell (0,0) to 'center'.
      await tester.tap(find.byTooltip('单元格居中对齐'));
      await tester.pump();
      expect(_richTextAlign(tester, 'AA'), TextAlign.center);

      // Tab to (0,1). The alignment on the new cell is whatever it already was
      // (no explicit alignment for 'BB'), so it renders with start/default.
      await sendKey(tester, LogicalKeyboardKey.tab);
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 1);
      expect(_richTextAlign(tester, 'BB'), TextAlign.start);

      // Tab to (1,0).
      await sendKey(tester, LogicalKeyboardKey.tab);
      expect(controller.selection?.extent.path.tableRowIndex, 1);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);

      // Tab to (1,1), then wrap back to (0,0) (last cell Tab inserts a row,
      // so use Shift+Tab from (1,0) back up to (0,1) then to (0,0)).
      await sendKey(tester, LogicalKeyboardKey.tab);
      expect(controller.selection?.extent.path.tableRowIndex, 1);
      expect(controller.selection?.extent.path.tableColumnIndex, 1);

      // Shift+Tab twice to get back to (0,0).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.selection?.extent.path.tableRowIndex, 1);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);

      // After navigating back, the 'center' alignment on cell (0,0) is preserved.
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.alignment, 'center');
      expect(_richTextAlign(tester, 'AA'), TextAlign.center);
    });

    testWidgets('undo redo restores cell alignment state', (tester) async {
      final controller = WenzRichTextController(
        document: tableDocument,
        selection: cellCaret(0, 0, 0),
      );
      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                IconButton(
                  tooltip: '单元格右对齐',
                  onPressed: toolbar.canSetAlignment
                      ? () => toolbar.setAlignment('right')
                      : null,
                  icon: const Icon(Icons.format_align_right),
                ),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      TableBlockNode table() =>
          controller.document.blocks.single as TableBlockNode;

      // Initially, cell (0,0) has no alignment.
      expect(table().table.cellAt(0, 0)!.alignment, isNull);
      expect(_richTextAlign(tester, 'AA'), TextAlign.start);

      // Set alignment to 'right'.
      await tester.tap(find.byTooltip('单元格右对齐'));
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'right');
      expect(_richTextAlign(tester, 'AA'), TextAlign.right);

      // Undo: alignment should revert to null.
      expect(controller.canUndo, isTrue);
      controller.undo();
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, isNull);
      expect(_richTextAlign(tester, 'AA'), TextAlign.start);

      // Redo: alignment should be restored to 'right'.
      expect(controller.canRedo, isTrue);
      controller.redo();
      await tester.pump();
      expect(table().table.cellAt(0, 0)!.alignment, 'right');
      expect(_richTextAlign(tester, 'AA'), TextAlign.right);
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

    testWidgets(
        'table floating toolbar hides offscreen and returns on scroll back',
        (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: scrollingTableDocument(),
        selection: scrollingTableCellCaret(),
      );

      await _pumpTableToolbarOverlay(tester);

      final toolbarFinder =
          find.byKey(const ValueKey<String>('table-floating-toolbar'));
      expect(toolbarFinder, findsOneWidget);
      expect(workbench.controller.selection?.tableCellRange, isNotNull);

      final scrollableFinder = find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      final initialOffset = scrollable.position.pixels;
      expect(scrollable.position.maxScrollExtent, greaterThan(initialOffset));

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await _pumpTableToolbarOverlay(tester);
      expect(toolbarFinder, findsNothing);

      scrollable.position.jumpTo(initialOffset);
      await _pumpTableToolbarOverlay(tester);
      expect(toolbarFinder, findsOneWidget);
      expect(workbench.controller.selection?.tableCellRange, isNotNull);
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

    testWidgets('cross-cell drag produces normalized table cell range', (
      tester,
    ) async {
      // 3×3 table: drag from (row=2, col=2) to (row=0, col=0).
      // The bounding-box rectangle must span rows 0-2, cols 0-2.
      const crossCellDoc = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'r0c0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r0c0-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r0c1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r0c1-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BB')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r0c2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r0c2-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CC')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'r1c0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r1c0-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'DD')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r1c1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r1c1-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'EE')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r1c2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r1c2-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'FF')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'r2c0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r2c0-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'GG')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r2c1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r2c1-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'HH')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'r2c2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r2c2-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'II')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      await pumpWorkbench(tester, document: crossCellDoc);

      // Drag from bottom-right cell (II, row=2,col=2) to top-left (AA, row=0,col=0).
      final start = globalOffsetAt(tester, 'II', 1); // row=2, col=2
      final end = globalOffsetAt(tester, 'AA', 1); // row=0, col=0

      // Perform drag from II to AA.
      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final selection = workbenchControllerOf(tester).selection;
      expect(selection, isNotNull);

      final range = selection!.tableCellRange;
      expect(range, isNotNull,
          reason: 'cross-cell drag must produce a non-null tableCellRange');
      expect(range!.tableBlockId, 'table1');
      // Normalized: startRow=0, endRow=2, startColumn=0, endColumn=2.
      expect(range.startRow, 0);
      expect(range.endRow, 2);
      expect(range.startColumn, 0);
      expect(range.endColumn, 2);
      // All 9 cells should be in range.
      for (var r = 0; r <= 2; r++) {
        for (var c = 0; c <= 2; c++) {
          expect(range.containsCell(r, c), isTrue,
              reason: 'cell ($r,$c) must be inside rectangle (0,0)-(2,2)');
        }
      }
      expect(range.isSingleCell, isFalse);
      // Highlights must be present (text selection within cells).
      expect(isSelectionHighlightVisible(tester), isTrue);
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

TextAlign _richTextAlign(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
  return tester.widget<RichText>(finder).textAlign;
}

Future<void> _pumpTableToolbarOverlay(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
