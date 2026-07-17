/// Parser for Mermaid mindmap diagrams.
library;

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/mindmap.dart';
import '../models/node.dart';

/// Parses Mermaid mindmap source into tree and diagram models.
class MindmapParser {
  /// Creates a mindmap parser.
  const MindmapParser();

  /// Parses cleaned Mermaid lines into a diagram/mindmap pair.
  ///
  /// Returns null when the content does not form a valid single-root mindmap.
  (MermaidDiagramData, MindmapData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    final contentLines = _extractContentLines(lines);
    if (contentLines.isEmpty) return null;

    final rootBuilder = _parseTree(contentLines);
    if (rootBuilder == null) return null;

    final rootNode = _buildMindmapNode(rootBuilder, depth: 0);
    final mindmapData = MindmapData(root: rootNode);

    final diagramNodes = <MermaidNode>[];
    final diagramEdges = <MermaidEdge>[];
    _populateDiagram(rootNode, diagramNodes, diagramEdges);

    final diagramData = MermaidDiagramData(
      type: DiagramType.mindmap,
      nodes: diagramNodes,
      edges: diagramEdges,
      direction: DiagramDirection.leftToRight,
    );

    return (diagramData, mindmapData);
  }

  List<_IndentedMindmapLine> _extractContentLines(List<String> lines) {
    var start = 0;

    if (lines[start].trim() == '---') {
      final configEnd = _findConfigEnd(lines, start + 1);
      if (configEnd == -1) return const [];
      start = configEnd + 1;
    }

    if (start >= lines.length) return const [];

    final firstLine = lines[start];
    final trimmedFirstLine = firstLine.trimLeft();
    if (!trimmedFirstLine.toLowerCase().startsWith('mindmap')) {
      return const [];
    }

    final keywordIndent = _indentationOf(firstLine);
    final inlineContent = trimmedFirstLine.substring('mindmap'.length).trim();
    final result = <_IndentedMindmapLine>[];

    if (inlineContent.isNotEmpty) {
      result.add(_IndentedMindmapLine(
        indent: keywordIndent,
        content: inlineContent,
      ));
    }

    for (var i = start + 1; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      result.add(_IndentedMindmapLine(
        indent: _indentationOf(line),
        content: trimmedLine,
      ));
    }

    return result;
  }

  _MutableMindmapNode? _parseTree(List<_IndentedMindmapLine> lines) {
    final usedIds = <String>{};
    final stack = <_MutableMindmapNode>[];
    _MutableMindmapNode? root;

    for (final line in lines) {
      final parsedNode = _parseNodeContent(line.content, usedIds);
      if (parsedNode == null) return null;

      final current = _MutableMindmapNode(
        indent: line.indent,
        id: parsedNode.id,
        label: parsedNode.label,
        shape: parsedNode.shape,
        className: parsedNode.className,
        icon: parsedNode.icon,
      );

      if (root == null) {
        root = current;
        stack.add(current);
        continue;
      }

      while (stack.isNotEmpty && stack.last.indent >= line.indent) {
        stack.removeLast();
      }

      if (stack.isEmpty) {
        return null;
      }

      stack.last.children.add(current);
      stack.add(current);
    }

    return root;
  }

  _ParsedMindmapNode? _parseNodeContent(
    String source,
    Set<String> usedIds,
  ) {
    var content = source.trim();
    String? className;
    String? icon;
    var changed = true;

    while (changed) {
      changed = false;

      final iconMatch = RegExp(r'::icon\(([^)]*)\)\s*$').firstMatch(content);
      if (iconMatch != null) {
        icon = icon ?? iconMatch.group(1)!.trim();
        content = content.substring(0, iconMatch.start).trimRight();
        changed = true;
        continue;
      }

      final classMatch = RegExp(r':::\s*([A-Za-z0-9_\- ]+)\s*$').firstMatch(content);
      if (classMatch != null) {
        className = _mergeClassNames(classMatch.group(1)!.trim(), className);
        content = content.substring(0, classMatch.start).trimRight();
        changed = true;
      }
    }

    if (content.isEmpty) {
      if (icon == null) return null;
      return _ParsedMindmapNode(
        id: _generateId(icon, usedIds),
        label: '',
        shape: MindmapNodeShape.rectangle,
        className: className,
        icon: icon,
      );
    }

    final shapes = <_ShapePattern>[
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\)\)(.+)\(\($'), MindmapNodeShape.bang),
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\)(.+)\($'), MindmapNodeShape.cloud),
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\(\((.+)\)\)$'), MindmapNodeShape.circle),
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\{\{(.+)\}\}$'), MindmapNodeShape.hexagon),
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\[(.+)\]$'), MindmapNodeShape.rectangle),
      _ShapePattern(RegExp(r'^([A-Za-z_][\w-]*)?\((.+)\)$'), MindmapNodeShape.roundedRect),
    ];

    for (final pattern in shapes) {
      final match = pattern.expression.firstMatch(content);
      if (match == null) continue;

      final explicitId = match.group(1);
      final label = _normalizeLabel(match.group(2)!);
      if (label.isEmpty && icon == null) return null;

      final id = explicitId != null && explicitId.isNotEmpty
          ? _reserveExplicitId(explicitId, usedIds)
          : _generateId(label.isNotEmpty ? label : icon!, usedIds);
      if (id == null) return null;

      return _ParsedMindmapNode(
        id: id,
        label: label,
        shape: pattern.shape,
        className: className,
        icon: icon,
      );
    }

    final label = _normalizeLabel(content);
    if (label.isEmpty && icon == null) return null;

    return _ParsedMindmapNode(
      id: _generateId(label.isNotEmpty ? label : icon!, usedIds),
      label: label,
      shape: MindmapNodeShape.rectangle,
      className: className,
      icon: icon,
    );
  }

