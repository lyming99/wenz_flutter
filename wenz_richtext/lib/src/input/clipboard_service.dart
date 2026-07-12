import 'dart:convert';

import '../codecs/html_codec.dart';
import '../codecs/markdown_codec.dart';
import '../core/commands/inline_editing.dart';
import '../core/commands/table_cell_editing.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import 'clipboard_debug_log.dart';
import 'external_image_input.dart';

/// Magic prefix marking a clipboard payload as wenz-richtext rich JSON. The
/// platform clipboard only carries plain text reliably across Windows/Web, so
/// rich payloads are encoded as `<prefix><json>` and detected on paste.
const String wenzClipboardPrefix = 'wenz-richtext-json:v1\n';

const String _wenzClipboardHeader = 'wenz-richtext-json:v1';

/// Whether [value] starts with a Wenz private clipboard header.
///
/// Windows clipboard transports may rewrite the header's LF delimiter to CRLF
/// and some platform codecs prepend a UTF-8 BOM, so detection deliberately
/// accepts those transport variants.
bool hasWenzClipboardPrefix(String value) {
  return _leadingWenzClipboardPrefixLength(_stripLeadingClipboardBom(value)) !=
      null;
}

/// Canonicalises private clipboard data to exactly one LF-terminated header.
///
/// Besides CRLF/LF transport differences, repeated headers are removed so data
/// produced by older buggy paste normalisation remains recoverable.
String normalizeWenzClipboardPayload(String value) {
  var body = _stripLeadingClipboardBom(value);
  var prefixCount = 0;
  while (true) {
    final prefixLength = _leadingWenzClipboardPrefixLength(body);
    if (prefixLength == null) {
      break;
    }
    body = _stripLeadingClipboardBom(body.substring(prefixLength));
    prefixCount += 1;
  }
  while (body.endsWith('\u0000')) {
    body = body.substring(0, body.length - 1);
  }
  WenzClipboardDebugLog.event(
    'payload.prefix-normalized',
    fields: <String, Object?>{
      'inputLength': value.length,
      'prefixCount': prefixCount,
      'changed': prefixCount != 1 || !value.startsWith(wenzClipboardPrefix),
      'outputLength': wenzClipboardPrefix.length + body.length,
    },
  );
  return '$wenzClipboardPrefix$body';
}

int? _leadingWenzClipboardPrefixLength(String value) {
  if (!value.startsWith(_wenzClipboardHeader)) {
    return null;
  }
  const offset = _wenzClipboardHeader.length;
  if (value.length == offset) {
    return offset;
  }
  if (value.startsWith('\r\n', offset)) {
    return offset + 2;
  }
  final delimiter = value.codeUnitAt(offset);
  if (delimiter == 0x0A || delimiter == 0x0D) {
    return offset + 1;
  }
  return null;
}

String _stripLeadingClipboardBom(String value) {
  var result = value;
  while (result.startsWith('\uFEFF')) {
    result = result.substring(1);
  }
  return result;
}

/// Private clipboard format carrying Wenz rich-text JSON.
const String wenzRichTextClipboardFormat = 'application/x-wenz-richtext';

/// Standard HTML clipboard format for external rich paste targets.
const String htmlClipboardFormat = 'text/html';

/// Standard Markdown clipboard format for external structured paste sources.
const String markdownClipboardFormat = 'text/markdown';

/// Standard plain-text clipboard format used as the readable fallback.
const String plainTextClipboardFormat = 'text/plain';

enum ClipboardPasteFormat {
  auto,
  plainText,
  markdown,
  html,
}

/// A rectangular clipboard fragment intended for table-cell paste.
///
/// Each item is a cell's block content. Keeping blocks (rather than only
/// plain text) lets HTML and Wenz rich-text table payloads use the same shape
/// as TSV while retaining their inline formatting for the table paste path.
class ClipboardTableCellMatrix {
  const ClipboardTableCellMatrix(this.cells);

  final List<List<List<BlockNode>>> cells;

  int get rowCount => cells.length;

  int get columnCount => cells.fold<int>(
        0,
        (count, row) => row.length > count ? row.length : count,
      );

  /// A one-cell payload keeps the existing inline paste behaviour.
  bool get isSingleCell => rowCount == 1 && columnCount == 1;

  List<BlockNode>? cellAt(int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= cells.length) {
      return null;
    }
    final row = cells[rowIndex];
    if (columnIndex < 0 || columnIndex >= row.length) {
      return null;
    }
    return row[columnIndex];
  }
}

/// Structured copy result with all clipboard flavours prepared from the same
/// selection slice.
class ClipboardCopyPayload {
  const ClipboardCopyPayload({
    required this.wenzRichText,
    required this.html,
    required this.plainText,
    String? legacyText,
  }) : legacyText = legacyText ?? wenzRichText;

