import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef CheckItemBuilder = Widget Function(
    BuildContext context, bool checked, bool hover, bool pressed);
typedef ItemVoidCallback = void Function(BuildContext context);
typedef EventCallback = void Function(
    BuildContext context, TapDownDetails details);
typedef LongPressCallback = void Function(
    BuildContext context, LongPressDownDetails details);

class ToggleItem extends StatefulWidget {
  final bool checked;
  final CheckItemBuilder itemBuilder;
  final ValueChanged<bool?>? onChanged;
  final ItemVoidCallback? onTap;
  final ItemVoidCallback? onTapDown;
  final LongPressCallback? onLongPress;
  final EventCallback? onSecondaryTap;
  final ItemVoidCallback? onHoverEnter;
  final ItemVoidCallback? onHoverExit;
  final MouseCursor cursor;

  const ToggleItem({
    super.key,
    this.checked = false,
    required this.itemBuilder,
    this.onChanged,
    this.onTap,
    this.onTapDown,
    this.onLongPress,
    this.onHoverEnter,
    this.onHoverExit,
    this.onSecondaryTap,
    this.cursor = MaterialStateMouseCursor.clickable,
  });

  @override
  State<ToggleItem> createState() => _ToggleItemState();
}

class _ToggleItemState extends State<ToggleItem> {
  bool checked = false;
  bool hover = false;
  bool pressed = false;
  LongPressDownDetails? longPressDownDetails;

  @override
  void initState() {
    super.initState();
    checked = widget.checked;
  }

  @override
  void didUpdateWidget(covariant ToggleItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    checked = widget.checked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        widget.onTapDown?.call(context);
        setState(() {
          pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },
      onTapUp: (e) {
        setState(() {
          pressed = false;
        });
      },
      onTap: () {
        checked = !checked;
        widget.onChanged?.call(checked);
        widget.onTap?.call(context);
        setState(() {});
      },
      onSecondaryTapDown: widget.onSecondaryTap == null
          ? null
          : (details) {
              widget.onSecondaryTap?.call(context, details);
            },
      onLongPressDown: widget.onLongPress == null
          ? null
          : (details) {
              longPressDownDetails = details;
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              widget.onLongPress?.call(context, longPressDownDetails!);
            },
      child: MouseRegion(
          cursor: widget.cursor,
          onEnter: (e) {
            if (hover == true) {
              return;
            }
            setState(() {
              hover = true;
              widget.onHoverEnter?.call(context);
            });
          },
          onExit: (e) {
            if (hover == false) {
              return;
            }
            setState(() {
              hover = false;
              widget.onHoverExit?.call(context);
            });
          },
          child:  widget.itemBuilder.call(context, checked, hover, pressed)),
    );
  }
}
