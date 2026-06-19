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
