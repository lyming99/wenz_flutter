import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  const service = ClipboardService();

  group('ClipboardService.copy', () {
    test('returns null for a collapsed selection', () {
      final doc = _doc('Hello');
      expect(service.copy(doc, collapsedTextSelection('p1', 0, 0)), isNull);
    });

    test('same-block range produces a rich payload with the magic prefix', () {
      final doc = _doc('Hello');
      final sel = textSelection('p1', 0, 1, 4);
      final payload = service.copy(doc, sel);

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      // The payload parses back to the selected slice 'ell'.
      expect(service.parse(payload).text, 'ell');
    });

    test('callout body range uses content offsets when copying', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'info1',
            title: 'Info Title',
            content: <InlineNode>[TextRun(text: 'Info body selectable')],
          ),
        ],
      );
      final payload = service.copy(doc, textSelection('info1', 0, 5, 9));

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      expect(service.parse(payload).text, 'body');
    });

    test('same-block range preserves run attributes on parse', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'He',
                attributes: TextAttributes(bold: true, color: 0xFFD81B60),
              ),
              TextRun(text: 'llo'),
            ],
          ),
        ],
      );
      final sel = textSelection('p1', 0, 1, 4); // 'ell'
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'ell');
      // The slice crosses the bold/plain boundary: 'e' (bold) + 'll' (plain).
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[0] as TextRun).attributes.color, 0xFFD81B60);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
      expect((paste.inlineRuns[1] as TextRun).attributes.color, isNull);
    });

    test('same-block range preserves an inline embed through copy and parse',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a'),
              InlineEmbed(
                  embedType: 'formula', data: <String, Object?>{'text': 'x^2'}),
              TextRun(text: 'b'),
            ],
          ),
        ],
      );
      // Select the whole run 'a' + embed + 'b' (offsets 0..3).
      final sel = textSelection('p1', 0, 0, 3);
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'ax^2b');
      // The embed must survive: a, embed, b — not just 'ab'.
      final embeds = paste.inlineRuns.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'formula');
      expect(embeds.single.data['text'], 'x^2');
    });

    test('complete unordered list item copies as a block payload', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'bullet item')],
          ),
        ],
      );

      final payload = service.copyPayload(
        doc,
        textSelection('li1', 0, 0, 'bullet item'.length),
      );

      expect(payload, isNotNull);
      final privatePaste = service.parse(payload!.wenzRichText);
      expect(privatePaste.isBlocks, isTrue);
      expect(privatePaste.blocks, hasLength(1));
      final item = privatePaste.blocks.single as TextBlockNode;
      expect(item.type, BlockType.listItem);
      expect(item.attributes.listType, isNull);
      expect(item.plainText, 'bullet item');

      final htmlPaste = service.parse(
        payload.html,
        format: ClipboardPasteFormat.html,
      );
      expect(
        (htmlPaste.blocks.single as TextBlockNode).type,
        BlockType.listItem,
      );
      expect(htmlPaste.blocks.single.plainText, 'bullet item');
    });

    test('partial unordered list text keeps inline copy behaviour', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'bullet item')],
          ),
        ],
      );

      final payload = service.copyPayload(doc, textSelection('li1', 0, 0, 6));
      final paste = service.parse(payload!.wenzRichText);

      expect(paste.isBlocks, isFalse);
      expect(paste.isRich, isTrue);
      expect(paste.text, 'bullet');
    });

    test('object block selection produces a blocks payload', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
        ],
      );

      final payload = service.copy(doc, objectSelection('img1', 0));
      final paste = service.parse(payload!);

      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(1));
      final image = paste.blocks.single as ImageBlockNode;
      expect(image.id, 'img1');
      expect(image.assetId, 'hero');
      expect(image.file, 'hero.png');
    });

    test('video block selection preserves metadata with a readable text view',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip-asset',
            playbackUrl: 'https://cdn.example.test/clip.mp4',
            file: 'clip.mp4',
            coverUrl: 'https://cdn.example.test/cover.jpg',
            title: 'Launch clip',
            description: 'Demo reel',
            aspectRatio: 4 / 3,
            uploadStatus: FileUploadStatus.uploaded,
          ),
        ],
      );

      final payload = service.copy(doc, objectSelection('video1', 0));
      final paste = service.parse(payload!);

      expect(paste.isBlocks, isTrue);
      expect(paste.text, '[video: Launch clip]');
      expect(paste.blocks, hasLength(1));
      final video = paste.blocks.single as VideoBlockNode;
      expect(video.id, 'video1');
      expect(video.assetId, 'clip-asset');
      expect(video.playbackUrl, 'https://cdn.example.test/clip.mp4');
      expect(video.file, 'clip.mp4');
      expect(video.coverUrl, 'https://cdn.example.test/cover.jpg');
      expect(video.title, 'Launch clip');
      expect(video.description, 'Demo reel');
      expect(video.aspectRatio, 4 / 3);
      expect(video.uploadStatus, FileUploadStatus.uploaded);
    });

    test('formula block selection exposes formula source text', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'formula1',
            embedType: 'formula',
            data: <String, Object?>{'text': r'\int_0^1 x dx'},
          ),
        ],
      );

      final payload = service.copy(doc, objectSelection('formula1', 0));
      final paste = service.parse(payload!);

      expect(paste.isBlocks, isTrue);
      expect(paste.text, r'\int_0^1 x dx');
    });

    test('cross-block range preserves an inline embed in the trimmed blocks',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'a'),
              InlineEmbed(
                  embedType: 'mention',
                  data: <String, Object?>{'id': 'u1', 'label': 'Ada'}),
              TextRun(text: 'b'),
            ],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'c')],
          ),
        ],
      );
      // From the start of p1 through p2 — the p1 slice includes the embed.
      final sel = DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 0),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 1, offset: 1),
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      final first = paste.blocks.first as TextBlockNode;
      final embeds = first.content.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'mention');
      expect(embeds.single.data['label'], 'Ada');
    });

    test('cross-block range produces a rich blocks payload with plain fallback',
        () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'def')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'p2',
          blockIndex: 1,
          path: PositionPath.blockText('p2'),
          offset: 2,
        ),
      );
      final payload = service.copy(doc, sel);

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      // Plain-text view of the payload matches the old behaviour.
      expect(service.parse(payload).text, 'bc\nde');
      // Parsed as a blocks payload carrying the block slice.
      final paste = service.parse(payload);
      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(2));
      expect((paste.blocks[0] as TextBlockNode).plainText, 'bc');
      expect((paste.blocks[1] as TextBlockNode).plainText, 'de');
    });

    test('cross-block range preserves a video block as an atomic block', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            title: 'Launch clip',
            playbackUrl: 'https://cdn.example.test/clip.mp4',
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 2),
        extent: DocumentPosition.text(blockId: 'p2', blockIndex: 2, offset: 3),
      );

      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      expect(paste.text, 'fore\n[video: Launch clip]\naft');
      expect(paste.blocks, hasLength(3));
      expect((paste.blocks[0] as TextBlockNode).plainText, 'fore');
      final video = paste.blocks[1] as VideoBlockNode;
      expect(video.id, 'video1');
      expect(video.playbackUrl, 'https://cdn.example.test/clip.mp4');
      expect((paste.blocks[2] as TextBlockNode).plainText, 'aft');
    });

    test('cross-block range preserves inline attributes per block', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'abc', attributes: TextAttributes(bold: true)),
            ],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'def', attributes: TextAttributes(italic: true)),
            ],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'p1',
          blockIndex: 0,
          path: PositionPath.blockText('p1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'p2',
          blockIndex: 1,
          path: PositionPath.blockText('p2'),
          offset: 2,
        ),
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      final firstRun =
          (paste.blocks[0] as TextBlockNode).content.first as TextRun;
      final lastRun =
          (paste.blocks[1] as TextBlockNode).content.first as TextRun;
      expect(firstRun.attributes.bold, isTrue);
      expect(lastRun.attributes.italic, isTrue);
    });

    test('cross-block range preserves block type and attributes', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
          TextBlockNode(
            id: 'q1',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'quoted')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'h1',
          blockIndex: 0,
          path: PositionPath.blockText('h1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'q1',
          blockIndex: 1,
          path: PositionPath.blockText('q1'),
          offset: 6,
        ),
      );
      final payload = service.copy(doc, sel)!;
      final paste = service.parse(payload);

      expect(paste.isBlocks, isTrue);
      expect((paste.blocks[0] as TextBlockNode).type, BlockType.heading);
      expect((paste.blocks[0] as TextBlockNode).attributes.level, 2);
      final quote = paste.blocks[1] as TextBlockNode;
      expect(quote.type, BlockType.paragraph);
      expect(quote.attributes.quoted, isTrue);
    });

    test('code block range copies plain text slice', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'c1', code: 'abcdef'),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 1,
        ),
        extent: DocumentPosition(
          blockId: 'c1',
          blockIndex: 0,
          path: PositionPath.blockCode('c1'),
          offset: 4,
        ),
      );
      expect(service.copy(doc, sel), 'bcd');
    });

    test('table cell range produces a rich payload from the selected cell', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(1, 4));

      expect(payload, isNotNull);
      expect(payload!.startsWith(wenzClipboardPrefix), isTrue);
      expect(service.parse(payload).text, 'ell');
    });

    test('table cell range preserves run attributes on parse', () {
      final doc = _tableDoc();
      final payload = service.copy(doc, _tableCellSelection(0, 4))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hell');
      expect(paste.inlineRuns, hasLength(2));
      expect((paste.inlineRuns[0] as TextRun).attributes.bold, isTrue);
      expect((paste.inlineRuns[0] as TextRun).attributes.color, 0xFFD81B60);
      expect((paste.inlineRuns[1] as TextRun).attributes.bold, isNull);
      expect((paste.inlineRuns[1] as TextRun).attributes.color, isNull);
    });

    test('table cell range copies as TSV plain text', () {
      final doc = _tableRangeDoc();

      expect(service.copy(doc, _tableRangeSelection()), 'AA\tBB\nCC\tDD');
      expect(
          service.copy(doc, _reversedTableRangeSelection()), 'AA\tBB\nCC\tDD');
    });
  });

  group('ClipboardService.parse', () {
    test('rich payload round-trips through parse', () {
      final doc = _doc('Hello');
      final payload = service.copy(doc, textSelection('p1', 0, 0, 5))!;
      final paste = service.parse(payload);

      expect(paste.isRich, isTrue);
      expect(paste.text, 'Hello');
    });

    test('plain text is parsed as plain', () {
      final paste = service.parse('just text');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'just text');
    });

    test('plain text preserves newlines for multi-line paste', () {
      final paste = service.parse('line one\nline two\nline three');
      expect(paste.isRich, isFalse);
      expect(paste.text, 'line one\nline two\nline three');
    });

    test('plainText format bypasses rich payload detection', () {
      final payload =
          service.copy(_doc('Hello'), textSelection('p1', 0, 0, 5))!;
      final paste = service.parse(
        payload,
        format: ClipboardPasteFormat.plainText,
      );

      expect(paste.isRich, isFalse);
      expect(paste.text, payload);
    });

    test('markdown format parses structured blocks', () {
      final paste = service.parse(
        '# Title\n\n- item',
        format: ClipboardPasteFormat.markdown,
      );

      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(2));
      expect((paste.blocks[0] as TextBlockNode).type, BlockType.heading);
      expect((paste.blocks[0] as TextBlockNode).plainText, 'Title');
      expect((paste.blocks[1] as TextBlockNode).type, BlockType.listItem);
    });

    test('html format parses structured blocks', () {
      final paste = service.parse(
        '<h1>Title</h1><p>body</p>',
        format: ClipboardPasteFormat.html,
      );

      expect(paste.isBlocks, isTrue);
      expect(paste.blocks, hasLength(2));
      expect((paste.blocks[0] as TextBlockNode).type, BlockType.heading);
      expect((paste.blocks[1] as TextBlockNode).plainText, 'body');
    });

    test('html format preserves list item body, type, and checked state', () {
      final paste = service.parse(
        '<ul><li>one</li></ul>'
        '<ol><li>two</li></ol>'
        '<ul><li><input type="checkbox" checked> done</li></ul>',
        format: ClipboardPasteFormat.html,
      );

      expect(paste.isBlocks, isTrue);
      final items = paste.blocks.cast<TextBlockNode>();
      expect(items, hasLength(3));
      expect(items[0].type, BlockType.listItem);
      expect(items[0].attributes.listType, isNull);
      expect(items[0].plainText, 'one');
      expect(items[1].attributes.listType, 'ordered');
      expect(items[1].plainText, 'two');
      expect(items[2].attributes.listType, 'task');
      expect(items[2].attributes.checked, isTrue);
      // The checkbox markup separates the input from its text with a space;
      // that whitespace is preserved as leading text on the item body.
      expect(items[2].plainText, ' done');
    });

    test('list copy round-trips through private rich and HTML payloads', () {
      const doc = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'li1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'First')],
          ),
          TextBlockNode(
            id: 'li2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'Done')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 'li1',
          blockIndex: 0,
          path: PositionPath.blockText('li1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'li2',
          blockIndex: 1,
          path: PositionPath.blockText('li2'),
          offset: 4,
        ),
      );

      final payload = service.copyPayload(doc, sel);
      expect(payload, isNotNull);

      // Private rich payload preserves block type, listType and checked state.
      final richPaste = service.parse(payload!.wenzRichText);
      expect(richPaste.isBlocks, isTrue);
      expect(richPaste.blocks, hasLength(2));
      final richItems = richPaste.blocks.cast<TextBlockNode>();
      expect(richItems[0].type, BlockType.listItem);
      expect(richItems[0].attributes.listType, 'ordered');
      expect(richItems[0].attributes.checked, isNull);
      expect(richItems[0].plainText, 'First');
      expect(richItems[1].attributes.listType, 'task');
      expect(richItems[1].attributes.checked, isTrue);
      expect(richItems[1].plainText, 'Done');

      // HTML payload re-parses back into the same structure, text and state.
      final htmlPaste =
          service.parse(payload.html, format: ClipboardPasteFormat.html);
      expect(htmlPaste.isBlocks, isTrue);
      expect(htmlPaste.blocks, hasLength(2));
      final htmlItems = htmlPaste.blocks.cast<TextBlockNode>();
      expect(htmlItems[0].type, BlockType.listItem);
      expect(htmlItems[0].attributes.listType, 'ordered');
      expect(htmlItems[0].attributes.checked, isNull);
      expect(htmlItems[0].plainText, 'First');
      expect(htmlItems[1].attributes.listType, 'task');
      expect(htmlItems[1].attributes.checked, isTrue);
      // The task checkbox markup separates input and body with a space.
      expect(htmlItems[1].plainText, ' Done');
    });

    test('html format imports list paragraphs copied by legacy wenz_editor',
        () {
      final paste = service.parse(
        '<!DOCTYPE html><html><body>'
        '<p itemType="li">bullet text</p>'
        '<p itemType="oli">ordered text</p>'
        '<p itemType="check" checked="true">task text</p>'
        '</body></html>',
        format: ClipboardPasteFormat.html,
      );

      expect(paste.isBlocks, isTrue);
      final items = paste.blocks.cast<TextBlockNode>();
      expect(items, hasLength(3));
      expect(items.every((item) => item.type == BlockType.listItem), isTrue);
      expect(items.map((item) => item.plainText),
          orderedEquals(<String>['bullet text', 'ordered text', 'task text']));
      expect(items[0].attributes.listType, isNull);
      expect(items[1].attributes.listType, 'ordered');
      expect(items[2].attributes.listType, 'task');
      expect(items[2].attributes.checked, isTrue);
    });

    test('html format preserves inline font color', () {
      final paste = service.parse(
        '<p><span style="color: #d81b60">colored</span></p>',
        format: ClipboardPasteFormat.html,
      );

      expect(paste.isBlocks, isTrue);
      final block = paste.blocks.single as TextBlockNode;
      final run = block.content.single as TextRun;
      expect(run.text, 'colored');
      expect(run.attributes.color, 0xFFD81B60);
    });

    test('external image descriptions produce a blocks paste payload', () {
      var id = 0;
      final paste = service.parseExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/paste.png',
            caption: 'paste',
            altText: 'pasted image',
            width: 640,
            height: 360,
          ),
        ],
        newBlockId: () => 'img-${++id}',
      );

      expect(paste, isNotNull);
      expect(paste!.isBlocks, isTrue);
      expect(paste.blocks, hasLength(1));
      final image = paste.blocks.single as ImageBlockNode;
      expect(image.id, 'img-1');
      expect(image.file, 'C:/tmp/paste.png');
      expect(image.width, 640);
      expect(image.height, 360);
      expect(image.showWidth, isNull);
      expect(image.showHeight, isNull);
      expect(image.caption, 'paste');
      expect(image.altText, 'pasted image');
    });

    test('external image descriptions without dimensions remain insertable',
        () {
      final paste = service.parseExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/unsized.png',
            caption: 'unsized',
            altText: 'unsized alt',
          ),
        ],
        newBlockId: () => 'img-unsized',
      );

      expect(paste, isNotNull);
      final image = paste!.blocks.single as ImageBlockNode;
      expect(image.file, 'C:/tmp/unsized.png');
      expect(image.width, 0);
      expect(image.height, 0);
      expect(image.showWidth, isNull);
      expect(image.showHeight, isNull);
    });

    test('external image descriptions preserve multi-image order', () {
      var id = 0;
      final paste = service.parseExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/first.png',
            caption: 'first',
            altText: 'first alt',
          ),
          ExternalImageBlockDescription(
            file: 'C:/tmp/second.webp',
            caption: 'second',
            altText: 'second alt',
          ),
        ],
        newBlockId: () => 'img-${++id}',
      );

      expect(paste, isNotNull);
      expect(paste!.blocks, hasLength(2));
      final first = paste.blocks[0] as ImageBlockNode;
      final second = paste.blocks[1] as ImageBlockNode;
      expect(first.id, 'img-1');
      expect(first.file, 'C:/tmp/first.png');
      expect(first.caption, 'first');
      expect(first.altText, 'first alt');
      expect(second.id, 'img-2');
      expect(second.file, 'C:/tmp/second.webp');
      expect(second.caption, 'second');
      expect(second.altText, 'second alt');
      expect(paste.text, '[image: first]\n[image: second]');
    });

    test('external image descriptions return null when none are insertable',
        () {
      var id = 0;
      final empty = service.parseExternalImages(
        const <ExternalImageBlockDescription>[],
        newBlockId: () => 'img-${++id}',
      );
      final blank = service.parseExternalImages(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: '   ',
            caption: 'blank',
            altText: 'blank',
          ),
        ],
        newBlockId: () => 'img-${++id}',
      );

      expect(empty, isNull);
      expect(blank, isNull);
      expect(id, 0);
    });

    test('legacy pasteMarkdown returns inline content for one paragraph', () {
      final inline = service.pasteMarkdown('hello **world**');

      expect(inline, isNotNull);
      expect(inline!.map((node) => node.plainText).join(), 'hello world');
    });
  });

  group('controller paste integration', () {
    test('paste plain single line inserts at caret', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('XY');

      expect(controller.document.plainText, 'aXYb');
      expect(controller.selection?.extent.offset, 3);
    });

    test('paste plain multi-line splits into blocks', () {
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText('X\nYY\nZ');

      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.plainText, 'aX\nYY\nZb');
      expect(
        controller.document.blocks.map((block) => block.runtimeType),
        <Type>[TextBlockNode, TextBlockNode, TextBlockNode],
      );
    });

    test('paste plain multi-line into code block preserves raw code', () {
      const pasted = '# title\n\n  final url = "http://example.test";\n```\n';
      final controller = WenzRichTextController(
        document: _codeDoc(
          'ab',
          language: 'dart',
          attributes: const BlockAttributes(anchor: 'code-anchor'),
        ),
        selection: collapsedCodeSelection('code1', 0, 1),
      );

      controller.pasteText(pasted);

      expect(controller.document.blocks, hasLength(1));
      final block = controller.document.blocks.single as CodeBlockNode;
      expect(block.id, 'code1');
      expect(block.language, 'dart');
      expect(block.attributes.anchor, 'code-anchor');
      expect(block.code, 'a${pasted}b');
      expect(
          controller.selection?.extent.path, PositionPath.blockCode('code1'));
      expect(controller.selection?.extent.offset, 1 + pasted.length);
    });

    test('paste plain multi-line replaces code selection in one undo step', () {
      const original = '0123456789';
      const pasted = 'A\nB\n';
      final controller = WenzRichTextController(
        document: _codeDoc(
          original,
          language: 'dart',
          attributes: const BlockAttributes(anchor: 'code-anchor'),
        ),
        selection: _codeSelection('code1', 0, 2, 7),
      );

      controller.pasteText(pasted);

      var block = controller.document.blocks.single as CodeBlockNode;
      expect(block.code, '01${pasted}789');
      expect(block.language, 'dart');
      expect(block.attributes.anchor, 'code-anchor');
      expect(controller.selection?.extent.offset, 2 + pasted.length);

      expect(controller.undo(), isTrue);
      block = controller.document.blocks.single as CodeBlockNode;
      expect(block.code, original);
      expect(block.language, 'dart');
      expect(block.attributes.anchor, 'code-anchor');
    });

    test('paste plain text does not trigger Markdown shortcuts', () {
      final controller = WenzRichTextController(
        document: _emptyDoc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      controller.pasteText('# ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.paragraph);
      expect(block.plainText, '# ');
    });

    test('pasteMarkdown into an empty paragraph preserves block structure', () {
      final controller = WenzRichTextController(
        document: _emptyDoc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      controller.pasteMarkdown('# Title\n\n- item');

      expect(controller.document.blocks, hasLength(2));
      expect((controller.document.blocks[0] as TextBlockNode).type,
          BlockType.heading);
      expect(controller.document.blocks[0].plainText, 'Title');
      expect((controller.document.blocks[1] as TextBlockNode).type,
          BlockType.listItem);
      expect(controller.document.blocks[1].plainText, 'item');
      expect(controller.selection?.extent.blockIndex, 1);
      expect(controller.selection?.extent.offset, 4);
    });

    test('pasteHtml into an empty paragraph preserves block structure', () {
      final controller = WenzRichTextController(
        document: _emptyDoc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      controller.pasteHtml('<h2>Title</h2><p>body</p>');

      expect(controller.document.blocks, hasLength(2));
      final heading = controller.document.blocks[0] as TextBlockNode;
      expect(heading.type, BlockType.heading);
      expect(heading.attributes.level, 2);
      expect(controller.document.blocks[1].plainText, 'body');
      expect(controller.selection?.extent.blockIndex, 1);
      expect(controller.selection?.extent.offset, 4);
    });

    test('single structured block keeps caret after pasted text', () {
      final controller = WenzRichTextController(
        document: _doc('beforeafter'),
        selection: collapsedTextSelection('p1', 0, 6),
      );

      controller.pasteMarkdown('**XY**');

      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.plainText, 'beforeXYafter');
      expect(
        controller.selection,
        collapsedTextSelection('p1', 0, 8),
      );
    });

    test('single structured block replacement includes retained prefix', () {
      final controller = WenzRichTextController(
        document: _doc('leftOLDright'),
        selection: textSelection('p1', 0, 4, 7),
      );

      controller.pasteHtml('<p><strong>new</strong></p>');

      expect(controller.document.blocks, hasLength(1));
      expect(controller.document.plainText, 'leftnewright');
      expect(
        controller.selection,
        collapsedTextSelection('p1', 0, 7),
      );
    });

    test('paste rich payload preserves attributes', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'bold',
                attributes: TextAttributes(bold: true, color: 0xFFD81B60),
              ),
            ],
          ),
        ],
      );
      final payload = service.copy(
        source,
        textSelection('p1', 0, 0, 4),
      )!;

      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      final block = controller.document.blocks.single as TextBlockNode;
      final pastedRun = block.content
          .whereType<TextRun>()
          .firstWhere((r) => r.text == 'bold');
      expect(pastedRun.attributes.bold, isTrue);
      expect(pastedRun.attributes.color, 0xFFD81B60);
      expect(controller.selection?.extent.offset, 5);
    });

    test('paste rich payload re-inserts an inline embed', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'src',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'x'),
              InlineEmbed(
                  embedType: 'formula', data: <String, Object?>{'text': 'y'}),
              TextRun(text: 'z'),
            ],
          ),
        ],
      );
      final payload = service.copy(
        source,
        DocumentSelection(
          base: DocumentPosition.text(blockId: 'src', blockIndex: 0, offset: 0),
          extent:
              DocumentPosition.text(blockId: 'src', blockIndex: 0, offset: 3),
        ),
      )!;

      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      final block = controller.document.blocks.single as TextBlockNode;
      final embeds = block.content.whereType<InlineEmbed>().toList();
      expect(embeds, hasLength(1));
      expect(embeds.single.embedType, 'formula');
      expect(embeds.single.data['text'], 'y');
    });

    test('copy and paste a complete unordered item preserves list structure',
        () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'source-li',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'copied bullet')],
          ),
        ],
      );
      final payload = service.copyPayload(
        source,
        textSelection('source-li', 0, 0, 'copied bullet'.length),
      )!;
      final controller = WenzRichTextController(
        document: _emptyDoc(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      // The editor paste path prioritises this private flavour over HTML.
      controller.pasteText(payload.wenzRichText);

      expect(controller.document.blocks, hasLength(1));
      final pasted = controller.document.blocks.single as TextBlockNode;
      expect(pasted.type, BlockType.listItem);
      expect(pasted.attributes.listType, isNull);
      expect(pasted.plainText, 'copied bullet');
    });

    test('cut deletes the selection and returns the payload', () {
      final controller = WenzRichTextController(
        document: _doc('abcdef'),
        selection: textSelection('p1', 0, 1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(controller.document.plainText, 'aef');
    });

    test('cut deletes a table cell selection and returns its payload', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _tableCellSelection(1, 4),
      );

      final payload = controller.cutSelection();

      expect(payload, isNotNull);
      expect(service.parse(payload!).text, 'ell');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'Ho');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 1);
    });

    test('cut clears a table cell range and returns TSV', () {
      final controller = WenzRichTextController(
        document: _tableRangeDoc(),
        selection: _tableRangeSelection(),
      );

      final payload = controller.cutSelection();

      expect(payload, 'AA\tBB\nCC\tDD');
      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, '');
      expect(table.table.cellAt(0, 1)!.plainText, '');
      expect(table.table.cellAt(1, 0)!.plainText, '');
      expect(table.table.cellAt(1, 1)!.plainText, '');
      expect(controller.selection?.extent.path.tableRowIndex, 0);
      expect(controller.selection?.extent.path.tableColumnIndex, 0);
    });

    test('paste plain single line inserts into table cell', () {
      final controller = WenzRichTextController(
        document: _tableDoc(),
        selection: _collapsedTableCellSelection(2),
      );

      controller.pasteText('XY');

      final table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.cellAt(0, 0)!.plainText, 'HeXYllo');
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
      expect(controller.selection?.extent.offset, 4);
    });

    test('paste rich payload preserves attributes inside table cell', () {
      final payload = service.copy(_tableDoc(), _tableCellSelection(0, 2))!;
      final controller = WenzRichTextController(
        document: _plainTableDoc('ab'),
        selection: _collapsedTableCellSelection(1),
      );

      controller.pasteText(payload);

      final table = controller.document.blocks.single as TableBlockNode;
      final cellBlock =
          table.table.cellAt(0, 0)!.blocks.single as TextBlockNode;
      final pastedRun = cellBlock.content
          .whereType<TextRun>()
          .firstWhere((run) => run.text.contains('He'));
      expect(table.table.cellAt(0, 0)!.plainText, 'aHeb');
      expect(pastedRun.text, 'He');
      expect(pastedRun.attributes.bold, isTrue);
      expect(controller.selection?.extent.path.isTableCellText, isTrue);
    });

    test('cross-block copy then paste restores block structure', () {
      // Source: two paragraphs with distinct inline attributes.
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'bo', attributes: TextAttributes(bold: true)),
              TextRun(text: 'ld'),
            ],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'it', attributes: TextAttributes(italic: true)),
            ],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 2,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Target: a single paragraph "ab" with the caret between a and b.
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );
      controller.pasteText(payload);

      // Expectation: "a" + bold+plain merged into block 1, italic in block 2,
      // then trailing "b" merged into the last block.
      expect(controller.document.blocks, hasLength(2));
      final first = controller.document.blocks[0] as TextBlockNode;
      final second = controller.document.blocks[1] as TextBlockNode;
      expect(first.plainText, 'abold');
      expect(second.plainText, 'itb');
      expect(controller.selection?.extent.blockIndex, 1);
      expect(controller.selection?.extent.offset, 2);
      // bold preserved on the 'bo' slice, italic on the 'it' slice.
      final boldRun = first.content.whereType<TextRun>().firstWhere(
            (r) => r.text.contains('bo'),
          );
      expect(boldRun.attributes.bold, isTrue);
      final italicRun = second.content.whereType<TextRun>().firstWhere(
            (r) => r.text.contains('it'),
          );
      expect(italicRun.attributes.italic, isTrue);
    });

    test('cross-block paste into a selection replaces the selection', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'X')],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Y')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 1,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Target: "a[BB]c" — selection covers 'BB', caret-equivalent after paste
      // should leave 'a' + X + (new block) Y + 'c'.
      final controller = WenzRichTextController(
        document: _doc('aBBc'),
        selection: textSelection('p1', 0, 1, 3),
      );
      controller.pasteText(payload);

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0].plainText, 'aX');
      expect(controller.document.blocks[1].plainText, 'Yc');
      expect(controller.selection?.extent.blockIndex, 1);
      expect(controller.selection?.extent.offset, 1);
    });

    test('cross-block copy-paste round-trips through cut', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 's1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello')],
          ),
          TextBlockNode(
            id: 's2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'world')],
          ),
        ],
      );
      final sel = DocumentSelection(
        base: DocumentPosition(
          blockId: 's1',
          blockIndex: 0,
          path: PositionPath.blockText('s1'),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 's2',
          blockIndex: 1,
          path: PositionPath.blockText('s2'),
          offset: 5,
        ),
      );
      final payload = service.copy(source, sel)!;

      // Cut removes the selected range; the payload still parses as blocks.
      final cutController = WenzRichTextController(
        document: source,
        selection: sel,
      );
      final cutPayload = cutController.cutSelection()!;
      expect(service.parse(cutPayload).isBlocks, isTrue);

      // Pasting elsewhere restores the two blocks.
      final target = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 't1',
              type: BlockType.paragraph,
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('t1', 0, 0),
      );
      target.pasteText(cutPayload);
      expect(target.document.blocks, hasLength(2));
      expect(target.document.blocks[0].plainText, 'hello');
      expect(target.document.blocks[1].plainText, 'world');
      expect(payload, isNotNull);
    });

    test('paste copied image into text uses a fresh id once', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
          ImageBlockNode(id: 'img1', assetId: 'hero', file: 'hero.png'),
        ],
      );
      final payload = service.copy(source, objectSelection('img1', 1))!;
      final controller = WenzRichTextController(
        document: source,
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText(payload);

      final images = controller.document.blocks.whereType<ImageBlockNode>();
      expect(images, hasLength(2));
      final pastedImage = controller.document.blocks[1] as ImageBlockNode;
      expect(pastedImage.id, isNot('img1'));
      expect(pastedImage.assetId, 'hero');
      expect(controller.document.blocks[3].id, 'img1');
      expect(controller.selection?.extent.path.isBlockText, isTrue);
      expect(
        controller.selection?.extent.blockId,
        controller.document.blocks[2].id,
      );
    });

    test('paste copied video into text uses a fresh id and keeps metadata', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            playbackUrl: 'https://cdn.example.test/clip.mp4',
            file: 'clip.mp4',
            coverUrl: 'https://cdn.example.test/cover.jpg',
            title: 'Launch clip',
            description: 'Demo reel',
            aspectRatio: 4 / 3,
            uploadStatus: FileUploadStatus.uploaded,
          ),
        ],
      );
      final payload = service.copy(source, objectSelection('video1', 0))!;
      final controller = WenzRichTextController(
        document: _doc('ab'),
        selection: collapsedTextSelection('p1', 0, 1),
      );

      controller.pasteText(payload);

      expect(controller.document.blocks, hasLength(3));
      final pastedVideo = controller.document.blocks[1] as VideoBlockNode;
      expect(pastedVideo.id, isNot('video1'));
      expect(pastedVideo.assetId, 'clip');
      expect(pastedVideo.playbackUrl, 'https://cdn.example.test/clip.mp4');
      expect(pastedVideo.file, 'clip.mp4');
      expect(pastedVideo.coverUrl, 'https://cdn.example.test/cover.jpg');
      expect(pastedVideo.title, 'Launch clip');
      expect(pastedVideo.description, 'Demo reel');
      expect(pastedVideo.aspectRatio, 4 / 3);
      expect(pastedVideo.uploadStatus, FileUploadStatus.uploaded);
      expect(controller.selection?.extent.path.isBlockText, isTrue);
      expect(controller.selection?.extent.blockId,
          controller.document.blocks[2].id);
    });

    test('paste copied image after an object selects the pasted image', () {
      const source = RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'src-img', assetId: 'hero', file: 'hero.png'),
        ],
      );
      final payload = service.copy(source, objectSelection('src-img', 0))!;
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'target-img', assetId: 'target'),
          ],
        ),
        selection: collapsedObjectSelection('target-img', 0),
      );

      controller.pasteText(payload);

      expect(controller.document.blocks, hasLength(2));
      final pastedImage = controller.document.blocks[1] as ImageBlockNode;
      expect(pastedImage.id, isNot('src-img'));
      expect(controller.selection?.isCollapsed, isFalse);
      expect(controller.selection?.start.blockId, pastedImage.id);
      expect(controller.selection?.start.path.isBlockObject, isTrue);
      expect(controller.selection?.start.offset, 0);
      expect(controller.selection?.end.blockId, pastedImage.id);
      expect(controller.selection?.end.offset, 1);
    });
  });
}

