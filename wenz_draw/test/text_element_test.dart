import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test(
    'text element wraps inside maxWidth and uses visual bounds for hitTest',
    () {
      final element = TextElement(
        id: 'text-1',
        position: Offset.zero,
        text: 'A long label that should wrap over multiple lines',
        maxWidth: 90,
        style: const TextStyle(fontSize: 16, height: 1.2),
      );

      expect(element.bounds.width, lessThanOrEqualTo(90));
      expect(element.bounds.height, greaterThan(16));
      expect(element.hitTest(const Offset(40, 20)), isTrue);
      expect(element.hitTest(const Offset(140, 20)), isFalse);
    },
  );

  test('text element fixed box controls bounds and scales consistently', () {
    final element = TextElement(
      id: 'text-1',
      position: const Offset(10, 20),
      text: 'Boxed',
      boxSize: const Size(120, 60),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, height: 1.4),
    );

    expect(element.bounds, const Rect.fromLTWH(10, 20, 120, 60));
    final scaled = element.scaleElement(2, pivot: Offset.zero);
    expect(scaled.position, const Offset(20, 40));
    expect(scaled.boxSize, const Size(240, 120));
    expect(scaled.style.fontSize, 40);
  });

  test(
    'text element serializes styles and remains compatible with old json',
    () {
      final element = TextElement(
        id: 'text-1',
        position: const Offset(5, 7),
        text: 'Hello\nworld',
        maxWidth: 160,
        boxSize: const Size(160, 80),
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF123456),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      );

      final restored =
          CanvasSerializer.elementFromJson(element.toJson()) as TextElement;
      expect(restored.text, element.text);
      expect(restored.maxWidth, 160);
      expect(restored.boxSize, const Size(160, 80));
      expect(restored.textAlign, TextAlign.right);
      expect(restored.style.color, const Color(0xFF123456));
      expect(restored.style.fontSize, 18);
      expect(restored.style.fontWeight, FontWeight.w700);
      expect(restored.style.height, 1.5);

      final old =
          CanvasSerializer.elementFromJson({
                'id': 'old-text',
                'type': 'text',
                'position': {'x': 1, 'y': 2},
                'text': 'Old',
                'style': {'color': Colors.black.toARGB32(), 'fontSize': 24},
              })
              as TextElement;
      expect(old.position, const Offset(1, 2));
      expect(old.maxWidth, isNull);
      expect(old.boxSize, isNull);
      expect(old.textAlign, TextAlign.left);
    },
  );

  test('controller text editing updates text and supports undo redo', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(id: 'text-1', position: Offset.zero, text: 'Draft'),
      record: false,
    );

    controller.beginTextEditing('text-1');
    expect(controller.editingTextElementId, 'text-1');
    controller.endTextEditing(text: 'Final');
    expect((controller.elementById('text-1') as TextElement).text, 'Final');
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect((controller.elementById('text-1') as TextElement).text, 'Draft');
    controller.redo();
    expect((controller.elementById('text-1') as TextElement).text, 'Final');
  });

  test('select tool double tap starts editing existing text', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(id: 'text-1', position: Offset.zero, text: 'Editable'),
      record: false,
    );
    controller.setTool(SelectTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasDoubleTapEvent(
        screenPoint: Offset(10, 10),
        worldPoint: Offset(10, 10),
        transform: CanvasTransform.identity,
      ),
    );

    expect(controller.editingTextElementId, 'text-1');
    controller.endTextEditing(text: 'Changed');
    expect((controller.elementById('text-1') as TextElement).text, 'Changed');
  });

  test('live editing recalculates text bounds before commit', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(
        id: 'text-1',
        position: Offset.zero,
        text: 'Short',
        maxWidth: 120,
        style: const TextStyle(fontSize: 18, height: 1.2),
      ),
      record: false,
    );

    final before = controller.elementById('text-1')!.bounds;
    controller.beginTextEditing('text-1');
    controller.updateEditingText('Line one\nLine two\nLine three');
    final during = controller.elementById('text-1')!.bounds;

    expect(during.height, greaterThan(before.height));
    controller.endTextEditing();
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect((controller.elementById('text-1') as TextElement).text, 'Short');
  });

  test('text tool click while editing only commits current edit', () {
    final controller = CanvasController();
    controller.setTool(TextTool.idValue);
    controller.addElement(
      TextElement(id: 'text-1', position: Offset.zero, text: 'Draft'),
      record: false,
    );
    controller.beginTextEditing('text-1');
    controller.updateEditingText('Changed');

    controller.endTextEditing();

    expect(controller.elements.length, 1);
    expect((controller.elementById('text-1') as TextElement).text, 'Changed');
  });

  test('text tool creates a content-sized box that grows while typing', () {
    final controller = CanvasController();
    controller.setTool(TextTool.idValue);
    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset.zero,
        worldPoint: Offset(12, 18),
        transform: CanvasTransform.identity,
      ),
    );

    final element = controller.elements.single as TextElement;
    expect(element.position, const Offset(12, 18));
    expect(element.boxSize, element.renderedSize);
    expect(element.maxWidth, 240);
    final initialBounds = element.bounds;

    controller.updateEditingText('First line\nSecond line\nThird line');
    final updated = controller.elements.single as TextElement;
    expect(updated.boxSize, updated.renderedSize);
    expect(updated.bounds.height, greaterThan(initialBounds.height));
    expect(updated.bounds.width, lessThanOrEqualTo(240));
  });

  test('controller resizes text box and keeps wrapping width in sync', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(
        id: 'text-1',
        position: Offset.zero,
        text: 'A long paragraph that wraps inside the concrete box width.',
        maxWidth: 120,
        boxSize: const Size(120, 60),
        style: const TextStyle(fontSize: 16, height: 1.2),
      ),
      record: false,
    );

    controller.resizeTextElement('text-1', const Size(300, 120), record: false);

    final element = controller.elementById('text-1') as TextElement;
    expect(element.boxSize, const Size(300, 120));
    expect(element.maxWidth, 300);
    expect(element.bounds, const Rect.fromLTWH(0, 0, 300, 120));
    expect(element.createTextPainter().width, lessThanOrEqualTo(300));
  });

  group('select tool text resize handles', () {
    for (final handle in _TestTextHandle.cornerValues) {
      test('${handle.name} scales the whole fixed text box', () {
        final controller = CanvasController();
        addTearDown(controller.dispose);
        final before = _boxedText();
        controller.addElement(before, record: false);
        controller
          ..setTool(SelectTool.idValue)
          ..setSelection({before.id});

        final draggedCorner = handle.pointFor(before.localBounds);
        final anchor = handle.anchorFor(before.localBounds);
        final target = anchor + (draggedCorner - anchor) * 1.5;
        _dragSelectedHandle(controller, draggedCorner, [target]);

        final after = controller.elementById(before.id)! as TextElement;
        final expected = before.scaleElement(1.5, pivot: anchor);
        _expectTextGeometry(after, expected);
        expect(after.text, before.text);
        expect(after.textAlign, before.textAlign);
        expect(after.style.color, before.style.color);
        expect(after.style.fontWeight, before.style.fontWeight);
        expect(after.style.fontFamily, before.style.fontFamily);
        expect(after.style.height, before.style.height);
        _expectOffsetClose(handle.anchorFor(after.localBounds), anchor);
        expect(controller.historyManager.undoStack, hasLength(1));

        controller.undo();
        _expectTextGeometry(
          controller.elementById(before.id)! as TextElement,
          before,
        );
        controller.redo();
        _expectTextGeometry(
          controller.elementById(before.id)! as TextElement,
          expected,
        );
      });
    }

    for (final handle in _TestTextHandle.edgeValues) {
      test('${handle.name} changes only the text layout box', () {
        final controller = CanvasController();
        addTearDown(controller.dispose);
        final before = _boxedText();
        controller.addElement(before, record: false);
        controller
          ..setTool(SelectTool.idValue)
          ..setSelection({before.id});

        final start = handle.pointFor(before.localBounds);
        final delta = switch (handle) {
          _TestTextHandle.top => const Offset(0, -20),
          _TestTextHandle.bottom => const Offset(0, 30),
          _TestTextHandle.left => const Offset(-30, 0),
          _TestTextHandle.right => const Offset(40, 0),
          _ => Offset.zero,
        };
        final target = start + delta;
        _dragSelectedHandle(controller, start, [target]);

        final after = controller.elementById(before.id)! as TextElement;
        final expectedRect = _edgeResizeRect(
          before.localBounds,
          handle,
          target,
        );
        _expectOffsetClose(after.position, expectedRect.topLeft);
        _expectSizeClose(after.boxSize!, expectedRect.size);
        expect(after.maxWidth, closeTo(expectedRect.width, 1e-6));
        expect(after.style.fontSize, before.style.fontSize);
        expect(after.style, before.style);
        expect(after.text, before.text);
        expect(after.textAlign, before.textAlign);
        expect(controller.historyManager.undoStack, hasLength(1));
      });
    }

    test('rotated text scales identically at different viewport scales', () {
      final before = _boxedText(
        position: const Offset(120, 100),
        boxSize: const Size(160, 80),
        rotation: math.pi / 6,
      );
      const handle = _TestTextHandle.bottomRight;
      final localCorner = handle.pointFor(before.localBounds);
      final localAnchor = handle.anchorFor(before.localBounds);
      final worldCorner = _rotatedTextPoint(before, localCorner);
      final worldAnchor = _rotatedTextPoint(before, localAnchor);
      final target = worldAnchor + (worldCorner - worldAnchor) * 1.5;
      final expectedScaled = before.scaleElement(1.5, pivot: localAnchor);
      final expected = expectedScaled.translate(
        worldAnchor - _rotatedTextPoint(expectedScaled, localAnchor),
      );

      final results = <TextElement>[];
      for (final transform in const [
        CanvasTransform.identity,
        CanvasTransform(scale: 2, offset: Offset(30, 20)),
      ]) {
        final controller = CanvasController();
        addTearDown(controller.dispose);
        controller.addElement(before, record: false);
        controller
          ..setTool(SelectTool.idValue)
          ..setSelection({before.id});

        final paddedBounds = before.localBounds.inflate(4 / transform.scale);
        final visualCorner = _rotatedTextPoint(
          before,
          handle.pointFor(paddedBounds),
        );
        final visualTarget = visualCorner + (target - worldCorner);
        _dragSelectedHandle(controller, visualCorner, [
          visualTarget,
        ], transform: transform);
        final after = controller.elementById(before.id)! as TextElement;
        results.add(after);
        _expectTextGeometry(after, expected);
        _expectOffsetClose(
          _rotatedTextPoint(after, handle.anchorFor(after.localBounds)),
          worldAnchor,
        );
        _expectOffsetClose(
          _rotatedTextPoint(after, handle.pointFor(after.localBounds)),
          target,
        );
        expect(controller.historyManager.undoStack, hasLength(1));
        controller.undo();
        _expectTextGeometry(
          controller.elementById(before.id)! as TextElement,
          before,
        );
        controller.redo();
        _expectTextGeometry(
          controller.elementById(before.id)! as TextElement,
          expected,
        );
      }
      _expectTextGeometry(results.first, results.last);
    });

    test('corner shrinking stops at valid box and font dimensions', () {
      final controller = CanvasController();
      addTearDown(controller.dispose);
      final before = _boxedText(
        position: Offset.zero,
        boxSize: const Size(240, 96),
        fontSize: 24,
      );
      controller.addElement(before, record: false);
      controller
        ..setTool(SelectTool.idValue)
        ..setSelection({before.id});

      const handle = _TestTextHandle.bottomRight;
      final start = handle.pointFor(before.localBounds);
      final anchor = handle.anchorFor(before.localBounds);
      _dragSelectedHandle(controller, start, [
        anchor + (start - anchor) * 0.2,
        anchor - (start - anchor),
      ]);

      final after = controller.elementById(before.id)! as TextElement;
      _expectOffsetClose(after.position, Offset.zero);
      _expectSizeClose(after.boxSize!, const Size(60, 24));
      expect(after.maxWidth, closeTo(60, 1e-6));
      expect(after.style.fontSize, closeTo(6, 1e-6));
      expect(after.boxSize!.width, greaterThanOrEqualTo(24));
      expect(after.boxSize!.height, greaterThanOrEqualTo(24));
      expect(after.style.fontSize!.isFinite, isTrue);
      expect(after.style.fontSize, greaterThan(0));
      expect(controller.historyManager.undoStack, hasLength(1));
    });
  });

  test('controller updates text style fields', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(id: 'text-1', position: Offset.zero, text: 'Styled'),
      record: false,
    );

    controller.updateTextElementStyle(
      'text-1',
      color: Colors.red,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
      lineHeight: 1.6,
      maxWidth: 220,
      boxSize: const Size(220, 90),
      record: false,
    );

    final element = controller.elementById('text-1') as TextElement;
    expect(element.style.color, Colors.red);
    expect(element.style.fontSize, 32);
    expect(element.style.fontWeight, FontWeight.bold);
    expect(element.style.height, 1.6);
    expect(element.textAlign, TextAlign.center);
    expect(element.maxWidth, 220);
    expect(element.boxSize, const Size(220, 90));
    controller.updateTextElementStyle(
      'text-1',
      fontFamily: 'Consolas',
      record: false,
    );
    expect(
      (controller.elementById('text-1') as TextElement).style.fontFamily,
      'Consolas',
    );
    controller.updateTextElementStyle(
      'text-1',
      fontFamily: null,
      record: false,
    );
    expect(
      (controller.elementById('text-1') as TextElement).style.fontFamily,
      isNull,
    );
  });
}

