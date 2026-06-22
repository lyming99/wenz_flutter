import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'helpers/expect_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('focus management', () {
    testWidgets('controller.requestFocus() focuses the editor', (tester) async {
      // Two focusable nodes: an external TextField and the editor. Focus the
      // TextField first, then call controller.requestFocus() and assert the
      // editor (and thus its caret) takes focus.
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
        ),
      );
      final externalField = FocusNode();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      installTestClipboard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                TextField(focusNode: externalField),
                Expanded(
                  child: WenzRichTextEditor(
                    controller: controller,
                    enableIme: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Start with focus on the external field.
      externalField.requestFocus();
      await tester.pump();
      expect(externalField.hasFocus, isTrue);
      expect(isCaretVisible(tester), isFalse);

      // The editor requests focus through the controller.
      controller.requestFocus();
      await tester.pump();

      expect(externalField.hasFocus, isFalse,
          reason: 'external field must lose focus');
      expect(isCaretVisible(tester), isTrue,
          reason: 'editor caret must show after controller.requestFocus()');
    });

    testWidgets('autofocus places focus on the editor on mount', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'abc')],
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
          extent: DocumentPosition.text(blockId: 'p1', blockIndex: 0, offset: 3),
        ),
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      installTestClipboard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();
      // autofocus drives the Focus widget to request focus on mount; the caret
      // appears once focused + a collapsed selection is present.
      expect(isCaretVisible(tester), isTrue);
    });

    testWidgets('controller.requestFocus() is a no-op before the editor is '
        'mounted (no crash)', (tester) async {
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
      );
      // No widget attached — must not throw.
      controller.requestFocus();
      expect(tester.takeException(), isNull);
    });
  });
}
