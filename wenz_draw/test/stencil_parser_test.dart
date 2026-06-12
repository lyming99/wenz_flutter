import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/wenz_draw.dart';

void main() {
  const sample = '''
<shape name="sample" w="100" h="80" aspect="fixed" strokewidth="inherit">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="0.5" y="0.5" name="middle" perimeter="0"/>
  </connections>
  <background>
    <path>
      <move x="0" y="0"/>
      <line x="100" y="0"/>
      <quad x1="100" y1="40" x2="50" y2="80"/>
      <curve x1="30" y1="70" x2="0" y2="50" x3="0" y3="0"/>
      <close/>
    </path>
    <rect x="10" y="10" w="20" h="20"/>
    <roundrect x="40" y="10" w="20" h="20" arcsize="6"/>
    <ellipse x="70" y="10" w="20" h="20"/>
    <text x="0" y="0" w="100" h="20" str="Title" align="center"/>
  </background>
  <foreground>
    <path><move x="0" y="40"/><arc rx="20" ry="20" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="100" y="40"/></path>
  </foreground>
</shape>
''';

  test('parses supported drawio XML stencil commands and connections', () {
    final stencil = StencilParser.parse(sample);

    expect(stencil.name, 'sample');
    expect(stencil.width, 100);
    expect(stencil.height, 80);
    expect(stencil.aspect, StencilAspect.fixed);
    expect(stencil.background, hasLength(5));
    expect(stencil.foreground, hasLength(1));
    expect(stencil.connections, hasLength(2));
    expect(stencil.connections.last.perimeter, isFalse);
    expect(stencil.background.first, isA<StencilPathCommand>());
  });

  test(
    'fixed aspect stencils are centered and direction can rotate output',
    () {
      final stencil = StencilParser.parse(sample);
      final rect = const Rect.fromLTWH(0, 0, 200, 200);
      final path = StencilRenderer.buildPath(stencil, rect, const {});
      final bounds = path.getBounds();

      expect(bounds.left, closeTo(0, 0.01));
      expect(bounds.top, closeTo(20, 0.01));
      expect(bounds.right, closeTo(200, 0.01));
      expect(bounds.bottom, closeTo(180, 0.01));

      final northPath = StencilRenderer.buildPath(stencil, rect, const {
        'direction': 'north',
      });
      expect(northPath.getBounds().width, closeTo(160, 0.01));
      expect(northPath.getBounds().height, closeTo(200, 0.01));
    },
  );

  test(
    'renderer exposes connection points to shape registry and snap resolver',
    () {
      final stencil = StencilParser.parse(sample);
      final definition = StencilRenderer.shapeDefinitionFor(stencil);
      final points = definition.connectionPointsFor(
        const Rect.fromLTWH(10, 20, 100, 80),
        const {},
      );

      expect(
        points.map((point) => point.anchorId),
        containsAll(['center', 'top', 'middle']),
      );
      expect(points.first.position, const Offset(60, 60));

      ShapeDefinitionRegistry.register(definition);
      const element = DrawioShapeElement(
        id: 'stencil-1',
        shapeKey: 'sample',
        rect: Rect.fromLTWH(10, 20, 100, 80),
      );
      final snapPoints = const SnapResolver()
          .pointsForElement(element)
          .toList();
      expect(snapPoints.map((point) => point.anchorId), contains('top'));
      expect(snapPoints.map((point) => point.anchorId), contains('middle'));
    },
  );

  test('built-in stencils register at least ten static shapes', () {
    ensureDrawioShapeDefinitionsRegistered();

    expect(BuiltinStencils.definitions.length, greaterThanOrEqualTo(10));
    for (final stencil in BuiltinStencils.definitions) {
      final definition = ShapeDefinitionRegistry.definitionFor(stencil.name);
      final rect = const Rect.fromLTWH(0, 0, 120, 80);
      expect(definition.pathFor(rect, const {}).getBounds().isEmpty, isFalse);
      expect(definition.svgPathFor(rect, const {}), isNotEmpty);
    }
  });
}
