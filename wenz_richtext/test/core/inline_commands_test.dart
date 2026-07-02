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

  test('auto link detects URLs and leaves trailing punctuation unlinked', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'See https://wenz.dev/docs, and www.example.com.',
              ),
            ],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 45),
    );
    final executor = CommandExecutor(session);

    executor.execute(const AutoLinkUrlsCommand());

    final block = session.document.blocks.single as TextBlockNode;
    final linkedRuns = block.content
        .whereType<TextRun>()
        .where((run) => run.attributes.url != null)
        .toList();
    expect(linkedRuns.map((run) => run.text), <String>[
      'https://wenz.dev/docs',
      'www.example.com',
    ]);
    expect(linkedRuns.map((run) => run.attributes.url), <String>[
      'https://wenz.dev/docs',
      'https://www.example.com',
    ]);
  });

  test('controller auto links inserted URL in the same undo step', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Visit ')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 6),
    );

    controller.insertText('https://wenz.dev', applyAutoLinkUrls: false);
    controller.insertText(' ');

    var block = controller.document.blocks.single as TextBlockNode;
    final linkedRuns = block.content
        .whereType<TextRun>()
        .where((run) => run.attributes.url != null)
        .toList();
    expect(linkedRuns.single.text, 'https://wenz.dev');
    expect(linkedRuns.single.attributes.url, 'https://wenz.dev');

    expect(controller.undo(), isTrue);
    block = controller.document.blocks.single as TextBlockNode;
    expect(block.plainText, 'Visit ');

    controller.dispose();
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
    controller.insertEmoji('😀', shortName: 'grinning');
    controller.insertInlineImage(assetId: 'asset-1', width: 32, height: 24);

    final block = controller.document.blocks.single as TextBlockNode;
    final linked = block.content.first as TextRun;
    expect(linked.attributes.url, 'https://example.com');
    expect(linked.attributes.remark, isTrue);
    final embeds = block.content.whereType<InlineEmbed>().toList();
    expect(embeds.map((embed) => embed.embedType), <String>[
      'formula',
      'mention',
      'emoji',
      'image',
    ]);
    expect(embeds[0].data['text'], 'x^2');
    expect(embeds[1].data['label'], 'Ada');
    expect(embeds[2].data['emoji'], '😀');
    expect(embeds[2].data['shortName'], 'grinning');
    expect(embeds[3].data['assetId'], 'asset-1');
  });

  test(
    'controller insertMention stores canonical payload and extension data',
    () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello ')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 6),
      );

      controller.insertMention(
        'u1',
        'Ada',
        data: const <String, Object?>{
          'id': 'stale-id',
          'label': 'Stale label',
          'role': 'admin',
          'department': 'Platform',
          'profile': <String, Object?>{'timezone': 'UTC'},
        },
      );

      final block = controller.document.blocks.single as TextBlockNode;
      final mention = block.content.singleWhere(
        (node) => node is InlineEmbed && node.embedType == 'mention',
      ) as InlineEmbed;
      expect(mention.data['id'], 'u1');
      expect(mention.data['label'], 'Ada');
      expect(mention.data['role'], 'admin');
      expect(mention.data['department'], 'Platform');
      expect(
        mention.data['profile'],
        const <String, Object?>{'timezone': 'UTC'},
      );
      expect(controller.toMarkdown(), 'Hello @Ada');

      controller.dispose();
    },
  );

  test('controller insertMention keeps empty label fallback', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    controller.insertMention('u-empty', '');

    final block = controller.document.blocks.single as TextBlockNode;
    final mention = block.content.single as InlineEmbed;
    expect(mention.data['id'], 'u-empty');
    expect(mention.data['label'], '');
    expect(controller.toMarkdown(), '@mention');

    controller.dispose();
  });

  test('controller insertMention replaces selected query and moves caret', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Ping @ad now')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 12),
    );

    controller.insertMention(
      'u-ada',
      'Ada',
      data: const <String, Object?>{'team': 'Core'},
      selection: textSelection('p1', 0, 5, 8),
    );

    final block = controller.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(3));
    expect((block.content[0] as TextRun).text, 'Ping ');
    final mention = block.content[1] as InlineEmbed;
    expect(mention.embedType, 'mention');
    expect(mention.data['id'], 'u-ada');
    expect(mention.data['label'], 'Ada');
    expect(mention.data['team'], 'Core');
    expect((block.content[2] as TextRun).text, ' now');
    expect(controller.selection, collapsedTextSelection('p1', 0, 6));

    controller.dispose();
  });

  test('controller updates inline formula data and preserves undo history', () {
    final initialSelection = collapsedTextSelection('p1', 0, 0);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'latex': 'x^2'},
              ),
              TextRun(text: ' now'),
            ],
          ),
        ],
      ),
      selection: initialSelection,
    );

    controller.updateInlineFormula(
      position: DocumentPosition.text(
        blockId: 'p1',
        blockIndex: 0,
        offset: 6,
      ),
      text: ' y^2 ',
    );

    var block = controller.document.blocks.single as TextBlockNode;
    var formula = block.content[1] as InlineEmbed;
    expect(controller.selection, initialSelection);
    expect(formula.data['text'], 'y^2');
    expect(formula.data['latex'], 'y^2');
    expect(formula.data['value'], 'y^2');
    expect(formula.data['formula'], 'y^2');

    expect(controller.undo(), isTrue);
    block = controller.document.blocks.single as TextBlockNode;
    formula = block.content[1] as InlineEmbed;
    expect(formula.data['text'], isNull);
    expect(formula.data['latex'], 'x^2');

    expect(controller.redo(), isTrue);
    block = controller.document.blocks.single as TextBlockNode;
    formula = block.content[1] as InlineEmbed;
    expect(formula.data['text'], 'y^2');

    controller.dispose();
  });

  test('controller updates block formula by id and keeps fallback in sync', () {
    final initialSelection = collapsedTextSelection('p1', 0, 0);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before')],
          ),
          BlockEmbedNode(
            id: 'formula-block',
            embedType: 'formula',
            data: <String, Object?>{'value': 'old'},
            fallbackText: 'old fallback',
          ),
        ],
      ),
      selection: initialSelection,
    );

    controller.updateBlockFormula(blockId: 'formula-block', text: r'\frac{1}{2}');

    var block = controller.document.blocks[1] as BlockEmbedNode;
    expect(controller.selection, initialSelection);
    expect(block.fallbackText, r'\frac{1}{2}');
    expect(block.data['text'], r'\frac{1}{2}');
    expect(block.data['latex'], r'\frac{1}{2}');
    expect(block.data['value'], r'\frac{1}{2}');
    expect(block.data['formula'], r'\frac{1}{2}');

    expect(controller.undo(), isTrue);
    block = controller.document.blocks[1] as BlockEmbedNode;
    expect(block.fallbackText, 'old fallback');
    expect(block.data['value'], 'old');

    expect(controller.redo(), isTrue);
    block = controller.document.blocks[1] as BlockEmbedNode;
    expect(block.fallbackText, r'\frac{1}{2}');

    controller.dispose();
  });

  test('formula updates are no-op for empty or non-formula targets', () {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Hi '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
            ],
          ),
          BlockEmbedNode(
            id: 'chart-block',
            embedType: 'chart',
            data: <String, Object?>{'text': 'chart'},
          ),
        ],
      ),
    );
    final before = controller.toJson();

    controller.updateInlineFormula(
      position: DocumentPosition.text(
        blockId: 'p1',
        blockIndex: 0,
        offset: 3,
      ),
      text: 'x^2',
    );
    controller.updateBlockFormula(blockId: 'chart-block', text: 'x^2');
    controller.updateBlockFormula(blockId: 'missing', text: 'x^2');
    controller.updateBlockFormula(blockId: 'chart-block', text: '   ');

    expect(controller.toJson(), before);
    expect(controller.canUndo, isFalse);

    controller.dispose();
  });

  test('controller updates only the targeted inline formula among many', () {
    // Two formulas share one paragraph. Updating the first by position must
    // leave the second's data untouched — the data-level counterpart to the
    // multi-formula rendering regression.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Ask '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'latex': 'a+b'},
              ),
              TextRun(text: ' then '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'latex': 'c+d'},
              ),
              TextRun(text: ' end'),
            ],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    // 'Ask ' occupies offsets 0..4; the first formula placeholder is 4..5.
    controller.updateInlineFormula(
      position: DocumentPosition.text(
        blockId: 'p1',
        blockIndex: 0,
        offset: 4,
      ),
      text: 'x+y',
    );

    var block = controller.document.blocks.single as TextBlockNode;
    final first = block.content[1] as InlineEmbed;
    final second = block.content[3] as InlineEmbed;
    expect(first.data['latex'], 'x+y');
    expect(first.data['text'], 'x+y');
    // The second formula keeps its original data.
    expect(second.data['latex'], 'c+d');
    expect(second.data['text'], isNull);

    expect(controller.undo(), isTrue);
    block = controller.document.blocks.single as TextBlockNode;
    expect((block.content[1] as InlineEmbed).data['latex'], 'a+b');
    expect((block.content[3] as InlineEmbed).data['latex'], 'c+d');

    expect(controller.redo(), isTrue);
    block = controller.document.blocks.single as TextBlockNode;
    expect((block.content[1] as InlineEmbed).data['latex'], 'x+y');

    controller.dispose();
  });
}
