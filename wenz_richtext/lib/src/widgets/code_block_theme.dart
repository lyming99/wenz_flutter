import 'package:flutter/material.dart';

/// Colors used by the built-in rich-text code-block renderer.
///
/// Keeping these colors in a [ThemeExtension] lets hosts style the code surface
/// without changing [ThemeData.brightness]. Popup menus and other transient UI
/// can therefore continue to follow the application's light or dark theme.
@immutable
class WenzCodeBlockThemeData extends ThemeExtension<WenzCodeBlockThemeData> {
  const WenzCodeBlockThemeData({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.accentColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color accentColor;

  @override
  WenzCodeBlockThemeData copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    Color? accentColor,
  }) {
    return WenzCodeBlockThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  @override
  WenzCodeBlockThemeData lerp(
    covariant WenzCodeBlockThemeData? other,
    double t,
  ) {
    if (other == null) return this;
    return WenzCodeBlockThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
    );
  }
}
