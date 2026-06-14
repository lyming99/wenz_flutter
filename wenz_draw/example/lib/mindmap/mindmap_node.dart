/// Mind map node position side relative to root.
enum MindmapNodeSide {
  /// Root node - center.
  center,
  /// Right side of root.
  right,
  /// Left side of root.
  left;

  /// Deserialize from string.
  static MindmapNodeSide fromString(String? value) {
    return switch (value) {
      'right' => MindmapNodeSide.right,
      'left' => MindmapNodeSide.left,
      _ => MindmapNodeSide.center,
    };
  }

  /// Serialize to string.
  String toValueString() => name;
}

/// A single node in a mind map tree.
///
/// Nodes form a tree structure with the root node as the anchor point.
/// Each node can be collapsed to hide its children.
class MindmapNode {
  MindmapNode({
    required this.id,
    required this.text,
    List<MindmapNode>? children,
    this.isCollapsed = false,
    this.side = MindmapNodeSide.center,
    this.color = 0xFFE3F2FD,
    this.textColor = 0xFF1F2937,
  }) : children = children ?? [];

  /// Unique identifier within this mind map.
  final String id;

  /// Display text.
  String text;

  /// Child nodes.
  final List<MindmapNode> children;

  /// Whether this node's subtree is collapsed (children hidden).
  bool isCollapsed;

  /// Layout side relative to root.
  MindmapNodeSide side;

  /// Background color as int (ARGB32).
  int color;

  /// Text color as int (ARGB32).
  int textColor;

  /// Whether this node has children.
  bool get hasChildren => children.isNotEmpty;

  /// Deep clone this node and all children.
  MindmapNode clone() {
    return MindmapNode(
      id: id,
      text: text,
      isCollapsed: isCollapsed,
      side: side,
      color: color,
      textColor: textColor,
      children: [for (final child in children) child.clone()],
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'collapsed': isCollapsed,
      'side': side.toValueString(),
      'color': color,
      'textColor': textColor,
      'children': [for (final child in children) child.toJson()],
    };
  }

  /// Deserialize from JSON map.
  factory MindmapNode.fromJson(Map<String, dynamic> json) {
    return MindmapNode(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      isCollapsed: json['collapsed'] as bool? ?? false,
      side: MindmapNodeSide.fromString(json['side'] as String?),
      color: _parseIntColor(json['color'], 0xFFE3F2FD),
      textColor: _parseIntColor(json['textColor'], 0xFF1F2937),
      children: json['children'] != null
          ? [
              for (final child in json['children'] as List)
                MindmapNode.fromJson(child as Map<String, dynamic>),
            ]
          : null,
    );
  }

  /// Find a node by id in this subtree. Returns null if not found.
  MindmapNode? find(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      final found = child.find(nodeId);
      if (found != null) return found;
    }
    return null;
  }

  /// Find the parent of [nodeId] in this subtree. Returns null if not found.
  MindmapNode? findParent(String nodeId) {
    for (final child in children) {
      if (child.id == nodeId) return this;
      final found = child.findParent(nodeId);
      if (found != null) return found;
    }
    return null;
  }

  /// Count all visible nodes (respecting collapse state).
  int get visibleNodeCount {
    if (isCollapsed) return 1;
    var count = 1;
    for (final child in children) {
      count += child.visibleNodeCount;
    }
    return count;
  }

  static int _parseIntColor(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
