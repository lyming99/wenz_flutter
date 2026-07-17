import 'dart:math' as math;
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'layout_engine.dart';

/// Dagre-style hierarchical graph layout algorithm
///
/// This implements a simplified version of the Dagre layout algorithm
/// which is used by Mermaid.js for rendering flowcharts.
class DagreLayout extends LayoutEngine {
  /// Creates a Dagre layout engine
  const DagreLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Check if we have subgraphs
    if (diagram.subgraphs.isNotEmpty) {
      return _computeSubgraphLayout(diagram, style, availableSize);
    }

    final context = _LayoutContext(diagram, style);

    // Step 1: Measure all nodes
    _measureNodes(context);

    // Step 2: Build graph structure
    _buildGraph(context);

    // Step 3: Assign ranks using topological sort (BFS)
    _assignRanks(context);

    // Step 4: Order nodes within layers to minimize crossings
    _orderNodes(context);

    // Step 5: Assign coordinates
    return _assignCoordinates(context);
  }

  /// Computes layout for diagrams with subgraphs
  Size _computeSubgraphLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    final isHorizontal = diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;

    // Build a mapping of node IDs to their subgraph
    final nodeToSubgraph = <String, Subgraph>{};
    for (final sg in diagram.subgraphs) {
      for (final nodeId in sg.nodeIds) {
        nodeToSubgraph[nodeId] = sg;
      }
    }

    // Measure all nodes first
    for (final node in diagram.nodes) {
      final size = measureNodeWithShape(node, style);
      node.width = size.width;
      node.height = size.height;
    }

    // Group nodes by subgraph
    final subgraphNodes = <String, List<MermaidNode>>{};
    final standaloneNodes = <MermaidNode>[];

    for (final node in diagram.nodes) {
      final sg = nodeToSubgraph[node.id];
      if (sg != null) {
        subgraphNodes[sg.id] ??= [];
        subgraphNodes[sg.id]!.add(node);
      } else {
        standaloneNodes.add(node);
      }
    }

    // Calculate layout for each subgraph
    final subgraphBounds = <String, Rect>{};
    final padding = style.padding;
    final subgraphPadding = 40.0; // Internal padding for subgraph
    final subgraphTitleHeight = 30.0;
    final subgraphSpacing = style.nodeSpacingX;

    double currentX = padding;
    double maxHeight = 0;

    // Layout subgraphs horizontally (for TD direction) or vertically (for LR)
    for (final sg in diagram.subgraphs) {
      final nodes = subgraphNodes[sg.id] ?? [];
      if (nodes.isEmpty) continue;

      // Layout nodes within subgraph
      double sgWidth = 0;
      double sgHeight = subgraphTitleHeight;
      double nodeY = subgraphTitleHeight + subgraphPadding / 2;
      double nodeX = subgraphPadding / 2;

      // Simple horizontal layout within each subgraph
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];

        if (isHorizontal) {
          // Vertical arrangement for LR direction
          node.x = currentX + subgraphPadding / 2;
          node.y = nodeY;
          nodeY += node.height + style.nodeSpacingY * 0.5;
          sgWidth = math.max(sgWidth, node.width + subgraphPadding);
          sgHeight = nodeY + subgraphPadding / 2;
        } else {
          // Horizontal arrangement for TD direction
          node.x = currentX + nodeX;
          node.y = padding + nodeY;
          nodeX += node.width + style.nodeSpacingX * 0.5;
          sgWidth = nodeX + subgraphPadding / 2;
          sgHeight = math.max(sgHeight, subgraphTitleHeight + node.height + subgraphPadding);
        }
      }

      // Store subgraph bounds
      subgraphBounds[sg.id] = Rect.fromLTWH(
        currentX,
        padding,
        sgWidth,
        sgHeight,
      );

      currentX += sgWidth + subgraphSpacing;
      maxHeight = math.max(maxHeight, sgHeight);
    }

    // Handle edges between subgraphs
    // For "Frontend --> Backend" style edges, we need to draw from subgraph to subgraph
    // This is handled in the painter

    final totalWidth = currentX - subgraphSpacing + padding;
    final totalHeight = maxHeight + padding * 2;

    return Size(totalWidth, totalHeight);
  }

  void _measureNodes(_LayoutContext context) {
    for (final node in context.diagram.nodes) {
      final size = measureNodeWithShape(node, context.style);
      node.width = size.width;
      node.height = size.height;
    }
  }

  /// Measures node size considering shape requirements
  Size measureNodeWithShape(MermaidNode node, MermaidStyle style) {
    final nodeStyle = style.getNodeStyle(node.className);
    final fontSize = nodeStyle.fontSize;

    // Calculate text dimensions
    final textWidth = _measureTextWidth(node.label, fontSize);
    final textHeight = fontSize * 1.4;

    // Shape-specific sizing
    switch (node.shape) {
      case NodeShape.diamond:
        // Diamond needs extra space for the rotated square
        final innerWidth = textWidth + 20;
        final innerHeight = textHeight + 12;
        final size = math.max(innerWidth, innerHeight) * 1.5;
        return Size(math.max(size, 90), math.max(size * 0.8, 70));

      case NodeShape.circle:
      case NodeShape.doubleCircle:
        final diameter = math.max(textWidth, textHeight) + 40;
        return Size(diameter, diameter);

      case NodeShape.hexagon:
        return Size(textWidth + 60, textHeight + 32);

      case NodeShape.stadium:
        return Size(textWidth + 40, textHeight + 24);

      case NodeShape.cylinder:
        return Size(textWidth + 32, textHeight + 40);

      case NodeShape.parallelogram:
      case NodeShape.parallelogramAlt:
        return Size(textWidth + 50, textHeight + 20);

      case NodeShape.trapezoid:
      case NodeShape.trapezoidAlt:
        return Size(textWidth + 40, textHeight + 20);

      case NodeShape.subroutine:
        return Size(textWidth + 40, textHeight + 20);

      case NodeShape.roundedRect:
        return Size(textWidth + 32, textHeight + 20);

      default:
        // Rectangle
        return Size(textWidth + 28, textHeight + 16);
    }
  }

  double _measureTextWidth(String text, double fontSize) {
    double width = 0;
    for (final char in text.runes) {
      if (char > 0x4E00 && char < 0x9FFF) {
        width += fontSize * 1.0; // CJK character
      } else {
        width += fontSize * 0.6; // Latin character
      }
    }
    return width;
  }

  void _buildGraph(_LayoutContext context) {
    // Initialize adjacency lists
    for (final node in context.diagram.nodes) {
      context.successors[node.id] = [];
      context.predecessors[node.id] = [];
    }

    // Build edges, handling back-edges (cycles)
    for (final edge in context.diagram.edges) {
      context.successors[edge.from]?.add(edge.to);
      context.predecessors[edge.to]?.add(edge.from);
    }

    // Find root nodes (no incoming edges)
    context.roots = context.diagram.nodes
        .where((n) => context.predecessors[n.id]?.isEmpty ?? true)
        .map((n) => n.id)
        .toList();

    // If no roots found (all cycles), use first node
    if (context.roots.isEmpty && context.diagram.nodes.isNotEmpty) {
      context.roots = [context.diagram.nodes.first.id];
    }
  }

  /// Assign ranks using BFS from roots, ignoring back-edges
  /// This follows the standard Mermaid/Dagre approach
  void _assignRanks(_LayoutContext context) {
    final ranks = <String, int>{};

    // First pass: identify back-edges by doing DFS to find cycles
    final backEdges = <String, Set<String>>{};
    final visited = <String>{};
    final inStack = <String>{};

    void findBackEdges(String nodeId) {
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);
      inStack.add(nodeId);

      for (final succId in context.successors[nodeId] ?? <String>[]) {
        if (inStack.contains(succId)) {
          // This is a back-edge
          backEdges[nodeId] ??= {};
          backEdges[nodeId]!.add(succId);
        } else if (!visited.contains(succId)) {
          findBackEdges(succId);
        }
      }

      inStack.remove(nodeId);
    }

    // Find all back-edges
    for (final root in context.roots) {
      findBackEdges(root);
    }
    // Also check from any unvisited nodes
    for (final node in context.diagram.nodes) {
      if (!visited.contains(node.id)) {
        findBackEdges(node.id);
      }
    }

    // Helper to check if an edge is a back-edge
    bool isBackEdge(String from, String to) {
      return (backEdges[from] ?? {}).contains(to);
    }

    // Second pass: Calculate ranks based on direct predecessor only
    // Each node's rank = predecessor's rank + 1, ignoring back-edges
    // For nodes with multiple non-back-edge predecessors, use the first one encountered

    final queue = <String>[];

    // Initialize with roots
    for (final root in context.roots) {
      ranks[root] = 0;
      queue.add(root);
    }

    // Also add any node with zero non-back-edge predecessors
    for (final node in context.diagram.nodes) {
      if (!ranks.containsKey(node.id)) {
        final preds = context.predecessors[node.id] ?? [];
        final nonBackPreds = preds.where((predId) => !isBackEdge(predId, node.id)).toList();
        if (nonBackPreds.isEmpty) {
          ranks[node.id] = 0;
          queue.add(node.id);
        }
      }
    }

    // BFS to assign ranks - siblings from same parent get same rank
    while (queue.isNotEmpty) {
      final nodeId = queue.removeAt(0);
      final currentRank = ranks[nodeId]!;

      // Get all successors that are not back-edges
      final successors = (context.successors[nodeId] ?? <String>[])
          .where((succId) => !isBackEdge(nodeId, succId))
          .toList();

      for (final succId in successors) {
        final newRank = currentRank + 1;

        // Only set rank if not already set
        // This ensures nodes keep the rank from their first parent
        if (!ranks.containsKey(succId)) {
          ranks[succId] = newRank;
          queue.add(succId);
        }
      }
    }

    // Handle any unranked nodes
    var maxRank = ranks.values.isEmpty ? 0 : ranks.values.reduce(math.max);
    for (final node in context.diagram.nodes) {
      if (!ranks.containsKey(node.id)) {
        ranks[node.id] = maxRank + 1;
      }
    }

    // Apply ranks to nodes
    for (final node in context.diagram.nodes) {
      node.rank = ranks[node.id] ?? 0;
    }

    // Group nodes by rank
    context.layers.clear();
    for (final node in context.diagram.nodes) {
      while (context.layers.length <= node.rank) {
        context.layers.add([]);
      }
      context.layers[node.rank].add(node);
    }

    // Store back-edges info for edge drawing
    context.backEdges = backEdges;
  }

  void _orderNodes(_LayoutContext context) {
    if (context.layers.isEmpty) return;

    // Build edge order map - tracks the order of successors for each node
    final edgeOrder = <String, Map<String, int>>{};
    for (final node in context.diagram.nodes) {
      edgeOrder[node.id] = {};
      final succs = context.successors[node.id] ?? [];
      for (var i = 0; i < succs.length; i++) {
        edgeOrder[node.id]![succs[i]] = i;
      }
    }

    // Initial ordering: preserve edge definition order from parent
    for (var layerIdx = 0; layerIdx < context.layers.length; layerIdx++) {
      final layer = context.layers[layerIdx];

      if (layerIdx == 0) {
        // First layer: use original order
        for (var i = 0; i < layer.length; i++) {
          layer[i].order = i;
        }
      } else {
        // Order by parent's edge order
        final prevLayer = context.layers[layerIdx - 1];
        layer.sort((a, b) {
          // Find common parent and compare edge order
          for (final pred in prevLayer) {
            final orderA = edgeOrder[pred.id]?[a.id];
            final orderB = edgeOrder[pred.id]?[b.id];
            if (orderA != null && orderB != null) {
              return orderA.compareTo(orderB);
            }
          }
          // If no common parent, use barycenter
          return 0;
        });

        for (var i = 0; i < layer.length; i++) {
          layer[i].order = i;
        }
      }
    }

    // Refine with barycenter heuristic (fewer iterations to preserve initial order)
    for (var iter = 0; iter < 4; iter++) {
      // Forward sweep (top to bottom)
      for (var i = 1; i < context.layers.length; i++) {
        _orderLayerByBarycenter(
          context.layers[i],
          context.layers[i - 1],
          context.predecessors,
        );
      }

      // Backward sweep (bottom to top)
      for (var i = context.layers.length - 2; i >= 0; i--) {
        _orderLayerByBarycenter(
          context.layers[i],
          context.layers[i + 1],
          context.successors,
        );
      }
    }

    // Final order assignment
    for (final layer in context.layers) {
      for (var i = 0; i < layer.length; i++) {
        layer[i].order = i;
      }
    }
  }

  void _orderLayerByBarycenter(
    List<MermaidNode> layer,
    List<MermaidNode> adjacentLayer,
    Map<String, List<String>> connections,
  ) {
    if (layer.isEmpty || adjacentLayer.isEmpty) return;

    // Build position map for adjacent layer
    final posMap = <String, double>{};
    for (var i = 0; i < adjacentLayer.length; i++) {
      posMap[adjacentLayer[i].id] = i.toDouble();
    }

    // Calculate barycenter for each node
    final barycenters = <MermaidNode, double>{};
    for (final node in layer) {
      final connected = connections[node.id] ?? [];
      final positions = connected
          .where((id) => posMap.containsKey(id))
          .map((id) => posMap[id]!)
          .toList();

      if (positions.isEmpty) {
        // Keep relative position
        barycenters[node] = node.order.toDouble();
      } else {
        // Average position of connected nodes
        barycenters[node] = positions.reduce((a, b) => a + b) / positions.length;
      }
    }

    // Sort by barycenter
    layer.sort((a, b) => barycenters[a]!.compareTo(barycenters[b]!));

    // Update order
    for (var i = 0; i < layer.length; i++) {
      layer[i].order = i;
    }
  }

  Size _assignCoordinates(_LayoutContext context) {
    final direction = context.diagram.direction;
    final isHorizontal = direction == DiagramDirection.leftToRight ||
        direction == DiagramDirection.rightToLeft;

    final style = context.style;
    // Increase spacing for better readability
    final rankSep = (isHorizontal ? style.nodeSpacingX : style.nodeSpacingY) * 1.2;
    final nodeSep = (isHorizontal ? style.nodeSpacingY : style.nodeSpacingX) * 1.0;

    // Calculate max width for each layer (for centering)
    final layerMaxSizes = <double>[];
    double maxLayerWidth = 0;

    for (final layer in context.layers) {
      double layerWidth = 0;
      double layerHeight = 0;

      for (final node in layer) {
        if (isHorizontal) {
          layerHeight += node.height + nodeSep;
          layerWidth = math.max(layerWidth, node.width);
        } else {
          layerWidth += node.width + nodeSep;
          layerHeight = math.max(layerHeight, node.height);
        }
      }

      if (isHorizontal) {
        layerHeight -= nodeSep;
        layerMaxSizes.add(layerWidth);
        maxLayerWidth = math.max(maxLayerWidth, layerHeight);
      } else {
        layerWidth -= nodeSep;
        layerMaxSizes.add(layerHeight);
        maxLayerWidth = math.max(maxLayerWidth, layerWidth);
      }
    }

    // Position nodes
    double mainOffset = style.padding;
    double totalWidth = 0;
    double totalHeight = 0;

    for (var layerIdx = 0; layerIdx < context.layers.length; layerIdx++) {
      final layer = context.layers[layerIdx];

      // Calculate layer's total cross size
      double layerCrossSize = 0;
      for (final node in layer) {
        layerCrossSize += (isHorizontal ? node.height : node.width) + nodeSep;
      }
      layerCrossSize -= nodeSep;

      // Center the layer
      double crossOffset = style.padding + (maxLayerWidth - layerCrossSize) / 2;

      for (final node in layer) {
        if (isHorizontal) {
          node.x = mainOffset;
          node.y = crossOffset;
          crossOffset += node.height + nodeSep;
          totalHeight = math.max(totalHeight, node.y + node.height);
        } else {
          node.x = crossOffset;
          node.y = mainOffset;
          crossOffset += node.width + nodeSep;
          totalWidth = math.max(totalWidth, node.x + node.width);
        }
      }

      // Move to next layer
      final maxMain = layer.isEmpty ? 0.0 : layer.map((n) =>
          isHorizontal ? n.width : n.height).reduce(math.max);
      mainOffset += maxMain + rankSep;
    }

    if (isHorizontal) {
      totalWidth = mainOffset - rankSep + style.padding;
      totalHeight += style.padding;
    } else {
      totalHeight = mainOffset - rankSep + style.padding;
      totalWidth += style.padding;
    }

    // Apply direction reversal
    if (direction == DiagramDirection.rightToLeft) {
      for (final node in context.diagram.nodes) {
        node.x = totalWidth - node.x - node.width;
      }
    } else if (direction == DiagramDirection.bottomToTop) {
      for (final node in context.diagram.nodes) {
        node.y = totalHeight - node.y - node.height;
      }
    }

    return Size(totalWidth, totalHeight);
  }
}

/// Internal context for layout computation
class _LayoutContext {
  _LayoutContext(this.diagram, this.style) {
    nodeMap = {for (final n in diagram.nodes) n.id: n};
  }

  final MermaidDiagramData diagram;
  final MermaidStyle style;

  late final Map<String, MermaidNode> nodeMap;
  final Map<String, List<String>> successors = {};
  final Map<String, List<String>> predecessors = {};
  List<String> roots = [];
  final List<List<MermaidNode>> layers = [];
  Map<String, Set<String>> backEdges = {};
}
