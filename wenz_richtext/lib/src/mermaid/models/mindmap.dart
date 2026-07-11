/// Data models for Mindmap diagrams
library;

import 'node.dart';

/// Common visual shapes used by Mermaid mindmap nodes.
enum MindmapNodeShape {
  /// Plain rectangular node.
  rectangle,

  /// Rounded rectangular node.
  roundedRect,

  /// Circular node.
  circle,

  /// Double circular node.
  doubleCircle,

  /// Hexagonal node.
  hexagon,

  /// Cloud-like node.
  cloud,

  /// Bang/emphasis node.
  bang,
}

/// Represents a node in a Mermaid mindmap tree.
class MindmapNode {
  /// Creates a mindmap node.
  const MindmapNode({
    required this.id,
    required this.label,
    this.depth = 0,
    this.parentId,
    this.children = const [],
    this.shape = MindmapNodeShape.rectangle,
    this.style,
    this.className,
    this.icon,
  });

  /// Stable node identifier.
  final String id;

  /// Display label.
  final String label;

  /// Depth in the mindmap tree. The root node starts at 0.
  final int depth;

  /// Parent node identifier, if this is not the root node.
  final String? parentId;

  /// Child nodes in source order.
  final List<MindmapNode> children;

  /// Visual shape derived from the Mermaid node syntax.
  final MindmapNodeShape shape;

  /// Optional custom style for this node.
  final NodeStyle? style;

  /// Optional class name assigned by Mermaid class syntax.
  final String? className;

  /// Optional icon identifier assigned by Mermaid icon syntax.
  final String? icon;

  /// Display text for renderers that need a fallback when the label is empty.
  String get displayText => label.isNotEmpty ? label : (icon ?? id);

  /// Whether this node has no children.
  bool get isLeaf => children.isEmpty;

  /// Maximum depth below this node, including this node.
  int get maxDepth {
    var result = depth;
    for (final child in children) {
      final childDepth = child.maxDepth;
      if (childDepth > result) result = childDepth;
    }
    return result;
  }

  /// Returns this node and all descendants in preorder.
  Iterable<MindmapNode> flatten() sync* {
    yield this;
    for (final child in children) {
      yield* child.flatten();
    }
  }

  /// Finds a node by identifier within this subtree.
  MindmapNode? findById(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      final match = child.findById(nodeId);
      if (match != null) return match;
    }
    return null;
  }

  /// Creates a copy with modified properties.
  MindmapNode copyWith({
    String? id,
    String? label,
    int? depth,
    String? parentId,
    List<MindmapNode>? children,
    MindmapNodeShape? shape,
    NodeStyle? style,
    String? className,
    String? icon,
  }) {
    return MindmapNode(
      id: id ?? this.id,
      label: label ?? this.label,
      depth: depth ?? this.depth,
      parentId: parentId ?? this.parentId,
      children: children ?? this.children,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      className: className ?? this.className,
      icon: icon ?? this.icon,
    );
  }
}

/// Data for a complete Mermaid mindmap.
class MindmapData {
  /// Creates mindmap data.
  const MindmapData({
    required this.root,
    this.title,
  });

  /// Optional title for the mindmap.
  final String? title;

  /// Root node of the mindmap tree.
  final MindmapNode root;

  /// All nodes in source preorder.
  List<MindmapNode> get nodes => root.flatten().toList();

  /// Maximum node depth in the tree.
  int get maxDepth => root.maxDepth;

  /// Parent-child node connections in preorder.
  List<MindmapConnection> get connections {
    final result = <MindmapConnection>[];

    void visit(MindmapNode node) {
      for (final child in node.children) {
        result.add(MindmapConnection(parentId: node.id, childId: child.id));
        visit(child);
      }
    }

    visit(root);
    return result;
  }

  /// Gets a node by its ID.
  MindmapNode? getNode(String id) => root.findById(id);

  /// Creates a copy with modified properties.
  MindmapData copyWith({
    MindmapNode? root,
    String? title,
  }) {
    return MindmapData(
      root: root ?? this.root,
      title: title ?? this.title,
    );
  }
}

/// A parent-child relationship inside a mindmap tree.
class MindmapConnection {
  /// Creates a mindmap connection.
  const MindmapConnection({
    required this.parentId,
    required this.childId,
  });

  /// Parent node identifier.
  final String parentId;

  /// Child node identifier.
  final String childId;
}