import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/canvas/canvas_controller.dart';
import 'package:wenz_draw/src/infinite_canvas/canvas_transform.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_config.dart';
import 'package:wenz_draw/src/infinite_canvas/infinite_canvas_controller.dart';

/// Covers the Phase B gesture/configuration surface:
/// - configurable min/max scale on the controller
/// - InfiniteCanvasConfig defaults (all gestures enabled, fling on)
/// - zoomTo/zoomBy respect the controller bounds
void main() {
  group('InfiniteCanvasController scale bounds', () {
    test('zoomTo clamps to the configured minScale', () {
      final controller = InfiniteCanvasController(
        canvasController: CanvasController(),
        minScale: 0.5,
        maxScale: 4.0,
      );
      controller.setViewportSize(const Size(400, 300));
      controller.zoomTo(0.1);
      expect(controller.transform.scale, 0.5);
      controller.dispose();
    });

    test('zoomBy clamps to the configured maxScale', () {
      final controller = InfiniteCanvasController(
        canvasController: CanvasController(),
        minScale: 0.5,
        maxScale: 4.0,
      );
      controller.setViewportSize(const Size(400, 300));
      controller.zoomBy(100);
      expect(controller.transform.scale, 4.0);
      controller.dispose();
    });

    test('defaults match CanvasTransform constants when unset', () {
      final controller = InfiniteCanvasController(
        canvasController: CanvasController(),
      );
      expect(controller.minScale, CanvasTransform.minScale);
      expect(controller.maxScale, CanvasTransform.maxScale);
      controller.dispose();
    });
  });

  group('InfiniteCanvasConfig defaults', () {
    test('all gestures are enabled by default', () {
      const config = InfiniteCanvasConfig();
      expect(config.enablePinch, isTrue);
      expect(config.enableWheelZoom, isTrue);
      expect(config.enableKeyboard, isTrue);
      expect(config.enableDoubleTapZoom, isTrue);
      expect(config.flingEnabled, isTrue);
    });

    test('double-tap zoom factor defaults to 2.0', () {
      const config = InfiniteCanvasConfig();
      expect(config.doubleTapZoomFactor, 2.0);
    });

    test('fling friction is in a sensible range', () {
      const config = InfiniteCanvasConfig();
      expect(config.flingDecayFriction, greaterThan(0));
      expect(config.flingDecayFriction, lessThan(1));
    });

    test('a custom config preserves overridden gesture flags', () {
      const config = InfiniteCanvasConfig(
        enablePinch: false,
        enableWheelZoom: false,
        enableKeyboard: false,
        enableDoubleTapZoom: false,
        flingEnabled: false,
        minScale: 0.2,
        maxScale: 5.0,
      );
      expect(config.enablePinch, isFalse);
      expect(config.enableWheelZoom, isFalse);
      expect(config.enableKeyboard, isFalse);
      expect(config.enableDoubleTapZoom, isFalse);
      expect(config.flingEnabled, isFalse);
      expect(config.minScale, 0.2);
      expect(config.maxScale, 5.0);
    });
  });
}