TextElement _boxedText({
  Offset position = const Offset(100, 80),
  Size boxSize = const Size(120, 60),
  double fontSize = 20,
  double rotation = 0,
}) {
  return TextElement(
    id: 'text-1',
    position: position,
    text: 'Resizable text',
    maxWidth: boxSize.width,
    boxSize: boxSize,
    textAlign: TextAlign.right,
    rotation: rotation,
    style: TextStyle(
      color: const Color(0xFF123456),
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      height: 1.4,
      fontFamily: 'Consolas',
    ),
  );
}

void _dragSelectedHandle(
  CanvasController controller,
  Offset worldStart,
  List<Offset> worldMoves, {
  CanvasTransform transform = CanvasTransform.identity,
}) {
  assert(worldMoves.isNotEmpty);
  var previousScreen = transform.worldToScreen(worldStart);
  controller.dispatchCanvasEvent(
    CanvasPointerDownEvent(
      screenPoint: previousScreen,
      worldPoint: worldStart,
      transform: transform,
    ),
  );
  for (final worldPoint in worldMoves) {
    final screenPoint = transform.worldToScreen(worldPoint);
    controller.dispatchCanvasEvent(
      CanvasPointerMoveEvent(
        screenPoint: screenPoint,
        worldPoint: worldPoint,
        transform: transform,
        delta: screenPoint - previousScreen,
      ),
    );
    previousScreen = screenPoint;
  }
  final worldEnd = worldMoves.last;
  controller.dispatchCanvasEvent(
    CanvasPointerUpEvent(
      screenPoint: transform.worldToScreen(worldEnd),
      worldPoint: worldEnd,
      transform: transform,
    ),
  );
}

