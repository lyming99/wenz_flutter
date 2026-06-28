import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/model/table_model.dart';

/// Exports and imports a [RichTextDocument] as GitHub-Flavored Markdown.
///
/// **Export** (`encode`) maps every block to its Markdown representation and
/// every inline run to `**bold**` / `*italic*` / `~~strike~~` / `<u>underline</u>`
/// / `[text](url)` syntax, joining blocks with blank lines.
///
/// **Import** (`decode`) runs a line-oriented state machine that recognises:
/// ATX headings (`#{1,6}`), unordered (`- `/`* `), ordered (`1. `), and task
/// (`- [x] `/`- [ ]`) lists, blockquotes (`> `), fenced code blocks
/// (``` ``` ```), GFM pipe tables, thematic breaks (`---`/`***`), images
/// (`![alt](url)`), Wenz video placeholders (`![video](url "wenz-video; …")`), and inline
/// `**bold**`/`*italic*`/`~~strike~~`/`<u>u</u>`/`[text](url)`. Anything
/// unrecognised falls back to a paragraph (Markdown's usual leniency —
/// [decode] never throws for content).
///
/// Coverage is aligned with the `gpt_markdown` syntax matrix for the block/
/// inline kinds this package models; LaTeX / radio buttons have no model
/// counterpart and are left as plain text. Underline uses `<u>` because GFM
/// has no native underline syntax.
///
/// The codec serializes document content only. Editor-owned view state such as
/// heading collapse is not emitted, so imported Markdown starts expanded while
/// preserving every block in source order.
class MarkdownCodec {
  const MarkdownCodec();

  // ---------------------------------------------------------------------------
  // Export: document -> Markdown
  // ---------------------------------------------------------------------------

  /// Encodes [document] to a Markdown string. Blocks are separated by a blank
  /// line; media blocks without a Markdown form emit a best-effort placeholder.
  String encode(RichTextDocument document) {
    final sections = <String>[];
    for (final block in document.blocks) {
      final rendered = _encodeBlock(block);
      if (rendered != null) {
        sections.add(rendered);
      }
    }
    return sections.join('\n\n');
  }

  String? _encodeBlock(BlockNode block) {
    switch (block.type) {
      case BlockType.heading:
        final text = block as TextBlockNode;
        final level = text.attributes.level ?? 1;
        final hashes = '#' * level.clamp(1, 6);
        return '$hashes ${_encodeInline(text.content)}';
      case BlockType.paragraph:
        final text = block as TextBlockNode;
        if (text.content.isEmpty) {
          return null;
        }
        return _encodeInline(text.content);
      case BlockType.quote:
        final text = block as TextBlockNode;
        final body = _encodeInline(text.content);
        // Prefix every line with `> ` so multi-line quotes stay valid.
        return body.split('\n').map((line) => '> $line').join('\n');
      case BlockType.listItem:
        return _encodeListItem(block as TextBlockNode);
      case BlockType.code:
        final code = block as CodeBlockNode;
        final fence = '```${code.language}';
        return '$fence\n${code.code}\n```';
      case BlockType.table:
        return _encodeTable(block as TableBlockNode);
      case BlockType.image:
        final image = block as ImageBlockNode;
        final alt = _imageAlt(image);
        final src = image.assetId.isNotEmpty ? image.assetId : image.file;
        final title = image.caption.isEmpty
            ? ''
            : ' "${_escapeImageTitle(image.caption)}"';
        return '![${_escapeImageAlt(alt)}]($src$title)';
      case BlockType.video:
        final video = block as VideoBlockNode;
        final src = _videoSource(video);
        final title = _videoMarkdownTitle(video, src);
        if (title.isEmpty) {
          return '![video]($src)';
        }
        return '![video]($src "${_escapeImageTitle(title)}")';
      case BlockType.embed:
        final embed = block as BlockEmbedNode;
        return '[${_escapeInline(embed.normalizedEmbedType)} embed: '
            '${_escapeInline(embed.displayText)}]';
      case BlockType.file:
        final file = block as FileBlockNode;
        return '[${file.displayName}](${file.effectiveDownloadUrl})';
      case BlockType.divider:
        return '---';
      case BlockType.callout:
        // Callouts degrade to blockquotes in plain Markdown. The visible icon,
        // title and body are preserved, but the structured variant is not.
        final callout = block as CalloutBlockNode;
        final title = '${callout.effectiveIcon} ${callout.effectiveTitle}';
        final lines = <String>['**${_escapeInline(title)}**'];
        final body = _encodeInline(callout.content);
        if (body.isNotEmpty) {
          lines.addAll(body.split('\n'));
        }
        return lines.map((line) => '> $line').join('\n');
    }
  }

