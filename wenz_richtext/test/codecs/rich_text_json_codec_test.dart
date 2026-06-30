import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('rich text json codec round trips core model', () {
    const codec = RichTextJsonCodec();
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'heading',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 2),
          content: <InlineNode>[
            TextRun(
              text: 'Hello',
              attributes: TextAttributes(bold: true, color: 0xFFD81B60),
            ),
            InlineEmbed(
              embedType: 'formula',
              data: <String, Object?>{'text': 'x^2'},
            ),
            InlineEmbed(
              embedType: 'emoji',
              data: <String, Object?>{
                'emoji': '😀',
                'shortName': 'grinning',
              },
            ),
          ],
        ),
        ImageBlockNode(
          id: 'image',
          assetId: 'img-1',
          file: 'assets/img-1.png',
          width: 320,
          height: 180,
          showWidth: 160,
          showHeight: 90,
          caption: 'Hero caption',
          altText: 'Hero alt',
        ),
        VideoBlockNode(
          id: 'video',
          assetId: 'video-1',
          playbackUrl: 'https://cdn.example.com/video.mp4',
          file: 'local/video.mp4',
          coverUrl: 'https://cdn.example.com/cover.jpg',
          title: 'Launch clip',
          description: 'Product launch overview',
          aspectRatio: 16 / 9,
          uploadStatus: FileUploadStatus.uploaded,
        ),
        BlockEmbedNode(
          id: 'embed',
          embedType: 'crm-card',
          data: <String, Object?>{'recordId': '42'},
          fallbackText: 'Acme account',
        ),
        TableBlockNode(
          id: 'table',
          table: TableModel(
            columnAlignments: <int, String>{1: 'right'},
            columnWidths: <int, double>{0: 120},
            rows: <List<TableCellNode>>[
              <TableCellNode>[
                TableCellNode(
                  id: 'cell-a',
                  rowSpan: 1,
                  columnSpan: 2,
                  isHeader: true,
                  backgroundColor: 0xFFEFEFEF,
                  blocks: <BlockNode>[
                    TextBlockNode(
                      id: 'cell-a-p',
                      type: BlockType.paragraph,
                      content: <InlineNode>[TextRun(text: 'A')],
                    ),
                  ],
                ),
                TableCellNode(id: 'cell-b', covered: true),
              ],
            ],
          ),
        ),
      ],
    );

    final encoded = codec.encode(document);
    final decoded = codec.decode(encoded);

    expect(decoded.version, 1);
    expect(decoded.blocks, hasLength(5));
    expect(decoded.blocks.first, isA<TextBlockNode>());
    expect(
      ((decoded.blocks.first as TextBlockNode).content.first as TextRun)
          .attributes
          .color,
      0xFFD81B60,
    );
    expect(
      (decoded.blocks.first as TextBlockNode).content.last,
      isA<InlineEmbed>(),
    );
    final emoji =
        (decoded.blocks.first as TextBlockNode).content.last as InlineEmbed;
    expect(emoji.embedType, 'emoji');
    expect(emoji.data['emoji'], '😀');
    expect(emoji.data['shortName'], 'grinning');
    final video = decoded.blocks[2] as VideoBlockNode;
    expect(video.assetId, 'video-1');
    expect(video.playbackUrl, 'https://cdn.example.com/video.mp4');
    expect(video.file, 'local/video.mp4');
    expect(video.coverUrl, 'https://cdn.example.com/cover.jpg');
    expect(video.title, 'Launch clip');
    expect(video.description, 'Product launch overview');
    expect(video.aspectRatio, 16 / 9);
    expect(video.uploadStatus, FileUploadStatus.uploaded);
    expect(decoded.toJson(), document.toJson());
  });

  test('json import ignores collapse UI metadata and re-exports content only',
      () {
    const codec = RichTextJsonCodec();
    const source = '''
{
  "version": 1,
  "metadata": {
    "outlineCollapse": {
      "collapsedBlockIds": ["h1"]
    }
  },
  "blocks": [
    {
      "id": "h1",
      "type": "heading",
      "attrs": {"level": 1, "collapsed": true},
      "content": [{"text": "Section"}]
    },
    {
      "id": "p1",
      "type": "paragraph",
      "attrs": {"hiddenByHeading": "h1"},
      "content": [{"text": "Body stays in the document"}]
    }
  ]
}
''';

    final document = codec.decode(source);
    final controller = WenzRichTextController(document: document);
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    addTearDown(controller.dispose);

    expect(document.blocks, hasLength(2));
    expect(document.plainText, 'Section\nBody stays in the document');
    expect(outline.collapsedBlockIds, isEmpty);
    expect(outline.hiddenBlockIds, isEmpty);

    final encoded = jsonDecode(codec.encode(document)) as Map<String, Object?>;
    expect(encoded, isNot(contains('metadata')));
    expect(jsonEncode(encoded), isNot(contains('collapsed')));
    expect(jsonEncode(encoded), isNot(contains('hiddenByHeading')));
  });

  test('callout body deletion keeps metadata in json export', () {
    const codec = RichTextJsonCodec();
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

    final encoded = jsonDecode(codec.encode(document)) as Map<String, Object?>;
    final blocks = encoded['blocks'] as List<Object?>;
    final callout = blocks.single as Map<String, Object?>;
    final content = callout['content'] as List<Object?>;
    final textRun = content.single as Map<String, Object?>;

    expect(callout['id'], 'callout1');
    expect(callout['type'], BlockType.callout.name);
    expect(callout['variant'], CalloutBlockNode.warningVariant);
    expect(callout['title'], 'Heads up');
    expect(callout['icon'], '!');
    expect(callout['attrs'], <String, Object?>{'anchor': 'note-anchor'});
    expect(textRun['text'], 'Keep body');
    expect(codec.decode(codec.encode(document)).toJson(), document.toJson());
  });

  test('ordered todo list items preserve checked state in json round trip', () {
    const codec = RichTextJsonCodec();
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'todo-checked',
          type: BlockType.listItem,
          attributes: BlockAttributes(listType: 'ordered', checked: true),
          content: <InlineNode>[TextRun(text: 'Done')],
        ),
        TextBlockNode(
          id: 'todo-open',
          type: BlockType.listItem,
          attributes: BlockAttributes(listType: 'ordered', checked: false),
          content: <InlineNode>[TextRun(text: 'Open')],
        ),
        TextBlockNode(
          id: 'ordered-only',
          type: BlockType.listItem,
          attributes: BlockAttributes(listType: 'ordered'),
          content: <InlineNode>[TextRun(text: 'Numbered')],
        ),
      ],
    );

    final encoded = jsonDecode(codec.encode(document)) as Map<String, Object?>;
    final blocks = encoded['blocks'] as List<Object?>;
    final checkedAttrs = (blocks[0] as Map<String, Object?>)['attrs'];
    final openAttrs = (blocks[1] as Map<String, Object?>)['attrs'];
    final orderedAttrs = (blocks[2] as Map<String, Object?>)['attrs'];

    expect(checkedAttrs, <String, Object?>{
      'listType': 'ordered',
      'checked': true,
    });
    expect(openAttrs, <String, Object?>{
      'listType': 'ordered',
      'checked': false,
    });
    expect(orderedAttrs, <String, Object?>{'listType': 'ordered'});
    expect(codec.decode(codec.encode(document)).toJson(), document.toJson());
  });

  test('quoted heading and todo semantics round trip through json', () {
    const codec = RichTextJsonCodec();
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'quoted-heading',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 2, quoted: true),
          content: <InlineNode>[TextRun(text: 'Quoted heading')],
        ),
        TextBlockNode(
          id: 'quoted-ordered-todo',
          type: BlockType.listItem,
          attributes: BlockAttributes(
            listType: 'ordered',
            checked: false,
            quoted: true,
          ),
          content: <InlineNode>[TextRun(text: 'Quoted ordered todo')],
        ),
        TextBlockNode(
          id: 'plain-paragraph',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Plain paragraph')],
        ),
      ],
    );

    final encoded = jsonDecode(codec.encode(document)) as Map<String, Object?>;
    final blocks = encoded['blocks'] as List<Object?>;
    final headingAttrs = (blocks[0] as Map<String, Object?>)['attrs'];
    final orderedTodoAttrs = (blocks[1] as Map<String, Object?>)['attrs'];
    final plainAttrs = (blocks[2] as Map<String, Object?>)['attrs'];

    expect(headingAttrs, <String, Object?>{'level': 2, 'quoted': true});
    expect(orderedTodoAttrs, <String, Object?>{
      'listType': 'ordered',
      'checked': false,
      'quoted': true,
    });
    expect(plainAttrs, isNull);
    expect(codec.decode(codec.encode(document)).toJson(), document.toJson());
  });

  test('legacy quote json imports as quoted paragraph', () {
    const codec = RichTextJsonCodec();
    const source = '''
{
  "version": 1,
  "blocks": [
    {
      "id": "legacy-quote",
      "type": "quote",
      "content": [{"text": "Legacy quote"}]
    }
  ]
}
''';

    final document = codec.decode(source);
    final block = document.blocks.single as TextBlockNode;

    expect(block.type, BlockType.paragraph);
    expect(block.attributes.isQuoted, isTrue);
    expect(block.plainText, 'Legacy quote');
    expect(jsonEncode(document.toJson()), isNot(contains('"type":"quote"')));
  });
}
