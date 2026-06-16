import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show
        cupertinoDesktopTextSelectionHandleControls,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MindMapTextField extends StatefulWidget {
  const MindMapTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.style,
    this.strutStyle,
    this.cursorColor,
    this.cursorHeight,
    this.contentPadding = EdgeInsets.zero,
    this.textAlign = TextAlign.center,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled,
    this.readOnly = false,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final Color? cursorColor;
  final double? cursorHeight;
  final EdgeInsetsGeometry contentPadding;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool? enabled;
  final bool readOnly;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;

  @override
  State<MindMapTextField> createState() => _MindMapTextFieldState();
}

class _MindMapTextFieldState extends State<MindMapTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();
  final UndoHistoryController _undoController = UndoHistoryController();
  late final TextSelectionGestureDetectorBuilder
  _selectionGestureDetectorBuilder;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder = TextSelectionGestureDetectorBuilder(
      delegate: this,
    );
  }

  @override
  void dispose() {
    _undoController.dispose();
    super.dispose();
  }

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled != false;

  static const Map<ShortcutActivator, Intent> _undoRedoShortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoTextIntent(
          SelectionChangedCause.keyboard,
        ),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            RedoTextIntent(SelectionChangedCause.keyboard),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoTextIntent(
          SelectionChangedCause.keyboard,
        ),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): UndoTextIntent(
          SelectionChangedCause.keyboard,
        ),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            RedoTextIntent(SelectionChangedCause.keyboard),
      };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    final style = widget.style;
    final strutStyle = widget.strutStyle;
    final cursorColor = widget.cursorColor;
    final cursorHeight = widget.cursorHeight;
    final contentPadding = widget.contentPadding;
    final textAlign = widget.textAlign;
    final keyboardType = widget.keyboardType;
    final textInputAction = widget.textInputAction;
    final textCapitalization = widget.textCapitalization;
    final autofocus = widget.autofocus;
    final enabled = widget.enabled;
    final readOnly = widget.readOnly;
    final hintText = widget.hintText;
    final onChanged = widget.onChanged;
    final onSubmitted = widget.onSubmitted;
    final onTapOutside = widget.onTapOutside;

    final editingController = controller;
    final editingFocusNode = focusNode;
    if (editingController == null || editingFocusNode == null) {
      return const SizedBox.shrink();
    }

    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(style);
    final editableStyle = effectiveStyle.color == null
        ? effectiveStyle.copyWith(color: defaultStyle.color)
        : effectiveStyle;
    final direction = Directionality.of(context);
    final resolvedPadding = contentPadding.resolve(direction);
    final textScaler = MediaQuery.textScalerOf(context);
    final platform = Theme.of(context).platform;
    final selectionControls = _selectionControlsForPlatform(platform);
    final showSelectionHandles = _showSelectionHandlesForPlatform(platform);
    final selectionColor =
        DefaultSelectionStyle.of(context).selectionColor ??
        Theme.of(context).textSelectionTheme.selectionColor ??
        (cursorColor ?? editableStyle.color ?? Colors.blue).withValues(
          alpha: 0.32,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _measureText(
          text: editingController.text,
          hintText: hintText,
          textAlign: textAlign,
          textDirection: direction,
          style: editableStyle,
          strutStyle: strutStyle,
          textScaler: textScaler,
          maxWidth: constraints.hasBoundedWidth
              ? (constraints.maxWidth - resolvedPadding.horizontal)
                    .clamp(0.0, double.infinity)
                    .toDouble()
              : double.infinity,
        );
        final effectiveCursorHeight = cursorHeight ?? metrics.lineHeight;
        final boxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : metrics.lineHeight;

        return Shortcuts(
          shortcuts: _undoRedoShortcuts,
          child: IgnorePointer(
            ignoring: enabled == false,
            child: ClipRect(
              child: SizedBox(
                height: boxHeight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: resolvedPadding.left,
                    right: resolvedPadding.right,
                  ),
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final lineWidth = innerConstraints.hasBoundedWidth
                          ? innerConstraints.maxWidth
                          : constraints.maxWidth;
                      final child = Stack(
                        alignment: Alignment.center,
                        children: [
                          if (hintText != null &&
                              hintText.isNotEmpty &&
                              editingController.text.isEmpty)
                            SizedBox(
                              width: lineWidth,
                              height: metrics.lineHeight,
                              child: IgnorePointer(
                                child: Text(
                                  hintText,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  textAlign: textAlign,
                                  textScaler: textScaler,
                                  strutStyle: strutStyle,
                                  style: editableStyle.copyWith(
                                    color: editableStyle.color?.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(
                            width: lineWidth,
                            height: metrics.lineHeight,
                            child: EditableText(
                              key: editableTextKey,
                              controller: editingController,
                              focusNode: editingFocusNode,
                              undoController: _undoController,
                              readOnly: readOnly || enabled == false,
                              style: editableStyle,
                              strutStyle: strutStyle,
                              cursorColor:
                                  cursorColor ??
                                  editableStyle.color ??
                                  Colors.black,
                              backgroundCursorColor: Colors.grey,
                              textAlign: textAlign,
                              textDirection: direction,
                              textScaler: textScaler,
                              maxLines: 1,
                              minLines: 1,
                              autofocus: autofocus,
                              enableInteractiveSelection: true,
                              selectionControls: selectionControls,
                              showSelectionHandles: showSelectionHandles,
                              rendererIgnoresPointer: true,
                              mouseCursor: MouseCursor.defer,
                              keyboardType: keyboardType,
                              textInputAction: textInputAction,
                              textCapitalization: textCapitalization,
                              cursorHeight: effectiveCursorHeight,
                              selectionColor: selectionColor,
                              onChanged: onChanged,
                              onSubmitted: onSubmitted,
                              onTapOutside: onTapOutside,
                            ),
                          ),
                        ],
                      );
                      return MouseRegion(
                        cursor: SystemMouseCursors.text,
                        child: _selectionGestureDetectorBuilder
                            .buildGestureDetector(
                              behavior: HitTestBehavior.translucent,
                              child: child,
                            ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static _TextMetrics _measureText({
    required String? text,
    required String? hintText,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextStyle style,
    required StrutStyle? strutStyle,
    required TextScaler textScaler,
    required double maxWidth,
  }) {
    final measuredText = text == null || text.isEmpty
        ? (hintText == null || hintText.isEmpty ? ' ' : hintText)
        : text;
    final painter = TextPainter(
      text: TextSpan(text: measuredText, style: style),
      textAlign: textAlign,
      maxLines: 1,
      textDirection: textDirection,
      strutStyle: strutStyle,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final lineMetrics = painter.computeLineMetrics();
    if (lineMetrics.isNotEmpty) {
      final line = lineMetrics.first;
      return _TextMetrics(lineHeight: line.height);
    }

    return _TextMetrics(lineHeight: painter.preferredLineHeight);
  }

  static TextSelectionControls _selectionControlsForPlatform(
    TargetPlatform platform,
  ) {
    return switch (platform) {
      TargetPlatform.iOS => cupertinoTextSelectionHandleControls,
      TargetPlatform.macOS => cupertinoDesktopTextSelectionHandleControls,
      TargetPlatform.android ||
      TargetPlatform.fuchsia => materialTextSelectionHandleControls,
      TargetPlatform.linux ||
      TargetPlatform.windows => desktopTextSelectionHandleControls,
    };
  }

  static bool _showSelectionHandlesForPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => false,
    };
  }
}

class _TextMetrics {
  const _TextMetrics({required this.lineHeight});

  final double lineHeight;
}

class MindMapTextInputFrame extends StatelessWidget {
  const MindMapTextInputFrame({
    super.key,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    this.boxShadow,
    this.child,
  });

  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: CustomPaint(
        foregroundPainter: _MindMapTextInputBorderPainter(
          color: borderColor,
          width: borderWidth,
          radius: borderRadius,
          devicePixelRatio: devicePixelRatio,
        ),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _MindMapTextInputBorderPainter extends CustomPainter {
  const _MindMapTextInputBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.devicePixelRatio,
  });

  final Color color;
  final double width;
  final double radius;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || size.isEmpty) return;

    final strokeWidth = _snapToPixel(width, devicePixelRatio);
    final inset = _snapToPixel(strokeWidth / 2, devicePixelRatio);
    final rect = Rect.fromLTRB(
      _snapToPixel(inset, devicePixelRatio),
      _snapToPixel(inset, devicePixelRatio),
      _snapToPixel(size.width - inset, devicePixelRatio),
      _snapToPixel(size.height - inset, devicePixelRatio),
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(
        _snapToPixel(
          math.max(0, radius - strokeWidth / 2).toDouble(),
          devicePixelRatio,
        ),
      ),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _MindMapTextInputBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.width != width ||
        oldDelegate.radius != radius ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }

  static double _snapToPixel(double value, double devicePixelRatio) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return value;
    return (value * devicePixelRatio).roundToDouble() / devicePixelRatio;
  }
}
