# wenz_draw Extension API

## Custom Elements

Create a `CanvasElement` subclass and an `ElementRenderer<T>`, then register it:

```dart
ElementRendererRegistry.register<MyElement>('my-element', MyElementRenderer());
```

The element should be immutable, implement `copyWith`, `translate`,
`scaleElement`, `hitTest`, and `toJson`.

## Custom Tools

Create a `CanvasTool` subclass and register it on a controller:

```dart
final controller = CanvasController();
controller.toolManager.registerTool(MyTool());
controller.setTool('my-tool');
```

Tools receive normalized `CanvasEvent` objects with both screen and world
coordinates. Return `ToolResultElement` to commit a new element,
`ToolResultPreview` for transient drawing, or mutate the controller directly for
advanced interactions.

## Custom Widgets

Register a `WidgetElementBuilder` for each `CanvasWidgetElement.widgetType`,
then add `CanvasWidgetElement` instances to the canvas:

```dart
class CounterButtonBuilder extends WidgetElementBuilder {
  const CounterButtonBuilder();

  @override
  Widget build(
    BuildContext context,
    CanvasWidgetElement element, {
    required CanvasWidgetBuildContext canvas,
  }) {
    final count = element.widgetData['count'] as int? ?? 0;
    return FilledButton(
      onPressed: () {
        canvas.updateProps(element.id, {
          ...element.widgetData,
          'count': count + 1,
        });
      },
      child: Text('Count: $count'),
    );
  }
}

WidgetElementRegistry.register(
  'counter_button',
  const CounterButtonBuilder(),
);

controller.addElement(
  const CanvasWidgetElement(
    id: 'counter-1',
    worldRect: Rect.fromLTWH(120, 80, 160, 64),
    widgetType: 'counter_button',
    widgetData: {'count': 0},
  ),
);
```

`CanvasWidgetElement` participates in selection, movement, history, layer
visibility, JSON serialization, and export placeholders. When the select tool is
active, interactive widget elements can receive pointer events. Drawing and pan
tools cause the widget layer to ignore pointer events so the canvas can handle
the gesture.

Use `CanvasWidgetScaleMode.layoutScale`, `paintScale`, or `fixedScreenSize` to
choose how widgets respond to zoom.

## Export

Use `CanvasSerializer.toJson(controller)` for JSON, `PngExporter` for raster
output, and `SvgExporter` for vector output.
