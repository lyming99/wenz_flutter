import 'dart:ui' show Offset;

import '../elements/path_point.dart';

/// Ramer-Douglas-Peucker 路径简化算法。
///
/// 用于实时简化自由绘制路径，减少点数提高渲染性能。
/// 典型效果：1000 点 → 100-200 点。
class PathSimplifier {
  /// 使用 RDP 算法简化路径。
  ///
  /// [points] 原始点序列。
  /// [epsilon] 容差（世界坐标单位），值越大简化越激进。默认 2.0。
  /// 返回简化后的点序列。
  static List<PathPoint> simplify(List<PathPoint> points, {double epsilon = 2.0}) {
    if (points.length <= 2) return List.of(points);
    if (epsilon <= 0) return List.of(points);

    // 找到距离首尾连线最远的点
    int index = 0;
    double maxDist = 0;

    final first = points.first.position;
    final last = points.last.position;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(points[i].position, first, last);
      if (dist > maxDist) {
        index = i;
        maxDist = dist;
      }
    }

    // 如果最大距离大于容差，递归简化
    if (maxDist > epsilon) {
      final left = simplify(points.sublist(0, index + 1), epsilon: epsilon);
      final right = simplify(points.sublist(index), epsilon: epsilon);

      // 合并（去掉 left 的最后一个点，因为它和 right 的第一个点重复）
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // 所有点都在容差范围内，只保留首尾
      return [points.first, points.last];
    }
  }

  /// 计算点 [point] 到线段 ([lineStart], [lineEnd]) 的垂直距离。
  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;

    // 线段长度为 0
    if (dx == 0 && dy == 0) {
      return (point - lineStart).distance;
    }

    // 使用叉积公式计算点到直线的距离
    final numerator = ((dy * point.dx - dx * point.dy + lineEnd.dx * lineStart.dy - lineEnd.dy * lineStart.dx).abs());
    final denominator = (dx * dx + dy * dy);

    return numerator / denominator;
  }
}
