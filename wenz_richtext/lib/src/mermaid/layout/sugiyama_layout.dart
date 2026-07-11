import 'dart:math' as math;
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'layout_engine.dart';

/// Sugiyama-style hierarchical graph layout algorithm
///
/// This layout algorithm is suitable for directed graphs (DAGs) and produces
/// a layered layout similar to what Mermaid.js uses. The algorithm consists
/// of these phases:
///
/// 1. Cycle removal (make the graph acyclic)
/// 2. Layer assignment (assign nodes to horizontal/vertical layers)
/// 3. Crossing reduction (minimize edge crossings within layers)
/// 4. Coordinate assignment (position nodes within layers)
class SugiyamaLayout extends LayoutEngine {
  /// Creates a Sugiyama layout engine
  const SugiyamaLayout();

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Measure all nodes first
    for (final node in diagram.nodes) {
      final size = measureNode(node, style);
      node.width = size.width;
      node.height = size.height;
    }

    // Build adjacency map
    final graph = _buildGraph(diagram);

    // Step 1: Assign layers (ranks)
    _assignLayers(diagram.nodes, graph);

    // Step 2: Order nodes within layers to minimize crossings
    final layers = _groupByLayer(diagram.nodes);
    _minimizeCrossings(layers, graph);

    // Step 3: Assign coordinates
    return _assignCoordinates(layers, diagram.direction, style);
  }

  /// Builds an adjacency list from edges
  Map<String, List<String>> _buildGraph(MermaidDiagramData diagram) {
    final graph = <String, List<String>>{};

    // Initialize all nodes
    for (final node in diagram.nodes) {
      graph[node.id] = [];
    }

    // Add edges
    for (final edge in diagram.edges) {
      if (graph.containsKey(edge.from)) {
        graph[edge.from]!.add(edge.to);
      }
    }

    return graph;
  }

  /// Assigns layers to nodes using longest path algorithm
  void _assignLayers(List<MermaidNode> nodes, Map<String, List<String>> graph) {
    final nodeMap = {for (final n in nodes) n.id: n};
    final visited = <String>{};
    final inProgress = <String>{};

    // Find root nodes (no incoming edges)
    final hasIncoming = <String>{};
    for (final edges in graph.values) {
      hasIncoming.addAll(edges);
    }
    final roots =
        nodes.where((n) => !hasIncoming.contains(n.id)).map((n) => n.id);

    // Calculate depth for each node using DFS
    int calculateDepth(String nodeId) {
      if (visited.contains(nodeId)) {
        return nodeMap[nodeId]!.rank;
      }

      // Cycle detection
      if (inProgress.contains(nodeId)) {
        return 0;
      }

      inProgress.add(nodeId);

      int maxChildDepth = -1;
      for (final childId in graph[nodeId] ?? <String>[]) {
        maxChildDepth = math.max(maxChildDepth, calculateDepth(childId));
      }

      inProgress.remove(nodeId);
      visited.add(nodeId);

      nodeMap[nodeId]!.rank = maxChildDepth + 1;
      return maxChildDepth + 1;
    }

    // Start from roots, or all nodes if no roots found
    final startNodes = roots.isEmpty ? nodes.map((n) => n.id) : roots;
    for (final nodeId in startNodes) {
      calculateDepth(nodeId);
    }

    // Process any remaining unvisited nodes
    for (final node in nodes) {
      if (!visited.contains(node.id)) {
        calculateDepth(node.id);
      }
    }

    // Invert ranks so roots are at top (rank 0)
    if (nodes.isEmpty) return;
    final maxRank = nodes.map((n) => n.rank).reduce(math.max);
    for (final node in nodes) {
      node.rank = maxRank - node.rank;
    }
  }

  /// Groups nodes by their layer
  List<List<MermaidNode>> _groupByLayer(List<MermaidNode> nodes) {
    if (nodes.isEmpty) return [];
    final maxRank = nodes.map((n) => n.rank).reduce(math.max);
    final layers = List<List<MermaidNode>>.generate(maxRank + 1, (_) => []);

    for (final node in nodes) {
      layers[node.rank].add(node);
    }

    return layers;
  }

  /// Minimizes edge crossings using barycenter heuristic
  void _minimizeCrossings(
    List<List<MermaidNode>> layers,
    Map<String, List<String>> graph,
  ) {
    // Build reverse graph for looking up parents
    final reverseGraph = <String, List<String>>{};
    for (final entry in graph.entries) {
      for (final target in entry.value) {
        reverseGraph.putIfAbsent(target, () => []).add(entry.key);
      }
    }

    // Multiple passes to improve ordering
    for (var iteration = 0; iteration < 4; iteration++) {
      // Forward pass (top to bottom)
      for (var i = 1; i < layers.length; i++) {
        _orderLayerByBarycenter(layers[i], layers[i - 1], reverseGraph);
      }

      // Backward pass (bottom to top)
      for (var i = layers.length - 2; i >= 0; i--) {
        _orderLayerByBarycenter(layers[i], layers[i + 1], graph);
      }
    }

    // Assign order indices
    for (final layer in layers) {
      for (var i = 0; i < layer.length; i++) {
        layer[i].order = i;
      }
    }
  }

  /// Orders a layer based on barycenter of connected nodes in adjacent layer
  void _orderLayerByBarycenter(
    List<MermaidNode> layer,
    List<MermaidNode> adjacentLayer,
    Map<String, List<String>> connections,
  ) {
    // Create position map for adjacent layer
    final positionMap = <String, int>{};
    for (var i = 0; i < adjacentLayer.length; i++) {
      positionMap[adjacentLayer[i].id] = i;
    }

    // Calculate barycenter for each node
    final barycenters = <MermaidNode, double>{};
    for (final node in layer) {
      final connectedIds = connections[node.id] ?? [];
      final positions = connectedIds
          .where((id) => positionMap.containsKey(id))
          .map((id) => positionMap[id]!)
          .toList();

      if (positions.isEmpty) {
        // Keep current relative position
        barycenters[node] = layer.indexOf(node).toDouble();
      } else {
        barycenters[node] = positions.reduce((a, b) => a + b) / positions.length;
      }
    }

    // Sort by barycenter
    layer.sort((a, b) => barycenters[a]!.compareTo(barycenters[b]!));
  }

  /// Assigns x,y coordinates to nodes
  Size _assignCoordinates(
    List<List<MermaidNode>> layers,
    DiagramDirection direction,
    MermaidStyle style,
  ) {
    final isHorizontal = direction == DiagramDirection.leftToRight ||
        direction == DiagramDirection.rightToLeft;

    double totalWidth = 0;
    double totalHeight = 0;

    // Calculate layer dimensions
    final layerSizes = <double>[];
    final layerMaxCross = <double>[];

    for (final layer in layers) {
      double layerMain = 0;
      double layerCross = 0;

      for (final node in layer) {
        if (isHorizontal) {
          layerMain = math.max(layerMain, node.width);
          layerCross += node.height + style.nodeSpacingY;
        } else {
          layerMain = math.max(layerMain, node.height);
          layerCross += node.width + style.nodeSpacingX;
        }
      }

      layerSizes.add(layerMain);
      layerMaxCross.add(layerCross - (isHorizontal ? style.nodeSpacingY : style.nodeSpacingX));
    }

    // Position nodes
    double mainOffset = style.padding;

    for (var layerIdx = 0; layerIdx < layers.length; layerIdx++) {
      final layer = layers[layerIdx];
      final layerMain = layerSizes[layerIdx];

      // Center nodes within layer
      double crossOffset = style.padding;
      final totalCross = layerMaxCross[layerIdx];
      final maxCross = layerMaxCross.isEmpty ? 0.0 : layerMaxCross.reduce(math.max);
      crossOffset += (maxCross - totalCross) / 2;

      for (final node in layer) {
        if (isHorizontal) {
          // Center node horizontally within its layer slot
          node.x = mainOffset + (layerMain - node.width) / 2;
          node.y = crossOffset;
          crossOffset += node.height + style.nodeSpacingY;
        } else {
          node.x = crossOffset;
          // Center node vertically within its layer slot
          node.y = mainOffset + (layerMain - node.height) / 2;
          crossOffset += node.width + style.nodeSpacingX;
        }
      }

      mainOffset += layerMain +
          (isHorizontal ? style.nodeSpacingX : style.nodeSpacingY);
    }

    // Apply direction reversal if needed
    if (direction == DiagramDirection.rightToLeft ||
        direction == DiagramDirection.bottomToTop) {
      final allNodes = layers.expand((l) => l).toList();

      if (allNodes.isNotEmpty) {
        if (isHorizontal) {
          final maxX = allNodes.map((n) => n.x + n.width).reduce(math.max);
          for (final node in allNodes) {
            node.x = maxX - node.x - node.width;
          }
        } else {
          final maxY = allNodes.map((n) => n.y + n.height).reduce(math.max);
          for (final node in allNodes) {
            node.y = maxY - node.y - node.height;
          }
        }
      }
    }

    // Calculate total size
    final allNodes = layers.expand((l) => l).toList();
    if (allNodes.isNotEmpty) {
      totalWidth = allNodes.map((n) => n.x + n.width).reduce(math.max) + style.padding;
      totalHeight = allNodes.map((n) => n.y + n.height).reduce(math.max) + style.padding;
    }

    return Size(totalWidth, totalHeight);
  }
}

