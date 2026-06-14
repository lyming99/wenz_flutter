import 'package:flutter/material.dart';

import '../../theme/ui_colors.dart';

class PaletteSubhead extends StatelessWidget {
  const PaletteSubhead(this.title, {this.onTap, this.isExpanded});

  final String title;
  final VoidCallback? onTap;
  final bool? isExpanded;

  @override
  Widget build(BuildContext context) {
    final hasToggle = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 7),
        child: Row(
          children: [
            if (hasToggle)
              AnimatedRotation(
                turns: (isExpanded ?? true) ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.expand_more,
                  size: 16,
                  color: UiColors.muted,
                ),
              ),
            Text(
              title,
              style: const TextStyle(
                color: UiColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
