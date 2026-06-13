import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// Extracts draw.io stencil XML into a JSON manifest and/or a Dart library draft.
///
/// Example:
/// dart run tool/drawio_stencil_extract.dart ^
///   --input D:\project\GitHub\drawio\src\main\webapp\stencils\bpmn.xml ^
///   --library bpmn ^
///   --group BPMN ^
///   --out-manifest tool\generated_stencils\bpmn_manifest.json ^
///   --out-dart tool\generated_stencils\bpmn_stencils.dart
void main(List<String> args) {
  final options = _Options.parse(args);
  if (options.help || options.inputPath == null) {
    stdout.writeln(_usage);
    exit(options.help ? 0 : 64);
  }

  final input = File(options.inputPath!);
  if (!input.existsSync()) {
    stderr.writeln('Input file not found: ${input.path}');
    exit(66);
  }

  final library = options.library ?? _libraryNameFromFile(input);
  final group = options.group ?? library;
  final sourceText = input.readAsStringSync();
  final document = XmlDocument.parse(sourceText);
  final shapes = document.findAllElements('shape').toList(growable: false);

  final entries = <_StencilEntry>[];
  final usedKeys = <String, int>{};
  for (final shape in shapes) {
    final label = (shape.getAttribute('name') ?? 'shape').trim();
    final keySuffix = _uniqueKey(_lowerCamel(label), usedKeys);
    final key = '$library.$keySuffix';
    final aliases = _aliases(library, label, keySuffix);
    final width = _doubleAttr(shape, 'w');
    final height = _doubleAttr(shape, 'h');
    final xml = _shapeXmlWithName(shape, key);
    entries.add(
      _StencilEntry(
        key: key,
        label: label,
        group: group,
        sourceFile: input.path,
        defaultWidth: width,
        defaultHeight: height,
        tags: _tags(label, group),
        aliases: aliases,
        xml: xml,
      ),
    );
  }

  if (options.outManifestPath != null) {
    _writeFile(
      options.outManifestPath!,
      _manifestJson(entries, library, group, input),
    );
  }
  if (options.outDartPath != null) {
    _writeFile(
      options.outDartPath!,
      _dartLibrary(entries, library, group, input),
    );
  }

  stdout.writeln(
    'Extracted ${entries.length} shape(s) from ${input.path} as library "$library".',
  );
  if (options.outManifestPath != null) {
    stdout.writeln('Manifest: ${options.outManifestPath}');
  }
  if (options.outDartPath != null) {
    stdout.writeln('Dart draft: ${options.outDartPath}');
  }
  if (entries.isNotEmpty) {
    stdout.writeln(
      'First keys: ${entries.take(5).map((entry) => entry.key).join(', ')}',
    );
  }
}

const _usage = '''
Usage:
  dart run tool/drawio_stencil_extract.dart --input <file.xml> [options]

Options:
  --library <name>       Internal library prefix, e.g. bpmn, aws4, gcp2.
  --group <name>         Palette/manifest group label. Defaults to library.
  --out-manifest <file>  Write JSON manifest.
  --out-dart <file>      Write Dart stencil library draft.
  --help                 Show this help.

Output manifest fields per shape:
  key, label, group, sourceFile, defaultWidth, defaultHeight, tags, aliases
''';

class _Options {
  const _Options({
    required this.inputPath,
    required this.library,
    required this.group,
    required this.outManifestPath,
    required this.outDartPath,
    required this.help,
  });

  final String? inputPath;
  final String? library;
  final String? group;
  final String? outManifestPath;
  final String? outDartPath;
  final bool help;

  static _Options parse(List<String> args) {
    String? valueAfter(String name) {
      final index = args.indexOf(name);
      if (index < 0 || index + 1 >= args.length) {
        return null;
      }
      return args[index + 1];
    }

    return _Options(
      inputPath: valueAfter('--input'),
      library: valueAfter('--library'),
      group: valueAfter('--group'),
      outManifestPath: valueAfter('--out-manifest'),
      outDartPath: valueAfter('--out-dart'),
      help: args.contains('--help') || args.contains('-h'),
    );
  }
}

class _StencilEntry {
  const _StencilEntry({
    required this.key,
    required this.label,
    required this.group,
    required this.sourceFile,
    required this.defaultWidth,
    required this.defaultHeight,
    required this.tags,
    required this.aliases,
    required this.xml,
  });

  final String key;
  final String label;
  final String group;
  final String sourceFile;
  final double? defaultWidth;
  final double? defaultHeight;
  final List<String> tags;
  final List<String> aliases;
  final String xml;

