import '../core/position/document_position.dart';

/// Describes the active IME composition region inside a single editable block.
///
/// While a composition is in progress (e.g. a Chinese IME showing pinyin
/// candidates), the platform owns the composing text. The editor renders it
/// with a composition decoration (underline) and treats the range as a single
/// replaceable unit until the composition is committed.
///
/// [isEmpty] means no composition is active.
class CompositionState {
  const CompositionState({
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.startOffset,
    required this.endOffset,
  });

  /// Block id the composition lives in (for a table cell this is the table id).
  final String blockId;

  final int blockIndex;

  /// Path of the editable region (blockText / blockCode / tableCellText).
  final PositionPath path;

  /// Inclusive start of the composing region within the block's text.
  final int startOffset;

  /// Exclusive end of the composing region.
  final int endOffset;

  bool get isEmpty => startOffset == endOffset;

  bool covers(DocumentPosition position) {
    return position.blockId == blockId &&
        position.path == path &&
        position.offset >= startOffset &&
        position.offset <= endOffset;
  }

  @override
  bool operator ==(Object other) {
    return other is CompositionState &&
        other.blockId == blockId &&
        other.blockIndex == blockIndex &&
        other.path == path &&
        other.startOffset == startOffset &&
        other.endOffset == endOffset;
  }

  @override
  int get hashCode =>
      Object.hash(blockId, blockIndex, path, startOffset, endOffset);
}
