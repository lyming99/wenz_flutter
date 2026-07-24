import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('panel searches, navigates, and replaces current match',
      (tester) async {
    final editor = WenzRichTextController(document: _document());
    final findController = WenzFindReplaceController(editor: editor);
    addTearDown(findController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzFindReplacePanel(controller: findController),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('wenz-find-query')),
      'alpha',
    );
    await tester.pump();

    expect(findController.matches, hasLength(2));
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('wenz-find-next')));
    await tester.pump();

    expect(findController.currentIndex, 1);
    expect(find.text('2/2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('wenz-find-replacement')),
      'omega',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-find-replace-current')),
    );
    await tester.pump();

    expect((editor.document.blocks.first as TextBlockNode).plainText,
        'alpha beta omega');
  });

  testWidgets('panel uses dark theme surface and toggle colors',
      (tester) async {
    final editor = WenzRichTextController(document: _document());
    final findController = WenzFindReplaceController(editor: editor);
    addTearDown(findController.dispose);
    findController.setOptions(caseSensitive: true);

    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WenzFindReplacePanel(controller: findController),
        ),
      ),
    );

    final colorScheme = theme.colorScheme;
    final material = tester.widget<Material>(
      find.byKey(const ValueKey<String>('wenz-find-replace-panel-surface')),
    );
    expect(material.color, colorScheme.surface);
    expect(material.surfaceTintColor, Colors.transparent);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, colorScheme.outlineVariant);

    final toggle = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('wenz-find-case-sensitive')),
    );
    expect(toggle.isSelected, isTrue);
    expect(toggle.style?.foregroundColor?.resolve(<WidgetState>{}),
        colorScheme.onSurfaceVariant);
    expect(
      toggle.style?.backgroundColor
          ?.resolve(<WidgetState>{WidgetState.selected}),
      colorScheme.primaryContainer,
    );
  });

  testWidgets('panel autofocuses query and handles navigation and escape',
      (tester) async {
    final editor = WenzRichTextController(document: _document());
    final findController = WenzFindReplaceController(editor: editor);
    addTearDown(findController.dispose);
    var closeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzFindReplacePanel(
            controller: findController,
            onClose: () => closeCount += 1,
          ),
        ),
      ),
    );
    await tester.pump();

    final query = find.byKey(const ValueKey<String>('wenz-find-query'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: query, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.enterText(query, 'alpha');
    await tester.pump();
    expect(findController.currentIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(findController.currentIndex, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(findController.currentIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closeCount, 1);
  });

  testWidgets('panel keeps every action visible without narrow-width overflow',
      (tester) async {
    final editor = WenzRichTextController(document: _document());
    final findController = WenzFindReplaceController(editor: editor);
    addTearDown(findController.dispose);
    await tester.binding.setSurfaceSize(const Size(260, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzFindReplacePanel(
            controller: findController,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final key in <String>[
      'wenz-find-query',
      'wenz-find-previous',
      'wenz-find-next',
      'wenz-find-case-sensitive',
      'wenz-find-whole-word',
      'wenz-find-replacement',
      'wenz-find-replace-current',
      'wenz-find-replace-all',
      'wenz-find-close',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
  });

  testWidgets(
      'editor paints find highlights when a find controller is attached',
      (tester) async {
    final editor = WenzRichTextController(document: _document());
    final findController = WenzFindReplaceController(editor: editor);
    addTearDown(findController.dispose);
    findController.setQuery('alpha');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            findController: findController,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-find-highlight')),
      findsOneWidget,
    );
  });
}

RichTextDocument _document() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(text: 'alpha beta alpha'),
        ],
      ),
    ],
  );
}
