import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../controller/find_replace_controller.dart';
import '../controller/outline_controller.dart';
import '../controller/slash_menu_controller.dart';
import '../controller/wenz_rich_text_controller.dart';
import '../core/commands/inline_editing.dart';
import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import '../input/composition_state.dart';
import '../input/editor_text_input_client.dart';
import '../input/shortcut_manager.dart';
import '../rendering/text_layout_service.dart';
import 'block_geometry_registry.dart';
import 'block_renderer_registry.dart';
import 'code_syntax_highlighter.dart';
import 'inline_embed_renderer.dart';
import 'link_edit_dialog.dart';
import 'link_hover_overlay.dart';
import 'media_resolver.dart';
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
const _accessibilityFocusHighlightKey = ValueKey<String>(
  'wenz-richtext-accessibility-focus-highlight',
);
const _blockReorderDropIndicatorKey = ValueKey<String>(
  'wenz-richtext-block-reorder-drop-indicator',
);

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
const double _kRichTextBodyFontSize = 16.0;
const double _kRichTextBodyLineHeight = 1.75;
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
const double _kTableToolbarMinWidth = 150.0;
const double _kTableFloatingToolbarGap = 4.0;
const double _kTableFloatingToolbarEstimatedHeight = 36.0;
const double _kTableFloatingToolbarEstimatedWidth = 160.0;
const int _kTableToolbarBackgroundColor = 0xFFFFF3CD;
const double _kTableSurfaceRadius = 8.0;
const double _kTableCellFontSize = 15.0;
const EdgeInsets _kTableCellPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 10,
);
const Color _kTableBorderColor = Color(0xFFECE9F5);
const Color _kTableEvenRowBackgroundColor = Color(0xFFFAFAFF);

/// Minimum block height multiplier applied to the block's font size, ensuring
/// a tap target even for empty paragraphs. A single constant so the text,
/// code, and table-cell renderers stay in sync.
const double _kBlockMinHeightFactor = 1.35;
const double _kTodoCheckboxWidth = 24.0;
const double _kTodoCheckboxHeight = 28.0;
const double _kTodoTextGap = 10.0;
const double _kTaskListPaddingLeft = 8.0;
const double _kListTextInset = 26.0;
const double _kListMarkerWidth = 18.0;
const double _kListMarkerGap = _kListTextInset - _kListMarkerWidth;
const double _kListItemSpacing = _kRichTextBodyFontSize * 0.25;
const double _kNestedListItemSpacing = _kRichTextBodyFontSize * 0.15;
/// Collapses index-adjacent quote blocks so their surface backgrounds fuse
/// into one continuous run (see `_spacingBetweenBlocks`). Grouping is
/// adjacency + type only; an `indent` attribute does not break the run.
const double _kAdjacentQuoteSpacing = 0.0;
const double _kHeadingCollapseSlotWidth = 30.0;
const double _kHeadingCollapseButtonSize = 26.0;
const double _kHeadingCollapseIconSize = 20.0;
const double _kCodeBlockFontSize = 13.5;
const double _kCodeBlockLineHeight = 1.6;
const double _kCodeBlockPaddingVertical = 18.0;
const double _kCodeBlockPaddingHorizontal = 20.0;
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
const double _kMinimalMenuSurfaceRadius = 12.0;
const double _kMinimalMenuSurfaceElevation = 6.0;
const int _kMinimalMenuSurfaceShadowAlpha = 48;
const int _kMinimalMenuSurfaceBorderAlpha = 180;
const double _kMinimalMenuItemHeight = 32.0;
const double _kMinimalMenuDividerHeight = 8.0;
const double _kMinimalMenuItemRadius = 8.0;
const double _kMinimalMenuIconSlotWidth = 22.0;
const double _kMinimalMenuIconSize = 18.0;
const double _kMinimalMenuIconTextGap = 10.0;
const double _kMinimalMenuShortcutGap = 18.0;
const EdgeInsets _kMinimalMenuSurfacePadding = EdgeInsets.all(4);
const EdgeInsets _kMinimalMenuItemPadding = EdgeInsets.symmetric(
  horizontal: 12,
);
const double _kMinimalToolbarButtonSize = 32.0;
const double _kMinimalToolbarIconSize = 18.0;
const double _kMinimalToolbarButtonRadius = 8.0;
const double _kMinimalFloatingToolbarSurfaceRadius = 12.0;
const double _kMinimalFloatingToolbarSurfaceElevation = 3.0;
const int _kMinimalFloatingToolbarShadowAlpha = 40;
const int _kMinimalFloatingToolbarBorderAlpha = 180;
const EdgeInsets _kMinimalFloatingToolbarPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 2,
);
const double _kMinimalFloatingToolbarButtonGap = 2.0;
const double _kMinimalFloatingToolbarDividerWidth = 9.0;
const double _kMinimalFloatingToolbarDividerHeight = 18.0;
const int _kMinimalFloatingToolbarDividerAlpha = 120;
const int _kMinimalToolbarDisabledAlpha = 96;
const int _kMinimalMenuDisabledAlpha = 110;
const int _kMinimalMenuSelectedAlphaLight = 36;
const int _kMinimalMenuSelectedAlphaDark = 48;
const int _kMinimalToolbarHoverAlpha = 150;
const int _kMinimalToolbarFocusAlpha = 26;
const int _kMinimalToolbarPressedAlpha = 34;
const double _kBlockFloatingToolbarInset = 6.0;
const double _kBlockToolbarButtonSize = _kMinimalToolbarButtonSize;
const double _kBlockToolbarIconSize = _kMinimalToolbarIconSize;
const double _kBlockToolbarButtonRadius = _kMinimalToolbarButtonRadius;
const Size _kBlockToolbarButtonFixedSize =
    Size.square(_kBlockToolbarButtonSize);
const BoxConstraints _kBlockToolbarButtonConstraints = BoxConstraints.tightFor(
  width: _kBlockToolbarButtonSize,
  height: _kBlockToolbarButtonSize,
);
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
// `.img-placeholder`). The caption gap mirrors the figcaption `padding-top`.
const double _kImagePlaceholderAspectRatio = 2.0;
const double _kImageCaptionGap = 8.0;

// Video blocks have a single overflow boundary: the rounded video frame.
// The frame width is capped by the editor content width, its aspect ratio is
// clamped to avoid unusable extremes, and its computed height is clamped below.
// Everything inside the frame (built-in chrome or MediaResolver output) must be
// laid out by these finite constraints and clipped by the frame.
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
const double _kPopupMenuTextMaxWidth = 212.0;
const double _kSlashMenuGap = 6.0;
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
const int _kFormulaBlockBackgroundColor = 0xFFE8E0FF;
const int _kFormulaBlockForegroundColor = 0xFF241946;
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

Color _popupMenuColor(ThemeData theme) => theme.colorScheme.surfaceContainerLow;

Color _popupMenuShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kMinimalMenuSurfaceShadowAlpha);

ShapeBorder _popupMenuShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: theme.colorScheme.outlineVariant.withAlpha(
        _kMinimalMenuSurfaceBorderAlpha,
      ),
    ),
    borderRadius: BorderRadius.circular(_kPopupMenuRadius),
  );
}

Color _floatingToolbarSurfaceColor(ThemeData theme) =>
    theme.colorScheme.surfaceContainerLow;

Color _floatingToolbarShadowColor(ThemeData theme) =>
    theme.colorScheme.shadow.withAlpha(_kMinimalFloatingToolbarShadowAlpha);

ShapeBorder _floatingToolbarShape(ThemeData theme) {
  return RoundedRectangleBorder(
    side: BorderSide(
      color: theme.colorScheme.outlineVariant.withAlpha(
        _kMinimalFloatingToolbarBorderAlpha,
      ),
    ),
    borderRadius: BorderRadius.circular(_kMinimalFloatingToolbarSurfaceRadius),
  );
}

Color _blockToolbarIconColor(ThemeData theme) =>
    theme.colorScheme.onSurfaceVariant;

Color _blockToolbarDisabledIconColor(ThemeData theme) =>
    theme.colorScheme.onSurfaceVariant.withAlpha(_kMinimalToolbarDisabledAlpha);

Color _blockToolbarPressedOverlayColor(ThemeData theme) =>
    theme.colorScheme.primary.withAlpha(_kMinimalToolbarPressedAlpha);

