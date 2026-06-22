import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;

import '../core/model/attributes.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/rich_text_document.dart';
import '../core/model/table_model.dart';

/// Exports and imports a [RichTextDocument] as an HTML fragment.
///
/// **Export** (`encode`) maps each block to its HTML element and each inline
/// run to `<strong>` / `<em>` / `<s>` / `<u>` / `<a>` tags, joining blocks with
/// newlines.
///
/// **Import** (`decode`) uses `package:html` (a pure-Dart HTML5 parser) to turn
/// an HTML fragment into a document. Recognised block tags (`<p>`, `<h1>`–
/// `<h6>`, `<ul>`/`<ol>`/`<li>`, `<blockquote>`, `<pre>`, `<table>`, `<hr>`,
/// `<img>`) map to their block counterparts; inline tags (`<strong>`/`<b>`,
/// `<em>`/`<i>`, `<s>`/`<del>`/`<strike>`, `<u>`, `<a>`, `<img>`) map to
/// [TextAttributes] with nesting merged. Unrecognised content falls back to a
/// paragraph (HTML5 leniency — `decode` does not throw for content).
///
/// This is the package's first third-party runtime dependency (`package:html`).
/// See `docs/architecture.md`.
class HtmlCodec {
  const HtmlCodec();

  // ---------------------------------------------------------------------------
  // Export: document -> HTML fragment
  // ---------------------------------------------------------------------------

  /// Encodes [document] to an HTML fragment string. Each block becomes its
  /// HTML element; inline runs are wrapped in emphasis/anchor tags.
  String encode(RichTextDocument document) {
    final buffer = StringBuffer();
    for (var i = 0; i < document.blocks.length; i++) {
      if (i > 0) {
        buffer.write('\n');
      }
      final rendered = _encodeBlock(document.blocks[i]);
      if (rendered != null) {
        buffer.write(rendered);
      }
    }
    return buffer.toString();
  }

  String? _encodeBlock(BlockNode block) {
    switch (block.type) {
      case BlockType.heading:
        final text = block as TextBlockNode;
        final level = (text.attributes.level ?? 1).clamp(1, 6);
        return '<h$level>${_encodeInline(text.content)}</h$level>';
      case BlockType.paragraph:
        final text = block as TextBlockNode;
        if (text.content.isEmpty) {
          return '<p></p>';
        }
        return '<p>${_encodeInline(text.content)}</p>';
      case BlockType.quote:
        final text = block as TextBlockNode;
        return '<blockquote>${_encodeInline(text.content)}</blockquote>';
      case BlockType.listItem:
        return _encodeListItem(block as TextBlockNode);
      case BlockType.code:
        final code = block as CodeBlockNode;
        final langClass =
            code.language.isNotEmpty ? ' class="language-${code.language}"' : '';
        final escaped = _escapeHtml(code.code);
        return '<pre><code$langClass>$escaped</code></pre>';
      case BlockType.table:
        return _encodeTable(block as TableBlockNode);
      case BlockType.image:
        final image = block as ImageBlockNode;
        final alt = _escapeHtml(image.file.isNotEmpty ? image.file : 'image');
        final src = _escapeHtml(
            image.assetId.isNotEmpty ? image.assetId : image.file);
        return '<img src="$src" alt="$alt">';
      case BlockType.video:
        final video = block as VideoBlockNode;
        final src = _escapeHtml(video.file.isNotEmpty ? video.file : video.assetId);
        return '<video src="$src"></video>';
      case BlockType.file:
        final file = block as FileBlockNode;
        final href = _escapeHtml(file.file.isNotEmpty ? file.file : file.assetId);
        final name = _escapeHtml(file.name.isNotEmpty ? file.name : file.assetId);
        return '<a href="$href">$name</a>';
      case BlockType.divider:
        return '<hr>';
      case BlockType.callout:
        final callout = block as CalloutBlockNode;
        // Callouts map to blockquotes; the variant is not preserved in HTML.
        return '<blockquote>${_encodeInline(callout.content)}</blockquote>';
    }
  }

