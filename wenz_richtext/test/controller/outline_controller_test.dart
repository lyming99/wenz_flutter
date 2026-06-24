import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzOutlineController', () {
    test('derives outline items from non-empty headings', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.items, hasLength(2));
      expect(outline.items[0].blockId, 'h1');
      expect(outline.items[0].blockIndex, 0);
      expect(outline.items[0].level, 1);
      expect(outline.items[0].title, 'Intro');
      expect(outline.items[0].anchor, 'intro');
      expect(outline.items[0].target, 'intro');
      expect(outline.items[1].blockId, 'h2');
      expect(outline.items[1].level, 2);
      expect(outline.items[1].target, 'h2');

      outline.dispose();
      host.dispose();
    });

    test('updates when a heading anchor changes', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);
      var notifications = 0;
      outline.addListener(() => notifications++);

      host.setBlockAnchor(blockIndex: 2, anchor: 'details');

      expect(notifications, 1);
      expect(outline.itemForBlockId('h2')?.anchor, 'details');
      expect(outline.itemForAnchor('details')?.blockId, 'h2');

      outline.dispose();
      host.dispose();
    });

    test('selectByAnchor moves host selection to heading start', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      final selected = outline.selectByAnchor('intro', requestFocus: false);

      expect(selected, isTrue);
      expect(host.selection?.extent.blockId, 'h1');
      expect(host.selection?.extent.blockIndex, 0);
      expect(host.selection?.extent.offset, 0);
      expect(host.selection?.extent.path.isBlockText, isTrue);

      outline.dispose();
      host.dispose();
    });

    test('selectByBlockId returns false for non-heading blocks', () {
      final host = WenzRichTextController(document: _doc());
      final outline = WenzOutlineController(editor: host);

      expect(outline.selectByBlockId('p1', requestFocus: false), isFalse);
      expect(host.selection, isNull);

      outline.dispose();
      host.dispose();
    });
  });
}

RichTextDocument _doc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'h1',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 1, anchor: 'intro'),
        content: <InlineNode>[TextRun(text: 'Intro')],
      ),
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body')],
      ),
      TextBlockNode(
        id: 'h2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Details')],
      ),
      TextBlockNode(
        id: 'empty-heading',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 3),
        content: <InlineNode>[],
      ),
    ],
  );
}
