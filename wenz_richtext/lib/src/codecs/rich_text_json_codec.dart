import 'dart:convert';

import '../core/model/rich_text_document.dart';

class RichTextJsonCodec {
  const RichTextJsonCodec();

  String encode(RichTextDocument document) {
    return jsonEncode(document.toJson());
  }

  RichTextDocument decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Rich text JSON must be an object.');
    }
    return RichTextDocument.fromJson(Map<String, Object?>.from(decoded));
  }
}
