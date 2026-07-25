import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _kPackageName = 'wenz_richtext';
const String _kAssetRoot = 'assets/lucide';

/// Lucide icon names used by the default toolbars.
///
/// Values are also the local SVG file names without the `.svg` suffix.
abstract final class WenzLucideToolbarIcons {
  static const String arrowDown = 'arrow-down';
  static const String arrowLeft = 'arrow-left';
  static const String arrowRight = 'arrow-right';
  static const String arrowUp = 'arrow-up';
  static const String alignCenter = 'text-align-center';
  static const String alignJustify = 'text-align-justify';
  static const String alignLeft = 'text-align-start';
  static const String alignRight = 'text-align-end';
  static const String badge = 'badge';
  static const String bold = 'bold';
  static const String callout = 'lightbulb';
  static const String check = 'check';
  static const String chevronDown = 'chevron-down';
  static const String chevronRight = 'chevron-right';
  static const String chevronUp = 'chevron-up';
  static const String clearTextColor = 'eraser';
  static const String code = 'code';
  static const String divider = 'minus';
  static const String columns = 'columns-3';
  static const String extension = 'puzzle';
  static const String file = 'paperclip';
  static const String formula = 'square-function';
  static const String heading = 'heading';
  static const String indentDecrease = 'indent-decrease';
  static const String indentIncrease = 'indent-increase';
  static const String image = 'image';
  static const String insert = 'plus';
  static const String italic = 'italic';
  static const String link = 'link';
  static const String listTree = 'list-tree';
  static const String more = 'ellipsis';
  static const String orderedList = 'list-ordered';
  static const String paintBucket = 'paint-bucket';
  static const String palette = 'palette';
  static const String quote = 'quote';
  static const String refresh = 'refresh-cw';
  static const String redo = 'redo-2';
  static const String removeFormat = 'remove-formatting';
  static const String rows = 'rows-3';
  static const String strikethrough = 'strikethrough';
  static const String table = 'table';
  static const String tableBackgroundClear = clearTextColor;
  static const String tableBackgroundFill = paintBucket;
  static const String tableCellAlignCenter = alignCenter;
  static const String tableCellAlignClear = removeFormat;
  static const String tableCellAlignLeft = alignLeft;
  static const String tableCellAlignRight = alignRight;
  static const String tableCellStyle = table;
  static const String tableColumnInsert = 'table-columns-split';
  static const String tableColumnInsertAfter = arrowRight;
  static const String tableColumnInsertBefore = arrowLeft;
  static const String tableColumnDelete = columns;
  static const String tableColumnWidthReset = refresh;
  static const String tableDelete = 'trash-2';
  static const String tableHeaderToggle = heading;
  static const String tableMerge = 'table-cells-merge';
  static const String tableMore = more;
  static const String tableSelect = table;
  static const String tableSelectColumn = columns;
  static const String tableSelectRow = rows;
  static const String tableRowInsert = 'table-rows-split';
  static const String tableRowInsertAbove = arrowUp;
  static const String tableRowInsertBelow = arrowDown;
  static const String tableRowDelete = rows;
  static const String tableSplit = 'table-cells-split';
  static const String taskList = 'list-checks';
  static const String textColor = 'type';
  static const String textBlock = textColor;
  static const String underline = 'underline';
  static const String undo = 'undo-2';
  static const String unorderedList = 'list';
  static const String video = 'video';
  static const String workflow = 'workflow';
  static const String emoji = 'smile';

  static const String fallback = extension;
}

