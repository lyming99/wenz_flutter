import 'package:flutter/cupertino.dart';

import '../mind_map_controller.dart';

class MindInputState with ChangeNotifier {
  MindInputState(this.controller);

  MindMapController controller;
}