  String _encodeListItem(TextBlockNode block) {
    final indent = block.attributes.indent ?? 0;
    final pad = '  ' * indent;
    final attrs = block.attributes;
    final body = _encodeInline(block.content);
    if (attrs.listType == 'ordered') {
      if (attrs.checked != null) {
        final box = attrs.checked == true ? '[x]' : '[ ]';
        return '${pad}1. $box $body';
      }
      return '${pad}1. $body';
    }
    if (attrs.listType == 'task') {
      final box = attrs.checked == true ? '[x]' : '[ ]';
      return '$pad- $box $body';
    }
    return '$pad- $body';
  }

  String _encodeTable(TableBlockNode block) {
    final table = block.table;
    if (table.rows.isEmpty) {
      return '';
    }
    final columnCount = table.columnCount;
    final lines = <String>[];

    String cellText(TableCellNode cell) {
      final text = cell.plainText;
      // Cells are inline-only in GFM; escape pipes so they don't break columns.
      return text.replaceAll('|', '\\|');
    }

    String alignmentMarker(int column) {
      final align = table.columnAlignments[column];
      if (align == 'center') {
        return ':---:';
      }
      if (align == 'right') {
        return '---:';
      }
      if (align == 'left') {
        return ':---';
      }
      return '---';
    }

    // Header row (first row) + separator.
    final header = table.rows.first;
    lines.add(List.generate(columnCount, (c) {
      final cell = c < header.length ? header[c] : null;
      return cell == null || cell.covered ? '' : cellText(cell);
    }).join(' | '));
    lines.add(List.generate(columnCount, alignmentMarker).join(' | '));

    // Body rows (skip the first).
    for (var r = 1; r < table.rows.length; r++) {
      final row = table.rows[r];
      lines.add(List.generate(columnCount, (c) {
        final cell = c < row.length ? row[c] : null;
        return cell == null || cell.covered ? '' : cellText(cell);
      }).join(' | '));
    }
    return lines.join('\n');
  }

