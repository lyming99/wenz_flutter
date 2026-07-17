import 'mindmap_node.dart';

/// Single mind map node data, stored **decentralized** in each node element's
/// `widgetData`. This is the "non-component mode" data model: there is no
/// single tree blob — the tree is reconstructed on demand by walking
/// `parentId` links across canvas elements.
///
/// Widget data shape:
/// ```
/// {
///   "id": "node-xxx",
///   "text": "分支1",
///   "parentId": "root",   // null for root
///   "side": "right",
///   "collapsed": false,          // non-root: whole subtree collapsed
///   "collapsedRight": false,     // root only: right-side subtree collapsed
///   "collapsedLeft": false,      // root only: left-side subtree collapsed
///   "isRoot": false,
///   "color": 0xFFE3F2FD,
///   "textColor": 0xFF1F2937,
///   "todoEnabled": false,
///   "todoDone": false,
///   "linkUrl": "https://example.com",
/// }
/// ```
class MindmapNodeData {
  const MindmapNodeData({
    required this.id,
    required this.text,
    this.parentId,
    this.side = MindmapNodeSide.center,
    this.isCollapsed = false,
    this.collapsedRight = false,
    this.collapsedLeft = false,
    this.isRoot = false,
    this.order = 0,
    this.color = 0xFFE3F2FD,
    this.textColor = 0xFF1F2937,
    this.fillColor,
    this.borderColor,
    this.fontColor,
    this.themeId,
    this.todoEnabled = false,
    this.todoDone = false,
    this.linkUrl,
  });

  /// Unique node id. Matches the hosting element's id.
  final String id;

  /// Display text.
  final String text;

  /// Parent node id. `null` for the root.
  final String? parentId;

  /// Layout side relative to the root.
  final MindmapNodeSide side;

  /// Whether this node's subtree is collapsed (non-root nodes).
  final bool isCollapsed;

  /// Root only: whether the right-side subtree is collapsed.
  final bool collapsedRight;

  /// Root only: whether the left-side subtree is collapsed.
  final bool collapsedLeft;

  /// Whether this node is the root of its tree.
  final bool isRoot;

  /// Sort order among siblings (same parent). Lower = higher/earlier.
  /// Used by [MindmapTreeBuilder] to order children for layout.
  final int order;

  /// Background color (ARGB32 int).
  final int color;

  /// Text color (ARGB32 int).
  final int textColor;

  /// Optional per-node background override (ARGB32 int).
  final int? fillColor;

  /// Optional per-node border override (ARGB32 int).
  final int? borderColor;

  /// Optional per-node font override (ARGB32 int).
  final int? fontColor;

  /// Root-only theme id for the whole mind map tree.
  final String? themeId;

  /// Whether this node displays a todo checkbox.
  final bool todoEnabled;

  /// Whether the todo checkbox is completed.
  final bool todoDone;

  /// Optional URL attached to this node.
  final String? linkUrl;

  /// Whether the subtree on [sideSide] is collapsed.
  ///
  /// For root nodes, uses the per-side flags ([collapsedRight] /
  /// [collapsedLeft]); for non-root nodes, uses the single [isCollapsed]
  /// flag (their children all live on one side anyway).
  bool isCollapsedOnSide(MindmapNodeSide sideSide) {
    if (!isRoot) return isCollapsed;
    return switch (sideSide) {
      MindmapNodeSide.right => collapsedRight,
      MindmapNodeSide.left => collapsedLeft,
      MindmapNodeSide.center => false,
    };
  }

  /// Deserialize from widgetData map.
  factory MindmapNodeData.fromWidgetData(Map<String, dynamic> data) {
    return MindmapNodeData(
      id: data['id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      parentId: data['parentId'] as String?,
      side: MindmapNodeSide.fromString(data['side'] as String?),
      isCollapsed: data['collapsed'] as bool? ?? false,
      collapsedRight: data['collapsedRight'] as bool? ?? false,
      collapsedLeft: data['collapsedLeft'] as bool? ?? false,
      isRoot: data['isRoot'] as bool? ?? false,
      order: data['order'] as int? ?? 0,
      color: _parseIntColor(data['color'], 0xFFE3F2FD),
      textColor: _parseIntColor(data['textColor'], 0xFF1F2937),
      fillColor: _parseOptionalIntColor(data['fillColor']),
      borderColor: _parseOptionalIntColor(data['borderColor']),
      fontColor: _parseOptionalIntColor(data['fontColor']),
      themeId: data['themeId'] as String?,
      todoEnabled: data['todoEnabled'] as bool? ?? false,
      todoDone: data['todoDone'] as bool? ?? false,
      linkUrl: _parseOptionalString(data['linkUrl']),
    );
  }

  /// Serialize to widgetData map.
  Map<String, dynamic> toWidgetData() {
    return {
      'id': id,
      'text': text,
      if (parentId != null) 'parentId': parentId,
      'side': side.toValueString(),
      'collapsed': isCollapsed,
      if (isRoot) 'collapsedRight': collapsedRight,
      if (isRoot) 'collapsedLeft': collapsedLeft,
      'isRoot': isRoot,
      'order': order,
      'color': color,
      'textColor': textColor,
      if (fillColor != null) 'fillColor': fillColor,
      if (borderColor != null) 'borderColor': borderColor,
      if (fontColor != null) 'fontColor': fontColor,
      if (isRoot && themeId != null) 'themeId': themeId,
      if (todoEnabled) 'todoEnabled': todoEnabled,
      if (todoEnabled || todoDone) 'todoDone': todoDone,
      if (linkUrl != null && linkUrl!.isNotEmpty) 'linkUrl': linkUrl,
    };
  }

  MindmapNodeData copyWith({
    String? id,
    String? text,
    Object? parentId = _unset,
    MindmapNodeSide? side,
    bool? isCollapsed,
    bool? collapsedRight,
    bool? collapsedLeft,
    bool? isRoot,
    int? order,
    int? color,
    int? textColor,
    Object? fillColor = _unset,
    Object? borderColor = _unset,
    Object? fontColor = _unset,
    Object? themeId = _unset,
    bool? todoEnabled,
    bool? todoDone,
    Object? linkUrl = _unset,
  }) {
    return MindmapNodeData(
      id: id ?? this.id,
      text: text ?? this.text,
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as String?,
      side: side ?? this.side,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      collapsedRight: collapsedRight ?? this.collapsedRight,
      collapsedLeft: collapsedLeft ?? this.collapsedLeft,
      isRoot: isRoot ?? this.isRoot,
      order: order ?? this.order,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      fillColor: identical(fillColor, _unset)
          ? this.fillColor
          : fillColor as int?,
      borderColor: identical(borderColor, _unset)
          ? this.borderColor
          : borderColor as int?,
      fontColor: identical(fontColor, _unset)
          ? this.fontColor
          : fontColor as int?,
      themeId: identical(themeId, _unset) ? this.themeId : themeId as String?,
      todoEnabled: todoEnabled ?? this.todoEnabled,
      todoDone: todoDone ?? this.todoDone,
      linkUrl: identical(linkUrl, _unset) ? this.linkUrl : linkUrl as String?,
    );
  }

  static int _parseIntColor(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int? _parseOptionalIntColor(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _parseOptionalString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static const _unset = Object();
}
