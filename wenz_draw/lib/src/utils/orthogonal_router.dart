import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class OrthogonalRouteEngine {
  const OrthogonalRouteEngine._();

  static const int _defaultMaxObstacles = 32;
  static const int _defaultMaxLanesPerAxis = 18;
  static const double _defaultSearchPadding = 240;
  static const double _defaultTurnPenalty = 24;
  static const double _defaultNodeTouchPenalty = 8;

  static List<Offset> route({
    required Offset start,
    required Offset end,
    Rect? sourceBounds,
    Rect? targetBounds,
    Iterable<Rect> obstacles = const <Rect>[],
    double margin = 16,
    Offset? preferredStartDirection,
    Offset? preferredEndDirection,
    Offset? preferredStartPoint,
    Offset? preferredEndPoint,
    double searchPadding = _defaultSearchPadding,
    int maxObstacles = _defaultMaxObstacles,
    int maxLanesPerAxis = _defaultMaxLanesPerAxis,
    double turnPenalty = _defaultTurnPenalty,
    double nodeTouchPenalty = _defaultNodeTouchPenalty,
    List<Offset>? previousRoute,
    double stabilityPenalty = 0,
  }) {
    final source = sourceBounds?.inflate(margin);
    final target = targetBounds?.inflate(margin);
    final inflatedObstacles = _relevantObstacles(
      start,
      end,
      obstacles,
      margin,
      searchPadding: searchPadding,
      maxObstacles: maxObstacles,
    );
    final blocked = [
      ...inflatedObstacles,
      if (source != null) source,
      if (target != null) target,
    ];

    final sourcePorts = _portsForEndpoint(
      point: start,
      bounds: source,
      toward: end,
      preferredDirection: preferredStartDirection,
      preferredPoint: preferredStartPoint,
    );
    final targetPorts = _portsForEndpoint(
      point: end,
      bounds: target,
      toward: start,
      preferredDirection: preferredEndDirection,
      preferredPoint: preferredEndPoint,
    );

    var best = <Offset>[];
    var bestScore = double.infinity;
    final drawioCandidate = _drawioOrthogonalRoute(
      start: start,
      end: end,
      source: source,
      target: target,
      sourceDirection: preferredStartDirection,
      targetDirection: preferredEndDirection,
      buffer: margin,
    );
    if (drawioCandidate != null) {
      final score = _score(
        drawioCandidate,
        blocked,
        start,
        end,
        preferredStartDirection: preferredStartDirection,
        preferredEndDirection: preferredEndDirection,
        preferredStartPoint: preferredStartPoint,
        preferredEndPoint: preferredEndPoint,
        previousRoute: previousRoute,
        stabilityPenalty: stabilityPenalty,
        turnPenalty: turnPenalty,
        nodeTouchPenalty: nodeTouchPenalty,
      );
      if (score < 100000 &&
          _sameLockedDirection(
            preferredStartDirection,
            preferredEndDirection,
          )) {
        return drawioCandidate;
      }
      if (score < 100000 && _sharesPreviousRoute(drawioCandidate, previousRoute)) {
        return drawioCandidate;
      }
      if (score < 100000) {
        best = drawioCandidate;
        bestScore = score;
      }
    }
    for (final sourcePort in sourcePorts) {
      for (final targetPort in targetPorts) {
        final sourceLead = _leadPoint(
          sourcePort,
          start,
          preferredStartDirection,
          margin,
        );
        final targetLead = _leadPoint(
          targetPort,
          end,
          preferredEndDirection,
          margin,
        );
        final routed = _routeBetweenPorts(
          start: sourceLead,
          end: targetLead,
          source: source,
          target: target,
          obstacles: inflatedObstacles,
          blocked: blocked,
          searchPadding: searchPadding,
          maxLanesPerAxis: maxLanesPerAxis,
          turnPenalty: turnPenalty,
          nodeTouchPenalty: nodeTouchPenalty,
          previousRoute: previousRoute,
        );
        final candidate = _dedupe(
          [
            start,
            if ((sourcePort - start).distance > 0.0001) sourcePort,
            if ((sourceLead - sourcePort).distance > 0.0001) sourceLead,
            ...routed.skip(1),
            if ((targetLead - targetPort).distance > 0.0001) targetLead,
            if ((targetPort - end).distance > 0.0001) end,
          ],
          keepPoints: {sourcePort, targetPort, sourceLead, targetLead},
        );
        final score = _score(
          candidate,
          blocked,
          start,
          end,
          preferredStartDirection: preferredStartDirection,
          preferredEndDirection: preferredEndDirection,
          preferredStartPoint: preferredStartPoint,
          preferredEndPoint: preferredEndPoint,
          previousRoute: previousRoute,
          stabilityPenalty: stabilityPenalty,
          turnPenalty: turnPenalty,
          nodeTouchPenalty: nodeTouchPenalty,
        );
        if (score < bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
    }

    return best.isEmpty ? [start, end] : best;
  }

  static bool _sharesPreviousRoute(
    List<Offset> candidate,
    List<Offset>? previousRoute,
  ) {
    if (previousRoute == null || previousRoute.length < 2 || candidate.length < 2) {
      return false;
    }
    for (var i = 0; i < candidate.length - 1; i++) {
      for (var j = 0; j < previousRoute.length - 1; j++) {
        if (_collinearOverlapLength(
              candidate[i],
              candidate[i + 1],
              previousRoute[j],
              previousRoute[j + 1],
            ) >
            0.0001) {
          return true;
        }
      }
    }
    return false;
  }

  static double _collinearOverlapLength(Offset a, Offset b, Offset c, Offset d) {
    final aVertical = (a.dx - b.dx).abs() < 0.0001;
    final cVertical = (c.dx - d.dx).abs() < 0.0001;
    final aHorizontal = (a.dy - b.dy).abs() < 0.0001;
    final cHorizontal = (c.dy - d.dy).abs() < 0.0001;
    if (aVertical && cVertical && (a.dx - c.dx).abs() < 0.0001) {
      final minA = math.min(a.dy, b.dy);
      final maxA = math.max(a.dy, b.dy);
      final minC = math.min(c.dy, d.dy);
      final maxC = math.max(c.dy, d.dy);
      return math.max(0, math.min(maxA, maxC) - math.max(minA, minC));
    }
    if (aHorizontal && cHorizontal && (a.dy - c.dy).abs() < 0.0001) {
      final minA = math.min(a.dx, b.dx);
      final maxA = math.max(a.dx, b.dx);
      final minC = math.min(c.dx, d.dx);
      final maxC = math.max(c.dx, d.dx);
      return math.max(0, math.min(maxA, maxC) - math.max(minA, minC));
    }
    return 0;
  }

  static bool _sameLockedDirection(Offset? source, Offset? target) {
    final sourceMask = _directionMaskFor(source);
    final targetMask = _directionMaskFor(target);
    return sourceMask != null && sourceMask == targetMask;
  }

  static List<Offset>? _drawioOrthogonalRoute({
    required Offset start,
    required Offset end,
    required Rect? source,
    required Rect? target,
    Offset? sourceDirection,
    Offset? targetDirection,
    required double buffer,
  }) {
    if (source == null && target == null) {
      return null;
    }
    final sourceDir =
        _directionMaskFor(sourceDirection) ??
        _preferredDirectionForTerminal(
          start,
          end,
          source,
          target,
          isSource: true,
        );
    final targetDir =
        _directionMaskFor(targetDirection) ??
        _preferredDirectionForTerminal(
          end,
          start,
          target,
          source,
          isSource: false,
        );
    final sourceJetty = _jettyPoint(start, source, sourceDir, buffer);
    final targetJetty = _jettyPoint(end, target, targetDir, buffer);
    final points = <Offset>[start];
    if ((sourceJetty - start).distance > 0.0001) {
      points.add(sourceJetty);
    }
    points.addAll(
      _drawioMiddlePoints(
        sourceJetty,
        targetJetty,
        sourceDir,
        targetDir,
        source,
        target,
        buffer,
      ),
    );
    if ((targetJetty - end).distance > 0.0001) {
      points.add(targetJetty);
    }
    points.add(end);
    return _dedupe(points, keepPoints: {sourceJetty, targetJetty});
  }

  static List<Offset> _drawioMiddlePoints(
    Offset sourceJetty,
    Offset targetJetty,
    _DirectionMask sourceDir,
    _DirectionMask targetDir,
    Rect? source,
    Rect? target,
    double buffer,
  ) {
    final sameAxis = sourceDir.isHorizontal == targetDir.isHorizontal;
    if (!sameAxis) {
      final corner = sourceDir.isHorizontal
          ? Offset(targetJetty.dx, sourceJetty.dy)
          : Offset(sourceJetty.dx, targetJetty.dy);
      return [corner];
    }

    if (sourceDir.isHorizontal) {
      if (sourceDir == targetDir) {
        final x = sourceDir == _DirectionMask.west
            ? math.min(
                    _leftOf(source, sourceJetty),
                    _leftOf(target, targetJetty),
                  ) -
                  buffer
            : math.max(
                    _rightOf(source, sourceJetty),
                    _rightOf(target, targetJetty),
                  ) +
                  buffer;
        return [Offset(x, sourceJetty.dy), Offset(x, targetJetty.dy)];
      }
      final midX = (sourceJetty.dx + targetJetty.dx) / 2;
      return [Offset(midX, sourceJetty.dy), Offset(midX, targetJetty.dy)];
    }

    if (sourceDir == targetDir) {
      final y = sourceDir == _DirectionMask.north
          ? math.min(_topOf(source, sourceJetty), _topOf(target, targetJetty)) -
                buffer
          : math.max(
                  _bottomOf(source, sourceJetty),
                  _bottomOf(target, targetJetty),
                ) +
                buffer;
      return [Offset(sourceJetty.dx, y), Offset(targetJetty.dx, y)];
    }
    final midY = (sourceJetty.dy + targetJetty.dy) / 2;
    return [Offset(sourceJetty.dx, midY), Offset(targetJetty.dx, midY)];
  }

  static _DirectionMask _preferredDirectionForTerminal(
    Offset point,
    Offset other,
    Rect? terminal,
    Rect? otherTerminal, {
    required bool isSource,
  }) {
    final center = terminal?.center ?? point;
    final otherCenter = otherTerminal?.center ?? other;
    final dx = otherCenter.dx - center.dx;
    final dy = otherCenter.dy - center.dy;
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? _DirectionMask.east : _DirectionMask.west;
    }
    return dy >= 0 ? _DirectionMask.south : _DirectionMask.north;
  }

  static _DirectionMask? _directionMaskFor(Offset? direction) {
    if (direction == null || direction.distance <= 0.0001) {
      return null;
    }
    if (direction.dx.abs() >= direction.dy.abs()) {
      return direction.dx >= 0 ? _DirectionMask.east : _DirectionMask.west;
    }
    return direction.dy >= 0 ? _DirectionMask.south : _DirectionMask.north;
  }

  static Offset _jettyPoint(
    Offset point,
    Rect? terminal,
    _DirectionMask direction,
    double buffer,
  ) {
    if (terminal == null) {
      return point + direction.vector * buffer;
    }
    return switch (direction) {
      _DirectionMask.west => Offset(terminal.left - buffer, point.dy),
      _DirectionMask.north => Offset(point.dx, terminal.top - buffer),
      _DirectionMask.east => Offset(terminal.right + buffer, point.dy),
      _DirectionMask.south => Offset(point.dx, terminal.bottom + buffer),
    };
  }

  static double _leftOf(Rect? rect, Offset fallback) =>
      rect?.left ?? fallback.dx;
  static double _rightOf(Rect? rect, Offset fallback) =>
      rect?.right ?? fallback.dx;
  static double _topOf(Rect? rect, Offset fallback) => rect?.top ?? fallback.dy;
  static double _bottomOf(Rect? rect, Offset fallback) =>
      rect?.bottom ?? fallback.dy;

  static Offset _leadPoint(
    Offset port,
    Offset endpoint,
    Offset? preferredDirection,
    double margin,
  ) {
    if (preferredDirection == null || preferredDirection.distance <= 0.0001) {
      return port;
    }
    final unit = preferredDirection / preferredDirection.distance;
    final outward = port + unit * margin;
    final endpointInside = (endpoint - port).distance <= 0.0001;
    return endpointInside ? outward : port;
  }

  static List<Offset> _portsForEndpoint({
    required Offset point,
    required Rect? bounds,
    required Offset toward,
    Offset? preferredDirection,
    Offset? preferredPoint,
  }) {
    if (bounds == null || !_containsInclusive(bounds, point)) {
      return [point];
    }

    final dy = toward.dy - point.dy;
    final dx = toward.dx - point.dx;
    final preferred = preferredPoint;
    final y = preferred == null
        ? point.dy.clamp(bounds.top, bounds.bottom)
        : preferred.dy.clamp(bounds.top, bounds.bottom);
    final x = preferred == null
        ? point.dx.clamp(bounds.left, bounds.right)
        : preferred.dx.clamp(bounds.left, bounds.right);
    final horizontalFirst = dx.abs() >= dy.abs();

    final horizontal = dx >= 0
        ? [Offset(bounds.right, y), Offset(bounds.left, y)]
        : [Offset(bounds.left, y), Offset(bounds.right, y)];
    final vertical = dy >= 0
        ? [Offset(x, bounds.bottom), Offset(x, bounds.top)]
        : [Offset(x, bounds.top), Offset(x, bounds.bottom)];

    final ports = _dedupe(
      horizontalFirst
          ? [...horizontal, ...vertical]
          : [...vertical, ...horizontal],
    );
    final preferredDirectionValue = preferredDirection;
    if (preferredDirectionValue == null ||
        preferredDirectionValue.distance <= 0.0001) {
      return ports;
    }
    final unit = preferredDirectionValue / preferredDirectionValue.distance;
    return ports.toList()..sort((a, b) {
      final da = a - point;
      final db = b - point;
      final scoreA = da.distance <= 0.0001
          ? -1.0
          : (da.dx * unit.dx + da.dy * unit.dy) / da.distance;
      final scoreB = db.distance <= 0.0001
          ? -1.0
          : (db.dx * unit.dx + db.dy * unit.dy) / db.distance;
      return scoreB.compareTo(scoreA);
    });
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
    double margin, {
    required double searchPadding,
    required int maxObstacles,
  }) {
    final corridor = Rect.fromPoints(
      start,
      end,
    ).inflate(searchPadding + margin);
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
    if (list.length <= maxObstacles) {
      return list;
    }
    return list.take(maxObstacles).toList(growable: false);
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
    required double searchPadding,
    required int maxLanesPerAxis,
    required double turnPenalty,
    required double nodeTouchPenalty,
    List<Offset>? previousRoute,
  }) {
    final laneRects = [
      if (source != null) source,
      if (target != null) target,
      ...obstacles,
    ];
    final xLanes = _lanes(
      start.dx,
      end.dx,
      laneRects,
      previousRoute: previousRoute,
      horizontal: true,
      searchPadding: searchPadding,
      maxLanesPerAxis: maxLanesPerAxis,
    );
    final yLanes = _lanes(
      start.dy,
      end.dy,
      laneRects,
      previousRoute: previousRoute,
      horizontal: false,
      searchPadding: searchPadding,
      maxLanesPerAxis: maxLanesPerAxis,
    );

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
          nodeTouchPenalty: nodeTouchPenalty,
        );
        if (segmentPenalty >= 100000) {
          continue;
        }
        final turnCost =
            node.previous == null ||
                _sameDirection(node.previous!.key, node.key, next)
            ? 0.0
            : turnPenalty;
        final cost =
            node.cost +
            (nextPoint - current).distance +
            segmentPenalty +
            turnCost;
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
      final aScore = _score(
        a,
        blocked,
        start,
        end,
        turnPenalty: turnPenalty,
        nodeTouchPenalty: nodeTouchPenalty,
      );
      final bScore = _score(
        b,
        blocked,
        start,
        end,
        turnPenalty: turnPenalty,
        nodeTouchPenalty: nodeTouchPenalty,
      );
      return aScore.compareTo(bScore);
    });
    return candidates.isEmpty ? [start, end] : _dedupe(candidates.first);
  }

  static List<double> _lanes(
    double start,
    double end,
    List<Rect> rects, {
    List<Offset>? previousRoute,
    required bool horizontal,
    required double searchPadding,
    required int maxLanesPerAxis,
  }) {
    final corridorMin = math.min(start, end) - searchPadding;
    final corridorMax = math.max(start, end) + searchPadding;
    final values = <double>{start, end, (start + end) / 2};
    if (previousRoute != null) {
      for (final point in previousRoute) {
        values.add(horizontal ? point.dx : point.dy);
      }
    }
    for (final rect in rects) {
      if (horizontal) {
        if (rect.left >= corridorMin && rect.left <= corridorMax) {
          values.add(rect.left);
        }
        if (rect.right >= corridorMin && rect.right <= corridorMax) {
          values.add(rect.right);
        }
      } else {
        if (rect.top >= corridorMin && rect.top <= corridorMax) {
          values.add(rect.top);
        }
        if (rect.bottom >= corridorMin && rect.bottom <= corridorMax) {
          values.add(rect.bottom);
        }
      }
    }
    final sorted = values.toList()..sort();
    return _thinLanes(sorted, start, end, maxExtra: maxLanesPerAxis);
  }

  static List<double> _thinLanes(
    List<double> sorted,
    double start,
    double end, {
    required int maxExtra,
  }) {
    if (sorted.length <= maxExtra + 2) {
      return sorted;
    }
    final mustKeep = <double>{start, end, (start + end) / 2};
    final extras = [
      for (final value in sorted)
        if (!mustKeep.contains(value)) value,
    ];
    extras.sort((a, b) {
      final center = (start + end) / 2;
      final da = (a - center).abs();
      final db = (b - center).abs();
      return da.compareTo(db);
    });
    final kept = <double>{...mustKeep, ...extras.take(maxExtra)};
    return kept.toList()..sort();
  }

  static Iterable<_GridKey> _neighbors(
    _GridKey key,
    List<double> xLanes,
    List<double> yLanes,
  ) sync* {
    final xIndex = xLanes.indexWhere((x) => (x - key.x).abs() < 0.0001);
    final yIndex = yLanes.indexWhere((y) => (y - key.y).abs() < 0.0001);
    if (xIndex >= 0) {
      if (xIndex > 0) {
        yield _GridKey(xLanes[xIndex - 1], key.y);
      }
      if (xIndex < xLanes.length - 1) {
        yield _GridKey(xLanes[xIndex + 1], key.y);
      }
    }
    if (yIndex >= 0) {
      if (yIndex > 0) {
        yield _GridKey(key.x, yLanes[yIndex - 1]);
      }
      if (yIndex < yLanes.length - 1) {
        yield _GridKey(key.x, yLanes[yIndex + 1]);
      }
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
    Offset end, {
    required double nodeTouchPenalty,
  }) {
    var penalty = 0.0;
    for (final rect in blocked) {
      if (_blockedSegment(a, b, rect, start, end)) {
        return 100000;
      }
      if (_segmentTouchesRect(a, b, rect)) {
        penalty += nodeTouchPenalty;
      }
    }
    return penalty;
  }

  static double _score(
    List<Offset> points,
    List<Rect> blocked,
    Offset start,
    Offset end, {
    Offset? preferredStartDirection,
    Offset? preferredEndDirection,
    Offset? preferredStartPoint,
    Offset? preferredEndPoint,
    List<Offset>? previousRoute,
    double stabilityPenalty = 0,
    double turnPenalty = _defaultTurnPenalty,
    double nodeTouchPenalty = _defaultNodeTouchPenalty,
  }) {
    final path = _dedupe(points);
    var score = _length(path);
    score += _preferredDirectionPenalty(
      path,
      preferredStartDirection,
      atStart: true,
    );
    score += _preferredDirectionPenalty(
      path,
      preferredEndDirection,
      atStart: false,
    );
    score += _preferredPointPenalty(path, preferredStartPoint, atStart: true);
    score += _preferredPointPenalty(path, preferredEndPoint, atStart: false);
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      if (i > 0 && !_sameLine(path[i - 1], a, b)) {
        score += turnPenalty;
      }
      for (final rect in blocked) {
        if (_blockedSegment(a, b, rect, start, end)) {
          score += 100000;
        } else if (_segmentTouchesRect(a, b, rect)) {
          score += nodeTouchPenalty;
        }
      }
    }
    if (previousRoute != null && previousRoute.length >= 2) {
      score += _routeStabilityPenalty(path, previousRoute) * stabilityPenalty;
    }
    return score;
  }

  static double _routeStabilityPenalty(
    List<Offset> path,
    List<Offset> previousRoute,
  ) {
    if (path.length < 2 || previousRoute.length < 2) {
      return 0;
    }
    var total = 0.0;
    for (var i = 1; i < path.length - 1; i++) {
      total += _distanceToPath(path[i], previousRoute);
    }
    return total;
  }

  static double _distanceToPath(Offset point, List<Offset> path) {
    var best = double.infinity;
    for (var i = 0; i < path.length - 1; i++) {
      best = math.min(best, distanceToSegment(point, path[i], path[i + 1]));
    }
    return best.isFinite ? best : 0;
  }

  static double _preferredPointPenalty(
    List<Offset> path,
    Offset? preferred, {
    required bool atStart,
  }) {
    if (preferred == null || path.length < 2) {
      return 0;
    }
    final segmentEnd = atStart ? path[1] : path[path.length - 2];
    return (segmentEnd - preferred).distance * 0.35;
  }

  static double _preferredDirectionPenalty(
    List<Offset> path,
    Offset? preferred, {
    required bool atStart,
  }) {
    if (preferred == null || preferred.distance <= 0.0001 || path.length < 2) {
      return 0;
    }
    final segment = atStart
        ? path[1] - path.first
        : path[path.length - 2] - path.last;
    if (segment.distance <= 0.0001) {
      return 0;
    }
    final dot =
        (segment.dx * preferred.dx + segment.dy * preferred.dy) /
        (segment.distance * preferred.distance);
    if (dot > 0.999) {
      return 0;
    }
    if (dot > 0.5) {
      return 24;
    }
    if (dot > -0.5) {
      return 96;
    }
    return 240;
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

enum _DirectionMask {
  west,
  north,
  east,
  south;

  bool get isHorizontal => this == west || this == east;

  Offset get vector {
    return switch (this) {
      west => const Offset(-1, 0),
      north => const Offset(0, -1),
      east => const Offset(1, 0),
      south => const Offset(0, 1),
    };
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
