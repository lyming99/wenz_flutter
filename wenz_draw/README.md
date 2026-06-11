# wenz_draw

`wenz_draw` is a Flutter infinite canvas drawing SDK built on `CustomPainter`
and `ChangeNotifier`. It includes pan/zoom, adaptive grid rendering, elements,
tools, selection, history, layers, spatial indexing, JSON serialization, PNG/SVG
export, minimap, and a runnable example app.

See [spec/wenz_draw_infinite_canvas.md](spec/wenz_draw_infinite_canvas.md) for
the full design plan, [TODO.md](TODO.md) for implementation status, and
[docs/extension_api.md](docs/extension_api.md) for custom tool/element
extension notes.

## Quick Start

```dart
final canvasController = CanvasController();
final controller = InfiniteCanvasController(
  canvasController: canvasController,
);

InfiniteCanvasWidget(controller: controller);
```

## Export

```dart
final json = CanvasSerializer.toJson(canvasController);
final svg = SvgExporter.exportElements(elements: canvasController.elements);
final png = await PngExporter.exportElements(
  elements: canvasController.elements,
);
```
