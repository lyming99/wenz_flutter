import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/rendering/text_layout_service.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('BlockGeometryRegistry via editor', () {
    testWidgets('resolves a global offset to a position in the hit block', (
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
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );
      // Drive a tap so the surfaces register; verify behaviour through the
      // resulting selection rather than touching the private registry.
      await tester.tapAt(_globalTextOffset(tester, 'abcdef', 3));
      await tester.pump();

      expect(controller.selection?.extent.blockId, 'p1');
      expect(controller.selection?.extent.offset, 3);
    });

    testWidgets('resolves a tap inside a table cell to tableCellText path', (
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
                          content: <InlineNode>[TextRun(text: 'Cell')],
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
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );

      await tester.tapAt(_globalTextOffset(tester, 'Cell', 2));
      await tester.pump();

      final extent = controller.selection?.extent;
      expect(extent, isNotNull);
      expect(extent!.blockId, 'table1');
      expect(extent.path.isTableCellText, isTrue);
      expect(extent.path.tableRowIndex, 0);
      expect(extent.path.tableColumnIndex, 0);
      expect(extent.offset, 2);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-caret')),
        findsOneWidget,
      );
    });

    testWidgets('keeps separate registry entries for cells in the same table', (
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
                          content: <InlineNode>[TextRun(text: 'Left')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'cell2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-p2',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Right')],
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
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );

      await tester.tapAt(_globalTextOffset(tester, 'Right', 3));
      await tester.pump();

      final extent = controller.selection?.extent;
      expect(extent, isNotNull);
      expect(extent!.blockId, 'table1');
      expect(extent.path.isTableCellText, isTrue);
      expect(extent.path.tableRowIndex, 0);
      expect(extent.path.tableColumnIndex, 1);
      expect(extent.offset, 3);
    });

    // Regression: a tap anywhere inside a table cell — including the 8px
    // padding around the centred text — used to miss the (smaller, centred)
    // text surface and fall through to a vertical-only nearest-cell clamp,
    // which attributed the tap to the wrong column. The hit-test box now
    // covers the whole cell frame.
    testWidgets('tap in cell padding resolves to that cell, not a neighbour', (
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
                          content: <InlineNode>[TextRun(text: 'Left')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'cell2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-p2',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Right')],
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
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );

      // Tap in the RIGHT cell's left padding — a point that is inside the
      // visible cell but left of its centred text. Before the fix this fell
      // into the gap and was attributed to 'Left' (column 0).
      final rightCell = find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == 'Right',
      );
      final topLeft = tester.getTopLeft(rightCell);
      // A few pixels left of the text but still within the right cell's frame.
      await tester.tapAt(Offset(topLeft.dx - 4, topLeft.dy + 6));
      await tester.pump();

      final extent = controller.selection?.extent;
      expect(extent, isNotNull);
      expect(extent!.blockId, 'table1');
      expect(extent.path.isTableCellText, isTrue);
      expect(extent.path.tableColumnIndex, 1,
          reason: 'padding tap must stay in the right cell');
    });

    // Regression: when a row is stretched tall by a multi-line sibling, a
    // short cell is vertically centred and gains a large top/bottom gutter.
    // Tapping that gutter used to clamp (vertically) into the adjacent row.
    testWidgets('tap above/below a short centred cell stays in its row', (
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
                      id: 'r0c0',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'r0c0-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'top')],
                        ),
                      ],
                    ),
                  ],
                  // Row 1: a very tall right cell forces the row height up;
                  // the short left cell is centred with a big bottom gutter.
                  <TableCellNode>[
                    TableCellNode(
                      id: 'r1c0',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'r1c0-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'short')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'r1c1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'r1c1-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'a\nb\nc\nd\ne\nf'),
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
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );

      final shortCell = find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == 'short',
      );
      final rect = tester.getRect(shortCell);
      // Tap well below the centred text but still inside the stretched row 1
      // cell frame. Before the fix this clamped into row 0 / row 2.
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 14));
      await tester.pump();

      final extent = controller.selection?.extent;
      expect(extent, isNotNull);
      expect(extent!.blockId, 'table1');
      expect(extent.path.tableRowIndex, 1,
          reason: 'gutter tap in the short cell must stay in its row');
      expect(extent.path.tableColumnIndex, 0);
    });

    // A tap in the vertical gap between two paragraph blocks used to clamp to
    // a hard 0 / textLength offset regardless of the tap's horizontal column.
    // It now resolves through the nearest block's layout so a gap-tap on the
    // 4th column lands near offset 4, matching where the user clicked.
    testWidgets('gap tap between blocks honours the horizontal column', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcdefghij')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'klmnopqrst')],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WenzRichTextEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the two blocks and tap midway between them, on the 5th column.
      final p1 = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'abcdefghij',
      );
      final p2 = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'klmnopqrst',
      );
      final p1Rect = tester.getRect(p1);
      final p2Rect = tester.getRect(p2);
      // Column 5 x: 5 characters in from p1's left.
      final columnX = p1Rect.left + 5 * (p1Rect.width / 'abcdefghij'.length);
      final gapY = (p1Rect.bottom + p2Rect.top) / 2;
      await tester.tapAt(Offset(columnX, gapY));
      await tester.pump();

      final extent = controller.selection?.extent;
      expect(extent, isNotNull);
      // The caret should land near column 5 of whichever block owns the gap —
      // not at 0 or textLength (10). Allow some tolerance for glyph widths.
      expect(extent!.offset, inInclusiveRange(3, 7),
          reason: 'gap tap must honour the horizontal column, not clamp to an edge');
    });
  });

  group('TextLayoutService word/paragraph ranges', () {
    test('wordRangeAt delegates to TextPainter word boundaries', () {
      final service = TextLayoutService();
      const span = TextSpan(text: 'hello world', style: TextStyle(fontSize: 14));
      final painter = service.layout(
        span: span,
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        maxWidth: 1000,
      );

      final range = service.wordRangeAt(painter, 2);
      // "hello" occupies 0..5.
      expect(range.start, 0);
      expect(range.end, 5);

      final range2 = service.wordRangeAt(painter, 7);
      expect(range2.start, 6);
      expect(range2.end, 11);
    });

    test('paragraphRange spans the whole laid-out text', () {
      final service = TextLayoutService();
      const span = TextSpan(text: 'hello world', style: TextStyle(fontSize: 14));
      final painter = service.layout(
        span: span,
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        maxWidth: 1000,
      );

      final range = service.paragraphRange(painter);
      expect(range.start, 0);
      expect(range.end, 'hello world'.length);
    });
  });

  // B1: word/paragraph boundary coverage. The implementation already worked
  // (double/triple-tap widget tests existed); these unit tests pin the edge
  // cases the gesture overlay relies on so a regression in TextLayoutService
  // surfaces at the unit level rather than as a flaky widget interaction.
  group('TextLayoutService word boundaries (B1)', () {
    TextPainter paint(String text) {
      final service = TextLayoutService();
      return service.layout(
        span: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        maxWidth: 1000,
      );
    }

    test('offset at the first character selects the whole word', () {
      final painter = paint('hello world');
      final range = TextLayoutService().wordRangeAt(painter, 0);
      expect(range.start, 0);
      expect(range.end, 5);
    });

    test('offset at the last character of a word stays in that word', () {
      final painter = paint('hello world');
      // Offset 4 is the final "o" of "hello"; the word boundary still covers
      // 0..5 (getWordBoundary is inclusive of the offset's word).
      final range = TextLayoutService().wordRangeAt(painter, 4);
      expect(range.start, 0);
      expect(range.end, 5);
    });

    test('offset in the middle of a word selects the whole word', () {
      final painter = paint('hello world');
      final range = TextLayoutService().wordRangeAt(painter, 2);
      expect(range.start, 0);
      expect(range.end, 5);
    });

    test('offset on the second word selects only the second word', () {
      final painter = paint('hello world');
      final range = TextLayoutService().wordRangeAt(painter, 7);
      expect(range.start, 6);
      expect(range.end, 11);
    });

    test('a single-word text returns a range covering the whole text', () {
      final painter = paint('single');
      final range = TextLayoutService().wordRangeAt(painter, 0);
      expect(range.start, 0);
      expect(range.end, 6);
    });

    test('offset clamped to text length does not throw', () {
      final painter = paint('hi');
      // Offset 100 is far past the end; wordRangeAt must clamp to the text
      // length and return a valid (possibly collapsed) range, not throw.
      final range = TextLayoutService().wordRangeAt(painter, 100);
      expect(range.start, inInclusiveRange(0, 2));
      expect(range.end, inInclusiveRange(0, 2));
    });

    test('a CJK run returns a range contained within the run', () {
      // TextPainter.getWordBoundary's behaviour on CJK is locale-dependent:
      // some segmenters treat a contiguous CJK run as a single word, others
      // break per character. The contract double-click relies on is the weaker
      // one — the returned range must stay *inside* the CJK run and never bleed
      // into the trailing ASCII word. We assert that, not the exact span.
      final painter = paint('你好 world');
      final range = TextLayoutService().wordRangeAt(painter, 0);
      expect(range.start, inInclusiveRange(0, 1));
      expect(range.end, inInclusiveRange(1, 2));
      // The trailing ASCII word is an independent segment.
      final asciiRange = TextLayoutService().wordRangeAt(painter, 3);
      expect(asciiRange.start, 3);
      expect(asciiRange.end, 8);
    });
  });

  group('TextLayoutService paragraph boundaries (B1)', () {
    TextPainter paint(String text) {
      final service = TextLayoutService();
      return service.layout(
        span: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        maxWidth: 1000,
      );
    }

    test('a multi-line paragraph spans the whole text including newlines', () {
      final painter = paint('line1\nline2');
      final range = TextLayoutService().paragraphRange(painter);
      expect(range.start, 0);
      // The paragraph is the whole block — newlines are inline content here.
      expect(range.end, 'line1\nline2'.length);
    });

    test('an empty paragraph returns a collapsed range at 0', () {
      final painter = paint('');
      final range = TextLayoutService().paragraphRange(painter);
      expect(range.start, 0);
      expect(range.end, 0);
      // Word boundary on empty text must also be safe.
      final word = TextLayoutService().wordRangeAt(painter, 0);
      expect(word.start, 0);
      expect(word.end, 0);
    });
  });
}

Offset _globalTextOffset(WidgetTester tester, String text, int offset) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final local = painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
  return tester.getTopLeft(finder) + local + Offset(1, painter.preferredLineHeight / 2);
}
