import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';

/// Helper class for arrow information
class _ArrowInfo {
  const _ArrowInfo(this.type, this.label);
  final String type;
  final String? label;
}

/// Parser for Mermaid flowchart diagrams
///
/// Supports syntax like:
/// ```
/// graph TD
///   A[Start] --> B{Decision}
///   B -->|Yes| C[OK]
///   B -->|No| D[Cancel]
/// ```
class FlowchartParser {
  final Map<String, MermaidNode> _nodes = {};
  final List<MermaidEdge> _edges = [];
  final List<Subgraph> _subgraphs = [];
  final Map<String, NodeStyle> _classDefs = {};
  final Map<String, String> _nodeClasses = {};

  // Subgraph parsing state
  String? _currentSubgraphId;
  String? _currentSubgraphLabel;
  final List<String> _currentSubgraphNodes = [];
  final List<_SubgraphState> _subgraphStack = [];
  final Set<String> _subgraphIds = {}; // Track all subgraph IDs

  DiagramDirection _direction = DiagramDirection.topToBottom;

  /// Parses flowchart lines into diagram data
  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    _nodes.clear();
    _edges.clear();
    _subgraphs.clear();
    _classDefs.clear();
    _nodeClasses.clear();
    _currentSubgraphId = null;
    _currentSubgraphLabel = null;
    _currentSubgraphNodes.clear();
    _subgraphStack.clear();
    _subgraphIds.clear();

    // Parse first line for direction
    final firstLine = lines.first.trim().toLowerCase();
    _parseDirection(firstLine);

    // Parse remaining lines
    for (var i = 1; i < lines.length; i++) {
      _parseLine(lines[i]);
    }

    // Apply class styles to nodes
    _applyClassStyles();

