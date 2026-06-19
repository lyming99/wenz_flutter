import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('set link applies and clears url on selected text', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetLinkCommand('https://example.com'));

    var block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(3));
    expect((block.content[1] as TextRun).text, 'ell');
    expect((block.content[1] as TextRun).attributes.url, 'https://example.com');

    executor.execute(const SetLinkCommand(null));

    block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(1));
    expect((block.content.single as TextRun).attributes.url, isNull);
  });

  test('toggle mark applies and clears remark', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 5),
    );
    final executor = CommandExecutor(session);

    executor.execute(const ToggleMarkCommand(TextMark.remark));

    var block = session.document.blocks.single as TextBlockNode;
    expect((block.content.single as TextRun).attributes.remark, isTrue);

    executor.execute(const ToggleMarkCommand(TextMark.remark));

    block = session.document.blocks.single as TextBlockNode;
    expect((block.content.single as TextRun).attributes.remark, isNull);
  });

  test('insert inline embed replaces selection and moves caret after embed', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const InsertInlineEmbedCommand(
        embedType: 'mention',
        data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(3));
    expect((block.content[0] as TextRun).text, 'H');
    expect((block.content[1] as InlineEmbed).embedType, 'mention');
    expect((block.content[1] as InlineEmbed).data['label'], 'Ada');
    expect((block.content[2] as TextRun).text, 'o');
    expect(session.selection?.extent.offset, 2);
  });

  test('controller wraps inline commands', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hello')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 0, 5),
    );

    controller.setLink('https://example.com');
    controller.toggleRemark();
    controller.setSelection(collapsedTextSelection('p1', 0, 5));
    controller.insertFormula('x^2');
    controller.insertMention('u1', 'Ada');
    controller.insertInlineImage(assetId: 'asset-1', width: 32, height: 24);

    final block = controller.document.blocks.single as TextBlockNode;
    final linked = block.content.first as TextRun;
    expect(linked.attributes.url, 'https://example.com');
    expect(linked.attributes.remark, isTrue);
    final embeds = block.content.whereType<InlineEmbed>().toList();
    expect(embeds.map((embed) => embed.embedType), <String>[
      'formula',
      'mention',
      'image',
    ]);
    expect(embeds[0].data['text'], 'x^2');
    expect(embeds[1].data['label'], 'Ada');
    expect(embeds[2].data['assetId'], 'asset-1');
  });
}
