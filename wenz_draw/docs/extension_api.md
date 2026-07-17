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

## Custom Image Loaders

An `ImageElement` can reference its raster three ways: an in-memory `ui.Image`,
an inline `imageData` base64 string, or a deferred source (`url` / `filePath` /
`assetId`). After a save/load round-trip the in-memory image is gone, so the SDK
re-decodes it through the controller's `ImageLoaderRegistry`:

```dart
// The bundled CanvasImageResolver (created by InfiniteCanvasWidget) watches the
// controller and re-decodes any ImageElement whose image is null. Built-in
// loaders cover base64 and raw bytes.
```

To fetch images from your own backend (an OSS bucket, a database, a signed CDN),
implement `ImageLoader` and register it:

```dart
class OssImageLoader extends ImageLoader {
  @override
  bool supports(ImageSource source) => source.url?.startsWith('https://oss.') ?? false;

  @override
  Future<ui.Image> load(ImageSource source) async {
    final bytes = await myOssClient.fetchBytes(source.url!);
    return decodeBytes(bytes, maxWidth: source.maxWidth);
  }
}

// Register once per controller (or on the shared registry):
controller.imageLoaders.register(OssImageLoader());
```

Then create the element with that source — the resolver fetches and decodes it
on demand, and the JSON only stores the URL, keeping documents small:

```dart
controller.addElement(ImageElement(
  id: 'photo-1',
  rect: Rect.fromLTWH(40, 40, 320, 240),
  url: 'https://oss.example.com/photo.png',
));
```

## Embedding The Canvas (Headless Kernel)

Hosts that build their own UI import only `package:wenz_draw/wenz_draw.dart`
and embed `InfiniteCanvasWidget` directly — no toolbar, panels, or inspector:

```dart
import 'package:wenz_draw/wenz_draw.dart';

final canvas = CanvasController();
final view = InfiniteCanvasController(
  canvasController: canvas,
  minScale: 0.25,
  maxScale: 6.0,
);

InfiniteCanvasWidget(
  controller: view,
  config: const InfiniteCanvasConfig(gridType: GridType.dots),
);
```

### Gesture & Zoom Configuration

`InfiniteCanvasConfig` exposes every gesture as a toggle, plus zoom bounds and
fling tuning. All flags default to enabled, so a config-less canvas already
works on both desktop and mobile:

| Flag | Default | Effect |
|------|---------|--------|
| `enablePinch` | `true` | Two-finger pinch-to-zoom (mobile) |
| `enableWheelZoom` | `true` | Mouse/trackpad wheel zoom (desktop) |
| `enableKeyboard` | `true` | Undo/redo, select-all, arrow nudge, delete, clipboard |
| `enableDoubleTapZoom` | `true` | Double-tap zooms in (shift/alt = out) |
| `flingEnabled` | `true` | Released pan continues with inertia (mobile feel) |
| `flingDecayFriction` | `0.005` | Higher = fling stops sooner |
| `minScale` / `maxScale` | `0.1` / `10.0` | Zoom clamp; mirror on the controller ctor |

The `InfiniteCanvasController` clamps zoom to its own `minScale`/`maxScale`.
When you pass a custom `InfiniteCanvasConfig.minScale`, set the same values on
the controller constructor so wheel, pinch, and double-tap all agree:

```dart
const cfg = InfiniteCanvasConfig(minScale: 0.5, maxScale: 4.0);
final view = InfiniteCanvasController(
  canvasController: canvas,
  minScale: cfg.minScale,
  maxScale: cfg.maxScale,
);
```

`ZoomControls` (the zoom in/out/fit pill) and `MinimapWidget` are exported
separately and can be embedded into a host's own chrome without the full
editor.

### Viewport Persistence

The current pan/zoom round-trips through `DocumentViewport`. Capture it on save
and restore on load so a reopened board lands where the user left off:

```dart
final json = CanvasSerializer.toJsonWithView(view, viewport: view.currentViewport);
await store.save(json);
// ... later, into fresh controllers ...
CanvasSerializer.loadDocument(view, await store.load()!);
// loadDocument applies the viewport, but only once the widget has a size;
// if you load before mount, call view.applyViewport(document.viewport) in a
// post-frame callback.
```

## Embedding The Editor (UI Shell)

For the fastest integration, import `package:wenz_draw/wenz_draw_ui.dart` and
embed `WenzDrawEditor`. It composes a toolbar, a shape palette, the canvas, and
an inspector — all configurable:

```dart
import 'package:wenz_draw/wenz_draw.dart';
import 'package:wenz_draw/wenz_draw_ui.dart';

WenzDrawEditor(
  canvasController: canvas,
  viewController: view,
  config: EditorConfig(
    showRightPanel: true,
    contentCallbacks: EditorContentCallbacks(
      onInsertImage: myImagePicker,
      onAddMindmap: myAddMindmap,
      // Persistence: the 菜单's 保存/加载 route through this store.
      documentStore: myDocumentStore,
      // PNG export override (defaults to the bundled PngExporter).
      onExportPng: myPngExporter,
    ),
    // Host-contributed toolbar buttons rendered in the trailing cluster.
    toolbarActions: const [
      EditorToolbarAction(label: 'Share', icon: Icons.share, onPressed: share),
    ],
    // Tune the canvas's gestures/grid (passed through to InfiniteCanvasWidget).
    canvasConfig: const InfiniteCanvasConfig(flingEnabled: true),
  ),
  theme: EditorTheme.light,
)
```

