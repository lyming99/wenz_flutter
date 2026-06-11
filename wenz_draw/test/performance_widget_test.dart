// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

/// A minimal widget builder used for stress testing.  Each instance renders a
/// thin colored border + a small label so we can visually verify placement.
class PerfBoxBuilder extends WidgetElementBuilder {
  const PerfBoxBuilder();

  static int buildCount = 0;
  static int previewCount = 0;

  static void reset() {
    buildCount = 0;
    previewCount = 0;
  }

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    buildCount++;
    final colorValue =
        int.tryParse(element.widgetData['color'] as String? ?? '0xFFE5E7EB') ??
        0xFFE5E7EB;
    final label = element.widgetData['label'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Color(colorValue),
        border: Border.all(color: const Color(0x33000000)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: Color(0xFF374151)),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  @override
  Widget buildPreview(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    previewCount++;
    return super.buildPreview(context, element, canvas: canvas);
  }
}

void main() {
  // -----------------------------------------------------------------
  // Helper: create 500 elements arranged in a grid.
  // -----------------------------------------------------------------
  List<CanvasWidgetElement> _make500Elements({
    double cellWidth = 80,
    double cellHeight = 48,
    int columns = 25,
    int rows = 20,
  }) {
    final elements = <CanvasWidgetElement>[];
    final rng = math.Random(42); // deterministic
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final id = 'perf-${row * columns + col}';
        final x = col * (cellWidth + 4);
        final y = row * (cellHeight + 4);
        // Pick a random light pastel hue for visual variety.
        final hue = rng.nextInt(360);
        final color = HSLColor.fromAHSL(
          0.9,
          hue.toDouble(),
          0.5,
          0.85,
        ).toColor().toARGB32();

        elements.add(
          CanvasWidgetElement(
            id: id,
            worldRect: Rect.fromLTWH(x, y, cellWidth, cellHeight),
            widgetType: 'perf_box',
            widgetData: {
              'color':
                  '0x${color.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              'label': '$col,$row',
            },
            zIndex: row * columns + col,
            scaleMode: CanvasWidgetScaleMode.layoutScale,
          ),
        );
      }
    }
    return elements;
  }

  // -----------------------------------------------------------------
  // 1) Pure data-layer performance (no widget tree).
  // -----------------------------------------------------------------
  group('Data-layer: 500-element stress', () {
    test('add 500 elements timed', () {
      final controller = CanvasController();
      final elements = _make500Elements();

      final stopwatch = Stopwatch()..start();
      for (final e in elements) {
        controller.addElement(e, record: false);
      }
      stopwatch.stop();

      expect(controller.elements.length, 500);
      // Should be well under 500 ms on any modern machine.
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      print('  -> Added 500 elements in ${stopwatch.elapsedMilliseconds} ms');
    });

    test('hit-testing 500 stacked elements', () {
      final controller = CanvasController();
      final elements = _make500Elements(
        columns: 1,
        rows: 500,
      ); // vertical stack
      for (final e in elements) {
        controller.addElement(e, record: false);
      }

      // Hit at a point that overlaps every element (they're all stacked).
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        controller.hitTest(const Offset(40, 24));
      }
      stopwatch.stop();
      final avgUs = (stopwatch.elapsedMicroseconds / 100).toStringAsFixed(0);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      print(
        '  -> 100 hit-tests on 500 stacked elements: '
        '${stopwatch.elapsedMilliseconds} ms ($avgUs us avg)',
      );
    });

    test('viewport culling: only visible elements returned', () {
      final controller = CanvasController();
      final elements = _make500Elements();
      for (final e in elements) {
        controller.addElement(e, record: false);
      }

      // A viewport that covers only the first 3 columns x 3 rows.
      final viewport = const Rect.fromLTWH(0, 0, 250, 150);
      final visible = controller
          .orderedElements(visibleOnly: true)
          .where((e) => e.bounds.overlaps(viewport))
          .toList();

      expect(visible.length, lessThan(500));
      print('  -> Viewport (250x150) sees ${visible.length} / 500 elements');
    });

    test('shared spatial index keeps 500-element culling stable', () {
      final elements = _make500Elements();
      const viewport = Rect.fromLTWH(0, 0, 250, 150);
      final stopwatch = Stopwatch()..start();

      var visible = const <CanvasElement>[];
      for (var i = 0; i < 100; i++) {
        visible = ViewportCulling.visibleElements(elements, viewport).toList();
      }
      stopwatch.stop();

      expect(visible.length, lessThan(500));
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      print(
        '  -> 100 indexed viewport queries over 500 elements: '
        '${stopwatch.elapsedMilliseconds} ms (${visible.length} visible)',
      );
    });

    test('serialize / deserialize 500 elements', () {
      final controller = CanvasController();
      for (final e in _make500Elements()) {
        controller.addElement(e, record: false);
      }

      final stopwatch = Stopwatch()..start();
      final json = CanvasSerializer.toJson(controller);
      final doc = CanvasSerializer.fromJson(json);
      stopwatch.stop();

      expect(doc.elements.length, 500);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      print(
        '  -> Serialize + deserialize 500 elements in '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    });

    test('undo stack stays within bounds', () {
      final controller = CanvasController();
      final elements = _make500Elements();

      for (final e in elements) {
        controller.addElement(e); // with history recording
      }

      // After 500 individual adds the undo stack should be pruned.
      expect(controller.canUndo, isTrue);
      final undoCount = _countUndos(controller);
      print('  -> Undo stack depth after 500 adds: $undoCount');
      // Should have been capped (default is usually 50-100).
      expect(undoCount, lessThanOrEqualTo(200));
    });
  });

  // -----------------------------------------------------------------
  // 2) Full widget-tree performance tests.
  // -----------------------------------------------------------------
  group('Widget-tree: 500-element render', () {
    // Ensure the builder is registered before widget tests run.
    setUpAll(() {
      WidgetElementRegistry.register('perf_box', const PerfBoxBuilder());
      PerfBoxBuilder.reset();
    });

    tearDownAll(() {
      WidgetElementRegistry.unregister('perf_box');
    });

    testWidgets(
      'uses preview LOD instead of full widget builds at default zoom',
      (tester) async {
        final canvasController = CanvasController();
        final viewController = InfiniteCanvasController(
          canvasController: canvasController,
        );

        for (final e in _make500Elements()) {
          canvasController.addElement(e, record: false);
        }
        PerfBoxBuilder.reset();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteCanvasWidget(
                controller: viewController,
                config: const InfiniteCanvasConfig(gridType: GridType.none),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(PerfBoxBuilder.buildCount, 0);
        expect(PerfBoxBuilder.previewCount, greaterThan(0));
      },
    );

    testWidgets('initial layout with 500 widgets does not crash', (
      tester,
    ) async {
      final canvasController = CanvasController();
      final viewController = InfiniteCanvasController(
        canvasController: canvasController,
      );

      // Add all elements BEFORE mounting the widget so we measure "first-load".
      for (final e in _make500Elements()) {
        canvasController.addElement(e, record: false);
      }

      // Profiling: wrap pump in a measured scope.
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvasWidget(
              controller: viewController,
              config: const InfiniteCanvasConfig(
                gridType: GridType.none,
                backgroundColor: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );

      // Allow the post-frame snapshot captures to settle.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      stopwatch.stop();

      // The key assertion: no exceptions were thrown.
      expect(tester.takeException(), isNull);
      // The widget tree should still be alive.
      expect(viewController.viewportSize, isNotNull);

      print(
        '  -> First-frame layout + 2 pump cycles with 500 elements: '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    });

    testWidgets('scroll/pan performance with 500 widgets', (tester) async {
      final canvasController = CanvasController();
      final viewController = InfiniteCanvasController(
        canvasController: canvasController,
      );

      for (final e in _make500Elements()) {
        canvasController.addElement(e, record: false);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvasWidget(
              controller: viewController,
              config: const InfiniteCanvasConfig(
                gridType: GridType.none,
                backgroundColor: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Simulate pan gestures.
      final stopwatch = Stopwatch()..start();

      final panGesture = await tester.startGesture(const Offset(300, 300));
      for (double dx = 0; dx < 2000; dx += 50) {
        await panGesture.moveBy(const Offset(-50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await panGesture.up();
      await tester.pump(const Duration(seconds: 1));

      stopwatch.stop();

      expect(tester.takeException(), isNull);
      print(
        '  -> Pan across 2000 world-units with 500 elements: '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    });

    testWidgets('zoom performance with 500 widgets', (tester) async {
      final canvasController = CanvasController();
      final viewController = InfiniteCanvasController(
        canvasController: canvasController,
      );

      for (final e in _make500Elements()) {
        canvasController.addElement(e, record: false);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvasWidget(
              controller: viewController,
              config: const InfiniteCanvasConfig(
                gridType: GridType.none,
                backgroundColor: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final stopwatch = Stopwatch()..start();

      // Zoom in and out in steps.
      for (int i = 0; i < 10; i++) {
        viewController.zoomIn();
        await tester.pump(const Duration(milliseconds: 32));
      }
      for (int i = 0; i < 10; i++) {
        viewController.zoomOut();
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pump(const Duration(seconds: 1));

      stopwatch.stop();

      expect(tester.takeException(), isNull);
      print(
        '  -> Zoom in/out x10 with 500 elements: '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    });

    testWidgets(
      'full-frame rasterization timing',
      (tester) async {
        final canvasController = CanvasController();
        final viewController = InfiniteCanvasController(
          canvasController: canvasController,
        );

        for (final e in _make500Elements()) {
          canvasController.addElement(e, record: false);
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteCanvasWidget(
                controller: viewController,
                config: const InfiniteCanvasConfig(
                  gridType: GridType.none,
                  backgroundColor: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Measure how long a single frame takes to rasterize.
        final durations = <Duration>[];

        for (int i = 0; i < 5; i++) {
          final stopwatch = Stopwatch()..start();
          await tester.pump(const Duration(milliseconds: 16));
          stopwatch.stop();
          durations.add(stopwatch.elapsed);
        }

        final avgMs =
            (durations.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
                    durations.length /
                    1000)
                .toStringAsFixed(1);

        print('  -> Avg pump() time across 5 frames: $avgMs ms');
        // On a reasonable machine this should be well under 100 ms per pump
        // (pump includes the full build/layout/paint/composite cycle).
        expect(tester.takeException(), isNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Count how many undo steps are available by actually stepping through them.
int _countUndos(CanvasController controller) {
  int count = 0;
  while (controller.canUndo) {
    controller.undo();
    count++;
  }
  return count;
}
