import 'dart:convert';

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
/// `<h6>`, `<ul>`/`<ol>`/`<li>`, `<blockquote>`, Wenz callout `<aside>`,
/// `<pre>`, `<table>`, `<hr>`, `<img>`, `<video>`) map to their block counterparts;
/// inline tags (`<strong>`/`<b>`, `<em>`/`<i>`, `<s>`/`<del>`/`<strike>`,
/// `<u>`, `<a>`, `<img>`) map to
/// [TextAttributes] with nesting merged. Unrecognised content falls back to a
/// paragraph (HTML5 leniency — `decode` does not throw for content).
///
/// This is the package's first third-party runtime dependency (`package:html`).
/// See `docs/architecture.md`.
///
/// The codec serializes document content only. Editor-owned view state such as
/// heading collapse is not emitted, and any external collapse metadata on
/// imported HTML is treated as non-content metadata rather than document state.
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
        final langClass = code.language.isNotEmpty
            ? ' class="language-${code.language}"'
            : '';
        final escaped = _escapeHtml(code.code);
        return '<pre><code$langClass>$escaped</code></pre>';
      case BlockType.table:
        return _encodeTable(block as TableBlockNode);
      case BlockType.image:
        final image = block as ImageBlockNode;
        return _encodeImageBlock(image);
      case BlockType.video:
        final video = block as VideoBlockNode;
        return _encodeVideoBlock(video);
      case BlockType.embed:
        final embed = block as BlockEmbedNode;
        return _encodeBlockEmbed(embed);
      case BlockType.file:
        final file = block as FileBlockNode;
        return _encodeFileBlock(file);
      case BlockType.divider:
        return '<hr>';
      case BlockType.callout:
        final callout = block as CalloutBlockNode;
        return _encodeCalloutBlock(callout);
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
        final spanAttrs = StringBuffer();
        if (cell.rowSpan > 1) {
          spanAttrs.write(' rowspan="${cell.rowSpan}"');
        }
        if (cell.columnSpan > 1) {
          spanAttrs.write(' colspan="${cell.columnSpan}"');
        }
        buffer.write('<$tag$spanAttrs>');
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
      final url =
          _escapeHtml('${embed.data['assetId'] ?? embed.data['id'] ?? ''}');
      final alt =
          _escapeHtml('${embed.data['altText'] ?? embed.data['text'] ?? ''}');
      final attrs = StringBuffer(' src="$url" alt="$alt"');
      final width = _embedDimension(embed.data['width']);
      final height = _embedDimension(embed.data['height']);
      if (width != null) {
        attrs.write(' width="${_formatDimension(width)}"');
      }
      if (height != null) {
        attrs.write(' height="${_formatDimension(height)}"');
      }
      final caption = _embedString(embed.data['caption']);
      if (caption.isNotEmpty) {
        final escapedCaption = _escapeHtml(caption);
        attrs.write(' title="$escapedCaption" data-caption="$escapedCaption"');
      }
      return '<img$attrs>';
    }
    return _escapeHtml(_embedDisplayText(embed));
  }

  num? _embedDimension(Object? value) {
    if (value is num && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  String _embedString(Object? value) {
    return value?.toString() ?? '';
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

  String _encodeImageBlock(ImageBlockNode image) {
    final alt = _escapeHtml(_imageAlt(image));
    final src = _escapeHtml(
      image.assetId.isNotEmpty ? image.assetId : image.file,
    );
    final sizeAttrs = StringBuffer();
    final width = image.showWidth ?? (image.width > 0 ? image.width : null);
    final height = image.showHeight ?? (image.height > 0 ? image.height : null);
    if (width != null) {
      sizeAttrs.write(' width="${_formatDimension(width)}"');
    }
    if (height != null) {
      sizeAttrs.write(' height="${_formatDimension(height)}"');
    }
    if (image.width > 0) {
      sizeAttrs.write(' data-width="${image.width}"');
    }
    if (image.height > 0) {
      sizeAttrs.write(' data-height="${image.height}"');
    }
    final img = '<img src="$src" alt="$alt"$sizeAttrs>';
    if (image.caption.isEmpty) {
      return img;
    }
    return '<figure>$img<figcaption>${_escapeHtml(image.caption)}</figcaption></figure>';
  }

  String _encodeFileBlock(FileBlockNode file) {
    final href = _escapeHtml(file.effectiveDownloadUrl);
    final name = _escapeHtml(file.displayName);
    final attrs = StringBuffer(' href="$href" data-wenz-block="file"');
    if (file.assetId.isNotEmpty) {
      attrs.write(' data-asset-id="${_escapeHtml(file.assetId)}"');
    }
    if (file.size > 0) {
      attrs.write(' data-size="${file.size}"');
    }
    if (file.mimeType.isNotEmpty) {
      attrs.write(' data-mime-type="${_escapeHtml(file.mimeType)}"');
    }
    if (file.file.isNotEmpty) {
      attrs.write(' data-file="${_escapeHtml(file.file)}"');
    }
    if (file.uploadStatus != FileUploadStatus.none) {
      attrs.write(' data-upload-status="${file.uploadStatus.name}"');
    }
    if (file.uploadError.isNotEmpty) {
      attrs.write(' data-upload-error="${_escapeHtml(file.uploadError)}"');
    }
    return '<a$attrs>$name</a>';
  }

  String _encodeVideoBlock(VideoBlockNode video) {
    final src = _escapeHtml(_videoSource(video));
    final attrs = StringBuffer(' src="$src" data-wenz-block="video"');
    if (video.assetId.isNotEmpty) {
      attrs.write(' data-asset-id="${_escapeHtml(video.assetId)}"');
    }
    if (video.playbackUrl.isNotEmpty) {
      attrs.write(' data-playback-url="${_escapeHtml(video.playbackUrl)}"');
    }
    if (video.file.isNotEmpty) {
      attrs.write(' data-file="${_escapeHtml(video.file)}"');
    }
    if (video.coverUrl.isNotEmpty) {
      attrs.write(' poster="${_escapeHtml(video.coverUrl)}"');
    }
    if (video.title.isNotEmpty) {
      attrs.write(' title="${_escapeHtml(video.title)}"');
      attrs.write(' data-title="${_escapeHtml(video.title)}"');
    }
    if (video.description.isNotEmpty) {
      attrs.write(' data-description="${_escapeHtml(video.description)}"');
    }
    final aspectRatio = video.aspectRatio;
    if (aspectRatio != null && aspectRatio > 0) {
      attrs.write(' data-aspect-ratio="${_formatDimension(aspectRatio)}"');
    }
    if (video.uploadStatus != FileUploadStatus.none) {
      attrs.write(' data-upload-status="${video.uploadStatus.name}"');
    }
    if (video.uploadError.isNotEmpty) {
      attrs.write(' data-upload-error="${_escapeHtml(video.uploadError)}"');
    }
    return '<video$attrs></video>';
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

  String _encodeBlockEmbed(BlockEmbedNode embed) {
    final attrs = StringBuffer(
      ' data-wenz-block="embed"'
      ' data-embed-type="${_escapeHtml(embed.normalizedEmbedType)}"',
    );
    final encodedData = _tryEncodeEmbedData(embed.data);
    if (encodedData != null) {
      attrs.write(' data-embed-data="${_escapeHtml(encodedData)}"');
    }
    return '<div$attrs>${_escapeHtml(embed.displayText)}</div>';
  }

  String? _tryEncodeEmbedData(Map<String, Object?> data) {
    if (data.isEmpty) {
      return null;
    }
    try {
      return jsonEncode(data);
    } on Object {
      return null;
    }
  }

  String _encodeCalloutBlock(CalloutBlockNode callout) {
    final variant = callout.normalizedVariant;
    final icon = callout.effectiveIcon;
    final title = callout.effectiveTitle;
    return '<aside class="wenz-callout" data-wenz-block="callout" '
        'data-callout-variant="${_escapeHtml(variant)}" '
        'data-callout-icon="${_escapeHtml(icon)}">'
        '<div data-callout-title>${_escapeHtml(title)}</div>'
        '<div data-callout-body>${_encodeInline(callout.content)}</div>'
        '</aside>';
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

  String _formatDimension(num value) {
    final asDouble = value.toDouble();
    return asDouble == asDouble.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
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
      if (_isCalloutElement(node)) {
        blocks.add(_decodeCallout(node, newId));
        return;
      }
      if (_isFileBlockElement(node)) {
        blocks.add(_decodeFileBlock(node, newId));
        return;
      }
      if (_isBlockEmbedElement(node)) {
        blocks.add(_decodeBlockEmbed(node, newId));
        return;
      }
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
        case 'figure':
          final img = node.querySelector('img');
          if (img != null) {
            _decodeImageElement(
              img,
              blocks,
              newId,
              caption: node.querySelector('figcaption')?.text.trim() ?? '',
            );
            return;
          }
          final video = node.querySelector('video');
          if (video != null) {
            _decodeVideoElement(
              video,
              blocks,
              newId,
              title: node.querySelector('figcaption')?.text.trim() ?? '',
            );
            return;
          }
          for (final child in node.nodes) {
            _decodeNode(child, blocks, newId);
          }
          return;
        case 'img':
          _decodeImageElement(node, blocks, newId);
          return;
        case 'video':
          _decodeVideoElement(node, blocks, newId);
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

  void _decodeImageElement(
    dom.Element node,
    List<BlockNode> blocks,
    String Function(String) newId, {
    String caption = '',
  }) {
    final src = node.attributes['src'] ?? '';
    if (src.isEmpty) {
      return;
    }
    final alt = node.attributes['alt'] ?? '';
    final resolvedCaption = caption.isNotEmpty
        ? caption
        : (node.attributes['data-caption'] ?? node.attributes['title'] ?? '')
            .trim();
    final naturalWidth = _parseIntAttribute(node.attributes['data-width']);
    final naturalHeight = _parseIntAttribute(node.attributes['data-height']);
    blocks.add(ImageBlockNode(
      id: newId('image'),
      assetId: src,
      file: alt,
      width: naturalWidth,
      height: naturalHeight,
      showWidth: _parseDoubleAttribute(node.attributes['width']),
      showHeight: _parseDoubleAttribute(node.attributes['height']),
      caption: resolvedCaption,
      altText: alt,
    ));
  }

  void _decodeVideoElement(
    dom.Element node,
    List<BlockNode> blocks,
    String Function(String) newId, {
    String title = '',
  }) {
    final sourceElement = node.querySelector('source[src]');
    final src =
        (node.attributes['src'] ?? sourceElement?.attributes['src'] ?? '')
            .trim();
    final rawAssetId = (node.attributes['data-asset-id'] ??
            sourceElement?.attributes['data-asset-id'] ??
            '')
        .trim();
    final rawPlaybackUrl = (node.attributes['data-playback-url'] ??
            sourceElement?.attributes['data-playback-url'] ??
            '')
        .trim();
    final rawFile = (node.attributes['data-file'] ??
            sourceElement?.attributes['data-file'] ??
            '')
        .trim();
    if (src.isEmpty &&
        rawAssetId.isEmpty &&
        rawPlaybackUrl.isEmpty &&
        rawFile.isEmpty) {
      return;
    }
    var assetId = rawAssetId;
    var playbackUrl = rawPlaybackUrl;
    var file = rawFile;

    if (playbackUrl.isEmpty &&
        src.isNotEmpty &&
        src != file &&
        (_looksLikeRemoteUrl(src) || (assetId.isNotEmpty && file.isNotEmpty))) {
      playbackUrl = src;
    }
    if (file.isEmpty &&
        src.isNotEmpty &&
        src != playbackUrl &&
        src != assetId &&
        !_looksLikeRemoteUrl(src)) {
      file = src;
    }
    if (assetId.isEmpty && playbackUrl.isEmpty && file.isEmpty) {
      assetId = src;
    }

    final coverUrl = (node.attributes['data-cover-url'] ??
            node.attributes['poster'] ??
            sourceElement?.attributes['data-cover-url'] ??
            '')
        .trim();
    final fallbackTitle = title.isNotEmpty ? title : node.text.trim();
    final resolvedTitle = (node.attributes['data-title'] ??
            node.attributes['title'] ??
            fallbackTitle)
        .trim();
    blocks.add(VideoBlockNode(
      id: newId('video'),
      assetId: assetId,
      playbackUrl: playbackUrl,
      file: file,
      coverUrl: coverUrl,
      title: resolvedTitle,
      description: (node.attributes['data-description'] ?? '').trim(),
      aspectRatio: _parseDoubleAttribute(node.attributes['data-aspect-ratio']),
      uploadStatus:
          FileUploadStatus.parse(node.attributes['data-upload-status']),
      uploadError: (node.attributes['data-upload-error'] ?? '').trim(),
    ));
  }

  bool _isFileBlockElement(dom.Element node) {
    return node.attributes['data-wenz-block'] == 'file';
  }

  bool _isBlockEmbedElement(dom.Element node) {
    return node.attributes['data-wenz-block'] == 'embed';
  }

  BlockEmbedNode _decodeBlockEmbed(
    dom.Element node,
    String Function(String) newId,
  ) {
    final embedType = (node.attributes['data-embed-type'] ?? '').trim();
    return BlockEmbedNode(
      id: newId('embed'),
      embedType: embedType.isEmpty ? 'custom' : embedType,
      data: _decodeEmbedData(node.attributes['data-embed-data']),
      fallbackText: node.text.trim(),
    );
  }

  Map<String, Object?> _decodeEmbedData(String? source) {
    if (source == null || source.trim().isEmpty) {
      return const <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } on Object {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  FileBlockNode _decodeFileBlock(
    dom.Element node,
    String Function(String) newId,
  ) {
    final href = (node.attributes['href'] ?? '').trim();
    final assetId = (node.attributes['data-asset-id'] ?? '').trim();
    final file = (node.attributes['data-file'] ?? '').trim();
    final explicitDownloadUrl =
        (node.attributes['data-download-url'] ?? '').trim();
    final downloadUrl = explicitDownloadUrl.isNotEmpty
        ? explicitDownloadUrl
        : href.isNotEmpty && href != assetId && href != file
            ? href
            : '';
    final name = (node.attributes['data-name'] ?? node.text).trim();
    return FileBlockNode(
      id: newId('file'),
      assetId: assetId,
      name: name,
      size: _parseIntAttribute(node.attributes['data-size']),
      mimeType: (node.attributes['data-mime-type'] ?? '').trim(),
      file: file,
      downloadUrl: downloadUrl,
      uploadStatus:
          FileUploadStatus.parse(node.attributes['data-upload-status']),
      uploadError: (node.attributes['data-upload-error'] ?? '').trim(),
    );
  }

  bool _isCalloutElement(dom.Element node) {
    final blockType = node.attributes['data-wenz-block'];
    if (blockType == 'callout') {
      return true;
    }
    final classNames = node.attributes['class'] ?? '';
    return classNames.split(RegExp(r'\s+')).contains('wenz-callout') &&
        node.attributes.containsKey('data-callout-variant');
  }

  CalloutBlockNode _decodeCallout(
    dom.Element node,
    String Function(String) newId,
  ) {
    final variant = CalloutBlockNode.normalizeVariant(
      node.attributes['data-callout-variant'],
    );
    final titleElement = node.querySelector('[data-callout-title]');
    var title = titleElement?.text.trim() ?? '';
    if (title == CalloutBlockNode.defaultTitleFor(variant)) {
      title = '';
    }
    var icon = (node.attributes['data-callout-icon'] ?? '').trim();
    if (icon == CalloutBlockNode.defaultIconFor(variant)) {
      icon = '';
    }
    final bodyElement = node.querySelector('[data-callout-body]');
    final content = bodyElement == null
        ? _parseCalloutInlineWithoutTitle(node, titleElement)
        : _parseInline(bodyElement);
    return CalloutBlockNode(
      id: newId('callout'),
      variant: variant,
      title: title,
      icon: icon,
      content: content,
    );
  }

  List<InlineNode> _parseCalloutInlineWithoutTitle(
    dom.Element node,
    dom.Element? titleElement,
  ) {
    final runs = <InlineNode>[];
    for (final child in node.nodes) {
      if (titleElement != null && identical(child, titleElement)) {
        continue;
      }
      runs.addAll(_parseInlineNode(child, const TextAttributes()));
    }
    return _coalesce(runs);
  }

  int _parseIntAttribute(String? value) {
    if (value == null) {
      return 0;
    }
    return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
  }

  double? _parseDoubleAttribute(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  bool _looksLikeRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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
    final activeRowSpans = <int, int>{};
    // If a <thead> exists, its rows are headers.
    final thead = table.querySelector('thead');
    for (var r = 0; r < trList.length; r++) {
      final tr = trList[r];
      final isHeaderRow = thead != null && thead.contains(tr);
      final cells = <TableCellNode>[];
      final cellElements =
          tr.children.where((e) => e.localName == 'th' || e.localName == 'td');
      var c = 0;
      void consumeCoveredCell() {
        cells.add(TableCellNode(id: '$tableId-r$r-c$c', covered: true));
        final remaining = activeRowSpans[c]! - 1;
        if (remaining > 0) {
          activeRowSpans[c] = remaining;
        } else {
          activeRowSpans.remove(c);
        }
        c++;
      }

      for (final cell in cellElements) {
        while ((activeRowSpans[c] ?? 0) > 0) {
          consumeCoveredCell();
        }
        final isHeader = isHeaderRow || cell.localName == 'th';
        final rowSpan = _parseTableSpan(cell.attributes['rowspan']);
        final columnSpan = _parseTableSpan(cell.attributes['colspan']);
        cells.add(TableCellNode(
          id: '$tableId-r$r-c$c',
          isHeader: isHeader,
          rowSpan: rowSpan,
          columnSpan: columnSpan,
          blocks: <BlockNode>[
            TextBlockNode(
              id: '$tableId-r$r-c$c-p',
              type: BlockType.paragraph,
              content: _parseInline(cell),
            ),
          ],
        ));
        if (rowSpan > 1) {
          for (var offset = 0; offset < columnSpan; offset++) {
            activeRowSpans[c + offset] = rowSpan - 1;
          }
        }
        for (var offset = 1; offset < columnSpan; offset++) {
          cells.add(TableCellNode(
            id: '$tableId-r$r-c${c + offset}',
            covered: true,
          ));
        }
        c += columnSpan;
      }
      while ((activeRowSpans[c] ?? 0) > 0) {
        consumeCoveredCell();
      }
      rows.add(cells);
    }
    return TableBlockNode(
      id: tableId,
      table: TableModel(rows: rows),
    );
  }

  int _parseTableSpan(String? value) {
    final parsed = _parseIntAttribute(value);
    return parsed > 1 ? parsed : 1;
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
          return _parseChildren(node, attributes.copyWith(bold: true));
        case 'em':
        case 'i':
          return _parseChildren(node, attributes.copyWith(italic: true));
        case 's':
        case 'del':
        case 'strike':
          return _parseChildren(node, attributes.copyWith(lineThrough: true));
        case 'u':
          return _parseChildren(node, attributes.copyWith(underline: true));
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
          final caption = (node.attributes['data-caption'] ??
                  node.attributes['title'] ??
                  '')
              .trim();
          final width = _parseDoubleAttribute(node.attributes['width']) ??
              _parseDoubleAttribute(node.attributes['data-width']);
          final height = _parseDoubleAttribute(node.attributes['height']) ??
              _parseDoubleAttribute(node.attributes['data-height']);
          return <InlineNode>[
            InlineEmbed(
              embedType: 'image',
              data: <String, Object?>{
                'assetId': src,
                'text': alt,
                'altText': alt,
                if (caption.isNotEmpty) 'caption': caption,
                if (width != null) 'width': width,
                if (height != null) 'height': height,
              },
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
      if (node is TextRun &&
          last is TextRun &&
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
