import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController video blocks', () {
    test(
        'insertVideo writes metadata, selects the video, and supports undo redo',
        () {
      final initialSelection = _collapsedTextSelection('p1', 0, 6);
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

      final change = controller.insertVideo(
        index: 1,
        blockId: 'video1',
        playbackUrl: 'https://cdn.example.com/intro.mp4',
        coverUrl: 'https://cdn.example.com/intro.jpg',
        title: 'Intro',
        description: 'Opening clip',
        aspectRatio: 4 / 3,
        uploadStatus: FileUploadStatus.uploading,
      );

      expect(change.description, 'insertVideoBlock');
      expect(controller.document.blocks, hasLength(3));
      expect(
          (controller.document.blocks[0] as TextBlockNode).plainText, 'before');
      expect(
          (controller.document.blocks[2] as TextBlockNode).plainText, 'after');
      final video = controller.document.blocks[1] as VideoBlockNode;
      expect(video.id, 'video1');
      expect(video.effectivePlaybackUrl, 'https://cdn.example.com/intro.mp4');
      expect(video.coverUrl, 'https://cdn.example.com/intro.jpg');
      expect(video.title, 'Intro');
      expect(video.description, 'Opening clip');
      expect(video.aspectRatio, 4 / 3);
      expect(video.uploadStatus, FileUploadStatus.uploading);
      expect(controller.selection?.start.blockId, 'video1');
      expect(controller.selection?.start.path.isBlockObject, isTrue);
      expect(controller.selection?.start.offset, 0);
      expect(controller.selection?.end.offset, 1);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(2));
      expect(controller.selection, initialSelection);

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks[1], isA<VideoBlockNode>());
      expect(controller.selection?.start.blockId, 'video1');

      controller.dispose();
    });

    test('updateVideoBlock updates metadata and participates in undo redo', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'video1',
              assetId: 'draft',
              playbackUrl: 'https://cdn.example.com/draft.mp4',
              file: 'draft.mov',
              coverUrl: 'draft.jpg',
              title: 'Draft',
              description: 'Old description',
              aspectRatio: 16 / 9,
              uploadStatus: FileUploadStatus.uploading,
              uploadError: 'waiting',
            ),
          ],
        ),
      );

      final change = controller.updateVideoBlock(
        blockIndex: 0,
        assetId: 'final',
        playbackUrl: 'https://cdn.example.com/final.mp4',
        file: '',
        coverUrl: 'final.jpg',
        title: 'Final',
        description: 'Published clip',
        clearAspectRatio: true,
        uploadStatus: FileUploadStatus.uploaded,
        uploadError: '',
      );

      expect(change.description, 'updateVideoBlock');
      final updated = controller.document.blocks.single as VideoBlockNode;
      expect(updated.assetId, 'final');
      expect(updated.effectivePlaybackUrl, 'https://cdn.example.com/final.mp4');
      expect(updated.file, isEmpty);
      expect(updated.coverUrl, 'final.jpg');
      expect(updated.title, 'Final');
      expect(updated.description, 'Published clip');
      expect(updated.aspectRatio, isNull);
      expect(updated.uploadStatus, FileUploadStatus.uploaded);
      expect(updated.uploadError, isEmpty);

      expect(controller.undo(), isTrue);
      final undone = controller.document.blocks.single as VideoBlockNode;
      expect(undone.assetId, 'draft');
      expect(undone.aspectRatio, 16 / 9);
      expect(undone.uploadStatus, FileUploadStatus.uploading);
      expect(undone.uploadError, 'waiting');

      expect(controller.redo(), isTrue);
      final redone = controller.document.blocks.single as VideoBlockNode;
      expect(redone.assetId, 'final');
      expect(redone.uploadStatus, FileUploadStatus.uploaded);

      controller.dispose();
    });

    test('copyVideoBlock produces a paste payload preserving video fields', () {
      final source = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'video1',
              assetId: 'asset-1',
              playbackUrl: 'https://cdn.example.com/source.mp4',
              coverUrl: 'source.jpg',
              title: 'Source',
              description: 'Copied clip',
              aspectRatio: 21 / 9,
              uploadStatus: FileUploadStatus.uploaded,
            ),
          ],
        ),
      );
      final payload = source.copyVideoBlock(blockIndex: 0);

      expect(payload, isNotNull);

      final target = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: _collapsedTextSelection('p1', 0, 0),
      );
      target.pasteText(payload!);

      final pasted = target.document.blocks.single as VideoBlockNode;
      expect(pasted.id, isNot('video1'));
      expect(pasted.assetId, 'asset-1');
      expect(pasted.playbackUrl, 'https://cdn.example.com/source.mp4');
      expect(pasted.coverUrl, 'source.jpg');
      expect(pasted.title, 'Source');
      expect(pasted.description, 'Copied clip');
      expect(pasted.aspectRatio, 21 / 9);
      expect(pasted.uploadStatus, FileUploadStatus.uploaded);

      source.dispose();
      target.dispose();
    });

    test('deleteVideoBlock removes the block and supports undo redo', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            VideoBlockNode(
              id: 'video1',
              assetId: 'asset-1',
              playbackUrl: 'https://cdn.example.com/source.mp4',
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
      );

      final change = controller.deleteVideoBlock(blockIndex: 1);

      expect(change.description, 'deleteVideoBlock');
      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0].id, 'p1');
      expect(controller.document.blocks[1].id, 'p2');
      expect(controller.selection?.extent.blockId, 'p1');
      expect(controller.selection?.extent.offset, 6);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks[1], isA<VideoBlockNode>());

      expect(controller.redo(), isTrue);
      expect(controller.document.blocks, hasLength(2));

      controller.dispose();
    });

    test('video helpers no-op for non-video targets', () {
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

      expect(controller.copyVideoBlock(blockIndex: 0), isNull);

      final update =
          controller.updateVideoBlock(blockIndex: 0, title: 'ignored');
      expect(update.isNoop, isTrue);
      expect(controller.canUndo, isFalse);

      final deletion = controller.deleteVideoBlock(blockIndex: 0);
      expect(deletion.isNoop, isTrue);
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
