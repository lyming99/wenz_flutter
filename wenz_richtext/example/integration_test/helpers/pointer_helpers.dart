import 'package:flutter/material.dart';
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

/// Taps at the given character [offset] inside the [RichText] for [text].
Future<void> tapAtTextOffset(
  WidgetTester tester,
  String text,
  int offset,
) async {
  await tester.tapAt(globalOffsetAt(tester, text, offset));
  await tester.pump();
}

/// Drags from [fromOffset] to [toOffset] in text-offset coordinates within the
/// same [RichText] for [text].
Future<void> dragInsideText(
  WidgetTester tester,
  String text, {
  required int fromOffset,
  required int toOffset,
}) async {
  final start = globalOffsetAt(tester, text, fromOffset);
  final end = globalOffsetAt(tester, text, toOffset);
  await tester.dragFrom(start, end - start);
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
}) async {
  final start = globalOffsetAt(tester, fromText, fromOffset);
  final end = globalOffsetAt(tester, toText, toOffset);
  await tester.dragFrom(start, end - start);
  await tester.pump();
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
