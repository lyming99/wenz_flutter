# wenz_draw TODO

## Phase 1: Infinite Canvas Skeleton

- [x] P1-1 CanvasTransform immutable data structure and coordinate conversion.
- [x] P1-2 CanvasState immutable state model.
- [x] P1-3 InfiniteCanvasController view transform and coordinate conversion.
- [x] P1-4 InfiniteCanvasPainter CustomPainter baseline rendering.
- [x] P1-5 Adaptive grid background renderer.
- [x] P1-6 InfiniteCanvasWidget with gesture handling.
- [x] P1-7 Basic gesture resolver for pan, pinch zoom, and wheel zoom.
- [x] P1-8 Public exports in `wenz_draw.dart`.
- [x] P1-9 Add `uuid` dependency to `pubspec.yaml`.

## Phase 2: Drawing Basics

- [x] P2-1 CanvasElement abstract base and immutable copy patterns.
- [x] P2-2 ElementRenderer interface and registry.
- [x] P2-3 PathElement and renderer.
- [x] P2-4 LineElement and renderer.
- [x] P2-5 RectElement and renderer.
- [x] P2-6 EllipseElement and renderer.
- [x] P2-7 CanvasTool interface and ToolResult sealed classes.
- [x] P2-8 ToolManager.
- [x] P2-9 PenTool with path simplification hook.
- [x] P2-10 LineTool, RectTool, and EllipseTool.
- [x] P2-11 CanvasController element CRUD and tool coordination.
- [x] P2-12 Drag preview rendering.
- [x] P2-13 Viewport culling helper.

## Phase 3: Interaction Enhancements

- [x] P3 selection manager and selected bounds rendering.
- [x] P3 select tool with point select, marquee select, and move.
- [x] P3 arrow, text, eraser, and highlighter tools.
- [x] P3 keyboard shortcuts for select all, delete, undo, and redo.

## Phase 4: Layers, History, and Performance

- [x] P4 HistoryManager and command objects.
- [x] P4 add, remove, update, move, and batch commands.
- [x] P4 undo/redo integrated into CanvasController and example.
- [x] P4 CanvasLayer and LayerManager.
- [x] P4 layer visibility and active-layer insertion.
- [x] P4 QuadTree and SpatialIndex-backed viewport culling.
- [x] P4 pointer interaction cancellation and move throttling-ready path.

## Phase 5: Advanced Features

- [x] P5 ImageElement model and renderer placeholder/image rendering.
- [x] P5 JSON serializer and CanvasDocument model.
- [x] P5 MinimapWidget.
- [x] P5 ZoomControls and zoomToFit support.
- [x] P5 example integration for minimap and layer controls.

## Phase 6: Extension and Release Surface

- [x] P6 custom tool and element registration API.
- [x] P6 PNG exporter.
- [x] P6 SVG exporter.
- [x] P6 web and Windows example scaffolding.
- [x] P6 extension API documentation.
- [x] P6 unit and widget tests.

## Phase 7: Custom Widget Embedding

- [x] W1 CanvasWidgetElement data model with serialization fields.
- [x] W1 WidgetElementBuilder and WidgetElementRegistry APIs.
- [x] W2 CanvasWidgetLayer Stack overlay for embedded Flutter widgets.
- [x] W2 InfiniteCanvasWidget integration with CustomPaint + Widget layer.
- [x] W3 Pointer conflict handling between canvas tools and embedded widgets.
- [x] W4 Example app with sticky note and counter widget builders.
- [x] W5 Export placeholders for widget elements in PNG/SVG.
- [x] W5 Unit tests for widget element serialization and registry behavior.
