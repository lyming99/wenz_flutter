import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const schema = DocumentSchema();

  group('DocumentSchema.normalize', () {
    test('empty document gets a paragraph', () {
      const empty = RichTextDocument();
      final normalized = schema.normalize(empty);

      expect(normalized.blocks, hasLength(1));
      expect(normalized.blocks.single, isA<TextBlockNode>());
      expect((normalized.blocks.single as TextBlockNode).type,
          BlockType.paragraph);
    });

    test('heading drops list-specific attributes', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(
              level: 2,
              listType: 'ordered',
              checked: true,
              indent: 1,
              alignment: 'center',
              anchor: 'intro',
            ),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      );
      final normalized = schema.normalize(doc);
      final block = normalized.blocks.single as TextBlockNode;

      expect(block.attributes.level, 2);
      expect(block.attributes.indent, 1);
      expect(block.attributes.alignment, 'center');
      expect(block.attributes.anchor, 'intro');
      // list-specific attrs stripped from a heading.
      expect(block.attributes.listType, isNull);
      expect(block.attributes.checked, isNull);
    });

    test('listItem canonicalises listType and clears level', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(
              level: 3,
              listType: 'li',
            ),
            content: <InlineNode>[TextRun(text: 'item')],
          ),
          TextBlockNode(
            id: 'li2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'oli'),
            content: <InlineNode>[TextRun(text: 'ordered')],
          ),
          TextBlockNode(
            id: 'li3',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'check'),
            content: <InlineNode>[TextRun(text: 'task')],
          ),
        ],
      );
      final normalized = schema.normalize(doc);
      final blocks = normalized.blocks.cast<TextBlockNode>();

      // 'li' -> null (unordered).
      expect(blocks[0].attributes.listType, isNull);
      expect(blocks[0].attributes.level, isNull);
      // 'oli' -> 'ordered'.
      expect(blocks[1].attributes.listType, 'ordered');
      // 'check' -> 'task'.
      expect(blocks[2].attributes.listType, 'task');
      expect(blocks[2].attributes.checked, isFalse);
    });

    test('listItem preserves ordered todo checked state', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'todo1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'done')],
          ),
          TextBlockNode(
            id: 'todo2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: false),
            content: <InlineNode>[TextRun(text: 'open')],
          ),
          TextBlockNode(
            id: 'ordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'plain ordered')],
          ),
        ],
      );
      final blocks = schema.normalize(doc).blocks.cast<TextBlockNode>();

      expect(blocks[0].attributes.listType, 'ordered');
      expect(blocks[0].attributes.checked, isTrue);
      expect(blocks[1].attributes.listType, 'ordered');
      expect(blocks[1].attributes.checked, isFalse);
      expect(blocks[2].attributes.listType, 'ordered');
      expect(blocks[2].attributes.checked, isNull);
    });

    test('non-list blocks drop listType and checked attributes', () {
      const listAttrs = BlockAttributes(
        listType: 'ordered',
        checked: true,
        anchor: 'keep-anchor',
      );
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code', code: 'x', attributes: listAttrs),
          DividerBlockNode(id: 'divider', attributes: listAttrs),
          BlockEmbedNode(
            id: 'embed',
            embedType: 'card',
            fallbackText: 'Card',
            attributes: listAttrs,
          ),
          TableBlockNode(
            id: 'table',
            table: TableModel(),
            attributes: listAttrs,
          ),
        ],
      );
      final normalized = schema.normalize(doc);

      for (final block in normalized.blocks) {
        expect(block.attributes.listType, isNull);
        expect(block.attributes.checked, isNull);
        expect(block.attributes.anchor, 'keep-anchor');
      }
    });

    test('paragraph drops level/listType/checked but keeps indent/alignment',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(
              level: 2,
              listType: 'ordered',
              checked: true,
              indent: 2,
              alignment: 'right',
            ),
            content: <InlineNode>[TextRun(text: 'p')],
          ),
        ],
      );
      final block = (schema.normalize(doc).blocks.single as TextBlockNode);

      expect(block.attributes.level, isNull);
      expect(block.attributes.listType, isNull);
      expect(block.attributes.checked, isNull);
      expect(block.attributes.indent, 2);
      expect(block.attributes.alignment, 'right');
    });

    test('block embed normalizes type and fallback text', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'embed1',
            embedType: '  ',
            fallbackText: '  Acme account  ',
          ),
        ],
      );

      final block = schema.normalize(doc).blocks.single as BlockEmbedNode;

      expect(block.embedType, 'custom');
      expect(block.fallbackText, 'Acme account');
    });

    test('valid video block normalizes protocol fields', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: ' asset-1 ',
            playbackUrl: ' https://cdn.example.com/video.mp4 ',
            file: ' file:///tmp/video.mp4 ',
            coverUrl: ' https://cdn.example.com/poster.jpg ',
            title: ' Launch demo ',
            description: ' Walkthrough ',
            aspectRatio: -1,
            uploadStatus: FileUploadStatus.failed,
            uploadError: ' timeout ',
          ),
        ],
      );

      final block = schema.normalize(doc).blocks.single as VideoBlockNode;

      expect(block.assetId, 'asset-1');
      expect(block.playbackUrl, 'https://cdn.example.com/video.mp4');
      expect(block.file, 'file:///tmp/video.mp4');
      expect(block.coverUrl, 'https://cdn.example.com/poster.jpg');
      expect(block.title, 'Launch demo');
      expect(block.description, 'Walkthrough');
      expect(block.aspectRatio, isNull);
      expect(block.effectiveAspectRatio,
          closeTo(VideoBlockNode.defaultAspectRatio, 0.0001));
      expect(block.uploadStatus, FileUploadStatus.failed);
      expect(block.uploadError, 'timeout');
    });

    test('video image file and embed stay distinct when valid', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'video-asset'),
          ImageBlockNode(id: 'image1', assetId: 'image-asset'),
          FileBlockNode(id: 'file1', assetId: 'file-asset'),
          BlockEmbedNode(id: 'embed1', embedType: 'video-card'),
        ],
      );

      final normalized = schema.normalize(doc);

      expect(normalized.blocks[0], isA<VideoBlockNode>());
      expect(normalized.blocks[1], isA<ImageBlockNode>());
      expect(normalized.blocks[2], isA<FileBlockNode>());
      expect(normalized.blocks[3], isA<BlockEmbedNode>());
    });

    test('video block without a source degrades to video embed', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: '  ',
            coverUrl: ' https://cdn.example.com/poster.jpg ',
            title: ' Missing source ',
            description: ' Kept as fallback metadata ',
          ),
        ],
      );

      final block = schema.normalize(doc).blocks.single as BlockEmbedNode;

      expect(block.embedType, 'video');
      expect(block.fallbackText, 'Missing source');
      expect(block.data,
          containsPair('coverUrl', 'https://cdn.example.com/poster.jpg'));
      expect(block.data, containsPair('title', 'Missing source'));
      expect(
          block.data, containsPair('description', 'Kept as fallback metadata'));
    });

    test('table cell with no blocks gets a paragraph', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(id: 'c1', blocks: <BlockNode>[]),
                ],
              ],
            ),
          ),
        ],
      );
      final table = schema.normalize(doc).blocks.single as TableBlockNode;

      expect(table.table.cellAt(0, 0)!.blocks, hasLength(1));
      expect(
        table.table.cellAt(0, 0)!.blocks.single,
        isA<TextBlockNode>(),
      );
    });

    test('indent is clamped to maxIndent', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(indent: 99),
            content: <InlineNode>[],
          ),
        ],
      );
      final block = (schema.normalize(doc).blocks.single as TextBlockNode);
      expect(block.attributes.indent, 8);
    });

    test('coalesces adjacent equal text runs during normalization', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'one'),
              TextRun(text: ' two'),
              TextRun(
                text: ' bold',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(
                text: ' run',
                attributes: TextAttributes(bold: true),
              ),
            ],
          ),
        ],
      );

      final content =
          (schema.normalize(doc).blocks.single as TextBlockNode).content;

      expect(content, hasLength(2));
      expect((content[0] as TextRun).text, 'one two');
      expect((content[1] as TextRun).text, ' bold run');
    });

    test('idempotent on an already-normal document', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            attributes: BlockAttributes(indent: 1, alignment: 'center'),
            content: <InlineNode>[TextRun(text: 'hi')],
          ),
        ],
      );
      final once = schema.normalize(doc);
      final twice = schema.normalize(once);

      // Structural equality: normalising a normal doc changes nothing.
      expect(twice.blocks.length, once.blocks.length);
      expect((twice.blocks.single as TextBlockNode).attributes,
          (once.blocks.single as TextBlockNode).attributes);
    });

    test('code/image/divider blocks pass through unchanged', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'x'),
          DividerBlockNode(id: 'd1'),
        ],
      );
      final normalized = schema.normalize(doc);
      expect(normalized.blocks, hasLength(2));
      expect(normalized.blocks[0], isA<CodeBlockNode>());
      expect(normalized.blocks[1], isA<DividerBlockNode>());
    });
  });
}
