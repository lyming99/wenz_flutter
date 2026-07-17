import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('WenzOutlinePanel renders items from controller',
      (tester) async {
    final controller = _ControllerStub(items: <OutlineItem>[
      _item(blockId: 'h1', level: 1, title: 'Hello'),
      _item(blockId: 'h2', level: 2, title: 'World'),
    ]);

    await tester.pumpWidget(_wrap(
      WenzOutlinePanel(controller: controller),
    ));

    expect(find.text('大纲'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('2 headings'), findsNothing);
  });

  testWidgets('WenzOutlinePanel shows empty state when no headings',
      (tester) async {
    final controller = _ControllerStub(items: const <OutlineItem>[]);

    await tester.pumpWidget(_wrap(
      WenzOutlinePanel(controller: controller),
    ));

    expect(find.text('No headings'), findsOneWidget);
  });

  testWidgets('WenzOutlinePanel shows custom emptyBuilder',
      (tester) async {
    final controller = _ControllerStub(items: const <OutlineItem>[]);

    await tester.pumpWidget(_wrap(
      WenzOutlinePanel(
        controller: controller,
        emptyBuilder: (_) => const Text('Custom empty'),
      ),
    ));

    expect(find.text('Custom empty'), findsOneWidget);
    expect(find.text('No headings'), findsNothing);
  });

  testWidgets('WenzOutlinePanel honours width', (tester) async {
    final controller = _ControllerStub(items: <OutlineItem>[
      _item(blockId: 'h1', level: 1, title: 'Test'),
    ]);

    await tester.pumpWidget(_wrap(
      WenzOutlinePanel(controller: controller, width: 300),
    ));

    final sizedBox = tester.widget<SizedBox>(
      find.byKey(const ValueKey<String>('wenz-outline-tree')),
    );
    expect(sizedBox.width, 300);
  });

  testWidgets('WenzOutlinePanel row collapse is local tree state',
      (tester) async {
    final controller = _ControllerStub(items: <OutlineItem>[
      _item(
        blockId: 'h1',
        blockIndex: 0,
        level: 1,
        title: 'Parent',
        collapseRange: const OutlineCollapseRange(
          startBlockIndex: 1,
          endBlockIndexExclusive: 3,
        ),
      ),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Child'),
      _item(blockId: 'h1b', blockIndex: 3, level: 1, title: 'Peer'),
    ]);

    await tester.pumpWidget(_wrap(WenzOutlinePanel(controller: controller)));

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Child'), findsNothing);
    expect(find.text('Peer'), findsOneWidget);
    expect(controller.toggleCalls, 0);
    expect(controller.expandAllCalls, 0);
    expect(controller.collapsedBlockIds, isEmpty);
  });

  testWidgets('WenzOutlinePanel expand and collapse all stay local',
      (tester) async {
    final controller = _ControllerStub(items: <OutlineItem>[
      _item(
        blockId: 'h1',
        blockIndex: 0,
        level: 1,
        title: 'Parent',
        collapseRange: const OutlineCollapseRange(
          startBlockIndex: 1,
          endBlockIndexExclusive: 2,
        ),
      ),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Child'),
    ]);

    await tester.pumpWidget(_wrap(WenzOutlinePanel(controller: controller)));

    await tester.tap(find.byIcon(Icons.unfold_less));
    await tester.pump();

    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Child'), findsNothing);
    expect(controller.toggleCalls, 0);
    expect(controller.expandAllCalls, 0);

    await tester.tap(find.byIcon(Icons.unfold_more));
    await tester.pump();

    expect(find.text('Child'), findsOneWidget);
    expect(controller.toggleCalls, 0);
    expect(controller.expandAllCalls, 0);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

OutlineItem _item({
  String blockId = 'b1',
  int blockIndex = 0,
  int level = 1,
  String title = 'Heading',
  String? anchor,
  OutlineCollapseRange collapseRange = OutlineCollapseRange.empty,
  bool isCollapsed = false,
}) {
  return OutlineItem(
    blockId: blockId,
    blockIndex: blockIndex,
    level: level,
    title: title,
    anchor: anchor,
    collapseRange: collapseRange,
    isCollapsed: isCollapsed,
  );
}

class _ControllerStub extends WenzOutlineController {
  _ControllerStub({required List<OutlineItem> items})
      : _stubItems = items,
        super(editor: _NoopEditor());

  final List<OutlineItem> _stubItems;
  int toggleCalls = 0;
  int expandAllCalls = 0;

  @override
  List<OutlineItem> get items => _stubItems;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool get isEmpty => _stubItems.isEmpty;

  @override
  bool get isNotEmpty => _stubItems.isNotEmpty;

  @override
  bool toggle(OutlineItem item) {
    toggleCalls++;
    return false;
  }

  @override
  bool expandAll() {
    expandAllCalls++;
    return false;
  }
}

class _NoopEditor extends WenzRichTextController {
  _NoopEditor() : super(document: _emptyDoc());

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  DocumentSelection? get selection => null;
}

RichTextDocument _emptyDoc() => const RichTextDocument(blocks: <BlockNode>[]);
