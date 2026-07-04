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
        'Undo',
        'Redo',
        'Bold',
        'Italic',
        'Underline',
        'Strikethrough',
        'Remark',
        'Text color',
        'Clear style',
        'Add link',
        'Formula',
        'Emoji',
        'Heading 1',
        'Paragraph',
        'Ordered list',
        'Align center',
        'Insert code block',
        'Insert callout',
        'Insert table',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      expect(_iconButton(tester, 'Undo').onPressed, isNull);
      expect(_iconButton(tester, 'Redo').onPressed, isNull);
      expect(_iconButton(tester, 'Bold').onPressed, isNotNull);

      harness.controller.permission = WenzEditorPermission.read;
      await tester.pump();

      expect(_iconButton(tester, 'Bold').onPressed, isNull);
      expect(_iconButton(tester, 'Add link').onPressed, isNull);
      expect(_iconButton(tester, 'Heading 1').onPressed, isNull);
      expect(_iconButton(tester, 'Insert code block').onPressed, isNull);
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
      expect(find.byTooltip('Insert image'), findsNothing);

      final disabledHarness = await _pumpToolbar(
        tester,
        actions: const WenzDefaultDesktopToolbarActions(
          imageUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
        ),
      );
      expect(find.byTooltip('Insert image unavailable'), findsOneWidget);
      expect(_iconButton(tester, 'Insert image unavailable').onPressed, isNull);

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
        'Insert image',
        'Insert video',
        'Insert file',
        'Insert embed',
      ]) {
        await _tapToolbarButton(tester, tooltip);
      }
      expect(contexts, hasLength(4));
      expect(contexts.first.controller, same(disabledHarness.controller));
      expect(contexts.first.toolbar, same(disabledHarness.toolbar));
      expect(contexts.first.state.hasSelection, isTrue);

      await _pumpToolbar(
        tester,
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: contexts.add,
          isPickingImage: true,
        ),
      );
      expect(find.byTooltip('Picking image'), findsOneWidget);
      expect(_iconButton(tester, 'Picking image').onPressed, isNull);
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

      await _tapToolbarButton(tester, 'Bold');
      expect(_iconButton(tester, 'Bold').isSelected, isTrue);
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isTrue);
      expect(_iconButton(tester, 'Undo').onPressed, isNotNull);

      await _tapToolbarButton(tester, 'Italic');
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isTrue,
      );

      await _tapToolbarButton(tester, 'Clear style');
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isFalse);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isFalse,
      );

      await _tapToolbarButton(tester, 'Undo');
      expect(_iconButton(tester, 'Redo').onPressed, isNotNull);
      await _tapToolbarButton(tester, 'Redo');
      expect(_iconButton(tester, 'Undo').onPressed, isNotNull);
    });

    testWidgets('sets block type, list, alignment, and indentation', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _tapToolbarButton(tester, 'Heading 1');
      var block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.heading);
      expect(block.attributes.level, 1);
      expect(_iconButton(tester, 'Heading 1').isSelected, isTrue);

      await _tapToolbarButton(tester, 'Paragraph');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.paragraph);

      await _tapToolbarButton(tester, 'Ordered list');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');

      await _tapToolbarButton(tester, 'Unordered list');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, isNull);

      await _tapToolbarButton(tester, 'Align center');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.alignment, 'center');
      expect(_iconButton(tester, 'Align center').isSelected, isTrue);

      await _tapToolbarButton(tester, 'Increase indent');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.indent, 1);

      await _tapToolbarButton(tester, 'Decrease indent');
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.indent, 0);
    });

    testWidgets('inserts default structure blocks from toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _tapToolbarButton(tester, 'Insert code block');
      expect(harness.controller.document.blocks.first, isA<CodeBlockNode>());

      await _tapToolbarButton(tester, 'Insert callout');
      expect(
        harness.controller.document.blocks.whereType<CalloutBlockNode>(),
        isNotEmpty,
      );

      await _tapToolbarButton(tester, 'Insert table');
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

      await _tapToolbarButton(tester, 'Add link');
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
      expect(_iconButton(tester, 'Edit link').isSelected, isTrue);
    });

    testWidgets('cancel leaves the document unchanged', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapToolbarButton(tester, 'Add link');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://ignored.test');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      expect(find.byTooltip('Add link'), findsOneWidget);
    });

    testWidgets('removes an existing link', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        document: _textDocument(link: 'https://wenz.dev'),
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(_iconButton(tester, 'Edit link').isSelected, isTrue);

      await _tapToolbarButton(tester, 'Edit link');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      expect(find.byTooltip('Add link'), findsOneWidget);
    });
  });

  group('WenzDefaultDesktopToolbar table context', () {
    testWidgets('shows table buttons only for table cell selections', (
      tester,
    ) async {
      await _pumpToolbar(tester);
      expect(find.byTooltip('Insert row below'), findsNothing);

      final harness = await _pumpToolbar(
        tester,
        document: _tableDocument(),
        selection: _tableSelection(0, 0, 0, 0),
      );

      for (final tooltip in const <String>[
        'Insert row below',
        'Insert column right',
        'Delete row',
        'Delete column',
        'Merge cells',
        'Split cell',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
        expect(_iconButton(tester, tooltip).onPressed, isNotNull);
      }

      await _tapToolbarButton(tester, 'Insert row below');
      expect(_table(harness.controller).table.rowCount, 3);

      await _tapToolbarButton(tester, 'Insert column right');
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

      await _tapToolbarButton(tester, 'Merge cells');
      var table = _table(harness.controller).table;
      expect(table.cellAt(0, 0)?.columnSpan, 2);
      expect(table.cellAt(0, 1)?.covered, isTrue);

      await _tapToolbarButton(tester, 'Split cell');
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