RichTextDocument _doc(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}

RichTextDocument _emptyDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[],
      ),
    ],
  );
}

RichTextDocument _codeDoc(
  String code, {
  String language = '',
  BlockAttributes attributes = const BlockAttributes(),
}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      CodeBlockNode(
        id: 'code1',
        code: code,
        language: language,
        attributes: attributes,
      ),
    ],
  );
}

DocumentSelection _codeSelection(
  String blockId,
  int blockIndex,
  int startOffset,
  int endOffset,
) {
  final path = PositionPath.blockCode(blockId);
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: path,
    offset: startOffset,
  );
  final end = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: path,
    offset: endOffset,
  );
  return DocumentSelection(base: start, extent: end);
}

RichTextDocument _tableDoc([String plainTail = 'llo']) {
  return RichTextDocument(
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
                    content: <InlineNode>[
                      const TextRun(
                        text: 'He',
                        attributes:
                            TextAttributes(bold: true, color: 0xFFD81B60),
                      ),
                      TextRun(text: plainTail),
                    ],
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

RichTextDocument _plainTableDoc(String text) {
  return RichTextDocument(
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
                    content: <InlineNode>[TextRun(text: text)],
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

RichTextDocument _tableRangeDoc() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'AA')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'BB')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'cell-c',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-c-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'CC')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-d',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-d-p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'DD')],
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

DocumentSelection _tableRangeSelection() {
  return DocumentSelection(
    base: _tableCellPositionAt(row: 0, column: 0),
    extent: _tableCellPositionAt(row: 1, column: 1),
  );
}

DocumentSelection _reversedTableRangeSelection() {
  return DocumentSelection(
    base: _tableCellPositionAt(row: 1, column: 1),
    extent: _tableCellPositionAt(row: 0, column: 0),
  );
}

DocumentPosition _tableCellPositionAt({required int row, required int column}) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: row,
    tableColumnIndex: column,
    offset: 0,
  );
}

DocumentSelection _tableCellSelection(int start, int end) {
  return DocumentSelection(
    base: _tableCellPosition(start),
    extent: _tableCellPosition(end),
  );
}

DocumentSelection _collapsedTableCellSelection(int offset) {
  final position = _tableCellPosition(offset);
  return DocumentSelection(base: position, extent: position);
}

DocumentPosition _tableCellPosition(int offset) {
  return DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: offset,
  );
}

DocumentSelection collapsedObjectSelection(String blockId, int blockIndex) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: position, extent: position);
}

DocumentSelection objectSelection(String blockId, int blockIndex) {
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
}
