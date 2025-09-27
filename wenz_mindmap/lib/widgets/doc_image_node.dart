import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wenz_editor/commons/entity/wenz_assets_file.dart';
import 'package:wenz_editor/commons/service/file_manager.dart';
import 'package:wenz_editor/editor/widget/drag_resize_container.dart';
import 'package:wenz_mindmap/controller/mind_doc_controller.dart';
import 'package:wenz_ui/utils/mvc.dart';

class DocImageNode extends StatefulWidget {
  final String? imageId;
  final double width;
  final double height;
  final String? docRootDir;
  final String? docId;
  final String? noteId;
  final OnResized? onResized;
  final WenzAssetsFileManager? fileManager;

  const DocImageNode({
    super.key,
    this.imageId,
    required this.width,
    required this.height,
    this.onResized,
    this.docRootDir,
    this.noteId,
    this.docId,
    this.fileManager,
  });

  @override
  State<DocImageNode> createState() => _DocImageNodeState();
}

class _DocImageNodeState extends State<DocImageNode> {
  bool isError = false;
  WenzAssetsFile? imageFile;

  @override
  void initState() {
    super.initState();
    readImageFile();
  }

  @override
  void didUpdateWidget(covariant DocImageNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      readImageFile();
    }
  }

  void readImageFile() async {
    MindDocController? docController = findController(context);
    if (docController == null) {
      return;
    }
    String? rootDir = widget.docRootDir;
    rootDir ??= docController.getRootDir();
    var fileManager = widget.fileManager;
    var file = await fileManager?.getFileInfo(widget.imageId ?? '');
    setState(() {
      imageFile = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    var path = imageFile?.path;
    if (path == null) {
      return isError
          ? SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(child: Text("error.")),
            )
          : Container();
    }
    Image image;
    if (path.startsWith("http")) {
      image = Image.network(path, fit: BoxFit.cover);
    } else {
      image = Image.file(File(path), fit: BoxFit.cover);
    }
    return DragResizeContainer(
      onResized: widget.onResized,
      child: SizedBox(width: widget.width, height: widget.height, child: image),
    );
  }
}
