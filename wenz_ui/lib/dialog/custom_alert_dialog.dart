import 'package:flutter/material.dart';

import 'dart:ui' show clampDouble, lerpDouble;

const EdgeInsets _defaultInsetPadding =
    EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0);

class CustomAlertDialog extends StatelessWidget {
  const CustomAlertDialog({
    super.key,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding,
    this.actionsAlignment,
    this.actionsOverflowAlignment,
    this.actionsOverflowDirection,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.insetPadding = _defaultInsetPadding,
    this.clipBehavior = Clip.none,
    this.shape,
    this.alignment,
    this.scrollable = false,
  });

  final Widget? icon;

  final Color? iconColor;

  final EdgeInsetsGeometry? iconPadding;

  final Widget? title;

  final EdgeInsetsGeometry? titlePadding;

  final TextStyle? titleTextStyle;

  final Widget? content;

  final EdgeInsetsGeometry? contentPadding;

  final TextStyle? contentTextStyle;

  final List<Widget>? actions;

  final EdgeInsetsGeometry? actionsPadding;

  final MainAxisAlignment? actionsAlignment;

  final OverflowBarAlignment? actionsOverflowAlignment;

  final VerticalDirection? actionsOverflowDirection;

  final double? actionsOverflowButtonSpacing;

  final EdgeInsetsGeometry? buttonPadding;

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final String? semanticLabel;

  final EdgeInsets insetPadding;

  final Clip clipBehavior;

  final ShapeBorder? shape;

  final AlignmentGeometry? alignment;

  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final ThemeData theme = Theme.of(context);

    final dialogTheme = DialogTheme.of(context);
    final defaults = theme.useMaterial3
        ? _DialogDefaultsM3(context)
        : _DialogDefaultsM2(context);

    String? label = semanticLabel;
    switch (theme.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        label ??= MaterialLocalizations.of(context).alertDialogLabel;
    }

    final double paddingScaleFactor =
        _paddingScaleFactor(MediaQuery.textScalerOf(context).textScaleFactor);
    final TextDirection? textDirection = Directionality.maybeOf(context);

    Widget? iconWidget;
    Widget? titleWidget;
    Widget? contentWidget;
    Widget? actionsWidget;

    if (icon != null) {
      final bool belowIsTitle = title != null;
      final bool belowIsContent = !belowIsTitle && content != null;
      final EdgeInsets defaultIconPadding = EdgeInsets.only(
        left: 24.0,
        top: 24.0,
        right: 24.0,
        bottom: belowIsTitle
            ? 16.0
            : belowIsContent
                ? 0.0
                : 24.0,
      );
      final EdgeInsets effectiveIconPadding =
          iconPadding?.resolve(textDirection) ?? defaultIconPadding;
      iconWidget = Padding(
        padding: EdgeInsets.only(
          left: effectiveIconPadding.left * paddingScaleFactor,
          right: effectiveIconPadding.right * paddingScaleFactor,
          top: effectiveIconPadding.top * paddingScaleFactor,
          bottom: effectiveIconPadding.bottom,
        ),
        child: IconTheme(
          data: IconThemeData(
            color: iconColor ?? dialogTheme.iconColor ?? defaults.iconColor,
          ),
          child: icon!,
        ),
      );
    }

    if (title != null) {
      final EdgeInsets defaultTitlePadding = EdgeInsets.only(
        left: 24.0,
        top: icon == null ? 24.0 : 0.0,
        right: 24.0,
        bottom: content == null ? 20.0 : 0.0,
      );
      final EdgeInsets effectiveTitlePadding =
          titlePadding?.resolve(textDirection) ?? defaultTitlePadding;
      titleWidget = Padding(
        padding: EdgeInsets.only(
          left: effectiveTitlePadding.left * paddingScaleFactor,
          right: effectiveTitlePadding.right * paddingScaleFactor,
          top: icon == null
              ? effectiveTitlePadding.top * paddingScaleFactor
              : effectiveTitlePadding.top,
          bottom: effectiveTitlePadding.bottom,
        ),
        child: DefaultTextStyle(
          style: titleTextStyle ??
              dialogTheme.titleTextStyle ??
              defaults.titleTextStyle!,
          textAlign: icon == null ? TextAlign.start : TextAlign.center,
          child: Semantics(
            namesRoute: label == null && theme.platform != TargetPlatform.iOS,
            container: true,
            child: title,
          ),
        ),
      );
    }

