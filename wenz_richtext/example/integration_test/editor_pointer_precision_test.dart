import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A single long paragraph so each character has a distinct x-coordinate and
  /// taps at different offsets resolve to different carets.
  const textDocument = RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'abcdefghij')],
      ),
    ],
  );

  group('pointer click precision', () {
    testWidgets('clicking the middle of a character run places the caret '
        'near that offset', (tester) async {
      await pumpWorkbench(tester, document: textDocument);

      // Click around the middle of "abcdefghij" (offset ~5).
      await tapAtTextOffset(tester, 'abcdefghij', 5);

      final controller = _controllerOf(tester);
      // The resolved offset should land on or adjacent to 5 — not jump to 0
      // or the end of the block.
      expect(controller.selection?.extent.offset, inInclusiveRange(4, 6));
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('clicking near the start places the caret near offset 0', (
      tester,
    ) async {
      await pumpWorkbench(tester, document: textDocument);

      await tapAtTextOffset(tester, 'abcdefghij', 1);

      final controller = _controllerOf(tester);
      expect(controller.selection?.extent.offset, inInclusiveRange(0, 2));
    });

    testWidgets('clicking near the end places the caret near the last offset', (
      tester,
    ) async {
      await pumpWorkbench(tester, document: textDocument);

      await tapAtTextOffset(tester, 'abcdefghij', 9);

      final controller = _controllerOf(tester);
      // Should resolve to 9 or 10 (the block length), not an early offset.
      expect(controller.selection?.extent.offset, greaterThanOrEqualTo(8));
    });

    testWidgets('successive clicks to different offsets move the caret each '
        'time', (tester) async {
      await pumpWorkbench(tester, document: textDocument);

      await tapAtTextOffset(tester, 'abcdefghij', 2);
      var controller = _controllerOf(tester);
      final firstOffset = controller.selection!.extent.offset;
      expect(firstOffset, inInclusiveRange(1, 3));

      await tapAtTextOffset(tester, 'abcdefghij', 7);
      controller = _controllerOf(tester);
      final secondOffset = controller.selection!.extent.offset;

      // The caret must have moved to follow the second click.
      expect(
        (secondOffset - firstOffset).abs(),
        greaterThan(2),
        reason: 'clicking a different position must reposition the caret',
      );
    });

    testWidgets('click resolves to the right offset on a multi-line wrap', (
      tester,
    ) async {
      // A long line that wraps in the narrow-ish editor viewport; clicking on
      // the second visual line must resolve to an offset in the wrapped part,
      // not clamp to the first line.
      const wrappedDocument = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee',
              ),
            ],
          ),
        ],
      );
      await pumpWorkbench(tester, document: wrappedDocument);

      // Tap an offset well into the second wrapped line (offset ~40).
      await tapAtTextOffset(
        tester,
        'aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee',
        40,
      );

      final controller = _controllerOf(tester);
      // Must land in the second half of the text, not jump back to line 1.
      expect(controller.selection?.extent.offset, greaterThan(25));
    });

    testWidgets('clicking wrapped-line right blank keeps caret on that line', (
      tester,
    ) async {
      const wrappedText =
          'one two extraordinarily three four magnificent five six seven eight';
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'wrapped',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: wrappedText)],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 240,
                child: WenzRichTextEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                  textStyle: const TextStyle(
                    fontFamily: 'Ahem',
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstLine = rightBlankOnVisualLine(
        tester,
        wrappedText,
        lineIndex: 0,
      );
      final secondLine = rightBlankOnVisualLine(
        tester,
        wrappedText,
        lineIndex: 1,
      );
      expect(
        firstLine.lineRange.end,
        lessThanOrEqualTo(secondLine.lineRange.start),
      );

      await tester.tapAt(firstLine.globalPoint);
      await tester.pump();
      expect(controller.selection?.extent.blockId, 'wrapped');
      expect(controller.selection?.extent.offset, firstLine.lineRange.end);
      expect(isCaretVisible(tester), isTrue);

      await tester.tapAt(secondLine.globalPoint);
      await tester.pump();
      expect(controller.selection?.extent.blockId, 'wrapped');
      expect(controller.selection?.extent.offset, secondLine.lineRange.end);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('a tap with small pointer-up drift still places the caret at '
        'the down position', (tester) async {
      // The editor resolves a single tap at the pointer-DOWN coordinate, so a
      // click whose release drifts a little must not jump the caret to the up
      // location. Drive the gesture manually to inject sub-slop drift.
      await pumpWorkbench(tester, document: textDocument);

      final downAt = globalOffsetAt(tester, 'abcdefghij', 3);
      final gesture = await tester.startGesture(downAt);
      await tester.pump();
      // Drift the release a few pixels (below the drag slop threshold).
      await gesture.moveTo(downAt + const Offset(4, 0));
      await gesture.up();
      await tester.pump();

      final controller = _controllerOf(tester);
      // The caret should resolve near the down offset (3), not the drifted
      // up offset.
      expect(controller.selection?.extent.offset, inInclusiveRange(2, 4));
    });
  });
}

WenzRichTextController _controllerOf(WidgetTester tester) {
  final widget = tester.widget<WenzRichTextEditor>(
    find.byType(WenzRichTextEditor),
  );
  return widget.controller;
}
