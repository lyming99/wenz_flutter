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

    test('heading collapse state is not exported', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'h1',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 1),
              content: <InlineNode>[TextRun(text: 'Section')],
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Body stays exported')],
            ),
          ],
        ),
      );
      final outline = WenzOutlineController(editor: controller);
      addTearDown(outline.dispose);
      addTearDown(controller.dispose);
      expect(outline.collapseByBlockId('h1'), isTrue);

      final markdown = codec.encode(controller.document);

      expect(markdown, '# Section\n\nBody stays exported');
      expect(markdown, isNot(contains('collapse')));
      expect(markdown, isNot(contains('hidden')));
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

    test('font color degrades to plain Markdown text', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'plain '),
              TextRun(
                text: 'red',
                attributes: TextAttributes(color: 0xFFD81B60),
              ),
            ],
          ),
        ],
      );

      expect(codec.encode(document), 'plain red');
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

    test('quoted heading and list items keep their Markdown markers', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'qh',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2, quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted title')],
          ),
          TextBlockNode(
            id: 'qtodo',
            type: BlockType.listItem,
            attributes: BlockAttributes(
              listType: 'task',
              checked: false,
              quoted: true,
            ),
            content: <InlineNode>[TextRun(text: 'Quoted todo')],
          ),
          TextBlockNode(
            id: 'qordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted ordered')],
          ),
        ],
      );

      expect(
        codec.encode(document),
        '> ## Quoted title\n\n> - [ ] Quoted todo\n\n> 1. Quoted ordered',
      );
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

    test('ordered todo list items include checkbox marker', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'todo1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: false),
            content: <InlineNode>[TextRun(text: 'todo')],
          ),
          TextBlockNode(
            id: 'todo2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'done')],
          ),
          TextBlockNode(
            id: 'ordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'plain')],
          ),
        ],
      );

      expect(codec.encode(document), '1. [ ] todo\n\n1. [x] done\n\n1. plain');
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

    test('mermaid language variants export as canonical mermaid fence', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'm1',
            language: 'language-mermaid theme=dark',
            code: 'flowchart TD\n  A --> B',
          ),
          CodeBlockNode(
            id: 'm2',
            language: '{.mermaid}',
            code: 'sequenceDiagram\n  A->>B: hi',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '```mermaid\nflowchart TD\n  A --> B\n```\n\n'
        '```mermaid\nsequenceDiagram\n  A->>B: hi\n```',
      );
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
    test('import starts expanded with all heading content present', () {
      final document = codec.decode('# Section\n\nBody stays imported');
      final controller = WenzRichTextController(document: document);
      final outline = WenzOutlineController(editor: controller);
      addTearDown(outline.dispose);
      addTearDown(controller.dispose);

      expect(document.blocks, hasLength(2));
      expect(document.plainText, 'Section\nBody stays imported');
      expect(outline.collapsedBlockIds, isEmpty);
      expect(outline.hiddenBlockIds, isEmpty);
    });

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

    test('ordered todo list items keep ordered list type and checked state', () {
      const source = '1. [ ] todo\n  1. [x] nested\n1. plain';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(3));
      final items = doc.blocks.cast<TextBlockNode>();

      expect(items[0].attributes.listType, 'ordered');
      expect(items[0].attributes.checked, isFalse);
      expect(items[1].attributes.indent, 1);
      expect(items[1].attributes.listType, 'ordered');
      expect(items[1].attributes.checked, isTrue);
      expect(items[2].attributes.listType, 'ordered');
      expect(items[2].attributes.checked, isNull);
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

    test('mermaid code fences normalize language variants', () {
      const cases = <String>[
        '```mermaid\n# not a heading\nflowchart TD\n  A --> B\n```',
        '``` Mermaid \n# not a heading\nflowchart TD\n  A --> B\n```',
        '```MERMAID\n# not a heading\nflowchart TD\n  A --> B\n```',
        '```mermaid theme=dark\n# not a heading\nflowchart TD\n  A --> B\n```',
        '```language-mermaid\n# not a heading\nflowchart TD\n  A --> B\n```',
        '```{.mermaid}\n# not a heading\nflowchart TD\n  A --> B\n```',
        '```.language-mermaid\n# not a heading\nflowchart TD\n  A --> B\n```',
        '```{.language-mermaid}\n# not a heading\nflowchart TD\n  A --> B\n```',
        '~~~mermaid\n# not a heading\nflowchart TD\n  A --> B\n~~~',
        '```   mermaid   \n# not a heading\nflowchart TD\n  A --> B\n```',
      ];

      for (final source in cases) {
        final doc = codec.decode(source);
        expect(doc.blocks, hasLength(1), reason: source);
        final code = doc.blocks.single as CodeBlockNode;
        expect(code.language, 'mermaid', reason: source);
        expect(
          code.code,
          '# not a heading\nflowchart TD\n  A --> B',
          reason: source,
        );
      }
    });

    test('blockquote aggregates consecutive > lines', () {
      const source = '> line one\n> line two';
      final doc = codec.decode(source);
      expect(doc.blocks, hasLength(1));
      final block = doc.blocks[0] as TextBlockNode;
      expect(block.type, BlockType.paragraph);
      expect(block.attributes.isQuoted, isTrue);
      expect(doc.blocks[0].plainText, 'line one line two');
    });

    test('blockquote restores quoted heading and list item semantics', () {
      const source = '> ## Quoted title\n> - [ ] Quoted todo\n> 1. Quoted ordered';
      final doc = codec.decode(source);
      final blocks = doc.blocks.cast<TextBlockNode>().toList();

      expect(blocks, hasLength(3));
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].attributes.level, 2);
      expect(blocks[0].attributes.isQuoted, isTrue);
      expect(blocks[1].type, BlockType.listItem);
      expect(blocks[1].attributes.listType, 'task');
      expect(blocks[1].attributes.checked, isFalse);
      expect(blocks[1].attributes.isQuoted, isTrue);
      expect(blocks[2].type, BlockType.listItem);
      expect(blocks[2].attributes.listType, 'ordered');
      expect(blocks[2].attributes.isQuoted, isTrue);
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
      expect(image.file, 'https://x.dev/a.png');
      expect(image.altText, 'alt');
    });

    test('standalone image title becomes caption', () {
      const source = '![alt](https://x.dev/a.png "Hero caption")';
      final doc = codec.decode(source);
      final image = doc.blocks.single as ImageBlockNode;

      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'https://x.dev/a.png');
      expect(image.altText, 'alt');
      expect(image.caption, 'Hero caption');
    });

    test('normalizes CRLF and strips optional ATX closing hashes', () {
      const source = '# Windows heading ###\r\n\r\nBody text\r\n';
      final document = codec.decode(source);

      expect(document.blocks, hasLength(2));
      expect(document.blocks.first.plainText, 'Windows heading');
      expect(document.blocks.last.plainText, 'Body text');
      expect(document.plainText, isNot(contains('\r')));
    });

    test('only a matching fence closes a fenced code block', () {
      const source = '```text\nalpha\n~~~\nomega\n```';
      final document = codec.decode(source);

      expect(document.blocks, hasLength(1));
      final code = document.blocks.single as CodeBlockNode;
      expect(code.language, 'text');
      expect(code.code, 'alpha\n~~~\nomega');
    });

    test('inline code parses and round-trips without visible backticks', () {
      const source = 'Use `flutter test` and ``a ` b``.';
      final document = codec.decode(source);
      final paragraph = document.blocks.single as TextBlockNode;
      final codeRuns = paragraph.content
          .whereType<TextRun>()
          .where((run) => run.attributes.inlineCode == true)
          .toList();

      expect(
        codeRuns.map((run) => run.text),
        <String>['flutter test', 'a ` b'],
      );
      expect(codec.encode(document), source);
    });

    test('standalone video placeholder becomes video block', () {
      const source = '![video](local/video.mp4)';
      final doc = codec.decode(source);

      expect(doc.blocks, hasLength(1));
      final video = doc.blocks.single as VideoBlockNode;
      expect(video.assetId, 'local/video.mp4');
      expect(video.file, isEmpty);
    });

    test('standalone video placeholder metadata becomes video block', () {
      const source = '![video: Launch clip](https://cdn.example.com/video.mp4 '
          '"wenz-video; assetId=video-1; '
          'playbackUrl=https://cdn.example.com/video.mp4; '
          'file=local/video.mp4; '
          'coverUrl=https://cdn.example.com/cover.jpg; '
          'title=Launch clip; '
          'description=Product launch overview; '
          'aspectRatio=1.7777777777777777; '
          'uploadStatus=uploaded")';
      final doc = codec.decode(source);

      expect(doc.blocks, hasLength(1));
      final video = doc.blocks.single as VideoBlockNode;
      expect(video.assetId, 'video-1');
      expect(video.playbackUrl, 'https://cdn.example.com/video.mp4');
      expect(video.file, 'local/video.mp4');
      expect(video.coverUrl, 'https://cdn.example.com/cover.jpg');
      expect(video.title, 'Launch clip');
      expect(video.description, 'Product launch overview');
      expect(video.aspectRatio, 16 / 9);
      expect(video.uploadStatus, FileUploadStatus.uploaded);
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
            playbackUrl: 'https://cdn.example.com/video.mp4',
            file: 'local/video.mp4',
            coverUrl: 'https://cdn.example.com/cover.jpg',
            title: 'Launch clip',
            description: 'Product launch overview',
            aspectRatio: 16 / 9,
            uploadStatus: FileUploadStatus.uploaded,
          ),
        ],
      );

      final exported = codec.encode(document);
      final reimported = codec.decode(exported);

      expect(
        exported,
        '[report.pdf](https://cdn.example.com/report.pdf)\n\n'
        '![video](https://cdn.example.com/video.mp4 '
        '"wenz-video; assetId=video-1; '
        'playbackUrl=https://cdn.example.com/video.mp4; '
        'file=local/video.mp4; '
        'coverUrl=https://cdn.example.com/cover.jpg; '
        'title=Launch clip; '
        'description=Product launch overview; '
        'aspectRatio=1.7777777777777777; '
        'uploadStatus=uploaded")',
      );
      expect(reimported.blocks, hasLength(2));

      final fileParagraph = reimported.blocks[0] as TextBlockNode;
      expect(fileParagraph.plainText, 'report.pdf');
      final linkedRun = fileParagraph.content.whereType<TextRun>().single;
      expect(linkedRun.attributes.url, 'https://cdn.example.com/report.pdf');

      final video = reimported.blocks[1] as VideoBlockNode;
      expect(video.assetId, 'video-1');
      expect(video.playbackUrl, 'https://cdn.example.com/video.mp4');
      expect(video.file, 'local/video.mp4');
      expect(video.coverUrl, 'https://cdn.example.com/cover.jpg');
      expect(video.title, 'Launch clip');
      expect(video.description, 'Product launch overview');
      expect(video.aspectRatio, 16 / 9);
      expect(video.uploadStatus, FileUploadStatus.uploaded);
    });

    test('mermaid language stays canonical after export and import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'mermaid',
            language: ' MERMAID ',
            code: 'flowchart TD\n  A --> B',
          ),
        ],
      );

      final exported = codec.encode(document);
      final reimported = codec.decode(exported);

      expect(exported, '```mermaid\nflowchart TD\n  A --> B\n```');
      final code = reimported.blocks.single as CodeBlockNode;
      expect(code.language, 'mermaid');
      expect(code.code, 'flowchart TD\n  A --> B');
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