  /// Internal Wenz payload. This keeps the historical magic prefix so it can
  /// still be pasted through [parse] when only plain text is available.
  final String wenzRichText;

  /// HTML fragment for external rich paste targets.
  final String html;

  /// Readable plain-text fallback. This must never expose raw Wenz JSON.
  final String plainText;

  /// Backwards-compatible string returned by [ClipboardService.copy]. Some
  /// legacy paths intentionally returned plain text for code/table selections.
  final String legacyText;

  /// Payloads keyed by clipboard MIME/format identifiers.
  Map<String, String> get formats => <String, String>{
        wenzRichTextClipboardFormat: wenzRichText,
        htmlClipboardFormat: html,
        plainTextClipboardFormat: plainText,
      };
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

  /// Serialises [selection] from [document] into the legacy clipboard string.
  ///
  /// Returns `null` when the selection is collapsed or points at nothing
  /// copyable.
  String? copy(RichTextDocument document, DocumentSelection? selection) {
    return copyPayload(document, selection)?.legacyText;
  }

  /// Serialises [selection] from [document] into internal rich text, HTML, and
  /// readable plain-text clipboard flavours.
  ///
  /// Returns `null` when the selection is collapsed or points at nothing
  /// copyable.
  ClipboardCopyPayload? copyPayload(
    RichTextDocument document,
    DocumentSelection? selection,
  ) {
    WenzClipboardDebugLog.event(
      'copy.request',
      fields: <String, Object?>{
        'documentBlocks': document.blocks.length,
        'selection': WenzClipboardDebugLog.selection(selection),
      },
    );
    if (selection == null || selection.isCollapsed) {
      WenzClipboardDebugLog.event(
        'copy.skipped',
        fields: <String, Object?>{
          'reason': selection == null ? 'no-selection' : 'collapsed-selection',
        },
      );
      return null;
    }
    final range = selection.tableCellRange;
    if (range != null && !range.isSingleCell) {
      return _copyTableCellRangePayload(document, range);
    }
    final start = selection.start;
    final end = selection.end;
    if (start.blockIndex == end.blockIndex && start.path == end.path) {
      return _copySameBlockPayload(document, start, end);
    }
    return _copyCrossBlockPayload(document, start, end);
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
    WenzClipboardDebugLog.event(
      'parse.request',
      fields: <String, Object?>{
        'requestedFormat': format.name,
        'hasWenzPrefix': hasWenzClipboardPrefix(raw),
        'input': WenzClipboardDebugLog.text(raw),
      },
    );
    final context = ClipboardPasteContext(raw: raw, format: format);
    for (final transformer in pasteTransformers) {
      final paste = transformer.transform(context);
      if (paste != null) {
        return _tracePasteResult('transformer:${transformer.id}', paste);
      }
    }
    switch (format) {
      case ClipboardPasteFormat.markdown:
        return _tracePasteResult(
          'markdown',
          parseMarkdown(raw) ?? _plainPaste(raw),
        );
      case ClipboardPasteFormat.html:
        return _tracePasteResult('html', parseHtml(raw) ?? _plainPaste(raw));
      case ClipboardPasteFormat.plainText:
        return _tracePasteResult('plain-text-explicit', _plainPaste(raw));
      case ClipboardPasteFormat.auto:
        break;
    }
    if (hasWenzClipboardPrefix(raw)) {
      return _tracePasteResult(
        'wenz-private',
        _parseWenzRichTextPayload(normalizeWenzClipboardPayload(raw)),
      );
    }
    // Plain text. Split into lines: first line stays inline, the rest become
    // new blocks via Enter-on-paste.
    return _tracePasteResult('plain-text-auto', _plainPaste(raw));
  }

  ClipboardPaste _tracePasteResult(String source, ClipboardPaste paste) {
    WenzClipboardDebugLog.event(
      'parse.result',
      fields: <String, Object?>{
        'source': source,
        'kind': paste.isBlocks
            ? 'blocks'
            : paste.isRich
                ? 'inline'
                : 'plain',
        'blockCount': paste.blocks.length,
        'blocks': _clipboardBlocksSummary(paste.blocks),
        'inlineRunCount': paste.inlineRuns.length,
        'hasTableMatrix': paste.tableCellMatrix != null,
        'text': WenzClipboardDebugLog.text(paste.text),
      },
    );
    return paste;
  }

  ClipboardPaste _plainPaste(String raw) {
    return ClipboardPaste.plain(
      raw,
      tableCellMatrix: _tableCellMatrixFromPlainText(raw),
    );
  }

