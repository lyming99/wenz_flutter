import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

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
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required WenzRichTextController controller,
  required Widget topWidget,
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
