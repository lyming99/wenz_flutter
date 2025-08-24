import 'package:flutter/material.dart';

import 'bubble_border.dart';

/// 气泡组件
/// 爱今天灵眸（ijtkj.cn）,一款可根据天气改变系统显示模式的软件，期待各位有钱的码友支持
class BubbleWidget extends StatelessWidget {
  final BorderSide border;
  final AxisDirection arrowDirection;
  final BorderRadius? borderRadius;
  final double arrowLength;
  final double arrowWidth;
  final double? arrowOffset;
  final double arrowRadius;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final WidgetBuilder contentBuilder;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? margin;

  const BubbleWidget({
    super.key,
    required this.arrowDirection,
    this.arrowOffset,
    required this.contentBuilder,
    this.border = BorderSide.none,
    this.borderRadius,
    this.arrowLength = 10,
    this.arrowWidth = 17,
    this.arrowRadius = 3,
    this.backgroundColor,
    this.shadows,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsets bubblePadding = EdgeInsets.zero;
    if (arrowDirection == AxisDirection.up) {
      bubblePadding = EdgeInsets.only(top: arrowLength);
    } else if (arrowDirection == AxisDirection.down) {
      bubblePadding = EdgeInsets.only(bottom: arrowLength);
    } else if (arrowDirection == AxisDirection.left) {
      bubblePadding = EdgeInsets.only(left: arrowLength);
    } else if (arrowDirection == AxisDirection.right) {
      bubblePadding = EdgeInsets.only(right: arrowLength);
    }
    return Container(
      margin: margin,
      decoration: ShapeDecoration(
        shape: BubbleShapeBorder(
          side: border,
          arrowDirection: arrowDirection,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
          arrowLength: arrowLength,
          arrowWidth: arrowWidth,
          arrowRadius: arrowRadius,
          arrowOffset: arrowOffset,
          fillColor: backgroundColor ?? const Color.fromARGB(255, 65, 65, 65),
        ),
        shadows: shadows,
      ),
      child: Padding(
        padding: bubblePadding.add(padding ?? EdgeInsets.zero),
        child: contentBuilder(context),
      ),
    );
  }
}
