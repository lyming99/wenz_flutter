import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('detects slash query and filters registry items', () {
    final editor = WenzRichTextController(
      document: _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.isOpen, isTrue);
    expect(slash.query, 'hea');
    expect(slash.items.map((item) => item.id), contains('heading'));
    expect(slash.items.every((item) => item.matches('hea')), isTrue);
  });

  test('moves highlighted item with wrapping', () {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.highlightedIndex, 0);
    slash.moveHighlight(-1);
    expect(slash.highlightedIndex, slash.items.length - 1);
    slash.moveHighlight(1);
    expect(slash.highlightedIndex, 0);
  });

  test('activating heading removes trigger and runs block command', () {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    expect(slash.activateHighlighted(), isTrue);

    final block = editor.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.plainText, isEmpty);
    expect(slash.isOpen, isFalse);
    expect(editor.canUndo, isTrue);
  });

  test('built-in table item replaces the trigger paragraph', () {
    final editor = WenzRichTextController(
      document: _document('/table'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    final tableIndex = slash.items.indexWhere((item) => item.id == 'table');
    slash.selectIndex(tableIndex);
    expect(slash.activateHighlighted(), isTrue);

    final block = editor.document.blocks.single;
    expect(block, isA<TableBlockNode>());
    expect((block as TableBlockNode).table.rowCount, 3);
    expect(block.table.columnCount, 3);
    expect(editor.selection?.extent.path.isTableCellText, isTrue);
  });

  test('custom registry item can execute existing commands', () {
    final editor = WenzRichTextController(
      document: _document('/alert'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    final registry = SlashMenuRegistry(<SlashMenuItem>[
      SlashMenuItem(
        id: 'alert',
        title: 'Alert',
        icon: 'format_quote',
        action: (editor, context) {
          editor.setBlockType(type: BlockType.quote);
        },
      ),
    ]);
    final slash = SlashMenuController(editor: editor, registry: registry);
    addTearDown(slash.dispose);

    expect(slash.items.single.id, 'alert');
    expect(slash.activateHighlighted(), isTrue);
    expect(
        (editor.document.blocks.single as TextBlockNode).type, BlockType.quote);
  });
}

RichTextDocument _document(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}