  /// Encodes a list of inline nodes to a Markdown string, applying each run's
  /// attributes as inline markup.
  String _encodeInline(List<InlineNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is TextRun) {
        buffer.write(_encodeTextRun(node));
      } else if (node is InlineEmbed) {
        buffer.write(_encodeEmbed(node));
      }
    }
    return buffer.toString();
  }

  String _encodeTextRun(TextRun run) {
    var text = _escapeInline(run.text);
    final attrs = run.attributes;
    if (attrs.lineThrough == true) {
      text = '~~$text~~';
    }
    if (attrs.bold == true) {
      text = '**$text**';
    }
    if (attrs.italic == true) {
      text = '*$text*';
    }
    if (attrs.underline == true) {
      text = '<u>$text</u>';
    }
    if (attrs.url != null && attrs.url!.isNotEmpty) {
      text = '[$text](${attrs.url})';
    }
    return text;
  }

  String _encodeEmbed(InlineEmbed embed) {
    if (embed.embedType == 'image') {
      final url = embed.data['assetId'] ?? embed.data['id'] ?? '';
      final alt =
          (embed.data['altText'] ?? embed.data['text']) as String? ?? '';
      final caption = embed.data['caption'] as String? ?? '';
      final title = caption.isEmpty ? '' : ' "${_escapeImageTitle(caption)}"';
      return '![${_escapeImageAlt(alt)}]($url$title)';
    }
    // formula / mention / emoji: no standard Markdown — render the visible
    // fallback so export at least preserves readable characters.
    return _escapeInline(_embedDisplayText(embed));
  }

  String _embedDisplayText(InlineEmbed embed) {
    return switch (embed.embedType) {
      'mention' => _mentionDisplayText(embed),
      'formula' => _formulaDisplayText(embed),
      'emoji' => _emojiDisplayText(embed),
      _ => embed.plainText.trim(),
    };
  }

  String _mentionDisplayText(InlineEmbed embed) {
    final raw = embed.data['label'] ?? embed.data['id'];
    final label = raw?.toString() ?? '';
    return label.isEmpty ? '@mention' : '@$label';
  }

  String _formulaDisplayText(InlineEmbed embed) {
    final raw =
        embed.data['text'] ?? embed.data['latex'] ?? embed.data['value'];
    final text = raw?.toString() ?? '';
    return text.isEmpty ? '[formula]' : text;
  }

  String _emojiDisplayText(InlineEmbed embed) {
    final raw = embed.data['emoji'] ??
        embed.data['text'] ??
        embed.data['value'] ??
        embed.data['shortName'] ??
        embed.data['label'];
    final text = raw?.toString() ?? '';
    return text.isEmpty ? '[emoji]' : text;
  }

  /// Escapes characters that would otherwise start inline/block Markdown
  /// syntax when they appear at a run boundary. Kept minimal so output stays
  /// readable; only the chars that change parsing are escaped.
  String _escapeInline(String text) {
    // Avoid double-escaping: only escape when the char could start a construct.
    return text.replaceAllMapped(RegExp(r'([\\`*\_\[\]])'), (m) => '\\${m[1]}');
  }

  String _imageAlt(ImageBlockNode image) {
    if (image.altText.isNotEmpty) {
      return image.altText;
    }
    if (image.file.isNotEmpty) {
      return image.file;
    }
    if (image.caption.isNotEmpty) {
      return image.caption;
    }
    return 'image';
  }

  String _videoSource(VideoBlockNode video) {
    if (video.playbackUrl.isNotEmpty) {
      return video.playbackUrl;
    }
    if (video.file.isNotEmpty) {
      return video.file;
    }
    return video.assetId;
  }

  String _videoMarkdownTitle(VideoBlockNode video, String source) {
    final fields = <String, String>{};

    void add(String key, Object? value) {
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) {
        fields[key] = text;
      }
    }

    if (video.assetId.isNotEmpty &&
        (video.assetId != source ||
            video.playbackUrl.isNotEmpty ||
            video.file.isNotEmpty)) {
      add('assetId', video.assetId);
    }
    add('playbackUrl', video.playbackUrl);
    add('file', video.file);
    add('coverUrl', video.coverUrl);
    add('title', video.title);
    add('description', video.description);
    final aspectRatio = video.aspectRatio;
    if (aspectRatio != null && aspectRatio > 0) {
      add('aspectRatio', aspectRatio);
    }
    if (video.uploadStatus != FileUploadStatus.none) {
      add('uploadStatus', video.uploadStatus.name);
    }
    add('uploadError', video.uploadError);

    if (fields.isEmpty) {
      return '';
    }
    final body = fields.entries
        .map((entry) => '${entry.key}=${_escapeVideoMetaValue(entry.value)}')
        .join('; ');
    return 'wenz-video; $body';
  }

  String _escapeImageAlt(String text) {
    return text.replaceAll('\\', r'\\').replaceAll(']', r'\]');
  }

  String _escapeImageTitle(String text) {
    return text.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  String _escapeVideoMetaValue(String text) {
    return text
        .replaceAll('\\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll('=', r'\=');
  }

  // ---------------------------------------------------------------------------
  // Import: Markdown -> document
  // ---------------------------------------------------------------------------

  /// Decodes [source] Markdown into a [RichTextDocument]. Markdown's leniency
  /// means any unrecognised line becomes a paragraph; [decode] does not throw
  /// for content. (A non-String / null source is impossible at the type level.)
  RichTextDocument decode(String source) {
    final lines = source.split('\n');
    final blocks = <BlockNode>[];
    var blockSeq = 0;
    var i = 0;

    String newId(String prefix) => 'md-${blockSeq++}-$prefix';

    while (i < lines.length) {
      final line = lines[i];

      // Blank line: block separator, skip.
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // Fenced code block.
      final fenceMatch = _fenceRegex.firstMatch(line.trimLeft());
      if (fenceMatch != null) {
        final language = fenceMatch.group(2) ?? '';
        final codeLines = <String>[];
        i++;
        while (i < lines.length) {
          final codeLine = lines[i];
          if (_fenceRegex.hasMatch(codeLine.trimLeft())) {
            i++;
            break;
          }
          codeLines.add(codeLine);
          i++;
        }
        blocks.add(CodeBlockNode(
          id: newId('code'),
          code: codeLines.join('\n'),
          language: language,
        ));
        continue;
      }

      // Heading (ATX).
      final headingMatch = _headingRegex.firstMatch(line.trimLeft());
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!.trim();
        blocks.add(TextBlockNode(
          id: newId('h'),
          type: BlockType.heading,
          attributes: BlockAttributes(level: level),
          content: _parseInline(text),
        ));
        i++;
        continue;
      }

      // Thematic break.
      if (_thematicBreakRegex.hasMatch(line.trim())) {
        blocks.add(DividerBlockNode(id: newId('hr')));
        i++;
        continue;
      }

      // Blockquote (consecutive `>` lines aggregated).
      if (line.trimLeft().startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          quoteLines
              .add(lines[i].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(TextBlockNode(
          id: newId('quote'),
          type: BlockType.quote,
          content: _parseInline(quoteLines.join(' ')),
        ));
        continue;
      }

      // List item (unordered / ordered / task).
      final listMatch = _listItemRegex.firstMatch(line);
      if (listMatch != null) {
        final indent = (listMatch.group(1) ?? '').length ~/ 2;
        final marker = listMatch.group(2)!;
        final taskBox = listMatch.group(3); // `[x] ` / `[ ] ` or null.
        final body = (listMatch.group(4) ?? '').trim();

        if (marker.startsWith(RegExp(r'\d'))) {
          // Ordered list.
          final checked = taskBox?.toLowerCase().contains('x');
          blocks.add(TextBlockNode(
            id: newId('oli'),
            type: BlockType.listItem,
            attributes: BlockAttributes(
              indent: indent,
              listType: 'ordered',
              checked: checked,
            ),
            content: _parseInline(body),
          ));
        } else if (taskBox != null) {
          // Task list item: the box was captured by the list regex.
          final checked = taskBox.toLowerCase().contains('x');
          blocks.add(TextBlockNode(
            id: newId('task'),
            type: BlockType.listItem,
            attributes: BlockAttributes(
              indent: indent,
              listType: 'task',
              checked: checked,
            ),
            content: _parseInline(body),
          ));
        } else {
          blocks.add(TextBlockNode(
            id: newId('li'),
            type: BlockType.listItem,
            attributes: BlockAttributes(indent: indent),
            content: _parseInline(body),
          ));
        }
        i++;
        continue;
      }

      // GFM table: a pipe row followed by a separator row.
      if (_looksLikeTableRow(line) &&
          i + 1 < lines.length &&
          _looksLikeTableSeparator(lines[i + 1])) {
        final tableRows = <List<String>>[_splitTableRow(line)];
        final alignments = _parseTableAlignments(lines[i + 1]);
        i += 2;
        while (i < lines.length && _looksLikeTableRow(lines[i])) {
          tableRows.add(_splitTableRow(lines[i]));
          i++;
        }
        blocks.add(_buildTable(tableRows, alignments, newId('table')));
        continue;
      }

      // Paragraph: gather consecutive non-blank, non-structural lines.
      final paraLines = <String>[line];
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_startsBlock(lines[i])) {
        paraLines.add(lines[i]);
        i++;
      }
      final paraText = paraLines.join(' ');
      // An image-only paragraph becomes an image block; Wenz video export uses
      // the `![video](src)` readable placeholder and can be restored as video.
      final imageOnly = _imageOnlyRegex.firstMatch(paraText.trim());
      if (imageOnly != null) {
        final alt = _unescapeImageToken(imageOnly.group(1) ?? '');
        final caption = _unescapeImageToken(imageOnly.group(3) ?? '');
        final source = imageOnly.group(2)!;
        if (_isVideoPlaceholderAlt(alt)) {
          blocks.add(_videoFromMarkdown(
            id: newId('video'),
            source: source,
            alt: alt,
            title: caption,
          ));
        } else {
          blocks.add(ImageBlockNode(
            id: newId('image'),
            assetId: source,
            file: alt,
            caption: caption,
            altText: alt,
          ));
        }
      } else {
        blocks.add(TextBlockNode(
          id: newId('p'),
          type: BlockType.paragraph,
          content: _parseInline(paraText),
        ));
      }
    }

    return RichTextDocument(blocks: blocks);
  }

  /// Whether [line] would start a new block construct (used to bound paragraph
  /// aggregation). Code fences, headings, thematic breaks, blockquotes, and
  /// list items all count.
  bool _startsBlock(String line) {
    final trimmed = line.trimLeft();
    if (_fenceRegex.hasMatch(trimmed)) {
      return true;
    }
    if (_headingRegex.hasMatch(trimmed)) {
      return true;
    }
    if (_thematicBreakRegex.hasMatch(line.trim())) {
      return true;
    }
    if (trimmed.startsWith('>')) {
      return true;
    }
    if (_listItemRegex.hasMatch(line)) {
      return true;
    }
    if (_looksLikeTableRow(line)) {
      return true;
    }
    return false;
  }

  /// Parses inline markup (`**bold**`, `*italic*`, `~~strike~~`, `<u>u</u>`,
  /// `[text](url)`, `![alt](url)`) into a list of [InlineNode]s. Un-escapes
  /// backslash-escaped punctuation. Anything unmatched is plain text.
  List<InlineNode> _parseInline(String text) {
    if (text.isEmpty) {
      return const <InlineNode>[];
    }
    final runs = <InlineNode>[];
    final buffer = StringBuffer();

    void flush({TextAttributes? attrs}) {
      if (buffer.isNotEmpty) {
        runs.add(TextRun(
          text: buffer.toString(),
          attributes: attrs ?? const TextAttributes(),
        ));
        buffer.clear();
      }
    }

    var pos = 0;
    while (pos < text.length) {
      // Escaped character: `\x` → literal `x`.
      if (text[pos] == '\\' && pos + 1 < text.length) {
        buffer.write(text[pos + 1]);
        pos += 2;
        continue;
      }

      // Image: ![alt](url)
      final imageMatch = _inlineImageRegex.matchAsPrefix(text, pos);
      if (imageMatch != null) {
        final alt = _unescapeImageToken(imageMatch.group(1) ?? '');
        final caption = _unescapeImageToken(imageMatch.group(3) ?? '');
        flush();
        runs.add(InlineEmbed(
          embedType: 'image',
          data: <String, Object?>{
            'assetId': imageMatch.group(2),
            'text': alt,
            'altText': alt,
            if (caption.isNotEmpty) 'caption': caption,
          },
        ));
        pos = imageMatch.end;
        continue;
      }

      // Link: [text](url)
      final linkMatch = _inlineLinkRegex.matchAsPrefix(text, pos);
      if (linkMatch != null) {
        final label = linkMatch.group(1) ?? '';
        final url = linkMatch.group(2) ?? '';
        // Recurse to parse nested emphasis inside the label.
        final inner = _parseInline(label);
        if (inner.isEmpty) {
          buffer.write(label);
        } else {
          flush();
          for (final node in inner) {
            if (node is TextRun) {
              runs.add(TextRun(
                text: node.text,
                attributes: node.attributes.copyWith(url: url),
              ));
            } else {
              runs.add(node);
            }
          }
        }
        pos = linkMatch.end;
        continue;
      }

      // Bold: **text**
      final boldMatch = _boldRegex.matchAsPrefix(text, pos);
      if (boldMatch != null) {
        flush();
        final inner = _parseInline(boldMatch.group(1)!);
        for (final node in inner) {
          if (node is TextRun) {
            runs.add(TextRun(
              text: node.text,
              attributes: node.attributes.copyWith(bold: true),
            ));
          } else {
            runs.add(node);
          }
        }
        pos = boldMatch.end;
        continue;
      }

      // Italic: *text*
      final italicMatch = _italicRegex.matchAsPrefix(text, pos);
      if (italicMatch != null) {
        flush();
        final inner = _parseInline(italicMatch.group(1)!);
        for (final node in inner) {
          if (node is TextRun) {
            runs.add(TextRun(
              text: node.text,
              attributes: node.attributes.copyWith(italic: true),
            ));
          } else {
            runs.add(node);
          }
        }
        pos = italicMatch.end;
        continue;
      }

      // Strikethrough: ~~text~~
      final strikeMatch = _strikeRegex.matchAsPrefix(text, pos);
      if (strikeMatch != null) {
        flush();
        final inner = _parseInline(strikeMatch.group(1)!);
        for (final node in inner) {
          if (node is TextRun) {
            runs.add(TextRun(
              text: node.text,
              attributes: node.attributes.copyWith(lineThrough: true),
            ));
          } else {
            runs.add(node);
          }
        }
        pos = strikeMatch.end;
        continue;
      }

      // Underline: <u>text</u>
      final underlineMatch = _underlineRegex.matchAsPrefix(text, pos);
      if (underlineMatch != null) {
        flush();
        final inner = _parseInline(underlineMatch.group(1)!);
        for (final node in inner) {
          if (node is TextRun) {
            runs.add(TextRun(
              text: node.text,
              attributes: node.attributes.copyWith(underline: true),
            ));
          } else {
            runs.add(node);
          }
        }
        pos = underlineMatch.end;
        continue;
      }

      buffer.write(text[pos]);
      pos++;
    }
    flush();
    return runs;
  }

  bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return trimmed.contains('|') && !trimmed.startsWith('#');
  }

  bool _looksLikeTableSeparator(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    // A separator row is made of `|`, `-`, `:`, and spaces only, and must
    // contain at least one dash.
    if (!trimmed.contains('-')) {
      return false;
    }
    return RegExp(r'^[\s\|\:\-]+$').hasMatch(trimmed);
  }

  List<String> _splitTableRow(String line) {
    var trimmed = line.trim();
    // Strip a single leading/trailing pipe if present.
    if (trimmed.startsWith('|')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return _splitOnUnescapedPipe(trimmed)
        .map((cell) => cell.trim().replaceAll('\\|', '|'))
        .toList();
  }

  List<String> _splitOnUnescapedPipe(String text) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text[i] == '\\' && i + 1 < text.length && text[i + 1] == '|') {
        buffer.write('\\|');
        i += 2;
        continue;
      }
      if (text[i] == '|') {
        cells.add(buffer.toString());
        buffer.clear();
        i++;
        continue;
      }
      buffer.write(text[i]);
      i++;
    }
    cells.add(buffer.toString());
    return cells;
  }

  Map<int, String> _parseTableAlignments(String separator) {
    final cells = _splitTableRow(separator);
    final alignments = <int, String>{};
    for (var c = 0; c < cells.length; c++) {
      final cell = cells[c].trim();
      final leftColon = cell.startsWith(':');
      final rightColon = cell.endsWith(':');
      if (leftColon && rightColon) {
        alignments[c] = 'center';
      } else if (rightColon) {
        alignments[c] = 'right';
      } else if (leftColon) {
        alignments[c] = 'left';
      }
    }
    return alignments;
  }

  BlockNode _buildTable(
    List<List<String>> rows,
    Map<int, String> alignments,
    String id,
  ) {
    final tableRows = <List<TableCellNode>>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final cells = <TableCellNode>[];
      for (var c = 0; c < row.length; c++) {
        final isHeader = r == 0;
        cells.add(TableCellNode(
          id: '$id-r$r-c$c',
          isHeader: isHeader,
          blocks: <BlockNode>[
            TextBlockNode(
              id: '$id-r$r-c$c-p',
              type: BlockType.paragraph,
              content: _parseInline(row[c]),
            ),
          ],
        ));
      }
      tableRows.add(cells);
    }
    return TableBlockNode(
      id: id,
      table: TableModel(
        rows: tableRows,
        columnAlignments: alignments,
      ),
    );
  }

  VideoBlockNode _videoFromMarkdown({
    required String id,
    required String source,
    required String alt,
    required String title,
  }) {
    final metadata = _parseVideoMetadata(title);
    final plainTitle = metadata == null ? title.trim() : '';
    final altTitle = _videoTitleFromAlt(alt);
    final resolvedTitle =
        metadata?['title'] ?? (plainTitle.isNotEmpty ? plainTitle : altTitle);
    var assetId = metadata?['assetId'] ?? '';
    var playbackUrl = metadata?['playbackUrl'] ?? '';
    var file = metadata?['file'] ?? '';

    if (assetId.isEmpty && playbackUrl.isEmpty && file.isEmpty) {
      assetId = source;
    } else if (playbackUrl.isEmpty &&
        source.isNotEmpty &&
        source != assetId &&
        source != file) {
      playbackUrl = source;
    }

    return VideoBlockNode(
      id: id,
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: metadata?['coverUrl'] ?? '',
      title: resolvedTitle,
      description: metadata?['description'] ?? '',
      aspectRatio: _positiveDouble(metadata?['aspectRatio']),
      uploadStatus: FileUploadStatus.parse(metadata?['uploadStatus']),
      uploadError: metadata?['uploadError'] ?? '',
    );
  }

  Map<String, String>? _parseVideoMetadata(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final marker =
        RegExp(r'^wenz-video\b', caseSensitive: false).firstMatch(trimmed);
    if (marker == null) {
      return null;
    }
    var body = trimmed.substring(marker.end).trimLeft();
    if (body.startsWith(';')) {
      body = body.substring(1).trimLeft();
    }
    if (body.isEmpty) {
      return <String, String>{};
    }
    final result = <String, String>{};
    for (final part in _splitEscaped(body, ';')) {
      final trimmedPart = part.trim();
      if (trimmedPart.isEmpty) {
        continue;
      }
      final equalIndex = _indexOfUnescaped(trimmedPart, '=');
      if (equalIndex <= 0) {
        continue;
      }
      final key = trimmedPart.substring(0, equalIndex).trim();
      final value = trimmedPart.substring(equalIndex + 1).trim();
      if (key.isNotEmpty) {
        result[key] = _unescapeVideoMetaValue(value);
      }
    }
    return result;
  }

  List<String> _splitEscaped(String text, String separator) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (escaped) {
        buffer.write('\\');
        buffer.write(char);
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == separator) {
        parts.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (escaped) {
      buffer.write('\\');
    }
    parts.add(buffer.toString());
    return parts;
  }

  int _indexOfUnescaped(String text, String target) {
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == target) {
        return i;
      }
    }
    return -1;
  }

  String _unescapeVideoMetaValue(String text) {
    final buffer = StringBuffer();
    var escaped = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      buffer.write(char);
    }
    if (escaped) {
      buffer.write('\\');
    }
    return buffer.toString();
  }

  String _videoTitleFromAlt(String alt) {
    final trimmed = alt.trim();
    final match =
        RegExp(r'^video\s*:\s*(.+)$', caseSensitive: false).firstMatch(trimmed);
    return match?.group(1)?.trim() ?? '';
  }

  double? _positiveDouble(Object? value) {
    final text = value?.toString() ?? '';
    final parsed = double.tryParse(text);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String _unescapeImageToken(String text) {
    if (!text.contains('\\')) {
      return text;
    }
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '\\' && i + 1 < text.length) {
        buffer.write(text[i + 1]);
        i++;
      } else {
        buffer.write(text[i]);
      }
    }
    return buffer.toString();
  }

  bool _isVideoPlaceholderAlt(String alt) {
    final normalized = alt.trim().toLowerCase();
    return normalized == 'video' || normalized.startsWith('video:');
  }
}

