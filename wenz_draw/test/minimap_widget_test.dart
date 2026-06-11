import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('MinimapLayout', () {
    test(
      'keeps viewport inside minimap when visible rect is outside content',
      () {
        final layout = MinimapLayout.resolve(
          contentBounds: const Rect.fromLTWH(0, 0, 100, 100),
          visibleWorldRect: const Rect.fromLTWH(1000, 1000, 500, 300),
          minimapSize: const Size(180, 120),
        );

        expect(layout.viewportRect.left, greaterThanOrEqualTo(0));
        expect(layout.viewportRect.top, greaterThanOrEqualTo(0));
        expect(layout.viewportRect.right, lessThanOrEqualTo(180));
        expect(layout.viewportRect.bottom, lessThanOrEqualTo(120));
      },
    );

    test('maps viewport as relative position in combined world bounds', () {
      final layout = MinimapLayout.resolve(
        contentBounds: const Rect.fromLTWH(0, 0, 1000, 500),
        visibleWorldRect: const Rect.fromLTWH(250, 100, 250, 200),
        minimapSize: const Size(180, 120),
        worldPadding: 0,
      );

      expect(layout.worldBounds, const Rect.fromLTWH(0, 0, 1000, 500));
      expect(layout.scale, 0.18);
      expect(layout.viewportRect, const Rect.fromLTWH(45, 33, 45, 36));
    });

    test('converts minimap position back to world position', () {
      final layout = MinimapLayout.resolve(
        contentBounds: const Rect.fromLTWH(0, 0, 1000, 500),
        visibleWorldRect: const Rect.fromLTWH(250, 100, 250, 200),
        minimapSize: const Size(180, 120),
        worldPadding: 0,
      );

      expect(
        layout.screenToWorld(const Offset(90, 60)),
        const Offset(500, 250),
      );
    });
  });
}
