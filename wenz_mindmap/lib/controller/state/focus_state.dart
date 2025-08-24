import 'package:flutter/cupertino.dart';

import '../mind_map_controller.dart';

class MindFocusState with ChangeNotifier {
  MindFocusState(this.controller);

  MindMapController controller;
  bool _focus = false;

  bool get focus => _focus;

  void updateState(bool focus) {
    if (focus != _focus) {
      _focus = focus;
      notifyListeners();
    }
  }
}