// Regexes are anchored at match positions via `matchAsPrefix` / `firstMatch`
// rather than searching globally, so the inline scanner walks left-to-right and
// each construct is matched exactly where the cursor sits.

final RegExp _fenceRegex = RegExp(r'^(`{3,}|~{3,})(.*)$');
final RegExp _headingRegex = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _thematicBreakRegex =
    RegExp(r'^(-\s?){3,}$|^(\*\s?){3,}$|^(_\s?){3,}$');
final RegExp _listItemRegex =
    RegExp(r'^(\s*)(-|\*|\+|\d+\.)\s+(\[[ xX]\]\s+)?(.*)$');

// Inline patterns — each is matched at the current cursor position.
final RegExp _inlineImageRegex =
    RegExp(r'!\[([^\]]*)\]\(([^)\s]+)(?:\s+"((?:\\"|[^"])*)")?\)');
final RegExp _inlineLinkRegex = RegExp(r'\[([^\]]*)\]\(([^)]+)\)');
final RegExp _boldRegex = RegExp(r'\*\*([^*]+)\*\*');
final RegExp _italicRegex = RegExp(r'\*([^*]+)\*');
final RegExp _strikeRegex = RegExp(r'~~([^~]+)~~');
final RegExp _underlineRegex = RegExp(r'<u>([^<]*)</u>');

// Matches a paragraph that is a single image token (whitespace trimmed).
final RegExp _imageOnlyRegex =
    RegExp(r'^!\[([^\]]*)\]\(([^)\s]+)(?:\s+"((?:\\"|[^"])*)")?\)$');
