import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

const _queryKey = ValueKey<String>('wenz-find-query');
const _toggleReplaceKey = ValueKey<String>('wenz-find-toggle-replace');
const _replacementKey = ValueKey<String>('wenz-find-replacement');
const _replaceCurrentKey = ValueKey<String>('wenz-find-replace-current');
const _replaceAllKey = ValueKey<String>('wenz-find-replace-all');
const _findHighlightKey = ValueKey<String>('wenz-richtext-find-highlight');
const _panelSurfaceKey = ValueKey<String>('wenz-find-replace-panel-surface');

void main() {
  testWidgets(
    'Ctrl+F opens compact find, navigates, closes, and restores focus',
    (tester) async {
      final editor = WenzRichTextController(document: _searchDocument());
      await _pumpEditor(tester, editor: editor);

      await _sendCtrlF(tester);

      final query = find.byKey(_queryKey);
      expect(query, findsOneWidget);
      expect(find.byKey(_toggleReplaceKey), findsOneWidget);
      expect(find.byKey(_replacementKey), findsNothing);
      expect(find.byKey(_replaceCurrentKey), findsNothing);
      expect(find.byKey(_replaceAllKey), findsNothing);
      expect(_editableText(tester, query).focusNode.hasFocus, isTrue);

      await tester.enterText(query, 'needle');
      await tester.pump();

      expect(find.text('1/3'), findsOneWidget);
      expect(find.byKey(_findHighlightKey), findsNWidgets(3));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('1/3'), findsOneWidget);

      editor.requestFocus();
      await tester.pump();
      expect(editor.hasFocus, isTrue);

      await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
      expect(_editableText(tester, query).focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(_queryKey), findsNothing);
      expect(find.byKey(_findHighlightKey), findsNothing);
      expect(editor.hasFocus, isTrue);
    },
  );

  testWidgets('Ctrl+H and the disclosure button expose replacement actions', (
    tester,
  ) async {
    final editor = WenzRichTextController(document: _searchDocument());
    await _pumpEditor(tester, editor: editor);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyH);

    expect(find.byKey(_queryKey), findsOneWidget);
    expect(find.byKey(_replacementKey), findsOneWidget);
    expect(find.byKey(_replaceCurrentKey), findsOneWidget);
    expect(find.byKey(_replaceAllKey), findsOneWidget);
    expect(
      _editableText(tester, find.byKey(_replacementKey)).focusNode.hasFocus,
      isTrue,
    );

    _editableText(tester, find.byKey(_queryKey)).focusNode.requestFocus();
    await tester.pump();
    expect(_editableText(tester, find.byKey(_queryKey)).focusNode.hasFocus,
        isTrue);

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyH);
    expect(
      _editableText(tester, find.byKey(_replacementKey)).focusNode.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byKey(_queryKey), 'needle');
    await tester.enterText(find.byKey(_replacementKey), 'found');
    await tester.tap(find.byKey(_replaceCurrentKey));
    await tester.pump();

    expect(_paragraphText(editor), 'found in paragraph');
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byKey(_replaceAllKey));
    await tester.pump();

    expect(_codeText(editor), 'found in code');
    expect(_tableCellText(editor), 'found in table');
    expect(find.byKey(_findHighlightKey), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);

    expect(find.byKey(_replacementKey), findsNothing);
    await tester.tap(find.byKey(_toggleReplaceKey));
    await tester.pump();
    expect(find.byKey(_replacementKey), findsOneWidget);
    expect(find.byKey(_replaceCurrentKey), findsOneWidget);
    expect(find.byKey(_replaceAllKey), findsOneWidget);
  });

  testWidgets('read-only editor searches but exposes no replacement actions', (
    tester,
  ) async {
    final editor = WenzRichTextController(document: _searchDocument());
    await _pumpEditor(tester, editor: editor, readOnly: true);

    await _sendCtrlF(tester);
    await tester.enterText(find.byKey(_queryKey), 'needle');
    await tester.pump();

    expect(find.text('1/3'), findsOneWidget);
    expect(find.byKey(_findHighlightKey), findsNWidgets(3));
    expect(find.byKey(_toggleReplaceKey), findsNothing);
    expect(find.byKey(_replacementKey), findsNothing);
    expect(find.byKey(_replaceCurrentKey), findsNothing);
    expect(find.byKey(_replaceAllKey), findsNothing);
    expect(_paragraphText(editor), 'needle in paragraph');
    expect(_codeText(editor), 'needle in code');
    expect(_tableCellText(editor), 'needle in table');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyH);
    expect(find.byKey(_queryKey), findsNothing);
    expect(editor.hasFocus, isTrue);
  });

  testWidgets('dark narrow editor keeps the overlay in bounds without overflow',
      (
    tester,
  ) async {
    final editor = WenzRichTextController(document: _searchDocument());
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    await _pumpEditor(
      tester,
      editor: editor,
      size: const Size(280, 600),
      theme: theme,
    );

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyH);

    expect(tester.takeException(), isNull);
    final panel = find.byKey(_panelSurfaceKey);
    expect(panel, findsOneWidget);
    final panelRect = tester.getRect(panel);
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(280));
    expect(panelRect.top, closeTo(8, 0.01));
    expect(panelRect.right, closeTo(272, 0.01));

    final material = tester.widget<Material>(panel);
    expect(material.color, theme.colorScheme.surface);
    expect(material.surfaceTintColor, Colors.transparent);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, theme.colorScheme.outlineVariant);

    for (final key in <ValueKey<String>>[
      _queryKey,
      _toggleReplaceKey,
      const ValueKey<String>('wenz-find-previous'),
      const ValueKey<String>('wenz-find-next'),
      const ValueKey<String>('wenz-find-case-sensitive'),
      const ValueKey<String>('wenz-find-whole-word'),
      _replacementKey,
      _replaceCurrentKey,
      _replaceAllKey,
      const ValueKey<String>('wenz-find-close'),
    ]) {
      final control = find.byKey(key);
      expect(control, findsOneWidget);
      final controlRect = tester.getRect(control);
      expect(controlRect.left, greaterThanOrEqualTo(panelRect.left));
      expect(controlRect.right, lessThanOrEqualTo(panelRect.right));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('host find callback takes priority over the built-in panel', (
    tester,
  ) async {
    final editor = WenzRichTextController(document: _searchDocument());
    var requests = 0;
    await _pumpEditor(
      tester,
      editor: editor,
      onFindRequested: () => requests += 1,
    );

    await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);

    expect(requests, 1);
    expect(find.byKey(_queryKey), findsNothing);
  });

  testWidgets('disposing the editor releases its owned find controller', (
    tester,
  ) async {
    final editor = _ListenerTrackingEditor(document: _searchDocument());
    await _pumpEditor(tester, editor: editor);

    expect(editor.listenerBalance, greaterThanOrEqualTo(2));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(editor.listenerBalance, 0);
  });

  testWidgets('disabled find lets Ctrl+F bubble to the host', (tester) async {
    final editor = WenzRichTextController(document: _searchDocument());
    var bubbledEvents = 0;
    var hostRequests = 0;
    await _pumpEditor(
      tester,
      editor: editor,
      enableFindReplace: false,
      onFindRequested: () => hostRequests += 1,
      onAncestorKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyF &&
            HardwareKeyboard.instance.isControlPressed) {
          bubbledEvents += 1;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );

    await _sendCtrlF(tester);

    expect(bubbledEvents, 1);
    expect(hostRequests, 0);
    expect(find.byKey(_queryKey), findsNothing);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required WenzRichTextController editor,
  bool readOnly = false,
  bool enableFindReplace = true,
  VoidCallback? onFindRequested,
  FocusOnKeyEventCallback? onAncestorKeyEvent,
  Size size = const Size(1000, 700),
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Focus(
          onKeyEvent: onAncestorKeyEvent,
          child: WenzRichTextEditor(
            controller: editor,
            autofocus: true,
            enableIme: false,
            readOnly: readOnly,
            enableFindReplace: enableFindReplace,
            onFindRequested: onFindRequested,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(editor.hasFocus, isTrue);
}

Future<void> _sendCtrlF(WidgetTester tester) async {
  await _sendPrimaryShortcut(tester, LogicalKeyboardKey.keyF);
}

Future<void> _sendPrimaryShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

EditableText _editableText(WidgetTester tester, Finder field) {
  return tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
}

String _paragraphText(WenzRichTextController editor) {
  return (editor.document.blocks[0] as TextBlockNode).plainText;
}

String _codeText(WenzRichTextController editor) {
  return (editor.document.blocks[1] as CodeBlockNode).code;
}

String _tableCellText(WenzRichTextController editor) {
  final table = editor.document.blocks[2] as TableBlockNode;
  return table.table.rows[0][0].plainText;
}

RichTextDocument _searchDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'paragraph',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'needle in paragraph')],
      ),
      CodeBlockNode(id: 'code', code: 'needle in code'),
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-paragraph',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'needle in table')],
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

class _ListenerTrackingEditor extends WenzRichTextController {
  _ListenerTrackingEditor({required super.document});

  int listenerBalance = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerBalance += 1;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerBalance -= 1;
    super.removeListener(listener);
  }
}
