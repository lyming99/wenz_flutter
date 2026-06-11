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
    expect(controller.elements.single.id, 'line-1');

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
    final controller = CanvasController(
      autoLayeringPolicy: const AutoLayeringPolicy.manual(),
    );
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
      final controller =
          CanvasController(
              autoLayeringPolicy: const AutoLayeringPolicy.manual(),
            )
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
  test('manual auto layering preserves explicit layer and zIndex', () {
    final controller = CanvasController(
      autoLayeringPolicy: const AutoLayeringPolicy.manual(),
    );
    controller.addLayer(name: 'Other');

    controller.addElement(
      const CanvasWidgetElement(
        id: 'manual-widget',
        worldRect: Rect.fromLTWH(0, 0, 10, 10),
        widgetType: 'test-widget',
        layerId: 'default',
        zIndex: 7,
      ),
      record: false,
    );

    final element = controller.elements.single;
    expect(element.layerId, 'default');
    expect(element.zIndex, 7);
  });

  test(
    'active-layer auto layering inserts into active layer and next zIndex',
    () {
      final controller = CanvasController(
        autoLayeringPolicy: const AutoLayeringPolicy.activeLayer(
          assignZIndex: true,
        ),
      );
      controller.addLayer(name: 'Active');
      final activeLayerId = controller.activeLayerId;

      controller.addElement(
        RectElement(
          id: 'first',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          layerId: activeLayerId,
          zIndex: 5,
        ),
        record: false,
      );
      controller.updateElement(
        'first',
        RectElement(
          id: 'first',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          layerId: activeLayerId,
          zIndex: 5,
        ),
        record: false,
      );
      controller.addElement(
        const CanvasWidgetElement(
          id: 'second',
          worldRect: Rect.fromLTWH(0, 0, 10, 10),
          widgetType: 'test-widget',
          layerId: 'default',
        ),
        record: false,
      );

      final second = controller.elementById('second')!;
      expect(second.layerId, activeLayerId);
      expect(second.zIndex, 6);
    },
  );

  test('type-lane auto layering gives widgets and text higher lanes', () {
    final controller = CanvasController(
      autoLayeringPolicy: const AutoLayeringPolicy.typeLane(),
    );

    controller
      ..addElement(
        const RectElement(id: 'shape', rect: Rect.fromLTWH(0, 0, 10, 10)),
        record: false,
      )
      ..addElement(
        const CanvasWidgetElement(
          id: 'widget',
          worldRect: Rect.fromLTWH(0, 0, 10, 10),
          widgetType: 'test-widget',
        ),
        record: false,
      )
      ..addElement(
        TextElement(id: 'text', position: Offset.zero, text: 'Label'),
        record: false,
      );

    expect(controller.elementById('shape')!.zIndex, 1000001);
    expect(controller.elementById('widget')!.zIndex, 2000001);
    expect(controller.elementById('text')!.zIndex, 4000001);
    expect(controller.orderedElements().map((e) => e.id), [
      'shape',
      'widget',
      'text',
    ]);
  });

  test('overlap-aware auto layering only stacks over overlapping elements', () {
    final controller = CanvasController(
      autoLayeringPolicy: const AutoLayeringPolicy.typeLane(overlapAware: true),
    );

    controller
      ..addElement(
        const RectElement(
          id: 'far-widget-lane-shape',
          rect: Rect.fromLTWH(100, 100, 10, 10),
          zIndex: 2000099,
        ),
        record: false,
      )
      ..addElement(
        const CanvasWidgetElement(
          id: 'near-widget',
          worldRect: Rect.fromLTWH(0, 0, 10, 10),
          widgetType: 'test-widget',
        ),
        record: false,
      );

    expect(controller.elementById('near-widget')!.zIndex, 2000001);
  });
  test('select tool drags selection handles to scale widget elements', () {
    final controller = CanvasController();
    controller.addElement(
      const CanvasWidgetElement(
        id: 'widget-1',
        worldRect: Rect.fromLTWH(0, 0, 100, 50),
        widgetType: 'test-widget',
      ),
      record: false,
    );
    controller
      ..setTool(SelectTool.idValue)
      ..setSelection({'widget-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(100, 50),
        worldPoint: Offset(100, 50),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(200, 100),
        worldPoint: Offset(200, 100),
        transform: CanvasTransform.identity,
        delta: Offset(100, 50),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(200, 100),
        worldPoint: Offset(200, 100),
        transform: CanvasTransform.identity,
      ),
    );

    final element = controller.elementById('widget-1') as CanvasWidgetElement;
    expect(element.worldRect, const Rect.fromLTWH(0, 0, 200, 100));
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(
      (controller.elementById('widget-1') as CanvasWidgetElement).worldRect,
      const Rect.fromLTWH(0, 0, 100, 50),
    );
  });

  test('select tool scales shape labels with their shape', () {
    final controller = CanvasController();
    controller.addElement(
      const RectElement(
        id: 'rect-1',
        rect: Rect.fromLTWH(0, 0, 100, 50),
        strokeStyle: PaintStyle(strokeWidth: 0),
        label: 'Label',
        labelStyle: TextStyle(fontSize: 16),
      ),
      record: false,
    );
    controller
      ..setTool(SelectTool.idValue)
      ..setSelection({'rect-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(100, 50),
        worldPoint: Offset(100, 50),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(200, 100),
        worldPoint: Offset(200, 100),
        transform: CanvasTransform.identity,
        delta: Offset(100, 50),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(200, 100),
        worldPoint: Offset(200, 100),
        transform: CanvasTransform.identity,
      ),
    );

    final element = controller.elementById('rect-1') as RectElement;
    expect(element.rect, const Rect.fromLTWH(0, 0, 200, 100));
    expect(element.labelStyle.fontSize, 32);
  });
}
