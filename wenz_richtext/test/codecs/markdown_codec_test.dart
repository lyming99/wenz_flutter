import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// C2 — verifies the Markdown codec export/import against golden strings.
/// See `docs/acceptance_report.md` task C2 / acceptance item 7.4.
void main() {
  const codec = MarkdownCodec();

  group('MarkdownCodec.encode (export)', () {
    test('heading levels', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
          TextBlockNode(
            id: 'h3',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3),
            content: <InlineNode>[TextRun(text: 'Subtitle')],
          ),
        ],
      );
      expect(codec.encode(document), '# Title\n\n### Subtitle');
    });

    test('paragraph with bold + italic + strikethrough inline', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a ', attributes: TextAttributes()),
              TextRun(
                text: 'bold',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'ital',
                attributes: TextAttributes(italic: true),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'gone',
                attributes: TextAttributes(lineThrough: true),
              ),
            ],
          ),
        ],
      );
      // Plain words carry no trigger chars, so no escaping; markup wraps each.
      expect(
        codec.encode(document),
        'a **bold** *ital* ~~gone~~',
      );
    });

    test('link run', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'see '),
              TextRun(
                text: 'docs',
                attributes: TextAttributes(url: 'https://x.dev'),
              ),
            ],
          ),
        ],
      );
      expect(
        codec.encode(document),
        'see [docs](https://x.dev)',
      );
    });

    test('inline embeds export readable fallbacks', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Ask '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' '),
              InlineEmbed(
                embedType: 'emoji',
                data: <String, Object?>{'emoji': '😀'},
              ),
              TextRun(text: ' from '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
            ],
          ),
        ],
      );

      expect(codec.encode(document), 'Ask x^2 😀 from @Ada');
    });

    test('block embed exports readable fallback', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'embed1',
            embedType: 'crm-card',
            fallbackText: 'Acme account',
          ),
        ],
      );

      expect(codec.encode(document), '[crm-card embed: Acme account]');
    });

    test('blockquote', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'q1',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'quoted')],
          ),
        ],
      );
      expect(codec.encode(document), '> quoted');
    });

    test('callout degrades to blockquote with visible metadata', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'co1',
            variant: 'warning',
            title: 'Heads up',
            icon: '🚨',
            content: <InlineNode>[TextRun(text: 'Body')],
          ),
        ],
      );

      expect(codec.encode(document), '> **🚨 Heads up**\n> Body');
    });

    test('unordered + ordered + task list', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'one')],
          ),
          TextBlockNode(
            id: 'li2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'two')],
          ),
          TextBlockNode(
            id: 'li3',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'done')],
          ),
          TextBlockNode(
            id: 'li4',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'todo')],
          ),
        ],
      );
      expect(
        codec.encode(document),
        '- one\n\n1. two\n\n- [x] done\n\n- [ ] todo',
      );
    });

    test('code block with language', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'c1',
            language: 'dart',
            code: 'var x = 1;\nprint(x);',
          ),
        ],
      );
      expect(codec.encode(document), '```dart\nvar x = 1;\nprint(x);\n```');
    });

    test('table with alignment', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              columnAlignments: <int, String>{1: 'right'},
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'h0',
                    isHeader: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'h0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'A')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'h1',
                    isHeader: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'h1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'B')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'b0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'b0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: '1')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'b1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'b1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: '2')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      expect(
        codec.encode(document),
        'A | B\n--- | ---:\n1 | 2',
      );
    });

    test('image, divider', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'im1',
            assetId: 'https://x.dev/a.png',
            file: 'alt',
          ),
          DividerBlockNode(id: 'd1'),
        ],
      );
      expect(
        codec.encode(document),
        '![alt](https://x.dev/a.png)\n\n---',
      );
    });

    test('image uses altText and caption title when present', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'im1',
            assetId: 'https://x.dev/a.png',
            file: 'fallback-name',
            caption: 'Hero caption',
            altText: 'Hero alt',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '![Hero alt](https://x.dev/a.png "Hero caption")',
      );
    });

    test('file uses display name and download URL', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          FileBlockNode(
            id: 'file1',
            assetId: 'asset-1',
            name: 'report.pdf',
            downloadUrl: 'https://cdn.example.com/report.pdf',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '[report.pdf](https://cdn.example.com/report.pdf)',
      );
    });
  });

  group('MarkdownCodec.decode (import)', () {
    test('heading levels parsed with correct level', () {
      const source = '# Title\n\n### Subtitle';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(2));
      expect(doc.blocks[0], isA<TextBlockNode>());
      expect((doc.blocks[0] as TextBlockNode).attributes.level, 1);
      expect(doc.blocks[0].plainText, 'Title');
      expect((doc.blocks[1] as TextBlockNode).attributes.level, 3);
    });

    test('paragraph with inline bold + italic + strike', () {
      const source = 'this is **bold** and *ital* and ~~gone~~';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      final para = doc.blocks[0] as TextBlockNode;
      // The inline parser splits into runs with the right attributes.
      final bold = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.bold == true);
      final ital = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.italic == true);
      final strike = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.lineThrough == true);
      expect(bold, isNotEmpty);
      expect(bold.first.text, 'bold');
      expect(ital.first.text, 'ital');
      expect(strike.first.text, 'gone');
    });

    test('link parsed with url', () {
      const source = 'see [docs](https://x.dev)';
      final doc = codec.decode(source);
      final para = doc.blocks[0] as TextBlockNode;
      final linked = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.url == 'https://x.dev');
      expect(linked, isNotEmpty);
      expect(linked.first.text, 'docs');
    });

    test('unordered, ordered, and task list items', () {
      const source = '- one\n1. two\n- [x] done\n- [ ] todo';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(4));
      expect(doc.blocks.every((b) => b.type == BlockType.listItem), isTrue);
      final items = doc.blocks.cast<TextBlockNode>();
      expect(items[0].attributes.listType, isNull); // unordered
      expect(items[1].attributes.listType, 'ordered');
      expect(items[2].attributes.listType, 'task');
      expect(items[2].attributes.checked, true);
      expect(items[3].attributes.checked, false);
    });

    test('code fence preserves content verbatim and language', () {
      const source = '```dart\n# not a heading\nvar x = 1;\n```';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      final code = doc.blocks[0] as CodeBlockNode;
      expect(code.language, 'dart');
      // The `#` inside the fence is NOT parsed as a heading.
      expect(code.code, '# not a heading\nvar x = 1;');
    });

    test('blockquote aggregates consecutive > lines', () {
      const source = '> line one\n> line two';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0].type, BlockType.quote);
      expect(doc.blocks[0].plainText, 'line one line two');
    });

    test('GFM table parses rows and alignment', () {
      const source = '| A | B |\n| --- | ---: |\n| 1 | 2 |';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      final table = doc.blocks[0] as TableBlockNode;
      expect(table.table.rowCount, 2);
      expect(table.table.columnCount, 2);
      expect(table.table.columnAlignments[1], 'right');
      // First row cells are marked as headers.
      expect(table.table.rows[0][0].isHeader, isTrue);
    });

    test('thematic break → divider', () {
      const source = '---';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<DividerBlockNode>());
    });

    test('standalone image → image block', () {
      const source = '![alt](https://x.dev/a.png)';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<ImageBlockNode>());
      final image = doc.blocks[0] as ImageBlockNode;
      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'alt');
      expect(image.altText, 'alt');
    });

    test('standalone image title becomes caption', () {
      const source = '![alt](https://x.dev/a.png "Hero caption")';
      final doc = codec.decode(source);
      final image = doc.blocks.single as ImageBlockNode;

      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'alt');
      expect(image.altText, 'alt');
      expect(image.caption, 'Hero caption');
    });

    test('standalone video placeholder becomes video block', () {
      const source = '![video](local/video.mp4)';
      final doc = codec.decode(source);

      expect(doc.blocks, hasLength(1));
      final video = doc.blocks.single as VideoBlockNode;
      expect(video.assetId, 'local/video.mp4');
      expect(video.file, isEmpty);
    });

    test('unrecognised content falls back to a paragraph (no throw)', () {
      const source = 'just some text\nwith no markdown';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0].type, BlockType.paragraph);
      expect(doc.blocks[0].plainText, 'just some text with no markdown');
    });
  });

  group('MarkdownCodec round-trip', () {
    test('code + divider + list survive export → import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', language: 'dart', code: 'var x = 1;'),
          DividerBlockNode(id: 'd1'),
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'first')],
          ),
        ],
      );
      final exported = codec.encode(document);
      final reimported = codec.decode(exported);
      expect(reimported.blocks, hasLength(3));
      expect(reimported.blocks[0].type, BlockType.code);
      expect((reimported.blocks[0] as CodeBlockNode).code, 'var x = 1;');
      expect(reimported.blocks[1].type, BlockType.divider);
      expect(reimported.blocks[2].type, BlockType.listItem);
    });

    test('plain text round-trips through escape/unescape', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'a*b c')],
          ),
        ],
      );
      final exported = codec.encode(document);
      final reimported = codec.decode(exported);
      expect(reimported.blocks[0].plainText, 'a*b c');
    });

    test('file stays readable and video restores from Markdown fallback', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          FileBlockNode(
            id: 'file1',
            assetId: 'asset-1',
            name: 'report.pdf',
            downloadUrl: 'https://cdn.example.com/report.pdf',
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'video-1',
            file: 'local/video.mp4',
          ),
        ],
      );

      final exported = codec.encode(document);
      final reimported = codec.decode(exported);

      expect(
        exported,
        '[report.pdf](https://cdn.example.com/report.pdf)\n\n'
        '![video](local/video.mp4)',
      );
      expect(reimported.blocks, hasLength(2));

      final fileParagraph = reimported.blocks[0] as TextBlockNode;
      expect(fileParagraph.plainText, 'report.pdf');
      final linkedRun = fileParagraph.content.whereType<TextRun>().single;
      expect(linkedRun.attributes.url, 'https://cdn.example.com/report.pdf');

      final video = reimported.blocks[1] as VideoBlockNode;
      expect(video.assetId, 'local/video.mp4');
    });
  });

  group('WenzRichTextController markdown helpers', () {
    test('toMarkdown / loadMarkdown / tryLoadMarkdown', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'h1',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Hi')],
            ),
          ],
        ),
      );
      expect(controller.toMarkdown(), contains('##'));

      // loadMarkdown replaces the document.
      controller.loadMarkdown('# Replaced');
      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.blocks[0].type, BlockType.heading);

      // tryLoadMarkdown always succeeds for Markdown content.
      final result = controller.tryLoadMarkdown('plain text');
      expect(result.ok, isTrue);
      expect(result.document, isNotNull);
      expect(result.document!.blocks[0].type, BlockType.paragraph);

      controller.dispose();
    });
  });
}