  String _encodeListItem(TextBlockNode block) {
    final attrs = block.attributes;
    final body = _encodeInline(block.content);
    if (attrs.listType == 'task') {
      final checked = attrs.checked == true ? ' checked' : '';
      return '<ul><li><input type="checkbox"$checked disabled> $body</li></ul>';
    }
    if (attrs.listType == 'ordered') {
      return '<ol><li>$body</li></ol>';
    }
    return '<ul><li>$body</li></ul>';
  }

  String _encodeTable(TableBlockNode block) {
    final table = block.table;
    if (table.rows.isEmpty) {
      return '<table></table>';
    }
    final buffer = StringBuffer('<table>');
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      buffer.write('<tr>');
      for (final cell in row) {
        if (cell.covered) {
          continue;
        }
        final tag = cell.isHeader ? 'th' : 'td';
        buffer.write('<$tag>');
        for (final innerBlock in cell.blocks) {
          if (innerBlock is TextBlockNode) {
            buffer.write(_encodeInline(innerBlock.content));
          } else {
            buffer.write(_escapeHtml(innerBlock.plainText));
          }
        }
        buffer.write('</$tag>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</table>');
    return buffer.toString();
  }

  /// Encodes a list of inline nodes to an HTML string, wrapping each run in
  /// tags for its active attributes.
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
    var text = _escapeHtml(run.text);
    final attrs = run.attributes;
    if (attrs.bold == true) {
      text = '<strong>$text</strong>';
    }
    if (attrs.italic == true) {
      text = '<em>$text</em>';
    }
    if (attrs.lineThrough == true) {
      text = '<s>$text</s>';
    }
    if (attrs.underline == true) {
      text = '<u>$text</u>';
    }
    if (attrs.url != null && attrs.url!.isNotEmpty) {
      final href = _escapeHtml(attrs.url!);
      text = '<a href="$href">$text</a>';
    }
    return text;
  }

