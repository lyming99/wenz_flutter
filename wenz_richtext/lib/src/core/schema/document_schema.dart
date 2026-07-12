import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/persistent_block_list.dart';
import '../model/rich_text_document.dart';
import '../model/table_model.dart';

/// Document schema rules and the [normalize] pass that enforces them.
///
/// The editor has no schema enforcement at construction time (a
/// [RichTextDocument] can legally be empty, a [TableCellNode] can contain zero
/// blocks, and a [TextBlockNode]'s [BlockAttributes] can be inconsistent with
/// its [BlockType]). [normalize] is the single place that fixes all of these
/// so every command output, loaded JSON, and session default is well-formed.
///
/// Canonical `listType` values (after normalize): `'ordered'`, `'task'`, or
/// `null` (unordered). `listType` only describes the list marker/numbering
/// family; todo state is carried by `BlockAttributes.checked` and may coexist
/// with `'ordered'` for ordered todo items. Legacy `'task'` remains the
/// compatible unordered todo representation. Legacy values `li`/`oli`/`check`
/// are mapped on decode.
///
/// Quote is a block decoration carried by `BlockAttributes.quoted`, not a text
/// semantic type. Legacy `BlockType.quote` is normalized to a paragraph with
/// `quoted == true` so quote styling can compose with headings and lists.
class DocumentSchema {
  const DocumentSchema({this.maxIndent = 8});

  /// Maximum indent depth a block may carry.
  final int maxIndent;

  /// Returns a well-formed copy of [document]. Idempotent: normalising an
  /// already-normal document returns an equivalent one.
  RichTextDocument normalize(RichTextDocument document) {
    var blocks = document.blocks;
    if (blocks.isEmpty) {
      return RichTextDocument(
        version: document.version,
        blocks: <BlockNode>[
          TextBlockNode(
            id: _freshId(),
            type: BlockType.paragraph,
            content: const <InlineNode>[],
          ),
        ],
        comments: document.comments,
        revisions: document.revisions,
      );
    }
    if (blocks is PersistentBlockList) {
      final dirtyIndexes = blocks.pendingNormalizationIndexes;
      if (dirtyIndexes.isEmpty) {
        return document;
      }
      var normalizedBlocks = blocks;
      for (final index in dirtyIndexes) {
        if (index < 0 || index >= normalizedBlocks.length) {
          continue;
        }
        final block = normalizedBlocks[index];
        final normalized = _normalizeBlock(block);
        if (!identical(normalized, block)) {
          normalizedBlocks = normalizedBlocks.replaceAt(index, normalized);
        }
      }
      normalizedBlocks = normalizedBlocks.markNormalized();
      return RichTextDocument(
        version: document.version,
        blocks: normalizedBlocks,
        comments: document.comments,
        revisions: document.revisions,
      );
    }
    var changed = false;
    final next = <BlockNode>[];
    for (final block in blocks) {
      final normalized = _normalizeBlock(block);
      if (!identical(normalized, block)) {
        changed = true;
      }
      next.add(normalized);
    }
    if (!changed) {
      return document;
    }
    return RichTextDocument(
      version: document.version,
      blocks: next,
      comments: document.comments,
      revisions: document.revisions,
    );
  }

  BlockNode _normalizeBlock(BlockNode block) {
    switch (block) {
      case final TextBlockNode text:
        return _normalizeTextBlock(text);
      case final CalloutBlockNode callout:
        return _normalizeCalloutBlock(callout);
      case final BlockEmbedNode embed:
        return _normalizeBlockEmbed(embed);
      case final TableBlockNode table:
        return _normalizeTableBlock(table);
      case final VideoBlockNode video:
        return _normalizeVideoBlock(video);
      case final CodeBlockNode code:
        return _normalizeCodeBlock(code);
      case final ImageBlockNode image:
        return _normalizeImageBlock(image);
      case final DividerBlockNode divider:
        return _normalizeDividerBlock(divider);
      case final FileBlockNode file:
        return _normalizeFileBlock(file);
      default:
        return block;
    }
  }

  BlockNode _normalizeCodeBlock(CodeBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    if (attrs == block.attributes) {
      return block;
    }
    return CodeBlockNode(
      id: block.id,
      code: block.code,
      language: block.language,
      attributes: attrs,
    );
  }

