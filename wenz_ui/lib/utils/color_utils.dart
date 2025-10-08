import 'dart:ui';

class ColorUtils {
  ColorUtils._();

  static Color additionColor(Color color, int addition) {
    var r = color.red + addition;
    var g = color.green + addition;
    var b = color.blue + addition;
    var a = color.alpha;
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    return Color.fromARGB(a, r, g, b);
  }
}
