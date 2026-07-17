import 'package:wenz_richtext/wenz_richtext.dart';

/// Embed type string stored on [BlockEmbedNode.embedType] for the flowchart
/// sample. The renderer, slash-menu item, and toolbar item all key off it so a
/// single insertion path covers the data, render, and entry layers.
const String kFlowchartEmbedType = 'flowchart';

/// Schema version of the flowchart `data` contract. Bumped only when the shape
/// of [FlowchartDocument.toJson] changes; readers fall back to the current
/// version when the field is missing so older documents still render.
const int kFlowchartDataVersion = 1;

/// Plain-text fallback shown when the embed is exported to HTML/Markdown or
/// rendered without a registered `flowchart` builder.
const String kFlowchartFallbackText = '流程图';

/// Flow direction of the canvas. Stored as the short `TB`/`LR` code so the data
/// stays JSON-friendly and stable across Dart enum renames.
enum FlowchartDirection {
  topToBottom('TB'),
  leftToRight('LR');

  const FlowchartDirection(this.code);

  final String code;

  static FlowchartDirection fromCode(String? code) {
    switch (code) {
      case 'LR':
        return FlowchartDirection.leftToRight;
      case 'TB':
      default:
        return FlowchartDirection.topToBottom;
    }
  }
}

/// Visual role of a node. Drives the shape and colour painted by
/// [FlowchartView] (start/end → pill, process → rounded rect, decision →
/// diamond). Persisted by name so unknown kinds degrade to `process`.
enum FlowchartNodeKind {
  start,
  process,
  decision,
  end;

  static FlowchartNodeKind fromName(String? name) {
    switch (name) {
      case 'start':
        return FlowchartNodeKind.start;
      case 'decision':
        return FlowchartNodeKind.decision;
      case 'end':
        return FlowchartNodeKind.end;
      case 'process':
      default:
        return FlowchartNodeKind.process;
    }
  }
}

/// A single flowchart node positioned on the canvas. Coordinates are logical
/// pixels in the embed's local canvas space; [FlowchartView] clamps them to the
/// available size so dragging never pushes a node off-screen.
class FlowchartNode {
  const FlowchartNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.kind = FlowchartNodeKind.process,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final FlowchartNodeKind kind;

