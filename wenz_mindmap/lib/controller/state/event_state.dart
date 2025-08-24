import 'package:flutter/cupertino.dart';

import '../mind_map_controller.dart';


class MindEventState with ChangeNotifier {
  MindEventState(this.controller);

  MindMapController controller;
}
