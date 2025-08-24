import 'package:flutter/material.dart';

import 'vertical_popup_layout.dart';

typedef PopupBuilder = Widget Function(
    BuildContext context, OverlayPortalController controller);

class VerticalPopupField extends StatefulWidget {
  final double popupWidth;
  final double popupHeight;
  final double itemHeight;
  final PopupBuilder popupBuilder;
  final TextEditingController editController;
  final VoidCallback? onPopup;

  const VerticalPopupField({
    super.key,
    this.popupWidth = 400,
    this.popupHeight = 280,
    this.itemHeight = 40,
    required this.popupBuilder,
    required this.editController,
    this.onPopup,
  });

  @override
  State<VerticalPopupField> createState() => _VerticalPopupFieldState();
}

class _VerticalPopupFieldState extends State<VerticalPopupField> {
  var overlayController = OverlayPortalController();
  BuildContext? editContext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (BuildContext context) {
          var box = editContext!.findRenderObject() as RenderBox;
          var topLeft = box.localToGlobal(Offset.zero);
          var anchorRect = topLeft & Size(box.size.width, box.size.height);
          return TapRegion(
            onTapOutside: (e) {
              var box = editContext!.findRenderObject() as RenderBox;
              var rect = box.localToGlobal(Offset.zero) & box.size;
              if (!rect.contains(e.position)) {
                overlayController.hide();
              }
            },
            child: CustomSingleChildLayout(
              delegate: VerticalPopupLayout(
                verticalMargin: 4,
                anchorRect: anchorRect,
                childSize: Size(widget.popupWidth, widget.popupHeight),
              ),
              child: Material(
                color: Colors.transparent,
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Theme
                      .of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  elevation: 2,
                  shape: const RoundedRectangleBorder(),
                  child: SizedBox(
                    width: widget.popupWidth,
                    height: widget.popupHeight,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        return true;
                      },
                      child:
                      widget.popupBuilder.call(context, overlayController),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: Builder(builder: (context) {
          editContext = context;
          var theme = Theme
              .of(context)
              .inputDecorationTheme
              .copyWith();
          return TextField(
            controller: widget.editController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: theme.contentPadding,
              suffixIconConstraints: BoxConstraints(
                maxWidth: widget.itemHeight,
                maxHeight: widget.itemHeight,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: widget.itemHeight -
                        (theme.contentPadding?.vertical ?? 0),
                    height: widget.itemHeight -
                        (theme.contentPadding?.vertical ?? 0),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () {
                    overlayController.show();
                    widget.onPopup?.call();
                  },
                ),
              ),
            ),
            onTap: () {
              overlayController.toggle();
              if (overlayController.isShowing) {
                widget.onPopup?.call();
              }
            },
          );
        }),
      );
    });
  }
}
