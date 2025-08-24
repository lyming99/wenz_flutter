import 'package:flutter/material.dart';

import '../mindmap.dart';

final buttonColors = [
  Color(0xfffd8c00),
  Color(0xffff003d),
  Color(0xff0605f1),
  Color(0xffff6400),
  Color(0xfff4a101),
  Color(0xff03a15a),
];
final secondaryBackgroundColors = [
  Color(0xfff10505),
  Color(0xffff6400),
  Color(0xfff4a101),
  Color(0xff03a15a),
  Color(0xff008cfd),
  Color(0xff3d00ff),
];
final secondaryFontColors = [
  Color(0xffffffff),
  Color(0xff020000),
  Color(0xff070000),
  Color(0xfff7f8f8),
  Color(0xfff7f8f8),
  Color(0xfffdfdfd),
];
final thirdBackgroundColors = [
  Color(0xfff69797),
  Color(0xfff3ac7e),
  Color(0xffffd75e),
  Color(0xff77efb4),
  Color(0xff7cbcf1),
  Color(0xff9779f4),
];
final thirdFontColors = [
  Color(0xff472d2d),
  Color(0xff4e3728),
  Color(0xff574729),
  Color(0xff1f3c2e),
  Color(0xff121a22),
  Color(0xff2b2245),
];

extension NodeExtension on MindNode {
  int getSecondaryIndex() {
    MindNode? node = this;
    while (node != null && node.depth != 1) {
      node = node.parent;
    }
    return node?.getIndex() ?? 0;
  }
}

class XMindStyle extends MindStyle {
  const XMindStyle({
    super.selectBorderWidth = 2,
  });

  @override
  Color getBackgroundColor(MindNode node) {
    if (node.depth == 0) {
      return Colors.black;
    }
    if (node.depth == 1) {
      var index = node.getIndex();
      return secondaryBackgroundColors[
          index % secondaryBackgroundColors.length];
    }
    var index = node.getSecondaryIndex();
    return thirdBackgroundColors[index % thirdBackgroundColors.length];
  }

  @override
  Color getBorderColor(MindNode node) {
    return Colors.transparent;
  }

  @override
  double getBorderWidth(MindNode node) {
    return 0;
  }

  @override
  Color getFontColor(MindNode node) {
    if (node.depth == 0) {
      return Colors.white;
    }
    if (node.depth == 1) {
      var index = node.getIndex();
      return secondaryFontColors[index % secondaryFontColors.length];
    }
    var index = node.getSecondaryIndex();
    return thirdFontColors[index % thirdFontColors.length];
  }

  @override
  double getFontSize(MindNode node) {
    if (node.depth == 0) {
      return 24;
    }
    if (node.depth == 1) {
      return 16;
    }
    return 14;
  }

  @override
  double getMargin(MindNode node) {
    return 2;
  }

  @override
  double getHorizontalPadding(MindNode node) {
    if (node.depth == 0) {
      return 24;
    }
    if (node.depth == 1) {
      return 16;
    }
    return 8;
  }

  @override
  double getVerticalPadding(MindNode node) {
    if (node.depth == 0) {
      return 12;
    }
    if (node.depth == 1) {
      return 8;
    }
    return 4;
  }

  @override
  double getRadius(MindNode node) {
    return 8;
  }

  @override
  Color getPathColor(MindNode node) {
    var index = node.getSecondaryIndex();
    return secondaryBackgroundColors[index % secondaryBackgroundColors.length];
  }

  @override
  Color getIconButtonColor(MindNode node) {
    var index = node.getSecondaryIndex();
    if (node.depth <= 1) {
      return buttonColors[index % buttonColors.length];
    }
    return secondaryBackgroundColors[index % secondaryBackgroundColors.length];
  }

  @override
  Color getExpandButtonColor(MindNode node) {
    if (node.isRoot) {
      return getBackgroundColor(node);
    }
    var index = node.getSecondaryIndex();
    return thirdBackgroundColors[index % thirdBackgroundColors.length];
  }

  @override
  LinePath? buildParentPath(MindNode node, Offset offset, double scale) {
    var color = getPathColor(node);
    var parent = node.parent;
    if (parent == null) {
      return null;
    }
    var start = (parent.widgetPosition & parent.widgetSize)
        .centerRight
        .translate(offset.dx, offset.dy);
    var end = (node.widgetPosition & node.widgetSize)
        .centerLeft
        .translate(offset.dx, offset.dy);
    var borderWidth =
        getBorderWidth(node) + selectBorderWidth + getMargin(node);
    return LinePath(
      scale: scale,
      color: color,
      start: start.translate(-borderWidth * scale, 0),
      end: end.translate(borderWidth * scale, 0),
      node: node,
    );
  }

  @override
  Color? getCursorColor(MindNode node) {
    if (node.depth == 0) {
      return null;
    }
    if (node.depth == 1) {
      var index = node.getIndex() + 2;
      return secondaryBackgroundColors[
          index % secondaryBackgroundColors.length];
    }
    var index = node.getSecondaryIndex() + 2;

    return thirdBackgroundColors[index % thirdBackgroundColors.length];
  }
}
