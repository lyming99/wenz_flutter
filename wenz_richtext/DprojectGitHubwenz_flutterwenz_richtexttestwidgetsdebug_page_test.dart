import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('debug page', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(id: 'p1', type: BlockType.paragraph, content: <InlineNode>[TextRun(text: 'aaa')]),
          TextBlockNode(id: 'p2', type: BlockType.paragraph, content: <InlineNode>[TextRun(text: 'bbb')]),
          TextBlockNode(id: 'p3', type: BlockType.paragraph, content: <InlineNode>[TextRun(text: 'ccc')]),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(controller: controller, autofocus: true, enableIme: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inspect registry entries via the editor's box
    final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
    debugPrint('EDITOR BOX: $editorBox');
    debugPrint('BEFORE sel: ${controller.selection!.extent.blockId} @ ${controller.selection!.extent.offset}');

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    await tester.pumpAndSettle();

    debugPrint('AFTER sel: ${controller.selection!.extent.blockId} @ ${controller.selection!.extent.offset}');
  });
}
