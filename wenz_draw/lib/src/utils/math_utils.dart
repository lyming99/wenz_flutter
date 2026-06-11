import 'dart:math' as math;

import 'package:flutter/widgets.dart';

double distanceBetween(Offset a, Offset b) {
  return (a - b).distance;
}

double distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final t =
      (((point.dx - start.dx) * segment.dx) +
          ((point.dy - start.dy) * segment.dy)) /
      lengthSquared;
  final clamped = t.clamp(0.0, 1.0).toDouble();
  final projection = Offset(
    start.dx + segment.dx * clamped,
    start.dy + segment.dy * clamped,
  );
  return (point - projection).distance;
}

Rect boundsForPoints(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) {
    return Rect.zero;
  }

  var minX = iterator.current.dx;
  var minY = iterator.current.dy;
  var maxX = iterator.current.dx;
  var maxY = iterator.current.dy;

  while (iterator.moveNext()) {
    final point = iterator.current;
    minX = math.min(minX, point.dx);
    minY = math.min(minY, point.dy);
    maxX = math.max(maxX, point.dx);
    maxY = math.max(maxY, point.dy);
  }

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Offset scalePoint(Offset point, double factor, Offset pivot) {
  return pivot + (point - pivot) * factor;
}

Rect normalizedRectFromPoints(Offset a, Offset b) {
  return Rect.fromLTRB(
    math.min(a.dx, b.dx),
    math.min(a.dy, b.dy),
    math.max(a.dx, b.dx),
    math.max(a.dy, b.dy),
  );
}
