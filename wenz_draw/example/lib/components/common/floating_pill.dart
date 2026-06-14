import 'package:flutter/material.dart';
import 'package:wenz_draw/wenz_draw.dart';

import '../../theme/ui_colors.dart';

class ZoomPill extends StatelessWidget {
  const ZoomPill({required this.viewController});

  final InfiniteCanvasController viewController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewController,
      builder: (context, _) {
        return FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniButton(
                icon: Icons.remove,
                onPressed: viewController.zoomOut,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(viewController.transform.scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF425264),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              MiniButton(icon: Icons.add, onPressed: viewController.zoomIn),
            ],
          ),
        );
      },
    );
  }
}

class MiniButton extends StatelessWidget {
  const MiniButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 15),
      color: UiColors.muted,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class FloatingPill extends StatelessWidget {
  const FloatingPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: UiColors.panel.withValues(alpha: 0.9),
        border: Border.all(color: UiColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1418232E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }
}