### Customizing Panels And Toolbar

`EditorConfig` exposes four layers of customization:

1. **Toggles** — `showLeftPanel`, `showRightPanel`, `leftPanelWidth`, …
2. **Slot replacement** — `leftPanelBuilder`, `rightPanelBuilder`,
   `toolbarBuilder` fully replace a region with your own widget.
3. **Toolbar actions** — `toolbarActions` appends host buttons to the default
   toolbar's trailing cluster (no need to replace the whole toolbar).
4. **Inspector sections** — modules contribute their own inspector controls via
   `InspectorSectionRegistry.register(...)` without the shell importing them.

```dart
// A module ships an inspector for its custom element type:
class TodoInspector extends InspectorSectionBuilder {
  @override
  bool matches(CanvasController c, CanvasElement? e) => e is TodoElement;

  @override
  Widget? build(BuildContext ctx, CanvasController c, CanvasElement e) =>
      TodoEditor(element: e as TodoElement);
}

InspectorSectionRegistry.register(TodoInspector());
```

The default right panel walks every registered builder in order and embeds the
returned widget as a section. This keeps the dependency direction one-way:
modules depend on the shell, never the reverse.

## Document Format (Schema 2.0)

Serialized documents are forward- and backward-compatible:

```json
{
  "schemaVersion": "2.0",
  "metadata": { "title": "...", "appId": "...", "createdAt": 1700000000000 },
  "viewport": { "scale": 1.5, "centerX": 100, "centerY": 200 },
  "assets": [ { "id": "a1", "type": "image", "source": "url", "ref": "..." } ],
  "layers": [ ... ],
  "elements": [ ... ]
}
```

- **Migration**: `DocumentMigrator` upgrades older documents (`version` →
  `schemaVersion`) automatically on load, seeding the optional
  metadata/viewport/assets sections. Version-less documents are treated as
  current; future/unknown versions pass through untouched to avoid corruption.
- **Unknown elements**: an element whose `type` the loader doesn't recognize is
  preserved as `UnknownElement` — its original JSON is written back verbatim, so
  a round-trip through an older app never loses data written by a newer one.
- **Unknown top-level keys**: preserved in `CanvasDocument.extras` and re-emitted
  on save.
- **Metadata / viewport / assets**: optional sections passed through
  `CanvasSerializer.toJson(controller, metadata: ..., viewport: ..., assets: ...)`.

### Load Fault Tolerance

The loader never lets one bad element sink a whole document. Parse with
`fromJsonWithWarnings` to collect recoverable problems as
`DocumentFormatWarning`s — each malformed element is downgraded to an
`UnknownElement` (raw JSON kept) and loading continues:

```dart
final result = CanvasSerializer.fromJsonWithWarnings(json, onWarning: (w) {
  myLogger.warn('${w.elementType ?? '?'} ${w.elementId ?? '?'}: ${w.message}');
});
final document = result.document;          // always usable
if (result.hasWarnings) {
  showToast('${result.warnings.length} 个元素已跳过/降级');
}
```

Structural problems that make the document unusable (empty JSON, `layers` /
`elements` not arrays) throw `DocumentFormatException` with
`severity: fatal` — catch and show an error. A JSON Schema describing the
format lives at `docs/canvas_document.schema.json` for host-side validation
(e.g. with `ajv`).

### Write Validation

Before persisting, run `CanvasSerializer.validateForSave(json)` for a
non-throwing health check. It flags missing ids and negative rects as
recoverable warnings you can log or reject:

```dart
final warnings = CanvasSerializer.validateForSave(json);
if (warnings.isNotEmpty) {
  for (final w in warnings) myLogger.warn(w.toString());
  // optionally abort: throw w.toException();
}
await store.save(json);
```

## Mind Map Module

The mind map module (`package:wenz_draw/wenz_draw_mindmap.dart`) is optional.
Register it once at startup — it installs a `WidgetElementBuilder` for
`mindmap_node` elements and wires up a host-supplied link opener (the SDK does
not depend on platform plugins):

```dart
import 'package:wenz_draw/wenz_draw_mindmap.dart';

void main() {
  registerMindmapModule(linkOpener: const UrlLauncherLinkOpener());
  runApp(const MyApp());
}
```

Each mind map is a forest of `CanvasWidgetElement`s linked by `parentId`; the
tree is rebuilt on demand. `MindmapActions` (attached per controller) handles
add/delete/collapse/reparent and triggers `MindmapLayoutEngine` re-layouts.
`MindmapSyncController` keeps a live canvas consistent (drag-following, auto
re-layout). Hosts that don't need mind maps simply never call
`registerMindmapModule`.
