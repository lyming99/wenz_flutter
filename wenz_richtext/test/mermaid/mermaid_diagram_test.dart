import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';
import 'package:wenz_richtext/src/mermaid/painter/mindmap_painter.dart';

const Map<String, String> _supportedDiagramSources = <String, String>{
  'flowchart': 'flowchart TD\n  A[Start] --> B[Done]',
  'sequence': 'sequenceDiagram\n  participant A as Alice\n  A->>B: Hello',
  'pie': 'pie\n  title Pets\n  "Dogs" : 386\n  "Cats" : 85',
  'gantt': '''
gantt
  title Plan
  dateFormat YYYY-MM-DD
  section Work
    Task A :a1, 2026-07-01, 2d
''',
  'timeline': 'timeline\n  title History\n  2024 : Alpha',
  'kanban': 'kanban\ntodo[Todo]\n    task1[Write parser]',
  'mindmap': '''
mindmap
  root((Root))
    left[Left]
    right{{Right}}
''',
  'radar': 'radar-beta\naxis A, B, C\ncurve Team{1,2,3}',
  'xy chart': 'xychart-beta\nx-axis [A, B]\ny-axis 0 --> 10\nbar [2, 4]',
};

Widget _diagramHost({
  required String source,
  Widget Function(BuildContext context, String error)? errorBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 640,
          height: 420,
          child: MermaidDiagram(
            code: source,
            style: MermaidStyle.dark(),
            enableResponsive: false,
            errorBuilder: errorBuilder,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MermaidDiagram pure Flutter painter', () {
    for (final entry in _supportedDiagramSources.entries) {
      testWidgets('paints ${entry.key} diagrams with CustomPaint', (
        tester,
      ) async {
        await tester.pumpWidget(_diagramHost(source: entry.value));
        await tester.pump();

        expect(find.byType(MermaidDiagram), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('uses MindmapPainter for mindmap diagrams', (tester) async {
      await tester.pumpWidget(
        _diagramHost(
          source: '''
mindmap
  root((Root))
    left[Left]
      note(Detail)
    right{{Right}}
''',
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is MindmapPainter,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses errorBuilder for unsupported diagrams', (tester) async {
      var reportedError = '';

      await tester.pumpWidget(
        _diagramHost(
          source: 'classDiagram\n  class Foo',
          errorBuilder: (context, error) {
            reportedError = error;
            return Text('mermaid-error:$error');
          },
        ),
      );
      await tester.pump();

      expect(find.textContaining('mermaid-error:'), findsOneWidget);
      expect(reportedError, contains('classDiagram'));
      expect(tester.takeException(), isNull);
    });
  });
}
