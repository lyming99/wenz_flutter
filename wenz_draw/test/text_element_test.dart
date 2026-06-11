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

  test('text tool creates a concrete resizable text box', () {
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
    expect(element.boxSize, const Size(240, 96));
    expect(element.maxWidth, 240);
    expect(element.bounds, const Rect.fromLTWH(12, 18, 240, 96));
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

  test('select tool drags text handles to resize concrete box', () {
    final controller = CanvasController();
    controller.addElement(
      TextElement(
        id: 'text-1',
        position: Offset.zero,
        text: 'Resizable text',
        maxWidth: 120,
        boxSize: const Size(120, 60),
      ),
      record: false,
    );
    controller
      ..setTool(SelectTool.idValue)
      ..setSelection({'text-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(120, 60),
        worldPoint: Offset(120, 60),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(200, 90),
        worldPoint: Offset(200, 90),
        transform: CanvasTransform.identity,
        delta: Offset(80, 30),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(200, 90),
        worldPoint: Offset(200, 90),
        transform: CanvasTransform.identity,
      ),
    );

    final element = controller.elementById('text-1') as TextElement;
    expect(element.position, Offset.zero);
    expect(element.boxSize, const Size(200, 90));
    expect(element.maxWidth, 200);
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(
      (controller.elementById('text-1') as TextElement).boxSize,
      const Size(120, 60),
    );
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
