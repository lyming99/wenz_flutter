import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Single-block text layout cache.
///
/// Wraps a [TextPainter] and caches the laid-out instance keyed by
/// `(span, textAlign, direction, maxWidth)`. Consumers within a single
/// `_TextSelectionSurface` call [layout] repeatedly (caret placement, hit
/// testing, selection boxes, painting) for the same content each frame;
/// caching avoids re-creating and re-laying-out the painter on every call.
///
/// Scope (stage 0): single block only. Cross-block selection layout is a
/// stage 2 concern. This class is internal — it is not exported from the
/// public package API until the layout layer stabilises.
@internal
class TextLayoutService {
  TextLayoutData? _cache;

  /// Returns a laid-out [TextPainter] for the given inputs, reusing a cached
  /// instance when all inputs match.
  TextPainter layout({
    required InlineSpan span,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required double maxWidth,
  }) {
    final cache = _cache;
    if (cache != null &&
        cache.span == span &&
        cache.textAlign == textAlign &&
        cache.textDirection == textDirection &&
        cache.maxWidth == maxWidth) {
      return cache.painter;
    }
    final painter = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    _cache = TextLayoutData(
      span: span,
      textAlign: textAlign,
      textDirection: textDirection,
      maxWidth: maxWidth,
      painter: painter,
    );
    return painter;
  }

  /// Caret top-left for [offset].
  Offset caretOffset(TextPainter painter, int offset) {
    return painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
  }

  /// Caret height for [offset], or `null` when unavailable.
  double? caretHeight(TextPainter painter, int offset) {
    return painter.getFullHeightForCaret(
      TextPosition(offset: offset),
      Rect.zero,
    );
  }

  /// Character offset under [localPosition].
  int offsetAt(TextPainter painter, Offset localPosition, int textLength) {
    final position = painter.getPositionForOffset(localPosition);
    return position.offset.clamp(0, textLength).toInt();
  }

  /// Selection highlight boxes for [start, end).
  List<TextBox> selectionBoxes(TextPainter painter, int start, int end) {
    return painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  /// Returns the word range covering [offset] using the platform text
  /// segmentation exposed by [TextPainter.getWordBoundary]. This handles
  /// CJK and locale-specific boundaries, which a hand-rolled ASCII rule
  /// cannot. Used by double-click select-word.
  TextRange wordRangeAt(TextPainter painter, int offset) {
    final clamped = offset.clamp(0, _textLength(painter)).toInt();
    return painter.getWordBoundary(TextPosition(offset: clamped));
  }

  /// Returns the full editable range of the block. Stage 2 treats a "paragraph"
  /// as a single block (the block itself is the paragraph unit); triple-click
  /// selects the whole block.
  TextRange paragraphRange(TextPainter painter) {
    return TextRange(start: 0, end: _textLength(painter));
  }

  int _textLength(TextPainter painter) {
    return painter.text?.toPlainText().length ?? 0;
  }

  /// Drop the cached painter (e.g. when the owning surface is disposed).
  void forget() {
    _cache = null;
  }
}

@immutable
class TextLayoutData {
  const TextLayoutData({
    required this.span,
    required this.textAlign,
    required this.textDirection,
    required this.maxWidth,
    required this.painter,
  });

  final InlineSpan span;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double maxWidth;
  final TextPainter painter;
}
