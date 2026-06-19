import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('IndentCommand', () {
    test('increases indent on text blocks in the selection', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'a')],
            ),
            TextBlockNode(
              id: 'p2',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'b')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const IndentCommand(1));

      final block = session.document.blocks[0] as TextBlockNode;
      expect(block.attributes.indent, 1);
      // block 2 untouched (not in the collapsed selection); normaliser clamps
      // a null indent to 0.
      expect(
        (session.document.blocks[1] as TextBlockNode).attributes.indent,
        0,
      );
    });

    test('clamps at zero when outdenting an unindented block', () {
      final session = DocumentSession(
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
      final executor = CommandExecutor(session);

      executor.execute(const IndentCommand(-1));

      expect(
        (session.document.blocks.single as TextBlockNode).attributes.indent,
        0,
      );
    });
  });

  group('ToggleTodoCommand', () {
    test('converts a paragraph to an unchecked task item', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'todo')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleTodoCommand());

      final block = session.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'task');
      expect(block.attributes.checked, isFalse);
    });

    test('toggles checked state on an existing task item', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 't1',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'task', checked: false),
              content: <InlineNode>[TextRun(text: 'todo')],
            ),
          ],
        ),
        selection: collapsedTextSelection('t1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleTodoCommand());

      expect(
        (session.document.blocks.single as TextBlockNode).attributes.checked,
        isTrue,
      );
    });
  });

  group('SetCodeLanguageCommand', () {
    test('updates the language of the code block at the caret', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(id: 'c1', code: 'print(1)', language: 'text'),
          ],
        ),
        selection: collapsedCodeSelection('c1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const SetCodeLanguageCommand('python'));

      expect(
        (session.document.blocks.single as CodeBlockNode).language,
        'python',
      );
    });

    test('no-op on a non-code block', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'hi')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const SetCodeLanguageCommand('python'));

      expect(session.document.blocks.single, isA<TextBlockNode>());
    });
  });

  group('ToggleQuoteCommand', () {
    test('paragraph becomes quote and back', () {
      final session = DocumentSession(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'q')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final executor = CommandExecutor(session);

      executor.execute(const ToggleQuoteCommand());
      expect(
        (session.document.blocks.single as TextBlockNode).type,
        BlockType.quote,
      );

      executor.execute(const ToggleQuoteCommand());
      expect(
        (session.document.blocks.single as TextBlockNode).type,
        BlockType.paragraph,
      );
    });
  });

  group('CalloutBlockNode / FileBlockNode', () {
    test('callout round-trips through JSON', () {
      const block = CalloutBlockNode(
        id: 'co1',
        variant: 'warning',
        content: <InlineNode>[TextRun(text: 'hey')],
      );
      final decoded = BlockNode.fromJson(
        Map<String, Object?>.from(block.toJson()),
      );
      expect(decoded, isA<CalloutBlockNode>());
      final callout = decoded as CalloutBlockNode;
      expect(callout.variant, 'warning');
      expect(callout.plainText, 'hey');
    });

    test('file block round-trips through JSON', () {
      const block = FileBlockNode(
        id: 'f1',
        assetId: 'a1',
        name: 'doc.pdf',
        size: 1024,
      );
      final decoded = BlockNode.fromJson(
        Map<String, Object?>.from(block.toJson()),
      );
      expect(decoded, isA<FileBlockNode>());
      final file = decoded as FileBlockNode;
      expect(file.name, 'doc.pdf');
      expect(file.size, 1024);
    });
  });
}
