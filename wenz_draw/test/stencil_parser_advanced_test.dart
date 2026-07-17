import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_draw/src/stencils/stencil_parser.dart';
import 'package:wenz_draw/src/stencils/stencil_definition.dart';

/// Helper to wrap foreground commands in a full shape XML document.
String _shapeXml(String foregroundXml, {String backgroundXml = ''}) {
  return '''
<shape name="test.shape" w="100" h="100" aspect="variable" strokewidth="inherit">
<connections>
<constraint x="0.5" y="0" perimeter="1" name="N" />
<constraint x="0.5" y="1" perimeter="1" name="S" />
<constraint x="0" y="0.5" perimeter="1" name="W" />
<constraint x="1" y="0.5" perimeter="1" name="E" />
</connections>
<background>
$backgroundXml
</background>
<foreground>
$foregroundXml
</foreground>
</shape>
''';
}

void main() {
  group('StencilParser advanced commands', () {
    // ─── dashpattern ──────────────────────────────────────────────
    test('dashpattern parses pattern string', () {
      final xml = _shapeXml('<dashpattern pattern="5 3 2 3" />');

      final stencil = StencilParser.parse(xml);

      expect(stencil.foreground, hasLength(1));
      final cmd = stencil.foreground.single;
      expect(cmd, isA<StencilDashPatternCommand>());
      final dash = cmd as StencilDashPatternCommand;
      expect(dash.pattern, '5 3 2 3');
    });

    // ─── shadow ───────────────────────────────────────────────────
    test('shadow parses all fields', () {
      final xml = _shapeXml(
        '<shadow dx="3" dy="3" blur="5" color="#888888" opacity="0.6" />',
      );

      final stencil = StencilParser.parse(xml);

      expect(stencil.foreground, hasLength(1));
      final cmd = stencil.foreground.single;
      expect(cmd, isA<StencilShadowCommand>());
      final shadow = cmd as StencilShadowCommand;
      expect(shadow.dx, 3);
      expect(shadow.dy, 3);
      expect(shadow.blur, 5);
      expect(shadow.color, '#888888');
      expect(shadow.opacity, 0.6);
    });

    // ─── gradient ─────────────────────────────────────────────────
    test('gradient parses all fields', () {
      final xml = _shapeXml(
        '<gradient x1="0" y1="0" x2="1" y2="1" c1="#FF0000" c2="#0000FF" direction="south" />',
      );

      final stencil = StencilParser.parse(xml);

      expect(stencil.foreground, hasLength(1));
      final cmd = stencil.foreground.single;
      expect(cmd, isA<StencilGradientCommand>());
      final gradient = cmd as StencilGradientCommand;
      expect(gradient.x1, 0);
      expect(gradient.y1, 0);
      expect(gradient.x2, 1);
      expect(gradient.y2, 1);
      expect(gradient.color1, '#FF0000');
      expect(gradient.color2, '#0000FF');
      expect(gradient.direction, 'south');
    });

    // ─── Combined commands ───────────────────────────────────────
    test('combined foreground with save/dashpattern/stroke/restore', () {
      final xml = _shapeXml(
        '<save />\n'
        '<dashpattern pattern="5 3" />\n'
        '<stroke />\n'
        '<restore />',
      );

      final stencil = StencilParser.parse(xml);

      expect(stencil.foreground, hasLength(4));
      expect(stencil.foreground[0], isA<StencilSaveCommand>());
      expect(stencil.foreground[1], isA<StencilDashPatternCommand>());
      expect(
        (stencil.foreground[1] as StencilDashPatternCommand).pattern,
        '5 3',
      );
      expect(stencil.foreground[2], isA<StencilStrokeCommand>());
      expect(stencil.foreground[3], isA<StencilRestoreCommand>());
    });

    // ─── Default values ──────────────────────────────────────────
    test('shadow with no attributes uses defaults', () {
      final xml = _shapeXml('<shadow />');

      final stencil = StencilParser.parse(xml);

      expect(stencil.foreground, hasLength(1));
      final cmd = stencil.foreground.single;
      expect(cmd, isA<StencilShadowCommand>());
      final shadow = cmd as StencilShadowCommand;
      expect(shadow.dx, 2);
      expect(shadow.dy, 2);
      expect(shadow.blur, 4);
      expect(shadow.color, 'gray');
      expect(shadow.opacity, 0.5);
    });
  });
}
