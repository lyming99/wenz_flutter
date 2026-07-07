import 'package:flutter/widgets.dart';

/// Design tokens that govern the editor's layout and density, resolved per form
/// factor.
///
/// The editor historically hardcoded every dimension as a private `_k*` constant
/// tuned for the desktop. To support a mobile form factor without churning every
/// call site, the layout-affecting subset of those constants is now sourced from
/// here.
///
/// - [desktop] mirrors the legacy `_k*` constants in `wenz_rich_text_editor.dart`
///   exactly, so desktop rendering is byte-for-byte unchanged.
/// - [mobile] supplies touch-friendlier defaults (denser body text, larger tap
///   targets, tighter table cells).
///
/// Platform selection happens entirely inside [resolve], driven by
/// [MediaQuery]; callers never branch on platform themselves.
class EditorTokens {
  const EditorTokens({
    required this.richTextBodyFontSize,
    required this.richTextBodyLineHeight,
    required this.minimalToolbarButtonSize,
    required this.minimalToolbarIconSize,
    required this.todoCheckboxWidth,
    required this.todoCheckboxHeight,
    required this.tableCellPadding,
    required this.tableCellFontSize,
    required this.codeBlockPaddingHorizontal,
    required this.codeBlockFontSize,
    required this.isMobile,
  });

  /// Desktop set — identical to the pre-adaptation hardcoded constants.
  static const EditorTokens desktop = EditorTokens(
    richTextBodyFontSize: 16.0,
    richTextBodyLineHeight: 1.75,
    minimalToolbarButtonSize: 32.0,
    minimalToolbarIconSize: 18.0,
    todoCheckboxWidth: 20.0,
    // 16.0 (font size) * 1.75 (line height).
    todoCheckboxHeight: 28.0,
    tableCellPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    tableCellFontSize: 15.0,
    codeBlockPaddingHorizontal: 20.0,
    codeBlockFontSize: 13.5,
    isMobile: false,
  );

  /// Mobile set — touch-friendlier density tuned for phones.
  static const EditorTokens mobile = EditorTokens(
    richTextBodyFontSize: 15.0,
    richTextBodyLineHeight: 1.6,
    minimalToolbarButtonSize: 40.0,
    minimalToolbarIconSize: 22.0,
    todoCheckboxWidth: 24.0,
    // 15.0 (font size) * 1.6 (line height).
    todoCheckboxHeight: 24.0,
    tableCellPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    tableCellFontSize: 15.0,
    codeBlockPaddingHorizontal: 12.0,
    codeBlockFontSize: 12.5,
    isMobile: true,
  );

  /// Shortest screen side, in logical pixels, below which the mobile token set
  /// is used. Matches the responsive split applied in the example shell.
  static const double mobileBreakpoint = 600;

  /// Resolves the token set for [context].
  ///
  /// Returns [mobile] when the shortest screen side is below
  /// [mobileBreakpoint], otherwise [desktop]. When no [MediaQuery] is available
  /// (for example some unit tests) the desktop set is returned as the safe
  /// default so behaviour never silently switches to mobile.
  static EditorTokens resolve(BuildContext context) {
    final size = MediaQuery.maybeOf(context)?.size;
    if (size == null) {
      return desktop;
    }
    final shortestSide = size.shortestSide;
    if (!shortestSide.isFinite) {
      return desktop;
    }
    return shortestSide < mobileBreakpoint ? mobile : desktop;
  }

  /// Base font size for paragraph and list body text.
  final double richTextBodyFontSize;

  /// Line height (multiple of [richTextBodyFontSize]) for body text.
  final double richTextBodyLineHeight;

  /// Square hit/visual size of a minimal toolbar button (block / floating /
  /// object toolbars).
  final double minimalToolbarButtonSize;

  /// Icon size used inside minimal toolbar buttons.
  final double minimalToolbarIconSize;

  /// Visual width of a task-list checkbox.
  final double todoCheckboxWidth;

  /// Visual height of a task-list checkbox — kept in step with the body line
  /// height so the checkbox and its text align.
  final double todoCheckboxHeight;

  /// Inner padding of a table cell.
  final EdgeInsets tableCellPadding;

  /// Font size used for table cell text.
  final double tableCellFontSize;

  /// Horizontal padding inside a fenced code block.
  final double codeBlockPaddingHorizontal;

  /// Font size used for fenced code block text.
  final double codeBlockFontSize;

  /// Whether this set targets the mobile form factor.
  final bool isMobile;
}
