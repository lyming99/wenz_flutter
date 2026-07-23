import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('outline click precisely aligns a heading in a large document',
      (tester) async {
    final blocks = <BlockNode>[
      const TextBlockNode(
        id: 'top-heading',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1),
        content: <InlineNode>[TextRun(text: 'Top heading')],
      ),
      for (var index = 0; index < 240; index++)
        TextBlockNode(
          id: 'paragraph-$index',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(
              text: index.isEven
                  ? 'Short paragraph $index.'
                  : List<String>.filled(
                      7,
                      'Variable-height paragraph $index fills several lines.',
                    ).join(' '),
            ),
          ],
        ),
      const TextBlockNode(
        id: 'deep-heading',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Deep target')],
      ),
      for (var index = 0; index < 60; index++)
        TextBlockNode(
          id: 'tail-$index',
          type: BlockType.paragraph,
          content: const <InlineNode>[TextRun(text: 'Tail paragraph.')],
        ),
    ];
    final editor = WenzRichTextController(
      document: RichTextDocument(blocks: blocks),
    );
    final outline = WenzOutlineController(editor: editor);
    addTearDown(outline.dispose);
    addTearDown(editor.dispose);

    await tester.binding.setSurfaceSize(const Size(760, 380));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              WenzOutlinePanel(controller: outline, width: 220),
              Expanded(
                child: ColoredBox(
                  key: const ValueKey('editor-viewport'),
                  color: Colors.white,
                  child: WenzRichTextEditor(
                    controller: editor,
                    outlineController: outline,
                    enableIme: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('wenz-richtext-positioned-deep-heading'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Deep target'));
    for (var frame = 0; frame < 34; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final target = find.byKey(
      const ValueKey('wenz-richtext-positioned-deep-heading'),
    );
    expect(target, findsOneWidget);
    expect(editor.selection?.extent.blockId, 'deep-heading');

    final viewportTop =
        tester.getTopLeft(find.byKey(const ValueKey('editor-viewport'))).dy;
    final targetTop = tester.getTopLeft(target).dy;
    expect(targetTop - viewportTop, closeTo(12, 1.5));
    expect(tester.takeException(), isNull);
  });
}
