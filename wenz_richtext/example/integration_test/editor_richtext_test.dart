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

  group('rich text formatting & history', () {
    testWidgets('Bold toolbar button bolds the selected run', (tester) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );

      await dragInsideText(tester, 'hello', fromOffset: 0, toOffset: 5);
      await tester.tap(find.byTooltip('Bold'));
      await tester.pump();

      // The whole run "hello" is now bold.
      final style = styleOfRun(tester, 'hello', 'hello');
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('Italic toolbar button italicises the selected run', (
      tester,
    ) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hello')],
            ),
          ],
        ),
      );

      await dragInsideText(tester, 'hello', fromOffset: 0, toOffset: 5);
      await tester.tap(find.byTooltip('Italic'));
      await tester.pump();

      final style = styleOfRun(tester, 'hello', 'hello');
      expect(style?.fontStyle, FontStyle.italic);
    });

    testWidgets('Heading toolbar button switches block type', (tester) async {
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Title')],
            ),
          ],
        ),
      );

      // Place the caret anywhere in the block to give it block-type context.
      await tapAtTextOffset(tester, 'Title', 2);
      await tester.tap(find.byTooltip('Heading'));
      await tester.pump();

      // Heading level 1 renders at fontSize 24 with bold weight.
      final style = richTextStyle(tester, 'Title');
      expect(style?.fontSize, 24);
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('Ctrl+Z undoes a typed insertion', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'abc');
      expect(controller.document.plainText, 'abc');
      expect(controller.canUndo, isTrue);

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      // One coalesced undo step reverts the whole typed run.
      expect(controller.document.plainText, '');
    });

    testWidgets('Ctrl+Shift+Z redoes the undone insertion', (tester) async {
      final workbench = await pumpWorkbench(tester);
      final controller = workbench.controller;

      await typeText(tester, controller, 'abc');
      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.document.plainText, '');

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(controller.document.plainText, 'abc');
    });

    testWidgets('copy and paste duplicate the selection', (tester) async {
      // Start with "abc", select it, copy, move caret to end, paste.
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
      );
      final controller = workbench.controller;

      await dragInsideText(tester, 'abc', fromOffset: 0, toOffset: 3);

      // Ctrl+C copies the rich payload into the clipboard.
      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      // Collapse the caret to the end of the block (a non-collapsed selection
      // would be replaced on paste, yielding "abc" instead of "abcabc").
      await tapAtTextOffset(tester, 'abc', 3);

      await sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();

      expect(controller.document.plainText, 'abcabc');
      expect(richTextWith('abcabc'), findsOneWidget);
    });
  });
}
