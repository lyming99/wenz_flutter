import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class OrthogonalRouter {
  const OrthogonalRouter._();

  static const int _maxObstacles = 32;
  static const double _searchPadding = 240;

  static List<Offset> route({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    Iterable<Rect> obstacles = const <Rect>[],
    double margin = 16,
  }) {
    final source = sourceBounds?.inflate(margin);
    final target = targetBounds?.inflate(margin);
    final inflatedObstacles = _relevantObstacles(start, end, obstacles, margin);
    final blocked = [
      ...inflatedObstacles,
      if (source != null) source,
      if (target != null) target,
    ];

    final sourcePorts = _portsForEndpoint(
      point: start,
      bounds: source,
      toward: end,
    );
    final targetPorts = _portsForEndpoint(
      point: end,
      bounds: target,
      toward: start,
    );

    var best = <Offset>[];
    var bestScore = double.infinity;
    for (final sourcePort in sourcePorts) {
      for (final targetPort in targetPorts) {
        final routed = _routeBetweenPorts(
          start: sourcePort,
          end: targetPort,
          source: source,
          target: target,
          obstacles: inflatedObstacles,
          blocked: blocked,
        );
        final candidate = _dedupe(
          [
            start,
            if ((sourcePort - start).distance > 0.0001) sourcePort,
            ...routed.skip(1),
            if ((targetPort - end).distance > 0.0001) end,
          ],
          keepPoints: {sourcePort, targetPort},
        );
        final score = _score(candidate, blocked, start, end);
        if (score < bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
    }

    return best.isEmpty ? [start, end] : best;
  }

  static List<Offset> _portsForEndpoint({
    required Offset point,
    required Rect? bounds,
    required Offset toward,
  }) {
    if (bounds == null || !_containsInclusive(bounds, point)) {
      return [point];
    }

    final dy = toward.dy - point.dy;
    final dx = toward.dx - point.dx;
    final y = point.dy.clamp(bounds.top, bounds.bottom);
    final x = point.dx.clamp(bounds.left, bounds.right);
    final horizontalFirst = dx.abs() >= dy.abs();

    final horizontal = dx >= 0
        ? [Offset(bounds.right, y), Offset(bounds.left, y)]
        : [Offset(bounds.left, y), Offset(bounds.right, y)];
    final vertical = dy >= 0
        ? [Offset(x, bounds.bottom), Offset(x, bounds.top)]
        : [Offset(x, bounds.top), Offset(x, bounds.bottom)];

    return _dedupe(
      horizontalFirst
          ? [...horizontal, ...vertical]
          : [...vertical, ...horizontal],
    );
  }

  static bool _containsInclusive(Rect rect, Offset point) {
    return point.dx >= rect.left &&
        point.dx <= rect.right &&
        point.dy >= rect.top &&
        point.dy <= rect.bottom;
  }

  static List<Rect> _relevantObstacles(
    Offset start,
    Offset end,
    Iterable<Rect> obstacles,
    double margin,
  ) {
    final corridor = Rect.fromPoints(
      start,
      end,
    ).inflate(_searchPadding + margin);
    final list = [
      for (final obstacle in obstacles)
        if (!obstacle.isEmpty && obstacle.inflate(margin).overlaps(corridor))
          obstacle.inflate(margin),
    ];
    list.sort((a, b) {
      final da = distanceToSegment(a.center, start, end);
      final db = distanceToSegment(b.center, start, end);
      return da.compareTo(db);
    });
    if (list.length <= _maxObstacles) {
      return list;
    }
    return list.take(_maxObstacles).toList(growable: false);
  }

  static List<List<Offset>> _candidateRoutes({
    required Offset start,
    required Offset end,
    required Rect? source,
    required Rect? target,
    required List<Rect> obstacles,
  }) {
    final xLanes = <double>{start.dx, end.dx, (start.dx + end.dx) / 2};
    final yLanes = <double>{start.dy, end.dy, (start.dy + end.dy) / 2};

    for (final rect in [
      if (source != null) source,
      if (target != null) target,
    ]) {
      xLanes
        ..add(rect.left)
        ..add(rect.right);
      yLanes
        ..add(rect.top)
        ..add(rect.bottom);
    }

    for (final rect in obstacles) {
      if (_segmentIntersectsInterior(start, end, rect) ||
          Rect.fromPoints(start, end).inflate(80).overlaps(rect)) {
        xLanes
          ..add(rect.left)
          ..add(rect.right);
        yLanes
          ..add(rect.top)
          ..add(rect.bottom);
      }
    }

    final routes = <List<Offset>>[];
    for (final x in xLanes) {
      routes.add([start, Offset(x, start.dy), Offset(x, end.dy), end]);
    }
    for (final y in yLanes) {
      routes.add([start, Offset(start.dx, y), Offset(end.dx, y), end]);
    }

    final directionalX = end.dx >= start.dx
        ? [for (final rect in obstacles) rect.right]
        : [for (final rect in obstacles) rect.left];
    final directionalY = end.dy >= start.dy
        ? [for (final rect in obstacles) rect.bottom]
        : [for (final rect in obstacles) rect.top];

    for (final x in directionalX) {
      for (final y in yLanes) {
        routes.add([
          start,
          Offset(x, start.dy),
          Offset(x, y),
          Offset(end.dx, y),
          end,
        ]);
      }
    }
    for (final y in directionalY) {
      for (final x in xLanes) {
        routes.add([
          start,
          Offset(start.dx, y),
          Offset(x, y),
          Offset(x, end.dy),
          end,
        ]);
      }
    }

    routes.add([start, Offset(end.dx, start.dy), end]);
    routes.add([start, Offset(start.dx, end.dy), end]);
    return routes;
  }

  static List<Offset> _routeBetweenPorts({
    required Offset start,
    required Offset end,
    required Rect? source,
    required Rect? target,
    required List<Rect> obstacles,
    required List<Rect> blocked,
  }) {
    final xLanes = _lanes(start.dx, end.dx, [
      if (source != null) source,
      if (target != null) target,
      ...obstacles,
    ], horizontal: true);
    final yLanes = _lanes(start.dy, end.dy, [
      if (source != null) source,
      if (target != null) target,
      ...obstacles,
    ], horizontal: false);

    final startKey = _GridKey(start.dx, start.dy);
    final endKey = _GridKey(end.dx, end.dy);
    final open = <_RouteNode>[_RouteNode(startKey, null, 0, 0)];
    final bestCost = <_GridKey, double>{startKey: 0};
    final closed = <_GridKey>{};

    while (open.isNotEmpty) {
      open.sort((a, b) => a.priority.compareTo(b.priority));
      final node = open.removeAt(0);
      if (!closed.add(node.key)) {
        continue;
      }
      if (node.key == endKey) {
        return _dedupe(_nodePath(node));
      }

      final current = node.key.offset;
      for (final next in _neighbors(node.key, xLanes, yLanes)) {
        if (closed.contains(next)) {
          continue;
        }
        final nextPoint = next.offset;
        final segmentPenalty = _segmentPenalty(
          current,
          nextPoint,
          blocked,
          start,
          end,
        );
        if (segmentPenalty >= 100000) {
          continue;
        }
        final turnPenalty =
            node.previous == null ||
                _sameDirection(node.previous!.key, node.key, next)
            ? 0.0
            : 0.001;
        final cost =
            node.cost +
            (nextPoint - current).distance +
            segmentPenalty +
            turnPenalty;
        if (cost >= (bestCost[next] ?? double.infinity)) {
          continue;
        }
        bestCost[next] = cost;
        final heuristic = (end - nextPoint).distance;
        open.add(_RouteNode(next, node, cost, cost + heuristic));
      }
    }

    final candidates = _candidateRoutes(
      start: start,
      end: end,
      source: source,
      target: target,
      obstacles: obstacles,
    );
    candidates.sort((a, b) {
      final aScore = _score(a, blocked, start, end);
      final bScore = _score(b, blocked, start, end);
      return aScore.compareTo(bScore);
    });
    return candidates.isEmpty ? [start, end] : _dedupe(candidates.first);
  }

  static List<double> _lanes(
    double start,
    double end,
    List<Rect> rects, {
    required bool horizontal,
  }) {
    final values = <double>{start, end, (start + end) / 2};
    for (final rect in rects) {
      if (horizontal) {
        values
          ..add(rect.left)
          ..add(rect.right);
      } else {
        values
          ..add(rect.top)
          ..add(rect.bottom);
      }
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  static Iterable<_GridKey> _neighbors(
    _GridKey key,
    List<double> xLanes,
    List<double> yLanes,
  ) sync* {
    final xIndex = xLanes.indexWhere((x) => (x - key.x).abs() < 0.0001);
    final yIndex = yLanes.indexWhere((y) => (y - key.y).abs() < 0.0001);
    if (xIndex > 0) {
      yield _GridKey(xLanes[xIndex - 1], key.y);
    }
    if (xIndex >= 0 && xIndex < xLanes.length - 1) {
      yield _GridKey(xLanes[xIndex + 1], key.y);
    }
    if (yIndex > 0) {
      yield _GridKey(key.x, yLanes[yIndex - 1]);
    }
    if (yIndex >= 0 && yIndex < yLanes.length - 1) {
      yield _GridKey(key.x, yLanes[yIndex + 1]);
    }
  }

  static bool _sameDirection(_GridKey a, _GridKey b, _GridKey c) {
    return _sameLine(a.offset, b.offset, c.offset);
  }

  static bool _sameLine(Offset a, Offset b, Offset c) {
    return ((a.dx - b.dx).abs() < 0.0001 && (b.dx - c.dx).abs() < 0.0001) ||
        ((a.dy - b.dy).abs() < 0.0001 && (b.dy - c.dy).abs() < 0.0001);
  }

  static List<Offset> _nodePath(_RouteNode node) {
    final points = <Offset>[];
    _RouteNode? cursor = node;
    while (cursor != null) {
      points.add(cursor.key.offset);
      cursor = cursor.previous;
    }
    return points.reversed.toList(growable: false);
  }

  static double _segmentPenalty(
    Offset a,
    Offset b,
    List<Rect> blocked,
    Offset start,
    Offset end,
  ) {
    var penalty = 0.0;
    for (final rect in blocked) {
      if (_blockedSegment(a, b, rect, start, end)) {
        return 100000;
      }
      if (_segmentTouchesRect(a, b, rect)) {
        penalty += 0.001;
      }
    }
    return penalty;
  }

  static double _score(
    List<Offset> points,
    List<Rect> blocked,
    Offset start,
    Offset end,
  ) {
    final path = _dedupe(points);
    var score = _length(path);
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      if (i > 0 && !_sameLine(path[i - 1], a, b)) {
        score += 0.001;
      }
      for (final rect in blocked) {
        if (_blockedSegment(a, b, rect, start, end)) {
          score += 100000;
        } else if (_segmentTouchesRect(a, b, rect)) {
          score += 0.0001;
        }
      }
    }
    return score;
  }

  static bool _pathIntersects(
    List<Offset> points,
    List<Rect> blocked,
    Offset start,
    Offset end,
  ) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      for (final rect in blocked) {
        if (_blockedSegment(a, b, rect, start, end)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _blockedSegment(
    Offset a,
    Offset b,
    Rect rect,
    Offset start,
    Offset end,
  ) {
    if (!_segmentIntersectsInterior(a, b, rect)) {
      return false;
    }
    final startInside = rect.contains(start);
    final endInside = rect.contains(end);
    return !((a == start && startInside) || (b == end && endInside));
  }

  static double _length(List<Offset> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  static bool segmentIntersectsRectInterior(Offset a, Offset b, Rect rect) {
    return _segmentIntersectsInterior(a, b, rect);
  }

  static bool _segmentIntersectsInterior(Offset a, Offset b, Rect rect) {
    final inner = rect.deflate(0.001);
    if (inner.isEmpty) {
      return false;
    }
    if ((a.dx - b.dx).abs() < 0.0001) {
      final x = a.dx;
      if (x <= inner.left || x >= inner.right) {
        return false;
      }
      final top = math.min(a.dy, b.dy);
      final bottom = math.max(a.dy, b.dy);
      return bottom > inner.top && top < inner.bottom;
    }
    if ((a.dy - b.dy).abs() < 0.0001) {
      final y = a.dy;
      if (y <= inner.top || y >= inner.bottom) {
        return false;
      }
      final left = math.min(a.dx, b.dx);
      final right = math.max(a.dx, b.dx);
      return right > inner.left && left < inner.right;
    }
    return false;
  }

  static bool _segmentTouchesRect(Offset a, Offset b, Rect rect) {
    if ((a.dx - b.dx).abs() < 0.0001) {
      final x = a.dx;
      final top = math.min(a.dy, b.dy);
      final bottom = math.max(a.dy, b.dy);
      return x >= rect.left &&
          x <= rect.right &&
          bottom >= rect.top &&
          top <= rect.bottom;
    }
    if ((a.dy - b.dy).abs() < 0.0001) {
      final y = a.dy;
      final left = math.min(a.dx, b.dx);
      final right = math.max(a.dx, b.dx);
      return y >= rect.top &&
          y <= rect.bottom &&
          right >= rect.left &&
          left <= rect.right;
    }
    return false;
  }

  static double distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) {
      return (point - a).distance;
    }
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    final projection = a + ab * t;
    return (point - projection).distance;
  }

  static List<Offset> _dedupe(
    List<Offset> points, {
    Set<Offset> keepPoints = const <Offset>{},
  }) {
    final result = <Offset>[];
    for (final point in points) {
      if (result.isEmpty || (result.last - point).distance > 0.0001) {
        result.add(point);
      }
    }
    if (result.length <= 2) {
      return result;
    }
    final simplified = <Offset>[];
    for (final point in result) {
      simplified.add(point);
      while (simplified.length >= 3) {
        final a = simplified[simplified.length - 3];
        final b = simplified[simplified.length - 2];
        final c = simplified[simplified.length - 1];
        final sameX =
            (a.dx - b.dx).abs() < 0.0001 && (b.dx - c.dx).abs() < 0.0001;
        final sameY =
            (a.dy - b.dy).abs() < 0.0001 && (b.dy - c.dy).abs() < 0.0001;
        final keepPoint = keepPoints.any(
          (point) => (point - b).distance <= 0.0001,
        );
        if ((!sameX && !sameY) || keepPoint) {
          break;
        }
        simplified.removeAt(simplified.length - 2);
      }
    }
    return simplified;
  }
}

class _GridKey {
  const _GridKey(this.x, this.y);

  final double x;
  final double y;

  Offset get offset => Offset(x, y);

  @override
  bool operator ==(Object other) {
    return other is _GridKey &&
        (x - other.x).abs() < 0.0001 &&
        (y - other.y).abs() < 0.0001;
  }

  @override
  int get hashCode => Object.hash(x.toStringAsFixed(3), y.toStringAsFixed(3));
}

class _RouteNode {
  const _RouteNode(this.key, this.previous, this.cost, this.priority);

  final _GridKey key;
  final _RouteNode? previous;
  final double cost;
  final double priority;
}
