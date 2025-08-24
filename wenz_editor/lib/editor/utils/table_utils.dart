import 'package:flutter/material.dart';
import 'package:wenz_editor/editor/edit_controller.dart';

import '../block/table/adjust_widget.dart';

class TableUtils {
  TableUtils._();

  static void showAddTableDialog(WenzEditController editController) async {
    var viewContext = editController.viewContext;
    var ok = false;
    var rowController = TextEditingController(text: "4");
    var colController = TextEditingController(text: "3");
    await showDialog(
        context: viewContext,
        builder: (context) {
          return AlertDialog(
            title: const Text("插入表格"),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(" 列 "),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                              bottom: 10, top: 10, left: 10, right: 10),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "请输入列",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              // 完善的计数输入替代方案
                              CounterTextInputFormatter(min: 1, max: 200),
                            ],
                            controller: colController,
                            autofocus: true,
                            onSubmitted: (e) {
                              ok = true;
                              Navigator.pop(context, '确定');
                            },
                          ),
                        ),
                      ),
                      const Text(" 行 "),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                              bottom: 10, top: 10, left: 10),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "请输入行",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            controller: rowController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              // 完善的计数输入替代方案
                              CounterTextInputFormatter(min: 1, max: 1000),
                            ],
                            onSubmitted: (e) {
                              ok = true;
                              Navigator.pop(context, '确定');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                child: const Text('取消'),
                onPressed: () {
                  Navigator.pop(context, '取消');
                  // Delete file here
                },
              ),
              FilledButton(
                  onPressed: () {
                    ok = true;
                    Navigator.pop(context, '确定');
                  },
                  child: const Text("确定")),
            ],
          );
        });
    if (ok) {
      var colCount = int.parse(colController.text);
      var rowCount = int.parse(rowController.text);
      if (colCount > 0 && rowCount > 0) {
        editController.addTable(rowCount, colCount);
      }
    }
  }
}
