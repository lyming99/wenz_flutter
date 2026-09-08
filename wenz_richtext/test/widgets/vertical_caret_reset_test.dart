import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  for (final key in [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
  ]) {
    testWidgets('vertical column resets after Ctrl+${key.keyLabel}',
        (tester) async {
      final controller = WenzRichTextController(
        document: RichTextDocument(blocks: [
          for (var i = 0; i < 4; i++)
            TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: const [TextRun(text: 'aaaa bbbb cccc dddd')],
            ),
        ]),
        selection: collapsedTextSelection('p0', 0, 7),
      );
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WenzRichTextEditor(
        controller: controller,
        autofocus: true,
        enableIme: false,
      ))));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.selection?.extent.offset, 7);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final moved = controller.selection!.extent;
      expect(moved.offset, isNot(7));
      final up = key == LogicalKeyboardKey.end;
      await tester.sendKeyEvent(
          up ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.selection?.extent.blockIndex,
          moved.blockIndex + (up ? -1 : 1));
      expect(controller.selection?.extent.offset, moved.offset);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
}
