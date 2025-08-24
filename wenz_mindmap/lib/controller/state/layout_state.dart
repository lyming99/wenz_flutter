import 'package:flutter/cupertino.dart';

import '../mind_map_controller.dart';

class MindLayoutState with ChangeNotifier {
  MindLayoutState(this.controller);

  MindMapController controller;

  Size? viewSize;

  Rect viewBoundRect = Rect.zero;
  // 是否正在调整子节点的大小
  bool isChildResizing = false;
}
