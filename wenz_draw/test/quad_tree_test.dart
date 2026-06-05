import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('QuadTree', () {
    late QuadTree<String> tree;

    setUp(() {
      tree = QuadTree<String>(bounds: Rect.fromLTRB(0, 0, 100, 100));
    });

    test('insert and query basic', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));
      tree.insert('b', Rect.fromLTWH(50, 50, 5, 5));

      final result = tree.query(Rect.fromLTWH(8, 8, 10, 10));
      expect(result, contains('a'));
      expect(result, isNot(contains('b')));
    });

    test('query returns items overlapping query rect', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));
      tree.insert('b', Rect.fromLTWH(50, 50, 5, 5));
      tree.insert('c', Rect.fromLTWH(80, 80, 10, 10));

      final result = tree.query(Rect.fromLTWH(0, 0, 100, 100));
      expect(result, containsAll(['a', 'b', 'c']));
    });

    test('query with empty tree returns empty', () {
      final result = tree.query(Rect.fromLTWH(0, 0, 50, 50));
      expect(result, isEmpty);
    });

    test('query with non-overlapping rect returns empty', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));

      final result = tree.query(Rect.fromLTWH(50, 50, 10, 10));
      expect(result, isEmpty);
    });

    test('query with rect outside tree bounds returns empty', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));

      final result = tree.query(Rect.fromLTWH(200, 200, 10, 10));
      expect(result, isEmpty);
    });

    test('remove removes item from tree', () {
      const bounds = Rect.fromLTWH(10, 10, 5, 5);
      tree.insert('a', bounds);

      expect(tree.query(Rect.fromLTWH(8, 8, 10, 10)), contains('a'));

      final removed = tree.remove('a', bounds);
      expect(removed, isTrue);

      expect(tree.query(Rect.fromLTWH(8, 8, 10, 10)), isNot(contains('a')));
    });

    test('remove returns false for non-existent item', () {
      const bounds = Rect.fromLTWH(10, 10, 5, 5);
      tree.insert('a', bounds);

      final removed = tree.remove('b', bounds);
      expect(removed, isFalse);
    });

    test('remove returns false for item outside bounds', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));

      final removed = tree.remove('a', Rect.fromLTWH(200, 200, 5, 5));
      expect(removed, isFalse);
    });

    test('clear empties all items', () {
      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));
      tree.insert('b', Rect.fromLTWH(50, 50, 5, 5));
      tree.insert('c', Rect.fromLTWH(80, 80, 5, 5));

      expect(tree.size, 3);

      tree.clear();

      expect(tree.size, 0);
      expect(tree.query(Rect.fromLTWH(0, 0, 100, 100)), isEmpty);
    });

    test('size returns total item count', () {
      expect(tree.size, 0);

      tree.insert('a', Rect.fromLTWH(10, 10, 5, 5));
      expect(tree.size, 1);

      tree.insert('b', Rect.fromLTWH(50, 50, 5, 5));
      expect(tree.size, 2);

      tree.insert('c', Rect.fromLTWH(80, 80, 5, 5));
      expect(tree.size, 3);
    });

    test('insert ignores items outside tree bounds', () {
      tree.insert('a', Rect.fromLTWH(200, 200, 5, 5));
      expect(tree.size, 0);
    });

    test('query returns deduplicated results', () {
      // Insert same value at overlapping bounds
      tree.insert('a', Rect.fromLTWH(10, 10, 20, 20));
      tree.insert('a', Rect.fromLTWH(15, 15, 20, 20));

      final result = tree.query(Rect.fromLTWH(0, 0, 100, 100));
      // Should contain 'a' only once (deduplicated via Set)
      expect(result.length, 1);
      expect(result, contains('a'));
    });

    test('handles items spanning multiple quadrants', () {
      // Item that spans across the center of the tree
      tree.insert('span', Rect.fromLTWH(40, 40, 20, 20));

      final result = tree.query(Rect.fromLTWH(30, 30, 40, 40));
      expect(result, contains('span'));
    });

    test('large dataset insert and query', () {
      final bigTree = QuadTree<String>(
        bounds: Rect.fromLTRB(0, 0, 1000, 1000),
        maxItems: 4,
        maxDepth: 6,
      );

      // Insert 500 items
      for (int i = 0; i < 500; i++) {
        final x = (i * 7.3) % 990;
        final y = (i * 11.1) % 990;
        bigTree.insert('item_$i', Rect.fromLTWH(x, y, 10, 10));
      }

      expect(bigTree.size, 500);

      // Query a region
      final result = bigTree.query(Rect.fromLTWH(0, 0, 100, 100));
      expect(result, isNotEmpty);

      // Query entire tree
      final all = bigTree.query(Rect.fromLTWH(0, 0, 1000, 1000));
      expect(all.length, 500);
    });

    test('large dataset remove', () {
      final bigTree = QuadTree<String>(
        bounds: Rect.fromLTRB(0, 0, 1000, 1000),
        maxItems: 4,
        maxDepth: 6,
      );

      final items = <String, Rect>{};
      for (int i = 0; i < 100; i++) {
        final key = 'item_$i';
        final bounds = Rect.fromLTWH(i * 9.0, i * 9.0, 10, 10);
        items[key] = bounds;
        bigTree.insert(key, bounds);
      }

      expect(bigTree.size, 100);

      // Remove half
      for (int i = 0; i < 50; i++) {
        final key = 'item_$i';
        final removed = bigTree.remove(key, items[key]!);
        expect(removed, isTrue);
      }

      expect(bigTree.size, 50);

      // Verify removed items are gone
      for (int i = 0; i < 50; i++) {
        final bounds = items['item_$i']!;
        final result = bigTree.query(bounds);
        expect(result, isNot(contains('item_$i')));
      }

      // Verify remaining items are still there
      final allRemaining = bigTree.query(Rect.fromLTWH(0, 0, 1000, 1000));
      expect(allRemaining.length, 50);
      for (int i = 50; i < 100; i++) {
        expect(allRemaining, contains('item_$i'));
      }
    });

    test('query at exact boundary', () {
      tree.insert('edge', Rect.fromLTWH(0, 0, 5, 5));

      // Query exactly at the item location
      final result = tree.query(Rect.fromLTWH(0, 0, 5, 5));
      expect(result, contains('edge'));
    });

    test('multiple inserts at same location', () {
      const bounds = Rect.fromLTWH(10, 10, 5, 5);
      tree.insert('a', bounds);
      tree.insert('b', bounds);
      tree.insert('c', bounds);

      final result = tree.query(Rect.fromLTWH(8, 8, 10, 10));
      expect(result, containsAll(['a', 'b', 'c']));
      expect(tree.size, 3);
    });

    test('remove one of multiple items at same location', () {
      const bounds = Rect.fromLTWH(10, 10, 5, 5);
      tree.insert('a', bounds);
      tree.insert('b', bounds);
      tree.insert('c', bounds);

      tree.remove('b', bounds);

      final result = tree.query(Rect.fromLTWH(8, 8, 10, 10));
      expect(result, containsAll(['a', 'c']));
      expect(result, isNot(contains('b')));
      expect(tree.size, 2);
    });
  });
}
