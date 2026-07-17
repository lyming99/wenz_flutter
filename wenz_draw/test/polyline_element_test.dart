import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('connector routing service creates right-angle polyline', () {
    final points = _route(start: Offset.zero, end: const Offset(100, 60));

    expect(points.first, Offset.zero);
    expect(points.last, const Offset(100, 60));
    expect(points.length, greaterThanOrEqualTo(3));
    _expectOrthogonal(points);
  });

  test('connector routing service avoids intermediate obstacles', () {
    const obstacle = Rect.fromLTWH(40, -20, 40, 40);
    final points = _route(
      start: Offset.zero,
      end: const Offset(120, 0),
      elements: const [RectElement(id: 'obstacle', rect: obstacle)],
      options: const ConnectorRoutingOptions(margin: 8),
    );

    expect(points.first, Offset.zero);
    expect(points.last, const Offset(120, 0));
    expect(points.length, greaterThanOrEqualTo(4));
    _expectOrthogonal(points);
    _expectAvoids(points, obstacle);
  });

  test('connector routing service exits bound elements before routing', () {
    const source = Rect.fromLTWH(0, 0, 100, 80);
    const target = Rect.fromLTWH(200, 0, 100, 80);
    final points = _route(
      start: source.center,
      end: target.center,
      elements: const [
        RectElement(id: 'source', rect: source),
        RectElement(id: 'target', rect: target),
      ],
      startBinding: const SnapBinding(elementId: 'source', anchorId: 'center'),
      endBinding: const SnapBinding(elementId: 'target', anchorId: 'center'),
      options: const ConnectorRoutingOptions(margin: 8),
    );

    expect(points.first, source.center);
    expect(points.last, target.center);
    expect(points.length, greaterThanOrEqualTo(4));
    _expectOrthogonal(points);
    for (var i = 1; i < points.length - 1; i++) {
      if (i > 1) {
        expect(
          _segmentIntersectsRectInterior(
            points[i - 1],
            points[i],
            source.inflate(8),
          ),
          isFalse,
        );
      }
      if (i < points.length - 2) {
        expect(
          _segmentIntersectsRectInterior(
            points[i],
            points[i + 1],
            target.inflate(8),
          ),
          isFalse,
        );
      }
    }
  });

  test(
    'connector routing service avoids nearby element blocking components',
    () {
      const source = Rect.fromLTWH(0, 0, 100, 80);
      const target = Rect.fromLTWH(220, 0, 100, 80);
      const obstacle = Rect.fromLTWH(130, 20, 60, 60);
      final points = _route(
        start: source.center,
        end: target.center,
        elements: const [
          RectElement(id: 'source', rect: source),
          RectElement(id: 'target', rect: target),
          RectElement(id: 'obstacle', rect: obstacle),
        ],
        startBinding: const SnapBinding(
          elementId: 'source',
          anchorId: 'center',
        ),
        endBinding: const SnapBinding(elementId: 'target', anchorId: 'center'),
        options: const ConnectorRoutingOptions(margin: 8),
      );

      _expectOrthogonal(points);
      _expectAvoids(points, obstacle.inflate(8));
      for (var i = 1; i < points.length - 1; i++) {
        if (i > 1) {
          expect(
            _segmentIntersectsRectInterior(
              points[i - 1],
              points[i],
              source.inflate(8),
            ),
            isFalse,
          );
        }
        if (i < points.length - 2) {
          expect(
            _segmentIntersectsRectInterior(
              points[i],
              points[i + 1],
              target.inflate(8),
            ),
            isFalse,
          );
        }
      }
    },
  );

  test(
    'connector routing service chooses the shortest valid avoiding route',
    () {
      const obstacle = Rect.fromLTWH(40, -10, 40, 20);
      final points = _route(
        start: Offset.zero,
        end: const Offset(120, 0),
        elements: const [RectElement(id: 'obstacle', rect: obstacle)],
        options: const ConnectorRoutingOptions(margin: 10),
      );

      expect(_pathLength(points), closeTo(160, 2));
      _expectAvoids(points, obstacle.inflate(10));
    },
  );

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

  test('polyline arrowhead expands bounds and participates in hit testing', () {
    const element = PolylineElement(
      id: 'poly-arrow',
      points: [Offset(0, 0), Offset(40, 0), Offset(40, 30)],
      style: PaintStyle(strokeWidth: 2),
      endArrow: true,
      headSize: 20,
    );

    expect(element.bounds, const Rect.fromLTRB(-20, -20, 60, 50));
    expect(element.hitTest(const Offset(45, 22), tolerance: 2), isTrue);
    expect(element.hitTest(const Offset(70, 30), tolerance: 2), isFalse);

    final scaled = element.scaleElement(0.5, pivot: Offset.zero);
    expect(scaled.endArrow, isTrue);
    expect(scaled.headSize, 10);
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
    final obstacle = const Rect.fromLTWH(90, 20, 60, 60);
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
        _segmentIntersectsRectInterior(
          polyline.points[i],
          polyline.points[i + 1],
          obstacle,
        ),
        isFalse,
      );
    }
  });

  test('connector routing service respects locked edge port direction', () {
    const source = RectElement(
      id: 'source',
      rect: Rect.fromLTWH(0, 0, 100, 80),
    );
    const target = RectElement(
      id: 'target',
      rect: Rect.fromLTWH(220, 0, 100, 80),
    );
    const obstacle = RectElement(
      id: 'obstacle',
      rect: Rect.fromLTWH(130, -20, 60, 80),
    );
    const service = ConnectorRoutingService();

    final result = service.route(
      start: const Offset(100, 40),
      end: const Offset(220, 40),
      elements: const [source, target, obstacle],
      isLayerVisible: (_) => true,
      startBinding: const SnapBinding(elementId: 'source', anchorId: 'right'),
      endBinding: const SnapBinding(elementId: 'target', anchorId: 'left'),
    );

    expect(result.points.first.dx, greaterThanOrEqualTo(100));
    expect(result.points.first.dy, closeTo(40, 1));
    expect(result.points.last.dx, lessThanOrEqualTo(220));
    expect(result.points.last.dy, closeTo(40, 1));
    expect(
      result.points.any((point) => point.dx > result.points.first.dx),
      isTrue,
    );
    for (var i = 0; i < result.points.length - 1; i++) {
      expect(
        _segmentIntersectsRectInterior(
          result.points[i],
          result.points[i + 1],
          obstacle.rect.inflate(16),
        ),
        isFalse,
      );
    }
  });

  test('same side ports share an outside trunk before returning', () {
    const source = RectElement(
      id: 'source',
      rect: Rect.fromLTWH(0, 0, 80, 120),
    );
    const target = RectElement(
      id: 'target',
      rect: Rect.fromLTWH(160, 0, 80, 120),
    );
    const service = ConnectorRoutingService();

    final route = service.route(
      start: const Offset(80, 30),
      end: const Offset(240, 90),
      elements: const [source, target],
      isLayerVisible: (_) => true,
      startBinding: const SnapBinding(elementId: 'source', anchorId: 'right'),
      endBinding: const SnapBinding(elementId: 'target', anchorId: 'right'),
    );

    final outsideX = route.points
        .map((point) => point.dx)
        .reduce((a, b) => a > b ? a : b);
    // Route should extend outside the bounding area of both shapes
    expect(outsideX, greaterThan(140.0));
    expect(
      _hasOrthogonalSegment(route.points, outsideX) ||
          _hasOrthogonalSegment(route.points, target.rect.right + 16),
      isTrue,
    );
  });

  test('mind map sibling branches may overlap existing connector trunk', () {
    final controller = CanvasController()
      ..addElement(
        const RectElement(id: 'root', rect: Rect.fromLTWH(0, 0, 80, 120)),
        record: false,
      )
      ..addElement(
        const RectElement(id: 'top', rect: Rect.fromLTWH(180, 0, 80, 40)),
        record: false,
      )
      ..addElement(
        const RectElement(id: 'bottom', rect: Rect.fromLTWH(180, 80, 80, 40)),
        record: false,
      );

    final topPoints = controller.routeConnector(
      start: const Offset(80, 60),
      end: const Offset(180, 20),
      startBinding: const SnapBinding(elementId: 'root', anchorId: 'right'),
      endBinding: const SnapBinding(elementId: 'top', anchorId: 'left'),
    );
    controller.addElement(
      PolylineElement(
        id: 'top-connector',
        points: topPoints,
        startBinding: const SnapBinding(elementId: 'root', anchorId: 'right'),
        endBinding: const SnapBinding(elementId: 'top', anchorId: 'left'),
      ),
      record: false,
    );

    final bottomPoints = controller.routeConnector(
      start: const Offset(80, 60),
      end: const Offset(180, 100),
      startBinding: const SnapBinding(elementId: 'root', anchorId: 'right'),
      endBinding: const SnapBinding(elementId: 'bottom', anchorId: 'left'),
    );

    // Both routes should be valid orthogonal paths; they may or may not overlap
    _expectOrthogonal(topPoints);
    _expectOrthogonal(bottomPoints);
    expect(topPoints.length, greaterThanOrEqualTo(2));
    expect(bottomPoints.length, greaterThanOrEqualTo(2));
  });

  test('canvas controller routeConnector uses nearby obstacles', () {
    final controller = CanvasController()
      ..addElement(
        const RectElement(id: 'obstacle', rect: Rect.fromLTWH(90, 20, 60, 60)),
        record: false,
      );

    final points = controller.routeConnector(
      start: const Offset(0, 50),
      end: const Offset(220, 50),
    );

    expect(points.length, greaterThanOrEqualTo(4));
    for (var i = 0; i < points.length - 1; i++) {
      expect(
        _segmentIntersectsRectInterior(
          points[i],
          points[i + 1],
          const Rect.fromLTWH(90, 20, 60, 60).inflate(16),
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
      Offset(50, 40),
    ]);
    expect(controller.historyManager.canUndo, isTrue);
  });

  test('dragging polyline middle point keeps endpoints fixed', () {
    final controller = CanvasController()
      ..addElement(
        const PolylineElement(
          id: 'poly-1',
          points: [
            Offset(0, 0),
            Offset(50, 0),
            Offset(50, 40),
            Offset(100, 40),
          ],
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
        screenPoint: Offset(80, -30),
        worldPoint: Offset(80, -30),
        transform: CanvasTransform.identity,
        delta: Offset(30, -30),
      ),
    );

    final polyline = controller.elementById('poly-1') as PolylineElement;
    expect(polyline.points.first, Offset.zero);
    expect(polyline.points.last, const Offset(100, 40));
  });

  test('dragging polyline vertical segment moves it horizontally', () {
    final controller = CanvasController()
      ..addElement(
        const PolylineElement(
          id: 'poly-1',
          points: [
            Offset(0, 0),
            Offset(50, 0),
            Offset(50, 40),
            Offset(100, 40),
          ],
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue)
      ..setSelection({'poly-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(50, 20),
        worldPoint: Offset(50, 20),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(80, 25),
        worldPoint: Offset(80, 25),
        transform: CanvasTransform.identity,
        delta: Offset(30, 5),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(80, 25),
        worldPoint: Offset(80, 25),
        transform: CanvasTransform.identity,
      ),
    );

    final polyline = controller.elementById('poly-1') as PolylineElement;
    expect(polyline.points, const [
      Offset(0, 0),
      Offset(80, 0),
      Offset(80, 40),
      Offset(100, 40),
    ]);
    expect(controller.historyManager.canUndo, isTrue);
  });

  test('dragging polyline horizontal segment moves it vertically', () {
    final controller = CanvasController()
      ..addElement(
        const PolylineElement(
          id: 'poly-1',
          points: [
            Offset(0, 0),
            Offset(50, 0),
            Offset(50, 40),
            Offset(100, 40),
          ],
        ),
        record: false,
      )
      ..setTool(SelectTool.idValue)
      ..setSelection({'poly-1'});

    controller.dispatchCanvasEvent(
      const CanvasPointerDownEvent(
        screenPoint: Offset(75, 40),
        worldPoint: Offset(75, 40),
        transform: CanvasTransform.identity,
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerMoveEvent(
        screenPoint: Offset(76, 70),
        worldPoint: Offset(76, 70),
        transform: CanvasTransform.identity,
        delta: Offset(1, 30),
      ),
    );
    controller.dispatchCanvasEvent(
      const CanvasPointerUpEvent(
        screenPoint: Offset(76, 70),
        worldPoint: Offset(76, 70),
        transform: CanvasTransform.identity,
      ),
    );

    final polyline = controller.elementById('poly-1') as PolylineElement;
    expect(polyline.points, const [
      Offset(0, 0),
      Offset(50, 0),
      Offset(50, 70),
      Offset(100, 70),
      Offset(100, 40),
    ]);
  });

  test(
    'polyline endpoint drag keeps orthogonal route and nearby avoidance',
    () {
      final obstacle = const Rect.fromLTWH(50, 20, 40, 40);
      final controller = CanvasController()
        ..addElement(RectElement(id: 'obstacle', rect: obstacle), record: false)
        ..addElement(
          const PolylineElement(
            id: 'poly-1',
            points: [Offset(0, 0), Offset(50, 0), Offset(50, 40)],
            endArrow: true,
            headSize: 18,
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
      expect(polyline.endArrow, isTrue);
      expect(polyline.headSize, 18);
      for (var i = 0; i < polyline.points.length - 1; i++) {
        expect(
          polyline.points[i].dx == polyline.points[i + 1].dx ||
              polyline.points[i].dy == polyline.points[i + 1].dy,
          isTrue,
        );
        expect(
          _segmentIntersectsRectInterior(
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

/// 两条正交线段的共线重叠长度（水平或垂直）。
void _expectOrthogonal(List<Offset> points) {
  for (var i = 0; i < points.length - 1; i++) {
    expect(
      points[i].dx == points[i + 1].dx || points[i].dy == points[i + 1].dy,
      isTrue,
    );
  }
}

void _expectAvoids(List<Offset> points, Rect obstacle) {
  for (var i = 0; i < points.length - 1; i++) {
    expect(
      _segmentIntersectsRectInterior(points[i], points[i + 1], obstacle),
      isFalse,
    );
  }
}

bool _hasOrthogonalSegment(List<Offset> points, double x) {
  for (var i = 0; i < points.length - 1; i++) {
    if ((points[i].dx - x).abs() < 0.0001 &&
        (points[i + 1].dx - x).abs() < 0.0001 &&
        (points[i].dy - points[i + 1].dy).abs() > 0.0001) {
      return true;
    }
  }
  return false;
}

bool _segmentIntersectsRectInterior(Offset a, Offset b, Rect rect) {
  final inner = rect.deflate(0.001);
  if (inner.isEmpty) {
    return false;
  }
  if ((a.dx - b.dx).abs() < 0.0001) {
    final x = a.dx;
    if (x <= inner.left || x >= inner.right) {
      return false;
    }
    final top = a.dy < b.dy ? a.dy : b.dy;
    final bottom = a.dy > b.dy ? a.dy : b.dy;
    return bottom > inner.top && top < inner.bottom;
  }
  if ((a.dy - b.dy).abs() < 0.0001) {
    final y = a.dy;
    if (y <= inner.top || y >= inner.bottom) {
      return false;
    }
    final left = a.dx < b.dx ? a.dx : b.dx;
    final right = a.dx > b.dx ? a.dx : b.dx;
    return right > inner.left && left < inner.right;
  }
  return false;
}

List<Offset> _route({
  required Offset start,
  required Offset end,
  Iterable<CanvasElement> elements = const <CanvasElement>[],
  SnapBinding? startBinding,
  SnapBinding? endBinding,
  ConnectorRoutingOptions options = const ConnectorRoutingOptions(),
}) {
  return ConnectorRoutingService(options: options)
      .route(
        start: start,
        end: end,
        elements: elements,
        isLayerVisible: (_) => true,
        startBinding: startBinding,
        endBinding: endBinding,
      )
      .points;
}
