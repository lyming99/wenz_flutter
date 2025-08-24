import 'package:flutter/material.dart';

import '../mindmap.dart';

class NodeEditController {
  MindMapController controller;
  MindNode node;
  FocusNode? focusNode;

  bool get isEditing => node.editing;
  ValueChanged<String>? onContentChanged;
  ValueChanged<bool>? onEditChanged;

  NodeEditController({
    required this.controller,
    required this.node,
    this.onContentChanged,
    this.onEditChanged,
    this.focusNode,
  });

  List<String> get childNoteList => node.childNoteList;

  void showEdit() {
    onEditChanged?.call(true);
  }

  void closeEdit() {
    onEditChanged?.call(false);
  }

  void updateContent(String content) {
    onContentChanged?.call(content);
  }

  bool hasChildInfo(BuildContext context, MindNode node) {
    if (node.hasLink) {
      return true;
    }
    if (node.hasNote) {
      return node.getExistChildNoteList(context).isNotEmpty;
    }
    return false;
  }

  List<String> getExistChildNoteList(BuildContext context) {
    return node.getExistChildNoteList(context);
  }
}
