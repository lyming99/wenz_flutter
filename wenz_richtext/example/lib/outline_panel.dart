import 'package:flutter/material.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

/// Thin delegate that forwards to [WenzOutlinePanel].
///
/// Kept as a `const`-constructible wrapper so the workbench tree does not
/// require a full rebuild; all behaviour is handled by [WenzOutlinePanel].
class ExampleOutlinePanel extends StatelessWidget {
  const ExampleOutlinePanel({
    super.key,
    required this.outlineController,
    this.width = 260,
  });

  final WenzOutlineController outlineController;
  final double width;

  @override
  Widget build(BuildContext context) {
    return WenzOutlinePanel(
      controller: outlineController,
      width: width,
    );
  }
}
