import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController file blocks', () {
    test('insertFile writes attachment metadata', () {
      final controller = WenzRichTextController();

      controller.insertFile(
        blockId: 'file1',
        assetId: 'asset-1',
        name: 'report.pdf',
        size: 4096,
        mimeType: 'application/pdf',
        downloadUrl: 'https://cdn.example.com/report.pdf',
        uploadStatus: FileUploadStatus.uploading,
      );

      final block = controller.document.blocks.last as FileBlockNode;
      expect(block.assetId, 'asset-1');
      expect(block.name, 'report.pdf');
      expect(block.size, 4096);
      expect(block.mimeType, 'application/pdf');
      expect(block.effectiveDownloadUrl, 'https://cdn.example.com/report.pdf');
      expect(block.uploadStatus, FileUploadStatus.uploading);

      controller.dispose();
    });

    test('updateFileBlock updates metadata and participates in undo redo', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            FileBlockNode(
              id: 'file1',
              assetId: 'draft',
              name: 'draft.pdf',
              size: 1024,
              mimeType: 'application/pdf',
              uploadStatus: FileUploadStatus.uploading,
            ),
          ],
        ),
      );

      final change = controller.updateFileBlock(
        blockIndex: 0,
        assetId: 'final',
        name: 'final.pdf',
        size: 2048,
        downloadUrl: 'https://cdn.example.com/final.pdf',
        uploadStatus: FileUploadStatus.uploaded,
        uploadError: '',
      );

      expect(change.description, 'updateFileBlock');
      final updated = controller.document.blocks.single as FileBlockNode;
      expect(updated.assetId, 'final');
      expect(updated.name, 'final.pdf');
      expect(updated.size, 2048);
      expect(updated.mimeType, 'application/pdf');
      expect(updated.effectiveDownloadUrl, 'https://cdn.example.com/final.pdf');
      expect(updated.uploadStatus, FileUploadStatus.uploaded);

      expect(controller.undo(), isTrue);
      final undone = controller.document.blocks.single as FileBlockNode;
      expect(undone.assetId, 'draft');
      expect(undone.name, 'draft.pdf');
      expect(undone.uploadStatus, FileUploadStatus.uploading);

      expect(controller.redo(), isTrue);
      final redone = controller.document.blocks.single as FileBlockNode;
      expect(redone.assetId, 'final');
      expect(redone.uploadStatus, FileUploadStatus.uploaded);

      controller.dispose();
    });

    test('updateFileBlock returns a no-op for non-file targets', () {
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

      final change = controller.updateFileBlock(
        blockIndex: 0,
        name: 'ignored.pdf',
      );

      expect(change.isNoop, isTrue);
      expect(controller.canUndo, isFalse);
      controller.dispose();
    });
  });
}
