import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/ui/toolbar/tool_button.dart';
import 'package:wenz_draw/src/ui/toolbar/toolbar.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('Toolbar indicator arrow tool', () {
    testWidgets('shows a distinct solid indicator arrow entry', (tester) async {
      final harness = await _pumpToolbar(tester);
      final indicatorArrow = find.byTooltip('标识箭头');

      expect(indicatorArrow, findsOneWidget);
      expect(
        find.descendant(
          of: indicatorArrow,
          matching: find.byIcon(Icons.forward),
        ),
        findsOneWidget,
      );

      await tester.tap(indicatorArrow);
      await tester.pump();

      expect(
        harness.canvasController.currentTool?.id,
        ShapeTool.idFor('arrows.arrowRight'),
      );
      expect(_toolbarButton(tester, '标识箭头').selected, isTrue);
      expect(_toolbarButton(tester, '图形').selected, isFalse);
    });

    testWidgets('creates the arrow shape with current stroke and fill', (
      tester,
    ) async {
      final harness = await _pumpToolbar(tester);
      harness.canvasController.updateBrushSettings(
        const BrushSettings(
          color: Color(0xFF1D4ED8),
          strokeWidth: 3,
          fillColor: Color(0xFFE0F2FE),
        ),
      );

      await tester.tap(find.byTooltip('标识箭头'));
      await tester.pump();

      harness.canvasController.dispatchCanvasEvent(
        const CanvasPointerDownEvent(
          pointer: 1,
          screenPoint: Offset(20, 30),
          worldPoint: Offset(20, 30),
          transform: CanvasTransform.identity,
          buttons: 1,
        ),
      );

      expect(harness.canvasController.previewElement, isA<DrawioShapeElement>());
      expect(
        (harness.canvasController.previewElement! as DrawioShapeElement)
            .shapeKey,
        'arrows.arrowRight',
      );

      harness.canvasController
        ..dispatchCanvasEvent(
          const CanvasPointerMoveEvent(
            pointer: 1,
            screenPoint: Offset(140, 90),
            worldPoint: Offset(140, 90),
            transform: CanvasTransform.identity,
            delta: Offset(120, 60),
            buttons: 1,
          ),
        )
        ..dispatchCanvasEvent(
          const CanvasPointerUpEvent(
            pointer: 1,
            screenPoint: Offset(140, 90),
            worldPoint: Offset(140, 90),
            transform: CanvasTransform.identity,
          ),
        );

      final element = harness.canvasController.elements.single;
      expect(element, isA<DrawioShapeElement>());
      expect(element, isNot(isA<ArrowElement>()));
      final arrowShape = element as DrawioShapeElement;
      expect(arrowShape.shapeKey, 'arrows.arrowRight');
      expect(arrowShape.rect, const Rect.fromLTWH(20, 30, 120, 60));
      expect(arrowShape.strokeStyle.color, const Color(0xFF1D4ED8));
      expect(arrowShape.strokeStyle.strokeWidth, 3);
      expect(arrowShape.fillStyle!.color, const Color(0xFFE0F2FE));
      expect(harness.canvasController.previewElement, isNull);
    });

    testWidgets('keeps selection feedback exclusive across tool switches', (
      tester,
    ) async {
      final harness = await _pumpToolbar(tester);

      await tester.tap(find.byTooltip('标识箭头'));
      await tester.pump();
      await tester.tap(find.byTooltip('选择'));
      await tester.pump();

      expect(harness.canvasController.currentTool?.id, SelectTool.idValue);
      expect(_toolbarButton(tester, '选择').selected, isTrue);
      expect(_toolbarButton(tester, '标识箭头').selected, isFalse);
      expect(_toolbarButton(tester, '图形').selected, isFalse);

      await tester.tap(find.byTooltip('标识箭头'));
      await tester.pump();
      await tester.tap(find.byTooltip('直线'));
      await tester.pump();

      expect(harness.canvasController.currentTool?.id, LineTool.idValue);
      expect(_toolbarButton(tester, '直线').selected, isTrue);
      expect(_toolbarButton(tester, '标识箭头').selected, isFalse);
      expect(_toolbarButton(tester, '图形').selected, isFalse);

      await tester.tap(find.byTooltip('标识箭头'));
      await tester.pump();
      await tester.tap(find.byTooltip('图形'));
      await tester.pump();

      expect(harness.canvasController.currentTool?.id, RectTool.idValue);
      expect(_toolbarButton(tester, '图形').selected, isTrue);
      expect(_toolbarButton(tester, '标识箭头').selected, isFalse);

      harness.canvasController.setTool(ShapeTool.idFor('rhombus'));
      await tester.pump();

      expect(_toolbarButton(tester, '图形').selected, isTrue);
      expect(_toolbarButton(tester, '标识箭头').selected, isFalse);

      harness.canvasController.setTool(EllipseTool.idValue);
      await tester.pump();

      expect(_toolbarButton(tester, '图形').selected, isTrue);
      expect(_toolbarButton(tester, '标识箭头').selected, isFalse);
    });

    testWidgets('remains horizontally accessible in a narrow viewport', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpToolbar(tester);

      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scrollView).scrollDirection,
        Axis.horizontal,
      );

      final scrollable = find.descendant(
        of: scrollView,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      final indicatorArrow = find.byTooltip('标识箭头');
      await tester.ensureVisible(indicatorArrow);
      await tester.pump();
      _expectHorizontallyVisible(tester, indicatorArrow, viewportWidth: 320);

      final layers = find.byTooltip('图层');
      await tester.ensureVisible(layers);
      await tester.pump();
      _expectHorizontallyVisible(tester, layers, viewportWidth: 320);

      expect(position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });

  group('Toolbar component insert menu', () {
    testWidgets('shows mindmap with an icon distinct from curve', (
      tester,
    ) async {
      await _pumpToolbar(tester);

      expect(find.byIcon(Icons.timeline), findsOneWidget);

      await tester.tap(find.byTooltip('特殊组件创建'));
      await tester.pumpAndSettle();

      final mindmapText = find.text('思维导图');
      expect(mindmapText, findsOneWidget);

      final mindmapItem = find.ancestor(
        of: mindmapText,
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String>,
        ),
      );
      expect(mindmapItem, findsOneWidget);
      expect(
        find.descendant(
          of: mindmapItem,
          matching: find.byIcon(Icons.account_tree_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: mindmapItem,
          matching: find.byIcon(Icons.timeline),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('selecting mindmap calls only the mindmap callback', (
      tester,
    ) async {
      final harness = await _pumpToolbar(tester);

      await tester.tap(find.byTooltip('曲线'));
      await tester.pump();

      expect(harness.canvasController.currentTool?.id, CurveTool.idValue);
      expect(find.byIcon(Icons.timeline), findsOneWidget);

      await tester.tap(find.byTooltip('特殊组件创建'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('思维导图'));
      await tester.pumpAndSettle();

      expect(harness.mindmapAdds, 1);
      expect(harness.stickyNoteAdds, 0);
      expect(harness.counterAdds, 0);
      expect(harness.canvasController.currentTool?.id, CurveTool.idValue);
    });
  });
}

ToolButton _toolbarButton(WidgetTester tester, String label) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is ToolButton && widget.label == label,
  );
  expect(finder, findsOneWidget);
  return tester.widget<ToolButton>(finder);
}

void _expectHorizontallyVisible(
  WidgetTester tester,
  Finder finder, {
  required double viewportWidth,
}) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(viewportWidth));
}

Future<_ToolbarHarness> _pumpToolbar(WidgetTester tester) async {
  final harness = _ToolbarHarness();
  addTearDown(harness.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Toolbar(
            canvasController: harness.canvasController,
            viewController: harness.viewController,
            onAddStickyNote: () => harness.stickyNoteAdds++,
            onAddCounter: () => harness.counterAdds++,
            onAddMindmap: () => harness.mindmapAdds++,
            onInsertImage: () => harness.imageInserts++,
          ),
        ),
      ),
    ),
  );

  return harness;
}

class _ToolbarHarness {
  _ToolbarHarness() {
    viewController = InfiniteCanvasController(
      canvasController: canvasController,
    );
  }

  final CanvasController canvasController = CanvasController();
  late final InfiniteCanvasController viewController;
  int stickyNoteAdds = 0;
  int counterAdds = 0;
  int mindmapAdds = 0;
  int imageInserts = 0;

  void dispose() {
    viewController.dispose();
    canvasController.dispose();
  }
}
