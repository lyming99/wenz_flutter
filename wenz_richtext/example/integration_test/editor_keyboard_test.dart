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

  group('keyboard editing', () {
    testWidgets('types text at the caret', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;
      expect(controller.document.plainText, '');

      await typeText(tester, controller, 'Hello');
      expect(controller.document.plainText, 'Hello');
      expect(richTextWith('Hello'), findsOneWidget);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('backspace deletes the character before the caret', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'Hello');
      expect(controller.document.plainText, 'Hello');
      expect(controller.selection?.extent.offset, 5);

      await sendKey(tester, LogicalKeyboardKey.backspace);
      expect(controller.document.plainText, 'Hell');
      expect(controller.selection?.extent.offset, 4);
      expect(richTextWith('Hell'), findsOneWidget);
    });

    testWidgets('delete removes the character after the caret', (tester) async {
      // Caret in the middle of "Hello" (offset 2).
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 2,
          ),
          extent: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 2,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.delete);
      expect(controller.document.plainText, 'Helo');
      expect(controller.selection?.extent.offset, 2);
    });

    testWidgets('enter splits the block and moves caret to the new block', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 1,
          ),
          extent: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 1,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.document.blocks, hasLength(2));
      // Split at offset 1: first block "a", second block "b".
      expect(controller.document.blocks[0].plainText, 'a');
      expect(controller.document.blocks[1].plainText, 'b');
      expect(controller.selection?.extent.blockIndex, 1);
    });

    testWidgets('arrow keys move the caret within a block', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 3,
          ),
          extent: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 3,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection?.extent.offset, 2);

      await sendKey(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection?.extent.offset, 1);

      await sendKey(tester, LogicalKeyboardKey.arrowRight);
      expect(controller.selection?.extent.offset, 2);
    });

    testWidgets('Home and End jump to block boundaries', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 3,
          ),
          extent: DocumentPosition.text(
            blockId: 'p1',
            blockIndex: 0,
            offset: 3,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.home);
      expect(controller.selection?.extent.offset, 0);

      await sendKey(tester, LogicalKeyboardKey.end);
      expect(controller.selection?.extent.offset, 6);
    });

    testWidgets('Ctrl+A selects the whole editable range', (tester) async {
      final workbench = await pumpWorkbench(
        tester,
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
      final controller = workbench.controller;

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection?.start.offset, 0);
      expect(controller.selection?.end.offset, 6);
      expect(isSelectionHighlightVisible(tester), isTrue);
    });

    testWidgets('delete an existing character via Backspace on focused '
        'content', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'xyz');
      // Move caret back to the middle.
      await sendKey(tester, LogicalKeyboardKey.arrowLeft);
      await sendKey(tester, LogicalKeyboardKey.arrowLeft);
      await sendKey(tester, LogicalKeyboardKey.backspace);
      // "xyz", caret at 1 (between y and z), delete 'x' -> "yz".
      expect(controller.document.plainText, 'yz');
    });

    testWidgets('arrow down at a block end moves to the next block', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
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
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.selection?.extent.blockId, 'p2');
      expect(controller.selection?.extent.offset, 0);
    });

    testWidgets('arrow up at a block start moves to the previous block', (
      tester,
    ) async {
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
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
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p2', blockIndex: 1, offset: 0),
          extent: DocumentPosition.text(blockId: 'p2', blockIndex: 1, offset: 0),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection?.extent.blockId, 'p1');
      // Lands at the end of the previous block.
      expect(controller.selection?.extent.offset, 3);
    });

    testWidgets('arrow down/up do nothing in the middle of a single-line '
        'block', (tester, ) async {
      // A single visual line has no line above/below, and the caret is not at a
      // block boundary, so Up/Down must be no-ops.
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdef')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.selection?.extent.offset, 2);

      await sendKey(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection?.extent.offset, 2);
    });

    testWidgets('arrow down moves to the next visual line keeping the column', (
      tester,
    ) async {
      // A long paragraph that wraps across multiple visual lines in the
      // viewport. Down from line 1 must land on line 2 at a nearby
      // column, not jump to the block end.
      const wrapped = 'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee '
          'ffffffffff gggggggggg hhhhhhhhhh iiiiiiiiii jjjjjjjjjj kkkkkkkkkk '
          'llllllllll mmmmmmmmmm nnnnnnnnnn oooooooooo pppppppppp';
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: wrapped)],
            ),
          ],
        ),
        // Caret near the start of line 1.
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      // The caret must have advanced into the second visual line (a sizable
      // jump forward), but not all the way to the block end.
      final afterDown = controller.selection!.extent.offset;
      expect(afterDown, greaterThan(10),
          reason: 'Down must move to the next wrapped line');
      expect(afterDown, lessThan(wrapped.length),
          reason: 'Down must not jump to the block end');

      // Up returns to the first line, near the original column.
      await sendKey(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection!.extent.offset, lessThan(afterDown));
    });

    testWidgets('repeated arrow down keeps advancing through lines', (
      tester,
    ) async {
      // Regression: consecutive Up/Down must each move the caret, not stall
      // after the first press (the remembered column lets the move repeat).
      // Use a long enough paragraph to wrap across several visual lines.
      const wrapped = 'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee '
          'ffffffffff gggggggggg hhhhhhhhhh iiiiiiiiii jjjjjjjjjj kkkkkkkkkk '
          'llllllllll mmmmmmmmmm nnnnnnnnnn oooooooooo pppppppppp qqqqqqqqqq '
          'rrrrrrrrrr ssssssssss tttttttttt uuuuuuuuuu vvvvvvvvvv wwwwwwwwww '
          'xxxxxxxxxx yyyyyyyyyy zzzzzzzzzz aaaaaaaaaa bbbbbbbbbb cccccccccc '
          'dddddddddd eeeeeeeeee ffffffffff gggggggggg hhhhhhhhhh iiiiiiiiii';
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: wrapped)],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      final first = controller.selection!.extent.offset;
      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      final second = controller.selection!.extent.offset;

      expect(second, greaterThan(first),
          reason: 'the second Down must advance further than the first');
    });

    testWidgets('arrow down exits a table at the last row', (tester) async {
      // Caret in the last row of a 2-row table; Down must leave the table and
      // land in the following paragraph, not stay trapped in the cell.
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 't1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c1p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'AA')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c2p',
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
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 't1',
            blockIndex: 0,
            tableRowIndex: 1,
            tableColumnIndex: 0,
            offset: 1,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 't1',
            blockIndex: 0,
            tableRowIndex: 1,
            tableColumnIndex: 0,
            offset: 1,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.selection?.extent.blockId, 'p1',
          reason: 'Down at the last table row must exit to the next block');
    });

    testWidgets('arrow up exits a table at the first row', (tester) async {
      // Caret in the first row of a table preceded by a paragraph; Up must
      // leave the table for the preceding block.
      final workbench = await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            TableBlockNode(
              id: 't1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c1p',
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
        ),
        selection: DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 't1',
            blockIndex: 1,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 1,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 't1',
            blockIndex: 1,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 1,
          ),
        ),
      );
      final controller = workbench.controller;

      await sendKey(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.selection?.extent.blockId, 'p1',
          reason: 'Up at the first table row must exit to the previous block');
    });
  });
}