const Set<String> _kKnownIconNames = <String>{
  'align-center-horizontal',
  'align-end-horizontal',
  'align-horizontal-justify-center',
  'align-start-horizontal',
  WenzLucideToolbarIcons.arrowDown,
  WenzLucideToolbarIcons.arrowLeft,
  WenzLucideToolbarIcons.arrowRight,
  WenzLucideToolbarIcons.arrowUp,
  WenzLucideToolbarIcons.alignCenter,
  WenzLucideToolbarIcons.alignJustify,
  WenzLucideToolbarIcons.alignLeft,
  WenzLucideToolbarIcons.alignRight,
  WenzLucideToolbarIcons.badge,
  WenzLucideToolbarIcons.bold,
  WenzLucideToolbarIcons.callout,
  WenzLucideToolbarIcons.check,
  WenzLucideToolbarIcons.chevronDown,
  WenzLucideToolbarIcons.chevronRight,
  WenzLucideToolbarIcons.chevronUp,
  WenzLucideToolbarIcons.clearTextColor,
  WenzLucideToolbarIcons.code,
  WenzLucideToolbarIcons.divider,
  WenzLucideToolbarIcons.columns,
  WenzLucideToolbarIcons.extension,
  WenzLucideToolbarIcons.file,
  WenzLucideToolbarIcons.formula,
  WenzLucideToolbarIcons.heading,
  WenzLucideToolbarIcons.indentDecrease,
  WenzLucideToolbarIcons.indentIncrease,
  WenzLucideToolbarIcons.image,
  WenzLucideToolbarIcons.insert,
  WenzLucideToolbarIcons.italic,
  WenzLucideToolbarIcons.link,
  WenzLucideToolbarIcons.listTree,
  WenzLucideToolbarIcons.more,
  WenzLucideToolbarIcons.orderedList,
  WenzLucideToolbarIcons.paintBucket,
  WenzLucideToolbarIcons.palette,
  WenzLucideToolbarIcons.quote,
  WenzLucideToolbarIcons.refresh,
  WenzLucideToolbarIcons.redo,
  WenzLucideToolbarIcons.removeFormat,
  WenzLucideToolbarIcons.rows,
  WenzLucideToolbarIcons.strikethrough,
  WenzLucideToolbarIcons.table,
  WenzLucideToolbarIcons.tableColumnInsert,
  WenzLucideToolbarIcons.tableDelete,
  WenzLucideToolbarIcons.tableMerge,
  WenzLucideToolbarIcons.tableRowInsert,
  WenzLucideToolbarIcons.tableSplit,
  WenzLucideToolbarIcons.taskList,
  WenzLucideToolbarIcons.textColor,
  WenzLucideToolbarIcons.underline,
  WenzLucideToolbarIcons.undo,
  WenzLucideToolbarIcons.unorderedList,
  WenzLucideToolbarIcons.video,
  WenzLucideToolbarIcons.workflow,
  WenzLucideToolbarIcons.emoji,
};

