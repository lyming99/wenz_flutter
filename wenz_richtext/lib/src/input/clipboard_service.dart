import 'dart:convert';

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

/// Serialises and parses editor clipboard payloads.
///
/// Stage 1 scope:
/// - Same-block selection: rich JSON preserving [TextRun] attributes, plus a
///   plain-text fallback embedded in the payload.
/// - Cross-block selection: plain text joined with newlines only. Rich
///   cross-block copy/paste lands with cross-block selection editing (stage 2).
/// - Paste: detects [wenzClipboardPrefix] for rich inline payloads, otherwise
///   treats the payload as plain text and splits on newlines into blocks.
///
/// This service is pure logic — it does not touch [Clipboard] directly, so it
/// can be unit tested without a binding. The widget layer is responsible for
/// `Clipboard.setData` / `Clipboard.getData`.
class ClipboardService {
  const ClipboardService();

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
    return _copyCrossBlockPlain(document, start, end);
  }

  /// Parses a clipboard string into structured paste data.
  ClipboardPaste parse(String raw) {
    if (raw.startsWith(wenzClipboardPrefix)) {
      final json = raw.substring(wenzClipboardPrefix.length);
      final decoded = jsonDecode(json);
      if (decoded is Map && decoded['type'] == 'inline') {
        final runs = (decoded['runs'] as List)
            .whereType<Map>()
            .map((node) => InlineNode.fromJson(Map<String, Object?>.from(node)))
            .toList();
        return ClipboardPaste.inline(runs);
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

  String _copySameBlock(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    if (start.path.isTableCellText) {
      return _copySameTableCell(document, start, end);
    }
    final block = _blockAt(document, start.blockIndex);
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

  /// Placeholder for HTML paste (stage 6). Always returns `null` for now.
  List<InlineNode>? pasteHtml(String html) {
    // Intentionally unimplemented; reserved for stage 6 import.
    return null;
  }

  /// Placeholder for Markdown paste (stage 6). Always returns `null` for now.
  List<InlineNode>? pasteMarkdown(String markdown) {
    // Intentionally unimplemented; reserved for stage 6 import.
    return null;
  }
}

/// Result of parsing clipboard data.
class ClipboardPaste {
  const ClipboardPaste.inline(this.inlineRuns)
      : plainText = null,
        isRich = true;

  const ClipboardPaste.plain(this.plainText)
      : inlineRuns = const <InlineNode>[],
        isRich = false;

  /// Rich inline runs when [isRich], otherwise empty.
  final List<InlineNode> inlineRuns;

  /// Plain text when not [isRich], otherwise `null`.
  final String? plainText;

  final bool isRich;

  /// Plain-text view of the paste content regardless of flavour.
  String get text {
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
    }
    // Non-text embeds inside a selection are dropped from the slice for stage 1;
    // they cannot be meaningfully re-inserted as plain inline yet.
  }
  return mergeTextRuns(result);
}
