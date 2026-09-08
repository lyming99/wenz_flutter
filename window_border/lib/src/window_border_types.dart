import 'dart:ui';

/// The edge used when starting a native resize operation.
enum WindowResizeEdge {
  left,
  top,
  right,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// The current native state of the host window.
enum WindowState {
  normal,
  minimized,
  maximized,
  fullscreen,
  unknown;

  static WindowState fromNative(String? value) {
    return switch (value) {
      'normal' => WindowState.normal,
      'minimized' => WindowState.minimized,
      'maximized' => WindowState.maximized,
      'fullscreen' => WindowState.fullscreen,
      _ => WindowState.unknown,
    };
  }
}

/// Visual and hit-test settings for the native window border.
class WindowBorderStyle {
  const WindowBorderStyle({
    this.borderWidth = 1,
    this.borderColor,
    this.themeColor,
    this.backgroundColor,
    this.cornerRadius = 0,
    this.shadowEnabled = true,
    this.resizeBorderWidth = 8,
    this.resizable = true,
  })  : assert(borderWidth >= 0),
        assert(cornerRadius >= 0),
        assert(resizeBorderWidth >= 0),
        assert(
          borderColor == null ||
              (borderColor >= 0 && borderColor <= 0xFFFFFFFF),
        ),
        assert(
          backgroundColor == null ||
              (backgroundColor >= 0 && backgroundColor <= 0xFFFFFFFF),
        );

  /// Width of the border drawn outside the Flutter content, in logical pixels.
  final double borderWidth;

  /// Optional native border color override encoded as a 32-bit ARGB value.
  ///
  /// When this and [themeColor] are both omitted, each native implementation
  /// uses its compiled-in color.
  final int? borderColor;

  /// The Flutter theme surface color used to derive a native border color.
  ///
  /// This is normally the color rendered next to the native border, such as
  /// [ThemeData.scaffoldBackgroundColor] or [ColorScheme.surface]. A subtle
  /// contrasting border is derived from it when [borderColor] is omitted.
  ///
  /// An explicit [borderColor] always takes precedence.
  final Color? themeColor;

  /// Native host background color encoded as a 32-bit ARGB value.
  ///
  /// This is visible behind the Flutter surface while the native window is
  /// being laid out and in any area exposed by rounded corners.
  final int? backgroundColor;

  /// Radius of the outer native window corners, in logical pixels.
  final double cornerRadius;

  /// Whether the platform compositor should draw an external window shadow.
  final bool shadowEnabled;

  /// Width of the native resize hit-test zone, in logical pixels.
  ///
  /// Windows adds 2 logical pixels to the larger of this and [borderWidth]
  /// for easier edge/corner dragging, without changing the visible border.
  /// The Windows top target is at least 12 logical pixels deep; the first
  /// and last 16 logical pixels of horizontal edges select diagonal resizing.
  /// Edge resizing is disabled while maximized or fullscreen.
  final double resizeBorderWidth;

  /// Whether native edge and corner resizing is enabled.
  final bool resizable;

  /// The explicit or theme-derived border color sent to the native platform.
  int? get resolvedBorderColor {
    return borderColor ??
        (themeColor == null ? null : borderColorForTheme(themeColor!));
  }

  /// Derives a subtle, opaque ARGB border color from a Flutter theme color.
  ///
  /// Dark colors are mixed with 20% white and light colors with 15% black.
  /// The asymmetric blend keeps the outline visible without making it compete
  /// with the Flutter content.
  static int borderColorForTheme(Color themeColor) {
    // Color.value is used for compatibility with this package's Flutter 3.22
    // minimum. Newer SDKs expose the equivalent value through toARGB32().
    // ignore: deprecated_member_use
    final argb = themeColor.value;
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    final isDark = red * 299 + green * 587 + blue * 114 < 128000;
    final target = isDark ? 0xFF : 0;
    final blendPercent = isDark ? 20 : 15;

    int blend(int channel) {
      return (channel * (100 - blendPercent) + target * blendPercent + 50) ~/
          100;
    }

    return 0xFF000000 | (blend(red) << 16) | (blend(green) << 8) | blend(blue);
  }

  WindowBorderStyle copyWith({
    double? borderWidth,
    int? borderColor,
    Color? themeColor,
    int? backgroundColor,
    double? cornerRadius,
    bool? shadowEnabled,
    double? resizeBorderWidth,
    bool? resizable,
  }) {
    return WindowBorderStyle(
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      themeColor: themeColor ?? this.themeColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shadowEnabled: shadowEnabled ?? this.shadowEnabled,
      resizeBorderWidth: resizeBorderWidth ?? this.resizeBorderWidth,
      resizable: resizable ?? this.resizable,
    );
  }

  Map<String, Object> toMap() {
    final resolvedBorderColor = this.resolvedBorderColor;
    return <String, Object>{
      'borderWidth': borderWidth,
      if (resolvedBorderColor != null) 'borderColor': resolvedBorderColor,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!,
      'cornerRadius': cornerRadius,
      'shadowEnabled': shadowEnabled,
      'resizeBorderWidth': resizeBorderWidth,
      'resizable': resizable,
    };
  }
}
