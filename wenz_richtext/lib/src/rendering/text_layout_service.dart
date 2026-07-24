import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show WidgetSpan;

@internal
class MeasuredWidgetSpan extends WidgetSpan {
  const MeasuredWidgetSpan({
    required this.placeholderSize,
    required super.child,
    super.alignment,
    super.baseline,
    super.style,
  });

  final Size placeholderSize;
}

/// Single-block text layout cache.
///
/// Wraps a [TextPainter] and caches the laid-out instance keyed by
/// `(span, textAlign, direction, locale, minWidth, maxWidth)`. Consumers within
/// a single `_TextSelectionSurface` call [layout] repeatedly (caret placement,
/// hit testing, selection boxes, painting) for the same content each frame;
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
  ///
  /// Pass the render box's tight width as both [minWidth] and [maxWidth] when
  /// the corresponding [RichText] is stretched to its parent. This keeps
  /// center/right aligned selection boxes in the same coordinate space as the
  /// painted text.
  TextPainter layout({
    required InlineSpan span,
    required TextAlign textAlign,
    required TextDirection textDirection,
    Locale? locale,
    double minWidth = 0.0,
    required double maxWidth,
  }) {
    final cache = _cache;
    if (cache != null &&
        cache.span == span &&
        cache.textAlign == textAlign &&
        cache.textDirection == textDirection &&
        cache.locale == locale &&
        cache.minWidth == minWidth &&
        cache.maxWidth == maxWidth) {
      return cache.painter;
    }
    final painter = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
    );
    final placeholderDimensions = _placeholderDimensionsFor(span);
    if (placeholderDimensions != null) {
      painter.setPlaceholderDimensions(placeholderDimensions);
    }
    painter.layout(minWidth: minWidth, maxWidth: maxWidth);
    _cache = TextLayoutData(
      span: span,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      minWidth: minWidth,
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
    if (textLength <= 0) {
      return 0;
    }
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      final position = painter.getPositionForOffset(
        Offset(localPosition.dx, 0),
      );
      return position.offset.clamp(0, textLength).toInt();
    }
    final line = _lineForY(metrics, localPosition.dy);
    // Preserve the nearest visual line by y, but let TextPainter resolve x.
    // Its layout already includes TextAlign shifts for centered/right text.
    final position = painter.getPositionForOffset(
      Offset(localPosition.dx, _lineCenterY(line)),
    );
    final boundary = painter.getLineBoundary(position);
    final start = boundary.start.clamp(0, textLength).toInt();
    final end = boundary.end.clamp(0, textLength).toInt();
    final lineStart = start <= end ? start : end;
    final lineEnd = start <= end ? end : start;
    return position.offset.clamp(lineStart, lineEnd).toInt();
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

  /// Resolves the caret offset one visual line up ([forward] = false) or down
  /// ([forward] = true) from [offset], keeping the horizontal position at
  /// [preferX] (the remembered column for repeated vertical moves).
  ///
  /// Returns:
  /// - the new offset if a neighbouring visual line exists within this block;
  /// - `null` if the caret is already on the first (Up) / last (Down) line and
  ///   the caller should fall back to cross-block / boundary motion.
  int? verticalMoveOffset(
    TextPainter painter,
    int offset,
    bool forward, {
    double? preferX,
  }) {
    final textLength = _textLength(painter);
    final clamped = offset.clamp(0, textLength).toInt();
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: clamped),
      Rect.zero,
    );
    // preferX is in the painter's LOCAL coordinate space (same as caret).
    final prefer = preferX ?? caret.dx;
    // Use exact line metrics to find the current line and step to the neighbour.
    // Estimating with caret.dy ± lineHeight is imprecise at line boundaries
    // (leading/strut shifts the caret y off the line's top), so getPositionForOffset
    // resolves back to the same line.
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return null;
    }
    int currentIndex = -1;
    for (var i = 0; i < metrics.length; i++) {
      final m = metrics[i];
      if (caret.dy >= m.baseline - m.height && caret.dy <= m.baseline + 1) {
        currentIndex = i;
        break;
      }
    }
    if (currentIndex < 0) {
      // Fallback: pick the line whose top is nearest the caret.
      currentIndex = 0;
      var bestDelta = (caret.dy - metrics[0].baseline).abs();
      for (var i = 1; i < metrics.length; i++) {
        final d = (caret.dy - metrics[i].baseline).abs();
        if (d < bestDelta) {
          bestDelta = d;
          currentIndex = i;
        }
      }
    }
    final targetIndex = forward ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex < 0 || targetIndex >= metrics.length) {
      return null; // at the first/last line: caller crosses blocks
    }
    final targetLine = metrics[targetIndex];
    final pos = painter.getPositionForOffset(
      Offset(prefer, _lineCenterY(targetLine)),
    );
    final next = pos.offset.clamp(0, textLength).toInt();
    if (next == clamped) {
      return null;
    }
    return next;
  }

  /// Returns the caret's LOCAL x for [offset] (painter coordinate space), used
  /// to seed the remembered column for repeated vertical moves.
  double caretLocalX(TextPainter painter, int offset) {
    final clamped = offset.clamp(0, _textLength(painter)).toInt();
    return painter
        .getOffsetForCaret(TextPosition(offset: clamped), Rect.zero)
        .dx;
  }

  int _textLength(TextPainter painter) {
    return painter.text?.toPlainText().length ?? 0;
  }

  /// Drop the cached painter (e.g. when the owning surface is disposed).
  void forget() {
    _cache = null;
  }
}

