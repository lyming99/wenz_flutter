import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'package:wenz_editor/editor/widget/view_insets_observer.dart';

class MobileToolbarController extends MvcController {
  var isShowBottomPane = false;
  var bottomIndex = ValueNotifier<int>(0);
  double keyboardHeight = 0;
  var notifier = ChangeNotifier();

  @override
  void onDidUpdateWidget(
      BuildContext context, MobileToolbarController oldController) {
    super.onDidUpdateWidget(context, oldController);
    isShowBottomPane = oldController.isShowBottomPane;
    bottomIndex = oldController.bottomIndex;
    keyboardHeight = oldController.keyboardHeight;
  }

  void showBottomPane(BuildContext context, int index) {
    bottomIndex.value = index;
    var keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight == 0) {
      return;
    }
    this.keyboardHeight = keyboardHeight;
    isShowBottomPane = true;
    notifier.notifyListeners();
  }

  void closeBottomPane() {
    isShowBottomPane = false;
    notifier.notifyListeners();
  }
}

class MobileToolbar extends MvcView<MobileToolbarController> {
  final Widget child;
  final Widget toolbar;
  final List<Widget>? bottomPanes;
  final double toolbarHeight;
  final bool showToolbar;

  const MobileToolbar({
    super.key,
    required super.controller,
    required this.child,
    required this.toolbar,
    this.bottomPanes,
    this.toolbarHeight = 48,
    this.showToolbar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ViewInsetsObserver(
      shouldRebuild: (oldInsets, newInsets) {
        return oldInsets.bottom != newInsets.bottom;
      },
      builder: (context, viewInsets) {
        return ListenableBuilder(
            listenable: controller.notifier,
            builder: (context, c) {
              var toolBar = Column(
                children: [
                  SizedBox(height: toolbarHeight, child: toolbar),
                  if (bottomPanes != null &&
                      bottomPanes!.isNotEmpty &&
                      controller.isShowBottomPane)
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: controller.bottomIndex,
                        builder: (context, index, child) {
                          return IndexedStack(
                            index: index,
                            children: [
                              ...bottomPanes!,
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
              var currentKeyboardHeight =
                  viewInsets.bottom ;
              var keyboardHeight = currentKeyboardHeight;
              bool isKeyboardOpen = viewInsets.bottom > 0;
              if (keyboardHeight >= controller.keyboardHeight &&
                  !controller.isShowBottomPane) {
                controller.keyboardHeight = 0;
              }
              keyboardHeight = max(keyboardHeight, controller.keyboardHeight);
              double toolHeight = controller.isShowBottomPane || isKeyboardOpen
                  ? keyboardHeight + 48
                  : 0;

              var caonimaPadding = MediaQuery.of(context).padding.bottom;
              var caonimaBottom = MediaQuery.of(context).viewInsets.bottom;
              return Column(
                children: [
                  Expanded(child: child),
                  if (showToolbar)
                    SizedBox(
                      height: toolHeight,
                      child: toolBar,
                    ),
                ],
              );
            });
      },
    );
  }
}
