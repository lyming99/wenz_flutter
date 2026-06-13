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

Basic MVP:

- rectangle, roundedRectangle, ellipse
- rhombus, triangle, hexagon
- plus, cross

Official Basic stencil library (`basic.*`, with `mxgraph.basic.*` aliases):

- 4 Point Star, 6 Point Star, 8 Point Star
- Banner, Cloud Callout, Cloud Rect
- Cone, Cross, Document, Flash, Half Circle, Heart
- Loud Callout, Moon, No Symbol, Octagon, Orthogonal Triangle
- Oval Callout, Parallelepiped, Pentagon, Pointed Oval
- Rectangular Callout, Rounded Rectangular Callout
- Smiley, Star, Sun, Tick, Trapezoid, Wave, X

Official Arrows stencil library (`arrows.*`, with `mxgraph.arrows.*` aliases) contains draw.io block-arrow shapes. These are fillable vertex shapes, separate from ArrowElement connector arrows:

- Arrow Down, Arrow Left, Arrow Right, Arrow Up
- Bent Left Arrow, Bent Right Arrow, Bent Up Arrow
- Callout Double Arrow, Callout Quad Arrow, Callout Up Arrow
- Chevron Arrow, Circular Arrow
- Jump-in Arrow 1, Jump-in Arrow 2
- Left and Up Arrow, Left Sharp Edged Head Arrow
- Notched Signal-in Arrow, Right Notched Arrow, Signal-in Arrow
- Quad Arrow, Sharp Edged Arrow
- Slender Left Arrow, Slender Two Way Arrow, Slender Wide Tailed Arrow
- Striped Arrow, Stylised Notched Arrow, Triad Arrow
- Two Way Arrow Horizontal, Two Way Arrow Vertical
- U Turn Arrow, U Turn Down Arrow, U Turn Left Arrow, U Turn Right Arrow, U Turn Up Arrow

Flowchart:

- parallelogram, trapezoid
- document, step
- cylinder, doubleEllipse

Container and diagram shapes:

- swimlane, note, callout
- actor, cloud
- cube, isoRectangle alias

Draw.io aliases currently include rect, process, rounded, circle, diamond, manualInput, cylinder3, isoRectangle, `mxgraph.flowchart.*`, `mxgraph.basic.*`, and `mxgraph.arrows.*` (camelCase, snake_case, and kebab-case variants where applicable).

## Style Compatibility

The draw.io style parser supports key=value; pairs and bare keys. Common fields include shape, rounded, whiteSpace, html, fillColor, strokeColor, strokeWidth, dashed, direction, arcSize, opacity, fillOpacity, strokeOpacity, fontColor, fontSize, fontStyle, align, and spacing fields.

`fillColor=none` disables fill. `strokeColor=none` disables stroke. Unknown fields are preserved in the element properties so later import/export work can keep them available.

## Example Palette

The example app includes a left palette with Basic, Basic Symbols, Flowchart, Arrows, and Container groups. Selecting an entry activates ShapeTool for that shape; dragging on the canvas creates the matching DrawioShapeElement with the current brush fill and stroke.

## Visual Acceptance

Fixed-size examples are available in the example palette and in the shape rendering/SVG tests. For a manual pass, create each MVP shape at 120x80 and 160x100, then check fill, stroke, label placement, selection handles, snapping anchors, and SVG export.

Acceptance set:

- Basic MVP: rectangle, roundedRectangle, ellipse, rhombus, triangle, hexagon, plus, cross.
- Basic stencil library: all 30 `BasicStencils.keys` entries, with focused checks for Smiley, Sun, Cloud Callout, and No Symbol.
- Arrows stencil library: all 34 `ArrowStencils.keys` entries, including horizontal/vertical, U Turn, Circular, callout, and slender arrow variants.
- Flowchart: parallelogram, trapezoid, document, step, cylinder, doubleEllipse.
- Container and diagram shapes: swimlane, note, callout, actor, cloud, cube.
- Stencil subset: stencil.process, stencil.decision, stencil.document and the registered basic/flowchart static stencil entries.

The performance regression suite builds a 500-element mixed canvas with 125 DrawioShapeElement instances and verifies culling, serialization, hit testing, pan/zoom state changes, and selection movement.

## Deferred Items

Large vendor libraries such as AWS, Azure, GCP, Kubernetes, Cisco, and image-backed icon sets are deferred. Full .drawio round-trip compatibility is also deferred; the current layer focuses on stable shape creation, rendering, snapping, serialization, SVG export, and style-string bridging.