    if (content != null) {
      final EdgeInsets defaultContentPadding = EdgeInsets.only(
        left: 24.0,
        top: theme.useMaterial3 ? 16.0 : 20.0,
        right: 24.0,
        bottom: 24.0,
      );
      final EdgeInsets effectiveContentPadding =
          contentPadding?.resolve(textDirection) ?? defaultContentPadding;
      contentWidget = Padding(
        padding: EdgeInsets.only(
          left: effectiveContentPadding.left * paddingScaleFactor,
          right: effectiveContentPadding.right * paddingScaleFactor,
          top: title == null && icon == null
              ? effectiveContentPadding.top * paddingScaleFactor
              : effectiveContentPadding.top,
          bottom: effectiveContentPadding.bottom,
        ),
        child: DefaultTextStyle(
          style: contentTextStyle ??
              dialogTheme.contentTextStyle ??
              defaults.contentTextStyle!,
          child: Semantics(
            container: true,
            child: content,
          ),
        ),
      );
    }

    if (actions != null) {
      final double spacing = (buttonPadding?.horizontal ?? 16) / 2;
      actionsWidget = Padding(
        padding: actionsPadding ??
            dialogTheme.actionsPadding ??
            (theme.useMaterial3
                ? defaults.actionsPadding!
                : defaults.actionsPadding!.add(EdgeInsets.all(spacing))),
        child: OverflowBar(
          alignment: actionsAlignment ?? MainAxisAlignment.end,
          spacing: spacing,
          overflowAlignment:
              actionsOverflowAlignment ?? OverflowBarAlignment.end,
          overflowDirection: actionsOverflowDirection ?? VerticalDirection.down,
          overflowSpacing: actionsOverflowButtonSpacing ?? 0,
          children: actions!,
        ),
      );
    }

    List<Widget> columnChildren;
    if (scrollable) {
      columnChildren = <Widget>[
        if (title != null || content != null)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (icon != null) iconWidget!,
                  if (title != null) titleWidget!,
                  if (content != null) contentWidget!,
                ],
              ),
            ),
          ),
        if (actions != null) actionsWidget!,
      ];
    } else {
      columnChildren = <Widget>[
        if (icon != null) iconWidget!,
        if (title != null) titleWidget!,
        if (content != null) Flexible(child: contentWidget!),
        if (actions != null) actionsWidget!,
      ];
    }

    Widget dialogChild = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: columnChildren,
      ),
    );

    if (label != null) {
      dialogChild = Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: label,
        child: dialogChild,
      );
    }

    return Dialog(
      backgroundColor: backgroundColor,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      insetPadding: insetPadding,
      clipBehavior: clipBehavior,
      shape: shape,
      alignment: alignment,
      child: dialogChild,
    );
  }
}

class Dialog extends StatelessWidget {
  /// Creates a dialog.
  ///
  /// Typically used in conjunction with [showDialog].
  const Dialog({
    super.key,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.insetAnimationDuration = const Duration(milliseconds: 100),
    this.insetAnimationCurve = Curves.decelerate,
    this.insetPadding = _defaultInsetPadding,
    this.clipBehavior = Clip.none,
    this.shape,
    this.alignment,
    this.child,
  })  : assert(elevation == null || elevation >= 0.0),
        _fullscreen = false;

  /// Creates a fullscreen dialog.
  ///
  /// Typically used in conjunction with [showDialog].
  const Dialog.fullscreen({
    super.key,
    this.backgroundColor,
    this.insetAnimationDuration = Duration.zero,
    this.insetAnimationCurve = Curves.decelerate,
    this.child,
  })  : elevation = 0,
        shadowColor = null,
        surfaceTintColor = null,
        insetPadding = EdgeInsets.zero,
        clipBehavior = Clip.none,
        shape = null,
        alignment = null,
        _fullscreen = true;

  /// {@template flutter.material.dialog.backgroundColor}
  /// The background color of the surface of this [Dialog].
  ///
  /// This sets the [Material.color] on this [Dialog]'s [Material].
  ///
  /// If `null`, [ThemeData.dialogBackgroundColor] is used.
  /// {@endtemplate}
  final Color? backgroundColor;

