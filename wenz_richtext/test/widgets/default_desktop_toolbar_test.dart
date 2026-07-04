import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  group('WenzDefaultDesktopToolbar rendering', () {
    testWidgets('renders core tooltips and derives enabled state', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      for (final tooltip in const <String>[
        '撤销',
        '重做',
        '加粗',
        '斜体',
        '下划线',
        '删除线',
        '批注',
        '文字颜色',
        '无文字颜色',
        '清除样式',
        '添加链接',
        '公式',
        '表情',
        '一级标题',
        '二级标题',
        '三级标题',
        '段落',
        '引用',
        '任务列表',
        '有序列表',
        '无序列表',
        '左对齐',
        '居中对齐',
        '右对齐',
        '两端对齐',
        '清除对齐',
        '增加缩进',
        '减少缩进',
        '插入代码块',
        '插入标注',
        '插入表格',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      expect(_iconButton(tester, '撤销').onPressed, isNull);
      expect(_iconButton(tester, '重做').onPressed, isNull);
      expect(_iconButton(tester, '加粗').onPressed, isNotNull);

      harness.controller.permission = WenzEditorPermission.read;
      await tester.pump();

      expect(_iconButton(tester, '加粗').onPressed, isNull);
      expect(_iconButton(tester, '添加链接').onPressed, isNull);
      expect(_iconButton(tester, '一级标题').onPressed, isNull);
      expect(_iconButton(tester, '插入代码块').onPressed, isNull);
    });

    testWidgets('wraps inside a narrow width without framework overflow', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        width: 176,
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resource actions hide, disable, pending, and invoke context', (
      tester,
    ) async {
      await _pumpToolbar(tester);
      expect(find.byTooltip('插入图片'), findsNothing);
      expect(find.byTooltip('插入视频'), findsNothing);
      expect(find.byTooltip('插入文件'), findsNothing);
      expect(find.byTooltip('插入业务嵌入'), findsNothing);

      final disabledHarness = await _pumpToolbar(
        tester,
        actions: const WenzDefaultDesktopToolbarActions(
          imageUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          videoUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          fileUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          blockEmbedUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
        ),
      );
      expect(find.byTooltip('插入图片不可用'), findsOneWidget);
      expect(find.byTooltip('插入视频不可用'), findsOneWidget);
      expect(find.byTooltip('插入文件不可用'), findsOneWidget);
      expect(find.byTooltip('插入业务嵌入不可用'), findsOneWidget);
      expect(_iconButton(tester, '插入图片不可用').onPressed, isNull);
      expect(_iconButton(tester, '插入视频不可用').onPressed, isNull);
      expect(_iconButton(tester, '插入文件不可用').onPressed, isNull);
      expect(_iconButton(tester, '插入业务嵌入不可用').onPressed, isNull);

      final contexts = <WenzDefaultDesktopToolbarActionContext>[];
      await _pumpToolbar(
        tester,
        controller: disabledHarness.controller,
        toolbar: disabledHarness.toolbar,
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: contexts.add,
          onInsertVideo: contexts.add,
          onInsertFile: contexts.add,
          onInsertBlockEmbed: contexts.add,
        ),
      );

      for (final tooltip in const <String>[
        '插入图片',
        '插入视频',
        '插入文件',
        '插入业务嵌入',
      ]) {
        await _tapToolbarButton(tester, tooltip);
      }
      expect(contexts, hasLength(4));
      expect(contexts.first.controller, same(disabledHarness.controller));
      expect(contexts.first.toolbar, same(disabledHarness.toolbar));
      expect(contexts.first.state.hasSelection, isTrue);
      expect(contexts[1].controller, same(disabledHarness.controller));
      expect(contexts[1].toolbar, same(disabledHarness.toolbar));
      expect(contexts[1].state.hasSelection, isTrue);

      await _pumpToolbar(
        tester,
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: contexts.add,
          isPickingImage: true,
        ),
      );
      expect(find.byTooltip('正在选择图片'), findsOneWidget);
      expect(_iconButton(tester, '正在选择图片').onPressed, isNull);

      for (final permission in <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        var mediaCalls = 0;
        await _pumpToolbar(
          tester,
          permission: permission,
          actions: WenzDefaultDesktopToolbarActions(
            onInsertImage: (_) => mediaCalls++,
            onInsertVideo: (_) => mediaCalls++,
          ),
        );
        expect(_iconButton(tester, '插入图片').onPressed, isNull);
        expect(_iconButton(tester, '插入视频').onPressed, isNull);
        await tester.tap(find.byTooltip('插入图片'), warnIfMissed: false);
        await tester.tap(find.byTooltip('插入视频'), warnIfMissed: false);
        await tester.pump();
        expect(mediaCalls, 0);
      }
    });
  });

  group('WenzDefaultDesktopToolbar commands', () {
    testWidgets('toggles marks and undo/redo through toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isFalse);

      await _tapToolbarButton(tester, '加粗');
      expect(_iconButton(tester, '加粗').isSelected, isTrue);
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isTrue);
      expect(_iconButton(tester, '撤销').onPressed, isNotNull);

      await _tapToolbarButton(tester, '斜体');
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isTrue,
      );

      await _tapToolbarButton(tester, '清除样式');
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isFalse);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isFalse,
      );

      await _tapToolbarButton(tester, '撤销');
      expect(_iconButton(tester, '重做').onPressed, isNotNull);
      await _tapToolbarButton(tester, '重做');
      expect(_iconButton(tester, '撤销').onPressed, isNotNull);
    });

    testWidgets('sets block type, list, alignment, and indentation', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _tapToolbarButton(tester, '一级标题');
      var block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.heading);
      expect(block.attributes.level, 1);
      expect(_iconButton(tester, '一级标题').isSelected, isTrue);

      await _tapToolbarButton(tester, '段落');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.paragraph);

      await _tapToolbarButton(tester, '有序列表');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');

      await _tapToolbarButton(tester, '无序列表');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, isNull);

      await _tapToolbarButton(tester, '居中对齐');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.alignment, 'center');
      expect(_iconButton(tester, '居中对齐').isSelected, isTrue);

      await _tapToolbarButton(tester, '增加缩进');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.indent, 1);

      await _tapToolbarButton(tester, '减少缩进');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.indent, 0);
    });

    testWidgets('uses localized dynamic color and mixed alignment tooltips', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(find.byTooltip('文字颜色'), findsOneWidget);
      expect(find.byTooltip('无文字颜色'), findsOneWidget);

      harness.toolbar.setTextColorValue(0xFFFF0000);
      await tester.pump();
      expect(find.byTooltip('文字颜色 #FFFF0000'), findsOneWidget);
      expect(find.byTooltip('清除文字颜色 #FFFF0000'), findsOneWidget);

      harness.toolbar.clearTextColor();
      await tester.pump();
      expect(find.byTooltip('文字颜色'), findsOneWidget);
      expect(find.byTooltip('无文字颜色'), findsOneWidget);

      await _pumpToolbar(
        tester,
        document: _mixedTextColorDocument(),
        selection: textSelection('p1', 0, 0, 10),
      );
      expect(find.byTooltip('文字颜色（混合）'), findsOneWidget);
      expect(find.byTooltip('清除混合文字颜色'), findsOneWidget);

      await _pumpToolbar(
        tester,
        document: _mixedAlignmentDocument(),
        selection: _mixedAlignmentSelection(),
      );
      expect(find.byTooltip('左对齐（混合对齐）'), findsOneWidget);
      expect(find.byTooltip('清除对齐（混合对齐）'), findsOneWidget);
    });

    testWidgets('inserts default structure blocks from toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _tapToolbarButton(tester, '插入代码块');
      expect(harness.controller.document.blocks.first, isA<CodeBlockNode>());

      await _tapToolbarButton(tester, '插入标注');
      expect(
        harness.controller.document.blocks.whereType<CalloutBlockNode>(),
        isNotEmpty,
      );

      await _tapToolbarButton(tester, '插入表格');
      expect(
        harness.controller.document.blocks.whereType<TableBlockNode>(),
        isNotEmpty,
      );
    });

    testWidgets('media buttons do not affect core toolbar commands', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: (_) {},
          onInsertVideo: (_) {},
        ),
      );

      await _tapToolbarButton(tester, '加粗');
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isTrue);

      await _tapToolbarButton(tester, '插入表格');
      expect(
        harness.controller.document.blocks.whereType<TableBlockNode>(),
        isNotEmpty,
      );
    });
  });

  group('WenzDefaultDesktopToolbar link dialog', () {
    testWidgets('applies a new link', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapToolbarButton(tester, '添加链接');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://wenz.dev');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(
          harness.controller,
          (run) => run.text == 'Hello' && run.attributes.url == 'https://wenz.dev',
        ),
        isTrue,
      );
      expect(_iconButton(tester, '编辑链接').isSelected, isTrue);
    });

    testWidgets('cancel leaves the document unchanged', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapToolbarButton(tester, '添加链接');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://ignored.test');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      expect(find.byTooltip('添加链接'), findsOneWidget);
    });

    testWidgets('removes an existing link', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        document: _textDocument(link: 'https://wenz.dev'),
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(_iconButton(tester, '编辑链接').isSelected, isTrue);

      await _tapToolbarButton(tester, '编辑链接');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      expect(find.byTooltip('添加链接'), findsOneWidget);
    });
  });

  group('WenzDefaultDesktopToolbar table context', () {
    testWidgets('shows table buttons only for table cell selections', (
      tester,
    ) async {
      await _pumpToolbar(tester);
      expect(find.byTooltip('下方插入行'), findsNothing);

      final harness = await _pumpToolbar(
        tester,
        document: _tableDocument(),
        selection: _tableSelection(0, 0, 0, 0),
      );

      for (final tooltip in const <String>[
        '下方插入行',
        '右侧插入列',
        '删除行',
        '删除列',
        '合并单元格',
        '拆分单元格',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
        expect(_iconButton(tester, tooltip).onPressed, isNotNull);
      }

      await _tapToolbarButton(tester, '下方插入行');
      expect(_table(harness.controller).table.rowCount, 3);

      await _tapToolbarButton(tester, '右侧插入列');
      expect(_table(harness.controller).table.columnCount, 3);
    });

    testWidgets('merge and split table cells through toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        document: _tableDocument(),
        selection: _tableSelection(0, 0, 0, 1),
      );

      await _tapToolbarButton(tester, '合并单元格');
      var table = _table(harness.controller).table;
      expect(table.cellAt(0, 0)?.columnSpan, 2);
      expect(table.cellAt(0, 1)?.covered, isTrue);

      await _tapToolbarButton(tester, '拆分单元格');
      table = _table(harness.controller).table;
      expect(table.cellAt(0, 0)?.columnSpan, 1);
      expect(table.cellAt(0, 1)?.covered, isFalse);
    });
  });

  group('WenzDefaultDesktopToolbar registry items', () {
    testWidgets('sorts, renders, overrides, activates, disables, and acts', (
      tester,
    ) async {
      final calls = <String>[];
      final registry = WenzToolbarItemRegistry(<WenzToolbarItem>[
        WenzToolbarItem(
          id: 'later',
          title: 'Later item',
          tooltip: 'Later item',
          priority: 20,
          icon: 'extension',
          action: (_, __) => calls.add('later'),
        ),
        WenzToolbarItem(
          id: 'active',
          title: 'Active item',
          tooltip: 'Active item',
          priority: 5,
          icon: 'account_tree',
          isActive: (_) => true,
          action: (_, __) => calls.add('active'),
        ),
        WenzToolbarItem(
          id: 'disabled',
          title: 'Disabled item',
          tooltip: 'Disabled item',
          priority: 6,
          isEnabled: (_) => false,
          action: (_, __) => calls.add('disabled'),
        ),
        WenzToolbarItem(
          id: 'override',
          title: 'Registry override',
          tooltip: 'Registry override',
          priority: 1,
          action: (_, __) => calls.add('registry'),
        ),
      ]);
      final explicit = <WenzToolbarItem>[
        WenzToolbarItem(
          id: 'first',
          title: 'First item',
          tooltip: 'First item',
          priority: -1,
          action: (_, __) => calls.add('first'),
        ),
        WenzToolbarItem(
          id: 'override',
          title: 'Host override',
          tooltip: 'Host override',
          priority: 0,
          icon: 'unknown-token',
          action: (_, __) => calls.add('host'),
        ),
      ];

      final harness = await _pumpToolbar(
        tester,
        toolbarItemRegistry: registry,
        toolbarItems: explicit,
      );
      final toolbarWidget = tester.widget<WenzDefaultDesktopToolbar>(
        find.byType(WenzDefaultDesktopToolbar),
      );

      expect(
        toolbarWidget.effectiveToolbarItems.map((item) => item.id),
        <String>['first', 'override', 'active', 'disabled', 'later'],
      );
      expect(find.byTooltip('Registry override'), findsNothing);
      expect(find.byTooltip('Host override'), findsOneWidget);
      expect(find.byTooltip('Active item'), findsOneWidget);
      expect(find.byTooltip('Disabled item'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Active item'),
          matching: find.byIcon(Icons.account_tree_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byTooltip('Host override'),
          matching: find.byIcon(Icons.extension_outlined),
        ),
        findsOneWidget,
      );
      expect(_iconButton(tester, 'Active item').isSelected, isTrue);
      expect(_iconButton(tester, 'Disabled item').onPressed, isNull);

      await _tapToolbarButton(tester, 'Host override');
      await _tapToolbarButton(tester, 'Active item');
      expect(calls, <String>['host', 'active']);
      expect(harness.toolbar.state.hasSelection, isTrue);
    });
  });
}

