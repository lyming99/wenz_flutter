import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('WenzRichTextController.insertImage', () {
    test('inserts full metadata at an explicit index and supports undo redo',
        () {
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
      expect(
          (controller.document.blocks[0] as TextBlockNode).plainText, 'before');
      expect(
          (controller.document.blocks[2] as TextBlockNode).plainText, 'after');
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

  group('WenzRichTextController.pasteExternalImages', () {
    test('pastes a single image with metadata and supports redo', () {
      final initialSelection = _collapsedTextSelection('p1', 0, 1);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: initialSelection,
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/single.png',
            caption: 'single caption',
            altText: 'single alt',
          ),
        ],
      );

      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(result.insertedImageCount, 1);
      expect(controller.document.blocks, hasLength(3));
      final image = controller.document.blocks[1] as ImageBlockNode;
      expect(image.file, 'C:/tmp/single.png');
      expect(image.caption, 'single caption');
      expect(image.altText, 'single alt');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect(
          (controller.document.blocks.single as TextBlockNode).plainText, 'ab');
      expect(controller.selection, initialSelection);

      expect(controller.redo(), isTrue);
      final redoneImage = controller.document.blocks[1] as ImageBlockNode;
      expect(redoneImage.file, 'C:/tmp/single.png');
      expect(redoneImage.caption, 'single caption');
      expect(redoneImage.altText, 'single alt');

      controller.dispose();
    });

    test('pastes drop-prepared image descriptions with fallback metadata', () {
      final initialSelection = _collapsedTextSelection('p1', 0, 1);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: initialSelection,
      );
      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/Drop%20Image.png',
            caption: '   ',
            altText: '',
            width: 640,
            height: 360,
          ),
        ],
      );
      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(result.insertedImageCount, 1);
      final image = controller.document.blocks[1] as ImageBlockNode;
      expect(image.file, 'C:/tmp/Drop%20Image.png');
      expect(image.caption, 'Drop Image');
      expect(image.altText, 'Drop Image');
      expect(image.width, 640);
      expect(image.height, 360);
      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect(controller.selection, initialSelection);
      expect(controller.redo(), isTrue);
      final redoneImage = controller.document.blocks[1] as ImageBlockNode;
      expect(redoneImage.caption, 'Drop Image');
      expect(redoneImage.width, 640);
      controller.dispose();
    });

    test('pastes multiple images through block paste history', () {
      final initialSelection = _collapsedTextSelection('p1', 0, 1);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: initialSelection,
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/first.png',
            caption: 'first',
            altText: 'first alt',
          ),
          ExternalImageBlockDescription(
            file: 'C:/tmp/second.jpg',
            caption: 'second',
            altText: 'second alt',
          ),
        ],
      );

      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(result.insertedImageCount, 2);
      expect(result.change?.description, 'pasteBlocks');
      expect(controller.document.blocks, hasLength(4));
      expect((controller.document.blocks[0] as TextBlockNode).plainText, 'a');
      final first = controller.document.blocks[1] as ImageBlockNode;
      final second = controller.document.blocks[2] as ImageBlockNode;
      expect(first.file, 'C:/tmp/first.png');
      expect(first.caption, 'first');
      expect(first.altText, 'first alt');
      expect(second.file, 'C:/tmp/second.jpg');
      expect(second.caption, 'second');
      expect((controller.document.blocks[3] as TextBlockNode).plainText, 'b');
      expect(controller.selection?.extent.path.isBlockText, isTrue);
      expect(controller.selection?.extent.blockId,
          controller.document.blocks[3].id);
      expect(controller.selection?.extent.offset, 0);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect(
          (controller.document.blocks.single as TextBlockNode).plainText, 'ab');
      expect(controller.selection, initialSelection);

      controller.dispose();
    });

    test('replaces selected text and restores it with one undo', () {
      final selection = _textSelection('p1', 0, 1, 3);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abcd')],
            ),
          ],
        ),
        selection: selection,
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/replacement.png',
            caption: 'replacement',
            altText: 'replacement',
          ),
        ],
      );

      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(controller.document.blocks, hasLength(3));
      expect((controller.document.blocks[0] as TextBlockNode).plainText, 'a');
      expect((controller.document.blocks[1] as ImageBlockNode).file,
          'C:/tmp/replacement.png');
      expect((controller.document.blocks[2] as TextBlockNode).plainText, 'd');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect((controller.document.blocks.single as TextBlockNode).plainText,
          'abcd');
      expect(controller.selection, selection);

      controller.dispose();
    });

    test('replaces a selected object block without leaving the old object', () {
      final selection = _objectSelection('old-image', 1);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'before',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
            ImageBlockNode(
              id: 'old-image',
              assetId: 'old',
              file: 'C:/tmp/old.png',
            ),
            TextBlockNode(
              id: 'after',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'after')],
            ),
          ],
        ),
        selection: selection,
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/new.png',
            caption: 'new',
            altText: 'new',
          ),
        ],
      );

      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(controller.document.blocks.any((block) => block.id == 'old-image'),
          isFalse);
      expect(controller.document.blocks[0].id, 'before');
      final pasted = controller.document.blocks[1] as ImageBlockNode;
      expect(pasted.file, 'C:/tmp/new.png');
      expect(controller.document.blocks.last.id, 'after');

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.blocks[1].id, 'old-image');
      expect(controller.selection, selection);

      controller.dispose();
    });

    test('inserts from a table cell after the table block', () {
      final selection = _collapsedTableCellSelection(offset: 1);
      final controller = WenzRichTextController(
        document: _tableDocument(),
        selection: selection,
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/from-cell.png',
            caption: 'from cell',
            altText: 'from cell',
          ),
        ],
      );

      expect(result.status, ExternalImagePasteStatus.inserted);
      expect(result.change?.description, 'insertBlocks');
      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0], isA<TableBlockNode>());
      final image = controller.document.blocks[1] as ImageBlockNode;
      expect(image.file, 'C:/tmp/from-cell.png');
      expect(controller.selection?.start.blockId, image.id);
      expect(controller.selection?.start.path.isBlockObject, isTrue);
      expect(controller.selection?.end.offset, 1);

      expect(controller.undo(), isTrue);
      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.blocks.single, isA<TableBlockNode>());
      expect(controller.selection, selection);

      controller.dispose();
    });

    test('returns emptyInput for an empty paste request without history', () {
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
        selection: _collapsedTextSelection('p1', 0, 0),
      );

      final result = controller.pasteExternalImages(
        const <ExternalImageBlockDescription>[],
      );

      expect(result.status, ExternalImagePasteStatus.emptyInput);
      expect(result.insertedImageCount, 0);
      expect(result.change, isNull);
      expect(controller.document.blocks, hasLength(1));
      expect(controller.canUndo, isFalse);

      controller.dispose();
    });

    test('returns assertion-friendly failures for invalid input and permission',
        () {
      final invalidController = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'before')],
            ),
          ],
        ),
        selection: _collapsedTextSelection('p1', 0, 0),
      );

      final invalidResult = invalidController.pasteExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: '   ',
            caption: 'blank',
            altText: 'blank',
          ),
        ],
      );

      expect(invalidResult.status, ExternalImagePasteStatus.noInsertableImages);
      expect(invalidResult.change, isNull);
      expect(invalidController.canUndo, isFalse);
      invalidController.dispose();

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
          selection: _collapsedTextSelection('p1', 0, 0),
          permission: permission,
        );

        final result = controller.pasteExternalImages(
          const <ExternalImageBlockDescription>[
            ExternalImageBlockDescription(
              file: 'C:/tmp/blocked.png',
              caption: 'blocked',
              altText: 'blocked',
            ),
          ],
        );

        expect(result.status, ExternalImagePasteStatus.permissionDenied);
        expect(result.change?.isNoop, isTrue);
        expect(result.change?.metadata?['reason'], 'permissionDenied');
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

    test('records image display resize as one undoable update', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
              width: 640,
              height: 320,
              showWidth: 180,
              showHeight: 90,
            ),
          ],
        ),
      );

      final change = controller.updateImageBlock(
        blockIndex: 0,
        showWidth: 240,
        showHeight: 120,
      );

      expect(change.description, 'updateImageBlock');
      final resized = controller.document.blocks.single as ImageBlockNode;
      expect(resized.showWidth, 240);
      expect(resized.showHeight, 120);
      expect(controller.canUndo, isTrue);

      expect(controller.undo(), isTrue);
      final undone = controller.document.blocks.single as ImageBlockNode;
      expect(undone.showWidth, 180);
      expect(undone.showHeight, 90);
      expect(controller.canUndo, isFalse);

      expect(controller.redo(), isTrue);
      final redone = controller.document.blocks.single as ImageBlockNode;
      expect(redone.showWidth, 240);
      expect(redone.showHeight, 120);

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

DocumentSelection _textSelection(
  String blockId,
  int blockIndex,
  int startOffset,
  int endOffset,
) {
  final start = DocumentPosition.text(
    blockId: blockId,
    blockIndex: blockIndex,
    offset: startOffset,
  );
  final end = start.copyWith(offset: endOffset);
  return DocumentSelection(base: start, extent: end);
}

DocumentSelection _objectSelection(String blockId, int blockIndex) {
  final start = DocumentPosition.object(
    blockId: blockId,
    blockIndex: blockIndex,
    offset: 0,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
}

DocumentSelection _collapsedTableCellSelection({required int offset}) {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

RichTextDocument _tableDocument() {
  return const RichTextDocument(
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
                    content: <InlineNode>[TextRun(text: 'cell')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
