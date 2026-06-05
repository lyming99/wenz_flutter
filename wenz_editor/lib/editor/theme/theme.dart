import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_editor/editor/edit_widget.dart';

class EditTheme {
  final bool isDark;
  final Color bgColor;
  final Color bgColor2;
  final Color bgColor3;
  final Color codeBgColor;
  final Color fontColor;
  final Color fontColor2;
  final Color linkColor;
  final Color cursorColor;
  final Color selectionColor;
  final Color navIndicateColor;
  final Color navUnSelectColor;
  final Color treeItemSelectColor;
  final Color treeItemHoverColor;
  final Color scrollBarDefaultColor;
  final Color scrollBarHoverColor;
  final Color scrollBarHoverBgColor;
  final Color checkedColor;
  final Color uncheckedColor;
  final Color quoteBgColor;
  final Color quoteBarColor;
  final Color dropColor;
  final Color borderColor;
  final Color lineColor;
  final Color windowTitleColor;
  final Color mobileBgColor;
  final Color mobileContentBgColor;
  final Color mobileNavBgColor;
  final Color floatingButtonColor;
  final Color mobileNavActiveColor;
  final Color itemColor;
  final TextStyle textStyle;
  final double fontSize;

  const EditTheme.create({
    required this.isDark,
    required this.bgColor,
    required this.bgColor2,
    required this.bgColor3,
    required this.codeBgColor,
    required this.fontColor,
    required this.fontColor2,
    required this.linkColor,
    required this.cursorColor,
    required this.selectionColor,
    required this.navIndicateColor,
    required this.navUnSelectColor,
    required this.treeItemSelectColor,
    required this.treeItemHoverColor,
    required this.scrollBarDefaultColor,
    required this.scrollBarHoverColor,
    required this.scrollBarHoverBgColor,
    required this.checkedColor,
    required this.uncheckedColor,
    required this.quoteBgColor,
    required this.quoteBarColor,
    required this.dropColor,
    required this.borderColor,
    required this.lineColor,
    required this.windowTitleColor,
    required this.mobileBgColor,
    required this.mobileContentBgColor,
    required this.mobileNavBgColor,
    required this.floatingButtonColor,
    required this.mobileNavActiveColor,
    required this.itemColor,
    required this.textStyle,
    this.fontSize = 16,
  });

  // copy with
  EditTheme copyWith({
    bool? isDark,
    Color? bgColor,
    Color? bgColor2,
    Color? bgColor3,
    Color? codeBgColor,
    Color? fontColor,
    Color? fontColor2,
    Color? linkColor,
    Color? cursorColor,
    Color? selectionColor,
    Color? navIndicateColor,
    Color? navUnSelectColor,
    Color? treeItemSelectColor,
    Color? treeItemHoverColor,
    Color? scrollBarDefaultColor,
    Color? scrollBarHoverColor,
    Color? scrollBarHoverBgColor,
    Color? checkedColor,
    Color? uncheckedColor,
    Color? quoteBgColor,
    Color? quoteBarColor,
    Color? dropColor,
    Color? borderColor,
    Color? lineColor,
    Color? windowTitleColor,
    Color? mobileBgColor,
    Color? mobileContentBgColor,
    Color? mobileNavBgColor,
    Color? floatingButtonColor,
    Color? mobileNavActiveColor,
    Color? itemColor,
    TextStyle? textStyle,
    double? fontSize,
  }) =>
      EditTheme.create(
        isDark: isDark ?? this.isDark,
        bgColor: bgColor ?? this.bgColor,
        bgColor2: bgColor2 ?? this.bgColor2,
        bgColor3: bgColor3 ?? this.bgColor3,
        codeBgColor: codeBgColor ?? this.codeBgColor,
        fontColor: fontColor ?? this.fontColor,
        fontColor2: fontColor2 ?? this.fontColor2,
        linkColor: linkColor ?? this.linkColor,
        cursorColor: cursorColor ?? this.cursorColor,
        selectionColor: selectionColor ??
            cursorColor?.withValues(alpha: 0.4) ??
            this.selectionColor,
        navIndicateColor: navIndicateColor ?? this.navIndicateColor,
        navUnSelectColor: navUnSelectColor ?? this.navUnSelectColor,
        treeItemSelectColor: treeItemSelectColor ?? this.treeItemSelectColor,
        treeItemHoverColor: treeItemHoverColor ?? this.treeItemHoverColor,
        scrollBarDefaultColor:
            scrollBarDefaultColor ?? this.scrollBarDefaultColor,
        scrollBarHoverColor: scrollBarHoverColor ?? this.scrollBarHoverColor,
        scrollBarHoverBgColor:
            scrollBarHoverBgColor ?? this.scrollBarHoverBgColor,
        checkedColor: checkedColor ?? this.checkedColor,
        uncheckedColor: uncheckedColor ?? this.uncheckedColor,
        quoteBgColor: quoteBgColor ?? this.quoteBgColor,
        quoteBarColor: quoteBarColor ?? this.quoteBarColor,
        dropColor: dropColor ?? this.dropColor,
        borderColor: borderColor ?? this.borderColor,
        lineColor: lineColor ?? this.lineColor,
        windowTitleColor: windowTitleColor ?? this.windowTitleColor,
        mobileBgColor: mobileBgColor ?? this.mobileBgColor,
        mobileContentBgColor: mobileContentBgColor ?? this.mobileContentBgColor,
        mobileNavBgColor: mobileNavBgColor ?? this.mobileNavBgColor,
        floatingButtonColor: floatingButtonColor ?? this.floatingButtonColor,
        mobileNavActiveColor: mobileNavActiveColor ?? this.mobileNavActiveColor,
        itemColor: itemColor ?? this.itemColor,
        textStyle: textStyle ?? this.textStyle,
        fontSize: fontSize ?? this.fontSize,
      );

