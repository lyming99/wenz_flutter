import 'package:flutter/material.dart';

import 'polyline_tool.dart';

class PolylineArrowTool extends PolylineTool {
  PolylineArrowTool()
      : super(
          id: idValue,
          name: 'Polyline Arrow',
          icon: Icons.account_tree,
          endArrow: true,
        );

  static const idValue = 'polyline_arrow';
}
