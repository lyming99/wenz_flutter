import 'package:flutter/cupertino.dart';

import '../mind_map_controller.dart';


class MindDragState with ChangeNotifier {
  MindDragState(this.controller);

  MindMapController controller;
}