  FlowchartNode copyWith({
    String? id,
    String? label,
    double? x,
    double? y,
    FlowchartNodeKind? kind,
  }) {
    return FlowchartNode(
      id: id ?? this.id,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      kind: kind ?? this.kind,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'x': x,
        'y': y,
        'kind': kind.name,
      };

  static FlowchartNode fromJson(Map<String, Object?> json) {
    return FlowchartNode(
      id: json['id'] as String? ?? '',
      label: (json['label'] as String?) ?? (json['name'] as String?) ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      kind: FlowchartNodeKind.fromName(json['kind'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlowchartNode &&
      other.id == id &&
      other.label == label &&
      other.x == x &&
      other.y == y &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, label, x, y, kind);
}

/// A directed edge between two nodes. [label] is optional (e.g. `是`/`否` on a
/// decision branch); an empty label is dropped from the JSON so the common
/// unlabelled case stays compact.
class FlowchartEdge {
  const FlowchartEdge({
    required this.from,
    required this.to,
    this.label = '',
  });

  final String from;
  final String to;
  final String label;

  FlowchartEdge copyWith({String? from, String? to, String? label}) {
    return FlowchartEdge(
      from: from ?? this.from,
      to: to ?? this.to,
      label: label ?? this.label,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'from': from,
        'to': to,
        if (label.isNotEmpty) 'label': label,
      };

  static FlowchartEdge fromJson(Map<String, Object?> json) {
    return FlowchartEdge(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      label: (json['label'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlowchartEdge &&
      other.from == from &&
      other.to == to &&
      other.label == label;

  @override
  int get hashCode => Object.hash(from, to, label);
}

/// The full flowchart document stored under [BlockEmbedNode.data]. The shape is
/// JSON-friendly and round-trips through `toJson`/`fromJson` without loss, so
/// rich-JSON persistence keeps every node, edge, and coordinate intact.
class FlowchartDocument {
  const FlowchartDocument({
    this.nodes = const <FlowchartNode>[],
    this.edges = const <FlowchartEdge>[],
    this.direction = FlowchartDirection.topToBottom,
    this.version = kFlowchartDataVersion,
  });

  final List<FlowchartNode> nodes;
  final List<FlowchartEdge> edges;
  final FlowchartDirection direction;
  final int version;

  /// An empty canvas; used as the default when no data is supplied.
  static const FlowchartDocument empty = FlowchartDocument();

  /// A small loan-approval graph inserted by the toolbar / slash item so a
  /// freshly inserted flowchart renders something meaningful to drag around.
  factory FlowchartDocument.sample() {
    return const FlowchartDocument(
      direction: FlowchartDirection.topToBottom,
      nodes: <FlowchartNode>[
        FlowchartNode(
          id: 'start',
          label: '开始',
          x: 132,
          y: 8,
          kind: FlowchartNodeKind.start,
        ),
        FlowchartNode(
          id: 'review',
          label: '审核申请',
          x: 130,
          y: 70,
          kind: FlowchartNodeKind.process,
        ),
        FlowchartNode(
          id: 'decision',
          label: '是否通过?',
          x: 122,
          y: 132,
          kind: FlowchartNodeKind.decision,
        ),
        FlowchartNode(
          id: 'approved',
          label: '放款',
          x: 34,
          y: 214,
          kind: FlowchartNodeKind.process,
        ),
        FlowchartNode(
          id: 'rejected',
          label: '驳回',
          x: 226,
          y: 214,
          kind: FlowchartNodeKind.process,
        ),
      ],
      edges: <FlowchartEdge>[
        FlowchartEdge(from: 'start', to: 'review'),
        FlowchartEdge(from: 'review', to: 'decision'),
        FlowchartEdge(from: 'decision', to: 'approved', label: '是'),
        FlowchartEdge(from: 'decision', to: 'rejected', label: '否'),
      ],
    );
  }

  FlowchartDocument copyWith({
    List<FlowchartNode>? nodes,
    List<FlowchartEdge>? edges,
    FlowchartDirection? direction,
    int? version,
  }) {
    return FlowchartDocument(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      direction: direction ?? this.direction,
      version: version ?? this.version,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'edges': edges.map((edge) => edge.toJson()).toList(),
        'direction': direction.code,
        'version': version,
      };

  static FlowchartDocument fromJson(Map<String, Object?> json) {
    final nodesRaw = json['nodes'];
    final edgesRaw = json['edges'];
    return FlowchartDocument(
      nodes: nodesRaw is List
          ? nodesRaw
              .whereType<Map>()
              .map((raw) => FlowchartNode.fromJson(Map<String, Object?>.from(raw)))
              .toList()
          : const <FlowchartNode>[],
      edges: edgesRaw is List
          ? edgesRaw
              .whereType<Map>()
              .map((raw) => FlowchartEdge.fromJson(Map<String, Object?>.from(raw)))
              .toList()
          : const <FlowchartEdge>[],
      direction: FlowchartDirection.fromCode(json['direction'] as String?),
      version: (json['version'] as num?)?.toInt() ?? kFlowchartDataVersion,
    );
  }
}

/// Reads a [FlowchartDocument] out of a flowchart [BlockEmbedNode]'s data map.
/// Tolerates a missing or partial `data` payload by falling back to an empty
/// canvas, so a malformed embed never throws during render.
FlowchartDocument flowchartDocumentFromBlock(BlockEmbedNode block) {
  return FlowchartDocument.fromJson(Map<String, Object?>.from(block.data));
}

/// Builds a flowchart [BlockEmbedNode] carrying [document] as its data. Hosts
/// and the slash/toolbar entries use this so the inserted block matches the
/// renderer's data contract on the first paint.
BlockEmbedNode flowchartBlockEmbed({
  required String id,
  FlowchartDocument document = FlowchartDocument.empty,
  String fallbackText = kFlowchartFallbackText,
}) {
  return BlockEmbedNode(
    id: id,
    embedType: kFlowchartEmbedType,
    data: document.toJson(),
    fallbackText: fallbackText,
  );
}
