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
      expect(codec.encode(document), '<blockquote>quoted</blockquote>');
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

    test('link parsed with href', () {
      final doc = codec.decode('<p>see <a href="https://x.dev">docs</a></p>');
      final para = doc.blocks[0] as TextBlockNode;
      final linked = para.content
          .whereType<TextRun>()
          .where((r) => r.attributes.url == 'https://x.dev');
      expect(linked, isNotEmpty);
      expect(linked.first.text, 'docs');
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
      expect(doc.blocks[0].type, BlockType.quote);
      expect(doc.blocks[0].plainText, 'quoted');
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

    test('img becomes an image block', () {
      final doc = codec.decode('<img src="https://x.dev/a.png" alt="alt">');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<ImageBlockNode>());
      final image = doc.blocks[0] as ImageBlockNode;
      expect(image.assetId, 'https://x.dev/a.png');
      expect(image.file, 'alt');
    });

    test('hr becomes a divider', () {
      final doc = codec.decode('<hr>');
      expect(doc.blocks, hasLength(1));
      expect(doc.blocks[0], isA<DividerBlockNode>());
    });

    test('malformed HTML does not throw, falls back to paragraphs', () {
      final doc = codec.decode('<p>unclosed paragraph');
      expect(doc.blocks, isNotEmpty);
      expect(doc.blocks.first.type, anyOf(BlockType.paragraph, BlockType.heading));
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
