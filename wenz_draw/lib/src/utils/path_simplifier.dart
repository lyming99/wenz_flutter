import 'package:flutter/widgets.dart';

import 'math_utils.dart';

class PathSimplifier {
  const PathSimplifier._();

  static List<Offset> simplify(List<Offset> points, {double tolerance = 1.2}) {
    if (points.length < 3) {
      return List<Offset>.unmodifiable(points);
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;
    _simplifySection(points, keep, 0, points.length - 1, tolerance);

    return List<Offset>.unmodifiable([
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ]);
  }

  static void _simplifySection(
    List<Offset> points,
    List<bool> keep,
    int first,
    int last,
    double tolerance,
  ) {
    if (last <= first + 1) {
      return;
    }

    var maxDistance = 0.0;
    var index = first;
    for (var i = first + 1; i < last; i++) {
      final distance = distanceToSegment(
        points[i],
        points[first],
        points[last],
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance <= tolerance) {
      return;
    }

    keep[index] = true;
    _simplifySection(points, keep, first, index, tolerance);
    _simplifySection(points, keep, index, last, tolerance);
  }
}
