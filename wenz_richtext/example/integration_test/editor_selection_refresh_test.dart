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

  group('selection refresh', () {
    testWidgets('drag-selecting within a block updates the selection each '
        'frame', (tester) async {
      // Regression: the per-block incremental cache keyed the cached child on
      // whether the block was a selection endpoint (a boolean). Dragging the
      // extent within an already-selected block did not flip that boolean, so
      // the stale child kept the OLD selection and the highlight did not
      // follow the drag.
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdefghij')],
            ),
          ],
        ),
      );

      // First drag: select a small range near the start.
      await dragInsideText(tester, 'abcdefghij', fromOffset: 0, toOffset: 3);
      var controller = _controllerOf(tester);
      final firstEnd = controller.selection!.end.offset;
      expect(firstEnd, inInclusiveRange(2, 4));
      expect(isSelectionHighlightVisible(tester), isTrue);

      // Second drag in the SAME block: extend further. The block stays an
      // endpoint, so a boolean cache key would not invalidate — the rendered
      // selection must still track the new, larger extent.
      await dragInsideText(tester, 'abcdefghij', fromOffset: 0, toOffset: 7);
      controller = _controllerOf(tester);
      final secondEnd = controller.selection!.end.offset;
      expect(secondEnd, greaterThan(firstEnd),
          reason: 'extent must move forward on the second drag');
      expect(isSelectionHighlightVisible(tester), isTrue);

      // A third drag to a different extent must also move the selection (not
      // stay frozen at the second drag's end).
      await dragInsideText(tester, 'abcdefghij', fromOffset: 0, toOffset: 5);
      controller = _controllerOf(tester);
      expect(controller.selection!.end.offset, isNot(secondEnd),
          reason: 'extent must change on the third drag');
    });

    testWidgets('collapsing a selection via arrow key clears the highlight '
        'and shows the caret', (tester) async {
      // Regression companion: after selecting, collapsing must re-render so
      // the highlight disappears and the caret appears. A stale cached child
      // would keep the highlight box mounted and hide the caret.
      await pumpWorkbench(
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

      await dragInsideText(tester, 'abcdef', fromOffset: 0, toOffset: 4);
      expect(isSelectionHighlightVisible(tester), isTrue);
      expect(isCaretVisible(tester), isFalse);

      // Collapse the selection with Left (caret moves to selection start).
      await sendKey(tester, LogicalKeyboardKey.arrowLeft);
      final controller = _controllerOf(tester);
      expect(controller.selection?.isCollapsed, isTrue);
      expect(isSelectionHighlightVisible(tester), isFalse);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('selecting across two blocks highlights both', (tester) async {
      // Cross-block selection: both endpoint blocks must render a highlight.
      await pumpWorkbench(
        tester,
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'aaaaaa')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'bbbbbb')],
            ),
          ],
        ),
      );

      await dragBetweenText(
        tester,
        fromText: 'aaaaaa',
        fromOffset: 1,
        toText: 'bbbbbb',
        toOffset: 4,
      );

      final controller = _controllerOf(tester);
      expect(controller.selection!.start.blockId, 'p1');
      expect(controller.selection!.end.blockId, 'p2');
      expect(isSelectionHighlightVisible(tester), isTrue);
    });
  });
}

WenzRichTextController _controllerOf(WidgetTester tester) {
  final widget = tester.widget<WenzRichTextEditor>(
    find.byType(WenzRichTextEditor),
  );
  return widget.controller;
}
