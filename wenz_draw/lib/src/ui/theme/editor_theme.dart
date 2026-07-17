import 'package:flutter/material.dart';

/// Color tokens consumed by the editor UI shell (toolbar, panels, inspectors).
///
/// Hosts override individual tokens by constructing a custom [EditorTheme] and
/// passing it to [WenzDrawEditor.theme]. Every token has a sensible default, so
/// an uncustomized editor uses the same palette as the bundled example.
@immutable
class EditorTheme {
  const EditorTheme({
    this.appBackground = const Color(0xFFF3F6F8),
    this.canvasBackground = const Color(0xFFEEF3F7),
    this.panel = const Color(0xFFFFFFFF),
    this.panelSoft = const Color(0xFFF7F9FB),
    this.line = const Color(0xFFD9E1E8),
    this.text = const Color(0xFF18232E),
    this.muted = const Color(0xFF61707F),
    this.accent = const Color(0xFF2476C7),
    this.accentSoft = const Color(0xFFE6F1FB),
    this.sectionLabel = const Color(0xFF465667),
  });

  final Color appBackground;
  final Color canvasBackground;
  final Color panel;
  final Color panelSoft;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color sectionLabel;

  /// The default theme, matching the bundled example app's look.
  static const EditorTheme light = EditorTheme();
}

/// Makes an [EditorTheme] reachable from deep in the widget tree without
/// threading it through every constructor. The editor shell installs a
/// [EditorThemeScope] at its root; descendants read it via
/// `EditorThemeScope.of(context)`.
class EditorThemeScope extends InheritedWidget {
  const EditorThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final EditorTheme theme;

  static EditorTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EditorThemeScope>();
    return scope?.theme ?? EditorTheme.light;
  }

  @override
  bool updateShouldNotify(EditorThemeScope oldWidget) =>
      theme != oldWidget.theme;
}
