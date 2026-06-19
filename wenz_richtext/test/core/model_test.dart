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
}
