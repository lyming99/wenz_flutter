import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
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
/// `null` (unordered). Legacy values `li`/`oli`/`check` are mapped on decode.
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
      case final CodeBlockNode _:
      case final ImageBlockNode _:
      case final DividerBlockNode _:
      case final VideoBlockNode _:
      case final FileBlockNode _:
        return block;
      default:
        return block;
    }
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
    if (attrs == block.attributes &&
        variant == block.variant &&
        title == block.title &&
        icon == block.icon) {
      return block;
    }
    return CalloutBlockNode(
      id: block.id,
      content: block.content,
      variant: variant,
      title: title,
      icon: icon,
      attributes: attrs,
    );
  }

  TextBlockNode _normalizeTextBlock(TextBlockNode block) {
    final attrs = _normalizeAttributes(block.type, block.attributes);
    if (attrs == block.attributes) {
      return block;
    }
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: attrs,
      content: block.content,
    );
  }

  TableBlockNode _normalizeTableBlock(TableBlockNode block) {
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
            ),
          );
          changed = true;
        } else {
          nextRow.add(cell);
        }
      }
      rows.add(nextRow);
    }
    if (!changed) {
      return block;
    }
    return TableBlockNode(
      id: block.id,
      attributes: block.attributes,
      table: TableModel(
        rows: rows,
        columnAlignments: Map<int, String>.from(block.table.columnAlignments),
        columnWidths: Map<int, double>.from(block.table.columnWidths),
      ),
    );
  }

  /// Returns attributes consistent with [type], or the same instance if already
  /// consistent. Canonicalises `listType` (li/oli/check → ordered/task/null).
  BlockAttributes _normalizeAttributes(BlockType type, BlockAttributes attrs) {
    final indent = (attrs.indent ?? 0).clamp(0, maxIndent).toInt();
    switch (type) {
      case BlockType.heading:
        return BlockAttributes(
          level: attrs.level ?? 1,
          indent: indent,
          alignment: attrs.alignment,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.quote:
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.listItem:
        final canonical = _canonicalListType(attrs.listType);
        return BlockAttributes(
          indent: indent,
          alignment: attrs.alignment,
          listType: canonical,
          checked: canonical == 'task' ? (attrs.checked ?? false) : null,
          childNote: attrs.childNote,
          anchor: attrs.anchor,
        );
      case BlockType.paragraph:
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
        // Non-text blocks don't carry text-block attrs; leave as-is.
        return attrs;
    }
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

int _idCounter = 0;

String _freshId() {
  _idCounter += 1;
  return 'schema-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}
