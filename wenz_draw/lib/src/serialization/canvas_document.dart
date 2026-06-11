import '../elements/canvas_element.dart';
import '../layers/canvas_layer.dart';

class CanvasDocument {
  const CanvasDocument({
    this.version = '1.0',
    this.layers = const <CanvasLayer>[],
    this.elements = const <CanvasElement>[],
  });

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