const Map<String, String> _kIconAliases = <String, String>{
  'account-tree': WenzLucideToolbarIcons.workflow,
  'account-tree-outlined': WenzLucideToolbarIcons.workflow,
  'align-cell-center': WenzLucideToolbarIcons.tableCellAlignCenter,
  'align-cell-left': WenzLucideToolbarIcons.tableCellAlignLeft,
  'align-cell-right': WenzLucideToolbarIcons.tableCellAlignRight,
  'align-cell-clear': WenzLucideToolbarIcons.tableCellAlignClear,
  'align-center': WenzLucideToolbarIcons.alignCenter,
  'align-justify': WenzLucideToolbarIcons.alignJustify,
  'align-left': WenzLucideToolbarIcons.alignLeft,
  'align-right': WenzLucideToolbarIcons.alignRight,
  'add': WenzLucideToolbarIcons.insert,
  'arrow-downward': WenzLucideToolbarIcons.arrowDown,
  'arrow-drop-down': WenzLucideToolbarIcons.chevronDown,
  'arrow-upward': WenzLucideToolbarIcons.arrowUp,
  'attach-file': WenzLucideToolbarIcons.file,
  'background-clear': WenzLucideToolbarIcons.tableBackgroundClear,
  'background-fill': WenzLucideToolbarIcons.tableBackgroundFill,
  'badge-outlined': WenzLucideToolbarIcons.badge,
  'call-merge': WenzLucideToolbarIcons.tableMerge,
  'call-split': WenzLucideToolbarIcons.tableSplit,
  'callout': WenzLucideToolbarIcons.callout,
  'checklist': WenzLucideToolbarIcons.taskList,
  'clear-alignment': WenzLucideToolbarIcons.tableCellAlignClear,
  'emoji': WenzLucideToolbarIcons.emoji,
  'emoji-emotions-outlined': WenzLucideToolbarIcons.emoji,
  'divider': WenzLucideToolbarIcons.divider,
  'delete-column': WenzLucideToolbarIcons.tableColumnDelete,
  'delete-row': WenzLucideToolbarIcons.tableRowDelete,
  'delete-table': WenzLucideToolbarIcons.tableDelete,
  'expand-less': WenzLucideToolbarIcons.chevronUp,
  'expand-more': WenzLucideToolbarIcons.chevronDown,
  'extension': WenzLucideToolbarIcons.extension,
  'extension-outlined': WenzLucideToolbarIcons.extension,
  'file': WenzLucideToolbarIcons.file,
  'flowchart': WenzLucideToolbarIcons.workflow,
  'format-align-center': WenzLucideToolbarIcons.alignCenter,
  'format-align-justify': WenzLucideToolbarIcons.alignJustify,
  'format-align-left': WenzLucideToolbarIcons.alignLeft,
  'format-align-right': WenzLucideToolbarIcons.alignRight,
  'format-bold': WenzLucideToolbarIcons.bold,
  'format-clear': WenzLucideToolbarIcons.removeFormat,
  'format-color-fill': WenzLucideToolbarIcons.tableBackgroundFill,
  'format-color-fill-outlined': WenzLucideToolbarIcons.tableBackgroundFill,
  'format-color-reset': WenzLucideToolbarIcons.clearTextColor,
  'format-color-reset-outlined': WenzLucideToolbarIcons.tableBackgroundClear,
  'format-color-text': WenzLucideToolbarIcons.textColor,
  'format-indent-decrease': WenzLucideToolbarIcons.indentDecrease,
  'format-indent-increase': WenzLucideToolbarIcons.indentIncrease,
  'format-italic': WenzLucideToolbarIcons.italic,
  'format-list-bulleted': WenzLucideToolbarIcons.unorderedList,
  'format-list-numbered': WenzLucideToolbarIcons.orderedList,
  'format-quote': WenzLucideToolbarIcons.quote,
  'format-strikethrough': WenzLucideToolbarIcons.strikethrough,
  'format-underline': WenzLucideToolbarIcons.underline,
  'formula': WenzLucideToolbarIcons.formula,
  'functions': WenzLucideToolbarIcons.formula,
  'highlight-remove-outlined': WenzLucideToolbarIcons.tableDelete,
  'horizontal-rule': WenzLucideToolbarIcons.divider,
  'image-outlined': WenzLucideToolbarIcons.image,
  'insert-column-after': WenzLucideToolbarIcons.tableColumnInsertAfter,
  'insert-column-before': WenzLucideToolbarIcons.tableColumnInsertBefore,
  'insert-row-above': WenzLucideToolbarIcons.tableRowInsertAbove,
  'insert-row-below': WenzLucideToolbarIcons.tableRowInsertBelow,
  'keyboard-arrow-down': WenzLucideToolbarIcons.arrowDown,
  'keyboard-arrow-down-rounded': WenzLucideToolbarIcons.arrowDown,
  'keyboard-arrow-left': WenzLucideToolbarIcons.arrowLeft,
  'keyboard-arrow-left-rounded': WenzLucideToolbarIcons.arrowLeft,
  'keyboard-arrow-right': WenzLucideToolbarIcons.arrowRight,
  'keyboard-arrow-right-rounded': WenzLucideToolbarIcons.arrowRight,
  'keyboard-arrow-up': WenzLucideToolbarIcons.arrowUp,
  'keyboard-arrow-up-rounded': WenzLucideToolbarIcons.arrowUp,
  'merge-cells': WenzLucideToolbarIcons.tableMerge,
  'more-horiz': WenzLucideToolbarIcons.tableMore,
  'more-horizontal': WenzLucideToolbarIcons.tableMore,
  'more-vert': WenzLucideToolbarIcons.tableMore,
  'more-vertical': WenzLucideToolbarIcons.tableMore,
  'palette-outlined': WenzLucideToolbarIcons.palette,
  'paragraph': WenzLucideToolbarIcons.textBlock,
  'remove-circle-outline': WenzLucideToolbarIcons.tableDelete,
  'redo': WenzLucideToolbarIcons.redo,
  'reset-column-width': WenzLucideToolbarIcons.tableColumnWidthReset,
  'smart-display': WenzLucideToolbarIcons.video,
  'smart-display-outlined': WenzLucideToolbarIcons.video,
  'select-column': WenzLucideToolbarIcons.tableSelectColumn,
  'select-row': WenzLucideToolbarIcons.tableSelectRow,
  'select-table': WenzLucideToolbarIcons.tableSelect,
  'split-cell': WenzLucideToolbarIcons.tableSplit,
  'set-background-color': WenzLucideToolbarIcons.tableBackgroundFill,
  'clear-background-color': WenzLucideToolbarIcons.tableBackgroundClear,
  'table-cell-align-center': WenzLucideToolbarIcons.tableCellAlignCenter,
  'table-cell-align-clear': WenzLucideToolbarIcons.tableCellAlignClear,
  'table-cell-align-left': WenzLucideToolbarIcons.tableCellAlignLeft,
  'table-cell-align-right': WenzLucideToolbarIcons.tableCellAlignRight,
  'table-chart': WenzLucideToolbarIcons.table,
  'text-block': WenzLucideToolbarIcons.textBlock,
  'table-chart-outlined': WenzLucideToolbarIcons.table,
  'table-column': WenzLucideToolbarIcons.tableColumnDelete,
  'table-column-delete': WenzLucideToolbarIcons.tableColumnDelete,
  'table-column-insert': WenzLucideToolbarIcons.tableColumnInsert,
  'table-column-insert-after': WenzLucideToolbarIcons.tableColumnInsertAfter,
  'table-column-insert-before': WenzLucideToolbarIcons.tableColumnInsertBefore,
  'table-column-width-reset': WenzLucideToolbarIcons.tableColumnWidthReset,
  'table-delete-column': WenzLucideToolbarIcons.tableColumnDelete,
  'table-delete-row': WenzLucideToolbarIcons.tableRowDelete,
  'table-header': WenzLucideToolbarIcons.tableHeaderToggle,
  'table-header-toggle': WenzLucideToolbarIcons.tableHeaderToggle,
  'table-merge-cells': WenzLucideToolbarIcons.tableMerge,
  'table-more': WenzLucideToolbarIcons.tableMore,
  'table-row': WenzLucideToolbarIcons.tableRowDelete,
  'table-row-delete': WenzLucideToolbarIcons.tableRowDelete,
  'table-row-insert': WenzLucideToolbarIcons.tableRowInsert,
  'table-row-insert-above': WenzLucideToolbarIcons.tableRowInsertAbove,
  'table-row-insert-below': WenzLucideToolbarIcons.tableRowInsertBelow,
  'table-rows-outlined': WenzLucideToolbarIcons.tableRowDelete,
  'table-select': WenzLucideToolbarIcons.tableSelect,
  'table-select-column': WenzLucideToolbarIcons.tableSelectColumn,
  'table-select-row': WenzLucideToolbarIcons.tableSelectRow,
  'table-split-cell': WenzLucideToolbarIcons.tableSplit,
  'toggle-header': WenzLucideToolbarIcons.tableHeaderToggle,
  'toggle-table-header': WenzLucideToolbarIcons.tableHeaderToggle,
  'tips': WenzLucideToolbarIcons.callout,
  'tips-and-updates-outlined': WenzLucideToolbarIcons.callout,
  'undo': WenzLucideToolbarIcons.undo,
  'view-column-outlined': WenzLucideToolbarIcons.tableColumnDelete,
  'width-normal': WenzLucideToolbarIcons.tableColumnWidthReset,
  'width-normal-outlined': WenzLucideToolbarIcons.tableColumnWidthReset,
};

