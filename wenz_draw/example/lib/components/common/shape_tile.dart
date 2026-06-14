import 'package:flutter/material.dart';

import '../../theme/ui_colors.dart';

class ShapeTile extends StatelessWidget {
  const ShapeTile({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : UiColors.panelSoft,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF9FC4E8) : UiColors.line,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: const IconThemeData(size: 34, color: Color(0xFF425264)),
              child: iconWidget ?? Icon(icon),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF425264),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
