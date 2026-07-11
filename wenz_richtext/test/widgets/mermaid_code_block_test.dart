import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext/src/mermaid/painter/mindmap_painter.dart';

class _RecordingMermaidRenderer implements MermaidRenderer {
  int renderCount = 0;
  final List<String> sources = <String>[];

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    renderCount++;
    sources.add(source);
    return '<svg></svg>';
  }
}

const _toggleKey = ValueKey<String>('wenz-richtext-mermaid-toggle');

Widget _wrapMermaidBlock({
  required CodeBlockNode block,
  required MermaidDiagramConfig config,
  required MermaidRenderer renderer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 720,
          child: MermaidCodeBlockWidget(
            block: block,
            config: config,
            renderer: renderer,
            blockIndex: 0,
          ),
        ),
      ),
    ),
  );
}

Future<_RecordingMermaidRenderer> _pumpBlock(
  WidgetTester tester, {
  required String code,
  String blockId = 'mermaid',
  MermaidDiagramConfig config = const MermaidDiagramConfig(
    debounce: Duration.zero,
  ),
}) async {
  final renderer = _RecordingMermaidRenderer();
  await tester.pumpWidget(
    _wrapMermaidBlock(
      block: CodeBlockNode(
        id: blockId,
        language: 'mermaid',
        code: code,
      ),
      config: config,
      renderer: renderer,
    ),
  );
  return renderer;
}

Future<void> _showPreview(WidgetTester tester) async {
  await tester.tap(find.byKey(_toggleKey));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('initial state shows source code with line numbers', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A[寮€濮媇 --> B{瀹℃壒}',
    );

    expect(find.textContaining('flowchart TD'), findsOneWidget);
    expect(find.textContaining('A[寮€濮媇 --> B{瀹℃壒}'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.code), findsNothing);
    expect(renderer.renderCount, 0);
  });

  testWidgets('toggle switches to pure Flutter painter preview', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'flowchart LR\n  A[寮€濮媇 -->|閫氳繃| B[缁撴潫]',
    );

    await tester.pump();
    await _showPreview(tester);

    expect(find.textContaining('flowchart LR'), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(MermaidDiagram), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.code), findsOneWidget);
    expect(renderer.renderCount, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pump();

    expect(find.textContaining('flowchart LR'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('mindmap preview routes through MindmapPainter', (tester) async {
    final renderer = await _pumpBlock(
      tester,
      code: '''
mindmap
  root((Root))
    left[Left]
      note(Detail)
    right{{Right}}
''',
    );

    await tester.pump();
    await _showPreview(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(MermaidDiagram), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is MindmapPainter,
      ),
      findsOneWidget,
    );
    expect(renderer.renderCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview request shows loading while debounce is pending', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A --> B',
      config: const MermaidDiagramConfig(
        debounce: Duration(milliseconds: 100),
      ),
    );

    await tester.tap(find.byKey(_toggleKey));
    await tester.pump();

    expect(find.text('姝ｅ湪鍑嗗 Mermaid 棰勮'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(renderer.renderCount, 0);
  });

  testWidgets('empty source preview shows feedback without rendering', (
    tester,
  ) async {
    final renderer = await _pumpBlock(tester, code: '   ');

    await _showPreview(tester);

    expect(find.text('Mermaid 婧愮爜涓虹┖'), findsOneWidget);
    expect(find.text('鏌ョ湅婧愮爜'), findsOneWidget);
    expect(renderer.renderCount, 0);

    await tester.tap(find.text('鏌ョ湅婧愮爜'));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('unsupported syntax surfaces parser error and recovery action', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'classDiagram\n  class Foo',
    );

    await tester.pump();
    await _showPreview(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('classDiagram is not supported'), findsOneWidget);
    expect(find.text('鏌ョ湅婧愮爜'), findsOneWidget);
    expect(renderer.renderCount, 0);

    await tester.tap(find.text('鏌ョ湅婧愮爜'));
    await tester.pump();

    expect(find.textContaining('classDiagram'), findsOneWidget);
  });

  testWidgets(
    'preview refreshes edited source and recovers from empty and errors',
    (tester) async {
      const config = MermaidDiagramConfig(debounce: Duration.zero);
      final renderer = _RecordingMermaidRenderer();

      Future<void> rebuildWithCode(String code) async {
        await tester.pumpWidget(
          _wrapMermaidBlock(
            block: CodeBlockNode(
              id: 'stateful-mermaid',
              language: 'mermaid',
              code: code,
            ),
            config: config,
            renderer: renderer,
          ),
        );
      }

      const initial = 'flowchart TD\n  A --> B';
      const edited = 'flowchart TD\n  A --> C';
      const repaired = 'flowchart TD\n  A --> D';

      await rebuildWithCode(initial);
      await tester.pump();
      await _showPreview(tester);

      expect(
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).code,
        initial,
      );

      await rebuildWithCode(edited);
      expect(find.byType(MermaidDiagram), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).code,
        edited,
      );

      await rebuildWithCode('classDiagram\n  class Foo');
      expect(find.byType(MermaidDiagram), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await rebuildWithCode('   ');
      expect(find.byType(MermaidDiagram), findsNothing);
      expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);

      await rebuildWithCode(repaired);
      expect(find.byType(MermaidDiagram), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).code,
        repaired,
      );

      await tester.tap(find.byKey(_toggleKey));
      await tester.pump();

      expect(find.textContaining('A --> D'), findsOneWidget);
      expect(renderer.renderCount, 0);
    },
  );
  testWidgets('preview does not crash under unbounded height constraints', (
    tester,
  ) async {
    final renderer = _RecordingMermaidRenderer();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Stack(
              children: <Widget>[
                MermaidCodeBlockWidget(
                  block: const CodeBlockNode(
                    id: 'unbounded',
                    language: 'mermaid',
                    code: 'flowchart TD\n  A[Start] --> B[Done]',
                  ),
                  config: const MermaidDiagramConfig(
                    debounce: Duration.zero,
                  ),
                  renderer: renderer,
                  blockIndex: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await _showPreview(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(MermaidDiagram), findsOneWidget);
    expect(renderer.renderCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview viewport keeps a stable 16:9 ratio', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'flowchart LR\n  A[One] --> B[Two] --> C[Three]',
    );

    await tester.pump();
    await _showPreview(tester);

    final viewportSize = tester.getSize(find.byType(InteractiveViewer));
    expect(viewportSize.width, greaterThan(0));
    expect(viewportSize.height, closeTo(viewportSize.width / (16 / 9), 0.5));
    expect(renderer.renderCount, 0);
  });

  testWidgets('preview focuses on pointer input and wheel zooms', (
    tester,
  ) async {
    final renderer = await _pumpBlock(
      tester,
      code: 'flowchart LR\n  A[One] --> B[Two] --> C[Three]',
    );

    await tester.pump();
    await _showPreview(tester);
    await tester.pump();

    final viewerFinder = find.byType(InteractiveViewer);
    await tester.tap(viewerFinder);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'wenz-richtext-mermaid-preview',
    );

    final before = tester
        .widget<InteractiveViewer>(viewerFinder)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(viewerFinder),
        scrollDelta: const Offset(0, -240),
      ),
    );
    await tester.pump();

    final after = tester
        .widget<InteractiveViewer>(viewerFinder)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    expect(after, greaterThan(before));
    expect(renderer.renderCount, 0);
  });
}