/// Resolves a toolbar icon token to a Lucide asset name.
///
/// Unknown tokens intentionally fall back to [WenzLucideToolbarIcons.fallback]
/// so plugin and host-provided [WenzToolbarItem.icon] values never fail asset
/// lookup at runtime.
String wenzLucideToolbarIconName(String? icon) {
  final normalized = _normalizeIconToken(icon);
  if (normalized.isEmpty) {
    return WenzLucideToolbarIcons.fallback;
  }
  return _kIconAliases[normalized] ??
      (_kKnownIconNames.contains(normalized)
          ? normalized
          : WenzLucideToolbarIcons.fallback);
}

String wenzLucideToolbarAssetName(String? icon) {
  final name = wenzLucideToolbarIconName(icon);
  return '$_kAssetRoot/$name.svg';
}

class WenzLucideToolbarIcon extends StatelessWidget {
  const WenzLucideToolbarIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.disabledColor,
    this.enabled = true,
    this.semanticLabel,
    this.matchTextDirection = false,
  });

  final String? icon;
  final double? size;
  final Color? color;
  final Color? disabledColor;
  final bool enabled;
  final String? semanticLabel;
  final bool matchTextDirection;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size;
    final effectiveColor =
        enabled ? color ?? iconTheme.color : disabledColor ?? iconTheme.color;
    return SvgPicture.asset(
      wenzLucideToolbarAssetName(icon),
      package: _kPackageName,
      width: effectiveSize,
      height: effectiveSize,
      fit: BoxFit.contain,
      colorFilter: effectiveColor == null
          ? null
          : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      matchTextDirection: matchTextDirection,
    );
  }
}

String _normalizeIconToken(String? icon) {
  return icon?.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-') ??
      '';
}
