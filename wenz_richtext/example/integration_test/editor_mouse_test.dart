import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/pointer_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('mouse selection', () {
    testWidgets('tap places the caret at the tapped offset', (tester) async {
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

      await tapAtTextOffset(tester, 'abcdef', 3);

      final controller = _controllerOf(tester);
      expect(controller.selection, isNotNull);
      expect(controller.selection?.extent.offset, 3);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('Shift-click extends a collapsed caret and releases Shift', (
      tester,
    ) async {
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
        selection: _collapsedTextSelection('p1', 0, 1),
      );

      await tapAtTextOffset(tester, 'abcdef', 5, shift: true);

      final controller = _controllerOf(tester);
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      expect(controller.selection!.base.offset, 1);
      expect(controller.selection!.extent.offset, 5);
      expect(isSelectionHighlightVisible(tester), isTrue);

      await tapAtTextOffset(tester, 'abcdef', 3);

      expect(controller.selection!.isCollapsed, isTrue);
      expect(controller.selection!.extent.offset, 3);
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('dragging selects a highlighted range', (tester) async {
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

      await dragInsideText(
        tester,
        'abcdef',
        fromOffset: 1,
        toOffset: 4,
      );

      final controller = _controllerOf(tester);
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection?.start.offset, lessThanOrEqualTo(2));
      expect(controller.selection?.end.offset, 4);
      expect(isSelectionHighlightVisible(tester), isTrue);
    });

    testWidgets('double-tap selects a word', (tester) async {
      await pumpWorkbench(
        tester,
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

      await multiTapText(tester, 'hello world', 2, taps: 2);

      final controller = _controllerOf(tester);
      expect(controller.selection?.isCollapsed, isFalse);
      // "hello" occupies offsets 0..5.
      expect(controller.selection!.start.offset, 0);
      expect(controller.selection!.end.offset, 5);
    });

    testWidgets('triple-tap selects the whole block', (tester) async {
      await pumpWorkbench(
        tester,
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

      await multiTapText(tester, 'hello world', 2, taps: 3);

      final controller = _controllerOf(tester);
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection!.start.offset, 0);
      expect(controller.selection!.end.offset, 'hello world'.length);
    });

    testWidgets('Shift-drag keeps the existing anchor across paragraphs', (
      tester,
    ) async {
      await pumpWorkbench(
        tester,
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
        selection: _collapsedTextSelection('p1', 0, 2),
      );

      await dragBetweenText(
        tester,
        fromText: 'abcdef',
        fromOffset: 5,
        toText: 'ghijkl',
        toOffset: 3,
        shift: true,
      );

      final controller = _controllerOf(tester);
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      expect(controller.selection!.base.blockId, 'p1');
      expect(controller.selection!.base.offset, 2);
      expect(controller.selection!.extent.blockId, 'p2');
      expect(controller.selection!.extent.offset, 3);
      expect(isSelectionHighlightVisible(tester), isTrue);
    });

    testWidgets('cross-block drag extends selection into the next paragraph', (
      tester,
    ) async {
      await pumpWorkbench(
        tester,
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

      await dragBetweenText(
        tester,
        fromText: 'abcdef',
        fromOffset: 1,
        toText: 'ghijkl',
        toOffset: 3,
      );

      final controller = _controllerOf(tester);
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      // Drag started in p1 and ended in p2 — a genuine cross-block range.
      expect(controller.selection!.start.blockId, 'p1');
      expect(controller.selection!.end.blockId, 'p2');
    });
  });
}

DocumentSelection _collapsedTextSelection(
  String blockId,
  int blockIndex,
  int offset,
) {
  final position = DocumentPosition.text(
    blockId: blockId,
    blockIndex: blockIndex,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}
WenzRichTextController _controllerOf(WidgetTester tester) {
  // The controller is the same instance the test's TestWorkbench holds; the
  // widget exposes it via its constructor param.
  final widget = tester.widget<WenzRichTextEditor>(
    find.byType(WenzRichTextEditor),
  );
  return widget.controller;
}
