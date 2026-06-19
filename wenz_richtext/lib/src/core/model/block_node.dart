import 'attributes.dart';
import 'inline_node.dart';
import 'table_model.dart';

enum BlockType {
  paragraph('paragraph'),
  heading('heading'),
  quote('quote'),
  listItem('listItem'),
  code('code'),
  image('image'),
  table('table'),
  divider('divider'),
  video('video'),
  callout('callout'),
  file('file');

  const BlockType(this.name);

  final String name;

  static BlockType parse(Object? value) {
    final text = value?.toString();
    return BlockType.values.firstWhere(
      (type) => type.name == text,
      orElse: () => BlockType.paragraph,
    );
  }
}

abstract class BlockNode {
  const BlockNode({
    required this.id,
    required this.type,
    this.attributes = const BlockAttributes(),
  });

  final String id;
  final BlockType type;
  final BlockAttributes attributes;

  String get plainText;

  Map<String, Object?> toJson();

  BlockNode copy();

  static BlockNode fromJson(Map<String, Object?> json) {
    final type = BlockType.parse(json['type']);
    switch (type) {
      case BlockType.heading:
      case BlockType.paragraph:
      case BlockType.quote:
      case BlockType.listItem:
        return TextBlockNode.fromJson(json);
      case BlockType.code:
        return CodeBlockNode.fromJson(json);
      case BlockType.image:
        return ImageBlockNode.fromJson(json);
      case BlockType.table:
        return TableBlockNode.fromJson(json);
      case BlockType.divider:
        return DividerBlockNode.fromJson(json);
      case BlockType.video:
        return VideoBlockNode.fromJson(json);
      case BlockType.callout:
        return CalloutBlockNode.fromJson(json);
      case BlockType.file:
        return FileBlockNode.fromJson(json);
    }
  }

  Map<String, Object?> baseJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      if (!attributes.isEmpty) 'attrs': attributes.toJson(),
    };
  }

  static BlockAttributes attrsFromJson(Map<String, Object?> json) {
    final attrs = json['attrs'];
    return attrs is Map
        ? BlockAttributes.fromJson(Map<String, Object?>.from(attrs))
        : const BlockAttributes();
  }
}

class TextBlockNode extends BlockNode {
  const TextBlockNode({
    required super.id,
    required super.type,
    super.attributes,
    this.content = const <InlineNode>[],
  }) : assert(
          type == BlockType.paragraph ||
              type == BlockType.heading ||
              type == BlockType.quote ||
              type == BlockType.listItem,
        );

  final List<InlineNode> content;

  @override
  String get plainText => content.map((node) => node.plainText).join();

  @override
  TextBlockNode copy() {
    return TextBlockNode(
      id: id,
      type: type,
      attributes: attributes,
      content: content.map((node) => node.copy()).toList(),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'content': content.map((node) => node.toJson()).toList(),
      });
  }

  factory TextBlockNode.fromJson(Map<String, Object?> json) {
    final rawContent = json['content'];
    return TextBlockNode(
      id: json['id'] as String? ?? '',
      type: BlockType.parse(json['type']),
      attributes: BlockNode.attrsFromJson(json),
      content: rawContent is List
          ? rawContent
              .whereType<Map>()
              .map(
                (node) => InlineNode.fromJson(Map<String, Object?>.from(node)),
              )
              .toList()
          : const <InlineNode>[],
    );
  }
}

class CodeBlockNode extends BlockNode {
  const CodeBlockNode({
    required super.id,
    required this.code,
    this.language = '',
    super.attributes,
  }) : super(type: BlockType.code);

  final String code;
  final String language;

  @override
  String get plainText => code;