  Map<String, Object?> toManifestJson() {
    return {
      'key': key,
      'label': label,
      'group': group,
      'sourceFile': sourceFile,
      'defaultWidth': defaultWidth,
      'defaultHeight': defaultHeight,
      'tags': tags,
      'aliases': aliases,
    };
  }
}

String _libraryNameFromFile(File input) {
  return input.uri.pathSegments.last.replaceFirst(
    RegExp(r'\.xml$', caseSensitive: false),
    '',
  );
}

double? _doubleAttr(XmlElement element, String name) {
  return double.tryParse(element.getAttribute(name) ?? '');
}

String _shapeXmlWithName(XmlElement shape, String key) {
  final copy = shape.copy();
  copy.setAttribute('name', key);
  return copy.toXmlString(pretty: true, indent: '  ');
}

String _uniqueKey(String base, Map<String, int> used) {
  final normalized = base.isEmpty ? 'shape' : base;
  final count = used.update(
    normalized,
    (value) => value + 1,
    ifAbsent: () => 0,
  );
  return count == 0 ? normalized : '$normalized${count + 1}';
}

String _lowerCamel(String label) {
  final parts = label
      .replaceAll('&', ' and ')
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return '';
  }

  String normalize(String part, {required bool first}) {
    if (part.length == 1 && RegExp(r'[0-9]').hasMatch(part)) {
      return part;
    }
    final lower = part.toLowerCase();
    return first ? lower : '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  return [
    normalize(parts.first, first: true),
    for (final part in parts.skip(1)) normalize(part, first: false),
  ].join();
}

String _snake(String label) {
  return label
      .replaceAll('&', ' and ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _kebab(String label) => _snake(label).replaceAll('_', '-');

List<String> _aliases(String library, String label, String keySuffix) {
  final aliases = <String>{
    'mxgraph.$library.$keySuffix',
    'mxgraph.$library.${_snake(label)}',
    'mxgraph.$library.${_kebab(label)}',
    'mxgraph.$library.$label',
  }..removeWhere((alias) => alias.endsWith('.'));
  return aliases.toList(growable: false);
}

List<String> _tags(String label, String group) {
  final tags = <String>{group.toLowerCase(), ..._snake(label).split('_')}
    ..removeWhere((tag) => tag.isEmpty);
  return tags.toList(growable: false);
}

String _manifestJson(
  List<_StencilEntry> entries,
  String library,
  String group,
  File input,
) {
  final payload = {
    'library': library,
    'group': group,
    'shapeCount': entries.length,
    'sourceFile': input.path,
    'sourceSizeBytes': input.lengthSync(),
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'shapes': entries.map((entry) => entry.toManifestJson()).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

String _dartLibrary(
  List<_StencilEntry> entries,
  String library,
  String group,
  File input,
) {
  final className = '${_pascal(library)}Stencils';
  final buffer = StringBuffer()
    ..writeln('// Generated draft from ${input.path.replaceAll('\\', '/')}.')
    ..writeln('// Review before moving into lib/src/stencils/libraries/.')
    ..writeln()
    ..writeln('class $className {')
    ..writeln('  const $className._();')
    ..writeln()
    ..writeln('  static const String group = ${jsonEncode(group)};')
    ..writeln()
    ..writeln('  static const List<String> keys = <String>[');
  for (final entry in entries) {
    buffer.writeln('    ${jsonEncode(entry.key)},');
  }
  buffer
    ..writeln('  ];')
    ..writeln()
    ..writeln('  static const Map<String, String> labels = <String, String>{');
  for (final entry in entries) {
    buffer.writeln('    ${jsonEncode(entry.key)}: ${jsonEncode(entry.label)},');
  }
  buffer
    ..writeln('  };')
    ..writeln()
    ..writeln(
      '  static const Map<String, List<String>> aliases = <String, List<String>>{',
    );
  for (final entry in entries) {
    buffer.writeln('    ${jsonEncode(entry.key)}: <String>[');
    for (final alias in entry.aliases) {
      buffer.writeln('      ${jsonEncode(alias)},');
    }
    buffer.writeln('    ],');
  }
  buffer
    ..writeln('  };')
    ..writeln()
    ..writeln('  static const List<String> xmlDefinitions = <String>[');
  for (final entry in entries) {
    buffer
      ..writeln('    // ${entry.label}')
      ..writeln('    ${jsonEncode(entry.xml)},');
  }
  buffer
    ..writeln('  ];')
    ..writeln('}');
  return buffer.toString();
}

String _pascal(String value) {
  final parts = value
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Generated';
  }
  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

void _writeFile(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
