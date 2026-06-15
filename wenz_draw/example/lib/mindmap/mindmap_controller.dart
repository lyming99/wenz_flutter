import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'mindmap_data.dart';
import 'mindmap_node.dart';

/// Controller for managing mind map state.
///
/// Notifies listeners when the mind map data changes (node added, removed,
/// text edited, collapsed/expanded, etc).
class MindmapController extends ChangeNotifier {
  MindmapController({required MindmapData data}) : _data = data;

  final MindmapData _data;

  /// Current mind map data.
  MindmapData get data => _data;

  /// The currently selected node id (null = root selected).
  String? _selectedNodeId;
  String? get selectedNodeId => _selectedNodeId;

  /// The node currently being edited (null = not editing).
  String? _editingNodeId;
  String? get editingNodeId => _editingNodeId;

  /// Whether a node is being edited.
  bool get isEditing => _editingNodeId != null;

  /// Get the currently selected node.
  MindmapNode? get selectedNode =>
      _selectedNodeId != null ? _data.findNode(_selectedNodeId!) : _data.root;

  /// Toggle collapse/expand for a node.
  void toggleCollapse(String nodeId) {
    final node = _data.findNode(nodeId);
    if (node == null || !node.hasChildren) return;
    node.isCollapsed = !node.isCollapsed;
    notifyListeners();
  }

  /// Select a node.
  void selectNode(String? nodeId) {
    _selectedNodeId = nodeId;
    notifyListeners();
  }

  /// Start editing a node's text.
  void startEditing(String nodeId) {
    _editingNodeId = nodeId;
    _selectedNodeId = nodeId;
    notifyListeners();
  }

  /// Commit text edit and stop editing.
  void commitEdit(String nodeId, String newText) {
    final node = _data.findNode(nodeId);
    if (node != null) {
      node.text = newText;
    }
    _editingNodeId = null;
    notifyListeners();
  }

  /// Cancel editing.
  void cancelEdit() {
    _editingNodeId = null;
    notifyListeners();
  }

  /// Add a child to the specified parent node.
  /// The new child inherits the parent's side (or right if parent is root).
  void addChild(String parentId) {
    final parent = _data.findNode(parentId);
    if (parent == null) return;

    // Determine side: root children alternate or go right
    MindmapNodeSide side;
    if (parent.id == _data.root.id) {
      side = MindmapNodeSide.right;
    } else {
      side = parent.side;
    }

    final newId = 'node-${DateTime.now().millisecondsSinceEpoch}';
    parent.children.add(
      MindmapNode(id: newId, text: '新节点', side: side, color: 0xFFE3F2FD),
    );
    parent.isCollapsed = false;
    _selectedNodeId = newId;
    _editingNodeId = newId;
    notifyListeners();
  }

  /// Add a sibling node (same parent, same level).
  void addSibling(String nodeId) {
    final parent = _data.findParent(nodeId);
    if (parent == null) return; // Can't add sibling to root

    final node = _data.findNode(nodeId);
    final side = node?.side ?? MindmapNodeSide.right;

    final newId = 'node-${DateTime.now().millisecondsSinceEpoch}';
    final insertIndex = parent.children.indexWhere((c) => c.id == nodeId) + 1;
    parent.children.insert(
      insertIndex,
      MindmapNode(id: newId, text: '新节点', side: side, color: 0xFFE3F2FD),
    );
    _selectedNodeId = newId;
    _editingNodeId = newId;
    notifyListeners();
  }

  /// Delete a node and all its children.
  void deleteNode(String nodeId) {
    if (nodeId == _data.root.id) return; // Can't delete root

    final parent = _data.findParent(nodeId);
    if (parent == null) return;

    parent.children.removeWhere((c) => c.id == nodeId);
    if (_selectedNodeId == nodeId) {
      _selectedNodeId = parent.id;
    }
    notifyListeners();
  }

  /// Update node color.
  void setNodeColor(String nodeId, int color) {
    setNodeStyle(nodeId, fillColor: color);
  }

  /// Update per-node style overrides. Pass null to clear an override.
  void setNodeStyle(
    String nodeId, {
    Object? fillColor = _styleUnset,
    Object? borderColor = _styleUnset,
    Object? fontColor = _styleUnset,
  }) {
    final node = _data.findNode(nodeId);
    if (node != null) {
      if (!identical(fillColor, _styleUnset)) {
        node.fillColor = fillColor as int?;
        node.color =
            node.fillColor ??
            (node.id == _data.root.id ? 0xFF2563EB : 0xFFE3F2FD);
      }
      if (!identical(borderColor, _styleUnset)) {
        node.borderColor = borderColor as int?;
      }
      if (!identical(fontColor, _styleUnset)) {
        node.fontColor = fontColor as int?;
        node.textColor =
            node.fontColor ??
            (node.id == _data.root.id ? 0xFFFFFFFF : 0xFF1F2937);
      }
      notifyListeners();
    }
  }

  /// Commit the current edit and immediately add a sibling node,
  /// then start editing the new sibling.
  /// This is an atomic operation (single notifyListeners call)
  /// to avoid widget-dispose timing issues.
  void commitAndAddSibling(String nodeId, String text) {
    final node = _data.findNode(nodeId);
    if (node != null) {
      node.text = text;
    }

    final parent = _data.findParent(nodeId);
    if (parent == null) {
      // Can't add sibling to root — just commit
      _editingNodeId = null;
      notifyListeners();
      return;
    }

    final side = node?.side ?? MindmapNodeSide.right;
    final newId = 'node-${DateTime.now().microsecondsSinceEpoch}';
    final insertIndex = parent.children.indexWhere((c) => c.id == nodeId) + 1;
    parent.children.insert(
      insertIndex,
      MindmapNode(id: newId, text: '', side: side, color: 0xFFE3F2FD),
    );
    _selectedNodeId = newId;
    _editingNodeId = newId;
    notifyListeners();
  }

  /// Commit the current edit and immediately add a child node,
  /// then start editing the new child.
  void commitAndAddChild(String nodeId, String text) {
    final node = _data.findNode(nodeId);
    if (node == null) return;

    node.text = text;

    MindmapNodeSide side;
    if (node.id == _data.root.id) {
      side = MindmapNodeSide.right;
    } else {
      side = node.side;
    }

    final newId = 'node-${DateTime.now().microsecondsSinceEpoch}';
    node.children.add(
      MindmapNode(id: newId, text: '', side: side, color: 0xFFE3F2FD),
    );
    node.isCollapsed = false;
    _selectedNodeId = newId;
    _editingNodeId = newId;
    notifyListeners();
  }

  /// Serialize data back to widgetData format.
  Map<String, dynamic> toWidgetData() => _data.toWidgetData();
}

const Object _styleUnset = Object();
