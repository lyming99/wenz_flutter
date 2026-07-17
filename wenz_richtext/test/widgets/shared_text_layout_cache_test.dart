import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/widgets/shared_text_layout_cache.dart';

void main() {
  test('entryFor returns the same instance for a surface identity', () {
    final cache = SharedTextLayoutCache();
    final a = cache.entryFor('p1', 'block/p1');
    final b = cache.entryFor('p1', 'block/p1');
    expect(identical(a, b), isTrue);
    cache.dispose();
  });

  test('entryFor keeps distinct entries per block id / path', () {
    final cache = SharedTextLayoutCache();
    final p1 = cache.entryFor('p1', 'block/p1');
    final p2 = cache.entryFor('p2', 'block/p2');
    final cell = cache.entryFor('t1', 'table/t1/row/0/cell/0');
    expect(identical(p1, p2), isFalse);
    expect(identical(p1, cell), isFalse);
    expect(cache.length, 3);
    cache.dispose();
  });

  test('invalidate drops a single surface entry', () {
    final cache = SharedTextLayoutCache();
    cache.entryFor('p1', 'block/p1');
    cache.entryFor('p1', 'table/p1/row/0/cell/0');
    expect(cache.length, 2);

    final before = cache.entryFor('p1', 'block/p1');
    cache.invalidate('p1', 'block/p1');
    expect(cache.length, 1);
    final after = cache.entryFor('p1', 'block/p1');
    // A fresh instance is created after invalidation.
    expect(identical(before, after), isFalse);
    cache.dispose();
  });

  test('removeBlock drops every entry for a block id', () {
    final cache = SharedTextLayoutCache();
    cache.entryFor('t1', 'table/t1/row/0/cell/0');
    cache.entryFor('t1', 'table/t1/row/0/cell/1');
    cache.entryFor('p2', 'block/p2');
    expect(cache.length, 3);

    cache.removeBlock('t1');
    expect(cache.length, 1);
    // p2 untouched.
    expect(cache.entryFor('p2', 'block/p2'), isNotNull);
    cache.dispose();
  });

  test('dispose clears all entries', () {
    final cache = SharedTextLayoutCache();
    cache.entryFor('p1', 'block/p1');
    cache.entryFor('p2', 'block/p2');
    expect(cache.length, 2);

    cache.dispose();
    expect(cache.length, 0);
  });

  test('entryFor returns a fresh instance after invalidate then re-entry', () {
    final cache = SharedTextLayoutCache();
    final first = cache.entryFor('p1', 'block/p1');
    cache.invalidate('p1', 'block/p1');
    final second = cache.entryFor('p1', 'block/p1');
    expect(identical(first, second), isFalse);
    cache.dispose();
  });

  test('LRU cap evicts the least recently used surface', () {
    final cache = SharedTextLayoutCache(
      maxEntries: 2,
      maxEstimatedBytes: 1024,
      estimatedBytesPerEntry: 128,
    );
    final first = cache.entryFor('p1', 'block/p1');
    final second = cache.entryFor('p2', 'block/p2');
    expect(identical(cache.entryFor('p1', 'block/p1'), first), isTrue);

    cache.entryFor('p3', 'block/p3');

    expect(cache.length, 2);
    expect(cache.evictionCount, 1);
    expect(identical(cache.entryFor('p1', 'block/p1'), first), isTrue);
    expect(identical(cache.entryFor('p2', 'block/p2'), second), isFalse);
    cache.dispose();
  });

  test('estimated byte budget is enforced independently of entry cap', () {
    final cache = SharedTextLayoutCache(
      maxEntries: 100,
      maxEstimatedBytes: 256,
      estimatedBytesPerEntry: 128,
    );

    for (var index = 0; index < 10; index++) {
      cache.entryFor('p$index', 'block/p$index');
    }

    expect(cache.length, 2);
    expect(cache.estimatedRetainedBytes, lessThanOrEqualTo(256));
    cache.dispose();
  });
}
