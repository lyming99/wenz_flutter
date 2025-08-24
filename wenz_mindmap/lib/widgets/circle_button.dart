import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final double radius;
  final Widget? child;
  final VoidCallback? onTap;
  final Color borderColor;
  final Color? background;

  const CircleButton({
    super.key,
    this.child,
    this.radius = 10,
    this.onTap,
    this.borderColor = const Color(0xfff6dba6),
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}
