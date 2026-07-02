import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/model/table_model.dart';
import 'document_errors.dart';

class LegacyWenJsonCodec {
  const LegacyWenJsonCodec();

  /// Decodes legacy `wenz_editor` JSON (a block list, or `{"blocks": [...]}`)
  /// into a [RichTextDocument].
  ///
  /// Always throws a [DocumentDecodeException] on failure; the originating
  /// error is preserved on [DocumentDecodeException.raw]. Non-`Map` entries
  /// inside the block list are skipped (with a debug-mode warning) rather
  /// than aborting the whole decode.
  RichTextDocument decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw DocumentDecodeException(
        'Source is not valid JSON.',
        raw: error,
      );
    }
    try {
      if (decoded is List) {
        return RichTextDocument(blocks: _decodeBlocks(decoded));
      }
      if (decoded is Map && decoded['blocks'] is List) {
        return RichTextDocument(
          blocks: _decodeBlocks(decoded['blocks'] as List),
        );
      }
      throw const DocumentDecodeException(
        'Legacy Wen JSON must be a block list.',
      );
    } on DocumentDecodeException {
      rethrow;
    } on Object catch (error) {
      throw DocumentDecodeException(
        'Failed to inflate legacy document.',
        raw: error,
      );
    }
  }

  List<BlockNode> _decodeBlocks(List<Object?> values) {
    final blocks = <BlockNode>[];
    for (var i = 0; i < values.length; i++) {
      final entry = values[i];
      if (entry is Map) {
        blocks
            .add(_decodeElement(Map<String, Object?>.from(entry), 'legacy-$i'));
      } else if (kDebugMode) {
        debugPrint(
          'LegacyWenJsonCodec: skipping non-object block at index $i '
          '(${entry.runtimeType}).',
        );
      }
    }
    return blocks;
  }

  BlockNode _decodeElement(Map<String, Object?> json, String id) {
    final legacyType = json['type'] as String? ?? 'text';
    switch (legacyType) {
      case 'title':
        return TextBlockNode(
          id: id,
          type: BlockType.heading,
          attributes: _blockAttributes(json, fallbackLevel: 1),
          content: _textContent(json),
        );
      case 'quote':
        return TextBlockNode(
          id: id,
          type: BlockType.quote,
          attributes: _blockAttributes(json),
          content: _textContent(json),
        );
      case 'text':
        final attrs = _blockAttributes(json);
        return TextBlockNode(
          id: id,
          type:
              attrs.listType == null ? BlockType.paragraph : BlockType.listItem,
          attributes: attrs,
          content: _textContent(json),
        );
      case 'code':
        return CodeBlockNode(
          id: id,
          code: json['code'] as String? ?? '',
          language: json['language'] as String? ?? '',
          attributes: _blockAttributes(json),
        );
      case 'image':
        return ImageBlockNode(
          id: id,
          assetId: json['id'] as String? ?? '',
          file: json['file'] as String? ?? '',
          width: _asInt(json['width']),
          height: _asInt(json['height']),
          showWidth: _asDouble(json['showWidth']),
          showHeight: _asDouble(json['showHeight']),
          attributes: _blockAttributes(json),
        );
      case 'table':
        return TableBlockNode(
          id: id,
          table: _tableModel(json, id),
          attributes: _blockAttributes(json),
        );
      case 'line':
        return DividerBlockNode(id: id, attributes: _blockAttributes(json));
      case 'video':
        return _videoBlock(json, id);
      default:
        return TextBlockNode(
          id: id,
          type: BlockType.paragraph,
          attributes: _blockAttributes(json),
          content: _textContent(json),
        );
    }
  }

  VideoBlockNode _videoBlock(Map<String, Object?> json, String id) {
    return VideoBlockNode(
      id: id,
      assetId: _firstString(json, const <String>[
        'assetId',
        'id',
        'videoId',
        'asset',
      ]),
      playbackUrl: _firstString(json, const <String>[
        'playbackUrl',
        'url',
        'src',
        'source',
        'videoUrl',
      ]),
      file: _firstString(json, const <String>['file', 'localFile', 'path']),
      coverUrl: _firstString(json, const <String>[
        'coverUrl',
        'poster',
        'thumbnail',
        'cover',
      ]),
      title: _firstString(json, const <String>['title', 'caption', 'name']),
      description: _firstString(json, const <String>['description', 'desc']),
      aspectRatio: _positiveDouble(json['aspectRatio']) ??
          _aspectRatioFromSize(json['width'], json['height']),
      uploadStatus: FileUploadStatus.parse(
        _firstString(json, const <String>['uploadStatus', 'status']),
      ),
      uploadError: _firstString(json, const <String>['uploadError', 'error']),
      attributes: _blockAttributes(json),
    );
  }

  BlockAttributes _blockAttributes(
    Map<String, Object?> json, {
    int? fallbackLevel,
  }) {
    final itemType = json['itemType'] as String?;
    return BlockAttributes(
      level: _asNullableInt(json['level']) ?? fallbackLevel,
      indent: _asNullableInt(json['indent']),
      alignment: json['alignment'] as String?,
      listType: _isListType(itemType) ? itemType : null,
      checked: json['checked'] as bool?,
      childNote: json['childNote'] as String?,
    );
  }

  List<InlineNode> _textContent(Map<String, Object?> json) {
    final parentAttrs = _textAttributes(json);
    final result = <InlineNode>[];
    final text = json['text'] as String?;
    if (text != null && text.isNotEmpty) {
      result.add(TextRun(text: text, attributes: parentAttrs));
    }

    final children = json['children'];
    if (children is List) {
      for (final child in children.whereType<Map>()) {
        result.add(_inlineNode(Map<String, Object?>.from(child), parentAttrs));
      }
    }

    return result;
  }

  InlineNode _inlineNode(
    Map<String, Object?> json,
    TextAttributes parentAttrs,
  ) {
    final attrs = _textAttributes(json).inheritFrom(parentAttrs);
    final itemType = json['itemType'] as String?;
    if (itemType == 'formula') {
      return InlineEmbed(
        embedType: 'formula',
        data: <String, Object?>{'text': json['text'] as String? ?? ''},
        attributes: attrs,
      );
    }
    if (itemType == 'image') {
      return InlineEmbed(
        embedType: 'image',
        data: <String, Object?>{'id': json['id'], 'text': json['text']},
        attributes: attrs,
      );
    }
    return TextRun(text: json['text'] as String? ?? '', attributes: attrs);
  }

  TextAttributes _textAttributes(Map<String, Object?> json) {
    return TextAttributes(
      color: _asNullableInt(json['color']),
      background: _asNullableInt(json['background']),
      bold: json['bold'] as bool?,
      italic: json['italic'] as bool?,
      fontSize: _asDouble(json['fontSize']),
      underline: json['underline'] as bool?,
      lineThrough: json['lineThrough'] as bool?,
      remark: json['remark'] as bool?,
      url: json['url'] as String?,
    );
  }

  TableModel _tableModel(Map<String, Object?> json, String id) {
    final alignments = json['alignments'];
    final rows = json['rows'];
    return TableModel(
      columnAlignments: alignments is Map
          ? <int, String>{
              for (final entry in alignments.entries)
                if (_asNullableInt(entry.key) != null)
                  _asNullableInt(entry.key)!: entry.value as String,
            }
          : const <int, String>{},
      rows: rows is List
          ? <List<TableCellNode>>[
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                if (rows[rowIndex] is List)
                  <TableCellNode>[
                    for (var colIndex = 0;
                        colIndex < (rows[rowIndex] as List).length;
                        colIndex++)
                      if ((rows[rowIndex] as List)[colIndex] is Map)
                        _tableCell(
                          Map<String, Object?>.from(
                            (rows[rowIndex] as List)[colIndex] as Map,
                          ),
                          '$id-r$rowIndex-c$colIndex',
                        ),
                  ],
            ]
          : const <List<TableCellNode>>[],
    );
  }

  TableCellNode _tableCell(Map<String, Object?> json, String id) {
    final alignment = json['alignment'];
    return TableCellNode(
      id: id,
      blocks: <BlockNode>[_decodeElement(json, id)],
      alignment:
          alignment is String && alignment.isNotEmpty ? alignment : null,
    );
  }

  bool _isListType(String? itemType) {
    return itemType == 'li' || itemType == 'oli' || itemType == 'check';
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

int? _asNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
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
    return value.trim();
  }
  return value.toString().trim();
}

String _firstString(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = _asString(json[key]);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

double? _positiveDouble(Object? value) {
  final parsed = _asDouble(value);
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _aspectRatioFromSize(Object? width, Object? height) {
  final parsedWidth = _positiveDouble(width);
  final parsedHeight = _positiveDouble(height);
  if (parsedWidth == null || parsedHeight == null) {
    return null;
  }
  return parsedWidth / parsedHeight;
}
