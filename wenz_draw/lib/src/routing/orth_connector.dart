import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 全自动正交路由连接器 —— draw.io (mxGraph) `mxEdgeStyle.OrthConnector` 的
/// 1:1 Dart 移植。
///
/// 算法与 mxGraph 完全一致：
/// 1. 计算 source/target 的 jetty size（引出缓冲，`getJettySize`）
/// 2. 距离过近时回退（这里回退到简单正交，mxGraph 回退到 SegmentConnector）
/// 3. 计算端口约束 `portConstraint`、`limits`、象限 `quad`
/// 4. 根据固定连接点所在边 + 距离启发式 + 端口约束确定 `dir[0]`、`dir[1]`
/// 5. 用 `routePatterns[sourceIndex][targetIndex]` 查表得到路由指令序列
/// 6. 遍历指令序列，按位拆解（方向/源目标/边界/中线）逐段生成 waypoint
/// 7. 末点奇偶校验、坐标取整、相邻去重
///
/// 方向位掩码与 mxConstants 保持一致：WEST=1, NORTH=2, SOUTH=4, EAST=8。
class OrthConnector {
  const OrthConnector._();

  // ---------------------------------------------------------------------------
  // 方向位掩码（与 mxConstants.DIRECTION_MASK_* 完全一致）
  // ---------------------------------------------------------------------------

  static const int _maskWest = 1;
  static const int _maskNorth = 2;
  static const int _maskSouth = 4;
  static const int _maskEast = 8;
  static const int _maskAll = 15;

  // 路由指令位段（与 mxEdgeStyle 一致）
  static const int _sideMask = 480;
  static const int _centerMask = 512;
  static const int _sourceMask = 1024;
  static const int _targetMask = 2048;

  // 默认引出缓冲（mxEdgeStyle.orthBuffer）
  static const double _orthBuffer = 10;

  // ---------------------------------------------------------------------------
  // 方向向量（mxEdgeStyle.dirVectors）
  // 索引按 directionIndex-1：[W, N, E, S, W, N, E]
  // ---------------------------------------------------------------------------
  static const List<List<int>> _dirVectors = [
    [-1, 0],
    [0, -1],
    [1, 0],
    [0, 1],
    [-1, 0],
    [0, -1],
    [1, 0],
  ];

  /// 路由模式查找表（mxEdgeStyle.routePatterns）。
  /// 4×4：[sourceIndex-1][targetIndex-1] → 指令数组。
  static const List<List<List<int>>> _routePatterns = [
    [
      [513, 2308, 2081, 2562],
      [513, 1090, 514, 2184, 2114, 2561],
      [513, 1090, 514, 2564, 2184, 2562],
      [513, 2308, 2561, 1090, 514, 2568, 2308],
    ],
    [
      [514, 1057, 513, 2308, 2081, 2562],
      [514, 2184, 2114, 2561],
      [514, 2184, 2562, 1057, 513, 2564, 2184],
      [514, 1057, 513, 2568, 2308, 2561],
    ],
    [
      [1090, 514, 1057, 513, 2308, 2081, 2562],
      [2114, 2561],
      [1090, 2562, 1057, 513, 2564, 2184],
      [1090, 514, 1057, 513, 2308, 2561, 2568],
    ],
    [
      [2081, 2562],
      [1057, 513, 1090, 514, 2184, 2114, 2561],
      [1057, 513, 1090, 514, 2184, 2562, 2564],
      [1057, 2561, 1090, 514, 2568, 2308],
    ],
  ];

  /// 当源目标在同一水平/垂直线上（dx==0 或 dy==0）时的简化模式
  /// （mxEdgeStyle.inlineRoutePatterns）。
  static const List<List<List<int>?>> _inlineRoutePatterns = [
    [null, [2114, 2568], null, null],
    [null, [514, 2081, 2114, 2568], null, null],
    [null, [2114, 2561], null, null],
    [
      [2081, 2562],
      [1057, 2114, 2568],
      [2184, 2562],
      null,
    ],
  ];