    return MermaidDiagramData(
      type: DiagramType.flowchart,
      nodes: _nodes.values.toList(),
      edges: _edges,
      direction: _direction,
      subgraphs: _subgraphs,
      style: MermaidStyle(classDefs: _classDefs),
    );
  }

  void _parseDirection(String line) {
    if (line.contains(' td') || line.contains(' tb')) {
      _direction = DiagramDirection.topToBottom;
    } else if (line.contains(' bt')) {
      _direction = DiagramDirection.bottomToTop;
    } else if (line.contains(' lr')) {
      _direction = DiagramDirection.leftToRight;
    } else if (line.contains(' rl')) {
      _direction = DiagramDirection.rightToLeft;
    }
  }

  void _parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    // Parse classDef
    if (trimmed.startsWith('classDef ')) {
      _parseClassDef(trimmed);
      return;
    }

    // Parse class assignment
    if (trimmed.startsWith('class ')) {
      _parseClassAssignment(trimmed);
      return;
    }

    // Parse style
    if (trimmed.startsWith('style ')) {
      _parseStyle(trimmed);
      return;
    }

    // Parse subgraph
    if (trimmed.startsWith('subgraph ')) {
      _parseSubgraphStart(trimmed);
      return;
    }

    if (trimmed == 'end') {
      _parseSubgraphEnd();
      return;
    }

    // Parse node and edge definitions
    _parseNodeOrEdge(trimmed);
  }

  void _parseSubgraphStart(String line) {
    // Parse: "subgraph id [label]" or "subgraph label"
    final trimmed = line.substring(9).trim(); // Remove "subgraph "

    // Save current subgraph state if we're in one (nested subgraph)
    if (_currentSubgraphId != null) {
      _subgraphStack.add(_SubgraphState(
        id: _currentSubgraphId!,
        label: _currentSubgraphLabel ?? _currentSubgraphId!,
        nodeIds: List.from(_currentSubgraphNodes),
      ));
    }

    // Parse id and label
    // Format can be: "subgraph id" or "subgraph id [label]" or "subgraph label"
    final bracketMatch = RegExp(r'^(\w+)\s*\[(.+)\]$').firstMatch(trimmed);
    if (bracketMatch != null) {
      _currentSubgraphId = bracketMatch.group(1);
      _currentSubgraphLabel = bracketMatch.group(2);
    } else {
      // Use the text as both id and label
      final parts = trimmed.split(RegExp(r'\s+'));
      _currentSubgraphId = parts.isNotEmpty ? parts[0] : 'subgraph_${_subgraphs.length}';
      _currentSubgraphLabel = trimmed;
    }

    // Record subgraph ID
    if (_currentSubgraphId != null) {
      _subgraphIds.add(_currentSubgraphId!);
    }

    _currentSubgraphNodes.clear();
  }

  void _parseSubgraphEnd() {
    if (_currentSubgraphId != null) {
      // Create the subgraph
      _subgraphs.add(Subgraph(
        id: _currentSubgraphId!,
        label: _currentSubgraphLabel ?? _currentSubgraphId!,
        nodeIds: List.from(_currentSubgraphNodes),
      ));

      // Restore parent subgraph state if any
      if (_subgraphStack.isNotEmpty) {
        final parent = _subgraphStack.removeLast();
        // Add this subgraph's nodes to parent
        parent.nodeIds.addAll(_currentSubgraphNodes);
        _currentSubgraphId = parent.id;
        _currentSubgraphLabel = parent.label;
        _currentSubgraphNodes
          ..clear()
          ..addAll(parent.nodeIds);
      } else {
        _currentSubgraphId = null;
        _currentSubgraphLabel = null;
        _currentSubgraphNodes.clear();
      }
    }
  }

  /// Tracks a node ID for the current subgraph
  void _trackNodeForSubgraph(String nodeId) {
    if (_currentSubgraphId != null && !_currentSubgraphNodes.contains(nodeId)) {
      _currentSubgraphNodes.add(nodeId);
    }
  }

  void _parseNodeOrEdge(String line) {
    // Split line by arrows to get individual node-edge pairs
    // Arrows: -->, ==>, ---, -.->
    final arrowRegex = RegExp(r'\s*(==>|-->|---|\.\.\.|===|-.->|-\.->|---->|====|---)\s*(\|[^|]*\|)?\s*');

    final parts = <String>[];
    final arrows = <_ArrowInfo>[];

    var lastEnd = 0;
    for (final match in arrowRegex.allMatches(line)) {
      if (match.start > lastEnd) {
        parts.add(line.substring(lastEnd, match.start).trim());
      }
      String? label;
      if (match.group(2) != null) {
        final labelStr = match.group(2)!;
        label = labelStr.substring(1, labelStr.length - 1);
      }
      arrows.add(_ArrowInfo(match.group(1)!, label));
      lastEnd = match.end;
    }
    // Add the last part
    if (lastEnd < line.length) {
      parts.add(line.substring(lastEnd).trim());
    }

    if (parts.length < 2 || arrows.isEmpty) {
      // Not an edge definition, try parsing as single node
      final node = _parseNode(line);
      if (node != null && !_subgraphIds.contains(node.id)) {
        _nodes[node.id] = node;
        _trackNodeForSubgraph(node.id);
      }
      return;
    }

    // Process all nodes and edges
    for (var i = 0; i < parts.length; i++) {
      final nodeId = _extractId(parts[i]);

      // Skip if this is a subgraph ID (don't create node for subgraph reference)
      if (!_subgraphIds.contains(nodeId)) {
        final node = _parseNode(parts[i]);
        if (node != null) {
          // Only add node if not exists, or update if new one has shape/label info
          if (!_nodes.containsKey(node.id) || _shouldUpdateNode(_nodes[node.id]!, node)) {
            _nodes[node.id] = node;
          }
          _trackNodeForSubgraph(node.id);
        }
      }

      // Create edge between consecutive nodes/subgraphs
      if (i < arrows.length && i + 1 < parts.length) {
        final fromId = _extractId(parts[i]);
        final toId = _extractId(parts[i + 1]);

        // Check if either endpoint is a subgraph
        final isFromSubgraph = _subgraphIds.contains(fromId);
        final isToSubgraph = _subgraphIds.contains(toId);

        // Create edge - the edge system will handle subgraph edges
        final arrow = arrows[i];
        final edge = MermaidEdge(
          from: fromId,
          to: toId,
          label: arrow.label,
          arrowType: _parseArrowType(arrow.type),
          lineType: _parseLineType(arrow.type),
          isSubgraphEdge: isFromSubgraph || isToSubgraph,
        );
        _edges.add(edge);
      }
    }
  }

  /// Determines if a new node should replace an existing node
  bool _shouldUpdateNode(MermaidNode existing, MermaidNode newNode) {
    // Update if existing is plain (just ID as label) and new has different label
    if (existing.label == existing.id && newNode.label != newNode.id) {
      return true;
    }
    // Update if new node has a non-rectangle shape
    if (existing.shape == NodeShape.rectangle && newNode.shape != NodeShape.rectangle) {
      return true;
    }
    return false;
  }

  /// Extracts just the ID from a node string like "B{label}" -> "B"
  String _extractId(String nodeStr) {
    final match = RegExp(r'^(\w+)').firstMatch(nodeStr);
    return match?.group(1) ?? nodeStr;
  }

  /// Parses a node definition and returns a MermaidNode
  MermaidNode? _parseNode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Try to match different node shapes
    // [text] - rectangle
    // (text) - rounded rect
    // ([text]) - stadium
    // {text} - diamond
    // {{text}} - hexagon
    // ((text)) - circle
    // [[text]] - subroutine
    // [(text)] - cylinder
    // >text] - asymmetric

    String id;
    String label;
    NodeShape shape;

    // Double bracket patterns first
    final doubleCircle = RegExp(r'^(\w+)\(\((.+)\)\)$');
    final hexagon = RegExp(r'^(\w+)\{\{(.+)\}\}$');
    final subroutine = RegExp(r'^(\w+)\[\[(.+)\]\]$');
    final cylinder = RegExp(r'^(\w+)\[\((.+)\)\]$');
    final stadium = RegExp(r'^(\w+)\(\[(.+)\]\)$');

    // Single bracket patterns
    final rectangle = RegExp(r'^(\w+)\[(.+)\]$');
    final roundedRect = RegExp(r'^(\w+)\((.+)\)$');
    final diamond = RegExp(r'^(\w+)\{(.+)\}$');
    final asymmetric = RegExp(r'^(\w+)>(.+)\]$');

    // Parallelogram patterns
    final parallelogram = RegExp(r'^(\w+)\[/(.+)/\]$');
    final parallelogramAlt = RegExp(r'^(\w+)\[\\(.+)\\\]$');
    final trapezoid = RegExp(r'^(\w+)\[/(.+)\\\]$');
    final trapezoidAlt = RegExp(r'^(\w+)\[\\(.+)/\]$');

    Match? match;

    if ((match = doubleCircle.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.circle;
    } else if ((match = hexagon.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.hexagon;
    } else if ((match = subroutine.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.subroutine;
    } else if ((match = cylinder.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.cylinder;
    } else if ((match = stadium.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.stadium;
    } else if ((match = parallelogram.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.parallelogram;
    } else if ((match = parallelogramAlt.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.parallelogramAlt;
    } else if ((match = trapezoid.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.trapezoid;
    } else if ((match = trapezoidAlt.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.trapezoidAlt;
    } else if ((match = asymmetric.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.asymmetric;
    } else if ((match = rectangle.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.rectangle;
    } else if ((match = roundedRect.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.roundedRect;
    } else if ((match = diamond.firstMatch(trimmed)) != null) {
      id = match!.group(1)!;
      label = match.group(2)!;
      shape = NodeShape.diamond;
    } else {
      // Plain node ID without shape
      final plainId = RegExp(r'^(\w+)$').firstMatch(trimmed);
      if (plainId != null) {
        id = plainId.group(1)!;
        label = id;
        shape = NodeShape.rectangle;
      } else {
        return null;
      }
    }

    // Handle escaped quotes in labels
    label = label.replaceAll('\\"', '"').replaceAll("\\'", "'");

    return MermaidNode(
      id: id,
      label: label,
      shape: shape,
    );
  }

  ArrowType _parseArrowType(String arrow) {
    if (arrow.contains('x')) return ArrowType.cross;
    if (arrow.contains('o')) return ArrowType.circle;
    if (arrow.contains('>')) return ArrowType.arrow;
    return ArrowType.none;
  }

  LineType _parseLineType(String arrow) {
    if (arrow.contains('=')) return LineType.thick;
    if (arrow.contains('.') || arrow.contains('-.')) return LineType.dotted;
    return LineType.solid;
  }

  void _parseClassDef(String line) {
    // classDef className fill:#f9f,stroke:#333,stroke-width:4px
    final pattern = RegExp(r'classDef\s+(\w+)\s+(.+)');
    final match = pattern.firstMatch(line);
    if (match == null) return;

    final className = match.group(1)!;
    final styleStr = match.group(2)!;

    final style = _parseStyleString(styleStr);
    if (style != null) {
      _classDefs[className] = style;
    }
  }

  void _parseClassAssignment(String line) {
    // class nodeId1,nodeId2 className
    final pattern = RegExp(r'class\s+([^\s]+)\s+(\w+)');
    final match = pattern.firstMatch(line);
    if (match == null) return;

    final nodeIds = match.group(1)!.split(',');
    final className = match.group(2)!;

    for (final nodeId in nodeIds) {
      _nodeClasses[nodeId.trim()] = className;
    }
  }

  void _parseStyle(String line) {
    // style nodeId fill:#f9f,stroke:#333
    final pattern = RegExp(r'style\s+(\w+)\s+(.+)');
    final match = pattern.firstMatch(line);
    if (match == null) return;

    final nodeId = match.group(1)!;
    final styleStr = match.group(2)!;

    final style = _parseStyleString(styleStr);
    if (style != null && _nodes.containsKey(nodeId)) {
      final node = _nodes[nodeId]!;
      _nodes[nodeId] = node.copyWith(style: style);
    }
  }

  NodeStyle? _parseStyleString(String styleStr) {
    int? fillColor;
    int? strokeColor;
    double strokeWidth = 1.0;
    int? textColor;

    final props = styleStr.split(',');
    for (final prop in props) {
      final parts = prop.split(':');
      if (parts.length != 2) continue;

      final key = parts[0].trim();
      final value = parts[1].trim();

      switch (key) {
        case 'fill':
          fillColor = _parseColor(value);
          break;
        case 'stroke':
          strokeColor = _parseColor(value);
          break;
        case 'stroke-width':
          strokeWidth = double.tryParse(
                value.replaceAll('px', ''),
              ) ??
              1.0;
          break;
        case 'color':
          textColor = _parseColor(value);
          break;
      }
    }

    return NodeStyle(
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      textColor: textColor,
    );
  }

  int? _parseColor(String color) {
    if (color.startsWith('#')) {
      final hex = color.substring(1);
      if (hex.length == 3) {
        // Short form: #rgb -> #rrggbb
        final r = hex[0] + hex[0];
        final g = hex[1] + hex[1];
        final b = hex[2] + hex[2];
        return int.tryParse('FF$r$g$b', radix: 16);
      } else if (hex.length == 6) {
        return int.tryParse('FF$hex', radix: 16);
      } else if (hex.length == 8) {
        return int.tryParse(hex, radix: 16);
      }
    }

    // Named colors
    return _namedColors[color.toLowerCase()];
  }

  void _applyClassStyles() {
    for (final entry in _nodeClasses.entries) {
      final nodeId = entry.key;
      final className = entry.value;

      if (_nodes.containsKey(nodeId) && _classDefs.containsKey(className)) {
        final node = _nodes[nodeId]!;
        _nodes[nodeId] = node.copyWith(
          className: className,
          style: _classDefs[className],
        );
      }
    }
  }

  static const Map<String, int> _namedColors = {
    'red': 0xFFFF0000,
    'green': 0xFF00FF00,
    'blue': 0xFF0000FF,
    'white': 0xFFFFFFFF,
    'black': 0xFF000000,
    'yellow': 0xFFFFFF00,
    'orange': 0xFFFFA500,
    'purple': 0xFF800080,
    'pink': 0xFFFFC0CB,
    'cyan': 0xFF00FFFF,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'lightgray': 0xFFD3D3D3,
    'lightgrey': 0xFFD3D3D3,
    'darkgray': 0xFFA9A9A9,
    'darkgrey': 0xFFA9A9A9,
  };
}

/// Helper class to track subgraph state during parsing
class _SubgraphState {
  _SubgraphState({
    required this.id,
    required this.label,
    required this.nodeIds,
  });

  final String id;
  final String label;
  final List<String> nodeIds;
}
