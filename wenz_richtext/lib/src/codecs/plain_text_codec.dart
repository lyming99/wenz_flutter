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
    for (final block in document.blocks) {
      if (omitEmptyBlocks && _isStructural(block)) {
        // Media / divider blocks are structural — skip them when the caller
        // wants only textual content.
        continue;
      }
      final rendered = _renderBlock(block);
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
  String? _renderBlock(BlockNode block) {
    switch (block.type) {
      case BlockType.paragraph:
      case BlockType.heading:
      case BlockType.quote:
      case BlockType.listItem:
      case BlockType.callout:
        return block.plainText;
      case BlockType.code:
        // Code is emitted verbatim (keeps internal newlines).
        return block.plainText;
      case BlockType.table:
        final text = block.plainText;
        return text.isEmpty ? '[table]' : text;
      case BlockType.image:
        final image = block as ImageBlockNode;
        return '[image: ${image.file.isNotEmpty ? image.file : image.assetId}]';
      case BlockType.video:
        final video = block as VideoBlockNode;
        return '[video: ${video.assetId}]';
      case BlockType.file:
        final file = block as FileBlockNode;
        return '[file: ${file.name.isNotEmpty ? file.name : file.assetId}]';
      case BlockType.divider:
        return '---';
    }
  }
}
