/// Visible range returned by [BlockLayoutIndex.visibleRange].
class BlockVisibleRange {
  const BlockVisibleRange({
    required this.start,
    required this.endExclusive,
  });

  static const BlockVisibleRange empty = BlockVisibleRange(
    start: 0,
    endExclusive: 0,
  );

  final int start;
  final int endExclusive;

  bool get isEmpty => start >= endExclusive;
}

/// Prefix-sum index for virtual block layout.
///
/// A Fenwick tree provides O(log N) height updates and offset lower-bounds,
/// while top/bottom queries and visible-range construction avoid allocating an
/// offsets list on every scroll frame.
class BlockLayoutIndex {
  BlockLayoutIndex({
    List<double> extents = const <double>[],
    List<double> trailingSpacings = const <double>[],
    List<bool> measured = const <bool>[],
    double? estimatedExtent,
  }) {
    reset(
      extents,
      trailingSpacings: trailingSpacings,
      measured: measured,
      estimatedExtent: estimatedExtent,
    );
  }

  final List<double> _extents = <double>[];
  final List<bool> _measured = <bool>[];
  final List<double> _trailingSpacings = <double>[];
  final List<double> _measuredExtentTree = <double>[];
  final List<double> _measuredCountTree = <double>[];
  final List<double> _spacingTree = <double>[];
  double _estimatedExtent = 1;

  int get length => _extents.length;

  double get totalExtent => _prefixSum(length);

  double extentAt(int index) =>
      _measured[index] ? _extents[index] : _estimatedExtent;

  double trailingSpacingAt(int index) => _trailingSpacings[index];

  double topFor(int index) {
    RangeError.checkValidIndex(index, _extents, 'index', length);
    return _prefixSum(index);
  }

  double bottomFor(int index) => topFor(index) + extentAt(index);

  void reset(
    List<double> extents, {
    List<double> trailingSpacings = const <double>[],
    List<bool> measured = const <bool>[],
    double? estimatedExtent,
  }) {
    if (trailingSpacings.isNotEmpty &&
        trailingSpacings.length != extents.length) {
      throw ArgumentError.value(
        trailingSpacings.length,
        'trailingSpacings.length',
        'must be empty or match extents.length',
      );
    }
    if (measured.isNotEmpty && measured.length != extents.length) {
      throw ArgumentError.value(
        measured.length,
        'measured.length',
        'must be empty or match extents.length',
      );
    }
    _extents
      ..clear()
      ..addAll(extents.map(_validExtent));
    _measured
      ..clear()
      ..addAll(
        measured.isEmpty ? List<bool>.filled(extents.length, true) : measured,
      );
    _estimatedExtent = _validExtent(
      estimatedExtent ?? (extents.isEmpty ? 1 : extents.first),
    );
    _trailingSpacings
      ..clear()
      ..addAll(
        trailingSpacings.isEmpty
            ? List<double>.filled(extents.length, 0)
            : trailingSpacings.map(_validSpacing),
      );
    _measuredExtentTree
      ..clear()
      ..addAll(List<double>.filled(extents.length + 1, 0));
    _measuredCountTree
      ..clear()
      ..addAll(List<double>.filled(extents.length + 1, 0));
    _spacingTree
      ..clear()
      ..addAll(List<double>.filled(extents.length + 1, 0));
    for (var index = 0; index < length; index++) {
      if (_measured[index]) {
        _add(_measuredExtentTree, index, _extents[index]);
        _add(_measuredCountTree, index, 1);
      }
      _add(_spacingTree, index, _trailingSpacings[index]);
    }
  }

  bool updateExtent(int index, double extent) {
    RangeError.checkValidIndex(index, _extents, 'index', length);
    final next = _validExtent(extent);
    final wasMeasured = _measured[index];
    final previous = wasMeasured ? _extents[index] : _estimatedExtent;
    if (wasMeasured && (previous - next).abs() <= 0.0001) {
      return false;
    }
    _extents[index] = next;
    _measured[index] = true;
    if (wasMeasured) {
      _add(_measuredExtentTree, index, next - previous);
    } else {
      _add(_measuredExtentTree, index, next);
      _add(_measuredCountTree, index, 1);
    }
    return true;
  }

  bool updateEstimatedExtent(double extent) {
    final next = _validExtent(extent);
    if ((_estimatedExtent - next).abs() <= 0.0001) {
      return false;
    }
    _estimatedExtent = next;
    return true;
  }

  bool updateTrailingSpacing(int index, double spacing) {
    RangeError.checkValidIndex(index, _extents, 'index', length);
    final next = _validSpacing(spacing);
    final previous = _trailingSpacings[index];
    if ((previous - next).abs() <= 0.0001) {
      return false;
    }
    _trailingSpacings[index] = next;
    _add(_spacingTree, index, next - previous);
    return true;
  }

  BlockVisibleRange visibleRange(double visibleTop, double visibleBottom) {
    if (length == 0) {
      return BlockVisibleRange.empty;
    }
    final start = _firstIndexWithBottomAtOrAfter(visibleTop);
    if (start >= length) {
      return BlockVisibleRange(start: length - 1, endExclusive: length);
    }
    final rawEnd = _firstIndexWithTopAfter(visibleBottom);
    final end = rawEnd <= start ? start + 1 : rawEnd;
    return BlockVisibleRange(
      start: start,
      endExclusive: end.clamp(0, length).toInt(),
    );
  }

  int _firstIndexWithBottomAtOrAfter(double y) {
    if (y <= 0) {
      return 0;
    }
    var candidate = _countWithPrefixAtMost(y);
    if (candidate >= length) {
      return length;
    }
    if (bottomFor(candidate) < y) {
      candidate++;
    }
    return candidate;
  }

  int _firstIndexWithTopAfter(double y) {
    if (y < 0) {
      return 0;
    }
    return (_countWithPrefixAtMost(y) + 1).clamp(0, length).toInt();
  }

  int _countWithPrefixAtMost(double target) {
    var index = 0;
    var sum = 0.0;
    var bit = _highestPowerOfTwoAtMost(length);
    while (bit != 0) {
      final next = index + bit;
      if (next <= length) {
        final segmentValue = _fenwickSegmentValue(next);
        if (sum + segmentValue <= target) {
          index = next;
          sum += segmentValue;
        }
      }
      bit >>= 1;
    }
    return index;
  }

  double _prefixSum(int endExclusive) {
    var index = endExclusive;
    var result = 0.0;
    while (index > 0) {
      result += _fenwickSegmentValue(index);
      index -= index & -index;
    }
    return result;
  }

  void _add(List<double> tree, int zeroBasedIndex, double delta) {
    var index = zeroBasedIndex + 1;
    while (index < tree.length) {
      tree[index] += delta;
      index += index & -index;
    }
  }

  double _fenwickSegmentValue(int oneBasedIndex) {
    final segmentLength = oneBasedIndex & -oneBasedIndex;
    final measuredCount = _measuredCountTree[oneBasedIndex];
    return _measuredExtentTree[oneBasedIndex] +
        (segmentLength - measuredCount) * _estimatedExtent +
        _spacingTree[oneBasedIndex];
  }
}

double _validExtent(double value) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, 'extent', 'must be finite and positive');
  }
  return value;
}

double _validSpacing(double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      'trailingSpacing',
      'must be finite and non-negative',
    );
  }
  return value;
}

int _highestPowerOfTwoAtMost(int value) {
  var result = 1;
  while ((result << 1) <= value) {
    result <<= 1;
  }
  return value == 0 ? 0 : result;
}
