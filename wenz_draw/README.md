# wenz_draw

`wenz_draw` is a Flutter infinite canvas drawing SDK built on `CustomPainter`
and `ChangeNotifier`. It includes pan/zoom, adaptive grid rendering, elements,
tools, selection, history, layers, spatial indexing, JSON serialization, PNG/SVG
export, minimap, and a runnable example app.

See [spec/wenz_draw_infinite_canvas.md](spec/wenz_draw_infinite_canvas.md) for
the full design plan, [TODO.md](TODO.md) for implementation status,
[docs/extension_api.md](docs/extension_api.md) for custom tool/element
extension notes, and [docs/drawio_shapes.md](docs/drawio_shapes.md) for
draw.io-style shape support.

## Quick Start

```dart
final canvasController = CanvasController();
final controller = InfiniteCanvasController(
  canvasController: canvasController,
);

InfiniteCanvasWidget(controller: controller);
```

## Draw.io Shapes

```dart
controller.setTool(ShapeTool.idFor('rhombus'));

final shape = DrawioShapeAdapter.fromStyleString(
  id: 'shape-1',
  rect: const Rect.fromLTWH(40, 40, 120, 80),
  style: 'shape=rhombus;fillColor=#fff2cc;strokeColor=#d6b656;',
  label: 'Decision',
);
controller.addElement(shape);
```

Supported MVP shapes include rhombus, triangle, hexagon, cylinder,
doubleEllipse, actor, cloud, swimlane, document, note, parallelogram,
trapezoid, callout, plus, cross, step, and cube. See
[docs/drawio_shapes.md](docs/drawio_shapes.md) for the full list and style
compatibility notes.

## Export

```dart
final json = CanvasSerializer.toJson(canvasController);
final svg = SvgExporter.exportElements(elements: canvasController.elements);
final png = await PngExporter.exportElements(
  elements: canvasController.elements,
);
```
