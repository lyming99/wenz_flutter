import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext/src/widgets/lucide_toolbar_icons.dart';

import '../helpers/selection_test_helpers.dart';

const double _kGeometryTolerance = 1.0;

void main() {
  group('WenzDefaultMobileToolbar main bar', () {
    testWidgets('renders primary commands in bottom-bar order', (tester) async {
      await _pumpMobileToolbar(tester);

      for (final tooltip in const <String>[
        '打开插入面板',
        '加粗',
        '斜体',
        '下划线',
        '删除线',
        '任务列表',
        '有序列表',
        '无序列表',
        '撤销',
        '重做',
        '打开格式面板',
        '收起键盘',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      expect(_tooltipRect(tester, '打开插入面板').left,
          lessThan(_tooltipRect(tester, '加粗').left));
      expect(_tooltipRect(tester, '打开格式面板').right,
          lessThan(_tooltipRect(tester, '收起键盘').right));
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection state drives enabled and selected buttons', (
      tester,
    ) async {
      final harness = await _pumpMobileToolbar(
        tester,
        document: _boldTextDocument(),
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(_iconButton(tester, '加粗').isSelected, isTrue);
      expect(_iconButton(tester, '斜体').isSelected, isFalse);
      expect(_iconButton(tester, '加粗').onPressed, isNotNull);

      harness.toolbar.toggleMark(TextMark.bold);
      await tester.pump();
      expect(_iconButton(tester, '加粗').isSelected, isFalse);

      await _pumpMobileToolbar(
        tester,
        permission: WenzEditorPermission.read,
        selection: textSelection('p1', 0, 0, 5),
      );
      expect(_iconButton(tester, '加粗').onPressed, isNull);
      expect(_iconButton(tester, '打开插入面板').onPressed, isNotNull);
      expect(_iconButton(tester, '收起键盘').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('WenzDefaultMobileToolbar insert panel', () {
    testWidgets('opens, closes, and remains scrollable at narrow width', (
      tester,
    ) async {
      await _pumpMobileToolbar(tester, width: 320);

      await _tapTooltip(tester, '打开插入面板');
      expect(find.byTooltip('收起插入面板'), findsOneWidget);
      expect(find.byTooltip('打开格式面板'), findsOneWidget);
      expect(find.text('插入'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsWidgets);

      for (final tooltip in const <String>[
        '添加文本块',
        '引用',
        '分割线',
        '添加链接',
        '公式',
        '代码块',
        '标注',
        '表格',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      await _tapTooltip(tester, '收起插入面板');
      expect(find.byTooltip('打开插入面板'), findsOneWidget);
      expect(find.text('插入'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses viewInsets for keyboard avoidance without resizing panel',
        (
      tester,
    ) async {
      await _pumpMobileToolbar(tester, height: 700);
      final noInsetBottom = _tooltipRect(tester, '收起键盘').bottom;
      await _tapTooltip(tester, '打开插入面板');
      final noInsetPanelHeight =
          tester.getRect(find.byType(SingleChildScrollView)).height;

      await _pumpMobileToolbar(
        tester,
        height: 700,
        viewInsetsBottom: 180,
      );
      final insetBottom = _tooltipRect(tester, '收起键盘').bottom;
      await _tapTooltip(tester, '打开插入面板');
      final insetPanelHeight =
          tester.getRect(find.byType(SingleChildScrollView)).height;

      expect(insetBottom, closeTo(noInsetBottom - 180, _kGeometryTolerance));
      expect(
          insetPanelHeight, closeTo(noInsetPanelHeight, _kGeometryTolerance));

      await _tapTooltip(tester, '收起键盘');
      expect(find.byTooltip('收起插入面板'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('built-in insert commands mutate the shared controller', (
      tester,
    ) async {
      final harness = await _pumpMobileToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 5),
      );
      await _tapTooltip(tester, '打开插入面板');

      await _tapTooltip(tester, '公式');
      expect(_hasInlineEmbed(harness.controller, 'formula'), isTrue);

      await _tapTooltip(tester, '添加文本块');
      expect(harness.controller.document.blocks.whereType<TextBlockNode>(),
          hasLength(2));

      await _tapTooltip(tester, '分割线');
      expect(harness.controller.document.blocks.whereType<DividerBlockNode>(),
          hasLength(1));

      await _tapTooltip(tester, '代码块');
      expect(harness.controller.document.blocks.whereType<CodeBlockNode>(),
          hasLength(1));

      await _tapTooltip(tester, '表格');
      expect(harness.controller.document.blocks.whereType<TableBlockNode>(),
          hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('host resource actions receive assembled action context', (
      tester,
    ) async {
      final imageContexts = <WenzDefaultDesktopToolbarActionContext>[];
      final videoContexts = <WenzDefaultDesktopToolbarActionContext>[];
      final fileContexts = <WenzDefaultDesktopToolbarActionContext>[];
      final embedContexts = <WenzDefaultDesktopToolbarActionContext>[];
      final harness = await _pumpMobileToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        actions: WenzDefaultMobileToolbarActions(
          onInsertImage: imageContexts.add,
          onInsertVideo: videoContexts.add,
          onInsertFile: fileContexts.add,
          onInsertBlockEmbed: embedContexts.add,
        ),
      );

      await _tapTooltip(tester, '打开插入面板');
      for (final tooltip in const <String>[
        '插入图片',
        '插入视频',
        '插入文件',
        '业务嵌入',
      ]) {
        await _tapTooltip(tester, tooltip);
      }

      for (final context in <WenzDefaultDesktopToolbarActionContext>[
        imageContexts.single,
        videoContexts.single,
        fileContexts.single,
        embedContexts.single,
      ]) {
        expect(context.controller, same(harness.controller));
        expect(context.toolbar, same(harness.toolbar));
        expect(context.state.hasSelection, isTrue);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('plugin and host toolbar items stay merged in insert panel', (
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
        WenzToolbarItem(
          id: 'select-table-token',
          title: 'Select table token',
          tooltip: 'Select table token',
          priority: 4,
          icon: 'select-table',
          isActive: (_) => true,
          action: (_, __) {},
        ),
        WenzToolbarItem(
          id: 'delete-table-token',
          title: 'Delete table token',
          tooltip: 'Delete table token',
          priority: 5,
          icon: 'delete-table',
          isEnabled: (_) => false,
          action: (_, __) {},
        ),
      ]);

      await _pumpMobileToolbar(tester, toolbarItemRegistry: registry);
      await _tapTooltip(tester, '打开插入面板');

      _expectLucideIcon(
          tester, 'Known token', WenzLucideToolbarIcons.extension);
      _expectLucideIcon(tester, 'Alias token', WenzLucideToolbarIcons.workflow);
      _expectLucideIcon(
        tester,
        'Fallback token',
        WenzLucideToolbarIcons.fallback,
      );
      _expectLucideIcon(
        tester,
        'Select table token',
        WenzLucideToolbarIcons.tableSelect,
      );
      _expectLucideIcon(
        tester,
        'Delete table token',
        WenzLucideToolbarIcons.tableDelete,
      );
      expect(_iconButton(tester, 'Select table token').isSelected, isTrue);
      expect(_iconButton(tester, 'Delete table token').onPressed, isNull);
    });
  });

  group('WenzDefaultMobileToolbar format panel', () {
    testWidgets('covers block style, list, indent, and alignment commands', (
      tester,
    ) async {
      final harness = await _pumpMobileToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 5),
      );
      await _tapTooltip(tester, '打开格式面板');

      for (final label in const <String>[
        '块样式',
        '列表',
        '缩进',
        '对齐',
        '文字颜色',
        '背景/高亮',
        '段落',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in const <String>[
        '正文',
        'H1',
        'H2',
        'H3',
        'H4',
        'H5',
        'H6',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await _tapTextButton(tester, 'H2');
      expect(_textBlock(harness.controller).type, BlockType.heading);
      expect(_textBlock(harness.controller).attributes.level, 2);

      await _tapTextButton(tester, '正文');
      expect(_textBlock(harness.controller).type, BlockType.paragraph);

      await _tapTooltip(tester, '任务列表', last: true);
      expect(_textBlock(harness.controller).attributes.listType, 'task');

      await _tapTooltip(tester, '有序列表', last: true);
      expect(_textBlock(harness.controller).attributes.listType, 'ordered');

      await _tapTooltip(tester, '无序列表', last: true);
      expect(_textBlock(harness.controller).attributes.listType, isNull);
      expect(_textBlock(harness.controller).type, BlockType.listItem);

      await _tapTooltip(tester, '增加缩进');
      expect(_textBlock(harness.controller).attributes.indent, 1);

      await _tapTooltip(tester, '减少缩进');
      expect(_textBlock(harness.controller).attributes.indent, isNull);

      await _tapTooltip(tester, '居中');
      expect(_textBlock(harness.controller).attributes.alignment, 'center');

      await _tapTooltip(tester, '两端');
      expect(_textBlock(harness.controller).attributes.alignment, 'justify');

      await _tapTooltip(tester, '清除');
      expect(_textBlock(harness.controller).attributes.alignment, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'applies, customizes, mixes, and clears text color and background',
        (tester) async {
      final harness = await _pumpMobileToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );
      await _tapTooltip(tester, '打开格式面板');

      expect(find.byType(GridView), findsOneWidget);
      await _tapTooltip(tester, '蓝色 #FF1976D2');
      expect(_firstRun(harness.controller).attributes.color, 0xFF1976D2);
      expect(_iconButton(tester, '蓝色 #FF1976D2').isSelected, isTrue);
      expect(find.widgetWithText(TextButton, '自定义颜色'), findsOneWidget);

      await _tapTextButtonByTooltip(tester, '自定义文字颜色');
      await tester.pumpAndSettle();
      expect(find.byType(WenzRichTextColorPickerDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1976D2',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(_firstRun(harness.controller).attributes.color, 0xFF1976D2);
      expect(_iconButton(tester, '蓝色 #FF1976D2').isSelected, isTrue);

      await _tapTextButtonByTooltip(tester, '自定义文字颜色');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '#336699');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(_firstRun(harness.controller).attributes.color, 0xFF336699);
      expect(find.byTooltip('自定义文字颜色 #FF336699'), findsOneWidget);
      expect(
          find.widgetWithText(TextButton, '自定义颜色 #FF336699'), findsOneWidget);

      await _tapTextButtonByTooltip(tester, '清除文字颜色 #FF336699');
      expect(_firstRun(harness.controller).attributes.color, isNull);
      expect(find.byTooltip('无文字颜色'), findsOneWidget);

      await _tapTooltip(tester, '浅黄背景 #FFFFF59D');
      expect(_firstRun(harness.controller).attributes.background, 0xFFFFF59D);
      expect(_iconButton(tester, '浅黄背景 #FFFFF59D').isSelected, isTrue);

      await _tapTooltip(tester, '清除背景色 #FFFFF59D');
      expect(_firstRun(harness.controller).attributes.background, isNull);
      expect(find.byTooltip('无背景色'), findsOneWidget);

      await _pumpMobileToolbar(
        tester,
        width: 320,
        selection: textSelection('p1', 0, 0, 5),
      );
      await _tapTooltip(tester, '打开格式面板');
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);

      final mixedHarness = await _pumpMobileToolbar(
        tester,
        document: _mixedTextColorDocument(),
        selection: textSelection('p1', 0, 0, 10),
      );
      await _tapTooltip(tester, '打开格式面板');
      expect(find.byTooltip('清除混合文字颜色'), findsOneWidget);
      expect(find.byTooltip('自定义文字颜色（混合）'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '自定义颜色（混合）'), findsOneWidget);
      expect(_iconButton(tester, '蓝色 #FF1976D2').isSelected, isFalse);
      await _tapTextButtonByTooltip(tester, '清除混合文字颜色');
      expect(
        mixedHarness.controller.document.blocks
            .whereType<TextBlockNode>()
            .single
            .content
            .whereType<TextRun>()
            .every((run) => run.attributes.color == null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('read and comment permissions disable format commands', (
      tester,
    ) async {
      for (final permission in const <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        await _pumpMobileToolbar(
          tester,
          permission: permission,
          selection: textSelection('p1', 0, 0, 5),
        );
        await _tapTooltip(tester, '打开格式面板');

        expect(_iconButton(tester, '加粗').onPressed, isNull);
        expect(_iconButton(tester, '增加缩进').onPressed, isNull);
        expect(_iconButton(tester, '蓝色 #FF1976D2').onPressed, isNull);
        expect(_iconButton(tester, '浅黄背景 #FFFFF59D').onPressed, isNull);
        expect(_textButtonByTooltip(tester, '清除文字颜色不可用').onPressed, isNull);
        expect(_textButtonByTooltip(tester, '自定义文字颜色不可用').onPressed, isNull);
        expect(_iconButton(tester, '清除背景色不可用').onPressed, isNull);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

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
  WenzMobileToolbarStyle style =
      const WenzMobileToolbarStyle(animationDuration: Duration.zero),
  double width = 390,
  double height = 700,
  double viewInsetsBottom = 0,
  EdgeInsets padding = EdgeInsets.zero,
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
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          padding: padding,
          viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: Align(
              alignment: Alignment.bottomCenter,
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
      ),
    ),
  );
  await tester.pump();

  return _MobileToolbarHarness(host, toolbarController);
}

Future<void> _tapTooltip(
  WidgetTester tester,
  String tooltip, {
  bool last = false,
}) async {
  final finder = last ? find.byTooltip(tooltip).last : find.byTooltip(tooltip);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapTextButton(WidgetTester tester, String text) async {
  final finder = find.widgetWithText(TextButton, text);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapTextButtonByTooltip(
  WidgetTester tester,
  String tooltip,
) async {
  final finder = _textButtonByTooltipFinder(tooltip);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Rect _tooltipRect(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  return tester.getRect(tooltipFinder);
}

IconButton _iconButton(WidgetTester tester, String tooltip) {
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

Finder _textButtonByTooltipFinder(String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  return find.descendant(
    of: tooltipFinder,
    matching: find.byType(TextButton),
  );
}

TextButton _textButtonByTooltip(WidgetTester tester, String tooltip) {
  final finder = _textButtonByTooltipFinder(tooltip);
  expect(finder, findsOneWidget);
  return tester.widget<TextButton>(finder);
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

TextBlockNode _textBlock(WenzRichTextController controller) {
  return controller.document.blocks.whereType<TextBlockNode>().first;
}

TextRun _firstRun(WenzRichTextController controller) {
  return _textBlock(controller).content.whereType<TextRun>().first;
}

bool _hasInlineEmbed(WenzRichTextController controller, String embedType) {
  return controller.document.blocks.whereType<TextBlockNode>().any(
        (block) => block.content
            .whereType<InlineEmbed>()
            .any((embed) => embed.embedType == embedType),
      );
}

RichTextDocument _textDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Hello world')],
      ),
    ],
  );
}

RichTextDocument _boldTextDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello world',
            attributes: TextAttributes(bold: true),
          ),
        ],
      ),
    ],
  );
}

RichTextDocument _mixedTextColorDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello',
            attributes: TextAttributes(color: 0xFFD32F2F),
          ),
          TextRun(
            text: 'World',
            attributes: TextAttributes(color: 0xFF0F766E),
          ),
        ],
      ),
    ],
  );
}
