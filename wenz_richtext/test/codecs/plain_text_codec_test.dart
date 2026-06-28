import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  group('PlainTextCodec', () {
    test('separates paragraphs with a blank line', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First paragraph.')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second paragraph.')],
          ),
        ],
      );
      const codec = PlainTextCodec();

      expect(
        codec.encode(document),
        'First paragraph.\n\nSecond paragraph.',
      );
    });

    test('preserves inline text without attributes', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'bo', attributes: TextAttributes(bold: true)),
              TextRun(text: 'ld', attributes: TextAttributes(italic: true)),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'label': 'team'},
              ),
            ],
          ),
        ],
      );
      const codec = PlainTextCodec();

      // Embeds contribute their plainText (e.g. '@team') — export is about
      // readable text, not attribute preservation.
      expect(codec.encode(document), contains('bold'));
    });

    test('exports mixed ordered and todo list markers', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ordered1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'plain ordered')],
          ),
          TextBlockNode(
            id: 'orderedTodo1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: false),
            content: <InlineNode>[TextRun(text: 'ordered todo')],
          ),
          TextBlockNode(
            id: 'task1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'unordered todo')],
          ),
          TextBlockNode(
            id: 'ordered2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'restarted ordered')],
          ),
        ],
      );
      const codec = PlainTextCodec();

      expect(
        codec.encode(document),
        '1. plain ordered\n\n'
        '2. [ ] ordered todo\n\n'
        '- [x] unordered todo\n\n'
        '1. restarted ordered',
      );
    });

    test('keeps internal newlines inside a code block', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'c1',
            code: 'void main() {\n  print(1);\n}',
            language: 'dart',
          ),
        ],
      );
      const codec = PlainTextCodec();

      expect(
        codec.encode(document),
        'void main() {\n  print(1);\n}',
      );
    });

    test('renders sentinels for non-text blocks by default', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'intro')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
          DividerBlockNode(id: 'd1'),
          VideoBlockNode(id: 'v1', assetId: 'clip'),
          FileBlockNode(id: 'f1', assetId: 'doc', name: 'plan.pdf'),
        ],
      );
      const codec = PlainTextCodec();
      final output = codec.encode(document);

      expect(output, contains('intro'));
      expect(output, contains('[image: hero.png]'));
      expect(output, contains('---'));
      expect(output, contains('[video: clip]'));
      expect(output, contains('[file: plan.pdf]'));
      // Each block separated by a blank line.
      expect(output.split('\n\n'), hasLength(5));
    });

    test('image sentinel prefers caption then alt text', () {
      const codec = PlainTextCodec();

      expect(
        codec.encode(
          const RichTextDocument(
            blocks: <BlockNode>[
              ImageBlockNode(
                id: 'img1',
                assetId: 'hero',
                file: 'hero.png',
                caption: 'Hero caption',
                altText: 'Hero alt',
              ),
              ImageBlockNode(
                id: 'img2',
                assetId: 'chart',
                altText: 'Chart alt',
              ),
            ],
          ),
        ),
        '[image: Hero caption]\n\n[image: Chart alt]',
      );
    });

    test('video sentinel prefers title then playable source', () {
      const codec = PlainTextCodec();

      expect(
        codec.encode(
          const RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(
                id: 'video1',
                assetId: 'video-1',
                playbackUrl: 'https://cdn.example.com/video.mp4',
                title: 'Launch clip',
              ),
            ],
          ),
        ),
        '[video: Launch clip]',
      );

      expect(
        codec.encode(
          const RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(
                id: 'video2',
                assetId: 'video-2',
                playbackUrl: 'https://cdn.example.com/video.mp4',
              ),
            ],
          ),
        ),
        '[video: https://cdn.example.com/video.mp4]',
      );
    });

    test('omits empty blocks when configured', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'only this')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'hero'),
          DividerBlockNode(id: 'd1'),
        ],
      );
      const codec = PlainTextCodec(omitEmptyBlocks: true);

      expect(codec.encode(document), 'only this');
    });

    test('exports an empty document as an empty string', () {
      const codec = PlainTextCodec();
      expect(codec.encode(const RichTextDocument()), '');
    });

    test('controller.toPlainText mirrors the codec', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'A')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'B')],
            ),
          ],
        ),
      );

      expect(controller.toPlainText(), 'A\n\nB');
    });

    test('exports a table block via its plainText', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c00',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c00-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'A1')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'c01',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c01-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'B1')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      const codec = PlainTextCodec();

      // Table plainText already joins cells/rows; the codec wraps it as a
      // single paragraph.
      expect(codec.encode(document), contains('A1'));
      expect(codec.encode(document), contains('B1'));
    });

    test('exports callout body after deletion without metadata', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.warningVariant,
            title: 'Heads up',
            icon: '!',
            attributes: BlockAttributes(anchor: 'note-anchor'),
            content: <InlineNode>[TextRun(text: 'Keep body')],
          ),
        ],
      );
      const codec = PlainTextCodec();

      expect(codec.encode(document), 'Heads up\nKeep body');
      expect(codec.encode(document), isNot(contains('warning')));
      expect(codec.encode(document), isNot(contains('note-anchor')));
      expect(codec.encode(document), isNot(contains('!')));
    });
  });
}
