import 'dart:math';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_code_editor/src/code_field/span_builder.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:wenz_editor/commons/util/html.dart';
import 'package:wenz_editor/commons/widget/ignore_parent_pointer.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/widget/toggle_item.dart';
import 'package:ydart/ydart.dart';

import '../../edit_controller.dart';
import '../../theme/theme.dart';
import '../../widget/auto_suggest_box.dart';
import '../block.dart';
import '../element/element.dart';
import '../text/text.dart';
import 'code_lang.dart';
import 'colors.dart';

class WenCodeElement extends WenElement {
  String _code = "";
  String _language = "";

  WenCodeElement({
    required String code,
    required String language,
    super.type = "code",
  }) {
    _code = code;
    _language = language;
  }

  WenCodeElement copy() {
    return WenCodeElement(
      code: code,
      language: language,
    );
  }

  hl.Mode? getLanguageMode() {
    return codeLanguages[language];
  }

  @override
  String getHtml({FilePathBuilder? filePathBuilder}) {
    return '<pre lang="$language">' + htmlSerializeEscape(code) + "</pre>";
  }

  @override
  String getMarkDown({FilePathBuilder? filePathBuilder}) {
    return "```$language\n$code\n```";
  }

  @override
  String getText() {
    return code;
  }

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        "code": code,
        "language": language,
      });
  }

  factory WenCodeElement.fromJson(Map<dynamic, dynamic> json) {
    return WenCodeElement(
      code: json["code"],
      language: json["language"],
    )..copyProperties(WenElement.fromJson(json));
  }

  String get language => _language;

  set language(String value) {
    _language = value;
  }

  String get code => _code;

  set code(String value) {
    _code = value;
  }

  @override
  YMap getYMap([YDoc? doc]) {
    var map = YMap();
    map.set("type", "code");
    map.set("code", YText(code));
    map.set("language", language);
    return map;
  }
}

/// 是否自动换行？可以支持，但默认先实现不自动换行
/// 如何输入，不独立操作模式，依赖与EditController输入法监听输入
class CodeBlock extends WenzBlock   {
  double toolPadding = 20;

  double padding = 10;
  double verticalMargin = 0;

  TextPainter? textPainter;

  @override
  WenCodeElement element;

  @override
  bool get catchEnter => true;

  @override
  bool get canEmpty => true;

  @override
  bool get canSelectAll => true;

  CodeBlock(
      {required this.element,
      required super.context,
      required super.editController});