  /// {@template flutter.material.dialog.elevation}
  /// The z-coordinate of this [Dialog].
  ///
  /// Controls how far above the parent the dialog will appear. Elevation is
  /// represented by a drop shadow if [shadowColor] is non null,
  /// and a surface tint overlay on the background color if [surfaceTintColor] is
  /// non null.
  ///
  /// If null then [DialogTheme.elevation] is used, and if that is null then
  /// the elevation will match the Material Design specification for Dialogs.
  ///
  /// See also:
  ///   * [Material.elevation], which describes how [elevation] effects the
  ///     drop shadow or surface tint overlay.
  ///   * [shadowColor], color of the drop shadow used to indicate the elevation.
  ///   * [surfaceTintColor], color of an overlay on top of the background
  ///     color used to indicate the elevation.
  ///   * <https://m3.material.io/components/dialogs/overview>, the Material
  ///     Design specification for dialogs.
  /// {@endtemplate}
  final double? elevation;

  /// {@template flutter.material.dialog.shadowColor}
  /// The color used to paint a drop shadow under the dialog's [Material],
  /// which reflects the dialog's [elevation].
  ///
  /// If null and [ThemeData.useMaterial3] is true then no drop shadow will
  /// be rendered.
  ///
  /// If null and [ThemeData.useMaterial3] is false then it will default to
  /// [ThemeData.shadowColor].
  ///
  /// See also:
  ///   * [Material.shadowColor], which describes how the drop shadow is painted.
  ///   * [elevation], which affects how the drop shadow is painted.
  ///   * [surfaceTintColor], which can be used to indicate elevation through
  ///     tinting the background color.
  /// {@endtemplate}
  final Color? shadowColor;

  /// {@template flutter.material.dialog.surfaceTintColor}
  /// The color used as a surface tint overlay on the dialog's background color,
  /// which reflects the dialog's [elevation].
  ///
  /// If [ThemeData.useMaterial3] is false property has no effect.
  ///
  /// If null and [ThemeData.useMaterial3] is true then [ThemeData]'s
  /// [ColorScheme.surfaceTint] will be used.
  ///
  /// To disable this feature, set [surfaceTintColor] to [Colors.transparent].
  ///
  /// See also:
  ///   * [Material.surfaceTintColor], which describes how the surface tint will
  ///     be applied to the background color of the dialog.
  ///   * [elevation], which affects the opacity of the surface tint.
  ///   * [shadowColor], which can be used to indicate elevation through
  ///     a drop shadow.
  /// {@endtemplate}
  final Color? surfaceTintColor;

  /// {@template flutter.material.dialog.insetAnimationDuration}
  /// The duration of the animation to show when the system keyboard intrudes
  /// into the space that the dialog is placed in.
  ///
  /// Defaults to 100 milliseconds when [Dialog] is used, and [Duration.zero]
  /// when [Dialog.fullscreen] is used.
  /// {@endtemplate}
  final Duration insetAnimationDuration;

  /// {@template flutter.material.dialog.insetAnimationCurve}
  /// The curve to use for the animation shown when the system keyboard intrudes
  /// into the space that the dialog is placed in.
  ///
  /// Defaults to [Curves.decelerate].
  /// {@endtemplate}
  final Curve insetAnimationCurve;

  /// {@template flutter.material.dialog.insetPadding}
  /// The amount of padding added to [MediaQueryData.viewInsets] on the outside
  /// of the dialog. This defines the minimum space between the screen's edges
  /// and the dialog.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0)`.
  /// {@endtemplate}
  final EdgeInsets? insetPadding;

  /// {@template flutter.material.dialog.clipBehavior}
  /// Controls how the contents of the dialog are clipped (or not) to the given
  /// [shape].
  ///
  /// See the enum [Clip] for details of all possible options and their common
  /// use cases.
  ///
  /// Defaults to [Clip.none].
  /// {@endtemplate}
  final Clip clipBehavior;

  /// {@template flutter.material.dialog.shape}
  /// The shape of this dialog's border.
  ///
  /// Defines the dialog's [Material.shape].
  ///
  /// The default shape is a [RoundedRectangleBorder] with a radius of 4.0
  /// {@endtemplate}
  final ShapeBorder? shape;

