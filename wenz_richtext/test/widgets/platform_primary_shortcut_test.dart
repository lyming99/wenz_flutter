import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('macOS uses Command, not Control, for primary editor shortcuts',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello')],
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.text(
          blockId: 'p1',
          blockIndex: 0,
          offset: 0,
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.selection?.isCollapsed, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.base.offset, 0);
    expect(controller.selection?.extent.offset, greaterThanOrEqualTo(5));
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}
