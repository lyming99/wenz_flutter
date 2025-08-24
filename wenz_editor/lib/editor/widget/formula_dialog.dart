import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:wenz_editor/commons/util/widget_util.dart';
import 'package:wenz_editor/editor/theme/theme.dart';

class FormulaWidget extends StatefulWidget {
  final String? title;
  final String? formula;

  const FormulaWidget({
    super.key,
    this.title,
    this.formula,
  });

  @override
  State<FormulaWidget> createState() => _FormulaState();
}

class _FormulaState extends State<FormulaWidget> {
  String? formula;
  double formulaWidth = 30;
  double formulaHeight = 30;
  double height = 30;
  SyntaxTree? ast;
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    formula = widget.formula;
    controller.text = formula ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.title ?? "输入公式"),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10, top: 10),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "请输入公式",
                ),
                controller: controller,
                maxLines: null,
                autofocus: true,
                onSubmitted: (s) {},
                onChanged: (text) {
                  setState(() {
                    formula = text;
                  });
                },
              ),
            ),
            Container(
                width: double.infinity,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  scrollDirection: Axis.horizontal,
                  child: Builder(builder: (context) {
                    var item = Math.tex(
                      formula ?? "",
                      textStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: EditTheme.of(context).fontColor,
                      ),
                    );
                    ast = item.ast;
                    if (item.parseError != null) {
                      return const Center(
                        child: Text(
                          "error.",
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      );
                    }

                    var size = calcWidgetSize(
                      item,
                      maxSize: const Size(1000, 1000),
                      context: context,
                    );
                    formulaWidth = size.width;
                    formulaHeight = size.height;
                    var height = min(200.0, max(30.0, size.height));
                    if (height != this.height) {
                      WidgetsBinding.instance
                          .scheduleFrameCallback((timeStamp) {
                        setState(() {
                          this.height = height;
                        });
                      });
                      return Container();
                    }
                    return Center(child: item);
                  }),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('取消'),
          onPressed: () {
            Navigator.pop(context, null);
            // Delete file here
          },
        ),
        ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                "formula": formula,
                "width": formulaWidth,
                "height": formulaHeight,
                "ok": true,
              });
            },
            child: const Text("确定")),
      ],
    );
  }
}
