import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mindmap_node.dart';
import 'mindmap_node_data.dart';

enum MindmapBorderPattern { solid, dashed, dotted, doubleLine }

typedef MindmapNodeStyleResolver =
    MindmapResolvedNodeStyle Function(MindmapThemeNodeContext context);

typedef MindmapCustomNodeStyleResolver =
    MindmapResolvedNodeStyle Function(
      MindmapThemeNodeContext context,
      MindmapResolvedNodeStyle base,
    );

class MindmapThemeNodeContext {
  const MindmapThemeNodeContext({
    required this.id,
    required this.text,
    required this.depth,
    required this.side,
    required this.isRoot,
    required this.siblingIndex,
    required this.siblingCount,
    this.branchIndex = 0,
    this.fillColor,
    this.borderColor,
    this.fontColor,
    this.legacyColor,
    this.legacyTextColor,
    this.isSelected = false,
  });

  factory MindmapThemeNodeContext.fromNodeData(
    MindmapNodeData data, {
    required int depth,
    required int siblingIndex,
    required int siblingCount,
    int? branchIndex,
    bool isSelected = false,
  }) {
    return MindmapThemeNodeContext(
      id: data.id,
      text: data.text,
      depth: depth,
      side: data.side,
      isRoot: data.isRoot || depth == 0,
      siblingIndex: siblingIndex,
      siblingCount: siblingCount,
      branchIndex: branchIndex ?? (depth <= 1 ? siblingIndex : 0),
      fillColor: data.fillColor,
      borderColor: data.borderColor,
      fontColor: data.fontColor,
      legacyColor: data.color,
      legacyTextColor: data.textColor,
      isSelected: isSelected,
    );
  }

  factory MindmapThemeNodeContext.fromNode(
    MindmapNode node, {
    required int depth,
    required int siblingIndex,
    required int siblingCount,
    int? branchIndex,
    bool isSelected = false,
  }) {
    return MindmapThemeNodeContext(
      id: node.id,
      text: node.text,
      depth: depth,
      side: node.side,
      isRoot: depth == 0,
      siblingIndex: siblingIndex,
      siblingCount: siblingCount,
      branchIndex: branchIndex ?? (depth <= 1 ? siblingIndex : 0),
      fillColor: node.fillColor,
      borderColor: node.borderColor,
      fontColor: node.fontColor,
      legacyColor: node.color,
      legacyTextColor: node.textColor,
      isSelected: isSelected,
    );
  }

  final String id;
  final String text;
  final int depth;
  final MindmapNodeSide side;
  final bool isRoot;
  final int siblingIndex;
  final int siblingCount;
  final int branchIndex;
  final int? fillColor;
  final int? borderColor;
  final int? fontColor;
  final int? legacyColor;
  final int? legacyTextColor;
  final bool isSelected;
}

class MindmapResolvedNodeStyle {
  const MindmapResolvedNodeStyle({
    required this.fillColor,
    required this.borderColor,
    required this.textStyle,
    this.borderWidth = 1,
    this.borderRadius = 8,
    this.borderPattern = MindmapBorderPattern.solid,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.shadow = true,
  });

  /// Single source of truth for line height. Both the display [Text] and the
  /// editing [TextField] must use exactly this value (with
  /// `forceStrutHeight: true`) so the text box has identical height in both
  /// states — otherwise the caret/text drifts vertically and looks off-center
  /// at certain zoom levels.
  static const double lineHeight = 1.25;

  final Color fillColor;
  final Color borderColor;
  final TextStyle textStyle;
  final double borderWidth;
  final double borderRadius;
  final MindmapBorderPattern borderPattern;
  final EdgeInsets padding;
  final bool shadow;

  Color get textColor => textStyle.color ?? const Color(0xFF1F2937);

  MindmapResolvedNodeStyle copyWith({
    Color? fillColor,
    Color? borderColor,
    TextStyle? textStyle,
    double? borderWidth,
    double? borderRadius,
    MindmapBorderPattern? borderPattern,
    EdgeInsets? padding,
    bool? shadow,
  }) {
    return MindmapResolvedNodeStyle(
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      textStyle: textStyle ?? this.textStyle,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      borderPattern: borderPattern ?? this.borderPattern,
      padding: padding ?? this.padding,
      shadow: shadow ?? this.shadow,
    );
  }
}

class MindmapThemeDefinition {
  const MindmapThemeDefinition({
    required this.id,
    required this.label,
    required this.connectionColor,
    required this.resolve,
  });

