import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('snap resolver uses screen threshold converted by scale', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(thresholdScreenPx: 10),
    );
    controller.addElement(
      const RectElement(id: 'rect-1', rect: Rect.fromLTWH(0, 0, 100, 80)),
      record: false,
    );

    final nearAtScaleOne = controller.snapResolver.resolve(
      controller,
      const Offset(55, 40),
      scale: 1,
    );
    expect(nearAtScaleOne?.position, const Offset(50, 40));

    final tooFarAtScaleTwo = controller.snapResolver.resolve(
      controller,
      const Offset(56, 40),
      scale: 2,
    );
    expect(tooFarAtScaleTwo, isNull);
  });

  test('line tool snaps start and end points to nearby anchors', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(thresholdScreenPx: 12),
    );
    controller
      ..addElement(
        const RectElement(id: 'start-rect', rect: Rect.fromLTWH(0, 0, 100, 80)),
        record: false,
      )
      ..addElement(
        const RectElement(id: 'end-rect', rect: Rect.fromLTWH(200, 0, 100, 80)),
        record: false,
      )
      ..setTool(LineTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(52, 41),
        worldPoint: Offset(52, 41),
        transform: CanvasTransform.identity,
      ),
    );
    expect(controller.snapPreview?.position, const Offset(50, 40));

    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(248, 38),
        worldPoint: Offset(248, 38),
        transform: CanvasTransform.identity,
        delta: Offset(196, -3),
      ),
    );
    expect(controller.snapPreview?.position, const Offset(250, 40));

    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(248, 38),
        worldPoint: Offset(248, 38),
        transform: CanvasTransform.identity,
      ),
    );

    final line = controller.elements.whereType<PolylineElement>().single;
    expect(line.points.first, const Offset(50, 40));
    expect(line.points.last, const Offset(250, 40));
    expect(controller.snapPreview, isNull);
  });

  test('arrow tool respects disabled snapping', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(enabled: false),
    );
    controller
      ..addElement(
        const RectElement(id: 'rect-1', rect: Rect.fromLTWH(0, 0, 100, 80)),
        record: false,
      )
      ..setTool(ArrowTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(52, 41),
        worldPoint: Offset(52, 41),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(130, 41),
        worldPoint: Offset(130, 41),
        transform: CanvasTransform.identity,
      ),
    );

    final arrow = controller.elements.whereType<PolylineElement>().single;
    expect(arrow.points.first, const Offset(52, 41));
    expect(arrow.points.last, const Offset(130, 41));
  });

  test('snap resolver ignores hidden and locked layers', () {
    final controller = CanvasController();
    controller.addLayer(name: 'Hidden');
    final hiddenLayer = controller.activeLayerId;
    controller.addElement(
      RectElement(
        id: 'hidden-rect',
        rect: const Rect.fromLTWH(0, 0, 100, 80),
        layerId: hiddenLayer,
      ),
      record: false,
    );
    controller.toggleLayerVisibility(hiddenLayer);

    expect(
      controller.snapResolver.resolve(
        controller,
        const Offset(50, 40),
        scale: 1,
      ),
      isNull,
    );

    controller.addLayer(name: 'Locked');
    final lockedLayer = controller.activeLayerId;
    controller.addElement(
      RectElement(
        id: 'locked-rect',
        rect: const Rect.fromLTWH(200, 0, 100, 80),
        layerId: lockedLayer,
      ),
      record: false,
    );
    controller.toggleLayerLock(lockedLayer);

    expect(
      controller.snapResolver.resolve(
        controller,
        const Offset(250, 40),
        scale: 1,
      ),
      isNull,
    );
  });
  test('snap-bound line endpoint follows moved widget anchor', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(thresholdScreenPx: 12),
    );
    controller
      ..addElement(
        const CanvasWidgetElement(
          id: 'widget-1',
          worldRect: Rect.fromLTWH(0, 0, 100, 80),
          widgetType: 'test-widget',
        ),
        record: false,
      )
      ..addElement(
        const RectElement(id: 'rect-1', rect: Rect.fromLTWH(200, 0, 100, 80)),
        record: false,
      )
      ..setTool(LineTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(52, 41),
        worldPoint: Offset(52, 41),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(248, 38),
        worldPoint: Offset(248, 38),
        transform: CanvasTransform.identity,
      ),
    );

    final line = controller.elements.whereType<PolylineElement>().single;
    expect(line.points.first, const Offset(50, 40));
    expect(line.startBinding?.elementId, 'widget-1');
    expect(line.startBinding?.anchorId, 'center');

    controller
      ..setTool(SelectTool.idValue)
      ..setSelection({'widget-1'});
    controller.moveSelected(const Offset(20, 10), record: false);

    final movedLine = controller.elementById(line.id) as PolylineElement;
    expect(movedLine.points.first, const Offset(70, 50));
    expect(movedLine.points.last, const Offset(250, 40));
  });

  test('snap bindings are serialized and restored', () {
    const line = LineElement(
      id: 'line-1',
      start: Offset(50, 40),
      end: Offset(250, 40),
      startBinding: SnapBinding(elementId: 'widget-1', anchorId: 'center'),
      endBinding: SnapBinding(elementId: 'rect-1', anchorId: 'center'),
    );

    final restored =
        CanvasSerializer.elementFromJson(line.toJson()) as LineElement;

    expect(restored.startBinding?.elementId, 'widget-1');
    expect(restored.startBinding?.anchorId, 'center');
    expect(restored.endBinding?.elementId, 'rect-1');
    expect(restored.endBinding?.anchorId, 'center');
  });
  test('select tool drags line endpoint and updates binding', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(thresholdScreenPx: 12),
    );
    controller
      ..addElement(
        const RectElement(id: 'rect-1', rect: Rect.fromLTWH(200, 0, 100, 80)),
        record: false,
      )
      ..addElement(
        const LineElement(
          id: 'line-1',
          start: Offset(0, 0),
          end: Offset(100, 0),
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue)
      ..setSelection({'line-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(100, 0),
        worldPoint: Offset(100, 0),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(248, 38),
        worldPoint: Offset(248, 38),
        transform: CanvasTransform.identity,
        delta: Offset(148, 38),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(248, 38),
        worldPoint: Offset(248, 38),
        transform: CanvasTransform.identity,
      ),
    );

    final line = controller.elementById('line-1') as LineElement;
    expect(line.start, const Offset(0, 0));
    expect(line.end, const Offset(250, 40));
    expect(line.endBinding?.elementId, 'rect-1');
    expect(line.endBinding?.anchorId, 'center');
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(
      (controller.elementById('line-1') as LineElement).end,
      const Offset(100, 0),
    );
  });

  test('select tool drags arrow start endpoint freely', () {
    final controller = CanvasController()
      ..addElement(
        const ArrowElement(
          id: 'arrow-1',
          start: Offset(0, 0),
          end: Offset(100, 0),
          startBinding: SnapBinding(elementId: 'old', anchorId: 'center'),
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue)
      ..setSelection({'arrow-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(0, 0),
        worldPoint: Offset(0, 0),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(-20, 30),
        worldPoint: Offset(-20, 30),
        transform: CanvasTransform.identity,
        delta: Offset(-20, 30),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(-20, 30),
        worldPoint: Offset(-20, 30),
        transform: CanvasTransform.identity,
      ),
    );

    final arrow = controller.elementById('arrow-1') as ArrowElement;
    expect(arrow.start, const Offset(-20, 30));
    expect(arrow.end, const Offset(100, 0));
    expect(arrow.startBinding, isNull);
  });
}
