import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';

class BackFloatButtonController extends MvcController {
  bool isVisible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void onDidUpdateWidget(
      BuildContext context, covariant BackFloatButtonController oldController) {
    super.onDidUpdateWidget(context, oldController);
    isVisible = oldController.isVisible;
  }

  void show() {
    isVisible = true;
    notifyListeners();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      hide();
    });
  }

  void hide() {
    isVisible = false;
    notifyListeners();
    _hideTimer?.cancel();
  }
}

class BackFloatButton extends MvcView<BackFloatButtonController> {
  const BackFloatButton({
    super.key,
    required super.controller,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !controller.isVisible,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(
            bottom: controller.isVisible ? 32 : 0,
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: controller.isVisible ? 1 : 0,
            child: TapRegion(
              onTapOutside: (event) {
                controller.hide();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  // border: Border.all(color: appColor.primary),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            "返回首页",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