  // ---------------------------------------------------------------------------
  // 公共入口
  // ---------------------------------------------------------------------------

  /// 计算正交路由路径。
  ///
  /// 参数：
  /// - [start] / [end]：连线的起止点（通常是形状边界上的固定接触点 p0/pe）
  /// - [sourceBounds] / [targetBounds]：源和目标形状的包围盒
  /// - [sourcePortConstraint] / [targetPortConstraint]：端口方向约束位掩码
  ///   （WEST=1/NORTH=2/SOUTH=4/EAST=8 的组合，null 表示不限制）
  /// - [margin]：基本缓冲距离（对应 orthBuffer）
  /// - [arrowSize]：箭头大小（用于自动 jetty size，<=0 表示无箭头）
  static List<Offset> route({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    int? sourcePortConstraint,
    int? targetPortConstraint,
    double margin = _orthBuffer,
    double arrowSize = 0,
    bool sourceFixed = false,
    bool targetFixed = false,
  }) {
    if (sourceBounds == null || targetBounds == null) {
      return _simpleFallback(start, end);
    }

    final source = sourceBounds;
    final target = targetBounds;

    final p0 = start;
    final pe = end;

    final sourceBuffer = _jettySize(margin, arrowSize);
    var targetBuffer = _jettySize(margin, arrowSize);
    var srcBuffer = sourceBuffer;

    // 自环缓冲区修正
    if (source == target) {
      targetBuffer = math.max(srcBuffer, targetBuffer);
      srcBuffer = targetBuffer;
    }

    final totalBuffer = targetBuffer + srcBuffer;

    // 距离过近 → 回退到简单正交（mxGraph 回退到 SegmentConnector）
    final dxe = pe.dx - p0.dx;
    final dye = pe.dy - p0.dy;
    if (dxe * dxe + dye * dye < totalBuffer * totalBuffer) {
      return _simpleFallback(start, end);
    }

    return _orthRoute(
      p0: p0,
      pe: pe,
      source: source,
      target: target,
      sourceBuffer: srcBuffer,
      targetBuffer: targetBuffer,
      portConstraint: [
        sourcePortConstraint ?? _maskAll,
        targetPortConstraint ?? _maskAll,
      ],
      sourceFixed: sourceFixed,
      targetFixed: targetFixed,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Jetty Size（mxEdgeStyle.getJettySize）
  // ---------------------------------------------------------------------------

  static double _jettySize(double buffer, double arrowSize) {
    if (arrowSize > 0) {
      final value =
          math.max(2, ((arrowSize + buffer) / buffer).ceil()) * buffer;
      return value.toDouble();
    }
    // 无箭头：使用 2 倍 buffer（mxGraph 的 'auto' 无箭头分支）。
    // 普通情况下 mxGraph 直接用 orthBuffer，这里用 buffer 本身。
    return buffer;
  }

  // ---------------------------------------------------------------------------
  // 核心：OrthConnector 主算法（mxEdgeStyle.OrthConnector 移植）
  // ---------------------------------------------------------------------------

  static List<Offset> _orthRoute({
    required Offset p0,
    required Offset pe,
    required Rect source,
    required Rect target,
    required double sourceBuffer,
    required double targetBuffer,
    required List<int> portConstraint,
    bool sourceFixed = false,
    bool targetFixed = false,
  }) {
    final result = <Offset>[];

    final sourceX = source.left;
    final sourceY = source.top;
    final sourceWidth = source.width;
    final sourceHeight = source.height;

    final targetX = target.left;
    final targetY = target.top;
    final targetWidth = target.width;
    final targetHeight = target.height;

    if (sourceWidth == 0 ||
        sourceHeight == 0 ||
        targetWidth == 0 ||
        targetHeight == 0) {
      return _simpleFallback(p0, pe);
    }

    final totalBuffer = targetBuffer + sourceBuffer;

    // geo -> [source, target] [x, y, width, height]
    final geo = [
      [sourceX, sourceY, sourceWidth, sourceHeight],
      [targetX, targetY, targetWidth, targetHeight],
    ];
    final buffer = [sourceBuffer, targetBuffer];

    // limits[i] = [_, left-buf, top-buf, _, right+buf, _, _, _, bottom+buf]
    final limits = [
      List<double>.filled(9, 0),
      List<double>.filled(9, 0),
    ];
    for (var i = 0; i < 2; i++) {
      limits[i][1] = geo[i][0] - buffer[i];
      limits[i][2] = geo[i][1] - buffer[i];
      limits[i][4] = geo[i][0] + geo[i][2] + buffer[i];
      limits[i][8] = geo[i][1] + geo[i][3] + buffer[i];
    }

    // 象限判定（与 mxGraph 一致）
    // 0 | 1
    // -----
    // 3 | 2
    final sourceCenX = geo[0][0] + geo[0][2] / 2.0;
    final sourceCenY = geo[0][1] + geo[0][3] / 2.0;
    final targetCenX = geo[1][0] + geo[1][2] / 2.0;
    final targetCenY = geo[1][1] + geo[1][3] / 2.0;

    final dx = sourceCenX - targetCenX;
    final dy = sourceCenY - targetCenY;

    var quad = 0;
    if (dx < 0) {
      quad = dy < 0 ? 2 : 1;
    } else {
      if (dy <= 0) {
        quad = 3;
        if (dx == 0) {
          quad = 2;
        }
      }
    }

    // 检查固定连接点约束（仅当端点是固定连接点时才探测出口边）。
    // mxGraph：浮动端点（pts[i]==null）不设 dir，由距离启发式决定方向。
    final dir = [0, 0];
    final constraint = [
      [0.5, 0.5],
      [0.5, 0.5],
    ];
    final fixed = [sourceFixed, targetFixed];

    var currentTerm = p0;
    for (var i = 0; i < 2; i++) {
      if (!fixed[i]) {
        // 浮动端点：保持中心约束 0.5，不探测边方向
        currentTerm = pe;
        continue;
      }
      constraint[i][0] = (currentTerm.dx - geo[i][0]) / geo[i][2];
      if ((currentTerm.dx - geo[i][0]).abs() <= 1) {
        dir[i] = _maskWest;
      } else if ((currentTerm.dx - geo[i][0] - geo[i][2]).abs() <= 1) {
        dir[i] = _maskEast;
      }

      constraint[i][1] = (currentTerm.dy - geo[i][1]) / geo[i][3];
      if ((currentTerm.dy - geo[i][1]).abs() <= 1) {
        dir[i] = _maskNorth;
      } else if ((currentTerm.dy - geo[i][1] - geo[i][3]).abs() <= 1) {
        dir[i] = _maskSouth;
      }

      currentTerm = pe;
    }

    final sourceTopDist = geo[0][1] - (geo[1][1] + geo[1][3]);
    final sourceLeftDist = geo[0][0] - (geo[1][0] + geo[1][2]);
    final sourceBottomDist = geo[1][1] - (geo[0][1] + geo[0][3]);
    final sourceRightDist = geo[1][0] - (geo[0][0] + geo[0][2]);

    final vertexSeperations = List<double>.filled(5, 0);
    vertexSeperations[1] = math.max(sourceLeftDist - totalBuffer, 0);
    vertexSeperations[2] = math.max(sourceTopDist - totalBuffer, 0);
    vertexSeperations[4] = math.max(sourceBottomDist - totalBuffer, 0);
    vertexSeperations[3] = math.max(sourceRightDist - totalBuffer, 0);

    // ===== 方向决定开始 =====
    final dirPref = [0, 0];
    final horPref = [0, 0];
    final vertPref = [0, 0];

    horPref[0] = (sourceLeftDist >= sourceRightDist) ? _maskWest : _maskEast;
    vertPref[0] = (sourceTopDist >= sourceBottomDist) ? _maskNorth : _maskSouth;

    horPref[1] = _reversePortConstraints(horPref[0]);
    vertPref[1] = _reversePortConstraints(vertPref[0]);

    final preferredHorizDist =
        sourceLeftDist >= sourceRightDist ? sourceLeftDist : sourceRightDist;
    final preferredVertDist =
        sourceTopDist >= sourceBottomDist ? sourceTopDist : sourceBottomDist;

    final prefOrdering = [
      [0, 0],
      [0, 0],
    ];
    var preferredOrderSet = false;

    for (var i = 0; i < 2; i++) {
      if (dir[i] != 0x0) continue;

      if ((horPref[i] & portConstraint[i]) == 0) {
        horPref[i] = _reversePortConstraints(horPref[i]);
      }
      if ((vertPref[i] & portConstraint[i]) == 0) {
        vertPref[i] = _reversePortConstraints(vertPref[i]);
      }

      prefOrdering[i][0] = vertPref[i];
      prefOrdering[i][1] = horPref[i];
    }

    if (preferredVertDist > 0 && preferredHorizDist > 0) {
      if (((horPref[0] & portConstraint[0]) > 0) &&
          ((vertPref[1] & portConstraint[1]) > 0)) {
        prefOrdering[0][0] = horPref[0];
        prefOrdering[0][1] = vertPref[0];
        prefOrdering[1][0] = vertPref[1];
        prefOrdering[1][1] = horPref[1];
        preferredOrderSet = true;
      } else if (((vertPref[0] & portConstraint[0]) > 0) &&
          ((horPref[1] & portConstraint[1]) > 0)) {
        prefOrdering[0][0] = vertPref[0];
        prefOrdering[0][1] = horPref[0];
        prefOrdering[1][0] = horPref[1];
        prefOrdering[1][1] = vertPref[1];
        preferredOrderSet = true;
      }
    }

    if (preferredVertDist > 0 && !preferredOrderSet) {
      prefOrdering[0][0] = vertPref[0];
      prefOrdering[0][1] = horPref[0];
      prefOrdering[1][0] = vertPref[1];
      prefOrdering[1][1] = horPref[1];
      preferredOrderSet = true;
    }

    if (preferredHorizDist > 0 && !preferredOrderSet) {
      prefOrdering[0][0] = horPref[0];
      prefOrdering[0][1] = vertPref[0];
      prefOrdering[1][0] = horPref[1];
      prefOrdering[1][1] = vertPref[1];
      preferredOrderSet = true;
    }

    for (var i = 0; i < 2; i++) {
      if (dir[i] != 0x0) continue;

      if ((prefOrdering[i][0] & portConstraint[i]) == 0) {
        prefOrdering[i][0] = prefOrdering[i][1];
      }

      dirPref[i] = prefOrdering[i][0] & portConstraint[i];
      dirPref[i] |= (prefOrdering[i][1] & portConstraint[i]) << 8;
      dirPref[i] |= (prefOrdering[1 - i][i] & portConstraint[i]) << 16;
      dirPref[i] |= (prefOrdering[1 - i][1 - i] & portConstraint[i]) << 24;

      if ((dirPref[i] & 0xF) == 0) {
        dirPref[i] = dirPref[i] << 8;
      }
      if ((dirPref[i] & 0xF00) == 0) {
        dirPref[i] = (dirPref[i] & 0xF) | (dirPref[i] >> 8);
      }
      if ((dirPref[i] & 0xF0000) == 0) {
        dirPref[i] = (dirPref[i] & 0xFFFF) | ((dirPref[i] & 0xF000000) >> 8);
      }

      dir[i] = dirPref[i] & 0xF;

      if (portConstraint[i] == _maskWest ||
          portConstraint[i] == _maskNorth ||
          portConstraint[i] == _maskEast ||
          portConstraint[i] == _maskSouth) {
        dir[i] = portConstraint[i];
      }
    }
    // ===== 方向决定结束 =====

    var sourceIndex = dir[0] == _maskEast ? 3 : dir[0];
    var targetIndex = dir[1] == _maskEast ? 3 : dir[1];

    sourceIndex -= quad;
    targetIndex -= quad;

    if (sourceIndex < 1) sourceIndex += 4;
    if (targetIndex < 1) targetIndex += 4;

    // 选择路由模式（含 inline 简化分支）
    var routePattern = _routePatterns[sourceIndex - 1][targetIndex - 1];
    if (dx == 0 || dy == 0) {
      final inline = _inlineRoutePatterns[sourceIndex - 1][targetIndex - 1];
      if (inline != null) {
        routePattern = inline;
      }
    }

    // wayPoints
    final wayPoints = List.generate(12, (_) => <double>[0, 0]);
    wayPoints[0][0] = geo[0][0];
    wayPoints[0][1] = geo[0][1];

    switch (dir[0]) {
      case _maskWest:
        wayPoints[0][0] -= sourceBuffer;
        wayPoints[0][1] += constraint[0][1] * geo[0][3];
        break;
      case _maskSouth:
        wayPoints[0][0] += constraint[0][0] * geo[0][2];
        wayPoints[0][1] += geo[0][3] + sourceBuffer;
        break;
      case _maskEast:
        wayPoints[0][0] += geo[0][2] + sourceBuffer;
        wayPoints[0][1] += constraint[0][1] * geo[0][3];
        break;
      case _maskNorth:
        wayPoints[0][0] += constraint[0][0] * geo[0][2];
        wayPoints[0][1] -= sourceBuffer;
        break;
    }

    var currentIndex = 0;
    var lastOrientation =
        (dir[0] & (_maskEast | _maskWest)) > 0 ? 0 : 1;
    final initialOrientation = lastOrientation;
    var currentOrientation = 0;

    for (var i = 0; i < routePattern.length; i++) {
      final nextDirection = routePattern[i] & 0xF;

      var directionIndex = nextDirection == _maskEast ? 3 : nextDirection;
      directionIndex += quad;
      if (directionIndex > 4) directionIndex -= 4;

      final direction = _dirVectors[directionIndex - 1];

      currentOrientation = (directionIndex % 2 > 0) ? 0 : 1;
      if (currentOrientation != lastOrientation) {
        currentIndex++;
        wayPoints[currentIndex][0] = wayPoints[currentIndex - 1][0];
        wayPoints[currentIndex][1] = wayPoints[currentIndex - 1][1];
      }

      final tar = (routePattern[i] & _targetMask) > 0;
      final sou = (routePattern[i] & _sourceMask) > 0;
      var side = (routePattern[i] & _sideMask) >> 5;
      side = side << quad;
      if (side > 0xF) side = side >> 4;

      final center = (routePattern[i] & _centerMask) > 0;

      if ((sou || tar) && side < 9) {
        var limit = 0.0;
        final souTar = sou ? 0 : 1;

        if (center && currentOrientation == 0) {
          limit = geo[souTar][0] + constraint[souTar][0] * geo[souTar][2];
        } else if (center) {
          limit = geo[souTar][1] + constraint[souTar][1] * geo[souTar][3];
        } else {
          limit = limits[souTar][side];
        }

        if (currentOrientation == 0) {
          final lastX = wayPoints[currentIndex][0];
          final deltaX = (limit - lastX) * direction[0];
          if (deltaX > 0) {
            wayPoints[currentIndex][0] += direction[0] * deltaX;
          }
        } else {
          final lastY = wayPoints[currentIndex][1];
          final deltaY = (limit - lastY) * direction[1];
          if (deltaY > 0) {
            wayPoints[currentIndex][1] += direction[1] * deltaY;
          }
        }
      } else if (center) {
        wayPoints[currentIndex][0] +=
            direction[0] * (vertexSeperations[directionIndex] / 2).abs();
        wayPoints[currentIndex][1] +=
            direction[1] * (vertexSeperations[directionIndex] / 2).abs();
      }

      if (currentIndex > 0 &&
          wayPoints[currentIndex][currentOrientation] ==
              wayPoints[currentIndex - 1][currentOrientation]) {
        currentIndex--;
      } else {
        lastOrientation = currentOrientation;
      }
    }

    // 构建结果：起点 + waypoints + 终点
    result.add(p0);

    for (var i = 0; i <= currentIndex; i++) {
      if (i == currentIndex) {
        final targetOrientation =
            (dir[1] & (_maskEast | _maskWest)) > 0 ? 0 : 1;
        final sameOrient = targetOrientation == initialOrientation ? 0 : 1;

        if (sameOrient != (currentIndex + 1) % 2) {
          break;
        }
      }

      result.add(Offset(wayPoints[i][0], wayPoints[i][1]));
    }

    result.add(pe);

    // 后处理：去重 + 正交化 + 移除形状内部点
    final deduped = _dedupe(result);
    final cleaned = _removeInternalPoints(deduped, source, target);
    return _ensureOrthogonal(cleaned);
  }

  /// 反转端口约束位掩码（mxUtils.reversePortConstraints）。
  /// north|east 变为 south|west。
  static int _reversePortConstraints(int constraint) {
    var result = (constraint & _maskWest) << 3;
    result |= (constraint & _maskNorth) << 1;
    result |= (constraint & _maskSouth) >> 1;
    result |= (constraint & _maskEast) >> 3;
    return result;
  }

  // ---------------------------------------------------------------------------
  // 后处理
  // ---------------------------------------------------------------------------

  /// 去重连续相同/近乎相同的点（mxGraph: 相邻坐标完全相同删除）。
  static List<Offset> _dedupe(List<Offset> points) {
    if (points.length <= 1) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - result.last).distance > 0.5) {
        result.add(points[i]);
      }
    }
    return result;
  }

  /// 移除落在 source/target 内部的冗余中间点。
  static List<Offset> _removeInternalPoints(
    List<Offset> points,
    Rect sourceBounds,
    Rect targetBounds,
  ) {
    if (points.length <= 2) return points;

    final result = <Offset>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final pt = points[i];
      final inSource = sourceBounds.deflate(0.5).contains(pt);
      final inTarget = targetBounds.deflate(0.5).contains(pt);
      if (!inSource && !inTarget) {
        result.add(pt);
      }
    }
    result.add(points.last);
    return result;
  }

  /// 确保路径是正交的（消除微小的非正交偏移），并去除共线中间点。
  /// 对真正的对角线段插入 L 形拐点，保证全程水平/垂直。
  static List<Offset> _ensureOrthogonal(List<Offset> points) {
    if (points.length <= 1) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      final prev = result.last;
      final curr = points[i];
      final ddx = (curr.dx - prev.dx).abs();
      final ddy = (curr.dy - prev.dy).abs();

      if (ddx < 1.0 && ddy >= 1.0) {
        // 近似垂直 → 锁定 x
        result.add(Offset(prev.dx, curr.dy));
      } else if (ddy < 1.0 && ddx >= 1.0) {
        // 近似水平 → 锁定 y
        result.add(Offset(curr.dx, prev.dy));
      } else if (ddx < 1.0 && ddy < 1.0) {
        // 几乎重合，跳过
        continue;
      } else {
        // 真正的对角线段：插入 L 形拐点（先水平后垂直）
        result.add(Offset(curr.dx, prev.dy));
        result.add(curr);
      }
    }
    return _removeCollinear(result);
  }

  /// 去除共线的中间点。
  static List<Offset> _removeCollinear(List<Offset> points) {
    if (points.length <= 2) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final a = result.last;
      final b = points[i];
      final c = points[i + 1];
      final sameX = (a.dx - b.dx).abs() < 0.5 && (b.dx - c.dx).abs() < 0.5;
      final sameY = (a.dy - b.dy).abs() < 0.5 && (b.dy - c.dy).abs() < 0.5;
      if (!sameX && !sameY) {
        result.add(b);
      }
    }
    result.add(points.last);
    return result;
  }

  // ---------------------------------------------------------------------------
  // 简单回退（无 bounds 或距离过近时）
  // ---------------------------------------------------------------------------

  static List<Offset> _simpleFallback(Offset start, Offset end) {
    if ((start.dx - end.dx).abs() < 0.5 || (start.dy - end.dy).abs() < 0.5) {
      return [start, end];
    }
    return [start, Offset(end.dx, start.dy), end];
  }
}
