import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  test('screen and world coordinate conversion round trips', () {
    const transform = CanvasTransform(scale: 2, offset: Offset(20, -10));
    const worldPoint = Offset(12, 18);

    final screenPoint = transform.worldToScreen(worldPoint);
    expect(transform.screenToWorld(screenPoint), worldPoint);
  });

  test('zoomTo keeps focal world point under the same screen position', () {
    const transform = CanvasTransform(scale: 1, offset: Offset(40, 20));
    const focalPoint = Offset(120, 100);
    final worldBefore = transform.screenToWorld(focalPoint);

    final zoomed = transform.zoomTo(2, focalPoint);

    expect(zoomed.screenToWorld(focalPoint), worldBefore);
  });

  test('visibleWorldRect maps the viewport into world coordinates', () {
    const transform = CanvasTransform(scale: 2, offset: Offset(20, 40));

    final rect = transform.visibleWorldRect(const Size(200, 100));

    expect(rect.left, -10);
    expect(rect.top, -20);
    expect(rect.width, 100);
    expect(rect.height, 50);
  });
}
