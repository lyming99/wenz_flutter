import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

/// Minimal headless-embedding demo: the kernel only, no UI shell.
///
/// This mirrors the "5-line embed" documented in the README. It shows that a
/// host can use `InfiniteCanvasWidget` directly — toolbar, panels and the
/// inspector are all optional. A few sample shapes are seeded so the canvas is
/// not empty on launch.
///
/// The default editor lives in [CanvasDemoPage]; this page is the lightweight
/// counterpart for hosts that build their own chrome.
class MinimalCanvasPage extends StatefulWidget {
  const MinimalCanvasPage({super.key, this.onExit});

  /// Called when the user taps the "back to full editor" action.
  final VoidCallback? onExit;

  @override
  State<MinimalCanvasPage> createState() => _MinimalCanvasPageState();
}

class _MinimalCanvasPageState extends State<MinimalCanvasPage> {
  late final CanvasController _canvasController;
  late final InfiniteCanvasController _viewController;

  @override
  void initState() {
    super.initState();
    _canvasController = CanvasController();
    _viewController = InfiniteCanvasController(
      canvasController: _canvasController,
      minScale: 0.25,
      maxScale: 6.0,
    );
    // Seed a couple of shapes so the canvas is not empty.
    _canvasController
      ..addElement(
        const RectElement(
          id: 'min-rect',
          rect: Rect.fromLTWH(60, 60, 160, 100),
          label: 'Kernel only',
        ),
        record: false,
      )
      ..addElement(
        const EllipseElement(
          id: 'min-ell',
          rect: Rect.fromLTWH(300, 120, 140, 100),
          label: 'No UI shell',
        ),
        record: false,
      );
  }

  @override
  void dispose() {
    _viewController.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimal kernel embed'),
        actions: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: _viewController.zoomIn,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: _viewController.zoomOut,
          ),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: _viewController.resetView,
          ),
          if (widget.onExit != null)
            IconButton(
              tooltip: 'Full editor',
              icon: const Icon(Icons.grid_view),
              onPressed: widget.onExit,
            ),
        ],
      ),
      // The entire infinite canvas, in five lines:
      body: InfiniteCanvasWidget(
        controller: _viewController,
        config: const InfiniteCanvasConfig(
          gridType: GridType.dots,
          enableDoubleTapZoom: true,
        ),
      ),
    );
  }
}
