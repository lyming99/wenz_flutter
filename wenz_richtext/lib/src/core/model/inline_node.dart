import 'attributes.dart';

abstract class InlineNode {
  const InlineNode();

  String get plainText;

  Map<String, Object?> toJson();

  InlineNode copy();

  static InlineNode fromJson(Map<String, Object?> json) {
    final type = json['type'];
    if (type == 'embed') {
      return InlineEmbed.fromJson(json);
    }
    return TextRun.fromJson(json);
  }
}

class TextRun extends InlineNode {
  const TextRun({required this.text, this.attributes = const TextAttributes()});

  final String text;
  final TextAttributes attributes;

  @override
  String get plainText => text;

  @override
  TextRun copy() {
    return TextRun(text: text, attributes: attributes);
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': 'text',
      'text': text,
      if (!attributes.isEmpty) 'attrs': attributes.toJson(),
    };
  }

  factory TextRun.fromJson(Map<String, Object?> json) {
    final attrs = json['attrs'];
    return TextRun(
      text: json['text'] as String? ?? '',
      attributes: attrs is Map
          ? TextAttributes.fromJson(Map<String, Object?>.from(attrs))
          : const TextAttributes(),
    );
  }
}

class InlineEmbed extends InlineNode {
  const InlineEmbed({
    required this.embedType,
    this.data = const <String, Object?>{},
    this.attributes = const TextAttributes(),
  });

  final String embedType;
  final Map<String, Object?> data;
  final TextAttributes attributes;

  @override
  String get plainText => embedType == 'formula' ? ' ' : '\uFFFC';

  @override
  InlineEmbed copy() {
    return InlineEmbed(
      embedType: embedType,
      data: Map<String, Object?>.from(data),
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': 'embed',
      'embedType': embedType,
      if (data.isNotEmpty) 'data': data,
      if (!attributes.isEmpty) 'attrs': attributes.toJson(),
    };
  }

  factory InlineEmbed.fromJson(Map<String, Object?> json) {
    final attrs = json['attrs'];
    final data = json['data'];
    return InlineEmbed(
      embedType: json['embedType'] as String? ?? 'unknown',
      data: data is Map
          ? Map<String, Object?>.from(data)
          : const <String, Object?>{},
      attributes: attrs is Map
          ? TextAttributes.fromJson(Map<String, Object?>.from(attrs))
          : const TextAttributes(),
    );
  }
}
