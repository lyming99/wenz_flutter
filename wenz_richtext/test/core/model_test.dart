import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('document plainText joins block text', () {
    const document = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'hello')],
        ),
        CodeBlockNode(id: 'c1', code: 'print(1);', language: 'dart'),
      ],
    );

    expect(document.plainText, 'hello\nprint(1);');
  });

  test('position compares block, path, and offset', () {
    const first = DocumentPosition(
      blockId: 'a',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'a', 'text']),
      offset: 3,
    );
    const second = DocumentPosition(
      blockId: 'a',
      blockIndex: 0,
      path: PositionPath(<Object>['block', 'a', 'text']),
      offset: 5,
    );

    expect(first.compareTo(second), lessThan(0));
    expect(
      const DocumentSelection(base: second, extent: first).start,
      same(first),
    );
  });

  test('image block round trips caption alt text and display size', () {
    const image = ImageBlockNode(
      id: 'img1',
      assetId: 'hero',
      file: 'hero.png',
      width: 640,
      height: 360,
      showWidth: 320,
      showHeight: 180,
      caption: 'Hero caption',
      altText: 'Hero alt',
    );

    final decoded = BlockNode.fromJson(image.toJson()) as ImageBlockNode;

    expect(decoded.assetId, 'hero');
    expect(decoded.file, 'hero.png');
    expect(decoded.width, 640);
    expect(decoded.height, 360);
    expect(decoded.showWidth, 320);
    expect(decoded.showHeight, 180);
    expect(decoded.caption, 'Hero caption');
    expect(decoded.altText, 'Hero alt');
    expect(decoded.plainText, 'Hero caption');
  });

  test('image block accepts legacy alt key as altText', () {
    final decoded = BlockNode.fromJson(<String, Object?>{
      'id': 'img1',
      'type': 'image',
      'assetId': 'hero',
      'alt': 'Legacy alt',
    }) as ImageBlockNode;

    expect(decoded.altText, 'Legacy alt');
  });

  test('block embed round trips data and fallback text', () {
    const block = BlockEmbedNode(
      id: 'embed1',
      embedType: 'crm-card',
      data: <String, Object?>{'recordId': '42', 'title': 'Acme'},
      fallbackText: 'Acme account',
    );

    final decoded = BlockNode.fromJson(block.toJson()) as BlockEmbedNode;

    expect(decoded.type, BlockType.embed);
    expect(decoded.embedType, 'crm-card');
    expect(decoded.data, containsPair('recordId', '42'));
    expect(decoded.displayText, 'Acme account');
    expect(decoded.plainText, 'Acme account');
  });

  test('block attributes round trip anchor', () {
    const block = TextBlockNode(
      id: 'h1',
      type: BlockType.heading,
      attributes: BlockAttributes(level: 2, anchor: 'intro'),
      content: <InlineNode>[TextRun(text: 'Intro')],
    );

    final decoded = BlockNode.fromJson(block.toJson()) as TextBlockNode;

    expect(decoded.attributes.level, 2);
    expect(decoded.attributes.anchor, 'intro');
    expect(decoded.toJson()['attrs'], containsPair('anchor', 'intro'));
  });
}
