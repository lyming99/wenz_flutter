import 'package:flutter/material.dart';

final appColor = AppColor();

class AppColor {
  late ThemeData themeData;

  void build(BuildContext context) {
    themeData = Theme.of(context);
  }

  Color get primary => themeData.colorScheme.primary;

  Color get background => themeData.colorScheme.surface;

  Color get surface => themeData.colorScheme.surface;

  Color get surfaceContainerHighest =>
      themeData.colorScheme.surfaceContainerHighest;

  Color get surfaceContainerLowest =>
      themeData.colorScheme.surfaceContainerLowest;

  Color get windowBorderColor => hintColor.withAlpha(20);

  Color get dialogBorderColor => themeData.colorScheme.primary;

  Color get splitColor => themeData.dividerColor.withOpacity(0.4);

  Color get cardColor => themeData.colorScheme.surfaceContainerLow;

  Color get textColor =>
      themeData.textTheme.bodyMedium?.color ??
          (themeData.brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87);

  Color get iconColor =>
      themeData.iconTheme.color ??
          (themeData.brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87);

  Color get primaryContainer => themeData.colorScheme.primaryContainer;

  Color get hintColor => themeData.hintColor;

  Color get dangerous => Colors.red;

  Color get codeBackground =>
      themeData.colorScheme.surfaceContainerHigh.withOpacity(0.8);

  Color get hoverColor => themeData.hoverColor;

  Color get navTextColor => Colors.grey.shade100;

  Color get navIndicatorColor => const Color.fromARGB(255, 18, 130, 217);

  // Color get tableHeaderColor => Colors.blue.shade50;          // 标题栏极浅蓝色
  // Color get tableHeaderTextColor => Colors.black;     // 标题栏文字深蓝色
  // Color get tableRowColor2 => Colors.blue.shade100;           // 交替行淡蓝色
  // Color get tableRowHoverColor => Colors.blue.shade200;       // 悬停行稍深淡蓝色
  // Color get tableBorderColor => Colors.blue.shade100;         // 边框淡蓝色
  Color get tableHeaderColor => Colors.blueGrey.shade100;       // 标题栏浅蓝灰色
  Color get tableHeaderTextColor => Colors.blueGrey.shade900;   // 标题栏文字深蓝灰色
  Color get tableRowColor2 => Colors.white;                     // 交替行白色
  Color get tableRowHoverColor => Colors.blueGrey.shade200;     // 悬停行稍深蓝灰色
  Color get tableBorderColor => Colors.blueGrey.shade300;       // 边框蓝灰色
}
