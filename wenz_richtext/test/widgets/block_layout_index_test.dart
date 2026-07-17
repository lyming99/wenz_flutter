import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  test('prefix offsets include trailing block spacing', () {
    final index = BlockLayoutIndex(
      extents: <double>[10, 20, 30],
      trailingSpacings: <double>[2, 3, 0],
    );

    expect(index.topFor(0), 0);
    expect(index.bottomFor(0), 10);
    expect(index.topFor(1), 12);
    expect(index.topFor(2), 35);
    expect(index.totalExtent, 65);
  });

  test('visible range skips spacing gaps and uses logarithmic lower bound', () {
    final index = BlockLayoutIndex(
      extents: <double>[10, 20, 30],
      trailingSpacings: <double>[2, 3, 0],
    );

    expect(index.visibleRange(0, 9).start, 0);
    expect(index.visibleRange(0, 9).endExclusive, 1);
    expect(index.visibleRange(11, 11).start, 1);
    expect(index.visibleRange(34, 34).start, 2);
    expect(index.visibleRange(100, 120).start, 2);
  });

  test('point height and spacing updates adjust only later prefixes', () {
    final index = BlockLayoutIndex(
      extents: List<double>.filled(10000, 10),
      trailingSpacings: List<double>.filled(10000, 1)..[9999] = 0,
    );

    expect(index.updateExtent(5000, 25), isTrue);
    expect(index.updateTrailingSpacing(5000, 4), isTrue);
    expect(index.topFor(5000), 55000);
    expect(index.topFor(5001), 55029);
    expect(index.totalExtent, 110017);
    expect(index.updateExtent(5000, 25), isFalse);
  });

  test('unknown blocks follow the rolling estimate without an O(N) rewrite',
      () {
    final index = BlockLayoutIndex(
      extents: <double>[10, 10, 10],
      measured: <bool>[true, false, false],
      estimatedExtent: 10,
    );

    expect(index.totalExtent, 30);
    expect(index.updateEstimatedExtent(20), isTrue);
    expect(index.totalExtent, 50);
    expect(index.updateExtent(1, 15), isTrue);
    expect(index.totalExtent, 45);
    expect(index.topFor(2), 25);
  });
}
