import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the [RichText] widget whose plain text matches [text] exactly.
Finder richTextWith(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

/// Finds the [RichText] widget whose plain text contains [substring].
Finder richTextContaining(String substring) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(substring),
    description: 'RichText containing "$substring"',
  );
}

/// Computes the global screen coordinate for tapping a character [offset]
/// within the [RichText] that renders [text].
///
/// Mirrors the approach in the package's widget tests: lay out a throwaway
/// [TextPainter] with the same span + width, ask it for the caret offset, then
/// convert to global coordinates and nudge inside the character run.
Offset globalOffsetAt(WidgetTester tester, String text, int offset) {
  final finder = richTextWith(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) +
      local +
      Offset(1, painter.preferredLineHeight / 2);
}

/// Computes a tap target in the right-side blank area of a wrapped visual line.
///
/// The returned [lineRange] is resolved with the same [TextPainter] line y, so
/// callers can assert the editor caret stayed on that visual line after the
/// pointer-down path runs through the overlay and geometry registry.
VisualLineBlankTarget rightBlankOnVisualLine(
  WidgetTester tester,
  String text, {
  required int lineIndex,
}) {
  final finder = richTextWith(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final lines = painter.computeLineMetrics();
  expect(lines.length, greaterThan(lineIndex));
  final line = lines[lineIndex];
  final lineY = _lineCenterY(line);
  final lineRange = TextRange(
    start: painter.getPositionForOffset(Offset(-100000, lineY)).offset,
    end: painter.getPositionForOffset(Offset(100000, lineY)).offset,
  );
  final lineRight = line.left + line.width;
  final blankWidth = size.width - lineRight;
  expect(
    blankWidth,
    greaterThan(8),
    reason: 'test text must leave a tappable blank area on the target line',
  );
  return VisualLineBlankTarget(
    globalPoint:
        tester.getTopLeft(finder) + Offset(lineRight + blankWidth / 2, lineY),
    lineRange: lineRange,
  );
}

double _lineCenterY(LineMetrics line) {
  final top = line.baseline - line.ascent;
  final bottom = line.baseline + line.descent;
  return top + (bottom - top) / 2;
}

class VisualLineBlankTarget {
  const VisualLineBlankTarget({
    required this.globalPoint,
    required this.lineRange,
  });

  final Offset globalPoint;
  final TextRange lineRange;
}

/// Taps at the given character [offset] inside the [RichText] for [text].
Future<void> tapAtTextOffset(
  WidgetTester tester,
  String text,
  int offset, {
  bool shift = false,
}) async {
  final target = globalOffsetAt(tester, text, offset);
  if (shift) {
    await _mouseClickAt(tester, target, shift: true);
  } else {
    await tester.tapAt(target);
  }
  await tester.pump();
}

/// Drags from [fromOffset] to [toOffset] in text-offset coordinates within the
/// same [RichText] for [text].
Future<void> dragInsideText(
  WidgetTester tester,
  String text, {
  required int fromOffset,
  required int toOffset,
  bool shift = false,
}) async {
  final start = globalOffsetAt(tester, text, fromOffset);
  final end = globalOffsetAt(tester, text, toOffset);
  if (shift) {
    await _mouseDragFromTo(tester, start, end, shift: true);
  } else {
    await tester.dragFrom(start, end - start);
  }
  await tester.pump();
}

/// Drags between two different blocks, from [fromText]/[fromOffset] to
/// [toText]/[toOffset]. Used for cross-block selection.
Future<void> dragBetweenText(
  WidgetTester tester, {
  required String fromText,
  required int fromOffset,
  required String toText,
  required int toOffset,
  bool shift = false,
}) async {
  final start = globalOffsetAt(tester, fromText, fromOffset);
  final end = globalOffsetAt(tester, toText, toOffset);
  if (shift) {
    await _mouseDragFromTo(tester, start, end, shift: true);
  } else {
    await tester.dragFrom(start, end - start);
  }
  await tester.pump();
}

Future<void> _mouseClickAt(
  WidgetTester tester,
  Offset point, {
  bool shift = false,
}) async {
  await _withOptionalShift(tester, shift, () async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await gesture.addPointer(location: point);
      await tester.pump();
      await gesture.down(point);
      await tester.pump();
      await gesture.up();
      await tester.pump();
    } finally {
      await gesture.removePointer();
    }
  });
}

Future<void> _mouseDragFromTo(
  WidgetTester tester,
  Offset start,
  Offset end, {
  bool shift = false,
}) async {
  await _withOptionalShift(tester, shift, () async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await gesture.addPointer(location: start);
      await tester.pump();
      await gesture.down(start);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pump();
    } finally {
      await gesture.removePointer();
    }
  });
}

Future<void> _withOptionalShift(
  WidgetTester tester,
  bool shift,
  Future<void> Function() action,
) async {
  if (!shift) {
    await action();
    return;
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    await action();
  } finally {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }
}

/// Performs a multi-tap (double or triple) at the same location for word /
/// paragraph selection.
Future<void> multiTapText(
  WidgetTester tester,
  String text,
  int offset, {
  required int taps,
}) async {
  final target = globalOffsetAt(tester, text, offset);
  for (var i = 0; i < taps; i++) {
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}
