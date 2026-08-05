import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'mermaid_fixtures.dart';

void main() {
  const parser = MermaidParser();

  group('MermaidParser current supported syntax', () {
    for (final fixture in supportedMermaidFixtures) {
      test('${fixture.name} parses minimum, CJK/emoji, and long text', () {
        for (final source in <String>[
          fixture.minimum,
          fixture.cjk,
          fixture.longText,
        ]) {
          final result = parser.parseWithData(source);
          expect(result, isNotNull, reason: '${fixture.name}: $source');
          expect(result!.diagram.type, fixture.type);
        }
      });
    }

    test('flowchart preserves Chinese labels, emoji, subgraphs, and classes',
        () {
      const source = '''
flowchart LR
  subgraph stage[销售阶段]
    A[开始 🚀] -->|通过| B{审批}
  end
  B -->|否| C[补充资料]
  classDef risk fill:#f96,stroke:#333,color:#111
  class C risk
''';
      final result = parser.parseWithData(source)!;
      final diagram = result.diagram;

      expect(diagram.direction, DiagramDirection.leftToRight);
      expect(diagram.getNode('A')?.label, '开始 🚀');
      expect(diagram.getNode('B')?.shape, NodeShape.diamond);
      expect(diagram.getNode('C')?.className, 'risk');
      expect(diagram.subgraphs.single.label, '销售阶段');
      expect(
          diagram.edges.map((edge) => edge.label),
          containsAll(<String?>[
            '通过',
            '否',
          ]));
    });

    test('CRLF input parses without changing labels', () {
      const source =
          'sequenceDiagram\r\n  participant U as 用户 👋\r\n  U->>S: 创建订单\r\n  S-->>U: 已确认';
      final result = parser.parseWithData(source);

      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.sequence);
      expect(result.diagram.nodes.map((node) => node.label), contains('用户 👋'));
      expect(
        result.diagram.edges.map((edge) => edge.label),
        containsAll(<String?>['创建订单', '已确认']),
      );
    });

    test('type-specific payloads remain available for all chart painters', () {
      final byType = <DiagramType, MermaidParseResult>{
        for (final fixture in supportedMermaidFixtures)
          fixture.type: parser.parseWithData(fixture.minimum)!,
      };

      expect(byType[DiagramType.pieChart]!.pieChartData, isNotNull);
      expect(byType[DiagramType.ganttChart]!.ganttChartData, isNotNull);
      expect(byType[DiagramType.timeline]!.timelineChartData, isNotNull);
      expect(byType[DiagramType.kanban]!.kanbanChartData, isNotNull);
      expect(byType[DiagramType.mindmap]!.mindmapData, isNotNull);
      expect(byType[DiagramType.radar]!.radarChartData, isNotNull);
      expect(byType[DiagramType.xyChart]!.xyChartData, isNotNull);
    });

    test('comments and blank lines are ignored', () {
      final result = parser.parseWithData('''
%% imported comment

flowchart TD
  A --> B
''');

      expect(result, isNotNull);
      expect(result!.diagram.nodes.map((node) => node.id),
          containsAll(<String>['A', 'B']));
    });

    test('unsupported and unknown diagrams report stable failures', () {
      const classSource = 'classDiagram\n  class Foo';
      const stateSource = 'stateDiagram-v2\n  [*] --> Idle';
      const unknownSource = 'not a Mermaid diagram';

      expect(parser.detectDiagramType(classSource), DiagramType.classDiagram);
      expect(parser.parseWithData(classSource), isNull);
      expect(
          parser.describeParseFailure(classSource), contains('classDiagram'));
      expect(parser.detectDiagramType(stateSource), DiagramType.stateDiagram);
      expect(parser.parseWithData(stateSource), isNull);
      expect(
          parser.describeParseFailure(stateSource), contains('stateDiagram'));
      expect(parser.detectDiagramType(unknownSource), DiagramType.unknown);
      expect(parser.parseWithData(unknownSource), isNull);
      expect(
          parser.describeParseFailure(unknownSource), contains('Unsupported'));
    });
  });
}
