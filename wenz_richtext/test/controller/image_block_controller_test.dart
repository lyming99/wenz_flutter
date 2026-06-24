import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController.updateImageBlock', () {
    test('updates image metadata and participates in undo redo', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
              width: 640,
              height: 360,
              showWidth: 160,
              showHeight: 90,
              caption: 'Before',
              altText: 'Before alt',
            ),
          ],
        ),
      );

      final change = controller.updateImageBlock(
        blockIndex: 0,
        assetId: 'hero-2',
        file: 'hero-2.png',
        width: 1280,
        height: 720,
        showWidth: 320,
        clearShowHeight: true,
        caption: 'After',
        altText: 'After alt',
      );

      expect(change.description, 'updateImageBlock');
      final updated = controller.document.blocks.single as ImageBlockNode;
      expect(updated.assetId, 'hero-2');
      expect(updated.file, 'hero-2.png');
      expect(updated.width, 1280);
      expect(updated.height, 720);
      expect(updated.showWidth, 320);
      expect(updated.showHeight, isNull);
      expect(updated.caption, 'After');
      expect(updated.altText, 'After alt');

      expect(controller.undo(), isTrue);
      final undone = controller.document.blocks.single as ImageBlockNode;
      expect(undone.assetId, 'hero');
      expect(undone.showWidth, 160);
      expect(undone.showHeight, 90);
      expect(undone.caption, 'Before');
      expect(undone.altText, 'Before alt');

      expect(controller.redo(), isTrue);
      final redone = controller.document.blocks.single as ImageBlockNode;
      expect(redone.assetId, 'hero-2');
      expect(redone.caption, 'After');

      controller.dispose();
    });

    test('returns a no-op for non-image targets', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'text')],
            ),
          ],
        ),
      );

      final change = controller.updateImageBlock(
        blockIndex: 0,
        caption: 'ignored',
      );

      expect(change.isNoop, isTrue);
      expect(controller.canUndo, isFalse);
      controller.dispose();
    });
  });
}
