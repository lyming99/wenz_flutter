import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('overlay renders slash items and activates tapped item',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(controller: slash),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-item-heading')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-slash-item-heading')),
    );
    await tester.pump();

    expect((editor.document.blocks.single as TextBlockNode).type,
        BlockType.heading);
  });

  testWidgets('overlay keeps compact styled surface and selected item state',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

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
          body: WenzSlashMenuOverlay(
            controller: slash,
            minWidth: 260,
            maxWidth: 220,
            maxHeight: 180,
          ),
        ),
      ),
    );

    final overlayFinder =
        find.byKey(const ValueKey<String>('wenz-slash-menu-overlay'));
    expect(overlayFinder, findsOneWidget);
    expect(tester.getSize(overlayFinder).width, lessThanOrEqualTo(220));

    final material = tester.widget<Material>(overlayFinder);
    final colorScheme = theme.colorScheme;
    expect(material.color, colorScheme.surfaceContainerLow);
    expect(material.elevation, 6);
    expect(material.surfaceTintColor, colorScheme.surfaceTint.withAlpha(0));
    expect(material.clipBehavior, Clip.antiAlias);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(shape.side.color, colorScheme.outlineVariant.withAlpha(180));

    final constraints = tester.widget<ConstrainedBox>(
      find.descendant(of: overlayFinder, matching: find.byType(ConstrainedBox)),
    );
    expect(constraints.constraints.minWidth, 220);
    expect(constraints.constraints.maxWidth, 220);
    expect(constraints.constraints.maxHeight, 180);

    final listView = tester.widget<ListView>(
      find.descendant(of: overlayFinder, matching: find.byType(ListView)),
    );
    expect(listView.padding, const EdgeInsets.all(6));

    final headingTile =
        find.byKey(const ValueKey<String>('wenz-slash-item-heading'));
    final selectedDecoration = tester.widget<DecoratedBox>(
      find.descendant(of: headingTile, matching: find.byType(DecoratedBox)),
    );
    final selectedBox = selectedDecoration.decoration as BoxDecoration;
    expect(selectedBox.color, colorScheme.primaryContainer.withAlpha(112));
    expect(selectedBox.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('overlay shows minimal empty state when no command matches',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/unknown-command'),
      selection: collapsedTextSelection('p1', 0, 16),
    );
    final slash = SlashMenuController(
      editor: editor,
      registry: SlashMenuRegistry(),
    );
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(controller: slash),
        ),
      ),
    );

    expect(find.text('No commands found'), findsOneWidget);
    expect(find.text('Try a different keyword.'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('overlay exposes item text icon description and semantics',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(controller: slash),
        ),
      ),
    );

    expect(find.text('Heading'), findsOneWidget);
    expect(find.text('Large section title'), findsOneWidget);
    // Every heading level (H1–H6) renders the shared `title` icon, so several
    // tiles carry it once the full heading family is in the registry.
    expect(find.byIcon(Icons.title), findsAtLeastNWidgets(1));
    expect(
      find.bySemanticsLabel('Heading, Large section title'),
      findsOneWidget,
    );
  });

  testWidgets('editor routes enter to the open slash menu', (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            slashMenuController: slash,
            focusNode: focusNode,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final block = editor.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.plainText, isEmpty);
    expect(slash.isOpen, isFalse);
  });

  testWidgets('editor routes arrow keys to slash menu highlight',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            slashMenuController: slash,
            focusNode: focusNode,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(slash.highlightedIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(slash.highlightedIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(slash.highlightedIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(slash.highlightedIndex, slash.items.length - 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(slash.highlightedIndex, 0);
  });

  testWidgets('editor keeps slash menu inside viewport near bottom',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 220),
            viewInsets: EdgeInsets.only(bottom: 80),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 360,
                height: 96,
                child: WenzRichTextEditor(
                  controller: editor,
                  slashMenuController: slash,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
    );
    expect(overlayRect.top, greaterThanOrEqualTo(0));
    expect(overlayRect.bottom, lessThanOrEqualTo(220));
  });

  testWidgets('overlay keeps long command list scrollable within max height',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/'),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(
            controller: slash,
            maxHeight: 96,
          ),
        ),
      ),
    );

    final overlayFinder =
        find.byKey(const ValueKey<String>('wenz-slash-menu-overlay'));
    expect(overlayFinder, findsOneWidget);
    expect(tester.getSize(overlayFinder).height, lessThanOrEqualTo(96));
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pump();

    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('read-only editor does not render an open slash menu',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            slashMenuController: slash,
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(slash.isOpen, isFalse);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );

    editor.replaceDocument(
      _document('/video'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    await tester.pump();

    expect(slash.isOpen, isFalse);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );
  });

  testWidgets('editor closes slash menu with Escape and focus loss',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    final otherFocusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(otherFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SizedBox(
                height: 500,
                child: WenzRichTextEditor(
                  controller: editor,
                  slashMenuController: slash,
                  focusNode: focusNode,
                  enableIme: false,
                ),
              ),
              Focus(
                focusNode: otherFocusNode,
                child: const SizedBox(width: 1, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(slash.isOpen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(slash.isOpen, isFalse);

    editor.replaceDocument(
      _document('/hea'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    await tester.pump();
    expect(slash.isOpen, isTrue);

    otherFocusNode.requestFocus();
    await tester.pump();
    expect(slash.isOpen, isFalse);
  });

  testWidgets('editor closes slash menu when tapping outside', (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SizedBox(
                height: 500,
                child: WenzRichTextEditor(
                  controller: editor,
                  slashMenuController: slash,
                  focusNode: focusNode,
                  enableIme: false,
                ),
              ),
              SizedBox(
                key: const ValueKey<String>('outside-slash-region'),
                width: 120,
                height: 80,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Outside'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(slash.isOpen, isTrue);

    await tester
        .tap(find.byKey(const ValueKey<String>('outside-slash-region')));
    await tester.pump();

    expect(slash.isOpen, isFalse);
  });

  testWidgets('tapping slash menu item does not pass through to editor',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: editor,
            slashMenuController: slash,
            focusNode: focusNode,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-slash-item-heading')),
    );
    await tester.pump();

    expect(
      (editor.document.blocks.single as TextBlockNode).type,
      BlockType.heading,
    );
    expect(editor.selection?.isCollapsed, isTrue);
    expect(editor.selection?.extent.offset, 0);
  });

  testWidgets('overlay renders nothing while the menu is closed', (tester) async {
    final editor = WenzRichTextController(
      document: _document('plain text'),
      selection: collapsedTextSelection('p1', 0, 4),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    // No slash trigger present: the overlay must not occupy any space.
    expect(slash.isOpen, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzSlashMenuOverlay(controller: slash),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );

    // Triggering the slash later renders the overlay.
    editor.replaceDocument(
      _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );

    // Closing hides it again (renders SizedBox.shrink, no overlay key).
    slash.close();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );
  });
}

RichTextDocument _document(String text) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: text)],
      ),
    ],
  );
}