  @override
  Widget buildWidget(BuildContext context) {
    this.context = context;
    List<Positioned> selectDraw = [];
    var start = selectedStart;
    var end = selectedEnd;
    if (selected && start != null && end != null && start != end) {
      var selection = TextSelection.fromPosition(start).extendTo(end);
      var boxes = textPainter?.getBoxesForSelection(selection) ?? [];
      for (var box in boxes) {
        var boxRect = box.toRect();
        selectDraw.add(Positioned(
          top: box.top,
          left: box.left,
          width: boxRect.width,
          height: boxRect.height,
          child: Container(
            color: Colors.blueAccent.withOpacity(0.4),
          ),
        ));
      }
    }
    return Container(
      width: width,
      height: height - verticalMargin * 2,
      decoration: BoxDecoration(
        color: theme.codeBgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      margin: EdgeInsets.symmetric(
        vertical: verticalMargin,
      ),
      padding: EdgeInsets.only(
        top: toolPadding + padding,
        left: padding,
        right: padding,
        bottom: padding,
      ),
      child: Stack(
        children: [
          ...selectDraw,
          CustomPaint(
            painter: CodePainter(textPainter: textPainter),
          ),
        ],
      ),
    );
  }

  @override
  List<PopupPositionWidget> buildFloatWidgets() {
    var items = codeLanguages.keys
        .map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ))
        .toList();
    var box = AutoSuggestBox<String>(
      key: ValueKey(this),
      items: items,
      itemWidth: 110,
      initialValue:
          items.where((item) => item.value == element.language).firstOrNull,
      onChanged: (dynamic item) {
        if (codeLanguages.containsKey(item)) {
          editController.updateCodeLanguage(this, item ?? "text");
        }
      },
    );
    var isFocus = editController.cursorState.cursorPosition?.block == this;
    var result = [
      PopupPositionWidget(
        top: top - editController.scrollOffset + editController.padding.top,
        left: left + editController.padding.left,
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: box,
        ),
      ),
      PopupPositionWidget(
        right: editController.padding.right,
        top: (top - editController.scrollOffset + editController.padding.top),
        child: SizedBox(
          width: 150,
          child: Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnoreParentPointer(
                  child: ToggleItem(
                    onTap: (ctx) {
                      editController.copyService.copyWenElements([element]);
                      BotToast.showText(text: "复制成功");
                    },
                    itemBuilder: (BuildContext context, bool checked,
                        bool hover, bool pressed) {
                      return Container(
                        padding: EdgeInsets.all(4),
                        color: hover
                            ? systemColor(context, "buttonIconColor")
                                .withOpacity(0.2)
                            : null,
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: hover
                              ? systemColor(context, "buttonIconColor")
                              : systemColor(context, "buttonIconColor")
                                  .withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                IgnoreParentPointer(
                  child: ToggleItem(
                    onTap: (ctx) {
                      editController.deleteCode();
                    },
                    itemBuilder: (BuildContext context, bool checked,
                        bool hover, bool pressed) {
                      return Container(
                        padding: EdgeInsets.all(4),
                        color: hover
                            ? systemColor(context, "buttonIconColor")
                                .withOpacity(0.2)
                            : null,
                        child: Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: hover
                              ? systemColor(context, "buttonIconColor")
                              : systemColor(context, "buttonIconColor")
                                  .withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
    return result;
  }

  @override
  void layout(BuildContext context, Size viewSize) {
    this.context = context;
    if (!relayoutFlag && width == viewSize.width) return;
    relayoutFlag = false;
    var code = Code(
      text: element.code,
      language: element.getLanguageMode(),
      highlighted: hl.highlight.parse(element.code, language: element.language),
    );
    var theme = EditTheme.of(context);
    var span = SpanBuilder(
      code: code,
      theme: CodeThemeData(
          styles: theme.isDark
              ? themeMap['atom-one-dark']
              : themeMap['atom-one-light']),
      rootStyle: TextStyle(
          color: theme.fontColor,
          fontSize: theme.fontSize,
          fontFamilyFallback: [
            "Consolas",
            "mononoki",
            "Liberation Mono",
            "微软雅黑",
            "Menlo",
            "Courier",
            "monospace",
            "Apple Color Emoji",
            "Segoe UI Emoji",
            "Noto Color Emoji",
            "Segoe UI Symbol",
            "Android Emoji",
            "EmojiSymbols"
          ]),
    ).build();
    textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(span.style ?? const TextStyle(),
          forceStrutHeight: true),
    )..layout(
        maxWidth: max(0, viewSize.width - padding * 2),
      );
    width = max(padding * 2, viewSize.width);
    height =
        textPainter!.height + padding * 2 + verticalMargin * 2 + toolPadding;
  }

  @override
  int get length => element.code.length;

  @override
  WenCodeElement copyElement(TextPosition start, TextPosition end) {
    return WenCodeElement(
        code: element.code.substring(start.offset, end.offset),
        language: element.language);
  }

  @override
  int deletePosition(TextPosition textPosition) {
    int len = length;
    relayoutFlag = true;
    element.code = element.code
        .replaceRange(textPosition.offset - 1, textPosition.offset, "");
    return len - length;
  }

  @override
  void deleteRange(TextPosition start, TextPosition end) {
    relayoutFlag = true;
    element.code = element.code.replaceRange(start.offset, end.offset, "");
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    return [];
  }

  @override
  Rect? getCursorRect(TextPosition textPosition) {
    var offset = textPainter?.getOffsetForCaret(
            textPosition, const Rect.fromLTWH(0, 0, 2, 2)) ??
        Offset.zero.translate(1, 0);

    var height = textPainter?.getFullHeightForCaret(textPosition, Rect.zero) ??
        textPainter?.preferredLineHeight;
    if (height != null) {
      return offset.translate(
              padding - 1, padding + verticalMargin + toolPadding) &
          Size(2, height);
    }
    return offset.translate(
            padding - 1, padding + verticalMargin + toolPadding) &
        Size(2, this.height);
  }

  @override
  TextRange? getWordBoundary(TextPosition textPosition) {
    return textPainter?.getWordBoundary(textPosition);
  }

  @override
  TextPosition? getPositionForOffset(Offset offset) {
    return textPainter?.getPositionForOffset(
        offset.translate(-padding, -padding - verticalMargin - toolPadding));
  }

  @override
  void inputText(WenzEditController controller, TextEditingValue text,
      {bool isComposing = false}) {
    var position = controller.cursorState.cursorPosition;
    if (position == null) {
      return;
    }
    var textPosition = position.textPosition;
    if (textPosition == null) {
      return;
    }
    var offset = textPosition.offset;
    relayoutFlag = true;
    element.code = element.code
        .replaceRange(offset, offset, text.text.replaceAll("\r\n", "\n"));
    controller.layoutCurrentBlock(this);
    var newTextPosition = position.textPosition = TextPosition(
      offset: offset + text.text.length,
      affinity: textPosition.affinity,
    );
    position.rect = getCursorRect(newTextPosition);
    controller.toPosition(
      position,
      true,
      applyUpdate: isComposing == false,
    );
  }

  @override
  WenzBlock? mergeBlock(WenzBlock endBlock) {
    if (endBlock.isEmpty) {
      return this;
    }
    return null;
  }

  @override
  WenzBlock splitBlock(TextPosition textPosition) {
    return TextBlock(
      context: context,
      textElement: WenTextElement(),
      editController: editController,
    );
  }

  @override
  TextRange? getLineBoundary(TextPosition textPosition) {
    return textPainter?.getLineBoundary(textPosition);
  }

  @override
  void visitElement(
      TextPosition start, TextPosition end, WenzElementVisitor visit) {
    var startIndex = start.offset;
    if (startIndex >= 0 && startIndex < element.code.length) {
      visit.call(this, element);
    }
  }

  void addIndent() {
    editController.deleteSelectRange();
    inputText(editController, const TextEditingValue(text: "    "));
  }

  void removeIndent() {}

  void deleteCode() {
    var index = blockIndex;
    var top = this.top;
    var textBlock = TextBlock(
      context: context,
      textElement: WenTextElement(),
      editController: editController,
    )..top = top;
    editController.blockManager.blocks[index] = textBlock;
    editController
        .layoutCurrentBlock(editController.blockManager.blocks[index]);
    editController.toPosition(textBlock.startCursorPosition, true);
    editController.record();
  }
}

class CodePainter extends CustomPainter {
  TextPainter? textPainter;

  CodePainter({this.textPainter});

  @override
  void paint(Canvas canvas, Size size) {
    textPainter?.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
