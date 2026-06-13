import '../../elements/shape_definition_registry.dart';
import '../stencil_definition.dart';
import '../stencil_parser.dart';
import '../stencil_renderer.dart';

class StencilLibraryRegistry {
  const StencilLibraryRegistry._();

  static void registerXmlDefinitions(
    Iterable<String> xmlDefinitions, {
    Map<String, List<String>> aliases = const {},
  }) {
    for (final xml in xmlDefinitions) {
      final definition = StencilParser.parse(xml);
      registerDefinition(
        definition,
        aliases: aliases[definition.name] ?? const [],
      );
    }
  }

  static void registerDefinition(
    StencilDefinition definition, {
    List<String> aliases = const [],
  }) {
    ShapeDefinitionRegistry.register(
      StencilRenderer.shapeDefinitionFor(definition),
      aliases: aliases,
    );
  }
}
