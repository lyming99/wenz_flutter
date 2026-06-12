import '../elements/shape_definition_registry.dart';
import 'stencil_definition.dart';
import 'stencil_parser.dart';
import 'stencil_renderer.dart';

class BuiltinStencils {
  const BuiltinStencils._();

  static final Map<String, StencilDefinition> _definitions = {
    for (final xml in _xmlDefinitions)
      StencilParser.parse(xml).name: StencilParser.parse(xml),
  };

  static Iterable<StencilDefinition> get definitions => _definitions.values;

  static StencilDefinition? definitionFor(String key) => _definitions[key];

  static void registerAll() {
    for (final definition in definitions) {
      ShapeDefinitionRegistry.register(
        StencilRenderer.shapeDefinitionFor(definition),
        aliases: ['stencil.${definition.name}'],
      );
    }
  }
}

const List<String> _xmlDefinitions = [
  '''
<shape name="stencil.process" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><rect x="0" y="0" w="120" h="80"/></background>
</shape>
''',
  '''
<shape name="stencil.roundedProcess" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><roundrect x="0" y="0" w="120" h="80" arcsize="12"/></background>
</shape>
''',
  '''
<shape name="stencil.decision" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="60" y="0"/><line x="120" y="40"/><line x="60" y="80"/><line x="0" y="40"/><close/></path></background>
</shape>
''',
  '''
<shape name="stencil.terminator" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><roundrect x="0" y="0" w="120" h="80" arcsize="40"/></background>
</shape>
''',
  '''
<shape name="stencil.data" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="20" y="0"/><line x="120" y="0"/><line x="100" y="80"/><line x="0" y="80"/><close/></path></background>
</shape>
''',
  '''
<shape name="stencil.document" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="0" y="0"/><line x="120" y="0"/><line x="120" y="66"/><quad x1="90" y1="82" x2="60" y2="66"/><quad x1="30" y1="50" x2="0" y2="66"/><close/></path></background>
</shape>
''',
  '''
<shape name="stencil.preparation" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="20" y="0"/><line x="100" y="0"/><line x="120" y="40"/><line x="100" y="80"/><line x="20" y="80"/><line x="0" y="40"/><close/></path></background>
</shape>
''',
  '''
<shape name="stencil.manualInput" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="0" y="20"/><line x="120" y="0"/><line x="120" y="80"/><line x="0" y="80"/><close/></path></background>
</shape>
''',
  '''
<shape name="stencil.database" w="120" h="90" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background>
    <path><move x="0" y="15"/><curve x1="0" y1="-5" x2="120" y2="-5" x3="120" y3="15"/><line x="120" y="75"/><curve x1="120" y1="95" x2="0" y2="95" x3="0" y3="75"/><close/></path>
  </background>
  <foreground><path><move x="0" y="15"/><curve x1="0" y1="35" x2="120" y2="35" x3="120" y3="15"/></path></foreground>
</shape>
''',
  '''
<shape name="stencil.cloud" w="120" h="80" aspect="variable">
  <connections>
    <constraint x="0.5" y="0" name="top" perimeter="1"/>
    <constraint x="1" y="0.5" name="right" perimeter="1"/>
    <constraint x="0.5" y="1" name="bottom" perimeter="1"/>
    <constraint x="0" y="0.5" name="left" perimeter="1"/>
  </connections>
  <background><path><move x="30" y="66"/><curve x1="-6" y1="62" x2="5" y2="30" x3="34" y3="34"/><curve x1="34" y1="6" x2="82" y2="2" x3="86" y3="30"/><curve x1="126" y1="30" x2="122" y2="70" x3="78" y3="67"/><close/></path></background>
</shape>
''',
];
