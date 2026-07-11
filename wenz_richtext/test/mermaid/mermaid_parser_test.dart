import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

class _ParseCase {
  const _ParseCase({
    required this.name,
    required this.source,
    required this.type,
    required this.verify,
  });

  final String name;
  final String source;
  final DiagramType type;
  final void Function(MermaidParseResult result) verify;
}

void main() {
  const parser = MermaidParser();

  group('MermaidParser pure Dart core', () {
    final cases = <_ParseCase>[
      _ParseCase(
        name: 'flowchart with labels, subgraphs, and classes',
        type: DiagramType.flowchart,
        source: '''
flowchart LR
  subgraph stage[閿€鍞樁娈礭
    A[寮€濮媇 -->|閫氳繃| B{瀹℃壒}
  end
  B -->|鍚 C[琛ュ厖璧勬枡]
  classDef risk fill:#f96,stroke:#333,color:#111
  class C risk
''',
        verify: (result) {
          final diagram = result.diagram;
          expect(diagram.direction, DiagramDirection.leftToRight);
          expect(diagram.getNode('A')?.label, '寮€濮?);
          expect(diagram.getNode('B')?.shape, NodeShape.diamond);
          expect(diagram.getNode('C')?.className, 'risk');
          expect(diagram.subgraphs.single.label, '閿€鍞樁娈?);
          expect(diagram.edges.map((edge) => edge.label), contains('閫氳繃'));
          expect(diagram.edges.map((edge) => edge.label), contains('鍚?));
        },
      ),
      _ParseCase(
        name: 'sequence diagram with aliases and replies',
        type: DiagramType.sequence,
        source: '''
sequenceDiagram
  participant U as 鐢ㄦ埛
  participant S as 鏈嶅姟绔?  U->>S: 鍒涘缓璁㈠崟
  S-->>U: 宸茬‘璁?''',
        verify: (result) {
          final diagram = result.diagram;
          expect(diagram.direction, DiagramDirection.leftToRight);
          expect(diagram.nodes.map((node) => node.label), contains('鐢ㄦ埛'));
          expect(diagram.nodes.map((node) => node.label), contains('鏈嶅姟绔?));
          expect(diagram.edges.map((edge) => edge.label), contains('鍒涘缓璁㈠崟'));
          expect(diagram.edges.map((edge) => edge.lineType), contains(LineType.dotted));
        },
      ),
      _ParseCase(
        name: 'pie chart data',
        type: DiagramType.pieChart,
        source: '''
pie showData
  title 瀹犵墿鍗犳瘮
  "Dogs" : 386
  "Cats" : 85
''',
        verify: (result) {
          final data = result.pieChartData!;
          expect(data.title, '瀹犵墿鍗犳瘮');
          expect(data.showValuesInLegend, isTrue);
          expect(data.slices.map((slice) => slice.label), <String>['Dogs', 'Cats']);
          expect(data.totalValue, 471);
        },
      ),
      _ParseCase(
        name: 'gantt chart sections and dependencies',
        type: DiagramType.ganttChart,
        source: '''
gantt
  title 鍙戝竷璁″垝
  dateFormat YYYY-MM-DD
  section 寮€鍙?    Implement core :done, core, 2026-07-01, 2d
    Verify path :after core, 3d
''',
        verify: (result) {
          final data = result.ganttChartData!;
          expect(data.title, '鍙戝竷璁″垝');
          expect(data.sections.single.name, '寮€鍙?);
          expect(data.getTask('core')?.status, GanttTaskStatus.done);
          expect(data.tasks.last.dependencies, <String>['core']);
        },
      ),
      _ParseCase(
        name: 'timeline chart with continuation events',
        type: DiagramType.timeline,
        source: '''
timeline
  title 浜у搧閲岀▼纰?  2024 : Alpha
       : Beta
  2025 : Launch
''',
        verify: (result) {
          final data = result.timelineChartData!;
          expect(data.title, '浜у搧閲岀▼纰?);
          expect(data.sections.map((section) => section.title), <String>['2024', '2025']);
          expect(data.sections.first.events.map((event) => event.title), <String>['Alpha', 'Beta']);
        },
      ),
      _ParseCase(
        name: 'kanban board with metadata and frontmatter',
        type: DiagramType.kanban,
        source: '''
---
ticketBaseUrl: 'https://tickets.example/#TICKET#'
---
kanban
title Roadmap
todo[Todo] wip:2
    task1[Write parser] @{ assigned: "Ada", ticket: "M-1", priority: "High" }
done[Done]
    task2[Ship preview]
''',
        verify: (result) {
          final data = result.kanbanChartData!;
          expect(data.title, 'Roadmap');
          expect(data.ticketBaseUrl, 'https://tickets.example/#TICKET#');
          expect(data.columns.map((column) => column.title), <String>['Todo', 'Done']);
          expect(data.getTask('task1')?.assigned, 'Ada');
          expect(data.getTask('task1')?.priority, KanbanPriority.high);
        },
      ),
      _ParseCase(
        name: 'mindmap tree with shapes, classes, and icons',
        type: DiagramType.mindmap,
        source: '''
mindmap
  root((Root)):::primary
    plan[Plan]
      detail(Detail)
    choice{{Choice}}:::decision
    cloud)Cloud(::icon(lightbulb)
''',
        verify: (result) {
          final data = result.mindmapData!;
          final diagram = result.diagram;
          expect(data.root.id, 'root');
          expect(data.root.shape, MindmapNodeShape.circle);
          expect(data.root.className, 'primary');
          expect(data.root.children.map((node) => node.id), <String>[
            'plan',
            'choice',
            'cloud',
          ]);
          expect(data.getNode('detail')?.parentId, 'plan');
          expect(data.getNode('detail')?.shape, MindmapNodeShape.roundedRect);
          expect(data.getNode('choice')?.shape, MindmapNodeShape.hexagon);
          expect(data.getNode('choice')?.className, 'decision');
          expect(data.getNode('cloud')?.icon, 'lightbulb');
          expect(data.maxDepth, 2);
          expect(
            data.connections
                .map((connection) => '${connection.parentId}->${connection.childId}'),
            <String>['root->plan', 'plan->detail', 'root->choice', 'root->cloud'],
          );
          expect(diagram.direction, DiagramDirection.leftToRight);
          expect(diagram.nodes, hasLength(5));
          expect(diagram.edges, hasLength(4));
          expect(
            diagram.edges.every((edge) => edge.arrowType == ArrowType.none),
            isTrue,
          );
          expect(diagram.getNode('root')?.shape, NodeShape.circle);
          expect(diagram.getNode('choice')?.shape, NodeShape.hexagon);
          expect(diagram.getNode('cloud')?.label, 'Cloud');
        },
      ),
      _ParseCase(
        name: 'radar chart axes, curve, and options',
        type: DiagramType.radar,
        source: '''
radar-beta
title 鎶€鑳介浄杈?axis 缂栫爜["Coding"], 璁捐["Design"], 娴嬭瘯["Testing"]
curve 鍥㈤槦["Team"]{80,70,90}
showLegend true
max 100
min 0
graticule circle
ticks 4
''',
        verify: (result) {
          final data = result.radarChartData!;
          expect(data.title, '鎶€鑳介浄杈?);
          expect(data.axes.map((axis) => axis.label), <String>['Coding', 'Design', 'Testing']);
          expect(data.curves.single.label, 'Team');
          expect(data.curves.single.values, <double>[80, 70, 90]);
          expect(data.max, 100);
          expect(data.graticule, RadarGraticule.circle);
          expect(data.ticks, 4);
        },
      ),
      _ParseCase(
        name: 'xy chart mixed bar and line series',
        type: DiagramType.xyChart,
        source: '''
xychart-beta
title "Revenue"
x-axis "Month" [Jan, Feb, Mar]
y-axis "USD" 0 --> 100
bar [20, 40, 60]
line [30, 50, 70]
''',
        verify: (result) {
          final data = result.xyChartData!;
          expect(data.title, 'Revenue');
          expect(data.xAxisTitle, 'Month');
          expect(data.yAxisTitle, 'USD');
          expect(data.xAxisCategories, <String>['Jan', 'Feb', 'Mar']);
          expect(data.series.map((series) => series.type), <XYSeriesType>[
            XYSeriesType.bar,
            XYSeriesType.line,
          ]);
          expect(data.yAxisMax, 100);
        },
      ),
    ];

    for (final parseCase in cases) {
      test(parseCase.name, () {
        final result = parser.parseWithData(parseCase.source);

        expect(result, isNotNull, reason: parseCase.name);
        expect(result!.diagram.type, parseCase.type);
        parseCase.verify(result);
      });
    }

    test('comments and blank lines are ignored before parsing', () {
      final result = parser.parseWithData('''
%% generated by markdown import

flowchart TD
  A --> B
''');

      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.flowchart);
      expect(result.diagram.nodes.map((node) => node.id), containsAll(<String>['A', 'B']));
    });

    test('unsupported diagrams report stable messages', () {
      const classSource = 'classDiagram\n  class Foo';
      const stateSource = 'stateDiagram-v2\n  [*] --> Idle';
      const unknownSource = 'not a Mermaid diagram';

      expect(parser.detectDiagramType(classSource), DiagramType.classDiagram);
      expect(parser.parseWithData(classSource), isNull);
      expect(parser.describeParseFailure(classSource), contains('classDiagram'));

      expect(parser.detectDiagramType(stateSource), DiagramType.stateDiagram);
      expect(parser.parseWithData(stateSource), isNull);
      expect(parser.describeParseFailure(stateSource), contains('stateDiagram'));

      expect(parser.detectDiagramType(unknownSource), DiagramType.unknown);
      expect(parser.parseWithData(unknownSource), isNull);
      expect(parser.describeParseFailure(unknownSource), contains('Unsupported'));
    });
  });
}
