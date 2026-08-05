import '../models/diagram.dart';
import '../models/gantt.dart';
import '../models/kanban.dart';
import '../models/mindmap.dart';
import '../models/pie_chart.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/xy_chart.dart';
import 'flowchart_parser.dart';
import 'gantt_parser.dart';
import 'kanban_parser.dart';
import 'mindmap_parser.dart';
import 'pie_chart_parser.dart';
import 'radar_parser.dart';
import 'sequence_parser.dart';
import 'timeline_parser.dart';
import 'xy_chart_parser.dart';

/// Result of parsing a Mermaid diagram
class MermaidParseResult {
  /// Creates a parse result
  const MermaidParseResult({
    required this.diagram,
    this.pieChartData,
    this.ganttChartData,
    this.timelineChartData,
    this.kanbanChartData,
    this.mindmapData,
    this.radarChartData,
    this.xyChartData,
  });

  /// The parsed diagram data
  final MermaidDiagramData diagram;

  /// Pie chart specific data (only set for pie charts)
  final PieChartData? pieChartData;

  /// Gantt chart specific data (only set for Gantt charts)
  final GanttChartData? ganttChartData;

  /// Timeline chart specific data (only set for timeline charts)
  final TimelineChartData? timelineChartData;

  /// Kanban chart specific data (only set for Kanban charts)
  final KanbanChartData? kanbanChartData;

  /// Mindmap specific data (only set for mindmap diagrams)
  final MindmapData? mindmapData;

  /// Radar chart specific data (only set for Radar charts)
  final RadarChartData? radarChartData;

  /// XY chart specific data (only set for XY charts)
  final XYChartData? xyChartData;
}

/// Main parser for Mermaid diagrams
///
/// This parser detects the diagram type and delegates to the
/// appropriate specialized parser.
class MermaidParser {
  /// Creates a new Mermaid parser
  const MermaidParser();

  /// Parses a Mermaid diagram string
  ///
  /// Returns null if the diagram cannot be parsed
  MermaidDiagramData? parse(String source) {
    final result = parseWithData(source);
    return result?.diagram;
  }

