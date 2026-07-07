import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _kPackageName = 'wenz_richtext';
const String _kAssetRoot = 'assets/lucide';

/// Lucide icon names used by the default toolbars.
///
/// Values are also the local SVG file names without the `.svg` suffix.
abstract final class WenzLucideToolbarIcons {
  static const String alignCenter = 'align-center-horizontal';
  static const String alignJustify = 'align-horizontal-justify-center';
  static const String alignLeft = 'align-start-horizontal';
  static const String alignRight = 'align-end-horizontal';
  static const String badge = 'badge';
  static const String bold = 'bold';
  static const String callout = 'lightbulb';
  static const String check = 'check';
  static const String chevronDown = 'chevron-down';
  static const String chevronUp = 'chevron-up';
  static const String clearTextColor = 'eraser';
  static const String code = 'code';
  static const String extension = 'puzzle';
  static const String file = 'paperclip';
  static const String formula = 'square-function';
  static const String image = 'image';
  static const String insert = 'plus';
  static const String italic = 'italic';
  static const String link = 'link';
  static const String orderedList = 'list-ordered';
  static const String palette = 'palette';
  static const String quote = 'quote';
  static const String redo = 'redo-2';
  static const String removeFormat = 'remove-formatting';
  static const String strikethrough = 'strikethrough';
  static const String table = 'table';
  static const String tableColumnInsert = 'table-columns-split';
  static const String tableDelete = 'trash-2';
  static const String tableMerge = 'table-cells-merge';
  static const String tableRowInsert = 'table-rows-split';
  static const String tableSplit = 'table-cells-split';
  static const String taskList = 'list-checks';
  static const String textColor = 'type';
  static const String underline = 'underline';
  static const String undo = 'undo-2';
  static const String unorderedList = 'list';
  static const String video = 'video';
  static const String workflow = 'workflow';
  static const String emoji = 'smile';

  static const String fallback = extension;
}

const Set<String> _kKnownIconNames = <String>{
  WenzLucideToolbarIcons.alignCenter,
  WenzLucideToolbarIcons.alignJustify,
  WenzLucideToolbarIcons.alignLeft,
  WenzLucideToolbarIcons.alignRight,
  WenzLucideToolbarIcons.badge,
  WenzLucideToolbarIcons.bold,
  WenzLucideToolbarIcons.callout,
  WenzLucideToolbarIcons.check,
  WenzLucideToolbarIcons.chevronDown,
  WenzLucideToolbarIcons.chevronUp,
  WenzLucideToolbarIcons.clearTextColor,
  WenzLucideToolbarIcons.code,
  WenzLucideToolbarIcons.extension,
  WenzLucideToolbarIcons.file,
  WenzLucideToolbarIcons.formula,
  WenzLucideToolbarIcons.image,
  WenzLucideToolbarIcons.insert,
  WenzLucideToolbarIcons.italic,
  WenzLucideToolbarIcons.link,
  WenzLucideToolbarIcons.orderedList,
  WenzLucideToolbarIcons.palette,
  WenzLucideToolbarIcons.quote,
  WenzLucideToolbarIcons.redo,
  WenzLucideToolbarIcons.removeFormat,
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
  'align-center': WenzLucideToolbarIcons.alignCenter,
  'align-justify': WenzLucideToolbarIcons.alignJustify,
  'align-left': WenzLucideToolbarIcons.alignLeft,
  'align-right': WenzLucideToolbarIcons.alignRight,
  'add': WenzLucideToolbarIcons.insert,
  'arrow-drop-down': WenzLucideToolbarIcons.chevronDown,
  'attach-file': WenzLucideToolbarIcons.file,
  'badge-outlined': WenzLucideToolbarIcons.badge,
  'call-merge': WenzLucideToolbarIcons.tableMerge,
  'call-split': WenzLucideToolbarIcons.tableSplit,
  'callout': WenzLucideToolbarIcons.callout,
  'checklist': WenzLucideToolbarIcons.taskList,
  'emoji': WenzLucideToolbarIcons.emoji,
  'emoji-emotions-outlined': WenzLucideToolbarIcons.emoji,
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
  'format-color-reset': WenzLucideToolbarIcons.clearTextColor,
  'format-color-text': WenzLucideToolbarIcons.textColor,
  'format-italic': WenzLucideToolbarIcons.italic,
  'format-list-bulleted': WenzLucideToolbarIcons.unorderedList,
  'format-list-numbered': WenzLucideToolbarIcons.orderedList,
  'format-quote': WenzLucideToolbarIcons.quote,
  'format-strikethrough': WenzLucideToolbarIcons.strikethrough,
  'format-underline': WenzLucideToolbarIcons.underline,
  'formula': WenzLucideToolbarIcons.formula,
  'functions': WenzLucideToolbarIcons.formula,
  'highlight-remove-outlined': WenzLucideToolbarIcons.tableDelete,
  'image-outlined': WenzLucideToolbarIcons.image,
  'palette-outlined': WenzLucideToolbarIcons.palette,
  'remove-circle-outline': WenzLucideToolbarIcons.tableDelete,
  'redo': WenzLucideToolbarIcons.redo,
  'smart-display': WenzLucideToolbarIcons.video,
  'smart-display-outlined': WenzLucideToolbarIcons.video,
  'table-chart': WenzLucideToolbarIcons.table,
  'table-chart-outlined': WenzLucideToolbarIcons.table,
  'table-rows-outlined': WenzLucideToolbarIcons.tableRowInsert,
  'tips': WenzLucideToolbarIcons.callout,
  'tips-and-updates-outlined': WenzLucideToolbarIcons.callout,
  'undo': WenzLucideToolbarIcons.undo,
  'view-column-outlined': WenzLucideToolbarIcons.tableColumnInsert,
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
