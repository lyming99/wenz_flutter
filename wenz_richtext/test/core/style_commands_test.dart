import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('format text splits run and applies attributes to selected range', () {
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
      const FormatTextCommand(attributes: TextAttributes(bold: true)),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.plainText, 'Hello');
    expect(block.content, hasLength(3));
    expect((block.content[1] as TextRun).text, 'ell');
    expect((block.content[1] as TextRun).attributes.bold, isTrue);
    expect(session.canUndo, isTrue);
  });

  test('format text applies across text blocks', () {
    final session = DocumentSession(
      document: const RichTextDocument(
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
      ),
      selection: DocumentSelection(
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
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const FormatTextCommand(attributes: TextAttributes(italic: true)),
    );

    final first = session.document.blocks[0] as TextBlockNode;
    final second = session.document.blocks[1] as TextBlockNode;
    expect((first.content.last as TextRun).text, 'bc');
    expect((first.content.last as TextRun).attributes.italic, isTrue);
    expect((second.content.first as TextRun).text, 'de');
    expect((second.content.first as TextRun).attributes.italic, isTrue);
  });

  test('clear style resets selected inline attributes only', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Hello',
                attributes: TextAttributes(bold: true, italic: true),
              ),
            ],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );
    final executor = CommandExecutor(session);

    executor.execute(const ClearStyleCommand());

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.content, hasLength(3));
    expect((block.content.first as TextRun).attributes.bold, isTrue);
    expect((block.content[1] as TextRun).attributes.isEmpty, isTrue);
    expect((block.content.last as TextRun).attributes.italic, isTrue);
  });

  test('set block type converts selected text blocks to heading', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Title')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(type: BlockType.heading, level: 2),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.attributes.level, 2);
  });

  test('set block type converts selected text blocks to check list item', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Task')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final executor = CommandExecutor(session);

    executor.execute(
      const SetBlockTypeCommand(
        type: BlockType.listItem,
        listType: 'check',
        checked: false,
      ),
    );

    final block = session.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.listItem);
    // 'check' is normalised to the canonical 'task' list type.
    expect(block.attributes.listType, 'task');
    expect(block.attributes.checked, isFalse);
  });

  test('set alignment updates non-text block attributes too', () {
    final session = DocumentSession(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'img', assetId: 'asset', width: 10, height: 10),
        ],
      ),
      selection: const DocumentSelection(
        base: DocumentPosition(
          blockId: 'img',
          blockIndex: 0,
          path: PositionPath(<Object>['block', 'img', 'object']),
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'img',
          blockIndex: 0,
          path: PositionPath(<Object>['block', 'img', 'object']),
          offset: 0,
        ),
      ),
    );
    final executor = CommandExecutor(session);

    executor.execute(const SetAlignmentCommand(alignment: 'center'));

    expect(session.document.blocks.single.attributes.alignment, 'center');
  });
}