  /// Parses a Mermaid diagram string and returns additional data
  ///
  /// Returns a [MermaidParseResult] containing the diagram and any
  /// type-specific data (like [PieChartData] for pie charts)
  MermaidParseResult? parseWithData(String source) {
    if (source.trim().isEmpty) return null;

    final lines = source.split('\n');
    final cleanedLines = _cleanLines(lines);

    if (cleanedLines.isEmpty) return null;

    final firstLine = _firstContentLine(cleanedLines);

    // Detect diagram type
    final type = _detectDiagramType(firstLine);

    switch (type) {
      case DiagramType.flowchart:
        final diagram = FlowchartParser().parse(cleanedLines);
        if (diagram != null) {
          return MermaidParseResult(diagram: diagram);
        }
        return null;
      case DiagramType.sequence:
        final diagram = SequenceParser().parse(cleanedLines);
        if (diagram != null) {
          return MermaidParseResult(diagram: diagram);
        }
        return null;
      case DiagramType.pieChart:
        final result = const PieChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            pieChartData: result.$2,
          );
        }
        return null;
      case DiagramType.ganttChart:
        final result = const GanttParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            ganttChartData: result.$2,
          );
        }
        return null;
      case DiagramType.timeline:
        final result = const TimelineParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            timelineChartData: result.$2,
          );
        }
        return null;
      case DiagramType.kanban:
        final result = const KanbanParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            kanbanChartData: result.$2,
          );
        }
        return null;
      case DiagramType.mindmap:
        final result = const MindmapParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            mindmapData: result.$2,
          );
        }
        return null;
      case DiagramType.radar:
        final result = const RadarParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            radarChartData: result.$2,
          );
        }
        return null;
      case DiagramType.xyChart:
        final result = const XYChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            xyChartData: result.$2,
          );
        }
        return null;
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
        return null;
      case DiagramType.unknown:
        return null;
    }
  }

  /// Detects the Mermaid diagram type without building the diagram model.
  DiagramType detectDiagramType(String source) {
    if (source.trim().isEmpty) return DiagramType.unknown;

    final cleanedLines = _cleanLines(source.split('\n'));
    if (cleanedLines.isEmpty) return DiagramType.unknown;

    return _detectDiagramType(_firstContentLine(cleanedLines));
  }

  /// Provides a stable message for unsupported or invalid Mermaid input.
  String describeParseFailure(String source) {
    final type = detectDiagramType(source);

    switch (type) {
      case DiagramType.classDiagram:
        return 'Mermaid classDiagram is not supported by the pure Dart renderer yet.';
      case DiagramType.stateDiagram:
        return 'Mermaid stateDiagram is not supported by the pure Dart renderer yet.';
      case DiagramType.unknown:
        return 'Unsupported or unknown Mermaid diagram syntax.';
      case DiagramType.flowchart:
        return 'Unable to parse Mermaid flowchart diagram.';
      case DiagramType.sequence:
        return 'Unable to parse Mermaid sequence diagram.';
      case DiagramType.pieChart:
        return 'Unable to parse Mermaid pie chart diagram.';
      case DiagramType.ganttChart:
        return 'Unable to parse Mermaid gantt chart diagram.';
      case DiagramType.timeline:
        return 'Unable to parse Mermaid timeline diagram.';
      case DiagramType.kanban:
        return 'Unable to parse Mermaid kanban diagram.';
      case DiagramType.mindmap:
        return 'Unable to parse Mermaid mindmap diagram.';
      case DiagramType.radar:
        return 'Unable to parse Mermaid radar chart diagram.';
      case DiagramType.xyChart:
        return 'Unable to parse Mermaid xy chart diagram.';
    }
  }

  /// Detects the diagram type from the first line
  DiagramType _detectDiagramType(String firstLine) {
    // Flowchart patterns
    if (firstLine.startsWith('graph ') || firstLine.startsWith('flowchart ')) {
      return DiagramType.flowchart;
    }

    // Sequence diagram
    if (firstLine.startsWith('sequencediagram')) {
      return DiagramType.sequence;
    }

    // Pie chart
    if (firstLine.startsWith('pie')) {
      return DiagramType.pieChart;
    }

    // Gantt chart
    if (firstLine.startsWith('gantt')) {
      return DiagramType.ganttChart;
    }

    // Timeline
    if (firstLine.startsWith('timeline')) {
      return DiagramType.timeline;
    }

    // Kanban
    if (firstLine.startsWith('kanban')) {
      return DiagramType.kanban;
    }

    // Mindmap
    if (firstLine == 'mindmap' || firstLine.startsWith('mindmap ')) {
      return DiagramType.mindmap;
    }

    // Radar chart
    if (firstLine.startsWith('radar-beta')) {
      return DiagramType.radar;
    }

    // XY chart
    if (firstLine.startsWith('xychart')) {
      return DiagramType.xyChart;
    }

    // Class diagram
    if (firstLine.startsWith('classdiagram')) {
      return DiagramType.classDiagram;
    }

    // State diagram
    if (firstLine.startsWith('statediagram') ||
        firstLine.startsWith('statediagram-v2')) {
      return DiagramType.stateDiagram;
    }

    return DiagramType.unknown;
  }

  String _firstContentLine(List<String> cleanedLines) {
    // Skip YAML frontmatter if present (used by some diagram types like Kanban)
    var firstContentLine = cleanedLines.first.trim().toLowerCase();
    if (firstContentLine == '---') {
      // Find the closing --- and get the first line after it
      for (var i = 1; i < cleanedLines.length; i++) {
        if (cleanedLines[i].trim() == '---') {
          if (i + 1 < cleanedLines.length) {
            firstContentLine = cleanedLines[i + 1].trim().toLowerCase();
          }
          break;
        }
      }
    }

    return firstContentLine;
  }

  /// Cleans and filters input lines
  List<String> _cleanLines(List<String> lines) {
    final result = <String>[];

    for (var line in lines) {
      // Remove comments
      final commentIndex = line.indexOf('%%');
      if (commentIndex != -1) {
        line = line.substring(0, commentIndex);
      }

      // Skip empty lines
      if (line.trim().isNotEmpty) {
        result.add(line);
      }
    }

    return result;
  }
}

/// Result of parsing a token
class ParseToken {
  /// Creates a parse token
  const ParseToken({
    required this.type,
    required this.value,
    this.start = 0,
    this.end = 0,
  });

  /// Type of token
  final TokenType type;

  /// Token value
  final String value;

  /// Start position in source
  final int start;

  /// End position in source
  final int end;
}

/// Token types for lexical analysis
enum TokenType {
  /// Node identifier
  nodeId,

  /// Node label
  nodeLabel,

  /// Arrow/edge
  arrow,

  /// Edge label
  edgeLabel,

  /// Keyword (graph, subgraph, etc)
  keyword,

  /// Style definition
  style,

  /// Class definition
  classDef,

  /// Subgraph start
  subgraphStart,

  /// Subgraph end
  subgraphEnd,

  /// End of input
  eof,
}
