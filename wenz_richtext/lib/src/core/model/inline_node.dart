import 'attributes.dart';

const List<String> formulaTextDataKeys = <String>[
  'text',
  'latex',
  'value',
  'formula',
];

bool isFormulaEmbedType(String embedType) => embedType.trim() == 'formula';

String formulaTextFromData(
  Map<String, Object?> data, {
  String fallbackText = '',
}) {
  final fallback = fallbackText.trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }
  for (final key in formulaTextDataKeys) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

Map<String, Object?> formulaDataWithText(
  Map<String, Object?> data,
  String text,
) {
  final normalizedText = text.trim();
  return <String, Object?>{
    ...data,
    for (final key in formulaTextDataKeys) key: normalizedText,
  };
}

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

/// Coalesces adjacent text runs with identical attributes while preserving the
/// original list instance when it is already compact.
List<InlineNode> mergeAdjacentTextRuns(List<InlineNode> nodes) {
  List<InlineNode>? result;
  for (var index = 0; index < nodes.length; index++) {
    final node = nodes[index];
    final previous = result == null
        ? (index == 0 ? null : nodes[index - 1])
        : (result.isEmpty ? null : result.last);
    if (node is TextRun &&
        previous is TextRun &&
        previous.attributes == node.attributes) {
      result ??= nodes.sublist(0, index);
      result[result.length - 1] = TextRun(
        text: previous.text + node.text,
        attributes: previous.attributes,
      );
      continue;
    }
    result?.add(node);
  }
  return result ?? nodes;
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

  String get normalizedEmbedType {
    final value = embedType.trim();
    return value.isEmpty ? 'custom' : value;
  }

  bool get isFormula => isFormulaEmbedType(normalizedEmbedType);

  String get formulaText => formulaTextFromData(data);

  @override
  String get plainText => isFormula ? ' ' : '\uFFFC';

  @override
  InlineEmbed copy() {
    return InlineEmbed(
      embedType: embedType,
      data: Map<String, Object?>.from(data),
      attributes: attributes,
    );
  }

  InlineEmbed copyWith({
    String? embedType,
    Map<String, Object?>? data,
    TextAttributes? attributes,
  }) {
    return InlineEmbed(
      embedType: embedType ?? this.embedType,
      data: data ?? this.data,
      attributes: attributes ?? this.attributes,
    );
  }

  InlineEmbed copyWithFormulaText(String text) {
    return copyWith(data: formulaDataWithText(data, text));
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
