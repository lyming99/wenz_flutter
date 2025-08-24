import 'dart:math';

import 'package:flutter/material.dart';

typedef TabWidgetBuilder<T> = Widget Function(
    BuildContext context, TabItem<T> item);

class TabItem<T> {
  Key key;
  String id;
  String? title;
  TabWidgetBuilder? titleBuilder;
  TabWidgetBuilder? builder;
  double? titleWidth;
  T? data;

  TabItem({
    required this.id,
    this.data,
    this.titleBuilder,
    this.builder,
    this.title,
    this.titleWidth,
  }) : key = ValueKey(id);

  Size measureTitleSize(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout();

    return Size(
      min(textPainter.width + 32.0, 180),
      textPainter.height + 16.0,
    );
  }

  Widget buildTitleWidget(BuildContext context, Color textColor) {
    return titleBuilder?.call(context, this) ??
        Center(
            child: Text(
              title == null || title!.isEmpty ? "未命名" : title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500),
            ));
  }
}