  String _encodeEmbed(InlineEmbed embed) {
    if (embed.embedType == 'image') {
      final url = _escapeHtml('${embed.data['assetId'] ?? embed.data['id'] ?? ''}');
      final alt = _escapeHtml('${embed.data['text'] ?? ''}');
      return '<img src="$url" alt="$alt">';
    }
    return _escapeHtml(embed.plainText.trim());
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  // ---------------------------------------------------------------------------
  // Import: HTML fragment -> document (via package:html)
  // ---------------------------------------------------------------------------

  /// Decodes [source] HTML into a [RichTextDocument]. HTML5's leniency means
  /// any unrecognised / malformed content becomes paragraphs; [decode] does
  /// not throw for content.
  RichTextDocument decode(String source) {
    final fragment = parser.parseFragment(source);
    final blocks = <BlockNode>[];
    var blockSeq = 0;

    String newId(String prefix) => 'html-${blockSeq++}-$prefix';

    for (final node in fragment.nodes) {
      _decodeNode(node, blocks, newId);
    }

    // A fragment with no recognised blocks (e.g. plain text or empty) still
    // yields at least one paragraph so the document is never empty.
    if (blocks.isEmpty) {
      blocks.add(TextBlockNode(
        id: newId('p'),
        type: BlockType.paragraph,
        content: const <InlineNode>[],
      ));
    }
    return RichTextDocument(blocks: blocks);
  }

  /// Decodes a single DOM [node] into zero or more blocks appended to
  /// [blocks].
  void _decodeNode(
    dom.Node node,
    List<BlockNode> blocks,
    String Function(String) newId,
  ) {
    if (node is dom.Element) {
      final tag = node.localName!.toLowerCase();
      switch (tag) {
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          final level = int.parse(tag.substring(1));
          blocks.add(TextBlockNode(
            id: newId('h'),
            type: BlockType.heading,
            attributes: BlockAttributes(level: level),
            content: _parseInline(node),
          ));
          return;
        case 'p':
          final inline = _parseInline(node);
          blocks.add(TextBlockNode(
            id: newId('p'),
            type: BlockType.paragraph,
            content: inline,
          ));
          return;
        case 'blockquote':
          // Flatten blockquote children into a single quote block.
          blocks.add(TextBlockNode(
            id: newId('quote'),
            type: BlockType.quote,
            content: _parseInline(node),
          ));
          return;
        case 'ul':
        case 'ol':
          final listType = tag == 'ol' ? 'ordered' : null;
          for (final child in node.children) {
            if (child.localName?.toLowerCase() == 'li') {
              blocks.add(_decodeListItem(child, listType, newId));
            }
          }
          return;
        case 'pre':
          blocks.add(_decodePre(node, newId));
          return;
        case 'table':
          blocks.add(_decodeTable(node, newId('table')));
          return;
        case 'hr':
          blocks.add(DividerBlockNode(id: newId('hr')));
          return;
        case 'img':
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? '';
          if (src.isNotEmpty) {
            blocks.add(ImageBlockNode(
              id: newId('image'),
              assetId: src,
              file: alt,
            ));
          }
          return;
        case 'br':
          return;
        default:
          // Unknown container (div/span/section/…): recurse into children so a
          // `<div><p>…</p></div>` still yields its paragraph.
          if (node.nodes.isNotEmpty) {
            for (final child in node.nodes) {
              _decodeNode(child, blocks, newId);
            }
          } else if (node.text.trim().isNotEmpty) {
            blocks.add(TextBlockNode(
              id: newId('p'),
              type: BlockType.paragraph,
              content: _parseInline(node),
            ));
          }
          return;
      }
    } else if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isNotEmpty) {
        blocks.add(TextBlockNode(
          id: newId('p'),
          type: BlockType.paragraph,
          content: _parseInlineText(text),
        ));
      }
    }
  }

  TextBlockNode _decodeListItem(
    dom.Element li,
    String? listType,
    String Function(String) newId,
  ) {
    // Detect a leading checkbox input for task list items.
    var checked = false;
    var isTask = false;
    dom.Element? checkboxInput;
    for (final child in li.children) {
      if (child.localName?.toLowerCase() == 'input') {
        final type = child.attributes['type'];
        if (type == 'checkbox') {
          isTask = true;
          checked = child.attributes.containsKey('checked');
          checkboxInput = child;
          break;
        }
      }
    }

    // Build the inline content, dropping the checkbox input node.
    final inline = <InlineNode>[];
    for (final child in li.nodes) {
      if (child == checkboxInput) {
        continue;
      }
      inline.addAll(_parseInline(child));
    }

    final effectiveListType = isTask ? 'task' : listType;
    return TextBlockNode(
      id: newId(isTask ? 'task' : (listType == 'ordered' ? 'oli' : 'li')),
      type: BlockType.listItem,
      attributes: BlockAttributes(
        listType: effectiveListType,
        checked: isTask ? checked : null,
      ),
      content: inline,
    );
  }

  BlockNode _decodePre(dom.Element pre, String Function(String) newId) {
    // `<pre><code class="language-dart">…</code></pre>` — language from class.
    var language = '';
    var codeText = pre.text;
    final codeChild = pre.querySelector('code');
    if (codeChild != null) {
      final cls = codeChild.attributes['class'] ?? '';
      final langMatch = RegExp(r'language-(\S+)').firstMatch(cls);
      if (langMatch != null) {
        language = langMatch.group(1)!;
      }
      codeText = codeChild.text;
    }
    // `package:html` decodes entities in `.text`, so the code is already
    // unescaped — emit it verbatim.
    return CodeBlockNode(
      id: newId('code'),
      code: codeText,
      language: language,
    );
  }

  BlockNode _decodeTable(dom.Element table, String tableId) {
    final rows = <List<TableCellNode>>[];
    final trList = table.querySelectorAll('tr');
    // If a <thead> exists, its rows are headers.
    final thead = table.querySelector('thead');
    for (var r = 0; r < trList.length; r++) {
      final tr = trList[r];
      final isHeaderRow = thead != null && thead.contains(tr);
      final cells = <TableCellNode>[];
      final cellElements = tr.children
          .where((e) => e.localName == 'th' || e.localName == 'td');
      var c = 0;
      for (final cell in cellElements) {
        final isHeader = isHeaderRow || cell.localName == 'th';
        cells.add(TableCellNode(
          id: '$tableId-r$r-c$c',
          isHeader: isHeader,
          blocks: <BlockNode>[
            TextBlockNode(
              id: '$tableId-r$r-c$c-p',
              type: BlockType.paragraph,
              content: _parseInline(cell),
            ),
          ],
        ));
        c++;
      }
      rows.add(cells);
    }
    return TableBlockNode(
      id: tableId,
      table: TableModel(rows: rows),
    );
  }

  /// Parses the inline content of [node] into a list of [InlineNode]s,
  /// recursing into child elements and merging nested emphasis attributes.
  List<InlineNode> _parseInline(dom.Node node) {
    final runs = <InlineNode>[];
    for (final child in node.nodes) {
      runs.addAll(_parseInlineNode(child, const TextAttributes()));
    }
    return _coalesce(runs);
  }

  /// Parses a single DOM node as inline content, carrying inherited
  /// [attributes] for nested emphasis.
  List<InlineNode> _parseInlineNode(
    dom.Node node,
    TextAttributes attributes,
  ) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isEmpty) {
        return const <InlineNode>[];
      }
      return <InlineNode>[TextRun(text: text, attributes: attributes)];
    }
    if (node is dom.Element) {
      final tag = node.localName!.toLowerCase();
      switch (tag) {
        case 'strong':
        case 'b':
          return _parseChildren(
              node, attributes.copyWith(bold: true));
        case 'em':
        case 'i':
          return _parseChildren(
              node, attributes.copyWith(italic: true));
        case 's':
        case 'del':
        case 'strike':
          return _parseChildren(
              node, attributes.copyWith(lineThrough: true));
        case 'u':
          return _parseChildren(
              node, attributes.copyWith(underline: true));
        case 'a':
          final href = node.attributes['href'] ?? '';
          return _parseChildren(
              node, attributes.copyWith(url: href.isEmpty ? null : href));
        case 'br':
          return const <InlineNode>[TextRun(text: '\n')];
        case 'img':
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? '';
          if (src.isEmpty) {
            return <InlineNode>[TextRun(text: alt, attributes: attributes)];
          }
          return <InlineNode>[
            InlineEmbed(
              embedType: 'image',
              data: <String, Object?>{'assetId': src, 'text': alt},
              attributes: attributes,
            ),
          ];
        case 'span':
        case 'sub':
        case 'sup':
        case 'code':
          // Inline code / generic wrappers: recurse with current attrs.
          return _parseChildren(node, attributes);
        default:
          return _parseChildren(node, attributes);
      }
    }
    return const <InlineNode>[];
  }

  List<InlineNode> _parseChildren(
    dom.Element element,
    TextAttributes attributes,
  ) {
    final runs = <InlineNode>[];
    for (final child in element.nodes) {
      runs.addAll(_parseInlineNode(child, attributes));
    }
    return runs;
  }

  /// Parses a bare text string into a single-run paragraph's inline list.
  List<InlineNode> _parseInlineText(String text) {
    if (text.isEmpty) {
      return const <InlineNode>[];
    }
    return <InlineNode>[TextRun(text: text)];
  }

  /// Merges adjacent [TextRun]s with identical attributes so the output run
  /// list is compact.
  List<InlineNode> _coalesce(List<InlineNode> nodes) {
    if (nodes.isEmpty) {
      return nodes;
    }
    final result = <InlineNode>[nodes.first.copy()];
    for (var i = 1; i < nodes.length; i++) {
      final node = nodes[i];
      final last = result.last;
      if (node is TextRun && last is TextRun &&
          node.attributes == last.attributes) {
        result[result.length - 1] = TextRun(
          text: last.text + node.text,
          attributes: last.attributes,
        );
      } else {
        result.add(node.copy());
      }
    }
    return result;
  }
}
