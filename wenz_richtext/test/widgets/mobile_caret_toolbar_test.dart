import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/widgets/mobile_selection_handles_overlay.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  testWidgets('first tap places caret and tapping caret shows three actions', (
    tester,
  ) async {
    final controller = _caretController(text: 'Caret menu');
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller, enableExternalImageInput: false);

      final caretPosition = _globalTextOffset(tester, 'Caret menu', 2);
      await _touchTap(tester, caretPosition);

      expect(
        controller.selection,
        collapsedTextSelection('mobile-caret', 0, 2),
      );
      expect(find.byType(WenzMobileCaretToolbar), findsNothing);

      await _waitPastMultiTapWindow(tester);
      await _touchTap(tester, caretPosition);

      _expectCaretToolbarOnly(tester);
      expect(
        tester
            .widget<TextButton>(_caretToolbarButton('caret-select'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester.widget<TextButton>(_caretToolbarButton('caret-paste')).onPressed,
        isNotNull,
      );

      controller.insertText('Z');
      await tester.pump();

      expect(controller.document.plainText, 'CaZret menu');
      expect(find.byType(WenzMobileCaretToolbar), findsNothing);
    });
  });

  testWidgets('caret toolbar paste button invokes its supplied action', (
    tester,
  ) async {
    final controller = _caretController(text: 'Paste target');
    var pasteCalls = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WenzMobileCaretToolbar(
                controller: controller,
                canEdit: true,
                canPaste: true,
                onPaste: () {
                  pasteCalls += 1;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(_caretToolbarButton('caret-paste'));
      await tester.pump();

      expect(pasteCalls, 1);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('caret select action selects text around the caret', (
    tester,
  ) async {
    final controller = _caretController(text: 'hello world');
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller);

      await _placeCaretThenTapCaret(
        tester,
        _globalTextOffset(tester, 'hello world', 2),
      );
      _expectCaretToolbarOnly(tester);

      await tester.tap(_caretToolbarButton('caret-select'));
      await tester.pump();

      expect(controller.selection, textSelection('mobile-caret', 0, 0, 5));
      expect(find.byType(WenzMobileCaretToolbar), findsNothing);
      expect(find.byType(WenzMobileSelectionToolbar), findsOneWidget);
    });
  });

  testWidgets('caret select action skips whitespace to nearby text', (
    tester,
  ) async {
    const text = 'hello   world';
    final controller = _caretController(text: text);
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller);

      await _placeCaretThenTapCaret(
        tester,
        _globalTextOffset(tester, text, 6),
      );

      await tester.tap(_caretToolbarButton('caret-select'));
      await tester.pump();

      expect(controller.selection, textSelection('mobile-caret', 0, 0, 5));
    });
  });

  testWidgets('tap caret menu select all selects the document', (tester) async {
    final controller = _caretController(text: 'Select everything');
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller);

      await _placeCaretThenTapCaret(
        tester,
        _globalTextOffset(tester, 'Select everything', 3),
      );
      _expectCaretToolbarOnly(tester);

      await tester.tap(_caretToolbarButton('caret-select-all'));
      await tester.pump();

      expect(
        controller.selection,
        textSelection(
          'mobile-caret',
          0,
          0,
          'Select everything'.length,
        ),
      );
    });
  });

  testWidgets('long press on an empty caret shows the caret menu', (
    tester,
  ) async {
    final controller = _caretController();
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller);

      await tester.longPressAt(tester.getRect(_emptyRichText()).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        controller.selection,
        collapsedTextSelection('mobile-caret', 0, 0),
      );
      _expectCaretToolbarOnly(tester);
    }, platform: TargetPlatform.iOS);
  });

  testWidgets('long press on a word keeps the expanded selection menu', (
    tester,
  ) async {
    final controller = _caretController(text: 'hello world');
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller);

      await tester.longPressAt(_globalTextOffset(tester, 'hello world', 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.selection, textSelection('mobile-caret', 0, 0, 5));
      expect(find.byType(WenzMobileCaretToolbar), findsNothing);
      expect(find.byType(WenzMobileSelectionToolbar), findsOneWidget);
    });
  });

  testWidgets('selection search emits selected text without requesting find', (
    tester,
  ) async {
    final controller = _caretController(text: 'hello world');
    final searchQueries = <String>[];
    var findRequests = 0;
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(
        tester,
        controller,
        onSelectionSearchRequested: searchQueries.add,
        onFindRequested: () => findRequests++,
      );

      controller.setSelection(textSelection('mobile-caret', 0, 6, 11));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(WenzMobileSelectionToolbar), findsOneWidget);
      await tester.tap(_caretToolbarButton('search'));
      await tester.pump();

      expect(searchQueries, <String>['world']);
      expect(findRequests, 0);
    });
  });

  testWidgets('selection toolbar is a popup outside a clipped editor card', (
    tester,
  ) async {
    const text = 'Popup selection remains interactive';
    final controller = _caretController(text: text);
    await _runOnMobile(tester, controller, () async {
      const cardKey = ValueKey<String>('clipped-editor-card');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned(
                  left: 40,
                  top: 240,
                  width: 240,
                  height: 96,
                  child: ClipRRect(
                    key: cardKey,
                    borderRadius: BorderRadius.circular(16),
                    child: WenzRichTextEditor(
                      controller: controller,
                      padding: const EdgeInsets.all(8),
                      enableIme: false,
                      readOnly: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      controller.setSelection(textSelection('mobile-caret', 0, 0, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final cardRect = tester.getRect(find.byKey(cardKey));
      final popupRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz.mobile-selection-toolbar-popup'),
        ),
      );
      expect(popupRect.bottom, lessThan(cardRect.top));
      expect(popupRect.width, greaterThan(cardRect.width));

      // Hit testing must work in the escaped area as well; selecting all proves
      // the card's clip no longer owns the toolbar interaction surface.
      await tester.tap(_caretToolbarButton('select-all'));
      await tester.pump();
      expect(
        controller.selection,
        textSelection('mobile-caret', 0, 0, text.length),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('selection popup follows an ancestor scrollable', (tester) async {
    const text = 'Popup follows its selected text';
    final controller = _caretController(text: text);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await _runOnMobile(tester, controller, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scrollController,
              children: <Widget>[
                const SizedBox(height: 240),
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 96,
                    child: WenzRichTextEditor(
                      controller: controller,
                      padding: const EdgeInsets.all(8),
                      enableIme: false,
                      readOnly: true,
                    ),
                  ),
                ),
                const SizedBox(height: 560),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      controller.setSelection(textSelection('mobile-caret', 0, 0, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final popup = find.byKey(
        const ValueKey<String>('wenz.mobile-selection-toolbar-popup'),
      );
      final before = tester.getRect(popup);
      scrollController.jumpTo(40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final after = tester.getRect(popup);

      expect(after.top, moreOrLessEquals(before.top - 40, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('narrow desktop does not show the mobile caret menu', (
    tester,
  ) async {
    final controller = _caretController(text: 'Desktop caret');
    await _runOnMobile(tester, controller, () async {
      await _pumpEditor(tester, controller, enableExternalImageInput: false);

      final caretPosition = _globalTextOffset(tester, 'Desktop caret', 2);
      await _touchTap(tester, caretPosition);
      await _waitPastMultiTapWindow(tester);
      await _touchTap(tester, caretPosition);

      expect(find.byType(MobileSelectionHandlesOverlay), findsNothing);
      expect(find.byType(WenzMobileCaretToolbar), findsNothing);
    }, platform: TargetPlatform.windows);
  });
}

WenzRichTextController _caretController({String text = ''}) {
  return WenzRichTextController(
    document: RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'mobile-caret',
          type: BlockType.paragraph,
          content: text.isEmpty
              ? const <InlineNode>[]
              : <InlineNode>[TextRun(text: text)],
        ),
      ],
    ),
  );
}

Future<void> _runOnMobile(
  WidgetTester tester,
  WenzRichTextController controller,
  Future<void> Function() body, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = const Size(320, 560);
  tester.view.devicePixelRatio = 1;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    controller.dispose();
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  bool enableExternalImageInput = true,
  ValueChanged<String>? onSelectionSearchRequested,
  VoidCallback? onFindRequested,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WenzRichTextEditor(
          controller: controller,
          padding: const EdgeInsets.all(24),
          enableIme: false,
          enableExternalImageInput: enableExternalImageInput,
          onSelectionSearchRequested: onSelectionSearchRequested,
          onFindRequested: onFindRequested,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _touchTap(WidgetTester tester, Offset position) async {
  final gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.touch,
  );
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _placeCaretThenTapCaret(
  WidgetTester tester,
  Offset position,
) async {
  await _touchTap(tester, position);
  expect(find.byType(WenzMobileCaretToolbar), findsNothing);
  await _waitPastMultiTapWindow(tester);
  await _touchTap(tester, position);
}

Future<void> _waitPastMultiTapWindow(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
}

void _expectCaretToolbarOnly(WidgetTester tester) {
  final toolbar = find.byType(WenzMobileCaretToolbar);
  expect(toolbar, findsOneWidget);
  expect(find.byType(WenzMobileSelectionToolbar), findsNothing);
  expect(
    find.descendant(of: toolbar, matching: find.byType(TextButton)),
    findsNWidgets(3),
  );
  expect(
    find.descendant(of: toolbar, matching: find.text('选择')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: toolbar, matching: find.text('全选')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: toolbar, matching: find.text('粘贴')),
    findsOneWidget,
  );
  expect(
    tester.getCenter(_caretToolbarButton('caret-select-all')).dx,
    lessThan(tester.getCenter(_caretToolbarButton('caret-select')).dx),
  );
  expect(
    tester.getCenter(_caretToolbarButton('caret-select')).dx,
    lessThan(tester.getCenter(_caretToolbarButton('caret-paste')).dx),
  );
  expect(find.text('剪切'), findsNothing);
  expect(find.text('复制'), findsNothing);
  expect(find.text('搜索'), findsNothing);
}

Finder _caretToolbarButton(String id) {
  return find.byKey(
    ValueKey<String>('wenz.mobile-selection-toolbar.$id'),
  );
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

Finder _emptyRichText() {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().isEmpty,
    description: 'empty RichText',
  );
}

Offset _globalTextOffset(WidgetTester tester, String text, int offset) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: size.width, maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) +
      local +
      Offset(1, painter.preferredLineHeight / 2);
}
