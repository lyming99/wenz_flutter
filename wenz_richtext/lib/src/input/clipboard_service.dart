import 'dart:convert';

import '../codecs/html_codec.dart';
import '../codecs/markdown_codec.dart';
import '../core/commands/inline_editing.dart';
import '../core/commands/table_cell_editing.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';

/// Magic prefix marking a clipboard payload as wenz-richtext rich JSON. The
/// platform clipboard only carries plain text reliably across Windows/Web, so
/// rich payloads are encoded as `<prefix><json>` and detected on paste.
const String wenzClipboardPrefix = 'wenz-richtext-json:v1\n';

enum ClipboardPasteFormat {
  auto,
  plainText,
  markdown,
  html,
}

/// Context passed to a plugin paste transformer.
class ClipboardPasteContext {
  const ClipboardPasteContext({
    required this.raw,
    required this.format,
  });

  /// Raw clipboard text as received from the platform or caller.
  final String raw;

  /// Parser flavour requested by the caller.
  final ClipboardPasteFormat format;
}

typedef ClipboardPasteTransform = ClipboardPaste? Function(
  ClipboardPasteContext context,
);

/// A named paste transformer contributed by a plugin.
///
/// Return `null` to decline and let the next transformer or built-in parser run;
/// return a [ClipboardPaste] to short-circuit the built-in parser.
class ClipboardPasteTransformer {
  const ClipboardPasteTransformer({
    required this.id,
    required this.transform,
  });

  /// Unique transformer id, usually namespaced by plugin.
  final String id;

  final ClipboardPasteTransform transform;
}

/// Serialises and parses editor clipboard payloads.
///
/// - Same-block selection: rich JSON preserving [TextRun] attributes, plus a
///   plain-text fallback embedded in the payload.
/// - Cross-block selection: rich JSON carrying the full block slice (each
///   block's type/attributes/inline content, with the first/last block trimmed
///   to the selection offsets) plus a plain-text fallback. Pasting it restores
///   the block structure and inline attributes.
/// - Paste: detects [wenzClipboardPrefix] for rich payloads (inline or blocks),
///   otherwise treats the payload as plain text and splits on newlines into
///   blocks.
///
/// This service is pure logic — it does not touch [Clipboard] directly, so it
/// can be unit tested without a binding. The widget layer is responsible for
/// `Clipboard.setData` / `Clipboard.getData`.
class ClipboardService {
  const ClipboardService({
    this.htmlCodec = const HtmlCodec(),
    this.markdownCodec = const MarkdownCodec(),
    this.pasteTransformers = const <ClipboardPasteTransformer>[],
  });

  /// HTML codec used by [pasteHtml] to turn an HTML fragment into blocks.
  /// Defaults to [HtmlCodec]; inject a custom one to tweak HTML mapping.
  final HtmlCodec htmlCodec;

  /// Markdown codec used by [parseMarkdown] to turn a Markdown fragment into
  /// blocks. Defaults to [MarkdownCodec].
  final MarkdownCodec markdownCodec;

  /// Optional plugin transformers checked before built-in rich/plain/markdown
  /// parsers. Pass a growable list when plugins should register after service
  /// construction.
  final List<ClipboardPasteTransformer> pasteTransformers;

  /// Serialises [selection] from [document] into a clipboard string.
  ///
  /// Returns `null` when the selection is collapsed or points at nothing
  /// copyable.
  String? copy(RichTextDocument document, DocumentSelection? selection) {
    if (selection == null || selection.isCollapsed) {
      return null;
    }
    final range = selection.tableCellRange;
    if (range != null && !range.isSingleCell) {
      return _copyTableCellRangePlain(document, range);
    }
    final start = selection.start;
    final end = selection.end;
    if (start.blockIndex == end.blockIndex && start.path == end.path) {
      return _copySameBlock(document, start, end);
    }
    return _copyCrossBlockRich(document, start, end);
  }

