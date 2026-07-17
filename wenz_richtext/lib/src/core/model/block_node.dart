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
  embed('embed'),
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

enum FileUploadStatus {
  none('none'),
  pending('pending'),
  uploading('uploading'),
  uploaded('uploaded'),
  failed('failed');

  const FileUploadStatus(this.name);

  final String name;

  static FileUploadStatus parse(Object? value) {
    if (value is FileUploadStatus) {
      return value;
    }
    final text = value?.toString();
    return FileUploadStatus.values.firstWhere(
      (status) => status.name == text,
      orElse: () => FileUploadStatus.none,
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
      case BlockType.embed:
        return BlockEmbedNode.fromJson(json);
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
    final type = BlockType.parse(json['type']);
    final attrs = BlockNode.attrsFromJson(json);
    final legacyQuote = type == BlockType.quote;
    return TextBlockNode(
      id: json['id'] as String? ?? '',
      type: legacyQuote ? BlockType.paragraph : type,
      attributes: legacyQuote
          ? attrs.mergeWith(const BlockAttributes(quoted: true))
          : attrs,
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
    this.caption = '',
    this.altText = '',
    super.attributes,
  }) : super(type: BlockType.image);

  final String assetId;
  final String file;
  final int width;
  final int height;
  final double? showWidth;
  final double? showHeight;
  final String caption;
  final String altText;

  @override
  String get plainText => caption;

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
      caption: caption,
      altText: altText,
      attributes: attributes,
    );
  }

  ImageBlockNode copyWith({
    String? id,
    String? assetId,
    String? file,
    int? width,
    int? height,
    double? showWidth,
    double? showHeight,
    bool clearShowWidth = false,
    bool clearShowHeight = false,
    String? caption,
    String? altText,
    BlockAttributes? attributes,
  }) {
    return ImageBlockNode(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      file: file ?? this.file,
      width: width ?? this.width,
      height: height ?? this.height,
      showWidth: clearShowWidth ? null : showWidth ?? this.showWidth,
      showHeight: clearShowHeight ? null : showHeight ?? this.showHeight,
      caption: caption ?? this.caption,
      altText: altText ?? this.altText,
      attributes: attributes ?? this.attributes,
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
        if (caption.isNotEmpty) 'caption': caption,
        if (altText.isNotEmpty) 'altText': altText,
      });
  }

  factory ImageBlockNode.fromJson(Map<String, Object?> json) {
    final alt = json['altText'] ?? json['alt'];
    return ImageBlockNode(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      file: json['file'] as String? ?? '',
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      showWidth: _asDouble(json['showWidth']),
      showHeight: _asDouble(json['showHeight']),
      caption: json['caption'] as String? ?? '',
      altText: alt as String? ?? '',
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
                      alignment: cell.alignment,
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
  static const double defaultAspectRatio = 16 / 9;

  const VideoBlockNode({
    required super.id,
    required this.assetId,
    this.playbackUrl = '',
    this.file = '',
    this.coverUrl = '',
    this.title = '',
    this.description = '',
    this.aspectRatio,
    this.showWidth,
    this.showHeight,
    this.uploadStatus = FileUploadStatus.none,
    this.uploadError = '',
    super.attributes,
  }) : super(type: BlockType.video);

  final String assetId;
  final String playbackUrl;
  final String file;
  final String coverUrl;
  final String title;
  final String description;
  final double? aspectRatio;
  final double? showWidth;
  final double? showHeight;
  final FileUploadStatus uploadStatus;
  final String uploadError;

  bool get hasSource =>
      assetId.trim().isNotEmpty ||
      playbackUrl.trim().isNotEmpty ||
      file.trim().isNotEmpty;

  String get effectivePlaybackUrl {
    final remote = playbackUrl.trim();
    if (remote.isNotEmpty) {
      return remote;
    }
    final local = file.trim();
    if (local.isNotEmpty) {
      return local;
    }
    return assetId.trim();
  }

  String get displayText {
    final heading = title.trim();
    if (heading.isNotEmpty) {
      return heading;
    }
    final body = description.trim();
    if (body.isNotEmpty) {
      return body;
    }
    return effectivePlaybackUrl;
  }

  double get effectiveAspectRatio =>
      _positiveDouble(aspectRatio) ?? defaultAspectRatio;

  @override
  String get plainText => displayText;

  @override
  VideoBlockNode copy() {
    return VideoBlockNode(
      id: id,
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: title,
      description: description,
      aspectRatio: aspectRatio,
      showWidth: showWidth,
      showHeight: showHeight,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
      attributes: attributes,
    );
  }

  VideoBlockNode copyWith({
    String? id,
    String? assetId,
    String? playbackUrl,
    String? file,
    String? coverUrl,
    String? title,
    String? description,
    double? aspectRatio,
    bool clearAspectRatio = false,
    double? showWidth,
    double? showHeight,
    bool clearShowWidth = false,
    bool clearShowHeight = false,
    FileUploadStatus? uploadStatus,
    String? uploadError,
    BlockAttributes? attributes,
  }) {
    return VideoBlockNode(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      file: file ?? this.file,
      coverUrl: coverUrl ?? this.coverUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      aspectRatio: clearAspectRatio ? null : aspectRatio ?? this.aspectRatio,
      showWidth: clearShowWidth ? null : showWidth ?? this.showWidth,
      showHeight: clearShowHeight ? null : showHeight ?? this.showHeight,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    final ratio = _positiveDouble(aspectRatio);
    return baseJson()
      ..addAll(<String, Object?>{
        'assetId': assetId,
        if (playbackUrl.isNotEmpty) 'playbackUrl': playbackUrl,
        if (file.isNotEmpty) 'file': file,
        if (coverUrl.isNotEmpty) 'coverUrl': coverUrl,
        if (title.isNotEmpty) 'title': title,
        if (description.isNotEmpty) 'description': description,
        if (ratio != null) 'aspectRatio': ratio,
        if (showWidth != null) 'showWidth': showWidth,
        if (showHeight != null) 'showHeight': showHeight,
        if (uploadStatus != FileUploadStatus.none)
          'uploadStatus': uploadStatus.name,
        if (uploadError.isNotEmpty) 'uploadError': uploadError,
      });
  }

  factory VideoBlockNode.fromJson(Map<String, Object?> json) {
    return VideoBlockNode(
      id: _asString(json['id']),
      assetId: _asString(json['assetId']),
      playbackUrl:
          _firstString(json, const <String>['playbackUrl', 'url', 'src']),
      file: _firstString(json, const <String>['file', 'localFile']),
      coverUrl: _firstString(
        json,
        const <String>['coverUrl', 'poster', 'thumbnail', 'cover'],
      ),
      title: _firstString(json, const <String>['title', 'caption']),
      description: _firstString(json, const <String>['description', 'desc']),
      aspectRatio: _videoAspectRatioFromJson(json),
      showWidth: _asDouble(json['showWidth']),
      showHeight: _asDouble(json['showHeight']),
      uploadStatus: FileUploadStatus.parse(json['uploadStatus']),
      uploadError: _asString(json['uploadError']),
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

class BlockEmbedNode extends BlockNode {
  const BlockEmbedNode({
    required super.id,
    required this.embedType,
    this.data = const <String, Object?>{},
    this.fallbackText = '',
    super.attributes,
  }) : super(type: BlockType.embed);

  final String embedType;
  final Map<String, Object?> data;
  final String fallbackText;

  String get normalizedEmbedType {
    final value = embedType.trim();
    return value.isEmpty ? 'custom' : value;
  }

  bool get isFormula => isFormulaEmbedType(normalizedEmbedType);

  String get formulaText => formulaTextFromData(
        data,
        fallbackText: fallbackText,
      );

  String get displayText {
    final fallback = fallbackText.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    if (isFormula) {
      final formula = formulaTextFromData(data);
      if (formula.isNotEmpty) {
        return formula;
      }
    }
    for (final key in const <String>['title', 'label', 'name', 'url']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return normalizedEmbedType;
  }

  @override
  String get plainText => displayText;

  @override
  BlockEmbedNode copy() {
    return BlockEmbedNode(
      id: id,
      embedType: embedType,
      data: Map<String, Object?>.from(data),
      fallbackText: fallbackText,
      attributes: attributes,
    );
  }

  BlockEmbedNode copyWith({
    String? id,
    String? embedType,
    Map<String, Object?>? data,
    String? fallbackText,
    BlockAttributes? attributes,
  }) {
    return BlockEmbedNode(
      id: id ?? this.id,
      embedType: embedType ?? this.embedType,
      data: data ?? this.data,
      fallbackText: fallbackText ?? this.fallbackText,
      attributes: attributes ?? this.attributes,
    );
  }

  BlockEmbedNode copyWithFormulaText(String text) {
    final normalizedText = text.trim();
    return copyWith(
      data: formulaDataWithText(data, normalizedText),
      fallbackText: fallbackText.trim().isEmpty ? fallbackText : normalizedText,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'embedType': embedType,
        if (data.isNotEmpty) 'data': data,
        if (fallbackText.isNotEmpty) 'fallbackText': fallbackText,
      });
  }

  factory BlockEmbedNode.fromJson(Map<String, Object?> json) {
    final data = json['data'];
    return BlockEmbedNode(
      id: json['id'] as String? ?? '',
      embedType: json['embedType'] as String? ?? 'custom',
      data: data is Map
          ? Map<String, Object?>.from(data)
          : const <String, Object?>{},
      fallbackText: json['fallbackText'] as String? ?? '',
      attributes: BlockNode.attrsFromJson(json),
    );
  }
}

/// A callout block: emphasised text in a tinted box, optionally carrying a
/// variant (e.g. `'info'`, `'warning'`) for styling.
///
/// The editable body is [content] and is addressed by `PositionPath.blockText`
/// at command/widget boundaries. [variant], [title], [icon], and [attributes]
/// are block metadata, not part of the body text deletion range. Empty
/// [content] is still a valid callout block.
class CalloutBlockNode extends BlockNode {
  const CalloutBlockNode({
    required super.id,
    required this.content,
    this.variant = 'info',
    this.title = '',
    this.icon = '',
    super.attributes,
  }) : super(type: BlockType.callout);

  static const String infoVariant = 'info';
  static const String successVariant = 'success';
  static const String warningVariant = 'warning';
  static const String dangerVariant = 'danger';

  static const List<String> supportedVariants = <String>[
    infoVariant,
    successVariant,
    warningVariant,
    dangerVariant,
  ];

  final List<InlineNode> content;
  final String variant;
  final String title;
  final String icon;

  static String normalizeVariant(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (supportedVariants.contains(text)) {
      return text;
    }
    return infoVariant;
  }

  static String defaultTitleFor(String variant) {
    switch (normalizeVariant(variant)) {
      case successVariant:
        return 'Success';
      case warningVariant:
        return 'Warning';
      case dangerVariant:
        return 'Danger';
      case infoVariant:
      default:
        return 'Info';
    }
  }

  static String defaultIconFor(String variant) {
    switch (normalizeVariant(variant)) {
      case successVariant:
        return '✅';
      case warningVariant:
        return '⚠️';
      case dangerVariant:
        return '⛔';
      case infoVariant:
      default:
        return 'ℹ️';
    }
  }

  String get normalizedVariant => normalizeVariant(variant);

  String get effectiveTitle {
    final trimmed = title.trim();
    return trimmed.isEmpty ? defaultTitleFor(normalizedVariant) : trimmed;
  }

  String get effectiveIcon {
    final trimmed = icon.trim();
    return trimmed.isEmpty ? defaultIconFor(normalizedVariant) : trimmed;
  }

  @override
  String get plainText {
    final body = content.map((node) => node.plainText).join();
    final heading = title.trim();
    if (heading.isEmpty) {
      return body;
    }
    if (body.isEmpty) {
      return heading;
    }
    return '$heading\n$body';
  }

  @override
  CalloutBlockNode copy() {
    return CalloutBlockNode(
      id: id,
      content: content.map((node) => node.copy()).toList(),
      variant: variant,
      title: title,
      icon: icon,
      attributes: attributes,
    );
  }

  CalloutBlockNode copyWith({
    String? id,
    List<InlineNode>? content,
    String? variant,
    String? title,
    String? icon,
    BlockAttributes? attributes,
  }) {
    return CalloutBlockNode(
      id: id ?? this.id,
      content: content ?? this.content,
      variant: variant ?? this.variant,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'content': content.map((node) => node.toJson()).toList(),
        if (normalizedVariant != infoVariant) 'variant': normalizedVariant,
        if (title.trim().isNotEmpty) 'title': title.trim(),
        if (icon.trim().isNotEmpty) 'icon': icon.trim(),
      });
  }

  factory CalloutBlockNode.fromJson(Map<String, Object?> json) {
    final rawContent = json['content'];
    return CalloutBlockNode(
      id: json['id'] as String? ?? '',
      variant: normalizeVariant(json['variant']),
      title: (json['title'] as String? ?? '').trim(),
      icon: (json['icon'] as String? ?? '').trim(),
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

/// A generic file/attachment block.
///
/// [file] is kept for backward compatibility with early media blocks. New code
/// should prefer [downloadUrl] for the remote/download address and [mimeType]
/// plus [uploadStatus] for attachment workflow state.
class FileBlockNode extends BlockNode {
  const FileBlockNode({
    required super.id,
    required this.assetId,
    this.name = '',
    this.size = 0,
    this.mimeType = '',
    this.file = '',
    this.downloadUrl = '',
    this.uploadStatus = FileUploadStatus.none,
    this.uploadError = '',
    super.attributes,
  }) : super(type: BlockType.file);

  final String assetId;
  final String name;
  final int size;
  final String mimeType;
  final String file;
  final String downloadUrl;
  final FileUploadStatus uploadStatus;
  final String uploadError;

  String get displayName {
    if (name.isNotEmpty) {
      return name;
    }
    if (assetId.isNotEmpty) {
      return assetId;
    }
    if (downloadUrl.isNotEmpty) {
      return downloadUrl;
    }
    return file;
  }

  String get effectiveDownloadUrl {
    if (downloadUrl.isNotEmpty) {
      return downloadUrl;
    }
    if (file.isNotEmpty) {
      return file;
    }
    return assetId;
  }

  @override
  String get plainText => displayName;

  @override
  FileBlockNode copy() {
    return FileBlockNode(
      id: id,
      assetId: assetId,
      name: name,
      size: size,
      mimeType: mimeType,
      file: file,
      downloadUrl: downloadUrl,
      uploadStatus: uploadStatus,
      uploadError: uploadError,
      attributes: attributes,
    );
  }

  FileBlockNode copyWith({
    String? id,
    String? assetId,
    String? name,
    int? size,
    String? mimeType,
    String? file,
    String? downloadUrl,
    FileUploadStatus? uploadStatus,
    String? uploadError,
    BlockAttributes? attributes,
  }) {
    return FileBlockNode(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      name: name ?? this.name,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      file: file ?? this.file,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return baseJson()
      ..addAll(<String, Object?>{
        'assetId': assetId,
        if (name.isNotEmpty) 'name': name,
        'size': size,
        if (mimeType.isNotEmpty) 'mimeType': mimeType,
        if (file.isNotEmpty) 'file': file,
        if (downloadUrl.isNotEmpty) 'downloadUrl': downloadUrl,
        if (uploadStatus != FileUploadStatus.none)
          'uploadStatus': uploadStatus.name,
        if (uploadError.isNotEmpty) 'uploadError': uploadError,
      });
  }

  factory FileBlockNode.fromJson(Map<String, Object?> json) {
    return FileBlockNode(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: _asInt(json['size']),
      mimeType: json['mimeType'] as String? ?? '',
      file: json['file'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      uploadStatus: FileUploadStatus.parse(json['uploadStatus']),
      uploadError: json['uploadError'] as String? ?? '',
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
  if (value is String) {
    return int.tryParse(value) ?? 0;
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
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String _asString(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

String _firstString(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = _asString(json[key]);
    if (value.trim().isNotEmpty) {
      return value;
    }
  }
  return '';
}

double? _firstPositiveDouble(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = _positiveDouble(json[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

double? _positiveDouble(Object? value) {
  final number = _asDouble(value);
  if (number == null || number <= 0 || !number.isFinite) {
    return null;
  }
  return number;
}

double? _videoAspectRatioFromJson(Map<String, Object?> json) {
  final explicit =
      _firstPositiveDouble(json, const <String>['aspectRatio', 'ratio']);
  if (explicit != null) {
    return explicit;
  }
  final width = _positiveDouble(json['width']);
  final height = _positiveDouble(json['height']);
  if (width != null && height != null) {
    return width / height;
  }
  return null;
}