  BlockNode _normalizeImageBlock(ImageBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    if (attrs == block.attributes) {
      return block;
    }
    return block.copyWith(attributes: attrs);
  }

  BlockNode _normalizeDividerBlock(DividerBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    if (attrs == block.attributes) {
      return block;
    }
    return DividerBlockNode(id: block.id, attributes: attrs);
  }

  BlockNode _normalizeFileBlock(FileBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    if (attrs == block.attributes) {
      return block;
    }
    return block.copyWith(attributes: attrs);
  }

  BlockNode _normalizeVideoBlock(VideoBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    final assetId = block.assetId.trim();
    final playbackUrl = block.playbackUrl.trim();
    final file = block.file.trim();
    final coverUrl = block.coverUrl.trim();
    final title = block.title.trim();
    final description = block.description.trim();
    final uploadError = block.uploadError.trim();
    final aspectRatio = _normalizeAspectRatio(block.aspectRatio);

    final normalized = VideoBlockNode(
      id: block.id,
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: title,
      description: description,
      aspectRatio: aspectRatio,
      uploadStatus: block.uploadStatus,
      uploadError: uploadError,
      attributes: attrs,
    );

    if (!normalized.hasSource) {
      return BlockEmbedNode(
        id: block.id,
        embedType: 'video',
        data: _videoEmbedData(normalized),
        fallbackText: normalized.displayText.isEmpty
            ? 'Unsupported video'
            : normalized.displayText,
        attributes: attrs,
      );
    }

    if (attrs == block.attributes &&
        assetId == block.assetId &&
        playbackUrl == block.playbackUrl &&
        file == block.file &&
        coverUrl == block.coverUrl &&
        title == block.title &&
        description == block.description &&
        aspectRatio == block.aspectRatio &&
        uploadError == block.uploadError) {
      return block;
    }
    return normalized;
  }

  BlockEmbedNode _normalizeBlockEmbed(BlockEmbedNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    final embedType = block.normalizedEmbedType;
    final fallbackText = block.fallbackText.trim();
    if (attrs == block.attributes &&
        embedType == block.embedType &&
        fallbackText == block.fallbackText) {
      return block;
    }
    return BlockEmbedNode(
      id: block.id,
      embedType: embedType,
      data: block.data,
      fallbackText: fallbackText,
      attributes: attrs,
    );
  }

  CalloutBlockNode _normalizeCalloutBlock(CalloutBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    final variant = CalloutBlockNode.normalizeVariant(block.variant);
    final title = block.title.trim();
    final icon = block.icon.trim();
    final content = mergeAdjacentTextRuns(block.content);
    if (attrs == block.attributes &&
        variant == block.variant &&
        title == block.title &&
        icon == block.icon &&
        identical(content, block.content)) {
      return block;
    }
    return CalloutBlockNode(
      id: block.id,
      content: content,
      variant: variant,
      title: title,
      icon: icon,
      attributes: attrs,
    );
  }

  TextBlockNode _normalizeTextBlock(TextBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    final type =
        block.type == BlockType.quote ? BlockType.paragraph : block.type;
    final content = mergeAdjacentTextRuns(block.content);
    if (attrs == block.attributes &&
        type == block.type &&
        identical(content, block.content)) {
      return block;
    }
    return TextBlockNode(
      id: block.id,
      type: type,
      attributes: attrs,
      content: content,
    );
  }

