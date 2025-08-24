import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/theme.dart';

Future<T?> showMyCustomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Size? windowSize,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      var appTheme = AppColor();
      appTheme.build(context);
      var borderColor = appTheme.dialogBorderColor;
      var backgroundColor = appTheme.surface;

      Widget content = Container(
        margin: const EdgeInsets.only(top: 50, left: 30, right: 30, bottom: 30),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(8),
              child: builder.call(context),
            ),
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 30,
                    width: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(80),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.close,
                      color: borderColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      Widget child;
      if (windowSize != null) {
        child = Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: windowSize.width,
            height: windowSize.height,
            child: content,
          ),
        );
      } else {
        child = content;
      }
      var inserts = MediaQuery.of(context).viewInsets;
      return Padding(
        padding: inserts,
        child: Stack(
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 38,
              child: DragToMoveArea(
                child: Container(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
