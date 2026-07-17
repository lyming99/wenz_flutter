/// Parser for XY Charts
library;

import '../models/diagram.dart';
import '../models/xy_chart.dart';

/// Parser for Mermaid XY Charts
class XYChartParser {
  /// Creates an XY chart parser
  const XYChartParser();

  /// Parses XY chart from cleaned lines
  /// Returns tuple of (MermaidDiagramData, XYChartData) or null if invalid
  (MermaidDiagramData, XYChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    String? title;
    String? xAxisTitle;
    String? yAxisTitle;
    final xAxisCategories = <String>[];
    double? xAxisMin;
    double? xAxisMax;
    double? yAxisMin;
    double? yAxisMax;
    var orientation = XYChartOrientation.vertical;
    final seriesList = <XYChartSeries>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) continue;

      final lowerLine = trimmedLine.toLowerCase();

      // Skip 'xychart-beta' or 'xychart' keyword
      if (lowerLine.startsWith('xychart')) {
        if (lowerLine.contains('horizontal')) {
          orientation = XYChartOrientation.horizontal;
        }
        continue;
      }

      // Parse title
      if (lowerLine.startsWith('title ')) {
        title = _extractQuotedOrPlain(trimmedLine.substring(6).trim());
        continue;
      }

      // Parse x-axis
      if (lowerLine.startsWith('x-axis ')) {
        final content = trimmedLine.substring(7).trim();
        final parsed = _parseAxis(content);
        xAxisTitle = parsed.title;
        if (parsed.categories != null) {
          xAxisCategories.addAll(parsed.categories!);
        }
        if (parsed.min != null) xAxisMin = parsed.min;
        if (parsed.max != null) xAxisMax = parsed.max;
        continue;
      }

      // Parse y-axis
      if (lowerLine.startsWith('y-axis ')) {
        final content = trimmedLine.substring(7).trim();
        final parsed = _parseAxis(content);
        yAxisTitle = parsed.title;
        if (parsed.min != null) yAxisMin = parsed.min;
        if (parsed.max != null) yAxisMax = parsed.max;
        continue;
      }

      // Parse bar series
      if (lowerLine.startsWith('bar ')) {
        final values = _parseValues(trimmedLine.substring(4).trim());
        if (values.isNotEmpty) {
          seriesList.add(XYChartSeries(type: XYSeriesType.bar, values: values));
        }
        continue;
      }

      // Parse line series
      if (lowerLine.startsWith('line ')) {
        final values = _parseValues(trimmedLine.substring(5).trim());
        if (values.isNotEmpty) {
          seriesList.add(XYChartSeries(type: XYSeriesType.line, values: values));
        }
        continue;
      }
    }

    if (seriesList.isEmpty) return null;

    final xyData = XYChartData(
      series: seriesList,
      title: title,
      xAxisTitle: xAxisTitle,
      yAxisTitle: yAxisTitle,
      xAxisCategories: xAxisCategories,
      xAxisMin: xAxisMin,
      xAxisMax: xAxisMax,
      yAxisMin: yAxisMin,
      yAxisMax: yAxisMax,
      orientation: orientation,
    );

    final diagramData = MermaidDiagramData(
      type: DiagramType.xyChart,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, xyData);
  }

  /// Extracts a quoted string or returns plain text
  String _extractQuotedOrPlain(String input) {
    if (input.startsWith('"') && input.endsWith('"') && input.length >= 2) {
      return input.substring(1, input.length - 1);
    }
    return input;
  }

  /// Parses axis definition
  /// Supports: "Title" [cat1, cat2] or "Title" min --> max or just [cat1, cat2]
  _AxisParseResult _parseAxis(String content) {
    String? title;
    List<String>? categories;
    double? min;
    double? max;

    var remaining = content;

    // Extract title (quoted string at the beginning)
    if (remaining.startsWith('"')) {
      final endQuote = remaining.indexOf('"', 1);
      if (endQuote != -1) {
        title = remaining.substring(1, endQuote);
        remaining = remaining.substring(endQuote + 1).trim();
      }
    } else if (!remaining.startsWith('[') && !remaining.contains('-->')) {
      // Unquoted title before categories or range
      final bracketIdx = remaining.indexOf('[');
      final arrowIdx = remaining.indexOf('-->');
      if (bracketIdx != -1) {
        title = remaining.substring(0, bracketIdx).trim();
        remaining = remaining.substring(bracketIdx).trim();
      } else if (arrowIdx != -1) {
        // Could be: title min --> max or just min --> max
        final beforeArrow = remaining.substring(0, arrowIdx).trim();
        final parts = beforeArrow.split(RegExp(r'\s+'));
        if (parts.length > 1) {
          // Last part is min, rest is title
          final minStr = parts.last;
          if (double.tryParse(minStr) != null) {
            title = parts.sublist(0, parts.length - 1).join(' ');
            remaining = '$minStr ${remaining.substring(arrowIdx)}';
          }
        }
      } else {
        title = remaining;
        remaining = '';
      }
    }

    // Parse categories: [cat1, "cat2 with space", cat3]
    if (remaining.startsWith('[')) {
      final endBracket = remaining.lastIndexOf(']');
      if (endBracket != -1) {
        final catStr = remaining.substring(1, endBracket);
        categories = _parseCategories(catStr);
      }
    }

    // Parse numeric range: min --> max
    final arrowMatch = RegExp(r'([\d.e+-]+)\s*-->\s*([\d.e+-]+)').firstMatch(remaining);
    if (arrowMatch != null) {
      min = double.tryParse(arrowMatch.group(1)!);
      max = double.tryParse(arrowMatch.group(2)!);
    }

    return _AxisParseResult(
      title: title,
      categories: categories,
      min: min,
      max: max,
    );
  }

  /// Parses category list from bracket content
  List<String> _parseCategories(String input) {
    final categories = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        final trimmed = current.trim();
        if (trimmed.isNotEmpty) categories.add(trimmed);
        current = '';
      } else {
        current += char;
      }
    }

    final trimmed = current.trim();
    if (trimmed.isNotEmpty) categories.add(trimmed);

    return categories;
  }

  /// Parses values from bracket notation: [1, 2, 3.5, -4]
  List<double> _parseValues(String input) {
    final values = <double>[];

    // Remove brackets
    var content = input.trim();
    if (content.startsWith('[')) content = content.substring(1);
    if (content.endsWith(']')) content = content.substring(0, content.length - 1);

    final parts = content.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final value = double.tryParse(trimmed);
      if (value != null) values.add(value);
    }

    return values;
  }
}

/// Internal result of axis parsing
class _AxisParseResult {
  const _AxisParseResult({this.title, this.categories, this.min, this.max});
  final String? title;
  final List<String>? categories;
  final double? min;
  final double? max;
}
