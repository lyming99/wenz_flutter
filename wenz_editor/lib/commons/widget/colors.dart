import 'dart:ui';

import 'package:flutter/foundation.dart';

class AccentColor {
  final String primary;

  final Map<String, Color> swatch;

  AccentColor(this.primary, this.swatch);

  AccentColor.swatch(this.swatch) : primary = 'normal';

  Color get darkest => swatch['darkest'] ?? darker.withValues(alpha: 0.7);

  Color get darker => swatch['darker'] ?? dark.withValues(alpha: 0.8);

  Color get dark => swatch['dark'] ?? normal.withValues(alpha: 0.9);

  Color get normal => swatch['normal']!;

  Color get light => swatch['light'] ?? normal.withValues(alpha: 0.9);

  Color get lighter => swatch['lighter'] ?? light.withValues(alpha: 0.8);

  Color get lightest => swatch['lightest'] ?? lighter.withValues(alpha: 0.7);

  static AccentColor lerp(AccentColor a, AccentColor b, double t) {
    final darkest = Color.lerp(a.darkest, b.darkest, t);
    final darker = Color.lerp(a.darker, b.darker, t);
    final dark = Color.lerp(a.dark, b.dark, t);
    final light = Color.lerp(a.light, b.light, t);
    final lighter = Color.lerp(a.lighter, b.lighter, t);
    final lightest = Color.lerp(a.lightest, b.lightest, t);

    return AccentColor.swatch({
      if (darkest != null) 'darkest': darkest,
      if (darker != null) 'darker': darker,
      if (dark != null) 'dark': dark,
      'normal': Color.lerp(a.normal, b.normal, t)!,
      if (light != null) 'light': light,
      if (lighter != null) 'lighter': lighter,
      if (lightest != null) 'lightest': lightest,
    });
  }

  Color defaultBrushFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return lighter;
    } else {
      return dark;
    }
  }

  Color secondaryBrushFor(Brightness brightness) {
    return defaultBrushFor(brightness).withValues(alpha: 0.9);
  }

  Color tertiaryBrushFor(Brightness brightness) {
    return defaultBrushFor(brightness).withValues(alpha: 0.8);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AccentColor &&
        other.primary == primary &&
        mapEquals(other.swatch, swatch);
  }

  @override
  int get hashCode => primary.hashCode ^ swatch.hashCode;
}

class MyColors {
  static const Color transparent = Color(0x00000000);

  static const Color black = Color(0xFF000000);

  static const ShadedColor grey = ShadedColor(
    0xFF323130, // grey160
    <int, Color>{
      220: Color(0xFF11100F),
      210: Color(0xFF161514),
      200: Color(0xFF1B1A19),
      190: Color(0xFF201F1E),
      180: Color(0xFF252423),
      170: Color(0xFF292827),
      160: Color(0xFF323130),
      150: Color(0xFF3B3A39),
      140: Color(0xFF484644),
      130: Color(0xFF605E5C),
      120: Color(0xFF797775),
      110: Color(0xFF8A8886),
      100: Color(0xFF979593),
      90: Color(0xFFA19F9D),
      80: Color(0xFFB3B0AD),
      70: Color(0xFFBEBBB8),
      60: Color(0xFFC8C6C4),
      50: Color(0xFFD2D0CE),
      40: Color(0xFFE1DFDD),
      30: Color(0xFFEDEBE9),
      20: Color(0xFFF3F2F1),
      10: Color(0xFFFAF9F8),
    },
  );

  static const Color white = Color(0xFFFFFFFF);

