import 'package:flutter/material.dart';

class MiniIconButton extends IconButton {
  const MiniIconButton({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    super.mouseCursor,
    super.focusNode,
    super.autofocus,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style = const ButtonStyle(
      visualDensity: VisualDensity(vertical: -1.4, horizontal: -1.4),
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      iconSize: WidgetStatePropertyAll(24),
    ),
    super.isSelected,
    super.selectedIcon,
    required super.onPressed,
    required super.icon,
  });
}
