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
  /// When omitted, each native implementation uses its compiled-in color.
  final int? borderColor;

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
  final double resizeBorderWidth;

  /// Whether native edge and corner resizing is enabled.
  final bool resizable;

  WindowBorderStyle copyWith({
    double? borderWidth,
    int? borderColor,
    int? backgroundColor,
    double? cornerRadius,
    bool? shadowEnabled,
    double? resizeBorderWidth,
    bool? resizable,
  }) {
    return WindowBorderStyle(
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shadowEnabled: shadowEnabled ?? this.shadowEnabled,
      resizeBorderWidth: resizeBorderWidth ?? this.resizeBorderWidth,
      resizable: resizable ?? this.resizable,
    );
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'borderWidth': borderWidth,
      if (borderColor != null) 'borderColor': borderColor!,
      if (backgroundColor != null) 'backgroundColor': backgroundColor!,
      'cornerRadius': cornerRadius,
      'shadowEnabled': shadowEnabled,
      'resizeBorderWidth': resizeBorderWidth,
      'resizable': resizable,
    };
  }
}
