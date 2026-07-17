import 'package:wenz_richtext/wenz_richtext.dart';

/// Shared selection builders for tests, replacing the per-file `_collapsed` /
/// `_selection` / `_codeCollapsed` helpers that were duplicated across
/// `test/core/*` and `test/widgets/*`.

/// Collapsed selection at [offset] inside the inline text of a text block.
DocumentSelection collapsedTextSelection(
  String blockId,
  int blockIndex,
  int offset,
) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockText(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

/// Collapsed selection at [offset] inside the inline body of a callout block.
DocumentSelection collapsedCalloutSelection(
  String blockId,
  int blockIndex,
  int offset,
) {
  return collapsedTextSelection(blockId, blockIndex, offset);
}

/// Collapsed selection at [offset] inside the code of a code block.
DocumentSelection collapsedCodeSelection(
  String blockId,
  int blockIndex,
  int offset,
) {
  final position = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockCode(blockId),
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

/// Text-block selection spanning [startOffset, endOffset). [base] is the
/// anchor (grows from the start by default); pass [reversed] to anchor at the
/// end instead.
DocumentSelection textSelection(
  String blockId,
  int blockIndex,
  int startOffset,
  int endOffset, {
  bool reversed = false,
}) {
  final path = PositionPath.blockText(blockId);
  final a = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: path,
    offset: startOffset,
  );
  final b = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: path,
    offset: endOffset,
  );
  return DocumentSelection(base: reversed ? b : a, extent: reversed ? a : b);
}

/// Callout body selection spanning [startOffset, endOffset). The body uses the
/// same `PositionPath.blockText` address space as normal text blocks.
DocumentSelection calloutSelection(
  String blockId,
  int blockIndex,
  int startOffset,
  int endOffset, {
  bool reversed = false,
}) {
  return textSelection(
    blockId,
    blockIndex,
    startOffset,
    endOffset,
    reversed: reversed,
  );
}