/// Layout engine for sequence diagrams
class SequenceLayout extends LayoutEngine {
  /// Creates a sequence layout engine
  const SequenceLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (diagram.nodes.isEmpty) return Size.zero;

    // Get responsive values
    final participantSpacingBase = deviceConfig?.participantSpacing ?? 150.0;
    final messageSpacing = deviceConfig?.messageSpacing ?? 50.0;
    final fontSize = deviceConfig?.fontSize ?? 14.0;

    // Measure all nodes first
    for (final node in diagram.nodes) {
      final size = measureNode(node, style);
      node.width = size.width;
      node.height = size.height;
    }

    // Sequence diagrams arrange participants horizontally
    const topY = 30.0; // Fixed Y for participant headers at top

    // Calculate width needed based on participant count and message labels
    final participantCount = diagram.nodes.length;

    // Calculate max label length to determine spacing
    var maxLabelLength = 0.0;
    for (final edge in diagram.edges) {
      if (edge.label != null) {
        // Estimate label width based on font size
        final labelWidth = edge.label!.length * fontSize * 0.5;
        if (labelWidth > maxLabelLength) {
          maxLabelLength = labelWidth;
        }
      }
    }

    // Minimum spacing based on label length, with responsive bounds
    final minSpacing = math.max(participantSpacingBase * 0.6, maxLabelLength + 30);
    final maxSpacing = participantSpacingBase; // Use responsive max spacing

    // Calculate optimal spacing
    final participantSpacing = math.min(minSpacing, maxSpacing);

    // Calculate total nodes width
    var totalNodesWidth = 0.0;
    for (final node in diagram.nodes) {
      totalNodesWidth += node.width;
    }

    // Total width is based on actual content
    final totalWidth = style.padding * 2 +
        totalNodesWidth +
        (participantCount > 1 ? (participantCount - 1) * participantSpacing : 0);

    // Position participants with calculated spacing
    var currentX = style.padding;
    for (var i = 0; i < diagram.nodes.length; i++) {
      final node = diagram.nodes[i];
      node.x = currentX;
      node.y = topY;
      currentX += node.width + participantSpacing;
    }

    // Calculate height based on number of messages with responsive spacing
    final messageStartOffset = messageSpacing * 0.8;
    final bottomParticipantHeight = messageSpacing;

    final nodeHeight = diagram.nodes.first.height;
    final messagesHeight = diagram.edges.length * messageSpacing;
    final totalHeight = topY + nodeHeight + messageStartOffset +
        messagesHeight + bottomParticipantHeight + style.padding;

    return Size(totalWidth, totalHeight);
  }
}
