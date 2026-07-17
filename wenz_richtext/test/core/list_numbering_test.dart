import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('ordered list numbering matches nested contiguous-list semantics', () {
    final blocks = <BlockNode>[
      _item('a', indent: 0),
      _item('b', indent: 1),
      _item('c', indent: 1),
      _item('d', indent: 0),
      _item('e', indent: 0, ordered: false),
      _item('f', indent: 0),
      _paragraph('g', indent: 1),
      _item('h', indent: 0),
      _paragraph('i', indent: 0),
      _item('j', indent: 0),
    ];

    expect(
      orderedListNumbersFor(blocks),
      <int?>[1, 1, 2, 2, null, 1, null, 2, null, 1],
    );
  });

  test('ten thousand ordered items are numbered in a single pass', () {
    final blocks = List<BlockNode>.generate(
      10000,
      (index) => _item('item-$index', indent: 0),
      growable: false,
    );

    final numbers = orderedListNumbersFor(blocks);

    expect(numbers.first, 1);
    expect(numbers.last, 10000);
  });
}

TextBlockNode _item(
  String id, {
  required int indent,
  bool ordered = true,
}) {
  return TextBlockNode(
    id: id,
    type: BlockType.listItem,
    attributes: BlockAttributes(
      indent: indent,
      listType: ordered ? 'ordered' : null,
    ),
  );
}

TextBlockNode _paragraph(String id, {required int indent}) {
  return TextBlockNode(
    id: id,
    type: BlockType.paragraph,
    attributes: BlockAttributes(indent: indent),
  );
}
