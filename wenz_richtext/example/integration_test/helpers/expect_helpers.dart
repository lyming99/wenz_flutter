import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _caretKey = ValueKey<String>('wenz-richtext-caret');
const _selectionHighlightKey = ValueKey<String>('wenz-richtext-selection-highlight');

/// Whether the editing caret is currently rendered (collapsed selection +
/// focus inside an editable block).
bool isCaretVisible(WidgetTester tester) {
  return find.byKey(_caretKey).evaluate().isNotEmpty;
}

/// Whether at least one selection-highlight anchor is rendered (non-collapsed
/// selection across one or more blocks).
bool isSelectionHighlightVisible(WidgetTester tester) {
  return find.byKey(_selectionHighlightKey).evaluate().isNotEmpty;
}

/// The top-level [TextStyle] of the [RichText] rendering [text] (the block's
/// base span style). Returns `null` when the block is not found.
TextStyle? richTextStyle(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
  if (!finder.evaluate().any((_) => true)) {
    return null;
  }
  final richText = tester.widget<RichText>(finder);
  final span = richText.text;
  return span is TextSpan ? span.style : null;
}

/// Returns the [TextStyle] of the first child [TextSpan] whose plain text
/// equals [runText], or `null` when no such run exists. Use this to assert on
/// inline formatting (bold run, italic run) applied to a substring.
TextStyle? styleOfRun(WidgetTester tester, String blockText, String runText) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == blockText,
  );
  if (finder.evaluate().isEmpty) {
    return null;
  }
  final richText = tester.widget<RichText>(finder);
  final span = richText.text;
  if (span is! TextSpan) {
    return null;
  }
  TextSpan? match;
  void visit(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text == runText) {
        match = node;
        return;
      }
      node.children?.forEach(visit);
    }
  }

  span.children?.forEach(visit);
  return match?.style;
}
