import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../button/circle_button.dart';
import '../popup/popup_dialog.dart';
import '../theme//theme.dart';
import '../layout/index.dart';
import '../popup/index.dart';
import '../utils/mvc.dart';

Future<String?> showFolderInputDialog(BuildContext context) async {
  var ret = await showMyCustomDialog(
    context: context,
    windowSize: Size(500, 400),
    builder: (context) => FolderSelectDialog(
      controller: FolderSelectController(),
    ),
  );
  if (ret is String) {
    return ret;
  }
  return null;
}

/// 1.选择文件夹
/// 2.输入项目文件夹名称
class FolderSelectDialog extends MvcView<FolderSelectController> {
  const FolderSelectDialog({super.key, required super.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text("请选择文件夹"),
      ),
      body: Column(
        children: [
          // form
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: SpacingColumn(
                    spacing: 16,
                    children: [
                      TextField(
                        readOnly: false,
                        controller: controller.folderController,
                        decoration: InputDecoration(
                          hintText: "选择系统文件夹",
                          prefixIcon: const Icon(Icons.folder),
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () {
                              controller.selectFolder(context);
                            },
                          ),
                        ),
                      ),
                      TextField(
                        controller: controller.nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "输入文件夹名称(可选)",
                          prefixIcon: Icon(Icons.folder),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ))
              ],
            ),
          ),

          // button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                CircleButton(
                  radius: 4,
                  borderColor: Colors.transparent,
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 80,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Text("取消"),
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                CircleButton(
                  radius: 4,
                  borderColor: appColor.primary,
                  onTap: () async {
                    submit(context);
                  },
                  child: Container(
                    width: 80,
                    height: 40,
                    alignment: Alignment.center,
                    child: const Text("确定"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void submit(BuildContext context) {
    var folderPath = controller.getFolderPath();
    if (!Directory(folderPath).existsSync()) {
      Directory(folderPath).createSync(recursive: true);
    }
    context.pop(folderPath);
  }
}

class FolderSelectController extends MvcController {
  FolderSelectController({this.recentFolder});

  String? recentFolder;
  var folderController = TextEditingController();
  var nameController = TextEditingController();

  @override
  void onInitState(BuildContext context, MvcViewState state) {
    super.onInitState(context, state);
    readDocumentFolder();
  }

  void selectFolder(BuildContext context) async {
    // 选择文件夹
    var recentDocFolder = recentFolder;
    if (recentDocFolder != null && !Directory(recentDocFolder).existsSync()) {
      recentDocFolder = null;
    }
    var dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择一个文件夹",
        lockParentWindow: true,
        initialDirectory: Platform.isMacOS ? null : recentDocFolder);
    if (dir != null) {
      recentFolder = folderController.text = dir;
    }
  }

  String getFolderPath() {
    return "${folderController.text}/${nameController.text}"
        .replaceAll("//", "/");
  }

  void readDocumentFolder() async {
    var dir = await getApplicationDocumentsDirectory();
    folderController.text = dir.path;
    notifyListeners();
  }
}
