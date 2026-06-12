import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 提供形状边界周长计算——计算连线从图形边界何处穿出/穿入。
///
/// 设计灵感来自 draw.io (mxGraph) 的 [mxPerimeter] 系统。
///
/// 每个 perimeter 函数签名为：
///   `Offset? perimeter(Rect bounds, Offset next, {bool orthogonal})`
///
/// - [bounds]：图形的绝对包围盒
/// - [next]：边线上"下一个"参考点（通常是第一个/最后一个拐点）
/// - [orthogonal]：是否返回正交投影（而非直线交点）
///
/// 返回值：边界上的精确接触点，或 null。

class WenzPerimeter {
  const WenzPerimeter._();

  // ---------------------------------------------------------------------------
  // Rectangle perimeter
  // ---------------------------------------------------------------------------

  /// 矩形周长——返回 [next] 与矩形中心连线与矩形边界的交点。
  ///
  /// 若 [orthogonal] 为 true，则返回 next 在矩形边界上的正交投影。
  static Offset rectanglePerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
  }) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final dx = next.dx - cx;
    final dy = next.dy - cy;
    final alpha = math.atan2(dy, dx);
    final pi = math.pi;
    final t = math.atan2(bounds.height, bounds.width);

    double px, py;

    if (alpha < -pi + t || alpha > pi - t) {
      // 左边
      px = bounds.left;
      py = cy - bounds.width * math.tan(alpha) / 2;
    } else if (alpha < -t) {
      // 上边
      py = bounds.top;
      px = cx - bounds.height * math.tan(pi / 2 - alpha) / 2;
    } else if (alpha < t) {
      // 右边
      px = bounds.right;
      py = cy + bounds.width * math.tan(alpha) / 2;
    } else {
      // 下边
      py = bounds.bottom;
      px = cx + bounds.height * math.tan(pi / 2 - alpha) / 2;
    }

    if (orthogonal) {
      if (next.dx >= bounds.left && next.dx <= bounds.right) {
        px = next.dx;
      } else if (next.dy >= bounds.top && next.dy <= bounds.bottom) {
        py = next.dy;
      }
      if (next.dx < bounds.left) {
        px = bounds.left;
      } else if (next.dx > bounds.right) {
        px = bounds.right;
      }
      if (next.dy < bounds.top) {
        py = bounds.top;
      } else if (next.dy > bounds.bottom) {
        py = bounds.bottom;
      }
    }

    return Offset(px, py);
  }

  // ---------------------------------------------------------------------------
  // Ellipse perimeter
  // ---------------------------------------------------------------------------

  /// 椭圆周长——返回 [next] 与椭圆中心连线与椭圆边界的交点。
  static Offset ellipsePerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
  }) {
    final a = bounds.width / 2;
    final b = bounds.height / 2;
    final cx = bounds.left + a;
    final cy = bounds.top + b;
    final px = next.dx;
    final py = next.dy;

    final dx = px - cx;
    final dy = py - cy;

    if (dx == 0 && dy != 0) {
      return Offset(cx, cy + b * dy / dy.abs());
    }
    if (dx == 0 && dy == 0) {
      return Offset(px, py);
    }

    if (orthogonal) {
      if (py >= bounds.top && py <= bounds.bottom) {
        final ty = py - cy;
        final tx = math.sqrt(a * a * (1 - (ty * ty) / (b * b)));
        return Offset(px <= bounds.left ? cx - tx : cx + tx, py);
      }
      if (px >= bounds.left && px <= bounds.right) {
        final tx = px - cx;
        final ty = math.sqrt(b * b * (1 - (tx * tx) / (a * a)));
        return Offset(px, py <= bounds.top ? cy - ty : cy + ty);
      }
    }

    // 直线与椭圆交点
    final d = dy / dx;
    final h = cy - d * cx;
    final e = a * a * d * d + b * b;
    final f = -2 * cx * e;
    final g = a * a * d * d * cx * cx + b * b * cx * cx - a * a * b * b;
    final det = math.sqrt(f * f - 4 * e * g);

    final xout1 = (-f + det) / (2 * e);
    final xout2 = (-f - det) / (2 * e);
    final yout1 = d * xout1 + h;
    final yout2 = d * xout2 + h;

    final dist1 = (Offset(xout1, yout1) - next).distance;
    final dist2 = (Offset(xout2, yout2) - next).distance;

    return dist1 < dist2 ? Offset(xout1, yout1) : Offset(xout2, yout2);
  }

  // ---------------------------------------------------------------------------
  // Diamond (rhombus) perimeter
  // ---------------------------------------------------------------------------

  /// 菱形周长。
  static Offset diamondPerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
  }) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final px = next.dx;
    final py = next.dy;

    // 特殊情况：与角对齐
    if ((cx - px).abs() < 0.0001) {
      return Offset(cx, cy > py ? bounds.top : bounds.bottom);
    }
    if ((cy - py).abs() < 0.0001) {
      return Offset(cx > px ? bounds.left : bounds.right, cy);
    }

    double tx = cx;
    double ty = cy;
    if (orthogonal) {
      if (px >= bounds.left && px <= bounds.right)
        tx = px;
      else if (py >= bounds.top && py <= bounds.bottom)
        ty = py;
    }

    // 四象限判断
    if (px < cx) {
      if (py < cy) {
        return _lineIntersection(
          px,
          py,
          tx,
          ty,
          cx,
          bounds.top,
          bounds.left,
          cy,
        );
      } else {
        return _lineIntersection(
          px,
          py,
          tx,
          ty,
          cx,
          bounds.bottom,
          bounds.left,
          cy,
        );
      }
    } else if (py < cy) {
      return _lineIntersection(
        px,
        py,
        tx,
        ty,
        cx,
        bounds.top,
        bounds.right,
        cy,
      );
    } else {
      return _lineIntersection(
        px,
        py,
        tx,
        ty,
        cx,
        bounds.bottom,
        bounds.right,
        cy,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Triangle perimeter
  // ---------------------------------------------------------------------------

  /// 三角形周长。
  ///
  /// [direction] 支持 'north', 'south', 'east', 'west'，默认 'east'。
  static Offset trianglePerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
    String direction = 'east',
  }) {
    final x = bounds.left;
    final y = bounds.top;
    final w = bounds.width;
    final h = bounds.height;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;

    Offset start, corner, end;
    switch (direction) {
      case 'north':
        start = Offset(x + w, y + h);
        corner = Offset(cx, y);
        end = Offset(x, y + h);
        break;
      case 'south':
        start = Offset(x, y);
        corner = Offset(cx, y + h);
        end = Offset(x + w, y);
        break;
      case 'west':
        start = Offset(x + w, y);
        corner = Offset(x, cy);
        end = Offset(x + w, y + h);
        break;
      default: // east
        start = Offset(x, y);
        corner = Offset(x + w, cy);
        end = Offset(x, y + h);
    }

    final vertical = direction == 'north' || direction == 'south';
    final dx = next.dx - cx;
    final dy = next.dy - cy;
    final alpha = vertical ? math.atan2(dx, dy) : math.atan2(dy, dx);
    final t = vertical ? math.atan2(w, h) : math.atan2(h, w);

    final bool base;
    if (direction == 'north' || direction == 'west') {
      base = alpha > -t && alpha < t;
    } else {
      base = alpha < -math.pi + t || alpha > math.pi - t;
    }

    if (base) {
      if (orthogonal) {
        if (vertical && next.dx >= start.dx && next.dx <= end.dx) {
          return Offset(next.dx, start.dy);
        }
        if (!vertical && next.dy >= start.dy && next.dy <= end.dy) {
          return Offset(start.dx, next.dy);
        }
      }
      // 底边上的点
      switch (direction) {
        case 'north':
          return Offset(cx + h * math.tan(alpha) / 2, y + h);
        case 'south':
          return Offset(cx - h * math.tan(alpha) / 2, y);
        case 'west':
          return Offset(x + w, cy + w * math.tan(alpha) / 2);
        default:
          return Offset(x, cy - w * math.tan(alpha) / 2);
      }
    }

    // 侧边
    if (orthogonal) {
      Offset pt = Offset(cx, cy);
      if (next.dy >= y && next.dy <= y + h) {
        pt = Offset(vertical ? cx : (direction == 'west' ? x + w : x), next.dy);
      } else if (next.dx >= x && next.dx <= x + w) {
        pt = Offset(
          next.dx,
          !vertical ? cy : (direction == 'north' ? y + h : y),
        );
      }
      final dxx = next.dx - pt.dx;
      final dyy = next.dy - pt.dy;
      if ((vertical && dxx <= 0) || (!vertical && dyy <= 0)) {
        return _lineIntersection(
          next.dx,
          next.dy,
          pt.dx,
          pt.dy,
          start.dx,
          start.dy,
          corner.dx,
          corner.dy,
        );
      }
      return _lineIntersection(
        next.dx,
        next.dy,
        pt.dx,
        pt.dy,
        corner.dx,
        corner.dy,
        end.dx,
        end.dy,
      );
    }

    if ((vertical && next.dx <= cx) || (!vertical && next.dy <= cy)) {
      return _lineIntersection(
        next.dx,
        next.dy,
        cx,
        cy,
        start.dx,
        start.dy,
        corner.dx,
        corner.dy,
      );
    }
    return _lineIntersection(
      next.dx,
      next.dy,
      cx,
      cy,
      corner.dx,
      corner.dy,
      end.dx,
      end.dy,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// 两条线段 (x1,y1)-(x2,y2) 与 (x3,y3)-(x4,y4) 的交点。
  static Offset _lineIntersection(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double x4,
    double y4,
  ) {
    final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 0.0000001) {
      return Offset((x1 + x2) / 2, (y1 + y2) / 2);
    }
    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    return Offset(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
  }

  // ---------------------------------------------------------------------------
  // Hexagon perimeter
  // ---------------------------------------------------------------------------

  /// 六边形周长。
  ///
  /// 六边形的六个顶点（环绕矩形）：
  /// - 左上、右上、右中、右下、左下、左中
  ///
  /// 使用线段交点法：先判断 [next] 在哪个区域，再与对应边界线段求交点。
  static Offset hexagonPerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
  }) {
    final x = bounds.left;
    final y = bounds.top;
    final w = bounds.width;
    final h = bounds.height;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;

    // 六边形顶点（顺时针，从上左开始）
    // 使用 1/4 宽度的偏移量（标准六边形比例）
    final offset = w * 0.25;
    final p0 = Offset(x + offset, y); // 顶左
    final p1 = Offset(x + w - offset, y); // 顶右
    final p2 = Offset(x + w, cy); // 右中
    final p3 = Offset(x + w - offset, y + h); // 底右
    final p4 = Offset(x + offset, y + h); // 底左
    final p5 = Offset(x, cy); // 左中

    final px = next.dx;
    final py = next.dy;

    if (orthogonal) {
      // 正交模式：投影到最近的边
      if (py >= y && py <= y + h) {
        // 在垂直范围内，投影到左或右
        if (px <= cx) {
          // 左半部分
          if (py <= cy) {
            // 左上区域：投影到线段 p0-p5
            final t = (py - y) / (cy - y);
            return Offset(x + offset * (1 - t), py);
          } else {
            // 左下区域：投影到线段 p5-p4
            final t = (py - cy) / (y + h - cy);
            return Offset(x + offset * (1 - t), py);
          }
        } else {
          // 右半部分
          if (py <= cy) {
            // 右上区域：投影到线段 p1-p2
            final t = (py - y) / (cy - y);
            return Offset(x + w - offset + offset * t, py);
          } else {
            // 右下区域：投影到线段 p2-p3
            final t = (py - cy) / (y + h - cy);
            return Offset(x + w - offset + offset * t, py);
          }
        }
      } else if (px >= x && px <= x + w) {
        // 在水平范围内，投影到顶或底
        return Offset(
          px.clamp(x + offset, x + w - offset),
          py <= cy ? y : y + h,
        );
      }
    }

    // 非正交模式：判断 next 在哪个区域
    // 划分为 6 个三角形区域，每个对应一条边
    final dx = px - cx;
    final dy = py - cy;

    // 先判断相对于六边形中心的象限
    if (dy <= 0) {
      // 上半部分
      if (dx.abs() <= offset && py <= y) {
        // 在顶部平坦区域上方
        return _lineIntersection(px, py, cx, cy, p0.dx, p0.dy, p1.dx, p1.dy);
      }
      if (dx >= 0) {
        // 右上 → 边 p1-p2
        return _lineIntersection(px, py, cx, cy, p1.dx, p1.dy, p2.dx, p2.dy);
      } else {
        // 左上 → 边 p0-p5
        return _lineIntersection(px, py, cx, cy, p0.dx, p0.dy, p5.dx, p5.dy);
      }
    } else {
      // 下半部分
      if (dx.abs() <= offset && py >= y + h) {
        // 在底部平坦区域下方
        return _lineIntersection(px, py, cx, cy, p3.dx, p3.dy, p4.dx, p4.dy);
      }
      if (dx >= 0) {
        // 右下 → 边 p2-p3
        return _lineIntersection(px, py, cx, cy, p2.dx, p2.dy, p3.dx, p3.dy);
      } else {
        // 左下 → 边 p4-p5
        return _lineIntersection(px, py, cx, cy, p4.dx, p4.dy, p5.dx, p5.dy);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Cylinder perimeter
  // ---------------------------------------------------------------------------

  /// 圆柱周长。
  ///
  /// 连接点沿外轮廓吸附，左右侧按竖边处理，顶部/底部按椭圆帽近似。
  static Offset cylinderPerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
  }) {
    final cap = math.min(bounds.height * 0.18, bounds.width / 3);
    final center = bounds.center;
    if (next.dy < bounds.top + cap) {
      return ellipsePerimeter(
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, cap * 2),
        next,
        orthogonal: orthogonal,
      );
    }
    if (next.dy > bounds.bottom - cap) {
      return ellipsePerimeter(
        Rect.fromLTWH(
          bounds.left,
          bounds.bottom - cap * 2,
          bounds.width,
          cap * 2,
        ),
        next,
        orthogonal: orthogonal,
      );
    }
    return next.dx < center.dx
        ? Offset(
            bounds.left,
            next.dy.clamp(bounds.top + cap, bounds.bottom - cap),
          )
        : Offset(
            bounds.right,
            next.dy.clamp(bounds.top + cap, bounds.bottom - cap),
          );
  }

  /// 根据形状类型选择合适的 perimeter 函数。
  ///
  /// [shapeType] 可选值：'rectangle', 'ellipse', 'diamond', 'triangle', 'hexagon',
  /// 'cylinder', 'doubleEllipse'。默认使用 rectangle。
  static Offset computePerimeter(
    Rect bounds,
    Offset next, {
    bool orthogonal = false,
    String shapeType = 'rectangle',
    String direction = 'east',
  }) {
    return switch (shapeType) {
      'ellipse' ||
      'circle' ||
      'doubleEllipse' => ellipsePerimeter(bounds, next, orthogonal: orthogonal),
      'diamond' ||
      'rhombus' => diamondPerimeter(bounds, next, orthogonal: orthogonal),
      'triangle' => trianglePerimeter(
        bounds,
        next,
        orthogonal: orthogonal,
        direction: direction,
      ),
      'hexagon' => hexagonPerimeter(bounds, next, orthogonal: orthogonal),
      'cylinder' ||
      'cylinder3' => cylinderPerimeter(bounds, next, orthogonal: orthogonal),
      _ => rectanglePerimeter(bounds, next, orthogonal: orthogonal),
    };
  }

  /// 根据给定的 [next] 点，判断其相对 [bounds] 最近的边。
  ///
  /// 返回 (side, intersectionPoint)，side 为 'left', 'right', 'top', 'bottom'。
  static (String side, Offset point) nearestSide(Rect bounds, Offset next) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final dx = next.dx - cx;
    final dy = next.dy - cy;

    if (dx.abs() < 0.0001 && dy.abs() < 0.0001) {
      return ('center', bounds.center);
    }

    // 使用 atan2 判断方向（与 rectanglePerimeter 一致）
    final alpha = math.atan2(dy, dx);
    final pi = math.pi;
    final t = math.atan2(bounds.height, bounds.width);

    if (alpha < -pi + t || alpha > pi - t) {
      final y = cy - bounds.width * math.tan(alpha) / 2;
      return ('left', Offset(bounds.left, y.clamp(bounds.top, bounds.bottom)));
    } else if (alpha < -t) {
      final x = cx - bounds.height * math.tan(pi / 2 - alpha) / 2;
      return ('top', Offset(x.clamp(bounds.left, bounds.right), bounds.top));
    } else if (alpha < t) {
      final y = cy + bounds.width * math.tan(alpha) / 2;
      return (
        'right',
        Offset(bounds.right, y.clamp(bounds.top, bounds.bottom)),
      );
    } else {
      final x = cx + bounds.height * math.tan(pi / 2 - alpha) / 2;
      return (
        'bottom',
        Offset(x.clamp(bounds.left, bounds.right), bounds.bottom),
      );
    }
  }
}
