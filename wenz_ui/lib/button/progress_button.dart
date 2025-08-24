import 'package:flutter/material.dart';

class ProgressButton extends StatelessWidget {
  final Widget child;
  final Widget? loadingLabel;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool isLoading;

  const ProgressButton({
    super.key,
    required this.child,
    this.loadingLabel,
    this.onPressed,
    this.style,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: style,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                loadingLabel ?? Container(),
              ],
            )
          : child,
    );
  }
}
