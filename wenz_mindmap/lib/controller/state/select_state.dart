import 'package:flutter/cupertino.dart';

import '../../data/index.dart';
import '../../data/mind_node.dart';
import '../mind_map_controller.dart';

class MindSelectState with ChangeNotifier {
  MindSelectState(this.controller);

  MindMapController controller;

  MindNode? _selectNode;
  List<MindNode> selectNodes = [];

  // 当前选中的节点
  MindNode? get selectNode => _selectNode;

  set selectNode(MindNode? value) {
    if (value == _selectNode) {
      return;
    }
    _selectNode?.closeEdit();
    _selectNode?.updateTapSelected(false);
    _selectNode = value;
    value?.updateTapSelected(true);
  }
}
