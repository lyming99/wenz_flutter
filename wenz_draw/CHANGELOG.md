## 0.1.0

- Initial package scaffold.
- Added draw.io-style shape support: DrawioShapeElement, ShapeDefinitionRegistry,
  built-in MVP shapes, draw.io style parsing/import helpers, stencil subset support,
  snap/perimeter integration, ShapeTool palette entry points, and SVG export for
  drawio/stencil-backed shapes.
- Added performance and regression coverage for 500-element mixed canvases with
  DrawioShapeElement instances, viewport culling, label editing, serialization,
  snapping, routing, style import, and XML stencil parsing.
- Public exports now include the draw.io shape, style, importer, stencil, registry,
  connection-point, and ShapeTool APIs while keeping the existing RectElement,
  EllipseElement, line, polyline, arrow, text, image, and widget APIs intact.
- Documented supported MVP shapes, style compatibility, example palette usage,
  visual fixture expectations, and deferred vendor/icon library scope.
