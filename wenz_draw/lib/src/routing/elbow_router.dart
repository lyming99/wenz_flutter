import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 肘形连接器——实现 draw.io 风格的 ElbowConnector 路由。
///
/// 提供三种路由模式：
/// - [SideToSide]：垂直肘形（连线从水平两侧伸出）
/// - [TopToBottom]：水平肘形（连线从垂直两侧伸出）
/// - [ElbowConnector]：自动选择模式
///
/// 以及：
/// - [EntityRelation]：ER 图风格（始终从左右伸出，带偏移量）
///
/// 所有函数签名为：
///   `List<Offset> fn(Offset start, Offset end, Rect? sourceBounds, Rect? targetBounds, ...)`
class ElbowRouter {
  const ElbowRouter._();

  // ---------------------------------------------------------------------------
  // ElbowConnector — 自动选择 SideToSide 或 TopToBottom
  // ---------------------------------------------------------------------------

  /// 自动肘形连接器。
  ///
  /// 判断依据：
  /// - 若两顶点有垂直重叠区（left==right）→ 使用 TopToBottom
  /// - 若两顶点有水平重叠区（top==bottom）→ 使用 SideToSide
  /// - 若有控制点 [controlPoint]，根据控制点位于顶点上方/下方/左方/右方决定
  /// - 否则根据 [style] 中的 'elbow' 属性（'vertical' / 'horizontal'）决定
  static List<Offset> elbowConnector({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    Offset? controlPoint,
    double margin = 16,
    String elbowStyle = 'auto',
  }) {
    bool vertical = false;
    bool horizontal = false;

    if (sourceBounds != null && targetBounds != null) {
      if (controlPoint != null) {
        final left = math.min(sourceBounds.left, targetBounds.left);
        final right = math.max(
          sourceBounds.right,
          targetBounds.right,
        );
        final top = math.min(sourceBounds.top, targetBounds.top);
        final bottom = math.max(
          sourceBounds.bottom,
          targetBounds.bottom,
        );
        vertical = controlPoint.dy < top || controlPoint.dy > bottom;
        horizontal = controlPoint.dx < left || controlPoint.dx > right;
      } else {
        final left = math.max(sourceBounds.left, targetBounds.left);
        final right = math.min(
          sourceBounds.right,
          targetBounds.right,
        );
        vertical = (left - right).abs() < 0.0001;

        if (!vertical) {
          final top = math.max(sourceBounds.top, targetBounds.top);
          final bottom = math.min(
            sourceBounds.bottom,
            targetBounds.bottom,
          );
          horizontal = (top - bottom).abs() < 0.0001;
        }
      }
    }

    if (!horizontal &&
        (vertical || elbowStyle == 'vertical')) {
      return topToBottom(
        start: start,
        end: end,
        sourceBounds: sourceBounds,
        targetBounds: targetBounds,
        controlPoint: controlPoint,
        margin: margin,
      );
    }
    return sideToSide(
      start: start,
      end: end,
      sourceBounds: sourceBounds,
      targetBounds: targetBounds,
      controlPoint: controlPoint,
      margin: margin,
    );
  }

  // ---------------------------------------------------------------------------
  // SideToSide — 垂直肘形
  // ---------------------------------------------------------------------------

  /// 垂直肘形——连线从源和目标两侧水平伸出，中间用一条垂直线连接。
  ///
  /// 算法：
  /// 1. 找一条垂直线 x = 两顶点水平重叠区的中点（或控制点的 x）
  /// 2. y1 = source 的 routing center y（或控制点 y）
  /// 3. y2 = target 的 routing center y（或控制点 y）
  /// 4. 最多 2 个拐点：(x, y1) 和 (x, y2)
  static List<Offset> sideToSide({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    Offset? controlPoint,
    double margin = 16,
  }) {
    if (sourceBounds == null || targetBounds == null) {
      // 无边界信息 → 简单两拐点
      return _simpleManhattan(start, end);
    }

    final src = sourceBounds;
    final tgt = targetBounds;

    // 水平重叠区
    final l = math.max(src.left, tgt.left);
    final r = math.min(src.right, tgt.right);

    // 垂直线 x
    final double x;
    if (controlPoint != null) {
      x = controlPoint.dx;
    } else if (l <= r) {
      // 有重叠 → 取中点
      x = (l + r) / 2;
    } else {
      // 无重叠 → 在两者之间
      x = src.right < tgt.left
          ? src.right + margin
          : tgt.right + margin;
    }

    // routing center y
    var y1 = _routingCenterY(src, start);
    var y2 = _routingCenterY(tgt, end);

    // 控制点微调
    if (controlPoint != null) {
      if (controlPoint.dy >= src.top && controlPoint.dy <= src.bottom) {
        y1 = controlPoint.dy;
      }
      if (controlPoint.dy >= tgt.top && controlPoint.dy <= tgt.bottom) {
        y2 = controlPoint.dy;
      }
    }

    final result = <Offset>[start];

    // 拐点 1：从 source 水平伸出到垂直线
    final p1 = Offset(x, y1);
    if (!_containsExpanded(src, p1, margin) &&
        !_containsExpanded(tgt, p1, margin)) {
      result.add(p1);
    }

    // 拐点 2：垂直线到 target 高度
    final p2 = Offset(x, y2);
    if (!_containsExpanded(src, p2, margin) &&
        !_containsExpanded(tgt, p2, margin)) {
      result.add(p2);
    }

    // 如果只有一个拐点且不够好 → 插入中点
    if (result.length == 1) {
      if (controlPoint != null) {
        final pm = Offset(x, controlPoint.dy);
        if (!_containsExpanded(src, pm, margin) &&
            !_containsExpanded(tgt, pm, margin)) {
          result.add(pm);
        }
      } else {
        final t = math.max(src.top, tgt.top);
        final b = math.min(src.bottom, tgt.bottom);
        result.add(Offset(x, t + (b - t) / 2));
      }
    }

    result.add(end);
    return _dedupe(result);
  }

