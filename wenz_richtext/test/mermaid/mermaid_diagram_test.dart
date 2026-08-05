import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'mermaid_fixtures.dart';

Widget _diagramHost(
  MermaidRenderResult result, {
  MermaidRenderDiagnostics? diagnostics,
  ValueChanged<String>? onNodeTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: MermaidDiagram(
          result: result,
          diagnostics: diagnostics,
          onNodeTap: onNodeTap,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DefaultNativeMermaidRenderService();
  var requestNumber = 0;

  tearDownAll(service.dispose);

  Future<MermaidRenderOutcome> render(String source) {
    return service.render(
      MermaidRenderRequest(
        source: source,
        sourceDigest: mermaidSourceDigest(source),
        theme: MermaidRenderTheme(
          key: 'diagram-test',
          style: MermaidStyle.dark(),
        ),
        viewport: const Size(800, 450),
        limits: const MermaidRenderLimits(),
        requestId: 'diagram-${requestNumber++}',
      ),
    );
  }

  group('MermaidDiagram precomputed painter', () {
    for (final fixture in supportedMermaidFixtures) {
      testWidgets('paints ${fixture.name} without parsing in the widget', (
        tester,
      ) async {
        final outcome = await tester.runAsync(() => render(fixture.cjk));
        expect(outcome, isA<MermaidRenderResult>());
        final result = outcome as MermaidRenderResult;

        await tester.pumpWidget(_diagramHost(result));
        await tester.pump();

        final widget = tester.widget<MermaidDiagram>(
          find.byType(MermaidDiagram),
        );
        expect(widget.result, same(result));
        expect(widget.result.diagramType, fixture.type);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('exposes diagram type and cardinalities through Semantics', (
      tester,
    ) async {
      final result = await tester.runAsync(
        () => render('flowchart TD\n  A --> B'),
      ) as MermaidRenderResult;

      await tester.pumpWidget(_diagramHost(result));
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp('Mermaid 流程图，2 个节点，1 条连线')),
        findsOneWidget,
      );
    });

    testWidgets('reports privacy-safe paint timing', (tester) async {
      final result = await tester.runAsync(
        () => render('mindmap\n  root((根))\n    child[子节点]'),
      ) as MermaidRenderResult;
      final events = <MermaidRenderDiagnosticEvent>[];

      await tester.pumpWidget(
        _diagramHost(result, diagnostics: events.add),
      );
      await tester.pump();

      final paintEvents = events
          .where((event) => event.stage == MermaidRenderStage.paint)
          .toList(growable: false);
      expect(paintEvents, isNotEmpty);
      expect(paintEvents.last.diagramType, DiagramType.mindmap);
      expect(paintEvents.last.nodeCount, 2);
    });

    testWidgets('node hit testing consumes laid-out coordinates',
        (tester) async {
      final result = await tester.runAsync(
        () => render('flowchart TD\n  A[开始] --> B[结束]'),
      ) as MermaidRenderResult;
      String? tapped;

      await tester.pumpWidget(
        _diagramHost(result, onNodeTap: (nodeId) => tapped = nodeId),
      );
      await tester.pump();

      final first = result.diagram.nodes.first;
      final origin = tester.getTopLeft(find.byType(MermaidDiagram));
      await tester.tapAt(
        origin + Offset(first.x + first.width / 2, first.y + first.height / 2),
      );

      expect(tapped, first.id);
    });

    test('unsupported types fail before a painter can be constructed',
        () async {
      final outcome = await render('classDiagram\n  class Foo');

      expect(outcome, isA<MermaidRenderFailure>());
      expect((outcome as MermaidRenderFailure).code,
          MermaidRenderErrorCode.unsupportedType);
    });
  });
}