  static final AccentColor yellow = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xfff9a825),
    'darker': Color(0xfffbc02d),
    'dark': Color(0xfffdd835),
    'normal': Color(0xffffeb3b),
    'light': Color(0xffffee58),
    'lighter': Color(0xfffff176),
    'lightest': Color(0xfffff59d),
  });

  static final AccentColor orange = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff993d07),
    'darker': Color(0xffac4508),
    'dark': Color(0xffd1540a),
    'normal': Color(0xfff7630c),
    'light': Color(0xfff87a30),
    'lighter': Color(0xfff99154),
    'lightest': Color(0xfffa9e68),
  });

  static final AccentColor red = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff8f0a15),
    'darker': Color(0xffa20b18),
    'dark': Color(0xffb90d1c),
    'normal': Color(0xffe81123),
    'light': Color(0xffec404f),
    'lighter': Color(0xffee5865),
    'lightest': Color(0xfff06b76),
  });

  static final AccentColor magenta = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff6f0061),
    'darker': Color(0xff7e006e),
    'dark': Color(0xff90007e),
    'normal': Color(0xffb4009e),
    'light': Color(0xffc333b1),
    'lighter': Color(0xffca4cbb),
    'lightest': Color(0xffd060c2),
  });

  static final AccentColor purple = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff472f68),
    'darker': Color(0xff513576),
    'dark': Color(0xff644293),
    'normal': Color(0xFF744da9),
    'light': Color(0xff8664b4),
    'lighter': Color(0xff9d82c2),
    'lightest': Color(0xffa890c9),
  });

  static final AccentColor blue = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff004a83),
    'darker': Color(0xff005494),
    'dark': Color(0xff0066b4),
    'normal': Color(0xff0078d4),
    'light': Color(0xff268cda),
    'lighter': Color(0xff4ca0e0),
    'lightest': Color(0xff60abe4),
  });

  static final AccentColor teal = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff006e5b),
    'darker': Color(0xff007c67),
    'dark': Color(0xff00977d),
    'normal': Color(0xff00b294),
    'light': Color(0xff26bda4),
    'lighter': Color(0xff4cc9b4),
    'lightest': Color(0xff60cfbc),
  });

  static final AccentColor green = AccentColor.swatch(const <String, Color>{
    'darkest': Color(0xff094c09),
    'darker': Color(0xff0c5d0c),
    'dark': Color(0xff0e6f0e),
    'normal': Color(0xff107c10),
    'light': Color(0xff278927),
    'lighter': Color(0xff4b9c4b),
    'lightest': Color(0xff6aad6a),
  });

  static const Color warningPrimaryColor = Color(0xFFd83b01);
  static final warningSecondaryColor = AccentColor.swatch(const <String, Color>{
    'dark': Color(0xFF433519),
    'normal': Color(0xFFfff4ce),
  });
  static const Color errorPrimaryColor = Color(0xFFa80000);
  static final errorSecondaryColor = AccentColor.swatch(const <String, Color>{
    'dark': Color(0xFF442726),
    'normal': Color(0xFFfde7e9),
  });
  static const Color successPrimaryColor = Color(0xFF107c10);
  static final successSecondaryColor = AccentColor.swatch(const <String, Color>{
    'dark': Color(0xFF393d1b),
    'normal': Color(0xFFdff6dd),
  });

  static final List<AccentColor> accentColors = [
    yellow,
    orange,
    red,
    magenta,
    purple,
    blue,
    teal,
    green,
  ];
}

@immutable
class ColorSwatch<T> extends Color {
  const ColorSwatch(super.primary, this._swatch);

  @protected
  final Map<T, Color> _swatch;

  Color? operator [](T key) => _swatch[key];

  Iterable<T> get keys => _swatch.keys;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return super == other &&
        other is ColorSwatch<T> &&
        mapEquals<T, Color>(other._swatch, _swatch);
  }

  @override
  int get hashCode => Object.hash(runtimeType, value, _swatch);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'ColorSwatch')}(primary value: ${super.toString()})';

  static ColorSwatch<T>? lerp<T>(
      ColorSwatch<T>? a, ColorSwatch<T>? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    final Map<T, Color> swatch;
    if (b == null) {
      swatch = a!._swatch.map(
        (T key, Color color) =>
            MapEntry<T, Color>(key, Color.lerp(color, null, t)!),
      );
    } else {
      if (a == null) {
        swatch = b._swatch.map(
          (T key, Color color) =>
              MapEntry<T, Color>(key, Color.lerp(null, color, t)!),
        );
      } else {
        swatch = a._swatch.map(
          (T key, Color color) =>
              MapEntry<T, Color>(key, Color.lerp(color, b[key], t)!),
        );
      }
    }
    return ColorSwatch<T>(Color.lerp(a, b, t)!.value, swatch);
  }
}

class ShadedColor extends ColorSwatch<int> {
  const ShadedColor(super.primary, super.swatch);

  @override
  Color operator [](int key) {
    return super[key]!;
  }
}

extension ColorExtension on Color {
  AccentColor toAccentColor({
    double darkestFactor = 0.38,
    double darkerFactor = 0.30,
    double darkFactor = 0.15,
    double lightFactor = 0.15,
    double lighterFactor = 0.30,
    double lightestFactor = 0.38,
  }) {
    return AccentColor.swatch({
      'darkest': lerpWith(MyColors.black, darkestFactor),
      'darker': lerpWith(MyColors.black, darkerFactor),
      'dark': lerpWith(MyColors.black, darkFactor),
      'normal': this,
      'light': lerpWith(MyColors.white, lightFactor),
      'lighter': lerpWith(MyColors.white, lighterFactor),
      'lightest': lerpWith(MyColors.white, lightestFactor),
    });
  }

  Color basedOnLuminance({
    Color darkColor = MyColors.black,
    Color lightColor = MyColors.white,
  }) {
    return computeLuminance() < 0.5 ? lightColor : darkColor;
  }

  Color lerpWith(Color color, double t) {
    return Color.lerp(this, color, t)!;
  }

  @protected
  int get colorValue {
    return _floatToInt8(a) << 24 |
        _floatToInt8(r) << 16 |
        _floatToInt8(g) << 8 |
        _floatToInt8(b) << 0;
  }

  @protected
  static int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }
}
