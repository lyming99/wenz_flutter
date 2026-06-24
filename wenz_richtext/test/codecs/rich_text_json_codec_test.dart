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
            TextRun(text: 'Hello', attributes: TextAttributes(bold: true)),
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
    expect(decoded.blocks, hasLength(4));
    expect(decoded.blocks.first, isA<TextBlockNode>());
    expect(
      (decoded.blocks.first as TextBlockNode).content.last,
      isA<InlineEmbed>(),
    );
    final emoji =
        (decoded.blocks.first as TextBlockNode).content.last as InlineEmbed;
    expect(emoji.embedType, 'emoji');
    expect(emoji.data['emoji'], '😀');
    expect(emoji.data['shortName'], 'grinning');
    expect(decoded.toJson(), document.toJson());
  });
}
