import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

const _textId = 'editable-text';
const _shapeId = 'editable-shape';
const _red = Color(0xFFEF4444);
const _blue = Color(0xFF3B82F6);

void main() {
  group('InfiniteCanvasWidget text editing toolbar', () {
    for (final scale in [1.0, 1.75]) {
      testWidgets(
        'keeps narrow text editing active at ${scale}x toolbar edges',
        (tester) async {
          final harness = await _pumpEditingTarget(
            tester,
            TextElement(
              id: _textId,
              position: Offset(360 / scale, 250 / scale),
              text: 'Narrow',
              boxSize: const Size(24, 48),
            ),
            transform: CanvasTransform(scale: scale),
          );

          await tester.tap(_toolbarColor(_red));
          await tester.pump();

          expect(harness.canvasController.editingTextElementId, _textId);
          expect(_textElement(harness).style.color, _red);

          await _selectToolbarMenu(
            tester,
            tooltip: 'Font family',
            option: 'Mono',
          );

          expect(harness.canvasController.editingTextElementId, _textId);
          expect(_textElement(harness).style.fontFamily, 'Consolas');
          expect(harness.canvasController.historyManager.undoStack, isEmpty);
          _expectEditingFieldFocused(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'updates text styles continuously and restores focus after color dialogs',
      (tester) async {
        final harness = await _pumpEditingTarget(
          tester,
          TextElement(
            id: _textId,
            position: const Offset(340, 250),
            text: 'Draft',
            boxSize: const Size(120, 64),
          ),
        );

        await tester.tap(_toolbarColor(_red));
        await tester.pump();
        await _selectToolbarMenu(
          tester,
          tooltip: 'Font size',
          option: '32',
        );
        await _selectToolbarMenu(
          tester,
          tooltip: 'Font family',
          option: 'Serif',
        );

        var element = _textElement(harness);
        expect(element.style.color, _red);
        expect(element.style.fontSize, 32);
        expect(element.style.fontFamily, 'Times New Roman');
        expect(find.text('32'), findsOneWidget);
        expect(find.text('Serif'), findsOneWidget);
        expect(harness.canvasController.editingTextElementId, _textId);
        _expectEditingFieldFocused(tester);

        await _selectToolbarMenu(
          tester,
          tooltip: 'Font family',
          option: 'Sans',
        );
        expect(_textElement(harness).style.fontFamily, isNull);
        expect(find.text('Sans'), findsOneWidget);
        _expectEditingFieldFocused(tester);

        await _selectToolbarMenu(
          tester,
          tooltip: 'Font family',
          option: 'Serif',
        );

        await tester.tap(find.byTooltip('Font size'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(40, 560));
        await tester.pumpAndSettle();

        expect(harness.canvasController.editingTextElementId, _textId);
        expect(_textElement(harness).style.fontSize, 32);
        _expectEditingFieldFocused(tester);

        await tester.tap(find.byTooltip('Custom color'));
        await tester.pumpAndSettle();
        expect(find.text('Text color'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(harness.canvasController.editingTextElementId, _textId);
        expect(_textElement(harness).style.color, _red);
        _expectEditingFieldFocused(tester);

        await tester.tap(find.byTooltip('Custom color'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '112233');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
        await tester.pumpAndSettle();

        element = _textElement(harness);
        expect(element.style.color?.toARGB32(), 0xFF112233);
        expect(element.style.fontSize, 32);
        expect(element.style.fontFamily, 'Times New Roman');
        expect(harness.canvasController.editingTextElementId, _textId);
        expect(find.text('32'), findsOneWidget);
        expect(find.text('Serif'), findsOneWidget);
        _expectEditingFieldFocused(tester);

        await tester.enterText(find.byType(TextField), 'Still editing');
        await tester.pump();

        expect(_textElement(harness).text, 'Still editing');
        expect(harness.canvasController.editingTextElementId, _textId);
        expect(harness.canvasController.historyManager.undoStack, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 1.75]) {
      testWidgets(
        'scales and resizes text during one editing session at ${scale}x',
        (tester) async {
          final transform = CanvasTransform(scale: scale);
          final harness = await _pumpEditingTarget(
            tester,
            TextElement(
              id: _textId,
              position: const Offset(180, 160),
              text: 'Before resize',
              maxWidth: 120,
              boxSize: const Size(120, 60),
              style: const TextStyle(fontSize: 20, height: 1.2),
            ),
            transform: transform,
          );

          await _dragEditingHandle(
            tester,
            transform.worldToScreen(const Offset(300, 220)),
            transform.worldToScreen(const Offset(360, 250)),
          );

          var element = _textElement(harness);
          _expectOffsetClose(element.position, const Offset(180, 160));
          _expectSizeClose(element.boxSize!, const Size(180, 90));
          expect(element.maxWidth, closeTo(180, 1e-6));
          expect(element.style.fontSize, closeTo(30, 1e-6));
          expect(find.text('32'), findsOneWidget);
          expect(harness.canvasController.editingTextElementId, _textId);
          expect(harness.canvasController.historyManager.undoStack, isEmpty);
          _expectEditingFieldFocused(tester);

          await _dragEditingHandle(
            tester,
            transform.worldToScreen(const Offset(180, 160)),
            transform.worldToScreen(const Offset(270, 205)),
          );

          element = _textElement(harness);
          _expectOffsetClose(element.position, const Offset(270, 205));
          _expectSizeClose(element.boxSize!, const Size(90, 45));
          expect(element.maxWidth, closeTo(90, 1e-6));
          expect(element.style.fontSize, closeTo(15, 1e-6));
          expect(find.text('14'), findsOneWidget);
          expect(harness.canvasController.editingTextElementId, _textId);
          expect(harness.canvasController.historyManager.undoStack, isEmpty);
          _expectEditingFieldFocused(tester);

          await _dragEditingHandle(
            tester,
            transform.worldToScreen(const Offset(360, 227.5)),
            transform.worldToScreen(const Offset(420, 227.5)),
          );

          element = _textElement(harness);
          _expectOffsetClose(element.position, const Offset(270, 205));
          _expectSizeClose(element.boxSize!, const Size(150, 45));
          expect(element.maxWidth, closeTo(150, 1e-6));
          expect(element.style.fontSize, closeTo(15, 1e-6));
          expect(find.text('14'), findsOneWidget);
          expect(harness.canvasController.editingTextElementId, _textId);
          expect(harness.canvasController.historyManager.undoStack, isEmpty);
          _expectEditingFieldFocused(tester);

          await tester.enterText(find.byType(TextField), 'After resize');
          await tester.pump();
          expect(_textElement(harness).text, 'After resize');
          expect(harness.canvasController.historyManager.undoStack, isEmpty);

          await tester.tapAt(const Offset(40, 560));
          await tester.pumpAndSettle();

          expect(harness.canvasController.editingTextElementId, isNull);
          expect(
            harness.canvasController.historyManager.undoStack,
            hasLength(1),
          );
          element = _textElement(harness);
          expect(element.text, 'After resize');
          _expectOffsetClose(element.position, const Offset(270, 205));
          _expectSizeClose(element.boxSize!, const Size(150, 45));
          expect(element.maxWidth, closeTo(150, 1e-6));
          expect(element.style.fontSize, closeTo(15, 1e-6));

          harness.canvasController.undo();
          await tester.pump();
          element = _textElement(harness);
          expect(element.text, 'Before resize');
          _expectOffsetClose(element.position, const Offset(180, 160));
          _expectSizeClose(element.boxSize!, const Size(120, 60));
          expect(element.maxWidth, closeTo(120, 1e-6));
          expect(element.style.fontSize, closeTo(20, 1e-6));
          expect(harness.canvasController.canUndo, isFalse);
          expect(harness.canvasController.canRedo, isTrue);

          harness.canvasController.redo();
          await tester.pump();
          element = _textElement(harness);
          expect(element.text, 'After resize');
          _expectOffsetClose(element.position, const Offset(270, 205));
          _expectSizeClose(element.boxSize!, const Size(150, 45));
          expect(element.maxWidth, closeTo(150, 1e-6));
          expect(element.style.fontSize, closeTo(15, 1e-6));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('uses the same live style controls for editable shape labels', (
      tester,
    ) async {
      final harness = await _pumpEditingTarget(
        tester,
        const RectElement(
          id: _shapeId,
          rect: Rect.fromLTWH(300, 240, 180, 88),
          label: 'Shape label',
          labelStyle: TextStyle(
            color: Colors.black,
            fontSize: 14,
            height: 1.2,
          ),
        ),
      );

      await tester.tap(_toolbarColor(_blue));
      await tester.pump();
      await _selectToolbarMenu(
        tester,
        tooltip: 'Font size',
        option: '48',
      );
      await _selectToolbarMenu(
        tester,
        tooltip: 'Font family',
        option: 'Mono',
      );
      await tester.enterText(find.byType(TextField), 'Updated label');
      await tester.pump();

      final element = _shapeElement(harness);
      expect(element.label, 'Updated label');
      expect(element.labelStyle.color, _blue);
      expect(element.labelStyle.fontSize, 48);
      expect(element.labelStyle.fontFamily, 'Consolas');
      expect(harness.canvasController.editingShapeLabelElementId, _shapeId);
      expect(harness.canvasController.historyManager.undoStack, isEmpty);
      _expectEditingFieldFocused(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'outside click commits one undo entry and restores text and styles',
      (tester) async {
        final harness = await _pumpEditingTarget(
          tester,
          TextElement(
            id: _textId,
            position: const Offset(340, 250),
            text: 'Before',
            boxSize: const Size(120, 64),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'After');
        await tester.pump();
        await _selectToolbarMenu(
          tester,
          tooltip: 'Font size',
          option: '32',
        );
        await _selectToolbarMenu(
          tester,
          tooltip: 'Font family',
          option: 'Serif',
        );

        expect(harness.canvasController.historyManager.undoStack, isEmpty);

        // Leave a pending post-frame focus restoration while ending editing.
        // This exercises disposal of the editing overlay's FocusNode as well as
        // the outside-pointer commit path.
        await tester.tap(_toolbarColor(_red));
        await tester.tapAt(const Offset(40, 560));
        await tester.pumpAndSettle();

        expect(harness.canvasController.editingTextElementId, isNull);
        expect(find.byType(TextField), findsNothing);
        expect(harness.canvasController.historyManager.undoStack, hasLength(1));

        var element = _textElement(harness);
        expect(element.text, 'After');
        expect(element.style.color, _red);
        expect(element.style.fontSize, 32);
        expect(element.style.fontFamily, 'Times New Roman');
        expect(tester.takeException(), isNull);

        harness.canvasController.undo();
        await tester.pump();

        element = _textElement(harness);
        expect(element.text, 'Before');
        expect(element.style.color, Colors.black);
        expect(element.style.fontSize, 18);
        expect(element.style.fontFamily, isNull);
        expect(harness.canvasController.canUndo, isFalse);
        expect(harness.canvasController.canRedo, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<_CanvasHarness> _pumpEditingTarget(
  WidgetTester tester,
  CanvasElement element, {
  CanvasTransform transform = CanvasTransform.identity,
}) async {
  final harness = _CanvasHarness(transform: transform);
  addTearDown(harness.dispose);
  harness.canvasController.addElement(element, record: false);
  if (element is TextElement) {
    harness.canvasController.beginTextEditing(element.id);
  } else {
    harness.canvasController.beginShapeLabelEditing(element.id);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: InfiniteCanvasWidget(
          controller: harness.viewController,
          config: const InfiniteCanvasConfig(gridType: GridType.none),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _dragEditingHandle(
  WidgetTester tester,
  Offset start,
  Offset end,
) async {
  final gesture = await tester.startGesture(start);
  await tester.pump();
  await gesture.moveTo(end);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _selectToolbarMenu(
  WidgetTester tester, {
  required String tooltip,
  required String option,
}) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  expect(find.text(option), findsWidgets);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder _toolbarColor(Color color) {
  final dot = find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
      return false;
    }
    final decoration = widget.decoration as BoxDecoration;
    return decoration.shape == BoxShape.circle && decoration.color == color;
  });
  return find
      .ancestor(of: dot, matching: find.byType(InkResponse))
      .first;
}

void _expectEditingFieldFocused(WidgetTester tester) {
  final fieldFinder = find.byType(TextField);
  expect(fieldFinder, findsOneWidget);
  final field = tester.widget<TextField>(fieldFinder);
  expect(field.focusNode, isNotNull);
  expect(field.focusNode!.hasFocus, isTrue);
}

TextElement _textElement(_CanvasHarness harness) {
  return harness.canvasController.elementById(_textId)! as TextElement;
}

RectElement _shapeElement(_CanvasHarness harness) {
  return harness.canvasController.elementById(_shapeId)! as RectElement;
}

void _expectOffsetClose(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-6));
  expect(actual.dy, closeTo(expected.dy, 1e-6));
}

void _expectSizeClose(Size actual, Size expected) {
  expect(actual.width, closeTo(expected.width, 1e-6));
  expect(actual.height, closeTo(expected.height, 1e-6));
}

class _CanvasHarness {
  _CanvasHarness({required CanvasTransform transform}) {
    viewController = InfiniteCanvasController(
      canvasController: canvasController,
      transform: transform,
    );
  }

  final CanvasController canvasController = CanvasController();
  late final InfiniteCanvasController viewController;

  void dispose() {
    viewController.dispose();
    canvasController.dispose();
  }
}
