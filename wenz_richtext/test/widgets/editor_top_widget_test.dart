import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('topWidget renders for an empty document and owns its gestures', (
    tester,
  ) async {
    final controller = WenzRichTextController();
    addTearDown(controller.dispose);
    var tapCount = 0;

    await _pumpEditor(
      tester,
      controller: controller,
      topWidget: SizedBox(
        height: 96,
        child: TextButton(
          key: const ValueKey<String>('top-action'),
          onPressed: () => tapCount += 1,
          child: const Text('Top content'),
        ),
      ),
    );

    expect(find.text('Top content'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('top-action')));
    await tester.pump();

    expect(tapCount, 1);
    expect(controller.selection, isNull);
  });

  testWidgets('topWidget and document blocks share one vertical scroll view', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: List<BlockNode>.generate(
          40,
          (index) => TextBlockNode(
            id: 'block-$index',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Paragraph $index')],
          ),
        ),
      ),
    );
    addTearDown(controller.dispose);

    await _pumpEditor(
      tester,
      controller: controller,
      topWidget: const SizedBox(
        key: ValueKey<String>('scrolling-top-widget'),
        height: 120,
        child: Text('Scrolling header'),
      ),
    );

    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    expect(scrollable, findsOneWidget);
    final initialTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('scrolling-top-widget')),
    );

    await tester.drag(scrollable, const Offset(0, -220));
    await tester.pump();

    final state = tester.state<ScrollableState>(scrollable);
    final scrolledTop = tester.getTopLeft(
      find.byKey(const ValueKey<String>('scrolling-top-widget')),
    );
    expect(state.position.pixels, greaterThan(0));
    expect(scrolledTop.dy, lessThan(initialTop.dy));
  });

  testWidgets(
    'topWidget TextField owns keyboard input until editor regains focus',
    (tester) async {
      final editorFocusNode = FocusNode(debugLabel: 'editor-body');
      final titleFocusNode = FocusNode(debugLabel: 'nested-title');
      final titleController = TextEditingController(text: 'Title');
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'body',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Body')],
            ),
          ],
        ),
        selection: collapsedTextSelection('body', 0, 4),
      );
      addTearDown(editorFocusNode.dispose);
      addTearDown(titleFocusNode.dispose);
      addTearDown(titleController.dispose);
      addTearDown(controller.dispose);

      await _pumpEditor(
        tester,
        controller: controller,
        focusNode: editorFocusNode,
        topWidget: TextField(
          key: const ValueKey<String>('nested-title-field'),
          controller: titleController,
          focusNode: titleFocusNode,
        ),
      );

      titleFocusNode.requestFocus();
      titleController.selection = TextSelection.collapsed(
        offset: titleController.text.length,
      );
      await tester.pump();

      expect(titleFocusNode.hasPrimaryFocus, isTrue);
      expect(editorFocusNode.hasPrimaryFocus, isFalse);

      for (var index = 0; index < 'Title'.length; index += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
      }

      expect(titleController.text, isEmpty);
      expect(titleFocusNode.hasPrimaryFocus, isTrue);
      expect(editorFocusNode.hasPrimaryFocus, isFalse);
      expect(controller.document.plainText, 'Body');
      expect(controller.selection, collapsedTextSelection('body', 0, 4));

      editorFocusNode.requestFocus();
      await tester.pump();

      expect(editorFocusNode.hasPrimaryFocus, isTrue);
      expect(titleFocusNode.hasPrimaryFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyX, character: 'x');
      await tester.pump();
      expect(controller.document.plainText, 'Bodyx');

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.document.plainText, 'Body');
      expect(controller.selection, collapsedTextSelection('body', 0, 4));
    },
  );
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required WenzRichTextController controller,
  required Widget topWidget,
  FocusNode? focusNode,
}) async {
  tester.view.physicalSize = const Size(320, 240);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WenzRichTextEditor(
          controller: controller,
          topWidget: topWidget,
          focusNode: focusNode,
          padding: EdgeInsets.zero,
          enableIme: false,
          enableExternalImageInput: false,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
