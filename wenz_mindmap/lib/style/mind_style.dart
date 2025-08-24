import 'dart:math';

import 'package:flutter/material.dart';

import '../mindmap.dart';
import 'node_tool_widget.dart';

abstract class MindStyle {
  final double selectBorderWidth;
  final Color selectBorderColor;

  const MindStyle({
    this.selectBorderWidth = 1,
    this.selectBorderColor = Colors.blue,
  });

  double getFontSize(MindNode node);

  Color getFontColor(MindNode node);

  double getBorderWidth(MindNode node);

  double getMargin(MindNode node);

  Color getBorderColor(MindNode node);

  Color getBackgroundColor(MindNode node);

  double getRadius(MindNode node);

  double getHorizontalPadding(MindNode node);

  double getVerticalPadding(MindNode node);

  Color getPathColor(MindNode node);

  Size getNodeSize(
    MindNode node, {
    bool forceMeasure = false,
    TextStyle? defaultTextStyle,
  }) {
    var width = node.info?.width;
    var height = node.info?.height;
    if (!forceMeasure && width != null && height != null) {
      return Size(width, height);
    }
    Size widgetSize = Size.zero;
    if (node.isImage) {
      var imageWidth = node.info?.imageShowWidth ?? 0;
      var imageHeight = node.info?.imageShowHeight ?? 0;
      widgetSize = getWithBorderSize(
          node,
          Size(widgetSize.width + imageWidth,
              max(imageHeight, widgetSize.height)));
    } else if (node.isFormula) {
      var formulaWidth = node.info?.formulaWidth ?? 0;
      var formulaHeight = node.info?.formulaHeight ?? 0;
      widgetSize = getWithBorderSize(
          node,
          Size(widgetSize.width + formulaWidth,
              max(formulaHeight, widgetSize.height)));
    } else {
      widgetSize = getTextSize(node, defaultTextStyle);
    }
    Size buttonSize = getIconButtonSize(node);
    if (node.hasLink || node.hasNote) {
      widgetSize = Size(widgetSize.width + buttonSize.width,
          max(buttonSize.height, widgetSize.height));
    }
    if (node.isTodo) {
      widgetSize = Size(widgetSize.width + buttonSize.width,
          max(buttonSize.height, widgetSize.height));
    }
    // link、 待办、 formula、image、note
    node.info?.width = widgetSize.width;
    node.info?.height = widgetSize.height;
    return widgetSize;
  }

  Size getIconButtonSize(MindNode node) {
    return const Size(40, 40);
  }

  Size getTextSize(MindNode node, TextStyle? defaultTextStyle) {
    var textStyle = TextStyle(
      fontSize: getFontSize(node),
      fontFamily: getFontFamily(node),
    );
    if (defaultTextStyle != null) {
      textStyle = defaultTextStyle.merge(textStyle);
    }
    var painter = TextPainter(
      text: TextSpan(
        text: node.info?.content,
        style: textStyle,
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    var borderWidth =
        getBorderWidth(node) + selectBorderWidth * 2 + getMargin(node) + 1;
    var textSize = Size(
      max(
        60,
        painter.size.width + getHorizontalPadding(node) * 2 + borderWidth * 2,
      ),
      painter.size.height + getVerticalPadding(node) * 2 + borderWidth * 2,
    );
    return textSize;
  }

  Size getWithBorderSize(MindNode node, Size size) {
    var borderWidth =
        getBorderWidth(node) + selectBorderWidth * 2 + getMargin(node) + 1;
    return Size(
      max(
        60,
        size.width + getHorizontalPadding(node) * 2 + borderWidth * 2,
      ),
      size.height + getVerticalPadding(node) * 2 + borderWidth * 2,
    );
  }

  LinePath? buildParentPath(MindNode node, Offset offset, double scale) {
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
      start: start.translate(-borderWidth*scale, 0),
      end: end.translate(borderWidth*scale, 0),
      node: node,
    );
  }

  Color getExpandButtonColor(MindNode node);

  Color? getCursorColor(MindNode node) {
    return null;
  }

  String? getFontFamily(MindNode node) {
    return null;
  }

  Color getIconButtonColor(MindNode node) {
    if (node.depth <= 1) {
      return Colors.black;
    }
    return getPathColor(node);
  }

  Widget? buildToolWidget(MindNode element, double scale, Rect rect) {
    if (element.tapSelected) {
      scale = 1.0;
      return Positioned(
        left: rect.left,
        top: rect.top - 40 * scale,
        width: max((78 + 64) * scale, rect.width),
        height: 40 * scale,
        child: Container(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: (78 + 64) * scale,
            child: FittedBox(
              child: SizedBox(
                width: (78 + 64),
                child: NodeToolWidget(
                  node: element,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }
}
