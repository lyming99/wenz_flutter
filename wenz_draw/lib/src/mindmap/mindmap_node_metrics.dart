import 'package:flutter/painting.dart';

import 'mindmap_node.dart';

class MindmapNodeMetrics {
  const MindmapNodeMetrics._();

  static const double minNodeWidth = 120;
  static const double minRootWidth = 140;
  static const double maxNodeWidth = 320;
  static const double maxRootWidth = 380;
  static const double nodeHeight = 40;
  static const double rootHeight = 48;

  static double widthForText(
    String text, {
    required bool isRoot,
    double? minWidth,
    double? maxWidth,
  }) {
    final label = text.trim().isEmpty ? '...' : text.trim();
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: isRoot ? 16 : 14,
          fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final horizontalPadding = isRoot ? 32.0 : 24.0;
    final breathingRoom = isRoot ? 18.0 : 16.0;
    final rawWidth = painter.width + horizontalPadding + breathingRoom;
    return rawWidth
        .clamp(
          minWidth ?? (isRoot ? minRootWidth : minNodeWidth),
          maxWidth ?? (isRoot ? maxRootWidth : maxNodeWidth),
        )
        .toDouble();
  }

  static double widthForNode(MindmapNode node, {required bool isRoot}) {
    return widthForText(node.text, isRoot: isRoot);
  }
}
