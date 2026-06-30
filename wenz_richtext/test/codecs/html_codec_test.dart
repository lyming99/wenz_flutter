import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// C3 — verifies the HTML codec export/import. See `docs/acceptance_report.md`
/// task C3 / acceptance items 3.6 / 7.5.
void main() {
  const codec = HtmlCodec();

  group('HtmlCodec.encode (export)', () {
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
            content: <InlineNode>[TextRun(text: 'Sub')],
          ),
        ],
      );
      expect(codec.encode(document), '<h1>Title</h1>\n<h3>Sub</h3>');
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

      final html = codec.encode(controller.document);

      expect(html, '<h1>Section</h1>\n<p>Body stays exported</p>');
      expect(html, isNot(contains('collapse')));
      expect(html, isNot(contains('hidden')));
    });

    test('paragraph with bold + italic + strike inline', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a '),
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
      expect(
        codec.encode(document),
        '<p>a <strong>bold</strong> <em>ital</em> <s>gone</s></p>',
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
        '<p>see <a href="https://x.dev">docs</a></p>',
      );
    });

    test('font color exports as an inline CSS color', () {
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

      expect(
        codec.encode(document),
        '<p>plain <span style="color: #D81B60">red</span></p>',
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
                data: <String, Object?>{'text': 'x<2'},
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

      expect(codec.encode(document), '<p>Ask x&lt;2 😀 from @Ada</p>');
    });

    test('inline image exports alt, caption, and dimensions', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'before '),
              InlineEmbed(
                embedType: 'image',
                data: <String, Object?>{
                  'assetId': 'https://x.dev/inline.png',
                  'altText': 'Inline alt',
                  'caption': 'Inline caption',
                  'width': 32,
                  'height': 24,
                },
              ),
              TextRun(text: ' after'),
            ],
          ),
        ],
      );

      expect(
        codec.encode(document),
        '<p>before <img src="https://x.dev/inline.png" alt="Inline alt" '
        'width="32" height="24" title="Inline caption" '
        'data-caption="Inline caption"> after</p>',
      );
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
      expect(codec.encode(document), '<blockquote><p>quoted</p></blockquote>');
    });

    test('callout with variant title and icon', () {
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
      expect(
        codec.encode(document),
        '<aside class="wenz-callout" data-wenz-block="callout" '
        'data-callout-variant="warning" data-callout-icon="🚨">'
        '<div data-callout-title>Heads up</div>'
        '<div data-callout-body>Body</div></aside>',
      );
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
        ],
      );
      expect(
        codec.encode(document),
        '<ul><li>one</li></ul>\n'
        '<ol><li>two</li></ol>\n'
        '<ul><li><input type="checkbox" checked disabled> done</li></ul>',
      );
    });

    test('ordered todo list exports number and checkbox semantics', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'plain ordered')],
          ),
          TextBlockNode(
            id: 'orderedTodo',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: false),
            content: <InlineNode>[TextRun(text: 'ordered todo')],
          ),
          TextBlockNode(
            id: 'task',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'unordered todo')],
          ),
        ],
      );

      expect(
        codec.encode(document),
        '<ol><li>plain ordered</li></ol>\n'
        '<ol><li><input type="checkbox" disabled> ordered todo</li></ol>\n'
        '<ul><li><input type="checkbox" checked disabled> unordered todo</li></ul>',
      );
    });

    test('code block with language', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'c1',
            language: 'dart',
            code: 'var x = 1;',
          ),
        ],
      );
      expect(
        codec.encode(document),
        '<pre><code class="language-dart">var x = 1;</code></pre>',
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
        '<img src="https://x.dev/a.png" alt="alt">\n<hr>',
      );
    });

    test('image with caption exports as figure', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'im1',
            assetId: 'https://x.dev/a.png',
            file: 'fallback-name',
            width: 640,
            height: 360,
            showWidth: 320,
            showHeight: 180,
            caption: 'Hero caption',
            altText: 'Hero alt',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '<figure><img src="https://x.dev/a.png" alt="Hero alt" width="320" height="180" data-width="640" data-height="360"><figcaption>Hero caption</figcaption></figure>',
      );
    });

    test('file exports download metadata', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          FileBlockNode(
            id: 'file1',
            assetId: 'asset-1',
            name: 'report.pdf',
            size: 4096,
            mimeType: 'application/pdf',
            downloadUrl: 'https://cdn.example.com/report.pdf',
            uploadStatus: FileUploadStatus.failed,
            uploadError: 'network timeout',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '<a href="https://cdn.example.com/report.pdf" data-wenz-block="file" data-asset-id="asset-1" data-size="4096" data-mime-type="application/pdf" data-upload-status="failed" data-upload-error="network timeout">report.pdf</a>',
      );
    });

    test('video exports semantic video metadata', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: 'video-asset',
            playbackUrl: 'https://cdn.example.com/video.mp4',
            file: 'video.mp4',
            coverUrl: 'https://cdn.example.com/cover.jpg',
            title: 'Launch clip',
            description: 'Product launch overview',
            aspectRatio: 16 / 9,
            uploadStatus: FileUploadStatus.failed,
            uploadError: 'network timeout',
          ),
        ],
      );

      expect(
        codec.encode(document),
        '<video src="https://cdn.example.com/video.mp4" data-wenz-block="video" data-asset-id="video-asset" data-playback-url="https://cdn.example.com/video.mp4" data-file="video.mp4" poster="https://cdn.example.com/cover.jpg" title="Launch clip" data-title="Launch clip" data-description="Product launch overview" data-aspect-ratio="1.7777777777777777" data-upload-status="failed" data-upload-error="network timeout"></video>',
      );
    });

    test('table exports rowspan and colspan', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c0',
                    isHeader: true,
                    rowSpan: 2,
                    columnSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Merged')],
                      ),
                    ],
                  ),
                  TableCellNode(id: 'c1', covered: true),
                  TableCellNode(
                    id: 'c2',
                    isHeader: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c2p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Top')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(id: 'r1c0', covered: true),
                  TableCellNode(id: 'r1c1', covered: true),
                  TableCellNode(
                    id: 'r1c2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'r1c2p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Bottom')],
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
        '<table><tr><th rowspan="2" colspan="2">Merged</th><th>Top</th></tr><tr><td>Bottom</td></tr></table>',
      );
    });

    test('HTML-escapes special characters in text', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'a < b & c > d "e"')],
          ),
        ],
      );
      expect(
        codec.encode(document),
        '<p>a &lt; b &amp; c &gt; d &quot;e&quot;</p>',
      );
    });
  });

  group('HtmlCodec.decode (import)', () {
    test('external collapse metadata imports as expanded content', () {
      final document = codec.decode(
        '<h1 data-wenz-collapsed="true" aria-expanded="false">Section</h1>'
        '<p hidden data-hidden-by-heading="h1">Body stays imported</p>',
      );
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
      final doc = codec.decode('<h1>Title</h1><h3>Sub</h3>');
      expect(doc.blocks, hasLength(2));
      expect(doc.blocks[0].type, BlockType.heading);
      expect((doc.blocks[0] as TextBlockNode).attributes.level, 1);
      expect(doc.blocks[0].plainText, 'Title');
      expect((doc.blocks[1] as TextBlockNode).attributes.level, 3);
    });

    test('paragraph with nested bold + italic merges attributes', () {
      final doc = codec.decode('<p><strong><em>both</em></strong></p>');
      expect(doc.blocks, hasLength(1));
      final para = doc.blocks[0] as TextBlockNode;
      final both = para.content.whereType<TextRun>().where(
          (r) => r.attributes.bold == true && r.attributes.italic == true);
      expect(both, isNotEmpty);
      expect(both.first.text, 'both');
    });

    test('font color imports from style, color attribute, and rgba', () {
      final doc = codec.decode(
        '<p><span style="color: #d81b60">hex</span> '
        '<font color="blue">named</font> '
        '<span style="color: rgba(1, 2, 3, 0.5)">rgba</span> '
        '<span style="color: #01020380">hexAlpha</span> '
        '<span style="color: not-a-color">plain</span></p>',
      );
      final para = doc.blocks.single as TextBlockNode;
      final runs = para.content.whereType<TextRun>().toList();

      TextRun run(String text) => runs.firstWhere((node) => node.text == text);
      expect(run('hex').attributes.color, 0xFFD81B60);
      expect(run('named').attributes.color, 0xFF0000FF);
      expect(run('rgba').attributes.color, 0x80010203);
      expect(run('hexAlpha').attributes.color, 0x80010203);
      expect(run('plain').attributes.color, isNull);
    });

    test('link parsed with href', () {
      final doc = codec.decode('<p>see <a href="https://x.dev">docs</a></p>');
      final para = doc.blocks[0] as TextBlockNode;
      final linked = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.url == 'https://x.dev');
      expect(linked, isNotEmpty);
      expect(linked.first.text, 'docs');
    });

    test('inline image restores alt, caption, and dimensions', () {
      final doc = codec.decode(
        '<p>before <img src="https://x.dev/inline.png" alt="Inline alt" '
        'width="32" height="24" data-caption="Inline caption"> after</p>',
      );
      final para = doc.blocks.single as TextBlockNode;
      final image = para.content.whereType<InlineEmbed>().single;

      expect(image.embedType, 'image');
      expect(image.data['assetId'], 'https://x.dev/inline.png');
      expect(image.data['text'], 'Inline alt');
      expect(image.data['altText'], 'Inline alt');
      expect(image.data['caption'], 'Inline caption');
      expect(image.data['width'], 32);
      expect(image.data['height'], 24);
      expect(para.plainText, 'before \uFFFC after');
    });

    test('unordered, ordered, and task list items', () {
      final doc = codec.decode(
        '<ul><li>one</li></ul>'
        '<ol><li>two</li></ol>'
        '<ul><li><input type="checkbox" checked> done</li></ul>'
        '<ul><li><input type="checkbox"> todo</li></ul>',
      );
      expect(doc.blocks, hasLength(4));
      expect(doc.blocks.every((b) => b.type == BlockType.listItem), isTrue);
      final items = doc.blocks.cast<TextBlockNode>();
      expect(items[0].attributes.listType, isNull); // unordered
      expect(items[1].attributes.listType, 'ordered');
      expect(items[2].attributes.listType, 'task');
      expect(items[2].attributes.checked, true);
      expect(items[3].attributes.checked, false);
    });

    test('ordered todo list imports ordered type with checked state', () {
      final doc = codec.decode(
        '<ol><li>plain ordered</li></ol>'
        '<ol><li><input type="checkbox"> ordered todo</li></ol>'
        '<ol><li><input type="checkbox" checked> done</li></ol>'
        '<ul><li><input type="checkbox" checked> unordered todo</li></ul>',
      );
      expect(doc.blocks, hasLength(4));
      final items = doc.blocks.cast<TextBlockNode>();

      expect(items[0].attributes.listType, 'ordered');
      expect(items[0].attributes.checked, isNull);
      expect(items[1].attributes.listType, 'ordered');
      expect(items[1].attributes.checked, isFalse);
      expect(items[2].attributes.listType, 'ordered');
      expect(items[2].attributes.checked, isTrue);
      expect(items[3].attributes.listType, 'task');
      expect(items[3].attributes.checked, isTrue);
    });

    test('pre + code with language class', () {
      final doc = codec.decode(
        '<pre><code class="language-dart">var x = 1;</code></pre>',
      );
      expect(doc.blocks, hasLength(1));
      final code = doc.blocks[0] as CodeBlockNode;
      expect(code.language, 'dart');
      expect(code.code, 'var x = 1;');
    });

    test('blockquote', () {
      final doc = codec.decode('<blockquote>quoted</blockquote>');
      expect(doc.blocks, hasLength(1));
      final block = doc.blocks[0] as TextBlockNode;
      expect(block.type, BlockType.paragraph);
      expect(block.attributes.isQuoted, isTrue);
      expect(block.plainText, 'quoted');
    });

    test('blockquote restores quoted heading and list semantics', () {
      final doc = codec.decode(
        '<blockquote><h2>Quoted title</h2>'
        '<ul><li><input type="checkbox" disabled> Quoted todo</li></ul>'
        '<ol><li>Quoted ordered</li></ol></blockquote>',
      );
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

    test('callout restores variant title icon and body', () {
      final doc = codec.decode(
        '<aside class="wenz-callout" data-wenz-block="callout" '
        'data-callout-variant="danger" data-callout-icon="🔥">'
        '<div data-callout-title>Stop</div>'
        '<div data-callout-body>Check <strong>now</strong></div></aside>',
      );

      expect(doc.blocks, hasLength(1));
      expect(doc.blocks.single, isA<CalloutBlockNode>());
      final callout = doc.blocks.single as CalloutBlockNode;
      expect(callout.variant, 'danger');
      expect(callout.title, 'Stop');
      expect(callout.icon, '🔥');
      expect(callout.plainText, 'Stop\nCheck now');
      expect(callout.content, hasLength(2));
      expect((callout.content[1] as TextRun).attributes.bold, isTrue);
    });

    test('table with header row', () {
      final doc = codec.decode(
        '<table><thead><tr><th>A</th><th>B</th></tr></thead>'
        '<tbody><tr><td>1</td><td>2</td></tr></tbody></table>',
      );
      expect(doc.blocks, hasLength(1));
      final table = doc.blocks[0] as TableBlockNode;
      expect(table.table.rowCount, 2);
      expect(table.table.columnCount, 2);
      // First row cells (in thead) are headers.
      expect(table.table.rows[0][0].isHeader, isTrue);
      expect(table.table.rows[1][0].isHeader, isFalse);
    });

    test('table restores rowspan and colspan coverage', () {
      final doc = codec.decode(
        '<table><tbody><tr><td rowspan="2" colspan="2">Merged</td>'
        '<td>Top</td></tr><tr><td>Bottom</td></tr></tbody></table>',
      );

      expect(doc.blocks, hasLength(1));
      final table = doc.blocks.single as TableBlockNode;
      expect(table.table.rowCount, 2);
      expect(table.table.columnCount, 3);
      expect(table.table.rows[0][0].plainText, 'Merged');
      expect(table.table.rows[0][0].rowSpan, 2);
      expect(table.table.rows[0][0].columnSpan, 2);
      expect(table.table.rows[0][1].covered, isTrue);
      expect(table.table.rows[1][0].covered, isTrue);
      expect(table.table.rows[1][1].covered, isTrue);
      expect(table.table.rows[1][2].plainText, 'Bottom');
    });

    test('img becomes an image block', () {
      final doc = codec.decode('<img src="https://x.dev/a.png" alt="alt">');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<ImageBlockNode>());
      final image = doc.blocks[0] as ImageBlockNode;
      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'alt');
      expect(image.altText, 'alt');
    });

    test('figure restores image caption and dimensions', () {
      final doc = codec.decode(
        '<figure><img src="https://x.dev/a.png" alt="Hero alt" '
        'width="320" height="180" data-width="640" data-height="360">'
        '<figcaption>Hero caption</figcaption></figure>',
      );
      final image = doc.blocks.single as ImageBlockNode;

      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'Hero alt');
      expect(image.altText, 'Hero alt');
      expect(image.caption, 'Hero caption');
      expect(image.width, 640);
      expect(image.height, 360);
      expect(image.showWidth, 320);
      expect(image.showHeight, 180);
    });

    test('wenz file link becomes a file block', () {
      final doc = codec.decode(
        '<a href="https://cdn.example.com/report.pdf" data-wenz-block="file" '
        'data-asset-id="asset-1" data-size="4096" '
        'data-mime-type="application/pdf" data-upload-status="failed" '
        'data-upload-error="network timeout">report.pdf</a>',
      );

      expect(doc.blocks, hasLength(1));
      expect(doc.blocks.single, isA<FileBlockNode>());
      final file = doc.blocks.single as FileBlockNode;
      expect(file.assetId, 'asset-1');
      expect(file.name, 'report.pdf');
      expect(file.size, 4096);
      expect(file.mimeType, 'application/pdf');
      expect(file.downloadUrl, 'https://cdn.example.com/report.pdf');
      expect(file.uploadStatus, FileUploadStatus.failed);
      expect(file.uploadError, 'network timeout');
    });

    test('video becomes a video block', () {
      final doc = codec.decode(
        '<video src="https://cdn.example.com/video.mp4" '
        'data-asset-id="video-1" data-file="video.mp4" '
        'poster="https://cdn.example.com/cover.jpg" '
        'title="Launch clip" '
        'data-description="Product launch overview" '
        'data-aspect-ratio="1.7777777777777777" '
        'data-upload-status="uploaded"></video>',
      );

      expect(doc.blocks, hasLength(1));
      expect(doc.blocks.single, isA<VideoBlockNode>());
      final video = doc.blocks.single as VideoBlockNode;
      expect(video.assetId, 'video-1');
      expect(video.playbackUrl, 'https://cdn.example.com/video.mp4');
      expect(video.file, 'video.mp4');
      expect(video.coverUrl, 'https://cdn.example.com/cover.jpg');
      expect(video.title, 'Launch clip');
      expect(video.description, 'Product launch overview');
      expect(video.aspectRatio, 16 / 9);
      expect(video.uploadStatus, FileUploadStatus.uploaded);
    });

    test('hr becomes a divider', () {
      final doc = codec.decode('<hr>');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<DividerBlockNode>());
    });

    test('malformed HTML does not throw, falls back to paragraphs', () {
      final doc = codec.decode('<p>unclosed paragraph');
      expect(doc.blocks, isNotEmpty);
      expect(
          doc.blocks.first.type, anyOf(BlockType.paragraph, BlockType.heading));
    });

    test('plain text input becomes a paragraph', () {
      final doc = codec.decode('just plain text');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0].type, BlockType.paragraph);
      expect(doc.blocks[0].plainText, 'just plain text');
    });

    test('HTML entities are unescaped on import', () {
      final doc = codec.decode('<p>a &lt; b &amp; c</p>');
      expect(doc.blocks[0].plainText, 'a < b & c');
    });
  });

  group('HtmlCodec round-trip', () {
    test('font color and link survive export → import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'see '),
              TextRun(
                text: 'docs',
                attributes: TextAttributes(
                  color: 0xFFD81B60,
                  url: 'https://x.dev',
                ),
              ),
            ],
          ),
        ],
      );

      final reimported = codec.decode(codec.encode(document));
      final block = reimported.blocks.single as TextBlockNode;
      final linked = block.content
          .whereType<TextRun>()
          .firstWhere((run) => run.text == 'docs');

      expect(linked.attributes.color, 0xFFD81B60);
      expect(linked.attributes.url, 'https://x.dev');
    });
    test('ordered todo list preserves numbering type and checked state', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'plain ordered')],
          ),
          TextBlockNode(
            id: 'orderedTodo',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'ordered todo')],
          ),
          TextBlockNode(
            id: 'task',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'unordered todo')],
          ),
        ],
      );

      final reimported = codec.decode(codec.encode(document));
      final items = reimported.blocks.cast<TextBlockNode>();

      expect(items[0].attributes.listType, 'ordered');
      expect(items[0].attributes.checked, isNull);
      expect(items[1].attributes.listType, 'ordered');
      expect(items[1].attributes.checked, isTrue);
      expect(items[2].attributes.listType, 'task');
      expect(items[2].attributes.checked, isFalse);
    });
    test('quoted heading and lists survive export → import', () {
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

      final html = codec.encode(document);
      expect(html, contains('<blockquote><h2>Quoted title</h2></blockquote>'));
      expect(html, contains('<blockquote><ul>'));
      expect(html, contains('<blockquote><ol>'));

      final blocks = codec.decode(html).blocks.cast<TextBlockNode>().toList();
      expect(blocks[0].type, BlockType.heading);
      expect(blocks[0].attributes.isQuoted, isTrue);
      expect(blocks[1].attributes.listType, 'task');
      expect(blocks[1].attributes.checked, isFalse);
      expect(blocks[1].attributes.isQuoted, isTrue);
      expect(blocks[2].attributes.listType, 'ordered');
      expect(blocks[2].attributes.isQuoted, isTrue);
    });
    test('heading + paragraph + code survive export → import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Body')],
          ),
          CodeBlockNode(id: 'c1', language: 'dart', code: 'var x = 1;'),
        ],
      );
      final exported = codec.encode(document);
      final reimported = codec.decode(exported);
      expect(reimported.blocks, hasLength(3));
      expect(reimported.blocks[0].type, BlockType.heading);
      expect(reimported.blocks[1].type, BlockType.paragraph);
      expect(reimported.blocks[2].type, BlockType.code);
      expect((reimported.blocks[2] as CodeBlockNode).code, 'var x = 1;');
    });

    test('file and video metadata survive export → import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          FileBlockNode(
            id: 'file1',
            assetId: 'asset-1',
            name: 'report.pdf',
            size: 4096,
            mimeType: 'application/pdf',
            file: 'local/report.pdf',
            downloadUrl: 'https://cdn.example.com/report.pdf',
            uploadStatus: FileUploadStatus.uploaded,
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

      final reimported = codec.decode(codec.encode(document));

      expect(reimported.blocks, hasLength(2));
      final file = reimported.blocks[0] as FileBlockNode;
      expect(file.assetId, 'asset-1');
      expect(file.name, 'report.pdf');
      expect(file.size, 4096);
      expect(file.mimeType, 'application/pdf');
      expect(file.file, 'local/report.pdf');
      expect(file.downloadUrl, 'https://cdn.example.com/report.pdf');
      expect(file.uploadStatus, FileUploadStatus.uploaded);
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

    test('block embed metadata survives export → import', () {
      const document = RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'embed1',
            embedType: 'crm-card',
            data: <String, Object?>{'recordId': '42', 'title': 'Acme'},
            fallbackText: 'Acme account',
          ),
        ],
      );

      final reimported = codec.decode(codec.encode(document));

      expect(reimported.blocks.single, isA<BlockEmbedNode>());
      final embed = reimported.blocks.single as BlockEmbedNode;
      expect(embed.embedType, 'crm-card');
      expect(embed.data, containsPair('recordId', '42'));
      expect(embed.data, containsPair('title', 'Acme'));
      expect(embed.fallbackText, 'Acme account');
    });
  });

  group('WenzRichTextController html helpers', () {
    test('toHtml / loadHtml / tryLoadHtml', () {
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
      expect(controller.toHtml(), contains('<h2>'));

      controller.loadHtml('<p>Replaced</p>');
      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.blocks[0].type, BlockType.paragraph);

      final result = controller.tryLoadHtml('<h3>Try</h3>');
      expect(result.ok, isTrue);
      expect(result.document, isNotNull);
      expect(result.document!.blocks[0].type, BlockType.heading);

      controller.dispose();
    });
  });

  group('ClipboardService.pasteHtml', () {
    test('parses an HTML fragment into multiple blocks', () {
      const service = ClipboardService();
      final paste = service.pasteHtml('<h1>Title</h1><p>body</p>');
      expect(paste, isNotNull);
      expect(paste!.isBlocks, isTrue);
      expect(paste.blocks, hasLength(2));
      expect(paste.blocks[0].type, BlockType.heading);
      expect(paste.blocks[1].type, BlockType.paragraph);
    });

    test('empty fragment still yields a paste (single empty paragraph)', () {
      // The HTML codec always produces at least one paragraph so the document
      // is never empty; pasteHtml surfaces that as a one-block paste.
      const service = ClipboardService();
      final paste = service.pasteHtml('');
      expect(paste, isNotNull);
      expect(paste!.blocks, hasLength(1));
      expect(paste.blocks.first.type, BlockType.paragraph);
    });
  });
}
