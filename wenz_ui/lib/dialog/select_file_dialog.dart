import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../index.dart';

Future<String?> showSelectFileDialog(BuildContext context,
    String title,
    String fileName,) async {
  try {
    var result = await FilePicker.platform.pickFiles(
      dialogTitle: title,
    );
    if (result == null) {
      return null;
    }
    if (result.xFiles.isNotEmpty) {
      return result.xFiles.first.path;
    }
    if (result.files.isNotEmpty) {
      return result.files.first.path;
    }
    return null;
  } catch (e) {
    print(e);
  }
  return showMyCustomDialog(
    context: context,
    windowSize: Size(480, 400),
    builder: (context) {
      var controller = TextEditingController();
      return Scaffold(
        body: Center(
          child: SpacingColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "提示",
                  style: TextStyle(fontSize: 24),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("打开系统文件选择失败,请在下方输入$fileName路径"),
              ),
              SizedBox(
                height: 16,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "请输入$fileName路径",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    Navigator.of(context).pop(value);
                  },
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
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
                    CircleButton(
                      radius: 4,
                      borderColor: appColor.primary,
                      onTap: () async {
                        Navigator.of(context).pop(controller.text);
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
        ),
      );
    },
  );
}