  /// Parses already separated clipboard flavours using editor paste priority.
  ///
  /// Private Wenz data wins, followed by legacy prefixed plain text, HTML,
  /// Markdown, and finally readable plain text. Image handling stays outside
  /// this pure parser because platform images must first be materialised by an
  /// [ExternalImageStore].
  ClipboardPaste? parseFormats({
    String? wenzRichText,
    String? html,
    String? markdown,
    String? plainText,
  }) {
    WenzClipboardDebugLog.event(
      'parse.formats',
      fields: <String, Object?>{
        'wenz': WenzClipboardDebugLog.text(wenzRichText),
        'html': WenzClipboardDebugLog.text(html),
        'markdown': WenzClipboardDebugLog.text(markdown),
        'plain': WenzClipboardDebugLog.text(plainText),
      },
    );
    final rich = _nonEmptyClipboardString(wenzRichText);
    if (rich != null) {
      WenzClipboardDebugLog.event(
        'parse.format-selected',
        fields: const <String, Object?>{'format': wenzRichTextClipboardFormat},
      );
      final paste = parse(normalizeWenzClipboardPayload(rich));
      if (paste.hasContent) {
        return paste;
      }
      WenzClipboardDebugLog.event(
        'parse.format-rejected',
        fields: const <String, Object?>{
          'format': wenzRichTextClipboardFormat,
          'reason': 'parsed-empty',
        },
      );
    }
    final plain = _nonEmptyClipboardString(plainText);
    if (plain != null && hasWenzClipboardPrefix(plain)) {
      WenzClipboardDebugLog.event(
        'parse.format-selected',
        fields: const <String, Object?>{'format': 'legacy-wenz-in-text/plain'},
      );
      final paste = parse(normalizeWenzClipboardPayload(plain));
      if (paste.hasContent) {
        return paste;
      }
      WenzClipboardDebugLog.event(
        'parse.format-rejected',
        fields: const <String, Object?>{
          'format': 'legacy-wenz-in-text/plain',
          'reason': 'parsed-empty',
        },
      );
    }
    final htmlText = _nonEmptyClipboardString(html);
    if (htmlText != null) {
      WenzClipboardDebugLog.event(
        'parse.format-selected',
        fields: const <String, Object?>{'format': htmlClipboardFormat},
      );
      return parse(htmlText, format: ClipboardPasteFormat.html);
    }
    final markdownText = _nonEmptyClipboardString(markdown);
    if (markdownText != null) {
      WenzClipboardDebugLog.event(
        'parse.format-selected',
        fields: const <String, Object?>{'format': markdownClipboardFormat},
      );
      return parse(markdownText, format: ClipboardPasteFormat.markdown);
    }
    if (plain != null) {
      WenzClipboardDebugLog.event(
        'parse.format-selected',
        fields: const <String, Object?>{'format': plainTextClipboardFormat},
      );
      return parse(plain, format: ClipboardPasteFormat.plainText);
    }
    WenzClipboardDebugLog.event(
      'parse.format-selected',
      fields: const <String, Object?>{'format': 'none'},
    );
    return null;
  }

