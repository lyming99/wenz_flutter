import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../elements/element_registry.dart';
import 'infinite_canvas_controller.dart';

class MinimapWidget extends StatelessWidget {
  const MinimapWidget({
    super.key,
    required this.controller,
    this.size = const Size(180, 120),
    this.backgroundColor = const Color(0xF2FFFFFF),
  });

  final InfiniteCanvasController controller;
  final Size size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.canvasController]),
      builder: (context, _) {
        return SizedBox.fromSize(
          size: size,
          child: _MinimapGestureLayer(
            controller: controller,
            size: size,
            child: CustomPaint(
              painter: _MinimapPainter(controller, backgroundColor),
            ),
          ),
        );
      },
    );
  }
}

class _MinimapGestureLayer extends StatelessWidget {
  const _MinimapGestureLayer({
    required this.controller,
    required this.size,
    required this.child,
  });

  final InfiniteCanvasController controller;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _moveViewport(details.localPosition),
      onPanStart: (details) => _moveViewport(details.localPosition),
      onPanUpdate: (details) => _moveViewport(details.localPosition),
      child: child,
    );
  }

  void _moveViewport(Offset localPosition) {
    final contentBounds = controller.canvasController.state.contentBounds;
    final visible = controller.visibleWorldRect();
    final layout = MinimapLayout.resolve(
      contentBounds: contentBounds,
      visibleWorldRect: visible,
      minimapSize: size,
    );
    controller.centerOnWorld(layout.screenToWorld(localPosition));
  }
}

class MinimapLayout {
  const MinimapLayout({
    required this.worldBounds,
    required this.scale,
    required this.offset,
    required this.viewportRect,
  });

  final Rect worldBounds;
  final double scale;
  final Offset offset;
  final Rect viewportRect;

  Offset screenToWorld(Offset minimapPoint) {
    return Offset(
      (minimapPoint.dx - offset.dx) / scale,
      (minimapPoint.dy - offset.dy) / scale,
    );
  }

  static MinimapLayout resolve({
    required Rect? contentBounds,
    required Rect visibleWorldRect,
    required Size minimapSize,
    double worldPadding = 80,
  }) {
    final baseBounds = contentBounds == null || contentBounds.isEmpty
        ? visibleWorldRect
        : contentBounds.expandToInclude(visibleWorldRect);
    final worldBounds = baseBounds.inflate(worldPadding);
    final scale = math.min(
      minimapSize.width / worldBounds.width,
      minimapSize.height / worldBounds.height,
    );
    final offset = Offset(
      (minimapSize.width - worldBounds.width * scale) / 2 -
          worldBounds.left * scale,
      (minimapSize.height - worldBounds.height * scale) / 2 -
          worldBounds.top * scale,
    );

    return MinimapLayout(
      worldBounds: worldBounds,
      scale: scale,
      offset: offset,
      viewportRect: _mapRect(visibleWorldRect, scale, offset),
    );
  }

  static Rect _mapRect(Rect worldRect, double scale, Offset offset) {
    return Rect.fromLTWH(
      worldRect.left * scale + offset.dx,
      worldRect.top * scale + offset.dy,
      worldRect.width * scale,
      worldRect.height * scale,
    );
  }
}

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter(this.controller, this.backgroundColor);

  final InfiniteCanvasController controller;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final elements = controller.canvasController.elements;
    final contentBounds = controller.canvasController.state.contentBounds;
    final visible = controller.visibleWorldRect();
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(background, Paint()..color = backgroundColor);

    final layout = MinimapLayout.resolve(
      contentBounds: contentBounds,
      visibleWorldRect: visible,
      minimapSize: size,
    );

    canvas.save();
    canvas.clipRRect(background);
    canvas.save();
    canvas.translate(layout.offset.dx, layout.offset.dy);
    canvas.scale(layout.scale);
    for (final element in elements) {
      ElementRendererRegistry.render(canvas, element);
    }
    canvas.restore();

    canvas.drawRect(
      layout.viewportRect,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.controller.transform != controller.transform ||
        oldDelegate.controller.canvasController.state.revision !=
            controller.canvasController.state.revision;
  }
}
