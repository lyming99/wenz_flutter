import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Size calcWidgetSize(
  Widget widget, {
  Size? maxSize,
  BuildContext? context,
}) {
  var startTime = DateTime.now().millisecondsSinceEpoch;
  final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
  Size logicalSize = maxSize ??
      (ui.window.physicalSize / ui.window.devicePixelRatio); // Adapted
  final RenderView renderView = RenderView(
    view: ui.window,
    child: RenderPositionedBox(
        alignment: Alignment.center, child: repaintBoundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(
          maxWidth: logicalSize.width, maxHeight: logicalSize.height),
      devicePixelRatio: 1.0,
    ),
  );

  final PipelineOwner pipelineOwner = PipelineOwner();
  final BuildOwner buildOwner = BuildOwner(
    focusManager: FocusManager(),
  );
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();
  final RenderObjectToWidgetElement<RenderBox> rootElement =
      RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: widget,
    ),
  ).attachToRenderTree(
    buildOwner,
  );
  buildOwner.buildScope(
    rootElement,
  );
  pipelineOwner.flushLayout();
  print(
      'calc widget size use time:${DateTime.now().millisecondsSinceEpoch - startTime}ms');
  return repaintBoundary.size;
}
