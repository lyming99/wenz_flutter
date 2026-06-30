import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController.insertImage', () {
    test('inserts full metadata at an explicit index and supports undo redo', () {
      final initialSelection = _collapsedTextSelection('p1', 0, 6);
      final selectionAfterInsert = _collapsedTextSelection('p2', 2, 0);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: initialSelection,
      );

      final change = controller.insertImage(
        index: 1,
        blockId: 'img1',
        assetId: 'asset-1',
        file: r'C:\images\hero.png',
        width: 1280,
        height: 720,
        showWidth: 480,
        showHeight: 270,
        caption: 'Hero image',
        altText: 'Hero alt',
        selection: selectionAfterInsert,
      );

      expect(change.description, 'insertBlocks');
      expect(controller.document.blocks, hasLength(3));
      expect((controller.document.blocks[0] as TextBlockNode).plainText,
          'before');
      expect((controller.document.blocks[2] as TextBlockNode).plainText,
          'after');
      final image = controller.document.blocks[1] as ImageBlockNode;
      expect(image.id, 'img1');
      expect(image.assetId, 'asset-1');
      expect(image.file, r'C:\images\hero.png');
      expect(image.width, 1280);
      expect(image.height, 720);
      expect(image.showWidth, 480);
      expect(image.showHeight, 270);
      expect(image.caption, 'Hero image');
      expect(image.altText, 'Hero alt');
      expect(controller.selection, selectionAfterInsert);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(2));
      expect(controller.selection, initialSelection);

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks[1], isA<ImageBlockNode>());
      expect(controller.selection, selectionAfterInsert);

      controller.dispose();
    });

    test('defaults to appending when no index is supplied', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
          ],
        ),
      );

      controller.insertImage(blockId: 'img1', file: '/tmp/local.png');

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks.last, isA<ImageBlockNode>());
      final image = controller.document.blocks.last as ImageBlockNode;
      expect(image.id, 'img1');
      expect(image.file, '/tmp/local.png');

      controller.dispose();
    });

    test('is blocked by read and comment permissions', () {
      for (final permission in <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'before')],
              ),
            ],
          ),
          permission: permission,
        );

        final change = controller.insertImage(
          blockId: 'img-$permission',
          file: '/tmp/blocked.png',
        );

        expect(change.isNoop, isTrue);
        expect(change.description, 'permission:blocked:insertBlocks');
        expect(controller.document.blocks, hasLength(1));
        expect(controller.document.blocks.single, isA<TextBlockNode>());
        expect(controller.canUndo, isFalse);

        controller.dispose();
      }
    });
  });

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
