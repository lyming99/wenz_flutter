import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets(
      'renders multi-level headings indented by level without a header count',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', blockIndex: 0, level: 1, title: 'Alpha'),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
      _item(blockId: 'h3', blockIndex: 2, level: 3, title: 'Gamma'),
    ];

    await tester.pumpWidget(_wrap(WenzOutlineTree(items: items)));

    expect(find.byKey(const ValueKey<String>('wenz-outline-tree')),
        findsOneWidget);
    expect(find.text('大纲'), findsOneWidget);
    expect(find.text('3 headings'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);

    final alphaPadding = _rowContentPaddingForTitle(tester, 'Alpha');
    final betaPadding = _rowContentPaddingForTitle(tester, 'Beta');
    final gammaPadding = _rowContentPaddingForTitle(tester, 'Gamma');
    expect(alphaPadding.start, 8);
    expect(alphaPadding.end, 8);
    expect(betaPadding.end, 8);
    expect(gammaPadding.end, 8);
    expect(betaPadding.start, greaterThan(alphaPadding.start));
    expect(gammaPadding.start, greaterThan(betaPadding.start));

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
    expect(find.text('大纲'), findsOneWidget);
    expect(find.text('0 headings'), findsNothing);
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
    final child = _item(
      blockId: 'h2',
      blockIndex: 1,
      level: 2,
      title: 'Beta',
    );
    OutlineItem? toggled;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: <OutlineItem>[collapsible, child],
      onToggleCollapse: (item) => toggled = item,
    )));

    // Expanded headings show the open chevron.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(toggled, isNotNull);
    expect(toggled!.blockId, 'h1');
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('leaf headings reserve toggle space so equal levels stay aligned',
      (tester) async {
    final parent = _item(
      blockId: 'parent',
      blockIndex: 0,
      level: 1,
      title: 'Parent',
      collapseRange: const OutlineCollapseRange(
        startBlockIndex: 1,
        endBlockIndexExclusive: 2,
      ),
    );
    final child = _item(
      blockId: 'child',
      blockIndex: 1,
      level: 2,
      title: 'Child',
    );
    final leaf = _item(
      blockId: 'leaf',
      blockIndex: 2,
      level: 1,
      title: 'Leaf',
      collapseRange: const OutlineCollapseRange(
        startBlockIndex: 3,
        endBlockIndexExclusive: 4,
        blockIds: <String>['body'],
      ),
    );
    OutlineItem? selected;
    OutlineItem? toggled;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: <OutlineItem>[parent, child, leaf],
      onSelect: (item) => selected = item,
      onToggleCollapse: (item) => toggled = item,
    )));

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    final leafPadding = _rowContentPaddingForTitle(tester, 'Leaf');
    expect(leafPadding.start, 8);
    expect(leafPadding.end, 8);
    expect(
      tester.getTopLeft(find.text('Leaf')).dx,
      tester.getTopLeft(find.text('Parent')).dx,
    );
    expect(
      tester.getTopLeft(find.text('Child')).dx,
      greaterThan(tester.getTopLeft(find.text('Parent')).dx),
    );

    await tester.tap(find.text('Leaf'));
    await tester.pump();
    expect(selected?.blockId, 'leaf');
    expect(toggled, isNull);
  });

  testWidgets('tree collapse hides only descendant outline rows',
      (tester) async {
    final items = <OutlineItem>[
      _item(
        blockId: 'h1',
        blockIndex: 0,
        level: 1,
        title: 'Alpha',
        collapseRange: const OutlineCollapseRange(
          startBlockIndex: 1,
          endBlockIndexExclusive: 4,
        ),
      ),
      _item(blockId: 'h2', blockIndex: 1, level: 2, title: 'Beta'),
      _item(blockId: 'h3', blockIndex: 2, level: 3, title: 'Gamma'),
      _item(blockId: 'h1b', blockIndex: 4, level: 1, title: 'Next'),
    ];
    OutlineItem? selected;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      onSelect: (item) => selected = item,
    )));

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Gamma'), findsNothing);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(selected?.blockId, 'h1');

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
  });

  // --- P003: heading level badge ---

  testWidgets('renders H1–H6 level badges on each heading row', (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', level: 1, title: 'One'),
      _item(blockId: 'h2', level: 2, title: 'Two'),
      _item(blockId: 'h6', level: 6, title: 'Six'),
    ];

    await tester.pumpWidget(_wrap(WenzOutlineTree(items: items)));

    expect(find.text('H1'), findsOneWidget);
    expect(find.text('H2'), findsOneWidget);
    expect(find.text('H6'), findsOneWidget);
    expect(find.text('H3'), findsNothing);
  });

  // --- P004: expand / collapse all ---

  testWidgets(
      'shows expand/collapse all buttons when there are collapsible items',
      (tester) async {
    final collapsible = _item(
      blockId: 'h1',
      blockIndex: 0,
      level: 1,
      title: 'Alpha',
      collapseRange: const OutlineCollapseRange(
        startBlockIndex: 1,
        endBlockIndexExclusive: 2,
      ),
    );
    final child = _item(
      blockId: 'h2',
      blockIndex: 1,
      level: 2,
      title: 'Beta',
    );
    final items = <OutlineItem>[collapsible, child];

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      onExpandAll: () {},
      onCollapseAll: () {},
    )));

    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    expect(find.byIcon(Icons.unfold_less), findsOneWidget);
  });

  testWidgets('hides expand/collapse all buttons when no collapsible items',
      (tester) async {
    final items = <OutlineItem>[
      _item(
        blockId: 'h1',
        level: 1,
        title: 'Alpha',
        collapseRange: const OutlineCollapseRange(
          startBlockIndex: 1,
          endBlockIndexExclusive: 2,
          blockIds: <String>['body'],
        ),
      ),
    ];

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      onExpandAll: () {},
      onCollapseAll: () {},
    )));

    expect(find.byIcon(Icons.unfold_more), findsNothing);
    expect(find.byIcon(Icons.unfold_less), findsNothing);
  });

  testWidgets('fires onCollapseAll and onExpandAll when buttons are tapped',
      (tester) async {
    final collapsible = _item(
      blockId: 'h1',
      blockIndex: 0,
      level: 1,
      title: 'Alpha',
      collapseRange: const OutlineCollapseRange(
        startBlockIndex: 1,
        endBlockIndexExclusive: 2,
      ),
    );
    final child = _item(
      blockId: 'h2',
      blockIndex: 1,
      level: 2,
      title: 'Beta',
    );
    var expandFired = false;
    var collapseFired = false;

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: <OutlineItem>[collapsible, child],
      onExpandAll: () => expandFired = true,
      onCollapseAll: () => collapseFired = true,
    )));

    await tester.tap(find.byIcon(Icons.unfold_less));
    await tester.pump();
    expect(collapseFired, isTrue);
    expect(find.text('Beta'), findsNothing);

    await tester.tap(find.byIcon(Icons.unfold_more));
    await tester.pump();
    expect(expandFired, isTrue);
    expect(find.text('Beta'), findsOneWidget);
  });

  // --- P005: keyboard navigation ---

  testWidgets(
      'moves focused index on ArrowUp/ArrowDown when keyboard navigation enabled',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', level: 1, title: 'First'),
      _item(blockId: 'h2', level: 2, title: 'Second'),
      _item(blockId: 'h3', level: 3, title: 'Third'),
    ];

    OutlineItem? selected;
    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      enableKeyboardNavigation: true,
      onSelect: (item) => selected = item,
    )));

    // Initial focus on index 0; send ArrowDown twice to reach index 2,
    // then Enter to select "Third".
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.title, 'Third');
  });

  testWidgets('keyboard navigation respects item boundaries (clamp)',
      (tester) async {
    final items = <OutlineItem>[
      _item(blockId: 'h1', level: 1, title: 'Alpha'),
    ];

    await tester.pumpWidget(_wrap(WenzOutlineTree(
      items: items,
      enableKeyboardNavigation: true,
    )));

    // Clamp to first item.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    // Should not crash — single item, ArrowUp clamped.
    expect(find.text('Alpha'), findsOneWidget);
  });
}

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

EdgeInsetsDirectional _rowContentPaddingForTitle(
  WidgetTester tester,
  String title,
) {
  final rowPaddingFinder = find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate(
      (widget) => widget is Padding && widget.padding is EdgeInsetsDirectional,
    ),
  );
  final padding = tester.widgetList<Padding>(rowPaddingFinder).single;
  return padding.padding as EdgeInsetsDirectional;
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
