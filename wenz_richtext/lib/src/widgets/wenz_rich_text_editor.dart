import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart' as super_clipboard;
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as super_drag;

import '../controller/find_replace_controller.dart';
import '../controller/outline_controller.dart';
import '../controller/slash_menu_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/list_numbering.dart';
import '../core/model/persistent_block_list.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import '../input/clipboard_debug_log.dart';
import '../input/composition_state.dart';
import '../input/editor_text_input_client.dart';
import '../input/external_image_input.dart';
import '../input/rich_clipboard_adapter.dart';
import '../input/external_image_store_stub.dart'
    if (dart.library.io) '../input/external_image_store_io.dart'
    as external_image_store;
import '../input/shortcut_manager.dart';
import '../rendering/text_layout_service.dart';
import 'block_geometry_registry.dart';
import 'block_layout_index.dart';
import 'block_renderer_registry.dart';
import 'code_syntax_highlighter.dart';
import 'editor_context_menu.dart';
import 'editor_tokens.dart';
import 'inline_embed_renderer.dart';
import 'link_edit_dialog.dart';
import 'link_hover_overlay.dart';
import 'lucide_toolbar_icons.dart';
import 'media_resolver.dart';
import 'mention_search_overlay.dart';
import 'mermaid/mermaid_code_block_widget.dart'
    show MermaidCodeBlockSourceControls;
import 'mobile_selection_handles_overlay.dart';
import 'object_block_toolbar_overlay.dart';
import 'selection_gesture_overlay.dart';
import 'shared_text_layout_cache.dart';
import 'slash_menu_overlay.dart';

const _caretKey = ValueKey<String>('wenz-richtext-caret');
const _selectionHighlightKey = ValueKey<String>(
  'wenz-richtext-selection-highlight',
);
const _mediaSelectionStrokeKey = ValueKey<String>(
  'wenz-richtext-media-selection-stroke',
);
const _findHighlightKey = ValueKey<String>('wenz-richtext-find-highlight');
const _inlineFormulaKey = ValueKey<String>('wenz-richtext-inline-formula');
const _editorBackgroundKey = ValueKey<String>(
  'wenz-richtext-editor-background',
);

ValueKey<String> _inlineFormulaInstanceKey(DocumentPosition position) {
  return ValueKey<String>(
    'wenz-richtext-inline-formula:${position.blockIndex}:'
    '${position.path}:${position.offset}',
  );
}

const _accessibilityFocusHighlightKey = ValueKey<String>(
  'wenz-richtext-accessibility-focus-highlight',
);
const _blockReorderDropIndicatorKey = ValueKey<String>(
  'wenz-richtext-block-reorder-drop-indicator',
);
const _externalImageDropOverlayKey = ValueKey<String>(
  'wenz-richtext-external-image-drop-overlay',
);
const String _kMentionSearchInlineBoundary = '\uFFFC';

final List<_ExternalImageDropFileFormat> _externalImageDropFileFormats =
    <_ExternalImageDropFileFormat>[
  const _ExternalImageDropFileFormat(
    super_clipboard.Formats.png,
    'image/png',
    'dropped-image.png',
  ),
  const _ExternalImageDropFileFormat(
    super_clipboard.Formats.jpeg,
    'image/jpeg',
    'dropped-image.jpg',
  ),
  const _ExternalImageDropFileFormat(
    super_clipboard.Formats.gif,
    'image/gif',
    'dropped-image.gif',
  ),
  const _ExternalImageDropFileFormat(
    super_clipboard.Formats.webp,
    'image/webp',
    'dropped-image.webp',
  ),
  const _ExternalImageDropFileFormat(
    super_clipboard.Formats.bmp,
    'image/bmp',
    'dropped-image.bmp',
  ),
];

final List<super_clipboard.DataFormat<Object>> _externalImageDropFormats =
    <super_clipboard.DataFormat<Object>>[
  super_clipboard.Formats.fileUri,
  for (final format in _externalImageDropFileFormats) format.format,
];

class _ExternalImageDropFileFormat {
  const _ExternalImageDropFileFormat(
    this.format,
    this.mimeType,
    this.fallbackFileName,
  );

  final super_clipboard.FileFormat format;
  final String mimeType;
  final String fallbackFileName;
}

/// Passive long-press detector for inline links on touch surfaces.
///
/// Wraps the editor content and, on a touch pointer that holds still over a
/// link for the long-press deadline, fires [onLongPressLink] with the global
/// position. It uses a raw [Listener] (no gesture-arena participation) so the
/// editor's tap/drag/selection recognizers keep working exactly as before —
/// only a deliberate hold over a link surfaces the touch context menu.
class _TouchLinkLongPressHandler extends StatefulWidget {
  const _TouchLinkLongPressHandler({
    required this.child,
    required this.onLongPressLink,
  });

  final Widget child;
  final ValueChanged<Offset> onLongPressLink;

  @override
  State<_TouchLinkLongPressHandler> createState() =>
      _TouchLinkLongPressHandlerState();
}

class _TouchLinkLongPressHandlerState
    extends State<_TouchLinkLongPressHandler> {
  Timer? _timer;
  Offset? _downPosition;

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // Only touch pointers long-press; mouse/pen follow the desktop hover path.
    if (event.kind != PointerDeviceKind.touch) {
      return;
    }
    _downPosition = event.position;
    _timer?.cancel();
    _timer = Timer(kLongPressTimeout, () {
      final position = _downPosition;
      if (!mounted || position == null) {
        return;
      }
      widget.onLongPressLink(position);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down == null) {
      return;
    }
    // A drag past the touch slop is a selection drag, not a long-press.
    if ((event.position - down).distance > kTouchSlop) {
      _cancelTimer();
    }
  }

  void _onPointerUp(PointerUpEvent event) => _cancelTimer();

  void _onPointerCancel(PointerCancelEvent event) => _cancelTimer();

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _downPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

enum _RowBlockFormat { paragraph, heading, code }

typedef _RowBlockFormatChangeHandler = void Function(
  int blockIndex,
  _RowBlockFormat format,
);

EditorShortcutPlatform _currentShortcutPlatform() {
  if (kIsWeb) {
    return EditorShortcutPlatform.web;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => EditorShortcutPlatform.android,
    TargetPlatform.fuchsia => EditorShortcutPlatform.all,
    TargetPlatform.iOS => EditorShortcutPlatform.iOS,
    TargetPlatform.linux => EditorShortcutPlatform.linux,
    TargetPlatform.macOS => EditorShortcutPlatform.macOS,
    TargetPlatform.windows => EditorShortcutPlatform.windows,
  };
}

IconData _iconForRowFormat(_RowBlockFormat format) {
  return switch (format) {
    _RowBlockFormat.paragraph => Icons.notes,
    _RowBlockFormat.heading => Icons.title,
    _RowBlockFormat.code => Icons.code,
  };
}

/// Caret geometry constants — kept in one place so the painted caret, the caret
/// rect reported to the IME, and any future theming all share the same source.
const double _kCaretStrokeWidth = 1.5;
const Duration _kBlinkHalfPeriod = Duration(milliseconds: 530);
// Layout/density constants below are the desktop source of truth. They mirror
// `EditorTokens.desktop` (kept in sync by hand — Dart's constant evaluator on
// this SDK rejects `EditorTokens.desktop.x` in const expressions, so the
// literals are duplicated here). Mobile resolves a different set via
// `EditorTokens.resolve(context)` at runtime.
const double _kRichTextBodyFontSize =
    16.0; // == EditorTokens.desktop.richTextBodyFontSize
const double _kParagraphMarginEm = 0.55;
const double _kHeadingMarginTopEm = 0.6;
const double _kHeadingMarginBottomEm = 0.35;
const double _kDefaultBlockSpacing =
    _kRichTextBodyFontSize * _kParagraphMarginEm;
const int _kInlineLinkColor = 0xFF1976D2;
const int _kInlineRemarkColor = 0xFFC97B00;
const int _kInlineRevisionBackgroundAlpha = 72;
const double _kDefaultBlockExtent = 48.0;
const double _kVirtualListOverscan = 600.0;
const double _kBlockReorderIndicatorHeight = 3.0;
const double _kTableResizeHandleWidth = 12.0;
const double _kMinTableColumnWidth = 48.0;
const double _kMaxTableColumnWidth = 640.0;
const double _kTableToolbarMinWidth = 304.0;
const double _kTableFloatingToolbarGap = 4.0;
const double _kTableFloatingToolbarEstimatedHeight = 36.0;
const double _kTableFloatingToolbarEstimatedWidth = 304.0;
const int _kTableToolbarBackgroundColor = 0xFFFFF3CD;
const double _kTableSurfaceRadius = 8.0;
const double _kTableCellFontSize =
    15.0; // == EditorTokens.desktop.tableCellFontSize
const Color _kTableBorderColor = Color(0xFFECE9F5);
const Color _kTableEvenRowBackgroundColor = Color(0xFFFAFAFF);

/// Minimum block height multiplier applied to the block's font size, ensuring
/// a tap target even for empty paragraphs. A single constant so the text,
/// code, and table-cell renderers stay in sync.
const double _kBlockMinHeightFactor = 1.35;
const double _kTodoTextGap = 6.0;
const double _kTaskListPaddingLeft = 4.0;
const double _kListTextInset = 26.0;
const double _kListMarkerWidth = 18.0;
const double _kListMarkerGap = _kListTextInset - _kListMarkerWidth;
const double _kListItemSpacing = _kRichTextBodyFontSize * 0.25;
const double _kNestedListItemSpacing = _kRichTextBodyFontSize * 0.15;

/// Collapses index-adjacent quoted text blocks so their surface backgrounds
/// fuse into one continuous run (see `_spacingBetweenBlocks`). Grouping is
/// adjacency + quote decoration only; an `indent` attribute does not break the
/// run.
const double _kAdjacentQuoteSpacing = 0.0;
const double _kHeadingCollapseSlotWidth = 24.0;
const double _kHeadingCollapseButtonSize = 24.0;
const double _kHeadingCollapseIconSize = 18.0;
const double _kCodeBlockFontSize =
    13.5; // == EditorTokens.desktop.codeBlockFontSize
const double _kCodeBlockLineHeight = 1.6;
const int _kMaxCodeSyntaxHighlightCharacters = 50000;
const double _kCodeBlockPaddingVertical = 18.0;
const double _kCodeBlockHeaderGap = 14.0;
const double _kCodeBlockHeaderHeight = 36.0;
const double _kCodeBlockHeaderPaddingHorizontal = 10.0;
const double _kCodeBlockHeaderToolbarEndPadding = 4.0;
const double _kCodeBlockRadius = 12.0;
const int _kCodeBlockBackgroundColor = 0xFF1E1E2E;
const int _kCodeBlockTextColor = 0xFFE6E6F0;
const int _kCodeBlockSelectionHighlightColor = 0x944C7DFF;
const int _kCodeLineNumberColor = 0x8AE6E6F0;
const double _kCodeLineNumberGap = 12.0;
const int _kCodeLanguageTagColor = 0xB38A8AFF;

// Menu and floating toolbar tokens are documented in
// docs/design/menu_toolbar_minimal_spec.md; keep future chrome changes here.
const double _kMinimalMenuSurfaceRadius = 10.0;
const double _kMinimalMenuSurfaceElevation = 3.0;
const int _kMinimalMenuSurfaceShadowAlpha = 30;
const Color _kMinimalMenuSurfaceColorLight = Color(0xFFF8F9FA);
const Color _kMinimalMenuSurfaceColorDark = Color(0xFF292A2D);
const Color _kMinimalMenuSurfaceBorderColorLight = Color(0xFFDADCE0);
const Color _kMinimalMenuSurfaceBorderColorDark = Color(0xFF4A4C50);
const Color _kMinimalMenuDividerColorLight = Color(0xFFE9ECEF);
const Color _kMinimalMenuDividerColorDark = Color(0xFF383A3E);
const double _kMinimalMenuSurfacePaddingValue = 4.0;
const double _kMinimalMenuItemHeight = 32.0;
const double _kMinimalMenuDividerHeight = 8.0;
const double _kMinimalMenuItemRadius = 8.0;
const double _kMinimalMenuIconSlotWidth = 22.0;
const double _kMinimalMenuIconSize = 18.0;
const double _kMinimalMenuIconTextGap = 10.0;
const double _kMinimalMenuShortcutGap = 18.0;
const EdgeInsets _kMinimalMenuSurfacePadding =
    EdgeInsets.all(_kMinimalMenuSurfacePaddingValue);
const EdgeInsets _kMinimalMenuItemPadding = EdgeInsets.zero;
const EdgeInsets _kMinimalMenuItemContentPadding =
    EdgeInsets.symmetric(horizontal: 10);
const double _kMinimalToolbarButtonSize =
    32.0; // == EditorTokens.desktop.minimalToolbarButtonSize
const double _kMinimalFloatingToolbarSurfaceRadius = _kMinimalMenuSurfaceRadius;
const double _kMinimalFloatingToolbarSurfaceElevation = 3.0;
const int _kMinimalFloatingToolbarShadowAlpha = _kMinimalMenuSurfaceShadowAlpha;
const EdgeInsets _kMinimalFloatingToolbarPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 2,
);
const double _kMinimalFloatingToolbarButtonGap = 2.0;
const double _kMinimalFloatingToolbarDividerWidth = 9.0;
const double _kMinimalFloatingToolbarDividerHeight = 18.0;
const int _kMinimalFloatingToolbarDividerAlpha = 84;
const int _kMinimalToolbarDisabledAlpha = 96;
const int _kMinimalMenuDisabledAlpha = 110;
const Color _kMinimalMenuHoverColorLight = Color(0xFFF1F3F4);
const Color _kMinimalMenuHoverColorDark = Color(0xFF34363A);
const Color _kMinimalMenuSelectedColorLight = Color(0xFFE8EAED);
const Color _kMinimalMenuSelectedColorDark = Color(0xFF3C4043);
const Color _kMinimalToolbarHoverOverlayLight = Color(0x14000000);
const Color _kMinimalToolbarHoverOverlayDark = Color(0x1AFFFFFF);
const Color _kMinimalToolbarFocusOverlayLight = Color(0x1A000000);
const Color _kMinimalToolbarFocusOverlayDark = Color(0x21FFFFFF);
const Color _kMinimalToolbarPressedOverlayLight = Color(0x26000000);
const Color _kMinimalToolbarPressedOverlayDark = Color(0x2EFFFFFF);
const double _kBlockFloatingToolbarInset = 6.0;
const double _kBlockToolbarButtonSize = _kMinimalToolbarButtonSize;
const double _kMediaToolbarEstimatedHeight = 36.0;
const int _kCodeKeywordColor = 0xFFC792EA;
const int _kCodeStringColor = 0xFFC3E88D;
const int _kCodeTypeColor = 0xFF82AAFF;
const int _kCodeNumberColor = 0xFFF78C6C;
const int _kCodeCommentColor = 0xFF6B7394;
const double _kDividerMarginVertical = _kRichTextBodyFontSize * 1.6;
const int _kDividerLineColor = 0xFFE4E1EE;
const double _kDividerDotSize = 6.0;
const double _kCalloutIconFontSize = 20.0;
const int _kCalloutInfoBackgroundColor = 0xFFF2F0F7;
const int _kCalloutInfoForegroundColor = 0xFF46464F;
const int _kCalloutSuccessForegroundColor = 0xFF0E1F1B;
const int _kCalloutWarningBackgroundColor = 0xFFFFF8E1;
const int _kCalloutWarningForegroundColor = 0xFFC97B00;
const int _kCalloutDangerForegroundColor = 0xFF410002;
const int _kCalloutInfoBorderColor = 0xFFD8D5E2;
const int _kCalloutSuccessBorderColor = 0xFFBCD8D0;
const int _kCalloutWarningBorderColor = 0xFFFFE082;
const int _kCalloutDangerBorderColor = 0xFFF5B8B0;
const int _kCalloutSuccessBackgroundColor = 0x99D6E4E0;
const int _kCalloutDangerBackgroundColor = 0xB3FFDAD6;
const double _kMediaBlockMarginVertical = _kRichTextBodyFontSize * 1.2;
const double _kMediaCornerRadius = 12.0;
// Image-block placeholder chrome: the placeholder fills the content width and
// keeps a 2:1 figure slot (see ui/media_block_display_design.html
// `.img-placeholder`).
const double _kImagePlaceholderAspectRatio = 2.0;
const double _kMinImageDisplayWidth = 96.0;
const double _kFallbackImageDisplayMaxWidth = 520.0;
const double _kMinImageAspectRatio = 0.1;
const double _kMaxImageAspectRatio = 10.0;
const double _kImageResizeHandleHitWidth = 18.0;
const double _kImageResizeChangeEpsilon = 0.5;

// Video embeds and previews use distinct crop strategies. The editor block keeps
// the rounded media frame, while preview/fullscreen surfaces use a rectangular
// frame so video content can fill its container without inherited corner clips.
// Both paths still normalize width/aspect ratio into finite constraints before
// laying out built-in chrome or MediaResolver output.
const double _kVideoPlayButtonSize = 64.0;
const double _kVideoPlayIconSize = 24.0;
const double _kVideoMinAspectRatio = 1 / 3;
const double _kVideoMaxAspectRatio = 4.0;
const double _kVideoMinFrameHeight = 96.0;
const double _kVideoMaxFrameHeight = 420.0;
const double _kVideoFrameFallbackWidth = 320.0;
const int _kFileCardBorderColor = 0xFFECE9F5;
const double _kFileIconSize = 40.0;
const double _kFileCardGap = 14.0;
const double _kPopupMenuRadius = _kMinimalMenuSurfaceRadius;
const double _kPopupMenuElevation = _kMinimalMenuSurfaceElevation;
const double _kPopupMenuMinWidth = 184.0;
const double _kPopupMenuMaxWidth = 320.0;
const double _kPopupMenuMaxHeight = 560.0;
const double _kPopupMenuItemHeight = _kMinimalMenuItemHeight;
const double _kPopupMenuDividerHeight = _kMinimalMenuDividerHeight;
const double _kPopupMenuItemContentMinWidth =
    _kPopupMenuMinWidth - _kMinimalMenuSurfacePaddingValue * 2;
const double _kPopupMenuItemContentMaxWidth =
    _kPopupMenuMaxWidth - _kMinimalMenuSurfacePaddingValue * 2;
const double _kPopupMenuTextMaxWidth = 212.0;
const double _kPopupMenuCompactMinLabelWidth = 0.0;
const double _kPopupMenuShortcutEstimatedWidth = 48.0;
const double _kSlashMenuGap = 6.0;
const double _kSlashMenuMinReadableHeight = 132.0;
const double _kFormulaEditorGap = 8.0;
const double _kFormulaEditorWidth = 360.0;
const double _kFormulaEditorEstimatedHeight = 180.0;
const double _kPopupViewportInset = 8.0;
const EdgeInsets _kPopupMenuPadding = _kMinimalMenuSurfacePadding;
const EdgeInsets _kPopupMenuItemPadding = _kMinimalMenuItemPadding;
const RouteSettings _kPopupMenuRouteSettings = RouteSettings(
  name: 'wenz-richtext-popup-menu',
);
const BoxConstraints _kPopupMenuConstraints = BoxConstraints(
  minWidth: _kPopupMenuMinWidth,
  maxWidth: _kPopupMenuMaxWidth,
  maxHeight: _kPopupMenuMaxHeight,
);
const int _kEmbedBlockBorderColor = 0xFFCFCBE0;
const int _kEmbedBlockBackgroundColor = 0xFFFAFAFF;
const double _kPopupMenuSectionHeaderHeight = 24.0;
const List<BoxShadow> _kSurfaceBoxShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x14141428),
    blurRadius: 3,
    offset: Offset(0, 1),
  ),
  BoxShadow(
    color: Color(0x0F141428),
    blurRadius: 2,
    offset: Offset(0, 1),
  ),
];

/// Atomic block-level objects (images, videos, files, dividers) occupy one
/// selectable document slot, mirroring inline embeds' object-replacement slot.
const int _kAtomicBlockSelectionLength = 1;

/// Pixels of horizontal indent per indent level.
const double _kIndentPixelsPerLevel = 24;

Color _minimalMenuSurfaceColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalMenuSurfaceColorDark
      : _kMinimalMenuSurfaceColorLight;
}

Color _minimalMenuBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalMenuSurfaceBorderColorDark
      : _kMinimalMenuSurfaceBorderColorLight;
}

Color _minimalMenuDividerColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalMenuDividerColorDark
      : _kMinimalMenuDividerColorLight;
}

Color _popupMenuColor(ThemeData theme) => _minimalMenuSurfaceColor(theme);

Color _popupMenuShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kMinimalMenuSurfaceShadowAlpha);

ShapeBorder _popupMenuShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: _minimalMenuBorderColor(theme),
    ),
    borderRadius: BorderRadius.circular(_kPopupMenuRadius),
  );
}

Color _floatingToolbarSurfaceColor(ThemeData theme) =>
    _minimalMenuSurfaceColor(theme);

Color _floatingToolbarShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kMinimalFloatingToolbarShadowAlpha);

ShapeBorder _floatingToolbarShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: _minimalMenuBorderColor(theme),
    ),
    borderRadius: BorderRadius.circular(_kMinimalFloatingToolbarSurfaceRadius),
  );
}

Color _blockToolbarIconColor(ThemeData theme) =>
    theme.colorScheme.onSurfaceVariant;

Color _blockToolbarDisabledIconColor(ThemeData theme) =>
    theme.colorScheme.onSurfaceVariant.withAlpha(_kMinimalToolbarDisabledAlpha);

Color _minimalMenuSelectedColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalMenuSelectedColorDark
      : _kMinimalMenuSelectedColorLight;
}

Color _minimalMenuHoverColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalMenuHoverColorDark
      : _kMinimalMenuHoverColorLight;
}

Color _minimalToolbarHoverOverlayColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalToolbarHoverOverlayDark
      : _kMinimalToolbarHoverOverlayLight;
}

Color _minimalToolbarFocusOverlayColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? _kMinimalToolbarFocusOverlayDark
      : _kMinimalToolbarFocusOverlayLight;
}

Color _blockToolbarPressedOverlayColor(ThemeData theme) =>
    theme.brightness == Brightness.dark
        ? _kMinimalToolbarPressedOverlayDark
        : _kMinimalToolbarPressedOverlayLight;

double _blockRowChromeWidth({
  required bool showDragHandle,
  required bool reserveHeadingCollapseSlot,
  required EditorTokens tokens,
}) {
  if (showDragHandle) {
    if (reserveHeadingCollapseSlot) {
      final fullRailWidth = tokens.blockChromeStartMargin +
          BlockDragHandleSpec.hitSize.width +
          tokens.blockChromeGap +
          _kHeadingCollapseButtonSize +
          tokens.blockChromeGapToContent;
      if (!tokens.isMobile) {
        assert(
          fullRailWidth == BlockDragHandleSpec.railWidth,
          'BlockDragHandleSpec.railWidth must match desktop row chrome: '
          'start margin 4dp + operation button 28dp + gap 4dp + '
          'collapse button 24dp + content gap 8dp.',
        );
      }
      return fullRailWidth;
    }
    return tokens.blockChromeStartMargin +
        BlockDragHandleSpec.hitSize.width +
        tokens.blockChromeGapToContent;
  }
  if (reserveHeadingCollapseSlot) {
    final collapseOnlyWidth =
        _kHeadingCollapseButtonSize + tokens.blockChromeGapToContent;
    if (!tokens.isMobile) {
      assert(
        collapseOnlyWidth == BlockDragHandleSpec.collapseChromeOverflow,
        'BlockDragHandleSpec.collapseChromeOverflow must match desktop row '
        'chrome: collapse button 24dp + content gap 8dp.',
      );
    }
    return collapseOnlyWidth;
  }
  return 0.0;
}

bool _shouldReserveHeadingCollapseSlot({
  required EditorTokens tokens,
  required bool outlineChromeAttached,
  required bool showHeadingCollapse,
}) {
  return showHeadingCollapse ||
      (tokens.reserveFullOutlineChromeRail && outlineChromeAttached);
}

PopupMenuEntry<T> _popupMenuDivider<T>() {
  return _MinimalPopupMenuDivider<T>(height: _kPopupMenuDividerHeight);
}

ButtonStyle _blockToolbarIconButtonStyle(
  ThemeData theme, {
  EditorTokens tokens = EditorTokens.desktop,
  Color? foregroundColor,
  Color? disabledForegroundColor,
}) {
  final buttonSize = tokens.minimalToolbarButtonSize;
  final fixedSize = Size.square(buttonSize);
  return IconButton.styleFrom(
    fixedSize: fixedSize,
    minimumSize: fixedSize,
    maximumSize: fixedSize,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    foregroundColor: foregroundColor ?? _blockToolbarIconColor(theme),
    disabledForegroundColor:
        disabledForegroundColor ?? _blockToolbarDisabledIconColor(theme),
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    hoverColor: _minimalToolbarHoverOverlayColor(theme),
    focusColor: _minimalToolbarFocusOverlayColor(theme),
    highlightColor: _blockToolbarPressedOverlayColor(theme),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonSize / 2),
    ),
  );
}

class _MinimalFloatingToolbarSurface extends StatelessWidget {
  const _MinimalFloatingToolbarSurface({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _floatingToolbarSurfaceColor(theme),
      elevation: _kMinimalFloatingToolbarSurfaceElevation,
      shadowColor: _floatingToolbarShadowColor(theme),
      surfaceTintColor: Colors.transparent,
      shape: _floatingToolbarShape(theme),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: _kMinimalFloatingToolbarPadding,
        child: child,
      ),
    );
  }
}

class _PopupMenuItemContent extends StatelessWidget {
  const _PopupMenuItemContent({
    this.icon,
    this.lucideIcon,
    required this.label,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
    this.minWidth = _kPopupMenuItemContentMinWidth,
    this.maxWidth = _kPopupMenuItemContentMaxWidth,
    this.labelMaxWidth = _kPopupMenuTextMaxWidth,
  });

  final IconData? icon;
  final String? lucideIcon;
  final String label;
  final String? shortcut;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final double minWidth;
  final double maxWidth;
  final double labelMaxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconData = selected ? Icons.check : icon;
    final lucideIconName = selected && lucideIcon != null
        ? WenzLucideToolbarIcons.check
        : lucideIcon;
    final foregroundColor = !enabled
        ? colorScheme.onSurfaceVariant.withAlpha(_kMinimalMenuDisabledAlpha)
        : destructive
            ? colorScheme.error
            : colorScheme.onSurface;
    final iconColor = !enabled
        ? colorScheme.onSurfaceVariant.withAlpha(
            _kMinimalMenuDisabledAlpha,
          )
        : destructive
            ? colorScheme.error
            : selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant;
    final selectedBackgroundColor =
        selected ? _minimalMenuSelectedColor(theme) : Colors.transparent;
    final labelStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: foregroundColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final shortcutStyle =
        (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: enabled
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurfaceVariant.withAlpha(
              _kMinimalMenuDisabledAlpha,
            ),
    );
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: SizedBox(
        height: _kPopupMenuItemHeight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: maxWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selectedBackgroundColor,
              borderRadius: BorderRadius.circular(_kMinimalMenuItemRadius),
            ),
            child: Padding(
              padding: _kMinimalMenuItemContentPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: _kMinimalMenuIconSlotWidth,
                    child: lucideIconName != null
                        ? WenzLucideToolbarIcon(
                            lucideIconName,
                            size: _kMinimalMenuIconSize,
                            color: iconColor,
                            disabledColor: iconColor,
                            enabled: enabled,
                          )
                        : Icon(
                            iconData,
                            size: _kMinimalMenuIconSize,
                            color: iconColor,
                          ),
                  ),
                  const SizedBox(width: _kMinimalMenuIconTextGap),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: labelMaxWidth,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  if (shortcut != null) ...<Widget>[
                    const SizedBox(width: _kMinimalMenuShortcutGap),
                    Text(shortcut!, style: shortcutStyle),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupMenuSectionHeader extends StatelessWidget {
  const _PopupMenuSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: _kMinimalMenuItemContentPadding,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _MinimalPopupMenuDivider<T> extends PopupMenuEntry<T> {
  const _MinimalPopupMenuDivider({required this.height});

  @override
  final double height;

  @override
  bool represents(T? value) => false;

  @override
  State<_MinimalPopupMenuDivider<T>> createState() =>
      _MinimalPopupMenuDividerState<T>();
}

class _MinimalPopupMenuDividerState<T>
    extends State<_MinimalPopupMenuDivider<T>> {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: widget.height,
      thickness: 1,
      color: _minimalMenuDividerColor(Theme.of(context)),
    );
  }
}

class _EditorPopupMenuDismissal {
  static NavigatorState? _navigator;

  static void register(NavigatorState? navigator) {
    _navigator = navigator;
  }

  static void unregister(NavigatorState? navigator) {
    if (identical(_navigator, navigator)) {
      _navigator = null;
    }
  }

  static void dismiss() {
    dismissFrom(_navigator);
    _navigator = null;
  }

  static void dismissFrom(NavigatorState? navigator) {
    if (navigator?.mounted == true && navigator!.canPop()) {
      navigator.popUntil(
        (route) => route.settings.name != _kPopupMenuRouteSettings.name,
      );
    }
  }
}

/// Implementation-side baseline extracted from `ui/richtext_design.html`.
///
/// This is intentionally data-only: P001 records the target design tokens,
/// default renderer coverage, and the known gap categories without changing the
/// editor model, codecs, command protocol, or renderer extension points.
final class WenzRichTextDesignBaseline {
  const WenzRichTextDesignBaseline._();

  static const String source = 'ui/richtext_design.html';

  static const List<BlockType> defaultRendererBlockTypes = <BlockType>[
    BlockType.paragraph,
    BlockType.heading,
    BlockType.quote,
    BlockType.listItem,
    BlockType.code,
    BlockType.image,
    BlockType.table,
    BlockType.divider,
    BlockType.video,
    BlockType.embed,
    BlockType.callout,
    BlockType.file,
  ];

  static const Map<String, int> colorTokens = <String, int>{
    'primary': 0xFF4F6DF5,
    'onPrimary': 0xFFFFFFFF,
    'primaryContainer': 0xFFDDE0FF,
    'secondaryContainer': 0xFFE8E0FF,
    'onSecondaryContainer': 0xFF241946,
    'tertiaryContainer': 0xFFD6E4E0,
    'onTertiaryContainer': 0xFF0E1F1B,
    'errorContainer': 0xFFFFDAD6,
    'onErrorContainer': 0xFF410002,
    'surface': 0xFFFBFAFF,
    'surfaceContainer': 0xFFF2F0F7,
    'onSurface': 0xFF1B1B21,
    'onSurfaceVariant': 0xFF46464F,
    'outline': 0xFF777680,
    'amberStrong': 0xFFC97B00,
    'amberBackground': 0xFFFFF8E1,
    'blueLink': 0xFF1976D2,
    'codeBackground': 0xFF1E1E2E,
    'codeText': 0xFFE6E6F0,
    'dividerLine': 0xFFE4E1EE,
    'tableBorder': 0xFFECE9F5,
    'tableEvenRow': 0xFFFAFAFF,
    'embedBorder': 0xFFCFCBE0,
  };

  static const Map<String, Object> typographyTokens = <String, Object>{
    'bodyFontSize': 16.0,
    'bodyLineHeight': 1.75,
    'headingFontSizes': <int, double>{1: 24.0, 2: 21.0, 3: 18.0, 4: 16.0},
    'headingStrongWeight': 700,
    'headingWeakWeight': 600,
    'codeFontSize': 13.5,
    'codeLineHeight': 1.6,
    'tableFontSize': 15.0,
    'captionFontSize': 13.0,
    'languageTagFontSize': 11.0,
    'calloutIconFontSize': 20.0,
    'videoPlayIconSize': 24.0,
    'inlineSmallFontSize': 12.0,
    'inlineLargeFontSize': 22.0,
  };

  static const Map<String, Object> layoutTokens = <String, Object>{
    'radius': 12.0,
    'radiusSmall': 8.0,
    'chipRadius': 6.0,
    'highlightRadius': 3.0,
    'paragraphMarginEm': 0.55,
    'headingMarginEm': <String, double>{'top': 0.6, 'bottom': 0.35},
    'blockMarginEm': 1.0,
    'mediaMarginEm': 1.2,
    'dividerMarginEm': 1.6,
    'quotePadding': <double>[8.0, 18.0],
    'quoteBorderLeftWidth': 4.0,
    'listPaddingLeft': 26.0,
    'headingCollapse': <String, double>{
      'slotWidth': _kHeadingCollapseSlotWidth,
      'buttonSize': _kHeadingCollapseButtonSize,
      'iconSize': _kHeadingCollapseIconSize,
    },
    'listItemMarginEm': 0.25,
    'nestedListMarginEm': 0.15,
    'taskPaddingLeft': 8.0,
    'taskGap': 10.0,
    'codePadding': <double>[18.0, 20.0],
    'imageCaptionGap': 8.0,
    'tableCellPadding': <double>[10.0, 14.0],
    'fileIconSize': 40.0,
    'fileGap': 14.0,
    'filePadding': <double>[14.0, 16.0],
    'calloutGap': 12.0,
    'calloutPadding': <double>[14.0, 16.0],
    'embedGap': 12.0,
    'embedPadding': 16.0,
    'videoPlayButtonSize': 64.0,
  };

  static const Map<String, String> shadowTokens = <String, String>{
    'surface': '0 1px 3px rgba(20,20,40,.08), '
        '0 1px 2px rgba(20,20,40,.06)',
    'videoPlayButton': '0 6px 20px rgba(0,0,0,.3)',
  };

  static const Map<String, String> stateTokens = <String, String>{
    'todo.done': 'onSurfaceVariant + line-through',
    'file.hover': 'surface shadow + primary border',
    'callout.info': 'surfaceContainer / #d8d5e2 / onSurfaceVariant',
    'callout.success': 'tertiaryContainer 60% / #bcd8d0',
    'callout.warning': 'amberBackground / #ffe082 / amberStrong',
    'callout.danger': 'errorContainer 70% / #f5b8b0',
    'embed.formula': 'secondaryContainer math chip',
    'heading.collapse': 'primary hover/focus control + hidden-count badge',
    'inline.mention': 'primaryContainer 70% pill',
    'inline.formula': 'secondaryContainer math pill',
    'inline.highlight': '#fff59d background with 2px horizontal padding',
  };

  static const Map<String, String> currentRendererGaps = <String, String>{
    'paragraph': 'aligned: 16px body, 1.75 line height, and 0.55em spacing.',
    'inlineText':
        'aligned: TextStyle equivalents for link, highlight, remark, and anchors.',
    'inlineEmbed': 'structure: mention/formula/image need pill/image parity.',
    'heading': 'aligned: hierarchy styles plus collapse affordance states.',
    'quote': 'aligned: 4px primary left border and surface-container quote.',
    'listItem': 'aligned: 26px list inset, compact nesting, and task states.',
    'code': 'aligned: dark surface, monospace scale, language tag, and scroll.',
    'divider': 'aligned: light rule, 1.6em spacing, and centered primary dot.',
    'image': 'style+golden: figure radius, shadow, max width, and caption.',
    'video': 'structure+golden: black preview, cover fallback, play button.',
    'file': 'style+state: 40px icon card, hover/focus, metadata zones.',
    'table': 'style+golden: 15px text, padding, header/even rows, shadow.',
    'callout':
        'aligned: info/success/warning/danger tint, border, and fallback.',
    'embed':
        'structure+golden: dashed fallback chip and formula block surface.',
  };
}

/// Display-only policy for code-block line numbers.
///
/// Line numbers are derived from [CodeBlockNode.code] at render time. They do
/// not add fields to [CodeBlockNode], codecs, clipboard payloads, undo/redo
/// commands, or text-offset mapping.
final class WenzCodeBlockLineNumbers {
  const WenzCodeBlockLineNumbers._();

  static const int firstNumber = 1;
  static const bool displayOnly = true;
  static const bool storedInDocumentModel = false;
  static const bool storedInCodecs = false;
  static const bool copiedWithCode = false;
  static const bool recordedInUndoRedoCommands = false;
  static const bool participatesInTextOffsetMapping = false;
  static const bool gutterScrollsHorizontallyWithCode = false;
  static const TextAlign gutterTextAlign = TextAlign.right;
  static const String fontFamily = 'JetBrains Mono';
  static const double fontSize = _kCodeBlockFontSize;
  static const double lineHeight = _kCodeBlockLineHeight;
  static const int color = _kCodeLineNumberColor;
  static const double gapToCode = _kCodeLineNumberGap;

  static int lineCount(String code) => code.split('\n').length;

  static List<String> labelsForCode(String code) {
    return List<String>.generate(
      lineCount(code),
      (index) => '${firstNumber + index}',
    );
  }

  static int maxLabelDigits(String code) => lineCount(code).toString().length;
}

/// Exposes the editor's [SharedTextLayoutCache] down the subtree so each
/// [_TextSelectionSurface] can fetch (and reuse) its [TextLayoutService] across
/// remount, without threading the cache through every renderer widget.
class _SharedLayoutCacheScope extends InheritedWidget {
  const _SharedLayoutCacheScope({required this.cache, required super.child});

  final SharedTextLayoutCache cache;

  static SharedTextLayoutCache? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_SharedLayoutCacheScope>();
    return scope?.cache;
  }

  @override
  bool updateShouldNotify(_SharedLayoutCacheScope oldWidget) =>
      cache != oldWidget.cache;
}

class _FormulaEditRequestController {
  const _FormulaEditRequestController({required this.onRequested});

  final ValueChanged<_FormulaEditTarget> onRequested;

  void request(_FormulaEditTarget target) => onRequested(target);
}

class _FormulaEditRequestScope extends InheritedWidget {
  const _FormulaEditRequestScope({
    required this.controller,
    required super.child,
  });

  final _FormulaEditRequestController controller;

  static _FormulaEditRequestController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_FormulaEditRequestScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(_FormulaEditRequestScope oldWidget) =>
      controller != oldWidget.controller;
}

class _ImageDescriptionEditRequestController {
  const _ImageDescriptionEditRequestController({required this.onRequested});

  final ValueChanged<_ImageDescriptionEditTarget> onRequested;

  void request(_ImageDescriptionEditTarget target) => onRequested(target);
}

class _ImageDescriptionEditRequestScope extends InheritedWidget {
  const _ImageDescriptionEditRequestScope({
    required this.controller,
    required super.child,
  });

  final _ImageDescriptionEditRequestController controller;

  static _ImageDescriptionEditRequestController? maybeOf(
    BuildContext context,
  ) {
    final scope = context.dependOnInheritedWidgetOfExactType<
        _ImageDescriptionEditRequestScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(_ImageDescriptionEditRequestScope oldWidget) =>
      controller != oldWidget.controller;
}

class _ImageDescriptionEditTarget {
  const _ImageDescriptionEditTarget({
    required this.blockIndex,
    required this.blockId,
    required this.caption,
    required this.altText,
  });

  final int blockIndex;
  final String blockId;
  final String caption;
  final String altText;
}

class _ImageDescriptionEditResult {
  const _ImageDescriptionEditResult({
    required this.caption,
    required this.altText,
  });

  final String caption;
  final String altText;
}

class _FormulaEditTarget {
  const _FormulaEditTarget.inline({
    required this.position,
    required this.formula,
    required this.anchor,
  }) : blockId = null;

  const _FormulaEditTarget.block({
    required this.blockId,
    required this.formula,
    required this.anchor,
  }) : position = null;

  final DocumentPosition? position;
  final String? blockId;
  final String formula;
  final Rect anchor;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _FormulaEditTarget &&
            other.position == position &&
            other.blockId == blockId &&
            other.formula == formula &&
            other.anchor == anchor;
  }

  @override
  int get hashCode => Object.hash(position, blockId, formula, anchor);
}

class _FormulaEditorAnchor {
  const _FormulaEditorAnchor({
    required this.left,
    required this.top,
    required this.width,
  });

  final double left;
  final double top;
  final double width;
}

Rect _globalRectForContext(BuildContext context, Offset fallback) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
  return fallback & Size.zero;
}

class _FormulaEditPopup extends StatelessWidget {
  const _FormulaEditPopup({
    required this.controller,
    required this.focusNode,
    required this.onConfirm,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      namesRoute: true,
      label: '公式编辑弹窗',
      child: Material(
        key: const ValueKey<String>('wenz-richtext-formula-editor-popup'),
        color: _popupMenuColor(theme),
        elevation: _kPopupMenuElevation,
        shadowColor: _popupMenuShadowColor(theme),
        surfaceTintColor: Colors.transparent,
        shape: _popupMenuShape(theme),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '编辑公式',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'wenz-richtext-formula-editor-close',
                    ),
                    tooltip: '关闭公式编辑',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey<String>(
                    'wenz-richtext-formula-editor-input'),
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'LaTeX 公式',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onConfirm(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    key: const ValueKey<String>(
                      'wenz-richtext-formula-editor-cancel',
                    ),
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey<String>(
                      'wenz-richtext-formula-editor-confirm',
                    ),
                    onPressed: onConfirm,
                    child: const Text('确认'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class WenzRichTextEditorAccessibility {
  const WenzRichTextEditorAccessibility({
    this.label = 'Rich text editor',
    this.readOnlyLabel = 'Rich text document',
    this.hint =
        'Edit rich text content with text input and keyboard shortcuts.',
    this.readOnlyHint = 'Read-only rich text document.',
    this.highContrastFocusColor,
    this.highContrastFocusWidth = 3,
  }) : assert(highContrastFocusWidth >= 0);

  /// Screen-reader label announced for an editable editor.
  final String label;

  /// Screen-reader label announced when [WenzRichTextEditor.readOnly] is true.
  final String readOnlyLabel;

  /// Screen-reader hint announced for an editable editor.
  final String hint;

  /// Screen-reader hint announced when [WenzRichTextEditor.readOnly] is true.
  final String readOnlyHint;

  /// Optional border color for the focused editor when high contrast is active.
  final Color? highContrastFocusColor;

  /// Border width for the focused editor when high contrast is active.
  final double highContrastFocusWidth;

  String effectiveLabel({required bool readOnly}) =>
      readOnly ? readOnlyLabel : label;

  String effectiveHint({required bool readOnly}) =>
      readOnly ? readOnlyHint : hint;
}

/// Public wrapper for custom atomic block renderers.
///
/// Business [BlockRendererBuilder]s can wrap their widget with this surface so
/// object-block selection, geometry registration, caret anchoring, and debug
/// overlays behave like the built-in image/video/file/embed renderers.
class WenzObjectBlockSurface extends StatelessWidget {
  const WenzObjectBlockSurface({
    super.key,
    required this.renderContext,
    required this.child,
  });

  final BlockRenderContext renderContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _withSelectableObjectBlock(
      renderContext.block,
      renderContext,
      child,
    );
  }
}

/// Callback invoked when an inline link — text whose [TextAttributes.url] is
/// non-null — is activated. The library reports the link [url] and the document
/// [position] of the run that was activated (Ctrl/Cmd+click on the link text, or
/// the link hover overlay's "open" action) and leaves the actual opening to the
/// host, mirroring the callback-first philosophy of [WenzMentionTapCallback]. The
/// library itself never depends on a platform launcher.
typedef WenzLinkInteractionCallback = void Function(
  String url,
  DocumentPosition position,
);

/// Rich text editor surface backed by a [WenzRichTextController].
///
/// Heading collapse is a view concern of this surface: built-in collapse
/// affordances belong only to top-level heading blocks, can be toggled in
/// read-only mode, and must not call document-mutating commands or enqueue
/// undo/redo entries.
class WenzRichTextEditor extends StatefulWidget {
  const WenzRichTextEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.fromLTRB(0, 16, 16, 16),
    this.blockSpacing = _kDefaultBlockSpacing,
    this.textStyle,
    this.defaultTextColor,
    this.physics,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.showDebugOverlay = false,
    this.enableIme = true,
    this.shortcutConfiguration = const EditorShortcutConfiguration(),
    this.contextMenuConfiguration = const WenzEditorContextMenuConfiguration(),
    this.blockRenderers,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.mentionSearch,
    this.onMentionTap,
    this.onOpenLink,
    this.findController,
    this.onFindRequested,
    this.onReplaceRequested,
    this.slashMenuController,
    this.outlineController,
    this.enableExternalImageInput = true,
    this.enableExternalDragDrop = true,
    this.enableMobileSelectionHandles = true,
    this.externalImageClipboardReader,
    this.externalImageStore,
    this.accessibility = const WenzRichTextEditorAccessibility(),
  });

  final WenzRichTextController controller;
  final EdgeInsetsGeometry padding;
  final double blockSpacing;

  /// Baseline text style for editable content. [TextStyle.color] is the
  /// editor's default font color; runs without [TextAttributes.color] inherit
  /// it unless a link style supplies the foreground color.
  final TextStyle? textStyle;

  /// Default foreground color for uncolored text runs.
  ///
  /// This is a convenience override for [textStyle.color]. Inline
  /// [TextAttributes.color] still wins, and link text keeps the built-in link
  /// foreground when no inline color is set.
  final Color? defaultTextColor;
  final ScrollPhysics? physics;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;

  /// When true, overlays the active block's id, index, path, and caret offset
  /// for debugging selection behaviour. Does not affect layout or offsets.
  final bool showDebugOverlay;

  /// When true (default), attaches a [TextInput] connection on focus so the
  /// platform IME drives character entry via composition deltas. Set false to
  /// fall back to direct key-event character insertion (used by headless
  /// widget tests that inject characters via [sendKeyEvent]).
  final bool enableIme;

  /// Optional shortcut configuration applied on top of the built-in keymap.
  ///
  /// Updating this value rebuilds the resolver used by subsequent key events;
  /// the editor controller does not need to be recreated.
  final EditorShortcutConfiguration shortcutConfiguration;

  /// Optional desktop context-menu configuration.
  ///
  /// The configuration is a headless descriptor model: hosts can append custom
  /// entries, replace editor defaults, or provide a builder that resolves menu
  /// entries from the current selection and hit-test context.
  final WenzEditorContextMenuConfiguration contextMenuConfiguration;

  /// Optional [BlockRendererRegistry]. When `null`, the editor builds a fresh
  /// registry with the built-in default renderers. Pass your own to override
  /// how specific [BlockType]s render (e.g. a real image decoder for image
  /// blocks) or to register business [BlockEmbedNode.embedType] renderers. Use
  /// [installDefaultRenderers] to seed a custom registry with the built-ins
  /// before overriding individual types.
  final BlockRendererRegistry? blockRenderers;

  /// Optional [MediaResolver] that takes over rendering for image/video/file
  /// blocks. The built-in media renderers ask the resolver first and fall back
  /// to the placeholder when it returns `null` (or when no resolver is set).
  /// Video resolver output is always placed inside a finite, clipped frame:
  /// in-editor video blocks use the rounded media frame, while fullscreen
  /// previews use a rectangular frame on a viewport-sized black surface.
  /// This is the quick path for real media rendering; for finer control
  /// (e.g. swapping the whole block widget) use [blockRenderers] instead.
  /// Throwing from the resolver is tolerated — the editor falls back to the
  /// placeholder rather than crashing.
  final MediaResolver? mediaResolver;

  /// Optional renderer for inline embeds such as formula / mention. The
  /// built-in text renderers ask this first and use their compact fallback
  /// labels when it returns `null`.
  ///
  /// Mention interaction boundary: the built-in fallback renders mentions as
  /// compact `@label` text, keeps each mention as one logical document slot for
  /// caret/selection math, and lets the editor's normal tap/drag gestures handle
  /// hit testing in both editing and read-only modes. If a custom renderer
  /// returns a span for `mention`, it is responsible for any recognizer it adds;
  /// return `null` to preserve the built-in mention boundary and editor-level
  /// mention click handling.
  final InlineEmbedRenderer? inlineEmbedRenderer;

  /// Optional search callback for editor-driven `@` mention suggestions.
  ///
  /// When provided, a collapsed caret after `@` or `@query` in editable text
  /// opens the built-in mention search overlay. Selecting a candidate replaces
  /// that query range with a `mention` inline embed. When omitted, typing `@`
  /// behaves exactly like ordinary text.
  final WenzMentionSearchCallback? mentionSearch;

  /// Called when a `mention` inline embed is activated by the editor.
  ///
  /// The callback receives [WenzMentionTapDetails], including the mention `id`,
  /// `label`, original embed [WenzMentionTapDetails.data], and document
  /// position. When omitted, mention rendering and selection behaviour remain
  /// unchanged.
  final WenzMentionTapCallback? onMentionTap;

  /// Called when an inline link (`TextAttributes.url` non-null) is activated —
  /// by a Ctrl/Cmd+click on the link text or the link hover overlay's "open"
  /// action. The host receives the link [url] and the document [position] of the
  /// link run and decides how to open it (browser / in-app / allow-list). The
  /// library never launches a URL itself, mirroring [onMentionTap]. When
  /// omitted, link activation is simply reported to no one; links keep their
  /// visual styling and remain editable as before.
  final WenzLinkInteractionCallback? onOpenLink;

  /// Optional find/replace controller. When provided, the editor paints all
  /// current matches and enables Ctrl/Cmd+F/H shortcut dispatch.
  final WenzFindReplaceController? findController;

  /// Called for Ctrl/Cmd+F when a find surface is available.
  final VoidCallback? onFindRequested;

  /// Called for Ctrl/Cmd+H when a replace surface is available.
  final VoidCallback? onReplaceRequested;

  /// Optional slash-menu controller. When provided, the editor shows the
  /// built-in slash overlay and routes ArrowUp/ArrowDown/Enter/Escape to it
  /// while the menu is open.
  final SlashMenuController? slashMenuController;

  /// Optional outline controller whose body-heading collapsed state projects
  /// the rendered top-level block list without mutating the source document.
  /// Outline-panel expansion is separate display state and does not write here.
  final WenzOutlineController? outlineController;

  /// Whether platform image clipboard flavors and external image file drops
  /// should be accepted.
  ///
  /// Defaults to `true`. When `false`, the editor keeps existing text,
  /// Wenz-rich JSON, HTML, and Markdown paste behaviour but ignores
  /// [externalImageClipboardReader], [externalImageStore], and external image
  /// drop targets.
  final bool enableExternalImageInput;

  /// Whether the external drag-and-drop surface (the `super_drag` `DropRegion`)
  /// is mounted at all.
  ///
  /// Defaults to `true`. Touch form factors additionally skip the `DropRegion`
  /// (they have no external drag source and its pointer routing interferes with
  /// touch selection gestures), so this flag only takes effect on mouse-driven
  /// surfaces. Hosts that never want drag-and-drop can disable it here.
  final bool enableExternalDragDrop;

  /// Whether the mobile selection-handles overlay may mount on touch surfaces.
  ///
  /// Defaults to `true` and remains the final opt-in/opt-out switch. Platform
  /// and form-factor eligibility for phone-style selection chrome is resolved
  /// by [EditorTokens.shouldUseMobileSelectionUi], so desktop platforms can stay
  /// on desktop selection behaviour even when their window is narrow. Mirrors
  /// [WenzEditorConfiguration.enableMobileSelectionHandles], which the bootstrap
  /// forwards here.
  final bool enableMobileSelectionHandles;

  /// Optional reader for image-capable clipboard flavors.
  ///
  /// Tests and host integrations can provide a reader backed by platform
  /// plugins. The editor only consumes [ExternalImageClipboardData], so plugin
  /// types do not leak into the editor surface.
  final ExternalImageClipboardReader? externalImageClipboardReader;

  /// Optional store/validator for image inputs from
  /// [externalImageClipboardReader] or external file drops. Defaults to the
  /// platform store where available and a no-op stub elsewhere.
  final ExternalImageStore? externalImageStore;

  /// Accessibility labels, hints, and high-contrast focus styling.
  final WenzRichTextEditorAccessibility accessibility;

  /// Seeds [registry] with the built-in block renderers for every [BlockType].
  /// Call this on a freshly constructed [BlockRendererRegistry] when you want
  /// to override only a few types while keeping the defaults for the rest:
  ///
  /// ```dart
  /// final registry = BlockRendererRegistry();
  /// WenzRichTextEditor.installDefaultRenderers(registry);
  /// registry.register(BlockType.image, myImageRenderer);
  /// ```
  static void installDefaultRenderers(BlockRendererRegistry registry) {
    registry
      ..register(BlockType.paragraph, _defaultTextBlockRenderer)
      ..register(BlockType.heading, _defaultTextBlockRenderer)
      ..register(BlockType.quote, _defaultTextBlockRenderer)
      ..register(BlockType.listItem, _defaultTextBlockRenderer)
      ..register(BlockType.code, _defaultCodeBlockRenderer)
      ..register(BlockType.image, _defaultImageBlockRenderer)
      ..register(BlockType.table, _defaultTableBlockRenderer)
      ..register(BlockType.divider, _defaultDividerBlockRenderer)
      ..register(BlockType.video, _defaultVideoBlockRenderer)
      ..register(BlockType.embed, _defaultBlockEmbedRenderer)
      ..register(BlockType.callout, _defaultCalloutBlockRenderer)
      ..register(BlockType.file, _defaultFileBlockRenderer);
  }

  @override
  State<WenzRichTextEditor> createState() => _WenzRichTextEditorState();
}

class _WenzRichTextEditorState extends State<WenzRichTextEditor> {
  FocusNode? _internalFocusNode;
  FocusNode? _listenedFocusNode;

  /// The focus node currently registered with the controller, tracked so we can
  /// detect swaps and clear it cleanly on dispose.
  FocusNode? _controllerAttachedFocusNode;
  bool _hadEditorFocus = false;

  /// Remembered horizontal column for repeated Up/Down moves, so the caret
  /// keeps its column across multiple line jumps. Cleared on Left/Right/Home/
  /// End/clicks (any horizontal repositioning).
  double? _verticalPreferX;
  int _generatedBlockCount = 0;
  late final EditorTextInputClient _inputClient;
  late EditorShortcutManager _shortcutManager = EditorShortcutManager(
    configuration: widget.shortcutConfiguration,
    platform: _currentShortcutPlatform(),
  );
  late final BlockGeometryRegistry _registry = BlockGeometryRegistry();
  final Map<GlobalKey, _InlineVideoResolverTapTargetRegistration>
      _inlineVideoResolverTapTargets =
      <GlobalKey, _InlineVideoResolverTapTargetRegistration>{};
  late final ScrollController _scrollController = ScrollController();
  late final SharedTextLayoutCache _layoutCache = SharedTextLayoutCache();
  final GlobalKey _editorOverlayKey = GlobalKey();
  DocumentPosition? _mobileCaretToolbarPosition;
  OverlayEntry? _slashMenuOverlayEntry;
  bool _slashMenuOverlaySyncScheduled = false;
  bool _contextMenuOpen = false;
  int _contextMenuGeneration = 0;
  final TextEditingController _formulaEditController = TextEditingController();
  final FocusNode _formulaEditFocusNode = FocusNode(
    debugLabel: 'WenzFormulaEditor',
  );
  late final TableFloatingToolbarOverlayController
      _tableToolbarOverlayController = TableFloatingToolbarOverlayController();
  late final ObjectBlockToolbarOverlayController
      _objectBlockToolbarOverlayController =
      ObjectBlockToolbarOverlayController();
  final _BlockExtentCache _extentCache = _BlockExtentCache();
  List<BlockNode>? _listMarkerBlocks;
  List<String?> _cachedListMarkers = const <String?>[];
  BlockRendererRegistry? _ownedBlockRenderers;
  _FormulaEditTarget? _formulaEditTarget;
  _MentionSearchTrigger? _mentionSearchTrigger;
  bool _mentionSearchLoading = false;
  Object? _mentionSearchError;
  List<WenzMentionCandidate> _mentionSearchCandidates =
      const <WenzMentionCandidate>[];
  int _mentionSearchHighlightedIndex = 0;
  int _mentionSearchGeneration = 0;
  String? _suppressedMentionSearchSignature;
  bool _externalImageDropActive = false;
  int _externalImageDropProbeEpoch = 0;

  /// The inline link run currently reported as hovered by the gesture surface,
  /// driving the [WenzLinkHoverOverlay]. `null` while no link is hovered or
  /// while a hide is pending (see [_linkHoverHideTimer]).
  WenzLinkHoverInfo? _linkHover;

  /// Whether the pointer currently rests over a link run on the editing surface
  /// (reported by the gesture surface). Together with [_linkPopupHovered] it is
  /// the hide-timer guard: the popup is only dismissed once the pointer is over
  /// neither the link text nor the popup itself, which makes the dismiss
  /// ordering-independent across the surface and popup event sources.
  bool _surfaceLinkHovered = false;

  /// Whether the pointer currently rests on the hover popup itself. See
  /// [_surfaceLinkHovered].
  bool _linkPopupHovered = false;
  Timer? _linkHoverHideTimer;

  /// Grace period before dismissing the popup after the pointer leaves the link
  /// run, giving it time to move onto the popup.
  static const Duration _kLinkHoverHideDelay = Duration(milliseconds: 300);

  /// Guards [_scrollCaretIntoView]'s virtualised estimate-and-realign loop.
  /// Each estimate-driven re-arm increments this; once it exceeds
  /// [_maxScrollRealignFrames] we stop, so a persistently mis-estimated block
  /// height cannot spin the viewport indefinitely.
  int _scrollRealignDepth = 0;
  static const int _maxScrollRealignFrames = 4;

  /// Records the most recent timestamp of a user-initiated scroll gesture.
  /// Used to suppress extent-update scroll-to-caret retries while the user is
  /// actively moving the viewport away from the caret.
  DateTime? _lastUserScrollTime;

  /// Counts editor-owned scroll jumps so their notifications are not treated as
  /// user input by the scroll notification listener.
  int _programmaticScrollDepth = 0;

  /// Cooldown period after a user scroll gesture during which extent-driven
  /// scroll-to-caret retries are suppressed. Prevents the feedback loop where
  /// layout remeasurement jumps the viewport back to the caret while the user
  /// is actively scrolling away from it.
  static const Duration _kUserScrollCooldown = Duration(milliseconds: 300);

  /// The caret position (block index + offset) at the last scroll-into-view
  /// check. IME composition updates call `notifyListeners` without moving the
  /// caret; remembering the last-checked position lets us skip the (layout +
  /// localToGlobal) scroll check when the caret hasn't moved — a hot path
  /// during pinyin/japanese input.
  _CaretKey? _lastScrollCheckedCaret;
  bool _skipNextCaretScrollIntoView = false;
  bool _inputGeometrySyncPending = false;

  /// Last finite size offered to the editor shell. Keyboard/panel occupancy,
  /// rotation, and parent layout changes all flow through these constraints.
  Size? _lastViewportSize;
  bool _viewportCaretCheckScheduled = false;

  /// The active block renderer registry. When the widget supplies one it is
  /// used as-is; otherwise a private registry with built-in defaults is lazily
  /// created and kept for the widget's lifetime.
  BlockRendererRegistry get _blockRenderers {
    if (widget.blockRenderers != null) {
      return widget.blockRenderers!;
    }
    return _ownedBlockRenderers ??= () {
      final registry = BlockRendererRegistry();
      WenzRichTextEditor.installDefaultRenderers(registry);
      return registry;
    }();
  }

  @override
  void initState() {
    super.initState();
    _inputClient = EditorTextInputClient(widget.controller);
    // The IME bridge asks the widget layer for the caret's global rect so the
    // platform can position its candidate window (e.g. pinyin) at the caret.
    _inputClient.caretRectProvider = () {
      final selection = widget.controller.selection;
      if (selection == null || !selection.isCollapsed) {
        return null;
      }
      return _registry.caretRectForPosition(selection.extent);
    };
    _inputClient.textInputGeometryProvider = () {
      final selection = widget.controller.selection;
      if (selection == null || !selection.isCollapsed) {
        return null;
      }
      final position = selection.extent;
      final composition = widget.controller.compositionState;
      final composingRange = composition != null &&
              composition.blockId == position.blockId &&
              composition.blockIndex == position.blockIndex &&
              composition.path == position.path &&
              !composition.isEmpty
          ? TextRange(
              start: composition.startOffset,
              end: composition.endOffset,
            )
          : null;
      final geometry = _registry.textInputGeometryForPosition(
        position,
        composingRange: composingRange,
      );
      if (geometry == null) {
        return null;
      }
      return EditorTextInputGeometry(
        editableSize: geometry.editableSize,
        transform: geometry.transform,
        caretRect: geometry.caretRect,
        composingRect: geometry.composingRect,
        globalCaretRect: geometry.globalCaretRect,
      );
    };
    // The platform text-input engine rejects a client whose configuration has
    // no viewId (Android throws "view ID is null"). We resolve the current view
    // lazily via the mounted BuildContext so the id stays correct across view
    // reparenting / multi-window.
    _inputClient.viewIdProvider = _resolveViewId;
    _inputClient.performSelectorHandler = _handlePlatformSelector;
    widget.controller.addListener(_handleControllerChanged);
    _scrollController.addListener(_handleScrollChanged);
    widget.findController?.addListener(_handleFindControllerChanged);
    widget.slashMenuController?.attachEditor(widget.controller);
    if (widget.readOnly) {
      widget.slashMenuController?.close();
    }
    widget.slashMenuController?.addListener(_handleSlashMenuChanged);
    _scheduleSlashMenuOverlaySync();
    widget.outlineController?.addListener(_handleOutlineControllerChanged);
    _syncFindControllerOutline();
    _revealCurrentSelectionIfHidden();
    // Expose the focus node to the controller so controller.requestFocus() can
    // drive focus. Updated in _syncFocusListener (which runs each build and on
    // controller/focusNode change).
    final focusNode = _effectiveFocusNode;
    widget.controller.attachFocusNode(focusNode);
    _controllerAttachedFocusNode = focusNode;
    // Ensure owned defaults are installed eagerly when no external registry is
    // provided, mirroring the lazy getter above.
    _blockRenderers;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshMentionSearch();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSlashMenuOverlaySync();
  }

  @override
  void didUpdateWidget(covariant WenzRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _EditorPopupMenuDismissal.dismiss();
      oldWidget.controller.removeListener(_handleControllerChanged);
      oldWidget.controller.attachFocusNode(null);
      widget.controller.addListener(_handleControllerChanged);
      _objectBlockToolbarOverlayController.hide();
      _extentCache.clear();
      _layoutCache.clear();
    } else if (oldWidget.textStyle != widget.textStyle ||
        oldWidget.defaultTextColor != widget.defaultTextColor ||
        oldWidget.blockRenderers != widget.blockRenderers ||
        oldWidget.mediaResolver != widget.mediaResolver ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
        oldWidget.mentionSearch != widget.mentionSearch ||
        oldWidget.onMentionTap != widget.onMentionTap ||
        oldWidget.findController != widget.findController ||
        oldWidget.slashMenuController != widget.slashMenuController) {
      _extentCache.clear();
      _layoutCache.clear();
    }
    if (oldWidget.findController != widget.findController) {
      oldWidget.findController?.removeListener(_handleFindControllerChanged);
      widget.findController?.addListener(_handleFindControllerChanged);
    }
    if (oldWidget.shortcutConfiguration != widget.shortcutConfiguration) {
      _shortcutManager = EditorShortcutManager(
        configuration: widget.shortcutConfiguration,
        platform: _currentShortcutPlatform(),
      );
    }
    if (oldWidget.slashMenuController != widget.slashMenuController) {
      oldWidget.slashMenuController?.removeListener(_handleSlashMenuChanged);
      _removeSlashMenuOverlay();
      widget.slashMenuController?.attachEditor(widget.controller);
      if (widget.readOnly) {
        widget.slashMenuController?.close();
      }
      widget.slashMenuController?.addListener(_handleSlashMenuChanged);
    } else if (oldWidget.controller != widget.controller) {
      widget.slashMenuController?.attachEditor(widget.controller);
    }
    if (oldWidget.contextMenuConfiguration != widget.contextMenuConfiguration ||
        oldWidget.readOnly != widget.readOnly) {
      _EditorPopupMenuDismissal.dismiss();
    }
    if (!oldWidget.readOnly && widget.readOnly) {
      widget.slashMenuController?.close();
      _removeSlashMenuOverlay();
      _closeFormulaEditor();
      _closeMentionSearch();
    }
    if (oldWidget.mentionSearch != widget.mentionSearch ||
        oldWidget.controller != widget.controller) {
      _refreshMentionSearch();
    }
    if (!_canAcceptExternalImageDrop) {
      _clearExternalImageDropActive();
    }
    _scheduleSlashMenuOverlaySync();
    if (oldWidget.outlineController != widget.outlineController) {
      oldWidget.outlineController?.removeListener(
        _handleOutlineControllerChanged,
      );
      widget.outlineController?.addListener(_handleOutlineControllerChanged);
      _syncFindControllerOutline();
      _handleOutlineControllerChanged();
    } else if (oldWidget.findController != widget.findController) {
      _syncFindControllerOutline();
    }
    // The effective focus node may change when the caller swaps focusNode or
    // controller; re-inject so controller.requestFocus() targets the right node.
    final focusNode = _effectiveFocusNode;
    if (focusNode != _controllerAttachedFocusNode) {
      widget.controller.attachFocusNode(focusNode);
      _controllerAttachedFocusNode = focusNode;
    }
    _synchronizeMobileCaretToolbar();
    _syncTableToolbarOverlayWithSelection();
    _syncObjectBlockToolbarOverlayWithSelection();
  }

  @override
  void dispose() {
    assert(() {
      _debugLogEditorVideoLifecycle(
        'editor dispose',
        widget.controller.document.blocks,
        StackTrace.current,
      );
      return true;
    }());
    _EditorPopupMenuDismissal.dismiss();
    widget.controller.removeListener(_handleControllerChanged);
    _scrollController.removeListener(_handleScrollChanged);
    widget.findController?.removeListener(_handleFindControllerChanged);
    widget.slashMenuController?.removeListener(_handleSlashMenuChanged);
    _removeSlashMenuOverlay();
    widget.outlineController?.removeListener(_handleOutlineControllerChanged);
    // Release the focus node from the controller so a later requestFocus() on
    // a disposed editor is a safe no-op. Only clear when this widget was the
    // one that injected it.
    if (_controllerAttachedFocusNode != null) {
      widget.controller.attachFocusNode(null);
    }
    _controllerAttachedFocusNode = null;
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    _inputClient.performSelectorHandler = null;
    _inputClient.detach();
    _mentionSearchGeneration++;
    _tableToolbarOverlayController.hide();
    _tableToolbarOverlayController.dispose();
    _objectBlockToolbarOverlayController.hide();
    _objectBlockToolbarOverlayController.dispose();
    _linkHoverHideTimer?.cancel();
    _formulaEditController.dispose();
    _formulaEditFocusNode.dispose();
    _scrollController.dispose();
    // BlockGeometryRegistry holds no native resources; clearing its maps is
    // unnecessary once the editor is gone.
    _layoutCache.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFindControllerChanged() {
    _revealCurrentSelectionIfHidden();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSlashMenuChanged() {
    if (mounted) {
      if (widget.slashMenuController?.isOpen == true) {
        _closeMentionSearch();
      }
      _scheduleSlashMenuOverlaySync();
      setState(() {});
    }
  }

  void _handleScrollChanged() {
    if (_contextMenuOpen) {
      _EditorPopupMenuDismissal.dismiss();
    }
    if (mounted &&
        (widget.slashMenuController?.isOpen == true ||
            _mentionSearchTrigger != null ||
            _formulaEditTarget != null)) {
      _scheduleSlashMenuOverlaySync();
      setState(() {});
    }
  }

  void _markUserScrollInteraction() {
    _lastUserScrollTime = DateTime.now();
  }

  bool _isInUserScrollCooldown() {
    final lastUserScrollTime = _lastUserScrollTime;
    return lastUserScrollTime != null &&
        DateTime.now().difference(lastUserScrollTime) < _kUserScrollCooldown;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      _markUserScrollInteraction();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_programmaticScrollDepth > 0 || notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _markUserScrollInteraction();
    } else if (notification is ScrollUpdateNotification) {
      _markUserScrollInteraction();
    } else if (notification is OverscrollNotification) {
      _markUserScrollInteraction();
    } else if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _markUserScrollInteraction();
    }
    return false;
  }

  void _scheduleSlashMenuOverlaySync() {
    if (!mounted || _slashMenuOverlaySyncScheduled) {
      return;
    }
    _slashMenuOverlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slashMenuOverlaySyncScheduled = false;
      if (mounted) {
        _syncSlashMenuOverlay();
      }
    });
  }

  void _syncSlashMenuOverlay() {
    final shouldShow =
        !widget.readOnly && widget.slashMenuController?.isOpen == true;
    if (!shouldShow) {
      _removeSlashMenuOverlay();
      return;
    }
    final entry = _slashMenuOverlayEntry;
    if (entry != null) {
      entry.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    _slashMenuOverlayEntry = OverlayEntry(
      builder: (_) {
        final controller = widget.slashMenuController;
        if (!mounted ||
            widget.readOnly ||
            controller == null ||
            !controller.isOpen) {
          return const SizedBox.shrink();
        }
        return _buildSlashMenuOverlay(controller);
      },
    );
    overlay.insert(_slashMenuOverlayEntry!);
  }

  void _removeSlashMenuOverlay() {
    final entry = _slashMenuOverlayEntry;
    if (entry == null) {
      return;
    }
    _slashMenuOverlayEntry = null;
    entry.remove();
    entry.dispose();
  }

  void _handleOutlineControllerChanged() {
    if (!mounted) {
      return;
    }
    final outline = widget.outlineController;
    final bodyToggleWithoutSelectionMove = outline != null &&
        identical(outline.editor, widget.controller) &&
        outline.lastCollapseChangeReason ==
            OutlineCollapseChangeReason.bodyToggle &&
        !outline.lastCollapseChangeMovedSelection;
    final revealedSelection = _revealCurrentSelectionIfHidden();
    final shouldScrollCaret =
        revealedSelection || !bodyToggleWithoutSelectionMove;
    if (shouldScrollCaret) {
      _lastScrollCheckedCaret = null;
    } else {
      _lastScrollCheckedCaret = _currentCollapsedCaretKey();
    }
    _scrollRealignDepth = 0;
    setState(() {});
    if (!shouldScrollCaret) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (revealedSelection || !_isInUserScrollCooldown()) {
          _scrollCaretIntoView();
        }
      }
    });
  }

  void _handleControllerChanged() {
    if (mounted) {
      _synchronizeMobileCaretToolbar(hideForDocumentChange: true);
      if (_contextMenuOpen) {
        _EditorPopupMenuDismissal.dismiss();
      }
      if (widget.readOnly) {
        widget.slashMenuController?.close();
        _closeMentionSearch();
      }
      _refreshMentionSearch();
      if (!_canAcceptExternalImageDrop) {
        _clearExternalImageDropActive();
      }
      _syncTableToolbarOverlayWithSelection();
      _syncObjectBlockToolbarOverlayWithSelection();
      if (_revealCurrentSelectionIfHidden()) {
        _lastScrollCheckedCaret = null;
        _scrollRealignDepth = 0;
      }
      // Drop the cached laid-out painter for blocks whose content changed so a
      // stale painter is not reused on the next build. Selection-only /
      // composition-only changes (empty set) do not invalidate anything.
      //
      // The block *extent* cache is intentionally NOT invalidated here. While a
      // block's text is being edited (most acutely during IME composition such
      // as pinyin input) its content mutates on every keystroke, but its height
      // barely changes. Dropping the cached height mid-edit would fall back to
      // the document-wide average height for one frame, repositioning every
      // following block — a visible flicker of the content below the caret. The
      // real (possibly unchanged) height is reconciled on the next frame by the
      // measured-block widget, so leaving the stale value yields one frame of a
      // near-correct height instead of one frame of a wrong average.
      final dirty = widget.controller.lastChangedBlockIds;
      if (dirty == null) {
        _extentCache.clear();
      } else if (dirty.isNotEmpty) {
        for (final id in dirty) {
          _layoutCache.removeBlock(id);
        }
      }
      // Keep the platform IME candidate window anchored at the caret, and
      // scroll a programmatically-moved caret back into view. Both run in a
      // post-frame callback so the caret's render box reflects the latest
      // selection (and any keep-alive mount) before we read its global rect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_inputClient.isAttached) {
          _inputClient.syncBuffer();
        }
        // Bring an off-screen caret into view — but only when it actually
        // moved. IME composition updates fire notifyListeners without changing
        // the caret's position; skipping the scroll check there avoids a
        // layout + localToGlobal round-trip per composition keystroke.
        final selection = widget.controller.selection;
        if (selection?.isCollapsed == true) {
          final skipCaretScroll = _skipNextCaretScrollIntoView;
          _skipNextCaretScrollIntoView = false;
          final caretKey = _CaretKey(
            selection!.extent.blockIndex,
            selection.extent.offset,
          );
          if (caretKey != _lastScrollCheckedCaret) {
            _lastScrollCheckedCaret = caretKey;
            if (!skipCaretScroll) {
              _scrollCaretIntoView();
            }
          }
        } else {
          _skipNextCaretScrollIntoView = false;
          _lastScrollCheckedCaret = null;
        }
      });
      setState(() {});
    }
  }

  void _syncTableToolbarOverlayWithSelection() {
    final request = _tableToolbarRequestForCurrentSelection();
    if (request == null) {
      _tableToolbarOverlayController.hide();
      return;
    }
    _tableToolbarOverlayController.show(request);
  }

  TableFloatingToolbarOverlayRequest?
      _tableToolbarRequestForCurrentSelection() {
    if (widget.readOnly || !widget.controller.canEdit) {
      return null;
    }
    final tableRange = widget.controller.selection?.tableCellRange;
    if (tableRange == null) {
      return null;
    }
    final tableBlock = _tableBlockAt(tableRange.blockIndex);
    final normalizedRange =
        tableBlock != null && tableBlock.id == tableRange.tableBlockId
            ? _normalizeTableRange(
                tableBlock,
                blockIndex: tableRange.blockIndex,
                startRow: tableRange.startRow,
                endRow: tableRange.endRow,
                startColumn: tableRange.startColumn,
                endColumn: tableRange.endColumn,
              )
            : null;
    if (tableBlock == null ||
        normalizedRange == null ||
        tableBlock.id != tableRange.tableBlockId) {
      return null;
    }
    final anchor = _tableToolbarOverlayController.anchorFor(
      tableBlock.id,
      blockIndex: tableRange.blockIndex,
    );
    if (anchor == null) {
      return null;
    }
    return TableFloatingToolbarOverlayRequest(
      owner: anchor.owner,
      anchorLink: anchor.anchorLink,
      anchorRect: anchor.anchorRect,
      visibleTop: anchor.visibleTop,
      visibleBottom: anchor.visibleBottom,
      tableBlockId: tableBlock.id,
      blockIndex: tableRange.blockIndex,
      selectionRange: normalizedRange,
      minWidth: _kTableToolbarMinWidth,
      gap: _kTableFloatingToolbarGap,
      fallbackHeight: _kTableFloatingToolbarEstimatedHeight,
      toolbarBuilder: (context) => _TableFloatingToolbar(
        block: tableBlock,
        blockIndex: tableRange.blockIndex,
        range: normalizedRange,
        onAction: _handleTableToolbarAction,
      ),
    );
  }

  void _syncObjectBlockToolbarOverlayWithSelection() {
    final request = _objectBlockToolbarOverlayController.request;
    if (request == null) {
      return;
    }
    final block = _blockAt(request.blockIndex);
    if (block == null || block.id != request.blockId) {
      _objectBlockToolbarOverlayController.hide();
      return;
    }
    final selected = _selectionTouchesPath(
      widget.controller.selection,
      request.blockIndex,
      request.blockId,
      PositionPath.blockObject(request.blockId),
      _kAtomicBlockSelectionLength,
    );
    if (!selected) {
      _objectBlockToolbarOverlayController.hide();
    }
  }

  void _handleFocusChanged() {
    if (!mounted) {
      return;
    }
    final focusNode = _effectiveFocusNode;
    if (widget.enableIme && focusNode.hasFocus && !widget.readOnly) {
      _inputClient.attach();
    } else {
      _inputClient.detach();
    }
    if (focusNode.hasFocus) {
      _hadEditorFocus = true;
    } else if (_hadEditorFocus) {
      widget.slashMenuController?.close();
      _closeMentionSearch();
    }
    if (!focusNode.hasFocus) {
      _mobileCaretToolbarPosition = null;
    }
    setState(() {});
  }

  /// Resolves the [FlutterView.viewId] backing this editor for the IME bridge.
  /// Returns `null` when not yet mounted (no [BuildContext]); callers must
  /// tolerate that — the attach path still works on platforms that do not
  /// enforce the viewId contract.
  int? _resolveViewId() {
    if (!mounted) {
      return null;
    }
    final context = this.context;
    return View.maybeOf(context)?.viewId;
  }

  OutlineBlockProjection _visibleBlockProjectionFor(List<BlockNode> blocks) {
    final outline = widget.outlineController;
    if (outline == null) {
      return OutlineBlockProjection.all(blocks);
    }
    assert(
      identical(outline.editor, widget.controller),
      'outlineController must be created with the same WenzRichTextController.',
    );
    if (!identical(outline.editor, widget.controller)) {
      return OutlineBlockProjection.all(blocks);
    }
    return outline.visibleBlockProjection();
  }

  List<String?> _listMarkersForDocument(List<BlockNode> blocks) {
    if (identical(blocks, _listMarkerBlocks)) {
      return _cachedListMarkers;
    }
    final previousBlocks = _listMarkerBlocks;
    if (blocks is PersistentBlockList &&
        previousBlocks != null &&
        blocks.length == previousBlocks.length) {
      final delta = blocks.deltaSince(previousBlocks);
      if (delta != null) {
        var markerSemanticsChanged = false;
        for (final index in delta.changedIndexes) {
          if (!_sameListMarkerSemantics(
            previousBlocks[index],
            blocks[index],
          )) {
            markerSemanticsChanged = true;
            break;
          }
        }
        if (!markerSemanticsChanged) {
          _listMarkerBlocks = blocks;
          return _cachedListMarkers;
        }
      }
    }
    _listMarkerBlocks = blocks;
    _cachedListMarkers = List<String?>.unmodifiable(_listMarkersFor(blocks));
    return _cachedListMarkers;
  }

  void _syncFindControllerOutline() {
    widget.findController?.attachOutlineController(widget.outlineController);
  }

  bool _revealCurrentSelectionIfHidden() {
    final outline = widget.outlineController;
    final selection = widget.controller.selection;
    if (outline == null ||
        selection == null ||
        !identical(outline.editor, widget.controller)) {
      return false;
    }
    return outline.expandToRevealSelection(selection);
  }

  _CaretKey? _currentCollapsedCaretKey() {
    final selection = widget.controller.selection;
    if (selection?.isCollapsed != true) {
      return null;
    }
    return _CaretKey(
      selection!.extent.blockIndex,
      selection.extent.offset,
    );
  }

  bool _expandHiddenContentAdjacentToSelection({required bool forward}) {
    if (_revealCurrentSelectionIfHidden()) {
      return true;
    }
    final outline = widget.outlineController;
    final selection = widget.controller.selection;
    if (outline == null ||
        selection == null ||
        !selection.isCollapsed ||
        !identical(outline.editor, widget.controller)) {
      return false;
    }
    final position = selection.extent;
    if (!_isAtBlockBoundary(position, forward: forward)) {
      return false;
    }
    final blocks = widget.controller.document.blocks;
    final adjacentIndex = position.blockIndex + (forward ? 1 : -1);
    if (adjacentIndex < 0 || adjacentIndex >= blocks.length) {
      return false;
    }
    return outline.expandToRevealBlockId(blocks[adjacentIndex].id);
  }

  bool _isAtBlockBoundary(
    DocumentPosition position, {
    required bool forward,
  }) {
    final blocks = widget.controller.document.blocks;
    if (position.blockIndex < 0 || position.blockIndex >= blocks.length) {
      return false;
    }
    final block = blocks[position.blockIndex];
    if (position.path.isBlockText && block is TextBlockNode) {
      final length = inlineNodesLength(block.content);
      final offset = position.offset.clamp(0, length).toInt();
      return forward ? offset >= length : offset <= 0;
    }
    if (position.path.isBlockCode && block is CodeBlockNode) {
      final offset = position.offset.clamp(0, block.code.length).toInt();
      return forward ? offset >= block.code.length : offset <= 0;
    }
    return position.path.isBlockObject;
  }

  bool get _hasHeadingCollapseChrome {
    final outline = widget.outlineController;
    return outline != null && identical(outline.editor, widget.controller);
  }

  HeadingCollapseState? _headingCollapseStateFor(BlockNode block) {
    final outline = widget.outlineController;
    if (outline == null || !identical(outline.editor, widget.controller)) {
      return null;
    }
    // Only heading text blocks that cover child blocks expose the left-side
    // collapse affordance. Leaf headings return null so no disabled button,
    // tooltip, semantics button, or selection exclusion is mounted.
    if (block is! TextBlockNode || block.type != BlockType.heading) {
      return null;
    }
    final state = outline.collapseStateForBlockId(block.id);
    if (state == null || !state.canCollapse) {
      return null;
    }
    return HeadingCollapseState(
      canCollapse: state.canCollapse,
      isCollapsed: state.isCollapsed,
      hiddenBlockCount: state.coveredBlockCount,
    );
  }

  void _handleHeadingCollapseToggled(String blockId) {
    widget.outlineController?.toggleBodyHeadingByBlockId(blockId);
  }

  _ResolvedBlockReorderDropTarget _resolveBlockReorderDropTarget(
    BlockReorderDropTarget target,
  ) {
    final blocks = widget.controller.document.blocks;
    final rawInsertionIndex =
        target.insertionIndex.clamp(0, blocks.length).toInt();
    final fallback = _ResolvedBlockReorderDropTarget(
      indicatorTarget: target,
      insertionIndex: rawInsertionIndex,
    );
    if (target.placement != BlockReorderDropPlacement.after) {
      return fallback;
    }
    if (target.blockIndex < 0 ||
        target.blockIndex >= blocks.length ||
        blocks[target.blockIndex].id != target.blockId) {
      return fallback;
    }
    final outline = widget.outlineController;
    if (outline == null || !identical(outline.editor, widget.controller)) {
      return fallback;
    }
    if (!outline.canCollapseByBlockId(target.blockId)) {
      return fallback;
    }
    final headingRange = outline.headingRangeForBlockIndex(target.blockIndex);
    if (headingRange == null || headingRange.length <= 1) {
      return fallback;
    }
    final insertionIndex =
        headingRange.endBlockIndexExclusive.clamp(0, blocks.length).toInt();
    final indicatorTarget =
        _registry.blockReorderDropTargetAfterLastMountedRowInRange(
              startBlockIndex: headingRange.startBlockIndex + 1,
              endBlockIndexExclusive: insertionIndex,
            ) ??
            target;
    return _ResolvedBlockReorderDropTarget(
      indicatorTarget: indicatorTarget,
      insertionIndex: insertionIndex,
    );
  }

  _BlockMoveRange? _blockMoveRangeFor(int blockIndex) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    final outline = widget.outlineController;
    if (outline != null && identical(outline.editor, widget.controller)) {
      final headingRange = outline.headingRangeForBlockIndex(blockIndex);
      if (headingRange != null) {
        return _BlockMoveRange(
          startBlockIndex: headingRange.startBlockIndex,
          endBlockIndexExclusive: headingRange.endBlockIndexExclusive,
        );
      }
    }
    return _BlockMoveRange.single(blockIndex);
  }

  void _openFormulaEditor(_FormulaEditTarget target) {
    if (widget.readOnly) {
      return;
    }
    widget.slashMenuController?.close();
    _closeMentionSearch();
    _formulaEditController.text = target.formula;
    _formulaEditController.selection = TextSelection.collapsed(
      offset: _formulaEditController.text.length,
    );
    setState(() {
      _formulaEditTarget = target;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _formulaEditTarget == target) {
        _formulaEditFocusNode.requestFocus();
      }
    });
  }

  void _closeFormulaEditor() {
    if (_formulaEditTarget == null) {
      return;
    }
    setState(() {
      _formulaEditTarget = null;
    });
  }

  void _confirmFormulaEditor() {
    final target = _formulaEditTarget;
    if (target == null) {
      return;
    }
    final text = _formulaEditController.text.trim();
    if (text.isNotEmpty) {
      if (target.position != null) {
        widget.controller.updateInlineFormula(
          position: target.position!,
          text: text,
        );
      } else if (target.blockId != null) {
        widget.controller.updateBlockFormula(
          blockId: target.blockId!,
          text: text,
        );
      }
    }
    _closeFormulaEditor();
    widget.controller.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = _effectiveFocusNode;
    _syncFocusListener(focusNode);
    final sourceBlocks = widget.controller.document.blocks;
    final projection = _visibleBlockProjectionFor(sourceBlocks);
    final blocks = projection.visibleBlocks;
    final blockIndexes = projection.visibleBlockIndexes;
    _registry.retainBlocks(projection.visibleBlockIds);
    // Heading collapse should project this original block list for rendering
    // only. The source document order, block ids/indexes, codecs, and edit
    // history remain unchanged while read-only and editable editors may toggle
    // the view state.
    if (blocks.isEmpty) {
      return _buildEditorShell(
        context,
        focusNode,
        _wrapMentionTapHandler(const SizedBox.shrink()),
      );
    }

    // Show a caret only in editable mode. Read-only mode still allows
    // selection (see _handleSelectionChanged) but has no editing caret.
    final selection = widget.controller.selection;
    final canEdit = !widget.readOnly && widget.controller.canEdit;
    final showCaret = !widget.readOnly &&
        focusNode.hasFocus &&
        selection?.isCollapsed == true;
    final useMobileSelectionUi =
        EditorTokens.shouldUseMobileSelectionUi(context);
    // Blocks that must stay mounted even when scrolled out of view: the caret
    // (collapsed selection) and the selection endpoints. Keeping these alive
    // means the caret and selection highlight always paint and the geometry
    // registry always knows their box, so cross-block selection / caret do not
    // break under virtualisation. Usually resolves to 1-2 ids.
    final keepAliveIds = _keepAliveBlockIds(widget.controller.selection)
        .intersection(projection.visibleBlockIds);
    // Block ids whose content changed in the most recent controller mutation.
    // null = treat every block as changed (full rebuild), e.g. after a document
    // replace where no diff was available. Used by _KeepAliveBlock to skip
    // re-rendering blocks whose content + selection-relevance did not change.
    final dirtyIds = widget.controller.lastChangedBlockIds;
    final findMatches =
        widget.findController?.matches ?? const <FindReplaceMatch>[];
    final currentFindMatch = widget.findController?.currentMatch;
    final listMarkers = _listMarkersForDocument(sourceBlocks);
    final effectiveTextStyle = _effectiveEditorTextStyle(
      widget.textStyle,
      widget.defaultTextColor,
    );

    _extentCache.retainBlocks(sourceBlocks);

    final editor = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handlePointerSignal,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: _MeasuredVirtualBlockList(
          controller: _scrollController,
          padding: widget.padding,
          physics: widget.physics,
          blocks: blocks,
          blockIndexes: blockIndexes,
          blockSpacing: widget.blockSpacing,
          extentCache: _extentCache,
          keepAliveIds: keepAliveIds,
          onExtentUpdated: _scrollCaretIntoViewIfNeeded,
          shouldSuppressExtentUpdate: _isInUserScrollCooldown,
          itemBuilder: (context, blockIndex) {
            final block = sourceBlocks[blockIndex];
            final blockMoveRange = _blockMoveRangeFor(blockIndex) ??
                _BlockMoveRange.single(blockIndex);
            return _KeepAliveBlock(
              key: ValueKey<String>(block.id),
              block: block,
              blockIndex: blockIndex,
              blockCount: sourceBlocks.length,
              blockMoveRange: blockMoveRange,
              listMarker: listMarkers[blockIndex],
              quoteGroupPosition:
                  _quoteGroupPositionFor(sourceBlocks, blockIndex),
              keepAlive: keepAliveIds.contains(block.id),
              blockChanged: dirtyIds == null || dirtyIds.contains(block.id),
              selection: selection,
              compositionState: widget.controller.compositionState,
              registry: _registry,
              blockRenderers: _blockRenderers,
              showCaret: showCaret,
              textStyle: effectiveTextStyle,
              showDebugOverlay: widget.showDebugOverlay,
              canEdit: canEdit,
              mediaResolver: widget.mediaResolver,
              inlineEmbedRenderer: widget.inlineEmbedRenderer,
              onMentionTap: widget.onMentionTap,
              reserveHeadingCollapseRail: _hasHeadingCollapseChrome,
              headingCollapseState: _headingCollapseStateFor(block),
              onHeadingCollapseToggled: _handleHeadingCollapseToggled,
              resolveBlockReorderDropTarget: _resolveBlockReorderDropTarget,
              onCodeLanguageChanged: widget.readOnly
                  ? null
                  : (language) {
                      widget.controller.setCodeLanguage(
                        language,
                        blockIndex: blockIndex,
                      );
                    },
              onCodeCopied: _copyTextToClipboard,
              onCalloutVariantChanged: widget.readOnly
                  ? null
                  : (variant) {
                      widget.controller.setCalloutVariant(
                        variant,
                        blockIndex: blockIndex,
                      );
                    },
              onTableToolbarAction:
                  widget.readOnly || !widget.controller.canEdit
                      ? null
                      : _handleTableToolbarAction,
              tableToolbarOverlayController: _tableToolbarOverlayController,
              objectBlockToolbarOverlayController:
                  _objectBlockToolbarOverlayController,
              onTableColumnResize: widget.readOnly || !widget.controller.canEdit
                  ? null
                  : _handleTableColumnResize,
              onImageBlockResize: widget.readOnly || !widget.controller.canEdit
                  ? null
                  : _handleMediaBlockResize,
              onTodoCheckedChanged:
                  widget.readOnly ? null : _handleTodoCheckedChanged,
              onObjectBlockAction: _handleObjectBlockAction,
              onRowBlockFormatChanged:
                  widget.readOnly ? null : _handleRowBlockFormatChanged,
              findMatches: findMatches,
              currentFindMatch: currentFindMatch,
            );
          },
        ),
      ),
    );
    // Phone-style selection handles; desktop target platforms never mount the
    // overlay even when the editor is rendered in a narrow window.
    final showMobileSelectionHandles =
        widget.enableMobileSelectionHandles && useMobileSelectionUi;
    final editorStack = Stack(
      key: _editorOverlayKey,
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        SelectionGestureOverlay(
          registry: _registry,
          scrollController: _scrollController,
          focusNode: focusNode,
          readOnly: widget.readOnly,
          useMobileTouchGestures: useMobileSelectionUi,
          onSelectionChanged: _handleSelectionChanged,
          currentSelection: widget.controller.selection,
          shouldDeferTapSelection: _shouldDeferInlineVideoResolverTapSelection,
          shouldCommitDeferredTapSelection:
              _shouldCommitInlineVideoResolverTapSelection,
          shouldRequestFocusForTapSelection: _shouldRequestFocusForTapSelection,
          onMobileCaretTap: _handleMobileCaretTap,
          onMobileCaretToolbarDismissed: _dismissMobileCaretToolbar,
          onTapBeyondContent: _handleTapBeyondContent,
          onContextMenuRequested: _handleContextMenuRequested,
          linkProbe: _probeLinkAtGlobal,
          onLinkHover: _handleLinkHover,
          onLinkOpen: widget.onOpenLink == null ? null : _openHoveredLink,
          child: editor,
        ),
        if (_formulaEditTarget != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeFormulaEditor,
            ),
          ),
        if (_formulaEditTarget != null) _buildFormulaEditorOverlay(),
        if (_linkHover != null) _buildLinkHoverOverlay(),
        if (_mentionSearchTrigger != null) _buildMentionSearchOverlay(),
        if (showMobileSelectionHandles)
          MobileSelectionHandlesOverlay(
            registry: _registry,
            controller: widget.controller,
            scrollController: _scrollController,
            containerKey: _editorOverlayKey,
            caretToolbarPosition: _mobileCaretToolbarPosition,
            selectionToolbarBuilder: _buildMobileSelectionToolbar,
          ),
      ],
    );
    // Compact-density touch surfaces have no mouse-hover link popup; a
    // long-press on an inline link surfaces 打开/复制 actions instead.
    final videoTapAwareStack = _VideoResolverTapRouteScope(
      registerTapTarget: _registerInlineVideoResolverTapTarget,
      unregisterTapTarget: _unregisterInlineVideoResolverTapTarget,
      child: editorStack,
    );
    final touchAwareStack = EditorTokens.resolve(context).isMobile
        ? _TouchLinkLongPressHandler(
            onLongPressLink: _handleLinkLongPress,
            child: videoTapAwareStack,
          )
        : videoTapAwareStack;
    var scopedEditorStack = _wrapMentionTapHandler(touchAwareStack);
    if (!widget.readOnly && widget.controller.canEdit) {
      scopedEditorStack = _ImageDescriptionEditRequestScope(
        controller: _ImageDescriptionEditRequestController(
          onRequested: _openImageDescriptionEditor,
        ),
        child: scopedEditorStack,
      );
    }
    return _buildEditorShell(
      context,
      focusNode,
      widget.readOnly
          ? scopedEditorStack
          : _FormulaEditRequestScope(
              controller: _FormulaEditRequestController(
                onRequested: _openFormulaEditor,
              ),
              child: scopedEditorStack,
            ),
    );
  }

  Widget _wrapMentionTapHandler(Widget child) {
    return WenzMentionTapHandler(
      onMentionTap: widget.onMentionTap,
      selection: widget.controller.selection,
      child: child,
    );
  }

  Widget _buildFormulaEditorOverlay() {
    final anchor = _formulaEditorAnchor();
    final width = anchor.width;
    return Positioned(
      left: anchor.left,
      top: anchor.top,
      child: SizedBox(
        width: width,
        child: _FormulaEditPopup(
          controller: _formulaEditController,
          focusNode: _formulaEditFocusNode,
          onConfirm: _confirmFormulaEditor,
          onCancel: _closeFormulaEditor,
        ),
      ),
    );
  }

  _FormulaEditorAnchor _formulaEditorAnchor() {
    final target = _formulaEditTarget;
    final overlayBox = _editorOverlayKey.currentContext?.findRenderObject();
    if (target == null || overlayBox is! RenderBox || !overlayBox.hasSize) {
      final fallback = widget.padding.resolve(TextDirection.ltr).topLeft;
      return _FormulaEditorAnchor(
        left: fallback.dx,
        top: fallback.dy,
        width: _kFormulaEditorWidth,
      );
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final keyboardInset = mediaQuery?.viewInsets.bottom ?? 0.0;
    final viewportHeight = mediaQuery?.size.height ?? overlayBox.size.height;
    final overlayTop = overlayBox.localToGlobal(Offset.zero).dy;
    final keyboardTop = viewportHeight - keyboardInset;
    final visibleBottom = math.max(
      _kPopupViewportInset,
      math.min(
        overlayBox.size.height,
        keyboardInset > 0 ? keyboardTop - overlayTop : overlayBox.size.height,
      ),
    );
    final localRect =
        overlayBox.globalToLocal(target.anchor.topLeft) & target.anchor.size;
    final width = math.min(
      _kFormulaEditorWidth,
      math.max(0.0, overlayBox.size.width - _kPopupViewportInset * 2),
    );
    final preferredBelowTop = localRect.bottom + _kFormulaEditorGap;
    final roomBelow = visibleBottom - preferredBelowTop - _kPopupViewportInset;
    final roomAbove = localRect.top - _kFormulaEditorGap - _kPopupViewportInset;
    final opensAbove =
        roomBelow < _kFormulaEditorEstimatedHeight && roomAbove > roomBelow;
    final preferredTop = opensAbove
        ? localRect.top - _kFormulaEditorEstimatedHeight - _kFormulaEditorGap
        : preferredBelowTop;
    final maxLeft = overlayBox.size.width - width - _kPopupViewportInset;
    final maxTop = visibleBottom - _kFormulaEditorEstimatedHeight;
    final leftMin =
        maxLeft >= _kPopupViewportInset ? _kPopupViewportInset : 0.0;
    final topMin = maxTop >= _kPopupViewportInset ? _kPopupViewportInset : 0.0;
    return _FormulaEditorAnchor(
      left: localRect.left.clamp(leftMin, maxLeft > 0 ? maxLeft : 0).toDouble(),
      top: preferredTop.clamp(topMin, maxTop > 0 ? maxTop : 0).toDouble(),
      width: width,
    );
  }

  Widget _buildSlashMenuOverlay(SlashMenuController controller) {
    final anchor = _slashMenuAnchor();
    final positioningBox = _slashMenuPositioningBox();
    final hasPositioningSize =
        positioningBox is RenderBox && positioningBox.hasSize;
    final overlaySize = hasPositioningSize ? positioningBox.size : Size.zero;
    final availableWidth = math.max(
      0.0,
      hasPositioningSize
          ? overlaySize.width - anchor.offset.dx - _kPopupViewportInset
          : _kPopupMenuMaxWidth,
    );
    final availableHeight = math.max(
      0.0,
      hasPositioningSize
          ? anchor.availableHeight ??
              (anchor.opensAbove
                  ? anchor.offset.dy - _kPopupViewportInset
                  : overlaySize.height -
                      anchor.offset.dy -
                      _kPopupViewportInset)
          : _kPopupMenuMaxHeight,
    );
    return Positioned(
      left: anchor.offset.dx,
      top: anchor.opensAbove ? null : anchor.offset.dy,
      bottom: anchor.opensAbove && hasPositioningSize
          ? overlaySize.height - anchor.offset.dy
          : null,
      child: TapRegion(
        groupId: this,
        child: WenzSlashMenuOverlay(
          controller: controller,
          maxWidth: math.min(_kPopupMenuMaxWidth, availableWidth),
          maxHeight: math.min(_kPopupMenuMaxHeight, availableHeight),
        ),
      ),
    );
  }

  Widget _buildEditorShell(
    BuildContext context,
    FocusNode focusNode,
    Widget child,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _handleViewportConstraintsChanged(constraints);
        return TapRegion(
          groupId: this,
          enabled: widget.slashMenuController?.isOpen == true ||
              _mentionSearchTrigger != null ||
              _formulaEditTarget != null,
          onTapOutside: (_) {
            widget.slashMenuController?.close();
            _closeMentionSearch();
            _closeFormulaEditor();
          },
          child: _SharedLayoutCacheScope(
            cache: _layoutCache,
            child: Focus(
              focusNode: focusNode,
              autofocus: widget.autofocus,
              onKeyEvent: _handleKeyEvent,
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                enabled: true,
                textField: true,
                readOnly: widget.readOnly,
                focusable: true,
                focused: focusNode.hasFocus,
                multiline: true,
                label: widget.accessibility
                    .effectiveLabel(readOnly: widget.readOnly),
                hint: widget.accessibility
                    .effectiveHint(readOnly: widget.readOnly),
                onTap: () => focusNode.requestFocus(),
                onFocus: () => focusNode.requestFocus(),
                child: _withHighContrastFocusHighlight(
                  context,
                  focusNode,
                  ColoredBox(
                    key: _editorBackgroundKey,
                    color: _editorBackgroundColor(Theme.of(context)),
                    child: TableFloatingToolbarOverlayHost(
                      controller: _tableToolbarOverlayController,
                      child: ObjectBlockToolbarOverlayHost(
                        controller: _objectBlockToolbarOverlayController,
                        child: _buildExternalImageDropTarget(child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleViewportConstraintsChanged(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return;
    }
    final nextSize = Size(width, height);
    final previousSize = _lastViewportSize;
    _lastViewportSize = nextSize;
    if (previousSize == null ||
        previousSize == nextSize ||
        !EditorTokens.shouldUseMobileSelectionUi(context)) {
      return;
    }
    if (_viewportCaretCheckScheduled) {
      return;
    }
    _viewportCaretCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportCaretCheckScheduled = false;
      if (!mounted ||
          widget.readOnly ||
          !_effectiveFocusNode.hasFocus ||
          widget.controller.selection?.isCollapsed != true) {
        return;
      }
      _scrollCaretIntoViewAfterViewportResize();
    });
  }

  /// Keeps the existing offset across viewport changes unless the laid-out
  /// caret is clipped by the new bounds. Unlike programmatic caret movement,
  /// this path never estimates an unmounted caret position, so a resize cannot
  /// pull a user-scrolled virtual list back toward an off-screen selection.
  void _scrollCaretIntoViewAfterViewportResize() {
    if (!_scrollController.hasClients) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    final caretRect = _registry.caretRectForPosition(selection.extent);
    if (renderBox == null || !renderBox.hasSize || caretRect == null) {
      return;
    }
    final position = _scrollController.position;
    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    final caretTopInContent = caretRect.top - viewportTop + position.pixels;
    final caretBottomInContent = caretTopInContent + caretRect.height;
    final visibleTop = position.pixels;
    final visibleBottom = visibleTop + renderBox.size.height;
    if (caretTopInContent < visibleTop) {
      _jumpToScrollOffset(caretTopInContent);
    } else if (caretBottomInContent > visibleBottom) {
      _jumpToScrollOffset(caretBottomInContent - renderBox.size.height);
    }
  }

  bool get _canAcceptExternalImageDrop =>
      widget.enableExternalImageInput &&
      widget.enableExternalDragDrop &&
      !widget.readOnly &&
      widget.controller.canEdit;

  DocumentSelection? _selectionForExternalImageDropGlobalOffset(
    Offset globalPosition,
  ) {
    if (!_canAcceptExternalImageDrop ||
        _registry.isSelectionExcluded(globalPosition)) {
      return null;
    }
    final position = _registry.positionFromGlobalOffset(globalPosition);
    if (position == null) {
      return null;
    }
    return DocumentSelection(base: position, extent: position);
  }

  Widget _buildExternalImageDropTarget(Widget child) {
    if (!_canAcceptExternalImageDrop) {
      return child;
    }
    // Touch form factors have no desktop-style external drag source, and the
    // DropRegion's raw pointer routing interferes with touch selection gestures.
    // Keep narrow desktop windows eligible while skipping mobile target
    // platforms entirely.
    if (_isTouchExternalImageDropSurface) {
      return child;
    }
    return DragTarget<List<ExternalImageInput>>(
      onWillAcceptWithDetails: (details) {
        final insertionSelection = _selectionForExternalImageDropGlobalOffset(
          details.offset,
        );
        final willAccept = _canAcceptExternalImageDrop &&
            insertionSelection != null &&
            details.data.any(isUsableExternalImageInput);
        _setExternalImageDropActive(willAccept);
        return willAccept;
      },
      onLeave: (_) => _clearExternalImageDropActive(),
      onAcceptWithDetails: (details) {
        final insertionSelection = _selectionForExternalImageDropGlobalOffset(
          details.offset,
        );
        _clearExternalImageDropActive();
        if (insertionSelection == null) {
          return;
        }
        unawaited(
          _handleExternalImageDropInputs(
            details.data,
            insertionSelection: insertionSelection,
          ),
        );
      },
      builder: (context, _, __) {
        return super_drag.DropRegion(
          formats: _externalImageDropFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropEnter: (dynamic event) {
            _clearExternalImageDropActive();
          },
          onDropOver: (dynamic event) {
            return _syncExternalImageDropActiveForSession(
              event.session,
              globalPosition: event.position.global,
            );
          },
          onDropLeave: (dynamic event) {
            _clearExternalImageDropActive();
          },
          onPerformDrop: (dynamic event) async {
            final insertionSelection =
                _selectionForExternalImageDropGlobalOffset(
              event.position.global,
            );
            _clearExternalImageDropActive();
            if (insertionSelection == null) {
              return;
            }
            final inputs = await _readExternalImageDropInputs(event.session);
            await _handleExternalImageDropInputs(
              inputs,
              insertionSelection: insertionSelection,
            );
          },
          child: _buildExternalImageDropStack(context, child),
        );
      },
    );
  }

  bool get _isTouchExternalImageDropSurface =>
      EditorTokens.isMobileSelectionUiPlatform(defaultTargetPlatform);

  Widget _buildExternalImageDropStack(BuildContext context, Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (_externalImageDropActive) _buildExternalImageDropOverlay(context),
      ],
    );
  }

  Widget _buildExternalImageDropOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          key: _externalImageDropOverlayKey,
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(24),
            border: Border.all(
              color: scheme.primary.withAlpha(180),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  void _clearExternalImageDropActive() {
    _externalImageDropProbeEpoch++;
    _setExternalImageDropActive(false);
  }

  Future<super_drag.DropOperation> _syncExternalImageDropActiveForSession(
    dynamic session, {
    Offset? globalPosition,
  }) async {
    final epoch = ++_externalImageDropProbeEpoch;
    final operation = await _externalImageDropOperationFor(
      session,
      globalPosition: globalPosition,
    );
    if (epoch == _externalImageDropProbeEpoch) {
      _setExternalImageDropActive(
        operation != super_drag.DropOperation.none,
      );
    }
    return operation;
  }

  void _setExternalImageDropActive(bool active) {
    final next = active && _canAcceptExternalImageDrop;
    if (_externalImageDropActive == next) {
      return;
    }
    if (!mounted) {
      _externalImageDropActive = next;
      return;
    }
    setState(() {
      _externalImageDropActive = next;
    });
  }

  Future<super_drag.DropOperation> _externalImageDropOperationFor(
    dynamic session, {
    Offset? globalPosition,
  }) async {
    if (!_canAcceptExternalImageDrop ||
        !_dropSessionAllowsCopy(session) ||
        (globalPosition != null &&
            _selectionForExternalImageDropGlobalOffset(globalPosition) ==
                null)) {
      return super_drag.DropOperation.none;
    }
    final canProvideImage = await _dropSessionCanProvideExternalImage(session);
    if (!canProvideImage) {
      return super_drag.DropOperation.none;
    }
    return super_drag.DropOperation.copy;
  }

  bool _dropSessionAllowsCopy(dynamic session) {
    try {
      final allowedOperations = session.allowedOperations;
      if (allowedOperations == null) {
        return true;
      }
      if (allowedOperations is Iterable<Object?>) {
        return allowedOperations.contains(super_drag.DropOperation.copy);
      }
      if (allowedOperations == super_drag.DropOperation.copy) {
        return true;
      }
      try {
        return allowedOperations.contains(super_drag.DropOperation.copy) ==
            true;
      } on Object {
        return true;
      }
    } on Object {
      return true;
    }
  }

  Future<bool> _dropSessionCanProvideExternalImage(dynamic session) async {
    for (final item in _dropSessionItems(session)) {
      if (await _dropItemCanProvideExternalImage(item)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _dropItemCanProvideExternalImage(dynamic item) async {
    for (final format in _externalImageDropFileFormats) {
      if (_dropItemCanProvideFormat(item, format.format)) {
        return true;
      }
    }
    if (!_dropItemCanProvideFormat(item, super_clipboard.Formats.fileUri)) {
      return false;
    }
    final reader = _dropItemDataReader(item);
    if (reader == null) {
      return false;
    }
    final fileUriInput = await _readExternalImageDropFileUri(reader);
    return fileUriInput != null && isUsableExternalImageInput(fileUriInput);
  }

  bool _dropItemCanProvideFormat(dynamic item, dynamic format) {
    try {
      if (item.canProvide(format) == true) {
        return true;
      }
    } on Object {
      // Fall through to dataReader when a fake item only exposes that surface.
    }
    final reader = _dropItemDataReader(item);
    return reader != null && _readerCanProvide(reader, format);
  }

  List<dynamic> _dropSessionItems(dynamic session) {
    try {
      final items = session.items;
      if (items is Iterable<Object?>) {
        return List<dynamic>.from(items);
      }
    } on Object {
      return const <dynamic>[];
    }
    return const <dynamic>[];
  }

  dynamic _dropItemDataReader(dynamic item) {
    try {
      return item.dataReader;
    } on Object {
      return null;
    }
  }

  bool _readerCanProvide(dynamic reader, dynamic format) {
    try {
      return reader.canProvide(format) == true;
    } on Object {
      return false;
    }
  }

  Future<List<ExternalImageInput>> _readExternalImageDropInputs(
    dynamic session,
  ) async {
    final inputs = <ExternalImageInput>[];
    for (final item in _dropSessionItems(session)) {
      final reader = _dropItemDataReader(item);
      if (reader == null) {
        continue;
      }
      final fileUriInput = await _readExternalImageDropFileUri(reader);
      if (fileUriInput != null && isUsableExternalImageInput(fileUriInput)) {
        inputs.add(fileUriInput);
        continue;
      }
      final memoryInput = await _readExternalImageDropFile(reader);
      if (memoryInput != null && isUsableExternalImageInput(memoryInput)) {
        inputs.add(memoryInput);
      }
    }
    return inputs;
  }

  Future<ExternalImageInput?> _readExternalImageDropFileUri(
    dynamic reader,
  ) async {
    if (!_readerCanProvide(reader, super_clipboard.Formats.fileUri)) {
      return null;
    }
    final suggestedName = await _readDropSuggestedName(reader);
    final value = await _readDropValue(reader, super_clipboard.Formats.fileUri);
    return _externalImageDropFileUriInput(
      value,
      fileName: suggestedName,
    );
  }

  ExternalImageInput? _externalImageDropFileUriInput(
    Object? value, {
    String? fileName,
  }) {
    if (value is Uri) {
      return ExternalImageInput.fileUri(
        uri: value,
        source: ExternalImageInputSource.drop,
        fileName: fileName,
      );
    }
    if (value is String) {
      return ExternalImageInput.fileLocation(
        location: value,
        source: ExternalImageInputSource.drop,
        fileName: fileName,
      );
    }
    return null;
  }

  Future<ExternalImageInput?> _readExternalImageDropFile(dynamic reader) async {
    for (final format in _externalImageDropFileFormats) {
      if (!_readerCanProvide(reader, format.format)) {
        continue;
      }
      final input = await _readDropFile(reader, format);
      if (input != null) {
        return input;
      }
    }
    return null;
  }

  Future<String?> _readDropSuggestedName(dynamic reader) async {
    try {
      final name = await reader.getSuggestedName();
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<Object?> _readDropValue(dynamic reader, dynamic format) {
    final completer = Completer<Object?>();

    void complete(Object? value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    try {
      final progress = reader.getValue(
        format,
        (dynamic value) => complete(value),
        onError: (Object error) => complete(null),
      );
      if (progress == null) {
        complete(null);
      }
    } on Object {
      complete(null);
    }
    return completer.future;
  }

  Future<ExternalImageInput?> _readDropFile(
    dynamic reader,
    _ExternalImageDropFileFormat format,
  ) {
    final completer = Completer<ExternalImageInput?>();

    void complete(ExternalImageInput? input) {
      if (!completer.isCompleted) {
        completer.complete(input);
      }
    }

    try {
      final progress = reader.getFile(
        format.format,
        (dynamic file) async {
          try {
            final bytes = _dropFileBytes(await file.readAll());
            if (bytes == null) {
              complete(null);
              return;
            }
            complete(
              ExternalImageInput.memory(
                bytes: bytes,
                source: ExternalImageInputSource.drop,
                mimeType: format.mimeType,
                fileName: _dropFileName(file) ?? format.fallbackFileName,
              ),
            );
          } on Object {
            complete(null);
          }
        },
        onError: (Object error) => complete(null),
      );
      if (progress == null) {
        complete(null);
      }
    } on Object {
      complete(null);
    }
    return completer.future;
  }

  Uint8List? _dropFileBytes(Object? value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    return null;
  }

  String? _dropFileName(dynamic file) {
    try {
      final name = file.fileName;
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<void> _handleExternalImageDropInputs(
    List<ExternalImageInput> inputs, {
    DocumentSelection? insertionSelection,
  }) async {
    final acceptedInputs = <ExternalImageInput>[
      for (final input in inputs)
        if (isUsableExternalImageInput(input)) input,
    ];
    if (!_canAcceptExternalImageDrop || acceptedInputs.isEmpty) {
      return;
    }
    final images = await _prepareExternalImages(acceptedInputs);
    if (images.isNotEmpty) {
      _pasteExternalImages(
        images,
        selection: insertionSelection,
      );
    }
  }

  Widget _withHighContrastFocusHighlight(
    BuildContext context,
    FocusNode focusNode,
    Widget child,
  ) {
    final accessibility = widget.accessibility;
    if (!focusNode.hasFocus ||
        !(MediaQuery.maybeHighContrastOf(context) ?? false) ||
        accessibility.highContrastFocusWidth == 0) {
      return child;
    }
    return DecoratedBox(
      key: _accessibilityFocusHighlightKey,
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: accessibility.highContrastFocusColor ??
              Theme.of(context).colorScheme.primary,
          width: accessibility.highContrastFocusWidth,
        ),
      ),
      child: child,
    );
  }

  _SlashMenuAnchor _slashMenuAnchor() {
    final paddingFallback = widget.padding.resolve(TextDirection.ltr).topLeft;
    final selection = widget.controller.selection;
    final overlayContext = _editorOverlayKey.currentContext;
    final editorBox = overlayContext?.findRenderObject();
    final positioningBox = _slashMenuPositioningBox();
    final fallback = editorBox is RenderBox &&
            editorBox.hasSize &&
            positioningBox != null &&
            positioningBox.hasSize
        ? positioningBox.globalToLocal(
            editorBox.localToGlobal(paddingFallback),
          )
        : paddingFallback;
    if (selection == null ||
        !selection.isCollapsed ||
        positioningBox == null ||
        !positioningBox.hasSize) {
      return _SlashMenuAnchor(offset: fallback);
    }
    final caret = _registry.caretRectForPosition(selection.extent);
    if (caret == null) {
      return _SlashMenuAnchor(offset: fallback);
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final keyboardInset = mediaQuery?.viewInsets.bottom ?? 0.0;
    final viewportHeight =
        mediaQuery?.size.height ?? positioningBox.size.height;
    final overlayTop = positioningBox.localToGlobal(Offset.zero).dy;
    final keyboardTop = viewportHeight - keyboardInset;
    final keyboardClippedBottom = keyboardInset > 0
        ? keyboardTop - overlayTop
        : positioningBox.size.height;
    final caretTop = positioningBox.globalToLocal(caret.topLeft);
    final caretBottom = positioningBox.globalToLocal(caret.bottomLeft);
    final maxLeft =
        positioningBox.size.width - _kPopupMenuMinWidth - _kPopupViewportInset;
    final visibleBottom = math.max(
      _kPopupViewportInset,
      math.min(positioningBox.size.height, keyboardClippedBottom),
    );
    final preferredBelowTop = caretBottom.dy + _kSlashMenuGap;
    final preferredAboveBottom = caretTop.dy - _kSlashMenuGap;
    final roomBelow = visibleBottom - preferredBelowTop - _kPopupViewportInset;
    final roomAbove = preferredAboveBottom - _kPopupViewportInset;
    final availableBelow = math.max(0.0, roomBelow);
    final availableAbove = math.max(0.0, roomAbove);
    final opensAbove = _shouldOpenSlashMenuAbove(
      availableAbove: availableAbove,
      availableBelow: availableBelow,
    );
    final preferredTop = opensAbove ? preferredAboveBottom : preferredBelowTop;
    final maxTop = visibleBottom - _kPopupViewportInset;
    final topMin = maxTop >= _kPopupViewportInset ? _kPopupViewportInset : 0.0;
    final clampedTop =
        preferredTop.clamp(topMin, maxTop > 0 ? maxTop : 0).toDouble();
    final availableHeight = opensAbove
        ? math.max(0.0, clampedTop - _kPopupViewportInset)
        : math.max(0.0, visibleBottom - clampedTop - _kPopupViewportInset);
    return _SlashMenuAnchor(
      offset: Offset(
        caretBottom.dx.clamp(0, maxLeft > 0 ? maxLeft : 0).toDouble(),
        clampedTop,
      ),
      opensAbove: opensAbove,
      availableHeight: availableHeight,
    );
  }

  bool _shouldOpenSlashMenuAbove({
    required double availableAbove,
    required double availableBelow,
  }) {
    if (availableBelow >= _kSlashMenuMinReadableHeight) {
      return false;
    }
    if (availableAbove >= _kSlashMenuMinReadableHeight) {
      return true;
    }
    return availableAbove > availableBelow;
  }

  RenderBox? _slashMenuPositioningBox() {
    final overlay = Overlay.maybeOf(context);
    final renderObject = overlay?.context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject;
    }
    final editorObject = _editorOverlayKey.currentContext?.findRenderObject();
    if (editorObject is RenderBox && editorObject.hasSize) {
      return editorObject;
    }
    return null;
  }

  void _handleSelectionChanged(DocumentSelection selection) {
    _skipNextCaretScrollIntoView = true;
    widget.controller.setSelection(selection);
    _dispatchMentionTapForSelection(selection);
    // A selection change from the gesture overlay repositions the caret, so
    // refresh the IME buffer so the platform input follows the new location.
    // Android system Back can close the TextInput connection without removing
    // editor focus; a later text tap must restore that connection (or show its
    // still-attached, hidden keyboard) even though focus did not change.
    if (_shouldRestoreTextInputForSelection(selection)) {
      _inputClient.reconnectAndShow();
    } else {
      _inputClient.syncBuffer();
    }
  }

  bool _shouldRestoreTextInputForSelection(DocumentSelection selection) {
    if (!EditorTokens.isMobileSelectionUiPlatform(defaultTargetPlatform) ||
        widget.readOnly ||
        !widget.enableIme ||
        !widget.controller.canEdit ||
        !_effectiveFocusNode.hasFocus) {
      return false;
    }
    // The platform buffer represents a single text-bearing surface. Keeping
    // the selection within one such surface avoids reopening the keyboard for
    // atomic media selections or cross-target selections that cannot be edited
    // by this input client.
    final base = selection.base;
    final extent = selection.extent;
    return base.blockId == extent.blockId &&
        base.blockIndex == extent.blockIndex &&
        base.path == extent.path &&
        _isTextInputPath(extent.path);
  }

  bool _isTextInputPath(PositionPath path) {
    return path.isBlockText || path.isBlockCode || path.isTableCellText;
  }

  void _handleMobileCaretTap(
    DocumentPosition caret,
    Offset _,
  ) {
    final selection = widget.controller.selection;
    if (!_canShowMobileCaretToolbar ||
        selection == null ||
        !selection.isCollapsed ||
        selection.extent != caret) {
      return;
    }
    if (_mobileCaretToolbarPosition == caret) {
      return;
    }
    setState(() {
      _mobileCaretToolbarPosition = caret;
    });
  }

  void _dismissMobileCaretToolbar() {
    if (_mobileCaretToolbarPosition == null) {
      return;
    }
    setState(() {
      _mobileCaretToolbarPosition = null;
    });
  }

  bool get _canShowMobileCaretToolbar {
    return widget.enableMobileSelectionHandles &&
        EditorTokens.shouldUseMobileSelectionUi(context) &&
        !widget.readOnly &&
        widget.enableIme &&
        widget.controller.canEdit;
  }

  void _synchronizeMobileCaretToolbar({bool hideForDocumentChange = false}) {
    final caret = _mobileCaretToolbarPosition;
    if (caret == null) {
      return;
    }
    final selection = widget.controller.selection;
    final contentChanged = hideForDocumentChange &&
        (widget.controller.lastChangedBlockIds == null ||
            widget.controller.lastChangedBlockIds!.isNotEmpty);
    if (contentChanged ||
        !_canShowMobileCaretToolbar ||
        !_effectiveFocusNode.hasFocus ||
        selection == null ||
        !selection.isCollapsed ||
        selection.extent != caret) {
      _mobileCaretToolbarPosition = null;
    }
  }

  Widget _buildMobileSelectionToolbar(
    BuildContext _,
    WenzRichTextController controller,
  ) {
    final canEdit = _canRunContextMenuMutation;
    return WenzMobileSelectionToolbar(
      controller: controller,
      canEdit: canEdit,
      canPaste: canEdit,
      canSearch: widget.onFindRequested != null,
      onSelectAll: () => _handleDefaultContextMenuAction(
        WenzEditorContextMenuDefaultAction.selectAll,
      ),
      onCut: () => _handleDefaultContextMenuAction(
        WenzEditorContextMenuDefaultAction.cut,
      ),
      onCopy: () => _handleDefaultContextMenuAction(
        WenzEditorContextMenuDefaultAction.copy,
      ),
      onPaste: () => _handleDefaultContextMenuAction(
        WenzEditorContextMenuDefaultAction.paste,
      ),
      onSearch: _handleMobileSelectionToolbarSearch,
    );
  }

  void _handleMobileSelectionToolbarSearch() {
    // Do not route this through shortcut handling: search should only request
    // the host find surface and must leave the active selection, focus, and
    // platform text-input connection untouched.
    widget.onFindRequested?.call();
  }

  void _registerInlineVideoResolverTapTarget(
    String blockId,
    GlobalKey key,
    bool Function(Offset globalPosition) consumeUnclaimedTap,
  ) {
    _inlineVideoResolverTapTargets[key] =
        _InlineVideoResolverTapTargetRegistration(
      blockId: blockId,
      consumeUnclaimedTap: consumeUnclaimedTap,
    );
  }

  void _unregisterInlineVideoResolverTapTarget(
    String blockId,
    GlobalKey key,
  ) {
    if (_inlineVideoResolverTapTargets[key]?.blockId == blockId) {
      _inlineVideoResolverTapTargets.remove(key);
    }
  }

  bool _shouldDeferInlineVideoResolverTapSelection(
    DocumentPosition anchor,
    Offset globalPosition,
  ) {
    if (!anchor.path.isBlockObject) {
      return false;
    }
    for (final entry in _inlineVideoResolverTapTargets.entries) {
      if (entry.value.blockId != anchor.blockId) {
        continue;
      }
      if (_globalPointHitsKey(entry.key, globalPosition)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldCommitInlineVideoResolverTapSelection(
    DocumentPosition anchor,
    Offset globalPosition,
  ) {
    if (!EditorTokens.shouldUseMobileSelectionUi(context)) {
      return true;
    }
    for (final entry in _inlineVideoResolverTapTargets.entries) {
      final target = entry.value;
      if (target.blockId == anchor.blockId &&
          _globalPointHitsKey(entry.key, globalPosition) &&
          target.consumeUnclaimedTap(globalPosition)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldRequestFocusForTapSelection(
    DocumentPosition anchor,
    Offset _,
  ) {
    if (!EditorTokens.shouldUseMobileSelectionUi(context) ||
        !anchor.path.isBlockObject) {
      return true;
    }
    final blockIndex = anchor.blockIndex;
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return true;
    }
    final block = blocks[blockIndex];
    return block.id != anchor.blockId || block is! VideoBlockNode;
  }

  bool _globalPointHitsKey(GlobalKey key, Offset globalPosition) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final local = renderObject.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dx <= renderObject.size.width &&
        local.dy >= 0 &&
        local.dy <= renderObject.size.height;
  }

  Future<void> _handleContextMenuRequested(
    SelectionContextMenuRequest request,
  ) async {
    if (_contextMenuOpen || !mounted) {
      return;
    }
    final hitPosition = request.hitPosition;
    final selectionBeforeMenu = widget.controller.selection;
    final hitInsideSelection = _contextMenuHitInsideSelection(
      selectionBeforeMenu,
      hitPosition,
    );
    final hadFocus = _effectiveFocusNode.hasFocus;

    final menuSelection = !hitInsideSelection && hitPosition != null
        ? _selectionForContextMenuHit(hitPosition)
        : selectionBeforeMenu;

    final menuContext = WenzEditorContextMenuContext(
      controller: widget.controller,
      selection: menuSelection,
      hitPosition: hitPosition,
      globalPosition: request.globalPosition,
      readOnly: widget.readOnly,
      canEdit: !widget.readOnly && widget.controller.canEdit,
      hitInsideSelection: hitInsideSelection,
      buildContext: context,
    );
    final position = _contextMenuPositionForGlobal(request.globalPosition);
    if (position == null) {
      return;
    }
    final menuConstraints = _editorContextMenuConstraintsFor(position);
    final entries = _buildEditorContextMenuPopupEntries(
      menuContext,
      _resolveEditorContextMenuEntries(menuContext),
      menuConstraints,
    );
    if (entries.isEmpty) {
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      return;
    }

    _dismissPeerOverlaysForContextMenu();
    if (menuSelection != selectionBeforeMenu) {
      _skipNextCaretScrollIntoView = true;
      widget.controller.setSelection(menuSelection);
      _inputClient.syncBuffer();
    }

    final generation = ++_contextMenuGeneration;
    _contextMenuOpen = true;
    _EditorPopupMenuDismissal.dismiss();
    _EditorPopupMenuDismissal.register(navigator);
    try {
      final selected = await showMenu<WenzEditorContextMenuItem>(
        context: context,
        position: position,
        elevation: _kPopupMenuElevation,
        shadowColor: _popupMenuShadowColor(Theme.of(context)),
        surfaceTintColor: Colors.transparent,
        shape: _popupMenuShape(Theme.of(context)),
        menuPadding: _kPopupMenuPadding,
        color: _popupMenuColor(Theme.of(context)),
        constraints: menuConstraints,
        clipBehavior: Clip.antiAlias,
        semanticLabel: '编辑器操作',
        routeSettings: _kPopupMenuRouteSettings,
        items: entries,
      );
      if (!mounted || selected == null) {
        return;
      }
      await _invokeEditorContextMenuItem(selected, menuContext);
    } finally {
      _EditorPopupMenuDismissal.unregister(navigator);
      if (mounted && _contextMenuGeneration == generation) {
        _contextMenuOpen = false;
        _restoreEditorFocusAfterContextMenu(hadFocus);
      }
    }
  }

  void _dismissPeerOverlaysForContextMenu() {
    widget.slashMenuController?.close();
    _removeSlashMenuOverlay();
    _closeMentionSearch();
    _closeFormulaEditor();
    _dismissLinkHover();
    _tableToolbarOverlayController.hide();
    _objectBlockToolbarOverlayController.hide();
  }

  DocumentSelection _selectionForContextMenuHit(DocumentPosition position) {
    if (position.path.isBlockObject) {
      final objectPosition = position.copyWith(offset: 0);
      return DocumentSelection(
        base: objectPosition,
        extent: objectPosition.copyWith(offset: _kAtomicBlockSelectionLength),
      );
    }
    return DocumentSelection(base: position, extent: position);
  }

  bool _contextMenuHitInsideSelection(
    DocumentSelection? selection,
    DocumentPosition? hitPosition,
  ) {
    if (selection == null || selection.isCollapsed || hitPosition == null) {
      return false;
    }
    final tableRange = selection.tableCellRange;
    if (tableRange != null && hitPosition.path.isTableCellText) {
      final row = hitPosition.path.tableRowIndex;
      final column = hitPosition.path.tableColumnIndex;
      return hitPosition.blockId == tableRange.tableBlockId &&
          hitPosition.blockIndex == tableRange.blockIndex &&
          row != null &&
          column != null &&
          tableRange.containsCell(row, column);
    }
    return hitPosition.compareTo(selection.start) >= 0 &&
        hitPosition.compareTo(selection.end) <= 0;
  }

  RelativeRect? _contextMenuPositionForGlobal(Offset globalPosition) {
    final overlay = Overlay.maybeOf(context);
    final overlayObject = overlay?.context.findRenderObject();
    if (overlayObject is RenderBox && overlayObject.hasSize) {
      return _contextMenuPositionInBox(overlayObject, globalPosition);
    }
    final editorObject = _editorOverlayKey.currentContext?.findRenderObject();
    if (editorObject is RenderBox && editorObject.hasSize) {
      return _contextMenuPositionInBox(editorObject, globalPosition);
    }
    return null;
  }

  RelativeRect _contextMenuPositionInBox(RenderBox box, Offset globalPosition) {
    final size = box.size;
    final local = box.globalToLocal(globalPosition);
    final maxX = math.max(0.0, size.width - _kPopupViewportInset);
    final maxY = math.max(0.0, size.height - _kPopupViewportInset);
    final minX = math.min(_kPopupViewportInset, maxX);
    final minY = math.min(_kPopupViewportInset, maxY);
    final anchor = Offset(
      local.dx.clamp(minX, maxX).toDouble(),
      local.dy.clamp(minY, maxY).toDouble(),
    );
    return RelativeRect.fromRect(
      Rect.fromLTWH(anchor.dx, anchor.dy, 1, 1),
      Offset.zero & size,
    );
  }

  BoxConstraints _editorContextMenuConstraintsFor(RelativeRect position) {
    final overlayWidth = position.left + position.right + 1.0;
    final overlayHeight = position.top + position.bottom + 1.0;
    final availableWidth = math.max(
      1.0,
      overlayWidth - _kPopupViewportInset * 2,
    );
    final availableHeight = math.max(
      1.0,
      overlayHeight - _kPopupViewportInset * 2,
    );
    final maxWidth = math.min(_kPopupMenuMaxWidth, availableWidth);
    return BoxConstraints(
      minWidth: math.min(_kPopupMenuMinWidth, maxWidth),
      maxWidth: maxWidth,
      maxHeight: math.min(_kPopupMenuMaxHeight, availableHeight),
    );
  }

  List<WenzEditorContextMenuEntry> _resolveEditorContextMenuEntries(
    WenzEditorContextMenuContext menuContext,
  ) {
    final defaultEntries = _defaultEditorContextMenuEntries(menuContext);
    try {
      return widget.contextMenuConfiguration.resolveEntries(
        menuContext,
        defaultEntries,
      );
    } catch (error, stackTrace) {
      _reportEditorContextMenuError(
        'while resolving editor context-menu entries',
        error,
        stackTrace,
      );
      return defaultEntries;
    }
  }

  List<WenzEditorContextMenuEntry> _defaultEditorContextMenuEntries(
    WenzEditorContextMenuContext context,
  ) {
    final selection = context.selection;
    final canCopy = selection?.isCollapsed == false;
    final canMutate = context.canEdit;
    final copyShortcut = _editorContextMenuShortcut('C');
    final cutShortcut = _editorContextMenuShortcut('X');
    final pasteShortcut = _editorContextMenuShortcut('V');
    final selectAllShortcut = _editorContextMenuShortcut('A');
    return <WenzEditorContextMenuEntry>[
      WenzEditorContextMenuItem(
        id: 'wenz.default.copy',
        title: '复制',
        icon: Icons.content_copy,
        shortcut: copyShortcut,
        defaultAction: WenzEditorContextMenuDefaultAction.copy,
        enabled: canCopy,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.copy,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.cut',
        title: '剪切',
        icon: Icons.content_cut,
        shortcut: cutShortcut,
        defaultAction: WenzEditorContextMenuDefaultAction.cut,
        enabled: canCopy && canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.cut,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.paste',
        title: '粘贴',
        icon: Icons.content_paste,
        shortcut: pasteShortcut,
        defaultAction: WenzEditorContextMenuDefaultAction.paste,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.paste,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.delete',
        title: '删除',
        icon: Icons.delete_outline,
        defaultAction: WenzEditorContextMenuDefaultAction.delete,
        enabled: canCopy && canMutate,
        destructive: true,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.delete,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.select-all',
        title: '全选',
        icon: Icons.select_all,
        shortcut: selectAllShortcut,
        defaultAction: WenzEditorContextMenuDefaultAction.selectAll,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.selectAll,
        ),
      ),
      const WenzEditorContextMenuDivider(),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-paragraph',
        title: '插入段落',
        icon: Icons.notes,
        defaultAction: WenzEditorContextMenuDefaultAction.insertParagraph,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertParagraph,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-heading',
        title: '插入标题',
        icon: Icons.title,
        defaultAction: WenzEditorContextMenuDefaultAction.insertHeading,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertHeading,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-quote',
        title: '插入引用',
        icon: Icons.format_quote,
        defaultAction: WenzEditorContextMenuDefaultAction.insertQuote,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertQuote,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-code-block',
        title: '插入代码块',
        icon: Icons.code,
        defaultAction: WenzEditorContextMenuDefaultAction.insertCodeBlock,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertCodeBlock,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-divider',
        title: '插入分割线',
        icon: Icons.horizontal_rule,
        defaultAction: WenzEditorContextMenuDefaultAction.insertDivider,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertDivider,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-table',
        title: '插入表格',
        icon: Icons.table_chart_outlined,
        defaultAction: WenzEditorContextMenuDefaultAction.insertTable,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertTable,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-formula',
        title: '插入公式',
        icon: Icons.functions,
        defaultAction: WenzEditorContextMenuDefaultAction.insertFormula,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertFormula,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-image',
        title: '插入图片块',
        icon: Icons.image_outlined,
        defaultAction: WenzEditorContextMenuDefaultAction.insertImage,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertImage,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-video',
        title: '插入视频块',
        icon: Icons.smart_display_outlined,
        defaultAction: WenzEditorContextMenuDefaultAction.insertVideo,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertVideo,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-file',
        title: '插入文件块',
        icon: Icons.attach_file,
        defaultAction: WenzEditorContextMenuDefaultAction.insertFile,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertFile,
        ),
      ),
      WenzEditorContextMenuItem(
        id: 'wenz.default.insert-callout',
        title: '插入提示块',
        icon: Icons.info_outline,
        defaultAction: WenzEditorContextMenuDefaultAction.insertCallout,
        enabled: canMutate,
        action: (_) => _handleDefaultContextMenuAction(
          WenzEditorContextMenuDefaultAction.insertCallout,
        ),
      ),
    ];
  }

  String _editorContextMenuShortcut(String key) {
    final platform = _currentShortcutPlatform();
    return switch (platform) {
      EditorShortcutPlatform.iOS || EditorShortcutPlatform.macOS => 'Cmd+$key',
      _ => 'Ctrl+$key',
    };
  }

  Future<void> _invokeEditorContextMenuItem(
    WenzEditorContextMenuItem item,
    WenzEditorContextMenuContext menuContext,
  ) async {
    try {
      final defaultAction = item.defaultAction;
      if (defaultAction != null && item.action == null) {
        await _handleDefaultContextMenuAction(defaultAction);
        return;
      }
      await item.invoke(menuContext);
    } catch (error, stackTrace) {
      _reportEditorContextMenuError(
        'while invoking editor context-menu item "${item.id}"',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleDefaultContextMenuAction(
    WenzEditorContextMenuDefaultAction action,
  ) async {
    switch (action) {
      case WenzEditorContextMenuDefaultAction.copy:
        await _handleCopy();
        return;
      case WenzEditorContextMenuDefaultAction.cut:
        if (_canRunContextMenuMutation) {
          await _handleCut();
        }
        return;
      case WenzEditorContextMenuDefaultAction.paste:
        if (_canRunContextMenuMutation) {
          await _handlePaste();
        }
        return;
      case WenzEditorContextMenuDefaultAction.delete:
        if (_canRunContextMenuMutation) {
          _deleteActiveSelectionIfAny();
        }
        return;
      case WenzEditorContextMenuDefaultAction.selectAll:
        _selectAllFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertParagraph:
        _insertParagraphFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertHeading:
        _insertHeadingFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertQuote:
        _insertQuoteFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertCodeBlock:
        _insertCodeBlockFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertDivider:
        _insertDividerFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertTable:
        if (_canRunContextMenuMutation) {
          _insertTableShortcut();
        }
        return;
      case WenzEditorContextMenuDefaultAction.insertImage:
        _insertImageFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertVideo:
        _insertVideoFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertFile:
        _insertFileFromContextMenu();
        return;
      case WenzEditorContextMenuDefaultAction.insertFormula:
        if (_canRunContextMenuMutation) {
          _insertFormulaShortcut();
        }
        return;
      case WenzEditorContextMenuDefaultAction.insertCallout:
        _insertCalloutFromContextMenu();
        return;
    }
  }

  bool get _canRunContextMenuMutation =>
      !widget.readOnly && widget.controller.canEdit;

  void _selectAllFromContextMenu() {
    if (!_selectCurrentCodeBlockCode()) {
      widget.controller.selectAll();
    }
    _inputClient.syncBuffer();
  }

  void _insertParagraphFromContextMenu() {
    _insertBlockFromContextMenu(
      TextBlockNode(
        id: _nextBlockId(),
        type: BlockType.paragraph,
      ),
    );
  }

  void _insertHeadingFromContextMenu() {
    _insertBlockFromContextMenu(
      TextBlockNode(
        id: _nextBlockId(),
        type: BlockType.heading,
        attributes: const BlockAttributes(level: 1),
      ),
    );
  }

  void _insertQuoteFromContextMenu() {
    _insertBlockFromContextMenu(
      TextBlockNode(
        id: _nextBlockId(),
        type: BlockType.paragraph,
        attributes: const BlockAttributes(quoted: true),
      ),
    );
  }

  void _insertCodeBlockFromContextMenu() {
    _insertBlockFromContextMenu(
      CodeBlockNode(
        id: _nextBlockId(),
        code: '',
      ),
    );
  }

  void _insertDividerFromContextMenu() {
    _insertBlockFromContextMenu(DividerBlockNode(id: _nextBlockId()));
  }

  void _insertImageFromContextMenu() {
    if (!_canRunContextMenuMutation) {
      return;
    }
    widget.controller.insertImage(
      index: _currentBlockInsertionIndex(),
      blockId: _nextBlockId(),
    );
    _inputClient.syncBuffer();
  }

  void _insertVideoFromContextMenu() {
    if (!_canRunContextMenuMutation) {
      return;
    }
    widget.controller.insertVideo(
      index: _currentBlockInsertionIndex(),
      blockId: _nextBlockId(),
    );
    _inputClient.syncBuffer();
  }

  void _insertFileFromContextMenu() {
    if (!_canRunContextMenuMutation) {
      return;
    }
    widget.controller.insertFile(
      index: _currentBlockInsertionIndex(),
      blockId: _nextBlockId(),
      assetId: '',
    );
    _inputClient.syncBuffer();
  }

  void _insertCalloutFromContextMenu() {
    _insertBlockFromContextMenu(
      CalloutBlockNode(
        id: _nextBlockId(),
        content: const <InlineNode>[],
        variant: CalloutBlockNode.infoVariant,
        title: CalloutBlockNode.defaultTitleFor(CalloutBlockNode.infoVariant),
      ),
    );
  }

  void _insertBlockFromContextMenu(BlockNode block) {
    if (!_canRunContextMenuMutation) {
      return;
    }
    final insertionIndex = _currentBlockInsertionIndex();
    widget.controller.insertBlocks(
      index: insertionIndex,
      blocks: <BlockNode>[block],
      selection: _selectionForBlock(block, insertionIndex),
    );
    _inputClient.syncBuffer();
  }

  List<PopupMenuEntry<WenzEditorContextMenuItem>>
      _buildEditorContextMenuPopupEntries(
    WenzEditorContextMenuContext menuContext,
    Iterable<WenzEditorContextMenuEntry> entries,
    BoxConstraints menuConstraints,
  ) {
    final result = <PopupMenuEntry<WenzEditorContextMenuItem>>[];
    final itemIdOccurrences = <String, int>{};
    var hasItemAfterDivider = false;
    for (final entry in entries) {
      if (entry is WenzEditorContextMenuDivider) {
        if (hasItemAfterDivider) {
          result.add(_popupMenuDivider<WenzEditorContextMenuItem>());
          hasItemAfterDivider = false;
        }
        continue;
      }
      if (entry is! WenzEditorContextMenuItem ||
          !_isEditorContextMenuItemVisible(entry, menuContext)) {
        continue;
      }
      final occurrence = (itemIdOccurrences[entry.id] ?? 0) + 1;
      itemIdOccurrences[entry.id] = occurrence;
      final enabled = _isEditorContextMenuItemEnabled(entry, menuContext);
      final shortcut = _editorContextMenuShortcutForLayout(
        entry,
        menuConstraints,
      );
      result.add(
        PopupMenuItem<WenzEditorContextMenuItem>(
          key: _editorContextMenuItemKey(entry, occurrence),
          value: entry,
          enabled: enabled,
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: Semantics(
            label: _editorContextMenuSemanticLabel(entry),
            button: true,
            enabled: enabled,
            child: _PopupMenuItemContent(
              icon: entry.icon ?? Icons.more_horiz,
              label: entry.title,
              shortcut: shortcut,
              enabled: enabled,
              destructive: entry.destructive,
              minWidth: _editorContextMenuItemContentMinWidth(
                menuConstraints,
              ),
              maxWidth: _editorContextMenuItemContentMaxWidth(
                menuConstraints,
              ),
              labelMaxWidth: _editorContextMenuLabelMaxWidth(
                menuConstraints,
                shortcut,
              ),
            ),
          ),
        ),
      );
      hasItemAfterDivider = true;
    }
    while (result.isNotEmpty &&
        result.last is! PopupMenuItem<WenzEditorContextMenuItem>) {
      result.removeLast();
    }
    return result;
  }

  double _editorContextMenuItemContentMaxWidth(BoxConstraints constraints) {
    return math.max(
      1.0,
      constraints.maxWidth - _kPopupMenuPadding.horizontal,
    );
  }

  double _editorContextMenuItemContentMinWidth(BoxConstraints constraints) {
    final maxWidth = _editorContextMenuItemContentMaxWidth(constraints);
    return math.min(_kPopupMenuItemContentMinWidth, maxWidth);
  }

  String? _editorContextMenuShortcutForLayout(
    WenzEditorContextMenuItem item,
    BoxConstraints constraints,
  ) {
    final shortcut = item.shortcut;
    if (shortcut == null) {
      return null;
    }
    final maxWidth = _editorContextMenuItemContentMaxWidth(constraints);
    if (maxWidth < _kPopupMenuItemContentMinWidth) {
      return null;
    }
    return shortcut;
  }

  double _editorContextMenuLabelMaxWidth(
    BoxConstraints constraints,
    String? shortcut,
  ) {
    final maxWidth = _editorContextMenuItemContentMaxWidth(constraints);
    final reservedWidth = _kMinimalMenuItemContentPadding.horizontal +
        _kMinimalMenuIconSlotWidth +
        _kMinimalMenuIconTextGap +
        (shortcut == null
            ? 0.0
            : _kMinimalMenuShortcutGap + _kPopupMenuShortcutEstimatedWidth);
    return math.max(
      _kPopupMenuCompactMinLabelWidth,
      math.min(_kPopupMenuTextMaxWidth, maxWidth - reservedWidth),
    );
  }

  Key _editorContextMenuItemKey(
    WenzEditorContextMenuItem item,
    int occurrence,
  ) {
    final explicitKey = item.key;
    if (explicitKey != null) {
      return explicitKey;
    }
    final suffix = occurrence <= 1 ? '' : '#$occurrence';
    return ValueKey<String>(
      'wenz-richtext-context-menu-item:${item.id}$suffix',
    );
  }

  String _editorContextMenuSemanticLabel(WenzEditorContextMenuItem item) {
    final explicitLabel = item.semanticLabel;
    if (explicitLabel != null && explicitLabel.trim().isNotEmpty) {
      return explicitLabel;
    }
    final shortcut = item.shortcut?.trim();
    if (shortcut == null || shortcut.isEmpty) {
      return item.title;
    }
    return '${item.title}, $shortcut';
  }

  bool _isEditorContextMenuItemVisible(
    WenzEditorContextMenuItem item,
    WenzEditorContextMenuContext menuContext,
  ) {
    try {
      return item.visibleFor(menuContext);
    } catch (error, stackTrace) {
      _reportEditorContextMenuError(
        'while evaluating visibility for editor context-menu item "${item.id}"',
        error,
        stackTrace,
      );
      return false;
    }
  }

  bool _isEditorContextMenuItemEnabled(
    WenzEditorContextMenuItem item,
    WenzEditorContextMenuContext menuContext,
  ) {
    try {
      return item.enabledFor(menuContext);
    } catch (error, stackTrace) {
      _reportEditorContextMenuError(
        'while evaluating enabled state for editor context-menu item '
        '"${item.id}"',
        error,
        stackTrace,
      );
      return false;
    }
  }

  void _reportEditorContextMenuError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'wenz_richtext',
        context: ErrorDescription(operation),
      ),
    );
  }

  void _restoreEditorFocusAfterContextMenu(bool hadFocus) {
    if (!hadFocus || !mounted) {
      return;
    }
    _effectiveFocusNode.requestFocus();
    _inputClient.syncBuffer();
  }

  void _dispatchMentionTapForSelection(DocumentSelection selection) {
    final callback = widget.onMentionTap;
    if (callback == null || !selection.isCollapsed) {
      return;
    }
    final position = selection.extent;
    final mention = _mentionEmbedAtPosition(position);
    if (mention == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.selection != selection) {
        return;
      }
      callback(
        WenzMentionTapDetails(
          embed: mention,
          position: position,
          selection: selection,
        ),
      );
    });
  }

  InlineEmbed? _mentionEmbedAtPosition(DocumentPosition position) {
    final nodes = _inlineNodesForPosition(position);
    if (nodes == null) {
      return null;
    }
    var offset = 0;
    for (final node in nodes) {
      final length = inlineLength(node);
      final start = offset;
      final end = offset + length;
      if (node is InlineEmbed &&
          _isMentionEmbedType(node.embedType) &&
          (position.offset == start || position.offset == end)) {
        return node;
      }
      offset = end;
    }
    return null;
  }

  List<InlineNode>? _inlineNodesForPosition(DocumentPosition position) {
    final blocks = widget.controller.document.blocks;
    if (position.blockIndex < 0 || position.blockIndex >= blocks.length) {
      return null;
    }
    final block = blocks[position.blockIndex];
    if (block.id != position.blockId) {
      return null;
    }
    if (position.path.isBlockText) {
      if (block is TextBlockNode) {
        return block.content;
      }
      if (block is CalloutBlockNode) {
        return block.content;
      }
      return null;
    }
    if (position.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return null;
      }
      final cell = block.table.cellAt(rowIndex, columnIndex);
      final cellBlocks = cell?.blocks;
      if (cellBlocks == null) {
        return null;
      }
      for (final cellBlock in cellBlocks) {
        if (cellBlock is TextBlockNode) {
          return cellBlock.content;
        }
      }
    }
    return null;
  }

  /// Resolves the contiguous inline link run that contains [position].
  ///
  /// Returns `null` when [position] is not over a link ([TextAttributes.url]
  /// non-null), is out of range, or its block surface has not been laid out yet.
  ///
  /// The returned record's `range` is the run's `[start, end)` offset span within
  /// the block's inline content (block-local, matching [DocumentPosition.offset]),
  /// and its `globalRect` is the bounding global [Rect] of that span — the union
  /// of the run's start and end caret rects, resolved via the geometry registry.
  /// Adjacent runs carrying a different `url` (or no url) bound their own runs, so
  /// a continuous same-`url` sequence collapses to a single range while same-`url`
  /// runs split by other content stay independent. Works for both
  /// paragraph/callout text and table-cell text paths via [_inlineNodesForPosition].
  ({String url, TextRange range, Rect globalRect})? _linkInfoAtPosition(
    DocumentPosition position,
  ) {
    final nodes = _inlineNodesForPosition(position);
    if (nodes == null) {
      return null;
    }

    // Build each inline node's `[start, end)` span alongside its resolved
    // attributes, mirroring `_attributesAtOffset` (revision_commands.dart).
    // Inline nodes are laid out contiguously, so each span starts where the
    // previous one ended.
    var cursor = 0;
    final spans = <({int start, int end, TextAttributes attributes})>[];
    for (final node in nodes) {
      final length = inlineLength(node);
      final start = cursor;
      final attributes = switch (node) {
        TextRun(:final attributes) => attributes,
        InlineEmbed(:final attributes) => attributes,
        _ => const TextAttributes(),
      };
      spans.add((start: start, end: cursor + length, attributes: attributes));
      cursor += length;
    }

    // Find the node whose span contains the offset and carries a link url.
    var hitIndex = -1;
    String? hitUrl;
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      if (position.offset >= span.start &&
          position.offset < span.end &&
          span.attributes.url != null) {
        hitIndex = i;
        hitUrl = span.attributes.url;
        break;
      }
    }
    if (hitIndex < 0 || hitUrl == null) {
      return null;
    }

    // Expand to the maximal contiguous run sharing the same url. A run with a
    // different url — or no url — terminates the expansion, so split same-`url`
    // links stay independent ranges.
    var rangeStart = spans[hitIndex].start;
    var rangeEnd = spans[hitIndex].end;
    for (var i = hitIndex - 1; i >= 0; i--) {
      if (spans[i].attributes.url == hitUrl) {
        rangeStart = spans[i].start;
      } else {
        break;
      }
    }
    for (var i = hitIndex + 1; i < spans.length; i++) {
      if (spans[i].attributes.url == hitUrl) {
        rangeEnd = spans[i].end;
      } else {
        break;
      }
    }

    // Merge the run's start/end caret rects into a single global bounding box.
    final startRect = _registry.caretRectForPosition(
      position.copyWith(offset: rangeStart),
    );
    final endRect = _registry.caretRectForPosition(
      position.copyWith(offset: rangeEnd),
    );
    final globalRect = switch ((startRect, endRect)) {
      (final Rect start, final Rect end) => start.expandToInclude(end),
      (final Rect only, _) => only,
      (_, final Rect only) => only,
      _ => null,
    };
    if (globalRect == null) {
      return null;
    }
    return (
      url: hitUrl,
      range: TextRange(start: rangeStart, end: rangeEnd),
      globalRect: globalRect,
    );
  }

  /// Probes a global pointer position for an inline link run, bundling the
  /// resolved run with the block [DocumentPosition] (offset pinned to the run
  /// start so the value is stable across the whole run). This is the
  /// [SelectionGestureOverlay.linkProbe] implementation that backs the hover
  /// popup. Returns `null` for non-link positions, out-of-range offsets, or
  /// blocks that have not been laid out yet.
  WenzLinkHoverInfo? _probeLinkAtGlobal(Offset global) {
    final position = _registry.positionFromGlobalOffset(global);
    if (position == null) {
      return null;
    }
    final resolved = _linkInfoAtPosition(position);
    if (resolved == null) {
      return null;
    }
    return (
      url: resolved.url,
      range: resolved.range,
      globalRect: resolved.globalRect,
      position: position.copyWith(offset: resolved.range.start),
    );
  }

  /// Receives the link (or its absence) currently under the hovering pointer
  /// from the gesture surface. Shows / updates the popup immediately on a link,
  /// and schedules a delayed hide otherwise — letting the pointer travel onto
  /// the popup before it disappears.
  void _handleLinkHover(WenzLinkHoverInfo? info) {
    if (!mounted) {
      return;
    }
    _cancelLinkHoverHide();
    if (info != null) {
      _surfaceLinkHovered = true;
      // Stable per-run (offset pinned to run start), so skip redundant rebuilds
      // while the pointer drifts within the same link.
      if (_linkHover != info) {
        setState(() {
          _linkHover = info;
        });
      }
    } else {
      _surfaceLinkHovered = false;
      if (_linkHover != null) {
        _scheduleLinkHoverHide();
      }
    }
  }

  void _scheduleLinkHoverHide() {
    _linkHoverHideTimer?.cancel();
    _linkHoverHideTimer = Timer(_kLinkHoverHideDelay, () {
      _linkHoverHideTimer = null;
      // Ordering-independent guard: only hide once the pointer is over neither
      // the link text nor the popup. The flags reflect the settled pointer
      // state by the time this fires, so the order of surface/popup events in
      // the originating frame does not matter.
      if (!mounted ||
          _surfaceLinkHovered ||
          _linkPopupHovered ||
          _linkHover == null) {
        return;
      }
      setState(() {
        _linkHover = null;
      });
    });
  }

  void _cancelLinkHoverHide() {
    _linkHoverHideTimer?.cancel();
    _linkHoverHideTimer = null;
  }

  /// The pointer entered the popup: keep it alive regardless of any pending
  /// hide the gesture surface requested when the pointer left the link text.
  void _onLinkPopupHoverEnter() {
    _linkPopupHovered = true;
    _cancelLinkHoverHide();
  }

  /// The pointer left the popup: dismiss after the grace delay (the pointer may
  /// be heading back to the link text, which will re-report it).
  void _onLinkPopupHoverExit() {
    _linkPopupHovered = false;
    _scheduleLinkHoverHide();
  }

  /// Hover popup "Edit": select the link run, dismiss the popup, and open the
  /// library link-edit dialog over it. The dialog returns `null` (cancel),
  /// `''` (remove the link), or a new URL; `setLink` maps an empty result to a
  /// clear. The selection is passed explicitly so a link rewrite lands on the
  /// run even if focus drifted while the dialog was open.
  Future<void> _editHoveredLink(WenzLinkHoverInfo info) async {
    final start = info.position.copyWith(offset: info.range.start);
    final end = info.position.copyWith(offset: info.range.end);
    final selection = DocumentSelection(base: start, extent: end);
    widget.controller.setSelection(selection);
    _dismissLinkHover();
    final result = await showWenzLinkEditDialog(
      context: context,
      initialUrl: info.url,
      canRemove: true,
    );
    if (!mounted || result == null) {
      return;
    }
    widget.controller.setLink(
      result.isEmpty ? null : result,
      selection: selection,
    );
  }

  /// Opens an inline link run: forwards its URL to the host callback, then
  /// dismisses any showing hover popup. Serves both the hover popup's "Open"
  /// action and a Ctrl/Cmd+click on the link, which the gesture surface routes
  /// here via [SelectionGestureOverlay.onLinkOpen] (with the caret/selection
  /// placement suppressed).
  void _openHoveredLink(WenzLinkHoverInfo info) {
    widget.onOpenLink?.call(info.url, info.position);
    _dismissLinkHover();
  }

  /// Touch entry point for an inline link: a long-press over a link surfaces
  /// 打开链接 / 复制链接 instead of the desktop mouse-hover popup. No-op when the
  /// long-press did not land on a link.
  void _handleLinkLongPress(Offset globalPosition) {
    if (!mounted) {
      return;
    }
    final info = _probeLinkAtGlobal(globalPosition);
    if (info == null) {
      return;
    }
    unawaited(_showLinkTouchMenu(info));
  }

  Future<void> _showLinkTouchMenu(WenzLinkHoverInfo info) async {
    if (!mounted) {
      return;
    }
    final chosen = await showWenzLinkTouchContextMenu(
      context,
      globalPosition: info.globalRect.center,
      url: info.url,
    );
    if (!mounted) {
      return;
    }
    if (chosen == WenzLinkTouchMenuAction.open) {
      widget.onOpenLink?.call(info.url, info.position);
    }
    // WenzLinkTouchMenuAction.copy already wrote the URL to the clipboard
    // inside showWenzLinkTouchContextMenu.
  }

  void _dismissLinkHover() {
    _linkPopupHovered = false;
    _cancelLinkHoverHide();
    if (_linkHover == null) {
      return;
    }
    setState(() {
      _linkHover = null;
    });
  }

  Widget _buildLinkHoverOverlay() {
    final info = _linkHover;
    if (info == null) {
      return const SizedBox.shrink();
    }
    final box = _editorOverlayKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return const SizedBox.shrink();
    }
    final localTopLeft = box.globalToLocal(info.globalRect.topLeft);
    final linkRect = localTopLeft & info.globalRect.size;
    return WenzLinkHoverOverlay(
      linkRect: linkRect,
      containerWidth: box.size.width,
      url: info.url,
      readOnly: widget.readOnly,
      onEdit: () => _editHoveredLink(info),
      onOpen: widget.onOpenLink == null ? null : () => _openHoveredLink(info),
      onHoverEnter: _onLinkPopupHoverEnter,
      onHoverExit: _onLinkPopupHoverExit,
    );
  }

  Widget _buildMentionSearchOverlay() {
    final trigger = _mentionSearchTrigger;
    if (trigger == null) {
      return const SizedBox.shrink();
    }
    final overlayBox = _editorOverlayKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) {
      return const SizedBox.shrink();
    }
    final caret = _registry.caretRectForPosition(trigger.endPosition);
    if (caret == null) {
      return const SizedBox.shrink();
    }
    final localCaret = overlayBox.globalToLocal(caret.topLeft) & caret.size;
    return WenzMentionSearchOverlay(
      anchorRect: localCaret,
      containerSize: overlayBox.size,
      candidates: _mentionSearchCandidates,
      highlightedIndex: _mentionSearchHighlightedIndex,
      loading: _mentionSearchLoading,
      error: _mentionSearchError,
      tapRegionGroupId: this,
      onHighlightChanged: _setMentionSearchHighlight,
      onCandidateSelected: _insertMentionCandidate,
    );
  }

  WenzMentionCandidate? get _highlightedMentionCandidate {
    if (_mentionSearchCandidates.isEmpty ||
        _mentionSearchHighlightedIndex < 0 ||
        _mentionSearchHighlightedIndex >= _mentionSearchCandidates.length) {
      return null;
    }
    return _mentionSearchCandidates[_mentionSearchHighlightedIndex];
  }

  void _refreshMentionSearch() {
    final callback = widget.mentionSearch;
    if (widget.readOnly ||
        callback == null ||
        _formulaEditTarget != null ||
        widget.slashMenuController?.isOpen == true) {
      _closeMentionSearch();
      return;
    }
    if (widget.controller.isApplyingComposingTextInput ||
        widget.controller.compositionState != null) {
      return;
    }
    final trigger = _detectMentionSearchTrigger();
    if (trigger == null) {
      _suppressedMentionSearchSignature = null;
      _closeMentionSearch();
      return;
    }
    if (_suppressedMentionSearchSignature == trigger.signature) {
      _closeMentionSearch();
      return;
    }
    if (_mentionSearchTrigger?.signature == trigger.signature) {
      return;
    }
    _startMentionSearch(trigger, callback);
  }

  void _startMentionSearch(
    _MentionSearchTrigger trigger,
    WenzMentionSearchCallback callback,
  ) {
    final generation = ++_mentionSearchGeneration;
    _dismissLinkHover();
    setState(() {
      _mentionSearchTrigger = trigger;
      _mentionSearchLoading = true;
      _mentionSearchError = null;
      _mentionSearchCandidates = const <WenzMentionCandidate>[];
      _mentionSearchHighlightedIndex = 0;
    });
    unawaited(_runMentionSearch(trigger, callback, generation));
  }

  Future<void> _runMentionSearch(
    _MentionSearchTrigger trigger,
    WenzMentionSearchCallback callback,
    int generation,
  ) async {
    try {
      final candidates = await Future<List<WenzMentionCandidate>>.value(
        callback(
          WenzMentionSearchRequest(
            query: trigger.query,
            position: trigger.endPosition,
            selection: widget.controller.selection,
          ),
        ),
      );
      if (!mounted ||
          generation != _mentionSearchGeneration ||
          _mentionSearchTrigger?.signature != trigger.signature) {
        return;
      }
      setState(() {
        _mentionSearchLoading = false;
        _mentionSearchError = null;
        _mentionSearchCandidates =
            List<WenzMentionCandidate>.unmodifiable(candidates);
        _mentionSearchHighlightedIndex = 0;
      });
    } on Object catch (error) {
      if (!mounted ||
          generation != _mentionSearchGeneration ||
          _mentionSearchTrigger?.signature != trigger.signature) {
        return;
      }
      setState(() {
        _mentionSearchLoading = false;
        _mentionSearchError = error;
        _mentionSearchCandidates = const <WenzMentionCandidate>[];
        _mentionSearchHighlightedIndex = 0;
      });
    }
  }

  void _moveMentionSearchHighlight(int delta) {
    if (_mentionSearchCandidates.isEmpty || delta == 0) {
      return;
    }
    final next = (_mentionSearchHighlightedIndex + delta) %
        _mentionSearchCandidates.length;
    _setMentionSearchHighlight(
      next < 0 ? next + _mentionSearchCandidates.length : next,
    );
  }

  void _setMentionSearchHighlight(int index) {
    if (_mentionSearchCandidates.isEmpty) {
      return;
    }
    final next = index.clamp(0, _mentionSearchCandidates.length - 1).toInt();
    if (next == _mentionSearchHighlightedIndex) {
      return;
    }
    setState(() {
      _mentionSearchHighlightedIndex = next;
    });
  }

  void _insertMentionCandidate(WenzMentionCandidate candidate) {
    final trigger = _mentionSearchTrigger;
    if (trigger == null || widget.readOnly) {
      return;
    }
    _closeMentionSearch();
    final selection = DocumentSelection(
      base: trigger.startPosition,
      extent: trigger.endPosition,
    );
    widget.controller.insertMention(
      candidate.id,
      candidate.label,
      data: candidate.toMentionData(),
      selection: selection,
    );
    widget.controller.requestFocus();
    _inputClient.syncBuffer();
  }

  void _suppressAndCloseMentionSearch() {
    _suppressedMentionSearchSignature = _mentionSearchTrigger?.signature;
    _closeMentionSearch();
  }

  void _closeMentionSearch() {
    if (_mentionSearchTrigger == null &&
        !_mentionSearchLoading &&
        _mentionSearchError == null &&
        _mentionSearchCandidates.isEmpty) {
      return;
    }
    _mentionSearchGeneration++;
    if (!mounted) {
      _mentionSearchTrigger = null;
      _mentionSearchLoading = false;
      _mentionSearchError = null;
      _mentionSearchCandidates = const <WenzMentionCandidate>[];
      _mentionSearchHighlightedIndex = 0;
      return;
    }
    setState(() {
      _mentionSearchTrigger = null;
      _mentionSearchLoading = false;
      _mentionSearchError = null;
      _mentionSearchCandidates = const <WenzMentionCandidate>[];
      _mentionSearchHighlightedIndex = 0;
    });
  }

  _MentionSearchTrigger? _detectMentionSearchTrigger() {
    final selection = widget.controller.selection;
    if (selection == null || !selection.isCollapsed) {
      return null;
    }
    final position = selection.extent;
    if (!position.path.isBlockText && !position.path.isTableCellText) {
      return null;
    }
    final nodes = _inlineNodesForPosition(position);
    if (nodes == null) {
      return null;
    }
    final beforeCaret = _inlineTextBeforePosition(nodes, position.offset);
    if (beforeCaret == null || beforeCaret.isEmpty) {
      return null;
    }
    final atIndex = _mentionTriggerIndex(beforeCaret);
    if (atIndex == null) {
      return null;
    }
    final query = beforeCaret.substring(atIndex + 1);
    final start = position.copyWith(offset: atIndex);
    return _MentionSearchTrigger(
      query: query,
      startPosition: start,
      endPosition: position,
    );
  }

  String? _inlineTextBeforePosition(List<InlineNode> nodes, int offset) {
    if (offset < 0) {
      return null;
    }
    final buffer = StringBuffer();
    var cursor = 0;
    for (final node in nodes) {
      final length = inlineLength(node);
      final nodeStart = cursor;
      final nodeEnd = cursor + length;
      if (offset <= nodeStart) {
        break;
      }
      if (node is TextRun) {
        final end = math.min(offset, nodeEnd) - nodeStart;
        if (end > 0) {
          buffer.write(node.text.substring(0, end));
        }
      } else if (offset >= nodeEnd) {
        buffer.write(_kMentionSearchInlineBoundary);
      } else {
        return null;
      }
      if (offset <= nodeEnd) {
        break;
      }
      cursor = nodeEnd;
    }
    return buffer.toString();
  }

  int? _mentionTriggerIndex(String textBeforeCaret) {
    for (var index = textBeforeCaret.length - 1; index >= 0; index--) {
      final character = textBeforeCaret[index];
      if (character == '@') {
        if (index == 0 ||
            _isMentionSearchBoundary(textBeforeCaret[index - 1])) {
          return index;
        }
        return null;
      }
      if (_isMentionSearchBoundary(character)) {
        return null;
      }
    }
    return null;
  }

  bool _handleTapBeyondContent(Offset _) {
    if (widget.readOnly) {
      return false;
    }
    final blocks = widget.controller.document.blocks;
    if (blocks.isEmpty) {
      return false;
    }
    final last = blocks.last;
    if (last is TextBlockNode) {
      return false;
    }

    final nextBlockId = _nextBlockId();
    final nextBlockIndex = blocks.length;
    final nextPosition = DocumentPosition.text(
      blockId: nextBlockId,
      blockIndex: nextBlockIndex,
      offset: 0,
    );
    final nextSelection =
        DocumentSelection(base: nextPosition, extent: nextPosition);
    _skipNextCaretScrollIntoView = true;
    widget.controller.insertBlocks(
      index: nextBlockIndex,
      blocks: <BlockNode>[
        TextBlockNode(
          id: nextBlockId,
          type: BlockType.paragraph,
          content: const <InlineNode>[],
        ),
      ],
      selection: nextSelection,
    );
    _inputClient.syncBuffer();
    return true;
  }

  void _handleTableToolbarAction(TableToolbarActionIntent intent) {
    if (widget.readOnly || !widget.controller.canEdit) {
      return;
    }
    final tableBlock = _tableBlockAt(intent.blockIndex);
    if (tableBlock == null) {
      return;
    }

    final range = _currentTableRange(tableBlock, intent);
    if (range == null) {
      return;
    }
    widget.controller.requestFocus();
    if (!_isTableSelectionAction(intent.action)) {
      _selectTableRange(tableBlock, intent.blockIndex, range);
    }

    switch (intent.action) {
      case TableToolbarAction.selectRow:
        _selectTableRange(
          tableBlock,
          intent.blockIndex,
          TableCellRange(
            tableBlockId: tableBlock.id,
            blockIndex: intent.blockIndex,
            startRow: range.startRow,
            endRow: range.endRow,
            startColumn: 0,
            endColumn: tableBlock.table.columnCount - 1,
          ),
        );
        return;
      case TableToolbarAction.selectColumn:
        _selectTableRange(
          tableBlock,
          intent.blockIndex,
          TableCellRange(
            tableBlockId: tableBlock.id,
            blockIndex: intent.blockIndex,
            startRow: 0,
            endRow: tableBlock.table.rowCount - 1,
            startColumn: range.startColumn,
            endColumn: range.endColumn,
          ),
        );
        return;
      case TableToolbarAction.selectTable:
        _selectTableRange(
          tableBlock,
          intent.blockIndex,
          TableCellRange(
            tableBlockId: tableBlock.id,
            blockIndex: intent.blockIndex,
            startRow: 0,
            endRow: tableBlock.table.rowCount - 1,
            startColumn: 0,
            endColumn: tableBlock.table.columnCount - 1,
          ),
        );
        return;
      case TableToolbarAction.insertRowAbove:
        widget.controller.insertTableRow(
          blockIndex: intent.blockIndex,
          rowIndex: range.startRow,
        );
        return;
      case TableToolbarAction.insertRowBelow:
        widget.controller.insertTableRow(
          blockIndex: intent.blockIndex,
          rowIndex: range.endRow + 1,
        );
        return;
      case TableToolbarAction.deleteRow:
        if (!_canDeleteTableRows(tableBlock, range)) {
          return;
        }
        for (var row = range.endRow; row >= range.startRow; row--) {
          final current = _tableBlockAt(intent.blockIndex);
          if (current == null || current.table.rowCount <= 1) {
            break;
          }
          widget.controller.deleteTableRow(
            blockIndex: intent.blockIndex,
            rowIndex: row,
          );
        }
        return;
      case TableToolbarAction.insertColumnBefore:
        widget.controller.insertTableColumn(
          blockIndex: intent.blockIndex,
          columnIndex: range.startColumn,
        );
        return;
      case TableToolbarAction.insertColumnAfter:
        widget.controller.insertTableColumn(
          blockIndex: intent.blockIndex,
          columnIndex: range.endColumn + 1,
        );
        return;
      case TableToolbarAction.deleteColumn:
        if (!_canDeleteTableColumns(tableBlock, range)) {
          return;
        }
        for (var column = range.endColumn;
            column >= range.startColumn;
            column--) {
          final current = _tableBlockAt(intent.blockIndex);
          if (current == null || current.table.columnCount <= 1) {
            break;
          }
          widget.controller.deleteTableColumn(
            blockIndex: intent.blockIndex,
            columnIndex: column,
          );
        }
        return;
      case TableToolbarAction.toggleHeader:
        final anchor = _firstVisibleTableCell(tableBlock, range);
        if (anchor == null) {
          return;
        }
        final nextHeader = !anchor.isHeader;
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellHeader(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            isHeader: nextHeader,
          );
        });
        return;
      case TableToolbarAction.setBackgroundColor:
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellBackground(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            backgroundColor: intent.backgroundColor,
          );
        });
        return;
      case TableToolbarAction.clearBackgroundColor:
        _forEachVisibleTableCell(tableBlock, range, (row, column) {
          widget.controller.setTableCellBackground(
            blockIndex: intent.blockIndex,
            rowIndex: row,
            columnIndex: column,
            backgroundColor: null,
          );
        });
        return;
      case TableToolbarAction.alignLeft:
        _setTableCellAlignment(intent.blockIndex, tableBlock, range, 'left');
        return;
      case TableToolbarAction.alignCenter:
        _setTableCellAlignment(intent.blockIndex, tableBlock, range, 'center');
        return;
      case TableToolbarAction.alignRight:
        _setTableCellAlignment(intent.blockIndex, tableBlock, range, 'right');
        return;
      case TableToolbarAction.clearAlignment:
        _setTableCellAlignment(intent.blockIndex, tableBlock, range, null);
        return;
      case TableToolbarAction.mergeCells:
        if (!range.isSingleCell) {
          widget.controller.mergeTableCells(
            blockIndex: intent.blockIndex,
            startRow: range.startRow,
            startColumn: range.startColumn,
            endRow: range.endRow,
            endColumn: range.endColumn,
          );
        }
        return;
      case TableToolbarAction.splitCell:
        widget.controller.splitTableCell(
          blockIndex: intent.blockIndex,
          rowIndex: range.startRow,
          columnIndex: range.startColumn,
        );
        return;
      case TableToolbarAction.resetColumnWidth:
        for (var column = range.startColumn;
            column <= range.endColumn;
            column++) {
          widget.controller.setTableColumnWidth(
            blockIndex: intent.blockIndex,
            columnIndex: column,
            width: null,
          );
        }
        return;
      case TableToolbarAction.deleteTable:
        _deleteBlock(intent.blockIndex);
        return;
    }
  }

  // Row/column delete commands do not reshape merged spans; toolbar actions
  // reject deletions that would cut through one.
  bool _canDeleteTableRows(
    TableBlockNode tableBlock,
    TableCellRange range,
  ) {
    if (tableBlock.table.rowCount <= 1) {
      return false;
    }
    for (var row = 0; row < tableBlock.table.rowCount; row++) {
      for (var column = 0;
          column < tableBlock.table.rows[row].length;
          column++) {
        final cell = tableBlock.table.rows[row][column];
        if (cell.covered || cell.rowSpan <= 1) {
          continue;
        }
        final spanEndRow = row + cell.rowSpan - 1;
        if (_rangesOverlap(row, spanEndRow, range.startRow, range.endRow)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _canDeleteTableColumns(
    TableBlockNode tableBlock,
    TableCellRange range,
  ) {
    if (tableBlock.table.columnCount <= 1) {
      return false;
    }
    for (var row = 0; row < tableBlock.table.rowCount; row++) {
      for (var column = 0;
          column < tableBlock.table.rows[row].length;
          column++) {
        final cell = tableBlock.table.rows[row][column];
        if (cell.covered || cell.columnSpan <= 1) {
          continue;
        }
        final spanEndColumn = column + cell.columnSpan - 1;
        if (_rangesOverlap(
          column,
          spanEndColumn,
          range.startColumn,
          range.endColumn,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  bool _rangesOverlap(int startA, int endA, int startB, int endB) {
    return startA <= endB && startB <= endA;
  }

  bool _isTableSelectionAction(TableToolbarAction action) {
    switch (action) {
      case TableToolbarAction.selectRow:
      case TableToolbarAction.selectColumn:
      case TableToolbarAction.selectTable:
        return true;
      default:
        return false;
    }
  }

  void _handleTableColumnResize({
    required int blockIndex,
    required int columnIndex,
    required double width,
  }) {
    if (widget.readOnly || !widget.controller.canEdit) {
      return;
    }
    final tableBlock = _tableBlockAt(blockIndex);
    if (tableBlock == null ||
        columnIndex < 0 ||
        columnIndex >= tableBlock.table.columnCount) {
      return;
    }
    widget.controller.setTableColumnWidth(
      blockIndex: blockIndex,
      columnIndex: columnIndex,
      width:
          width.clamp(_kMinTableColumnWidth, _kMaxTableColumnWidth).toDouble(),
    );
  }

  void _handleMediaBlockResize({
    required int blockIndex,
    required double width,
    required double height,
  }) {
    final block = _blockAt(blockIndex);
    if (block is ImageBlockNode) {
      _handleImageBlockResize(
        blockIndex: blockIndex,
        width: width,
        height: height,
      );
      return;
    }
    if (block is VideoBlockNode) {
      _handleVideoBlockResize(
        blockIndex: blockIndex,
        block: block,
        width: width,
      );
    }
  }

  void _handleImageBlockResize({
    required int blockIndex,
    required double width,
    required double height,
  }) {
    final block = _blockAt(blockIndex);
    if (widget.readOnly ||
        !widget.controller.canEdit ||
        block is! ImageBlockNode) {
      return;
    }
    final metrics = _ImageDisplayMetrics.resolve(
      block,
      availableWidth: _availableImageContentWidth(block, blockIndex) ?? width,
      measuredFrameSize: Size(width, height),
    );
    final showWidth = metrics.clampWidth(width);
    final showHeight = metrics.heightForWidth(showWidth);
    final currentWidth = _positiveFiniteDimension(block.showWidth);
    final currentHeight = _positiveFiniteDimension(block.showHeight);
    if (currentWidth != null &&
        currentHeight != null &&
        (currentWidth - showWidth).abs() < _kImageResizeChangeEpsilon &&
        (currentHeight - showHeight).abs() < _kImageResizeChangeEpsilon) {
      return;
    }
    widget.controller.updateImageBlock(
      blockIndex: blockIndex,
      showWidth: showWidth,
      showHeight: showHeight,
    );
  }

  void _handleVideoBlockResize({
    required int blockIndex,
    required VideoBlockNode block,
    required double width,
  }) {
    if (widget.readOnly || !widget.controller.canEdit) {
      return;
    }
    final metrics = _VideoDisplayMetrics.resolve(
      block,
      availableWidth: _availableMediaContentWidth(block, blockIndex) ?? width,
    );
    final showWidth = metrics.clampWidth(width);
    final showHeight = metrics.heightForWidth(showWidth);
    final currentWidth = _positiveFiniteDimension(block.showWidth);
    final currentHeight = _positiveFiniteDimension(block.showHeight);
    if (currentWidth != null &&
        currentHeight != null &&
        (currentWidth - showWidth).abs() < _kImageResizeChangeEpsilon &&
        (currentHeight - showHeight).abs() < _kImageResizeChangeEpsilon) {
      return;
    }
    widget.controller.updateVideoBlock(
      blockIndex: blockIndex,
      showWidth: showWidth,
      showHeight: showHeight,
    );
  }

  Future<void> _openImageDescriptionEditor(
    _ImageDescriptionEditTarget target,
  ) async {
    if (widget.readOnly || !widget.controller.canEdit) {
      return;
    }
    final block = _blockAt(target.blockIndex);
    if (block is! ImageBlockNode || block.id != target.blockId) {
      return;
    }
    final result = await showDialog<_ImageDescriptionEditResult>(
      context: context,
      builder: (context) => _ImageDescriptionEditDialog(
        caption: block.caption,
        altText: block.altText,
      ),
    );
    if (!mounted ||
        result == null ||
        widget.readOnly ||
        !widget.controller.canEdit) {
      return;
    }
    final currentBlock = _blockAt(target.blockIndex);
    if (currentBlock is! ImageBlockNode || currentBlock.id != target.blockId) {
      return;
    }
    if (currentBlock.caption == result.caption &&
        currentBlock.altText == result.altText) {
      return;
    }
    widget.controller.updateImageBlock(
      blockIndex: target.blockIndex,
      caption: result.caption,
      altText: result.altText,
    );
  }

  void _handleTodoCheckedChanged({
    required int blockIndex,
    required bool checked,
  }) {
    widget.controller.setTodoChecked(
      blockIndex: blockIndex,
      checked: checked,
    );
  }

  void _handleRowBlockFormatChanged(
    int blockIndex,
    _RowBlockFormat format,
  ) {
    if (widget.readOnly) {
      return;
    }
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }
    final block = blocks[blockIndex];
    switch (format) {
      case _RowBlockFormat.paragraph:
        if (block is TextBlockNode) {
          widget.controller.setBlockType(
            type: BlockType.paragraph,
            selection: _selectionForBlock(block, blockIndex),
          );
          return;
        }
        if (block is CodeBlockNode) {
          final nextBlock = TextBlockNode(
            id: block.id,
            type: BlockType.paragraph,
            attributes: _rowTextAttributesFor(
              block.attributes,
              _RowBlockFormat.paragraph,
            ),
            content: _plainTextInlineContent(block.code),
          );
          widget.controller.replaceBlocks(
            index: blockIndex,
            deleteCount: 1,
            blocks: <BlockNode>[nextBlock],
            selection: _selectionForBlock(nextBlock, blockIndex),
          );
        }
        return;
      case _RowBlockFormat.heading:
        if (block is TextBlockNode) {
          widget.controller.setBlockType(
            type: BlockType.heading,
            level: block.attributes.level ?? 1,
            selection: _selectionForBlock(block, blockIndex),
          );
          return;
        }
        if (block is CodeBlockNode) {
          final nextBlock = TextBlockNode(
            id: block.id,
            type: BlockType.heading,
            attributes: _rowTextAttributesFor(
              block.attributes,
              _RowBlockFormat.heading,
            ),
            content: _plainTextInlineContent(block.code),
          );
          widget.controller.replaceBlocks(
            index: blockIndex,
            deleteCount: 1,
            blocks: <BlockNode>[nextBlock],
            selection: _selectionForBlock(nextBlock, blockIndex),
          );
        }
        return;
      case _RowBlockFormat.code:
        if (block is CodeBlockNode) {
          return;
        }
        if (block is TextBlockNode) {
          final nextBlock = CodeBlockNode(
            id: block.id,
            code: block.plainText,
            attributes: _rowCodeAttributesFor(block.attributes),
          );
          widget.controller.replaceBlocks(
            index: blockIndex,
            deleteCount: 1,
            blocks: <BlockNode>[nextBlock],
            selection: _selectionForBlock(nextBlock, blockIndex),
          );
        }
        return;
    }
  }

  TableBlockNode? _tableBlockAt(int blockIndex) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    final block = blocks[blockIndex];
    return block is TableBlockNode ? block : null;
  }

  TableCellRange? _currentTableRange(
    TableBlockNode tableBlock,
    TableToolbarActionIntent intent,
  ) {
    if (intent.tableBlockId != null && intent.tableBlockId != tableBlock.id) {
      return null;
    }
    // Popup menu routes can briefly move focus/selection; the toolbar intent's
    // captured block and cell bounds are the authoritative action target.
    return _normalizeTableRange(
      tableBlock,
      blockIndex: intent.blockIndex,
      startRow: math.min(intent.rowIndex, intent.targetEndRowIndex),
      endRow: math.max(intent.rowIndex, intent.targetEndRowIndex),
      startColumn: math.min(
        intent.columnIndex,
        intent.targetEndColumnIndex,
      ),
      endColumn: math.max(
        intent.columnIndex,
        intent.targetEndColumnIndex,
      ),
    );
  }

  TableCellRange? _normalizeTableRange(
    TableBlockNode tableBlock, {
    required int blockIndex,
    required int startRow,
    required int endRow,
    required int startColumn,
    required int endColumn,
  }) {
    final rowCount = tableBlock.table.rowCount;
    final columnCount = tableBlock.table.columnCount;
    if (rowCount == 0 || columnCount == 0) {
      return null;
    }
    return TableCellRange(
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      startRow: startRow.clamp(0, rowCount - 1).toInt(),
      endRow: endRow.clamp(0, rowCount - 1).toInt(),
      startColumn: startColumn.clamp(0, columnCount - 1).toInt(),
      endColumn: endColumn.clamp(0, columnCount - 1).toInt(),
    );
  }

  void _forEachVisibleTableCell(
    TableBlockNode tableBlock,
    TableCellRange range,
    void Function(int row, int column) visit,
  ) {
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = tableBlock.table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        visit(row, column);
      }
    }
  }

  TableCellNode? _firstVisibleTableCell(
    TableBlockNode tableBlock,
    TableCellRange range,
  ) {
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = tableBlock.table.cellAt(row, column);
        if (cell != null && !cell.covered) {
          return cell;
        }
      }
    }
    return null;
  }

  void _setTableCellAlignment(
    int blockIndex,
    TableBlockNode tableBlock,
    TableCellRange range,
    String? alignment,
  ) {
    final currentSelection = widget.controller.selection;
    final selection =
        currentSelection != null && currentSelection.tableCellRange == range
            ? currentSelection
            : _tableRangeSelection(tableBlock, blockIndex, range);
    widget.controller.setAlignment(
      alignment,
      selection: selection,
    );
  }

  void _selectTableRange(
    TableBlockNode tableBlock,
    int blockIndex,
    TableCellRange range,
  ) {
    widget.controller.setSelection(
      _tableRangeSelection(tableBlock, blockIndex, range),
    );
  }

  DocumentSelection _tableRangeSelection(
    TableBlockNode tableBlock,
    int blockIndex,
    TableCellRange range,
  ) {
    final base = DocumentPosition.tableCell(
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      tableRowIndex: range.startRow,
      tableColumnIndex: range.startColumn,
      offset: 0,
    );
    final extent = DocumentPosition.tableCell(
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      tableRowIndex: range.endRow,
      tableColumnIndex: range.endColumn,
      offset: 0,
    );
    return DocumentSelection(base: base, extent: extent);
  }

  void _handleObjectBlockAction(ObjectBlockActionIntent intent) {
    final block = _blockAt(intent.blockIndex);
    if (block == null) {
      return;
    }
    switch (intent.action) {
      case ObjectBlockAction.copyContent:
        final text = block.plainText;
        if (text.isNotEmpty) {
          unawaited(_copyTextToClipboard(text));
        }
        return;
      case ObjectBlockAction.copyReference:
        if (block is ImageBlockNode || block is VideoBlockNode) {
          return;
        }
        final reference = _objectBlockReference(block);
        if (reference.isNotEmpty) {
          unawaited(_copyTextToClipboard(reference));
        }
        return;
      case ObjectBlockAction.duplicate:
        if (widget.readOnly || block is ImageBlockNode) {
          return;
        }
        final duplicate = _copyBlockWithFreshIds(block);
        widget.controller.insertBlocks(
          index: intent.blockIndex + 1,
          blocks: <BlockNode>[duplicate],
          selection: _selectionForBlock(duplicate, intent.blockIndex + 1),
        );
        return;
      case ObjectBlockAction.moveUp:
        if (widget.readOnly) {
          return;
        }
        _moveBlockFromIntent(intent, forward: false);
        return;
      case ObjectBlockAction.moveDown:
        if (widget.readOnly) {
          return;
        }
        _moveBlockFromIntent(intent, forward: true);
        return;
      case ObjectBlockAction.delete:
        if (widget.readOnly) {
          return;
        }
        _deleteBlock(intent.blockIndex);
        return;
      case ObjectBlockAction.resetImageSize:
        if (widget.readOnly) {
          return;
        }
        if (block is ImageBlockNode) {
          widget.controller.updateImageBlock(
            blockIndex: intent.blockIndex,
            clearShowWidth: true,
            clearShowHeight: true,
          );
          return;
        }
        if (block is VideoBlockNode) {
          widget.controller.updateVideoBlock(
            blockIndex: intent.blockIndex,
            clearShowWidth: true,
            clearShowHeight: true,
          );
        }
        return;
      case ObjectBlockAction.setImageDisplayWidth:
        if (widget.readOnly) {
          return;
        }
        final width = intent.value;
        if (width is! num) {
          return;
        }
        final requestedWidth = width.toDouble();
        if (!requestedWidth.isFinite || requestedWidth <= 0) {
          return;
        }
        if (block is ImageBlockNode) {
          final metrics = _ImageDisplayMetrics.resolve(
            block,
            availableWidth:
                _availableImageContentWidth(block, intent.blockIndex) ??
                    requestedWidth,
          );
          final showWidth = metrics.clampWidth(requestedWidth);
          widget.controller.updateImageBlock(
            blockIndex: intent.blockIndex,
            showWidth: showWidth,
            showHeight: metrics.heightForWidth(showWidth),
          );
          return;
        }
        if (block is VideoBlockNode) {
          final metrics = _VideoDisplayMetrics.resolve(
            block,
            availableWidth:
                _availableMediaContentWidth(block, intent.blockIndex) ??
                    requestedWidth,
          );
          final showWidth = metrics.clampWidth(requestedWidth);
          widget.controller.updateVideoBlock(
            blockIndex: intent.blockIndex,
            showWidth: showWidth,
            showHeight: metrics.heightForWidth(showWidth),
          );
        }
        return;
      case ObjectBlockAction.setImageBlockAlignment:
        if (widget.readOnly ||
            (block is! ImageBlockNode && block is! VideoBlockNode)) {
          return;
        }
        final value = intent.value;
        final String? alignment;
        if (value == null) {
          alignment = null;
        } else if (value is String &&
            (value == 'left' || value == 'center' || value == 'right')) {
          alignment = value;
        } else {
          return;
        }
        widget.controller.setAlignment(
          alignment,
          selection: _selectionForBlock(block, intent.blockIndex),
        );
        return;
      case ObjectBlockAction.markFileUploading:
        if (widget.readOnly || block is! FileBlockNode) {
          return;
        }
        widget.controller.updateFileBlock(
          blockIndex: intent.blockIndex,
          uploadStatus: FileUploadStatus.uploading,
          uploadError: '',
        );
        return;
      case ObjectBlockAction.markFileUploaded:
        if (widget.readOnly || block is! FileBlockNode) {
          return;
        }
        widget.controller.updateFileBlock(
          blockIndex: intent.blockIndex,
          uploadStatus: FileUploadStatus.uploaded,
          uploadError: '',
        );
        return;
      case ObjectBlockAction.markFileFailed:
        if (widget.readOnly || block is! FileBlockNode) {
          return;
        }
        widget.controller.updateFileBlock(
          blockIndex: intent.blockIndex,
          uploadStatus: FileUploadStatus.failed,
          uploadError:
              block.uploadError.isEmpty ? 'Upload failed' : block.uploadError,
        );
        return;
    }
  }

  BlockNode? _blockAt(int blockIndex) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    return blocks[blockIndex];
  }

  void _moveBlockFromIntent(
    ObjectBlockActionIntent intent, {
    required bool forward,
  }) {
    final blocks = widget.controller.document.blocks;
    if (intent.blockIndex < 0 || intent.blockIndex >= blocks.length) {
      return;
    }
    final range = _blockMoveRangeFor(intent.blockIndex);
    if (range == null) {
      return;
    }
    final insertionIndex = _resolveMoveBlockInsertionIndex(
      intent,
      range: range,
      blockCount: blocks.length,
      forward: forward,
    );
    if (insertionIndex == null) {
      return;
    }
    _moveBlockRangeToInsertionBoundary(range, insertionIndex);
  }

  int? _resolveMoveBlockInsertionIndex(
    ObjectBlockActionIntent intent, {
    required _BlockMoveRange range,
    required int blockCount,
    required bool forward,
  }) {
    final value = intent.value;
    if (value is _BlockReorderDropRequest) {
      final insertionIndex = value.insertionIndex.clamp(0, blockCount).toInt();
      return range.containsInsertionBoundary(insertionIndex)
          ? null
          : insertionIndex;
    }
    if (value is int) {
      return range.insertionBoundaryForFinalStartIndex(value, blockCount);
    }
    return forward
        ? range.insertionBoundaryForMoveDown(blockCount)
        : range.insertionBoundaryForMoveUp(blockCount);
  }

  void _moveBlockRangeToInsertionBoundary(
    _BlockMoveRange range,
    int insertionIndex,
  ) {
    final blocks = widget.controller.document.blocks;
    if (range.isEmpty ||
        range.startBlockIndex < 0 ||
        range.endBlockIndexExclusive > blocks.length ||
        insertionIndex < 0 ||
        insertionIndex > blocks.length ||
        range.containsInsertionBoundary(insertionIndex)) {
      return;
    }
    final finalStartIndex =
        range.finalStartIndexForInsertionBoundary(insertionIndex);
    if (finalStartIndex < 0 ||
        finalStartIndex >= blocks.length ||
        finalStartIndex == range.startBlockIndex) {
      return;
    }
    if (range.length == 1) {
      widget.controller.moveBlock(
        fromIndex: range.startBlockIndex,
        toIndex: finalStartIndex,
      );
      return;
    }
    widget.controller.moveBlockRange(
      fromIndex: range.startBlockIndex,
      count: range.length,
      toIndex: insertionIndex,
    );
  }

  void _deleteBlock(int blockIndex) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }
    if (blocks.length == 1) {
      final replacement = TextBlockNode(
        id: _nextBlockId(),
        type: BlockType.paragraph,
        content: const <InlineNode>[],
      );
      widget.controller.replaceBlocks(
        index: 0,
        deleteCount: 1,
        blocks: <BlockNode>[replacement],
        selection: _selectionForBlock(replacement, 0),
      );
      return;
    }

    final nextIndex =
        blockIndex < blocks.length - 1 ? blockIndex : blockIndex - 1;
    final nextBlock = blockIndex < blocks.length - 1
        ? blocks[blockIndex + 1]
        : blocks[nextIndex];
    widget.controller.replaceBlocks(
      index: blockIndex,
      deleteCount: 1,
      blocks: const <BlockNode>[],
      selection: _selectionForBlock(nextBlock, nextIndex),
    );
  }

  DocumentSelection _selectionForBlock(BlockNode block, int blockIndex) {
    final position = switch (block) {
      TextBlockNode() => DocumentPosition.text(
          blockId: block.id,
          blockIndex: blockIndex,
          offset: inlineNodesLength(block.content),
        ),
      CodeBlockNode() => DocumentPosition.code(
          blockId: block.id,
          blockIndex: blockIndex,
          offset: block.code.length,
        ),
      CalloutBlockNode() => DocumentPosition(
          blockId: block.id,
          blockIndex: blockIndex,
          path: PositionPath.blockText(block.id),
          offset: 0,
        ),
      TableBlockNode() => _firstTableCellPosition(block, blockIndex) ??
          DocumentPosition(
            blockId: block.id,
            blockIndex: blockIndex,
            path: PositionPath.blockObject(block.id),
            offset: 0,
          ),
      _ => DocumentPosition(
          blockId: block.id,
          blockIndex: blockIndex,
          path: PositionPath.blockObject(block.id),
          offset: 0,
        ),
    };
    if (position.path.isBlockObject) {
      return DocumentSelection(
        base: position,
        extent: position.copyWith(offset: _kAtomicBlockSelectionLength),
      );
    }
    return DocumentSelection(base: position, extent: position);
  }

  DocumentPosition? _firstTableCellPosition(
    TableBlockNode block,
    int blockIndex,
  ) {
    for (var rowIndex = 0; rowIndex < block.table.rows.length; rowIndex++) {
      final row = block.table.rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final cell = row[columnIndex];
        if (cell.covered) {
          continue;
        }
        return DocumentPosition.tableCell(
          tableBlockId: block.id,
          blockIndex: blockIndex,
          tableRowIndex: rowIndex,
          tableColumnIndex: columnIndex,
          offset: 0,
        );
      }
    }
    return null;
  }

  BlockNode _copyBlockWithFreshIds(BlockNode block) {
    if (block is TextBlockNode) {
      return TextBlockNode(
        id: _nextBlockId(),
        type: block.type,
        attributes: block.attributes,
        content: block.content.map((node) => node.copy()).toList(),
      );
    }
    if (block is CodeBlockNode) {
      return CodeBlockNode(
        id: _nextBlockId(),
        code: block.code,
        language: block.language,
        attributes: block.attributes,
      );
    }
    if (block is ImageBlockNode) {
      return ImageBlockNode(
        id: _nextBlockId(),
        assetId: block.assetId,
        file: block.file,
        width: block.width,
        height: block.height,
        showWidth: block.showWidth,
        showHeight: block.showHeight,
        caption: block.caption,
        altText: block.altText,
        attributes: block.attributes,
      );
    }
    if (block is TableBlockNode) {
      return TableBlockNode(
        id: _nextBlockId(),
        table: TableModel(
          rows: block.table.rows
              .map(
                (row) => row
                    .map(
                      (cell) => TableCellNode(
                        id: _nextBlockId(),
                        blocks:
                            cell.blocks.map(_copyBlockWithFreshIds).toList(),
                        rowSpan: cell.rowSpan,
                        columnSpan: cell.columnSpan,
                        isHeader: cell.isHeader,
                        backgroundColor: cell.backgroundColor,
                        covered: cell.covered,
                      ),
                    )
                    .toList(),
              )
              .toList(),
          columnAlignments: Map<int, String>.from(block.table.columnAlignments),
          columnWidths: Map<int, double>.from(block.table.columnWidths),
        ),
        attributes: block.attributes,
      );
    }
    if (block is DividerBlockNode) {
      return DividerBlockNode(id: _nextBlockId(), attributes: block.attributes);
    }
    if (block is VideoBlockNode) {
      return VideoBlockNode(
        id: _nextBlockId(),
        assetId: block.assetId,
        file: block.file,
        attributes: block.attributes,
      );
    }
    if (block is BlockEmbedNode) {
      return BlockEmbedNode(
        id: _nextBlockId(),
        embedType: block.embedType,
        data: Map<String, Object?>.from(block.data),
        fallbackText: block.fallbackText,
        attributes: block.attributes,
      );
    }
    if (block is CalloutBlockNode) {
      return CalloutBlockNode(
        id: _nextBlockId(),
        content: block.content.map((node) => node.copy()).toList(),
        variant: block.variant,
        title: block.title,
        icon: block.icon,
        attributes: block.attributes,
      );
    }
    if (block is FileBlockNode) {
      return FileBlockNode(
        id: _nextBlockId(),
        assetId: block.assetId,
        name: block.name,
        size: block.size,
        mimeType: block.mimeType,
        file: block.file,
        downloadUrl: block.downloadUrl,
        uploadStatus: block.uploadStatus,
        uploadError: block.uploadError,
        attributes: block.attributes,
      );
    }
    return block.copy();
  }

  double? _availableImageContentWidth(ImageBlockNode block, int blockIndex) {
    return _availableMediaContentWidth(block, blockIndex);
  }

  double? _availableMediaContentWidth(BlockNode block, int blockIndex) {
    final entry = _registry.blockRowEntry(block.id, blockIndex);
    final box = entry?.renderBox;
    if (box != null && box.hasSize) {
      final chromeTokens = EditorTokens.resolveBlockChrome(context);
      final showHeadingCollapse =
          _headingCollapseStateFor(block)?.canCollapse ?? false;
      final chromeWidth = _blockRowChromeWidth(
        showDragHandle: !chromeTokens.isMobile &&
            BlockDragHandleSpec.canShow(
              canEdit: !widget.readOnly && widget.controller.canEdit,
              blockIndex: blockIndex,
              blockCount: widget.controller.document.blocks.length,
            ),
        reserveHeadingCollapseSlot: _shouldReserveHeadingCollapseSlot(
          tokens: chromeTokens,
          outlineChromeAttached: _hasHeadingCollapseChrome,
          showHeadingCollapse: showHeadingCollapse,
        ),
        tokens: chromeTokens,
      );
      return _positiveFiniteDimension(box.size.width - chromeWidth);
    }
    return null;
  }

  String _objectBlockReference(BlockNode block) {
    if (block is ImageBlockNode) {
      return _assetLabel(block.assetId, block.file);
    }
    if (block is VideoBlockNode) {
      return _assetLabel(block.assetId, block.file);
    }
    if (block is FileBlockNode) {
      return block.effectiveDownloadUrl;
    }
    if (block is BlockEmbedNode) {
      return block.displayText;
    }
    if (block is DividerBlockNode) {
      return 'divider';
    }
    return block.plainText;
  }

  /// Block ids that must stay mounted under virtualisation: the caret block
  /// (collapsed selection) and the selection endpoints. Keeping these alive
  /// guarantees the caret/selection highlight always paint and the geometry
  /// registry always knows their box. Returns an empty set when there is no
  /// selection.
  Set<String> _keepAliveBlockIds(DocumentSelection? selection) {
    if (selection == null) {
      return <String>{};
    }
    return <String>{
      selection.base.blockId,
      selection.extent.blockId,
    };
  }

  FocusNode get _effectiveFocusNode {
    return widget.focusNode ??
        (_internalFocusNode ??= FocusNode(debugLabel: 'WenzRichTextEditor'));
  }

  void _syncFocusListener(FocusNode focusNode) {
    if (_listenedFocusNode == focusNode) {
      return;
    }
    _listenedFocusNode?.removeListener(_handleFocusChanged);
    focusNode.addListener(_handleFocusChanged);
    _listenedFocusNode = focusNode;
    // Keep the controller's injected node in sync so requestFocus() targets the
    // currently effective focus node even after a swap.
    widget.controller.attachFocusNode(focusNode);
    _controllerAttachedFocusNode = focusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _listenedFocusNode == focusNode) {
        _handleFocusChanged();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // The formula edit popup's TextField is a descendant of this editor Focus
    // in the focus tree. Without this guard, key events (arrow keys, Home/End,
    // backspace, characters) bubble up from the popup's FocusNode and get
    // intercepted below as editor caret movement, hijacking the popup input.
    // While the popup input holds focus, hand all keys to the TextField.
    if (_formulaEditFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    if (_handleSlashMenuKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    if (_handleMentionSearchKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    if (_handleCodeBlockTabKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    if (_handleTableTabKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final resolution = _shortcutManager.resolve(
      event,
      shiftPressed: keyboard.isShiftPressed,
      primaryPressed: keyboard.isControlPressed || keyboard.isMetaPressed,
      controlPressed: keyboard.isControlPressed,
      altPressed: keyboard.isAltPressed,
      metaPressed: keyboard.isMetaPressed,
      readOnly: widget.readOnly,
      imeEnabled: widget.enableIme,
      inputClientAttached: _inputClient.isAttached,
      findEnabled:
          widget.findController != null || widget.onFindRequested != null,
      replaceEnabled:
          widget.findController != null || widget.onReplaceRequested != null,
    );
    if (resolution.disposition == EditorShortcutDisposition.handled) {
      _performShortcut(resolution);
      return KeyEventResult.handled;
    }
    if (resolution.disposition == EditorShortcutDisposition.ignored) {
      return KeyEventResult.ignored;
    }
    // Unrecognised Ctrl/Cmd combo: let it propagate (e.g. browser Ctrl+S,
    // dev tools) rather than swallowing everything.
    return KeyEventResult.ignored;
  }

  bool _handleCodeBlockTabKeyEvent(KeyEvent event) {
    if (widget.readOnly ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return false;
    }
    final selection = widget.controller.selection;
    if (selection == null ||
        selection.start.blockIndex != selection.end.blockIndex ||
        selection.start.path != selection.end.path ||
        !selection.start.path.isBlockCode) {
      return false;
    }
    if (selection.start.blockIndex < 0 ||
        selection.start.blockIndex >=
            widget.controller.document.blocks.length) {
      return false;
    }
    final block = widget.controller.document.blocks[selection.start.blockIndex];
    if (block is! CodeBlockNode) {
      return false;
    }
    widget.controller.indentCodeBlock(
      outdent: HardwareKeyboard.instance.isShiftPressed,
    );
    return true;
  }

  bool _handleTableTabKeyEvent(KeyEvent event) {
    if (widget.readOnly ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return false;
    }
    final selection = widget.controller.selection;
    if (selection == null ||
        selection.start.blockIndex != selection.end.blockIndex ||
        selection.start.path != selection.end.path ||
        !selection.start.path.isTableCellText) {
      return false;
    }
    widget.controller.moveTableCell(
      forward: !HardwareKeyboard.instance.isShiftPressed,
    );
    return true;
  }

  bool _handleSlashMenuKeyEvent(KeyEvent event) {
    final slashMenu = widget.slashMenuController;
    if (widget.readOnly || slashMenu == null || !slashMenu.isOpen) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (slashMenu.items.isEmpty) return false;
      slashMenu.moveHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (slashMenu.items.isEmpty) return false;
      slashMenu.moveHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return slashMenu.activateHighlighted();
    }
    if (key == LogicalKeyboardKey.escape) {
      slashMenu.close();
      return true;
    }
    return false;
  }

  bool _handleMentionSearchKeyEvent(KeyEvent event) {
    if (_mentionSearchTrigger == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveMentionSearchHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveMentionSearchHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final candidate = _highlightedMentionCandidate;
      if (candidate != null) {
        _insertMentionCandidate(candidate);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      _suppressAndCloseMentionSearch();
      return true;
    }
    return false;
  }

  void _toggleHeadingShortcut(int level) {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    final type = _selectionIsHeadingLevel(level)
        ? BlockType.paragraph
        : BlockType.heading;
    widget.controller.setBlockType(
      type: type,
      level: type == BlockType.heading ? level : null,
    );
  }

  bool _selectionIsHeadingLevel(int level) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return false;
    }
    final blocks = widget.controller.document.blocks;
    var sawTextBlock = false;
    for (var index = selection.start.blockIndex;
        index <= selection.end.blockIndex;
        index++) {
      if (index < 0 || index >= blocks.length) {
        continue;
      }
      final block = blocks[index];
      if (block is! TextBlockNode) {
        continue;
      }
      sawTextBlock = true;
      if (block.type != BlockType.heading ||
          (block.attributes.level ?? 1) != level) {
        return false;
      }
    }
    return sawTextBlock;
  }

  void _toggleCodeBlockShortcut() {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    final blockIndex = selection.extent.blockIndex;
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }
    final block = blocks[blockIndex];
    if (!_canChangeRowBlockFormat(block)) {
      return;
    }
    _handleRowBlockFormatChanged(
      blockIndex,
      block is CodeBlockNode ? _RowBlockFormat.paragraph : _RowBlockFormat.code,
    );
  }

  void _cycleListShortcut() {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    final blockIndex = selection.extent.blockIndex;
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }
    final block = blocks[blockIndex];
    if (block is! TextBlockNode) {
      return;
    }
    if (block.type != BlockType.listItem) {
      widget.controller.setBlockType(type: BlockType.listItem);
      return;
    }
    if (block.attributes.listType == 'ordered') {
      widget.controller.setBlockType(type: BlockType.paragraph);
      return;
    }
    widget.controller.setBlockType(
      type: BlockType.listItem,
      listType: 'ordered',
    );
  }

  void _insertFormulaShortcut() {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    widget.controller.insertFormula('');
  }

  void _insertTableShortcut() {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    widget.controller.insertTable(
      index: _currentBlockInsertionIndex(),
      tableId: _nextBlockId(),
      rowCount: 3,
      columnCount: 3,
    );
  }

  void _insertTextBlockShortcut({required bool above}) {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    if (above) {
      widget.controller.insertTextBlockAbove(blockId: _nextBlockId());
    } else {
      widget.controller.insertTextBlockBelow(blockId: _nextBlockId());
    }
    _inputClient.syncBuffer();
  }

  int _currentBlockInsertionIndex() {
    final selection = widget.controller.selection;
    final blockCount = widget.controller.document.blocks.length;
    if (selection == null) {
      return blockCount;
    }
    final position = selection.extent;
    final index = position.blockIndex.clamp(0, blockCount).toInt();
    if (position.path.isTableCellText) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    if (position.path.isBlockObject && position.offset > 0) {
      return (index + 1).clamp(0, blockCount).toInt();
    }
    return index;
  }

  Future<void> _insertLinkShortcut() async {
    if (widget.readOnly) {
      return;
    }
    _revealCurrentSelectionIfHidden();
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    final initialUrl = _shortcutLinkUrl(selection);
    final result = await showWenzLinkEditDialog(
      context: context,
      initialUrl: initialUrl ?? '',
      canRemove: initialUrl != null,
    );
    if (!mounted || result == null) {
      return;
    }
    widget.controller.setLink(
      result.isEmpty ? null : result,
      selection: selection,
    );
    widget.controller.requestFocus();
  }

  String? _shortcutLinkUrl(DocumentSelection selection) {
    if (selection.start.blockIndex != selection.end.blockIndex ||
        selection.start.path != selection.end.path) {
      return null;
    }
    final probe = selection.isCollapsed ? selection.extent : selection.start;
    return _linkInfoAtPosition(probe)?.url;
  }

  bool _selectCurrentCodeBlockCode() {
    final selection = widget.controller.selection;
    if (selection == null ||
        selection.start.blockIndex != selection.end.blockIndex ||
        selection.start.blockId != selection.end.blockId ||
        selection.start.path != selection.end.path ||
        !selection.start.path.isBlockCode) {
      return false;
    }
    final blockIndex = selection.start.blockIndex;
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return false;
    }
    final block = blocks[blockIndex];
    if (block is! CodeBlockNode || block.id != selection.start.blockId) {
      return false;
    }
    final start = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: 0,
    );
    final end = DocumentPosition.code(
      blockId: block.id,
      blockIndex: blockIndex,
      offset: block.code.length,
    );
    widget.controller.setSelection(
      DocumentSelection(base: start, extent: end),
    );
    return true;
  }

  void _performShortcut(EditorShortcutResolution resolution) {
    final controller = widget.controller;
    switch (resolution.intent) {
      case EditorShortcutIntent.selectAll:
        if (!_selectCurrentCodeBlockCode()) {
          controller.selectAll();
        }
        return;
      case EditorShortcutIntent.undo:
        controller.undo();
        _revealCurrentSelectionIfHidden();
        return;
      case EditorShortcutIntent.redo:
        controller.redo();
        _revealCurrentSelectionIfHidden();
        return;
      case EditorShortcutIntent.copy:
        _handleCopy();
        return;
      case EditorShortcutIntent.cut:
        _handleCut();
        return;
      case EditorShortcutIntent.paste:
        _revealCurrentSelectionIfHidden();
        _handlePaste();
        return;
      case EditorShortcutIntent.find:
        widget.onFindRequested?.call();
        widget.findController?.next();
        return;
      case EditorShortcutIntent.replace:
        widget.onReplaceRequested?.call();
        return;
      case EditorShortcutIntent.toggleHeading1:
        _toggleHeadingShortcut(1);
        return;
      case EditorShortcutIntent.toggleHeading2:
        _toggleHeadingShortcut(2);
        return;
      case EditorShortcutIntent.toggleHeading3:
        _toggleHeadingShortcut(3);
        return;
      case EditorShortcutIntent.toggleHeading4:
        _toggleHeadingShortcut(4);
        return;
      case EditorShortcutIntent.toggleHeading5:
        _toggleHeadingShortcut(5);
        return;
      case EditorShortcutIntent.toggleHeading6:
        _toggleHeadingShortcut(6);
        return;
      case EditorShortcutIntent.toggleQuote:
        _revealCurrentSelectionIfHidden();
        controller.toggleQuote();
        return;
      case EditorShortcutIntent.insertFormula:
        _insertFormulaShortcut();
        return;
      case EditorShortcutIntent.toggleCodeBlock:
        _toggleCodeBlockShortcut();
        return;
      case EditorShortcutIntent.toggleTodo:
        _revealCurrentSelectionIfHidden();
        controller.toggleTodo();
        return;
      case EditorShortcutIntent.cycleList:
        _cycleListShortcut();
        return;
      case EditorShortcutIntent.insertTable:
        _insertTableShortcut();
        return;
      case EditorShortcutIntent.insertLink:
        unawaited(_insertLinkShortcut());
        return;
      case EditorShortcutIntent.insertTextBlockAbove:
        _insertTextBlockShortcut(above: true);
        return;
      case EditorShortcutIntent.insertTextBlockBelow:
        _insertTextBlockShortcut(above: false);
        return;
      case EditorShortcutIntent.moveTableCellBackward:
        controller.moveTableCell(forward: false);
        return;
      case EditorShortcutIntent.moveTableCellForward:
        controller.moveTableCell(forward: true);
        return;
      case EditorShortcutIntent.moveCaretBackward:
        _verticalPreferX = null;
        controller.moveCaretBackward(
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretForward:
        _verticalPreferX = null;
        controller.moveCaretForward(
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretUp:
        _handleVerticalKey(false, resolution.expandSelection);
        return;
      case EditorShortcutIntent.moveCaretDown:
        _handleVerticalKey(true, resolution.expandSelection);
        return;
      case EditorShortcutIntent.moveCaretToBlockStart:
        controller.moveCaretToBlockBoundary(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToBlockEnd:
        controller.moveCaretToBlockBoundary(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretByWordBackward:
        controller.moveCaretByWord(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretByWordForward:
        controller.moveCaretByWord(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToDocumentStart:
        controller.moveCaretToDocumentBoundary(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.moveCaretToDocumentEnd:
        controller.moveCaretToDocumentBoundary(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.pageUp:
        _handlePageKey(
          forward: false,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.pageDown:
        _handlePageKey(
          forward: true,
          expandSelection: resolution.expandSelection,
        );
        return;
      case EditorShortcutIntent.deleteBackward:
        if (!_deleteActiveSelectionIfAny()) {
          if (!_expandHiddenContentAdjacentToSelection(forward: false)) {
            controller.deleteBackward();
          }
        }
        return;
      case EditorShortcutIntent.deleteForward:
        if (!_deleteActiveSelectionIfAny()) {
          if (!_expandHiddenContentAdjacentToSelection(forward: true)) {
            controller.deleteForward();
          }
        }
        return;
      case EditorShortcutIntent.enter:
        _revealCurrentSelectionIfHidden();
        controller.enter(newBlockId: _nextBlockId());
        return;
      case EditorShortcutIntent.insertCharacter:
        final character = resolution.character;
        if (character != null) {
          _revealCurrentSelectionIfHidden();
          controller.insertText(character);
        }
        return;
      case EditorShortcutIntent.indent:
        _revealCurrentSelectionIfHidden();
        controller.indent();
        return;
      case EditorShortcutIntent.outdent:
        _revealCurrentSelectionIfHidden();
        controller.outdent();
        return;
      case null:
        return;
    }
  }

  /// Handles PageUp/PageDown: scrolls the content by exactly one viewport (a
  /// "page") and moves the caret by the same amount through the document, so
  /// repeated paging advances one page each press and the caret keeps both its
  /// horizontal column and its relative screen position.
  ///
  /// `forward` = true → PageDown, false → PageUp. When [expandSelection] is
  /// true the anchor stays put and only the extent moves. Falls back to
  /// block-boundary motion when no viewport / caret geometry is available
  /// (e.g. headless tests).
  ///
  /// The caret target is measured in the document's content (scroll) space —
  /// caret Y ± one viewport — and is *not* clamped to the current viewport.
  /// Clamping there was the old bug: it pinned the caret at the viewport edge
  /// and then jumped to the document end on the next press.
  ///
  /// Resolution is split in two:
  /// 1. When the target lands inside the currently-mounted content (the common
  ///    case — a short doc, or a page that stays within the built range) the
  ///    caret is placed synchronously right after the one-page scroll jump.
  /// 2. When the target overshoots the mounted range (a tall, virtualised
  ///    document) the one-page scroll is applied first and the caret is placed
  ///    on the next frame, once the target block is built. Only an actual
  ///    scroll change schedules that frame, so there is always a frame to run
  ///    the deferred place.
  void _handlePageKey({required bool forward, required bool expandSelection}) {
    final controller = widget.controller;
    final selection = controller.selection;
    if (selection == null) {
      controller.moveCaretToBlockBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
      return;
    }
    final caretRect = _registry.caretRectForPosition(selection.extent);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (caretRect == null ||
        renderBox == null ||
        !renderBox.hasSize ||
        !_scrollController.hasClients) {
      // No layout/viewport available: fall back to block-boundary motion so
      // the key still does something predictable (matches prior behaviour).
      controller.moveCaretToBlockBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
      return;
    }
    final scrollPosition = _scrollController.position;
    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    final viewportHeight = renderBox.size.height;
    // Preserve the caret's horizontal column across the page jump so repeated
    // PageUp/PageDown keep the same x position.
    final caretX = caretRect.left;
    // Caret Y in the document's content (scroll) coordinate space: pixels from
    // the top of the full scrollable content.
    final caretContentY = caretRect.top - viewportTop + scrollPosition.pixels;
    // Move exactly one viewport ("page") through the content in the travel
    // direction. Measured in content space, so it is independent of where the
    // viewport currently sits.
    final targetContentY = forward
        ? caretContentY + viewportHeight
        : caretContentY - viewportHeight;

    // The document's content extent in content space: the bottom of the last
    // mounted block. When a page jump overshoots this the caret should go to
    // the document end rather than the (ambiguous) nearest block.
    final globalBottom = _registry.contentExtent();
    final contentExtent = globalBottom == null
        ? null
        : globalBottom - viewportTop + scrollPosition.pixels;
    final beyondDocument = contentExtent == null ||
        (forward && targetContentY >= contentExtent) ||
        (!forward && targetContentY <= 0);

    // Scroll one page so the caret target stays at the same screen offset and
    // the surrounding context stays visible across the jump.
    final pageScroll = (forward
            ? scrollPosition.pixels + viewportHeight
            : scrollPosition.pixels - viewportHeight)
        .clamp(0.0, scrollPosition.maxScrollExtent);
    final scrollChanged = _jumpToScrollOffset(pageScroll.toDouble());

    if (beyondDocument) {
      // A page that overshoots the document: place the caret at the document
      // boundary. Resolve the boundary position via the registry so a plain
      // page yields a collapsed caret (moveCaretToDocumentBoundary would keep
      // the pre-move range end as the anchor, producing a selection range).
      final boundaryContentY =
          forward ? (contentExtent ?? targetContentY) : 0.0;
      final boundaryGlobalY =
          boundaryContentY - scrollPosition.pixels + viewportTop;
      final boundary = _registry.positionFromGlobalOffset(
        Offset(caretX, boundaryGlobalY),
      );
      if (boundary == null) {
        controller.moveCaretToDocumentBoundary(
          forward: forward,
          expandSelection: expandSelection,
        );
      } else {
        final next = expandSelection
            ? DocumentSelection(base: selection.base, extent: boundary)
            : DocumentSelection(base: boundary, extent: boundary);
        controller.setSelection(next);
      }
      _scrollCaretIntoView();
      return;
    }

    if (!scrollChanged) {
      // The scroll did not move (nothing to scroll): the target block is
      // already mounted, so resolve and place the caret synchronously.
      _placeCaretAtContentY(
        caretX: caretX,
        contentY: targetContentY,
        forward: forward,
        expandSelection: expandSelection,
        base: selection.base,
        previousExtent: selection.extent,
      );
      return;
    }
    // The scroll moved — under virtualisation the target block mounts on the
    // next frame, so place the caret then. Only an actual scroll schedules a
    // frame, guaranteeing the deferred place runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _placeCaretAtContentY(
        caretX: caretX,
        contentY: targetContentY,
        forward: forward,
        expandSelection: expandSelection,
        base: selection.base,
        previousExtent: selection.extent,
      );
    });
  }

  /// Resolves the caret position at content-space Y [contentY] (pixels from the
  /// top of the full scrollable content), sets the selection, then pixel-realigns
  /// the scroll. Used by [_handlePageKey] either synchronously (short doc /
  /// target within the mounted range) or on the frame after a one-page scroll
  /// (tall, virtualised document whose target block needs building).
  void _placeCaretAtContentY({
    required double caretX,
    required double contentY,
    required bool forward,
    required bool expandSelection,
    required DocumentPosition base,
    required DocumentPosition previousExtent,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final position = _scrollController.position;
    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    // Content Y → global Y under the current scroll offset.
    final globalY = contentY - position.pixels + viewportTop;
    final target = _registry.positionFromGlobalOffset(Offset(caretX, globalY));
    if (target == null || target == previousExtent) {
      // Target off the mounted range or already there: move to the document
      // boundary so the caret still advances as far as it can.
      widget.controller.moveCaretToDocumentBoundary(
        forward: forward,
        expandSelection: expandSelection,
      );
    } else {
      final next = expandSelection
          ? DocumentSelection(base: base, extent: target)
          : DocumentSelection(base: target, extent: target);
      widget.controller.setSelection(next);
    }
    _scrollCaretIntoView();
  }

  /// Re-evaluates whether the caret needs to be scrolled into view after a
  /// block's measured extent was updated. When content grows (e.g. pasting
  /// several lines), the mutation frame still carries the pre-edit block
  /// height, so the caret-into-view check run then may decide "already visible"
  /// and record the position as handled. Once the real height lands a frame
  /// later, the caret may have ended up off-screen; this re-arms the check so
  /// it runs again against the accurate layout.
  ///
  /// The check is deferred to a post-frame callback because the extent update
  /// arrives via a `setState` in the virtual list, whose re-layout (which
  /// updates `maxScrollExtent` and caret geometry) only completes on the next
  /// frame. Running it synchronously would observe the pre-update layout.
  void _scrollCaretIntoViewIfNeeded() {
    if (!mounted) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection?.isCollapsed != true) {
      return;
    }

    // If the user recently scrolled manually, suppress extent-driven retries
    // so layout remeasurement cannot jump the viewport back to the caret.
    if (_isInUserScrollCooldown()) {
      return;
    }

    // P002: Skip if the caret position hasn't changed since the last check.
    // This avoids redundant rescroll on extent-update callbacks during IME
    // composition (which fires notifyListeners without moving the caret).
    final caretKey = _CaretKey(
      selection!.extent.blockIndex,
      selection.extent.offset,
    );
    if (caretKey == _lastScrollCheckedCaret) {
      return;
    }
    _lastScrollCheckedCaret = caretKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollCaretIntoView();
      }
    });
  }

  /// Scrolls the scrollable just enough to bring the current caret into view.
  /// Used after PageUp/PageDown jumps and after programmatic selection
  /// changes. No-op when the caret is already visible or no scroll client is
  /// attached.
  ///
  /// Under virtualisation the caret's block may not be mounted yet (it has
  /// never entered the viewport), in which case we cannot read its pixel
  /// position. We fall back to an estimate — mean block height × target block
  /// index — to jump the viewport close enough for ListView to build the
  /// block; a follow-up frame then pixel-aligns via the now-available rect.
  void _scrollCaretIntoView() {
    if (!_scrollController.hasClients) {
      return;
    }
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final caretRect = _registry.caretRectForPosition(selection.extent);
    final position = _scrollController.position;
    final viewportHeight = renderBox.size.height;

    if (caretRect == null) {
      // The caret's block is not laid out (virtualised out of view). Estimate
      // the scroll offset from the average built-block height so the viewport
      // jumps near the target; the next frame will pixel-align once the block
      // is mounted.
      final estimated = _estimateOffsetForBlock(
        selection.extent.blockIndex,
        viewportHeight: viewportHeight,
      );
      if (estimated != null && (estimated - position.pixels).abs() > 1) {
        _jumpToScrollOffset(estimated);
        // Re-run on the next frame so the freshly-mounted block's rect is
        // available for pixel-accurate alignment. Bound the re-arm depth so a
        // persistently mis-estimated block height cannot loop forever.
        _scrollRealignDepth += 1;
        if (_scrollRealignDepth <= _maxScrollRealignFrames) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollCaretIntoView();
            }
          });
        }
      }
      return;
    }
    // A real rect resolved — the estimate loop has converged (or was never
    // needed). Reset the guard for the next programmatic jump.
    _scrollRealignDepth = 0;

    final viewportTop = renderBox.localToGlobal(Offset.zero).dy;
    // Convert the caret's global Y into the scrollable's content coordinate
    // (pixels from the top of the full content).
    final caretTopInContent = caretRect.top - viewportTop + position.pixels;
    final caretBottomInContent = caretTopInContent + caretRect.height;
    final visibleTop = position.pixels;
    final visibleBottom = position.pixels + viewportHeight;
    if (caretTopInContent >= visibleTop &&
        caretBottomInContent <= visibleBottom) {
      return;
    }
    double target;
    if (caretTopInContent < visibleTop) {
      // Caret is above the viewport: align it with the top edge.
      target = caretTopInContent;
    } else {
      // Caret is below the viewport: align its bottom with the viewport's
      // bottom edge.
      target = caretBottomInContent - viewportHeight;
    }
    _jumpToScrollOffset(target);
  }

  /// Estimates the scroll offset that brings [blockIndex] into view, using the
  /// cached measured height for each block when available and a measured
  /// average for blocks the user has not visited yet.
  double? _estimateOffsetForBlock(
    int blockIndex, {
    required double viewportHeight,
  }) {
    final blocks = widget.controller.document.blocks;
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return null;
    }
    final projection = _visibleBlockProjectionFor(blocks);
    final visibleIndex =
        projection.nearestVisibleIndexForBlockIndex(blockIndex);
    if (visibleIndex == null) {
      return null;
    }
    // Offset so the target block sits near the top of the viewport. We aim
    // one third down from the top so the surrounding context is visible.
    final targetBlockTop = _extentCache.offsetFor(
      projection.visibleBlocks,
      visibleIndex,
      widget.blockSpacing,
    );
    return targetBlockTop - viewportHeight / 3;
  }

  /// Handles Up/Down arrow keys: visual-line motion within a block (keeping the
  /// horizontal column), crossing to the neighbouring block at a boundary, and
  /// exiting a table cell at the table's first/last row.
  void _handleVerticalKey(bool forward, bool shift) {
    final controller = widget.controller;
    final selection = controller.selection;
    if (selection == null) {
      return;
    }
    final extent = selection.extent;

    // Table cells: try intra-table row navigation first.
    if (extent.path.isTableCellText && !shift) {
      final before = controller.selection;
      controller.moveTableCellVertical(forward: forward);
      if (controller.selection != before) {
        // Moved within the table.
        return;
      }
      // On the table boundary row: fall through to cross-block exit.
      controller.moveCaretVertical(forward: forward, expandSelection: shift);
      _verticalPreferX = null;
      return;
    }

    // Plain text/code blocks: visual-line motion via the layout service.
    // preferX is in the block's LOCAL coordinate space; null lets the layout
    // use the caret's own local x on the first press.
    final result = _registry.verticalMoveForPosition(
      extent,
      forward,
      preferX: _verticalPreferX,
    );
    final target = result?.targetOffset;
    if (target != null) {
      // Remember the local column for repeated vertical moves.
      _verticalPreferX = result?.caretX ?? _verticalPreferX;
      final next = extent.copyWith(offset: target);
      controller.setSelection(
        shift
            ? DocumentSelection(base: selection.base, extent: next)
            : DocumentSelection(base: next, extent: next),
      );
      return;
    }
    // At the block's first/last visual line: cross to the neighbour.
    _verticalPreferX = null;
    controller.moveCaretVertical(forward: forward, expandSelection: shift);
  }

  void _handlePlatformSelector(String selectorName) {
    final syncAfter = _performPlatformSelector(selectorName);
    if (syncAfter) {
      _inputClient.syncBuffer();
    }
  }

  bool _performPlatformSelector(String selectorName) {
    final controller = widget.controller;
    switch (selectorName) {
      case 'copy:':
        _runSelectorFuture(_handleCopy());
        return true;
      case 'selectAll:':
        if (!_selectCurrentCodeBlockCode()) {
          controller.selectAll();
        }
        return true;
      case 'moveLeft:':
      case 'moveBackward:':
        _verticalPreferX = null;
        controller.moveCaretBackward();
        return true;
      case 'moveRight:':
      case 'moveForward:':
        _verticalPreferX = null;
        controller.moveCaretForward();
        return true;
      case 'moveLeftAndModifySelection:':
      case 'moveBackwardAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretBackward(expandSelection: true);
        return true;
      case 'moveRightAndModifySelection:':
      case 'moveForwardAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretForward(expandSelection: true);
        return true;
      case 'moveUp:':
        _handleVerticalKey(false, false);
        return true;
      case 'moveDown:':
        _handleVerticalKey(true, false);
        return true;
      case 'moveUpAndModifySelection:':
        _handleVerticalKey(false, true);
        return true;
      case 'moveDownAndModifySelection:':
        _handleVerticalKey(true, true);
        return true;
      case 'moveWordLeft:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: false);
        return true;
      case 'moveWordRight:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: true);
        return true;
      case 'moveWordLeftAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: false, expandSelection: true);
        return true;
      case 'moveWordRightAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretByWord(forward: true, expandSelection: true);
        return true;
      case 'moveToBeginningOfParagraph:':
      case 'moveToLeftEndOfLine:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(forward: false);
        return true;
      case 'moveToEndOfParagraph:':
      case 'moveToRightEndOfLine:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(forward: true);
        return true;
      case 'moveParagraphBackwardAndModifySelection:':
      case 'moveToLeftEndOfLineAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(
          forward: false,
          expandSelection: true,
        );
        return true;
      case 'moveParagraphForwardAndModifySelection:':
      case 'moveToRightEndOfLineAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToBlockBoundary(
          forward: true,
          expandSelection: true,
        );
        return true;
      case 'moveToBeginningOfDocument:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(forward: false);
        return true;
      case 'moveToEndOfDocument:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(forward: true);
        return true;
      case 'moveToBeginningOfDocumentAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(
          forward: false,
          expandSelection: true,
        );
        return true;
      case 'moveToEndOfDocumentAndModifySelection:':
        _verticalPreferX = null;
        controller.moveCaretToDocumentBoundary(
          forward: true,
          expandSelection: true,
        );
        return true;
      case 'scrollToBeginningOfDocument:':
        _scrollToDocumentBoundary(forward: false);
        return false;
      case 'scrollToEndOfDocument:':
        _scrollToDocumentBoundary(forward: true);
        return false;
      case 'scrollPageUp:':
        _scrollPage(forward: false);
        return false;
      case 'scrollPageDown:':
        _scrollPage(forward: true);
        return false;
      case 'pageUpAndModifySelection:':
        _handlePageKey(forward: false, expandSelection: true);
        return true;
      case 'pageDownAndModifySelection:':
        _handlePageKey(forward: true, expandSelection: true);
        return true;
      case 'cancelOperation:':
        controller.setCompositionState(null);
        return true;
    }

    if (widget.readOnly) {
      return false;
    }
    switch (selectorName) {
      case 'deleteBackward:':
        if (!_deleteActiveSelectionIfAny()) {
          if (!_expandHiddenContentAdjacentToSelection(forward: false)) {
            controller.deleteBackward();
          }
        }
        return true;
      case 'deleteForward:':
        if (!_deleteActiveSelectionIfAny()) {
          if (!_expandHiddenContentAdjacentToSelection(forward: true)) {
            controller.deleteForward();
          }
        }
        return true;
      case 'deleteWordBackward:':
        _deleteByWord(forward: false);
        return true;
      case 'deleteWordForward:':
        _deleteByWord(forward: true);
        return true;
      case 'deleteToBeginningOfLine:':
        _deleteToBlockBoundary(forward: false);
        return true;
      case 'deleteToEndOfLine:':
        _deleteToBlockBoundary(forward: true);
        return true;
      case 'cut:':
        _runSelectorFuture(_handleCut());
        return true;
      case 'paste:':
        _revealCurrentSelectionIfHidden();
        _runSelectorFuture(_handlePaste());
        return true;
      case 'insertTab:':
        controller.moveTableCell(forward: true);
        return true;
      case 'insertBacktab:':
        controller.moveTableCell(forward: false);
        return true;
    }
    return false;
  }

  bool _deleteActiveSelectionIfAny() {
    final selection = widget.controller.selection;
    if (selection == null || selection.isCollapsed) {
      return false;
    }
    if (_revealCurrentSelectionIfHidden()) {
      _inputClient.syncBuffer();
      return true;
    }
    widget.controller.deleteSelection(selection);
    _inputClient.syncBuffer();
    return true;
  }

  void _deleteByWord({required bool forward}) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    if (!selection.isCollapsed) {
      _deleteActiveSelectionIfAny();
      return;
    }
    if (_expandHiddenContentAdjacentToSelection(forward: forward)) {
      return;
    }
    widget.controller.moveCaretByWord(
      forward: forward,
      expandSelection: true,
    );
    widget.controller.deleteSelection();
  }

  void _deleteToBlockBoundary({required bool forward}) {
    final selection = widget.controller.selection;
    if (selection == null) {
      return;
    }
    if (!selection.isCollapsed) {
      _deleteActiveSelectionIfAny();
      return;
    }
    if (_expandHiddenContentAdjacentToSelection(forward: forward)) {
      return;
    }
    widget.controller.moveCaretToBlockBoundary(
      forward: forward,
      expandSelection: true,
    );
    widget.controller.deleteSelection();
  }

  void _scrollToDocumentBoundary({required bool forward}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    _jumpToScrollOffset(forward ? position.maxScrollExtent : 0);
  }

  void _scrollPage({required bool forward}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final delta = position.viewportDimension;
    final target = position.pixels + (forward ? delta : -delta);
    _jumpToScrollOffset(target);
  }

  bool _jumpToScrollOffset(double target) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    final next = target.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((next - position.pixels).abs() <= 0.5) {
      return false;
    }
    _programmaticScrollDepth += 1;
    try {
      position.jumpTo(next);
    } finally {
      _programmaticScrollDepth -= 1;
    }
    _scheduleInputGeometrySync();
    return true;
  }

  void _scheduleInputGeometrySync() {
    if (_inputGeometrySyncPending) {
      return;
    }
    _inputGeometrySyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputGeometrySyncPending = false;
      if (!mounted || !_inputClient.isAttached) {
        return;
      }
      _inputClient.syncBuffer();
    });
  }

  void _runSelectorFuture(Future<void> future) {
    unawaited(
      future.whenComplete(() {
        if (mounted) {
          _inputClient.syncBuffer();
        }
      }),
    );
  }

  Future<void> _handleCopy() async {
    WenzClipboardDebugLog.event(
      'editor.copy-invoked',
      fields: <String, Object?>{
        'selection':
            WenzClipboardDebugLog.selection(widget.controller.selection),
        'documentBlocks': widget.controller.document.blocks.length,
      },
    );
    final payload = widget.controller.copySelectionPayload();
    if (payload == null) {
      WenzClipboardDebugLog.event(
        'editor.copy-skipped',
        fields: const <String, Object?>{'reason': 'payload=null'},
      );
      return;
    }
    final success =
        await defaultRichClipboardAdapter.tryWriteCopyPayload(payload);
    WenzClipboardDebugLog.event(
      'editor.copy-finished',
      fields: <String, Object?>{'success': success},
    );
  }

  Future<void> _handleCut() async {
    WenzClipboardDebugLog.event(
      'editor.cut-invoked',
      fields: <String, Object?>{
        'selection':
            WenzClipboardDebugLog.selection(widget.controller.selection),
      },
    );
    if (_revealCurrentSelectionIfHidden()) {
      WenzClipboardDebugLog.event(
        'editor.cut-skipped',
        fields: const <String, Object?>{'reason': 'revealed-hidden-selection'},
      );
      return;
    }
    final payload = widget.controller.cutSelectionPayload();
    if (payload == null) {
      WenzClipboardDebugLog.event(
        'editor.cut-skipped',
        fields: const <String, Object?>{'reason': 'payload=null'},
      );
      return;
    }
    final success =
        await defaultRichClipboardAdapter.tryWriteCopyPayload(payload);
    WenzClipboardDebugLog.event(
      'editor.cut-finished',
      fields: <String, Object?>{'success': success},
    );
  }

  Future<void> _copyTextToClipboard(String text) async {
    await defaultRichClipboardAdapter.writePlainText(text);
  }

  Future<void> _handlePaste() async {
    WenzClipboardDebugLog.event(
      'editor.paste-invoked',
      fields: <String, Object?>{
        'selection':
            WenzClipboardDebugLog.selection(widget.controller.selection),
        'externalImagesEnabled': widget.enableExternalImageInput,
      },
    );
    _revealCurrentSelectionIfHidden();
    final snapshot = await _clipboardAdapter.read(
      includeExternalImages: widget.enableExternalImageInput,
    );
    final wenzRichText = snapshot.wenzRichTextForPaste;
    if (wenzRichText != null) {
      WenzClipboardDebugLog.event(
        'editor.paste-route',
        fields: <String, Object?>{
          'route': 'wenz-private',
          'value': WenzClipboardDebugLog.text(wenzRichText),
        },
      );
      final parsed = widget.controller.clipboardService.parse(wenzRichText);
      if (parsed.hasContent) {
        widget.controller.pasteParsedClipboard(parsed);
        return;
      }
      WenzClipboardDebugLog.event(
        'editor.paste-route-rejected',
        fields: const <String, Object?>{
          'route': 'wenz-private',
          'reason': 'parsed-empty',
          'fallback': 'html/markdown/plain-text',
        },
      );
    }

    final images = await _prepareExternalImages(snapshot.images);
    if (images.isNotEmpty) {
      WenzClipboardDebugLog.event(
        'editor.paste-route',
        fields: <String, Object?>{
          'route': 'external-images',
          'count': images.length,
        },
      );
      _pasteExternalImages(images);
      return;
    }

    final html = snapshot.html;
    if (html != null) {
      WenzClipboardDebugLog.event(
        'editor.paste-route',
        fields: <String, Object?>{
          'route': 'html',
          'value': WenzClipboardDebugLog.text(html),
        },
      );
      widget.controller.pasteHtml(html);
      return;
    }
    final markdown = snapshot.markdown;
    if (markdown != null) {
      WenzClipboardDebugLog.event(
        'editor.paste-route',
        fields: <String, Object?>{
          'route': 'markdown',
          'value': WenzClipboardDebugLog.text(markdown),
        },
      );
      widget.controller.pasteMarkdown(markdown);
      return;
    }
    final plainText = snapshot.plainText;
    if (plainText == null) {
      WenzClipboardDebugLog.event(
        'editor.paste-skipped',
        fields: const <String, Object?>{'reason': 'clipboard-empty'},
      );
      return;
    }
    WenzClipboardDebugLog.event(
      'editor.paste-route',
      fields: <String, Object?>{
        'route': 'plain-text',
        'value': WenzClipboardDebugLog.text(plainText),
      },
    );
    widget.controller.pasteText(plainText);
  }

  RichClipboardAdapter get _clipboardAdapter {
    final reader = widget.externalImageClipboardReader;
    if (reader == null) {
      return defaultRichClipboardAdapter;
    }
    return RichClipboardAdapter(externalImageClipboardReader: reader);
  }

  Future<List<ExternalImageBlockDescription>> _prepareExternalImages(
    List<ExternalImageInput> inputs,
  ) async {
    if (inputs.isEmpty) {
      return const <ExternalImageBlockDescription>[];
    }
    final store = widget.externalImageStore ??
        external_image_store.createDefaultExternalImageStore();
    final descriptions = <ExternalImageBlockDescription>[];
    final consumedIndexes = <int>{};
    for (var index = 0; index < inputs.length; index++) {
      if (consumedIndexes.contains(index)) {
        continue;
      }
      final input = inputs[index];
      final relatedIndex = _relatedExternalImageInputIndex(
        inputs,
        index,
        consumedIndexes,
      );
      final relatedInput = relatedIndex == null ? null : inputs[relatedIndex];
      final fileInput = relatedInput == null
          ? null
          : _isFileExternalImageInput(input)
              ? input
              : relatedInput;
      final memoryFallback = relatedInput == null
          ? null
          : input.kind == ExternalImageInputKind.memory
              ? input
              : relatedInput;
      final ExternalImageBlockDescription? description;
      if (fileInput != null && memoryFallback != null) {
        description = await _prepareExternalImageWithMemoryFallback(
          store: store,
          fileInput: fileInput,
          memoryFallback: memoryFallback,
        );
      } else {
        description = await _prepareExternalImage(store, input);
      }
      if (description != null) {
        descriptions.add(description);
      }
      consumedIndexes.add(index);
      if (relatedIndex != null) {
        consumedIndexes.add(relatedIndex);
      }
    }
    return descriptions;
  }

  Future<ExternalImageBlockDescription?> _prepareExternalImage(
    ExternalImageStore store,
    ExternalImageInput input,
  ) async {
    try {
      return (await store.prepare(input)).description;
    } on Object {
      return null;
    }
  }

  Future<ExternalImageBlockDescription?>
      _prepareExternalImageWithMemoryFallback({
    required ExternalImageStore store,
    required ExternalImageInput fileInput,
    required ExternalImageInput memoryFallback,
  }) async {
    final fallbackPixelSize =
        externalImagePixelSizeFromBytes(memoryFallback.bytes);
    final fileDescription = await _prepareExternalImage(store, fileInput);
    if (fileDescription == null) {
      return _prepareExternalImage(store, memoryFallback);
    }
    if (_shouldUseExternalImageFallbackPixelSize(
      fileDescription,
      fallbackPixelSize,
    )) {
      return _externalImageDescriptionWithPixelSize(
        fileDescription,
        fallbackPixelSize!,
      );
    }
    if (_hasExternalImagePixelSize(fileDescription)) {
      return fileDescription;
    }
    final fallbackDescription = await _prepareExternalImage(
      store,
      memoryFallback,
    );
    if (fallbackDescription != null &&
        _hasExternalImagePixelSize(fallbackDescription)) {
      return _externalImageDescriptionWithDimensions(
        fileDescription,
        fallbackDescription,
      );
    }
    return fileDescription;
  }

  int? _relatedExternalImageInputIndex(
    List<ExternalImageInput> inputs,
    int index,
    Set<int> consumedIndexes,
  ) {
    final input = inputs[index];
    if (!input.isAccepted ||
        (!_isFileExternalImageInput(input) &&
            input.kind != ExternalImageInputKind.memory)) {
      return null;
    }
    final preferredIndex = index + 1;
    if (preferredIndex < inputs.length &&
        !consumedIndexes.contains(preferredIndex) &&
        _externalImageInputsMayDescribeSameImage(
          input,
          inputs[preferredIndex],
          adjacent: true,
        )) {
      return preferredIndex;
    }
    for (var candidateIndex = 0;
        candidateIndex < inputs.length;
        candidateIndex++) {
      if (candidateIndex == index || consumedIndexes.contains(candidateIndex)) {
        continue;
      }
      if (_externalImageInputsMayDescribeSameImage(
        input,
        inputs[candidateIndex],
        adjacent: (candidateIndex - index).abs() == 1,
      )) {
        return candidateIndex;
      }
    }
    return null;
  }

  bool _externalImageInputsMayDescribeSameImage(
    ExternalImageInput first,
    ExternalImageInput second, {
    required bool adjacent,
  }) {
    if (!first.isAccepted ||
        !second.isAccepted ||
        first.source != second.source ||
        !_isFileAndMemoryExternalImagePair(first, second)) {
      return false;
    }
    if (adjacent && first.source == ExternalImageInputSource.clipboard) {
      return true;
    }
    final firstName = _externalImageCandidateStem(first);
    final secondName = _externalImageCandidateStem(second);
    return firstName != null && secondName != null && firstName == secondName;
  }

  bool _isFileAndMemoryExternalImagePair(
    ExternalImageInput first,
    ExternalImageInput second,
  ) {
    return (_isFileExternalImageInput(first) &&
            second.kind == ExternalImageInputKind.memory) ||
        (_isFileExternalImageInput(second) &&
            first.kind == ExternalImageInputKind.memory);
  }

  bool _isFileExternalImageInput(ExternalImageInput input) {
    return switch (input.kind) {
      ExternalImageInputKind.filePath || ExternalImageInputKind.fileUri => true,
      ExternalImageInputKind.memory => false,
    };
  }

  bool _hasExternalImagePixelSize(ExternalImageBlockDescription description) {
    final width = description.width;
    final height = description.height;
    return width != null && height != null && width > 0 && height > 0;
  }

  bool _shouldUseExternalImageFallbackPixelSize(
    ExternalImageBlockDescription description,
    ExternalImagePixelSize? fallbackPixelSize,
  ) {
    if (fallbackPixelSize == null) {
      return false;
    }
    if (!_hasExternalImagePixelSize(description)) {
      return true;
    }
    final currentRatio = description.width! / description.height!;
    final fallbackRatio = fallbackPixelSize.width / fallbackPixelSize.height;
    return (currentRatio - fallbackRatio).abs() > 0.001;
  }

  ExternalImageBlockDescription _externalImageDescriptionWithPixelSize(
    ExternalImageBlockDescription description,
    ExternalImagePixelSize pixelSize,
  ) {
    return ExternalImageBlockDescription(
      file: description.file,
      caption: description.caption,
      altText: description.altText,
      width: pixelSize.width,
      height: pixelSize.height,
    );
  }

  ExternalImageBlockDescription _externalImageDescriptionWithDimensions(
    ExternalImageBlockDescription description,
    ExternalImageBlockDescription dimensionsSource,
  ) {
    return ExternalImageBlockDescription(
      file: description.file,
      caption: description.caption,
      altText: description.altText,
      width: dimensionsSource.width,
      height: dimensionsSource.height,
    );
  }

  String? _externalImageCandidateStem(ExternalImageInput input) {
    final normalized = externalImageDisplayName(input).trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == defaultExternalImageCaption.toLowerCase()) {
      return null;
    }
    return normalized;
  }

  void _pasteExternalImages(
    List<ExternalImageBlockDescription> images, {
    DocumentSelection? selection,
  }) {
    if (widget.readOnly) {
      return;
    }
    final result = widget.controller.pasteExternalImages(
      images,
      selection: selection,
    );
    if (result.isSuccess) {
      widget.controller.requestFocus();
    }
  }

  String _nextBlockId() {
    _generatedBlockCount += 1;
    return 'block-${DateTime.now().microsecondsSinceEpoch}-$_generatedBlockCount';
  }
}

class _BlockExtentCache {
  final Map<String, double> _extents = <String, double>{};
  final Map<String, int> _blockVersions = <String, int>{};
  final Map<String, Object> _measureSignatures = <String, Object>{};
  Set<String> _knownBlockIds = <String>{};
  List<BlockNode>? _retainedBlocks;
  List<BlockNode>? _layoutBlocks;
  BlockLayoutIndex? _layoutIndex;
  Map<String, int> _layoutIndexesById = const <String, int>{};
  double? _layoutSpacing;
  double _measuredExtentTotal = 0;
  int _epoch = 0;
  double? _contentWidth;

  void clear() {
    _epoch += 1;
    _extents.clear();
    _measuredExtentTotal = 0;
    _invalidateLayout();
  }

  void updateContentWidth(double? width) {
    if (width == null || !width.isFinite || width < 0) {
      return;
    }
    final previous = _contentWidth;
    if (previous != null && (previous - width).abs() <= 0.5) {
      return;
    }
    _contentWidth = width;
    clear();
  }

  void removeBlock(String blockId) {
    final removedExtent = _extents.remove(blockId);
    if (removedExtent != null) {
      _measuredExtentTotal -= removedExtent;
    }
    _measureSignatures.remove(blockId);
    _blockVersions[blockId] = (_blockVersions[blockId] ?? 0) + 1;
  }

  void retainBlocks(List<BlockNode> blocks) {
    if (identical(blocks, _retainedBlocks)) {
      return;
    }
    final previousBlocks = _retainedBlocks;
    if (blocks is PersistentBlockList && previousBlocks != null) {
      final delta = blocks.deltaSince(previousBlocks);
      if (delta != null && blocks.length == previousBlocks.length) {
        var sameStructure = true;
        for (final index in delta.changedIndexes) {
          if (blocks[index].id != previousBlocks[index].id) {
            sameStructure = false;
            break;
          }
        }
        if (sameStructure) {
          for (final index in delta.changedIndexes) {
            _syncMeasureSignature(blocks[index]);
          }
          _retainedBlocks = blocks;
          return;
        }
      }
    }
    final ids = blocks.map((block) => block.id).toSet();
    for (final id in _knownBlockIds.difference(ids)) {
      removeBlock(id);
    }
    for (final block in blocks) {
      _syncMeasureSignature(block);
    }
    _knownBlockIds = ids;
    _retainedBlocks = blocks;
    _extents.removeWhere((id, _) => !ids.contains(id));
    _measureSignatures.removeWhere((id, _) => !ids.contains(id));
  }

  int tokenFor(String blockId) {
    return Object.hash(_epoch, _blockVersions[blockId] ?? 0);
  }

  _ExtentRecordResult? record(String blockId, int token, double extent) {
    if (token != tokenFor(blockId)) {
      return null;
    }
    if (!extent.isFinite || extent <= 0) {
      return null;
    }
    final previous = _extents[blockId];
    if (previous != null && (previous - extent).abs() <= 0.5) {
      return null;
    }
    final layoutIndex = _layoutIndexesById[blockId];
    final previousLayoutExtent = layoutIndex == null
        ? extent
        : _layoutIndex?.extentAt(layoutIndex) ?? extent;
    final previousBlockTop =
        layoutIndex == null ? null : _layoutIndex?.topFor(layoutIndex);
    _extents[blockId] = extent;
    _measuredExtentTotal += extent - (previous ?? 0);
    if (layoutIndex != null && layoutIndex < (_layoutIndex?.length ?? 0)) {
      _layoutIndex!
        ..updateExtent(layoutIndex, extent)
        ..updateEstimatedExtent(averageExtent);
    }
    return _ExtentRecordResult(
      previousBlockTop: previousBlockTop,
      extentDelta: extent - previousLayoutExtent,
    );
  }

  double get averageExtent {
    if (_extents.isEmpty) {
      return _kDefaultBlockExtent;
    }
    return _measuredExtentTotal / _extents.length;
  }

  double extentFor(BlockNode block) {
    return _extents[block.id] ?? averageExtent;
  }

  double offsetFor(List<BlockNode> blocks, int blockIndex, double spacing) {
    if (blocks.isEmpty || blockIndex <= 0) {
      return 0;
    }
    final metrics = layoutFor(blocks, spacing);
    final safeIndex = blockIndex.clamp(0, blocks.length - 1).toInt();
    return metrics.topFor(safeIndex);
  }

  _BlockLayoutMetrics layoutFor(List<BlockNode> blocks, double spacing) {
    _syncLayout(blocks, spacing);
    return _BlockLayoutMetrics(
      blocks: blocks,
      index: _layoutIndex!,
      indexesById: _layoutIndexesById,
    );
  }

  void _syncLayout(List<BlockNode> blocks, double spacing) {
    if (_layoutIndex != null &&
        identical(blocks, _layoutBlocks) &&
        _layoutSpacing == spacing) {
      return;
    }

    final previousBlocks = _layoutBlocks;
    if (_layoutIndex != null &&
        _layoutSpacing == spacing &&
        blocks is PersistentBlockList &&
        previousBlocks != null &&
        blocks.length == previousBlocks.length) {
      final delta = blocks.deltaSince(previousBlocks);
      if (delta != null) {
        var sameStructure = true;
        for (final index in delta.changedIndexes) {
          if (blocks[index].id != previousBlocks[index].id) {
            sameStructure = false;
            break;
          }
        }
        if (sameStructure) {
          final spacingIndexes = <int>{};
          for (final index in delta.changedIndexes) {
            final measuredExtent = _extents[blocks[index].id];
            if (measuredExtent != null) {
              _layoutIndex!.updateExtent(index, measuredExtent);
            }
            spacingIndexes
              ..add(index)
              ..add(index - 1);
          }
          for (final index in spacingIndexes) {
            if (index < 0 || index >= blocks.length) {
              continue;
            }
            final trailingSpacing = index < blocks.length - 1
                ? _spacingBetweenBlocks(
                    blocks[index],
                    blocks[index + 1],
                    spacing,
                  )
                : 0.0;
            _layoutIndex!.updateTrailingSpacing(index, trailingSpacing);
          }
          _layoutBlocks = blocks;
          return;
        }
      }
    }

    final extents = <double>[];
    final measured = <bool>[];
    final spacings = <double>[];
    final indexesById = <String, int>{};
    for (var index = 0; index < blocks.length; index++) {
      final measuredExtent = _extents[blocks[index].id];
      extents.add(measuredExtent ?? averageExtent);
      measured.add(measuredExtent != null);
      spacings.add(
        index < blocks.length - 1
            ? _spacingBetweenBlocks(
                blocks[index],
                blocks[index + 1],
                spacing,
              )
            : 0.0,
      );
      indexesById[blocks[index].id] = index;
    }
    _layoutIndex = BlockLayoutIndex(
      extents: extents,
      trailingSpacings: spacings,
      measured: measured,
      estimatedExtent: averageExtent,
    );
    _layoutIndexesById = Map<String, int>.unmodifiable(indexesById);
    _layoutBlocks = blocks;
    _layoutSpacing = spacing;
  }

  void _invalidateLayout() {
    _layoutBlocks = null;
    _layoutIndex = null;
    _layoutIndexesById = const <String, int>{};
    _layoutSpacing = null;
  }

  void _syncMeasureSignature(BlockNode block) {
    final signature = _measureSignatureFor(block);
    final previous = _measureSignatures[block.id];
    if (signature == null) {
      if (_measureSignatures.remove(block.id) != null) {
        _blockVersions[block.id] = (_blockVersions[block.id] ?? 0) + 1;
      }
      return;
    }
    if (previous == signature) {
      return;
    }
    _measureSignatures[block.id] = signature;
    _blockVersions[block.id] = (_blockVersions[block.id] ?? 0) + 1;
  }

  Object? _measureSignatureFor(BlockNode block) {
    if (block is! ImageBlockNode) {
      return null;
    }
    final displaySize = _ImageDisplayMetrics.resolve(block).displaySize;
    return Object.hash(
      block.width,
      block.height,
      _dimensionSignature(block.showWidth),
      _dimensionSignature(block.showHeight),
      _dimensionSignature(displaySize?.width),
      _dimensionSignature(displaySize?.height),
      block.caption,
    );
  }
}

class _ExtentRecordResult {
  const _ExtentRecordResult({
    required this.previousBlockTop,
    required this.extentDelta,
  });

  final double? previousBlockTop;
  final double extentDelta;
}

class _BlockMoveRange {
  const _BlockMoveRange({
    required this.startBlockIndex,
    required this.endBlockIndexExclusive,
  });

  factory _BlockMoveRange.single(int blockIndex) {
    return _BlockMoveRange(
      startBlockIndex: blockIndex,
      endBlockIndexExclusive: blockIndex + 1,
    );
  }

  final int startBlockIndex;
  final int endBlockIndexExclusive;

  int get length {
    final count = endBlockIndexExclusive - startBlockIndex;
    return count <= 0 ? 0 : count;
  }

  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  bool containsInsertionBoundary(int insertionIndex) {
    return insertionIndex >= startBlockIndex &&
        insertionIndex <= endBlockIndexExclusive;
  }

  bool canMoveUp(int blockCount) {
    return !isEmpty && blockCount > length && startBlockIndex > 0;
  }

  bool canMoveDown(int blockCount) {
    return !isEmpty &&
        blockCount > length &&
        endBlockIndexExclusive < blockCount;
  }

  int? insertionBoundaryForMoveUp(int blockCount) {
    return canMoveUp(blockCount) ? startBlockIndex - 1 : null;
  }

  int? insertionBoundaryForMoveDown(int blockCount) {
    return canMoveDown(blockCount) ? endBlockIndexExclusive + 1 : null;
  }

  int? insertionBoundaryForFinalStartIndex(
    int finalStartIndex,
    int blockCount,
  ) {
    if (finalStartIndex < 0 ||
        finalStartIndex >= blockCount ||
        finalStartIndex == startBlockIndex) {
      return null;
    }
    final insertionIndex = finalStartIndex < startBlockIndex
        ? finalStartIndex
        : finalStartIndex + length;
    if (insertionIndex < 0 ||
        insertionIndex > blockCount ||
        containsInsertionBoundary(insertionIndex)) {
      return null;
    }
    return insertionIndex;
  }

  int finalStartIndexForInsertionBoundary(int insertionIndex) {
    return insertionIndex < startBlockIndex
        ? insertionIndex
        : insertionIndex - length;
  }

  @override
  bool operator ==(Object other) {
    return other is _BlockMoveRange &&
        other.startBlockIndex == startBlockIndex &&
        other.endBlockIndexExclusive == endBlockIndexExclusive;
  }

  @override
  int get hashCode => Object.hash(startBlockIndex, endBlockIndexExclusive);
}

class _BlockReorderDropRequest {
  const _BlockReorderDropRequest({required this.insertionIndex});

  final int insertionIndex;
}

typedef _BlockReorderDropTargetResolver = _ResolvedBlockReorderDropTarget
    Function(BlockReorderDropTarget target);

class _ResolvedBlockReorderDropTarget {
  const _ResolvedBlockReorderDropTarget({
    required this.indicatorTarget,
    required this.insertionIndex,
  });

  final BlockReorderDropTarget indicatorTarget;
  final int insertionIndex;
}

class _SlashMenuAnchor {
  const _SlashMenuAnchor({
    required this.offset,
    this.opensAbove = false,
    this.availableHeight,
  });

  final Offset offset;
  final bool opensAbove;
  final double? availableHeight;
}

class _BlockLayoutMetrics {
  const _BlockLayoutMetrics({
    required this.blocks,
    required this.index,
    required this.indexesById,
  });

  final List<BlockNode> blocks;
  final BlockLayoutIndex index;
  final Map<String, int> indexesById;

  double get totalExtent => index.totalExtent;

  double topFor(int blockIndex) => index.topFor(blockIndex);

  int? indexForBlockId(String blockId) => indexesById[blockId];

  List<int> visibleIndices(double visibleTop, double visibleBottom) {
    final range = index.visibleRange(visibleTop, visibleBottom);
    if (range.isEmpty) {
      return const <int>[];
    }
    return <int>[
      for (var i = range.start; i < range.endExclusive; i++) i,
    ];
  }
}

class _MeasuredVirtualBlockList extends StatefulWidget {
  const _MeasuredVirtualBlockList({
    required this.controller,
    required this.blocks,
    required this.blockIndexes,
    required this.blockSpacing,
    required this.extentCache,
    required this.keepAliveIds,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.onExtentUpdated,
    this.shouldSuppressExtentUpdate,
  });

  final ScrollController controller;
  final List<BlockNode> blocks;
  final List<int> blockIndexes;
  final double blockSpacing;
  final _BlockExtentCache extentCache;
  final Set<String> keepAliveIds;

  /// Builds one top-level `Document.blocks` row. Editor-owned row chrome, such
  /// as the block drag handle defined by [BlockDragHandleSpec], must wrap this
  /// builder at the row shell instead of living inside [BlockRendererBuilder]
  /// output. That keeps table-cell text, inline embeds, and object-block
  /// internal controls from being mistaken for sortable rows.
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  /// Invoked after a block's measured extent was actually updated in the cache
  /// (i.e. its height changed). The editor uses it to re-run caret-into-view
  /// logic that depends on accurate block heights, which only becomes available
  /// a frame after the content mutation (the mutation frame still carried the
  /// pre-edit height).
  final void Function()? onExtentUpdated;

  /// P003: When this returns `true`, [_handleExtentChanged] skips calling
  /// [onExtentUpdated] even though the extent cache was updated. The editor
  /// sets this to its user-scroll cooldown check so that block re-measurement
  /// during an active user scroll does not kick off caret-into-view logic.
  final bool Function()? shouldSuppressExtentUpdate;

  @override
  State<_MeasuredVirtualBlockList> createState() =>
      _MeasuredVirtualBlockListState();
}

class _MeasuredVirtualBlockListState extends State<_MeasuredVirtualBlockList> {
  double _resolvedPaddingTop = 0;
  double _pendingScrollAnchorDelta = 0;
  bool _scrollAnchorUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _MeasuredVirtualBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleExtentChanged(String blockId, int measureToken, double extent) {
    final update = widget.extentCache.record(blockId, measureToken, extent);
    if (update != null && mounted) {
      setState(() {});
      // P003: If the user is actively scrolling, suppress the extent-updated
      // callback to avoid triggering caret-into-view logic during a user
      // gesture. P002's cooldown check in _scrollCaretIntoViewIfNeeded handles
      // most cases; this gate is a defense-in-depth supplement that avoids
      // even scheduling the post-frame callback during user scroll.
      if (widget.shouldSuppressExtentUpdate?.call() == true) {
        return;
      }
      _preserveScrollAnchor(update);
      // A real height change may unlock a caret-into-view that the content
      // mutation frame could not perform (it ran with the pre-edit height).
      // Notify the editor so it can retry the scroll against the now-accurate
      // layout.
      widget.onExtentUpdated?.call();
    }
  }

  void _preserveScrollAnchor(_ExtentRecordResult update) {
    final blockTop = update.previousBlockTop;
    if (blockTop == null ||
        update.extentDelta.abs() <= 0.5 ||
        !widget.controller.hasClients ||
        blockTop + _resolvedPaddingTop >= widget.controller.offset) {
      return;
    }
    _pendingScrollAnchorDelta += update.extentDelta;
    if (_scrollAnchorUpdateScheduled) {
      return;
    }
    _scrollAnchorUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollAnchorUpdateScheduled = false;
      final delta = _pendingScrollAnchorDelta;
      _pendingScrollAnchorDelta = 0;
      if (!mounted ||
          delta.abs() <= 0.5 ||
          !widget.controller.hasClients ||
          widget.shouldSuppressExtentUpdate?.call() == true) {
        return;
      }
      final position = widget.controller.position;
      final target = (widget.controller.offset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((target - widget.controller.offset).abs() > 0.5) {
        widget.controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding.resolve(Directionality.of(context));
    _resolvedPaddingTop = padding.top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - padding.horizontal)
                .clamp(0.0, double.infinity)
                .toDouble()
            : null;
        widget.extentCache.updateContentWidth(contentWidth);
        final metrics = widget.extentCache.layoutFor(
          widget.blocks,
          widget.blockSpacing,
        );
        final viewportHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final scrollOffset =
            widget.controller.hasClients ? widget.controller.offset : 0.0;
        final contentTop = (scrollOffset - padding.top - _kVirtualListOverscan)
            .clamp(0.0, double.infinity)
            .toDouble();
        final contentBottom =
            scrollOffset - padding.top + viewportHeight + _kVirtualListOverscan;
        final visible = metrics.visibleIndices(contentTop, contentBottom);
        final indices = <int>{...visible};
        for (final blockId in widget.keepAliveIds) {
          final index = metrics.indexForBlockId(blockId);
          if (index != null) {
            indices.add(index);
          }
        }
        final sortedIndices = indices.toList()..sort();
        final height = padding.vertical + metrics.totalExtent;
        return SingleChildScrollView(
          controller: widget.controller,
          physics: widget.physics,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final index in sortedIndices)
                  Positioned(
                    key: ValueKey<String>(
                      'wenz-richtext-positioned-${widget.blocks[index].id}',
                    ),
                    top: padding.top + metrics.topFor(index),
                    left: padding.left,
                    right: padding.right,
                    child: _MeasuredBlockExtent(
                      key: ValueKey<String>(
                        'wenz-richtext-measure-${widget.blocks[index].id}',
                      ),
                      blockId: widget.blocks[index].id,
                      measureToken: widget.extentCache.tokenFor(
                        widget.blocks[index].id,
                      ),
                      onChanged: _handleExtentChanged,
                      child: widget.itemBuilder(
                        context,
                        widget.blockIndexes[index],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeasuredBlockExtent extends SingleChildRenderObjectWidget {
  const _MeasuredBlockExtent({
    super.key,
    required this.blockId,
    required this.measureToken,
    required this.onChanged,
    required super.child,
  });

  final String blockId;
  final int measureToken;
  final void Function(String blockId, int measureToken, double extent)
      onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredBlockExtent(
      blockId: blockId,
      measureToken: measureToken,
      onChanged: onChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasuredBlockExtent renderObject,
  ) {
    renderObject
      ..blockId = blockId
      ..measureToken = measureToken
      ..onChanged = onChanged;
  }
}

class _RenderMeasuredBlockExtent extends RenderProxyBox {
  _RenderMeasuredBlockExtent({
    required String blockId,
    required int measureToken,
    required void Function(String blockId, int measureToken, double extent)
        onChanged,
  })  : _blockId = blockId,
        _measureToken = measureToken,
        _onChanged = onChanged;

  String _blockId;
  int _measureToken;
  void Function(String blockId, int measureToken, double extent) _onChanged;
  double? _lastReportedExtent;

  set blockId(String value) {
    if (_blockId == value) {
      return;
    }
    _blockId = value;
    _lastReportedExtent = null;
  }

  set measureToken(int value) {
    if (_measureToken == value) {
      return;
    }
    _measureToken = value;
    _lastReportedExtent = null;
  }

  set onChanged(
    void Function(String blockId, int measureToken, double extent) value,
  ) {
    _onChanged = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    final extent = size.height;
    final previous = _lastReportedExtent;
    if (previous != null && (previous - extent).abs() <= 0.5) {
      return;
    }
    _lastReportedExtent = extent;
    final reportedBlockId = _blockId;
    final reportedToken = _measureToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) {
        _onChanged(reportedBlockId, reportedToken, extent);
      }
    });
  }
}

/// Wraps a [_BlockRenderer] so that the underlying block widget (and its
/// [_TextSelectionSurface] children, geometry registration, and text-layout
/// cache) stay mounted even when scrolled out of the viewport — but only when
/// [keepAlive] is true. Used to keep the caret block and selection endpoints
/// alive under editor virtualisation, so the caret and selection
/// highlight always paint and the geometry registry always knows their box.
///
/// Also drives incremental rebuild: a block is only re-rendered when its
/// content changed ([blockChanged]) *or* when the selection / caret / IME
/// composition touches it. A pure caret move inside a different block leaves
/// this block's cached child intact, avoiding the inline-span rebuild that
/// would otherwise run for every block on every keystroke.
class _KeepAliveBlock extends StatefulWidget {
  const _KeepAliveBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.blockCount,
    required this.blockMoveRange,
    this.listMarker,
    this.quoteGroupPosition = QuoteGroupPosition.standalone,
    required this.keepAlive,
    required this.blockChanged,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.blockRenderers,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.canEdit = true,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.onMentionTap,
    this.reserveHeadingCollapseRail = false,
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.resolveBlockReorderDropTarget,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.tableToolbarOverlayController,
    this.objectBlockToolbarOverlayController,
    this.onTableColumnResize,
    this.onImageBlockResize,
    this.onTodoCheckedChanged,
    this.onObjectBlockAction,
    this.onRowBlockFormatChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final int blockCount;
  final _BlockMoveRange blockMoveRange;
  final String? listMarker;
  final QuoteGroupPosition quoteGroupPosition;
  final bool keepAlive;
  final bool blockChanged;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final BlockRendererRegistry blockRenderers;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final bool canEdit;
  final MediaResolver? mediaResolver;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final WenzMentionTapCallback? onMentionTap;
  final bool reserveHeadingCollapseRail;
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final _BlockReorderDropTargetResolver? resolveBlockReorderDropTarget;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableFloatingToolbarOverlayController? tableToolbarOverlayController;
  final ObjectBlockToolbarOverlayController?
      objectBlockToolbarOverlayController;
  final TableColumnResizeHandler? onTableColumnResize;
  final ImageBlockResizeHandler? onImageBlockResize;
  final TodoCheckedChangeHandler? onTodoCheckedChanged;
  final ObjectBlockActionHandler? onObjectBlockAction;
  final _RowBlockFormatChangeHandler? onRowBlockFormatChanged;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  State<_KeepAliveBlock> createState() => _KeepAliveBlockState();
}

class _KeepAliveBlockState extends State<_KeepAliveBlock>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  /// Cached child from the last build that actually rendered. Reused when the
  /// block's content and selection-relevance are unchanged.
  Widget? _cachedChild;

  @override
  void didUpdateWidget(covariant _KeepAliveBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
    // Invalidate the cache when something this block renders depends on
    // changed. Content change, selection/caret/composition touching this block,
    // or ambient style/debug toggles all force a fresh render.
    //
    // Selection requires care: a block that stays selected while the selection
    // extent moves within it (e.g. dragging to resize a range) does not flip
    // the boolean "touches" flag, but the rendered highlight/caret offset DID
    // change. So when this block is touched by the selection, a different
    // selection object must also invalidate the cache.
    final selectionTouchedChanged =
        _selectionTouchesBlock(oldWidget) != _selectionTouchesBlock(widget);
    final selectionShiftedWhileTouched = _selectionTouchesBlock(widget) &&
        oldWidget.selection != widget.selection;
    if (widget.blockChanged ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.blockCount != widget.blockCount ||
        oldWidget.blockMoveRange != widget.blockMoveRange ||
        selectionTouchedChanged ||
        selectionShiftedWhileTouched ||
        oldWidget.showCaret != widget.showCaret ||
        oldWidget.showDebugOverlay != widget.showDebugOverlay ||
        oldWidget.listMarker != widget.listMarker ||
        oldWidget.quoteGroupPosition != widget.quoteGroupPosition ||
        oldWidget.canEdit != widget.canEdit ||
        oldWidget.textStyle != widget.textStyle ||
        !identical(oldWidget.mediaResolver, widget.mediaResolver) ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
        oldWidget.onMentionTap != widget.onMentionTap ||
        oldWidget.reserveHeadingCollapseRail !=
            widget.reserveHeadingCollapseRail ||
        oldWidget.headingCollapseState != widget.headingCollapseState ||
        oldWidget.onHeadingCollapseToggled != widget.onHeadingCollapseToggled ||
        oldWidget.resolveBlockReorderDropTarget !=
            widget.resolveBlockReorderDropTarget ||
        oldWidget.onCodeLanguageChanged != widget.onCodeLanguageChanged ||
        oldWidget.onCodeCopied != widget.onCodeCopied ||
        oldWidget.onCalloutVariantChanged != widget.onCalloutVariantChanged ||
        oldWidget.onTableToolbarAction != widget.onTableToolbarAction ||
        oldWidget.tableToolbarOverlayController !=
            widget.tableToolbarOverlayController ||
        oldWidget.objectBlockToolbarOverlayController !=
            widget.objectBlockToolbarOverlayController ||
        oldWidget.onTableColumnResize != widget.onTableColumnResize ||
        oldWidget.onImageBlockResize != widget.onImageBlockResize ||
        oldWidget.onTodoCheckedChanged != widget.onTodoCheckedChanged ||
        oldWidget.onObjectBlockAction != widget.onObjectBlockAction ||
        oldWidget.onRowBlockFormatChanged != widget.onRowBlockFormatChanged ||
        oldWidget.findMatches != widget.findMatches ||
        oldWidget.currentFindMatch != widget.currentFindMatch ||
        _compositionTouchesBlock(oldWidget) !=
            _compositionTouchesBlock(widget) ||
        oldWidget.blockRenderers != widget.blockRenderers) {
      _cachedChild = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cached = _cachedChild;
    if (cached != null) {
      return cached;
    }
    final child = _BlockRenderer(
      block: widget.block,
      blockIndex: widget.blockIndex,
      blockCount: widget.blockCount,
      blockMoveRange: widget.blockMoveRange,
      listMarker: widget.listMarker,
      quoteGroupPosition: widget.quoteGroupPosition,
      selection: widget.selection,
      compositionState: widget.compositionState,
      registry: widget.registry,
      blockRenderers: widget.blockRenderers,
      showCaret: widget.showCaret,
      textStyle: widget.textStyle,
      showDebugOverlay: widget.showDebugOverlay,
      canEdit: widget.canEdit,
      mediaResolver: widget.mediaResolver,
      inlineEmbedRenderer: widget.inlineEmbedRenderer,
      reserveHeadingCollapseRail: widget.reserveHeadingCollapseRail,
      headingCollapseState: widget.headingCollapseState,
      onHeadingCollapseToggled: widget.onHeadingCollapseToggled,
      resolveBlockReorderDropTarget: widget.resolveBlockReorderDropTarget,
      onCodeLanguageChanged: widget.onCodeLanguageChanged,
      onCodeCopied: widget.onCodeCopied,
      onCalloutVariantChanged: widget.onCalloutVariantChanged,
      onTableToolbarAction: widget.onTableToolbarAction,
      tableToolbarOverlayController: widget.tableToolbarOverlayController,
      objectBlockToolbarOverlayController:
          widget.objectBlockToolbarOverlayController,
      onTableColumnResize: widget.onTableColumnResize,
      onImageBlockResize: widget.onImageBlockResize,
      onTodoCheckedChanged: widget.onTodoCheckedChanged,
      onObjectBlockAction: widget.onObjectBlockAction,
      onRowBlockFormatChanged: widget.onRowBlockFormatChanged,
      findMatches: widget.findMatches,
      currentFindMatch: widget.currentFindMatch,
    );
    _cachedChild = child;
    return child;
  }

  /// Whether the current selection could affect this block's rendering: it is
  /// an endpoint, or it lies strictly between the selection's start and end
  /// (so it would be fully highlighted), or the selection is collapsed inside
  /// it (the caret).
  bool _selectionTouchesBlock(_KeepAliveBlock w) {
    return _selectionTouchesBlockIndex(w.selection, w.blockIndex);
  }

  /// Whether an active IME composition affects this block (composition lives in
  /// the caret's block). Only that block needs to repaint the underline span.
  bool _compositionTouchesBlock(_KeepAliveBlock w) {
    final composition = w.compositionState;
    if (composition == null) {
      return false;
    }
    final selection = w.selection;
    return selection != null && selection.extent.blockIndex == w.blockIndex;
  }
}

class _BlockRenderer extends StatelessWidget {
  const _BlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.blockCount,
    required this.blockMoveRange,
    this.listMarker,
    this.quoteGroupPosition = QuoteGroupPosition.standalone,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.blockRenderers,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.canEdit = true,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.reserveHeadingCollapseRail = false,
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.resolveBlockReorderDropTarget,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.tableToolbarOverlayController,
    this.objectBlockToolbarOverlayController,
    this.onTableColumnResize,
    this.onImageBlockResize,
    this.onTodoCheckedChanged,
    this.onObjectBlockAction,
    this.onRowBlockFormatChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final int blockCount;
  final _BlockMoveRange blockMoveRange;
  final String? listMarker;
  final QuoteGroupPosition quoteGroupPosition;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final BlockRendererRegistry blockRenderers;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final bool canEdit;
  final MediaResolver? mediaResolver;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final bool reserveHeadingCollapseRail;
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final _BlockReorderDropTargetResolver? resolveBlockReorderDropTarget;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableFloatingToolbarOverlayController? tableToolbarOverlayController;
  final ObjectBlockToolbarOverlayController?
      objectBlockToolbarOverlayController;
  final TableColumnResizeHandler? onTableColumnResize;
  final ImageBlockResizeHandler? onImageBlockResize;
  final TodoCheckedChangeHandler? onTodoCheckedChanged;
  final ObjectBlockActionHandler? onObjectBlockAction;
  final _RowBlockFormatChangeHandler? onRowBlockFormatChanged;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final renderContext = BlockRenderContext(
      block: block,
      blockIndex: blockIndex,
      blockCount: blockCount,
      listMarker: listMarker,
      quoteGroupPosition: quoteGroupPosition,
      selection: selection,
      compositionState: compositionState,
      registry: registry,
      showCaret: showCaret,
      textStyle: textStyle,
      showDebugOverlay: showDebugOverlay,
      canEdit: canEdit,
      mediaResolver: mediaResolver,
      inlineEmbedRenderer: inlineEmbedRenderer,
      headingCollapseState: headingCollapseState,
      onHeadingCollapseToggled: onHeadingCollapseToggled,
      onCodeLanguageChanged: onCodeLanguageChanged,
      onCodeCopied: onCodeCopied,
      onCalloutVariantChanged: onCalloutVariantChanged,
      onTableToolbarAction: onTableToolbarAction,
      tableToolbarOverlayController: tableToolbarOverlayController,
      objectBlockToolbarOverlayController: objectBlockToolbarOverlayController,
      onTableColumnResize: onTableColumnResize,
      onImageBlockResize: onImageBlockResize,
      onTodoCheckedChanged: onTodoCheckedChanged,
      onObjectBlockAction: onObjectBlockAction,
      findMatches: _matchesForBlock(findMatches, blockIndex),
      currentFindMatch:
          currentFindMatch?.blockIndex == blockIndex ? currentFindMatch : null,
    );
    final builder = blockRenderers.resolveForBlock(
      block,
      fallback: _defaultBlockFallback,
    );
    final leadingIndent = _indentStartFor(block);
    final chromeLineExtent = _rowChromeLineExtentFor(
      context,
      block,
      textStyle,
    );
    final chromeTopOffset = _rowChromeTopOffsetFor(block);
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: leadingIndent,
      ),
      child: builder(context, renderContext),
    );
    return _BlockDragHandleOverlay(
      blockId: block.id,
      blockPlainText: block.plainText,
      blockFormat: _rowBlockFormatFor(block),
      canChangeBlockFormat: _canChangeRowBlockFormat(block),
      canDuplicateBlock: block is! ImageBlockNode,
      blockIndex: blockIndex,
      blockCount: blockCount,
      blockMoveRange: blockMoveRange,
      chromeLineExtent: chromeLineExtent,
      chromeTopOffset: chromeTopOffset,
      reserveHeadingCollapseRail: reserveHeadingCollapseRail,
      headingCollapseState: headingCollapseState,
      onHeadingCollapseToggled: onHeadingCollapseToggled,
      resolveBlockReorderDropTarget: resolveBlockReorderDropTarget,
      canEdit: canEdit,
      registry: registry,
      onAction: onObjectBlockAction,
      onFormatChanged: onRowBlockFormatChanged,
      child: content,
    );
  }
}

class _BlockDragHandleOverlay extends StatefulWidget {
  const _BlockDragHandleOverlay({
    required this.blockId,
    required this.blockPlainText,
    required this.blockFormat,
    required this.canChangeBlockFormat,
    required this.canDuplicateBlock,
    required this.blockIndex,
    required this.blockCount,
    required this.blockMoveRange,
    required this.chromeLineExtent,
    required this.chromeTopOffset,
    required this.reserveHeadingCollapseRail,
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.resolveBlockReorderDropTarget,
    required this.canEdit,
    required this.registry,
    required this.child,
    this.onAction,
    this.onFormatChanged,
  });

  final String blockId;
  final String blockPlainText;
  final _RowBlockFormat? blockFormat;
  final bool canChangeBlockFormat;
  final bool canDuplicateBlock;
  final int blockIndex;
  final int blockCount;
  final _BlockMoveRange blockMoveRange;
  final double chromeLineExtent;
  final double chromeTopOffset;
  final bool reserveHeadingCollapseRail;
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final _BlockReorderDropTargetResolver? resolveBlockReorderDropTarget;
  final bool canEdit;
  final BlockGeometryRegistry registry;
  final Widget child;
  final ObjectBlockActionHandler? onAction;
  final _RowBlockFormatChangeHandler? onFormatChanged;

  @override
  State<_BlockDragHandleOverlay> createState() =>
      _BlockDragHandleOverlayState();
}

class _BlockDragHandleOverlayState extends State<_BlockDragHandleOverlay> {
  final GlobalKey _blockRowKey = GlobalKey();
  bool _blockHovered = false;
  bool _contentDimmed = false;

  @override
  Widget build(BuildContext context) {
    final chromeTokens = EditorTokens.resolveBlockChrome(context);
    final showDragHandle = !chromeTokens.isMobile &&
        BlockDragHandleSpec.canShow(
          canEdit: widget.canEdit,
          blockIndex: widget.blockIndex,
          blockCount: widget.blockCount,
        );
    final headingCollapseState = widget.headingCollapseState;
    final showHeadingCollapse = headingCollapseState?.canCollapse ?? false;
    final reserveHeadingCollapseSlot = _shouldReserveHeadingCollapseSlot(
      tokens: chromeTokens,
      outlineChromeAttached: widget.reserveHeadingCollapseRail,
      showHeadingCollapse: showHeadingCollapse,
    );
    // Desktop keeps a shared outline rail for cross-row alignment. Compact
    // phones reserve the second slot only when this heading can collapse.
    if (!showDragHandle && !reserveHeadingCollapseSlot) {
      return widget.child;
    }
    final activeChromeWidth = _blockRowChromeWidth(
      showDragHandle: showDragHandle,
      reserveHeadingCollapseSlot: reserveHeadingCollapseSlot,
      tokens: chromeTokens,
    );
    final headingCollapseStart = _headingCollapseStartFor(
      showDragHandle: showDragHandle,
      tokens: chromeTokens,
    );
    final handleStart = _blockDragHandleStartFor(
      showDragHandle: showDragHandle,
      tokens: chromeTokens,
    );
    final handleTop = widget.chromeTopOffset +
        _rowChromeTopFor(
          lineExtent: widget.chromeLineExtent,
          controlHeight: BlockDragHandleSpec.hitSize.height,
        );
    final headingCollapseTop = widget.chromeTopOffset +
        _rowChromeTopFor(
          lineExtent: widget.chromeLineExtent,
          controlHeight: _kHeadingCollapseButtonSize,
        );
    final content = Padding(
      padding: EdgeInsetsDirectional.only(start: activeChromeWidth),
      child: widget.child,
    );
    return _BlockReorderRowGeometry(
      blockId: widget.blockId,
      blockIndex: widget.blockIndex,
      registry: widget.registry,
      blockRowKey: _blockRowKey,
      child: MouseRegion(
        onEnter: (_) => _setBlockHovered(true),
        onExit: (_) => _setBlockHovered(false),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              opacity: _contentDimmed ? _kContentDimmedOpacity : 1.0,
              child: content,
            ),
            if (showDragHandle)
              PositionedDirectional(
                start: handleStart,
                top: handleTop,
                child: _BlockDragHandleButton(
                  blockId: widget.blockId,
                  blockPlainText: widget.blockPlainText,
                  blockFormat: widget.blockFormat,
                  canChangeBlockFormat: widget.canChangeBlockFormat,
                  canDuplicateBlock: widget.canDuplicateBlock,
                  blockIndex: widget.blockIndex,
                  blockCount: widget.blockCount,
                  blockMoveRange: widget.blockMoveRange,
                  blockHovered: _blockHovered,
                  resolveDropTarget: widget.resolveBlockReorderDropTarget,
                  canEdit: widget.canEdit,
                  registry: widget.registry,
                  dragSnapshotKey: _blockRowKey,
                  onDragChanged: _handleDragChanged,
                  onAction: widget.onAction,
                  onFormatChanged: widget.onFormatChanged,
                ),
              ),
            if (showHeadingCollapse)
              PositionedDirectional(
                start: headingCollapseStart,
                top: headingCollapseTop,
                child: _HeadingCollapseButton(
                  blockId: widget.blockId,
                  state: headingCollapseState!,
                  registry: widget.registry,
                  onToggled: widget.onHeadingCollapseToggled,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setBlockHovered(bool value) {
    if (_blockHovered != value && mounted) {
      setState(() => _blockHovered = value);
    }
  }

  void _handleDragChanged(bool dragging) {
    if (!mounted || _contentDimmed == dragging) {
      return;
    }
    setState(() => _contentDimmed = dragging);
  }

  static double _headingCollapseStartFor({
    required bool showDragHandle,
    required EditorTokens tokens,
  }) {
    if (!showDragHandle) {
      return 0.0;
    }
    return tokens.blockChromeStartMargin +
        BlockDragHandleSpec.hitSize.width +
        tokens.blockChromeGap;
  }

  static double _blockDragHandleStartFor({
    required bool showDragHandle,
    required EditorTokens tokens,
  }) {
    if (!showDragHandle) {
      return 0.0;
    }
    return tokens.blockChromeStartMargin;
  }

  static const double _kContentDimmedOpacity = 0.3;
}

class _BlockReorderRowGeometry extends StatefulWidget {
  const _BlockReorderRowGeometry({
    required this.blockId,
    required this.blockIndex,
    required this.registry,
    required this.blockRowKey,
    required this.child,
  });

  final String blockId;
  final int blockIndex;
  final BlockGeometryRegistry registry;
  final GlobalKey blockRowKey;
  final Widget child;

  @override
  State<_BlockReorderRowGeometry> createState() =>
      _BlockReorderRowGeometryState();
}

class _BlockReorderRowGeometryState extends State<_BlockReorderRowGeometry> {
  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _BlockReorderRowGeometry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId) {
      oldWidget.registry
          .unregisterBlockRow(oldWidget.blockId, widget.blockRowKey);
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex) {
      _register();
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterBlockRow(widget.blockId, widget.blockRowKey);
    super.dispose();
  }

  void _register() {
    widget.registry.registerBlockRow(
      BlockRowGeometryEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        key: widget.blockRowKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.blockRowKey,
      child: widget.child,
    );
  }
}

class _BlockDragHandleButton extends StatefulWidget {
  const _BlockDragHandleButton({
    required this.blockId,
    required this.blockPlainText,
    required this.blockFormat,
    required this.canChangeBlockFormat,
    required this.canDuplicateBlock,
    required this.blockIndex,
    required this.blockCount,
    required this.blockMoveRange,
    required this.blockHovered,
    this.resolveDropTarget,
    required this.canEdit,
    required this.registry,
    this.dragSnapshotKey,
    this.onDragChanged,
    this.onAction,
    this.onFormatChanged,
  });

  final String blockId;
  final String blockPlainText;
  final _RowBlockFormat? blockFormat;
  final bool canChangeBlockFormat;
  final bool canDuplicateBlock;
  final int blockIndex;
  final int blockCount;
  final _BlockMoveRange blockMoveRange;
  final bool blockHovered;
  final _BlockReorderDropTargetResolver? resolveDropTarget;
  final bool canEdit;
  final BlockGeometryRegistry registry;
  final GlobalKey? dragSnapshotKey;
  final ValueChanged<bool>? onDragChanged;
  final ObjectBlockActionHandler? onAction;
  final _RowBlockFormatChangeHandler? onFormatChanged;

  @override
  State<_BlockDragHandleButton> createState() => _BlockDragHandleButtonState();
}

class _BlockDragHandleButtonState extends State<_BlockDragHandleButton> {
  final GlobalKey _hitTestKey = GlobalKey();
  bool _hovered = false;
  bool _focused = false;
  bool _menuOpen = false;
  bool _dragging = false;
  int? _activePointer;
  Offset? _pressOrigin;
  bool _suppressMenuForPointer = false;
  OverlayEntry? _dropIndicatorEntry;
  _ResolvedBlockReorderDropTarget? _dropTarget;

  // Drag-preview snapshot fields
  ui.Image? _dragSnapshot;
  OverlayEntry? _dragPreviewEntry;
  Offset _dragPointerPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_hitTestKey);
  }

  @override
  void didUpdateWidget(covariant _BlockDragHandleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_hitTestKey);
      widget.registry.registerSelectionExclusion(_hitTestKey);
    }
    if (!_enabled ||
        oldWidget.blockMoveRange != widget.blockMoveRange ||
        oldWidget.blockCount != widget.blockCount) {
      _resetPointerGesture();
    }
  }

  @override
  void dispose() {
    _removeDropIndicator();
    _removeDragPreview();
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final hovered = _hovered || widget.blockHovered;
    final opacity = !enabled
        ? BlockDragHandleSpec.disabledOpacity
        : _menuOpen || _focused || _dragging
            ? BlockDragHandleSpec.activeOpacity
            : hovered
                ? BlockDragHandleSpec.hoverOpacity
                : BlockDragHandleSpec.idleOpacity;
    final theme = Theme.of(context);
    final active = _menuOpen || _focused || _dragging;
    final backgroundColor = active
        ? _minimalMenuSelectedColor(theme)
        : _hovered
            ? _minimalMenuHoverColor(theme)
            : Colors.transparent;
    return KeyedSubtree(
      key:
          ValueKey<String>('wenz-richtext-block-drag-handle-${widget.blockId}'),
      child: MouseRegion(
        cursor: enabled
            ? _dragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab
            : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Focus(
          canRequestFocus: enabled,
          onFocusChange: _setFocused,
          onKeyEvent: _handleKeyEvent,
          child: Semantics(
            button: true,
            enabled: enabled,
            label: '块操作',
            onTap: enabled ? () => unawaited(_showMenu()) : null,
            child: Tooltip(
              message: '块操作',
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                child: SizedBox(
                  key: _hitTestKey,
                  width: BlockDragHandleSpec.hitSize.width,
                  height: BlockDragHandleSpec.hitSize.height,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    opacity: opacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.drag_indicator,
                          size: BlockDragHandleSpec.visualSize.width,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _enabled =>
      widget.canEdit &&
      (widget.onAction != null || widget.onFormatChanged != null);

  bool get _canDragSort =>
      widget.onAction != null &&
      BlockDragHandleSpec.canDragSort(
        canEdit: widget.canEdit,
        blockIndex: widget.blockIndex,
        blockCount: widget.blockCount,
      ) &&
      widget.blockMoveRange.isNotEmpty &&
      widget.blockMoveRange.length < widget.blockCount;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      unawaited(_showMenu());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled || !_isPrimaryPointer(event)) {
      _resetPointerGesture();
      return;
    }
    _activePointer = event.pointer;
    _pressOrigin = event.position;
    _suppressMenuForPointer = false;
    if (_dragging) {
      _setDragging(false);
      _removeDropIndicator();
      _removeDragPreview();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _pressOrigin;
    if (_activePointer != event.pointer || origin == null) {
      return;
    }
    if ((event.position - origin).distance <
        BlockDragHandleSpec.dragStartSlop) {
      return;
    }
    _suppressMenuForPointer = true;
    if (!_canDragSort) {
      return;
    }
    if (!_dragging) {
      _setDragging(true);
      _captureDragSnapshot();
    }
    if (_dragging) {
      _dragPointerPosition = event.position;
      _dragPreviewEntry?.markNeedsBuild();
    }
    _updateDropTarget(event.position);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    final shouldSubmitDrop = _dragging;
    final dropTarget = _dropTarget;
    final shouldOpenMenu = _enabled && !_dragging && !_suppressMenuForPointer;
    _resetPointerGesture();
    if (shouldSubmitDrop) {
      _submitBlockReorder(dropTarget);
      return;
    }
    if (shouldOpenMenu) {
      unawaited(_showMenu());
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer == event.pointer) {
      _resetPointerGesture();
    }
  }

  bool _isPrimaryPointer(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      return event.buttons == kPrimaryMouseButton;
    }
    return event.buttons == 0 ||
        (event.buttons & kPrimaryMouseButton) == kPrimaryMouseButton;
  }

  /// Captures a snapshot of the block row's [RenderRepaintBoundary] as a
  /// [ui.Image] for the drag-preview overlay.  Silently degrades when the
  /// snapshot key is unavailable, the render object isn't a repaint boundary,
  /// or the captured image has zero size — the core drag-sort flow is never
  /// interrupted.
  Future<void> _captureDragSnapshot() async {
    final key = widget.dragSnapshotKey;
    if (key == null) {
      return;
    }
    final currentContext = key.currentContext;
    if (currentContext == null) {
      return;
    }
    final renderObject = currentContext.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return;
    }
    try {
      final image = await renderObject.toImage(
        pixelRatio: _kDragPreviewDevicePixelRatio,
      );
      if (image.width == 0 || image.height == 0) {
        image.dispose();
        return;
      }
      if (!mounted || !_dragging) {
        image.dispose();
        return;
      }
      _dragSnapshot = image;
      _insertDragPreview();
    } catch (_) {
      // Silently degrade — snapshot failure should not break drag sorting.
    }
  }

  void _insertDragPreview() {
    if (_dragPreviewEntry != null) {
      return;
    }
    final overlay = Overlay.of(context);
    _dragPreviewEntry = OverlayEntry(
      builder: _buildDragPreview,
    );
    overlay.insert(_dragPreviewEntry!);
  }

  Widget _buildDragPreview(BuildContext overlayContext) {
    final image = _dragSnapshot;
    if (image == null) {
      return const SizedBox.shrink();
    }
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) {
      return const SizedBox.shrink();
    }
    final localPos = overlayBox.globalToLocal(_dragPointerPosition);
    final imageWidth = image.width.toDouble() / _kDragPreviewDevicePixelRatio;
    final imageHeight = image.height.toDouble() / _kDragPreviewDevicePixelRatio;
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxPreviewHeight = viewportHeight * _kDragPreviewMaxHeightRatio;
    final previewHeight = imageHeight.clamp(0.0, maxPreviewHeight);
    final previewWidth = previewHeight < imageHeight
        ? (imageWidth * (previewHeight / imageHeight)).clamp(0.0, imageWidth)
        : imageWidth;
    return Positioned(
      left: localPos.dx + _kDragPreviewOffsetDx,
      top: localPos.dy + _kDragPreviewOffsetDy,
      width: previewWidth,
      height: previewHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _kDragPreviewOpacity),
            borderRadius: BorderRadius.circular(_kDragPreviewBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kDragPreviewBorderRadius),
            clipBehavior: Clip.antiAlias,
            child: Opacity(
              opacity: _kDragPreviewOpacity,
              child: RawImage(
                image: image,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _kDragPreviewDevicePixelRatio = 1.0;
  static const double _kDragPreviewOpacity = 0.85;
  static const double _kDragPreviewOffsetDx = -16.0;
  static const double _kDragPreviewOffsetDy = -12.0;
  static const double _kDragPreviewBorderRadius = 8.0;
  static const double _kDragPreviewMaxHeightRatio = 0.4;

  void _resetPointerGesture() {
    final wasDragging = _dragging;
    _activePointer = null;
    _pressOrigin = null;
    _suppressMenuForPointer = false;
    _dropTarget = null;
    _removeDropIndicator();
    _removeDragPreview();
    if (wasDragging) {
      _setDragging(false);
    }
  }

  void _setDragging(bool dragging) {
    if (_dragging == dragging) {
      return;
    }
    if (mounted) {
      setState(() => _dragging = dragging);
    } else {
      _dragging = dragging;
    }
    widget.onDragChanged?.call(dragging);
  }

  void _updateDropTarget(Offset globalPosition) {
    final rawTarget = widget.registry.blockReorderDropTargetFromGlobalOffset(
      globalPosition,
    );
    final next = _validDropTarget(rawTarget);
    if (_sameDropTarget(_dropTarget, next)) {
      return;
    }
    _dropTarget = next;
    _syncDropIndicator();
  }

  _ResolvedBlockReorderDropTarget? _validDropTarget(
    BlockReorderDropTarget? target,
  ) {
    if (target == null) {
      return null;
    }
    final resolved = widget.resolveDropTarget?.call(target) ??
        _ResolvedBlockReorderDropTarget(
          indicatorTarget: target,
          insertionIndex: target.insertionIndex,
        );
    final insertionIndex =
        resolved.insertionIndex.clamp(0, widget.blockCount).toInt();
    if (widget.blockMoveRange.containsInsertionBoundary(insertionIndex)) {
      return null;
    }
    return _ResolvedBlockReorderDropTarget(
      indicatorTarget: resolved.indicatorTarget,
      insertionIndex: insertionIndex,
    );
  }

  bool _sameDropTarget(
    _ResolvedBlockReorderDropTarget? a,
    _ResolvedBlockReorderDropTarget? b,
  ) {
    return a?.insertionIndex == b?.insertionIndex &&
        a?.indicatorTarget.blockId == b?.indicatorTarget.blockId &&
        a?.indicatorTarget.blockIndex == b?.indicatorTarget.blockIndex &&
        a?.indicatorTarget.placement == b?.indicatorTarget.placement &&
        a?.indicatorTarget.blockRect == b?.indicatorTarget.blockRect;
  }

  void _syncDropIndicator() {
    if (_dropTarget == null || !_dragging || !mounted) {
      _removeDropIndicator();
      return;
    }
    final entry = _dropIndicatorEntry;
    if (entry == null) {
      final overlay = Overlay.of(context);
      _dropIndicatorEntry = OverlayEntry(
        builder: _buildDropIndicator,
      );
      overlay.insert(_dropIndicatorEntry!);
      return;
    }
    entry.markNeedsBuild();
  }

  Widget _buildDropIndicator(BuildContext overlayContext) {
    final target = _dropTarget?.indicatorTarget;
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (target == null || overlayBox is! RenderBox || !overlayBox.hasSize) {
      return const SizedBox.shrink();
    }
    final lineCenterY = target.placement == BlockReorderDropPlacement.before
        ? target.blockRect.top
        : target.blockRect.bottom;
    final lineRect = Rect.fromLTWH(
      target.blockRect.left,
      lineCenterY - _kBlockReorderIndicatorHeight / 2,
      target.blockRect.width,
      _kBlockReorderIndicatorHeight,
    );
    if (lineRect.width <= 0 || lineRect.height <= 0) {
      return const SizedBox.shrink();
    }
    final localTopLeft = overlayBox.globalToLocal(lineRect.topLeft);
    final color = Theme.of(context).colorScheme.primary;
    return Positioned(
      left: localTopLeft.dx,
      top: localTopLeft.dy,
      width: lineRect.width,
      height: lineRect.height,
      child: IgnorePointer(
        child: DecoratedBox(
          key: _blockReorderDropIndicatorKey,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              _kBlockReorderIndicatorHeight / 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withAlpha(72),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeDropIndicator() {
    _dropIndicatorEntry?.remove();
    _dropIndicatorEntry = null;
  }

  void _removeDragPreview() {
    _dragPreviewEntry?.remove();
    _dragPreviewEntry = null;
    _dragSnapshot?.dispose();
    _dragSnapshot = null;
  }

  void _submitBlockReorder(_ResolvedBlockReorderDropTarget? target) {
    if (!_canDragSort || target == null) {
      return;
    }
    final insertionIndex =
        target.insertionIndex.clamp(0, widget.blockCount).toInt();
    final moveRange = widget.blockMoveRange;
    if (moveRange.containsInsertionBoundary(insertionIndex)) {
      return;
    }
    widget.onAction?.call(
      ObjectBlockActionIntent(
        action: insertionIndex < moveRange.startBlockIndex
            ? ObjectBlockAction.moveUp
            : ObjectBlockAction.moveDown,
        blockIndex: widget.blockIndex,
        value: _BlockReorderDropRequest(insertionIndex: insertionIndex),
      ),
    );
  }

  Future<void> _showMenu() async {
    if (!_enabled || _dragging || _menuOpen || !mounted) {
      return;
    }
    final position = _menuPosition();
    if (position == null) {
      return;
    }
    _handleMenuOpened();
    final selection = await showMenu<_ObjectMenuSelection>(
      context: context,
      position: position,
      elevation: _kPopupMenuElevation,
      shadowColor: _popupMenuShadowColor(Theme.of(context)),
      surfaceTintColor: Colors.transparent,
      shape: _popupMenuShape(Theme.of(context)),
      menuPadding: _kPopupMenuPadding,
      color: _popupMenuColor(Theme.of(context)),
      constraints: _kPopupMenuConstraints,
      clipBehavior: Clip.antiAlias,
      semanticLabel: '块操作',
      routeSettings: _kPopupMenuRouteSettings,
      items: _buildMenuItems(context),
    );
    if (!mounted) {
      return;
    }
    _handleMenuClosed();
    if (selection == null) {
      return;
    }
    if (selection.more) {
      await _showMoreMenu(position);
      return;
    }
    _handleActionSelected(selection);
  }

  RelativeRect? _menuPosition() {
    final button = _hitTestKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null ||
        overlay == null ||
        !button.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      buttonTopLeft & button.size,
      Offset.zero & overlay.size,
    );
  }

  Future<void> _showMoreMenu(RelativeRect position) async {
    final selection = await showMenu<_ObjectMenuSelection>(
      context: context,
      position: position,
      elevation: _kPopupMenuElevation,
      shadowColor: _popupMenuShadowColor(Theme.of(context)),
      surfaceTintColor: Colors.transparent,
      shape: _popupMenuShape(Theme.of(context)),
      menuPadding: _kPopupMenuPadding,
      color: _popupMenuColor(Theme.of(context)),
      constraints: _kPopupMenuConstraints,
      clipBehavior: Clip.antiAlias,
      semanticLabel: '更多块操作',
      routeSettings: _kPopupMenuRouteSettings,
      items: _buildMoreMenuItems(),
    );
    if (!mounted || selection == null) {
      return;
    }
    _handleActionSelected(selection);
  }

  List<PopupMenuEntry<_ObjectMenuSelection>> _buildMenuItems(
    BuildContext context,
  ) {
    final entries = <PopupMenuEntry<_ObjectMenuSelection>>[];
    if (widget.onAction != null) {
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        PopupMenuItem<_ObjectMenuSelection>(
          value: const _ObjectMenuSelection.action(
            ObjectBlockAction.copyContent,
          ),
          enabled: widget.blockPlainText.isNotEmpty,
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.content_copy,
            label: '复制块内容',
            shortcut: 'Ctrl+C',
            enabled: widget.blockPlainText.isNotEmpty,
          ),
        ),
        const PopupMenuItem<_ObjectMenuSelection>(
          value: _ObjectMenuSelection.action(ObjectBlockAction.copyReference),
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.link,
            label: '复制块引用',
          ),
        ),
      ]);
      if (widget.canDuplicateBlock) {
        entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
          _popupMenuDivider<_ObjectMenuSelection>(),
          const PopupMenuItem<_ObjectMenuSelection>(
            value: _ObjectMenuSelection.action(ObjectBlockAction.duplicate),
            height: _kPopupMenuItemHeight,
            padding: _kPopupMenuItemPadding,
            child: _PopupMenuItemContent(
              icon: Icons.copy_all_outlined,
              label: '创建块副本',
            ),
          ),
        ]);
      }
    }
    final hasRowFormatItems =
        widget.onFormatChanged != null && widget.canChangeBlockFormat;
    if (hasRowFormatItems || widget.blockCount > 1) {
      if (!widget.canDuplicateBlock && entries.isNotEmpty) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
      entries.add(
        const PopupMenuItem<_ObjectMenuSelection>(
          value: _ObjectMenuSelection.more(),
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.more_horiz,
            label: '更多块操作',
          ),
        ),
      );
    }
    if (widget.onAction != null) {
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _popupMenuDivider<_ObjectMenuSelection>(),
        const PopupMenuItem<_ObjectMenuSelection>(
          value: _ObjectMenuSelection.action(ObjectBlockAction.delete),
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.delete_outline,
            label: '删除块',
            destructive: true,
          ),
        ),
      ]);
    }
    return entries;
  }

  List<PopupMenuEntry<_ObjectMenuSelection>> _buildMoreMenuItems() {
    final canMoveUp =
        widget.canEdit && widget.blockMoveRange.canMoveUp(widget.blockCount);
    final canMoveDown =
        widget.canEdit && widget.blockMoveRange.canMoveDown(widget.blockCount);
    final entries = <PopupMenuEntry<_ObjectMenuSelection>>[];
    if (widget.onFormatChanged != null && widget.canChangeBlockFormat) {
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _rowFormatMenuItem(_RowBlockFormat.paragraph, '普通文本'),
        _rowFormatMenuItem(_RowBlockFormat.heading, '标题'),
        _rowFormatMenuItem(_RowBlockFormat.code, '代码块'),
      ]);
      if (widget.blockCount > 1) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
    }
    if (widget.blockCount > 1) {
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        PopupMenuItem<_ObjectMenuSelection>(
          value: const _ObjectMenuSelection.action(ObjectBlockAction.moveUp),
          enabled: canMoveUp && widget.onAction != null,
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.arrow_upward,
            label: '上移块',
            enabled: canMoveUp && widget.onAction != null,
          ),
        ),
        PopupMenuItem<_ObjectMenuSelection>(
          value: const _ObjectMenuSelection.action(ObjectBlockAction.moveDown),
          enabled: canMoveDown && widget.onAction != null,
          height: _kPopupMenuItemHeight,
          padding: _kPopupMenuItemPadding,
          child: _PopupMenuItemContent(
            icon: Icons.arrow_downward,
            label: '下移块',
            enabled: canMoveDown && widget.onAction != null,
          ),
        ),
      ]);
    }
    return entries;
  }

  PopupMenuItem<_ObjectMenuSelection> _rowFormatMenuItem(
    _RowBlockFormat format,
    String label,
  ) {
    return PopupMenuItem<_ObjectMenuSelection>(
      value: _ObjectMenuSelection.format(format),
      enabled: widget.blockFormat != format,
      height: _kPopupMenuItemHeight,
      padding: _kPopupMenuItemPadding,
      child: _PopupMenuItemContent(
        icon: _iconForRowFormat(format),
        label: label,
        enabled: widget.blockFormat != format,
        selected: widget.blockFormat == format,
      ),
    );
  }

  void _handleMenuOpened() {
    if (mounted) {
      setState(() => _menuOpen = true);
    }
  }

  void _handleMenuClosed() {
    if (mounted) {
      setState(() => _menuOpen = false);
    }
  }

  void _handleActionSelected(_ObjectMenuSelection selection) {
    final format = selection.format;
    if (format != null) {
      widget.onFormatChanged?.call(widget.blockIndex, format);
      return;
    }
    final action = selection.action;
    if (action == null) {
      return;
    }
    widget.onAction?.call(
      ObjectBlockActionIntent(
        action: action,
        blockIndex: widget.blockIndex,
        value: selection.value,
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered != value && mounted) {
      setState(() => _hovered = value);
    }
  }

  void _setFocused(bool value) {
    if (_focused != value && mounted) {
      setState(() => _focused = value);
    }
  }
}

double _indentStartFor(BlockNode block) {
  final indent = _blockIndentLevel(block).toDouble();
  final step =
      _isListItemBlock(block) ? _kListTextInset : _kIndentPixelsPerLevel;
  return indent * step;
}

double _rowChromeLineExtentFor(
  BuildContext context,
  BlockNode block,
  TextStyle? textStyle,
) {
  if (block is TextBlockNode) {
    final style = _blockTextStyle(context, block, textStyle);
    final tokens = EditorTokens.resolve(context);
    final lineHeight = _lineHeightFor(style, tokens);
    final isTodoListItem = block.type == BlockType.listItem &&
        (block.attributes.listType == 'task' ||
            block.attributes.checked != null);
    return isTodoListItem
        ? math.max(lineHeight, tokens.todoCheckboxHeight)
        : lineHeight;
  }
  if (block is CodeBlockNode) {
    return _kCodeBlockHeaderHeight;
  }
  return BlockDragHandleSpec.hitSize.height;
}

double _rowChromeTopOffsetFor(BlockNode block) {
  if (block is ImageBlockNode || block is VideoBlockNode) {
    return _kMediaBlockMarginVertical / 2;
  }
  return 0.0;
}

double _rowChromeTopFor({
  required double lineExtent,
  required double controlHeight,
}) {
  if (!lineExtent.isFinite ||
      lineExtent <= 0 ||
      !controlHeight.isFinite ||
      controlHeight <= 0) {
    return BlockDragHandleSpec.topInset;
  }
  return math.max(0.0, (lineExtent - controlHeight) / 2);
}

/// Vertical spacing between two index-adjacent top-level blocks.
///
/// Render-layer concern only: it feeds the virtual list's `offsetFor` /
/// `totalExtent` accounting but never the document model, measurement of an
/// individual block, or keep-alive. Per the "Consecutive quoted text block
/// background" contract in `docs/rendering.md`, quoted → quoted always
/// collapses to `0` before custom spacing is considered; otherwise a host
/// `blockSpacing` value would become a transparent seam between two separately
/// painted quote surfaces. Every other adjacency keeps its current spacing,
/// including quoted ↔ non-quoted boundaries. List pairs collapse to
/// `_kListItemSpacing` / `_kNestedListItemSpacing` and heading margins apply via
/// `_blockMarginBefore` / `_blockMarginAfter` only on the default-spacing path.
double _spacingBetweenBlocks(
  BlockNode previous,
  BlockNode next,
  double fallback,
) {
  // Any index-adjacent quoted → quoted pair collapses to 0 so their surface
  // backgrounds fuse into one continuous run. Grouping is adjacency + quote
  // decoration only — an `indent` attribute does not start a new column or
  // break the run (see the "Consecutive quoted text block background" contract
  // in `docs/rendering.md`).
  if (_isQuoteBlock(previous) && _isQuoteBlock(next)) {
    return _kAdjacentQuoteSpacing;
  }
  if ((fallback - _kDefaultBlockSpacing).abs() > 0.01) {
    return fallback;
  }
  if (_isListItemBlock(previous) && _isListItemBlock(next)) {
    final previousIndent = _blockIndentLevel(previous);
    final nextIndent = _blockIndentLevel(next);
    return previousIndent > 0 || nextIndent > 0
        ? _kNestedListItemSpacing
        : _kListItemSpacing;
  }
  return math.max(
    _blockMarginAfter(previous, fallback),
    _blockMarginBefore(next, fallback),
  );
}

double _blockMarginBefore(BlockNode block, double fallback) {
  if (block is TextBlockNode && block.type == BlockType.heading) {
    return _kRichTextBodyFontSize * _kHeadingMarginTopEm;
  }
  return fallback;
}

double _blockMarginAfter(BlockNode block, double fallback) {
  if (block is TextBlockNode && block.type == BlockType.heading) {
    return _kRichTextBodyFontSize * _kHeadingMarginBottomEm;
  }
  return fallback;
}

bool _isListItemBlock(BlockNode block) {
  return block is TextBlockNode && block.type == BlockType.listItem;
}

bool _isQuoteBlock(BlockNode block) {
  return block is TextBlockNode &&
      (block.type == BlockType.quote || block.attributes.isQuoted);
}

bool _selectionTouchesBlockIndex(DocumentSelection? selection, int blockIndex) {
  if (selection == null) {
    return false;
  }
  final start = selection.start;
  final end = selection.end;
  return start.blockIndex == blockIndex ||
      end.blockIndex == blockIndex ||
      (blockIndex > start.blockIndex && blockIndex < end.blockIndex);
}

int _blockIndentLevel(BlockNode block) {
  return (block.attributes.indent ?? 0).clamp(0, 8).toInt();
}

/// Position of [blocks[index]] within its run of consecutive quote blocks,
/// mirroring the adjacency rule used by [_spacingBetweenBlocks] exactly: two
/// quotes join into one continuous background when (and only when) they are
/// index-adjacent and both carry quote decoration (or legacy `BlockType.quote`).
/// Grouping is adjacency + quote state only — an `indent` attribute does not
/// extend or break the run, so a quote flanked by quotes of any indent still
/// joins them. A non-quote block (or a quote flanked only by non-quotes) is
/// [QuoteGroupPosition.standalone]. See
/// "Consecutive quoted text block background" in `docs/rendering.md`.
QuoteGroupPosition _quoteGroupPositionFor(List<BlockNode> blocks, int index) {
  final block = blocks[index];
  if (!_isQuoteBlock(block)) {
    return QuoteGroupPosition.standalone;
  }
  final joinsPrevious = index > 0 && _isQuoteBlock(blocks[index - 1]);
  final joinsNext =
      index < blocks.length - 1 && _isQuoteBlock(blocks[index + 1]);
  if (joinsPrevious && joinsNext) {
    return QuoteGroupPosition.interior;
  }
  if (joinsPrevious) {
    return QuoteGroupPosition.last;
  }
  if (joinsNext) {
    return QuoteGroupPosition.first;
  }
  return QuoteGroupPosition.standalone;
}

_RowBlockFormat? _rowBlockFormatFor(BlockNode block) {
  return switch (block) {
    CodeBlockNode() => _RowBlockFormat.code,
    TextBlockNode(type: BlockType.heading) => _RowBlockFormat.heading,
    TextBlockNode() => _RowBlockFormat.paragraph,
    _ => null,
  };
}

bool _canChangeRowBlockFormat(BlockNode block) {
  return block is TextBlockNode || block is CodeBlockNode;
}

BlockAttributes _rowTextAttributesFor(
  BlockAttributes current,
  _RowBlockFormat format,
) {
  return BlockAttributes(
    level: format == _RowBlockFormat.heading ? current.level ?? 1 : null,
    indent: current.indent,
    alignment: current.alignment,
    childNote: current.childNote,
    anchor: current.anchor,
  );
}

BlockAttributes _rowCodeAttributesFor(BlockAttributes current) {
  return BlockAttributes(
    indent: current.indent,
    alignment: current.alignment,
    childNote: current.childNote,
    anchor: current.anchor,
  );
}

List<InlineNode> _plainTextInlineContent(String text) {
  if (text.isEmpty) {
    return const <InlineNode>[];
  }
  return <InlineNode>[TextRun(text: text)];
}

/// Plain-text fallback used when no renderer is registered for a block type.
/// Guarantees every block paints *something*.
Widget _defaultBlockFallback(
  BuildContext context,
  BlockRenderContext renderContext,
) {
  return Text(renderContext.block.plainText);
}

/// Installs the built-in block renderers onto [registry]. Exposed so the editor
/// can wire defaults into a caller-supplied registry without duplicating the
/// dispatch table.
extension BlockRendererRegistryDefaults on BlockRendererRegistry {
  void installDefaultBuilders() {
    register(BlockType.paragraph, _defaultTextBlockRenderer);
    register(BlockType.heading, _defaultTextBlockRenderer);
    register(BlockType.quote, _defaultTextBlockRenderer);
    register(BlockType.listItem, _defaultTextBlockRenderer);
    register(BlockType.code, _defaultCodeBlockRenderer);
    register(BlockType.image, _defaultImageBlockRenderer);
    register(BlockType.table, _defaultTableBlockRenderer);
    register(BlockType.divider, _defaultDividerBlockRenderer);
    register(BlockType.video, _defaultVideoBlockRenderer);
    register(BlockType.embed, _defaultBlockEmbedRenderer);
    register(BlockType.callout, _defaultCalloutBlockRenderer);
    register(BlockType.file, _defaultFileBlockRenderer);
  }
}

Widget _defaultTextBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _TextBlockRenderer(
    block: rc.block as TextBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    textStyle: rc.textStyle,
    showDebugOverlay: rc.showDebugOverlay,
    listMarker: rc.listMarker,
    quoteGroupPosition: rc.quoteGroupPosition,
    inlineEmbedRenderer: rc.inlineEmbedRenderer,
    onToolbarAction: rc.onTableToolbarAction,
    onColumnResize: rc.onTableColumnResize,
    onTodoCheckedChanged: rc.onTodoCheckedChanged,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultCodeBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _CodeBlockRenderer(
    block: rc.block as CodeBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    showDebugOverlay: rc.showDebugOverlay,
    onLanguageChanged: rc.onCodeLanguageChanged,
    onCodeCopied: rc.onCodeCopied,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultImageBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final image = rc.block as ImageBlockNode;
  final result = _resolveMediaWithStatus(context, rc);
  // A resolver-provided widget always wins over any placeholder; only the
  // fallback distinguishes empty (no / declining resolver) from failed (threw),
  // so the catch-and-fallback path surfaces a visually distinct failure state.
  final media = result.hasWidget
      ? result.widget!
      : _ImageBlockPlaceholder(
          status: result.threw
              ? _ImageBlockPlaceholderStatus.failed
              : _ImageBlockPlaceholderStatus.empty,
        );
  return _SelectableImageBlock(
    block: image,
    renderContext: rc,
    media: media,
    onPreview: () => _showImagePreview(context, image, rc),
  );
}

Widget _defaultTableBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  return _TableBlockRenderer(
    block: rc.block as TableBlockNode,
    blockIndex: rc.blockIndex,
    selection: rc.selection,
    compositionState: rc.compositionState,
    registry: rc.registry,
    showCaret: rc.showCaret,
    textStyle: rc.textStyle,
    showDebugOverlay: rc.showDebugOverlay,
    inlineEmbedRenderer: rc.inlineEmbedRenderer,
    onToolbarAction: rc.onTableToolbarAction,
    toolbarOverlayController: rc.tableToolbarOverlayController,
    onColumnResize: rc.onTableColumnResize,
    findMatches: rc.findMatches,
    currentFindMatch: rc.currentFindMatch,
  );
}

Widget _defaultDividerBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final block = rc.block as DividerBlockNode;
  return _withSelectableObjectBlock(
    block,
    rc,
    _DividerBlockContent(
      blockId: block.id,
      selected: _objectBlockSelected(block, rc),
    ),
    showSelectionOverlay: false,
  );
}

Widget _defaultVideoBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final video = rc.block as VideoBlockNode;
  final media = _StableResolvedVideoMedia(
    key: ValueKey<String>('wenz-richtext-video-resolved-${video.id}-inline'),
    block: video,
    renderContext: rc,
    position: _VideoMediaRenderPosition.inline,
  );
  return _SelectableVideoBlock(
    block: video,
    renderContext: rc,
    media: media,
    onPreview: () => _showVideoPreview(context, video, rc),
  );
}

Widget _defaultBlockEmbedRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final embed = rc.block as BlockEmbedNode;
  final selected = _objectBlockSelected(embed, rc);
  return WenzObjectBlockSurface(
    renderContext: rc,
    child: embed.normalizedEmbedType == 'formula'
        ? _FormulaBlockContent(
            block: embed,
            blockIndex: rc.blockIndex,
            blockCount: rc.blockCount,
            selected: selected,
            canEdit: rc.canEdit,
            onAction: rc.onObjectBlockAction,
          )
        : _BlockEmbedContent(
            block: embed,
            blockIndex: rc.blockIndex,
            blockCount: rc.blockCount,
            selected: selected,
            canEdit: rc.canEdit,
            onAction: rc.onObjectBlockAction,
          ),
  );
}

Widget _defaultCalloutBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final block = rc.block as CalloutBlockNode;
  final path = PositionPath.blockText(block.id);
  final textLength = inlineNodesLength(block.content);
  final selected = _selectionRangeForPath(
        rc.selection,
        rc.blockIndex,
        path,
        textLength,
      ) !=
      null;
  return _withBlockSemantics(
    block,
    _CalloutRenderer(
      block: block,
      blockIndex: rc.blockIndex,
      selection: rc.selection,
      compositionState: rc.compositionState,
      registry: rc.registry,
      showCaret: rc.showCaret,
      textStyle: rc.textStyle,
      selected: selected,
      showDebugOverlay: rc.showDebugOverlay,
      inlineEmbedRenderer: rc.inlineEmbedRenderer,
      onVariantChanged: rc.onCalloutVariantChanged,
      findMatches: rc.findMatches,
      currentFindMatch: rc.currentFindMatch,
    ),
    selected: selected,
  );
}

Widget _defaultFileBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final file = rc.block as FileBlockNode;
  final resolved = _resolveMedia(context, rc);
  if (resolved != null) {
    return _withSelectableObjectBlock(
      file,
      rc,
      _MediaSelectionStroke(
        selected: _objectBlockSelected(file, rc),
        child: resolved,
      ),
      showSelectionOverlay: false,
    );
  }
  return _withSelectableObjectBlock(
    file,
    rc,
    _FileBlockContent(
      block: file,
      blockIndex: rc.blockIndex,
      blockCount: rc.blockCount,
      selected: _objectBlockSelected(file, rc),
      canEdit: rc.canEdit,
      onAction: rc.onObjectBlockAction,
    ),
  );
}

/// Outcome of consulting the injected [MediaResolver]: the resolved widget (if
/// any) plus whether the resolver threw. Image blocks use [threw] to render the
/// load-failure placeholder instead of the empty one, keeping the empty and
/// failure fallbacks visually distinct (see
/// `docs/design/media_block_display_spec.md` §占位状态契约).
class _MediaResolveResult {
  const _MediaResolveResult({this.widget, this.threw = false});

  final Widget? widget;
  final bool threw;

  bool get hasWidget => widget != null;
}

enum _VideoMediaRenderPosition { inline, dialog }

/// Identifies the independently resolved video-rendering subtree.
enum WenzRichTextVideoMediaResolveEntry {
  /// The rounded video frame embedded in the editor document.
  inline,

  /// The square-corner fullscreen preview route.
  ///
  /// The historical `dialog` name is retained for API compatibility.
  dialog,
}

/// Exposes the current video resolver entry to host-side media resolvers.
class WenzRichTextMediaResolveScope extends InheritedWidget {
  const WenzRichTextMediaResolveScope({
    super.key,
    required this.videoEntry,
    required super.child,
  });

  final WenzRichTextVideoMediaResolveEntry? videoEntry;

  static WenzRichTextVideoMediaResolveEntry? maybeVideoEntryOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<WenzRichTextMediaResolveScope>()
        ?.videoEntry;
  }

  @override
  bool updateShouldNotify(covariant WenzRichTextMediaResolveScope oldWidget) {
    return oldWidget.videoEntry != videoEntry;
  }
}

typedef _InlineVideoResolverTapTargetRegistrar = void Function(
  String blockId,
  GlobalKey key,
  bool Function(Offset globalPosition) consumeUnclaimedTap,
);

typedef _InlineVideoResolverTapTargetUnregistrar = void Function(
  String blockId,
  GlobalKey key,
);

class _InlineVideoResolverTapTargetRegistration {
  const _InlineVideoResolverTapTargetRegistration({
    required this.blockId,
    required this.consumeUnclaimedTap,
  });

  final String blockId;
  final bool Function(Offset globalPosition) consumeUnclaimedTap;
}

class _VideoResolverTapRouteScope extends InheritedWidget {
  const _VideoResolverTapRouteScope({
    required this.registerTapTarget,
    required this.unregisterTapTarget,
    required super.child,
  });

  final _InlineVideoResolverTapTargetRegistrar registerTapTarget;
  final _InlineVideoResolverTapTargetUnregistrar unregisterTapTarget;

  static _VideoResolverTapRouteScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_VideoResolverTapRouteScope>();
  }

  @override
  bool updateShouldNotify(covariant _VideoResolverTapRouteScope oldWidget) {
    return false;
  }
}

class _InlineVideoResolverTapTarget extends StatefulWidget {
  const _InlineVideoResolverTapTarget({
    required this.blockId,
    required this.child,
  });

  final String blockId;
  final Widget child;

  @override
  State<_InlineVideoResolverTapTarget> createState() =>
      _InlineVideoResolverTapTargetState();
}

class _InlineVideoResolverTapTargetState
    extends State<_InlineVideoResolverTapTarget> {
  final GlobalKey _hitTestKey = GlobalKey();
  final List<Offset> _unclaimedTapPositions = <Offset>[];
  _VideoResolverTapRouteScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScope();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoResolverTapTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockId != widget.blockId) {
      _scope?.unregisterTapTarget(oldWidget.blockId, _hitTestKey);
      _unclaimedTapPositions.clear();
      _scope?.registerTapTarget(
        widget.blockId,
        _hitTestKey,
        _consumeUnclaimedTapAt,
      );
    }
  }

  @override
  void dispose() {
    _scope?.unregisterTapTarget(widget.blockId, _hitTestKey);
    super.dispose();
  }

  void _updateScope() {
    final next = _VideoResolverTapRouteScope.maybeOf(context);
    if (identical(_scope, next)) {
      return;
    }
    _scope?.unregisterTapTarget(widget.blockId, _hitTestKey);
    _scope = next;
    _scope?.registerTapTarget(
      widget.blockId,
      _hitTestKey,
      _consumeUnclaimedTapAt,
    );
  }

  void _recordUnclaimedTap(TapUpDetails details) {
    _unclaimedTapPositions.add(details.globalPosition);
    if (_unclaimedTapPositions.length > 8) {
      _unclaimedTapPositions.removeAt(0);
    }
  }

  bool _consumeUnclaimedTapAt(Offset globalPosition) {
    final index = _unclaimedTapPositions.lastIndexWhere(
      (position) => (position - globalPosition).distance <= 1,
    );
    if (index < 0) {
      return false;
    }
    _unclaimedTapPositions.removeAt(index);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // This recognizer wins only when no resolver descendant claims the tap.
    // SelectionGestureOverlay consumes the recorded position on mobile to
    // distinguish frame background selection from playback-control gestures.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _recordUnclaimedTap,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          _EditorReservedVideoPointerRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  _EditorReservedVideoPointerRecognizer>(
            _EditorReservedVideoPointerRecognizer.new,
            (_EditorReservedVideoPointerRecognizer instance) {},
          ),
        },
        child: KeyedSubtree(
          key: _hitTestKey,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Claims Shift+mouse sequences before resolver controls enter the gesture
/// arena. The document selection listener still receives the raw pointer
/// events, so Shift extension and Shift drag keep working without also firing a
/// player's ordinary tap callback. Unmodified taps are rejected immediately and
/// remain entirely owned by the resolver subtree.
class _EditorReservedVideoPointerRecognizer
    extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    final reservesForEditor = event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0 &&
        HardwareKeyboard.instance.isShiftPressed;
    if (!reservesForEditor) {
      resolve(GestureDisposition.rejected);
      return;
    }
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'editor-reserved-video-pointer';
}

String _videoMediaRenderPositionLabel(_VideoMediaRenderPosition position) {
  return switch (position) {
    _VideoMediaRenderPosition.inline => 'inline',
    _VideoMediaRenderPosition.dialog => 'dialog',
  };
}

String _videoMediaResolveEntryLabel(
  WenzRichTextVideoMediaResolveEntry entry,
) {
  return switch (entry) {
    WenzRichTextVideoMediaResolveEntry.inline => 'inline-video',
    WenzRichTextVideoMediaResolveEntry.dialog => 'fullscreen-preview',
  };
}

WenzRichTextVideoMediaResolveEntry _videoMediaResolveEntry(
  _VideoMediaRenderPosition position,
) {
  return switch (position) {
    _VideoMediaRenderPosition.inline =>
      WenzRichTextVideoMediaResolveEntry.inline,
    _VideoMediaRenderPosition.dialog =>
      WenzRichTextVideoMediaResolveEntry.dialog,
  };
}

class _VideoMediaPositionBoundary extends StatelessWidget {
  const _VideoMediaPositionBoundary({
    required this.blockId,
    required this.position,
    required this.child,
  });

  final String blockId;
  final _VideoMediaRenderPosition position;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>(
        'wenz-richtext-video-media-$blockId-'
        '${_videoMediaRenderPositionLabel(position)}',
      ),
      child: child,
    );
  }
}

_MediaResolveResult _resolveVideoMediaWithStatus(
  BuildContext context,
  BlockRenderContext rc,
  _VideoMediaRenderPosition position,
) {
  final block = rc.block as VideoBlockNode;
  final result = _resolveMediaWithStatus(
    context,
    rc,
    renderPosition: _videoMediaRenderPositionLabel(position),
  );
  final media = result.widget;
  if (media == null) {
    return result;
  }
  final routedMedia = position == _VideoMediaRenderPosition.inline
      ? _InlineVideoResolverTapTarget(
          blockId: block.id,
          child: media,
        )
      : media;
  return _MediaResolveResult(
    widget: _VideoMediaPositionBoundary(
      blockId: block.id,
      position: position,
      child: routedMedia,
    ),
    threw: result.threw,
  );
}

Widget _videoFallbackForResolve(
  VideoBlockNode block,
  _MediaResolveResult result,
  _VideoMediaRenderPosition position,
) {
  return _VideoBlockPlaceholder(
    block: block,
    squareCorners: position == _VideoMediaRenderPosition.dialog,
    status: result.threw
        ? _VideoBlockPlaceholderStatus.failed
        : _VideoBlockPlaceholderStatus.cover,
  );
}

void _debugLogVideoMediaResolveEntry(
  String entry,
  VideoBlockNode block,
  BlockRenderContext rc,
  StackTrace stackTrace,
) {
  debugPrint(
    '[wenz_richtext.video] resolve entry=$entry; '
    'block=${block.id}; '
    'index=${rc.blockIndex}/${rc.blockCount}; '
    'source=${_videoSourceLabel(block)}; '
    'firstProjectFrame=${_debugFirstProjectStackFrame(stackTrace) ?? "-"}',
  );
}

void _debugLogEditorVideoLifecycle(
  String event,
  List<BlockNode> blocks,
  StackTrace stackTrace,
) {
  final videos = blocks.whereType<VideoBlockNode>().toList(growable: false);
  if (videos.isEmpty) {
    return;
  }
  debugPrint(
    '[wenz_richtext.video] $event; '
    'videoCount=${videos.length}; '
    'blocks=${videos.map((video) => video.id).join(",")}; '
    'firstProjectFrame=${_debugFirstProjectStackFrame(stackTrace) ?? "-"}',
  );
}

String? _debugFirstProjectStackFrame(StackTrace? stackTrace) {
  if (stackTrace == null) {
    return null;
  }
  for (final rawLine in stackTrace.toString().split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final normalized = line.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('/wenzflow_flutter/lib/') ||
        normalized.contains('package:wenzflow/') ||
        normalized.contains('/wenz_flutter/wenz_richtext/lib/') ||
        normalized.contains('package:wenz_richtext/')) {
      return line;
    }
  }
  return null;
}

/// Asks the injected [MediaResolver] (if any) to render [rc.block]. Returns
/// `null` when no resolver is injected, the resolver declines (`null`), or the
/// resolver throws — in all those cases the caller falls back to the built-in
/// placeholder. The try/catch keeps a faulty resolver from crashing the editor
/// (see `docs/schema_and_commands.md` §Error handling).
Widget? _resolveMedia(BuildContext context, BlockRenderContext rc) {
  return _resolveMediaWithStatus(context, rc).widget;
}

/// Same as [_resolveMedia] but also reports whether the resolver threw, so
/// callers that distinguish the failure fallback (image/video blocks) can pick
/// the right placeholder status.
_MediaResolveResult _resolveMediaWithStatus(
  BuildContext context,
  BlockRenderContext rc, {
  String? renderPosition,
}) {
  final resolver = rc.mediaResolver;
  if (resolver == null) {
    return const _MediaResolveResult();
  }
  try {
    return _MediaResolveResult(widget: resolver.resolve(context, rc.block));
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'wenz_richtext',
      context: ErrorDescription('MediaResolver.resolve threw for block '
          '${rc.block.id} (${rc.block.type})'
          '${renderPosition == null ? '' : ' at $renderPosition'}; '
          'falling back to placeholder.'),
      informationCollector: () => <DiagnosticsNode>[
        if (renderPosition != null)
          DiagnosticsProperty<String>('render position', renderPosition),
        DiagnosticsProperty<String>(
          'first project frame',
          _debugFirstProjectStackFrame(stackTrace) ?? '-',
        ),
        DiagnosticsProperty<String>('block id', rc.block.id),
        DiagnosticsProperty<String>('block type', rc.block.type.toString()),
      ],
    ));
    return const _MediaResolveResult(threw: true);
  }
}

void _showImagePreview(
  BuildContext context,
  ImageBlockNode block,
  BlockRenderContext rc,
) {
  final media = _resolveMedia(context, rc) ?? const _ImageBlockPlaceholder();
  final label = _imageAccessibleLabel(block);
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
            child: Semantics(
              label: label,
              image: true,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(child: media),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void _showVideoPreview(
  BuildContext context,
  VideoBlockNode block,
  BlockRenderContext rc,
) {
  assert(() {
    _debugLogVideoMediaResolveEntry(
      'fullscreen-preview',
      block,
      rc,
      StackTrace.current,
    );
    return true;
  }());
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) {
    return;
  }
  final materialLocalizations = Localizations.of<MaterialLocalizations>(
    context,
    MaterialLocalizations,
  );
  final barrierLabel =
      materialLocalizations?.modalBarrierDismissLabel ?? 'Dismiss';
  _VideoFullscreenRouteCoordinator.show(
    navigator: navigator,
    barrierLabel: barrierLabel,
    block: block,
    renderContext: rc,
  );
}

class _VideoFullscreenRouteCoordinator {
  static const Duration _transitionDuration = Duration(milliseconds: 180);
  static final Expando<Object> _activeNavigatorSessions =
      Expando<Object>('wenz-richtext-video-fullscreen-session');

  static void show({
    required NavigatorState navigator,
    required String barrierLabel,
    required VideoBlockNode block,
    required BlockRenderContext renderContext,
  }) {
    if (!navigator.mounted || _activeNavigatorSessions[navigator] != null) {
      return;
    }
    final session = Object();
    _activeNavigatorSessions[navigator] = session;

    final toolbarController = renderContext.objectBlockToolbarOverlayController;
    final handoff = toolbarController?.beginRouteHandoff(
      blockId: block.id,
      blockIndex: renderContext.blockIndex,
    );
    if (toolbarController != null && handoff?.isActive != true) {
      _activeNavigatorSessions[navigator] = null;
      return;
    }

    // Popup routes owned by the toolbar must leave before the fullscreen route
    // starts capturing focus and inherited state from the navigator overlay.
    _EditorPopupMenuDismissal.dismiss();
    unawaited(
      _run(
        navigator: navigator,
        barrierLabel: barrierLabel,
        block: block,
        renderContext: renderContext,
        handoff: handoff,
        session: session,
      ),
    );
  }

  static Future<void> _run({
    required NavigatorState navigator,
    required String barrierLabel,
    required VideoBlockNode block,
    required BlockRenderContext renderContext,
    required ObjectBlockToolbarOverlayHandoff? handoff,
    required Object session,
  }) async {
    try {
      if (handoff != null) {
        await handoff.waitUntilHidden();
        if (!handoff.isActive) {
          return;
        }
      } else {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!navigator.mounted) {
        return;
      }

      final route = RawDialogRoute<void>(
        settings: RouteSettings(
          name: 'wenz-richtext-video-fullscreen-${block.id}',
        ),
        barrierDismissible: false,
        barrierColor: Colors.black,
        barrierLabel: barrierLabel,
        transitionDuration: _transitionDuration,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenVideoPreview(
            block: block,
            renderContext: renderContext,
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
      await navigator.push<void>(route);
      // Navigator.push completes when pop begins. Keep the toolbar suppressed
      // until the reverse transition has removed the route's overlay entries.
      await route.completed;
    } finally {
      handoff?.complete();
      if (identical(_activeNavigatorSessions[navigator], session)) {
        _activeNavigatorSessions[navigator] = null;
      }
    }
  }
}

class _FullscreenVideoPreview extends StatefulWidget {
  const _FullscreenVideoPreview({
    required this.block,
    required this.renderContext,
  });

  final VideoBlockNode block;
  final BlockRenderContext renderContext;

  @override
  State<_FullscreenVideoPreview> createState() =>
      _FullscreenVideoPreviewState();
}

class _FullscreenVideoPreviewState extends State<_FullscreenVideoPreview> {
  bool _closeRequested = false;

  Future<void> _requestClose() async {
    if (_closeRequested || !mounted) {
      return;
    }
    _closeRequested = true;
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      _closeRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(_requestClose());
        },
      },
      child: Focus(
        autofocus: true,
        child: Material(
          key: ValueKey<String>(
            'wenz-richtext-video-fullscreen-surface-${widget.block.id}',
          ),
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _FullscreenVideoViewport(
                block: widget.block,
                renderContext: widget.renderContext,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton(
                      key: ValueKey<String>(
                        'wenz-richtext-video-fullscreen-close-${widget.block.id}',
                      ),
                      tooltip: '关闭视频预览',
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () => unawaited(_requestClose()),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoViewport extends StatelessWidget {
  const _FullscreenVideoViewport({
    required this.block,
    required this.renderContext,
  });

  final VideoBlockNode block;
  final BlockRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = _finiteVideoViewportSize(
          constraints,
          MediaQuery.sizeOf(context),
        );
        if (viewport.isEmpty) {
          return const ColoredBox(color: Colors.black);
        }
        return SizedBox.fromSize(
          size: viewport,
          child: ColoredBox(
            key: ValueKey<String>(
              'wenz-richtext-video-fullscreen-viewport-${block.id}',
            ),
            color: Colors.black,
            child: SizedBox.expand(
              key: ValueKey<String>(
                'wenz-richtext-video-fullscreen-frame-${block.id}',
              ),
              child: Semantics(
                label: _videoAccessibleLabel(block),
                image: true,
                child: ColoredBox(
                  color: Colors.black,
                  child: _VideoPreviewMedia(
                    block: block,
                    renderContext: renderContext,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Size _finiteVideoViewportSize(
  BoxConstraints constraints,
  Size mediaQuerySize,
) {
  final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
      ? constraints.maxWidth
      : mediaQuerySize.width;
  final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
      ? constraints.maxHeight
      : mediaQuerySize.height;
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return Size.zero;
  }
  return Size(width, height);
}

class _VideoPreviewMedia extends StatelessWidget {
  const _VideoPreviewMedia({
    required this.block,
    required this.renderContext,
  });

  final VideoBlockNode block;
  final BlockRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    return _VideoFrameChildBoundary(
      child: _StableResolvedVideoMedia(
        key: ValueKey<String>(
          'wenz-richtext-video-resolved-${block.id}-dialog',
        ),
        block: block,
        renderContext: renderContext,
        position: _VideoMediaRenderPosition.dialog,
      ),
    );
  }
}

class _StableResolvedVideoMedia extends StatefulWidget {
  const _StableResolvedVideoMedia({
    super.key,
    required this.block,
    required this.renderContext,
    required this.position,
  });

  final VideoBlockNode block;
  final BlockRenderContext renderContext;
  final _VideoMediaRenderPosition position;

  @override
  State<_StableResolvedVideoMedia> createState() =>
      _StableResolvedVideoMediaState();
}

class _StableResolvedVideoMediaState extends State<_StableResolvedVideoMedia> {
  Widget? _cachedMedia;
  late _VideoMediaResolverCacheKey _cacheKey;

  @override
  void initState() {
    super.initState();
    _cacheKey = _currentCacheKey();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedMedia = null;
  }

  @override
  void didUpdateWidget(covariant _StableResolvedVideoMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _currentCacheKey();
    if (_cacheKey != nextKey) {
      _cacheKey = nextKey;
      _cachedMedia = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _cachedMedia ??= _buildResolvedMedia(context);
  }

  Widget _buildResolvedMedia(BuildContext context) {
    final entry = _videoMediaResolveEntry(widget.position);
    assert(() {
      _debugLogVideoMediaResolveEntry(
        _videoMediaResolveEntryLabel(entry),
        widget.block,
        widget.renderContext,
        StackTrace.current,
      );
      return true;
    }());
    return WenzRichTextMediaResolveScope(
      videoEntry: entry,
      child: Builder(
        builder: (context) {
          final result = _resolveVideoMediaWithStatus(
            context,
            widget.renderContext,
            widget.position,
          );
          return result.widget ??
              _videoFallbackForResolve(
                widget.block,
                result,
                widget.position,
              );
        },
      ),
    );
  }

  _VideoMediaResolverCacheKey _currentCacheKey() {
    return _VideoMediaResolverCacheKey(
      resolver: widget.renderContext.mediaResolver,
      position: widget.position,
      block: widget.block,
    );
  }
}

class _VideoMediaResolverCacheKey {
  _VideoMediaResolverCacheKey({
    required this.resolver,
    required this.position,
    required VideoBlockNode block,
  })  : blockId = block.id,
        assetId = block.assetId,
        playbackUrl = block.playbackUrl,
        file = block.file,
        coverUrl = block.coverUrl,
        title = block.title,
        description = block.description,
        aspectRatio = block.aspectRatio,
        showWidth = block.showWidth,
        showHeight = block.showHeight,
        uploadStatus = block.uploadStatus,
        uploadError = block.uploadError,
        attributes = block.attributes;

  final MediaResolver? resolver;
  final _VideoMediaRenderPosition position;
  final String blockId;
  final String assetId;
  final String playbackUrl;
  final String file;
  final String coverUrl;
  final String title;
  final String description;
  final double? aspectRatio;
  final double? showWidth;
  final double? showHeight;
  final FileUploadStatus uploadStatus;
  final String uploadError;
  final BlockAttributes attributes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _VideoMediaResolverCacheKey &&
            identical(other.resolver, resolver) &&
            other.position == position &&
            other.blockId == blockId &&
            other.assetId == assetId &&
            other.playbackUrl == playbackUrl &&
            other.file == file &&
            other.coverUrl == coverUrl &&
            other.title == title &&
            other.description == description &&
            other.aspectRatio == aspectRatio &&
            other.showWidth == showWidth &&
            other.showHeight == showHeight &&
            other.uploadStatus == uploadStatus &&
            other.uploadError == uploadError &&
            other.attributes == attributes;
  }

  @override
  int get hashCode {
    return Object.hash(
      identityHashCode(resolver),
      position,
      blockId,
      assetId,
      playbackUrl,
      file,
      coverUrl,
      title,
      description,
      aspectRatio,
      showWidth,
      showHeight,
      uploadStatus,
      uploadError,
      attributes,
    );
  }
}

Widget _withSelectableObjectBlock(
  BlockNode block,
  BlockRenderContext rc,
  Widget child, {
  bool showSelectionOverlay = true,
}) {
  final path = PositionPath.blockObject(block.id);
  final selected = _selectionTouchesPath(
    rc.selection,
    rc.blockIndex,
    block.id,
    path,
    _kAtomicBlockSelectionLength,
  );
  return _withBlockSemantics(
    block,
    _BlockObjectSelectionSurface(
      blockId: block.id,
      blockIndex: rc.blockIndex,
      path: path,
      selection: rc.selection,
      registry: rc.registry,
      showDebugOverlay: rc.showDebugOverlay,
      showSelectionOverlay: showSelectionOverlay,
      child: child,
    ),
    selected: selected,
  );
}

Widget _withSelectableImageBlock(
  BuildContext context,
  ImageBlockNode block,
  BlockRenderContext rc,
  Widget child, {
  VoidCallback? onPreview,
  double? toolbarFrameWidth,
}) {
  final path = PositionPath.blockObject(block.id);
  final selected = _selectionTouchesPath(
    rc.selection,
    rc.blockIndex,
    block.id,
    path,
    _kAtomicBlockSelectionLength,
  );
  final imageDescriptionEditController =
      _ImageDescriptionEditRequestScope.maybeOf(context);
  return _withBlockSemantics(
    block,
    _MediaBlockChrome(
      blockIndex: rc.blockIndex,
      blockCount: rc.blockCount,
      blockId: block.id,
      selected: selected,
      canEdit: rc.canEdit,
      imageActions: true,
      imageAlignment: block.attributes.alignment,
      toolbarFrameWidth: toolbarFrameWidth ?? _preferredImageFrameWidth(block),
      toolbarFrameAlignment: _imageBlockFigureAlignment(
        block.attributes.alignment,
      ),
      toolbarOverlayController: rc.objectBlockToolbarOverlayController,
      onAction: rc.onObjectBlockAction,
      onEditImageDescription: imageDescriptionEditController == null
          ? null
          : () {
              imageDescriptionEditController.request(
                _ImageDescriptionEditTarget(
                  blockIndex: rc.blockIndex,
                  blockId: block.id,
                  caption: block.caption,
                  altText: block.altText,
                ),
              );
            },
      onPreview: onPreview,
      child: _BlockObjectSelectionSurface(
        blockId: block.id,
        blockIndex: rc.blockIndex,
        path: path,
        selection: rc.selection,
        registry: rc.registry,
        showDebugOverlay: rc.showDebugOverlay,
        showSelectionOverlay: false,
        onDoubleTap: onPreview,
        child: child,
      ),
    ),
    selected: selected,
  );
}

class _SelectableImageBlock extends StatefulWidget {
  const _SelectableImageBlock({
    required this.block,
    required this.renderContext,
    required this.media,
    this.onPreview,
  });

  final ImageBlockNode block;
  final BlockRenderContext renderContext;
  final Widget media;
  final VoidCallback? onPreview;

  @override
  State<_SelectableImageBlock> createState() => _SelectableImageBlockState();
}

class _SelectableImageBlockState extends State<_SelectableImageBlock> {
  double? _previewToolbarFrameWidth;
  double? _committedToolbarFrameWidth;

  @override
  void didUpdateWidget(covariant _SelectableImageBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.width != widget.block.width ||
        oldWidget.block.height != widget.block.height ||
        oldWidget.block.showWidth != widget.block.showWidth ||
        oldWidget.block.showHeight != widget.block.showHeight ||
        !_objectBlockSelected(widget.block, widget.renderContext) ||
        !_canResizeImageBlock(widget.renderContext)) {
      _previewToolbarFrameWidth = null;
      _committedToolbarFrameWidth = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final rc = widget.renderContext;
    final selected = _objectBlockSelected(block, rc);
    final canResize = _canResizeImageBlock(rc);
    return _withSelectableImageBlock(
      context,
      block,
      rc,
      _ImageBlockContent(
        block: block,
        blockIndex: rc.blockIndex,
        selected: selected,
        canResize: canResize,
        registry: rc.registry,
        onResize: rc.onImageBlockResize,
        onPreviewSizeChanged: _handlePreviewSizeChanged,
        onResizeCommitted: _handleResizeCommitted,
        child: widget.media,
      ),
      onPreview: widget.onPreview,
      toolbarFrameWidth: _previewToolbarFrameWidth ??
          _committedToolbarFrameWidth ??
          _preferredImageFrameWidth(block),
    );
  }

  void _handlePreviewSizeChanged(Size? size) {
    final width = _positiveFiniteDimension(size?.width);
    final current = _previewToolbarFrameWidth;
    if ((current == null && width == null) ||
        (current != null &&
            width != null &&
            (current - width).abs() < _kImageResizeChangeEpsilon)) {
      return;
    }
    if (!mounted) {
      _previewToolbarFrameWidth = width;
      return;
    }
    setState(() {
      _previewToolbarFrameWidth = width;
    });
  }

  void _handleResizeCommitted(Size? size) {
    final width = _positiveFiniteDimension(size?.width);
    final current = _committedToolbarFrameWidth;
    if ((current == null && width == null) ||
        (current != null &&
            width != null &&
            (current - width).abs() < _kImageResizeChangeEpsilon)) {
      return;
    }
    if (!mounted) {
      _committedToolbarFrameWidth = width;
      return;
    }
    setState(() {
      _committedToolbarFrameWidth = width;
    });
  }
}

bool _canResizeImageBlock(BlockRenderContext rc) {
  return rc.canEdit && rc.onImageBlockResize != null;
}

class _SelectableVideoBlock extends StatefulWidget {
  const _SelectableVideoBlock({
    required this.block,
    required this.renderContext,
    required this.media,
    this.onPreview,
  });

  final VideoBlockNode block;
  final BlockRenderContext renderContext;
  final Widget media;
  final VoidCallback? onPreview;

  @override
  State<_SelectableVideoBlock> createState() => _SelectableVideoBlockState();
}

class _SelectableVideoBlockState extends State<_SelectableVideoBlock> {
  double? _previewToolbarFrameWidth;

  @override
  void didUpdateWidget(covariant _SelectableVideoBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.showWidth != widget.block.showWidth ||
        oldWidget.block.showHeight != widget.block.showHeight ||
        !_objectBlockSelected(widget.block, widget.renderContext) ||
        !_canResizeVideoBlock(widget.renderContext)) {
      _previewToolbarFrameWidth = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final rc = widget.renderContext;
    final selected = _objectBlockSelected(block, rc);
    final canResize = _canResizeVideoBlock(rc);
    return _withSelectableVideoBlock(
      block,
      rc,
      _VideoBlockContent(
        block: block,
        blockIndex: rc.blockIndex,
        selected: selected,
        canResize: canResize,
        registry: rc.registry,
        onResize: rc.onImageBlockResize,
        onPreviewSizeChanged: _handlePreviewSizeChanged,
        child: widget.media,
      ),
      onPreview: widget.onPreview,
      toolbarFrameWidth:
          _previewToolbarFrameWidth ?? _preferredVideoFrameWidth(block),
    );
  }

  void _handlePreviewSizeChanged(Size? size) {
    final width = _positiveFiniteDimension(size?.width);
    final current = _previewToolbarFrameWidth;
    if ((current == null && width == null) ||
        (current != null &&
            width != null &&
            (current - width).abs() < _kImageResizeChangeEpsilon)) {
      return;
    }
    if (!mounted) {
      _previewToolbarFrameWidth = width;
      return;
    }
    setState(() {
      _previewToolbarFrameWidth = width;
    });
  }
}

bool _canResizeVideoBlock(BlockRenderContext rc) {
  return rc.canEdit && rc.onImageBlockResize != null;
}

Widget _withSelectableVideoBlock(
  VideoBlockNode block,
  BlockRenderContext rc,
  Widget child, {
  VoidCallback? onPreview,
  double? toolbarFrameWidth,
}) {
  final path = PositionPath.blockObject(block.id);
  final selected = _selectionTouchesPath(
    rc.selection,
    rc.blockIndex,
    block.id,
    path,
    _kAtomicBlockSelectionLength,
  );
  return _withBlockSemantics(
    block,
    MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _MediaBlockChrome(
        blockIndex: rc.blockIndex,
        blockCount: rc.blockCount,
        blockId: block.id,
        selected: selected,
        canEdit: rc.canEdit,
        imageActions: false,
        videoActions: true,
        imageAlignment: block.attributes.alignment,
        toolbarFrameWidth:
            toolbarFrameWidth ?? _preferredVideoFrameWidth(block),
        toolbarFrameAlignment: _imageBlockFigureAlignment(
          block.attributes.alignment,
        ),
        toolbarOverlayController: rc.objectBlockToolbarOverlayController,
        onAction: rc.onObjectBlockAction,
        onPreview: onPreview,
        child: _BlockObjectSelectionSurface(
          blockId: block.id,
          blockIndex: rc.blockIndex,
          path: path,
          selection: rc.selection,
          registry: rc.registry,
          showDebugOverlay: rc.showDebugOverlay,
          showSelectionOverlay: false,
          onDoubleTap: onPreview,
          child: child,
        ),
      ),
    ),
    selected: selected,
  );
}

bool _objectBlockSelected(BlockNode block, BlockRenderContext rc) {
  return _selectionTouchesPath(
    rc.selection,
    rc.blockIndex,
    block.id,
    PositionPath.blockObject(block.id),
    _kAtomicBlockSelectionLength,
  );
}

class _TextBlockRenderer extends StatelessWidget {
  const _TextBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.listMarker,
    this.quoteGroupPosition = QuoteGroupPosition.standalone,
    this.inlineEmbedRenderer,
    this.onToolbarAction,
    this.onColumnResize,
    this.onTodoCheckedChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TextBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final String? listMarker;
  final QuoteGroupPosition quoteGroupPosition;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final TableToolbarActionHandler? onToolbarAction;
  final TableColumnResizeHandler? onColumnResize;
  final TodoCheckedChangeHandler? onTodoCheckedChanged;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final isTodoListItem = block.type == BlockType.listItem &&
        (block.attributes.listType == 'task' ||
            block.attributes.checked != null);
    final showTodoListMarker =
        isTodoListItem && block.attributes.listType == 'ordered';
    final isTaskChecked = block.attributes.checked == true;
    final baseStyle = _blockTextStyle(context, block, textStyle);
    final tokens = EditorTokens.resolve(context);
    final todoStyle =
        isTodoListItem ? _todoTextStyle(baseStyle, tokens) : baseStyle;
    final effectiveStyle = isTodoListItem && isTaskChecked
        ? _completedTodoTextStyle(context, todoStyle)
        : todoStyle;
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockText(block.id),
    );
    final path = PositionPath.blockText(block.id);
    final textLength = inlineNodesLength(block.content);
    final inlineTextLayout = _inlineTextLayoutFor(
      context,
      block.content,
      effectiveStyle,
      compositionRange,
      inlineEmbedRenderer,
      blockId: block.id,
      blockIndex: blockIndex,
      path: path,
    );
    final selected = _selectionRangeForPath(
          selection,
          blockIndex,
          path,
          textLength,
        ) !=
        null;
    final text = _TextSelectionSurface(
      blockId: block.id,
      blockIndex: blockIndex,
      path: path,
      textLength: textLength,
      textSpan: TextSpan(
        style: effectiveStyle,
        children: inlineTextLayout.spans,
      ),
      offsetMapper: inlineTextLayout.offsetMapper,
      textAlign: _textAlign(block.attributes.alignment),
      minHeight: isTodoListItem
          ? _lineHeightFor(effectiveStyle, tokens)
          : (effectiveStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
      selection: selection,
      showCaret: showCaret,
      registry: registry,
      showDebugOverlay: showDebugOverlay,
      findRanges: _findRangesForPath(
        findMatches,
        currentFindMatch,
        blockIndex,
        path,
        textLength,
      ),
    );
    final prefix = listMarker ?? _prefixFor(block);
    final isQuotedBlock = _isQuoteBlock(block);
    Widget quoteSurface(Widget child) {
      if (!isQuotedBlock) {
        return child;
      }
      return _QuoteBlockSurface(
        position: quoteGroupPosition,
        child: child,
      );
    }

    if (isTodoListItem) {
      return _withBlockSemantics(
        block,
        quoteSurface(
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _kTaskListPaddingLeft,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showTodoListMarker && prefix != null) ...<Widget>[
                  SizedBox(
                    key: ValueKey<String>(
                      'wenz-richtext-list-marker-${block.id}',
                    ),
                    width: _kListMarkerWidth,
                    child: Text(
                      prefix,
                      style: effectiveStyle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: _kListMarkerGap),
                ],
                _TodoCheckbox(
                  blockId: block.id,
                  registry: registry,
                  checked: isTaskChecked,
                  onChanged: onTodoCheckedChanged == null
                      ? null
                      : (checked) {
                          onTodoCheckedChanged!(
                            blockIndex: blockIndex,
                            checked: checked,
                          );
                        },
                ),
                const SizedBox(width: _kTodoTextGap),
                Expanded(child: text),
              ],
            ),
          ),
        ),
        selected: selected,
      );
    }
    if (prefix == null) {
      return _withBlockSemantics(
        block,
        quoteSurface(text),
        selected: selected,
      );
    }
    return _withBlockSemantics(
      block,
      quoteSurface(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              key: ValueKey<String>('wenz-richtext-list-marker-${block.id}'),
              width: _kListMarkerWidth,
              child: Text(
                prefix,
                style: effectiveStyle,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: _kListMarkerGap),
            Expanded(child: text),
          ],
        ),
      ),
      selected: selected,
    );
  }
}

class _HeadingCollapseButton extends StatefulWidget {
  const _HeadingCollapseButton({
    required this.blockId,
    required this.state,
    required this.registry,
    required this.onToggled,
  });

  final String blockId;
  final HeadingCollapseState state;
  final BlockGeometryRegistry registry;
  final ValueChanged<String>? onToggled;

  @override
  State<_HeadingCollapseButton> createState() => _HeadingCollapseButtonState();
}

class _HeadingCollapseButtonState extends State<_HeadingCollapseButton> {
  final GlobalKey _hitTestKey = GlobalKey();
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'Wenz heading collapse button',
  );

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_hitTestKey);
  }

  @override
  void didUpdateWidget(covariant _HeadingCollapseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_hitTestKey);
      widget.registry.registerSelectionExclusion(_hitTestKey);
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    _focusNode.requestFocus();
    widget.onToggled?.call(widget.blockId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.state.canCollapse) {
        _focusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.state.canCollapse ||
        widget.onToggled == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _toggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.state.canCollapse && widget.onToggled != null;
    final overlay = scheme.primary.withAlpha(22);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: SizedBox(
        key: _hitTestKey,
        width: _kHeadingCollapseSlotWidth,
        height: _kHeadingCollapseButtonSize,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleKeyEvent,
            child: IconButton(
              key: ValueKey<String>(
                'wenz-richtext-heading-collapse-${widget.blockId}',
              ),
              focusNode: _focusNode,
              tooltip: _headingCollapseTooltip(widget.state),
              onPressed: enabled ? _toggle : null,
              iconSize: _kHeadingCollapseIconSize,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: _kHeadingCollapseButtonSize,
                height: _kHeadingCollapseButtonSize,
              ),
              visualDensity: VisualDensity.compact,
              splashRadius: _kHeadingCollapseButtonSize / 2,
              color: scheme.onSurfaceVariant,
              disabledColor: scheme.outline.withAlpha(110),
              focusColor: overlay,
              hoverColor: overlay,
              highlightColor: scheme.primary.withAlpha(34),
              icon: _HeadingCollapseGlyph(
                state: widget.state,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadingCollapseGlyph extends StatelessWidget {
  const _HeadingCollapseGlyph({
    required this.state,
  });

  final HeadingCollapseState state;

  @override
  Widget build(BuildContext context) {
    final icon = state.isCollapsed
        ? Icons.keyboard_arrow_right_rounded
        : Icons.keyboard_arrow_down_rounded;
    return SizedBox.square(
      dimension: _kHeadingCollapseIconSize,
      child: Icon(icon),
    );
  }
}

String _headingCollapseTooltip(HeadingCollapseState state) {
  if (!state.canCollapse) {
    return '无可折叠内容';
  }
  if (state.isCollapsed) {
    return '展开标题内容（${state.hiddenBlockCount} 个块已隐藏）';
  }
  return '折叠标题内容（${state.hiddenBlockCount} 个块）';
}

class _TodoCheckbox extends StatefulWidget {
  const _TodoCheckbox({
    required this.blockId,
    required this.registry,
    required this.checked,
    required this.onChanged,
  });

  final String blockId;
  final BlockGeometryRegistry registry;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  State<_TodoCheckbox> createState() => _TodoCheckboxState();
}

class _TodoCheckboxState extends State<_TodoCheckbox> {
  final GlobalKey _hitTestKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_hitTestKey);
  }

  @override
  void didUpdateWidget(covariant _TodoCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_hitTestKey);
      widget.registry.registerSelectionExclusion(_hitTestKey);
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    return MouseRegion(
      cursor: widget.onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: SizedBox(
        key: _hitTestKey,
        width: tokens.todoCheckboxWidth,
        height: tokens.todoCheckboxHeight,
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: Checkbox(
            key: ValueKey<String>(
                'wenz-richtext-todo-checkbox-${widget.blockId}'),
            value: widget.checked,
            onChanged: widget.onChanged == null
                ? null
                : (value) => widget.onChanged!(value ?? false),
            activeColor: theme.colorScheme.primary,
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered)) {
                return Colors.transparent;
              }
              return null;
            }),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

/// Paint-only background for a quoted text block.
///
/// Visual elements: a `surfaceContainer` fill, a 4px `primary` accent bar on
/// the start edge (running the full block height), end-side rounded corners
/// that redistribute by [QuoteGroupPosition] (start edge stays square so the
/// accent bar seats flush and neighbours join without a seam), and a content
/// inset of `EdgeInsetsDirectional.fromSTEB(22, top, 18, bottom)` whose
/// vertical halves redistribute by group position — outer edges of a run keep
/// the original 8px while inner edges tighten to 4px so fused paragraphs share
/// a uniform 8px line gap.
///
/// This surface is decoration only: selection, caret, composition, hit-testing
/// geometry, and find highlights all live in the inner `_TextSelectionSurface`
/// (`child`), not here. See "Consecutive quoted text block background" in
/// `docs/rendering.md` for the contract by which index-adjacent quoted blocks
/// fuse into one continuous background — corners, vertical padding, and the
/// accent bar redistribute by group position (first / interior / last) while
/// the start edge stays square so neighbours join without a seam. Joined edges
/// intentionally overpaint by a physical-pixel-sized logical inset; this keeps
/// the run visually solid even when virtual-list offsets land on fractional
/// pixels or the backend snaps two adjacent block layers differently.
class _QuoteBlockSurface extends StatelessWidget {
  const _QuoteBlockSurface({
    required this.child,
    this.position = QuoteGroupPosition.standalone,
  });

  final Widget child;

  /// Group position controlling corner rounding and inner vertical padding so
  /// consecutive quote surfaces fuse into one continuous background.
  final QuoteGroupPosition position;

  /// End-side corner radius kept on a standalone quote and on the outer edge
  /// of a run's top/bottom blocks.
  static const Radius _endRadius = Radius.circular(8);

  /// Vertical inset on the outer edge of a fused run — the top of the run's
  /// first block and the bottom of its last block — matching the original
  /// standalone quote breathing room.
  static const double _outerVerticalPadding = 8.0;

  /// Vertical inset where a quote fuses with a neighbour. Two abutting
  /// `_innerVerticalPadding` halves meet across the collapsed inter-quote gap
  /// and sum to [_outerVerticalPadding], so stacked paragraphs read as one
  /// continuous surface with uniform line spacing and no doubled whitespace.
  static const double _innerVerticalPadding = 4.0;

  /// A tiny visual-only overlap on joined edges. The block's measured height,
  /// hit-test geometry, and semantics stay unchanged, but the background and
  /// accent bar extend into the neighbouring quote by this amount to cover
  /// subpixel seams.
  static const double _seamOverlap = 1.0;

  /// Top inset: full [_outerVerticalPadding] on a standalone quote and on the
  /// first block of a run; tightened to [_innerVerticalPadding] otherwise so
  /// the block joins the quote below without a doubled gap.
  double get _topPadding => position == QuoteGroupPosition.standalone ||
          position == QuoteGroupPosition.first
      ? _outerVerticalPadding
      : _innerVerticalPadding;

  /// Bottom inset: full [_outerVerticalPadding] on a standalone quote and on
  /// the last block of a run; tightened to [_innerVerticalPadding] otherwise
  /// so the block joins the quote above without a doubled gap.
  double get _bottomPadding => position == QuoteGroupPosition.standalone ||
          position == QuoteGroupPosition.last
      ? _outerVerticalPadding
      : _innerVerticalPadding;

  BorderRadiusDirectional get _borderRadius {
    final topEnd = position == QuoteGroupPosition.standalone ||
            position == QuoteGroupPosition.first
        ? _endRadius
        : Radius.zero;
    final bottomEnd = position == QuoteGroupPosition.standalone ||
            position == QuoteGroupPosition.last
        ? _endRadius
        : Radius.zero;
    return BorderRadiusDirectional.only(
      topEnd: topEnd,
      bottomEnd: bottomEnd,
    );
  }

  bool get _joinsPrevious =>
      position == QuoteGroupPosition.interior ||
      position == QuoteGroupPosition.last;

  bool get _joinsNext =>
      position == QuoteGroupPosition.first ||
      position == QuoteGroupPosition.interior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topPadding = _topPadding;
    final bottomPadding = _bottomPadding;
    final borderRadius = _borderRadius;
    return LayoutBuilder(
      builder: (context, constraints) {
        final quote = DecoratedBox(
          key: const ValueKey<String>('wenz-richtext-quote-background'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: borderRadius,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (_joinsPrevious) ...<Widget>[
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  top: -_seamOverlap,
                  height: _seamOverlap,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  top: -_seamOverlap,
                  width: 4,
                  height: _seamOverlap,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (_joinsNext) ...<Widget>[
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: -_seamOverlap,
                  height: _seamOverlap,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  bottom: -_seamOverlap,
                  width: 4,
                  height: _seamOverlap,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  key: const ValueKey<String>('wenz-richtext-quote-accent'),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  22,
                  topPadding,
                  18,
                  bottomPadding,
                ),
                child: constraints.maxWidth.isFinite
                    ? SizedBox(width: double.infinity, child: child)
                    : child,
              ),
            ],
          ),
        );
        return constraints.maxWidth.isFinite
            ? SizedBox(width: constraints.maxWidth, child: quote)
            : quote;
      },
    );
  }
}

class _CodeBlockRenderer extends StatelessWidget {
  const _CodeBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.showDebugOverlay = false,
    this.onLanguageChanged,
    this.onCodeCopied,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final CodeBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool showDebugOverlay;
  final ValueChanged<String>? onLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final codeBlockBackground = _codeBlockBackgroundColor(theme);
    final codeBlockText = _codeBlockTextColor(theme);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
          color: codeBlockText,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const <String>[
            'Fira Code',
            'Consolas',
            'monospace',
          ],
          fontSize: tokens.codeBlockFontSize,
          height: _kCodeBlockLineHeight,
        ) ??
        TextStyle(
          color: codeBlockText,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const <String>[
            'Fira Code',
            'Consolas',
            'monospace',
          ],
          fontSize: tokens.codeBlockFontSize,
          height: _kCodeBlockLineHeight,
        );
    final compositionRange = _localCompositionRange(
      compositionState,
      block.id,
      blockIndex,
      PositionPath.blockCode(block.id),
    );
    final path = PositionPath.blockCode(block.id);
    final selected = _selectionTouchesPath(
      selection,
      blockIndex,
      block.id,
      path,
      block.code.length,
    );
    final codeSpan = _codeSpan(
      block.code,
      block.language,
      codeStyle,
      compositionRange,
    );
    final lineNumberStyle = codeStyle.copyWith(
      color: const Color(WenzCodeBlockLineNumbers.color),
      fontFamily: WenzCodeBlockLineNumbers.fontFamily,
      fontSize: WenzCodeBlockLineNumbers.fontSize,
      height: WenzCodeBlockLineNumbers.lineHeight,
    );
    final lineNumberLabels = WenzCodeBlockLineNumbers.labelsForCode(block.code);
    final lineNumberText = lineNumberLabels.join('\n');
    return _withBlockSemantics(
      block,
      DecoratedBox(
        key: ValueKey<String>('wenz-richtext-code-block-${block.id}'),
        decoration: BoxDecoration(
          color: codeBlockBackground,
          border: selected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : Border.all(color: _codeBlockBorderColor(theme)),
          borderRadius: BorderRadius.circular(_kCodeBlockRadius),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.codeBlockPaddingHorizontal,
            vertical: _kCodeBlockPaddingVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CodeBlockToolbar(
                blockId: block.id,
                language: block.language,
                onLanguageChanged: onLanguageChanged,
                onCopyPressed: onCodeCopied == null
                    ? null
                    : () {
                        unawaited(onCodeCopied!(block.code));
                      },
              ),
              const SizedBox(height: _kCodeBlockHeaderGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textDirection = Directionality.of(context);
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width;
                  final lineNumberDigits =
                      WenzCodeBlockLineNumbers.maxLabelDigits(block.code);
                  final lineNumberWidth = _measureInlineSpanWidth(
                        TextSpan(
                          text: '8' * lineNumberDigits,
                          style: lineNumberStyle,
                        ),
                        textDirection,
                      ) +
                      1;
                  final effectiveLineNumberWidth = math.min(
                    lineNumberWidth,
                    availableWidth,
                  );
                  final effectiveLineNumberGap = math.min(
                    WenzCodeBlockLineNumbers.gapToCode,
                    math.max(0.0, availableWidth - effectiveLineNumberWidth),
                  );
                  final scrollViewportWidth = math.max(
                    0.0,
                    availableWidth -
                        effectiveLineNumberWidth -
                        effectiveLineNumberGap,
                  );
                  final contentWidth = math.max(
                    scrollViewportWidth,
                    _measureInlineSpanWidth(codeSpan, textDirection) + 1,
                  );
                  final minHeight =
                      (codeStyle.fontSize ?? tokens.codeBlockFontSize) *
                          _kBlockMinHeightFactor;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _CodeLineNumberGutter(
                        blockId: block.id,
                        registry: registry,
                        width: effectiveLineNumberWidth,
                        minHeight: minHeight,
                        text: lineNumberText,
                        style: lineNumberStyle,
                      ),
                      SizedBox(width: effectiveLineNumberGap),
                      Expanded(
                        child: _CodeScrollableTextSurface(
                          blockId: block.id,
                          blockIndex: blockIndex,
                          path: path,
                          codeLength: block.code.length,
                          codeSpan: codeSpan,
                          contentWidth: contentWidth,
                          minHeight: minHeight,
                          selection: selection,
                          showCaret: showCaret,
                          registry: registry,
                          showDebugOverlay: showDebugOverlay,
                          findRanges: _findRangesForPath(
                            findMatches,
                            currentFindMatch,
                            blockIndex,
                            path,
                            block.code.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      selected: selected,
    );
  }
}

class _CodeLineNumberGutter extends StatefulWidget {
  const _CodeLineNumberGutter({
    required this.blockId,
    required this.registry,
    required this.width,
    required this.minHeight,
    required this.text,
    required this.style,
  });

  final String blockId;
  final BlockGeometryRegistry registry;
  final double width;
  final double minHeight;
  final String text;
  final TextStyle style;

  @override
  State<_CodeLineNumberGutter> createState() => _CodeLineNumberGutterState();
}

class _CodeLineNumberGutterState extends State<_CodeLineNumberGutter> {
  final GlobalKey _gutterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_gutterKey);
  }

  @override
  void didUpdateWidget(covariant _CodeLineNumberGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_gutterKey);
      widget.registry.registerSelectionExclusion(_gutterKey);
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterSelectionExclusion(_gutterKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: _gutterKey,
      constraints: BoxConstraints(
        minHeight: widget.minHeight,
        minWidth: widget.width,
        maxWidth: widget.width,
      ),
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Text(
          widget.text,
          key: ValueKey<String>(
            'wenz-richtext-code-line-numbers-${widget.blockId}',
          ),
          textAlign: WenzCodeBlockLineNumbers.gutterTextAlign,
          style: widget.style,
          strutStyle: StrutStyle.fromTextStyle(
            widget.style,
            forceStrutHeight: true,
          ),
        ),
      ),
    );
  }
}

class _CodeScrollableTextSurface extends StatefulWidget {
  const _CodeScrollableTextSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.codeLength,
    required this.codeSpan,
    required this.contentWidth,
    required this.minHeight,
    required this.selection,
    required this.showCaret,
    required this.registry,
    required this.showDebugOverlay,
    required this.findRanges,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int codeLength;
  final InlineSpan codeSpan;
  final double contentWidth;
  final double minHeight;
  final DocumentSelection? selection;
  final bool showCaret;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;
  final List<_FindHighlightRange> findRanges;

  @override
  State<_CodeScrollableTextSurface> createState() =>
      _CodeScrollableTextSurfaceState();
}

class _CodeScrollableTextSurfaceState
    extends State<_CodeScrollableTextSurface> {
  final GlobalKey _viewportKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _viewportKey,
      child: SingleChildScrollView(
        key: ValueKey<String>('wenz-richtext-code-scroll-${widget.blockId}'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widget.contentWidth,
          child: _TextSelectionSurface(
            blockId: widget.blockId,
            blockIndex: widget.blockIndex,
            path: widget.path,
            textLength: widget.codeLength,
            textSpan: widget.codeSpan,
            offsetMapper: _InlineOffsetMapper.identity(widget.codeLength),
            textAlign: TextAlign.start,
            minHeight: widget.minHeight,
            selection: widget.selection,
            showCaret: widget.showCaret,
            registry: widget.registry,
            showDebugOverlay: widget.showDebugOverlay,
            selectionHighlightColor: const Color(
              _kCodeBlockSelectionHighlightColor,
            ),
            findRanges: widget.findRanges,
            hitTestKey: _viewportKey,
            clampHitTestToVisibleBounds: true,
          ),
        ),
      ),
    );
  }
}

double _measureInlineSpanWidth(InlineSpan span, TextDirection textDirection) {
  final painter = TextPainter(
    text: span,
    textDirection: textDirection,
  )..layout(maxWidth: double.infinity);
  final width = painter.width;
  painter.dispose();
  return width.isFinite ? width : 0;
}

class _BlockFloatingToolbarSurface extends StatelessWidget {
  const _BlockFloatingToolbarSurface({
    required this.child,
    this.toolbar,
  });

  final Widget child;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    final toolbar = this.toolbar;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxToolbarWidth = constraints.maxWidth.isFinite
            ? math.max(0.0, constraints.maxWidth)
            : double.infinity;
        final constrainedChild = _constrainChildWidth(maxToolbarWidth, child);
        if (toolbar == null) {
          return constrainedChild;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxToolbarWidth),
              child: toolbar,
            ),
            const SizedBox(height: _kBlockFloatingToolbarInset),
            constrainedChild,
          ],
        );
      },
    );
  }

  Widget _constrainChildWidth(double width, Widget child) {
    if (!width.isFinite || width <= 0) {
      return child;
    }
    return SizedBox(width: width, child: child);
  }
}

class _CodeBlockToolbar extends StatelessWidget {
  const _CodeBlockToolbar({
    required this.blockId,
    required this.language,
    this.onLanguageChanged,
    this.onCopyPressed,
  });

  final String blockId;
  final String language;
  final ValueChanged<String>? onLanguageChanged;
  final VoidCallback? onCopyPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final accentColor = _codeBlockAccentColor(theme);
    final mermaidControls = MermaidCodeBlockSourceControls.maybeOf(context);
    final languages = _codeLanguageOptions(language);
    final current = languages.contains(language) ? language : '';
    final languageTag = _CodeLanguageTag(
      label: _codeLanguageLabel(language),
      accentColor: accentColor,
    );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: _kCodeBlockHeaderHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _kCodeBlockHeaderPaddingHorizontal,
            end: _kCodeBlockHeaderToolbarEndPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final constrainedTag = ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: languageTag,
                    );
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: onLanguageChanged == null
                          ? constrainedTag
                          : PopupMenuButton<String>(
                              tooltip: '切换代码语言',
                              padding: EdgeInsets.zero,
                              color: _popupMenuColor(theme),
                              elevation: _kPopupMenuElevation,
                              shadowColor: _popupMenuShadowColor(theme),
                              surfaceTintColor: Colors.transparent,
                              shape: _popupMenuShape(theme),
                              menuPadding: _kPopupMenuPadding,
                              position: PopupMenuPosition.under,
                              clipBehavior: Clip.antiAlias,
                              onSelected: onLanguageChanged,
                              routeSettings: _kPopupMenuRouteSettings,
                              itemBuilder: (context) =>
                                  <PopupMenuEntry<String>>[
                                for (final option in languages)
                                  PopupMenuItem<String>(
                                    value: option,
                                    enabled: option != current,
                                    height: _kPopupMenuItemHeight,
                                    padding: _kPopupMenuItemPadding,
                                    child: _PopupMenuItemContent(
                                      icon: Icons.code,
                                      label: _codeLanguageLabel(option),
                                      enabled: option != current,
                                      selected: option == current,
                                    ),
                                  ),
                              ],
                              child: constrainedTag,
                            ),
                    );
                  },
                ),
              ),
              IconButton(
                key: ValueKey<String>('wenz-richtext-code-copy-$blockId'),
                tooltip: '复制代码内容',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: tokens.minimalToolbarButtonSize,
                  height: tokens.minimalToolbarButtonSize,
                ),
                iconSize: tokens.minimalToolbarIconSize,
                style: _blockToolbarIconButtonStyle(
                  theme,
                  tokens: tokens,
                  foregroundColor: accentColor,
                  disabledForegroundColor: accentColor.withAlpha(
                    _kMinimalToolbarDisabledAlpha,
                  ),
                ),
                onPressed: onCopyPressed,
                icon: const Icon(Icons.copy, semanticLabel: '复制代码内容'),
              ),
              if (mermaidControls != null)
                IconButton(
                  key: const ValueKey<String>('wenz-richtext-mermaid-toggle'),
                  tooltip: '预览 Mermaid 图表',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: tokens.minimalToolbarButtonSize,
                    height: tokens.minimalToolbarButtonSize,
                  ),
                  iconSize: tokens.minimalToolbarIconSize,
                  style: _blockToolbarIconButtonStyle(
                    theme,
                    tokens: tokens,
                    foregroundColor: accentColor,
                    disabledForegroundColor: accentColor.withAlpha(
                      _kMinimalToolbarDisabledAlpha,
                    ),
                  ),
                  onPressed: mermaidControls.onPreview,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    semanticLabel: '预览 Mermaid 图表',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeLanguageTag extends StatelessWidget {
  const _CodeLanguageTag({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ) ??
        TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accentColor.withAlpha(22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accentColor.withAlpha(54)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _TableBlockRenderer extends StatelessWidget {
  const _TableBlockRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    this.showDebugOverlay = false,
    this.inlineEmbedRenderer,
    this.onToolbarAction,
    this.toolbarOverlayController,
    this.onColumnResize,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TableBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final TableToolbarActionHandler? onToolbarAction;
  final TableFloatingToolbarOverlayController? toolbarOverlayController;
  final TableColumnResizeHandler? onColumnResize;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final table = block.table;
    final columnCount = table.columnCount;
    if (table.rowCount == 0 || columnCount == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final tableTextStyle =
        effectiveStyle.copyWith(fontSize: _kTableCellFontSize);
    final tableBorderColor = _tableBorderColor(theme);
    final currentSelection = selection;
    return _withBlockSemantics(
      block,
      LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          final metrics = _tableGridMetricsCache.resolve(
            table: table,
            maxWidth: _tableMaxWidth(constraints, columnCount),
            textStyle: tableTextStyle,
            textDirection: direction,
            tableCellPadding: tokens.tableCellPadding,
          );
          final tableSelectionRect = currentSelection == null
              ? null
              : _selectionRectForTableCells(
                  context: context,
                  gridMetrics: metrics,
                  table: table,
                  tableBlockId: block.id,
                  blockIndex: blockIndex,
                  selection: currentSelection,
                  textStyle: tableTextStyle,
                  textDirection: direction,
                  inlineEmbedRenderer: inlineEmbedRenderer,
                );
          final activeRange = _activeTableRange(
            currentSelection,
            block,
            blockIndex,
          );
          final stackWidth = metrics.width;
          final resizeHeight = metrics.height;
          final tableSurface = SizedBox(
            width: stackWidth,
            height: metrics.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(_kTableSurfaceRadius),
                      boxShadow: _kSurfaceBoxShadow,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(_kTableSurfaceRadius),
                  child: SizedBox(
                    width: stackWidth,
                    height: metrics.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        for (final cell in metrics.cells)
                          Positioned(
                            left: cell.left,
                            top: cell.top,
                            width: cell.width,
                            height: cell.height,
                            child: DecoratedBox(
                              key: ValueKey<String>(
                                'table-cell-border-${block.id}-${cell.rowIndex}-${cell.columnIndex}',
                              ),
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: _tableCellBorder(
                                  cell: cell,
                                  rowCount: table.rowCount,
                                  columnCount: columnCount,
                                  color: tableBorderColor,
                                ),
                              ),
                              child: _TableCellSurface(
                                tableBlock: block,
                                blockIndex: blockIndex,
                                rowIndex: cell.rowIndex,
                                columnIndex: cell.columnIndex,
                                cell: cell.cell,
                                textStyle: tableTextStyle,
                                textAlign: _textAlign(
                                  cell.cell.alignment ??
                                      table.columnAlignments[cell.columnIndex],
                                ),
                                selection: currentSelection,
                                compositionState: compositionState,
                                registry: registry,
                                showCaret: showCaret,
                                highlightWholeCell: _shouldHighlightTableCell(
                                  currentSelection,
                                  block.id,
                                  blockIndex,
                                  cell.rowIndex,
                                  cell.columnIndex,
                                  gridMetrics: metrics,
                                  tableSelectionRect: tableSelectionRect,
                                ),
                                showDebugOverlay: showDebugOverlay,
                                inlineEmbedRenderer: inlineEmbedRenderer,
                                findMatches: findMatches,
                                currentFindMatch: currentFindMatch,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (activeRange != null &&
                    onColumnResize != null &&
                    resizeHeight > 0)
                  for (final resizeSegment in metrics.columnResizeSegments)
                    Positioned(
                      left: resizeSegment.left - (_kTableResizeHandleWidth / 2),
                      top: resizeSegment.top,
                      width: _kTableResizeHandleWidth,
                      height: resizeSegment.height,
                      child: _TableColumnResizeHandle(
                        key: ValueKey<String>(
                          resizeSegment.keyFor(block.id),
                        ),
                        columnIndex: resizeSegment.columnIndex,
                        width: metrics.columnWidths[resizeSegment.columnIndex],
                        onResize: (width) {
                          onColumnResize!(
                            blockIndex: blockIndex,
                            columnIndex: resizeSegment.columnIndex,
                            width: width,
                          );
                        },
                      ),
                    ),
              ],
            ),
          );
          return Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: TableFloatingToolbarOverlayAnchor(
              controller: toolbarOverlayController,
              requestBuilder: activeRange != null && onToolbarAction != null
                  ? ({
                      required Object owner,
                      required LayerLink anchorLink,
                      required Rect anchorRect,
                      required double visibleTop,
                      required double visibleBottom,
                    }) =>
                      TableFloatingToolbarOverlayRequest(
                        owner: owner,
                        anchorLink: anchorLink,
                        anchorRect: anchorRect,
                        visibleTop: visibleTop,
                        visibleBottom: visibleBottom,
                        tableBlockId: block.id,
                        blockIndex: blockIndex,
                        selectionRange: activeRange,
                        minWidth: _kTableFloatingToolbarEstimatedWidth,
                        gap: _kTableFloatingToolbarGap,
                        fallbackHeight: _kTableFloatingToolbarEstimatedHeight,
                        toolbarBuilder: (context) => _TableFloatingToolbar(
                          block: block,
                          blockIndex: blockIndex,
                          range: activeRange,
                          onAction: onToolbarAction!,
                        ),
                      )
                  : null,
              tableBlockId: block.id,
              blockIndex: blockIndex,
              child: tableSurface,
            ),
          );
        },
      ),
    );
  }
}

TableCellRange? _activeTableRange(
  DocumentSelection? selection,
  TableBlockNode tableBlock,
  int blockIndex,
) {
  final range = selection?.tableCellRange;
  if (range == null ||
      range.tableBlockId != tableBlock.id ||
      range.blockIndex != blockIndex) {
    return null;
  }
  final rowCount = tableBlock.table.rowCount;
  final columnCount = tableBlock.table.columnCount;
  if (rowCount == 0 || columnCount == 0) {
    return null;
  }
  return TableCellRange(
    tableBlockId: tableBlock.id,
    blockIndex: blockIndex,
    startRow: range.startRow.clamp(0, rowCount - 1).toInt(),
    endRow: range.endRow.clamp(0, rowCount - 1).toInt(),
    startColumn: range.startColumn.clamp(0, columnCount - 1).toInt(),
    endColumn: range.endColumn.clamp(0, columnCount - 1).toInt(),
  );
}

class _TableFloatingToolbar extends StatelessWidget {
  const _TableFloatingToolbar({
    required this.block,
    required this.blockIndex,
    required this.range,
    required this.onAction,
  });

  final TableBlockNode block;
  final int blockIndex;
  final TableCellRange range;
  final TableToolbarActionHandler onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final state = _TableToolbarState.resolve(block, range);
    return _MinimalFloatingToolbarSurface(
      key: const ValueKey<String>('table-floating-toolbar'),
      child: Wrap(
        spacing: _kMinimalFloatingToolbarButtonGap,
        runSpacing: _kMinimalFloatingToolbarButtonGap,
        children: <Widget>[
          _button(
            theme: theme,
            tokens: tokens,
            icon: WenzLucideToolbarIcons.tableRowInsertBelow,
            tooltip: '在下方插入行',
            action: TableToolbarAction.insertRowBelow,
          ),
          _button(
            theme: theme,
            tokens: tokens,
            icon: WenzLucideToolbarIcons.tableColumnInsertAfter,
            tooltip: '在右侧插入列',
            action: TableToolbarAction.insertColumnAfter,
          ),
          _divider(theme, tokens),
          if (state.canSplit)
            _button(
              theme: theme,
              tokens: tokens,
              icon: WenzLucideToolbarIcons.tableSplit,
              tooltip: '拆分单元格',
              action: TableToolbarAction.splitCell,
            )
          else
            _button(
              theme: theme,
              tokens: tokens,
              icon: WenzLucideToolbarIcons.tableMerge,
              tooltip: '合并所选单元格',
              action: TableToolbarAction.mergeCells,
              enabled: state.canMerge,
            ),
          _divider(theme, tokens),
          _menuButton(
            context,
            icon: WenzLucideToolbarIcons.tableSelectRow,
            tooltip: '行操作',
            entriesBuilder: () => _rowItems(state, includeSelection: true),
          ),
          _menuButton(
            context,
            icon: WenzLucideToolbarIcons.tableSelectColumn,
            tooltip: '列操作',
            entriesBuilder: () => _columnItems(
              state,
              includeSelection: true,
            ),
          ),
          _menuButton(
            context,
            icon: WenzLucideToolbarIcons.tableCellStyle,
            tooltip: '单元格样式',
            entriesBuilder: () => _cellItems(state),
          ),
          _menuButton(
            context,
            icon: WenzLucideToolbarIcons.table,
            tooltip: '整表操作',
            entriesBuilder: () => _tableItems(state),
          ),
          _moreButton(context, state: state),
        ],
      ),
    );
  }

  Widget _moreButton(
    BuildContext context, {
    required _TableToolbarState state,
  }) {
    return _menuButton(
      context,
      icon: WenzLucideToolbarIcons.tableMore,
      tooltip: '更多表格操作',
      entriesBuilder: () => _moreItems(state),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String icon,
    required String tooltip,
    required List<PopupMenuEntry<_TableToolbarSelection>> Function()
        entriesBuilder,
  }) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    return PopupMenuButton<_TableToolbarSelection>(
      tooltip: tooltip,
      icon: WenzLucideToolbarIcon(icon),
      iconSize: tokens.minimalToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme, tokens: tokens),
      color: _popupMenuColor(theme),
      elevation: _kPopupMenuElevation,
      shadowColor: _popupMenuShadowColor(theme),
      surfaceTintColor: Colors.transparent,
      shape: _popupMenuShape(theme),
      menuPadding: _kPopupMenuPadding,
      position: PopupMenuPosition.under,
      clipBehavior: Clip.antiAlias,
      onSelected: _dispatchSelection,
      routeSettings: _kPopupMenuRouteSettings,
      itemBuilder: (context) => entriesBuilder(),
    );
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _moreItems(
    _TableToolbarState state,
  ) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      _section('行操作'),
      ..._rowItems(state),
      _popupMenuDivider<_TableToolbarSelection>(),
      _section('列操作'),
      ..._columnItems(state),
      _popupMenuDivider<_TableToolbarSelection>(),
      _section('单元格样式'),
      ..._cellItems(state),
      _popupMenuDivider<_TableToolbarSelection>(),
      _section('选择范围'),
      ..._selectionItems(state),
      _popupMenuDivider<_TableToolbarSelection>(),
      _section('整表操作'),
      ..._tableItems(state, includeSelectTable: false),
    ];
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _rowItems(
    _TableToolbarState state, {
    bool includeSelection = false,
  }) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      _item(
        action: TableToolbarAction.insertRowAbove,
        icon: WenzLucideToolbarIcons.tableRowInsertAbove,
        label: '在上方插入行',
      ),
      _item(
        action: TableToolbarAction.insertRowBelow,
        icon: WenzLucideToolbarIcons.tableRowInsertBelow,
        label: '在下方插入行',
      ),
      if (includeSelection)
        _item(
          action: TableToolbarAction.selectRow,
          icon: WenzLucideToolbarIcons.tableSelectRow,
          label: '选择整行',
          selected: state.rowSelected,
        ),
      _item(
        action: TableToolbarAction.deleteRow,
        icon: WenzLucideToolbarIcons.tableRowDelete,
        label: '删除行',
        enabled: state.canDeleteRow,
        destructive: true,
      ),
    ];
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _columnItems(
    _TableToolbarState state, {
    bool includeSelection = false,
  }) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      _item(
        action: TableToolbarAction.insertColumnBefore,
        icon: WenzLucideToolbarIcons.tableColumnInsertBefore,
        label: '在左侧插入列',
      ),
      _item(
        action: TableToolbarAction.insertColumnAfter,
        icon: WenzLucideToolbarIcons.tableColumnInsertAfter,
        label: '在右侧插入列',
      ),
      if (includeSelection)
        _item(
          action: TableToolbarAction.selectColumn,
          icon: WenzLucideToolbarIcons.tableSelectColumn,
          label: '选择整列',
          selected: state.columnSelected,
        ),
      _item(
        action: TableToolbarAction.deleteColumn,
        icon: WenzLucideToolbarIcons.tableColumnDelete,
        label: '删除列',
        enabled: state.canDeleteColumn,
        destructive: true,
      ),
      _item(
        action: TableToolbarAction.resetColumnWidth,
        icon: WenzLucideToolbarIcons.tableColumnWidthReset,
        label: '重置列宽',
        enabled: state.canResetColumnWidth,
      ),
    ];
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _cellItems(
    _TableToolbarState state,
  ) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      _item(
        action: TableToolbarAction.toggleHeader,
        icon: WenzLucideToolbarIcons.tableHeaderToggle,
        label: '切换表头单元格',
        enabled: state.canStyleCells,
        selected: state.headerSelected,
      ),
      _item(
        action: TableToolbarAction.setBackgroundColor,
        icon: WenzLucideToolbarIcons.tableBackgroundFill,
        label: '设置单元格背景',
        backgroundColor: _kTableToolbarBackgroundColor,
        enabled: state.canStyleCells,
        selected: state.backgroundSelected,
      ),
      _item(
        action: TableToolbarAction.clearBackgroundColor,
        icon: WenzLucideToolbarIcons.tableBackgroundClear,
        label: '清除单元格背景',
        enabled: state.canClearBackground,
      ),
      _item(
        action: TableToolbarAction.alignLeft,
        icon: WenzLucideToolbarIcons.tableCellAlignLeft,
        label: '单元格左对齐',
        enabled: state.canStyleCells,
        selected: state.alignment == 'left',
      ),
      _item(
        action: TableToolbarAction.alignCenter,
        icon: WenzLucideToolbarIcons.tableCellAlignCenter,
        label: '单元格居中对齐',
        enabled: state.canStyleCells,
        selected: state.alignment == 'center',
      ),
      _item(
        action: TableToolbarAction.alignRight,
        icon: WenzLucideToolbarIcons.tableCellAlignRight,
        label: '单元格右对齐',
        enabled: state.canStyleCells,
        selected: state.alignment == 'right',
      ),
      _item(
        action: TableToolbarAction.clearAlignment,
        icon: WenzLucideToolbarIcons.tableCellAlignClear,
        label: '清除单元格对齐',
        enabled: state.canClearAlignment,
      ),
      _item(
        action: TableToolbarAction.mergeCells,
        icon: WenzLucideToolbarIcons.tableMerge,
        label: '合并所选单元格',
        enabled: state.canMerge,
      ),
      _item(
        action: TableToolbarAction.splitCell,
        icon: WenzLucideToolbarIcons.tableSplit,
        label: '拆分单元格',
        enabled: state.canSplit,
      ),
    ];
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _selectionItems(
    _TableToolbarState state,
  ) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      _item(
        action: TableToolbarAction.selectRow,
        icon: WenzLucideToolbarIcons.tableSelectRow,
        label: '选择整行',
        selected: state.rowSelected,
      ),
      _item(
        action: TableToolbarAction.selectColumn,
        icon: WenzLucideToolbarIcons.tableSelectColumn,
        label: '选择整列',
        selected: state.columnSelected,
      ),
      _item(
        action: TableToolbarAction.selectTable,
        icon: WenzLucideToolbarIcons.tableSelect,
        label: '选择整表',
        selected: state.tableSelected,
      ),
    ];
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _tableItems(
    _TableToolbarState state, {
    bool includeSelectTable = true,
  }) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      if (includeSelectTable)
        _item(
          action: TableToolbarAction.selectTable,
          icon: WenzLucideToolbarIcons.tableSelect,
          label: '选择整表',
          selected: state.tableSelected,
        ),
      _item(
        action: TableToolbarAction.deleteTable,
        icon: WenzLucideToolbarIcons.tableDelete,
        label: '删除整表',
        destructive: true,
      ),
    ];
  }

  PopupMenuEntry<_TableToolbarSelection> _section(String label) {
    return PopupMenuItem<_TableToolbarSelection>(
      enabled: false,
      height: _kPopupMenuSectionHeaderHeight,
      padding: _kPopupMenuItemPadding,
      child: _PopupMenuSectionHeader(label: label),
    );
  }

  PopupMenuItem<_TableToolbarSelection> _item({
    required TableToolbarAction action,
    required String icon,
    required String label,
    bool enabled = true,
    bool selected = false,
    bool destructive = false,
    int? backgroundColor,
  }) {
    return PopupMenuItem<_TableToolbarSelection>(
      value: _TableToolbarSelection(action, backgroundColor: backgroundColor),
      enabled: enabled,
      height: _kPopupMenuItemHeight,
      padding: _kPopupMenuItemPadding,
      child: _PopupMenuItemContent(
        lucideIcon: icon,
        label: label,
        enabled: enabled,
        selected: selected,
        destructive: destructive,
      ),
    );
  }

  Widget _button({
    required ThemeData theme,
    required EditorTokens tokens,
    required String icon,
    required String tooltip,
    required TableToolbarAction action,
    bool enabled = true,
    int? backgroundColor,
  }) {
    return IconButton(
      icon: WenzLucideToolbarIcon(icon),
      iconSize: tokens.minimalToolbarIconSize,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: tokens.minimalToolbarButtonSize,
        height: tokens.minimalToolbarButtonSize,
      ),
      style: _blockToolbarIconButtonStyle(theme, tokens: tokens),
      onPressed: enabled
          ? () => _dispatch(action, backgroundColor: backgroundColor)
          : null,
    );
  }

  void _dispatchSelection(_TableToolbarSelection selection) {
    _dispatch(selection.action, backgroundColor: selection.backgroundColor);
  }

  void _dispatch(TableToolbarAction action, {int? backgroundColor}) {
    onAction(
      TableToolbarActionIntent(
        action: action,
        blockIndex: blockIndex,
        rowIndex: range.startRow,
        columnIndex: range.startColumn,
        tableBlockId: block.id,
        endRowIndex: range.endRow,
        endColumnIndex: range.endColumn,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _divider(ThemeData theme, EditorTokens tokens) {
    return SizedBox(
      width: _kMinimalFloatingToolbarDividerWidth,
      height: tokens.minimalToolbarButtonSize,
      child: Center(
        child: SizedBox(
          width: 1,
          height: _kMinimalFloatingToolbarDividerHeight,
          child: ColoredBox(
            color: theme.colorScheme.outlineVariant.withAlpha(
              _kMinimalFloatingToolbarDividerAlpha,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableToolbarState {
  const _TableToolbarState({
    required this.canDeleteRow,
    required this.canDeleteColumn,
    required this.canMerge,
    required this.canStyleCells,
    required this.canSplit,
    required this.headerSelected,
    required this.backgroundSelected,
    required this.canClearBackground,
    required this.alignment,
    required this.canClearAlignment,
    required this.canResetColumnWidth,
    required this.rowSelected,
    required this.columnSelected,
    required this.tableSelected,
  });

  final bool canDeleteRow;
  final bool canDeleteColumn;
  final bool canMerge;
  final bool canStyleCells;
  final bool canSplit;
  final bool headerSelected;
  final bool backgroundSelected;
  final bool canClearBackground;
  final String? alignment;
  final bool canClearAlignment;
  final bool canResetColumnWidth;
  final bool rowSelected;
  final bool columnSelected;
  final bool tableSelected;

  static _TableToolbarState resolve(
    TableBlockNode block,
    TableCellRange range,
  ) {
    final cells = _visibleCells(block, range);
    final anchor = block.table.cellAt(range.startRow, range.startColumn);
    final rowFull = range.startColumn == 0 &&
        range.endColumn >= block.table.columnCount - 1;
    final columnFull =
        range.startRow == 0 && range.endRow >= block.table.rowCount - 1;
    final tableSelected = rowFull && columnFull;
    return _TableToolbarState(
      canDeleteRow: _canDeleteRows(block, range),
      canDeleteColumn: _canDeleteColumns(block, range),
      canMerge: _canMerge(block, range),
      canStyleCells: cells.isNotEmpty,
      canSplit: anchor != null &&
          !anchor.covered &&
          (anchor.rowSpan > 1 || anchor.columnSpan > 1),
      headerSelected: cells.isNotEmpty && cells.every((cell) => cell.isHeader),
      backgroundSelected: cells.isNotEmpty &&
          cells.every(
            (cell) => cell.backgroundColor == _kTableToolbarBackgroundColor,
          ),
      canClearBackground: cells.any((cell) => cell.backgroundColor != null),
      alignment: _uniformAlignment(cells),
      canClearAlignment: cells.any((cell) => cell.alignment != null),
      canResetColumnWidth: _canResetColumnWidth(block, range),
      rowSelected: rowFull && !tableSelected,
      columnSelected: columnFull && !tableSelected,
      tableSelected: tableSelected,
    );
  }

  static List<TableCellNode> _visibleCells(
    TableBlockNode block,
    TableCellRange range,
  ) {
    final cells = <TableCellNode>[];
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = block.table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        cells.add(cell);
      }
    }
    return cells;
  }

  static String? _uniformAlignment(List<TableCellNode> cells) {
    var hasFirst = false;
    String? first;
    for (final cell in cells) {
      final alignment = cell.alignment;
      if (!hasFirst) {
        first = alignment;
        hasFirst = true;
        continue;
      }
      if (alignment != first) {
        return null;
      }
    }
    return first;
  }

  static bool _canResetColumnWidth(
    TableBlockNode block,
    TableCellRange range,
  ) {
    for (var column = range.startColumn; column <= range.endColumn; column++) {
      if (block.table.columnWidths.containsKey(column)) {
        return true;
      }
    }
    return false;
  }

  static bool _canMerge(TableBlockNode block, TableCellRange range) {
    if (range.isSingleCell) {
      return false;
    }
    for (var row = range.startRow; row <= range.endRow; row++) {
      for (var column = range.startColumn;
          column <= range.endColumn;
          column++) {
        final cell = block.table.cellAt(row, column);
        if (cell == null ||
            cell.covered ||
            cell.rowSpan != 1 ||
            cell.columnSpan != 1) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _canDeleteRows(TableBlockNode block, TableCellRange range) {
    if (block.table.rowCount <= 1) {
      return false;
    }
    for (var row = 0; row < block.table.rowCount; row++) {
      for (var column = 0; column < block.table.rows[row].length; column++) {
        final cell = block.table.rows[row][column];
        if (cell.covered || cell.rowSpan <= 1) {
          continue;
        }
        if (_rangesOverlap(
          row,
          row + cell.rowSpan - 1,
          range.startRow,
          range.endRow,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _canDeleteColumns(TableBlockNode block, TableCellRange range) {
    if (block.table.columnCount <= 1) {
      return false;
    }
    for (var row = 0; row < block.table.rowCount; row++) {
      for (var column = 0; column < block.table.rows[row].length; column++) {
        final cell = block.table.rows[row][column];
        if (cell.covered || cell.columnSpan <= 1) {
          continue;
        }
        if (_rangesOverlap(
          column,
          column + cell.columnSpan - 1,
          range.startColumn,
          range.endColumn,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _rangesOverlap(int startA, int endA, int startB, int endB) {
    return startA <= endB && startB <= endA;
  }
}

class _TableToolbarSelection {
  const _TableToolbarSelection(this.action, {this.backgroundColor});

  final TableToolbarAction action;
  final int? backgroundColor;
}

class _TableColumnResizeHandle extends StatefulWidget {
  const _TableColumnResizeHandle({
    super.key,
    required this.columnIndex,
    required this.width,
    required this.onResize,
  });

  final int columnIndex;
  final double width;
  final ValueChanged<double> onResize;

  @override
  State<_TableColumnResizeHandle> createState() =>
      _TableColumnResizeHandleState();
}

class _TableColumnResizeHandleState extends State<_TableColumnResizeHandle> {
  late double _dragWidth;

  @override
  void initState() {
    super.initState();
    _dragWidth = widget.width;
  }

  @override
  void didUpdateWidget(_TableColumnResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _dragWidth = widget.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Resize table column ${widget.columnIndex + 1}',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            _dragWidth = widget.width;
          },
          onHorizontalDragUpdate: (details) {
            _dragWidth = (_dragWidth + details.delta.dx)
                .clamp(_kMinTableColumnWidth, _kMaxTableColumnWidth)
                .toDouble();
            widget.onResize(_dragWidth);
          },
          child: Center(
            child: SizedBox(
              width: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _withBlockSemantics(
  BlockNode block,
  Widget child, {
  bool selected = false,
}) {
  final label = selected
      ? '${_blockSemanticsLabel(block)}, selected'
      : _blockSemanticsLabel(block);
  final headingLevel = block is TextBlockNode && block.type == BlockType.heading
      ? (block.attributes.level ?? 1).clamp(1, 6).toInt()
      : null;
  return Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    selected: selected,
    header: headingLevel != null,
    headingLevel: headingLevel,
    image: block is ImageBlockNode,
    child: child,
  );
}

String _blockSemanticsLabel(BlockNode block) {
  return switch (block) {
    TextBlockNode(type: BlockType.heading) =>
      'Heading block level ${block.attributes.level}',
    TextBlockNode(type: BlockType.quote) => 'Quote block',
    TextBlockNode(type: BlockType.listItem) => 'List item block',
    TextBlockNode() => 'Paragraph block',
    CodeBlockNode() => 'Code block',
    TableBlockNode() =>
      'Table block, ${block.table.rowCount} rows, ${block.table.columnCount} columns',
    ImageBlockNode() => 'Image block ${_imageAccessibleLabel(block)}',
    VideoBlockNode() => 'Video block ${_assetLabel(block.assetId, block.file)}',
    BlockEmbedNode() =>
      'Embed block ${block.normalizedEmbedType}: ${block.displayText}',
    FileBlockNode() => 'File block ${_fileAccessibleLabel(block)}',
    DividerBlockNode() => 'Divider block',
    CalloutBlockNode() =>
      'Callout block ${block.normalizedVariant}: ${block.effectiveTitle}',
    BlockNode() => '${block.type.name} block',
  };
}

double _tableMaxWidth(BoxConstraints constraints, int columnCount) {
  if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
    return constraints.maxWidth;
  }
  return columnCount * 120;
}

Border _tableCellBorder({
  required _TableGridCell cell,
  required int rowCount,
  required int columnCount,
  required Color color,
}) {
  final side = BorderSide(color: color);
  return Border(
    top: side,
    left: side,
    right: cell.columnIndex + cell.columnSpan >= columnCount
        ? side
        : BorderSide.none,
    bottom: cell.rowIndex + cell.rowSpan >= rowCount ? side : BorderSide.none,
  );
}

class _TableGridMetrics {
  const _TableGridMetrics({
    required this.width,
    required this.height,
    required this.columnWidths,
    required this.columnResizeSegments,
    required this.cells,
  });

  final double width;
  final double height;
  final List<double> columnWidths;
  final List<_TableColumnResizeSegment> columnResizeSegments;
  final List<_TableGridCell> cells;

  static _TableGridMetrics compute({
    required TableModel table,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required EdgeInsets tableCellPadding,
  }) {
    final columnCount = table.columnCount;
    final rowCount = table.rowCount;
    final columnWidths = _resolveTableColumnWidths(table, maxWidth);
    final rowHeights = List<double>.filled(
      rowCount,
      _minimumTableCellHeight(textStyle, tableCellPadding),
    );

    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final cell = table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        final columnSpan = _clampedTableSpan(
          cell.columnSpan,
          column,
          columnCount,
        );
        final rowSpan = _clampedTableSpan(cell.rowSpan, row, rowCount);
        final cellWidth = _sumTableRange(columnWidths, column, columnSpan);
        final desiredHeight = _measureTableCellHeight(
          cell,
          textStyle,
          textDirection,
          cellWidth,
          tableCellPadding,
        );
        final currentHeight = _sumTableRange(rowHeights, row, rowSpan);
        if (desiredHeight > currentHeight) {
          final extra = (desiredHeight - currentHeight) / rowSpan;
          for (var i = 0; i < rowSpan; i++) {
            rowHeights[row + i] += extra;
          }
        }
      }
    }

    final lefts = _tableOffsets(columnWidths);
    final tops = _tableOffsets(rowHeights);
    final cells = <_TableGridCell>[];
    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final cell = table.cellAt(row, column);
        if (cell == null || cell.covered) {
          continue;
        }
        final columnSpan = _clampedTableSpan(
          cell.columnSpan,
          column,
          columnCount,
        );
        final rowSpan = _clampedTableSpan(cell.rowSpan, row, rowCount);
        cells.add(
          _TableGridCell(
            rowIndex: row,
            columnIndex: column,
            rowSpan: rowSpan,
            columnSpan: columnSpan,
            cell: cell,
            left: lefts[column],
            top: tops[row],
            width: _sumTableRange(columnWidths, column, columnSpan),
            height: _sumTableRange(rowHeights, row, rowSpan),
          ),
        );
      }
    }

    return _TableGridMetrics(
      width: _sumTableRange(columnWidths, 0, columnWidths.length),
      height: _sumTableRange(rowHeights, 0, rowHeights.length),
      columnWidths: columnWidths,
      columnResizeSegments: _tableColumnResizeSegments(
        cells: cells,
        columnCount: columnCount,
      ),
      cells: cells,
    );
  }
}

final _TableGridMetricsCache _tableGridMetricsCache =
    _TableGridMetricsCache(maxEntries: 8);

class _TableGridMetricsCache {
  _TableGridMetricsCache({required this.maxEntries});

  final int maxEntries;
  final Map<_TableGridMetricsCacheKey, _TableGridMetrics> _entries =
      <_TableGridMetricsCacheKey, _TableGridMetrics>{};

  _TableGridMetrics resolve({
    required TableModel table,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required EdgeInsets tableCellPadding,
  }) {
    final key = _TableGridMetricsCacheKey(
      table: table,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textDirection: textDirection,
      tableCellPadding: tableCellPadding,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final metrics = _TableGridMetrics.compute(
      table: table,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textDirection: textDirection,
      tableCellPadding: tableCellPadding,
    );
    _entries[key] = metrics;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return metrics;
  }
}

class _TableGridMetricsCacheKey {
  const _TableGridMetricsCacheKey({
    required this.table,
    required this.maxWidth,
    required this.textStyle,
    required this.textDirection,
    required this.tableCellPadding,
  });

  final TableModel table;
  final double maxWidth;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final EdgeInsets tableCellPadding;

  @override
  bool operator ==(Object other) {
    return other is _TableGridMetricsCacheKey &&
        identical(other.table, table) &&
        other.maxWidth == maxWidth &&
        other.textStyle == textStyle &&
        other.textDirection == textDirection &&
        other.tableCellPadding == tableCellPadding;
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(table),
        maxWidth,
        textStyle,
        textDirection,
        tableCellPadding,
      );
}

class _TableGridCell {
  const _TableGridCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.rowSpan,
    required this.columnSpan,
    required this.cell,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int rowIndex;
  final int columnIndex;
  final int rowSpan;
  final int columnSpan;
  final TableCellNode cell;
  final double left;
  final double top;
  final double width;
  final double height;
}

class _TableColumnResizeSegment {
  const _TableColumnResizeSegment({
    required this.columnIndex,
    required this.left,
    required this.top,
    required this.height,
  });

  final int columnIndex;
  final double left;
  final double top;
  final double height;

  double get bottom => top + height;

  String keyFor(String tableBlockId) {
    return 'table-resize-$tableBlockId-$columnIndex-$top-$height';
  }
}

List<_TableColumnResizeSegment> _tableColumnResizeSegments({
  required List<_TableGridCell> cells,
  required int columnCount,
}) {
  final rawSegments = <_TableColumnResizeSegment>[];
  for (final cell in cells) {
    if (cell.height <= 0) {
      continue;
    }
    if (cell.columnIndex > 0) {
      rawSegments.add(
        _TableColumnResizeSegment(
          columnIndex: cell.columnIndex - 1,
          left: cell.left,
          top: cell.top,
          height: cell.height,
        ),
      );
    }
    if (cell.columnIndex + cell.columnSpan >= columnCount) {
      rawSegments.add(
        _TableColumnResizeSegment(
          columnIndex: columnCount - 1,
          left: cell.left + cell.width,
          top: cell.top,
          height: cell.height,
        ),
      );
    }
  }
  rawSegments.sort((a, b) {
    final columnComparison = a.columnIndex.compareTo(b.columnIndex);
    if (columnComparison != 0) {
      return columnComparison;
    }
    final leftComparison = a.left.compareTo(b.left);
    if (leftComparison != 0) {
      return leftComparison;
    }
    return a.top.compareTo(b.top);
  });

  const geometryEpsilon = 0.5;
  final merged = <_TableColumnResizeSegment>[];
  for (final segment in rawSegments) {
    if (merged.isEmpty) {
      merged.add(segment);
      continue;
    }
    final previous = merged.last;
    final sameBoundary = previous.columnIndex == segment.columnIndex &&
        (previous.left - segment.left).abs() <= geometryEpsilon;
    if (sameBoundary && segment.top <= previous.bottom + geometryEpsilon) {
      merged[merged.length - 1] = _TableColumnResizeSegment(
        columnIndex: previous.columnIndex,
        left: previous.left,
        top: previous.top,
        height: math.max(previous.bottom, segment.bottom) - previous.top,
      );
      continue;
    }
    merged.add(segment);
  }
  return merged;
}

List<double> _resolveTableColumnWidths(TableModel table, double maxWidth) {
  final columnCount = table.columnCount;
  final widths = List<double>.filled(columnCount, 0);
  var fixedWidth = 0.0;
  var flexCount = 0;
  for (var i = 0; i < columnCount; i++) {
    final explicit = table.columnWidths[i];
    if (explicit != null && explicit > 0) {
      widths[i] = explicit;
      fixedWidth += explicit;
    } else {
      flexCount += 1;
    }
  }
  if (flexCount == 0) {
    return widths;
  }
  final remaining = maxWidth - fixedWidth;
  final flexWidth = remaining > 0 ? remaining / flexCount : 80.0;
  for (var i = 0; i < columnCount; i++) {
    if (widths[i] == 0) {
      widths[i] = flexWidth;
    }
  }
  return widths;
}

double _measureTableCellHeight(
  TableCellNode cell,
  TextStyle textStyle,
  TextDirection textDirection,
  double cellWidth,
  EdgeInsets tableCellPadding,
) {
  final effectiveTextStyle = cell.isHeader
      ? textStyle.copyWith(fontWeight: FontWeight.w700)
      : textStyle;
  final text = _tableCellDisplayText(cell);
  final displayText = text.isEmpty ? ' ' : text;
  final innerWidth = _tableCellInnerWidth(cellWidth, tableCellPadding);
  final painter = TextPainter(
    text: TextSpan(text: displayText, style: effectiveTextStyle),
    textAlign: TextAlign.start,
    textDirection: textDirection,
  )..layout(maxWidth: innerWidth);
  final height = painter.height + tableCellPadding.vertical;
  painter.dispose();
  final minimum = _minimumTableCellHeight(textStyle, tableCellPadding);
  return height > minimum ? height : minimum;
}

double _tableCellInnerWidth(double cellWidth, EdgeInsets tableCellPadding) {
  final innerWidth = cellWidth - tableCellPadding.horizontal;
  if (!innerWidth.isFinite || innerWidth <= 0) {
    return 0;
  }
  return innerWidth;
}

TextStyle _effectiveTableCellTextStyle(
  TableCellNode? cell,
  TextStyle textStyle,
  ThemeData theme,
) {
  if (cell?.isHeader ?? false) {
    return textStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
  return textStyle;
}

class _TableCellTextLayout {
  const _TableCellTextLayout({
    required this.textLength,
    required this.textSpan,
    required this.offsetMapper,
  });

  final int textLength;
  final InlineSpan textSpan;
  final _InlineOffsetMapper offsetMapper;
}

_TableCellTextLayout _tableCellTextLayoutFor({
  required BuildContext context,
  required TableCellNode? cell,
  required TextStyle textStyle,
  required ThemeData theme,
  required String blockId,
  required int blockIndex,
  required PositionPath path,
  required _LocalSelectionRange? compositionRange,
  InlineEmbedRenderer? inlineEmbedRenderer,
}) {
  final effectiveTextStyle = _effectiveTableCellTextStyle(
    cell,
    textStyle,
    theme,
  );
  final inlineContent = _tableCellInlineContent(cell);
  final textLength = inlineNodesLength(inlineContent);
  final inlineTextLayout = _inlineTextLayoutFor(
    context,
    inlineContent,
    effectiveTextStyle,
    compositionRange,
    inlineEmbedRenderer,
    blockId: blockId,
    blockIndex: blockIndex,
    path: path,
  );
  return _TableCellTextLayout(
    textLength: textLength,
    textSpan: TextSpan(
      style: effectiveTextStyle,
      children: textLength == 0
          ? const <InlineSpan>[TextSpan(text: ' ')]
          : inlineTextLayout.spans,
    ),
    offsetMapper: inlineTextLayout.offsetMapper,
  );
}

List<InlineNode> _tableCellInlineContent(TableCellNode? cell) {
  if (cell == null) {
    return const <InlineNode>[];
  }
  for (final block in cell.blocks) {
    if (block is TextBlockNode) {
      return block.content;
    }
  }
  return <InlineNode>[TextRun(text: cell.plainText)];
}

String _tableCellDisplayText(TableCellNode cell) {
  final inline = _tableCellInlineContent(cell);
  if (inline.isEmpty) {
    return cell.plainText;
  }
  return inline.map(_inlineDisplayText).join();
}

double _minimumTableCellHeight(
    TextStyle textStyle, EdgeInsets tableCellPadding) {
  return ((textStyle.fontSize ?? _kTableCellFontSize) *
          _kBlockMinHeightFactor) +
      tableCellPadding.vertical;
}

Color? _tableCellBackgroundColor({
  required ThemeData theme,
  required TableCellNode? cell,
  required int rowIndex,
}) {
  if (cell == null) {
    return null;
  }
  if (cell.backgroundColor != null) {
    return Color(cell.backgroundColor!);
  }
  if (cell.isHeader) {
    return theme.colorScheme.surfaceContainer;
  }
  if (rowIndex.isOdd) {
    return _tableEvenRowBackgroundColor(theme);
  }
  return null;
}

int _clampedTableSpan(int span, int start, int count) {
  final normalized = span < 1 ? 1 : span;
  final available = count - start;
  if (available <= 0) {
    return 1;
  }
  return normalized > available ? available : normalized;
}

List<double> _tableOffsets(List<double> sizes) {
  var offset = 0.0;
  final offsets = <double>[];
  for (final size in sizes) {
    offsets.add(offset);
    offset += size;
  }
  return offsets;
}

double _sumTableRange(List<double> values, int start, int count) {
  var result = 0.0;
  final end = start + count;
  for (var i = start; i < end && i < values.length; i++) {
    result += values[i];
  }
  return result;
}

/// Computes the visual bounding rectangle that spans from the caret at
/// [selection.start] to the caret at [selection.end] using the layout
/// information in [gridMetrics].
///
/// Each endpoint is resolved with the same text layout inputs used by the cell
/// renderer, so aligned text, empty cells, and multi-line cells contribute the
/// caret's actual pixel coordinates rather than the endpoint cell's full
/// rectangle. The returned [Rect] is normalized as
/// `min(left), min(top), max(right), max(bottom)`.
///
/// Returns `null` when:
/// - The selection is collapsed (no visual area to span).
/// - The selection does not intersect this table block.
/// - The relevant endpoint's row/column or text layout cannot be resolved.
Rect? _selectionRectForTableCells({
  required BuildContext context,
  required _TableGridMetrics gridMetrics,
  required TableModel table,
  required String tableBlockId,
  required int blockIndex,
  required DocumentSelection selection,
  required TextStyle textStyle,
  required TextDirection textDirection,
  InlineEmbedRenderer? inlineEmbedRenderer,
}) {
  if (selection.isCollapsed) {
    return null;
  }

  final start = selection.start;
  final end = selection.end;
  final tableRect = _tableRectForGridMetrics(gridMetrics);
  final startInTable = _isTableCellPositionInBlock(
    start,
    tableBlockId,
    blockIndex,
  );
  final endInTable = _isTableCellPositionInBlock(
    end,
    tableBlockId,
    blockIndex,
  );

  if (start.blockIndex < blockIndex && end.blockIndex > blockIndex) {
    return tableRect;
  }

  if (!startInTable && !endInTable) {
    return null;
  }

  if (startInTable && endInTable) {
    final startRect = _caretRectForTableSelectionEndpoint(
      context: context,
      gridMetrics: gridMetrics,
      table: table,
      position: start,
      textStyle: textStyle,
      textDirection: textDirection,
      inlineEmbedRenderer: inlineEmbedRenderer,
    );
    final endRect = _caretRectForTableSelectionEndpoint(
      context: context,
      gridMetrics: gridMetrics,
      table: table,
      position: end,
      textStyle: textStyle,
      textDirection: textDirection,
      inlineEmbedRenderer: inlineEmbedRenderer,
    );
    if (startRect == null || endRect == null) {
      return null;
    }
    return _normalizedRectBetween(startRect, endRect);
  }

  if (startInTable && end.blockIndex > blockIndex) {
    final startRect = _caretRectForTableSelectionEndpoint(
      context: context,
      gridMetrics: gridMetrics,
      table: table,
      position: start,
      textStyle: textStyle,
      textDirection: textDirection,
      inlineEmbedRenderer: inlineEmbedRenderer,
    );
    if (startRect == null) {
      return null;
    }
    return _normalizedRectBetween(
      startRect,
      Rect.fromLTWH(tableRect.right, tableRect.bottom, 0, 0),
    );
  }

  if (endInTable && start.blockIndex < blockIndex) {
    final endRect = _caretRectForTableSelectionEndpoint(
      context: context,
      gridMetrics: gridMetrics,
      table: table,
      position: end,
      textStyle: textStyle,
      textDirection: textDirection,
      inlineEmbedRenderer: inlineEmbedRenderer,
    );
    if (endRect == null) {
      return null;
    }
    return _normalizedRectBetween(
      Rect.fromLTWH(tableRect.left, tableRect.top, 0, 0),
      endRect,
    );
  }

  return null;
}

Rect _normalizedRectBetween(Rect startRect, Rect endRect) {
  return Rect.fromLTRB(
    math.min(startRect.left, endRect.left),
    math.min(startRect.top, endRect.top),
    math.max(startRect.right, endRect.right),
    math.max(startRect.bottom, endRect.bottom),
  );
}

Rect _tableRectForGridMetrics(_TableGridMetrics gridMetrics) {
  return Rect.fromLTWH(
    0,
    0,
    gridMetrics.width,
    gridMetrics.height,
  );
}

bool _isTableCellPositionInBlock(
  DocumentPosition position,
  String tableBlockId,
  int blockIndex,
) {
  return position.blockId == tableBlockId &&
      position.blockIndex == blockIndex &&
      position.path.isTableCellText;
}

Rect? _caretRectForTableSelectionEndpoint({
  required BuildContext context,
  required _TableGridMetrics gridMetrics,
  required TableModel table,
  required DocumentPosition position,
  required TextStyle textStyle,
  required TextDirection textDirection,
  InlineEmbedRenderer? inlineEmbedRenderer,
}) {
  final row = position.path.tableRowIndex;
  final column = position.path.tableColumnIndex;
  if (row == null || column == null) {
    return null;
  }
  final gridCell = _tableGridCellAt(gridMetrics, row, column);
  if (gridCell == null) {
    return null;
  }

  final theme = Theme.of(context);
  final tokens = EditorTokens.resolve(context);
  final cell = gridCell.cell;
  final textLayout = _tableCellTextLayoutFor(
    context: context,
    cell: cell,
    textStyle: textStyle,
    theme: theme,
    blockId: position.blockId,
    blockIndex: position.blockIndex,
    path: position.path,
    compositionRange: null,
    inlineEmbedRenderer: inlineEmbedRenderer,
  );
  final innerWidth =
      _tableCellInnerWidth(gridCell.width, tokens.tableCellPadding);
  final layoutService = TextLayoutService();
  final painter = layoutService.layout(
    span: textLayout.textSpan,
    textAlign: _textAlign(cell.alignment ?? table.columnAlignments[column]),
    textDirection: textDirection,
    minWidth: innerWidth,
    maxWidth: innerWidth,
  );
  final logicalOffset = position.offset.clamp(0, textLayout.textLength).toInt();
  final renderOffset =
      textLayout.offsetMapper.renderOffsetForLogicalOffset(logicalOffset);
  final localTopLeft = layoutService.caretOffset(painter, renderOffset);
  final height = _caretHeightFor(
    painter,
    layoutService.caretHeight(painter, renderOffset),
  );
  layoutService.forget();
  if (!localTopLeft.dx.isFinite ||
      !localTopLeft.dy.isFinite ||
      !height.isFinite ||
      height <= 0) {
    return null;
  }
  return Rect.fromLTWH(
    gridCell.left + tokens.tableCellPadding.left + localTopLeft.dx,
    gridCell.top + tokens.tableCellPadding.top + localTopLeft.dy,
    _kCaretStrokeWidth,
    height,
  );
}

_TableGridCell? _tableGridCellAt(
  _TableGridMetrics gridMetrics,
  int rowIndex,
  int columnIndex,
) {
  for (final cell in gridMetrics.cells) {
    if (cell.rowIndex == rowIndex && cell.columnIndex == columnIndex) {
      return cell;
    }
  }
  return null;
}

Rect? _tableGridCellRectAt(
  _TableGridMetrics? gridMetrics,
  int rowIndex,
  int columnIndex,
) {
  if (gridMetrics == null) {
    return null;
  }
  final cell = _tableGridCellAt(gridMetrics, rowIndex, columnIndex);
  if (cell == null) {
    return null;
  }
  return Rect.fromLTWH(
    cell.left,
    cell.top,
    cell.width,
    cell.height,
  );
}

bool _shouldHighlightTableCell(
  DocumentSelection? selection,
  String tableBlockId,
  int blockIndex,
  int rowIndex,
  int columnIndex, {
  _TableGridMetrics? gridMetrics,
  Rect? tableSelectionRect,
}) {
  if (selection == null || selection.isCollapsed) {
    return false;
  }

  // Intra-table cell range (drag within the table): the whole-cell visual
  // highlight is driven only by the caret-constrained selection rectangle
  // intersecting the current visible cell rectangle.
  final range = selection.tableCellRange;
  if (range != null) {
    if (range.isSingleCell) {
      return false;
    }
    if (range.tableBlockId != tableBlockId || range.blockIndex != blockIndex) {
      return false;
    }
    final selRect = tableSelectionRect;
    final cellRect = _tableGridCellRectAt(gridMetrics, rowIndex, columnIndex);
    if (selRect == null || cellRect == null) {
      return range.containsCell(rowIndex, columnIndex);
    }
    return cellRect.overlaps(selRect);
  }

  // Cross-block selection that spans this table block (e.g. select-all across
  // a paragraph + table): when the table block sits strictly between the
  // selection endpoints, every visible cell is part of the selection.
  final start = selection.start;
  final end = selection.end;
  final tableCovered =
      start.blockIndex < blockIndex && end.blockIndex > blockIndex;
  if (tableCovered) {
    return _tableGridCellRectAt(gridMetrics, rowIndex, columnIndex) != null;
  }
  final selRect = tableSelectionRect;
  final currentCellRect = _tableGridCellRectAt(
    gridMetrics,
    rowIndex,
    columnIndex,
  );
  if (selRect != null && currentCellRect != null) {
    return currentCellRect.overlaps(selRect);
  }
  // Selection partially covers this table block from one endpoint. Keep the
  // visual decision tied to resolved grid rectangles; if an endpoint or current
  // cell is not visible in the grid, do not paint a whole-cell highlight.
  if (start.blockIndex == blockIndex &&
      start.path.isTableCellText &&
      end.blockIndex > blockIndex) {
    if (start.blockId != tableBlockId) {
      return false;
    }
    if (gridMetrics == null) {
      return false;
    }
    // Use visual constraint: the start cell determines the visual boundary
    // within this table. Layout-missing cells are not highlighted.
    final startRow = start.path.tableRowIndex;
    final startCol = start.path.tableColumnIndex;
    if (startRow == null || startCol == null) {
      return false;
    }
    final startRect = _tableGridCellRectAt(gridMetrics, startRow, startCol);
    final cellRect = _tableGridCellRectAt(gridMetrics, rowIndex, columnIndex);
    if (startRect == null || cellRect == null) {
      return false;
    }
    return rowIndex > startRow ||
        (rowIndex == startRow && columnIndex >= startCol);
  }
  if (end.blockIndex == blockIndex &&
      end.path.isTableCellText &&
      start.blockIndex < blockIndex) {
    if (end.blockId != tableBlockId) {
      return false;
    }
    if (gridMetrics == null) {
      return false;
    }
    // Use visual constraint: the end cell determines the visual boundary
    // within this table. Layout-missing cells are not highlighted.
    final endRow = end.path.tableRowIndex;
    final endCol = end.path.tableColumnIndex;
    if (endRow == null || endCol == null) {
      return false;
    }
    final endRect = _tableGridCellRectAt(gridMetrics, endRow, endCol);
    final cellRect = _tableGridCellRectAt(gridMetrics, rowIndex, columnIndex);
    if (endRect == null || cellRect == null) {
      return false;
    }
    return rowIndex < endRow || (rowIndex == endRow && columnIndex <= endCol);
  }
  return false;
}

bool _shouldPaintTableCellTextSelection(
  DocumentSelection? selection,
  int blockIndex,
  PositionPath path,
) {
  if (selection == null || selection.isCollapsed || !path.isTableCellText) {
    return false;
  }
  final range = selection.tableCellRange;
  if (range != null) {
    return range.isSingleCell &&
        range.tableBlockId == path.blockId &&
        range.blockIndex == blockIndex &&
        _tableCellRangeContainsPath(range, path);
  }
  return _isSameTableCellTextSelection(selection, blockIndex, path);
}

bool _isSameTableCellTextSelection(
  DocumentSelection selection,
  int blockIndex,
  PositionPath path,
) {
  if (!path.isTableCellText) {
    return false;
  }
  final start = selection.start;
  final end = selection.end;
  return start.blockIndex == blockIndex &&
      end.blockIndex == blockIndex &&
      start.blockId == path.blockId &&
      end.blockId == path.blockId &&
      start.path == path &&
      end.path == path;
}

bool _tableCellRangeContainsPath(TableCellRange range, PositionPath path) {
  if (!path.isTableCellText) {
    return false;
  }
  final row = path.tableRowIndex;
  final column = path.tableColumnIndex;
  if (row == null || column == null) {
    return false;
  }
  return range.containsCell(row, column);
}

bool _isTableCellSemanticallySelected({
  required DocumentSelection? selection,
  required String tableBlockId,
  required int blockIndex,
  required int rowIndex,
  required int columnIndex,
  required bool hasTextSelection,
}) {
  if (hasTextSelection) {
    return true;
  }
  if (selection == null || selection.isCollapsed) {
    return false;
  }
  final range = selection.tableCellRange;
  if (range != null) {
    return range.tableBlockId == tableBlockId &&
        range.blockIndex == blockIndex &&
        range.containsCell(rowIndex, columnIndex);
  }
  final start = selection.start;
  final end = selection.end;
  if (start.blockIndex < blockIndex && end.blockIndex > blockIndex) {
    return true;
  }
  if (start.blockIndex == blockIndex &&
      start.blockId == tableBlockId &&
      start.path.isTableCellText &&
      end.blockIndex > blockIndex) {
    final startRow = start.path.tableRowIndex;
    final startColumn = start.path.tableColumnIndex;
    if (startRow == null || startColumn == null) {
      return false;
    }
    return rowIndex > startRow ||
        (rowIndex == startRow && columnIndex >= startColumn);
  }
  if (end.blockIndex == blockIndex &&
      end.blockId == tableBlockId &&
      end.path.isTableCellText &&
      start.blockIndex < blockIndex) {
    final endRow = end.path.tableRowIndex;
    final endColumn = end.path.tableColumnIndex;
    if (endRow == null || endColumn == null) {
      return false;
    }
    return rowIndex < endRow ||
        (rowIndex == endRow && columnIndex <= endColumn);
  }
  return false;
}

class _TableCellSurface extends StatefulWidget {
  const _TableCellSurface({
    required this.tableBlock,
    required this.blockIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.cell,
    required this.textStyle,
    required this.textAlign,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    required this.highlightWholeCell,
    required this.showDebugOverlay,
    this.inlineEmbedRenderer,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final TableBlockNode tableBlock;
  final int blockIndex;
  final int rowIndex;
  final int columnIndex;
  final TableCellNode? cell;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final bool highlightWholeCell;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  State<_TableCellSurface> createState() => _TableCellSurfaceState();
}

class _TableCellSurfaceState extends State<_TableCellSurface> {
  /// GlobalKey on the cell's outer frame — the whole cell (background +
  /// padding + centred text). Registered as the hit-test box so a tap anywhere
  /// inside the visible cell resolves to this cell, not a neighbour. The
  /// text-local surface is registered separately by [_TextSelectionSurface].
  final GlobalKey _cellFrameKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    if (cell?.covered ?? false) {
      return const SizedBox.shrink();
    }
    final tableBlock = widget.tableBlock;
    final blockIndex = widget.blockIndex;
    final path = PositionPath.tableCellText(
      tableBlock.id,
      widget.rowIndex,
      widget.columnIndex,
    );
    final compositionRange = _localCompositionRange(
      widget.compositionState,
      tableBlock.id,
      blockIndex,
      path,
    );
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final textLayout = _tableCellTextLayoutFor(
      context: context,
      cell: cell,
      textStyle: widget.textStyle,
      theme: theme,
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
      compositionRange: compositionRange,
      inlineEmbedRenderer: widget.inlineEmbedRenderer,
    );
    final backgroundColor = _tableCellBackgroundColor(
      theme: theme,
      cell: cell,
      rowIndex: widget.rowIndex,
    );
    final textSelectionRange = _selectionRangeForPath(
      widget.selection,
      blockIndex,
      path,
      textLayout.textLength,
    );
    final paintTextSelectionHighlight = textSelectionRange != null &&
        _shouldPaintTableCellTextSelection(
          widget.selection,
          blockIndex,
          path,
        );
    final surface = _TextSelectionSurface(
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
      textLength: textLayout.textLength,
      textSpan: textLayout.textSpan,
      offsetMapper: textLayout.offsetMapper,
      textAlign: widget.textAlign,
      minHeight: (widget.textStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
      selection: widget.selection,
      showCaret: widget.showCaret,
      registry: widget.registry,
      showDebugOverlay: widget.showDebugOverlay,
      paintSelectionHighlight: paintTextSelectionHighlight,
      findRanges: _findRangesForPath(
        widget.findMatches,
        widget.currentFindMatch,
        blockIndex,
        path,
        textLayout.textLength,
      ),
      // The cell frame — not the centred text surface — is the hit-test box.
      // The surface resolves the cell→text-local offset itself (it owns the
      // text-surface render box via its own key), stripping the padding and
      // the vertical centring gap that TableCellVerticalAlignment.middle
      // introduces for short cells.
      hitTestKey: _cellFrameKey,
    );
    final selected = _isTableCellSemanticallySelected(
      selection: widget.selection,
      tableBlockId: tableBlock.id,
      blockIndex: blockIndex,
      rowIndex: widget.rowIndex,
      columnIndex: widget.columnIndex,
      hasTextSelection: paintTextSelectionHighlight,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _tableCellSemanticsLabel(
        tableBlock: tableBlock,
        cell: cell,
        rowIndex: widget.rowIndex,
        columnIndex: widget.columnIndex,
        selected: selected,
      ),
      selected: selected,
      child: DecoratedBox(
        key: _cellFrameKey,
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Padding(
          padding: tokens.tableCellPadding,
          child: Stack(
            children: <Widget>[
              if (widget.highlightWholeCell)
                Positioned.fill(
                  child: DecoratedBox(
                    key: _selectionHighlightKey,
                    decoration: BoxDecoration(color: highlightColor),
                  ),
                ),
              surface,
            ],
          ),
        ),
      ),
    );
  }
}

String _tableCellSemanticsLabel({
  required TableBlockNode tableBlock,
  required TableCellNode? cell,
  required int rowIndex,
  required int columnIndex,
  required bool selected,
}) {
  final parts = <String>[
    'Table cell row ${rowIndex + 1} column ${columnIndex + 1}',
  ];
  if (cell?.isHeader ?? false) {
    parts.add('header');
  }
  if (cell != null) {
    final rowSpan = _clampedTableSpan(
      cell.rowSpan,
      rowIndex,
      tableBlock.table.rowCount,
    );
    final columnSpan = _clampedTableSpan(
      cell.columnSpan,
      columnIndex,
      tableBlock.table.columnCount,
    );
    if (rowSpan > 1) {
      parts.add('spans $rowSpan rows');
    }
    if (columnSpan > 1) {
      parts.add('spans $columnSpan columns');
    }
  }
  if (selected) {
    parts.add('selected');
  }
  return parts.join(', ');
}

class _BlockObjectSelectionSurface extends StatefulWidget {
  const _BlockObjectSelectionSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.selection,
    required this.registry,
    required this.showDebugOverlay,
    required this.child,
    this.onDoubleTap,
    this.showSelectionOverlay = true,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final DocumentSelection? selection;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;
  final Widget child;
  final VoidCallback? onDoubleTap;

  /// Whether to paint the generic full-size selection overlay. Blocks that draw
  /// their own tighter selection stroke disable this to avoid a loose, double
  /// rectangle over the block margins.
  final bool showSelectionOverlay;

  @override
  State<_BlockObjectSelectionSurface> createState() =>
      _BlockObjectSelectionSurfaceState();
}

class _BlockObjectSelectionSurfaceState
    extends State<_BlockObjectSelectionSurface> {
  final GlobalKey _surfaceKey = GlobalKey();
  DateTime? _lastPreviewTapTime;
  Offset? _lastPreviewTapPosition;
  int? _previewTapPointer;
  Offset? _previewTapDownPosition;
  bool _previewTapMoved = false;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _BlockObjectSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.path != widget.path) {
      oldWidget.registry.unregister(
        oldWidget.blockId,
        oldWidget.path,
        _surfaceKey,
      );
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.path != widget.path) {
      _register();
    }
    if (oldWidget.onDoubleTap != widget.onDoubleTap) {
      _resetPreviewTapSequence();
    }
  }

  @override
  void dispose() {
    widget.registry.unregister(widget.blockId, widget.path, _surfaceKey);
    super.dispose();
  }

  void _register() {
    widget.registry.register(
      BlockEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        path: widget.path,
        textLength: _kAtomicBlockSelectionLength,
        key: _surfaceKey,
        positionFromLocal: _offsetForLocalPosition,
        wordRangeAt: (_) => const TextRange(
          start: 0,
          end: _kAtomicBlockSelectionLength,
        ),
        caretRectAt: _caretRectAt,
        localCaretRectAt: _localCaretRectAt,
        localComposingRectForRange: _localComposingRectForRange,
        verticalMoveAt: _verticalMoveAt,
      ),
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    final width = box is RenderBox && box.hasSize ? box.size.width : 0.0;
    if (width <= 0) {
      return 0;
    }
    final after = switch (Directionality.of(context)) {
      TextDirection.ltr => localPosition.dx >= width / 2,
      TextDirection.rtl => localPosition.dx < width / 2,
    };
    return after ? _kAtomicBlockSelectionLength : 0;
  }

  Rect? _caretRectAt(int offset) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final localRect = _localCaretRectAt(offset);
    if (localRect == null) {
      return null;
    }
    return box.localToGlobal(localRect.topLeft) & localRect.size;
  }

  Rect? _localCaretRectAt(int offset) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final safeOffset = offset.clamp(0, _kAtomicBlockSelectionLength).toInt();
    final x = safeOffset == 0 ? 0.0 : box.size.width;
    return Rect.fromLTWH(
      x,
      0,
      _kCaretStrokeWidth,
      box.size.height,
    );
  }

  Rect? _localComposingRectForRange(int start, int end) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final safeStart = start.clamp(0, _kAtomicBlockSelectionLength).toInt();
    final safeEnd = end.clamp(safeStart, _kAtomicBlockSelectionLength).toInt();
    if (safeStart == safeEnd) {
      return _localCaretRectAt(safeStart);
    }
    return Offset.zero & box.size;
  }

  VerticalMoveResult _verticalMoveAt(
    int offset,
    bool forward,
    double? preferX,
  ) {
    return const VerticalMoveResult();
  }

  void _onPreviewPointerDown(PointerDownEvent event) {
    if (widget.onDoubleTap == null ||
        _isNonPrimaryPreviewPointer(event) ||
        widget.registry.isSelectionExcluded(event.position)) {
      _previewTapPointer = null;
      _previewTapDownPosition = null;
      _previewTapMoved = false;
      _resetPreviewTapSequence();
      return;
    }
    _previewTapPointer = event.pointer;
    _previewTapDownPosition = event.position;
    _previewTapMoved = false;
  }

  void _onPreviewPointerMove(PointerMoveEvent event) {
    if (_previewTapPointer != event.pointer) {
      return;
    }
    final down = _previewTapDownPosition;
    if (down != null && (event.position - down).distance > kTouchSlop) {
      _previewTapMoved = true;
    }
  }

  void _onPreviewPointerUp(PointerUpEvent event) {
    if (_previewTapPointer != event.pointer) {
      return;
    }
    final moved = _previewTapMoved;
    _previewTapPointer = null;
    _previewTapDownPosition = null;
    _previewTapMoved = false;
    if (moved) {
      _resetPreviewTapSequence();
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastPreviewTapTime;
    final lastPosition = _lastPreviewTapPosition;
    final isDoubleTap = lastTime != null &&
        lastPosition != null &&
        now.difference(lastTime) <= kDoubleTapTimeout &&
        (event.position - lastPosition).distance <= kTouchSlop;
    if (!isDoubleTap) {
      _lastPreviewTapTime = now;
      _lastPreviewTapPosition = event.position;
      return;
    }
    _resetPreviewTapSequence();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onDoubleTap?.call();
      }
    });
  }

  void _onPreviewPointerCancel(PointerCancelEvent event) {
    if (_previewTapPointer == event.pointer) {
      _previewTapPointer = null;
      _previewTapDownPosition = null;
      _previewTapMoved = false;
    }
    _resetPreviewTapSequence();
  }

  bool _isNonPrimaryPreviewPointer(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        ((event.buttons & kPrimaryMouseButton) == 0 ||
            (event.buttons & kSecondaryMouseButton) != 0);
  }

  void _resetPreviewTapSequence() {
    _lastPreviewTapTime = null;
    _lastPreviewTapPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectionTouchesPath(
      widget.selection,
      widget.blockIndex,
      widget.blockId,
      widget.path,
      _kAtomicBlockSelectionLength,
    );
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final debugOffset = _debugOffsetForPath(
      widget.selection,
      widget.blockId,
      widget.path,
      _kAtomicBlockSelectionLength,
    );
    final surface = Stack(
      key: _surfaceKey,
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        if (selected && widget.showSelectionOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: _selectionHighlightKey,
                decoration: BoxDecoration(
                  color: selectedColor.withAlpha(24),
                  border: Border.all(color: selectedColor, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        if (widget.showDebugOverlay)
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: _DebugSelectionTag(
                blockId: widget.blockId,
                blockIndex: widget.blockIndex,
                path: widget.path,
                offset: debugOffset,
              ),
            ),
          ),
      ],
    );
    final onDoubleTap = widget.onDoubleTap;
    if (onDoubleTap == null) {
      return surface;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPreviewPointerDown,
      onPointerMove: _onPreviewPointerMove,
      onPointerUp: _onPreviewPointerUp,
      onPointerCancel: _onPreviewPointerCancel,
      child: surface,
    );
  }
}

/// Text-bearing surface that paints text/selection/caret and registers geometry
/// for document-level selection hit testing.
///
/// Empty text content is still a text target for paragraphs, list/todo items,
/// quote/heading text, and table-cell text. When the visible editable line area
/// is hit, the selection should collapse to this surface's block/path at offset
/// 0; object-only blocks keep their separate block-object selection semantics.
/// Interactive chrome such as list markers, todo checkboxes, heading collapse
/// buttons, block handles, menus, and scrollbar gutters must stay outside this
/// text hit target or be registered as selection exclusions.
class _TextSelectionSurface extends StatefulWidget {
  const _TextSelectionSurface({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.textLength,
    required this.textSpan,
    required this.offsetMapper,
    required this.textAlign,
    required this.minHeight,
    required this.selection,
    required this.showCaret,
    required this.registry,
    required this.showDebugOverlay,
    this.findRanges = const <_FindHighlightRange>[],
    this.selectionHighlightColor,
    this.paintSelectionHighlight = true,
    this.hitTestKey,
    this.clampHitTestToVisibleBounds = false,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int textLength;
  final InlineSpan textSpan;
  final _InlineOffsetMapper offsetMapper;
  final TextAlign textAlign;
  final double minHeight;
  final DocumentSelection? selection;
  final bool showCaret;
  final BlockGeometryRegistry registry;
  final bool showDebugOverlay;
  final List<_FindHighlightRange> findRanges;
  final Color? selectionHighlightColor;
  final bool paintSelectionHighlight;
  final bool clampHitTestToVisibleBounds;

  /// Optional GlobalKey on a wider hit-test frame (e.g. a table cell's whole
  /// frame) whose local space differs from this surface's text-local space.
  /// When null the surface's own [_surfaceKey] is used for hit-testing. When
  /// set, the State registers a transform that maps hit-local offsets onto
  /// this surface's text-local space (see [_hitLocalToTextLocal]).
  final GlobalKey? hitTestKey;

  @override
  State<_TextSelectionSurface> createState() => _TextSelectionSurfaceState();
}

class _TextSelectionSurfaceState extends State<_TextSelectionSurface> {
  TextLayoutService? _ownedLayoutService;
  final GlobalKey _surfaceKey = GlobalKey();
  double _lastMinWidth = 0;
  double _lastMaxWidth = 0;

  /// Drives the caret blink. Period ~530ms, toggling [value] between 0 and 1.
  /// Uses a real [Timer] rather than an [AnimationController]+ticker so the
  /// repeating blink does not keep the frame scheduler busy — this lets tests
  /// (and idle frames) settle. The timer only fires on real time progress, so
  /// headless `pump()`/`pumpAndSettle()` without a duration are not blocked.
  Timer? _blinkTimer;

  /// Current blink phase: 1.0 = caret visible, 0.0 = caret hidden. Toggled by
  /// [_blinkTimer]; defaults to visible so the caret shows immediately on focus.
  double _blinkValue = 1.0;
  bool _blinkActive = false;

  /// True while a post-frame [_syncBlink] is scheduled but not yet fired.
  /// Prevents stacking multiple syncs across rapid rebuilds within one frame.
  bool _blinkSyncPending = false;

  /// The layout service for this surface. Prefers the editor-level
  /// [SharedTextLayoutCache] (so the laid-out painter survives a virtualised
  /// remount); falls back to a private instance when no scope is present (e.g.
  /// in tests that mount the surface in isolation).
  TextLayoutService get _layoutService {
    final shared = _SharedLayoutCacheScope.of(context);
    if (shared != null) {
      return shared.entryFor(widget.blockId, widget.path.toString());
    }
    return _ownedLayoutService ??= TextLayoutService();
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant _TextSelectionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.path != widget.path) {
      oldWidget.registry.unregister(
        oldWidget.blockId,
        oldWidget.path,
        _surfaceKey,
      );
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex ||
        oldWidget.path != widget.path ||
        oldWidget.textLength != widget.textLength ||
        oldWidget.textSpan != widget.textSpan ||
        oldWidget.hitTestKey != widget.hitTestKey ||
        oldWidget.clampHitTestToVisibleBounds !=
            widget.clampHitTestToVisibleBounds) {
      _register();
    }
    // When the caret stays visible but its position changes (typing, arrow
    // keys, programmatic moves), reset the blink phase so the caret is shown
    // immediately rather than possibly landing in its hidden half-cycle —
    // matching the platform EditableText behaviour where every selection
    // change makes the caret snap back to visible.
    if (oldWidget.selection != widget.selection) {
      _resetBlinkPhase();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    widget.registry.unregister(widget.blockId, widget.path, _surfaceKey);
    // Only forget the private fallback; shared-cache entries are owned by the
    // cache and survive this surface's unmount so the painter is reused on the
    // next remount.
    _ownedLayoutService?.forget();
    super.dispose();
  }

  /// Starts or stops the blink timer to match [caretVisible]. Idempotent so it
  /// is safe to call from build.
  void _syncBlink(bool caretVisible) {
    if (caretVisible && !_blinkActive) {
      _startBlinkTimer();
    } else if (!caretVisible && _blinkActive) {
      _blinkActive = false;
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _blinkValue = 1.0;
    }
  }

  /// (Re)arms the blink timer with the caret forced visible. Called when the
  /// caret first becomes visible, and again on every selection change while it
  /// stays visible, so the caret snaps back to its visible phase instead of
  /// possibly lingering in the hidden half-cycle.
  void _startBlinkTimer() {
    _blinkActive = true;
    _blinkValue = 1.0;
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(
      _kBlinkHalfPeriod,
      (_) {
        _blinkValue = _blinkValue == 1.0 ? 0.0 : 1.0;
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  /// Resets the blink phase to visible and restarts the timer, so a caret that
  /// is mid-hidden-phase snaps back into view immediately. No-op when the
  /// caret is not currently blinking.
  void _resetBlinkPhase() {
    if (!_blinkActive) {
      return;
    }
    _startBlinkTimer();
    if (mounted) {
      setState(() {});
    }
  }

  void _register() {
    widget.registry.register(
      BlockEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        path: widget.path,
        textLength: widget.textLength,
        key: _surfaceKey,
        positionFromLocal: _offsetForLocalPosition,
        wordRangeAt: _wordRangeAt,
        caretRectAt: _caretRectAt,
        localCaretRectAt: _localCaretRectAt,
        localComposingRectForRange: _localComposingRectForRange,
        verticalMoveAt: _verticalMoveAt,
        hitTestKey: widget.hitTestKey,
        hitLocalToTextLocal:
            widget.hitTestKey == null ? null : _hitLocalToTextLocal,
      ),
    );
  }

  /// Maps a tap offset in the registered hit-test frame's local space into
  /// this surface's text-local space. Only used when a separate [hitTestKey]
  /// was provided (table cells, object-card body, or the visible viewport of a
  /// horizontally scrolled code block); otherwise the registry treats the text
  /// surface itself as the hit-test box and this is never called.
  ///
  /// ## Coordinate transform
  ///
  /// Both boxes share global space, so the offset between their origins is
  /// simply the global delta. For a table cell the outer frame (DecoratedBox
  /// with [_cellFrameKey]) wraps a Padding that contains this text surface;
  /// therefore `cellOrigin - textOrigin` is `-cellPadding.topLeft` — the hit
  /// is shifted leftward/upward by the padding amount, placing it in the
  /// text-surface's local space.
  ///
  /// **Text alignment ([TextAlign.center] / [TextAlign.right]) does NOT affect
  /// this transform.** Alignment is handled internally by [TextPainter] during
  /// `getPositionForOffset` and `getBoxesForSelection` — the text-surface's
  /// render box fills the full available width when the parent is finite
  /// (`minWidth == maxWidth` in [build]), so the coordinate space of the
  /// hit-test box and the layout canvas are identical regardless of how the
  /// text is positioned within it.
  ///
  /// Resolves both render boxes at hit-test time and adds the global delta
  /// between them — robust to padding and to the vertical centring gap that
  /// `TableCellVerticalAlignment.middle` introduces for short cells.
  Offset _hitLocalToTextLocal(Offset hitLocal) {
    final hitKey = widget.hitTestKey;
    if (hitKey == null) {
      return hitLocal;
    }
    final cellBox = hitKey.currentContext?.findRenderObject();
    final textBox = _surfaceKey.currentContext?.findRenderObject();
    if (cellBox is! RenderBox || textBox is! RenderBox) {
      // Fallback: approximate the padding offset. Use the table-cell padding
      // as a reasonable default since that covers the majority of callers.
      // The `-Offset(8, 8)` historic fallback remains as a coarse guess when
      // clampToVisibleBounds is not set (object-card body, code viewport).
      final fallbackPadding = EditorTokens.resolve(context).tableCellPadding;
      return widget.clampHitTestToVisibleBounds
          ? Offset.zero
          : hitLocal - Offset(fallbackPadding.left, fallbackPadding.top);
    }
    final cellOrigin = cellBox.localToGlobal(Offset.zero);
    final textOrigin = textBox.localToGlobal(Offset.zero);
    // hitLocal is cell-relative; convert to text-surface-relative. Since both
    // boxes share global space: textLocal = hitLocal + (cellOrigin - textOrigin).
    // (cellOrigin < textOrigin because the text sits inside the padding, so this
    // subtracts the padding/centring offset, landing the tap on the text.)
    final textLocal = hitLocal +
        Offset(cellOrigin.dx - textOrigin.dx, cellOrigin.dy - textOrigin.dy);
    // Clamp into the text surface so an off-text tap (e.g. a bottom gutter
    // below a centred short cell, or a code tap inside the visible viewport but
    // outside the scrolled child's current local bounds) maps to the nearest
    // caret edge rather than a point outside the painter's line metrics.
    if (widget.clampHitTestToVisibleBounds) {
      final visibleLeft = cellOrigin.dx - textOrigin.dx;
      final visibleRight = visibleLeft + cellBox.size.width;
      final visibleTop = cellOrigin.dy - textOrigin.dy;
      final visibleBottom = visibleTop + cellBox.size.height;
      return Offset(
        textLocal.dx.clamp(
          math.max(0, visibleLeft),
          math.min(textBox.size.width, visibleRight),
        ),
        textLocal.dy.clamp(
          math.max(0, visibleTop),
          math.min(textBox.size.height, visibleBottom),
        ),
      );
    }
    return Offset(
      textLocal.dx.clamp(0, textBox.size.width),
      textLocal.dy.clamp(0, textBox.size.height),
    );
  }

  int _offsetForLocalPosition(Offset localPosition) {
    if (widget.textLength <= 0) {
      return 0;
    }
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      minWidth: _lastMinWidth,
      maxWidth: _lastMaxWidth,
    );
    final renderLength = widget.textSpan.toPlainText().length;
    final renderOffset = _layoutService.offsetAt(
      painter,
      localPosition,
      renderLength,
    );
    return widget.offsetMapper.logicalOffsetForHit(
      painter,
      localPosition,
      renderOffset,
    );
  }

  TextRange _wordRangeAt(int offset) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      minWidth: _lastMinWidth,
      maxWidth: _lastMaxWidth,
    );
    final renderOffset =
        widget.offsetMapper.renderOffsetForLogicalOffset(offset);
    final renderRange = _layoutService.wordRangeAt(painter, renderOffset);
    final start = widget.offsetMapper.logicalOffsetForRenderOffset(
      renderRange.start,
    );
    final end =
        widget.offsetMapper.logicalOffsetForRenderOffset(renderRange.end);
    return TextRange(
      start: start < end ? start : end,
      end: start < end ? end : start,
    );
  }

  /// Returns the caret's global [Rect] for [offset] in this block. Translates
  /// the laid-out caret's local top-left + height into screen coordinates via
  /// the surface render box.
  Rect? _caretRectAt(int offset) {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final localRect = _localCaretRectAt(offset);
    if (localRect == null) {
      return null;
    }
    return renderObject.localToGlobal(localRect.topLeft) & localRect.size;
  }

  Rect? _localCaretRectAt(int offset) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      minWidth: _lastMinWidth,
      maxWidth: _lastMaxWidth,
    );
    final clamped = offset.clamp(0, widget.textLength).toInt();
    final renderOffset = widget.offsetMapper.renderOffsetForLogicalOffset(
      clamped,
    );
    final local = _layoutService.caretOffset(painter, renderOffset);
    final height = _caretHeightFor(
      painter,
      _layoutService.caretHeight(painter, renderOffset),
    );
    // Width matches the painted stroke so the IME candidate window is anchored
    // to the caret the user actually sees.
    return Rect.fromLTWH(
      local.dx,
      local.dy,
      _kCaretStrokeWidth,
      height,
    );
  }

  Rect? _localComposingRectForRange(int start, int end) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      minWidth: _lastMinWidth,
      maxWidth: _lastMaxWidth,
    );
    final safeStart = start.clamp(0, widget.textLength).toInt();
    final safeEnd = end.clamp(safeStart, widget.textLength).toInt();
    if (safeStart == safeEnd) {
      return _localCaretRectAt(safeStart);
    }
    final renderStart = widget.offsetMapper.renderOffsetForLogicalOffset(
      safeStart,
    );
    final renderEnd = widget.offsetMapper.renderOffsetForLogicalOffset(safeEnd);
    final boxes =
        _layoutService.selectionBoxes(painter, renderStart, renderEnd);
    if (boxes.isEmpty) {
      return _localCaretRectAt(safeStart);
    }
    var rect = boxes.first.toRect();
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return rect;
  }

  /// Resolves one visual-line vertical move within this block, keeping the
  /// horizontal column at [preferX] (LOCAL coordinate space). Returns the new
  /// offset (or `null` at a block boundary) plus the caret's local x.
  VerticalMoveResult _verticalMoveAt(
      int offset, bool forward, double? preferX) {
    final painter = _layoutService.layout(
      span: widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: Directionality.of(context),
      minWidth: _lastMinWidth,
      maxWidth: _lastMaxWidth,
    );
    final renderOffset =
        widget.offsetMapper.renderOffsetForLogicalOffset(offset);
    final target = _layoutService.verticalMoveOffset(
      painter,
      renderOffset,
      forward,
      preferX: preferX,
    );
    return VerticalMoveResult(
      targetOffset: target == null
          ? null
          : widget.offsetMapper.logicalOffsetForRenderOffset(target),
      caretX: _layoutService.caretLocalX(painter, renderOffset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final selectionRange = widget.paintSelectionHighlight
        ? _selectionRangeForPath(
            widget.selection,
            widget.blockIndex,
            widget.path,
            widget.textLength,
          )
        : null;
    final caretOffset = _caretOffsetForPath(
      widget.selection,
      widget.showCaret,
      widget.blockId,
      widget.path,
      widget.textLength,
    );
    final theme = Theme.of(context);
    final selectionHighlightColor = widget.selectionHighlightColor ??
        theme.colorScheme.primary.withAlpha(54);
    final findHighlightColor = theme.colorScheme.tertiaryContainer.withAlpha(
      150,
    );
    final activeFindHighlightColor = theme.colorScheme.tertiary.withAlpha(120);
    final caretColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final minWidth = constraints.maxWidth.isFinite ? maxWidth : 0.0;
        _lastMinWidth = minWidth;
        _lastMaxWidth = maxWidth;
        // Warm the layout cache so painters and hit-testing reuse the same
        // laid-out TextPainter this frame.
        _layoutService.layout(
          span: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: direction,
          minWidth: minWidth,
          maxWidth: maxWidth,
        );
        // The caret's opacity is driven by the blink timer; while blinking it
        // toggles between fully visible (1.0) and hidden (0.0).
        final caretOpacity = caretOffset == null ? 1.0 : _blinkValue;
        // The caret is painted on its own CustomPaint, wrapped in a
        // RepaintBoundary. Blinking toggles opacity via setState, which would
        // otherwise dirty the whole surface — including the RichText child —
        // every half second. The boundary confines the repaint to the caret
        // layer, so the (much heavier) text layout/paint is untouched.
        final caretPainter = _CaretPainter(
          layoutService: _layoutService,
          textSpan: widget.textSpan,
          offsetMapper: widget.offsetMapper,
          textAlign: widget.textAlign,
          textDirection: direction,
          minWidth: minWidth,
          maxWidth: maxWidth,
          caretOffset: caretOffset,
          color: caretColor,
          textLength: widget.textLength,
          opacity: caretOpacity,
        );
        // Always stretch the text to the available width when maxWidth is finite
        // so that textAlign (center/right/justify) has a visible effect. Even
        // when a separate hitTestKey is set (table cells, object-card body), the
        // text box must fill the available width — the registry already handles
        // hit-local-to-text-local offset mapping via the hitTestKey mechanism.
        final textHitBoxMinWidth = minWidth;
        final text = CustomPaint(
          painter: _SelectionHighlightPainter(
            layoutService: _layoutService,
            textSpan: widget.textSpan,
            offsetMapper: widget.offsetMapper,
            textAlign: widget.textAlign,
            textDirection: direction,
            minWidth: minWidth,
            maxWidth: maxWidth,
            range: selectionRange,
            color: selectionHighlightColor,
          ),
          child: CustomPaint(
            painter: _FindHighlightPainter(
              layoutService: _layoutService,
              textSpan: widget.textSpan,
              textAlign: widget.textAlign,
              textDirection: direction,
              minWidth: minWidth,
              maxWidth: maxWidth,
              ranges: widget.findRanges,
              color: findHighlightColor,
              activeColor: activeFindHighlightColor,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: textHitBoxMinWidth,
                minHeight: widget.minHeight,
              ),
              child: RichText(
                text: widget.textSpan,
                textAlign: widget.textAlign,
                textDirection: direction,
              ),
            ),
          ),
        );
        // Keep the blink timer in step with whether the caret is showing.
        // Deferred to post-frame so we do not mutate timer state mid-build.
        // Guarded by [_blinkSyncPending] so repeated builds within the same
        // frame (or callbacks that have not fired yet) schedule at most one
        // sync, avoiding timer churn on rapid rebuilds.
        final caretVisible = caretOffset != null;
        if (caretVisible != _blinkActive && !_blinkSyncPending) {
          _blinkSyncPending = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _blinkSyncPending = false;
            if (mounted) {
              _syncBlink(caretVisible);
            }
          });
        }

        // Gestures live in the document-level SelectionGestureOverlay; the
        // surface only renders text, highlight, caret, and registers its
        // geometry for cross-block hit-testing.
        return Stack(
          key: _surfaceKey,
          children: <Widget>[
            text,
            if (selectionRange != null)
              const Positioned.fill(
                child: IgnorePointer(
                  child: SizedBox(key: _selectionHighlightKey),
                ),
              ),
            if (widget.findRanges.isNotEmpty)
              const Positioned.fill(
                child: IgnorePointer(
                  child: SizedBox(key: _findHighlightKey),
                ),
              ),
            // Caret lives in its own layer inside a RepaintBoundary so blink
            // repaints never reach the RichText below.
            if (caretOffset != null) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: _caretKey,
                      foregroundPainter: caretPainter,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.showDebugOverlay)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: _DebugSelectionTag(
                    blockId: widget.blockId,
                    blockIndex: widget.blockIndex,
                    path: widget.path,
                    offset: caretOffset ?? selectionRange?.end,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DebugSelectionTag extends StatelessWidget {
  const _DebugSelectionTag({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.offset,
  });

  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int? offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha(220),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$blockIndex ${blockId.isEmpty ? "<blockId>" : blockId}\n'
        '${path.toString()}\n'
        'offset=${offset ?? "-"}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _LocalSelectionRange {
  const _LocalSelectionRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _InlineTextLayout {
  const _InlineTextLayout({
    required this.spans,
    required this.offsetMapper,
  });

  final List<InlineSpan> spans;
  final _InlineOffsetMapper offsetMapper;
}

class _InlineOffsetMapper {
  const _InlineOffsetMapper({
    required this.segments,
    required this.logicalLength,
    required this.renderLength,
  });

  factory _InlineOffsetMapper.identity(int length) {
    final safeLength = length < 0 ? 0 : length;
    return _InlineOffsetMapper(
      segments: safeLength == 0
          ? const <_InlineOffsetSegment>[]
          : <_InlineOffsetSegment>[
              _InlineOffsetSegment(
                logicalStart: 0,
                logicalEnd: safeLength,
                renderStart: 0,
                renderEnd: safeLength,
                atomic: false,
              ),
            ],
      logicalLength: safeLength,
      renderLength: safeLength,
    );
  }

  final List<_InlineOffsetSegment> segments;
  final int logicalLength;
  final int renderLength;

  int logicalOffsetForHit(
    TextPainter painter,
    Offset localPosition,
    int renderOffset,
  ) {
    final atomicHit = _atomicLogicalOffsetForHit(painter, localPosition);
    if (atomicHit != null) {
      return atomicHit;
    }
    return logicalOffsetForRenderOffset(renderOffset);
  }

  int logicalOffsetForRenderOffset(int renderOffset) {
    final safeRenderOffset = renderOffset.clamp(0, renderLength).toInt();
    for (final segment in segments) {
      if (!segment.coversRenderOffset(safeRenderOffset)) {
        continue;
      }
      if (segment.atomic) {
        return segment.atomicLogicalOffsetForRenderOffset(safeRenderOffset);
      }
      return segment.logicalOffsetForRenderOffset(safeRenderOffset);
    }
    return safeRenderOffset == renderLength ? logicalLength : 0;
  }

  int renderOffsetForLogicalOffset(int logicalOffset) {
    final safeLogicalOffset = logicalOffset.clamp(0, logicalLength).toInt();
    for (final segment in segments) {
      if (!segment.coversLogicalOffset(safeLogicalOffset)) {
        continue;
      }
      return segment.renderOffsetForLogicalOffset(safeLogicalOffset);
    }
    return safeLogicalOffset == logicalLength ? renderLength : 0;
  }

  int? _atomicLogicalOffsetForHit(
    TextPainter painter,
    Offset localPosition,
  ) {
    for (final segment in segments) {
      if (!segment.atomic || segment.renderStart == segment.renderEnd) {
        continue;
      }
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: segment.renderStart,
          extentOffset: segment.renderEnd,
        ),
      );
      for (final box in boxes) {
        final rect = box.toRect();
        final hitRect = Rect.fromLTRB(
          rect.left,
          rect.top - 1,
          rect.right,
          rect.bottom + 1,
        );
        if (!hitRect.contains(localPosition)) {
          continue;
        }
        final after = switch (box.direction) {
          TextDirection.ltr => localPosition.dx >= rect.center.dx,
          TextDirection.rtl => localPosition.dx < rect.center.dx,
        };
        return after ? segment.logicalEnd : segment.logicalStart;
      }
    }
    return null;
  }
}

class _InlineOffsetSegment {
  const _InlineOffsetSegment({
    required this.logicalStart,
    required this.logicalEnd,
    required this.renderStart,
    required this.renderEnd,
    required this.atomic,
  });

  final int logicalStart;
  final int logicalEnd;
  final int renderStart;
  final int renderEnd;
  final bool atomic;

  int get logicalLength => logicalEnd - logicalStart;
  int get renderLength => renderEnd - renderStart;

  bool coversLogicalOffset(int offset) {
    return offset >= logicalStart && offset <= logicalEnd;
  }

  bool coversRenderOffset(int offset) {
    return offset >= renderStart && offset <= renderEnd;
  }

  int logicalOffsetForRenderOffset(int offset) {
    final delta = (offset - renderStart).clamp(0, renderLength).toInt();
    return (logicalStart + delta).clamp(logicalStart, logicalEnd).toInt();
  }

  int renderOffsetForLogicalOffset(int offset) {
    if (atomic) {
      return atomicRenderOffsetForLogicalOffset(offset);
    }
    final delta = (offset - logicalStart).clamp(0, logicalLength).toInt();
    return (renderStart + delta).clamp(renderStart, renderEnd).toInt();
  }

  int atomicRenderOffsetForLogicalOffset(int offset) {
    final beforeDistance = (offset - logicalStart).abs();
    final afterDistance = (logicalEnd - offset).abs();
    return afterDistance <= beforeDistance ? renderEnd : renderStart;
  }

  int atomicLogicalOffsetForRenderOffset(int offset) {
    final beforeDistance = (offset - renderStart).abs();
    final afterDistance = (renderEnd - offset).abs();
    return afterDistance <= beforeDistance ? logicalEnd : logicalStart;
  }
}

class _FindHighlightRange extends _LocalSelectionRange {
  const _FindHighlightRange({
    required super.start,
    required super.end,
    required this.active,
  });

  final bool active;
}

class _FindHighlightPainter extends CustomPainter {
  const _FindHighlightPainter({
    required this.layoutService,
    required this.textSpan,
    required this.textAlign,
    required this.textDirection,
    required this.minWidth,
    required this.maxWidth,
    required this.ranges,
    required this.color,
    required this.activeColor,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double minWidth;
  final double maxWidth;
  final List<_FindHighlightRange> ranges;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
    for (final range in ranges) {
      if (range.start == range.end) {
        continue;
      }
      final paint = Paint()..color = range.active ? activeColor : color;
      final boxes = layoutService.selectionBoxes(
        painter,
        range.start,
        range.end,
      );
      for (final box in boxes) {
        canvas.drawRect(box.toRect(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FindHighlightPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.minWidth != minWidth ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.ranges != ranges ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor;
  }
}

class _SelectionHighlightPainter extends CustomPainter {
  const _SelectionHighlightPainter({
    required this.layoutService,
    required this.textSpan,
    required this.offsetMapper,
    required this.textAlign,
    required this.textDirection,
    required this.minWidth,
    required this.maxWidth,
    required this.range,
    required this.color,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final _InlineOffsetMapper offsetMapper;

  /// Text alignment passed through to [TextPainter] during layout. The painter
  /// handles positioning internally (e.g. shifting text rightward for center /
  /// right alignment), so [selectionBoxes] returns boxes already in the correct
  /// canvas-local space as long as [minWidth] / [maxWidth] match [RichText].
  final TextAlign textAlign;

  final TextDirection textDirection;
  final double minWidth;
  final double maxWidth;
  final _LocalSelectionRange? range;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final range = this.range;
    if (range == null || range.start == range.end) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
    final renderStart = offsetMapper.renderOffsetForLogicalOffset(range.start);
    final renderEnd = offsetMapper.renderOffsetForLogicalOffset(range.end);
    final boxes = layoutService.selectionBoxes(painter, renderStart, renderEnd);
    final paint = Paint()..color = color;
    for (final box in boxes) {
      canvas.drawRect(box.toRect(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHighlightPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.offsetMapper != offsetMapper ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.minWidth != minWidth ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.range?.start != range?.start ||
        oldDelegate.range?.end != range?.end ||
        oldDelegate.color != color;
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({
    required this.layoutService,
    required this.textSpan,
    required this.offsetMapper,
    required this.textAlign,
    required this.textDirection,
    required this.minWidth,
    required this.maxWidth,
    required this.caretOffset,
    required this.color,
    required this.textLength,
    this.opacity = 1.0,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final _InlineOffsetMapper offsetMapper;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double minWidth;
  final double maxWidth;
  final int? caretOffset;
  final Color color;
  final int textLength;

  /// Caret alpha multiplier driven by the blink animation (1.0 = fully visible,
  /// 0.0 = hidden).
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final caretOffset = this.caretOffset;
    if (caretOffset == null) {
      return;
    }
    final painter = layoutService.layout(
      span: textSpan,
      textAlign: textAlign,
      textDirection: textDirection,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
    final safeOffset = caretOffset.clamp(0, textLength).toInt();
    final renderOffset = offsetMapper.renderOffsetForLogicalOffset(safeOffset);
    final caretTop = layoutService.caretOffset(painter, renderOffset);
    // Fall back through preferred/style heights (matching _localCaretRectAt) so
    // the caret is visible even when getFullHeightForCaret returns null or 0.
    final height = _caretHeightFor(
      painter,
      layoutService.caretHeight(painter, renderOffset),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = _kCaretStrokeWidth;
    canvas.drawLine(caretTop, caretTop.translate(0, height), paint);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) {
    return oldDelegate.textSpan != textSpan ||
        oldDelegate.offsetMapper != offsetMapper ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.minWidth != minWidth ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.caretOffset != caretOffset ||
        oldDelegate.color != color ||
        oldDelegate.textLength != textLength ||
        oldDelegate.opacity != opacity;
  }
}

double _caretHeightFor(TextPainter painter, double? measured) {
  if (measured != null && measured > 0) {
    return measured;
  }
  final preferred = painter.preferredLineHeight;
  if (preferred > 0) {
    return preferred;
  }
  final style = painter.text?.style;
  final fontSize = style?.fontSize;
  final safeFontSize =
      fontSize != null && fontSize > 0 ? fontSize : _kRichTextBodyFontSize;
  final lineHeight = style?.height;
  final safeLineHeight = lineHeight != null && lineHeight > 0
      ? lineHeight
      : _kBlockMinHeightFactor;
  return safeFontSize * safeLineHeight;
}

/// Display mode for the built-in image-block placeholder (see
/// `docs/design/media_block_display_spec.md` §图片块占位状态契约).
enum _ImageBlockPlaceholderStatus {
  /// No resolver / resolver declined — a neutral empty figure slot.
  empty,

  /// Source is being uploaded/resolved — a spinner inside the image frame.
  loading,

  /// Resolver threw (catch-and-fallback) — error-toned failure slot.
  failed,
}

/// Built-in image-block placeholder. Renders as a content-width figure-chrome
/// empty state (icon/progress + state tone) and distinguishes the upload and
/// load-failure fallbacks without visible explanatory text. The outer
/// [_ImageBlockContent] figure frame supplies the shared chrome (surface base,
/// `_kMediaCornerRadius`, `_kSurfaceBoxShadow`, clip), so the placeholder only
/// paints its own background + content and fills the frame at a 2:1 slot ratio.
class _ImageBlockPlaceholder extends StatelessWidget {
  const _ImageBlockPlaceholder({
    this.status = _ImageBlockPlaceholderStatus.empty,
  });

  final _ImageBlockPlaceholderStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final failed = status == _ImageBlockPlaceholderStatus.failed;
    final iconColor = failed ? colorScheme.error : colorScheme.onSurfaceVariant;
    final background = failed
        ? colorScheme.errorContainer.withAlpha(170)
        : colorScheme.surfaceContainerHighest.withAlpha(190);
    // The empty/uploading slot keeps image_outlined so the load-failure slot
    // stays distinguishable by tone (the throwing-resolver path still resolves
    // to image_outlined for screen-reader parity).
    final indicator = status == _ImageBlockPlaceholderStatus.loading
        ? SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: iconColor,
            ),
          )
        : Icon(Icons.image_outlined, size: 34, color: iconColor);

    return AspectRatio(
      aspectRatio: _kImagePlaceholderAspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_kMediaCornerRadius),
        ),
        child: Center(child: indicator),
      ),
    );
  }
}

/// Display mode for the built-in video-block placeholder (see
/// `docs/design/media_block_display_spec.md` §视频块占位状态契约).
enum _VideoBlockPlaceholderStatus {
  /// No resolver / resolver declined — cover backdrop + play button (default).
  cover,

  /// Resolver threw (catch-and-fallback) — error-toned failure slot.
  failed,
}

class _VideoBlockPlaceholder extends StatelessWidget {
  const _VideoBlockPlaceholder({
    required this.block,
    this.squareCorners = false,
    this.status = _VideoBlockPlaceholderStatus.cover,
  });

  final VideoBlockNode block;

  /// The fullscreen route owns a viewport-sized zero-radius playback frame;
  /// inline blocks retain the editor's rounded surface and shadow.
  final bool squareCorners;

  /// Whether this slot renders the cover preview (default) or the
  /// load-failure fallback (resolver threw). The cover branch keeps the
  /// backdrop / gradient / chip / play-button logic intact; only the failure
  /// branch swaps in an error-toned slot.
  final _VideoBlockPlaceholderStatus status;

  @override
  Widget build(BuildContext context) {
    final failed = status == _VideoBlockPlaceholderStatus.failed;
    final coverUrl = block.coverUrl.trim();
    final source = _videoSourceLabel(block);
    return Semantics(
      label: _videoAccessibleLabel(block),
      child: DecoratedBox(
        key: ValueKey<String>('wenz-richtext-video-placeholder-${block.id}'),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius:
              squareCorners ? null : BorderRadius.circular(_kMediaCornerRadius),
          boxShadow: squareCorners ? null : _kSurfaceBoxShadow,
        ),
        child: _VideoPlaceholderClip(
          squareCorners: squareCorners,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (failed) {
                return const _VideoLoadFailureSlot();
              }
              final horizontalInset = _videoOverlayInset(constraints.maxWidth);
              final verticalInset = _videoOverlayInset(constraints.maxHeight);
              final overlayMaxWidth = _videoOverlayMaxWidth(
                constraints.maxWidth,
                horizontalInset,
              );
              final metadataMaxHeight = _videoMetadataMaxHeight(
                constraints.maxHeight,
                verticalInset,
              );
              final buttonSize = _videoPlayButtonSizeFor(constraints.biggest);
              final iconSize = math.min(
                _kVideoPlayIconSize,
                math.max(0.0, buttonSize * 0.45),
              );
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _VideoCoverBackdrop(coverUrl: coverUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x22000000),
                          Color(0xDD000000),
                        ],
                      ),
                    ),
                  ),
                  if (coverUrl.isNotEmpty)
                    PositionedDirectional(
                      top: verticalInset,
                      start: horizontalInset,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: overlayMaxWidth,
                        ),
                        child:
                            _VideoCoverChip(label: _videoCoverLabel(coverUrl)),
                      ),
                    ),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox.square(
                        dimension: buttonSize,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black87,
                          size: iconSize,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: horizontalInset,
                    end: horizontalInset,
                    bottom: verticalInset,
                    child: _VideoMetadataOverlay(
                      title: _videoPreviewTitle(block),
                      source: source,
                      maxWidth: overlayMaxWidth,
                      maxHeight: metadataMaxHeight,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholderClip extends StatelessWidget {
  const _VideoPlaceholderClip({
    required this.squareCorners,
    required this.child,
  });

  final bool squareCorners;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (squareCorners) {
      return ClipRect(child: child);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kMediaCornerRadius),
      child: child,
    );
  }
}

/// Load-failure fallback for the built-in video-block placeholder (see
/// `docs/design/media_block_display_spec.md` §视频块占位状态契约). Fills the
/// frame with an `errorContainer` tone + 简体中文 failure copy so the throwing-
/// resolver path stays visually distinct from the default black cover preview.
class _VideoLoadFailureSlot extends StatelessWidget {
  const _VideoLoadFailureSlot();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.errorContainer),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.videocam_outlined, size: 34, color: colorScheme.error),
              const SizedBox(height: 10),
              Text(
                '视频加载失败',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '无法播放该视频，请重新上传',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoMetadataOverlay extends StatelessWidget {
  const _VideoMetadataOverlay({
    required this.title,
    required this.source,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String title;
  final String source;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (!maxWidth.isFinite ||
        !maxHeight.isFinite ||
        maxWidth <= 0 ||
        maxHeight <= 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    final sourceStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withAlpha(220),
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: ClipRect(
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.bottomStart,
            child: SizedBox(
              width: maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '[video: $source]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sourceStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCoverBackdrop extends StatelessWidget {
  const _VideoCoverBackdrop({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(coverUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _VideoCoverFallback(),
      );
    }
    return const _VideoCoverFallback();
  }
}

class _VideoCoverFallback extends StatelessWidget {
  const _VideoCoverFallback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.inverseSurface,
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
    );
  }
}

class _VideoCoverChip extends StatelessWidget {
  const _VideoCoverChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

double _safeVideoAspectRatio(double aspectRatio) {
  if (!aspectRatio.isFinite || aspectRatio <= 0) {
    return VideoBlockNode.defaultAspectRatio;
  }
  return aspectRatio
      .clamp(_kVideoMinAspectRatio, _kVideoMaxAspectRatio)
      .toDouble();
}

class _VideoDisplayMetrics {
  const _VideoDisplayMetrics._({
    required this.aspectRatio,
    required this.minWidth,
    required this.maxWidth,
    required this.displayWidth,
  });

  factory _VideoDisplayMetrics.resolve(
    VideoBlockNode block, {
    double? availableWidth,
  }) {
    final aspectRatio = _safeVideoAspectRatio(block.effectiveAspectRatio);
    final showWidth = _positiveFiniteDimension(block.showWidth);
    final showHeight = _positiveFiniteDimension(block.showHeight);
    final explicitWidth = showWidth ?? _widthForHeight(showHeight, aspectRatio);
    final rawAvailableWidth = _nonNegativeFiniteDimension(availableWidth) ??
        explicitWidth ??
        _kVideoFrameFallbackWidth;
    final maxWidthForHeight = _kVideoMaxFrameHeight * aspectRatio;
    final maxWidth = math.max(
      0.0,
      math.min(rawAvailableWidth, maxWidthForHeight),
    );
    final minWidthForHeight = _kVideoMinFrameHeight * aspectRatio;
    final minWidth = math.min(minWidthForHeight, maxWidth);
    final preferredWidth = explicitWidth ?? maxWidth;
    final displayWidth = preferredWidth.clamp(minWidth, maxWidth).toDouble();
    return _VideoDisplayMetrics._(
      aspectRatio: aspectRatio,
      minWidth: minWidth,
      maxWidth: maxWidth,
      displayWidth: displayWidth,
    );
  }

  final double aspectRatio;
  final double minWidth;
  final double maxWidth;
  final double displayWidth;

  double get displayHeight => heightForWidth(displayWidth);

  Size get displaySize => Size(displayWidth, displayHeight);

  double clampWidth(double width) {
    final safeWidth = _positiveFiniteDimension(width) ?? minWidth;
    return safeWidth.clamp(minWidth, maxWidth).toDouble();
  }

  double heightForWidth(double width) {
    final safeWidth = clampWidth(width);
    return safeWidth <= 0 ? 0 : safeWidth / aspectRatio;
  }
}

double _videoOverlayInset(double extent) {
  if (!extent.isFinite || extent <= 0) {
    return 0;
  }
  return math.min(12.0, math.max(0.0, extent / 8));
}

double _videoOverlayMaxWidth(double width, double inset) {
  if (!width.isFinite) {
    return double.infinity;
  }
  return math.max(0.0, width - inset * 2);
}

double _videoMetadataMaxHeight(double height, double inset) {
  if (!height.isFinite || height <= 0) {
    return 0;
  }
  return math.max(0.0, height - inset * 2);
}

double _videoPlayButtonSizeFor(Size size) {
  final shortestSide = math.min(size.width, size.height);
  if (!shortestSide.isFinite || shortestSide <= 0) {
    return 0;
  }
  return math.min(
    _kVideoPlayButtonSize,
    math.max(24.0, shortestSide * 0.42),
  );
}

class _BlockEmbedContent extends StatelessWidget {
  const _BlockEmbedContent({
    required this.block,
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    this.onAction,
  });

  final BlockEmbedNode block;
  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final ObjectBlockActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackText = block.fallbackText.trim().isNotEmpty
        ? block.fallbackText.trim()
        : block.displayText;
    return _EmbedBlockCard(
      key: ValueKey<String>('wenz-richtext-embed-card-${block.id}'),
      blockIndex: blockIndex,
      blockCount: blockCount,
      selected: selected,
      canEdit: canEdit,
      onAction: onAction,
      label: block.normalizedEmbedType,
      backgroundColor: _embedBlockBackgroundColor(theme),
      borderColor: _embedBlockBorderColor(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            fallbackText,
            key: ValueKey<String>('wenz-richtext-embed-fallback-${block.id}'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (block.data.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _ObjectMetadataList(
              entries: <String>[
                for (final entry in block.data.entries.take(4))
                  '${entry.key}: ${entry.value}',
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormulaBlockContent extends StatelessWidget {
  const _FormulaBlockContent({
    required this.block,
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    this.onAction,
  });

  final BlockEmbedNode block;
  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final ObjectBlockActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formula = _formulaSourceText(
      block.data,
      fallbackText: block.fallbackText,
    );
    final style = (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 22,
      fontStyle: FontStyle.italic,
      fontFamilyFallback: const <String>[
        'Cambria Math',
        'Times New Roman',
        'serif',
      ],
    );
    final card = _EmbedBlockCard(
      key: ValueKey<String>('wenz-richtext-formula-card-${block.id}'),
      blockIndex: blockIndex,
      blockCount: blockCount,
      selected: selected,
      canEdit: canEdit,
      onAction: onAction,
      label: 'formula',
      backgroundColor: null,
      borderColor: _embedBlockBorderColor(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            formula.isEmpty ? 'Formula' : formula,
            key: ValueKey<String>('wenz-richtext-formula-source-${block.id}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            key: ValueKey<String>('wenz-richtext-formula-preview-${block.id}'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: _FormulaMathView(
                    formula: formula,
                    textStyle: style,
                    displayMode: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final requestController = _FormulaEditRequestScope.maybeOf(context);
    final canRequestEdit = canEdit && requestController != null;
    final semanticCard = Semantics(
      label: canRequestEdit ? '编辑块级公式' : '块级公式',
      value: formula.trim().isEmpty ? '空公式' : formula.trim(),
      button: canRequestEdit,
      enabled: canRequestEdit,
      child: card,
    );
    if (!canRequestEdit) {
      return semanticCard;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        requestController.request(
          _FormulaEditTarget.block(
            blockId: block.id,
            formula: formula,
            anchor: _globalRectForContext(context, details.globalPosition),
          ),
        );
      },
      child: semanticCard,
    );
  }
}

class _VideoBlockContent extends StatefulWidget {
  const _VideoBlockContent({
    required this.block,
    required this.blockIndex,
    required this.child,
    required this.selected,
    required this.canResize,
    required this.registry,
    this.onResize,
    this.onPreviewSizeChanged,
  });

  final VideoBlockNode block;
  final int blockIndex;
  final Widget child;
  final bool selected;
  final bool canResize;
  final BlockGeometryRegistry registry;
  final ImageBlockResizeHandler? onResize;
  final ValueChanged<Size?>? onPreviewSizeChanged;

  @override
  State<_VideoBlockContent> createState() => _VideoBlockContentState();
}

class _VideoBlockContentState extends State<_VideoBlockContent> {
  final GlobalKey _frameMeasureKey = GlobalKey();
  Size? _previewSize;
  _VideoDisplayMetrics? _dragMetrics;
  _ImageResizeEdge? _activeResizeEdge;
  double? _resizeStartWidth;
  double _resizeDragDelta = 0.0;

  @override
  void didUpdateWidget(covariant _VideoBlockContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.showWidth != widget.block.showWidth ||
        oldWidget.block.showHeight != widget.block.showHeight ||
        !widget.selected ||
        !widget.canResize) {
      _clearResizeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-video-block-${block.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _kMediaBlockMarginVertical / 2,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _VideoDisplayMetrics.resolve(
              block,
              availableWidth: constraints.maxWidth,
            );
            final displaySize = _previewSize ?? metrics.displaySize;
            if (displaySize.width <= 0 || displaySize.height <= 0) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: _imageBlockFigureAlignment(
                block.attributes.alignment,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.maxWidth),
                child: _buildFrame(
                  block: block,
                  frameSize: displaySize,
                  metrics: metrics,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrame({
    required VideoBlockNode block,
    required Size frameSize,
    required _VideoDisplayMetrics metrics,
  }) {
    final showResizeHitZones = widget.selected && widget.canResize;
    return SizedBox(
      key: _frameMeasureKey,
      width: frameSize.width,
      height: frameSize.height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          _MediaSelectionStroke(
            selected: widget.selected,
            child: DecoratedBox(
              key: ValueKey<String>('wenz-richtext-video-frame-${block.id}'),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(_kMediaCornerRadius),
                boxShadow: _kSurfaceBoxShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kMediaCornerRadius),
                child: AspectRatio(
                  key: ValueKey<String>(
                    'wenz-richtext-video-aspect-${block.id}',
                  ),
                  aspectRatio: metrics.aspectRatio,
                  child: _VideoFrameChildBoundary(child: widget.child),
                ),
              ),
            ),
          ),
          if (showResizeHitZones) ...<Widget>[
            _buildResizeHitZone(_ImageResizeEdge.left, metrics),
            _buildResizeHitZone(_ImageResizeEdge.right, metrics),
          ],
        ],
      ),
    );
  }

  Widget _buildResizeHitZone(
    _ImageResizeEdge edge,
    _VideoDisplayMetrics metrics,
  ) {
    const sideOffset = -_kImageResizeHandleHitWidth / 2;
    return Positioned(
      top: 0,
      bottom: 0,
      left: edge == _ImageResizeEdge.left ? sideOffset : null,
      right: edge == _ImageResizeEdge.right ? sideOffset : null,
      width: _kImageResizeHandleHitWidth,
      child: _ImageResizeHandle(
        blockId: widget.block.id,
        edge: edge,
        registry: widget.registry,
        mediaKeyPrefix: 'video',
        semanticSubject: '视频',
        onDragStart: () => _startResize(edge, metrics),
        onDragUpdate: _updateResize,
        onDragEnd: _finishResize,
        onDragCancel: _cancelResize,
      ),
    );
  }

  void _startResize(_ImageResizeEdge edge, _VideoDisplayMetrics metrics) {
    final measuredSize = _measuredFrameSize();
    final dragMetrics = _VideoDisplayMetrics.resolve(
      widget.block,
      availableWidth: metrics.maxWidth,
    );
    final startWidth =
        _positiveFiniteDimension(measuredSize?.width) ?? metrics.displayWidth;
    final safeWidth = dragMetrics.clampWidth(startWidth);
    final previewSize = Size(
      safeWidth,
      dragMetrics.heightForWidth(safeWidth),
    );
    setState(() {
      _dragMetrics = dragMetrics;
      _activeResizeEdge = edge;
      _resizeStartWidth = safeWidth;
      _resizeDragDelta = 0.0;
      _previewSize = previewSize;
    });
    widget.onPreviewSizeChanged?.call(previewSize);
  }

  void _updateResize(DragUpdateDetails details) {
    final metrics = _dragMetrics;
    final startWidth = _resizeStartWidth;
    final edge = _activeResizeEdge;
    if (metrics == null || startWidth == null || edge == null) {
      return;
    }
    _resizeDragDelta += details.delta.dx;
    final signedDelta =
        edge == _ImageResizeEdge.right ? _resizeDragDelta : -_resizeDragDelta;
    final width = metrics.clampWidth(startWidth + signedDelta);
    final height = metrics.heightForWidth(width);
    final current = _previewSize;
    if (current != null &&
        (current.width - width).abs() < _kImageResizeChangeEpsilon &&
        (current.height - height).abs() < _kImageResizeChangeEpsilon) {
      return;
    }
    final previewSize = Size(width, height);
    setState(() {
      _previewSize = previewSize;
    });
    widget.onPreviewSizeChanged?.call(previewSize);
  }

  void _finishResize() {
    final previewSize = _previewSize;
    final startWidth = _resizeStartWidth;
    final shouldCommit = previewSize != null &&
        startWidth != null &&
        (previewSize.width - startWidth).abs() >= _kImageResizeChangeEpsilon;
    _clearResizeStateWithRebuild();
    if (shouldCommit) {
      widget.onResize?.call(
        blockIndex: widget.blockIndex,
        width: previewSize.width,
        height: previewSize.height,
      );
    }
  }

  void _cancelResize() {
    _clearResizeStateWithRebuild();
  }

  Size? _measuredFrameSize() {
    final renderObject = _frameMeasureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = renderObject.size;
    final width = _positiveFiniteDimension(size.width);
    final height = _positiveFiniteDimension(size.height);
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  void _clearResizeStateWithRebuild() {
    if (_previewSize != null) {
      widget.onPreviewSizeChanged?.call(null);
    }
    if (!mounted) {
      _clearResizeState();
      return;
    }
    setState(_clearResizeState);
  }

  void _clearResizeState() {
    _previewSize = null;
    _dragMetrics = null;
    _activeResizeEdge = null;
    _resizeStartWidth = null;
    _resizeDragDelta = 0.0;
  }
}

class _VideoFrameChildBoundary extends StatelessWidget {
  const _VideoFrameChildBoundary({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        // Keep resolver output tightly bounded without adding a corner radius
        // here. Embedded radius is owned by _VideoBlockContent; fullscreen
        // previews receive the complete viewport and stay square.
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: child,
          ),
        );
      },
    );
  }
}

class _DividerBlockContent extends StatelessWidget {
  const _DividerBlockContent({
    required this.blockId,
    required this.selected,
  });

  final String blockId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellDecoration = selected
        ? BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          )
        : const BoxDecoration();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kDividerMarginVertical),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth.clamp(0.0, double.infinity).toDouble()
              : null;
          final divider = DecoratedBox(
            key: ValueKey<String>('wenz-richtext-divider-shell-$blockId'),
            decoration: shellDecoration,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 8 : 0,
                vertical: selected ? 8 : 0,
              ),
              child: SizedBox(
                height: _kDividerDotSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      top: (_kDividerDotSize - 1) / 2,
                      child: SizedBox(
                        height: 1,
                        child: DecoratedBox(
                          key: ValueKey<String>(
                            'wenz-richtext-divider-line-$blockId',
                          ),
                          decoration: BoxDecoration(
                            color: _dividerLineColor(theme),
                          ),
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: _kDividerDotSize,
                      child: DecoratedBox(
                        key: ValueKey<String>(
                          'wenz-richtext-divider-dot-$blockId',
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          if (width == null) {
            return divider;
          }
          return SizedBox(width: width, child: divider);
        },
      ),
    );
  }
}

class _ObjectMetadataList extends StatelessWidget {
  const _ObjectMetadataList({required this.entries});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final entry in entries)
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  entry,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmbedBlockCard extends StatelessWidget {
  const _EmbedBlockCard({
    super.key,
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
    this.onAction,
  });

  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final String label;
  final Color? backgroundColor;
  final Color borderColor;
  final Widget child;
  final ObjectBlockActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBorderColor =
        selected ? theme.colorScheme.primary : borderColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        foregroundPainter: _DashedRRectBorderPainter(
          color: resolvedBorderColor,
          radius: _kMediaCornerRadius,
          strokeWidth: 1,
          dashLength: 7,
          gapLength: 4,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(_kMediaCornerRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _BlockFloatingToolbarSurface(
              toolbar: selected
                  ? _FloatingObjectBlockToolbar(
                      blockIndex: blockIndex,
                      blockCount: blockCount,
                      canEdit: canEdit,
                      imageActions: false,
                      fileActions: false,
                      onAction: onAction,
                    )
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _EmbedTypeChip(label: label),
                  const SizedBox(width: 12),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmbedTypeChip extends StatelessWidget {
  const _EmbedTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _DashedRRectBorderPainter extends CustomPainter {
  const _DashedRRectBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashLength = 7,
    this.gapLength = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(strokeWidth / 2),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class _ObjectBlockToolbar extends StatelessWidget {
  const _ObjectBlockToolbar({
    required this.blockIndex,
    required this.blockCount,
    required this.canEdit,
    required this.imageActions,
    required this.fileActions,
    this.videoActions = false,
    this.imageAlignment,
    this.mediaActions = false,
    this.onAction,
    this.onEditImageDescription,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final bool imageActions;
  final bool fileActions;
  final bool videoActions;
  final String? imageAlignment;
  final bool mediaActions;
  final ObjectBlockActionHandler? onAction;
  final VoidCallback? onEditImageDescription;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final canDispatch = onAction != null;
    final canRunMutation = canEdit && canDispatch;
    final hasMoreActions = canRunMutation;
    if (mediaActions) {
      return Wrap(
        spacing: _kMinimalFloatingToolbarButtonGap,
        runSpacing: _kMinimalFloatingToolbarButtonGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _ObjectActionButton(
            icon: Icons.open_in_full,
            tooltip: '预览媒体',
            onPressed: onPreview,
          ),
          if (hasMoreActions)
            _ObjectMoreMenu(
              blockIndex: blockIndex,
              blockCount: blockCount,
              canRunMutation: canRunMutation,
              imageActions: imageActions,
              videoActions: videoActions,
              imageAlignment: imageAlignment,
              fileActions: fileActions,
              onEditImageDescription: onEditImageDescription,
              onSelected: _dispatchSelection,
            ),
        ],
      );
    }
    return Wrap(
      spacing: _kMinimalFloatingToolbarButtonGap,
      runSpacing: _kMinimalFloatingToolbarButtonGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _ObjectActionButton(
          icon: Icons.copy,
          tooltip: '复制块引用',
          onPressed: canDispatch
              ? () => _dispatch(ObjectBlockAction.copyReference)
              : null,
        ),
        if (hasMoreActions)
          _ObjectMoreMenu(
            blockIndex: blockIndex,
            blockCount: blockCount,
            canRunMutation: canRunMutation,
            imageActions: imageActions,
            videoActions: videoActions,
            imageAlignment: imageAlignment,
            fileActions: fileActions,
            onEditImageDescription: onEditImageDescription,
            onSelected: _dispatchSelection,
          ),
      ],
    );
  }

  void _dispatchSelection(_ObjectMenuSelection selection) {
    final action = selection.action;
    if (action != null) {
      _dispatch(action, selection.value);
      return;
    }
    if (selection.editImageDescription) {
      onEditImageDescription?.call();
    }
  }

  void _dispatch(ObjectBlockAction action, [Object? value]) {
    onAction?.call(
      ObjectBlockActionIntent(
        action: action,
        blockIndex: blockIndex,
        value: value,
      ),
    );
  }
}

class _ObjectMenuSelection {
  const _ObjectMenuSelection.action(this.action, [this.value])
      : format = null,
        editImageDescription = false,
        more = false;
  const _ObjectMenuSelection.format(this.format)
      : action = null,
        editImageDescription = false,
        value = null,
        more = false;
  const _ObjectMenuSelection.editImageDescription()
      : action = null,
        format = null,
        value = null,
        editImageDescription = true,
        more = false;
  const _ObjectMenuSelection.more()
      : action = null,
        format = null,
        value = null,
        editImageDescription = false,
        more = true;

  final ObjectBlockAction? action;
  final _RowBlockFormat? format;
  final Object? value;
  final bool editImageDescription;
  final bool more;
}

PopupMenuItem<_ObjectMenuSelection> _objectActionMenuItem({
  required ObjectBlockAction action,
  required IconData icon,
  required String label,
  Object? value,
  bool enabled = true,
  String? shortcut,
  bool selected = false,
  bool destructive = false,
}) {
  return PopupMenuItem<_ObjectMenuSelection>(
    value: _ObjectMenuSelection.action(action, value),
    enabled: enabled,
    height: _kPopupMenuItemHeight,
    padding: _kPopupMenuItemPadding,
    child: _PopupMenuItemContent(
      icon: icon,
      label: label,
      shortcut: shortcut,
      enabled: enabled,
      selected: selected,
      destructive: destructive,
    ),
  );
}

class _ObjectMoreMenu extends StatefulWidget {
  const _ObjectMoreMenu({
    required this.blockIndex,
    required this.blockCount,
    required this.canRunMutation,
    required this.imageActions,
    required this.fileActions,
    required this.videoActions,
    required this.onSelected,
    this.imageAlignment,
    this.onEditImageDescription,
  });

  final int blockIndex;
  final int blockCount;
  final bool canRunMutation;
  final bool imageActions;
  final bool fileActions;
  final bool videoActions;
  final ValueChanged<_ObjectMenuSelection> onSelected;
  final String? imageAlignment;
  final VoidCallback? onEditImageDescription;

  @override
  State<_ObjectMoreMenu> createState() => _ObjectMoreMenuState();
}

class _ObjectMoreMenuState extends State<_ObjectMoreMenu> {
  bool _menuOpen = false;
  NavigatorState? _navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void deactivate() {
    _closeOpenMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    _closeOpenMenu();
    super.dispose();
  }

  void _closeOpenMenu() {
    if (!_menuOpen) {
      return;
    }
    _menuOpen = false;
    final navigator = _navigator;
    _EditorPopupMenuDismissal.unregister(navigator);
    _EditorPopupMenuDismissal.dismissFrom(navigator);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _EditorPopupMenuDismissal.dismissFrom(navigator),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    return PopupMenuButton<_ObjectMenuSelection>(
      tooltip: '更多块操作',
      icon: const Icon(Icons.more_horiz),
      iconSize: tokens.minimalToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme, tokens: tokens),
      color: _popupMenuColor(theme),
      elevation: _kPopupMenuElevation,
      shadowColor: _popupMenuShadowColor(theme),
      surfaceTintColor: Colors.transparent,
      shape: _popupMenuShape(theme),
      menuPadding: _kPopupMenuPadding,
      position: PopupMenuPosition.under,
      clipBehavior: Clip.antiAlias,
      onOpened: () {
        _menuOpen = true;
        _EditorPopupMenuDismissal.register(_navigator);
      },
      onCanceled: () {
        _menuOpen = false;
        _EditorPopupMenuDismissal.unregister(_navigator);
      },
      onSelected: (selection) {
        _menuOpen = false;
        _EditorPopupMenuDismissal.unregister(_navigator);
        widget.onSelected(selection);
      },
      routeSettings: _kPopupMenuRouteSettings,
      itemBuilder: (context) => _items(),
    );
  }

  List<PopupMenuEntry<_ObjectMenuSelection>> _items() {
    final entries = <PopupMenuEntry<_ObjectMenuSelection>>[];
    if (widget.canRunMutation && !widget.imageActions) {
      entries.add(
        _objectActionMenuItem(
          action: ObjectBlockAction.duplicate,
          icon: Icons.copy_all_outlined,
          label: '创建块副本',
        ),
      );
    }
    if (widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _objectActionMenuItem(
          action: ObjectBlockAction.moveUp,
          icon: Icons.arrow_upward,
          label: '上移块',
          enabled: BlockDragHandleSpec.canMoveUp(
            canEdit: widget.canRunMutation,
            blockIndex: widget.blockIndex,
            blockCount: widget.blockCount,
          ),
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.moveDown,
          icon: Icons.arrow_downward,
          label: '下移块',
          enabled: BlockDragHandleSpec.canMoveDown(
            canEdit: widget.canRunMutation,
            blockIndex: widget.blockIndex,
            blockCount: widget.blockCount,
          ),
        ),
      ]);
    }
    if ((widget.imageActions || widget.videoActions) && widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
      final mediaAlignment = widget.imageAlignment;
      final mediaLabel = widget.videoActions ? '视频' : '图片';
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        if (widget.imageActions && widget.onEditImageDescription != null) ...[
          const PopupMenuItem<_ObjectMenuSelection>(
            value: _ObjectMenuSelection.editImageDescription(),
            height: _kPopupMenuItemHeight,
            padding: _kPopupMenuItemPadding,
            child: _PopupMenuItemContent(
              icon: Icons.closed_caption_outlined,
              label: '修改图片描述',
              enabled: true,
            ),
          ),
          _popupMenuDivider<_ObjectMenuSelection>(),
        ],
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageBlockAlignment,
          icon: Icons.format_align_left,
          label: '$mediaLabel左对齐',
          value: 'left',
          enabled: mediaAlignment != 'left',
          selected: mediaAlignment == 'left',
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageBlockAlignment,
          icon: Icons.format_align_center,
          label: '$mediaLabel居中',
          value: 'center',
          enabled: mediaAlignment != 'center',
          selected: mediaAlignment == 'center',
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageBlockAlignment,
          icon: Icons.format_align_right,
          label: '$mediaLabel右对齐',
          value: 'right',
          enabled: mediaAlignment != 'right',
          selected: mediaAlignment == 'right',
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageBlockAlignment,
          icon: Icons.format_clear,
          label: '清除$mediaLabel对齐',
          enabled: mediaAlignment != null,
        ),
        _popupMenuDivider<_ObjectMenuSelection>(),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.photo_size_select_small_outlined,
          label: '$mediaLabel宽度：小',
          value: 240.0,
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.photo_size_select_large_outlined,
          label: '$mediaLabel宽度：中',
          value: 360.0,
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.fit_screen_outlined,
          label: '$mediaLabel宽度：大',
          value: 520.0,
        ),
        _popupMenuDivider<_ObjectMenuSelection>(),
        _objectActionMenuItem(
          action: ObjectBlockAction.resetImageSize,
          icon: Icons.restart_alt,
          label: '重置$mediaLabel尺寸',
        ),
      ]);
    }
    if (widget.fileActions && widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _objectActionMenuItem(
          action: ObjectBlockAction.markFileUploading,
          icon: Icons.cloud_upload_outlined,
          label: '标记为上传中',
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.markFileUploaded,
          icon: Icons.cloud_done_outlined,
          label: '标记为已上传',
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.markFileFailed,
          icon: Icons.cloud_off_outlined,
          label: '标记为失败',
        ),
      ]);
    }
    if (widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(_popupMenuDivider<_ObjectMenuSelection>());
      }
      entries.add(
        _objectActionMenuItem(
          action: ObjectBlockAction.delete,
          icon: Icons.delete_outline,
          label: '删除块',
          destructive: true,
        ),
      );
    }
    return entries;
  }
}

class _ImageDescriptionEditDialog extends StatefulWidget {
  const _ImageDescriptionEditDialog({
    required this.caption,
    required this.altText,
  });

  final String caption;
  final String altText;

  @override
  State<_ImageDescriptionEditDialog> createState() =>
      _ImageDescriptionEditDialogState();
}

class _ImageDescriptionEditDialogState
    extends State<_ImageDescriptionEditDialog> {
  late final TextEditingController _captionController;
  late final TextEditingController _altTextController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.caption);
    _altTextController = TextEditingController(text: widget.altText);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _altTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改图片描述'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _captionController,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '可见图注',
                hintText: '显示在图片下方',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _altTextController,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '替代文本',
                hintText: '供屏幕阅读器使用',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ImageDescriptionEditResult(
                caption: _captionController.text,
                altText: _altTextController.text,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _FloatingObjectBlockToolbar extends StatelessWidget {
  const _FloatingObjectBlockToolbar({
    required this.blockIndex,
    required this.blockCount,
    required this.canEdit,
    required this.imageActions,
    required this.fileActions,
    this.videoActions = false,
    this.imageAlignment,
    this.mediaActions = false,
    this.onAction,
    this.onEditImageDescription,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final bool imageActions;
  final bool fileActions;
  final bool videoActions;
  final String? imageAlignment;
  final bool mediaActions;
  final ObjectBlockActionHandler? onAction;
  final VoidCallback? onEditImageDescription;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return _MinimalFloatingToolbarSurface(
      child: _ObjectBlockToolbar(
        blockIndex: blockIndex,
        blockCount: blockCount,
        canEdit: canEdit,
        imageActions: imageActions,
        fileActions: fileActions,
        videoActions: videoActions,
        imageAlignment: imageAlignment,
        mediaActions: mediaActions,
        onAction: onAction,
        onEditImageDescription: onEditImageDescription,
        onPreview: onPreview,
      ),
    );
  }
}

class _ObjectActionButton extends StatelessWidget {
  const _ObjectActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: tokens.minimalToolbarButtonSize,
        height: tokens.minimalToolbarButtonSize,
      ),
      iconSize: tokens.minimalToolbarIconSize,
      style: _blockToolbarIconButtonStyle(theme, tokens: tokens),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _FileBlockContent extends StatefulWidget {
  const _FileBlockContent({
    required this.block,
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    this.onAction,
  });

  final FileBlockNode block;
  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final ObjectBlockActionHandler? onAction;

  @override
  State<_FileBlockContent> createState() => _FileBlockContentState();
}

class _FileBlockContentState extends State<_FileBlockContent> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = widget.block;
    final failed = block.uploadStatus == FileUploadStatus.failed;
    final active = widget.selected || _hovered || _focused;
    final borderColor =
        active ? theme.colorScheme.primary : _fileCardBorderColor(theme);
    final foregroundColor =
        failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    final sizeLabel = block.size > 0 ? _formatFileSize(block.size) : '';
    final subtitle = _fileSubtitle(block);
    final statusText = _fileStatusText(block);
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) {
        if (_hovered != value) {
          setState(() {
            _hovered = value;
          });
        }
      },
      onShowFocusHighlight: (value) {
        if (_focused != value) {
          setState(() {
            _focused = value;
          });
        }
      },
      child: AnimatedContainer(
        key: ValueKey<String>('wenz-richtext-file-card-${block.id}'),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hovered || _focused ? _kSurfaceBoxShadow : null,
        ),
        child: _BlockFloatingToolbarSurface(
          toolbar: _FileBlockActionMenu(
            blockIndex: widget.blockIndex,
            blockCount: widget.blockCount,
            canEdit: widget.canEdit,
            onAction: widget.onAction,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _FileTypeBadge(
                  label: _fileTypeLabel(block),
                  failed: failed,
                ),
                const SizedBox(width: _kFileCardGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        block.displayName.isEmpty
                            ? 'Untitled file'
                            : block.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          key: ValueKey<String>(
                              'wenz-richtext-file-meta-${block.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (statusText.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          key: ValueKey<String>(
                              'wenz-richtext-file-status-${block.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: failed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (sizeLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  Text(
                    sizeLabel,
                    key:
                        ValueKey<String>('wenz-richtext-file-size-${block.id}'),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTypeBadge extends StatelessWidget {
  const _FileTypeBadge({required this.label, required this.failed});

  final String label;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = failed
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foregroundColor =
        failed ? theme.colorScheme.onErrorContainer : theme.colorScheme.primary;
    return SizedBox.square(
      dimension: _kFileIconSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FileBlockActionMenu extends StatelessWidget {
  const _FileBlockActionMenu({
    required this.blockIndex,
    required this.blockCount,
    required this.canEdit,
    this.onAction,
  });

  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final ObjectBlockActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    return PopupMenuButton<_ObjectMenuSelection>(
      tooltip: '附件操作',
      icon: const Icon(Icons.more_horiz),
      iconSize: tokens.minimalToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme, tokens: tokens),
      color: _popupMenuColor(theme),
      elevation: _kPopupMenuElevation,
      shadowColor: _popupMenuShadowColor(theme),
      surfaceTintColor: Colors.transparent,
      shape: _popupMenuShape(theme),
      menuPadding: _kPopupMenuPadding,
      position: PopupMenuPosition.under,
      clipBehavior: Clip.antiAlias,
      onSelected: _dispatch,
      routeSettings: _kPopupMenuRouteSettings,
      itemBuilder: (context) => <PopupMenuEntry<_ObjectMenuSelection>>[
        _objectActionMenuItem(
          action: ObjectBlockAction.copyReference,
          icon: Icons.link,
          label: '复制块引用',
        ),
        _popupMenuDivider<_ObjectMenuSelection>(),
        ..._moreItems(),
      ],
    );
  }

  List<PopupMenuEntry<_ObjectMenuSelection>> _moreItems() {
    final canRunMutation = canEdit && onAction != null;
    return <PopupMenuEntry<_ObjectMenuSelection>>[
      _objectActionMenuItem(
        action: ObjectBlockAction.duplicate,
        icon: Icons.copy_all_outlined,
        label: '创建块副本',
        enabled: canRunMutation,
      ),
      _popupMenuDivider<_ObjectMenuSelection>(),
      _objectActionMenuItem(
        action: ObjectBlockAction.moveUp,
        icon: Icons.arrow_upward,
        label: '上移块',
        enabled: BlockDragHandleSpec.canMoveUp(
          canEdit: canRunMutation,
          blockIndex: blockIndex,
          blockCount: blockCount,
        ),
      ),
      _objectActionMenuItem(
        action: ObjectBlockAction.moveDown,
        icon: Icons.arrow_downward,
        label: '下移块',
        enabled: BlockDragHandleSpec.canMoveDown(
          canEdit: canRunMutation,
          blockIndex: blockIndex,
          blockCount: blockCount,
        ),
      ),
      _popupMenuDivider<_ObjectMenuSelection>(),
      _objectActionMenuItem(
        action: ObjectBlockAction.markFileUploading,
        icon: Icons.cloud_upload_outlined,
        label: '标记为上传中',
        enabled: canRunMutation,
      ),
      _objectActionMenuItem(
        action: ObjectBlockAction.markFileUploaded,
        icon: Icons.cloud_done_outlined,
        label: '标记为已上传',
        enabled: canRunMutation,
      ),
      _objectActionMenuItem(
        action: ObjectBlockAction.markFileFailed,
        icon: Icons.cloud_off_outlined,
        label: '标记为失败',
        enabled: canRunMutation,
      ),
      _popupMenuDivider<_ObjectMenuSelection>(),
      _objectActionMenuItem(
        action: ObjectBlockAction.delete,
        icon: Icons.delete_outline,
        label: '删除块',
        enabled: canRunMutation,
        destructive: true,
      ),
    ];
  }

  void _dispatch(_ObjectMenuSelection selection) {
    final action = selection.action;
    if (action == null) {
      return;
    }
    onAction?.call(
      ObjectBlockActionIntent(
        action: action,
        blockIndex: blockIndex,
        value: selection.value,
      ),
    );
  }
}

class _ImageDisplayMetrics {
  const _ImageDisplayMetrics._({
    required this.aspectRatio,
    required this.minWidth,
    required this.maxWidth,
    this.displayWidth,
  });

  factory _ImageDisplayMetrics.resolve(
    ImageBlockNode block, {
    double? availableWidth,
    Size? measuredFrameSize,
  }) {
    final aspectRatio = _imageAspectRatio(
      block,
      measuredFrameSize: measuredFrameSize,
    );
    final showWidth = _positiveFiniteDimension(block.showWidth);
    final showHeight = _positiveFiniteDimension(block.showHeight);
    final explicitWidth = showWidth ?? _widthForHeight(showHeight, aspectRatio);
    final naturalWidth = _positiveFiniteDimension(block.width) ??
        _widthForHeight(_positiveFiniteDimension(block.height), aspectRatio);
    final rawMaxWidth = _nonNegativeFiniteDimension(availableWidth) ??
        _nonNegativeFiniteDimension(measuredFrameSize?.width) ??
        explicitWidth ??
        _kFallbackImageDisplayMaxWidth;
    final maxWidth = math.max(0.0, rawMaxWidth);
    final minWidth = math.min(_kMinImageDisplayWidth, maxWidth);
    final preferredWidth = explicitWidth ?? naturalWidth ?? maxWidth;
    final displayWidth = preferredWidth.clamp(minWidth, maxWidth).toDouble();
    return _ImageDisplayMetrics._(
      aspectRatio: aspectRatio,
      minWidth: minWidth,
      maxWidth: maxWidth,
      displayWidth: displayWidth,
    );
  }

  final double aspectRatio;
  final double minWidth;
  final double maxWidth;
  final double? displayWidth;

  double? get displayHeight {
    final width = displayWidth;
    return width == null ? null : heightForWidth(width);
  }

  Size? get displaySize {
    final width = displayWidth;
    final height = displayHeight;
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  double clampWidth(double width) {
    final safeWidth = _positiveFiniteDimension(width) ?? minWidth;
    return safeWidth.clamp(minWidth, maxWidth).toDouble();
  }

  double heightForWidth(double width) {
    final safeWidth = clampWidth(width);
    return math.max(1.0, safeWidth / aspectRatio);
  }
}

double _imageAspectRatio(
  ImageBlockNode block, {
  Size? measuredFrameSize,
}) {
  final explicitAspectRatio = _boundedImageAspectRatio(
    _aspectRatioForDimensions(block.showWidth, block.showHeight),
  );
  if (explicitAspectRatio != null) {
    return explicitAspectRatio;
  }
  return _boundedImageAspectRatio(
        _aspectRatioForDimensions(block.width, block.height),
      ) ??
      _boundedImageAspectRatio(
        _aspectRatioForDimensions(
          measuredFrameSize?.width,
          measuredFrameSize?.height,
        ),
      ) ??
      _kImagePlaceholderAspectRatio;
}

double? _aspectRatioForDimensions(num? width, num? height) {
  final safeWidth = _positiveFiniteDimension(width);
  final safeHeight = _positiveFiniteDimension(height);
  if (safeWidth == null || safeHeight == null) {
    return null;
  }
  final ratio = safeWidth / safeHeight;
  return ratio.isFinite && ratio > 0 ? ratio : null;
}

double? _boundedImageAspectRatio(double? ratio) {
  if (ratio == null || !ratio.isFinite || ratio <= 0) {
    return null;
  }
  return ratio.clamp(_kMinImageAspectRatio, _kMaxImageAspectRatio).toDouble();
}

double? _widthForHeight(double? height, double aspectRatio) {
  if (height == null) {
    return null;
  }
  final width = height * aspectRatio;
  return width.isFinite && width > 0 ? width : null;
}

double? _positiveFiniteDimension(num? value) {
  if (value == null) {
    return null;
  }
  final dimension = value.toDouble();
  return dimension.isFinite && dimension > 0 ? dimension : null;
}

int? _dimensionSignature(num? value) {
  final dimension = _positiveFiniteDimension(value);
  return dimension == null ? null : (dimension * 1000).round();
}

double? _nonNegativeFiniteDimension(num? value) {
  if (value == null) {
    return null;
  }
  final dimension = value.toDouble();
  return dimension.isFinite && dimension >= 0 ? dimension : null;
}

enum _ImageResizeEdge { left, right }

class _ImageBlockContent extends StatefulWidget {
  const _ImageBlockContent({
    required this.block,
    required this.blockIndex,
    required this.child,
    required this.selected,
    required this.canResize,
    required this.registry,
    this.onResize,
    this.onPreviewSizeChanged,
    this.onResizeCommitted,
  });

  final ImageBlockNode block;
  final int blockIndex;
  final Widget child;
  final bool selected;
  final bool canResize;
  final BlockGeometryRegistry registry;
  final ImageBlockResizeHandler? onResize;
  final ValueChanged<Size?>? onPreviewSizeChanged;
  final ValueChanged<Size?>? onResizeCommitted;

  @override
  State<_ImageBlockContent> createState() => _ImageBlockContentState();
}

class _ImageBlockContentState extends State<_ImageBlockContent> {
  final GlobalKey _frameMeasureKey = GlobalKey();
  Size? _previewSize;
  Size? _lastNotifiedFrameSize;
  _ImageDisplayMetrics? _dragMetrics;
  _ImageResizeEdge? _activeResizeEdge;
  double? _resizeStartWidth;
  double _resizeDragDelta = 0.0;

  @override
  void didUpdateWidget(covariant _ImageBlockContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.width != widget.block.width ||
        oldWidget.block.height != widget.block.height ||
        oldWidget.block.showWidth != widget.block.showWidth ||
        oldWidget.block.showHeight != widget.block.showHeight ||
        !widget.selected ||
        !widget.canResize) {
      _clearResizeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = widget.block;
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-image-block-${block.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _kMediaBlockMarginVertical / 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _ImageDisplayMetrics.resolve(
              block,
              availableWidth: constraints.maxWidth,
            );
            final displaySize = _previewSize ??
                metrics.displaySize ??
                Size(
                  metrics.maxWidth,
                  metrics.heightForWidth(metrics.maxWidth),
                );
            _notifyFrameSize(displaySize);
            final media = SizedBox(
              key: ValueKey<String>('wenz-richtext-image-size-${block.id}'),
              width: displaySize.width,
              height: displaySize.height,
              child: _ImageFrameChildBoundary(child: widget.child),
            );
            final frame = _buildFrame(
              context: context,
              theme: theme,
              block: block,
              frameSize: displaySize,
              media: media,
              metrics: metrics,
            );
            return Align(
              alignment: _imageBlockFigureAlignment(
                block.attributes.alignment,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.maxWidth),
                child: Semantics(
                  // altText surfaces here (altText > caption > asset),
                  // cooperating with the block-level label so screen
                  // readers announce the image without a duplicate node.
                  label: _imageAccessibleLabel(block),
                  image: true,
                  child: frame,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _notifyFrameSize(Size size) {
    final width = _positiveFiniteDimension(size.width);
    final height = _positiveFiniteDimension(size.height);
    if (width == null || height == null) {
      return;
    }
    final next = Size(width, height);
    final previous = _lastNotifiedFrameSize;
    if (previous != null &&
        (previous.width - next.width).abs() < _kImageResizeChangeEpsilon &&
        (previous.height - next.height).abs() < _kImageResizeChangeEpsilon) {
      return;
    }
    _lastNotifiedFrameSize = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastNotifiedFrameSize != next) {
        return;
      }
      widget.onPreviewSizeChanged?.call(next);
    });
  }

  Widget _buildFrame({
    required BuildContext context,
    required ThemeData theme,
    required ImageBlockNode block,
    required Size frameSize,
    required Widget media,
    required _ImageDisplayMetrics metrics,
  }) {
    final showResizeHitZones = widget.selected && widget.canResize;
    return SizedBox(
      key: _frameMeasureKey,
      width: frameSize.width,
      height: frameSize.height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          _MediaSelectionStroke(
            selected: widget.selected,
            child: DecoratedBox(
              key: ValueKey<String>('wenz-richtext-image-frame-${block.id}'),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(_kMediaCornerRadius),
                boxShadow: _kSurfaceBoxShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kMediaCornerRadius),
                child: media,
              ),
            ),
          ),
          if (showResizeHitZones) ...<Widget>[
            _buildResizeHitZone(_ImageResizeEdge.left, metrics),
            _buildResizeHitZone(_ImageResizeEdge.right, metrics),
          ],
        ],
      ),
    );
  }

  Widget _buildResizeHitZone(
    _ImageResizeEdge edge,
    _ImageDisplayMetrics metrics,
  ) {
    const sideOffset = -_kImageResizeHandleHitWidth / 2;
    return Positioned(
      top: 0,
      bottom: 0,
      left: edge == _ImageResizeEdge.left ? sideOffset : null,
      right: edge == _ImageResizeEdge.right ? sideOffset : null,
      width: _kImageResizeHandleHitWidth,
      child: _ImageResizeHandle(
        blockId: widget.block.id,
        edge: edge,
        registry: widget.registry,
        onDragStart: () => _startResize(edge, metrics),
        onDragUpdate: _updateResize,
        onDragEnd: _finishResize,
        onDragCancel: _cancelResize,
      ),
    );
  }

  void _startResize(_ImageResizeEdge edge, _ImageDisplayMetrics metrics) {
    final measuredSize = _measuredFrameSize();
    final dragMetrics = _ImageDisplayMetrics.resolve(
      widget.block,
      availableWidth: metrics.maxWidth,
      measuredFrameSize: measuredSize,
    );
    final startWidth = _positiveFiniteDimension(measuredSize?.width) ??
        metrics.displayWidth ??
        dragMetrics.maxWidth;
    final safeWidth = dragMetrics.clampWidth(startWidth);
    final startHeight = _positiveFiniteDimension(measuredSize?.height) ??
        dragMetrics.heightForWidth(safeWidth);
    final previewSize = Size(safeWidth, startHeight);
    setState(() {
      _dragMetrics = dragMetrics;
      _activeResizeEdge = edge;
      _resizeStartWidth = safeWidth;
      _resizeDragDelta = 0.0;
      _previewSize = previewSize;
    });
    widget.onPreviewSizeChanged?.call(previewSize);
  }

  void _updateResize(DragUpdateDetails details) {
    final metrics = _dragMetrics;
    final startWidth = _resizeStartWidth;
    final edge = _activeResizeEdge;
    if (metrics == null || startWidth == null || edge == null) {
      return;
    }
    _resizeDragDelta += details.delta.dx;
    final signedDelta =
        edge == _ImageResizeEdge.right ? _resizeDragDelta : -_resizeDragDelta;
    final width = metrics.clampWidth(startWidth + signedDelta);
    final height = metrics.heightForWidth(width);
    final current = _previewSize;
    if (current != null &&
        (current.width - width).abs() < _kImageResizeChangeEpsilon &&
        (current.height - height).abs() < _kImageResizeChangeEpsilon) {
      return;
    }
    final previewSize = Size(width, height);
    setState(() {
      _previewSize = previewSize;
    });
    widget.onPreviewSizeChanged?.call(previewSize);
  }

  void _finishResize() {
    final previewSize = _previewSize;
    final startWidth = _resizeStartWidth;
    final shouldCommit = previewSize != null &&
        startWidth != null &&
        (previewSize.width - startWidth).abs() >= _kImageResizeChangeEpsilon;
    if (previewSize != null) {
      widget.onResizeCommitted?.call(previewSize);
    }
    _clearResizeStateWithRebuild();
    if (shouldCommit) {
      widget.onResize?.call(
        blockIndex: widget.blockIndex,
        width: previewSize.width,
        height: previewSize.height,
      );
    }
  }

  void _cancelResize() {
    _clearResizeStateWithRebuild();
  }

  Size? _measuredFrameSize() {
    final renderObject = _frameMeasureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = renderObject.size;
    final width = _positiveFiniteDimension(size.width);
    final height = _positiveFiniteDimension(size.height);
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  void _clearResizeStateWithRebuild() {
    if (_previewSize != null) {
      widget.onPreviewSizeChanged?.call(null);
    }
    if (!mounted) {
      _clearResizeState();
      return;
    }
    setState(_clearResizeState);
  }

  void _clearResizeState() {
    _previewSize = null;
    _lastNotifiedFrameSize = null;
    _dragMetrics = null;
    _activeResizeEdge = null;
    _resizeStartWidth = null;
    _resizeDragDelta = 0.0;
  }
}

class _ImageFrameChildBoundary extends StatelessWidget {
  const _ImageFrameChildBoundary({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        // Keep resolver output bounded to the image frame; rounded clipping is
        // owned by _ImageBlockContent so placeholder and real media share it.
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: child,
          ),
        );
      },
    );
  }
}

class _ImageResizeHandle extends StatefulWidget {
  const _ImageResizeHandle({
    required this.blockId,
    required this.edge,
    required this.registry,
    this.mediaKeyPrefix = 'image',
    this.semanticSubject = '图片',
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final String blockId;
  final _ImageResizeEdge edge;
  final BlockGeometryRegistry registry;
  final String mediaKeyPrefix;
  final String semanticSubject;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  State<_ImageResizeHandle> createState() => _ImageResizeHandleState();
}

class _ImageResizeHandleState extends State<_ImageResizeHandle> {
  final GlobalKey _hitTestKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_hitTestKey);
  }

  @override
  void didUpdateWidget(covariant _ImageResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_hitTestKey);
      widget.registry.registerSelectionExclusion(_hitTestKey);
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edgeName = widget.edge == _ImageResizeEdge.left ? 'left' : 'right';
    final semanticLabel = widget.edge == _ImageResizeEdge.left
        ? '拖拽左边缘调整${widget.semanticSubject}宽度'
        : '拖拽右边缘调整${widget.semanticSubject}宽度';
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: _hitTestKey,
          behavior: HitTestBehavior.translucent,
          onTap: () {},
          onDoubleTap: () {},
          onHorizontalDragStart: (_) => widget.onDragStart(),
          onHorizontalDragUpdate: widget.onDragUpdate,
          onHorizontalDragEnd: (_) => widget.onDragEnd(),
          onHorizontalDragCancel: widget.onDragCancel,
          child: Tooltip(
            message: semanticLabel,
            child: SizedBox.expand(
              key: ValueKey<String>(
                'wenz-richtext-${widget.mediaKeyPrefix}-resize-hit-zone-'
                '$edgeName-${widget.blockId}',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

AlignmentDirectional _imageBlockFigureAlignment(String? alignment) {
  return switch (alignment) {
    'left' => AlignmentDirectional.centerStart,
    'right' => AlignmentDirectional.centerEnd,
    'center' => AlignmentDirectional.center,
    _ => AlignmentDirectional.center,
  };
}

/// Paints a selection stroke that hugs the media frame. Unlike the generic
/// [_BlockObjectSelectionSurface] overlay — which fills the whole block (and
/// therefore floats over the vertical [_kMediaBlockMarginVertical] margins and
/// uses a fixed radius) — this stroke is laid out on the frame's own rectangle,
/// so it matches the media's real size and corner radius. Media blocks disable
/// the generic overlay and draw this instead, keeping hit-test/geometry
/// registration and double-tap preview untouched.
class _MediaSelectionStroke extends StatelessWidget {
  const _MediaSelectionStroke({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return child;
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: _mediaSelectionStrokeKey,
              decoration: BoxDecoration(
                border: Border.all(color: primary, width: 2),
                borderRadius: BorderRadius.circular(_kMediaCornerRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double? _preferredImageFrameWidth(ImageBlockNode block) {
  final hasPersistedSize = _positiveFiniteDimension(block.showWidth) != null ||
      _positiveFiniteDimension(block.showHeight) != null ||
      _positiveFiniteDimension(block.width) != null ||
      _positiveFiniteDimension(block.height) != null;
  if (!hasPersistedSize) {
    return null;
  }
  return _ImageDisplayMetrics.resolve(block).displayWidth;
}

double? _preferredVideoFrameWidth(VideoBlockNode block) {
  final hasPersistedSize = _positiveFiniteDimension(block.showWidth) != null ||
      _positiveFiniteDimension(block.showHeight) != null;
  if (!hasPersistedSize) {
    return null;
  }
  return _VideoDisplayMetrics.resolve(block).displayWidth;
}

class _MediaBlockChrome extends StatelessWidget {
  const _MediaBlockChrome({
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    required this.imageActions,
    this.videoActions = false,
    required this.child,
    this.blockId,
    this.imageAlignment,
    this.toolbarFrameWidth,
    this.toolbarFrameAlignment,
    this.toolbarOverlayController,
    this.onAction,
    this.onEditImageDescription,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final String? blockId;
  final bool selected;
  final bool canEdit;
  final bool imageActions;
  final bool videoActions;
  final Widget child;
  final double? toolbarFrameWidth;
  final String? imageAlignment;
  final AlignmentDirectional? toolbarFrameAlignment;
  final ObjectBlockToolbarOverlayController? toolbarOverlayController;
  final ObjectBlockActionHandler? onAction;
  final VoidCallback? onEditImageDescription;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: toolbarFrameAlignment ?? AlignmentDirectional.centerStart,
      child: child,
    );
    final overlayController = toolbarOverlayController;
    final overlayBlockId = blockId;
    if (overlayController != null && overlayBlockId != null) {
      return _buildOverlayAnchoredContent(
        controller: overlayController,
        overlayBlockId: overlayBlockId,
        content: content,
      );
    }
    if (!selected) {
      return content;
    }
    final toolbar = _buildToolbar();
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _constrainToAvailableWidth(
              availableWidth,
              _buildToolbarHost(availableWidth, toolbar),
            ),
            const SizedBox(height: _kBlockFloatingToolbarInset),
            _constrainToAvailableWidth(availableWidth, content),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return _FloatingObjectBlockToolbar(
      blockIndex: blockIndex,
      blockCount: blockCount,
      canEdit: canEdit,
      imageActions: imageActions,
      videoActions: videoActions,
      imageAlignment: imageAlignment,
      fileActions: false,
      mediaActions: true,
      onAction: onAction,
      onEditImageDescription: onEditImageDescription,
      onPreview: onPreview,
    );
  }

  double _mediaToolbarEstimatedWidth() {
    final canRunMutation = canEdit && onAction != null;
    final buttonCount = canRunMutation ? 2 : 1;
    return _kMinimalFloatingToolbarPadding.horizontal +
        (_kBlockToolbarButtonSize * buttonCount) +
        (_kMinimalFloatingToolbarButtonGap * (buttonCount - 1));
  }

  Widget _buildOverlayAnchoredContent({
    required ObjectBlockToolbarOverlayController controller,
    required String overlayBlockId,
    required Widget content,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final anchorWidth = _overlayToolbarFrameWidth(availableWidth);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            content,
            PositionedDirectional(
              start: 0,
              end: 0,
              top: _kMediaBlockMarginVertical / 2,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Align(
                    alignment:
                        toolbarFrameAlignment ?? AlignmentDirectional.center,
                    child: ObjectBlockToolbarOverlayAnchor(
                      controller: controller,
                      blockId: overlayBlockId,
                      blockIndex: blockIndex,
                      requestBuilder: selected
                          ? ({
                              required Object owner,
                              required LayerLink anchorLink,
                              required Rect anchorRect,
                              required double visibleTop,
                            }) =>
                              ObjectBlockToolbarOverlayRequest(
                                owner: owner,
                                anchorLink: anchorLink,
                                anchorRect: anchorRect,
                                visibleTop: visibleTop,
                                blockId: overlayBlockId,
                                blockIndex: blockIndex,
                                minWidth: _mediaToolbarEstimatedWidth(),
                                gap: _kBlockFloatingToolbarInset,
                                fallbackHeight: _kMediaToolbarEstimatedHeight,
                                toolbarBuilder: (_) => _buildToolbar(),
                              )
                          : null,
                      child: SizedBox(width: anchorWidth, height: 0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _overlayToolbarFrameWidth(double availableWidth) {
    final resolved = _resolvedToolbarFrameWidth(availableWidth);
    if (resolved != null && resolved.isFinite && resolved > 0) {
      return resolved;
    }
    if (availableWidth.isFinite && availableWidth > 0) {
      return availableWidth;
    }
    return _mediaToolbarEstimatedWidth();
  }

  Widget _buildToolbarHost(double availableWidth, Widget toolbar) {
    final frameWidth = _resolvedToolbarFrameWidth(availableWidth);
    if (frameWidth == null) {
      final alignment = toolbarFrameAlignment;
      if (alignment != null) {
        return Align(
          alignment: alignment,
          child: toolbar,
        );
      }
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: toolbar,
      );
    }
    return Align(
      alignment: toolbarFrameAlignment ?? AlignmentDirectional.center,
      child: SizedBox(
        width: frameWidth,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: frameWidth),
            child: toolbar,
          ),
        ),
      ),
    );
  }

  Widget _constrainToAvailableWidth(double availableWidth, Widget child) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return child;
    }
    return SizedBox(width: availableWidth, child: child);
  }

  double? _resolvedToolbarFrameWidth(double availableWidth) {
    final preferred = toolbarFrameWidth;
    if (preferred != null && preferred.isFinite && preferred > 0) {
      return availableWidth.isFinite && availableWidth > 0
          ? math.min(preferred, availableWidth)
          : preferred;
    }
    return availableWidth.isFinite && availableWidth > 0
        ? availableWidth
        : null;
  }
}

class _CalloutRenderer extends StatefulWidget {
  const _CalloutRenderer({
    required this.block,
    required this.blockIndex,
    required this.selection,
    required this.compositionState,
    required this.registry,
    required this.showCaret,
    this.textStyle,
    required this.selected,
    required this.showDebugOverlay,
    this.inlineEmbedRenderer,
    this.onVariantChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final CalloutBlockNode block;
  final int blockIndex;
  final DocumentSelection? selection;
  final CompositionState? compositionState;
  final BlockGeometryRegistry registry;
  final bool showCaret;
  final TextStyle? textStyle;
  final bool selected;
  final bool showDebugOverlay;
  final InlineEmbedRenderer? inlineEmbedRenderer;
  final ValueChanged<String>? onVariantChanged;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  State<_CalloutRenderer> createState() => _CalloutRendererState();
}

class _CalloutRendererState extends State<_CalloutRenderer> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
    final base = _richTextBodyStyle(theme, widget.textStyle, tokens);
    final variant = widget.block.normalizedVariant;
    final tint = _calloutTint(theme, variant);
    final foreground = _calloutForeground(theme, variant);
    final bodyStyle = base.copyWith(color: foreground);
    final titleStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
    final path = PositionPath.blockText(widget.block.id);
    final compositionRange = _localCompositionRange(
      widget.compositionState,
      widget.block.id,
      widget.blockIndex,
      path,
    );
    final textLength = inlineNodesLength(widget.block.content);
    final inlineTextLayout = _inlineTextLayoutFor(
      context,
      widget.block.content,
      bodyStyle,
      compositionRange,
      widget.inlineEmbedRenderer,
      blockId: widget.block.id,
      blockIndex: widget.blockIndex,
      path: path,
    );
    final borderColor = widget.selected
        ? theme.colorScheme.primary
        : _calloutBorder(theme, variant);
    final borderWidth = widget.selected ? 1.5 : 1.0;
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-callout-${widget.block.id}'),
      child: DecoratedBox(
        key: _cardKey,
        decoration: BoxDecoration(
          color: tint,
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CalloutIcon(icon: widget.block.effectiveIcon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(widget.block.effectiveTitle,
                              style: titleStyle),
                        ),
                        _CalloutVariantMenu(
                          registry: widget.registry,
                          variant: variant,
                          foreground: foreground,
                          onChanged: widget.onVariantChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _TextSelectionSurface(
                      blockId: widget.block.id,
                      blockIndex: widget.blockIndex,
                      path: path,
                      textLength: textLength,
                      textSpan: TextSpan(
                        style: bodyStyle,
                        children: inlineTextLayout.spans,
                      ),
                      offsetMapper: inlineTextLayout.offsetMapper,
                      textAlign: TextAlign.start,
                      minHeight:
                          (bodyStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
                      selection: widget.selection,
                      showCaret: widget.showCaret,
                      registry: widget.registry,
                      showDebugOverlay: widget.showDebugOverlay,
                      findRanges: _findRangesForPath(
                        widget.findMatches,
                        widget.currentFindMatch,
                        widget.blockIndex,
                        path,
                        textLength,
                      ),
                      hitTestKey: _cardKey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalloutIcon extends StatelessWidget {
  const _CalloutIcon({required this.icon, required this.color});

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        icon,
        style: TextStyle(
          color: color,
          fontSize: _kCalloutIconFontSize,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CalloutVariantMenu extends StatefulWidget {
  const _CalloutVariantMenu({
    required this.registry,
    required this.variant,
    required this.foreground,
    this.onChanged,
  });

  final BlockGeometryRegistry registry;
  final String variant;
  final Color foreground;
  final ValueChanged<String>? onChanged;

  @override
  State<_CalloutVariantMenu> createState() => _CalloutVariantMenuState();
}

class _CalloutVariantMenuState extends State<_CalloutVariantMenu> {
  final GlobalKey _hitTestKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.registry.registerSelectionExclusion(_hitTestKey);
  }

  @override
  void didUpdateWidget(covariant _CalloutVariantMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.unregisterSelectionExclusion(_hitTestKey);
      widget.registry.registerSelectionExclusion(_hitTestKey);
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _hitTestKey,
      child: Tooltip(
        message: '提示块类型',
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: widget.variant,
            isDense: true,
            borderRadius: BorderRadius.circular(8),
            iconSize: 18,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.foreground,
                      fontWeight: FontWeight.w600,
                    ) ??
                TextStyle(
                  color: widget.foreground,
                  fontWeight: FontWeight.w600,
                ),
            onChanged: widget.onChanged == null
                ? null
                : (value) {
                    if (value != null && value != widget.variant) {
                      widget.onChanged!(value);
                    }
                  },
            items: <DropdownMenuItem<String>>[
              for (final option in CalloutBlockNode.supportedVariants)
                DropdownMenuItem<String>(
                  value: option,
                  child: Text(_calloutVariantLabel(option)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _codeBlockBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHighest
      : const Color(_kCodeBlockBackgroundColor);
}

Color _codeBlockTextColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSurface
      : const Color(_kCodeBlockTextColor);
}

Color _codeBlockBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outlineVariant.withAlpha(150)
      : Colors.white.withAlpha(30);
}

Color _codeBlockAccentColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.primary
      : const Color(_kCodeLanguageTagColor);
}

Color _tableBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outlineVariant
      : _kTableBorderColor;
}

Color _tableEvenRowBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHighest.withAlpha(70)
      : _kTableEvenRowBackgroundColor;
}

Color _dividerLineColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outlineVariant
      : const Color(_kDividerLineColor);
}

Color _fileCardBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outlineVariant
      : const Color(_kFileCardBorderColor);
}

Color _embedBlockBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHighest.withAlpha(72)
      : const Color(_kEmbedBlockBackgroundColor);
}

Color _embedBlockBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outlineVariant
      : const Color(_kEmbedBlockBorderColor);
}

Color _calloutTint(ThemeData theme, String variant) {
  if (theme.brightness == Brightness.dark) {
    return switch (CalloutBlockNode.normalizeVariant(variant)) {
      CalloutBlockNode.successVariant =>
        theme.colorScheme.tertiaryContainer.withAlpha(96),
      CalloutBlockNode.warningVariant =>
        theme.colorScheme.secondaryContainer.withAlpha(104),
      CalloutBlockNode.dangerVariant =>
        theme.colorScheme.errorContainer.withAlpha(104),
      _ => theme.colorScheme.surfaceContainerHighest.withAlpha(96),
    };
  }
  switch (CalloutBlockNode.normalizeVariant(variant)) {
    case CalloutBlockNode.successVariant:
      return const Color(_kCalloutSuccessBackgroundColor);
    case CalloutBlockNode.warningVariant:
      return const Color(_kCalloutWarningBackgroundColor);
    case CalloutBlockNode.dangerVariant:
      return const Color(_kCalloutDangerBackgroundColor);
    case CalloutBlockNode.infoVariant:
    default:
      return const Color(_kCalloutInfoBackgroundColor);
  }
}

Color _calloutForeground(ThemeData theme, String variant) {
  if (theme.brightness == Brightness.dark) {
    return switch (CalloutBlockNode.normalizeVariant(variant)) {
      CalloutBlockNode.successVariant => theme.colorScheme.onTertiaryContainer,
      CalloutBlockNode.warningVariant => theme.colorScheme.onSecondaryContainer,
      CalloutBlockNode.dangerVariant => theme.colorScheme.onErrorContainer,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }
  switch (CalloutBlockNode.normalizeVariant(variant)) {
    case CalloutBlockNode.successVariant:
      return const Color(_kCalloutSuccessForegroundColor);
    case CalloutBlockNode.warningVariant:
      return const Color(_kCalloutWarningForegroundColor);
    case CalloutBlockNode.dangerVariant:
      return const Color(_kCalloutDangerForegroundColor);
    case CalloutBlockNode.infoVariant:
    default:
      return const Color(_kCalloutInfoForegroundColor);
  }
}

Color _calloutBorder(ThemeData theme, String variant) {
  if (theme.brightness == Brightness.dark) {
    return switch (CalloutBlockNode.normalizeVariant(variant)) {
      CalloutBlockNode.successVariant => theme.colorScheme.tertiary,
      CalloutBlockNode.warningVariant => theme.colorScheme.secondary,
      CalloutBlockNode.dangerVariant => theme.colorScheme.error,
      _ => theme.colorScheme.outlineVariant,
    };
  }
  switch (CalloutBlockNode.normalizeVariant(variant)) {
    case CalloutBlockNode.successVariant:
      return const Color(_kCalloutSuccessBorderColor);
    case CalloutBlockNode.warningVariant:
      return const Color(_kCalloutWarningBorderColor);
    case CalloutBlockNode.dangerVariant:
      return const Color(_kCalloutDangerBorderColor);
    case CalloutBlockNode.infoVariant:
    default:
      return const Color(_kCalloutInfoBorderColor);
  }
}

Color _inlineLinkColor(ColorScheme scheme) {
  return scheme.brightness == Brightness.dark
      ? scheme.primary
      : const Color(_kInlineLinkColor);
}

Color _inlineRemarkColor(ColorScheme scheme) {
  return scheme.brightness == Brightness.dark
      ? scheme.secondary
      : const Color(_kInlineRemarkColor);
}

String _calloutVariantLabel(String variant) {
  return CalloutBlockNode.defaultTitleFor(variant);
}

TextStyle _blockTextStyle(
  BuildContext context,
  TextBlockNode block,
  TextStyle? textStyle,
) {
  final theme = Theme.of(context);
  final tokens = EditorTokens.resolve(context);
  final baseStyle = _richTextBodyStyle(theme, textStyle, tokens);
  return switch (block.type) {
    BlockType.heading => baseStyle.merge(
        _headingTextStyle(theme, baseStyle, block.attributes.level),
      ),
    _ => baseStyle,
  };
}

TextStyle _richTextBodyStyle(
  ThemeData theme,
  TextStyle? overrideStyle,
  EditorTokens tokens,
) {
  final baseline = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: tokens.richTextBodyFontSize,
    height: tokens.richTextBodyLineHeight,
  );
  return overrideStyle == null ? baseline : baseline.merge(overrideStyle);
}

Color _editorBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainer
      : Colors.white;
}

TextStyle? _effectiveEditorTextStyle(
  TextStyle? textStyle,
  Color? defaultTextColor,
) {
  if (defaultTextColor == null) {
    return textStyle;
  }
  return (textStyle ?? const TextStyle()).copyWith(color: defaultTextColor);
}

TextStyle _headingTextStyle(
  ThemeData theme,
  TextStyle baseStyle,
  int? level,
) {
  final headingLevel = (level ?? 1).clamp(1, 6).toInt();
  final color = switch (headingLevel) {
    5 => theme.colorScheme.onSurfaceVariant,
    6 => theme.colorScheme.outline,
    _ => baseStyle.color ?? theme.colorScheme.onSurface,
  };
  return (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
    color: color,
    fontSize: _headingSize(headingLevel),
    fontWeight: headingLevel >= 5 ? FontWeight.w600 : FontWeight.w700,
  );
}

TextStyle _todoTextStyle(TextStyle baseStyle, EditorTokens tokens) {
  final fontSize = baseStyle.fontSize ?? 14;
  if (fontSize <= 0) {
    return baseStyle;
  }
  final lineHeight = math.max(
    _lineHeightFor(baseStyle, tokens),
    tokens.todoCheckboxHeight,
  );
  return baseStyle.copyWith(height: lineHeight / fontSize);
}

double _lineHeightFor(TextStyle style, EditorTokens tokens) {
  final fontSize = style.fontSize ?? 14;
  if (fontSize <= 0) {
    return tokens.todoCheckboxHeight;
  }
  return fontSize * (style.height ?? _kBlockMinHeightFactor);
}

/// Builds the inline spans for a text block, overlaying the IME composition
/// decoration (underline) on the runs that fall inside [compositionRange].
_InlineTextLayout _inlineTextLayoutFor(
  BuildContext context,
  List<InlineNode> nodes,
  TextStyle baseStyle,
  _LocalSelectionRange? compositionRange,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  required String blockId,
  required int blockIndex,
  required PositionPath path,
}) {
  final spans = <InlineSpan>[];
  final segments = <_InlineOffsetSegment>[];
  var logicalCursor = 0;
  var renderCursor = 0;
  for (final node in nodes) {
    final logicalLength = inlineLength(node);
    final nodeStart = logicalCursor;
    final nodeEnd = logicalCursor + logicalLength;
    final nodePosition = DocumentPosition(
      blockId: blockId,
      blockIndex: blockIndex,
      path: path,
      offset: nodeStart,
    );
    final overlapStart = compositionRange == null
        ? nodeStart
        : (nodeStart < compositionRange.start
            ? compositionRange.start
            : nodeStart);
    final overlapEnd = compositionRange == null
        ? nodeStart
        : (nodeEnd > compositionRange.end ? compositionRange.end : nodeEnd);
    final nodeSpans = compositionRange != null && overlapStart < overlapEnd
        ? _inlineSpansForNodeWithComposition(
            context,
            node,
            baseStyle,
            inlineEmbedRenderer,
            position: nodePosition,
            start: overlapStart - nodeStart,
            end: overlapEnd - nodeStart,
          )
        : <InlineSpan>[
            _inlineSpanFor(
              context,
              node,
              baseStyle,
              inlineEmbedRenderer,
              position: nodePosition,
              decorate: false,
            )
          ];
    final renderLength = _inlineSpanTextLength(nodeSpans);
    spans.addAll(nodeSpans);
    if (logicalLength > 0 || renderLength > 0) {
      segments.add(
        _InlineOffsetSegment(
          logicalStart: logicalCursor,
          logicalEnd: logicalCursor + logicalLength,
          renderStart: renderCursor,
          renderEnd: renderCursor + renderLength,
          atomic: node is InlineEmbed,
        ),
      );
    }
    logicalCursor += logicalLength;
    renderCursor += renderLength;
  }
  return _InlineTextLayout(
    spans: spans,
    offsetMapper: _InlineOffsetMapper(
      segments: segments,
      logicalLength: logicalCursor,
      renderLength: renderCursor,
    ),
  );
}

int _inlineSpanTextLength(List<InlineSpan> spans) {
  var length = 0;
  for (final span in spans) {
    length += span.toPlainText().length;
  }
  return length;
}

List<InlineSpan> _inlineSpansForNodeWithComposition(
  BuildContext context,
  InlineNode node,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  required DocumentPosition position,
  required int start,
  required int end,
}) {
  if (node is TextRun) {
    final text = node.text;
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(safeStart, text.length).toInt();
    final style = _textStyleForAttributes(context, baseStyle, node.attributes);
    return <InlineSpan>[
      if (safeStart > 0)
        TextSpan(text: text.substring(0, safeStart), style: style),
      if (safeStart < safeEnd)
        TextSpan(
          text: text.substring(safeStart, safeEnd),
          style: _compositionTextStyle(style),
        ),
      if (safeEnd < text.length)
        TextSpan(text: text.substring(safeEnd), style: style),
    ];
  }

  if (node is InlineEmbed) {
    return <InlineSpan>[
      _inlineEmbedSpanFor(
        context,
        node,
        baseStyle,
        inlineEmbedRenderer,
        position: position,
        decorate: true,
      ),
    ];
  }

  final text = node.plainText;
  final safeStart = start.clamp(0, text.length).toInt();
  final safeEnd = end.clamp(safeStart, text.length).toInt();
  return <InlineSpan>[
    if (safeStart > 0)
      TextSpan(text: text.substring(0, safeStart), style: baseStyle),
    if (safeStart < safeEnd)
      TextSpan(
        text: text.substring(safeStart, safeEnd),
        style: _compositionTextStyle(baseStyle),
      ),
    if (safeEnd < text.length)
      TextSpan(text: text.substring(safeEnd), style: baseStyle),
  ];
}

InlineSpan _inlineSpanFor(
  BuildContext context,
  InlineNode node,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  required DocumentPosition position,
  bool decorate = false,
}) {
  final undecoratedStyle = switch (node) {
    final TextRun textRun =>
      _textStyleForAttributes(context, baseStyle, textRun.attributes),
    final InlineEmbed embed =>
      _textStyleForAttributes(context, baseStyle, embed.attributes),
    _ => baseStyle,
  };
  final style =
      decorate ? _compositionTextStyle(undecoratedStyle) : undecoratedStyle;
  return switch (node) {
    final TextRun textRun => TextSpan(text: textRun.text, style: style),
    final InlineEmbed embed => _inlineEmbedSpanFor(
        context,
        embed,
        baseStyle,
        inlineEmbedRenderer,
        position: position,
        decorate: decorate,
      ),
    _ => TextSpan(text: node.plainText, style: style),
  };
}

InlineSpan _inlineEmbedSpanFor(
  BuildContext context,
  InlineEmbed embed,
  TextStyle baseStyle,
  InlineEmbedRenderer? inlineEmbedRenderer, {
  required DocumentPosition position,
  bool decorate = false,
}) {
  final base = _textStyleForAttributes(context, baseStyle, embed.attributes);
  final style = decorate ? _compositionTextStyle(base) : base;
  final custom = inlineEmbedRenderer?.buildTextSpan(context, embed, style);
  if (custom != null) {
    return custom;
  }
  if (_isFormulaEmbedType(embed.embedType)) {
    return _formulaInlineSpanFor(
      context,
      embed,
      style,
      position: position,
      decorate: decorate,
    );
  }
  return TextSpan(
    text: _embedDisplayText(embed),
    style: _defaultInlineEmbedStyle(context, embed, style),
  );
}

InlineSpan _formulaInlineSpanFor(
  BuildContext context,
  InlineEmbed embed,
  TextStyle style, {
  required DocumentPosition position,
  required bool decorate,
}) {
  final formula = _formulaSourceText(embed.data);
  final effectiveStyle = _defaultInlineEmbedStyle(context, embed, style);
  final size = _inlineFormulaPlaceholderSize(formula, effectiveStyle);
  return MeasuredWidgetSpan(
    placeholderSize: size,
    alignment: PlaceholderAlignment.middle,
    style: effectiveStyle,
    child: _InlineFormulaView(
      key: _inlineFormulaInstanceKey(position),
      formula: formula,
      textStyle: effectiveStyle,
      placeholderSize: size,
      position: position,
      composing: decorate,
    ),
  );
}

class _InlineFormulaView extends StatelessWidget {
  const _InlineFormulaView({
    super.key,
    required this.formula,
    required this.textStyle,
    required this.placeholderSize,
    required this.position,
    required this.composing,
  });

  final String formula;
  final TextStyle textStyle;
  final Size placeholderSize;
  final DocumentPosition position;
  final bool composing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: _FormulaMathView(
          formula: formula,
          textStyle: textStyle,
          displayMode: false,
        ),
      ),
    );
    final view = SizedBox.fromSize(
      key: _inlineFormulaKey,
      size: placeholderSize,
      child: composing
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: textStyle.color ?? scheme.primary),
                ),
              ),
              child: content,
            )
          : content,
    );
    final requestController = _FormulaEditRequestScope.maybeOf(context);
    final canRequestEdit = requestController != null;
    final semanticView = Semantics(
      label: canRequestEdit ? '编辑行内公式' : '行内公式',
      value: formula.trim().isEmpty ? '空公式' : formula.trim(),
      button: canRequestEdit,
      enabled: canRequestEdit,
      child: view,
    );
    if (!canRequestEdit) {
      return semanticView;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        requestController.request(
          _FormulaEditTarget.inline(
            position: position,
            formula: formula,
            anchor: _globalRectForContext(context, details.globalPosition),
          ),
        );
      },
      child: semanticView,
    );
  }
}

class _FormulaMathView extends StatelessWidget {
  const _FormulaMathView({
    required this.formula,
    required this.textStyle,
    required this.displayMode,
  });

  final String formula;
  final TextStyle textStyle;
  final bool displayMode;

  @override
  Widget build(BuildContext context) {
    final source = formula.trim();
    final theme = Theme.of(context);
    final style = textStyle.copyWith(
      color: textStyle.color ?? theme.colorScheme.onSurface,
      fontSize: textStyle.fontSize ?? 14,
    );
    final Widget content = source.isEmpty
        ? _FormulaFallbackText(formula: '[formula]', textStyle: style)
        : Math.tex(
            source,
            mathStyle: displayMode ? MathStyle.display : MathStyle.text,
            textStyle: style,
            textScaleFactor: 1,
            settings: const TexParserSettings(strict: Strict.ignore),
            options: MathOptions(
              style: displayMode ? MathStyle.display : MathStyle.text,
              color: style.color ?? theme.colorScheme.onSurface,
              fontSize: style.fontSize,
            ),
            onErrorFallback: (_) => _FormulaFallbackText(
              formula: source,
              textStyle: style,
            ),
          );
    // Key the rendered math subtree by its content so that editing a formula
    // (popup confirm / undo / redo) rebuilds the Math element from scratch
    // instead of reusing it via didUpdateWidget. flutter_math_fork's laid-out
    // subtree can stay stale when the element is reused across a content
    // change, collapsing the inline formula to nothing on the update frame —
    // the "update then disappears" regression. A fresh element renders exactly
    // like the initial mount. The key follows the rendered source, so only a
    // formula whose content actually changed is rebuilt; other formulas in the
    // same paragraph keep their element and layout untouched.
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-formula-math::$source'),
      child: content,
    );
  }
}

class _FormulaFallbackText extends StatelessWidget {
  const _FormulaFallbackText({required this.formula, required this.textStyle});

  final String formula;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      formula,
      style: textStyle.copyWith(
        color: scheme.onErrorContainer,
        fontFamily: 'monospace',
      ),
    );
  }
}

Size _inlineFormulaPlaceholderSize(String formula, TextStyle style) {
  final fontSize = style.fontSize ?? 14;
  final source = formula.trim();
  final runeCount = source.isEmpty ? 7 : source.runes.length;
  final heightFactor = _inlineFormulaHeightFactor(source);
  final width = math.max(
    fontSize * (heightFactor > 1.6 ? 2.8 : 2.2),
    math.min(fontSize * 32, runeCount * fontSize * 0.62 + fontSize),
  );
  return Size(width, fontSize * heightFactor);
}

double _inlineFormulaHeightFactor(String formula) {
  if (formula.isEmpty) {
    return 1.45;
  }
  var extraHeight = 0.0;
  extraHeight += RegExp(r'\\+(?:dfrac|tfrac|frac|binom|over|atop)\b')
          .allMatches(formula)
          .length *
      0.75;
  if (RegExp(r'\\+(?:sum|prod|int|lim)\b[^{}]*[_^]').hasMatch(formula)) {
    extraHeight += 0.3;
  }
  if (RegExp(r'\\+sqrt(?:\[[^\]]+\])?\{').hasMatch(formula)) {
    extraHeight += 0.2;
  }
  if (RegExp(r'\\+begin\{(?:matrix|pmatrix|bmatrix|vmatrix|Vmatrix|cases|aligned|array)\}')
          .hasMatch(formula) ||
      RegExp(r'\\\\(?![A-Za-z])').hasMatch(formula)) {
    extraHeight += 0.9;
  }
  return (1.45 + extraHeight).clamp(1.45, 3.2).toDouble();
}

String _formulaSourceText(
  Map<String, Object?> data, {
  String fallbackText = '',
}) {
  final fallback = fallbackText.trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }
  for (final key in const <String>['text', 'latex', 'value', 'formula']) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

TextStyle _defaultInlineEmbedStyle(
  BuildContext context,
  InlineEmbed embed,
  TextStyle style,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (embed.embedType.trim()) {
    'mention' => style.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
        backgroundColor: scheme.primaryContainer.withAlpha(80),
      ),
    'formula' => style.copyWith(
        color: style.color ?? scheme.onSurface,
        fontFamily: 'monospace',
      ),
    'emoji' => style,
    _ => style.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
  };
}

TextStyle _compositionTextStyle(TextStyle style) {
  final decoration = style.decoration;
  return style.copyWith(
    decoration: decoration == null
        ? TextDecoration.underline
        : TextDecoration.combine(<TextDecoration>[
            decoration,
            TextDecoration.underline,
          ]),
  );
}

TextStyle _completedTodoTextStyle(BuildContext context, TextStyle baseStyle) {
  final decoration = baseStyle.decoration;
  return baseStyle.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    decoration: decoration == null
        ? TextDecoration.lineThrough
        : TextDecoration.combine(<TextDecoration>[
            decoration,
            TextDecoration.lineThrough,
          ]),
  );
}

String _embedDisplayText(InlineEmbed embed) {
  return switch (embed.embedType.trim()) {
    'mention' => _mentionDisplayText(embed),
    'image' => '[img]',
    'formula' => _formulaDisplayText(embed),
    'emoji' => _emojiDisplayText(embed),
    _ => '[${embed.embedType}]',
  };
}

bool _isFormulaEmbedType(String embedType) => embedType.trim() == 'formula';

bool _isMentionEmbedType(String embedType) => embedType.trim() == 'mention';

String _inlineDisplayText(InlineNode node) {
  return switch (node) {
    TextRun() => node.text,
    InlineEmbed() => _embedDisplayText(node),
    _ => node.plainText,
  };
}

String _mentionDisplayText(InlineEmbed embed) {
  // Mention click/open integrations should receive the original embed data
  // alongside at least `id` and `label`; display text intentionally derives
  // from those fields without mutating or normalizing the payload.
  final raw = embed.data['label'] ?? embed.data['id'];
  final label = raw?.toString() ?? '';
  return label.isEmpty ? '@mention' : '@$label';
}

String _formulaDisplayText(InlineEmbed embed) {
  final text = _formulaSourceText(embed.data);
  return text.isEmpty ? '[formula]' : text;
}

String _emojiDisplayText(InlineEmbed embed) {
  final raw = embed.data['emoji'] ??
      embed.data['text'] ??
      embed.data['value'] ??
      embed.data['shortName'] ??
      embed.data['label'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[emoji]' : text;
}

/// Splits a code string into up to three spans, underlining the composition
/// region.
TextSpan _codeSpan(
  String code,
  String language,
  TextStyle codeStyle,
  _LocalSelectionRange? compositionRange,
) {
  if (code.length > _kMaxCodeSyntaxHighlightCharacters) {
    final start = compositionRange?.start.clamp(0, code.length).toInt();
    final end = compositionRange?.end.clamp(0, code.length).toInt();
    if (start == null || end == null || start >= end) {
      return TextSpan(text: code, style: codeStyle);
    }
    return TextSpan(
      style: codeStyle,
      children: <InlineSpan>[
        if (start > 0) TextSpan(text: code.substring(0, start)),
        TextSpan(
          text: code.substring(start, end),
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
        if (end < code.length) TextSpan(text: code.substring(end)),
      ],
    );
  }
  return CodeSyntaxHighlighter(
    language: language,
    baseStyle: codeStyle,
    palette: _darkCodeSyntaxPalette(),
    compositionStart: compositionRange?.start,
    compositionEnd: compositionRange?.end,
  ).highlight(code);
}

CodeSyntaxPalette _darkCodeSyntaxPalette() {
  return const CodeSyntaxPalette(
    keyword: Color(_kCodeKeywordColor),
    type: Color(_kCodeTypeColor),
    string: Color(_kCodeStringColor),
    comment: Color(_kCodeCommentColor),
    number: Color(_kCodeNumberColor),
    marker: Color(_kCodeKeywordColor),
  );
}

const List<String> _kDefaultCodeLanguages = <String>[
  '',
  'dart',
  'javascript',
  'typescript',
  'python',
  'java',
  'kotlin',
  'swift',
  'go',
  'rust',
  'sql',
  'json',
  'yaml',
  'html',
  'css',
  'markdown',
  'bash',
  'mermaid',
];

List<String> _codeLanguageOptions(String current) {
  if (current.isEmpty || _kDefaultCodeLanguages.contains(current)) {
    return _kDefaultCodeLanguages;
  }
  return <String>[current, ..._kDefaultCodeLanguages];
}

String _codeLanguageLabel(String language) {
  final normalized = language.trim();
  return normalized.isEmpty ? 'Plain text' : normalized;
}

/// Maps a [CompositionState] to a local offset range when it targets the given
/// block/path, otherwise returns null.
_LocalSelectionRange? _localCompositionRange(
  CompositionState? state,
  String blockId,
  int blockIndex,
  PositionPath path,
) {
  if (state == null ||
      state.blockId != blockId ||
      state.blockIndex != blockIndex ||
      state.path != path ||
      state.isEmpty) {
    return null;
  }
  return _LocalSelectionRange(
    start: state.startOffset,
    end: state.endOffset,
  );
}

int? _caretOffsetForPath(
  DocumentSelection? selection,
  bool showCaret,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (!showCaret || selection == null || !selection.isCollapsed) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId != blockId || position.path != path) {
    return null;
  }
  return position.offset.clamp(0, textLength).toInt();
}

bool _selectionTouchesPath(
  DocumentSelection? selection,
  int blockIndex,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (selection == null) {
    return false;
  }
  if (_selectionRangeForPath(selection, blockIndex, path, textLength) != null) {
    return true;
  }
  if (!selection.isCollapsed) {
    return false;
  }
  final position = selection.extent;
  return position.blockId == blockId && position.path == path;
}

List<FindReplaceMatch> _matchesForBlock(
  List<FindReplaceMatch> matches,
  int blockIndex,
) {
  if (matches.isEmpty) {
    return const <FindReplaceMatch>[];
  }
  return <FindReplaceMatch>[
    for (final match in matches)
      if (match.blockIndex == blockIndex) match,
  ];
}

List<_FindHighlightRange> _findRangesForPath(
  List<FindReplaceMatch> matches,
  FindReplaceMatch? current,
  int blockIndex,
  PositionPath path,
  int textLength,
) {
  if (matches.isEmpty) {
    return const <_FindHighlightRange>[];
  }
  return <_FindHighlightRange>[
    for (final match in matches)
      if (match.containsPath(path, blockIndex))
        _FindHighlightRange(
          start: match.start.clamp(0, textLength).toInt(),
          end: match.end.clamp(0, textLength).toInt(),
          active: match == current,
        ),
  ];
}

int? _debugOffsetForPath(
  DocumentSelection? selection,
  String blockId,
  PositionPath path,
  int textLength,
) {
  if (selection == null) {
    return null;
  }
  final position = selection.extent;
  if (position.blockId != blockId || position.path != path) {
    return null;
  }
  return position.offset.clamp(0, textLength).toInt();
}

_LocalSelectionRange? _selectionRangeForPath(
  DocumentSelection? selection,
  int blockIndex,
  PositionPath path,
  int textLength,
) {
  if (selection == null || selection.isCollapsed) {
    return null;
  }
  if (_isMultiCellTableRangePath(selection, blockIndex, path)) {
    return null;
  }
  final start = selection.start;
  final end = selection.end;
  int? localStart;
  int? localEnd;

  if (start.blockIndex == blockIndex) {
    final pathCompare = path.compare(start.path);
    if (pathCompare == 0) {
      localStart = start.offset;
    } else if (pathCompare > 0) {
      localStart = 0;
    }
  } else if (blockIndex > start.blockIndex) {
    localStart = 0;
  }

  if (end.blockIndex == blockIndex) {
    final pathCompare = path.compare(end.path);
    if (pathCompare == 0) {
      localEnd = end.offset;
    } else if (pathCompare < 0) {
      localEnd = textLength;
    }
  } else if (blockIndex < end.blockIndex) {
    localEnd = textLength;
  }

  if (localStart == null || localEnd == null) {
    return null;
  }
  final safeStart = localStart.clamp(0, textLength).toInt();
  final safeEnd = localEnd.clamp(0, textLength).toInt();
  if (safeStart == safeEnd) {
    return null;
  }
  return _LocalSelectionRange(
    start: safeStart < safeEnd ? safeStart : safeEnd,
    end: safeStart < safeEnd ? safeEnd : safeStart,
  );
}

bool _isMultiCellTableRangePath(
  DocumentSelection selection,
  int blockIndex,
  PositionPath path,
) {
  final range = selection.tableCellRange;
  return range != null &&
      !range.isSingleCell &&
      path.isTableCellText &&
      range.blockIndex == blockIndex &&
      range.tableBlockId == path.blockId;
}

TextStyle _textStyleForAttributes(
  BuildContext context,
  TextStyle baseStyle,
  TextAttributes attrs,
) {
  // Foreground precedence is inline color > link color > base/default color.
  // Remark and revision styling decorate the text without replacing inline
  // color. Background precedence is inline background > revision background >
  // base background.
  final scheme = Theme.of(context).colorScheme;
  final hasRemark = attrs.remark == true || attrs.commentIds.isNotEmpty;
  final hasRevision = attrs.revisionIds.isNotEmpty;
  final decorations = <TextDecoration>[];

  void addDecoration(TextDecoration decoration) {
    if (decorations.any((existing) => existing.contains(decoration))) {
      return;
    }
    decorations.add(decoration);
  }

  final baseDecoration = baseStyle.decoration;
  if (baseDecoration != null) {
    addDecoration(baseDecoration);
  }
  if (attrs.underline == true ||
      attrs.url != null ||
      hasRemark ||
      hasRevision) {
    addDecoration(TextDecoration.underline);
  }
  if (attrs.lineThrough == true) {
    addDecoration(TextDecoration.lineThrough);
  }

  final decorationColor = hasRemark
      ? _inlineRemarkColor(scheme)
      : hasRevision
          ? scheme.primary
          : attrs.url != null
              ? _inlineLinkColor(scheme)
              : baseStyle.decorationColor;
  final backgroundColor = attrs.background != null
      ? Color(attrs.background!)
      : hasRevision
          ? scheme.primaryContainer.withAlpha(_kInlineRevisionBackgroundAlpha)
          : baseStyle.backgroundColor;
  return baseStyle.copyWith(
    color: attrs.color != null
        ? Color(attrs.color!)
        : attrs.url != null
            ? _inlineLinkColor(scheme)
            : null,
    backgroundColor: backgroundColor,
    fontWeight: attrs.bold == true ? FontWeight.w700 : null,
    fontStyle: attrs.italic == true ? FontStyle.italic : null,
    fontSize: attrs.fontSize,
    fontFamily: attrs.fontFamily,
    decoration:
        decorations.isEmpty ? null : TextDecoration.combine(decorations),
    decorationColor: decorationColor,
    decorationStyle:
        hasRemark ? TextDecorationStyle.dotted : baseStyle.decorationStyle,
    decorationThickness: hasRemark ? 2 : baseStyle.decorationThickness,
  );
}

TextAlign _textAlign(String? alignment) {
  return switch (alignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

double _headingSize(int? level) {
  return switch (level) {
    1 => 24,
    2 => 21,
    3 => 18,
    _ => 16,
  };
}

String? _prefixFor(TextBlockNode block) {
  return switch (block.type) {
    BlockType.listItem => switch (block.attributes.listType) {
        'ordered' => '1.',
        'task' => block.attributes.checked == true ? '[x]' : '[ ]',
        _ => '-',
      },
    _ => null,
  };
}

List<String?> _listMarkersFor(List<BlockNode> blocks) {
  final orderedNumbers = orderedListNumbersFor(blocks);
  return <String?>[
    for (var index = 0; index < blocks.length; index++)
      _listMarkerFor(blocks[index], orderedNumbers[index]),
  ];
}

bool _sameListMarkerSemantics(BlockNode first, BlockNode second) {
  return first.type == second.type &&
      first.attributes.listType == second.attributes.listType &&
      _blockIndentLevel(first) == _blockIndentLevel(second);
}

String? _listMarkerFor(BlockNode block, int? orderedNumber) {
  if (block is! TextBlockNode || block.type != BlockType.listItem) {
    return null;
  }
  final indent = _blockIndentLevel(block);
  return switch (block.attributes.listType) {
    'ordered' => '${orderedNumber ?? 1}.',
    'task' => null,
    _ => _unorderedListBullet(indent),
  };
}

String _unorderedListBullet(int indent) {
  return switch (indent % 3) {
    1 => '◦',
    2 => '▪',
    _ => '•',
  };
}

String _assetLabel(String assetId, String file) {
  if (file.isNotEmpty) {
    return file;
  }
  if (assetId.isNotEmpty) {
    return assetId;
  }
  return 'unknown';
}

String _videoCardTitle(VideoBlockNode video) {
  final title = video.title.trim();
  return title.isNotEmpty ? title : 'Video';
}

String _videoPreviewTitle(VideoBlockNode video) {
  final source = _videoSourceLabel(video);
  return source == 'unknown' ? 'Video preview' : source;
}

String _videoSourceLabel(VideoBlockNode video) {
  final source = video.effectivePlaybackUrl.trim();
  return source.isEmpty ? 'unknown' : source;
}

String _videoCoverLabel(String coverUrl) {
  final trimmed = coverUrl.trim();
  if (trimmed.isEmpty) {
    return 'Cover';
  }
  final uri = Uri.tryParse(trimmed);
  final segments =
      uri?.pathSegments.where((segment) => segment.trim().isNotEmpty).toList();
  final fileName = segments?.isNotEmpty == true ? segments!.last : trimmed;
  return 'Cover: $fileName';
}

String _videoAccessibleLabel(VideoBlockNode video) {
  final parts = <String>[_videoCardTitle(video)];
  final source = _videoSourceLabel(video);
  if (source != 'unknown') {
    parts.add(source);
  }
  final description = video.description.trim();
  if (description.isNotEmpty) {
    parts.add(description);
  }
  if (video.uploadStatus == FileUploadStatus.failed &&
      video.uploadError.isNotEmpty) {
    parts.add(video.uploadError);
  }
  return parts.join(', ');
}

String _imageAccessibleLabel(ImageBlockNode image) {
  if (image.altText.isNotEmpty) {
    return image.altText;
  }
  if (image.caption.isNotEmpty) {
    return image.caption;
  }
  return _assetLabel(image.assetId, image.file);
}

String _fileAccessibleLabel(FileBlockNode file) {
  final parts = <String>[
    file.displayName.isEmpty ? 'untitled file' : file.displayName,
  ];
  final metadata = _fileMetadata(file);
  if (metadata.isNotEmpty) {
    parts.add(metadata);
  }
  return parts.join(', ');
}

String _fileMetadata(FileBlockNode file) {
  final parts = <String>[];
  if (file.size > 0) {
    parts.add(_formatFileSize(file.size));
  }
  final subtitle = _fileSubtitle(file);
  if (subtitle.isNotEmpty) {
    parts.add(subtitle);
  }
  final statusText = _fileStatusText(file);
  if (statusText.isNotEmpty) {
    parts.add(statusText);
  }
  return parts.join(' · ');
}

String _fileSubtitle(FileBlockNode file) {
  final parts = <String>[];
  final mimeType = file.mimeType.trim();
  if (mimeType.isNotEmpty) {
    parts.add(mimeType);
  }
  return parts.join(' · ');
}

String _fileStatusText(FileBlockNode file) {
  final status = _fileUploadStatusLabel(file.uploadStatus);
  if (status.isEmpty) {
    return '';
  }
  final error = file.uploadError.trim();
  if (file.uploadStatus == FileUploadStatus.failed && error.isNotEmpty) {
    return '$status · $error';
  }
  return status;
}

String _fileTypeLabel(FileBlockNode file) {
  final displayName = file.displayName.trim();
  final extension = _fileTypeSegment(displayName);
  if (extension.isNotEmpty) {
    return extension;
  }
  final mimeType = file.mimeType.trim();
  if (mimeType.isNotEmpty) {
    final subtype = mimeType.contains('/')
        ? mimeType.substring(mimeType.indexOf('/') + 1)
        : mimeType;
    final cleaned = _normalizeFileTypeLabel(
      subtype.split(RegExp(r'[+;]')).first,
    );
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return 'FILE';
}

String _fileTypeSegment(String displayName) {
  final cleanName = displayName.split('?').first.trim();
  final dot = cleanName.lastIndexOf('.');
  if (dot < 0 || dot == cleanName.length - 1) {
    return '';
  }
  return _normalizeFileTypeLabel(cleanName.substring(dot + 1));
}

String _normalizeFileTypeLabel(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').trim();
  if (cleaned.isEmpty) {
    return '';
  }
  final truncated = cleaned.length > 4 ? cleaned.substring(0, 4) : cleaned;
  return truncated.toUpperCase();
}

String _fileUploadStatusLabel(FileUploadStatus status) {
  return switch (status) {
    FileUploadStatus.none => '',
    FileUploadStatus.pending => 'Pending upload',
    FileUploadStatus.uploading => 'Uploading',
    FileUploadStatus.uploaded => 'Uploaded',
    FileUploadStatus.failed => 'Upload failed',
  };
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = -1;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final fixed = value >= 10 || value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$fixed ${units[unit]}';
}

bool _isMentionSearchBoundary(String character) {
  if (character == _kMentionSearchInlineBoundary || character.trim().isEmpty) {
    return true;
  }
  return '.,;:!?()[]{}<>/\\|\'"`~#\$%^&*+=，。！？；：、（）【】《》'.contains(character);
}

class _MentionSearchTrigger {
  _MentionSearchTrigger({
    required this.query,
    required this.startPosition,
    required this.endPosition,
  }) : signature = <Object?>[
          query,
          startPosition.blockId,
          startPosition.blockIndex,
          startPosition.path.segments.join('/'),
          startPosition.offset,
          endPosition.offset,
        ].join('|');

  final String query;
  final DocumentPosition startPosition;
  final DocumentPosition endPosition;
  final String signature;
}

/// A lightweight identity for a caret position, used to detect "the caret
/// hasn't moved" between controller notifications (e.g. IME composition updates
/// that leave the caret's block and offset unchanged) and skip redundant work.
class _CaretKey {
  const _CaretKey(this.blockIndex, this.offset);

  final int blockIndex;
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CaretKey &&
          other.blockIndex == blockIndex &&
          other.offset == offset);

  @override
  int get hashCode => Object.hash(blockIndex, offset);
}