ButtonStyle _blockToolbarIconButtonStyle(
  ThemeData theme, {
  Color? foregroundColor,
  Color? disabledForegroundColor,
}) {
  final colorScheme = theme.colorScheme;
  return IconButton.styleFrom(
    fixedSize: _kBlockToolbarButtonFixedSize,
    minimumSize: _kBlockToolbarButtonFixedSize,
    maximumSize: _kBlockToolbarButtonFixedSize,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    foregroundColor: foregroundColor ?? _blockToolbarIconColor(theme),
    disabledForegroundColor:
        disabledForegroundColor ?? _blockToolbarDisabledIconColor(theme),
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    hoverColor: colorScheme.surfaceContainerHighest.withAlpha(
      _kMinimalToolbarHoverAlpha,
    ),
    focusColor: colorScheme.primary.withAlpha(_kMinimalToolbarFocusAlpha),
    highlightColor: _blockToolbarPressedOverlayColor(theme),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kBlockToolbarButtonRadius),
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
    required this.icon,
    required this.label,
    this.shortcut,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool enabled;
  final bool selected;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveIcon = selected ? Icons.check : icon;
    final foregroundColor = !enabled
        ? colorScheme.onSurfaceVariant.withAlpha(_kMinimalMenuDisabledAlpha)
        : destructive
            ? colorScheme.error
            : selected
                ? colorScheme.primary
                : colorScheme.onSurface;
    final iconColor = !enabled
        ? colorScheme.onSurfaceVariant.withAlpha(
            _kMinimalMenuDisabledAlpha,
          )
        : destructive
            ? colorScheme.error
            : selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant;
    final selectedBackgroundAlpha =
        theme.brightness == Brightness.dark
            ? _kMinimalMenuSelectedAlphaDark
            : _kMinimalMenuSelectedAlphaLight;
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withAlpha(selectedBackgroundAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(_kMinimalMenuItemRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: _kMinimalMenuIconSlotWidth,
              child: Icon(
                effectiveIcon,
                size: _kMinimalMenuIconSize,
                color: iconColor,
              ),
            ),
            const SizedBox(width: _kMinimalMenuIconTextGap),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kPopupMenuTextMaxWidth),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (shortcut != null) ...<Widget>[
              const SizedBox(width: _kMinimalMenuShortcutGap),
              Text(
                shortcut!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurfaceVariant.withAlpha(
                          _kMinimalMenuDisabledAlpha,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
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
      'slotWidth': 30.0,
      'buttonSize': 26.0,
      'iconSize': 20.0,
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
              key: const ValueKey<String>('wenz-richtext-formula-editor-input'),
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
    this.padding = const EdgeInsets.all(16),
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
    this.blockRenderers,
    this.mediaResolver,
    this.inlineEmbedRenderer,
    this.onMentionTap,
    this.onOpenLink,
    this.findController,
    this.onFindRequested,
    this.onReplaceRequested,
    this.slashMenuController,
    this.outlineController,
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
  /// Video resolver output is placed inside the same finite, clipped video
  /// frame as the built-in placeholder, both in-editor and in preview dialogs.
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

  /// Optional outline controller whose collapsed-heading state projects the
  /// rendered top-level block list without mutating the source document.
  final WenzOutlineController? outlineController;

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
  late final ScrollController _scrollController = ScrollController();
  late final SharedTextLayoutCache _layoutCache = SharedTextLayoutCache();
  final GlobalKey _editorOverlayKey = GlobalKey();
  OverlayEntry? _slashMenuOverlayEntry;
  bool _slashMenuOverlaySyncScheduled = false;
  final TextEditingController _formulaEditController = TextEditingController();
  final FocusNode _formulaEditFocusNode = FocusNode(
    debugLabel: 'WenzFormulaEditor',
  );
  late final TableFloatingToolbarOverlayController
      _tableToolbarOverlayController = TableFloatingToolbarOverlayController();
  final _BlockExtentCache _extentCache = _BlockExtentCache();
  BlockRendererRegistry? _ownedBlockRenderers;
  _FormulaEditTarget? _formulaEditTarget;

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

  /// The caret position (block index + offset) at the last scroll-into-view
  /// check. IME composition updates call `notifyListeners` without moving the
  /// caret; remembering the last-checked position lets us skip the (layout +
  /// localToGlobal) scroll check when the caret hasn't moved — a hot path
  /// during pinyin/japanese input.
  _CaretKey? _lastScrollCheckedCaret;
  bool _skipNextCaretScrollIntoView = false;
  bool _inputGeometrySyncPending = false;

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
      _extentCache.clear();
      _layoutCache.clear();
    } else if (oldWidget.textStyle != widget.textStyle ||
        oldWidget.defaultTextColor != widget.defaultTextColor ||
        oldWidget.blockRenderers != widget.blockRenderers ||
        oldWidget.mediaResolver != widget.mediaResolver ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
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
    if (!oldWidget.readOnly && widget.readOnly) {
      widget.slashMenuController?.close();
      _removeSlashMenuOverlay();
      _closeFormulaEditor();
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
    _syncTableToolbarOverlayWithSelection();
  }

  @override
  void dispose() {
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
    _tableToolbarOverlayController.hide();
    _tableToolbarOverlayController.dispose();
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
      _scheduleSlashMenuOverlaySync();
      setState(() {});
    }
  }

  void _handleScrollChanged() {
    if (mounted &&
        (widget.slashMenuController?.isOpen == true ||
            _formulaEditTarget != null)) {
      _scheduleSlashMenuOverlaySync();
      setState(() {});
    }
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
        if (!mounted || widget.readOnly || controller == null ||
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
    _revealCurrentSelectionIfHidden();
    _lastScrollCheckedCaret = null;
    _scrollRealignDepth = 0;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollCaretIntoView();
      }
    });
  }

  void _handleControllerChanged() {
    if (mounted) {
      if (widget.readOnly) {
        widget.slashMenuController?.close();
      }
      _syncTableToolbarOverlayWithSelection();
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
    if (widget.readOnly) {
      return null;
    }
    final tableRange = widget.controller.selection?.tableCellRange;
    if (tableRange == null) {
      return null;
    }
    final tableBlock = _tableBlockAt(tableRange.blockIndex);
    final normalizedRange =
        tableBlock != null && tableBlock.id == tableRange.tableBlockId
            ? _normalizeTableRange(tableBlock, tableRange)
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

  HeadingCollapseState? _headingCollapseStateFor(BlockNode block) {
    final outline = widget.outlineController;
    if (outline == null || !identical(outline.editor, widget.controller)) {
      return null;
    }
    // Only top-level heading text blocks expose the left-side collapse slot.
    // Non-heading text rows plus code, table, divider, media, and file blocks
    // must not reserve the affordance or respond to heading-collapse gestures.
    if (block is! TextBlockNode || block.type != BlockType.heading) {
      return null;
    }
    final item = outline.itemForBlockId(block.id);
    return HeadingCollapseState(
      canCollapse: item?.canCollapse ?? false,
      isCollapsed: item?.isCollapsed ?? false,
      hiddenBlockCount: item?.coveredBlockIds.length ?? 0,
    );
  }

  void _handleHeadingCollapseToggled(String blockId) {
    widget.outlineController?.toggleByBlockId(blockId);
  }

  void _openFormulaEditor(_FormulaEditTarget target) {
    if (widget.readOnly) {
      return;
    }
    widget.slashMenuController?.close();
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
    final showCaret = !widget.readOnly &&
        focusNode.hasFocus &&
        widget.controller.selection?.isCollapsed == true;
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
    final listMarkers = _listMarkersFor(sourceBlocks);
    final effectiveTextStyle = _effectiveEditorTextStyle(
      widget.textStyle,
      widget.defaultTextColor,
    );

    _extentCache.retainBlocks(sourceBlocks);

    final editor = _MeasuredVirtualBlockList(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      blocks: blocks,
      blockIndexes: blockIndexes,
      blockSpacing: widget.blockSpacing,
      extentCache: _extentCache,
      keepAliveIds: keepAliveIds,
      onExtentUpdated: _scrollCaretIntoViewIfNeeded,
      itemBuilder: (context, blockIndex) {
        final block = sourceBlocks[blockIndex];
        return _KeepAliveBlock(
          key: ValueKey<String>(block.id),
          block: block,
          blockIndex: blockIndex,
          blockCount: sourceBlocks.length,
          listMarker: listMarkers[blockIndex],
          quoteGroupPosition:
              _quoteGroupPositionFor(sourceBlocks, blockIndex),
          keepAlive: keepAliveIds.contains(block.id),
          blockChanged: dirtyIds == null || dirtyIds.contains(block.id),
          selection: widget.controller.selection,
          compositionState: widget.controller.compositionState,
          registry: _registry,
          blockRenderers: _blockRenderers,
          showCaret: showCaret,
          textStyle: effectiveTextStyle,
          showDebugOverlay: widget.showDebugOverlay,
          canEdit: !widget.readOnly,
          mediaResolver: widget.mediaResolver,
          inlineEmbedRenderer: widget.inlineEmbedRenderer,
          onMentionTap: widget.onMentionTap,
          headingCollapseState: _headingCollapseStateFor(block),
          onHeadingCollapseToggled: _handleHeadingCollapseToggled,
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
              widget.readOnly ? null : _handleTableToolbarAction,
          tableToolbarOverlayController: _tableToolbarOverlayController,
          onTableColumnResize:
              widget.readOnly ? null : _handleTableColumnResize,
          onTodoCheckedChanged:
              widget.readOnly ? null : _handleTodoCheckedChanged,
          onObjectBlockAction: _handleObjectBlockAction,
          onRowBlockFormatChanged:
              widget.readOnly ? null : _handleRowBlockFormatChanged,
          findMatches: findMatches,
          currentFindMatch: currentFindMatch,
        );
      },
    );
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
          onSelectionChanged: _handleSelectionChanged,
          onTapBeyondContent: _handleTapBeyondContent,
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
      ],
    );
    final scopedEditorStack = _wrapMentionTapHandler(editorStack);
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
    final localRect = overlayBox.globalToLocal(target.anchor.topLeft) &
        target.anchor.size;
    final width = math.min(
      _kFormulaEditorWidth,
      math.max(0.0, overlayBox.size.width - _kPopupViewportInset * 2),
    );
    final preferredBelowTop = localRect.bottom + _kFormulaEditorGap;
    final roomBelow = visibleBottom - preferredBelowTop - _kPopupViewportInset;
    final roomAbove = localRect.top - _kFormulaEditorGap - _kPopupViewportInset;
    final opensAbove = roomBelow < _kFormulaEditorEstimatedHeight &&
        roomAbove > roomBelow;
    final preferredTop = opensAbove
        ? localRect.top - _kFormulaEditorEstimatedHeight - _kFormulaEditorGap
        : preferredBelowTop;
    final maxLeft = overlayBox.size.width - width - _kPopupViewportInset;
    final maxTop = visibleBottom - _kFormulaEditorEstimatedHeight;
    final leftMin = maxLeft >= _kPopupViewportInset ? _kPopupViewportInset : 0.0;
    final topMin = maxTop >= _kPopupViewportInset ? _kPopupViewportInset : 0.0;
    return _FormulaEditorAnchor(
      left: localRect.left
          .clamp(leftMin, maxLeft > 0 ? maxLeft : 0)
          .toDouble(),
      top: preferredTop
          .clamp(topMin, maxTop > 0 ? maxTop : 0)
          .toDouble(),
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
          ? (anchor.opensAbove
              ? anchor.offset.dy - _kPopupViewportInset
              : overlaySize.height - anchor.offset.dy - _kPopupViewportInset)
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
    return TapRegion(
      groupId: this,
      enabled: widget.slashMenuController?.isOpen == true ||
          _formulaEditTarget != null,
      onTapOutside: (_) {
        widget.slashMenuController?.close();
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
            label:
                widget.accessibility.effectiveLabel(readOnly: widget.readOnly),
            hint: widget.accessibility.effectiveHint(readOnly: widget.readOnly),
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
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    final viewportHeight = mediaQuery?.size.height ?? positioningBox.size.height;
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
    final roomBelow = visibleBottom - preferredBelowTop - _kPopupViewportInset;
    final roomAbove = caretTop.dy - _kSlashMenuGap - _kPopupViewportInset;
    final opensAbove = roomBelow < _kPopupMenuItemHeight && roomAbove > roomBelow;
    final preferredTop =
        opensAbove ? caretTop.dy - _kSlashMenuGap : preferredBelowTop;
    final maxTop = visibleBottom - _kPopupViewportInset;
    return _SlashMenuAnchor(
      offset: Offset(
        caretBottom.dx.clamp(0, maxLeft > 0 ? maxLeft : 0).toDouble(),
        preferredTop
            .clamp(_kPopupViewportInset, maxTop > 0 ? maxTop : 0)
            .toDouble(),
      ),
      opensAbove: opensAbove,
    );
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

  bool _handleTapBeyondContent(Offset _) {
    if (widget.readOnly) {
      return false;
    }
    final blocks = widget.controller.document.blocks;
    if (blocks.isEmpty) {
      return false;
    }
    final last = blocks.last;
    if (last is TextBlockNode || last is CodeBlockNode) {
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
    final tableBlock = _tableBlockAt(intent.blockIndex);
    if (tableBlock == null) {
      return;
    }

    final range = _currentTableRange(tableBlock, intent);
    if (range == null) {
      return;
    }
    widget.controller.requestFocus();

    switch (intent.action) {
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
        _setTableColumnAlignment(intent.blockIndex, range, 'left');
        return;
      case TableToolbarAction.alignCenter:
        _setTableColumnAlignment(intent.blockIndex, range, 'center');
        return;
      case TableToolbarAction.alignRight:
        _setTableColumnAlignment(intent.blockIndex, range, 'right');
        return;
      case TableToolbarAction.clearAlignment:
        _setTableColumnAlignment(intent.blockIndex, range, null);
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
    }
  }

  void _handleTableColumnResize({
    required int blockIndex,
    required int columnIndex,
    required double width,
  }) {
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
    final range = widget.controller.selection?.tableCellRange;
    if (range == null ||
        range.blockIndex != intent.blockIndex ||
        range.tableBlockId != tableBlock.id) {
      return null;
    }
    return _normalizeTableRange(tableBlock, range);
  }

  TableCellRange? _normalizeTableRange(
    TableBlockNode tableBlock,
    TableCellRange range,
  ) {
    final rowCount = tableBlock.table.rowCount;
    final columnCount = tableBlock.table.columnCount;
    if (rowCount == 0 || columnCount == 0) {
      return null;
    }
    return TableCellRange(
      tableBlockId: tableBlock.id,
      blockIndex: range.blockIndex,
      startRow: range.startRow.clamp(0, rowCount - 1).toInt(),
      endRow: range.endRow.clamp(0, rowCount - 1).toInt(),
      startColumn: range.startColumn.clamp(0, columnCount - 1).toInt(),
      endColumn: range.endColumn.clamp(0, columnCount - 1).toInt(),
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

  void _setTableColumnAlignment(
    int blockIndex,
    TableCellRange range,
    String? alignment,
  ) {
    for (var column = range.startColumn; column <= range.endColumn; column++) {
      widget.controller.setTableColumnAlignment(
        blockIndex: blockIndex,
        columnIndex: column,
        alignment: alignment,
      );
    }
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
        final reference = _objectBlockReference(block);
        if (reference.isNotEmpty) {
          unawaited(_copyTextToClipboard(reference));
        }
        return;
      case ObjectBlockAction.duplicate:
        if (widget.readOnly) {
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
        final toIndex = _resolveMoveBlockTarget(
          intent,
          fallback: intent.blockIndex - 1,
        );
        if (toIndex != null) {
          _moveBlock(intent.blockIndex, toIndex);
        }
        return;
      case ObjectBlockAction.moveDown:
        if (widget.readOnly) {
          return;
        }
        final toIndex = _resolveMoveBlockTarget(
          intent,
          fallback: intent.blockIndex + 1,
        );
        if (toIndex != null) {
          _moveBlock(intent.blockIndex, toIndex);
        }
        return;
      case ObjectBlockAction.delete:
        if (widget.readOnly) {
          return;
        }
        _deleteBlock(intent.blockIndex);
        return;
      case ObjectBlockAction.resetImageSize:
        if (widget.readOnly || block is! ImageBlockNode) {
          return;
        }
        widget.controller.updateImageBlock(
          blockIndex: intent.blockIndex,
          clearShowWidth: true,
          clearShowHeight: true,
        );
        return;
      case ObjectBlockAction.setImageDisplayWidth:
        if (widget.readOnly || block is! ImageBlockNode) {
          return;
        }
        final width = intent.value;
        if (width is! num || width <= 0) {
          return;
        }
        widget.controller.updateImageBlock(
          blockIndex: intent.blockIndex,
          showWidth: width.toDouble(),
          showHeight: _scaledImageHeight(block, width.toDouble()),
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

  int? _resolveMoveBlockTarget(
    ObjectBlockActionIntent intent, {
    required int fallback,
  }) {
    final blocks = widget.controller.document.blocks;
    if (intent.blockIndex < 0 || intent.blockIndex >= blocks.length) {
      return null;
    }
    final value = intent.value;
    final toIndex = value is int ? value : fallback;
    if (toIndex < 0 ||
        toIndex >= blocks.length ||
        toIndex == intent.blockIndex) {
      return null;
    }
    return toIndex;
  }

  void _moveBlock(int fromIndex, int toIndex) {
    widget.controller.moveBlock(
      fromIndex: fromIndex,
      toIndex: toIndex,
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

  double? _scaledImageHeight(ImageBlockNode block, double width) {
    if (block.width <= 0 || block.height <= 0) {
      return null;
    }
    return width * block.height / block.width;
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
    if (_handleCodeBlockTabKeyEvent(event)) {
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
      slashMenu.moveHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      slashMenu.moveHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      slashMenu.activateHighlighted();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      slashMenu.close();
      return true;
    }
    return false;
  }

  void _performShortcut(EditorShortcutResolution resolution) {
    final controller = widget.controller;
    switch (resolution.intent) {
      case EditorShortcutIntent.selectAll:
        controller.selectAll();
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
    _lastScrollCheckedCaret = null;
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
        controller.selectAll();
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
    position.jumpTo(next);
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
    final payload = widget.controller.copySelection();
    if (payload == null) {
      return;
    }
    await _copyTextToClipboard(payload);
  }

  Future<void> _handleCut() async {
    if (_revealCurrentSelectionIfHidden()) {
      return;
    }
    final payload = widget.controller.cutSelection();
    if (payload == null) {
      return;
    }
    await _copyTextToClipboard(payload);
  }

  Future<void> _copyTextToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _handlePaste() async {
    _revealCurrentSelectionIfHidden();
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    widget.controller.pasteText(text);
  }

  String _nextBlockId() {
    _generatedBlockCount += 1;
    return 'block-${DateTime.now().microsecondsSinceEpoch}-$_generatedBlockCount';
  }
}

class _BlockExtentCache {
  final Map<String, double> _extents = <String, double>{};
  final Map<String, int> _blockVersions = <String, int>{};
  Set<String> _knownBlockIds = <String>{};
  int _epoch = 0;
  double? _contentWidth;

  void clear() {
    _epoch += 1;
    _extents.clear();
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
    _extents.remove(blockId);
    _blockVersions[blockId] = (_blockVersions[blockId] ?? 0) + 1;
  }

  void retainBlocks(List<BlockNode> blocks) {
    final ids = blocks.map((block) => block.id).toSet();
    for (final id in _knownBlockIds.difference(ids)) {
      removeBlock(id);
    }
    _knownBlockIds = ids;
    _extents.removeWhere((id, _) => !ids.contains(id));
  }

  int tokenFor(String blockId) {
    return Object.hash(_epoch, _blockVersions[blockId] ?? 0);
  }

  bool record(String blockId, int token, double extent) {
    if (token != tokenFor(blockId)) {
      return false;
    }
    if (!extent.isFinite || extent <= 0) {
      return false;
    }
    final previous = _extents[blockId];
    if (previous != null && (previous - extent).abs() <= 0.5) {
      return false;
    }
    _extents[blockId] = extent;
    return true;
  }

  double get averageExtent {
    if (_extents.isEmpty) {
      return _kDefaultBlockExtent;
    }
    final total = _extents.values.fold<double>(0, (sum, h) => sum + h);
    return total / _extents.length;
  }

  double extentFor(BlockNode block) {
    return _extents[block.id] ?? averageExtent;
  }

  double offsetFor(List<BlockNode> blocks, int blockIndex, double spacing) {
    var offset = 0.0;
    final safeIndex = blockIndex.clamp(0, blocks.length).toInt();
    for (var i = 0; i < safeIndex; i++) {
      offset += extentFor(blocks[i]);
      if (i < blocks.length - 1) {
        offset += _spacingBetweenBlocks(blocks[i], blocks[i + 1], spacing);
      }
    }
    return offset;
  }

  _BlockLayoutMetrics layoutFor(List<BlockNode> blocks, double spacing) {
    final offsets = <double>[];
    var offset = 0.0;
    for (var i = 0; i < blocks.length; i++) {
      offsets.add(offset);
      offset += extentFor(blocks[i]);
      if (i < blocks.length - 1) {
        offset += _spacingBetweenBlocks(blocks[i], blocks[i + 1], spacing);
      }
    }
    return _BlockLayoutMetrics(
      blocks: blocks,
      offsets: offsets,
      totalExtent: offset,
      cache: this,
    );
  }
}

class _SlashMenuAnchor {
  const _SlashMenuAnchor({
    required this.offset,
    this.opensAbove = false,
  });

  final Offset offset;
  final bool opensAbove;
}

class _BlockLayoutMetrics {
  const _BlockLayoutMetrics({
    required this.blocks,
    required this.offsets,
    required this.totalExtent,
    required this.cache,
  });

  final List<BlockNode> blocks;
  final List<double> offsets;
  final double totalExtent;
  final _BlockExtentCache cache;

  double topFor(int index) => offsets[index];

  double bottomFor(int index) => topFor(index) + cache.extentFor(blocks[index]);

  List<int> visibleIndices(double visibleTop, double visibleBottom) {
    if (blocks.isEmpty) {
      return const <int>[];
    }
    final start = _firstIndexWithBottomAtOrAfter(visibleTop);
    if (start >= blocks.length) {
      return <int>[blocks.length - 1];
    }
    final endExclusive = _firstIndexWithTopAfter(visibleBottom);
    final end = endExclusive <= start ? start + 1 : endExclusive;
    return <int>[
      for (var i = start; i < end && i < blocks.length; i++) i,
    ];
  }

  int _firstIndexWithBottomAtOrAfter(double y) {
    var low = 0;
    var high = blocks.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (bottomFor(mid) < y) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _firstIndexWithTopAfter(double y) {
    var low = 0;
    var high = offsets.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (offsets[mid] <= y) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
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

  @override
  State<_MeasuredVirtualBlockList> createState() =>
      _MeasuredVirtualBlockListState();
}

class _MeasuredVirtualBlockListState extends State<_MeasuredVirtualBlockList> {
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
    if (widget.extentCache.record(blockId, measureToken, extent) && mounted) {
      setState(() {});
      // A real height change may unlock a caret-into-view that the content
      // mutation frame could not perform (it ran with the pre-edit height).
      // Notify the editor so it can retry the scroll against the now-accurate
      // layout.
      widget.onExtentUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding.resolve(Directionality.of(context));
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
        for (var i = 0; i < widget.blocks.length; i++) {
          if (widget.keepAliveIds.contains(widget.blocks[i].id)) {
            indices.add(i);
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
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.tableToolbarOverlayController,
    this.onTableColumnResize,
    this.onTodoCheckedChanged,
    this.onObjectBlockAction,
    this.onRowBlockFormatChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final int blockCount;
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
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableFloatingToolbarOverlayController? tableToolbarOverlayController;
  final TableColumnResizeHandler? onTableColumnResize;
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
        selectionTouchedChanged ||
        selectionShiftedWhileTouched ||
        oldWidget.showCaret != widget.showCaret ||
        oldWidget.showDebugOverlay != widget.showDebugOverlay ||
        oldWidget.listMarker != widget.listMarker ||
        oldWidget.quoteGroupPosition != widget.quoteGroupPosition ||
        oldWidget.canEdit != widget.canEdit ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.inlineEmbedRenderer != widget.inlineEmbedRenderer ||
        oldWidget.onMentionTap != widget.onMentionTap ||
        oldWidget.headingCollapseState != widget.headingCollapseState ||
        oldWidget.onHeadingCollapseToggled != widget.onHeadingCollapseToggled ||
        oldWidget.onCodeLanguageChanged != widget.onCodeLanguageChanged ||
        oldWidget.onCodeCopied != widget.onCodeCopied ||
        oldWidget.onCalloutVariantChanged != widget.onCalloutVariantChanged ||
        oldWidget.onTableToolbarAction != widget.onTableToolbarAction ||
        oldWidget.tableToolbarOverlayController !=
            widget.tableToolbarOverlayController ||
        oldWidget.onTableColumnResize != widget.onTableColumnResize ||
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
      headingCollapseState: widget.headingCollapseState,
      onHeadingCollapseToggled: widget.onHeadingCollapseToggled,
      onCodeLanguageChanged: widget.onCodeLanguageChanged,
      onCodeCopied: widget.onCodeCopied,
      onCalloutVariantChanged: widget.onCalloutVariantChanged,
      onTableToolbarAction: widget.onTableToolbarAction,
      tableToolbarOverlayController: widget.tableToolbarOverlayController,
      onTableColumnResize: widget.onTableColumnResize,
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
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
    this.onCodeLanguageChanged,
    this.onCodeCopied,
    this.onCalloutVariantChanged,
    this.onTableToolbarAction,
    this.tableToolbarOverlayController,
    this.onTableColumnResize,
    this.onTodoCheckedChanged,
    this.onObjectBlockAction,
    this.onRowBlockFormatChanged,
    this.findMatches = const <FindReplaceMatch>[],
    this.currentFindMatch,
  });

  final BlockNode block;
  final int blockIndex;
  final int blockCount;
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
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final ValueChanged<String>? onCodeLanguageChanged;
  final Future<void> Function(String code)? onCodeCopied;
  final ValueChanged<String>? onCalloutVariantChanged;
  final TableToolbarActionHandler? onTableToolbarAction;
  final TableFloatingToolbarOverlayController? tableToolbarOverlayController;
  final TableColumnResizeHandler? onTableColumnResize;
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
      onTableColumnResize: onTableColumnResize,
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
      blockIndex: blockIndex,
      blockCount: blockCount,
      leadingIndent: leadingIndent,
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
    required this.blockIndex,
    required this.blockCount,
    required this.leadingIndent,
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
  final int blockIndex;
  final int blockCount;
  final double leadingIndent;
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
  @override
  Widget build(BuildContext context) {
    if (!BlockDragHandleSpec.canShow(
      canEdit: widget.canEdit,
      blockIndex: widget.blockIndex,
      blockCount: widget.blockCount,
    )) {
      return widget.child;
    }
    final handleStart = math.max(
      0.0,
      BlockDragHandleSpec.railWidth +
          widget.leadingIndent -
          BlockDragHandleSpec.gapToContent -
          BlockDragHandleSpec.hitSize.width,
    );
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: BlockDragHandleSpec.railWidth,
      ),
      child: widget.child,
    );
    return _BlockReorderRowGeometry(
      blockId: widget.blockId,
      blockIndex: widget.blockIndex,
      registry: widget.registry,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          content,
          PositionedDirectional(
            start: handleStart,
            top: BlockDragHandleSpec.topInset,
            child: _BlockDragHandleButton(
              blockId: widget.blockId,
              blockPlainText: widget.blockPlainText,
              blockFormat: widget.blockFormat,
              canChangeBlockFormat: widget.canChangeBlockFormat,
              blockIndex: widget.blockIndex,
              blockCount: widget.blockCount,
              canEdit: widget.canEdit,
              registry: widget.registry,
              onAction: widget.onAction,
              onFormatChanged: widget.onFormatChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockReorderRowGeometry extends StatefulWidget {
  const _BlockReorderRowGeometry({
    required this.blockId,
    required this.blockIndex,
    required this.registry,
    required this.child,
  });

  final String blockId;
  final int blockIndex;
  final BlockGeometryRegistry registry;
  final Widget child;

  @override
  State<_BlockReorderRowGeometry> createState() =>
      _BlockReorderRowGeometryState();
}

class _BlockReorderRowGeometryState extends State<_BlockReorderRowGeometry> {
  final GlobalKey _rowKey = GlobalKey();

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
      oldWidget.registry.unregisterBlockRow(oldWidget.blockId, _rowKey);
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.blockId != widget.blockId ||
        oldWidget.blockIndex != widget.blockIndex) {
      _register();
    }
  }

  @override
  void dispose() {
    widget.registry.unregisterBlockRow(widget.blockId, _rowKey);
    super.dispose();
  }

  void _register() {
    widget.registry.registerBlockRow(
      BlockRowGeometryEntry(
        blockId: widget.blockId,
        blockIndex: widget.blockIndex,
        key: _rowKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _rowKey,
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
    required this.blockIndex,
    required this.blockCount,
    required this.canEdit,
    required this.registry,
    this.onAction,
    this.onFormatChanged,
  });

  final String blockId;
  final String blockPlainText;
  final _RowBlockFormat? blockFormat;
  final bool canChangeBlockFormat;
  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final BlockGeometryRegistry registry;
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
  BlockReorderDropTarget? _dropTarget;

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
    if (!_enabled) {
      _resetPointerGesture();
    }
  }

  @override
  void dispose() {
    _removeDropIndicator();
    widget.registry.unregisterSelectionExclusion(_hitTestKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final opacity = !enabled
        ? BlockDragHandleSpec.disabledOpacity
        : _menuOpen || _focused || _dragging
            ? BlockDragHandleSpec.activeOpacity
            : _hovered
                ? BlockDragHandleSpec.hoverOpacity
                : BlockDragHandleSpec.idleOpacity;
    final theme = Theme.of(context);
    final active = _menuOpen || _focused || _dragging;
    final backgroundColor = active
        ? theme.colorScheme.primaryContainer.withAlpha(180)
        : _hovered
            ? theme.colorScheme.surfaceContainerHighest.withAlpha(150)
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
      );

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
    if (_dragging && mounted) {
      setState(() => _dragging = false);
    } else {
      _dragging = false;
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
    if (!_dragging && mounted) {
      setState(() => _dragging = true);
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

  void _resetPointerGesture() {
    final wasDragging = _dragging;
    _activePointer = null;
    _pressOrigin = null;
    _suppressMenuForPointer = false;
    _dragging = false;
    _dropTarget = null;
    _removeDropIndicator();
    if (wasDragging && mounted) {
      setState(() {});
    }
  }

  void _updateDropTarget(Offset globalPosition) {
    final next = widget.registry.blockReorderDropTargetFromGlobalOffset(
      globalPosition,
    );
    if (_sameDropTarget(_dropTarget, next)) {
      return;
    }
    _dropTarget = next;
    _syncDropIndicator();
  }

  bool _sameDropTarget(
    BlockReorderDropTarget? a,
    BlockReorderDropTarget? b,
  ) {
    return a?.blockId == b?.blockId &&
        a?.blockIndex == b?.blockIndex &&
        a?.placement == b?.placement &&
        a?.blockRect == b?.blockRect;
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
    final target = _dropTarget;
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

  void _submitBlockReorder(BlockReorderDropTarget? target) {
    if (!_canDragSort || target == null) {
      return;
    }
    final insertionIndex =
        target.insertionIndex.clamp(0, widget.blockCount).toInt();
    final toIndex = insertionIndex > widget.blockIndex
        ? insertionIndex - 1
        : insertionIndex;
    if (toIndex < 0 ||
        toIndex >= widget.blockCount ||
        toIndex == widget.blockIndex) {
      return;
    }
    widget.onAction?.call(
      ObjectBlockActionIntent(
        action: toIndex < widget.blockIndex
            ? ObjectBlockAction.moveUp
            : ObjectBlockAction.moveDown,
        blockIndex: widget.blockIndex,
        value: toIndex,
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
        const PopupMenuDivider(height: _kPopupMenuDividerHeight),
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
    final hasRowFormatItems =
        widget.onFormatChanged != null && widget.canChangeBlockFormat;
    if (hasRowFormatItems || widget.blockCount > 1) {
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
      entries.addAll(const <PopupMenuEntry<_ObjectMenuSelection>>[
        PopupMenuDivider(height: _kPopupMenuDividerHeight),
        PopupMenuItem<_ObjectMenuSelection>(
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
    final canMoveUp = BlockDragHandleSpec.canMoveUp(
      canEdit: widget.canEdit,
      blockIndex: widget.blockIndex,
      blockCount: widget.blockCount,
    );
    final canMoveDown = BlockDragHandleSpec.canMoveDown(
      canEdit: widget.canEdit,
      blockIndex: widget.blockIndex,
      blockCount: widget.blockCount,
    );
    final entries = <PopupMenuEntry<_ObjectMenuSelection>>[];
    if (widget.onFormatChanged != null && widget.canChangeBlockFormat) {
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _rowFormatMenuItem(_RowBlockFormat.paragraph, '普通文本'),
        _rowFormatMenuItem(_RowBlockFormat.heading, '标题'),
        _rowFormatMenuItem(_RowBlockFormat.code, '代码块'),
      ]);
      if (widget.blockCount > 1) {
        entries.add(const PopupMenuDivider(height: _kPopupMenuDividerHeight));
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

/// Vertical spacing between two index-adjacent top-level blocks.
///
/// Render-layer concern only: it feeds the virtual list's `offsetFor` /
/// `totalExtent` accounting but never the document model, measurement of an
/// individual block, or keep-alive. Returns `fallback` unchanged when the host
/// passes custom spacing that deviates from `_kDefaultBlockSpacing` (the custom
/// path must keep winning). Otherwise list pairs collapse to
/// `_kListItemSpacing` / `_kNestedListItemSpacing` and heading margins apply via
/// `_blockMarginBefore` / `_blockMarginAfter`. Per the "Consecutive quote block
/// background" contract in `docs/rendering.md`, `quote → quote` collapses to `0`
/// so adjacent quote surfaces fuse; every other adjacency keeps its current
/// spacing, including `quote → non-quote` boundaries.
double _spacingBetweenBlocks(
  BlockNode previous,
  BlockNode next,
  double fallback,
) {
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
  // Any index-adjacent `quote → quote` pair collapses to 0 so their surface
  // backgrounds fuse into one continuous run. Grouping is adjacency + type
  // only — an `indent` attribute does not start a new column or break the
  // run (see the "Consecutive quote block background" contract in
  // `docs/rendering.md`).
  if (_isQuoteBlock(previous) && _isQuoteBlock(next)) {
    return _kAdjacentQuoteSpacing;
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
  return block is TextBlockNode && block.type == BlockType.quote;
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
/// index-adjacent and both `BlockType.quote`. Grouping is adjacency + type
/// only — an `indent` attribute does not extend or break the run, so a quote
/// flanked by quotes of any indent still joins them. A non-quote block (or a
/// quote flanked only by non-quotes) is [QuoteGroupPosition.standalone]. See
/// "Consecutive quote block background" in `docs/rendering.md`.
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
    headingCollapseState: rc.headingCollapseState,
    onHeadingCollapseToggled: rc.onHeadingCollapseToggled,
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
  return _withSelectableImageBlock(
    image,
    rc,
    _ImageBlockContent(
      block: image,
      selected: _objectBlockSelected(image, rc),
      child: media,
    ),
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
      blockIndex: rc.blockIndex,
      blockCount: rc.blockCount,
      selected: _objectBlockSelected(block, rc),
      canEdit: rc.canEdit,
      onAction: rc.onObjectBlockAction,
    ),
  );
}

Widget _defaultVideoBlockRenderer(
  BuildContext context,
  BlockRenderContext rc,
) {
  final video = rc.block as VideoBlockNode;
  final result = _resolveMediaWithStatus(context, rc);
  // A resolver-provided widget always wins over any placeholder; only the
  // fallback distinguishes the cover placeholder (no / declining resolver)
  // from the load-failure slot (threw), so the catch-and-fallback path
  // surfaces a visually distinct failure state.
  final media = result.hasWidget
      ? result.widget!
      : _VideoBlockPlaceholder(
          block: video,
          status: result.threw
              ? _VideoBlockPlaceholderStatus.failed
              : _VideoBlockPlaceholderStatus.cover,
        );
  return _withSelectableVideoBlock(
    video,
    rc,
    _VideoBlockContent(
      block: video,
      selected: _objectBlockSelected(video, rc),
      child: media,
    ),
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

/// Asks the injected [MediaResolver] (if any) to render [rc.block]. Returns
/// `null` when no resolver is injected, the resolver declines (`null`), or the
/// resolver throws — in all those cases the caller falls back to the built-in
/// placeholder. The try/catch keeps a faulty resolver from crashing the editor
/// (see `docs/schema_and_commands.md` §Error handling).
Widget? _resolveMedia(BuildContext context, BlockRenderContext rc) {
  return _resolveMediaWithStatus(context, rc).widget;
}

/// Same as [_resolveMedia] but also reports whether the resolver threw, so
/// callers that distinguish the failure fallback (image blocks) can pick the
/// right placeholder status.
_MediaResolveResult _resolveMediaWithStatus(
  BuildContext context,
  BlockRenderContext rc,
) {
  final resolver = rc.mediaResolver;
  if (resolver == null) {
    return const _MediaResolveResult();
  }
  try {
    return _MediaResolveResult(widget: resolver.resolve(context, rc.block));
  } on Object catch (error) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      library: 'wenz_richtext',
      context: ErrorDescription('MediaResolver.resolve threw for block '
          '${rc.block.id} (${rc.block.type}); falling back to placeholder.'),
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
  final media =
      _resolveMedia(context, rc) ?? _VideoBlockPlaceholder(block: block);
  final aspectRatio = _safeVideoAspectRatio(block.effectiveAspectRatio);
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
            child: Semantics(
              label: _videoAccessibleLabel(block),
              image: true,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: _VideoFrameChildBoundary(child: media),
              ),
            ),
          ),
        );
      },
    ),
  );
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
  ImageBlockNode block,
  BlockRenderContext rc,
  Widget child, {
  VoidCallback? onPreview,
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
    _MediaBlockChrome(
      blockIndex: rc.blockIndex,
      blockCount: rc.blockCount,
      selected: selected,
      canEdit: rc.canEdit,
      imageActions: true,
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
    selected: selected,
  );
}

Widget _withSelectableVideoBlock(
  VideoBlockNode block,
  BlockRenderContext rc,
  Widget child, {
  VoidCallback? onPreview,
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
        selected: selected,
        canEdit: rc.canEdit,
        imageActions: false,
        onAction: rc.onObjectBlockAction,
        onPreview: onPreview,
        child: _BlockObjectSelectionSurface(
          blockId: block.id,
          blockIndex: rc.blockIndex,
          path: path,
          selection: rc.selection,
          registry: rc.registry,
          showDebugOverlay: rc.showDebugOverlay,
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
    this.headingCollapseState,
    this.onHeadingCollapseToggled,
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
  final HeadingCollapseState? headingCollapseState;
  final ValueChanged<String>? onHeadingCollapseToggled;
  final TableToolbarActionHandler? onToolbarAction;
  final TableColumnResizeHandler? onColumnResize;
  final TodoCheckedChangeHandler? onTodoCheckedChanged;
  final List<FindReplaceMatch> findMatches;
  final FindReplaceMatch? currentFindMatch;

  @override
  Widget build(BuildContext context) {
    final isTodoListItem = block.type == BlockType.listItem &&
        (block.attributes.listType == 'task' || block.attributes.checked != null);
    final showTodoListMarker =
        isTodoListItem && block.attributes.listType == 'ordered';
    final isTaskChecked = block.attributes.checked == true;
    final baseStyle = _blockTextStyle(context, block, textStyle);
    final todoStyle = isTodoListItem ? _todoTextStyle(baseStyle) : baseStyle;
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
          ? _lineHeightFor(effectiveStyle)
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
    if (block.type == BlockType.quote) {
      return _withBlockSemantics(
        block,
        _QuoteBlockSurface(
          position: quoteGroupPosition,
          child: text,
        ),
        selected: selected,
      );
    }
    if (isTodoListItem) {
      return _withBlockSemantics(
        block,
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
        selected: selected,
      );
    }
    if (block.type == BlockType.heading && headingCollapseState != null) {
      return _withBlockSemantics(
        block,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HeadingCollapseButton(
              blockId: block.id,
              state: headingCollapseState!,
              registry: registry,
              onToggled: onHeadingCollapseToggled,
            ),
            Expanded(child: text),
          ],
        ),
        selected: selected,
      );
    }
    if (prefix == null) {
      return _withBlockSemantics(block, text, selected: selected);
    }
    return _withBlockSemantics(
      block,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            key: ValueKey<String>('wenz-richtext-list-marker-${block.id}'),
            width: _kListMarkerWidth,
            child:
                Text(prefix, style: effectiveStyle, textAlign: TextAlign.end),
          ),
          const SizedBox(width: _kListMarkerGap),
          Expanded(child: text),
        ],
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
          alignment: AlignmentDirectional.topStart,
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
                enabled: enabled,
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
    required this.enabled,
  });

  final HeadingCollapseState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final icon = state.isCollapsed
        ? Icons.keyboard_arrow_right_rounded
        : Icons.keyboard_arrow_down_rounded;
    return SizedBox.square(
      dimension: _kHeadingCollapseIconSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon),
          if (enabled && state.isCollapsed && state.hasHiddenBlocks)
            PositionedDirectional(
              end: -7,
              bottom: -5,
              child: _HeadingCollapseCountBadge(
                count: state.hiddenBlockCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeadingCollapseCountBadge extends StatelessWidget {
  const _HeadingCollapseCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          _headingCollapseCountText(count),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
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

String _headingCollapseCountText(int count) {
  if (count > 99) {
    return '99+';
  }
  return count.toString();
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
    return MouseRegion(
      cursor: widget.onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: SizedBox(
        key: _hitTestKey,
        width: _kTodoCheckboxWidth,
        height: _kTodoCheckboxHeight,
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

/// Paint-only background for a single `BlockType.quote` text block.
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
/// (`child`), not here. See "Consecutive quote block background" in
/// `docs/rendering.md` for the contract by which index-adjacent quote blocks
/// fuse into one continuous background — corners, vertical padding, and the
/// accent bar redistribute by group position (first / interior / last) while
/// the start edge stays square so neighbours join without a seam.
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

  /// Top inset: full [_outerVerticalPadding] on a standalone quote and on the
  /// first block of a run; tightened to [_innerVerticalPadding] otherwise so
  /// the block joins the quote below without a doubled gap.
  double get _topPadding =>
      position == QuoteGroupPosition.standalone ||
              position == QuoteGroupPosition.first
          ? _outerVerticalPadding
          : _innerVerticalPadding;

  /// Bottom inset: full [_outerVerticalPadding] on a standalone quote and on
  /// the last block of a run; tightened to [_innerVerticalPadding] otherwise
  /// so the block joins the quote above without a doubled gap.
  double get _bottomPadding =>
      position == QuoteGroupPosition.standalone ||
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
            children: <Widget>[
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
          fontSize: _kCodeBlockFontSize,
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
          fontSize: _kCodeBlockFontSize,
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
          padding: const EdgeInsets.symmetric(
            horizontal: _kCodeBlockPaddingHorizontal,
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
                      (codeStyle.fontSize ?? _kCodeBlockFontSize) *
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

class _CodeScrollableTextSurfaceState extends State<_CodeScrollableTextSurface> {
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
    if (toolbar == null) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxToolbarWidth = constraints.maxWidth.isFinite
            ? math.max(
                0.0,
                constraints.maxWidth - (_kBlockFloatingToolbarInset * 2),
              )
            : double.infinity;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            child,
            PositionedDirectional(
              top: _kBlockFloatingToolbarInset,
              end: _kBlockFloatingToolbarInset,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxToolbarWidth),
                child: toolbar,
              ),
            ),
          ],
        );
      },
    );
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
    final accentColor = _codeBlockAccentColor(theme);
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
                              itemBuilder: (context) => <PopupMenuEntry<String>>[
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
                constraints: _kBlockToolbarButtonConstraints,
                iconSize: _kBlockToolbarIconSize,
                style: _blockToolbarIconButtonStyle(
                  theme,
                  foregroundColor: accentColor,
                  disabledForegroundColor: accentColor.withAlpha(
                    _kMinimalToolbarDisabledAlpha,
                  ),
                ),
                onPressed: onCopyPressed,
                icon: const Icon(Icons.copy, semanticLabel: '复制代码内容'),
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
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final tableTextStyle =
        effectiveStyle.copyWith(fontSize: _kTableCellFontSize);
    final tableBorderColor = _tableBorderColor(theme);
    return _withBlockSemantics(
      block,
      LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _TableGridMetrics.compute(
            table: table,
            maxWidth: _tableMaxWidth(constraints, columnCount),
            textStyle: tableTextStyle,
            textDirection: Directionality.of(context),
          );
          final activeRange = _activeTableRange(selection, block, blockIndex);
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
                                  table.columnAlignments[cell.columnIndex],
                                ),
                                selection: selection,
                                compositionState: compositionState,
                                registry: registry,
                                showCaret: showCaret,
                                highlightWholeCell: _shouldHighlightTableCell(
                                  selection,
                                  block.id,
                                  blockIndex,
                                  cell.rowIndex,
                                  cell.columnIndex,
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
                  for (var column = 0;
                      column < metrics.columnWidths.length;
                      column++)
                    Positioned(
                      left: metrics.columnLefts[column] +
                          metrics.columnWidths[column] -
                          (_kTableResizeHandleWidth / 2),
                      top: 0,
                      width: _kTableResizeHandleWidth,
                      height: resizeHeight,
                      child: _TableColumnResizeHandle(
                        key: ValueKey<String>(
                          'table-resize-${block.id}-$column',
                        ),
                        columnIndex: column,
                        width: metrics.columnWidths[column],
                        onResize: (width) {
                          onColumnResize!(
                            blockIndex: blockIndex,
                            columnIndex: column,
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
                    }) =>
                      TableFloatingToolbarOverlayRequest(
                        owner: owner,
                        anchorLink: anchorLink,
                        anchorRect: anchorRect,
                        visibleTop: visibleTop,
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
    final cell = block.table.cellAt(range.startRow, range.startColumn);
    final canDeleteRow = block.table.rowCount > 1;
    final canDeleteColumn = block.table.columnCount > 1;
    final canMerge = !range.isSingleCell;
    final canSplit = cell != null &&
        !cell.covered &&
        (cell.rowSpan > 1 || cell.columnSpan > 1);
    return _MinimalFloatingToolbarSurface(
      key: const ValueKey<String>('table-floating-toolbar'),
      child: Wrap(
        spacing: _kMinimalFloatingToolbarButtonGap,
        runSpacing: _kMinimalFloatingToolbarButtonGap,
        children: <Widget>[
          _button(
            theme: theme,
            icon: Icons.keyboard_arrow_down,
            tooltip: '在下方插入行',
            action: TableToolbarAction.insertRowBelow,
          ),
          _button(
            theme: theme,
            icon: Icons.keyboard_arrow_right,
            tooltip: '在右侧插入列',
            action: TableToolbarAction.insertColumnAfter,
          ),
          _divider(theme),
          if (canSplit)
            _button(
              theme: theme,
              icon: Icons.call_split,
              tooltip: '拆分单元格',
              action: TableToolbarAction.splitCell,
            )
          else
            _button(
              theme: theme,
              icon: Icons.call_merge,
              tooltip: '合并所选单元格',
              action: TableToolbarAction.mergeCells,
              enabled: canMerge,
            ),
          _moreButton(
            context,
            canDeleteRow: canDeleteRow,
            canDeleteColumn: canDeleteColumn,
            canMerge: canMerge,
            canSplit: canSplit,
          ),
        ],
      ),
    );
  }

  Widget _moreButton(
    BuildContext context, {
    required bool canDeleteRow,
    required bool canDeleteColumn,
    required bool canMerge,
    required bool canSplit,
  }) {
    final theme = Theme.of(context);
    return PopupMenuButton<_TableToolbarSelection>(
      tooltip: '更多表格操作',
      icon: const Icon(Icons.more_horiz),
      iconSize: _kBlockToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme),
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
      itemBuilder: (context) => _moreItems(
        canDeleteRow: canDeleteRow,
        canDeleteColumn: canDeleteColumn,
        canMerge: canMerge,
        canSplit: canSplit,
      ),
    );
  }

  List<PopupMenuEntry<_TableToolbarSelection>> _moreItems({
    required bool canDeleteRow,
    required bool canDeleteColumn,
    required bool canMerge,
    required bool canSplit,
  }) {
    return <PopupMenuEntry<_TableToolbarSelection>>[
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.insertRowAbove),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.keyboard_arrow_up,
          label: '在上方插入行',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.insertRowBelow),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.keyboard_arrow_down,
          label: '在下方插入行',
        ),
      ),
      PopupMenuItem<_TableToolbarSelection>(
        value: const _TableToolbarSelection(TableToolbarAction.deleteRow),
        enabled: canDeleteRow,
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.table_rows_outlined,
          label: '删除行',
          enabled: canDeleteRow,
          destructive: true,
        ),
      ),
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.insertColumnBefore),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.keyboard_arrow_left,
          label: '在左侧插入列',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.insertColumnAfter),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.keyboard_arrow_right,
          label: '在右侧插入列',
        ),
      ),
      PopupMenuItem<_TableToolbarSelection>(
        value: const _TableToolbarSelection(TableToolbarAction.deleteColumn),
        enabled: canDeleteColumn,
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.view_column_outlined,
          label: '删除列',
          enabled: canDeleteColumn,
          destructive: true,
        ),
      ),
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.toggleHeader),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.table_chart_outlined,
          label: '切换表头单元格',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(
          TableToolbarAction.setBackgroundColor,
          backgroundColor: _kTableToolbarBackgroundColor,
        ),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_color_fill_outlined,
          label: '设置单元格背景',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.clearBackgroundColor),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_color_reset_outlined,
          label: '清除单元格背景',
        ),
      ),
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.alignLeft),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_align_left,
          label: '列左对齐',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.alignCenter),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_align_center,
          label: '列居中对齐',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.alignRight),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_align_right,
          label: '列右对齐',
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.clearAlignment),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.format_align_justify,
          label: '清除列对齐',
        ),
      ),
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
      PopupMenuItem<_TableToolbarSelection>(
        value: const _TableToolbarSelection(TableToolbarAction.mergeCells),
        enabled: canMerge,
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.call_merge,
          label: '合并所选单元格',
          enabled: canMerge,
        ),
      ),
      PopupMenuItem<_TableToolbarSelection>(
        value: const _TableToolbarSelection(TableToolbarAction.splitCell),
        enabled: canSplit,
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.call_split,
          label: '拆分单元格',
          enabled: canSplit,
        ),
      ),
      const PopupMenuItem<_TableToolbarSelection>(
        value: _TableToolbarSelection(TableToolbarAction.resetColumnWidth),
        height: _kPopupMenuItemHeight,
        padding: _kPopupMenuItemPadding,
        child: _PopupMenuItemContent(
          icon: Icons.width_normal_outlined,
          label: '重置列宽',
        ),
      ),
    ];
  }

  Widget _button({
    required ThemeData theme,
    required IconData icon,
    required String tooltip,
    required TableToolbarAction action,
    bool enabled = true,
    int? backgroundColor,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: _kBlockToolbarIconSize,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: _kBlockToolbarButtonConstraints,
      style: _blockToolbarIconButtonStyle(theme),
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
        endRowIndex: range.endRow,
        endColumnIndex: range.endColumn,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _divider(ThemeData theme) {
    return SizedBox(
      width: _kMinimalFloatingToolbarDividerWidth,
      height: _kBlockToolbarButtonSize,
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
    required this.columnLefts,
    required this.cells,
  });

  final double width;
  final double height;
  final List<double> columnWidths;
  final List<double> columnLefts;
  final List<_TableGridCell> cells;

  static _TableGridMetrics compute({
    required TableModel table,
    required double maxWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
  }) {
    final columnCount = table.columnCount;
    final rowCount = table.rowCount;
    final columnWidths = _resolveTableColumnWidths(table, maxWidth);
    final rowHeights = List<double>.filled(
      rowCount,
      _minimumTableCellHeight(textStyle),
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
      columnLefts: lefts,
      cells: cells,
    );
  }
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
) {
  final effectiveTextStyle = cell.isHeader
      ? textStyle.copyWith(fontWeight: FontWeight.w700)
      : textStyle;
  final text = _tableCellDisplayText(cell);
  final displayText = text.isEmpty ? ' ' : text;
  final innerWidth = cellWidth - _kTableCellPadding.horizontal;
  final painter = TextPainter(
    text: TextSpan(text: displayText, style: effectiveTextStyle),
    textAlign: TextAlign.start,
    textDirection: textDirection,
  )..layout(maxWidth: innerWidth > 0 ? innerWidth : 0);
  final height = painter.height + _kTableCellPadding.vertical;
  painter.dispose();
  final minimum = _minimumTableCellHeight(textStyle);
  return height > minimum ? height : minimum;
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

double _minimumTableCellHeight(TextStyle textStyle) {
  return ((textStyle.fontSize ?? _kTableCellFontSize) *
          _kBlockMinHeightFactor) +
      _kTableCellPadding.vertical;
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

bool _shouldHighlightTableCell(
  DocumentSelection? selection,
  String tableBlockId,
  int blockIndex,
  int rowIndex,
  int columnIndex,
) {
  if (selection == null || selection.isCollapsed) {
    return false;
  }
  // Intra-table cell range (drag within the table): highlight cells inside the
  // range via the structured TableCellRange.
  final range = selection.tableCellRange;
  if (range != null) {
    if (range.isSingleCell) {
      return false;
    }
    return range.tableBlockId == tableBlockId &&
        range.blockIndex == blockIndex &&
        range.containsCell(rowIndex, columnIndex);
  }
  // Cross-block selection that spans this table block (e.g. select-all across
  // a paragraph + table): when the table block sits strictly between the
  // selection endpoints, every cell is part of the selection and highlights.
  final start = selection.start;
  final end = selection.end;
  final tableCovered =
      start.blockIndex < blockIndex && end.blockIndex > blockIndex;
  if (tableCovered) {
    return true;
  }
  final cellPath = PositionPath.tableCellText(
    tableBlockId,
    rowIndex,
    columnIndex,
  );
  if (start.blockIndex == blockIndex &&
      start.path.isTableCellText &&
      end.blockIndex > blockIndex) {
    return start.blockId == tableBlockId && cellPath.compare(start.path) > 0;
  }
  if (end.blockIndex == blockIndex &&
      end.path.isTableCellText &&
      start.blockIndex < blockIndex) {
    return end.blockId == tableBlockId && cellPath.compare(end.path) < 0;
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
    final inlineContent = _tableCellInlineContent(cell);
    final textLength = inlineNodesLength(inlineContent);
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withAlpha(54);
    final effectiveTextStyle = (cell?.isHeader ?? false)
        ? widget.textStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : widget.textStyle;
    final inlineTextLayout = _inlineTextLayoutFor(
      context,
      inlineContent,
      effectiveTextStyle,
      compositionRange,
      widget.inlineEmbedRenderer,
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
    );
    final backgroundColor = _tableCellBackgroundColor(
      theme: theme,
      cell: cell,
      rowIndex: widget.rowIndex,
    );
    final surface = _TextSelectionSurface(
      blockId: tableBlock.id,
      blockIndex: blockIndex,
      path: path,
      textLength: textLength,
      textSpan: TextSpan(
        style: effectiveTextStyle,
        children: textLength == 0
            ? const <InlineSpan>[TextSpan(text: ' ')]
            : inlineTextLayout.spans,
      ),
      offsetMapper: inlineTextLayout.offsetMapper,
      textAlign: widget.textAlign,
      minHeight: (widget.textStyle.fontSize ?? 14) * _kBlockMinHeightFactor,
      selection: widget.selection,
      showCaret: widget.showCaret,
      registry: widget.registry,
      showDebugOverlay: widget.showDebugOverlay,
      findRanges: _findRangesForPath(
        widget.findMatches,
        widget.currentFindMatch,
        blockIndex,
        path,
        textLength,
      ),
      // The cell frame — not the centred text surface — is the hit-test box.
      // The surface resolves the cell→text-local offset itself (it owns the
      // text-surface render box via its own key), stripping the padding and
      // the vertical centring gap that TableCellVerticalAlignment.middle
      // introduces for short cells.
      hitTestKey: _cellFrameKey,
    );
    final selected = widget.highlightWholeCell ||
        _selectionRangeForPath(
              widget.selection,
              blockIndex,
              path,
              textLength,
            ) !=
            null;
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
          padding: _kTableCellPadding,
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

  /// Whether to paint the generic full-size selection overlay. Media blocks
  /// (image/video/resolved-as-media file) draw their own frame-hugging stroke
  /// and disable this to avoid a loose, double rectangle over the block margins.
  final bool showSelectionOverlay;

  @override
  State<_BlockObjectSelectionSurface> createState() =>
      _BlockObjectSelectionSurfaceState();
}

class _BlockObjectSelectionSurfaceState
    extends State<_BlockObjectSelectionSurface> {
  final GlobalKey _surfaceKey = GlobalKey();

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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTap,
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
        oldWidget.textSpan != widget.textSpan) {
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
      return widget.clampHitTestToVisibleBounds
          ? Offset.zero
          : hitLocal - const Offset(8, 8);
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
    final selectionRange = _selectionRangeForPath(
      widget.selection,
      widget.blockIndex,
      widget.path,
      widget.textLength,
    );
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
        _lastMaxWidth = maxWidth;
        // Warm the layout cache so painters and hit-testing reuse the same
        // laid-out TextPainter this frame.
        _layoutService.layout(
          span: widget.textSpan,
          textAlign: widget.textAlign,
          textDirection: direction,
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
          maxWidth: maxWidth,
          caretOffset: caretOffset,
          color: caretColor,
          textLength: widget.textLength,
          opacity: caretOpacity,
        );
        final expandEmptyTextHitBox =
            widget.textLength == 0 && constraints.maxWidth.isFinite;
        final emptyTextMinWidth = expandEmptyTextHitBox ? maxWidth : 0.0;
        final text = CustomPaint(
          painter: _SelectionHighlightPainter(
            layoutService: _layoutService,
            textSpan: widget.textSpan,
            offsetMapper: widget.offsetMapper,
            textAlign: widget.textAlign,
            textDirection: direction,
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
              maxWidth: maxWidth,
              ranges: widget.findRanges,
              color: findHighlightColor,
              activeColor: activeFindHighlightColor,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: emptyTextMinWidth,
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
    required this.maxWidth,
    required this.ranges,
    required this.color,
    required this.activeColor,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final TextAlign textAlign;
  final TextDirection textDirection;
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
    required this.maxWidth,
    required this.range,
    required this.color,
  });

  final TextLayoutService layoutService;
  final InlineSpan textSpan;
  final _InlineOffsetMapper offsetMapper;
  final TextAlign textAlign;
  final TextDirection textDirection;
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
  final safeFontSize = fontSize != null && fontSize > 0
      ? fontSize
      : _kRichTextBodyFontSize;
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
  /// Source is being uploaded/resolved — a spinner + 上传中 hint.
  loading,
  /// Resolver threw (catch-and-fallback) — error-toned failure slot.
  failed,
}

/// Built-in image-block placeholder. Renders as a content-width figure-chrome
/// empty state (icon + 简体中文 hint) and distinguishes the upload and
/// load-failure fallbacks. The outer [_ImageBlockContent] figure frame supplies
/// the shared chrome (surface base, `_kMediaCornerRadius`, `_kSurfaceBoxShadow`,
/// clip), so the placeholder only paints its own background + content and fills
/// the frame at a 2:1 slot ratio.
class _ImageBlockPlaceholder extends StatelessWidget {
  const _ImageBlockPlaceholder({
    this.status = _ImageBlockPlaceholderStatus.empty,
  });

  final _ImageBlockPlaceholderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = status == _ImageBlockPlaceholderStatus.failed;
    final titleColor = failed ? colorScheme.error : colorScheme.onSurface;
    final hintColor =
        failed ? colorScheme.error : colorScheme.onSurfaceVariant;
    final iconColor =
        failed ? colorScheme.error : colorScheme.onSurfaceVariant;
    final background = failed
        ? colorScheme.errorContainer.withAlpha(170)
        : colorScheme.surfaceContainerHighest.withAlpha(190);
    // The empty/uploading slot keeps image_outlined so the load-failure slot
    // stays distinguishable by tone + copy alone (the throwing-resolver path
    // still resolves to image_outlined for screen-reader parity).
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
    final (title, hint) = switch (status) {
      _ImageBlockPlaceholderStatus.empty =>
        ('图片占位', '插入后将在此显示图片'),
      _ImageBlockPlaceholderStatus.loading =>
        ('图片上传中', '正在处理，请稍候…'),
      _ImageBlockPlaceholderStatus.failed =>
        ('图片加载失败', '无法显示该图片，请重新上传'),
    };

    return AspectRatio(
      aspectRatio: _kImagePlaceholderAspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_kMediaCornerRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              indicator,
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: hintColor,
                ),
              ),
            ],
          ),
        ),
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
    this.status = _VideoBlockPlaceholderStatus.cover,
  });

  final VideoBlockNode block;

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
          borderRadius: BorderRadius.circular(_kMediaCornerRadius),
          boxShadow: _kSurfaceBoxShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kMediaCornerRadius),
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

double _videoFrameHeight(double width, double aspectRatio) {
  if (!width.isFinite || width <= 0) {
    return _kVideoMinFrameHeight;
  }
  final naturalHeight = width / aspectRatio;
  return naturalHeight
      .clamp(_kVideoMinFrameHeight, _kVideoMaxFrameHeight)
      .toDouble();
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
      color: _formulaBlockForegroundColor(theme),
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
      backgroundColor: _formulaBlockBackgroundColor(theme),
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
              color: theme.colorScheme.secondaryContainer,
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

class _VideoBlockContent extends StatelessWidget {
  const _VideoBlockContent({
    required this.block,
    required this.child,
    required this.selected,
  });

  final VideoBlockNode block;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-video-block-${block.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _kMediaBlockMarginVertical / 2,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Explicit overflow boundary for video content. The editor's
            // available width and the block's possibly unsafe aspect ratio are
            // normalized into finite frame constraints before any placeholder
            // or resolver-provided video player is laid out.
            final frameWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(0.0, double.infinity).toDouble()
                : _kVideoFrameFallbackWidth;
            final aspectRatio =
                _safeVideoAspectRatio(block.effectiveAspectRatio);
            final frameHeight = _videoFrameHeight(frameWidth, aspectRatio);
            return Align(
              alignment: AlignmentDirectional.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: frameWidth),
                child: SizedBox(
                  width: double.infinity,
                  height: frameHeight,
                  child: _MediaSelectionStroke(
                    selected: selected,
                    child: DecoratedBox(
                      key: ValueKey<String>(
                        'wenz-richtext-video-frame-${block.id}',
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius:
                            BorderRadius.circular(_kMediaCornerRadius),
                        boxShadow: _kSurfaceBoxShadow,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_kMediaCornerRadius),
                        child: AspectRatio(
                          key: ValueKey<String>(
                            'wenz-richtext-video-aspect-${block.id}',
                          ),
                          aspectRatio: aspectRatio,
                          child: _VideoFrameChildBoundary(child: child),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    this.onAction,
  });

  final String blockId;
  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final ObjectBlockActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellDecoration = selected
        ? BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(48),
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          )
        : const BoxDecoration();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kDividerMarginVertical),
      child: DecoratedBox(
        key: ValueKey<String>('wenz-richtext-divider-shell-$blockId'),
        decoration: shellDecoration,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 8 : 0,
            vertical: selected ? 8 : 0,
          ),
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
        ),
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
  final Color backgroundColor;
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
    this.mediaActions = false,
    this.onAction,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final bool imageActions;
  final bool fileActions;
  final bool mediaActions;
  final ObjectBlockActionHandler? onAction;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final canDispatch = onAction != null;
    final canRunMutation = canEdit && canDispatch;
    final hasMoreActions = canRunMutation;
    if (mediaActions) {
      return Wrap(
        spacing: _kMinimalFloatingToolbarButtonGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _ObjectActionButton(
            icon: Icons.open_in_full,
            tooltip: '预览媒体',
            onPressed: onPreview,
          ),
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
              fileActions: fileActions,
              onSelected: _dispatchSelection,
            ),
        ],
      );
    }
    return Wrap(
      spacing: _kMinimalFloatingToolbarButtonGap,
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
            fileActions: fileActions,
            onSelected: _dispatchSelection,
          ),
      ],
    );
  }

  void _dispatchSelection(_ObjectMenuSelection selection) {
    final action = selection.action;
    if (action != null) {
      _dispatch(action, selection.value);
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
        more = false;
  const _ObjectMenuSelection.format(this.format)
      : action = null,
        value = null,
        more = false;
  const _ObjectMenuSelection.more()
      : action = null,
        format = null,
        value = null,
        more = true;

  final ObjectBlockAction? action;
  final _RowBlockFormat? format;
  final Object? value;
  final bool more;
}

PopupMenuItem<_ObjectMenuSelection> _objectActionMenuItem({
  required ObjectBlockAction action,
  required IconData icon,
  required String label,
  Object? value,
  bool enabled = true,
  String? shortcut,
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
    required this.onSelected,
  });

  final int blockIndex;
  final int blockCount;
  final bool canRunMutation;
  final bool imageActions;
  final bool fileActions;
  final ValueChanged<_ObjectMenuSelection> onSelected;

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
    return PopupMenuButton<_ObjectMenuSelection>(
      tooltip: '更多块操作',
      icon: const Icon(Icons.more_horiz),
      iconSize: _kBlockToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme),
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
    if (widget.canRunMutation) {
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
        entries.add(const PopupMenuDivider(height: _kPopupMenuDividerHeight));
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
    if (widget.imageActions && widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(const PopupMenuDivider(height: _kPopupMenuDividerHeight));
      }
      entries.addAll(<PopupMenuEntry<_ObjectMenuSelection>>[
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.photo_size_select_small_outlined,
          label: '图片宽度：小',
          value: 240.0,
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.photo_size_select_large_outlined,
          label: '图片宽度：中',
          value: 360.0,
        ),
        _objectActionMenuItem(
          action: ObjectBlockAction.setImageDisplayWidth,
          icon: Icons.fit_screen_outlined,
          label: '图片宽度：大',
          value: 520.0,
        ),
        const PopupMenuDivider(height: _kPopupMenuDividerHeight),
        _objectActionMenuItem(
          action: ObjectBlockAction.resetImageSize,
          icon: Icons.restart_alt,
          label: '重置图片尺寸',
        ),
      ]);
    }
    if (widget.fileActions && widget.canRunMutation) {
      if (entries.isNotEmpty) {
        entries.add(const PopupMenuDivider(height: _kPopupMenuDividerHeight));
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
        entries.add(const PopupMenuDivider(height: _kPopupMenuDividerHeight));
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

class _FloatingObjectBlockToolbar extends StatelessWidget {
  const _FloatingObjectBlockToolbar({
    required this.blockIndex,
    required this.blockCount,
    required this.canEdit,
    required this.imageActions,
    required this.fileActions,
    this.mediaActions = false,
    this.onAction,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final bool canEdit;
  final bool imageActions;
  final bool fileActions;
  final bool mediaActions;
  final ObjectBlockActionHandler? onAction;
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
        mediaActions: mediaActions,
        onAction: onAction,
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
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: _kBlockToolbarButtonConstraints,
      iconSize: _kBlockToolbarIconSize,
      style: _blockToolbarIconButtonStyle(theme),
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
    return PopupMenuButton<_ObjectMenuSelection>(
      tooltip: '附件操作',
      icon: const Icon(Icons.more_horiz),
      iconSize: _kBlockToolbarIconSize,
      padding: EdgeInsets.zero,
      constraints: _kPopupMenuConstraints,
      style: _blockToolbarIconButtonStyle(theme),
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
        const PopupMenuDivider(height: _kPopupMenuDividerHeight),
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
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
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
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
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
      const PopupMenuDivider(height: _kPopupMenuDividerHeight),
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

class _ImageBlockContent extends StatelessWidget {
  const _ImageBlockContent({
    required this.block,
    required this.child,
    required this.selected,
  });

  final ImageBlockNode block;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget media = child;
    if (block.showWidth != null || block.showHeight != null) {
      media = SizedBox(
        key: ValueKey<String>('wenz-richtext-image-size-${block.id}'),
        width: block.showWidth,
        height: block.showHeight,
        child: child,
      );
    }
    final hasCaption = block.caption.trim().isNotEmpty;
    return KeyedSubtree(
      key: ValueKey<String>('wenz-richtext-image-block-${block.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _kMediaBlockMarginVertical / 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : double.infinity;
            return Align(
              alignment: AlignmentDirectional.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _MediaSelectionStroke(
                      selected: selected,
                      child: Semantics(
                        // altText surfaces here (altText > caption > asset),
                        // cooperating with the block-level label so screen
                        // readers announce the image without a duplicate node.
                        label: _imageAccessibleLabel(block),
                        image: true,
                        child: DecoratedBox(
                          key: ValueKey<String>(
                            'wenz-richtext-image-frame-${block.id}',
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius:
                                BorderRadius.circular(_kMediaCornerRadius),
                            boxShadow: _kSurfaceBoxShadow,
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(_kMediaCornerRadius),
                            child: media,
                          ),
                        ),
                      ),
                    ),
                    if (hasCaption)
                      Padding(
                        padding: const EdgeInsets.only(top: _kImageCaptionGap),
                        child: Text(
                          block.caption,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            height: 1.55,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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

class _MediaBlockChrome extends StatelessWidget {
  const _MediaBlockChrome({
    required this.blockIndex,
    required this.blockCount,
    required this.selected,
    required this.canEdit,
    required this.imageActions,
    required this.child,
    this.onAction,
    this.onPreview,
  });

  final int blockIndex;
  final int blockCount;
  final bool selected;
  final bool canEdit;
  final bool imageActions;
  final Widget child;
  final ObjectBlockActionHandler? onAction;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _BlockFloatingToolbarSurface(
        toolbar: selected
            ? _FloatingObjectBlockToolbar(
                blockIndex: blockIndex,
                blockCount: blockCount,
                canEdit: canEdit,
                imageActions: imageActions,
                fileActions: false,
                mediaActions: true,
                onAction: onAction,
                onPreview: onPreview,
              )
            : null,
        child: child,
      ),
    );
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
    final base = _richTextBodyStyle(theme, widget.textStyle);
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

Color _formulaBlockBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.secondaryContainer.withAlpha(110)
      : const Color(_kFormulaBlockBackgroundColor);
}

Color _formulaBlockForegroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSecondaryContainer
      : const Color(_kFormulaBlockForegroundColor);
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
  final baseStyle = _richTextBodyStyle(theme, textStyle);
  return switch (block.type) {
    BlockType.heading => baseStyle.merge(
        _headingTextStyle(theme, baseStyle, block.attributes.level),
      ),
    BlockType.quote => baseStyle.merge(
        TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    _ => baseStyle,
  };
}

TextStyle _richTextBodyStyle(ThemeData theme, TextStyle? overrideStyle) {
  final baseline = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: _kRichTextBodyFontSize,
    height: _kRichTextBodyLineHeight,
  );
  return overrideStyle == null ? baseline : baseline.merge(overrideStyle);
}

Color _editorBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark ? Colors.black : Colors.white;
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

TextStyle _todoTextStyle(TextStyle baseStyle) {
  final fontSize = baseStyle.fontSize ?? 14;
  if (fontSize <= 0) {
    return baseStyle;
  }
  final lineHeight = math.max(
    _lineHeightFor(baseStyle),
    _kTodoCheckboxHeight,
  );
  return baseStyle.copyWith(height: lineHeight / fontSize);
}

double _lineHeightFor(TextStyle style) {
  final fontSize = style.fontSize ?? 14;
  if (fontSize <= 0) {
    return _kTodoCheckboxHeight;
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
    final view = SizedBox.fromSize(
      key: _inlineFormulaKey,
      size: placeholderSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withAlpha(90),
          borderRadius: BorderRadius.circular(4),
          border: composing
              ? Border(
                  bottom: BorderSide(color: textStyle.color ?? scheme.primary))
              : null,
        ),
        child: Padding(
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
        ),
      ),
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
        color: scheme.onSecondaryContainer,
        backgroundColor: scheme.secondaryContainer.withAlpha(90),
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
    BlockType.quote => '|',
    BlockType.listItem => switch (block.attributes.listType) {
        'ordered' => '1.',
        'task' => block.attributes.checked == true ? '[x]' : '[ ]',
        _ => '-',
      },
    _ => null,
  };
}

List<String?> _listMarkersFor(List<BlockNode> blocks) {
  return <String?>[
    for (var index = 0; index < blocks.length; index++)
      _listMarkerFor(blocks, index),
  ];
}

String? _listMarkerFor(List<BlockNode> blocks, int index) {
  final block = blocks[index];
  if (block is! TextBlockNode || block.type != BlockType.listItem) {
    return null;
  }
  final indent = _blockIndentLevel(block);
  return switch (block.attributes.listType) {
    'ordered' => '${_orderedListNumberFor(blocks, index, indent)}.',
    'task' => null,
    _ => _unorderedListBullet(indent),
  };
}

int _orderedListNumberFor(List<BlockNode> blocks, int index, int indent) {
  var number = 1;
  for (var previousIndex = index - 1; previousIndex >= 0; previousIndex--) {
    final previous = blocks[previousIndex];
    final previousIndent = _blockIndentLevel(previous);
    if (previousIndent > indent) {
      continue;
    }
    if (previousIndent < indent) {
      break;
    }
    if (previous is TextBlockNode && previous.type == BlockType.listItem) {
      if (previous.attributes.listType == 'ordered') {
        number++;
        continue;
      }
      break;
    }
    break;
  }
  return number;
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