  @override
  CodeBlockNode copy() {
    return CodeBlockNode(
      id: id,
      code: code,
      language: language,
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'code': code,
        if (language.isNotEmpty) 'language': language,
      });
  }

  factory CodeBlockNode.fromJson(Map<String, Object?> json) {
    return CodeBlockNode(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      language: json['language'] as String? ?? '',
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

class ImageBlockNode extends BlockNode {
  const ImageBlockNode({
    required super.id,
    required this.assetId,
    this.file = '',
    this.width = 0,
    this.height = 0,
    this.showWidth,
    this.showHeight,
    super.attributes,
  }) : super(type: BlockType.image);

  final String assetId;
  final String file;
  final int width;
  final int height;
  final double? showWidth;
  final double? showHeight;

  @override
  String get plainText => '';

  @override
  ImageBlockNode copy() {
    return ImageBlockNode(
      id: id,
      assetId: assetId,
      file: file,
      width: width,
      height: height,
      showWidth: showWidth,
      showHeight: showHeight,
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'assetId': assetId,
        if (file.isNotEmpty) 'file': file,
        'width': width,
        'height': height,
        if (showWidth != null) 'showWidth': showWidth,
        if (showHeight != null) 'showHeight': showHeight,
      });
  }

  factory ImageBlockNode.fromJson(Map<String, Object?> json) {
    return ImageBlockNode(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      file: json['file'] as String? ?? '',
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      showWidth: _asDouble(json['showWidth']),
      showHeight: _asDouble(json['showHeight']),
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

class TableBlockNode extends BlockNode {
  const TableBlockNode({
    required super.id,
    required this.table,
    super.attributes,
  }) : super(type: BlockType.table);

  final TableModel table;

  @override
  String get plainText => table.plainText;

  @override
  TableBlockNode copy() {
    return TableBlockNode(
      id: id,
      table: TableModel(
        rows: table.rows
            .map(
              (row) => row
                  .map(
                    (cell) => TableCellNode(
                      id: cell.id,
                      blocks: cell.blocks.map((block) => block.copy()).toList(),
                      rowSpan: cell.rowSpan,
                      columnSpan: cell.columnSpan,
                      isHeader: cell.isHeader,
                      backgroundColor: cell.backgroundColor,
                      covered: cell.covered,
                    ),
                  )
                  .toList(),
            )
            .toList(),
        columnAlignments: Map<int, String>.from(table.columnAlignments),
        columnWidths: Map<int, double>.from(table.columnWidths),
      ),
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()..addAll(<String, Object?>{'table': table.toJson()});
  }

  factory TableBlockNode.fromJson(Map<String, Object?> json) {
    final table = json['table'];
    return TableBlockNode(
      id: json['id'] as String? ?? '',
      table: table is Map
          ? TableModel.fromJson(Map<String, Object?>.from(table))
          : const TableModel(),
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

class DividerBlockNode extends BlockNode {
  const DividerBlockNode({required super.id, super.attributes})
      : super(type: BlockType.divider);

  @override
  String get plainText => '';

  @override
  DividerBlockNode copy() {
    return DividerBlockNode(id: id, attributes: attributes);
  }

  @override
  Map<String, Object?> toJson() => baseJson();

  factory DividerBlockNode.fromJson(Map<String, Object?> json) {
    return DividerBlockNode(
      id: json['id'] as String? ?? '',
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

class VideoBlockNode extends BlockNode {
  const VideoBlockNode({
    required super.id,
    required this.assetId,
    this.file = '',
    super.attributes,
  }) : super(type: BlockType.video);

  final String assetId;
  final String file;

  @override
  String get plainText => '';

  @override
  VideoBlockNode copy() {
    return VideoBlockNode(
      id: id,
      assetId: assetId,
      file: file,
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'assetId': assetId,
        if (file.isNotEmpty) 'file': file,
      });
  }

  factory VideoBlockNode.fromJson(Map<String, Object?> json) {
    return VideoBlockNode(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      file: json['file'] as String? ?? '',
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

/// A callout block: emphasised text in a tinted box, optionally carrying a
/// variant (e.g. `'info'`, `'warning'`) for styling.
class CalloutBlockNode extends BlockNode {
  const CalloutBlockNode({
    required super.id,
    required this.content,
    this.variant = 'info',
    super.attributes,
  }) : super(type: BlockType.callout);

  final List<InlineNode> content;
  final String variant;

  @override
  String get plainText => content.map((node) => node.plainText).join();

  @override
  CalloutBlockNode copy() {
    return CalloutBlockNode(
      id: id,
      content: content.map((node) => node.copy()).toList(),
      variant: variant,
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'content': content.map((node) => node.toJson()).toList(),
        if (variant.isNotEmpty && variant != 'info') 'variant': variant,
      });
  }

  factory CalloutBlockNode.fromJson(Map<String, Object?> json) {
    final rawContent = json['content'];
    return CalloutBlockNode(
      id: json['id'] as String? ?? '',
      variant: json['variant'] as String? ?? 'info',
      content: rawContent is List
          ? rawContent
              .whereType<Map>()
              .map((node) =>
                  InlineNode.fromJson(Map<String, Object?>.from(node)))
              .toList()
          : const <InlineNode>[],
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

/// A generic file/attachment block. Rendered as a placeholder chip; full
/// attachment workflows land in a later stage.
class FileBlockNode extends BlockNode {
  const FileBlockNode({
    required super.id,
    required this.assetId,
    this.name = '',
    this.size = 0,
    this.file = '',
    super.attributes,
  }) : super(type: BlockType.file);

  final String assetId;
  final String name;
  final int size;
  final String file;

  @override
  String get plainText => name;

  @override
  FileBlockNode copy() {
    return FileBlockNode(
      id: id,
      assetId: assetId,
      name: name,
      size: size,
      file: file,
      attributes: attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'assetId': assetId,
        if (name.isNotEmpty) 'name': name,
        'size': size,
        if (file.isNotEmpty) 'file': file,
      });
  }

  factory FileBlockNode.fromJson(Map<String, Object?> json) {
    return FileBlockNode(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: _asInt(json['size']),
      file: json['file'] as String? ?? '',
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

double? _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
