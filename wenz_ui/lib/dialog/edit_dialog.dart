import 'package:flutter/material.dart';

import 'custom_alert_dialog.dart';

void showEditDialog(
  BuildContext context, {
  required String title,
  required ValueChanged<String> onSubmit,
  String? hintText,
  String? defaultValue,
}) {
  var editController = TextEditingController(text: defaultValue);
  showDialog(
    context: context,
    builder: (context) {
      return CustomAlertDialog(
        title: Text(title),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          onSubmitted: (value) {
            Navigator.of(context).pop();
            onSubmit(editController.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSubmit(editController.text);
            },
            child: Text("确定"),
          ),
        ],
      );
    },
  );
}

void showDoubleEditDialog(
  BuildContext context, {
  required String title,
  required ValueChanged<List<String>> onSubmit,
  String? hintText1,
  String? defaultValue1,
  String? hintText2,
  String? defaultValue2,
}) {
  var editController1 = TextEditingController(text: defaultValue1);
  var editController2 = TextEditingController(text: defaultValue2);
  showDialog(
    context: context,
    builder: (context) {
      return CustomAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editController1,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hintText1,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            TextField(
              controller: editController2,
              decoration: InputDecoration(
                hintText: hintText2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSubmit([editController1.text, editController2.text]);
            },
            child: const Text("确定"),
          ),
        ],
      );
    },
  );
}

void showConfirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  required VoidCallback onConfirm,
  Widget? contentWidget,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return CustomAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.all(8.0),
          child: contentWidget ?? Text(content ?? title),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text("确定"),
          ),
        ],
      );
    },
  );
}
