import 'package:flutter/material.dart';

class MvcController with ChangeNotifier {
  late BuildContext context;

  @mustCallSuper
  void onInitState(BuildContext context) {
    this.context = context;
    print("$runtimeType init state.");
  }

  @mustCallSuper
  void onDidUpdateWidget(BuildContext context, covariant MvcController oldController) {
    this.context = context;
  }

  void onDispose() {
    print("$runtimeType dispose.");
  }

  void onPause() {}
}
