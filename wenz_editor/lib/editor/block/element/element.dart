import 'package:wenz_editor/editor/block/code/code.dart';
import 'package:wenz_editor/editor/block/image/image_element.dart';
import 'package:wenz_editor/editor/block/line/line_element.dart';
import 'package:wenz_editor/editor/block/table/table_element.dart';
import 'package:wenz_editor/editor/block/text/text.dart';
import 'package:uuid/uuid.dart';
import 'package:ydart/ydart.dart';

typedef FilePathBuilder = String Function(String uuid);

const clearStyleMap = {
  "color": null,
  "bold": null,
  "italic": null,
  "fontSize": null,
  "underline": null,
  "lineThrough": null,
  "background": null,
};

class WenElement {
  bool newLine = false;
  String type = "unkown";
  int level = 0;
  int? indent;
  String? url;
  int offset = 0;
  String? alignment;
  String? childNote;
  int length = 0;
  bool hideText = true;
  bool? checked;
  int listIndex;


  WenElement({
    this.newLine = false,
    this.type = "unkown",
    this.level = 0,
    this.url,
    this.offset = 0,
    this.indent,
    this.alignment,
    this.childNote,
    this.checked,
    this.listIndex = 0,
  });

  String getHtml({FilePathBuilder? filePathBuilder}) {
    return "";
  }

  String getText() {
    return "";
  }

  String getMarkDown({FilePathBuilder? filePathBuilder}) {
    return "";
  }

  Map<String, dynamic> toJson() {
    return {
      if (newLine) "newLine": newLine,
      "type": type,
      "level": level,
      if (url != null) "url": url,
      if (indent != null) "indent": indent,
      if (alignment != null) "alignment": alignment,
      if(childNote!=null) "childNote": childNote,
    };
  }


  factory WenElement.fromJson(Map json) {
    return WenElement(
      newLine: json["newLine"] == true,
      type: json["type"],
      level: json["level"],
      url: json["url"],
      indent: json["indent"],
      alignment: json["alignment"],
      childNote: json["childNote"],
    );
  }

  void copyProperties(WenElement other) {
    offset = other.offset;
    newLine = other.newLine;
    type = other.type;
    level = other.level;
    url = other.url;
    indent = other.indent;
    alignment = other.alignment;
    childNote = other.childNote;
  }

  factory WenElement.parseJson(Map<dynamic, dynamic> json) {
    switch (json['type']) {
      case "title":
      case "text":
      case "quote":
        return WenTextElement.fromJson(json);
      case "image":
        return WenImageElement.fromJson(json);
      case "code":
        return WenCodeElement.fromJson(json);
      case "table":
        return WenTableElement.fromJson(json);
      case "line":
        return LineElement();
    }
    return WenElement.fromJson(json);
  }

  void clearStyle() {
    url = null;
    alignment = null;
    indent = null;
  }

  static String createUuid() {
    return const Uuid().v1();
  }

  YMap getYMap() {
    var map = YMap();
    var allAttrs = toJson();
    for (var attr in allAttrs.entries) {
      if (attr is List) {
        continue;
      }
      if (attr is Map) {
        continue;
      }
      map.set(attr.key, attr.value);
    }
    return map;
  }
}

/// 分割element用的，并不会保存到实质文件
class WenSplitElement extends WenElement {
  WenSplitElement({super.type = "split"});

  @override
  String getMarkDown({FilePathBuilder? filePathBuilder}) {
    return "";
  }
}

class WenElementStyle {
  String? type;
  int? level;
  int? color;
  int? background;
  bool? bold;
  bool? italic;
  double? fontSize;
  String? fontFamily;
  bool newLine;

  String? url;
  String? src;

  bool? lineThrough;

  bool? underline;
  bool? remark;

  int? indent;

  String? itemType;

  String? alignment;

  WenElementStyle copy() {
    return WenElementStyle(
      type: type,
      color: color,
      background: background,
      bold: bold,
      italic: italic,
      fontSize: fontSize,
      fontFamily: fontFamily,
      lineThrough: lineThrough,
      underline: underline,
      url: url,
      level: level,
      src: src,
      newLine: newLine,
      indent: indent,
      itemType: itemType,
    );
  }

  WenElementStyle({
    this.type,
    this.color,
    this.background,
    this.bold,
    this.italic,
    this.fontSize,
    this.fontFamily,
    this.lineThrough,
    this.remark,
    this.underline,
    this.url,
    this.src,
    this.level,
    this.newLine = false,
    this.indent,
    this.itemType,
  });
}
