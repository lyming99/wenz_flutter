import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext/src/widgets/lucide_toolbar_icons.dart';

import '../helpers/selection_test_helpers.dart';

const double _kGeometryTolerance = 0.1;

/// Mobile token values mirrored from the implementation so tests are coupled to
/// layout behaviour rather than exact literals.
const double _kMobileButtonSize = 40.0;
const double _kMobileToolbarVerticalPadding = 6.0;

void main() {
  group('WenzDefaultMobileToolbar rendering', () {
    testWidgets('renders primary rail with toolbar buttons and toggle', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester);

      for (final tooltip in const <String>[
        '加粗',
        '斜体',
        '下划线',
        '删除线',
        '任务列表',
        '有序列表',
        '无序列表',
        '撤销',
        '重做',
        '更多',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      // The expanded panel is collapsed by default.
      expect(find.byTooltip('收起'), findsNothing);
      expect(find.text('块样式'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('primary rail height is button size plus vertical padding', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester);

      // The primary rail constrains a ListView to a SizedBox whose height is
      // the button extent + 2 × vertical padding.
      final listViewRect = tester.getRect(find.byType(ListView));
      expect(
        listViewRect.height,
        closeTo(_kMobileButtonSize + _kMobileToolbarVerticalPadding * 2,
            _kGeometryTolerance),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('primary rail buttons are vertically centered', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester);

      final listViewRect = tester.getRect(find.byType(ListView));

      for (final tooltip in const <String>[
        '加粗',
        '斜体',
        '下划线',
        '删除线',
        '任务列表',
        '有序列表',
        '无序列表',
        '撤销',
        '重做',
      ]) {
        final buttonRect = _tooltipRect(tester, tooltip);
        // Each IconButton is fixed-size and centered in the ListView cross
        // axis (vertical). The button's vertical center and the ListView's
        // vertical center must coincide.
        expect(
          buttonRect.center.dy,
          closeTo(listViewRect.center.dy, _kGeometryTolerance),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded panel reveals sections when toggle is tapped', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester);

      expect(find.byTooltip('更多'), findsOneWidget);
      expect(find.byTooltip('收起'), findsNothing);

      // Expand the panel.
      await tester.tap(find.byTooltip('更多'));
      await tester.pump();

      expect(find.byTooltip('收起'), findsOneWidget);
      expect(find.byTooltip('更多'), findsNothing);

      // Section labels must be visible.
      for (final label in const <String>[
        '块样式',
        '对齐',
        '颜色',
        '段落',
        '插入',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // The panel should contain at least one Wrap for the section contents.
      expect(find.byType(Wrap), findsWidgets);

      // The panel uses a SingleChildScrollView for vertical overflow.
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('panel content wraps without overflow at narrow width', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester, width: 320);

      await tester.tap(find.byTooltip('更多'));
      await tester.pump();

      // At 320 dp the block-style chips (7 items at ~48 dp each) exceed one
      // row; the Wrap should flow to a second row without causing a framework
      // overflow exception.
      expect(find.byType(Wrap), findsWidgets);

      // Every section label must still be reachable.
      for (final label in const <String>[
        '块样式',
        '对齐',
        '颜色',
        '段落',
        '插入',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('primary rail scrolls and panel maps registry icons', (
      tester,
    ) async {
      final registry = WenzToolbarItemRegistry(<WenzToolbarItem>[
        WenzToolbarItem(
          id: 'known-token',
          title: 'Known token',
          tooltip: 'Known token',
          priority: 1,
          icon: 'extension',
          action: (_, __) {},
        ),
        WenzToolbarItem(
          id: 'alias-token',
          title: 'Alias token',
          tooltip: 'Alias token',
          priority: 2,
          icon: 'account_tree',
          action: (_, __) {},
        ),
        WenzToolbarItem(
          id: 'fallback-token',
          title: 'Fallback token',
          tooltip: 'Fallback token',
          priority: 3,
          icon: 'unknown-token',
          action: (_, __) {},
        ),
        for (var i = 0; i < 12; i++)
          WenzToolbarItem(
            id: 'scroll-item-$i',
            title: 'Item $i',
            tooltip: 'Item $i',
            priority: 100 + i,
            icon: 'extension',
            action: (_, __) {},
          ),
      ]);

      await _pumpMobileToolbar(
        tester,
        toolbarItemRegistry: registry,
        width: 320,
      );

      // The primary rail wraps a horizontal ListView, which remains
      // scrollable at narrow width.
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byTooltip('更多'));
      await tester.pump();

      _expectLucideIcon(
        tester,
        'Known token',
        WenzLucideToolbarIcons.extension,
      );
      _expectLucideIcon(
        tester,
        'Alias token',
        WenzLucideToolbarIcons.workflow,
      );
      _expectLucideIcon(
        tester,
        'Fallback token',
        WenzLucideToolbarIcons.fallback,
      );

      // The last injected item should exist in the expanded panel even when
      // the viewport is narrower than the full extension strip.
      expect(find.byTooltip('Item 11'), findsOneWidget);

      // No framework overflow — the horizontal ListView absorbs the width.
      expect(tester.takeException(), isNull);
    });
  });

  group('WenzDefaultMobileToolbar shared state', () {
    testWidgets('selected and disabled states mirror ToolbarState', (
      tester,
    ) async {
      final harness = await _pumpMobileToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      // Toggle bold via the toolbar controller and verify the button reflects
      // the new state.

      // The button should be enabled when the controller allows toggling.
      expect(_mobileIconButton(tester, '加粗').onPressed, isNotNull);

      // Toggle bold on.
      harness.toolbar.toggleMark(TextMark.bold);
      await tester.pump();
      expect(_mobileIconButton(tester, '加粗').isSelected, isTrue);

      // Toggle bold off.
      harness.toolbar.toggleMark(TextMark.bold);
      await tester.pump();
      expect(_mobileIconButton(tester, '加粗').isSelected, isFalse);

      // In read-only mode all formatting buttons are disabled.
      await _pumpMobileToolbar(
        tester,
        permission: WenzEditorPermission.read,
        selection: textSelection('p1', 0, 0, 5),
      );
      expect(_mobileIconButton(tester, '加粗').onPressed, isNull);
      expect(_mobileIconButton(tester, '斜体').onPressed, isNull);
      expect(_mobileIconButton(tester, '删除线').onPressed, isNull);

      expect(tester.takeException(), isNull);
    });

    testWidgets('expand toggle enabled in all permission modes', (
      tester,
    ) async {
      for (final permission in WenzEditorPermission.values) {
        await _pumpMobileToolbar(
          tester,
          permission: permission,
        );
        expect(
          _mobileIconButton(tester, '更多').onPressed,
          isNotNull,
          reason: 'expand toggle must stay enabled under $permission',
        );
      }
    });
  });
}

// ---- Helpers -----------------------------------------------------------------

class _MobileToolbarHarness {
  const _MobileToolbarHarness(this.controller, this.toolbar);

  final WenzRichTextController controller;
  final ToolbarController toolbar;
}

Future<_MobileToolbarHarness> _pumpMobileToolbar(
  WidgetTester tester, {
  WenzRichTextController? controller,
  ToolbarController? toolbar,
  RichTextDocument? document,
  DocumentSelection? selection,
  WenzEditorPermission permission = WenzEditorPermission.edit,
  WenzToolbarItemRegistry? toolbarItemRegistry,
  Iterable<WenzToolbarItem> toolbarItems = const <WenzToolbarItem>[],
  WenzDefaultMobileToolbarActions actions =
      const WenzDefaultMobileToolbarActions(),
  WenzMobileToolbarStyle style = const WenzMobileToolbarStyle(),
  double width = 360,
}) async {
  final host = controller ??
      WenzRichTextController(
        document: document ?? _textDocument(),
        selection: selection ?? collapsedTextSelection('p1', 0, 0),
        permission: permission,
      );
  final toolbarController = toolbar ?? ToolbarController(host);
  if (toolbar == null) {
    addTearDown(toolbarController.dispose);
  }
  if (controller == null) {
    addTearDown(host.dispose);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: WenzDefaultMobileToolbar(
              controller: host,
              toolbar: toolbarController,
              toolbarItemRegistry: toolbarItemRegistry,
              toolbarItems: toolbarItems,
              actions: actions,
              style: style,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return _MobileToolbarHarness(host, toolbarController);
}

Rect _tooltipRect(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  return tester.getRect(tooltipFinder);
}

IconButton _mobileIconButton(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  final matchedWidget = tooltipFinder.evaluate().single.widget;
  if (matchedWidget is IconButton) {
    return matchedWidget;
  }
  final iconButtonFinder = find.ancestor(
    of: tooltipFinder,
    matching: find.byType(IconButton),
  );
  expect(iconButtonFinder, findsOneWidget);
  return tester.widget<IconButton>(iconButtonFinder);
}

void _expectLucideIcon(
  WidgetTester tester,
  String tooltip,
  String icon,
) {
  expect(
    find.descendant(
      of: find.byTooltip(tooltip),
      matching: find.byWidgetPredicate(
        (widget) => widget is WenzLucideToolbarIcon && widget.icon == icon,
      ),
    ),
    findsOneWidget,
  );
}

RichTextDocument _textDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'Hello world'),
        ],
      ),
    ],
  );
}