  /// Parses a clipboard string into structured paste data.
  ///
  /// [ClipboardPasteFormat.auto] keeps the historical behaviour: rich Wenz
  /// payloads are detected by [wenzClipboardPrefix], and everything else is
  /// plain text. Pass [ClipboardPasteFormat.markdown] or
  /// [ClipboardPasteFormat.html] when the platform/business layer knows the
  /// clipboard flavour.
  ClipboardPaste parse(
    String raw, {
    ClipboardPasteFormat format = ClipboardPasteFormat.auto,
  }) {
    final context = ClipboardPasteContext(raw: raw, format: format);
    for (final transformer in pasteTransformers) {
      final paste = transformer.transform(context);
      if (paste != null) {
        return paste;
      }
    }
    switch (format) {
      case ClipboardPasteFormat.markdown:
        return parseMarkdown(raw) ?? ClipboardPaste.plain(raw);
      case ClipboardPasteFormat.html:
        return parseHtml(raw) ?? ClipboardPaste.plain(raw);
      case ClipboardPasteFormat.plainText:
        return ClipboardPaste.plain(raw);
      case ClipboardPasteFormat.auto:
        break;
    }
    if (raw.startsWith(wenzClipboardPrefix)) {
      final json = raw.substring(wenzClipboardPrefix.length);
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        if (decoded['type'] == 'inline') {
          final runs = (decoded['runs'] as List)
              .whereType<Map>()
              .map((node) =>
                  InlineNode.fromJson(Map<String, Object?>.from(node)))
              .toList();
          return ClipboardPaste.inline(runs);
        }
        if (decoded['type'] == 'blocks') {
          final blocksJson = decoded['blocks'];
          if (blocksJson is List) {
            final blocks = blocksJson
                .whereType<Map>()
                .map((node) =>
                    BlockNode.fromJson(Map<String, Object?>.from(node)))
                .toList();
            if (blocks.isNotEmpty) {
              return ClipboardPaste.blocks(blocks);
            }
          }
        }
      }
    }
    // Plain text. Split into lines: first line stays inline, the rest become
    // new blocks via Enter-on-paste.
    return ClipboardPaste.plain(raw);
  }

  String _copyTableCellRangePlain(
    RichTextDocument document,
    TableCellRange range,
  ) {
    final block = _blockAt(document, range.blockIndex);
    if (block is! TableBlockNode) {
      return '';
    }
    final lines = <String>[];
    for (var rowIndex = range.startRow; rowIndex <= range.endRow; rowIndex++) {
      final cells = <String>[];
      for (var columnIndex = range.startColumn;
          columnIndex <= range.endColumn;
          columnIndex++) {
        cells.add(block.table.cellAt(rowIndex, columnIndex)?.plainText ?? '');
      }
      lines.add(cells.join('\t'));
    }
    return lines.join('\n');
  }

  String? _copySameBlock(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    if (start.path.isTableCellText) {
      return _copySameTableCell(document, start, end);
    }
    final block = _blockAt(document, start.blockIndex);
    if (start.path.isBlockObject) {
      if (block == null) {
        return null;
      }
      return _encodeBlockSlice(<BlockNode>[block.copy()]);
    }
    if (block is! TextBlockNode) {
      // Code block or non-text: fall back to a plain text slice.
      final text = block?.plainText ?? '';
      return text.substring(
        start.offset.clamp(0, text.length),
        end.offset.clamp(0, text.length),
      );
    }
    return _encodeInlineSlice(block.content, start.offset, end.offset);
  }

  String _copySameTableCell(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    final block = _blockAt(document, start.blockIndex);
    final rowIndex = start.path.tableRowIndex;
    final columnIndex = start.path.tableColumnIndex;
    if (block is! TableBlockNode || rowIndex == null || columnIndex == null) {
      return '';
    }
    final cell = block.table.cellAt(rowIndex, columnIndex);
    if (cell == null) {
      return '';
    }
    return _encodeInlineSlice(
      cellTextBlock(cell).content,
      start.offset,
      end.offset,
    );
  }

  String _encodeInlineSlice(List<InlineNode> nodes, int start, int end) {
    final range = _sliceInline(nodes, start, end);
    final plain = range.map((node) => node.plainText).join();
    final payload = jsonEncode(<String, Object?>{
      'type': 'inline',
      'runs': range.map((node) => node.toJson()).toList(),
      'plain': plain,
    });
    return '$wenzClipboardPrefix$payload';
  }

  String _copyCrossBlockRich(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    final blocks = <BlockNode>[];
    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      final block = _blockAt(document, i);
      if (block == null) {
        continue;
      }
      if (block is! TextBlockNode) {
        // Non-text blocks (code/table/media) in a cross-block range: include
        // as-is rather than dropping. Their structure round-trips through
        // BlockNode.toJson/fromJson.
        blocks.add(block.copy());
        continue;
      }
      final text = block.plainText;
      final List<InlineNode> sliced;
      if (i == start.blockIndex && i == end.blockIndex) {
        // Same block, different paths — shouldn't reach here (same-path is
        // handled by _copySameBlock), but guard anyway.
        sliced = _sliceInline(block.content, start.offset, end.offset);
      } else if (i == start.blockIndex) {
        sliced = _sliceInline(
          block.content,
          start.offset,
          inlineNodesLength(block.content),
        );
        // When the start offset is 0 the slice equals the whole block; when
        // it is at the very end the slice is empty and we skip emitting an
        // empty leading block.
        if (sliced.isEmpty && start.offset >= text.length) {
          continue;
        }
      } else if (i == end.blockIndex) {
        sliced = _sliceInline(block.content, 0, end.offset);
        if (sliced.isEmpty && end.offset == 0) {
          continue;
        }
      } else {
        sliced = block.content.map((node) => node.copy()).toList();
      }
      blocks.add(
        TextBlockNode(
          id: block.id,
          type: block.type,
          attributes: block.attributes,
          content: sliced,
        ),
      );
    }
    return _encodeBlockSlice(blocks,
        plain: _copyCrossBlockPlain(document, start, end));
  }

  String _encodeBlockSlice(List<BlockNode> blocks, {String? plain}) {
    final payload = jsonEncode(<String, Object?>{
      'type': 'blocks',
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'plain': plain ?? blocks.map((block) => block.plainText).join('\n'),
    });
    return '$wenzClipboardPrefix$payload';
  }

  String _copyCrossBlockPlain(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    final lines = <String>[];
    for (var i = start.blockIndex; i <= end.blockIndex; i++) {
      final block = _blockAt(document, i);
      if (block == null) {
        continue;
      }
      final text = block.plainText;
      if (i == start.blockIndex) {
        lines.add(text.substring(start.offset.clamp(0, text.length)));
      } else if (i == end.blockIndex) {
        lines.add(text.substring(0, end.offset.clamp(0, text.length)));
      } else {
        lines.add(text);
      }
    }
    return lines.join('\n');
  }

  /// Parses an HTML fragment into a structured paste payload. Returns a
  /// [ClipboardPaste.blocks] carrying the decoded blocks (the caller pastes
  /// them via [PasteBlocksCommand], restoring multi-block structure), or
  /// `null` when the fragment yields no content.
  ClipboardPaste? parseHtml(String html) {
    final document = htmlCodec.decode(html);
    return _blocksPaste(document);
  }

  /// Backwards-compatible alias for [parseHtml].
  ClipboardPaste? pasteHtml(String html) => parseHtml(html);

  /// Parses a Markdown fragment into a structured paste payload.
  ClipboardPaste? parseMarkdown(String markdown) {
    final document = markdownCodec.decode(markdown);
    return _blocksPaste(document);
  }

  /// Legacy inline-only Markdown helper. Prefer [parseMarkdown] or
  /// `parse(markdown, format: ClipboardPasteFormat.markdown)` for full block
  /// paste.
  List<InlineNode>? pasteMarkdown(String markdown) {
    final paste = parseMarkdown(markdown);
    if (paste == null || !paste.isBlocks || paste.blocks.length != 1) {
      return null;
    }
    final block = paste.blocks.single;
    if (block is! TextBlockNode) {
      return null;
    }
    return block.content.map((node) => node.copy()).toList();
  }

  ClipboardPaste? _blocksPaste(RichTextDocument document) {
    if (document.blocks.isEmpty) {
      return null;
    }
    return ClipboardPaste.blocks(document.blocks);
  }
}

