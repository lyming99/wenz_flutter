import '../../commons/widget/popup_stack.dart';

class PopupUtils{
  PopupUtils._();
  ///对popupWidget的left坐标偏移量处理
  ///可以用于视图居中x计算处理
  static List<PopupPositionWidget> translatePopupPositionWidget(
      List<PopupPositionWidget> floatWidgets, double offsetX, double offsetY) {
    List<PopupPositionWidget> popupWidgets = [];
    for (var floatWidget in floatWidgets) {
      var left = floatWidget.left;
      var right = floatWidget.right;
      var top = floatWidget.top;
      var bottom = floatWidget.bottom;
      var anchorRect = floatWidget.anchorRect;
      if (left != null || right != null || anchorRect != null) {
        if (left != null) {
          left += offsetX;
        }
        if (right != null) {
          right += offsetX;
        }
        if (top != null) {
          top += offsetY;
        }
        if (bottom != null) {
          bottom += offsetY;
        }
        if (anchorRect != null) {
          anchorRect = anchorRect.translate(offsetX, offsetY);
        }
        floatWidget = PopupPositionWidget(
            key: floatWidget.key,
            layerIndex: floatWidget.layerIndex,
            left: left,
            right: right,
            top: top,
            bottom: bottom,
            width: floatWidget.width,
            height: floatWidget.height,
            anchorRect: anchorRect,
            keepVision: floatWidget.keepVision,
            popupAlignment: floatWidget.popupAlignment,
            overflowAlignment: floatWidget.overflowAlignment,
            child: floatWidget.child);
      }
      popupWidgets.add(floatWidget);
    }
    return popupWidgets;
  }
}