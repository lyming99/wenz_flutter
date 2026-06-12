# Draw.io Shapes

wenz_draw exposes a DrawioShapeElement layer for common draw.io-style vertex shapes. The shape model is intended to coexist with existing RectElement and EllipseElement APIs while giving draw.io imports, palettes, and stencil-backed shapes a shared path.

## Creating Shapes In Code

Use ShapeTool when the user should drag a shape onto the canvas:

```dart
final controller = CanvasController();
controller.setTool(ShapeTool.idFor('rhombus'));
```

For direct construction, create a DrawioShapeElement:

```dart
controller.addElement(
  DrawioShapeElement(
    id: 'decision-1',
    shapeKey: 'rhombus',
    rect: const Rect.fromLTWH(80, 80, 160, 100),
    strokeStyle: const PaintStyle(color: Color(0xFF0F172A)),
    fillStyle: const PaintStyle(
      color: Color(0xFFE0F2FE),
      paintingStyle: PaintingStyle.fill,
    ),
    label: 'Decision',
  ),
);
```

You can also bridge draw.io style strings:

```dart
final element = DrawioShapeAdapter.fromStyleString(
  id: 'shape-1',
  rect: const Rect.fromLTWH(40, 40, 120, 80),
  style: 'shape=rhombus;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=2;',
  label: 'Decision',
);
```

## Supported Built-in Shapes

Basic:

- rectangle, roundedRectangle, ellipse
- rhombus, triangle, hexagon
- plus, cross

Flowchart:

- parallelogram, trapezoid
- document, step
- cylinder, doubleEllipse

Container and diagram shapes:

- swimlane, note, callout
- actor, cloud
- cube, isoRectangle alias

Draw.io aliases currently include rect, process, rounded, circle, diamond, manualInput, cylinder3, and isoRectangle.

## Style Compatibility

The draw.io style parser supports key=value; pairs and bare keys. Common fields include shape, rounded, whiteSpace, html, fillColor, strokeColor, strokeWidth, dashed, direction, arcSize, opacity, fillOpacity, strokeOpacity, fontColor, fontSize, fontStyle, align, and spacing fields.

`fillColor=none` disables fill. `strokeColor=none` disables stroke. Unknown fields are preserved in the element properties so later import/export work can keep them available.

## Example Palette

The example app includes a left palette with Basic, Flowchart, and Container groups. Selecting an entry activates ShapeTool for that shape; dragging on the canvas creates the matching DrawioShapeElement with the current brush fill and stroke.

## Visual Acceptance

Fixed-size examples are available in the example palette and in the shape rendering/SVG tests. For a manual pass, create each MVP shape at 120x80 and 160x100, then check fill, stroke, label placement, selection handles, snapping anchors, and SVG export.

Acceptance set:

- Basic: rectangle, roundedRectangle, ellipse, rhombus, triangle, hexagon, plus, cross.
- Flowchart: parallelogram, trapezoid, document, step, cylinder, doubleEllipse.
- Container and diagram shapes: swimlane, note, callout, actor, cloud, cube.
- Stencil subset: stencil.process, stencil.decision, stencil.document and the registered basic/flowchart static stencil entries.

The performance regression suite builds a 500-element mixed canvas with 125 DrawioShapeElement instances and verifies culling, serialization, hit testing, pan/zoom state changes, and selection movement.

## Deferred Items

Large vendor libraries such as AWS, Azure, GCP, Kubernetes, Cisco, and image-backed icon sets are deferred. Full .drawio round-trip compatibility is also deferred; the current layer focuses on stable shape creation, rendering, snapping, serialization, SVG export, and style-string bridging.
