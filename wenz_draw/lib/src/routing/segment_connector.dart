import 'package:flutter/widgets.dart';

/// 分段正交连接器 —— 源自 draw.io (mxGraph) SegmentConnector。
///
/// 这是最灵活的路由算法，支持**任意数量的控制点**。
///
/// 核心思想：沿着控制点序列，以**交替水平/垂直**的方式生成正交路径。
///
/// 算法步骤：
/// 1. 将用户控制点从相对坐标转为绝对坐标
/// 2. 根据第一个控制点与 source 的关系确定初始方向（horizontal/vertical）
/// 3. 逐个控制点处理，交替水平→垂直→水平→垂直
/// 4. 移除落在 source/target 内部的冗余拐点（碰撞检测）
/// 5. 对路径点做去重（容差范围内合并）
///
/// 与 OrthConnector 互为补充：
/// - OrthConnector：全自动，无需用户手动添加控制点
/// - SegmentConnector：用户可通过拖拽控制点精细调整路径
class SegmentConnector {
  const SegmentConnector._();

  /// 分段正交路由。
  ///
  /// 参数：
  /// - [start] / [end]：起点和终点
  /// - [sourceBounds] / [targetBounds]：源和目标形状包围盒
  /// - [controlPoints]：用户控制点列表（绝对坐标）
  /// - [allowPolyline]：是否允许斜线段（默认 false，强制正交）
  /// - [tolerance]：去重容差
  static List<Offset> route({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    List<Offset> controlPoints = const [],
    bool allowPolyline = false,
    double tolerance = 0.5,
  }) {
    if (controlPoints.isEmpty) {
      // 无控制点 → 简单正交
      return _simpleOrthogonal(start, end, sourceBounds, targetBounds);
    }

    // Step 1: 确定初始方向
    final firstPt = controlPoints.first;
    final isHorizontal = _isHorizontalFirst(start, firstPt, sourceBounds);

    // Step 2: 生成路径段
    final segments = <Offset>[start];
    Offset prev = start;
    bool horizontal = isHorizontal;

    for (final pt in controlPoints) {
      if ((pt - prev).distance < tolerance) continue;

      // 交替水平/垂直
      final turn = horizontal
          ? Offset(pt.dx, prev.dy)
          : Offset(prev.dx, pt.dy);

      // 添加拐点
      if ((turn - prev).distance > tolerance) {
        segments.add(turn);
      }

      segments.add(pt);
      prev = pt;
      horizontal = !horizontal;
    }

    // Step 3: 连接到终点
    if ((end - prev).distance > tolerance) {
      final turn = horizontal
          ? Offset(end.dx, prev.dy)
          : Offset(prev.dx, end.dy);
      if ((turn - prev).distance > tolerance) {
        segments.add(turn);
      }
    }
    segments.add(end);

    // Step 4: 碰撞检测 —— 移除落在 source/target 内部的冗余拐点
    final cleaned = _removeInternalPoints(
      segments,
      sourceBounds: sourceBounds,
      targetBounds: targetBounds,
    );

    // Step 5: 去重
    return _dedupe(cleaned, tolerance: tolerance);
  }

  // ---------------------------------------------------------------------------
  // 初始方向判断
  // ---------------------------------------------------------------------------

  /// 判断第一个控制点与 source 的关系，确定初始方向。
  ///
  /// 规则：
  /// - 如果第一个控制点与 source 在水平/垂直方向重叠 → 优先非重叠方向
  /// - 否则根据偏移比例决定
  static bool _isHorizontalFirst(
    Offset start,
    Offset firstPt,
    Rect? sourceBounds,
  ) {
    final dx = (firstPt.dx - start.dx).abs();
    final dy = (firstPt.dy - start.dy).abs();

    // 如果控制点明显偏某个方向
    if (dx > dy * 1.5) return true;   // 水平优先
    if (dy > dx * 1.5) return false;  // 垂直优先

    // 参考 sourceBounds
    if (sourceBounds != null) {
      final startOnVerticalEdge =
          (start.dx - sourceBounds.left).abs() < 0.01 ||
              (start.dx - sourceBounds.right).abs() < 0.01;
      if (startOnVerticalEdge) return true;
    }

    // 默认水平
    return true;
  }

  // ---------------------------------------------------------------------------
  // 碰撞检测与冗余点移除
  // ---------------------------------------------------------------------------

  /// 移除落在 source 或 target 内部的冗余拐点。
  static List<Offset> _removeInternalPoints(
    List<Offset> points, {
    Rect? sourceBounds,
    Rect? targetBounds,
  }) {
    if (points.length <= 2) return points;

    // 检查并移除第一个中间点（如果落在 source 内）
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final pt = points[i];
      final prev = result.last;
      final next = points[i + 1];

      // 检查该点是否在 source 或 target 内部
      final bool inSource = sourceBounds?.contains(pt) ?? false;
      final bool inTarget = targetBounds?.contains(pt) ?? false;

      // 如果是冗余拐点（共线），移除
      if (_isCollinear(prev, pt, next)) {
        if (!inSource && !inTarget) {
          continue;
        }
      }

      result.add(pt);
    }
    result.add(points.last);
    return result;
  }

  /// 检查三个点是否共线（在容差范围内）。
  static bool _isCollinear(Offset a, Offset b, Offset c) {
    const eps = 0.5;
    // 三点共线：cross product == 0
    final cross = ((b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx)).abs();
    return cross < eps;
  }

  // ---------------------------------------------------------------------------
  // 简单正交回退
  // ---------------------------------------------------------------------------

  static List<Offset> _simpleOrthogonal(
    Offset start,
    Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
  ) {
    if ((start.dx - end.dx).abs() < 0.01 || (start.dy - end.dy).abs() < 0.01) {
      return [start, end];
    }
    // 默认水平优先
    return [start, Offset(end.dx, start.dy), end];
  }

  // ---------------------------------------------------------------------------
  // 工具函数
  // ---------------------------------------------------------------------------

  /// 去重连续相同/近乎相同的点。
  static List<Offset> _dedupe(List<Offset> points, {double tolerance = 0.5}) {
    final result = <Offset>[];
    for (final p in points) {
      if (result.isEmpty || (result.last - p).distance > tolerance) {
        result.add(p);
      }
    }
    return result;
  }
}
