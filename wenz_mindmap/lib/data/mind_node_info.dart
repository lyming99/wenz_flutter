import 'package:uuid/uuid.dart';

class MindNodeInfo {
  String? uuid;
  String? parentId;

  // 文本、图片、公式
  String? nodeType;
  bool? isTodo;
  bool? isChecked;
  String? content;
  int? fontColor;
  int? backgroundColor;
  int? borderColor;
  double? fontSize;
  double? borderWidth;
  double? borderRadius;
  double? width;
  double? height;
  double? padding;
  double? margin;
  String? link;
  bool? expand;
  double? rootX;
  double? rootY;
  int? index;
  String? note;

  String? linkTitle;
  String? wenzLink;

  String? image;
  int? imageWidth;
  int? imageHeight;
  double? imageShowWidth;
  double? imageShowHeight;

  String? formula;
  double? formulaWidth;
  double? formulaHeight;

  MindNodeInfo({
    this.content,
    this.link,
    this.uuid,
    this.parentId,
    this.nodeType,
    this.fontColor,
    this.backgroundColor,
    this.borderColor,
    this.fontSize,
    this.borderWidth,
    this.borderRadius,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.expand,
    this.rootX,
    this.rootY,
    this.index,
    this.isChecked,
    this.isTodo,
    this.linkTitle,
    this.note,
    this.wenzLink,
    this.image,
    this.imageWidth,
    this.imageHeight,
    this.imageShowWidth,
    this.imageShowHeight,
    this.formula,
    this.formulaWidth,
    this.formulaHeight,
  }) {
    uuid ??= const Uuid().v1();
  }

  // copy
  MindNodeInfo copyWith({
    String? uuid,
    String? parentId,
    String? nodeType,
    String? content,
    int? fontColor,
    int? backgroundColor,
    int? borderColor,
    double? fontSize,
    double? borderWidth,
    double? borderRadius,
    double? width,
    double? height,
    double? padding,
    double? margin,
    String? link,
    String? wenzLink,
    bool? expand,
    double? rootX,
    double? rootY,
    int? index,
    bool? isTodo,
    bool? isChecked,
    String? note,
    String? linkTitle,
    String? image,
    int? imageWidth,
    int? imageHeight,
    double? imageShowWidth,
    double? imageShowHeight,
    String? formula,
    double? formulaWidth,
    double? formulaHeight,
  }) {
    return MindNodeInfo(
      uuid: uuid ?? this.uuid,
      parentId: parentId ?? this.parentId,
      nodeType: nodeType ?? this.nodeType,
      content: content ?? this.content,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      fontSize: fontSize ?? this.fontSize,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      width: width ?? this.width,
      height: height ?? this.height,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      link: link ?? this.link,
      wenzLink: wenzLink ?? this.wenzLink,
      expand: expand ?? this.expand,
      rootX: rootX ?? this.rootX,
      rootY: rootY ?? this.rootY,
      index: index ?? this.index,
      isTodo: isTodo ?? this.isTodo,
      isChecked: isChecked ?? this.isChecked,
      note: note ?? this.note,
      linkTitle: linkTitle ?? this.linkTitle,
      image: image ?? this.image,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      imageShowWidth: imageShowWidth ?? this.imageShowWidth,
      imageShowHeight: imageShowHeight ?? this.imageShowHeight,
      formula: formula ?? this.formula,
      formulaWidth: formulaWidth ?? this.formulaWidth,
      formulaHeight: formulaHeight ?? this.formulaHeight,
    );
  }

  factory MindNodeInfo.fromJson(Map<String, dynamic> json) {
    return MindNodeInfo(
      uuid: json['uuid'] as String?,
      parentId: json['parentId'] as String?,
      nodeType: json['nodeType'] as String?,
      content: json['content'] as String?,
      fontColor: json['fontColor'] as int?,
      backgroundColor: json['backgroundColor'] as int?,
      borderColor: json['borderColor'] as int?,
      fontSize: json['fontSize']?.toDouble(),
      borderWidth: json['borderWidth']?.toDouble(),
      borderRadius: json['borderRadius']?.toDouble(),
      width: json['width']?.toDouble(),
      height: json['height']?.toDouble(),
      padding: json['padding']?.toDouble(),
      margin: json['margin']?.toDouble(),
      link: json['link'] as String?,
      wenzLink: json['wenzLink'] as String?,
      expand: json['expand'] as bool?,
      rootX: json['rootX']?.toDouble(),
      rootY: json['rootY']?.toDouble(),
      index: json['index'] as int?,
      isTodo: json['isTodo'] as bool?,
      isChecked: json['isChecked'] as bool?,
      note: json['note'] as String?,
      linkTitle: json['linkTitle'] as String?,
      image: json['image'] as String?,
      imageWidth: json['imageWidth'] as int?,
      imageHeight: json['imageHeight'] as int?,
      imageShowWidth: json['imageShowWidth']?.toDouble(),
      imageShowHeight: json['imageShowHeight']?.toDouble(),
      formula: json['formula'] as String?,
      formulaWidth: json['formulaWidth']?.toDouble(),
      formulaHeight: json['formulaHeight']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'parentId': parentId,
      'nodeType': nodeType,
      'content': content,
      'fontColor': fontColor,
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'fontSize': fontSize,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
      'width': width,
      'height': height,
      'padding': padding,
      'margin': margin,
      'link': link,
      'wenzLink': wenzLink,
      'expand': expand,
      'rootX': rootX,
      'rootY': rootY,
      'index': index,
      'isTodo': isTodo,
      'isChecked': isChecked,
      'note': note,
      'linkTitle': linkTitle,
      'image': image,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'imageShowWidth': imageShowWidth,
      'imageShowHeight': imageShowHeight,
      'formula': formula,
      'formulaWidth': formulaWidth,
      'formulaHeight': formulaHeight,
    };
  }
}