Future<_ToolbarHarness> _pumpToolbar(
  WidgetTester tester, {
  WenzRichTextController? controller,
  ToolbarController? toolbar,
  RichTextDocument? document,
  DocumentSelection? selection,
  WenzEditorPermission permission = WenzEditorPermission.edit,
  WenzToolbarItemRegistry? toolbarItemRegistry,
  Iterable<WenzToolbarItem> toolbarItems = const <WenzToolbarItem>[],
  WenzDefaultDesktopToolbarActions actions =
      const WenzDefaultDesktopToolbarActions(),
  double width = 760,
}) async {
  final host = controller ??
      WenzRichTextController(
        document: document ?? _textDocument(),
        selection: selection ?? textSelection('p1', 0, 0, 5),
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
            child: WenzDefaultDesktopToolbar(
              controller: host,
              toolbar: toolbarController,
              toolbarItemRegistry: toolbarItemRegistry,
              toolbarItems: toolbarItems,
              actions: actions,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return _ToolbarHarness(host, toolbarController);
}

Future<void> _tapToolbarButton(WidgetTester tester, String tooltip) async {
  expect(_iconButton(tester, tooltip).onPressed, isNotNull);
  await tester.tap(find.byTooltip(tooltip));
  await tester.pump();
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

RichTextDocument _textDocument({String? link}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello world',
            attributes: TextAttributes(url: link),
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
            attributes: TextAttributes(color: 0xFFFF0000),
          ),
          TextRun(
            text: 'World',
            attributes: TextAttributes(color: 0xFF00FF00),
          ),
        ],
      ),
    ],
  );
}