  /// {@template flutter.material.dialog.alignment}
  /// How to align the [Dialog].
  ///
  /// If null, then [DialogTheme.alignment] is used. If that is also null, the
  /// default is [Alignment.center].
  /// {@endtemplate}
  final AlignmentGeometry? alignment;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// This value is used to determine if this is a fullscreen dialog.
  final bool _fullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);
    final effectivePadding =
        MediaQuery.viewInsetsOf(context) + (insetPadding ?? EdgeInsets.zero);
    final DialogTheme defaults = theme.useMaterial3
        ? _DialogDefaultsM3(context)
        : _DialogDefaultsM2(context);

    Widget dialogChild;

    if (_fullscreen) {
      dialogChild = Material(
        color: backgroundColor ??
            dialogTheme.backgroundColor ??
            defaults.backgroundColor,
        child: child,
      );
    } else {
      dialogChild = Align(
        alignment: alignment ?? dialogTheme.alignment ?? defaults.alignment!,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280.0),
          child: Material(
            color: backgroundColor ??
                dialogTheme.backgroundColor ??
                Theme.of(context).dialogBackgroundColor,
            elevation:
                elevation ?? dialogTheme.elevation ?? defaults.elevation!,
            shadowColor:
                shadowColor ?? dialogTheme.shadowColor ?? defaults.shadowColor,
            surfaceTintColor: surfaceTintColor ??
                dialogTheme.surfaceTintColor ??
                defaults.surfaceTintColor,
            shape: shape ?? dialogTheme.shape ?? defaults.shape!,
            type: MaterialType.card,
            clipBehavior: clipBehavior,
            child: child,
          ),
        ),
      );
    }

    return AnimatedPadding(
      padding: effectivePadding,
      duration: insetAnimationDuration,
      curve: insetAnimationCurve,
      child: MediaQuery.removeViewInsets(
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        context: context,
        child: dialogChild,
      ),
    );
  }
}

class _AdaptiveAlertDialog extends CustomAlertDialog {
  const _AdaptiveAlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing,
    super.buttonPadding,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding = _defaultInsetPadding,
    super.clipBehavior = Clip.none,
    super.shape,
    super.alignment,
    super.scrollable = false,
    this.scrollController,
    this.actionScrollController,
    this.insetAnimationDuration = const Duration(milliseconds: 100),
    this.insetAnimationCurve = Curves.decelerate,
  });

  final ScrollController? scrollController;
  final ScrollController? actionScrollController;
  final Duration insetAnimationDuration;
  final Curve insetAnimationCurve;

  @override
  Widget build(BuildContext context) {
    return super.build(context);
  }
}

class SimpleDialogOption extends StatelessWidget {
  const SimpleDialogOption({
    super.key,
    this.onPressed,
    this.padding,
    this.child,
  });

  final VoidCallback? onPressed;

  final Widget? child;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: padding ??
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        child: child,
      ),
    );
  }
}

double _paddingScaleFactor(double textScaleFactor) {
  final double clampedTextScaleFactor = clampDouble(textScaleFactor, 1.0, 2.0);
  return lerpDouble(1.0, 1.0 / 3.0, clampedTextScaleFactor - 1.0)!;
}

class _DialogDefaultsM2 extends DialogTheme {
  _DialogDefaultsM2(this.context)
      : _textTheme = Theme.of(context).textTheme,
        _iconTheme = Theme.of(context).iconTheme,
        super(
          alignment: Alignment.center,
          elevation: 24.0,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0))),
        );

  final BuildContext context;
  final TextTheme _textTheme;
  final IconThemeData _iconTheme;

  @override
  Color? get iconColor => _iconTheme.color;

  @override
  Color? get backgroundColor => Theme.of(context).dialogBackgroundColor;

  @override
  Color? get shadowColor => Theme.of(context).shadowColor;

  @override
  TextStyle? get titleTextStyle => _textTheme.titleLarge;

  @override
  TextStyle? get contentTextStyle => _textTheme.titleMedium;

  @override
  EdgeInsetsGeometry? get actionsPadding => EdgeInsets.zero;
}

class _DialogDefaultsM3 extends DialogTheme {
  _DialogDefaultsM3(this.context)
      : super(
          alignment: Alignment.center,
          elevation: 6.0,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0))),
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get iconColor => _colors.secondary;

  @override
  Color? get backgroundColor => _colors.surface;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  TextStyle? get titleTextStyle => _textTheme.headlineSmall;

  @override
  TextStyle? get contentTextStyle => _textTheme.bodyMedium;

  @override
  EdgeInsetsGeometry? get actionsPadding =>
      const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0);
}