  ClipboardPaste _parseWenzRichTextPayload(String raw) {
    final decoded = _decodeWenzRichTextPayload(raw);
    if (decoded == null) {
      WenzClipboardDebugLog.event(
        'parse.wenz-payload-empty',
        fields: <String, Object?>{
          'input': WenzClipboardDebugLog.text(raw),
        },
      );
      return _plainPaste('');
    }
    final plain = _plainFromDecodedWenzPayload(decoded);
    try {
      if (decoded['type'] == 'inline') {
        final runsJson = decoded['runs'];
        if (runsJson is List) {
          final runs = runsJson
              .whereType<Map>()
              .map((node) =>
                  InlineNode.fromJson(Map<String, Object?>.from(node)))
              .toList();
          return runs.isEmpty && plain != null
              ? _plainPaste(plain)
              : ClipboardPaste.inline(runs);
        }
      }
      if (decoded['type'] == 'blocks') {
        final blocksJson = decoded['blocks'];
        if (blocksJson is List) {
          final blocks = blocksJson
              .whereType<Map>()
              .map(
                  (node) => BlockNode.fromJson(Map<String, Object?>.from(node)))
              .toList();
          if (blocks.isNotEmpty) {
            return ClipboardPaste.blocks(
              blocks,
              tableCellMatrix: _tableCellMatrixFromBlocks(blocks),
            );
          }
        }
      }
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'parse.wenz-payload-failed',
        fields: <String, Object?>{
          'decodedType': decoded['type'],
          'fallbackPlain': WenzClipboardDebugLog.text(plain),
        },
        error: error,
        stackTrace: stackTrace,
      );
      return _plainPaste(plain ?? '');
    }
    WenzClipboardDebugLog.event(
      'parse.wenz-payload-unsupported',
      fields: <String, Object?>{
        'decodedType': decoded['type'],
        'keys': decoded.keys.join(','),
        'fallbackPlain': WenzClipboardDebugLog.text(plain),
      },
    );
    return _plainPaste(plain ?? '');
  }

  Map<Object?, Object?>? _decodeWenzRichTextPayload(String raw) {
    try {
      final normalized = normalizeWenzClipboardPayload(raw);
      final json = normalized.substring(wenzClipboardPrefix.length);
      final decoded = jsonDecode(json);
      return decoded is Map ? decoded : null;
    } on Object catch (error, stackTrace) {
      WenzClipboardDebugLog.event(
        'parse.wenz-json-failed',
        fields: <String, Object?>{
          'input': WenzClipboardDebugLog.text(raw),
        },
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String? _plainFromDecodedWenzPayload(Map<Object?, Object?> decoded) {
    final plain = decoded['plain'];
    return plain is String ? plain : null;
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

  ClipboardCopyPayload? _copyTableCellRangePayload(
    RichTextDocument document,
    TableCellRange range,
  ) {
    final block = _blockAt(document, range.blockIndex);
    if (block is! TableBlockNode) {
      return null;
    }
    final plain = _copyTableCellRangePlain(document, range);
    final table = _sliceTableBlock(block, range);
    return _copyBlocksPayload(
      <BlockNode>[table],
      plain: plain,
      legacyText: plain,
    );
  }

  ClipboardCopyPayload? _copySameBlockPayload(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    if (start.path.isTableCellText) {
      return _copySameTableCellPayload(document, start, end);
    }
    final block = _blockAt(document, start.blockIndex);
    if (start.path.isBlockObject) {
      if (block == null) {
        return null;
      }
      return _copyBlocksPayload(
        <BlockNode>[block.copy()],
        plain: _plainTextForBlock(block),
      );
    }
    final content = block == null ? null : _blockTextContent(block);
    if (content != null && start.path.isBlockText) {
      // A list item's marker is block-level state. Encoding a complete item as
      // an inline payload makes same-editor paste prefer the private inline
      // flavour over the correctly structured HTML flavour, which silently
      // turns an unordered item (whose listType is intentionally null) into
      // ordinary paragraph text. Preserve the whole block only when the full
      // item body is selected; partial text selections remain inline as users
      // expect.
      if (block is TextBlockNode &&
          block.type == BlockType.listItem &&
          start.offset == 0 &&
          end.offset == inlineNodesLength(content)) {
        return _copyBlocksPayload(
          <BlockNode>[block.copy()],
          plain: _plainTextForBlock(block),
        );
      }
      return _copyInlineSlicePayload(
        content,
        start.offset,
        end.offset,
        htmlContextBlock: block,
      );
    }
    if (block is CodeBlockNode && start.path.isBlockCode) {
      return _copyCodeBlockSlicePayload(block, start.offset, end.offset);
    }
    final text = block?.plainText ?? '';
    final startOffset = _clampOffset(start.offset, text.length);
    final endOffset = _clampOffset(end.offset, text.length);
    final plain = text.substring(startOffset, endOffset);
    return _copyPlainTextPayload(
      plain,
      legacyText: plain,
    );
  }

  ClipboardCopyPayload _copySameTableCellPayload(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    final block = _blockAt(document, start.blockIndex);
    final rowIndex = start.path.tableRowIndex;
    final columnIndex = start.path.tableColumnIndex;
    if (block is! TableBlockNode || rowIndex == null || columnIndex == null) {
      return _copyPlainTextPayload('', legacyText: '');
    }
    final cell = block.table.cellAt(rowIndex, columnIndex);
    if (cell == null) {
      return _copyPlainTextPayload('', legacyText: '');
    }
    return _copyInlineSlicePayload(
      cellTextBlock(cell).content,
      start.offset,
      end.offset,
    );
  }

  ClipboardCopyPayload _copyInlineSlicePayload(
    List<InlineNode> nodes,
    int start,
    int end, {
    BlockNode? htmlContextBlock,
    String? legacyText,
  }) {
    final range = _sliceInline(nodes, start, end);
    final plain = _plainTextForInlineNodes(range);
    final htmlBlock = _htmlBlockForInlineSlice(htmlContextBlock, range);
    final payload = ClipboardCopyPayload(
      wenzRichText: _encodeInlineNodes(range, plain: plain),
      html: _htmlForBlocks(<BlockNode>[htmlBlock]),
      plainText: plain,
      legacyText: legacyText,
    );
    WenzClipboardDebugLog.event(
      'copy.payload-built',
      fields: <String, Object?>{
        'kind': 'inline',
        'contextBlock': htmlContextBlock?.type.name,
        'contextListType': htmlContextBlock?.attributes.listType,
        'sourceRange': '$start..$end',
        'inlineRunCount': range.length,
        'wenz': WenzClipboardDebugLog.text(payload.wenzRichText),
        'html': WenzClipboardDebugLog.text(payload.html),
        'plain': WenzClipboardDebugLog.text(payload.plainText),
      },
    );
    return payload;
  }

  ClipboardCopyPayload _copyCodeBlockSlicePayload(
    CodeBlockNode block,
    int start,
    int end,
  ) {
    final startOffset = _clampOffset(start, block.code.length);
    final endOffset = _clampOffset(end, block.code.length);
    final code = block.code.substring(startOffset, endOffset);
    return _copyBlocksPayload(
      <BlockNode>[
        CodeBlockNode(
          id: block.id,
          code: code,
          language: block.language,
          attributes: block.attributes,
        ),
      ],
      plain: code,
      legacyText: code,
    );
  }

  ClipboardCopyPayload _copyPlainTextPayload(
    String text, {
    String? legacyText,
  }) {
    final nodes =
        text.isEmpty ? const <InlineNode>[] : <InlineNode>[TextRun(text: text)];
    return _copyInlineSlicePayload(
      nodes,
      0,
      text.length,
      legacyText: legacyText,
    );
  }

  ClipboardCopyPayload _copyCrossBlockPayload(
    RichTextDocument document,
    DocumentPosition start,
    DocumentPosition end,
  ) {
    final blocks = _copyCrossBlockSlice(document, start, end);
    return _copyBlocksPayload(
      blocks,
      plain: _copyCrossBlockPlain(document, start, end),
    );
  }

  ClipboardCopyPayload _copyBlocksPayload(
    List<BlockNode> blocks, {
    required String plain,
    String? legacyText,
  }) {
    final payload = ClipboardCopyPayload(
      wenzRichText: _encodeBlockSlice(blocks, plain: plain),
      html: _htmlForBlocks(blocks),
      plainText: plain,
      legacyText: legacyText,
    );
    WenzClipboardDebugLog.event(
      'copy.payload-built',
      fields: <String, Object?>{
        'kind': 'blocks',
        'blockCount': blocks.length,
        'blocks': _clipboardBlocksSummary(blocks),
        'wenz': WenzClipboardDebugLog.text(payload.wenzRichText),
        'html': WenzClipboardDebugLog.text(payload.html),
        'plain': WenzClipboardDebugLog.text(payload.plainText),
      },
    );
    return payload;
  }

  String _encodeInlineNodes(List<InlineNode> nodes, {String? plain}) {
    final payload = jsonEncode(<String, Object?>{
      'type': 'inline',
      'runs': nodes.map((node) => node.toJson()).toList(),
      'plain': plain ?? _plainTextForInlineNodes(nodes),
    });
    return '$wenzClipboardPrefix$payload';
  }

  List<BlockNode> _copyCrossBlockSlice(
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
      if (block is CodeBlockNode &&
          (i == start.blockIndex || i == end.blockIndex)) {
        final codeLength = block.code.length;
        final startOffset =
            i == start.blockIndex ? _clampOffset(start.offset, codeLength) : 0;
        final endOffset = i == end.blockIndex
            ? _clampOffset(end.offset, codeLength)
            : codeLength;
        final code = block.code.substring(startOffset, endOffset);
        if (code.isEmpty &&
            ((i == start.blockIndex && startOffset >= codeLength) ||
                (i == end.blockIndex && endOffset == 0))) {
          continue;
        }
        blocks.add(
          CodeBlockNode(
            id: block.id,
            code: code,
            language: block.language,
            attributes: block.attributes,
          ),
        );
        continue;
      }
      final content = _blockTextContent(block);
      if (content == null) {
        // Non-text blocks (code/table/media) in a cross-block range: include
        // as-is rather than dropping. Their structure round-trips through
        // BlockNode.toJson/fromJson.
        blocks.add(block.copy());
        continue;
      }
      final textLength = inlineNodesLength(content);
      final List<InlineNode> sliced;
      if (i == start.blockIndex && i == end.blockIndex) {
        // Same block, different paths — shouldn't reach here (same-path is
        // handled by _copySameBlockPayload), but guard anyway.
        sliced = _sliceInline(content, start.offset, end.offset);
      } else if (i == start.blockIndex) {
        sliced = _sliceInline(
          content,
          start.offset,
          textLength,
        );
        // When the start offset is 0 the slice equals the whole block; when
        // it is at the very end the slice is empty and we skip emitting an
        // empty leading block.
        if (sliced.isEmpty && start.offset >= textLength) {
          continue;
        }
      } else if (i == end.blockIndex) {
        sliced = _sliceInline(content, 0, end.offset);
        if (sliced.isEmpty && end.offset == 0) {
          continue;
        }
      } else {
        sliced = content.map((node) => node.copy()).toList();
      }
      blocks.add(
        _copyTextLikeBlockWithContent(
          block,
          sliced,
          preserveCalloutMetadata: i != start.blockIndex && i != end.blockIndex,
        ),
      );
    }
    return blocks;
  }

  String _encodeBlockSlice(List<BlockNode> blocks, {String? plain}) {
    final payload = jsonEncode(<String, Object?>{
      'type': 'blocks',
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'plain': plain ?? blocks.map(_plainTextForBlock).join('\n'),
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
      final content = _blockTextContent(block);
      if (i == start.blockIndex && content != null) {
        lines.add(
          _plainTextForInlineNodes(
            _sliceInline(content, start.offset, inlineNodesLength(content)),
          ),
        );
      } else if (i == end.blockIndex && content != null) {
        lines.add(
          _plainTextForInlineNodes(_sliceInline(content, 0, end.offset)),
        );
      } else if (i == start.blockIndex) {
        final text = _plainTextForBoundary(block, start);
        lines.add(text.substring(_clampOffset(start.offset, text.length)));
      } else if (i == end.blockIndex) {
        final text = _plainTextForBoundary(block, end);
        lines.add(text.substring(0, _clampOffset(end.offset, text.length)));
      } else {
        lines.add(content == null
            ? _plainTextForBlock(block)
            : _plainTextForInlineNodes(content));
      }
    }
    return lines.join('\n');
  }

  List<InlineNode>? _blockTextContent(BlockNode block) {
    return switch (block) {
      TextBlockNode() => block.content,
      CalloutBlockNode() => block.content,
      _ => null,
    };
  }

  BlockNode _copyTextLikeBlockWithContent(
      BlockNode block, List<InlineNode> content,
      {required bool preserveCalloutMetadata}) {
    return switch (block) {
      TextBlockNode() => TextBlockNode(
          id: block.id,
          type: block.type,
          attributes: block.attributes,
          content: content,
        ),
      CalloutBlockNode() => preserveCalloutMetadata
          ? block.copyWith(content: content)
          : CalloutBlockNode(
              id: block.id,
              content: content,
              variant: block.variant,
              icon: block.icon,
              attributes: block.attributes,
            ),
      _ => block.copy(),
    };
  }

  BlockNode _htmlBlockForInlineSlice(
    BlockNode? context,
    List<InlineNode> content,
  ) {
    if (context is TextBlockNode) {
      return TextBlockNode(
        id: context.id,
        type: context.type,
        attributes: context.attributes,
        content: content,
      );
    }
    return TextBlockNode(
      id: context?.id ?? 'clipboard-inline',
      type: BlockType.paragraph,
      content: content,
    );
  }

  String _htmlForBlocks(List<BlockNode> blocks) {
    return htmlCodec.encodeBlocks(blocks);
  }

  TableBlockNode _sliceTableBlock(TableBlockNode block, TableCellRange range) {
    final rows = <List<TableCellNode>>[];
    for (var rowIndex = range.startRow; rowIndex <= range.endRow; rowIndex++) {
      final row = <TableCellNode>[];
      for (var columnIndex = range.startColumn;
          columnIndex <= range.endColumn;
          columnIndex++) {
        final cell = block.table.cellAt(rowIndex, columnIndex);
        row.add(
          cell == null
              ? TableCellNode(id: '${block.id}-r$rowIndex-c$columnIndex')
              : _copyTableCellForRange(cell, rowIndex, columnIndex, range),
        );
      }
      rows.add(row);
    }
    return TableBlockNode(
      id: block.id,
      table: TableModel(
        rows: rows,
        columnAlignments: _sliceTableColumnMap(
          block.table.columnAlignments,
          range,
        ),
        columnWidths: _sliceTableColumnMap(block.table.columnWidths, range),
      ),
      attributes: block.attributes,
    );
  }

  TableCellNode _copyTableCellForRange(
    TableCellNode cell,
    int rowIndex,
    int columnIndex,
    TableCellRange range,
  ) {
    final maxRowSpan = range.endRow - rowIndex + 1;
    final maxColumnSpan = range.endColumn - columnIndex + 1;
    return TableCellNode(
      id: cell.id,
      blocks: cell.blocks.map((block) => block.copy()).toList(),
      rowSpan: cell.rowSpan.clamp(1, maxRowSpan).toInt(),
      columnSpan: cell.columnSpan.clamp(1, maxColumnSpan).toInt(),
      isHeader: cell.isHeader,
      backgroundColor: cell.backgroundColor,
      covered: cell.covered,
      alignment: cell.alignment,
    );
  }

  Map<int, T> _sliceTableColumnMap<T>(
    Map<int, T> source,
    TableCellRange range,
  ) {
    final result = <int, T>{};
    for (var columnIndex = range.startColumn;
        columnIndex <= range.endColumn;
        columnIndex++) {
      final value = source[columnIndex];
      if (value != null) {
        result[columnIndex - range.startColumn] = value;
      }
    }
    return result;
  }

  String _plainTextForBoundary(BlockNode block, DocumentPosition position) {
    if (block is CalloutBlockNode && position.path.isBlockText) {
      return _plainTextForInlineNodes(block.content);
    }
    if (block is TextBlockNode && position.path.isBlockText) {
      return _plainTextForInlineNodes(block.content);
    }
    return _plainTextForBlock(block);
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

  /// Converts prepared external image descriptions into a blocks paste payload.
  ClipboardPaste? parseExternalImages(
    List<ExternalImageBlockDescription> images, {
    required String Function() newBlockId,
  }) {
    final blocks = <ImageBlockNode>[];
    for (final image in images) {
      final file = image.file.trim();
      if (file.isEmpty) {
        continue;
      }
      final fallbackLabel = _externalImageFallbackLabel(file);
      final caption = _nonEmptyExternalImageMetadata(image.caption) ??
          _nonEmptyExternalImageMetadata(image.altText) ??
          fallbackLabel;
      final altText = _nonEmptyExternalImageMetadata(image.altText) ?? caption;
      blocks.add(
        ImageBlockNode(
          id: newBlockId(),
          assetId: '',
          file: file,
          width: _positiveExternalImageDimension(image.width),
          height: _positiveExternalImageDimension(image.height),
          caption: caption,
          altText: altText,
        ),
      );
    }
    if (blocks.isEmpty) {
      return null;
    }
    return ClipboardPaste.blocks(blocks);
  }

  int _positiveExternalImageDimension(int? value) {
    return value == null || value <= 0 ? 0 : value;
  }

  String _externalImageFallbackLabel(String file) {
    return _externalImageFileStem(file) ?? defaultExternalImageCaption;
  }

  String? _nonEmptyExternalImageMetadata(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _externalImageFileStem(String value) {
    final withoutQuery = value.split('?').first.split('#').first;
    final slash = withoutQuery.lastIndexOf('/');
    final backslash = withoutQuery.lastIndexOf('\\');
    final segmentStart = slash > backslash ? slash : backslash;
    final segment = segmentStart < 0
        ? withoutQuery
        : withoutQuery.substring(segmentStart + 1);
    final decoded = _decodeExternalImageFileSegment(segment);
    final normalized = _nonEmptyExternalImageMetadata(decoded);
    if (normalized == null) {
      return null;
    }
    final dot = normalized.lastIndexOf('.');
    return _nonEmptyExternalImageMetadata(
      dot <= 0 ? normalized : normalized.substring(0, dot),
    );
  }

  String _decodeExternalImageFileSegment(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }

  ClipboardPaste? _blocksPaste(RichTextDocument document) {
    if (document.blocks.isEmpty) {
      return null;
    }
    return ClipboardPaste.blocks(
      document.blocks,
      tableCellMatrix: _tableCellMatrixFromBlocks(document.blocks),
    );
  }

  ClipboardTableCellMatrix? _tableCellMatrixFromBlocks(
    List<BlockNode> blocks,
  ) {
    if (blocks.length != 1 || blocks.single is! TableBlockNode) {
      return null;
    }
    final table = (blocks.single as TableBlockNode).table;
    if (table.rowCount == 0 || table.columnCount == 0) {
      return null;
    }
    return ClipboardTableCellMatrix(
      table.rows
          .map(
            (row) => row
                .map(
                  (cell) => cell.blocks.map((block) => block.copy()).toList(),
                )
                .toList(),
          )
          .toList(),
    );
  }

  ClipboardTableCellMatrix? _tableCellMatrixFromPlainText(String text) {
    // A single plain-text value must remain an inline paste. A tab or line
    // break is the explicit spreadsheet/table signal, including 1×N and N×1
    // ranges.
    if (!text.contains('\t') && !text.contains('\n') && !text.contains('\r')) {
      return null;
    }
    final rows = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map(
          (line) => line
              .split('\t')
              .map(
                (value) => <BlockNode>[
                  TextBlockNode(
                    id: '',
                    type: BlockType.paragraph,
                    content: value.isEmpty
                        ? const <InlineNode>[]
                        : <InlineNode>[TextRun(text: value)],
                  ),
                ],
              )
              .toList(),
        )
        .toList();
    return ClipboardTableCellMatrix(rows);
  }
}

String _clipboardBlocksSummary(List<BlockNode> blocks) {
  if (blocks.isEmpty) {
    return '[]';
  }
  const maxBlocks = 20;
  final visible = blocks.take(maxBlocks).map((block) {
    final attrs = block.attributes;
    return '{id:${WenzClipboardDebugLog.preview(block.id)},'
        'type:${block.type.name},listType:${attrs.listType},'
        'checked:${attrs.checked},indent:${attrs.indent},'
        'textLength:${block.plainText.length},'
        'text:${WenzClipboardDebugLog.preview(block.plainText)}}';
  }).join(',');
  final hidden = blocks.length - maxBlocks;
  return '[$visible${hidden > 0 ? ',…+$hidden blocks' : ''}]';
}

/// Result of parsing clipboard data.
class ClipboardPaste {
  const ClipboardPaste.inline(this.inlineRuns)
      : blocks = const <BlockNode>[],
        plainText = null,
        tableCellMatrix = null,
        isRich = true,
        isBlocks = false;

  const ClipboardPaste.plain(this.plainText, {this.tableCellMatrix})
      : inlineRuns = const <InlineNode>[],
        blocks = const <BlockNode>[],
        isRich = false,
        isBlocks = false;

  const ClipboardPaste.blocks(this.blocks, {this.tableCellMatrix})
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

  /// Table-shaped content detected from TSV, HTML, or a Wenz table payload.
  /// This remains optional so callers outside a table retain normal paste
  /// semantics for the original clipboard flavour.
  final ClipboardTableCellMatrix? tableCellMatrix;

  final bool isRich;

  /// Whether this paste carries whole-block structure (cross-block copy).
  final bool isBlocks;

  bool get hasContent {
    if (isBlocks) {
      return blocks.isNotEmpty;
    }
    if (isRich) {
      return inlineRuns.isNotEmpty;
    }
    return (plainText ?? '').isNotEmpty;
  }

  /// Plain-text view of the paste content regardless of flavour.
  String get text {
    if (isBlocks) {
      return blocks.map(_plainTextForBlock).join('\n');
    }
    if (!isRich) {
      return plainText ?? '';
    }
    return _plainTextForInlineNodes(inlineRuns);
  }
}

String _plainTextForInlineNodes(List<InlineNode> nodes) {
  return nodes.map(_plainTextForInlineNode).join();
}

String _plainTextForInlineNode(InlineNode node) {
  if (node is InlineEmbed && _isFormulaEmbedType(node.embedType)) {
    return _formulaPlainText(node.data);
  }
  return node.plainText;
}

String _plainTextForBlock(BlockNode block) {
  if (block is ImageBlockNode) {
    return '[image: ${_imagePlainTextLabel(block)}]';
  }
  if (block is VideoBlockNode) {
    return '[video: ${_videoPlainTextLabel(block)}]';
  }
  if (block is FileBlockNode) {
    return '[file: ${block.displayName}]';
  }
  if (block is DividerBlockNode) {
    return '---';
  }
  if (block is TableBlockNode && block.plainText.isEmpty) {
    return '[table]';
  }
  if (block is BlockEmbedNode) {
    if (block.isFormula) {
      final formula = block.formulaText.trim();
      return formula.isEmpty ? '[formula]' : formula;
    }
    return '[embed:${block.normalizedEmbedType}: ${block.displayText}]';
  }
  return block.plainText;
}

String _imagePlainTextLabel(ImageBlockNode image) {
  final label = image.caption.trim().isNotEmpty
      ? image.caption.trim()
      : image.altText.trim().isNotEmpty
          ? image.altText.trim()
          : image.file.trim().isNotEmpty
              ? image.file.trim()
              : image.assetId.trim();
  return label.isEmpty ? 'image' : label;
}

String _videoPlainTextLabel(VideoBlockNode video) {
  final label = video.displayText.trim();
  return label.isEmpty ? 'video' : label;
}

bool _isFormulaEmbedType(String embedType) => embedType.trim() == 'formula';

String _formulaPlainText(Map<String, Object?> data) {
  for (final key in const <String>['text', 'latex', 'value', 'formula']) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '[formula]';
}

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}

int _clampOffset(int offset, int length) {
  return offset.clamp(0, length).toInt();
}

String? _nonEmptyClipboardString(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : value;
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
