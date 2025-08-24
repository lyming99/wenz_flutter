import '../element/element.dart';

class WenImageElement extends WenElement {
  String id = "";
  String file = "";
  int width = 0;
  int height = 0;
  double? showWidth;
  double? showHeight;

  WenImageElement({
    required this.id,
    required this.file,
    required this.width,
    required this.height,
    super.type = "image",
    this.showWidth,
    this.showHeight,
    super.checked,
    super.childNote,
  });

  WenImageElement copy() {
    return WenImageElement(
      id: id,
      file: file,
      width: width,
      height: height,
      showWidth: showWidth,
      showHeight: showHeight,
    )..indent = indent;
  }

  @override
  String getHtml({FilePathBuilder? filePathBuilder}) {
    return '<img src="$file" id="$id" width="$width" height="$height" file="$file"/>';
  }

  @override
  String getMarkDown({FilePathBuilder? filePathBuilder}) {
    return "![](${filePathBuilder?.call(id) ?? ("assets/$id")})";
  }

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json.addAll({
      "id": id,
      "file": file,
      "width": width,
      "height": height,
      "showWidth": showWidth,
      "showHeight": showHeight,
    });
    return json;
  }

  factory WenImageElement.fromJson(Map<dynamic, dynamic> json) {
    return WenImageElement(
      id: json["id"] ?? "0",
      file: json["file"] ?? "",
      width: json["width"] ?? 0,
      height: json["height"] ?? 0,
      showWidth: json["showWidth"],
      showHeight: json["showHeight"],
    )..copyProperties(WenElement.fromJson(json));
  }
}