/// Result of parsing clipboard data.
class ClipboardPaste {
  const ClipboardPaste.inline(this.inlineRuns)
      : blocks = const <BlockNode>[],
        plainText = null,
        isRich = true,
        isBlocks = false;

  const ClipboardPaste.plain(this.plainText)
      : inlineRuns = const <InlineNode>[],
        blocks = const <BlockNode>[],
        isRich = false,
        isBlocks = false;

  const ClipboardPaste.blocks(this.blocks)
      : inlineRuns = const <InlineNode>[],
        plainText = null,
        isRich = true,
        isBlocks = true;

  /// Rich inline runs when [isRich] && !isBlocks, otherwise empty.
  final List<InlineNode> inlineRuns;

  /// Rich block slice when [isBlocks], otherwise empty. The first/last block
  /// are already trimmed to the copied selection offsets, so the consumer can
  /// merge them into the document at the caret verbatim.
  final List<BlockNode> blocks;

  /// Plain text when not [isRich], otherwise `null`.
  final String? plainText;

  final bool isRich;

  /// Whether this paste carries whole-block structure (cross-block copy).
  final bool isBlocks;

  /// Plain-text view of the paste content regardless of flavour.
  String get text {
    if (isBlocks) {
      return blocks.map((block) => block.plainText).join('\n');
    }
    if (!isRich) {
      return plainText ?? '';
    }
    return inlineRuns.map((node) => node.plainText).join();
  }
}

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

/// Extracts the inline nodes covering [start, end) within [nodes], splitting
/// runs at the boundaries (mirrors [formatInline] semantics without applying
/// any attribute change).
List<InlineNode> _sliceInline(List<InlineNode> nodes, int start, int end) {
  if (end <= start) {
    return const <InlineNode>[];
  }
  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= start || nodeStart >= end) {
      continue;
    }
    if (node is TextRun) {
      final localStart = start > nodeStart ? start - nodeStart : 0;
      final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
      final slice = node.text.substring(localStart, localEnd);
      if (slice.isNotEmpty) {
        result.add(TextRun(text: slice, attributes: node.attributes));
      }
    } else {
      // Inline embed (formula/mention/image): it occupies a single length-1
      // char, so any selection covering it (the overlap test above already
      // passed) keeps it whole. Re-emit it so copy/paste preserves rich
      // inline elements.
      result.add(node.copy());
    }
  }
  return mergeTextRuns(result);
}
