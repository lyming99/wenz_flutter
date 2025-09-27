import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wenz_editor/commons/entity/wenz_assets_file.dart';
import 'package:wenz_editor/commons/service/file_manager.dart';
import 'package:wenz_ui/utils/mvc.dart';

class WenzImageController extends MvcController {
  WenzImageController({
    this.fileManager,
    required this.imageId,
  });

  WenzAssetsFileManager? fileManager;
  String imageId;
  WenzAssetsFile? file;

  @override
  void onInitState(BuildContext context, MvcViewState state) {
    super.onInitState(context, state);
    fetchImage();
  }

  Future fetchImage() async {
    file = await fileManager?.getFileInfo(imageId);
    updateView();
  }

  @override
  void onDidUpdateWidget(
      BuildContext context, covariant WenzImageController oldController) {
    super.onDidUpdateWidget(context, oldController);
    file = oldController.file;
    imageId = oldController.imageId;
    fileManager = oldController.fileManager;
  }
}

class WenzImageView extends MvcView<WenzImageController> {
  const WenzImageView({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    var path = controller.file?.path;
    if (path != null) {
      if (path.startsWith("http")) {
        return Image.network(path);
      }
      return Image.file(File(path));
    }
    return Container();
  }
}
