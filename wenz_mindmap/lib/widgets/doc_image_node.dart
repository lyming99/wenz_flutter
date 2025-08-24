import 'dart:io';

import 'package:flutter/material.dart';
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

  const DocImageNode({
    super.key,
    this.imageId,
    required this.width,
    required this.height,
    this.onResized,
    this.docRootDir,
    this.noteId,
    this.docId,
  });

  @override
  State<DocImageNode> createState() => _DocImageNodeState();
}

class _DocImageNodeState extends State<DocImageNode> {
  bool isError = false;
  File? imageFile;

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
    var fileManager = DirectoryFileManager(
      rootDir: rootDir,
      uploadFileCallback: docController.uploadFile,
      downloadFileCallback: docController. downloadFile,
      docId: widget.docId,
      noteId: widget.noteId,
    );
    var file = await fileManager.getImageFile(widget.imageId);
    if (file != null) {
      if (File(file).existsSync()) {
        setState(() {
          imageFile = File(file);
        });
        return;
      }
    }
    setState(() {
      isError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (imageFile == null) {
      return isError
          ? SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(
                child: Text(
                  "error.",
                ),
              ),
            )
          : Container();
    }
    return DragResizeContainer(
      onResized: widget.onResized,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.file(
          imageFile!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
