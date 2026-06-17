import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';

class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? const Color(0xFFB8C2CC)
        : selected
            ? UiColors.accent
            : UiColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? UiColors.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? const Color(0xFFC7DDF2) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(size: 16, color: foreground),
                  child: iconWidget ?? Icon(icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