Rect _edgeResizeRect(Rect before, _TestTextHandle handle, Offset target) {
  return switch (handle) {
    _TestTextHandle.top => Rect.fromLTRB(
      before.left,
      target.dy,
      before.right,
      before.bottom,
    ),
    _TestTextHandle.bottom => Rect.fromLTRB(
      before.left,
      before.top,
      before.right,
      target.dy,
    ),
    _TestTextHandle.left => Rect.fromLTRB(
      target.dx,
      before.top,
      before.right,
      before.bottom,
    ),
    _TestTextHandle.right => Rect.fromLTRB(
      before.left,
      before.top,
      target.dx,
      before.bottom,
    ),
    _ => before,
  };
}

Offset _rotatedTextPoint(TextElement element, Offset point) {
  final center = element.localBounds.center;
  final translated = point - center;
  final cosine = math.cos(element.rotation);
  final sine = math.sin(element.rotation);
  return Offset(
    center.dx + translated.dx * cosine - translated.dy * sine,
    center.dy + translated.dx * sine + translated.dy * cosine,
  );
}

void _expectTextGeometry(TextElement actual, TextElement expected) {
  _expectOffsetClose(actual.position, expected.position);
  expect(actual.boxSize, isNotNull);
  expect(expected.boxSize, isNotNull);
  _expectSizeClose(actual.boxSize!, expected.boxSize!);
  expect(actual.maxWidth, closeTo(expected.maxWidth!, 1e-6));
  expect(actual.style.fontSize, closeTo(expected.style.fontSize!, 1e-6));
  expect(actual.rotation, closeTo(expected.rotation, 1e-9));
}

void _expectOffsetClose(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-6));
  expect(actual.dy, closeTo(expected.dy, 1e-6));
}

void _expectSizeClose(Size actual, Size expected) {
  expect(actual.width, closeTo(expected.width, 1e-6));
  expect(actual.height, closeTo(expected.height, 1e-6));
}

enum _TestTextHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right;

  static const cornerValues = [topLeft, topRight, bottomLeft, bottomRight];
  static const edgeValues = [top, bottom, left, right];

  Offset pointFor(Rect rect) {
    return switch (this) {
      topLeft => rect.topLeft,
      topRight => rect.topRight,
      bottomLeft => rect.bottomLeft,
      bottomRight => rect.bottomRight,
      top => rect.topCenter,
      bottom => rect.bottomCenter,
      left => rect.centerLeft,
      right => rect.centerRight,
    };
  }

  Offset anchorFor(Rect rect) {
    return switch (this) {
      topLeft => rect.bottomRight,
      topRight => rect.bottomLeft,
      bottomLeft => rect.topRight,
      bottomRight => rect.topLeft,
      top => rect.bottomCenter,
      bottom => rect.topCenter,
      left => rect.centerRight,
      right => rect.centerLeft,
    };
  }
}