  final String id;
  final String label;
  final Color connectionColor;
  final MindmapNodeStyleResolver resolve;
}

class MindmapThemeController extends ChangeNotifier {
  MindmapThemeController({
    MindmapThemeDefinition? theme,
    MindmapCustomNodeStyleResolver? customStyleResolver,
  }) : _theme = theme ?? MindmapThemes.defaultTheme,
       _customStyleResolver = customStyleResolver;

  MindmapThemeDefinition _theme;
  MindmapCustomNodeStyleResolver? _customStyleResolver;

  MindmapThemeDefinition get theme => _theme;
  Color get connectionColor => _theme.connectionColor;

  set theme(MindmapThemeDefinition value) {
    if (_theme.id == value.id) return;
    _theme = value;
    notifyListeners();
  }

  MindmapCustomNodeStyleResolver? get customStyleResolver =>
      _customStyleResolver;

  set customStyleResolver(MindmapCustomNodeStyleResolver? value) {
    _customStyleResolver = value;
    notifyListeners();
  }

  void useThemeId(String id) {
    theme = MindmapThemes.byId(id) ?? MindmapThemes.defaultTheme;
  }

  MindmapResolvedNodeStyle styleFor(MindmapThemeNodeContext context) {
    return styleForTheme(_theme, context);
  }

  MindmapResolvedNodeStyle styleForTheme(
    MindmapThemeDefinition theme,
    MindmapThemeNodeContext context,
  ) {
    final base = theme.resolve(context);
    final resolved = _customStyleResolver == null
        ? base
        : _customStyleResolver!(context, base);
    return _applyNodeOverrides(context, resolved);
  }

  MindmapResolvedNodeStyle _applyNodeOverrides(
    MindmapThemeNodeContext context,
    MindmapResolvedNodeStyle base,
  ) {
    final fill = context.fillColor ?? _legacyFillOverride(context);
    final border = context.borderColor;
    final font = context.fontColor ?? _legacyFontOverride(context);
    return base.copyWith(
      fillColor: fill == null ? null : Color(fill),
      borderColor: border == null ? null : Color(border),
      textStyle: font == null
          ? null
          : base.textStyle.copyWith(color: Color(font)),
    );
  }

  int? _legacyFillOverride(MindmapThemeNodeContext context) {
    final color = context.legacyColor;
    if (color == null) return null;
    if (context.isRoot && color == 0xFF2563EB) return null;
    if (!context.isRoot && color == 0xFFE3F2FD) return null;
    return color;
  }

  int? _legacyFontOverride(MindmapThemeNodeContext context) {
    final color = context.legacyTextColor;
    if (color == null) return null;
    if (context.isRoot && color == 0xFFFFFFFF) return null;
    if (!context.isRoot && color == 0xFF1F2937) return null;
    return color;
  }
}

class MindmapThemes {
  const MindmapThemes._();

  static MindmapThemeDefinition get defaultTheme => minimal;
  static String get defaultThemeId => defaultTheme.id;

  static final minimal = MindmapThemeDefinition(
    id: 'minimal',
    label: '极简白板',
    connectionColor: const Color(0xFF64748B),
    resolve: (context) {
      final isRoot = context.isRoot;
      return _baseStyle(
        context,
        fill: Colors.white,
        border: isRoot ? const Color(0xFF111827) : const Color(0xFFD7DEE8),
        text: isRoot ? const Color(0xFF111827) : const Color(0xFF233044),
        borderWidth: isRoot ? 2 : 1.5,
        borderRadius: isRoot ? 10 : 8,
        shadow: !isRoot,
      );
    },
  );

  static final sticky = MindmapThemeDefinition(
    id: 'sticky',
    label: '便利贴',
    connectionColor: const Color(0xFF9A7B2E),
    resolve: (context) {
      if (context.isRoot) {
        return _baseStyle(
          context,
          fill: const Color(0xFF243447),
          border: const Color(0xFF243447),
          text: Colors.white,
          borderWidth: 0,
          borderRadius: 8,
        );
      }
      final fills = const [
        Color(0xFFFEF3C7),
        Color(0xFFCCFBF1),
        Color(0xFFFFEDD5),
        Color(0xFFFCE7F3),
        Color(0xFFEDE9FE),
        Color(0xFFCFFAFE),
      ];
      final fill = fills[context.branchIndex % fills.length];
      return _baseStyle(
        context,
        fill: fill,
        border: const Color(0x1F5C491F),
        text: const Color(0xFF2F2A1F),
        borderWidth: 1,
        borderRadius: 4,
      );
    },
  );

