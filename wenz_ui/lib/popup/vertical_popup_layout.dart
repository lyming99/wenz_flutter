import 'dart:math';

import 'package:flutter/material.dart';

enum ChildAlignment { left, right, center }

class VerticalPopupLayout extends SingleChildLayoutDelegate {
  Rect anchorRect = Rect.zero;
  Size childSize = Size.zero;
  double verticalMargin;
  ChildAlignment childAlignment;

  VerticalPopupLayout({
    required this.anchorRect,
    required this.childSize,
    this.verticalMargin = 0,
    this.childAlignment = ChildAlignment.left,
  });

  @override
  bool shouldRelayout(covariant VerticalPopupLayout oldDelegate) {
    if (oldDelegate.anchorRect != anchorRect) {
      return true;
    }
    if (oldDelegate.childSize != childSize) {
      return true;
    }
    if (oldDelegate.verticalMargin != verticalMargin) {
      return true;
    }
    return false;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    var bottomExpand = constraints.maxHeight - anchorRect.bottom;
    var topExpand = anchorRect.top;
    double maxExpand =
        max(0, max(bottomExpand, topExpand) - verticalMargin * 2);
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
          max(0, max(bottomExpand, topExpand) - verticalMargin * 2);
      if (childSize.height > bottomExpand && bottomExpand < topExpand) {
        return anchorRect.topLeft
            .translate(0, -min(maxExpand, childSize.height) - verticalMargin);
      }
      return anchorRect.bottomLeft.translate(0, verticalMargin);
    }

    var position = topLeft();
    if (childAlignment == ChildAlignment.center) {
      position =
          position.translate((anchorRect.width - childSize.width) / 2, 0);
    } else if (childAlignment == ChildAlignment.right) {
      position = position.translate(anchorRect.width - childSize.width, 0);
    }
    return position;
  }
}
