import 'package:flutter/material.dart';

/// Visual tokens used by the built-in chat renderer.
@immutable
class WenzChatThemeData {
  const WenzChatThemeData({
    required this.backgroundColor,
    required this.incomingBubbleColor,
    required this.outgoingBubbleColor,
    required this.systemBubbleColor,
    required this.incomingTextStyle,
    required this.outgoingTextStyle,
    required this.systemTextStyle,
    required this.authorTextStyle,
    required this.timestampTextStyle,
    required this.dateSeparatorTextStyle,
    required this.failedColor,
    required this.avatarBackgroundColor,
    required this.avatarForegroundColor,
    this.bubbleRadius = 18,
    this.groupedCornerRadius = 6,
    this.horizontalPadding = 12,
    this.verticalPadding = 8,
    this.messageSpacing = 3,
    this.groupSpacing = 10,
    this.maxBubbleWidthFactor = 0.76,
    this.avatarRadius = 16,
    this.avatarGap = 8,
  });

  /// Builds sensible chat colors from the host Material theme.
  factory WenzChatThemeData.fromTheme(ThemeData theme) {
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    return WenzChatThemeData(
      backgroundColor: colors.surface,
      incomingBubbleColor: colors.surfaceContainerHighest,
      outgoingBubbleColor: colors.primary,
      systemBubbleColor: colors.surfaceContainerHigh,
      incomingTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: colors.onSurface,
        height: 1.35,
      ),
      outgoingTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: colors.onPrimary,
        height: 1.35,
      ),
      systemTextStyle: (textTheme.bodySmall ?? const TextStyle()).copyWith(
        color: colors.onSurfaceVariant,
      ),
      authorTextStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w600,
      ),
      timestampTextStyle: (textTheme.labelSmall ?? const TextStyle()).copyWith(
        color: colors.onSurfaceVariant.withValues(alpha: 0.78),
        fontSize: 10,
      ),
      dateSeparatorTextStyle: (textTheme.labelSmall ?? const TextStyle())
          .copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
      failedColor: colors.error,
      avatarBackgroundColor: colors.secondaryContainer,
      avatarForegroundColor: colors.onSecondaryContainer,
    );
  }

  final Color backgroundColor;
  final Color incomingBubbleColor;
  final Color outgoingBubbleColor;
  final Color systemBubbleColor;
  final TextStyle incomingTextStyle;
  final TextStyle outgoingTextStyle;
  final TextStyle systemTextStyle;
  final TextStyle authorTextStyle;
  final TextStyle timestampTextStyle;
  final TextStyle dateSeparatorTextStyle;
  final Color failedColor;
  final Color avatarBackgroundColor;
  final Color avatarForegroundColor;

  final double bubbleRadius;
  final double groupedCornerRadius;
  final double horizontalPadding;
  final double verticalPadding;
  final double messageSpacing;
  final double groupSpacing;
  final double maxBubbleWidthFactor;
  final double avatarRadius;
  final double avatarGap;

  WenzChatThemeData copyWith({
    Color? backgroundColor,
    Color? incomingBubbleColor,
    Color? outgoingBubbleColor,
    Color? systemBubbleColor,
    TextStyle? incomingTextStyle,
    TextStyle? outgoingTextStyle,
    TextStyle? systemTextStyle,
    TextStyle? authorTextStyle,
    TextStyle? timestampTextStyle,
    TextStyle? dateSeparatorTextStyle,
    Color? failedColor,
    Color? avatarBackgroundColor,
    Color? avatarForegroundColor,
    double? bubbleRadius,
    double? groupedCornerRadius,
    double? horizontalPadding,
    double? verticalPadding,
    double? messageSpacing,
    double? groupSpacing,
    double? maxBubbleWidthFactor,
    double? avatarRadius,
    double? avatarGap,
  }) {
    return WenzChatThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      incomingBubbleColor: incomingBubbleColor ?? this.incomingBubbleColor,
      outgoingBubbleColor: outgoingBubbleColor ?? this.outgoingBubbleColor,
      systemBubbleColor: systemBubbleColor ?? this.systemBubbleColor,
      incomingTextStyle: incomingTextStyle ?? this.incomingTextStyle,
      outgoingTextStyle: outgoingTextStyle ?? this.outgoingTextStyle,
      systemTextStyle: systemTextStyle ?? this.systemTextStyle,
      authorTextStyle: authorTextStyle ?? this.authorTextStyle,
      timestampTextStyle: timestampTextStyle ?? this.timestampTextStyle,
      dateSeparatorTextStyle:
          dateSeparatorTextStyle ?? this.dateSeparatorTextStyle,
      failedColor: failedColor ?? this.failedColor,
      avatarBackgroundColor:
          avatarBackgroundColor ?? this.avatarBackgroundColor,
      avatarForegroundColor:
          avatarForegroundColor ?? this.avatarForegroundColor,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      groupedCornerRadius: groupedCornerRadius ?? this.groupedCornerRadius,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      messageSpacing: messageSpacing ?? this.messageSpacing,
      groupSpacing: groupSpacing ?? this.groupSpacing,
      maxBubbleWidthFactor: maxBubbleWidthFactor ?? this.maxBubbleWidthFactor,
      avatarRadius: avatarRadius ?? this.avatarRadius,
      avatarGap: avatarGap ?? this.avatarGap,
    );
  }
}

/// Provides [WenzChatThemeData] to descendant chat views.
class WenzChatTheme extends InheritedTheme {
  const WenzChatTheme({required this.data, required super.child, super.key});

  final WenzChatThemeData data;

  static WenzChatThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WenzChatTheme>()?.data;
  }

  static WenzChatThemeData of(BuildContext context) {
    return maybeOf(context) ?? WenzChatThemeData.fromTheme(Theme.of(context));
  }

  @override
  bool updateShouldNotify(WenzChatTheme oldWidget) => data != oldWidget.data;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return WenzChatTheme(data: data, child: child);
  }
}
