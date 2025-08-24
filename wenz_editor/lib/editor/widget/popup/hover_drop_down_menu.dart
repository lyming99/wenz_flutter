import 'dart:async';

import 'package:flutter/material.dart';

import 'bubble_border.dart';
import 'custom_menu_anchor.dart';

enum MenuAlignment { left, right }

class HoverDropDownMenu extends StatefulWidget {
  final CustomMenuAnchorChildBuilder builder;
  final bool hoverPopup;
  final double borderRadius;
  final bool showBubble;
  final double bubbleBorderRadius;
  final double? bubbleArrowOffset;
  final double? bubbleArrowEndOffset;
  final List<MenuItemButton> menuChildren;
  final Offset? menuOffset;
  final MenuAlignment menuAlignment;
  final double? menuWidth;
  final int closeDelay;
  final int openDelay;

  const HoverDropDownMenu({
    super.key,
    this.hoverPopup = true,
    this.borderRadius = 4,
    this.showBubble = true,
    this.bubbleBorderRadius = 4,
    this.bubbleArrowOffset,
    this.bubbleArrowEndOffset,
    required this.menuChildren,
    required this.builder,
    this.menuOffset,
    this.menuAlignment = MenuAlignment.left,
    this.menuWidth,
    this.openDelay = 500,
    this.closeDelay = 200,
  });

  @override
  State<HoverDropDownMenu> createState() => _HoverDropDownMenuState();
}

class _HoverDropDownMenuState extends State<HoverDropDownMenu> {
  Timer? closeTimer;
  Timer? openTimer;
  var menuController = CustomMenuController();

  void onHover(bool value) {
    if (!widget.hoverPopup) {
      return;
    }
    if (value) {
      closeTimer?.cancel();
      closeTimer = null;
      if (widget.openDelay <= 0) {
        menuController.open();
      } else {
        openTimer = Timer(
          Duration(milliseconds: widget.openDelay),
          () {
            menuController.open();
          },
        );
      }
    } else {
      openTimer?.cancel();
      openTimer = null;
      closeTimer = Timer(
        Duration(milliseconds: widget.closeDelay),
        () {
          menuController.close();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var textDirection = Directionality.of(context);
    return Directionality(
      textDirection: widget.menuAlignment == MenuAlignment.left
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: CustomMenuAnchor(
        controller: menuController,
        alignmentOffset: widget.menuOffset,
        styleBuilder: (context, isBottom) => MenuStyle(
          shape: widget.showBubble
              ? WidgetStateProperty.all(
                  BubbleShapeBorder(
                    arrowDirection:
                        isBottom ? AxisDirection.up : AxisDirection.down,
                    borderRadius:
                        BorderRadius.circular(widget.bubbleBorderRadius),
                    arrowOffset: widget.bubbleArrowOffset,
                    arrowEndOffset: widget.bubbleArrowEndOffset,
                  ),
                )
              : null,
          padding: widget.showBubble
              ? WidgetStateProperty.all(
                  EdgeInsets.only(
                    top: isBottom ? 20 : 0,
                    bottom: isBottom ? 0 : 20,
                  ),
                )
              : null,
        ),
        menuChildren: [
          for (var i = 0; i < widget.menuChildren.length; i++)
            Directionality(
              textDirection: textDirection,
              child: SizedBox(
                width: widget.menuWidth,
                child: MenuItemButton(
                  leadingIcon: widget.menuChildren[i].leadingIcon,
                  trailingIcon: widget.menuChildren[i].trailingIcon,
                  onHover: (value) {
                    onHover(value);
                    widget.menuChildren[i].onHover?.call(value);
                  },
                  onPressed: widget.menuChildren[i].onPressed==null?null:(){
                    widget.menuChildren[i].onPressed!.call();
                    menuController.close();
                  },
                  child: widget.menuChildren[i].child,
                ),
              ),
            ),
        ],
        builder: (context, ctrl, child) {
          return MouseRegion(
            onEnter: (event) {
              onHover(true);
            },
            onExit: (event) {
              onHover(false);
            },
            child: GestureDetector(
              onTap: () {
                ctrl.open();
              },
              child: widget.builder.call(context, ctrl, child),
            ),
          );
        },
      ),
    );
  }
}
