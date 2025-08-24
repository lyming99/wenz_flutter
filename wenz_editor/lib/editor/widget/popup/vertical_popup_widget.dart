import 'package:flutter/material.dart';

import 'vertical_popup_layout.dart';

typedef ChildBuilder = Widget Function(
    BuildContext context, OverlayPortalController controller);

class PopupNotification extends Notification {
  bool isShow;

  PopupNotification({required this.isShow});
}

void notifyChildPopupState(BuildContext context, bool isShow) {
  PopupNotification(isShow: isShow).dispatch(context);
}

class VerticalPopupWidget extends StatefulWidget {
  final double popupWidth;
  final double popupHeight;
  final ChildBuilder popupBuilder;
  final VoidCallback? onPopup;
  final ChildBuilder childBuilder;
  final PopupAlignment popupAlignment;

  const VerticalPopupWidget({
    super.key,
    this.popupWidth = 400,
    this.popupHeight = 280,
    required this.popupBuilder,
    required this.childBuilder,
    this.popupAlignment = PopupAlignment.left,
    this.onPopup,
  });

  @override
  State<VerticalPopupWidget> createState() => _VerticalPopupWidgetState();
}

class _VerticalPopupWidgetState extends State<VerticalPopupWidget> {
  var overlayController = OverlayPortalController();
  Rect? editRect;
  bool hasChildPopupShown = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (BuildContext context) {
          var anchorRect = editRect!;
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
                if (!editRect!.contains(e.position)) {
                  overlayController.hide();
                }
              },
              child: CustomSingleChildLayout(
                delegate: VerticalPopupLayout(
                  margin: 4,
                  childAlignment: widget.popupAlignment,
                  anchorRect: anchorRect,
                  childSize: Size(
                      widget.popupWidth == 0
                          ? editRect!.size.width
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
                          ? editRect!.size.width
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
          var box = context.findRenderObject();
          if (box is RenderBox) {
            var rect = box.localToGlobal(Offset.zero) & box.size;
            editRect = rect;
          }
          return widget.childBuilder.call(context, overlayController);
        }),
      );
    });
  }
}