  MindmapNode _buildMindmapNode(
    _MutableMindmapNode source, {
    required int depth,
    String? parentId,
  }) {
    return MindmapNode(
      id: source.id,
      label: source.label,
      depth: depth,
      parentId: parentId,
      children: [
        for (final child in source.children)
          _buildMindmapNode(child, depth: depth + 1, parentId: source.id),
      ],
      shape: source.shape,
      className: source.className,
      icon: source.icon,
    );
  }

  void _populateDiagram(
    MindmapNode node,
    List<MermaidNode> nodes,
    List<MermaidEdge> edges,
  ) {
    nodes.add(MermaidNode(
      id: node.id,
      label: node.displayText,
      shape: _toMermaidNodeShape(node.shape),
      className: node.className,
      style: node.style,
    ));

    for (final child in node.children) {
      edges.add(MermaidEdge(
        from: node.id,
        to: child.id,
        arrowType: ArrowType.none,
      ));
      _populateDiagram(child, nodes, edges);
    }
  }

  NodeShape _toMermaidNodeShape(MindmapNodeShape shape) {
    switch (shape) {
      case MindmapNodeShape.rectangle:
        return NodeShape.rectangle;
      case MindmapNodeShape.roundedRect:
        return NodeShape.roundedRect;
      case MindmapNodeShape.circle:
        return NodeShape.circle;
      case MindmapNodeShape.doubleCircle:
        return NodeShape.doubleCircle;
      case MindmapNodeShape.hexagon:
        return NodeShape.hexagon;
      case MindmapNodeShape.cloud:
        return NodeShape.roundedRect;
      case MindmapNodeShape.bang:
        return NodeShape.rectangle;
    }
  }

  String _normalizeLabel(String value) {
    var result = value.trim();

    while (result.length >= 2) {
      final first = result[0];
      final last = result[result.length - 1];
      final isPair = (first == '"' && last == '"') ||
          (first == '\'' && last == '\'') ||
          (first == '`' && last == '`');
      if (!isPair) break;
      result = result.substring(1, result.length - 1).trim();
    }

    return result.replaceAll('\\"', '"').replaceAll("\\'", "'");
  }

  String _mergeClassNames(String incoming, String? existing) {
    if (existing == null || existing.isEmpty) return incoming;
    if (incoming.isEmpty) return existing;
    return '$incoming $existing';
  }

  String? _reserveExplicitId(String id, Set<String> usedIds) {
    if (usedIds.contains(id)) return null;
    usedIds.add(id);
    return id;
  }

  String _generateId(String seed, Set<String> usedIds) {
    final normalized = seed.trim().toLowerCase();
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final base = slug.isEmpty ? 'node' : slug;
    var candidate = base;
    var suffix = 2;

    while (usedIds.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix++;
    }

    usedIds.add(candidate);
    return candidate;
  }

  int _findConfigEnd(List<String> lines, int start) {
    for (var i = start; i < lines.length; i++) {
      if (lines[i].trim() == '---') return i;
    }
    return -1;
  }

  int _indentationOf(String line) {
    var count = 0;
    for (final rune in line.runes) {
      if (rune == 0x20) {
        count += 1;
        continue;
      }
      if (rune == 0x09) {
        count += 2;
        continue;
      }
      break;
    }
    return count;
  }
}

class _IndentedMindmapLine {
  const _IndentedMindmapLine({
    required this.indent,
    required this.content,
  });

  final int indent;
  final String content;
}

class _ParsedMindmapNode {
  const _ParsedMindmapNode({
    required this.id,
    required this.label,
    required this.shape,
    this.className,
    this.icon,
  });

  final String id;
  final String label;
  final MindmapNodeShape shape;
  final String? className;
  final String? icon;
}

class _MutableMindmapNode {
  _MutableMindmapNode({
    required this.indent,
    required this.id,
    required this.label,
    required this.shape,
    this.className,
    this.icon,
  });

  final int indent;
  final String id;
  final String label;
  final MindmapNodeShape shape;
  final String? className;
  final String? icon;
  final List<_MutableMindmapNode> children = [];
}

class _ShapePattern {
  const _ShapePattern(this.expression, this.shape);

  final RegExp expression;
  final MindmapNodeShape shape;
}