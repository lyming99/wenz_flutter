import '../style/mind_style.dart';
import '../style/xmind_style.dart';
import 'index.dart';

class MindDocument {
  MindDocument({
    required this.docId,
    required this.noteId,
    this.primaryRootId,
    this.nodes = const [],
    this.xScrollOffset,
    this.yScrollOffset,
    this.verticalSpacing = 20,
    this.horizontalSpacing = 50,
    this.style = const XMindStyle(),
  });

  String? primaryRootId;
  List<MindNodeInfo> nodes = [];
  double? xScrollOffset;
  double? yScrollOffset;
  String? noteId;
  String? docId;
  MindStyle? style;
  double verticalSpacing;
  double horizontalSpacing;

  List<MindNode> roots = [];

  MindNode get root => roots.first;

  factory MindDocument.fromJson(Map<String, dynamic> json) {
    return MindDocument(
      docId: json['docId'],
      noteId: json['noteId'],
      primaryRootId: json['primaryRootId'],
      nodes: (json['nodes'] as List)
          .map((e) => MindNodeInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      xScrollOffset: json['xScrollOffset'],
      yScrollOffset: json['yScrollOffset'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryRootId': primaryRootId,
      'nodes': nodes.map((e) => e.toJson()).toList(),
    };
  }

  void loadRoots() {
    var nodeMap = <String, MindNode>{};
    var roots = <MindNode>[];
    for (var node in nodes) {
      var mindNode = MindNode(info: node);
      nodeMap[mindNode.uuid!] = mindNode;
      if (node.parentId != null) {
        nodeMap[node.parentId!]?.addNodeToChildren(mindNode);
      } else {
        roots.add(mindNode);
      }
    }
    this.roots = roots;
  }
}
