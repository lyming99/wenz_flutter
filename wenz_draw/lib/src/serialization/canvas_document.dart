import '../elements/canvas_element.dart';
import '../layers/canvas_layer.dart';

class CanvasDocument {
  const CanvasDocument({
    this.version = currentVersion,
    this.layers = const <CanvasLayer>[],
    this.elements = const <CanvasElement>[],
  });

  static const currentVersion = '1.1';

  final String version;
  final List<CanvasLayer> layers;
  final List<CanvasElement> elements;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'layers': [for (final layer in layers) layer.toJson()],
      'elements': [for (final element in elements) element.toJson()],
    };
  }
}