  // ---------------------------------------------------------------------------
  // TopToBottom — 水平肘形
  // ---------------------------------------------------------------------------

  /// 水平肘形——连线从源和目标两侧垂直伸出，中间用一条水平线连接。
  static List<Offset> topToBottom({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    Offset? controlPoint,
    double margin = 16,
  }) {
    if (sourceBounds == null || targetBounds == null) {
      return _simpleManhattan(start, end);
    }

    final src = sourceBounds;
    final tgt = targetBounds;

    // 垂直重叠区
    final t = math.max(src.top, tgt.top);
    final b = math.min(src.bottom, tgt.bottom);

    // 水平线 y
    final double y;
    if (controlPoint != null) {
      y = controlPoint.dy;
    } else if (t <= b) {
      y = (t + b) / 2;
    } else {
      y = src.bottom < tgt.top
          ? src.bottom + margin
          : tgt.bottom + margin;
    }

    // routing center x
    var x1 = _routingCenterX(src, start);
    var x2 = _routingCenterX(tgt, end);

    if (controlPoint != null) {
      if (controlPoint.dx >= src.left && controlPoint.dx <= src.right) {
        x1 = controlPoint.dx;
      }
      if (controlPoint.dx >= tgt.left && controlPoint.dx <= tgt.right) {
        x2 = controlPoint.dx;
      }
    }

    final result = <Offset>[start];

    final p1 = Offset(x1, y);
    if (!_containsExpanded(src, p1, margin) &&
        !_containsExpanded(tgt, p1, margin)) {
      result.add(p1);
    }

    final p2 = Offset(x2, y);
    if (!_containsExpanded(src, p2, margin) &&
        !_containsExpanded(tgt, p2, margin)) {
      result.add(p2);
    }

    if (result.length == 1) {
      if (controlPoint != null) {
        final pm = Offset(controlPoint.dx, y);
        if (!_containsExpanded(src, pm, margin) &&
            !_containsExpanded(tgt, pm, margin)) {
          result.add(pm);
        }
      } else {
        final l = math.max(src.left, tgt.left);
        final r = math.min(src.right, tgt.right);
        result.add(Offset(l + (r - l) / 2, y));
      }
    }

    result.add(end);
    return _dedupe(result);
  }

  // ---------------------------------------------------------------------------
  // EntityRelation — ER 图风格连接
  // ---------------------------------------------------------------------------

  /// ER 图风格连接器——所有连线从顶点左/右边缘水平伸出。
  ///
  /// [segment] 控制伸出时的偏移量（类似 draw.io 的 ENTITY_SEGMENT）。
  static List<Offset> entityRelation({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    double segment = 30,
  }) {
    if (sourceBounds == null || targetBounds == null) {
      return _simpleManhattan(start, end);
    }

    final src = sourceBounds;
    final tgt = targetBounds;

    // 确定 source 在 target 的左边还是右边
    final isSourceLeft = src.right <= tgt.left ||
        (src.center.dx <= tgt.center.dx);
    final isTargetLeft = tgt.right <= src.left ||
        (tgt.center.dx <= src.center.dx);

    final x0 = isSourceLeft ? src.right : src.left;
    final y0 = _routingCenterY(src, start);
    final xe = isTargetLeft ? tgt.right : tgt.left;
    final ye = _routingCenterY(tgt, end);

    final seg = segment;
    final dxSrc = isSourceLeft ? seg : -seg;
    final dxTgt = isTargetLeft ? seg : -seg;

    final dep = Offset(x0 + dxSrc, y0);
    final arr = Offset(xe + dxTgt, ye);

    final result = <Offset>[start];

    if (isSourceLeft == isTargetLeft) {
      // 同侧 → U 型
      final x = isSourceLeft
          ? math.min(x0, xe) - seg
          : math.max(x0, xe) + seg;
      result.add(Offset(x, y0));
      result.add(Offset(x, ye));
    } else if ((dep.dx < arr.dx) == isSourceLeft) {
      // 四拐点 Z 型
      final midY = y0 + (ye - y0) / 2;
      result.add(dep);
      result.add(Offset(dep.dx, midY));
      result.add(Offset(arr.dx, midY));
      result.add(arr);
    } else {
      // 两拐点
      result.add(dep);
      result.add(arr);
    }

    result.add(end);
    return _dedupe(result);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// 计算 routing center X（默认取顶点中心 X）。
  static double _routingCenterX(Rect bounds, Offset fallback) {
    return bounds.center.dx;
  }

  /// 计算 routing center Y（默认取顶点中心 Y）。
  static double _routingCenterY(Rect bounds, Offset fallback) {
    return bounds.center.dy;
  }

  /// 点是否在 expanded 矩形内（含边距）。
  static bool _containsExpanded(Rect rect, Offset point, double margin) {
    return point.dx >= rect.left - margin &&
        point.dx <= rect.right + margin &&
        point.dy >= rect.top - margin &&
        point.dy <= rect.bottom + margin;
  }

  /// 简单曼哈顿路由（无边界信息时回退）。
  static List<Offset> _simpleManhattan(Offset start, Offset end) {
    if ((start.dx - end.dx).abs() < 0.0001 ||
        (start.dy - end.dy).abs() < 0.0001) {
      return [start, end];
    }
    return [start, Offset(end.dx, start.dy), end];
  }

  /// 去重连续相同点。
  static List<Offset> _dedupe(List<Offset> points) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isEmpty || (result.last - point).distance > 0.0001) {
        result.add(point);
      }
    }
    return result;
  }
}
