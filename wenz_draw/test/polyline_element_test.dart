import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('orthogonal router creates right-angle polyline', () {
    final points = OrthogonalRouter.route(
      start: Offset.zero,
      end: const Offset(100, 60),
    );

    expect(points.first, Offset.zero);
    expect(points.last, const Offset(100, 60));
    expect(points.length, greaterThanOrEqualTo(3));
    for (var i = 0; i < points.length - 1; i++) {
      expect(
        points[i].dx == points[i + 1].dx || points[i].dy == points[i + 1].dy,
        isTrue,
      );
    }
  });

  test('orthogonal router avoids intermediate obstacles with extra bends', () {
    final obstacle = Rect.fromLTWH(40, -20, 40, 40);
    final points = OrthogonalRouter.route(
      start: Offset.zero,
      end: const Offset(120, 0),
      obstacles: [obstacle],
      margin: 8,
    );

    expect(points.first, Offset.zero);
    expect(points.last, const Offset(120, 0));
    expect(points.length, greaterThanOrEqualTo(4));
    for (var i = 0; i < points.length - 1; i++) {
      expect(
        points[i].dx == points[i + 1].dx || points[i].dy == points[i + 1].dy,
        isTrue,
      );
      expect(
        OrthogonalRouter.segmentIntersectsRectInterior(
          points[i],
          points[i + 1],
          obstacle,
        ),
        isFalse,
      );
    }
  });

  test('orthogonal router exits bound elements before routing', () {
    const source = Rect.fromLTWH(0, 0, 100, 80);
    const target = Rect.fromLTWH(200, 0, 100, 80);
    final points = OrthogonalRouter.route(
      start: source.center,
      end: target.center,
      sourceBounds: source,
      targetBounds: target,
      margin: 8,
    );

    expect(points.first, source.center);
    expect(points.last, target.center);
    expect(points.length, greaterThanOrEqualTo(4));
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      if (i > 0) {
        expect(
          OrthogonalRouter.segmentIntersectsRectInterior(
            a,
            b,
            source.inflate(8),
          ),
          isFalse,
        );
      }
      if (i < points.length - 2) {
        expect(
          OrthogonalRouter.segmentIntersectsRectInterior(
            a,
            b,
            target.inflate(8),
          ),
          isFalse,
        );
      }
    }
  });

  test('orthogonal router avoids nearby element blocking bound components', () {
    const source = Rect.fromLTWH(0, 0, 100, 80);
    const target = Rect.fromLTWH(220, 0, 100, 80);
    const obstacle = Rect.fromLTWH(130, 20, 60, 60);
    final points = OrthogonalRouter.route(
      start: source.center,
      end: target.center,
      sourceBounds: source,
      targetBounds: target,
      obstacles: const [obstacle],
      margin: 8,
    );

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      expect(
        OrthogonalRouter.segmentIntersectsRectInterior(
          a,
          b,
          obstacle.inflate(8),
        ),
        isFalse,
      );
      if (i > 0) {
        expect(
          OrthogonalRouter.segmentIntersectsRectInterior(
            a,
            b,
            source.inflate(8),
          ),
          isFalse,
        );
      }
      if (i < points.length - 2) {
        expect(
          OrthogonalRouter.segmentIntersectsRectInterior(
            a,
            b,
            target.inflate(8),
          ),
          isFalse,
        );
      }
    }
  });

  test('orthogonal router chooses the shortest valid avoiding route', () {
    const obstacle = Rect.fromLTWH(40, -10, 40, 20);
    final points = OrthogonalRouter.route(
      start: Offset.zero,
      end: const Offset(120, 0),
      obstacles: const [obstacle],
      margin: 10,
    );

    expect(_pathLength(points), 160);
    for (var i = 0; i < points.length - 1; i++) {
      expect(
        OrthogonalRouter.segmentIntersectsRectInterior(
          points[i],
          points[i + 1],
          obstacle.inflate(10),
        ),
        isFalse,
      );
    }
  });

  test('polyline element bounds hitTest translate and scale', () {
    const element = PolylineElement(
      id: 'poly-1',
      points: [Offset(0, 0), Offset(50, 0), Offset(50, 40)],
      style: PaintStyle(strokeWidth: 2),
    );

    expect(element.bounds, const Rect.fromLTRB(-1, -1, 51, 41));
    expect(element.hitTest(const Offset(25, 1), tolerance: 2), isTrue);
    expect(element.hitTest(const Offset(25, 20), tolerance: 2), isFalse);

    final moved = element.translate(const Offset(10, 5));
    expect(moved.start, const Offset(10, 5));
    expect(moved.end, const Offset(60, 45));

    final scaled = element.scaleElement(2, pivot: Offset.zero);
    expect(scaled.points.last, const Offset(100, 80));
    expect(scaled.style.strokeWidth, 4);
  });

  test('polyline tool creates orthogonal route with snap bindings', () {
    final controller = CanvasController(
      snapSettings: const SnapSettings(thresholdScreenPx: 12),
    );
    controller
      ..addElement(
        const RectElement(id: 'source', rect: Rect.fromLTWH(0, 0, 100, 80)),
        record: false,
      )
      ..addElement(
        const RectElement(id: 'target', rect: Rect.fromLTWH(200, 0, 100, 80)),
        record: false,
      )
      ..setTool(PolylineTool.idValue);

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

    final polyline = controller.elements.whereType<PolylineElement>().single;
    expect(polyline.start, const Offset(50, 40));
    expect(polyline.end, const Offset(250, 40));
    expect(polyline.startBinding?.elementId, 'source');
    expect(polyline.endBinding?.elementId, 'target');
    for (var i = 0; i < polyline.points.length - 1; i++) {
      expect(
        polyline.points[i].dx == polyline.points[i + 1].dx ||
            polyline.points[i].dy == polyline.points[i + 1].dy,
        isTrue,
      );
    }
  });

  test('polyline tool routes around existing canvas elements', () {
    final obstacle = Rect.fromLTWH(90, 20, 60, 60);
    final controller = CanvasController()
      ..addElement(RectElement(id: 'obstacle', rect: obstacle), record: false)
      ..setTool(PolylineTool.idValue);

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(0, 50),
        worldPoint: Offset(0, 50),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(220, 50),
        worldPoint: Offset(220, 50),
        transform: CanvasTransform.identity,
      ),
    );

    final polyline = controller.elements.whereType<PolylineElement>().single;
    expect(polyline.points.length, greaterThanOrEqualTo(4));
    for (var i = 0; i < polyline.points.length - 1; i++) {
      expect(
        OrthogonalRouter.segmentIntersectsRectInterior(
          polyline.points[i],
          polyline.points[i + 1],
          obstacle,
        ),
        isFalse,
      );
    }
  });

  test('polyline serializes and exports to svg', () {
    const element = PolylineElement(
      id: 'poly-1',
      points: [Offset(0, 0), Offset(50, 0), Offset(50, 40)],
      startBinding: SnapBinding(elementId: 'a', anchorId: 'center'),
      endBinding: SnapBinding(elementId: 'b', anchorId: 'center'),
    );

    final restored =
        CanvasSerializer.elementFromJson(element.toJson()) as PolylineElement;
    expect(restored.points, element.points);
    expect(restored.startBinding?.elementId, 'a');
    expect(restored.endBinding?.elementId, 'b');

    final svg = SvgExporter.exportElements(
      elements: const [element],
      bounds: const Rect.fromLTWH(0, 0, 100, 80),
    );
    expect(svg, contains('<polyline'));
    expect(svg, contains('0.0,0.0 50.0,0.0 50.0,40.0'));
  });

  test('polyline middle point drag adjusts adjacent orthogonal segments', () {
    final controller = CanvasController()
      ..addElement(
        const PolylineElement(
          id: 'poly-1',
          points: [Offset(0, 0), Offset(50, 0), Offset(50, 40)],
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue)
      ..setSelection({'poly-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(50, 0),
        worldPoint: Offset(50, 0),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(80, 15),
        worldPoint: Offset(80, 15),
        transform: CanvasTransform.identity,
        delta: Offset(30, 15),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(80, 15),
        worldPoint: Offset(80, 15),
        transform: CanvasTransform.identity,
      ),
    );

    final polyline = controller.elementById('poly-1') as PolylineElement;
    expect(polyline.points, const [
      Offset(0, 0),
      Offset(80, 0),
      Offset(80, 40),
    ]);
    expect(controller.historyManager.canUndo, isTrue);
  });

  test(
    'polyline endpoint drag keeps orthogonal route and nearby avoidance',
    () {
      final obstacle = Rect.fromLTWH(50, 20, 40, 40);
      final controller = CanvasController()
        ..addElement(RectElement(id: 'obstacle', rect: obstacle), record: false)
        ..addElement(
          const PolylineElement(
            id: 'poly-1',
            points: [Offset(0, 0), Offset(50, 0), Offset(50, 40)],
          ),
          record: false,
        )
        ..setTool(SelectTool.idValue)
        ..setSelection({'poly-1'});

      controller.dispatchCanvasEvent(
        const CanvasPointerDownEvent(
          screenPoint: Offset(50, 40),
          worldPoint: Offset(50, 40),
          transform: CanvasTransform.identity,
        ),
      );
      controller.dispatchCanvasEvent(
        const CanvasPointerMoveEvent(
          screenPoint: Offset(120, 40),
          worldPoint: Offset(120, 40),
          transform: CanvasTransform.identity,
          delta: Offset(70, 0),
        ),
      );
      controller.dispatchCanvasEvent(
        const CanvasPointerUpEvent(
          screenPoint: Offset(120, 40),
          worldPoint: Offset(120, 40),
          transform: CanvasTransform.identity,
        ),
      );

      final polyline = controller.elementById('poly-1') as PolylineElement;
      expect(polyline.start, Offset.zero);
      expect(polyline.end, const Offset(120, 40));
      for (var i = 0; i < polyline.points.length - 1; i++) {
        expect(
          polyline.points[i].dx == polyline.points[i + 1].dx ||
              polyline.points[i].dy == polyline.points[i + 1].dy,
          isTrue,
        );
        expect(
          OrthogonalRouter.segmentIntersectsRectInterior(
            polyline.points[i],
            polyline.points[i + 1],
            obstacle.inflate(16),
          ),
          isFalse,
        );
      }
    },
  );
}

double _pathLength(List<Offset> points) {
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += (points[i + 1] - points[i]).distance;
  }
  return total;
}
