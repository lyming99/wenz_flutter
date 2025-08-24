import 'dart:async';

import 'package:flutter/material.dart';

import 'vertical_popup_layout.dart';

typedef ChildBuilder = Widget Function(
    BuildContext context, DelayHideOverlayPortalController controller);

class PopupNotification extends Notification {
  bool isShow;

  PopupNotification({required this.isShow});
}

void notifyChildPopupState(BuildContext context, bool isShow) {
  PopupNotification(isShow: isShow).dispatch(context);
}

class DelayHideOverlayPortalController extends OverlayPortalController {
  Timer? hideTimer;

  @override
  void show() {
    hideTimer?.cancel();
    hideTimer = null;
    super.show();
  }

  void cancelHide() {
    hideTimer?.cancel();
    hideTimer = null;
  }

  void delayHide(Duration duration) {
    hideTimer?.cancel();
    hideTimer = Timer(duration, () {
      super.hide();
    });
  }
}

class VerticalPopupWidget extends StatefulWidget {
  final double popupWidth;
  final double popupHeight;
  final ChildBuilder popupBuilder;
  final VoidCallback? onPopup;
  final ChildBuilder childBuilder;
  final DelayHideOverlayPortalController? controller;
  final ChildAlignment childAlignment;
  final Rect? anchorRect;

  const VerticalPopupWidget({
    super.key,
    this.popupWidth = 400,
    this.popupHeight = 280,
    this.controller,
    required this.popupBuilder,
    required this.childBuilder,
    this.onPopup,
    this.childAlignment = ChildAlignment.left,
    this.anchorRect,
  });

  @override
  State<VerticalPopupWidget> createState() => _VerticalPopupWidgetState();
}

class _VerticalPopupWidgetState extends State<VerticalPopupWidget> {
  late DelayHideOverlayPortalController overlayController;
  BuildContext? editContext;
  bool hasChildPopupShown = false;

  @override
  void initState() {
    super.initState();
    overlayController = widget.controller ?? DelayHideOverlayPortalController();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (BuildContext context) {
          var box = editContext!.findRenderObject() as RenderBox;
          var topLeft = box.localToGlobal(Offset.zero);
          var anchorRect = topLeft & Size(box.size.width, box.size.height);
          return NotificationListener<PopupNotification>(
            onNotification: (no) {
              hasChildPopupShown = no.isShow;
              return true;
            },
            child: TapRegion(
              onTapOutside: (e) {
                if (hasChildPopupShown) {
                  return;
                }
                var box = editContext!.findRenderObject() as RenderBox;
                var rect = box.localToGlobal(Offset.zero) & box.size;
                if (!rect.contains(e.position)) {
                  overlayController.hide();
                }
              },
              child: CustomSingleChildLayout(
                delegate: VerticalPopupLayout(
                  verticalMargin: 4,
                  anchorRect: widget.anchorRect ?? anchorRect,
                  childAlignment: widget.childAlignment,
                  childSize: Size(
                      widget.popupWidth == 0
                          ? box.size.width
                          : widget.popupWidth,
                      widget.popupHeight),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    elevation: 2,
                    shape: const RoundedRectangleBorder(),
                    child: SizedBox(
                      width: widget.popupWidth == 0
                          ? box.size.width
                          : widget.popupWidth,
                      height: widget.popupHeight,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          return true;
                        },
                        child: widget.popupBuilder
                            .call(context, overlayController),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: Builder(builder: (context) {
          editContext = context;
          return widget.childBuilder.call(context, overlayController);
        }),
      );
    });
  }
}
