import 'package:flutter/gestures.dart';
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

  testWidgets('exposes block semantics labels and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'h2',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Plan')],
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Alpha')],
            ),
            CodeBlockNode(id: 'code1', code: 'print(1);', language: 'dart'),
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          ],
        ),
        selection: textSelection('p1', 1, 0, 5),
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

      expect(find.bySemanticsLabel('Heading block level 2'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Paragraph block, selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Code block'), findsOneWidget);
      expect(find.bySemanticsLabel('Image block hero.png'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('exposes table and merged cell semantics labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'header',
                      isHeader: true,
                      rowSpan: 2,
                      columnSpan: 2,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'header-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Merged')],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'covered-right', covered: true),
                    TableCellNode(
                      id: 'top-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'top-right-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Q1')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(id: 'covered-bottom-left', covered: true),
                    TableCellNode(id: 'covered-bottom-right', covered: true),
                    TableCellNode(
                      id: 'bottom-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'bottom-right-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Done')],
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
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'table1',
            blockIndex: 0,
            tableRowIndex: 1,
            tableColumnIndex: 2,
            offset: 0,
          ),
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

      expect(
        find.bySemanticsLabel('Table block, 2 rows, 3 columns'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Table cell row 1 column 1, header, spans 2 rows, '
          'spans 2 columns, selected',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Table cell row 1 column 3, selected'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Table cell row 2 column 3, selected'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Table cell row 1 column 2'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('renders formula and mention inline embeds', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Ask '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' from '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
            ],
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
                        id: 'cell-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[
                          TextRun(text: 'Score '),
                          InlineEmbed(
                            embedType: 'formula',
                            data: <String, Object?>{'text': 'a+b'},
                          ),
                        ],
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

    expect(_richText('Ask x^2 from @Ada'), findsOneWidget);
    expect(_richText('Score a+b'), findsOneWidget);
  });

  testWidgets('allows custom inline embed text rendering', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' with '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
            ],
          ),
        ],
      ),
    );
    final renderer = InlineEmbedRendererCallback((context, embed, style) {
      if (embed.embedType == 'formula') {
        return TextSpan(text: 'formula(${embed.data['text']})', style: style);
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            inlineEmbedRenderer: renderer,
          ),
        ),
      ),
    );

    expect(_richText('Solve formula(x^2) with @Ada'), findsOneWidget);
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

    // Forward Tab on the last cell inserts a new row and lands the caret in
    // its first column (row 1, column 0).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 1);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);

    // Shift+Tab walks back to the previous (originally last) cell, with the
    // caret placed at its end.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 0);
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('table cell arrow up/down navigate across rows', (tester) async {
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
                ],
                <TableCellNode>[
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 1);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 0);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 1);
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

  testWidgets('arrow down crosses to the next paragraph block', (tester) async {
    // Two single-line paragraph blocks. ArrowDown from the end of p1 should
    // advance into p2 (the caret's last visual line == the block boundary).
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'first')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'second')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection?.extent.blockId, 'p2');
    expect(controller.selection?.extent.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // Up from the start of p2 returns to the end of p1.
    expect(controller.selection?.extent.blockId, 'p1');
    expect(controller.selection?.extent.offset, 5);
  });

  testWidgets('held arrow key (auto-repeat) moves the caret each repeat', (
    tester,
  ) async {
    // Holding a key down fires KeyDownEvent then repeated KeyRepeatEvents.
    // Each repeat must advance the caret, otherwise the view appears frozen
    // while a key is held.
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

    // Initial press.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 1);

    // Auto-repeat events while the key stays down.
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 3);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 3);
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

  testWidgets('tap image block selects the image object', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
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

    await tester.tapAt(tester.getCenter(find.text('[image: hero.png]')));
    await tester.pump();

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.isCollapsed, isFalse);
    expect(selection.start.blockId, 'image1');
    expect(selection.start.offset, 0);
    expect(selection.end.blockId, 'image1');
    expect(selection.end.offset, 1);
    expect(selection.extent.path.isBlockObject, isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('tap below a trailing image appends a paragraph', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('tap below a trailing table appends a paragraph', (tester) async {
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
                        content: <InlineNode>[TextRun(text: 'cell')],
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
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('ArrowDown from a trailing image appends a paragraph', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
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

    await tester.tapAt(tester.getCenter(find.text('[image: hero.png]')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('ArrowDown from a trailing table appends a paragraph', (
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
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
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

    await _tapTextOffset(tester, 'cell', 4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
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

  testWidgets('merged table cell spans covered columns for hit testing', (
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
                    columnSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Anchor')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b',
                    covered: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Covered')],
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

    expect(find.text('Covered'), findsNothing);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(
      Offset(editorRect.right - 24, editorRect.top + 22),
    );
    await tester.pump();

    final extent = controller.selection?.extent;
    expect(extent, isNotNull);
    expect(extent!.path.isTableCellText, isTrue);
    expect(extent.path.tableRowIndex, 0);
    expect(extent.path.tableColumnIndex, 0);
  });

  testWidgets('merged table cell spans covered rows for hit testing', (
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
                    rowSpan: 2,
                    columnSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Anchor')],
                      ),
                    ],
                  ),
                  TableCellNode(id: 'cell-b', covered: true),
                ],
                <TableCellNode>[
                  TableCellNode(id: 'cell-c', covered: true),
                  TableCellNode(id: 'cell-d', covered: true),
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

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(
      Offset(editorRect.right - 24, editorRect.top + 56),
    );
    await tester.pump();

    final extent = controller.selection?.extent;
    expect(extent, isNotNull);
    expect(extent!.path.isTableCellText, isTrue);
    expect(extent.path.tableRowIndex, 0);
    expect(extent.path.tableColumnIndex, 0);
  });

  testWidgets(
      'selection from a table cell into a later block highlights later cells', (
    tester,
  ) async {
    final start = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 1,
    );
    final end = DocumentPosition.text(
      blockId: 'p2',
      blockIndex: 1,
      offset: 3,
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
      selection: DocumentSelection(base: start, extent: end),
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
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsAtLeastNWidgets(4),
    );
  });

  testWidgets('read-only mode still allows placing a selection',
      (tester) async {
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

  testWidgets('IME composition underline only decorates the composing text', (
    tester,
  ) async {
    const text = 'Controller commands own document';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: text)],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 20),
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
    controller.setCompositionState(
      CompositionState(
        blockId: 'p1',
        blockIndex: 0,
        path: PositionPath.blockText('p1'),
        startOffset: 11,
        endOffset: 19,
      ),
    );
    await tester.pump();

    final richText = tester.widget<RichText>(_richText(text));

    expect(_underlinedTexts(richText.text), <String>['commands']);
  });

  testWidgets('re-reports IME geometry after growing content auto-scrolls', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'start')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 64,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    controller.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.log.clear();
    final scrollBefore = _scrollOffset(tester);

    controller.insertText(
      '\nline 1\nline 2\nline 3\nline 4\nline 5\nline 6',
    );
    await tester.pump();

    expect(_scrollOffset(tester), greaterThan(scrollBefore));
    tester.testTextInput.log.clear();

    await tester.pump();

    expect(
      tester.testTextInput.log.where(
          (call) => call.method == 'TextInput.setEditableSizeAndTransform'),
      isNotEmpty,
    );
  });

  testWidgets('platform selectors dispatch to editor commands', (tester) async {
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
      selection: collapsedTextSelection('p1', 0, 11),
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

    await _performPlatformSelectors(tester, <String>['moveLeft:']);
    await tester.pump();

    expect(controller.selection?.extent.offset, 10);

    controller.setSelection(collapsedTextSelection('p1', 0, 11));
    await tester.pump();

    await _performPlatformSelectors(tester, <String>['deleteWordBackward:']);
    await tester.pump();

    expect(controller.document.plainText, 'hello ');
    expect(controller.selection?.extent.offset, 6);
  });

  testWidgets('Backspace deletes an expanded selection', (tester) async {
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
      selection: textSelection('p1', 0, 1, 4),
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

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('Delete deletes an expanded selection', (tester) async {
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
      selection: textSelection('p1', 0, 1, 4),
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

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('platform delete selector deletes an expanded selection', (
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
      selection: textSelection('p1', 0, 1, 4),
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

    await _performPlatformSelectors(tester, <String>['deleteBackward:']);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
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

  testWidgets('Ctrl+A selects a lone image block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
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

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.blockId, 'image1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'image1');
    expect(controller.selection?.end.path.isBlockObject, isTrue);
    expect(controller.selection?.end.offset, 1);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('Delete after Ctrl+A leaves one empty paragraph', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          ImageBlockNode(id: 'image2', assetId: 'hero2', file: 'hero2.png'),
        ],
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

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final block = controller.document.blocks.single;
    expect(block, isA<TextBlockNode>());
    expect((block as TextBlockNode).content, isEmpty);
    expect(block.type, BlockType.paragraph);
    expect(controller.selection?.extent.blockIndex, 0);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
    expect(controller.selection?.extent.offset, 0);
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

  // B2: auto-scroll-on-drag. A mouse drag held near a viewport edge drives a
  // per-frame ticker that keeps scrolling and re-extends the selection, so the
  // user can drag-select past the visible area without moving the pointer.
  group('auto-scroll on drag', () {
    // A tall document: many short paragraphs whose combined height exceeds the
    // 150px viewport, so the bottom edge sits mid-document and there is room
    // to scroll down.
    RichTextDocument tallDocument({int count = 30}) => RichTextDocument(
          blocks: List<BlockNode>.generate(
            count,
            (i) => TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'block-$i-content')],
            ),
          ),
        );

    testWidgets('dragging the scrollbar gutter does not start a selection', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child:
                  WenzRichTextEditor(controller: controller, enableIme: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Place an initial collapsed caret in the content so we can detect any
      // spurious change.
      final contentPoint = _globalTextOffset(tester, 'block-0-content', 2);
      await tester.tapAt(contentPoint);
      await tester.pump();
      expect(controller.selection, isNotNull);
      final selectionBefore = controller.selection;

      // Drag vertically inside the trailing scrollbar gutter (rightmost 16px).
      // The gutter is within _kScrollbarGutterWidth of the editor's right edge.
      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      final gutterX = editorBox.right - 8;
      final gesture = await tester.startGesture(
        Offset(gutterX, editorBox.top + 30),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(Offset(gutterX, editorBox.top + 90));
      await gesture.up();
      await tester.pump();

      // The selection must be unchanged — scrolling the thumb is not a content
      // selection drag.
      expect(controller.selection, selectionBefore);
    });

    testWidgets('mouse drag held at the bottom edge keeps scrolling down', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the editor's render box to derive a point inside the bottom edge
      // band (within _autoScrollEdge = 48px of the viewport bottom).
      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      // Start the drag near the top so the drag base is in an early block.
      final dragStart = Offset(editorBox.left + 20, editorBox.top + 20);
      // Hold the pointer just inside the bottom edge.
      final edgePoint = Offset(editorBox.left + 20, editorBox.bottom - 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      // Move into the bottom edge band to arm the auto-scroll ticker.
      await gesture.moveTo(edgePoint);
      await tester.pump();

      final scrollBefore = _scrollOffset(tester);
      final extentBefore = controller.selection!.extent.blockIndex;

      // Hold still and advance frames — the ticker should keep scrolling down
      // even though the pointer is not moving.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scrollAfter = _scrollOffset(tester);
      final extentAfter = controller.selection!.extent.blockIndex;
      expect(scrollAfter, greaterThan(scrollBefore));
      expect(extentAfter, greaterThan(extentBefore));

      await gesture.up();
    });

    testWidgets('mouse drag held at the top edge keeps scrolling up', (
      tester,
    ) async {
      // Seed the caret on a late block so the editor scrolls down on mount,
      // giving us room to scroll back up.
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Jump the caret to a late block; the editor scrolls it into view.
      controller.setSelection(collapsedTextSelection('p25', 25, 0));
      await tester.pumpAndSettle();
      final scrolledDown = _scrollOffset(tester);
      expect(scrolledDown, greaterThan(0));

      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      // Start the drag in the middle, then move up into the top edge band.
      final dragStart = Offset(editorBox.left + 20, editorBox.center.dy);
      final topEdge = Offset(editorBox.left + 20, editorBox.top + 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(topEdge);
      await tester.pump();

      final scrollBefore = _scrollOffset(tester);

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scrollAfter = _scrollOffset(tester);
      // Scrolled up: the offset decreased.
      expect(scrollAfter, lessThan(scrollBefore));

      await gesture.up();
    });

    testWidgets('releasing the pointer stops the auto-scroll ticker', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      final dragStart = Offset(editorBox.left + 20, editorBox.top + 20);
      final edgePoint = Offset(editorBox.left + 20, editorBox.bottom - 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(edgePoint);
      await tester.pump();
      // Let the ticker scroll a bit.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrollBeforeRelease = _scrollOffset(tester);

      // Release the pointer — the ticker must stop.
      await gesture.up();
      await tester.pump();
      final scrollAtRelease = _scrollOffset(tester);

      // Advance more frames; the offset must not change once the pointer is up.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrollAfterRelease = _scrollOffset(tester);

      expect(scrollAtRelease, greaterThan(0));
      expect(scrollAfterRelease, equals(scrollBeforeRelease));
    });
  });

  testWidgets('PageDown moves the caret down by roughly one viewport', (
    tester,
  ) async {
    // Three short paragraphs stacked in a 360px-tall viewport. With the caret
    // at the top of p1, PageDown targets a Y one viewport below (clamped to the
    // viewport bottom) which lands in the last block p3.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.extent.blockId, 'p3');
    expect(controller.selection!.isCollapsed, isTrue);
  });

  testWidgets('PageUp moves the caret up by roughly one viewport', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      // Caret at the end of the last block.
      selection: collapsedTextSelection('p3', 2, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.extent.blockId, 'p1');
    expect(controller.selection!.isCollapsed, isTrue);
  });

  testWidgets('Shift+PageDown extends the selection keeping the anchor', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.isCollapsed, isFalse);
    // Anchor stays on p1; extent jumped down the document.
    expect(controller.selection!.base.blockId, 'p1');
    expect(controller.selection!.extent.blockId, 'p3');
  });

  testWidgets('PageDown at the document bottom stays at the end', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    // Single short block: caret cannot move further down — stays at end.
    expect(controller.selection!.extent.blockId, 'p1');
    expect(controller.selection!.extent.offset, 3);
  });

  testWidgets('block renderer registry overrides block rendering', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'real text')],
          ),
          DividerBlockNode(id: 'd1'),
        ],
      ),
    );
    // A registry that replaces the divider renderer with a sentinel Container
    // while keeping the built-in text renderer. The editor should honour the
    // override only for the registered type.
    final registry = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(registry);
    registry.register(
      BlockType.divider,
      (_, __) => const ColoredBox(
        color: Color(0xFF123456),
        child: SizedBox(height: 12, width: double.infinity),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            blockRenderers: registry,
          ),
        ),
      ),
    );
    await tester.pump();

    // The override rendered for the divider.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF123456),
      ),
      findsOneWidget,
    );
    // The built-in text renderer still renders the paragraph (it uses RichText,
    // not a plain Text widget).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'real text',
      ),
      findsOneWidget,
    );
    // The default Divider widget is no longer present.
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets(
    'block renderer registry falls back for unregistered types',
    (tester) async {
      // An empty registry (no defaults installed): every type should fall back
      // to the editor's plain-text fallback rather than crash.
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'fallback me')],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              blockRenderers: BlockRendererRegistry(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('fallback me'), findsOneWidget);
    },
  );

  // The virtualisation tests use a tall document (500 blocks) in the default
  // 800x600 test viewport, so only a handful of blocks fit on screen. They
  // assert that off-screen blocks are NOT built, and that the caret / selection
  // endpoint blocks stay mounted via AutomaticKeepAlive.

  group('virtualisation', () {
    RichTextDocument bigDocument({int count = 500}) {
      return RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < count; i++)
            TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'block-$i-content')],
            ),
        ],
      );
    }

    testWidgets('only builds visible blocks for a large document', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: bigDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // The first (visible) block is built (text blocks render as RichText).
      expect(_richText('block-0-content'), findsOneWidget);
      // A far off-screen block is NOT built under virtualisation.
      expect(_richText('block-499-content'), findsNothing);
      expect(_richText('block-400-content'), findsNothing);
    });

    testWidgets('keeps the caret block alive when it is off-screen', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              // Direct key-event character insertion (no IME) keeps the test
              // deterministic.
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // p1 starts visible.
      expect(_richText('block-1-content'), findsOneWidget);

      // Scroll the viewport so p1 leaves the screen.
      await tester.drag(
        find.byType(WenzRichTextEditor),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      // p1 is off-screen now, but it owns the caret so AutomaticKeepAlive
      // keeps it mounted (so the caret still paints / registers geometry).
      expect(_richText('block-1-content'), findsOneWidget);
    });

    testWidgets('keeps both selection endpoints alive across a range', (
      tester,
    ) async {
      // Both endpoints start within the viewport, then the range's far end is
      // scrolled off-screen; it must stay mounted via keep-alive.
      final start = collapsedTextSelection('p0', 0, 0).base;
      final end = DocumentPosition(
        blockId: 'p2',
        blockIndex: 2,
        path: PositionPath.blockText('p2'),
        offset: 0,
      );
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: DocumentSelection(base: start, extent: end),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_richText('block-2-content'), findsOneWidget);

      await tester.drag(
        find.byType(WenzRichTextEditor),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();

      // p2 (an endpoint) stays mounted even though it scrolled off-screen.
      expect(_richText('block-2-content'), findsOneWidget);
    });

    testWidgets('programmatic caret jump scrolls the caret into view', (
      tester,
    ) async {
      // Start with the caret on a visible block near the top.
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sanity: p400 is off-screen before the jump.
      expect(_richText('block-400-content'), findsNothing);

      // Jump the caret to block 400 programmatically.
      controller.setSelection(collapsedTextSelection('p400', 400, 0));
      await tester.pumpAndSettle();

      // After the jump the caret block is scrolled into the viewport — the
      // target block is now built and visible.
      expect(_richText('block-400-content'), findsOneWidget);
    });

    testWidgets('programmatic caret jump moves the scroll offset forward', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p0', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Scrollable state to read the offset.
      ScrollableState scrollable() => tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(WenzRichTextEditor),
              matching: find.byType(Scrollable),
            ),
          );
      final offsetBefore = scrollable().position.pixels;
      expect(offsetBefore, 0);

      controller.setSelection(collapsedTextSelection('p450', 450, 0));
      await tester.pumpAndSettle();

      final offsetAfter = scrollable().position.pixels;
      // Scrolled forward to bring the caret into view.
      expect(offsetAfter, greaterThan(offsetBefore));
    });
  });
}

Future<void> _performPlatformSelectors(
  WidgetTester tester,
  List<String> selectors,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.performSelectors', <dynamic>[
        -1,
        selectors,
      ]),
    ),
    (_) {},
  );
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

List<String> _underlinedTexts(InlineSpan span) {
  final result = <String>[];

  void visit(InlineSpan current, TextStyle? inheritedStyle) {
    if (current is! TextSpan) {
      return;
    }
    final style = current.style ?? inheritedStyle;
    final text = current.text;
    if (text != null &&
        text.isNotEmpty &&
        style?.decoration?.contains(TextDecoration.underline) == true) {
      result.add(text);
    }
    final children = current.children;
    if (children != null) {
      for (final child in children) {
        visit(child, style);
      }
    }
  }

  visit(span, null);
  return result;
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

/// The current scroll offset of the editor's scrollable. Used by the
/// auto-scroll-on-drag tests to assert the ticker advances the offset.
double _scrollOffset(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(WenzRichTextEditor),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollable.position.pixels;
}
