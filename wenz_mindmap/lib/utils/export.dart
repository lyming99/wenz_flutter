import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:wenz_ui/index.dart';

import '../mindmap.dart';

Future exportMindPng(BuildContext context, MindMapController controller) async {
  var devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  var content = controller.getContent();
  var exportController = MindMapController();
  exportController.setContent(content, null, true);
  exportController.root.visitChildren((element) {
    element.info?.expand = true;
  });
  exportController.defaultTextStyle = controller.defaultTextStyle;
  exportController.layout();
  var size = exportController.root.nodeContentSize;
  var widgets = <Widget>[];
  var toolWidgets = <Widget>[];
  var linePaths = <LinePath>[];
  exportController.root.buildWidgets(
      context: context,
      size: size,
      widgets: widgets,
      toolWidgets: toolWidgets,
      linePaths: linePaths,
      buildAll: true,
      style: exportController.document?.style,
      nodeBuilder: (context, node) {
        return XMindNodeWidget(
          key: ValueKey(node.uuid),
          docRootDir: controller.docRootDir,
          controller: NodeEditController(
            controller: exportController,
            node: node,
          ),
        );
      });
  var file = await FilePicker.platform.saveFile(
    type: FileType.custom,
    allowedExtensions: ["png"],
    fileName: "${exportController.root.info?.content ?? "export"}.png",
  );
  if (file == null) {
    return;
  }
  ScreenshotController screenshotController = ScreenshotController();
  var capture = await screenshotController.captureFromLongWidget(
    pixelRatio: devicePixelRatio,
    MediaQuery(
      data: MediaQuery.of(context),
      child: Material(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(
              painter: LinePathPainter(linePaths: linePaths),
              child: Stack(
                children: widgets,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await File(file).writeAsBytes(capture);

  WidgetsBinding.instance.scheduleFrameCallback((time) {
    if (!context.mounted) {
      return;
    }
    showConfirmDialog(
      context,
      title: '提示',
      contentWidget: SelectableText("导出完成：$file"),
      onConfirm: () {},
    );
  });
}
