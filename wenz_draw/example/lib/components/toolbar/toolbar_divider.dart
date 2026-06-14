import 'package:flutter/material.dart';

import '../../theme/ui_colors.dart';

class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: UiColors.line,
    );
  }
}
