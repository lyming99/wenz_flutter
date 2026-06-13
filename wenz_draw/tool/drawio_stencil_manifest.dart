import 'dart:convert';
import 'dart:io';

/// Reads one or more generated draw.io stencil manifests and prints a compact
/// summary for migration planning.
///
/// Example:
/// dart run tool/drawio_stencil_manifest.dart tool\generated_stencils\bpmn_manifest.json
void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  final summaries = <_ManifestSummary>[];
  for (final path in args) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('Manifest not found: $path');
      exitCode = 66;
      continue;
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final summary = _ManifestSummary.fromJson(path, json);
    summaries.add(summary);
    _printSummary(summary);
  }

  if (summaries.length > 1) {
    final totalShapes = summaries.fold<int>(
      0,
      (sum, item) => sum + item.shapeCount,
    );
    final totalAliases = summaries.fold<int>(
      0,
      (sum, item) => sum + item.aliasCount,
    );
    final totalSourceBytes = summaries.fold<int>(
      0,
      (sum, item) => sum + item.sourceSizeBytes,
    );
    stdout.writeln('Total:');
    stdout.writeln('  libraries: ${summaries.length}');
    stdout.writeln('  shapes: $totalShapes');
    stdout.writeln('  aliases: $totalAliases');
    stdout.writeln('  source XML size: ${_formatBytes(totalSourceBytes)}');
    final largest = summaries.reduce(
      (a, b) => a.shapeCount >= b.shapeCount ? a : b,
    );
    stdout.writeln(
      '  largest by shape count: ${largest.library} (${largest.shapeCount})',
    );
  }
}

void _printSummary(_ManifestSummary summary) {
  stdout.writeln('${summary.library} (${summary.group}):');
  stdout.writeln('  manifest: ${summary.path}');
  stdout.writeln('  source: ${summary.sourceFile ?? 'unknown'}');
  stdout.writeln('  source XML size: ${_formatBytes(summary.sourceSizeBytes)}');
  stdout.writeln('  shapes: ${summary.shapeCount}');
  stdout.writeln('  aliases: ${summary.aliasCount}');
  stdout.writeln(
    '  avg aliases/shape: ${summary.averageAliases.toStringAsFixed(2)}',
  );
  stdout.writeln(
    '  groups: ${summary.groupCounts.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
  );
  stdout.writeln('  recommendation: ${summary.recommendation}');
  if (summary.first != null) {
    stdout.writeln('  first: ${summary.first!.key} / ${summary.first!.label}');
  }
  if (summary.last != null) {
    stdout.writeln('  last:  ${summary.last!.key} / ${summary.last!.label}');
  }
}

class _ManifestSummary {
  const _ManifestSummary({
    required this.path,
    required this.library,
    required this.group,
    required this.sourceFile,
    required this.sourceSizeBytes,
    required this.shapes,
  });

  final String path;
  final String library;
  final String group;
  final String? sourceFile;
  final int sourceSizeBytes;
  final List<_ShapeSummary> shapes;

  int get shapeCount => shapes.length;

  int get aliasCount =>
      shapes.fold<int>(0, (sum, shape) => sum + shape.aliasCount);

  double get averageAliases => shapeCount == 0 ? 0 : aliasCount / shapeCount;

  _ShapeSummary? get first => shapes.isEmpty ? null : shapes.first;

  _ShapeSummary? get last => shapes.isEmpty ? null : shapes.last;

  Map<String, int> get groupCounts {
    final counts = <String, int>{};
    for (final shape in shapes) {
      counts.update(shape.group, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String get recommendation {
    if (shapeCount <= 50) {
      return 'small: safe candidate for eager registration after visual tests';
    }
    if (shapeCount <= 250) {
      return 'medium: consider grouped palette and registration benchmark';
    }
    return 'large: prefer manifest-driven lazy loading and searchable palette';
  }

  static _ManifestSummary fromJson(String path, Map<String, dynamic> json) {
    final rawShapes = json['shapes'] as List? ?? const [];
    return _ManifestSummary(
      path: path,
      library: (json['library'] ?? 'unknown').toString(),
      group: (json['group'] ?? json['library'] ?? 'unknown').toString(),
      sourceFile: json['sourceFile']?.toString(),
      sourceSizeBytes: _intValue(json['sourceSizeBytes']),
      shapes: [
        for (final raw in rawShapes)
          if (raw is Map) _ShapeSummary.fromJson(raw),
      ],
    );
  }
}

class _ShapeSummary {
  const _ShapeSummary({
    required this.key,
    required this.label,
    required this.group,
    required this.aliasCount,
  });

  final String key;
  final String label;
  final String group;
  final int aliasCount;

  static _ShapeSummary fromJson(Map raw) {
    return _ShapeSummary(
      key: (raw['key'] ?? '').toString(),
      label: (raw['label'] ?? '').toString(),
      group: (raw['group'] ?? '').toString(),
      aliasCount: (raw['aliases'] as List?)?.length ?? 0,
    );
  }
}

int _intValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return 'unknown';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

const _usage = '''
Usage:
  dart run tool/drawio_stencil_manifest.dart <manifest.json> [more.json ...]

Prints shape counts, alias counts, source size, group overview, and a rough
migration recommendation from generated draw.io stencil manifests.
''';
