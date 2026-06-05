import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  group('CanvasTransform', () {
    test('identity has default values', () {
      const t = CanvasTransform.identity;
      expect(t.scale, 1.0);
      expect(t.offset, Offset.zero);
    });

    test('screenToWorld and worldToScreen are inverse', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 50));
      const screenPoint = Offset(200, 150);

      final worldPoint = t.screenToWorld(screenPoint);
      final backToScreen = t.worldToScreen(worldPoint);

      expect(backToScreen.dx, closeTo(screenPoint.dx, 1e-10));
      expect(backToScreen.dy, closeTo(screenPoint.dy, 1e-10));
    });

    test('screenToWorld converts correctly', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 50));
      // world = (screen - offset) / scale
      final world = t.screenToWorld(const Offset(200, 150));
      expect(world.dx, closeTo(50.0, 1e-10));
      expect(world.dy, closeTo(50.0, 1e-10));
    });

    test('worldToScreen converts correctly', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 50));
      // screen = world * scale + offset
      final screen = t.worldToScreen(const Offset(50, 50));
      expect(screen.dx, closeTo(200.0, 1e-10));
      expect(screen.dy, closeTo(150.0, 1e-10));
    });

    test('pan moves offset', () {
      const t = CanvasTransform(scale: 1.0, offset: Offset(10, 20));
      final panned = t.pan(const Offset(30, 40));
      expect(panned.offset.dx, closeTo(40.0, 1e-10));
      expect(panned.offset.dy, closeTo(60.0, 1e-10));
      expect(panned.scale, 1.0);
    });

    test('zoomTo keeps focal point stable', () {
      const t = CanvasTransform(scale: 1.0, offset: Offset.zero);
      const focalPoint = Offset(100, 100);

      final zoomed = t.zoomTo(2.0, focalPoint);

      // The world point under the focal should stay at the same screen position
      final worldPoint = t.screenToWorld(focalPoint);
      final screenAfterZoom = zoomed.worldToScreen(worldPoint);

      expect(screenAfterZoom.dx, closeTo(focalPoint.dx, 1e-10));
      expect(screenAfterZoom.dy, closeTo(focalPoint.dy, 1e-10));
      expect(zoomed.scale, 2.0);
    });

    test('zoomTo clamps scale to min/max', () {
      const t = CanvasTransform.identity;
      const focal = Offset(100, 100);

      final tooSmall = t.zoomTo(0.01, focal);
      expect(tooSmall.scale, CanvasTransform.minScale);

      final tooLarge = t.zoomTo(100.0, focal);
      expect(tooLarge.scale, CanvasTransform.maxScale);
    });

    test('zoomIn increases scale', () {
      const t = CanvasTransform.identity;
      final zoomedIn = t.zoomIn();
      expect(zoomedIn.scale, closeTo(1.2, 1e-10));
    });

    test('zoomOut decreases scale', () {
      const t = CanvasTransform.identity;
      final zoomedOut = t.zoomOut();
      expect(zoomedOut.scale, closeTo(1.0 / 1.2, 1e-10));
    });

    test('zoomIn with custom focal point', () {
      const t = CanvasTransform(scale: 1.0, offset: Offset(50, 50));
      const focal = Offset(200, 200);

      final zoomedIn = t.zoomIn(focalPoint: focal);
      expect(zoomedIn.scale, closeTo(1.2, 1e-10));

      // Focal point should remain stable
      final worldBefore = t.screenToWorld(focal);
      final screenAfter = zoomedIn.worldToScreen(worldBefore);
      expect(screenAfter.dx, closeTo(focal.dx, 1e-10));
      expect(screenAfter.dy, closeTo(focal.dy, 1e-10));
    });

    test('zoomOut with custom focal point', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(50, 50));
      const focal = Offset(200, 200);

      final zoomedOut = t.zoomOut(focalPoint: focal);
      expect(zoomedOut.scale, closeTo(2.0 / 1.2, 1e-10));

      // Focal point should remain stable
      final worldBefore = t.screenToWorld(focal);
      final screenAfter = zoomedOut.worldToScreen(worldBefore);
      expect(screenAfter.dx, closeTo(focal.dx, 1e-10));
      expect(screenAfter.dy, closeTo(focal.dy, 1e-10));
    });

    test('reset returns identity', () {
      const t = CanvasTransform(scale: 3.0, offset: Offset(100, 200));
      final reset = t.reset();
      expect(reset.scale, 1.0);
      expect(reset.offset, Offset.zero);
    });

    test('visibleWorldRect computes correctly', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 50));
      const viewportSize = Size(800, 600);

      final rect = t.visibleWorldRect(viewportSize);

      // left = -offset.dx / scale = -100 / 2 = -50
      // top = -offset.dy / scale = -50 / 2 = -25
      // width = viewportWidth / scale = 800 / 2 = 400
      // height = viewportHeight / scale = 600 / 2 = 300
      expect(rect.left, closeTo(-50.0, 1e-10));
      expect(rect.top, closeTo(-25.0, 1e-10));
      expect(rect.width, closeTo(400.0, 1e-10));
      expect(rect.height, closeTo(300.0, 1e-10));
    });

    test('copyWith works', () {
      const t = CanvasTransform(scale: 1.0, offset: Offset(10, 20));

      final copied = t.copyWith(scale: 2.0);
      expect(copied.scale, 2.0);
      expect(copied.offset, const Offset(10, 20));

      final copied2 = t.copyWith(offset: const Offset(30, 40));
      expect(copied2.scale, 1.0);
      expect(copied2.offset, const Offset(30, 40));

      final copied3 = t.copyWith(scale: 3.0, offset: const Offset(50, 60));
      expect(copied3.scale, 3.0);
      expect(copied3.offset, const Offset(50, 60));
    });

    test('toMatrix4 produces correct transformation', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 50));
      final matrix = t.toMatrix4();

      // Matrix4 should map world → screen: screen = world * scale + offset
      final worldPoint = Offset(10, 20);
      final transformed = MatrixUtils.transformPoint(matrix, worldPoint);
      final expected = t.worldToScreen(worldPoint);

      expect(transformed.dx, closeTo(expected.dx, 1e-10));
      expect(transformed.dy, closeTo(expected.dy, 1e-10));
    });

    test('equality and hashCode', () {
      const t1 = CanvasTransform(scale: 2.0, offset: Offset(10, 20));
      const t2 = CanvasTransform(scale: 2.0, offset: Offset(10, 20));
      const t3 = CanvasTransform(scale: 3.0, offset: Offset(10, 20));

      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1, isNot(equals(t3)));
    });

    test('zoomToFit scales content to fit viewport', () {
      const t = CanvasTransform.identity;
      const contentBounds = Rect.fromLTWH(0, 0, 200, 100);
      const viewportSize = Size(800, 600);

      final fitted = t.zoomToFit(contentBounds, viewportSize);

      // Content should be visible and centered
      expect(fitted.scale, greaterThan(0));
      expect(fitted.scale, lessThanOrEqualTo(CanvasTransform.maxScale));

      // Content center should map to viewport center
      final contentCenter = Offset(
        contentBounds.left + contentBounds.width / 2,
        contentBounds.top + contentBounds.height / 2,
      );
      final screenCenter = fitted.worldToScreen(contentCenter);
      expect(screenCenter.dx, closeTo(viewportSize.width / 2, 1e-10));
      expect(screenCenter.dy, closeTo(viewportSize.height / 2, 1e-10));
    });

    test('zoomToFit returns this for empty content bounds', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(10, 20));
      final result = t.zoomToFit(Rect.zero, const Size(800, 600));
      expect(result, equals(t));
    });

    test('zoomBy multiplies scale by factor', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(100, 100));
      const focal = Offset(200, 200);

      final result = t.zoomBy(1.5, focal);
      expect(result.scale, closeTo(3.0, 1e-10));
    });

    test('toString returns readable format', () {
      const t = CanvasTransform(scale: 2.0, offset: Offset(10, 20));
      final str = t.toString();
      expect(str, contains('2.0'));
      expect(str, contains('10'));
      expect(str, contains('20'));
    });
  });
}
