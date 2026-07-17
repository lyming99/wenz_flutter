import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const _slashMenuOverlayKey = ValueKey<String>('wenz-slash-menu-overlay');
const _slashItemHeadingKey = ValueKey<String>('wenz-slash-item-heading');
const _slashMenuSurfaceColorLight = Color(0xFFF8F9FA);
const _slashMenuSurfaceColorDark = Color(0xFF292A2D);
const _slashMenuBorderColorLight = Color(0xFFDADCE0);
const _slashMenuBorderColorDark = Color(0xFF4A4C50);
const _slashMenuSelectedColorLight = Color(0xFFE8EAED);
const _slashMenuSelectedColorDark = Color(0xFF3C4043);
const _slashMenuMinReadableHeight = 132.0;
const _slashMenuViewportInset = 8.0;
const _slashMenuGap = 6.0;

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
      find.byKey(_slashMenuOverlayKey),
      findsOneWidget,
    );
    expect(
      find.byKey(_slashItemHeadingKey),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(_slashItemHeadingKey),
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

    final overlayFinder = find.byKey(_slashMenuOverlayKey);
    expect(overlayFinder, findsOneWidget);
    expect(tester.getSize(overlayFinder).width, lessThanOrEqualTo(220));
    _expectNoSlashMenuDividers(overlayFinder);

    final material = tester.widget<Material>(overlayFinder);
    final colorScheme = theme.colorScheme;
    expect(material.color, _slashMenuSurfaceColorDark);
    expect(material.elevation, 3);
    expect(material.shadowColor, colorScheme.shadow.withAlpha(30));
    expect(material.surfaceTintColor, Colors.transparent);
    expect(material.clipBehavior, Clip.antiAlias);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10));
    expect(shape.side.color, _slashMenuBorderColorDark);

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

    final headingTile = find.byKey(_slashItemHeadingKey);
    final selectedBox = _slashTileDecoration(tester, headingTile);
    expect(selectedBox.color, _slashMenuSelectedColorDark);
    expect(selectedBox.color, isNot(colorScheme.primary.withAlpha(34)));
    expect(selectedBox.borderRadius, BorderRadius.circular(8));
    final selectedIcon = tester.widget<Icon>(
      find.descendant(of: headingTile, matching: find.byIcon(Icons.title)),
    );
    expect(selectedIcon.color, colorScheme.onSurface);
    final selectedTitle = tester.widget<Text>(
      find.descendant(of: headingTile, matching: find.text('标题')),
    );
    expect(selectedTitle.style?.color, colorScheme.onSurface);
    final selectedDescription = tester.widget<Text>(
      find.descendant(of: headingTile, matching: find.text('大号章节标题')),
    );
    expect(selectedDescription.style?.color, colorScheme.onSurfaceVariant);
  });

  testWidgets('overlay uses light neutral chrome independent of seed color',
      (tester) async {
    final editor = WenzRichTextController(
      document: _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    final slash = SlashMenuController(editor: editor);
    addTearDown(slash.dispose);

    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: Brightness.light,
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

    final overlayFinder = find.byKey(_slashMenuOverlayKey);
    expect(overlayFinder, findsOneWidget);
    _expectNoSlashMenuDividers(overlayFinder);
    final material = tester.widget<Material>(overlayFinder);
    final colorScheme = theme.colorScheme;
    expect(material.color, _slashMenuSurfaceColorLight);
    expect(material.shadowColor, colorScheme.shadow.withAlpha(30));
    expect(material.surfaceTintColor, Colors.transparent);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, _slashMenuBorderColorLight);

    final constraints = tester.widget<ConstrainedBox>(
      find.descendant(of: overlayFinder, matching: find.byType(ConstrainedBox)),
    );
    expect(constraints.constraints.minWidth, 220);
    expect(constraints.constraints.maxWidth, 220);
    expect(constraints.constraints.maxHeight, 180);

    final selectedBox = _slashTileDecoration(
      tester,
      find.byKey(_slashItemHeadingKey),
    );
    expect(selectedBox.color, _slashMenuSelectedColorLight);
    expect(selectedBox.color, isNot(colorScheme.primary.withAlpha(34)));
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

    expect(find.text('未找到命令'), findsOneWidget);
    expect(find.text('试试输入「表格」「图片」或「代码」。'), findsOneWidget);
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

    expect(find.text('标题'), findsOneWidget);
    expect(find.text('大号章节标题'), findsOneWidget);
    // Every heading level (H1–H6) renders the shared `title` icon, so several
    // tiles carry it once the full heading family is in the registry.
    expect(find.byIcon(Icons.title), findsAtLeastNWidgets(1));
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
      find.byKey(_slashMenuOverlayKey),
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

  testWidgets('editor opens slash menu above near keyboard-clipped bottom',
      (tester) async {
    await _pumpPositionedSlashEditor(
      tester,
      surfaceSize: const Size(360, 260),
      viewInsets: const EdgeInsets.only(bottom: 80),
      alignment: Alignment.bottomLeft,
      editorHeight: 96,
    );

    final overlayRect = _slashOverlayRect(tester);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    const keyboardTop = 260.0 - 80.0;
    expect(overlayRect.top, greaterThanOrEqualTo(0));
    expect(overlayRect.left, greaterThanOrEqualTo(0));
    expect(overlayRect.bottom, lessThan(editorRect.center.dy));
    expect(overlayRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(
      overlayRect.height,
      greaterThanOrEqualTo(_slashMenuMinReadableHeight),
    );
  });

  testWidgets('editor opens slash menu below when top space is insufficient',
      (tester) async {
    await _pumpPositionedSlashEditor(
      tester,
      surfaceSize: const Size(360, 260),
      alignment: Alignment.topLeft,
      editorHeight: 96,
    );

    final overlayRect = _slashOverlayRect(tester);
    final textRect = tester.getRect(_richText('/'));
    expect(overlayRect.top, greaterThanOrEqualTo(textRect.bottom));
    expect(overlayRect.left, greaterThanOrEqualTo(0));
    expect(overlayRect.bottom, lessThanOrEqualTo(260));
    expect(
      overlayRect.height,
      greaterThanOrEqualTo(_slashMenuMinReadableHeight),
    );
  });

  testWidgets('editor chooses larger constrained side and keeps list scrollable',
      (tester) async {
    await _pumpPositionedSlashEditor(
      tester,
      surfaceSize: const Size(360, 170),
      alignment: Alignment.topLeft,
      bodyPadding: const EdgeInsets.only(top: 32),
      editorHeight: 72,
    );

    final overlayRect = _slashOverlayRect(tester);
    final textRect = tester.getRect(_richText('/'));
    final availableAbove =
        textRect.top - _slashMenuGap - _slashMenuViewportInset;
    final availableBelow =
        170.0 - textRect.bottom - _slashMenuGap - _slashMenuViewportInset;
    expect(availableAbove, lessThan(_slashMenuMinReadableHeight));
    expect(availableBelow, lessThan(_slashMenuMinReadableHeight));
    expect(availableBelow, greaterThan(availableAbove));
    expect(overlayRect.top, greaterThanOrEqualTo(textRect.bottom));
    expect(overlayRect.left, greaterThanOrEqualTo(0));
    expect(overlayRect.height, lessThan(_slashMenuMinReadableHeight));
    expect(overlayRect.height, greaterThan(48));
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('editor keeps slash menu inside viewport near bottom',
      (tester) async {
    await _pumpPositionedSlashEditor(
      tester,
      surfaceSize: const Size(360, 260),
      viewInsets: const EdgeInsets.only(bottom: 80),
      alignment: Alignment.bottomLeft,
      editorHeight: 96,
    );

    final overlayRect = _slashOverlayRect(tester);
    expect(overlayRect.top, greaterThanOrEqualTo(0));
    expect(overlayRect.left, greaterThanOrEqualTo(0));
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

    final overlayFinder = find.byKey(_slashMenuOverlayKey);
    expect(overlayFinder, findsOneWidget);
    expect(tester.getSize(overlayFinder).height, lessThanOrEqualTo(96));
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('视频'), findsOneWidget);
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
      find.byKey(_slashMenuOverlayKey),
      findsNothing,
    );

    editor.replaceDocument(
      _document('/video'),
      selection: collapsedTextSelection('p1', 0, 6),
    );
    await tester.pump();

    expect(slash.isOpen, isFalse);
    expect(
      find.byKey(_slashMenuOverlayKey),
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
      find.byKey(_slashItemHeadingKey),
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
      find.byKey(_slashMenuOverlayKey),
      findsNothing,
    );

    // Triggering the slash later renders the overlay.
    editor.replaceDocument(
      _document('/heading'),
      selection: collapsedTextSelection('p1', 0, 8),
    );
    await tester.pump();
    expect(
      find.byKey(_slashMenuOverlayKey),
      findsOneWidget,
    );

    // Closing hides it again (renders SizedBox.shrink, no overlay key).
    slash.close();
    await tester.pump();
    expect(
      find.byKey(_slashMenuOverlayKey),
      findsNothing,
    );
  });
}

Future<void> _pumpPositionedSlashEditor(
  WidgetTester tester, {
  required Size surfaceSize,
  required AlignmentGeometry alignment,
  required double editorHeight,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets bodyPadding = EdgeInsets.zero,
}) async {
  final editor = WenzRichTextController(
    document: _document('/'),
    selection: collapsedTextSelection('p1', 0, 1),
  );
  final slash = SlashMenuController(editor: editor);
  final focusNode = FocusNode();
  addTearDown(slash.dispose);
  addTearDown(focusNode.dispose);
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: surfaceSize, viewInsets: viewInsets),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: bodyPadding,
            child: Align(
              alignment: alignment,
              child: SizedBox(
                width: surfaceSize.width,
                height: editorHeight,
                child: WenzRichTextEditor(
                  controller: editor,
                  slashMenuController: slash,
                  focusNode: focusNode,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
  slash.refresh();
  await tester.pump();
}

Rect _slashOverlayRect(WidgetTester tester) {
  final overlay = find.byKey(_slashMenuOverlayKey);
  expect(overlay, findsOneWidget);
  return tester.getRect(overlay);
}

BoxDecoration _slashTileDecoration(WidgetTester tester, Finder itemFinder) {
  final selectedDecoration = tester.widget<DecoratedBox>(
    find.descendant(of: itemFinder, matching: find.byType(DecoratedBox)),
  );
  return selectedDecoration.decoration as BoxDecoration;
}

void _expectNoSlashMenuDividers(Finder overlayFinder) {
  expect(
    find.descendant(of: overlayFinder, matching: find.byType(Divider)),
    findsNothing,
  );
  expect(
    find.descendant(of: overlayFinder, matching: find.byType(VerticalDivider)),
    findsNothing,
  );
  expect(
    find.descendant(of: overlayFinder, matching: find.byType(PopupMenuDivider)),
    findsNothing,
  );
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
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
