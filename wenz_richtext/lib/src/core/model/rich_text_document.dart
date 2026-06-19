import 'block_node.dart';

class RichTextDocument {
  const RichTextDocument({this.version = 1, this.blocks = const <BlockNode>[]});

  final int version;
  final List<BlockNode> blocks;

  bool get isEmpty => blocks.isEmpty || plainText.isEmpty;

  String get plainText => blocks.map((block) => block.plainText).join('\n');

  RichTextDocument copy() {
    return RichTextDocument(
      version: version,
      blocks: blocks.map((block) => block.copy()).toList(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'blocks': blocks.map((block) => block.toJson()).toList(),
    };
  }

  factory RichTextDocument.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    return RichTextDocument(
      version: _asInt(json['version'], fallback: 1),
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (block) => BlockNode.fromJson(Map<String, Object?>.from(block)),
              )
              .toList()
          : const <BlockNode>[],
    );
  }
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}