LineMetrics _lineForY(List<LineMetrics> metrics, double y) {
  var nearest = metrics.first;
  var nearestDistance = _distanceToLine(nearest, y);
  for (final line in metrics) {
    final distance = _distanceToLine(line, y);
    if (distance == 0) {
      return line;
    }
    if (distance < nearestDistance) {
      nearest = line;
      nearestDistance = distance;
    }
  }
  return nearest;
}

double _distanceToLine(LineMetrics line, double y) {
  final top = _lineTop(line);
  final bottom = _lineBottom(line);
  if (y < top) {
    return top - y;
  }
  if (y > bottom) {
    return y - bottom;
  }
  return 0;
}

double _lineCenterY(LineMetrics line) {
  final top = _lineTop(line);
  final bottom = _lineBottom(line);
  if (bottom <= top) {
    return line.baseline;
  }
  return top + (bottom - top) / 2;
}

double _lineTop(LineMetrics line) {
  return line.baseline - line.ascent;
}

double _lineBottom(LineMetrics line) {
  return line.baseline + line.descent;
}

List<PlaceholderDimensions>? _placeholderDimensionsFor(InlineSpan span) {
  final dimensions = <PlaceholderDimensions>[];

  void collect(InlineSpan current) {
    if (current is PlaceholderSpan) {
      final size = current is MeasuredWidgetSpan
          ? current.placeholderSize
          : _estimatedPlaceholderSize(current);
      dimensions.add(
        PlaceholderDimensions(
          size: size,
          alignment: current.alignment,
          baseline: current.baseline,
          baselineOffset: _placeholderBaselineOffset(current, size),
        ),
      );
    }
    if (current is TextSpan) {
      for (final child in current.children ?? const <InlineSpan>[]) {
        collect(child);
      }
    }
  }

  collect(span);
  return dimensions.isEmpty ? null : dimensions;
}

Size _estimatedPlaceholderSize(PlaceholderSpan span) {
  final fontSize = span.style?.fontSize ?? 14;
  return Size(fontSize, fontSize * 1.2);
}

double? _placeholderBaselineOffset(PlaceholderSpan span, Size size) {
  if (span.baseline == null) {
    return null;
  }
  return size.height * 0.82;
}

@immutable
class TextLayoutData {
  const TextLayoutData({
    required this.span,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.minWidth,
    required this.maxWidth,
    required this.painter,
  });

  final InlineSpan span;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final double minWidth;
  final double maxWidth;
  final TextPainter painter;
}