  static final business = MindmapThemeDefinition(
    id: 'business',
    label: '商务卡片',
    connectionColor: const Color(0xFF94A3B8),
    resolve: (context) {
      if (context.isRoot) {
        return _baseStyle(
          context,
          fill: const Color(0xFF0F172A),
          border: const Color(0xFF334155),
          text: Colors.white,
          borderWidth: 1.5,
          borderRadius: 12,
        );
      }
      final accent = _rainbowColor(context.branchIndex);
      final fill = Color.lerp(
        accent,
        Colors.white,
        context.depth <= 1 ? 0.88 : 0.96,
      )!;
      final border = Color.lerp(
        accent,
        Colors.white,
        context.depth <= 1
            ? 0.12
            : context.depth == 2
            ? 0.35
            : 0.52,
      )!;
      return _baseStyle(
        context,
        fill: fill,
        border: border,
        text: const Color(0xFF172033),
        borderWidth: context.depth <= 1
            ? 2
            : context.depth == 2
            ? 1.4
            : 1.2,
        borderRadius: context.depth <= 1 ? 10 : 8,
        borderPattern: context.depth <= 2
            ? MindmapBorderPattern.solid
            : MindmapBorderPattern.dashed,
        shadow: context.depth <= 2,
      );
    },
  );

  static final classic = MindmapThemeDefinition(
    id: 'classic',
    label: '经典',
    connectionColor: const Color(0xFF94A3B8),
    resolve: (context) {
      final isRoot = context.isRoot;
      final fill = isRoot ? const Color(0xFF2563EB) : const Color(0xFFE3F2FD);
      final text = isRoot ? Colors.white : const Color(0xFF1F2937);
      return _baseStyle(
        context,
        fill: fill,
        border: _borderForFill(fill),
        text: text,
        borderRadius: isRoot ? 24 : 8,
      );
    },
  );

  static final rainbow = MindmapThemeDefinition(
    id: 'rainbow',
    label: '彩虹',
    connectionColor: const Color(0xFF7C8AA5),
    resolve: (context) {
      if (context.isRoot) {
        return _baseStyle(
          context,
          fill: const Color(0xFF1D4ED8),
          border: const Color(0xFF1E3A8A),
          text: Colors.white,
          borderRadius: 24,
          borderWidth: 2,
        );
      }
      final anchorIndex = context.depth == 1
          ? context.siblingIndex
          : context.siblingIndex + context.depth;
      final color = _rainbowColor(anchorIndex);
      final fill = _tint(color, context.depth <= 1 ? 0.88 : 0.94);
      return _baseStyle(
        context,
        fill: fill,
        border: color,
        text: const Color(0xFF172033),
        borderWidth: context.depth == 1 ? 2 : 1.4,
        borderPattern: context.depth <= 2
            ? MindmapBorderPattern.solid
            : MindmapBorderPattern.dashed,
      );
    },
  );

  static final ink = MindmapThemeDefinition(
    id: 'ink',
    label: '墨线',
    connectionColor: const Color(0xFF4B5563),
    resolve: (context) {
      final isRoot = context.isRoot;
      return _baseStyle(
        context,
        fill: isRoot ? const Color(0xFF111827) : const Color(0xFFFFFBEB),
        border: isRoot ? const Color(0xFF111827) : const Color(0xFF92400E),
        text: isRoot ? Colors.white : const Color(0xFF2F2218),
        borderWidth: isRoot ? 2 : 1.6,
        borderRadius: isRoot ? 20 : 6,
        borderPattern: context.depth >= 2
            ? MindmapBorderPattern.dashed
            : MindmapBorderPattern.solid,
        shadow: false,
      );
    },
  );

  static final neon = MindmapThemeDefinition(
    id: 'neon',
    label: '暗色霓虹',
    connectionColor: const Color(0xFF38BDF8),
    resolve: (context) {
      if (context.isRoot) {
        return _baseStyle(
          context,
          fill: const Color(0xFF6D28D9),
          border: const Color(0xFF06B6D4),
          text: Colors.white,
          borderWidth: 1.5,
          borderRadius: 24,
        );
      }
      final color = _neonColor(context.siblingIndex + context.depth);
      return _baseStyle(
        context,
        fill: const Color(0xFF101827),
        border: color,
        text: const Color(0xFFE5F6FF),
        borderWidth: 1.6,
        borderRadius: 16,
      );
    },
  );

