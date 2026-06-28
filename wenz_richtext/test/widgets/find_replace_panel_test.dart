import 'package:flutter/material.dart';
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
      toggle.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.selected}),
      colorScheme.primaryContainer,
    );
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