RichTextDocument _mixedAlignmentDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        attributes: BlockAttributes(alignment: 'left'),
        content: <InlineNode>[TextRun(text: 'One')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        attributes: BlockAttributes(alignment: 'center'),
        content: <InlineNode>[TextRun(text: 'Two')],
      ),
    ],
  );
}

DocumentSelection _mixedAlignmentSelection() {
  return DocumentSelection(
    base: DocumentPosition(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      offset: 0,
    ),
    extent: DocumentPosition(
      blockId: 'p2',
      blockIndex: 1,
      path: PositionPath.blockText('p2'),
      offset: 3,
    ),
  );
}

RichTextDocument _tableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'c00',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c00p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c01',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c01p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'c10',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c10p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'C')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c11',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c11p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'D')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _tableSelection(
  int startRow,
  int startColumn,
  int endRow,
  int endColumn,
) {
  return DocumentSelection(
    base: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: startRow,
      tableColumnIndex: startColumn,
      offset: 0,
    ),
    extent: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: endRow,
      tableColumnIndex: endColumn,
      offset: 0,
    ),
  );
}

TextBlockNode _textBlock(WenzRichTextController controller, String blockId) {
  return controller.document.blocks
      .whereType<TextBlockNode>()
      .singleWhere((block) => block.id == blockId);
}

TableBlockNode _table(WenzRichTextController controller) {
  return controller.document.blocks.whereType<TableBlockNode>().single;
}

bool _hasRun(
  WenzRichTextController controller,
  bool Function(TextRun run) test,
) {
  return _textBlock(controller, 'p1').content.whereType<TextRun>().any(test);
}

class _ToolbarHarness {
  const _ToolbarHarness(this.controller, this.toolbar);

  final WenzRichTextController controller;
  final ToolbarController toolbar;
}