  TableBlockNode _normalizeTableBlock(TableBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    var changed = false;
    final rows = <List<TableCellNode>>[];
    for (final row in block.table.rows) {
      final nextRow = <TableCellNode>[];
      for (final cell in row) {
        if (cell.blocks.isEmpty) {
          nextRow.add(
            TableCellNode(
              id: cell.id,
              blocks: <BlockNode>[
                TextBlockNode(
                  id: '${cell.id}-p',
                  type: BlockType.paragraph,
                  content: const <InlineNode>[],
                ),
              ],
              rowSpan: cell.rowSpan,
              columnSpan: cell.columnSpan,
              isHeader: cell.isHeader,
              backgroundColor: cell.backgroundColor,
              covered: cell.covered,
              alignment: cell.alignment,
            ),
          );
          changed = true;
        } else {
          final normalizedCellBlocks = <BlockNode>[];
          var cellChanged = false;
          for (final nestedBlock in cell.blocks) {
            final normalizedBlock = _normalizeBlock(nestedBlock);
            normalizedCellBlocks.add(normalizedBlock);
            if (!identical(normalizedBlock, nestedBlock)) {
              cellChanged = true;
            }
          }
          if (!cellChanged) {
            nextRow.add(cell);
          } else {
            nextRow.add(
              TableCellNode(
                id: cell.id,
                blocks: normalizedCellBlocks,
                rowSpan: cell.rowSpan,
                columnSpan: cell.columnSpan,
                isHeader: cell.isHeader,
                backgroundColor: cell.backgroundColor,
                covered: cell.covered,
                alignment: cell.alignment,
              ),
            );
            changed = true;
          }
        }
      }
      rows.add(nextRow);
    }
    if (!changed && attrs == block.attributes) {
      return block;
    }
    return TableBlockNode(
      id: block.id,
      attributes: attrs,
      table: TableModel(
        rows: rows,
        columnAlignments: Map<int, String>.from(block.table.columnAlignments),
        columnWidths: Map<int, double>.from(block.table.columnWidths),
      ),
    );
  }

  /// Returns attributes consistent with [type], or the same instance if already
  /// consistent. Canonicalises `listType` (li/oli/check → ordered/task/null).
  ///
  /// List items split marker type from todo state: `listType` controls bullet or
  /// numbering, while `checked != null` marks a todo item. Historical
  /// `listType == 'task'` data stays valid as an unordered todo variant.
  BlockAttributes _normalizeAttributes(BlockType type, BlockAttributes attrs) {
    final indent = (attrs.indent ?? 0).clamp(0, maxIndent).toInt();
    switch (type) {
      case BlockType.heading:
        return BlockAttributes(
          level: attrs.level ?? 1,
          indent: indent,
          alignment: attrs.alignment,
          quoted: attrs.quoted,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.quote:
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          quoted: true,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.listItem:
        final canonical = _canonicalListType(attrs.listType);
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          listType: canonical,
          checked:
              canonical == 'task' ? (attrs.checked ?? false) : attrs.checked,
          quoted: attrs.quoted,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.paragraph:
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          quoted: attrs.quoted,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.callout:
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.code:
      case BlockType.image:
      case BlockType.table:
      case BlockType.divider:
      case BlockType.video:
      case BlockType.embed:
      case BlockType.file:
        // Non-text blocks don't carry text-block list/todo attrs.
        return _withoutListTodoAttrs(attrs);
    }
  }

  static BlockAttributes _withoutListTodoAttrs(BlockAttributes attrs) {
    return BlockAttributes(
      level: attrs.level,
      indent: attrs.indent,
      alignment: attrs.alignment,
      childNote: attrs.childNote,
      anchor: attrs.anchor,
    );
  }

  /// Maps legacy list-type strings to the canonical set. Canonical values pass
  /// through unchanged.
  static String? _canonicalListType(String? listType) {
    switch (listType) {
      case 'li':
      case 'unordered':
        return null;
      case 'oli':
      case 'ordered':
        return 'ordered';
      case 'check':
      case 'task':
        return 'task';
      default:
        return listType;
    }
  }
}

Map<String, Object?> _videoEmbedData(VideoBlockNode block) {
  return <String, Object?>{
    if (block.assetId.isNotEmpty) 'assetId': block.assetId,
    if (block.playbackUrl.isNotEmpty) 'playbackUrl': block.playbackUrl,
    if (block.file.isNotEmpty) 'file': block.file,
    if (block.coverUrl.isNotEmpty) 'coverUrl': block.coverUrl,
    if (block.title.isNotEmpty) 'title': block.title,
    if (block.description.isNotEmpty) 'description': block.description,
    if (block.aspectRatio != null) 'aspectRatio': block.aspectRatio,
    if (block.uploadStatus != FileUploadStatus.none)
      'uploadStatus': block.uploadStatus.name,
    if (block.uploadError.isNotEmpty) 'uploadError': block.uploadError,
  };
}

double? _normalizeAspectRatio(double? value) {
  if (value == null || value <= 0 || !value.isFinite) {
    return null;
  }
  return value;
}

int _idCounter = 0;

String _freshId() {
  _idCounter += 1;
  return 'schema-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}
