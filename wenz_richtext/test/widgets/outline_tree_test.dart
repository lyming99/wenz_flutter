import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets(
      'renders multi-level headings indented by level with a header count',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', blockIndex: 0, level: 1, title: 'Alpha'),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
      _item(blockId: 'h3', blockIndex: 2, level: 3, title: 'Gamma'),
    ];

    await tester.pumpWidget(_wrap(WenzOutlineTree(items: items)));

    expect(find.byKey(const ValueKey<String>('wenz-outline-tree')),
        findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('3 headings'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);

    // Deeper levels render further to the right (per-level indentation).
    expect(
      tester.getTopLeft(find.text('Beta')).dx,
      greaterThan(tester.getTopLeft(find.text('Alpha')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Gamma')).dx,
      greaterThan(tester.getTopLeft(find.text('Beta')).dx),
    );
  });

  testWidgets('tapping a row reports its outline item via onSelect',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', blockIndex: 0, level: 1, title: 'Alpha'),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
    ];
    OutlineItem? selected;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      onSelect: (item) => selected = item,
    )));

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.blockId, 'h2');
    expect(selected!.title, 'Beta');
    expect(selected!.level, 2);
  });

  testWidgets('the active block id renders highlighted while others stay plain',
      (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
    final items = <OutlineItem>[
      _item(blockId: 'h1', blockIndex: 0, level: 1, title: 'Alpha'),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
    ];

    await tester.pumpWidget(_wrap(
      WenzOutlineTree(items: items, activeBlockId: 'h2'),
      theme: theme,
    ));

    final activeBox = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('Beta'), matching: find.byType(DecoratedBox)),
    );
    final activeDecoration = activeBox.decoration as BoxDecoration;
    expect(
      activeDecoration.color,
      theme.colorScheme.primaryContainer.withAlpha(48),
    );
    final activeBorder = activeDecoration.border as BorderDirectional;
    expect(activeBorder.start.color, theme.colorScheme.primary);

    final inactiveBox = tester.widget<DecoratedBox>(
      find.ancestor(
          of: find.text('Alpha'), matching: find.byType(DecoratedBox)),
    );
    expect(
      (inactiveBox.decoration as BoxDecoration).color,
      Colors.transparent,
    );
  });

  testWidgets('shows the empty state when there are no headings',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const WenzOutlineTree(items: <OutlineItem>[])),
    );

    expect(find.text('No headings'), findsOneWidget);
    expect(find.text('0 headings'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('honours a custom emptyBuilder', (tester) async {
    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: const <OutlineItem>[],
      emptyBuilder: (_) => const Text('Nothing to outline'),
    )));

    expect(find.text('Nothing to outline'), findsOneWidget);
    expect(find.text('No headings'), findsNothing);
  });

  testWidgets('renders under light and dark themes without throwing',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', blockIndex: 0, level: 1, title: 'Alpha'),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
    ];

    for (final brightness in <Brightness>[
      Brightness.light,
      Brightness.dark,
    ]) {
      await tester.pumpWidget(_wrap(
        WenzOutlineTree(items: items, activeBlockId: 'h2'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: brightness,
          ),
          useMaterial3: true,
        ),
      ));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('exposes a collapse toggle for collapsible headings',
      (tester) async {
    final collapsible = _item(
      blockId: 'h1',
      blockIndex: 0,
      level: 1,
      title: 'Alpha',
      collapseRange: const OutlineCollapseRange(
        startBlockIndex: 1,
        endBlockIndexExclusive: 2,
        blockIds: <String>['c1'],
      ),
    );
    OutlineItem? toggled;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: <OutlineItem>[collapsible],
      onToggleCollapse: (item) => toggled = item,
    )));

    // Expanded headings show the open chevron.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(toggled, isNotNull);
    expect(toggled!.blockId, 'h1');
  });
}

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
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
