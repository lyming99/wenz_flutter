import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('adds, selects, and removes elements', () {
    final controller = CanvasController();
    const element = LineElement(
      id: 'line-1',
      start: Offset.zero,
      end: Offset(100, 0),
    );

    controller.addElement(element);
    expect(controller.elements, [element]);

    controller.select('line-1');
    expect(controller.selectedIds, {'line-1'});

    controller.removeElement('line-1');
    expect(controller.elements, isEmpty);
    expect(controller.selectedIds, isEmpty);
  });

  test('hitTest returns topmost visible element', () {
    final controller = CanvasController()
      ..addElement(
        const LineElement(
          id: 'bottom',
          start: Offset.zero,
          end: Offset(100, 0),
          zIndex: 0,
        ),
      )
      ..addElement(
        const LineElement(
          id: 'top',
          start: Offset.zero,
          end: Offset(100, 0),
          zIndex: 1,
        ),
      );

    expect(controller.hitTest(const Offset(30, 0))?.id, 'top');
  });

  test('undo and redo restore element operations', () {
    final controller = CanvasController();
    const element = LineElement(
      id: 'line-1',
      start: Offset.zero,
      end: Offset(10, 0),
    );

    controller.addElement(element);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.elements, isEmpty);
    expect(controller.canRedo, isTrue);

    controller.redo();
    expect(controller.elements.single.id, 'line-1');
  });

  test('layer visibility removes elements from hit testing', () {
    final controller = CanvasController();
    controller.addLayer(name: 'Hidden');
    final hiddenLayerId = controller.activeLayerId;
    controller
      ..addElement(
        const LineElement(
          id: 'hidden-line',
          start: Offset.zero,
          end: Offset(100, 0),
        ),
      )
      ..toggleLayerVisibility(hiddenLayerId);

    expect(controller.hitTest(const Offset(20, 0)), isNull);
  });

  test('serializes and deserializes basic elements', () {
    final controller = CanvasController()
      ..addElement(
        const RectElement(id: 'rect-1', rect: Rect.fromLTWH(0, 0, 20, 10)),
      );

    final json = CanvasSerializer.toJson(controller);
    final document = CanvasSerializer.fromJson(json);

    expect(document.elements.single, isA<RectElement>());
    expect(document.elements.single.id, 'rect-1');
  });
  test('hitTest uses zIndex across drawing and widget elements', () {
    final controller = CanvasController()
      ..addElement(
        const RectElement(
          id: 'rect-bottom',
          rect: Rect.fromLTWH(0, 0, 100, 100),
          fillStyle: PaintStyle(),
          zIndex: 0,
        ),
      )
      ..addElement(
        const CanvasWidgetElement(
          id: 'widget-top',
          worldRect: Rect.fromLTWH(0, 0, 100, 100),
          widgetType: 'test-widget',
          zIndex: 1,
        ),
      );

    expect(controller.hitTest(const Offset(50, 50))?.id, 'widget-top');
  });

  test('hitTest uses zIndex when drawing element is above widget element', () {
    final controller = CanvasController()
      ..addElement(
        const CanvasWidgetElement(
          id: 'widget-bottom',
          worldRect: Rect.fromLTWH(0, 0, 100, 100),
          widgetType: 'test-widget',
          zIndex: 0,
        ),
      )
      ..addElement(
        const RectElement(
          id: 'rect-top',
          rect: Rect.fromLTWH(0, 0, 100, 100),
          fillStyle: PaintStyle(),
          zIndex: 1,
        ),
      );

    expect(controller.hitTest(const Offset(50, 50))?.id, 'rect-top');
  });

  test('hitTest prefers elements on higher layers', () {
    final controller = CanvasController();
    controller.addLayer(name: 'Top');
    final topLayerId = controller.activeLayerId;
    controller
      ..setActiveLayer('default')
      ..addElement(
        const CanvasWidgetElement(
          id: 'widget-bottom-layer',
          worldRect: Rect.fromLTWH(0, 0, 100, 100),
          widgetType: 'test-widget',
          layerId: 'default',
          zIndex: 100,
        ),
      )
      ..setActiveLayer(topLayerId)
      ..addElement(
        RectElement(
          id: 'rect-top-layer',
          rect: const Rect.fromLTWH(0, 0, 100, 100),
          fillStyle: const PaintStyle(),
          layerId: topLayerId,
          zIndex: 0,
        ),
      );

    expect(controller.hitTest(const Offset(50, 50))?.id, 'rect-top-layer');
  });

  test(
    'orderedElements keeps mixed elements stable by layer, zIndex, insertion',
    () {
      final controller = CanvasController()
        ..addElement(
          const RectElement(
            id: 'rect-a',
            rect: Rect.fromLTWH(0, 0, 10, 10),
            zIndex: 1,
          ),
        )
        ..addElement(
          const CanvasWidgetElement(
            id: 'widget-b',
            worldRect: Rect.fromLTWH(0, 0, 10, 10),
            widgetType: 'test-widget',
            zIndex: 1,
          ),
        )
        ..addElement(
          const RectElement(
            id: 'rect-c',
            rect: Rect.fromLTWH(0, 0, 10, 10),
            zIndex: 0,
          ),
        );

      expect(controller.orderedElements().map((element) => element.id), [
        'rect-c',
        'rect-a',
        'widget-b',
      ]);
    },
  );
}
