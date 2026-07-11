import 'package:flutter/foundation.dart';
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
/// Density selection happens entirely inside [resolve], driven by [MediaQuery].
/// Mobile-only interaction chrome uses [shouldUseMobileSelectionUi] instead so
/// a narrow desktop window can keep desktop selection behaviour while still
/// using compact density tokens when appropriate.
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
    required this.blockChromeStartMargin,
    required this.blockChromeGap,
    required this.blockChromeGapToContent,
    required this.reserveFullOutlineChromeRail,
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
    blockChromeStartMargin: 4.0,
    blockChromeGap: 4.0,
    blockChromeGapToContent: 8.0,
    reserveFullOutlineChromeRail: true,
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
    blockChromeStartMargin: 4.0,
    blockChromeGap: 4.0,
    blockChromeGapToContent: 4.0,
    reserveFullOutlineChromeRail: false,
    isMobile: true,
  );

  /// Shortest screen side, in logical pixels, below which the mobile token set
  /// is used. Matches the responsive split applied in the example shell.
  static const double mobileBreakpoint = 600;

  /// Returns whether [context] should use the compact mobile-density token set.
  ///
  /// This is intentionally a size-only responsive decision. Do not use it to
  /// decide whether phone-specific selection UI should mount; use
  /// [shouldUseMobileSelectionUi] for that platform-aware decision.
  static bool shouldUseMobileTokens(BuildContext context) {
    return _isCompactSize(MediaQuery.maybeOf(context)?.size);
  }

  /// Returns whether phone-style selection chrome may be enabled for [context].
  ///
  /// This combines the compact size breakpoint with the running target
  /// platform. Desktop platforms (Windows, macOS, Linux, and desktop browsers
  /// that resolve to those target platforms) return `false` even in very narrow
  /// windows. Android, iOS, and Fuchsia retain phone-style selection UI on
  /// compact surfaces.
  ///
  /// The editor's explicit `enableMobileSelectionHandles` flag remains the
  /// final opt-in/opt-out switch; callers should combine it with this result.
  static bool shouldUseMobileSelectionUi(
    BuildContext context, {
    TargetPlatform? platform,
  }) {
    return shouldUseMobileTokens(context) &&
        isMobileSelectionUiPlatform(platform ?? defaultTargetPlatform);
  }

  /// Returns whether [platform] is allowed to use phone-style selection chrome.
  static bool isMobileSelectionUiPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        true,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        false,
    };
  }

  /// Resolves the token set for [context].
  ///
  /// Returns [mobile] when the shortest screen side is below
  /// [mobileBreakpoint], otherwise [desktop]. When no [MediaQuery] is available
  /// (for example some unit tests) the desktop set is returned as the safe
  /// default so behaviour never silently switches to mobile.
  static EditorTokens resolve(BuildContext context) {
    return shouldUseMobileTokens(context) ? mobile : desktop;
  }

  /// Resolves row-chrome geometry without applying compact phone rails to a
  /// narrow desktop window.
  ///
  /// Body density remains size-responsive through [resolve]. Block operation
  /// rails also need platform awareness because their compact form changes
  /// which outline slots are reserved, not just visual density.
  static EditorTokens resolveBlockChrome(BuildContext context) {
    return shouldUseMobileSelectionUi(context) ? mobile : desktop;
  }

  static bool _isCompactSize(Size? size) {
    final shortestSide = size?.shortestSide;
    return shortestSide != null &&
        shortestSide.isFinite &&
        shortestSide < mobileBreakpoint;
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

  /// Leading 4dp inset before the top-level block operation control.
  final double blockChromeStartMargin;

  /// Gap between adjacent row-chrome controls.
  final double blockChromeGap;

  /// Gap between the last row-chrome control and block content.
  final double blockChromeGapToContent;

  /// Whether attaching an outline reserves the collapse-control slot on every
  /// row. Desktop keeps cross-row alignment; compact phones reserve the second
  /// slot only for headings that actually expose a collapse control.
  final bool reserveFullOutlineChromeRail;

  /// Whether this set is the compact mobile-density token set.
  final bool isMobile;
}
