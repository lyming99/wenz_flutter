import 'drawio_style.dart';

class DrawioStyleParser {
  const DrawioStyleParser._();

  static DrawioStyle parse(String style) {
    final values = <String, String>{};
    final flags = <String>{};

    for (final token in style.split(';')) {
      final part = token.trim();
      if (part.isEmpty) {
        continue;
      }
      final separator = part.indexOf('=');
      if (separator < 0) {
        flags.add(part);
        continue;
      }
      final key = part.substring(0, separator).trim();
      if (key.isEmpty) {
        continue;
      }
      values[key] = part.substring(separator + 1).trim();
    }

    return DrawioStyle(
      raw: style,
      values: Map<String, String>.unmodifiable(values),
      flags: Set<String>.unmodifiable(flags),
    );
  }
}
