import 'mindmap_node.dart';

/// Represents an entire mind map tree.
///
/// The mind map is stored as widgetData inside a CanvasWidgetElement.
/// This class handles serialization/deserialization and provides
/// convenient access to the tree structure.
class MindmapData {
  MindmapData({required this.root});

  /// The root node (anchor point).
  MindmapNode root;

  /// Serialize the entire mind map to a Map suitable for widgetData.
  Map<String, dynamic> toWidgetData() {
    return {
      'root': root.toJson(),
    };
  }

  /// Deserialize from widgetData map.
  factory MindmapData.fromWidgetData(Map<String, dynamic> data) {
    return MindmapData(
      root: MindmapNode.fromJson(
        data['root'] as Map<String, dynamic>,
      ),
    );
  }

  /// Create a default mind map with a root node and some sample children.
  factory MindmapData.createDefault({String rootText = '中心主题'}) {
    return MindmapData(
      root: MindmapNode(
        id: 'root',
        text: rootText,
        side: MindmapNodeSide.center,
        color: 0xFF2563EB,
        textColor: 0xFFFFFFFF,
        children: [
          MindmapNode(
            id: 'child-r1',
            text: '分支1',
            side: MindmapNodeSide.right,
            color: 0xFFE3F2FD,
            children: [
              MindmapNode(
                id: 'child-r1-1',
                text: '子主题',
                side: MindmapNodeSide.right,
              ),
            ],
          ),
          MindmapNode(
            id: 'child-r2',
            text: '分支2',
            side: MindmapNodeSide.right,
            color: 0xFFE3F2FD,
          ),
          MindmapNode(
            id: 'child-l1',
            text: '分支3',
            side: MindmapNodeSide.left,
            color: 0xFFE3F2FD,
          ),
        ],
      ),
    );
  }

  /// Find a node by id.
  MindmapNode? findNode(String nodeId) => root.find(nodeId);

  /// Find parent of a node by id.
  MindmapNode? findParent(String nodeId) => root.findParent(nodeId);
}
