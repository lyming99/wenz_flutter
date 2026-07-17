/// Parser for Radar charts
library;

import '../models/diagram.dart';
import '../models/radar.dart';

/// Parser for Mermaid Radar charts
class RadarParser {
  /// Creates a Radar parser
  const RadarParser();

  /// Parses Radar chart from cleaned lines
  /// Returns tuple of (MermaidDiagramData, RadarChartData) or null if invalid
  (MermaidDiagramData, RadarChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    String? title;
    final axes = <RadarAxis>[];
    final curves = <RadarCurve>[];
    var showLegend = true;
    double? max;
    double? min;
    var graticule = RadarGraticule.polygon;
    var ticks = 5;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) continue;

      // Skip 'radar-beta' keyword
      if (trimmedLine.toLowerCase() == 'radar-beta') continue;

      // Parse title
      if (trimmedLine.toLowerCase().startsWith('title ')) {
        title = _extractTitle(trimmedLine);
        continue;
      }

      // Parse axis definition: axis A, B, C or axis A["Label A"], B["Label B"]
      if (trimmedLine.toLowerCase().startsWith('axis ')) {
        final axisData = _parseAxes(trimmedLine);
        axes.addAll(axisData);
        continue;
      }

      // Parse curve: curve c1{1,2,3,4,5} or curve c1["Label"]{1,2,3,4,5}
      if (trimmedLine.toLowerCase().startsWith('curve ')) {
        final curve = _parseCurve(trimmedLine);
        if (curve != null) {
          curves.add(curve);
        }
        continue;
      }

      // Parse options
      if (trimmedLine.toLowerCase().startsWith('showlegend ')) {
        showLegend = _parseBool(trimmedLine.substring(11));
        continue;
      }

      if (trimmedLine.toLowerCase().startsWith('max ')) {
        max = double.tryParse(trimmedLine.substring(4).trim());
        continue;
      }

      if (trimmedLine.toLowerCase().startsWith('min ')) {
        min = double.tryParse(trimmedLine.substring(4).trim());
        continue;
      }

      if (trimmedLine.toLowerCase().startsWith('graticule ')) {
        final value = trimmedLine.substring(10).trim().toLowerCase();
        graticule = value == 'circle' ? RadarGraticule.circle : RadarGraticule.polygon;
        continue;
      }

      if (trimmedLine.toLowerCase().startsWith('ticks ')) {
        ticks = int.tryParse(trimmedLine.substring(6).trim()) ?? 5;
        continue;
      }
    }

    if (axes.isEmpty || curves.isEmpty) return null;

    final radarData = RadarChartData(
      axes: axes,
      curves: curves,
      title: title,
      showLegend: showLegend,
      max: max,
      min: min,
      graticule: graticule,
      ticks: ticks,
    );

    final diagramData = MermaidDiagramData(
      type: DiagramType.radar,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, radarData);
  }

  /// Extracts title from title line
  String _extractTitle(String line) {
    return line.substring(6).trim();
  }

  /// Parses axis definition
  /// Supports: axis A, B, C or axis A["Label A"], B["Label B"]
  List<RadarAxis> _parseAxes(String line) {
    final axisContent = line.substring(5).trim();
    final axes = <RadarAxis>[];

    // Split by comma, but respect brackets
    final parts = _splitByCommaRespectingBrackets(axisContent);

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Check for labeled axis: A["Label"] or 编程["Programming"]
      // Use .+? to match any characters (including Chinese) before the bracket
      final labelMatch = RegExp(r'^(.+?)\["([^"]+)"\]$').firstMatch(trimmed);
      if (labelMatch != null) {
        final id = labelMatch.group(1)!.trim();
        final label = labelMatch.group(2)!;
        axes.add(RadarAxis(id: id, label: label));
      } else {
        // Simple axis: A or 编程
        axes.add(RadarAxis(id: trimmed, label: trimmed));
      }
    }

    return axes;
  }

  /// Parses curve definition
  /// Supports: curve c1{1,2,3} or curve c1["Label"]{1,2,3}
  /// Also supports key-value format: curve c1{A:1, B:2, C:3}
  /// Supports Chinese: curve 张三{1,2,3}
  RadarCurve? _parseCurve(String line) {
    final curveContent = line.substring(6).trim();

    // Match: curveId{values} or curveId["Label"]{values}
    // Use .+? to match any characters including Chinese
    final pattern = RegExp(r'^(.+?)(?:\["([^"]+)"\])?\{([^}]+)\}$');
    final match = pattern.firstMatch(curveContent);

    if (match == null) return null;

    final id = match.group(1)!.trim();
    final label = match.group(2) ?? id;
    final valuesStr = match.group(3)!;

    // Parse values - can be: 1,2,3 or A:1, B:2, C:3
    final values = <double>[];
    final parts = valuesStr.split(',');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Check for key-value format (A:1)
      if (trimmed.contains(':')) {
        final colonIndex = trimmed.indexOf(':');
        final valueStr = trimmed.substring(colonIndex + 1).trim();
        final value = double.tryParse(valueStr);
        if (value != null) values.add(value);
      } else {
        // Simple number
        final value = double.tryParse(trimmed);
        if (value != null) values.add(value);
      }
    }

    if (values.isEmpty) return null;

    return RadarCurve(
      id: id,
      label: label,
      values: values,
    );
  }

  /// Splits string by comma while respecting brackets and quotes
  List<String> _splitByCommaRespectingBrackets(String input) {
    final parts = <String>[];
    var current = '';
    var bracketDepth = 0;
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        current += char;
      } else if (char == '[' && !inQuotes) {
        bracketDepth++;
        current += char;
      } else if (char == ']' && !inQuotes) {
        bracketDepth--;
        current += char;
      } else if (char == ',' && bracketDepth == 0 && !inQuotes) {
        parts.add(current);
        current = '';
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      parts.add(current);
    }

    return parts;
  }

  /// Parses boolean value
  bool _parseBool(String value) {
    final lower = value.trim().toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
}
