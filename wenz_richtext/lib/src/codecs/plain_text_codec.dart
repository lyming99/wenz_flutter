import '../core/model/block_node.dart';
import '../core/model/rich_text_document.dart';

/// Exports a [RichTextDocument] as plain text.
///
/// Each block contributes one paragraph (its [BlockNode.plainText]); blocks
/// are separated by a blank line so the output reads as paragraphs rather
/// than a single run-on line. Non-text blocks (divider/image/video/file) that
/// carry no plain text are rendered as a short sentinel so the reader can see
/// where they sat in the flow; pass [omitEmptyBlocks] = true to drop them
/// entirely.
///
/// This is a one-way export — there is no plain-text *import* (parsing
/// unstructured text back into block structure is the job of the Markdown /
/// HTML codecs, stage 6). Use it for "copy document as text", search
/// indexing, and export-to-`.txt` workflows.
class PlainTextCodec {
  const PlainTextCodec({this.omitEmptyBlocks = false});

  /// When true, blocks whose [BlockNode.plainText] is empty are skipped
  /// instead of emitting a sentinel line. Default is `false` so the export
  /// always reflects document structure.
  final bool omitEmptyBlocks;

  String encode(RichTextDocument document) {
    final lines = <String>[];
    for (var index = 0; index < document.blocks.length; index++) {
      final block = document.blocks[index];
      if (omitEmptyBlocks && _isStructural(block)) {
        // Media / divider blocks are structural — skip them when the caller
        // wants only textual content.
        continue;
      }
      final rendered = _renderBlock(document.blocks, index);
      if (rendered == null || rendered.isEmpty) {
        if (omitEmptyBlocks) {
          continue;
        }
        lines.add('');
        continue;
      }
      lines.add(rendered);
    }
    return lines.join('\n\n');
  }

  /// Whether [block] is a structural (non-textual) block whose presence is
  /// optional in a plain-text export.
  bool _isStructural(BlockNode block) {
    switch (block.type) {
      case BlockType.image:
      case BlockType.video:
      case BlockType.embed:
      case BlockType.file:
      case BlockType.divider:
        return true;
      case BlockType.paragraph:
      case BlockType.heading:
      case BlockType.quote:
      case BlockType.listItem:
      case BlockType.code:
      case BlockType.table:
      case BlockType.callout:
        return false;
    }
  }

  /// Returns the plain-text rendering for [block], or `null` when the block
  /// has no textual representation at all (an empty paragraph / callout).
  /// Media blocks always go through their sentinel so file names / asset ids
  /// are not mistaken for body text.
  String? _renderBlock(List<BlockNode> blocks, int index) {
    final block = blocks[index];
    switch (block.type) {
      case BlockType.paragraph:
      case BlockType.heading:
      case BlockType.quote:
      case BlockType.callout:
        return _quotePlainTextIfNeeded(block, block.plainText);
      case BlockType.listItem:
        return _quotePlainTextIfNeeded(
          block,
          _renderListItem(blocks, index, block as TextBlockNode),
        );
      case BlockType.code:
        // Code is emitted verbatim (keeps internal newlines).
        return block.plainText;
      case BlockType.table:
        final text = block.plainText;
        return text.isEmpty ? '[table]' : text;
      case BlockType.image:
        final image = block as ImageBlockNode;
        return '[image: ${_imageLabel(image)}]';
      case BlockType.video:
        final video = block as VideoBlockNode;
        return '[video: ${_videoLabel(video)}]';
      case BlockType.embed:
        final embed = block as BlockEmbedNode;
        return '[embed:${embed.normalizedEmbedType}: ${embed.displayText}]';
      case BlockType.file:
        final file = block as FileBlockNode;
        return '[file: ${file.displayName}]';
      case BlockType.divider:
        return '---';
    }
  }

  String _quotePlainTextIfNeeded(BlockNode block, String text) {
    if (block is! TextBlockNode ||
        (block.type != BlockType.quote && !block.attributes.isQuoted)) {
      return text;
    }
    return text
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
  }

  String _renderListItem(
    List<BlockNode> blocks,
    int index,
    TextBlockNode block,
  ) {
    final indent = block.attributes.indent ?? 0;
    final pad = '  ' * indent;
    final text = block.plainText;
    if (block.attributes.listType == 'ordered') {
      final marker = '${_orderedListNumberFor(blocks, index, indent)}.';
      if (block.attributes.checked != null) {
        final box = block.attributes.checked == true ? '[x]' : '[ ]';
        return '$pad$marker $box $text';
      }
      return '$pad$marker $text';
    }
    if (block.attributes.listType == 'task') {
      final box = block.attributes.checked == true ? '[x]' : '[ ]';
      return '$pad- $box $text';
    }
    return '$pad- $text';
  }

  int _orderedListNumberFor(List<BlockNode> blocks, int index, int indent) {
    var number = 1;
    for (var previousIndex = index - 1; previousIndex >= 0; previousIndex--) {
      final previous = blocks[previousIndex];
      final previousIndent = previous.attributes.indent ?? 0;
      if (previousIndent > indent) {
        continue;
      }
      if (previousIndent < indent) {
        break;
      }
      if (previous is TextBlockNode && previous.type == BlockType.listItem) {
        if (previous.attributes.listType == 'ordered') {
          number++;
          continue;
        }
        break;
      }
      break;
    }
    return number;
  }

  String _imageLabel(ImageBlockNode image) {
    if (image.caption.isNotEmpty) {
      return image.caption;
    }
    if (image.altText.isNotEmpty) {
      return image.altText;
    }
    if (image.file.isNotEmpty) {
      return image.file;
    }
    return image.assetId;
  }

  String _videoLabel(VideoBlockNode video) {
    if (video.title.isNotEmpty) {
      return video.title;
    }
    if (video.description.isNotEmpty) {
      return video.description;
    }
    if (video.playbackUrl.isNotEmpty) {
      return video.playbackUrl;
    }
    if (video.file.isNotEmpty) {
      return video.file;
    }
    return video.assetId;
  }
}
