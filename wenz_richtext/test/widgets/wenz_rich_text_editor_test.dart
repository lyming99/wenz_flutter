import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('renders document blocks', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[
              TextRun(text: 'Roadmap', attributes: TextAttributes(bold: true)),
            ],
          ),
          TextBlockNode(
            id: 'task1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'Ship core')],
          ),
          CodeBlockNode(
            id: 'code1',
            code: 'final done = true;',
            language: 'dart',
          ),
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
                        content: <InlineNode>[TextRun(text: 'Cell A')],
                      ),
                    ],
                  ),
                ],
              ],
              columnAlignments: <int, String>{0: 'center'},
            ),
          ),
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          DividerBlockNode(id: 'divider1'),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(_richText('Roadmap'), findsOneWidget);
    expect(_richText('Ship core'), findsOneWidget);
    expect(find.text('[x]'), findsOneWidget);
    expect(_richText('final done = true;'), findsOneWidget);
    expect(_richText('Cell A'), findsOneWidget);
    expect(find.text('[image: hero.png]'), findsOneWidget);
    expect(find.text('[video: clip]'), findsOneWidget);
  });

  testWidgets('rebuilds when controller document changes', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(_richText('Hi'), findsOneWidget);

    controller.insertText('!');
    await tester.pump();

    expect(_richText('Hi!'), findsOneWidget);
  });

  testWidgets('handles keyboard text, deletion, and enter', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();
    expect(controller.document.plainText, 'Hia');
    expect(_richTextIgnoringCaret('Hia'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.document.plainText, 'Hi');
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.document.blocks, hasLength(2));
    expect(controller.selection?.extent.blockIndex, 1);
  });

  testWidgets('keyboard text and backspace edit table cells', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'Hi')],
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
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 2,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 2,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();

    var table = controller.document.blocks.single as TableBlockNode;
    var cellText = table.table.cellAt(0, 0)!.plainText;
    expect(cellText, 'Hia');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    table = controller.document.blocks.single as TableBlockNode;
    cellText = table.table.cellAt(0, 0)!.plainText;
    expect(cellText, 'Hi');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('enter inserts newline inside table cell', (tester) async {
    final position = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 1,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'Hi')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(base: position, extent: position),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, 'H\ni');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('table cell arrow keys and tab navigate cells', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
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
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p2',
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
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
    expect(controller.selection?.extent.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('moves focused caret with arrow keys', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection?.extent.offset, 1);
    expect(_richTextIgnoringCaret('Hi'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('extends selection with shift and arrow keys', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.base.offset, 2);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('tap editable block places caret at block end', (tester) async {
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'Hi', 2);
    await tester.pump();

    expect(controller.selection?.extent.blockId, 'p1');
    expect(controller.selection?.extent.offset, 2);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
  });

  testWidgets('tap text uses text layout to place caret at offset', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'abcdef', 3);
    await tester.pump();

    expect(controller.selection?.extent.offset, 3);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
  });

  testWidgets('dragging text creates highlighted selection range', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'abcdef', 1);
    final end = _globalTextOffset(tester, 'abcdef', 4);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.base.offset, inInclusiveRange(1, 2));
    expect(controller.selection?.extent.offset, 4);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('dragging across table cells creates table cell range', (
    tester,
  ) async {
    final controller = WenzRichTextController(
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
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'AA', 1);
    final end = _globalTextOffset(tester, 'DD', 1);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.base.path.isTableCellText, isTrue);
    expect(selection.extent.path.isTableCellText, isTrue);
    expect(selection.base.path.tableRowIndex, 0);
    expect(selection.base.path.tableColumnIndex, 0);
    expect(selection.extent.path.tableRowIndex, 1);
    expect(selection.extent.path.tableColumnIndex, 1);

    final range = selection.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 0);
    expect(range.endRow, 1);
    expect(range.startColumn, 0);
    expect(range.endColumn, 1);
    expect(range.containsCell(0, 1), isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsAtLeastNWidgets(4),
    );
  });

  testWidgets('read-only mode still allows placing a selection', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'abcdef', 3);
    await tester.pump();

    // Selection is updated even in read-only mode (for copy workflows).
    expect(controller.selection, isNotNull);
    expect(controller.selection?.extent.offset, 3);
    // No editing caret is rendered in read-only mode.
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsNothing,
    );
  });

  testWidgets('read-only mode blocks text insertion via keyboard', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();

    // Document is unchanged because read-only mode swallows editing keys.
    expect(controller.document.plainText, 'abc');
  });

  testWidgets('C0 control characters are not inserted', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // U+0001 (SOH) is a C0 control character that is not \n/\r/\t.
    await tester.sendKeyEvent(
      LogicalKeyboardKey.keyA,
      character: String.fromCharCode(0x01),
    );
    await tester.pump();

    expect(controller.document.plainText, 'ab');
  });

  testWidgets('debug overlay renders selection tag when enabled', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            showDebugOverlay: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // The debug tag surfaces the block id and path string.
    expect(find.textContaining('#0 p1'), findsOneWidget);
    expect(find.textContaining('block/p1/text'), findsOneWidget);
  });

  testWidgets('Ctrl+A selects the whole editable range', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.offset, 6);
  });

  testWidgets('Ctrl+Z / Ctrl+Shift+Z undo and redo', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
    await tester.pump();
    expect(controller.document.plainText, 'abc');

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(controller.document.plainText, 'ab');

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    await tester.pump();
    expect(controller.document.plainText, 'abc');
  });

  testWidgets('Home and End move to block boundaries', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.selection?.extent.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(controller.selection?.extent.offset, 6);
  });

  testWidgets('Ctrl+Left/Right move by word', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'foo bar')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 4);

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('read-only mode still allows Ctrl+A select-all', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.end.offset, 6);
  });

  testWidgets('cross-block drag extends selection across paragraphs', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ghijkl')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: WenzRichTextEditor(controller: controller),
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'abcdef', 1);
    final end = _globalTextOffset(tester, 'ghijkl', 3);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.isCollapsed, isFalse);
    // The drag started in p1 and ended in p2 — a genuine cross-block selection.
    expect(controller.selection!.start.blockId, 'p1');
    expect(controller.selection!.end.blockId, 'p2');
  });

  testWidgets('double-tap selects a word', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello world')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller),
        ),
      ),
    );

    // Tap twice on the word "hello" quickly.
    final target = _globalTextOffset(tester, 'hello world', 2);
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    // "hello" occupies offsets 0..5.
    expect(controller.selection!.start.offset, 0);
    expect(controller.selection!.end.offset, 5);
  });

  testWidgets('triple-tap selects the whole block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello world')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller),
        ),
      ),
    );

    final target = _globalTextOffset(tester, 'hello world', 2);
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection!.start.offset, 0);
    expect(controller.selection!.end.offset, 'hello world'.length);
  });
}

Future<void> _sendCtrlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

Finder _richTextIgnoringCaret(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText().replaceAll('\uFFFC', '') == text,
    description: 'RichText with plain text "$text" ignoring caret',
  );
}

Future<void> _tapTextOffset(
  WidgetTester tester,
  String text,
  int offset,
) async {
  await tester.tapAt(_globalTextOffset(tester, text, offset));
}

Offset _globalTextOffset(WidgetTester tester, String text, int offset) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) +
      local +
      Offset(1, painter.preferredLineHeight / 2);
}
