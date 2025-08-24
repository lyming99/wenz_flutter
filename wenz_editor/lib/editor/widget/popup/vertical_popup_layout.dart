import 'dart:math';

import 'package:flutter/material.dart';

enum PopupAlignment { left, right, center }

class VerticalPopupLayout extends SingleChildLayoutDelegate {
  Rect anchorRect = Rect.zero;
  Size childSize = Size.zero;
  double margin;
  PopupAlignment childAlignment;

  VerticalPopupLayout({
    required this.anchorRect,
    required this.childSize,
    this.margin = 0,
    this.childAlignment = PopupAlignment.left,
  });

  @override
  bool shouldRelayout(covariant VerticalPopupLayout oldDelegate) {
    if (oldDelegate.anchorRect != anchorRect) {
      return true;
    }
    if (oldDelegate.childSize != childSize) {
      return true;
    }
    if (oldDelegate.margin != margin) {
      return true;
    }
    return false;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    var bottomExpand = constraints.maxHeight - anchorRect.bottom;
    var topExpand = anchorRect.top;
    double maxExpand =
        max(0, max(bottomExpand, topExpand) - margin * 2);
    return BoxConstraints(
      maxWidth: childSize.width,
      maxHeight: min(maxExpand, childSize.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size cSize) {
    Offset topLeft() {
      var bottomExpand = size.height - anchorRect.bottom;
      var topExpand = anchorRect.top;
      double maxExpand =
          max(0, max(bottomExpand, topExpand) - margin * 2);
      if (childSize.height > bottomExpand && bottomExpand < topExpand) {
        return anchorRect.topLeft
            .translate(0, -min(maxExpand, childSize.height) - margin);
      }
      return anchorRect.bottomLeft.translate(0, margin);
    }

    var position = topLeft();
    if (childAlignment == PopupAlignment.center) {
      position =
          position.translate((anchorRect.width - childSize.width) / 2, 0);
    } else if (childAlignment == PopupAlignment.right) {
      position = position.translate(anchorRect.width - childSize.width, 0);
    }
    if (position.dx < margin) {
      position = Offset(margin, position.dy);
    }
    if (position.dx + childSize.width > size.width - margin) {
      position = Offset(size.width - childSize.width - margin, position.dy);
    }
    return position;
  }
}