  static SystemUiOverlayStyle overlayStyle(
    context, {
    bool reverse = false,
  }) {
    var isLight = Theme.of(context).brightness == Brightness.dark;
    if (reverse) {
      isLight = !isLight;
    }
    return isLight ? lightOverlayStyle(context) : darkOverlayStyle(context);
  }

  static SystemUiOverlayStyle darkOverlayStyle(context) {
    return SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: EditTheme.of(context).mobileNavBgColor,
      systemNavigationBarDividerColor: EditTheme.of(context).mobileNavBgColor,
    );
  }

  static SystemUiOverlayStyle lightOverlayStyle(context) {
    return SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: EditTheme.of(context).mobileNavBgColor,
      systemNavigationBarDividerColor: EditTheme.of(context).mobileNavBgColor,
    );
  }

  static EditTheme dark = const EditTheme.create(
    isDark: true,
    bgColor: Color(0xff484848),
    bgColor2: Color(0xff383838),
    bgColor3: Color(0xff2c2c2c),
    fontColor: Colors.white,
    fontColor2: Color(0xffd2d2d2),
    linkColor: Colors.blue,
    cursorColor: Color(0xfffa5902),
    selectionColor: Color(0x66FA5902),
    navIndicateColor: Color(0xff002085),
    navUnSelectColor: Color(0xffa6a6a6),
    codeBgColor: Color(0xff494949),
    treeItemSelectColor: Color(0xff194176),
    treeItemHoverColor: Color(0xff2D2D2D),
    scrollBarDefaultColor: Color(0x33666666),
    scrollBarHoverColor: Color(0x33AAAAAA),
    scrollBarHoverBgColor: Color(0x33666666),
    checkedColor: Color(0xff038d44),
    uncheckedColor: Color(0xffeeeeee),
    quoteBgColor: Color(0xff333333),
    quoteBarColor: Color(0xff444444),
    dropColor: Color(0x22000000),
    borderColor: Color(0x22ffffff),
    lineColor: Color(0x22ffffff),
    windowTitleColor: Color(0xFFB7B7B7),
    mobileBgColor: Color(0xff111111),
    mobileContentBgColor: Color(0xff1f1f1f),
    mobileNavBgColor: Color(0xff1f1f1f),
    floatingButtonColor: Color(0xfffa5902),
    mobileNavActiveColor: Colors.white,
    itemColor: Colors.grey,
    textStyle: TextStyle(),
    fontSize: 16,
  );

  static EditTheme light = EditTheme.create(
    isDark: false,
    bgColor: const Color(0xffffffff),
    bgColor2: const Color(0xffffffff),
    bgColor3: const Color(0xfffcfcfc),
    fontColor: const Color(0xff000000),
    fontColor2: const Color(0xffadadad),
    linkColor: Colors.blue,
    codeBgColor: const Color(0xffefefef),
    cursorColor: const Color(0xfffa5902),
    selectionColor: const Color(0x66FA5902),
    navIndicateColor: const Color(0xff002085),
    navUnSelectColor: const Color(0xffa6a6a6),
    treeItemSelectColor: const Color(0xffD8E8FA),
    treeItemHoverColor: const Color(0xffd6d6d6),
    scrollBarDefaultColor: const Color(0x66999999),
    scrollBarHoverColor: const Color(0x99999999),
    scrollBarHoverBgColor: const Color(0x33999999),
    checkedColor: const Color(0xff038d44),
    uncheckedColor: const Color(0xff666666),
    quoteBgColor: const Color(0xffeeeeee),
    quoteBarColor: const Color(0xffdddddd),
    dropColor: const Color(0x22000000),
    borderColor: const Color(0x22000000),
    lineColor: const Color(0x22000000),
    windowTitleColor: const Color(0xFF707070),
    mobileBgColor: Colors.grey.shade50,
    mobileContentBgColor:  Colors.white,
    mobileNavBgColor: const Color(0xFFFFFFFF),
    floatingButtonColor: const Color(0xfff52e02),
    mobileNavActiveColor: Colors.black87,
    itemColor: Colors.grey,
    textStyle: const TextStyle(),
    fontSize: 16,
  );

  static EditTheme of(BuildContext context) {
    var state = context.findAncestorStateOfType<WenzEditState>();
    return state?.widget.editTheme ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  static Color? buildColor(
    BuildContext context, {
    Color? darkColor,
    Color? lightColor,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
  }
}
