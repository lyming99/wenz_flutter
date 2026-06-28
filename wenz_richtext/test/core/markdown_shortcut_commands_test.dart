import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('Markdown shortcuts', () {
    test('typing "# " converts an empty paragraph to a heading', () {
      final controller = _controller();

      controller.insertText('#');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.heading);
      expect(block.attributes.level, 1);
      expect(block.plainText, isEmpty);
      expect(controller.selection?.extent.offset, 0);

      controller.undo();
      final restored = controller.document.blocks.single as TextBlockNode;
      expect(restored.type, BlockType.paragraph);
      expect(restored.plainText, '# ');
    });

    test('typing "### " creates a level-3 heading', () {
      final controller = _controller();

      controller.insertText('#');
      controller.insertText('#');
      controller.insertText('#');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.heading);
      expect(block.attributes.level, 3);
      expect(block.plainText, isEmpty);
    });

    test('typing "- " creates an unordered list item', () {
      final controller = _controller();

      controller.insertText('-');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, isNull);
      expect(block.plainText, isEmpty);
    });

    test('typing "1. " creates an ordered list item', () {
      final controller = _controller();

      controller.insertText('1');
      controller.insertText('.');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');
      expect(block.plainText, isEmpty);
    });

    test('typing "1. [ ] " creates an ordered todo item', () {
      final controller = _controller();

      controller.insertText('1. [ ]', applyMarkdownShortcuts: false);
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');
      expect(block.attributes.checked, isFalse);
      expect(block.plainText, isEmpty);
    });

    test('typing "1. [x] " creates a checked ordered todo item', () {
      final controller = _controller();

      controller.insertText('1. [x]', applyMarkdownShortcuts: false);
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');
      expect(block.attributes.checked, isTrue);
      expect(block.plainText, isEmpty);
    });

    test('typing a task marker inside a bullet converts it to a task item', () {
      final controller = _controller();

      controller.insertText('-');
      controller.insertText(' ');
      controller.insertText('[');
      controller.insertText(' ');
      controller.insertText(']');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'task');
      expect(block.attributes.checked, isFalse);
      expect(block.plainText, isEmpty);
    });

    test('typing a checked task marker creates a checked task item', () {
      final controller = _controller();

      controller.insertText('-');
      controller.insertText(' ');
      controller.insertText('[');
      controller.insertText('x');
      controller.insertText(']');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.attributes.listType, 'task');
      expect(block.attributes.checked, isTrue);
      expect(block.plainText, isEmpty);
    });

    test('typing a task marker inside ordered list preserves numbering', () {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'ordered',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'ordered'),
              content: <InlineNode>[],
            ),
          ],
        ),
        selection: collapsedTextSelection('ordered', 0, 0),
      );

      controller.insertText('[');
      controller.insertText(' ');
      controller.insertText(']');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');
      expect(block.attributes.checked, isFalse);
      expect(block.plainText, isEmpty);
    });

    test('typing "> " creates a quote block', () {
      final controller = _controller();

      controller.insertText('>');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.quote);
      expect(block.plainText, isEmpty);
    });

    test('typing triple backticks creates a code block', () {
      final controller = _controller();

      controller.insertText('`');
      controller.insertText('`');
      controller.insertText('`');

      final block = controller.document.blocks.single as CodeBlockNode;
      expect(block.code, isEmpty);
      expect(controller.selection?.extent.path.isBlockCode, isTrue);
      expect(controller.selection?.extent.offset, 0);
    });

    test('typing "---" creates a divider followed by a paragraph', () {
      final controller = _controller();

      controller.insertText('-');
      controller.insertText('-');
      controller.insertText('-');

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0], isA<DividerBlockNode>());
      expect(controller.document.blocks[1], isA<TextBlockNode>());
      expect(controller.selection?.extent.blockIndex, 1);
      expect(controller.selection?.extent.offset, 0);
    });

    test('does not trigger away from the start of a block', () {
      final controller = _controller();

      controller.insertText('a');
      controller.insertText('#');
      controller.insertText(' ');

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.paragraph);
      expect(block.plainText, 'a# ');
    });

    test('can be disabled for programmatic inserts', () {
      final controller = _controller();

      controller.insertText('#');
      controller.insertText(' ', applyMarkdownShortcuts: false);

      final block = controller.document.blocks.single as TextBlockNode;
      expect(block.type, BlockType.paragraph);
      expect(block.plainText, '# ');
    });
  });
}

WenzRichTextController _controller() {
  return WenzRichTextController(
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
}