  static List<MindmapThemeDefinition> get presets => [
    minimal,
    sticky,
    business,
    neon,
  ];

  static List<MindmapThemeDefinition> get all => [
    ...presets,
    classic,
    rainbow,
    ink,
  ];

  static MindmapThemeDefinition? byId(String id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  static MindmapResolvedNodeStyle _baseStyle(
    MindmapThemeNodeContext context, {
    required Color fill,
    required Color border,
    required Color text,
    double? borderWidth,
    double? borderRadius,
    MindmapBorderPattern borderPattern = MindmapBorderPattern.solid,
    bool shadow = true,
  }) {
    final isRoot = context.isRoot;
    return MindmapResolvedNodeStyle(
      fillColor: fill,
      borderColor: border,
      borderWidth: borderWidth ?? (isRoot ? 2 : 1),
      borderRadius: borderRadius ?? (isRoot ? 24 : 8),
      borderPattern: borderPattern,
      padding: EdgeInsets.symmetric(
        horizontal: isRoot ? 16 : 12,
        vertical: isRoot ? 10 : 6,
      ),
      shadow: shadow,
      textStyle: TextStyle(
        color: text,
        fontSize: isRoot ? 16 : 14,
        fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
        height: MindmapResolvedNodeStyle.lineHeight,
      ),
    );
  }

  static Color _rainbowColor(int index) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEF4444),
    ];
    return colors[index % colors.length];
  }

  static Color _neonColor(int index) {
    const colors = [
      Color(0xFF22D3EE),
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
      Color(0xFFA78BFA),
      Color(0xFF67E8F9),
    ];
    return colors[index % colors.length];
  }

  static Color _tint(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0).toDouble())
        .withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  static Color _borderForFill(Color fill) {
    return fill.computeLuminance() > 0.72 ? const Color(0xFFD1D5DB) : fill;
  }
}

class MindmapNodeFrame extends StatelessWidget {
  const MindmapNodeFrame({
    super.key,
    required this.style,
    this.fillColor,
    this.borderColor,
    this.borderWidth,
    this.highlighted = false,
    this.highlightColor = const Color(0xFF2563EB),
    this.child,
  });

  final MindmapResolvedNodeStyle style;
  final Color? fillColor;
  final Color? borderColor;
  final double? borderWidth;
  final bool highlighted;
  final Color highlightColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = highlighted
        ? highlightColor
        : borderColor ?? style.borderColor;
    final effectiveBorderWidth = highlighted
        ? math.max(2, style.borderWidth).toDouble()
        : borderWidth ?? style.borderWidth;
    final shadows = style.shadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor ?? style.fillColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
        boxShadow: shadows,
      ),
      child: CustomPaint(
        foregroundPainter: _MindmapBorderPainter(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
          radius: style.borderRadius,
          pattern: highlighted
              ? MindmapBorderPattern.solid
              : style.borderPattern,
        ),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _MindmapBorderPainter extends CustomPainter {
  const _MindmapBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.pattern,
  });

  final Color color;
  final double width;
  final double radius;
  final MindmapBorderPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || (color.a * 255.0).round().clamp(0, 255).toInt() == 0) {
      return;
    }
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(width / 2),
      Radius.circular(math.max(0, radius - width / 2).toDouble()),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    switch (pattern) {
      case MindmapBorderPattern.solid:
        canvas.drawRRect(rrect, paint);
      case MindmapBorderPattern.doubleLine:
        canvas.drawRRect(rrect, paint);
        final inner = rect.deflate(width * 3);
        if (inner.width > 0 && inner.height > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              inner,
              Radius.circular(math.max(0, radius - width * 3)),
            ),
            paint..strokeWidth = math.max(1, width * 0.75),
          );
        }
      case MindmapBorderPattern.dashed:
        _drawDashedPath(canvas, Path()..addRRect(rrect), paint, 8, 5);
      case MindmapBorderPattern.dotted:
        _drawDashedPath(canvas, Path()..addRRect(rrect), paint, 1, 5);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashLength,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = (metric.length - distance).clamp(0.0, dashLength);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MindmapBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.width != width ||
        oldDelegate.radius != radius ||
        oldDelegate.pattern != pattern;
  }
}
