import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('overlay renders slash items and activates tapped item',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(controller: slash),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-item-heading')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-slash-item-heading')),
    );
    await tester.pump();

    expect((editor.document.blocks.single as TextBlockNode).type,
        BlockType.heading);
  });

  testWidgets('editor routes enter to the open slash menu', (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            slashMenuController: slash,
            focusNode: focusNode,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final block = editor.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.plainText, isEmpty);
    expect(slash.isOpen, isFalse);
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
