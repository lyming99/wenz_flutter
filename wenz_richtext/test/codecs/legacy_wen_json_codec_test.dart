import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const codec = LegacyWenJsonCodec();

  test('decodes text, heading, quote, and list item from legacy json', () {
    final source = File('test/fixtures/legacy_basic.json').readAsStringSync();
    final document = codec.decode(source);

    expect(document.blocks, hasLength(3));
    expect(document.blocks[0].type, BlockType.heading);
    expect(document.blocks[0].plainText, 'Wenz RichText');
    expect((document.blocks[0] as TextBlockNode).content.first, isA<TextRun>());

    final list = document.blocks[1] as TextBlockNode;
    expect(list.type, BlockType.listItem);
    expect(list.attributes.listType, 'check');
    expect(list.attributes.checked, isTrue);

    expect(document.blocks[2].type, BlockType.quote);
  });

  test('decodes table rows, alignments, and mixed cell blocks', () {
    final source = File('test/fixtures/legacy_table.json').readAsStringSync();
    final document = codec.decode(source);
    final table = document.blocks.single as TableBlockNode;

    expect(table.table.rowCount, 2);
    expect(table.table.columnCount, 2);
    expect(table.table.columnAlignments[1], 'right');
    expect(table.table.cellAt(0, 1)?.plainText, 'Value');
    expect(table.table.cellAt(1, 1)?.blocks.single, isA<ImageBlockNode>());
  });

  test('decodes code, image, formula embed, and divider', () {
    final source = File(
      'test/fixtures/legacy_code_image_formula.json',
    ).readAsStringSync();
    final document = codec.decode(source);

    expect(document.blocks[0], isA<CodeBlockNode>());
    expect((document.blocks[0] as CodeBlockNode).language, 'dart');
    expect(document.blocks[1], isA<ImageBlockNode>());
    expect((document.blocks[1] as ImageBlockNode).showWidth, 320);

    final text = document.blocks[2] as TextBlockNode;
    expect(text.content.last, isA<InlineEmbed>());
    expect((text.content.last as InlineEmbed).embedType, 'formula');

    expect(document.blocks[3], isA<DividerBlockNode>());
  });
}
