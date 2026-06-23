import '../model/attributes.dart';
import '../model/inline_node.dart';

class InlineSplit {
  const InlineSplit({required this.before, required this.after});

  final List<InlineNode> before;
  final List<InlineNode> after;
}

List<InlineNode> insertInline(
  List<InlineNode> nodes,
  int offset,
  String text,
  TextAttributes attributes,
) {
  final result = <InlineNode>[];
  var cursor = 0;
  var inserted = false;

  void insertRun() {
    result.add(TextRun(text: text, attributes: attributes));
    inserted = true;
  }

  for (final node in nodes) {
    final length = inlineLength(node);
    if (!inserted && offset <= cursor) {
      insertRun();
    }

    if (node is TextRun &&
        !inserted &&
        offset > cursor &&
        offset < cursor + length) {
      final local = offset - cursor;
      final before = node.text.substring(0, local);
      final after = node.text.substring(local);
      if (before.isNotEmpty) {
        result.add(TextRun(text: before, attributes: node.attributes));
      }
      insertRun();
      if (after.isNotEmpty) {
        result.add(TextRun(text: after, attributes: node.attributes));
      }
    } else {
      result.add(node.copy());
    }

    cursor += length;
    if (!inserted && offset == cursor) {
      insertRun();
    }
  }

  if (!inserted) {
    insertRun();
  }

  return mergeTextRuns(result);
}

List<InlineNode> deleteInline(List<InlineNode> nodes, int start, int end) {
  if (end <= start) {
    return nodes.map((node) => node.copy()).toList();
  }

  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= start || nodeStart >= end) {
      result.add(node.copy());
      continue;
    }

    if (node is! TextRun) {
      continue;
    }

    final keepBefore = (start - nodeStart).clamp(0, node.text.length);
    final keepAfter = (end - nodeStart).clamp(0, node.text.length);
    final before = node.text.substring(0, keepBefore);
    final after = node.text.substring(keepAfter);
    if (before.isNotEmpty) {
      result.add(TextRun(text: before, attributes: node.attributes));
    }
    if (after.isNotEmpty) {
      result.add(TextRun(text: after, attributes: node.attributes));
    }
  }

  return mergeTextRuns(result);
}

List<InlineNode> formatInline(
  List<InlineNode> nodes,
  int start,
  int end,
  TextAttributes attributes,
) {
  if (end <= start || attributes.isEmpty) {
    return nodes.map((node) => node.copy()).toList();
  }

  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= start || nodeStart >= end) {
      result.add(node.copy());
      continue;
    }

    if (node is TextRun) {
      final localStart = start > nodeStart ? start - nodeStart : 0;
      final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
      final before = node.text.substring(0, localStart);
      final middle = node.text.substring(localStart, localEnd);
      final after = node.text.substring(localEnd);
      if (before.isNotEmpty) {
        result.add(TextRun(text: before, attributes: node.attributes));
      }
      if (middle.isNotEmpty) {
        result.add(
          TextRun(
            text: middle,
            attributes: node.attributes.mergeWith(attributes),
          ),
        );
      }
      if (after.isNotEmpty) {
        result.add(TextRun(text: after, attributes: node.attributes));
      }
    } else if (node is InlineEmbed) {
      result.add(
        InlineEmbed(
          embedType: node.embedType,
          data: node.data,
          attributes: node.attributes.mergeWith(attributes),
        ),
      );
    }
  }

  return mergeTextRuns(result);
}

List<InlineNode> clearInlineFormatting(
  List<InlineNode> nodes,
  int start,
  int end,
) {
  if (end <= start) {
    return nodes.map((node) => node.copy()).toList();
  }

  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= start || nodeStart >= end) {
      result.add(node.copy());
      continue;
    }

    if (node is TextRun) {
      final localStart = start > nodeStart ? start - nodeStart : 0;
      final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
      final before = node.text.substring(0, localStart);
      final middle = node.text.substring(localStart, localEnd);
      final after = node.text.substring(localEnd);
      if (before.isNotEmpty) {
        result.add(TextRun(text: before, attributes: node.attributes));
      }
      if (middle.isNotEmpty) {
        result.add(TextRun(text: middle, attributes: const TextAttributes()));
      }
      if (after.isNotEmpty) {
        result.add(TextRun(text: after, attributes: node.attributes));
      }
    } else if (node is InlineEmbed) {
      result.add(
        InlineEmbed(
          embedType: node.embedType,
          data: node.data,
          attributes: const TextAttributes(),
        ),
      );
    }
  }

  return mergeTextRuns(result);
}

InlineSplit splitInline(List<InlineNode> nodes, int offset) {
  final before = <InlineNode>[];
  final after = <InlineNode>[];
  var cursor = 0;

  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= offset) {
      before.add(node.copy());
      continue;
    }
    if (nodeStart >= offset) {
      after.add(node.copy());
      continue;
    }

    if (node is TextRun) {
      final local = offset - nodeStart;
      final left = node.text.substring(0, local);
      final right = node.text.substring(local);
      if (left.isNotEmpty) {
        before.add(TextRun(text: left, attributes: node.attributes));
      }
      if (right.isNotEmpty) {
        after.add(TextRun(text: right, attributes: node.attributes));
      }
    } else {
      after.add(node.copy());
    }
  }

  return InlineSplit(
    before: mergeTextRuns(before),
    after: mergeTextRuns(after),
  );
}

List<InlineNode> mergeTextRuns(List<InlineNode> nodes) {
  final result = <InlineNode>[];
  for (final node in nodes) {
    if (node is TextRun &&
        result.isNotEmpty &&
        result.last is TextRun &&
        (result.last as TextRun).attributes == node.attributes) {
      final previous = result.removeLast() as TextRun;
      result.add(
        TextRun(
          text: previous.text + node.text,
          attributes: previous.attributes,
        ),
      );
    } else {
      result.add(node);
    }
  }
  return result;
}

int inlineLength(InlineNode node) {
  if (node is TextRun) {
    return node.text.length;
  }
  return 1;
}

int inlineNodesLength(List<InlineNode> nodes) {
  var result = 0;
  for (final node in nodes) {
    result += inlineLength(node);
  }
  return result;
}

/// Boolean inline marks toggleable by [ToggleMarkCommand] / [toggleTableCellMark].
enum TextMark { bold, italic, underline, lineThrough, remark }

/// The attributes that apply (turn on) a single [mark].
TextAttributes markAttributes(TextMark mark) {
  return switch (mark) {
    TextMark.bold => const TextAttributes(bold: true),
    TextMark.italic => const TextAttributes(italic: true),
    TextMark.underline => const TextAttributes(underline: true),
    TextMark.lineThrough => const TextAttributes(lineThrough: true),
    TextMark.remark => const TextAttributes(remark: true),
  };
}

/// Whether any text run overlapping [start, end) has [mark] set.
bool anyRunHasMark(
  List<InlineNode> nodes,
  int start,
  int end,
  TextMark mark,
) {
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;
    if (nodeEnd <= start || nodeStart >= end || node is! TextRun) {
      continue;
    }
    final on = switch (mark) {
      TextMark.bold => node.attributes.bold == true,
      TextMark.italic => node.attributes.italic == true,
      TextMark.underline => node.attributes.underline == true,
      TextMark.lineThrough => node.attributes.lineThrough == true,
      TextMark.remark => node.attributes.remark == true,
    };
    if (on) {
      return true;
    }
  }
  return false;
}

/// Clears [mark] from the runs covering [start, end), splitting at boundaries.
List<InlineNode> clearMark(
  List<InlineNode> nodes,
  int start,
  int end,
  TextMark mark,
) {
  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;
    if (nodeEnd <= start || nodeStart >= end || node is! TextRun) {
      result.add(node.copy());
      continue;
    }
    final localStart = start > nodeStart ? start - nodeStart : 0;
    final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
    final before = node.text.substring(0, localStart);
    final middle = node.text.substring(localStart, localEnd);
    final after = node.text.substring(localEnd);
    final middleAttrs = withoutMark(node.attributes, mark);
    if (before.isNotEmpty) {
      result.add(TextRun(text: before, attributes: node.attributes));
    }
    if (middle.isNotEmpty) {
      result.add(TextRun(text: middle, attributes: middleAttrs));
    }
    if (after.isNotEmpty) {
      result.add(TextRun(text: after, attributes: node.attributes));
    }
  }
  return mergeTextRuns(result);
}

/// Returns [attrs] with [mark] removed (set to null).
TextAttributes withoutMark(TextAttributes attrs, TextMark mark) {
  return TextAttributes(
    color: attrs.color,
    background: attrs.background,
    bold: mark == TextMark.bold ? null : attrs.bold,
    italic: mark == TextMark.italic ? null : attrs.italic,
    fontSize: attrs.fontSize,
    fontFamily: attrs.fontFamily,
    underline: mark == TextMark.underline ? null : attrs.underline,
    lineThrough: mark == TextMark.lineThrough ? null : attrs.lineThrough,
    remark: mark == TextMark.remark ? null : attrs.remark,
    url: attrs.url,
  );
}

/// Rewrites the runs covering [start, end) so each carries [url] (or has its
/// url removed when [url] is null). Splits runs at the boundaries like
/// [formatInline] but overwrites the url field rather than merging.
List<InlineNode> withUrl(
  List<InlineNode> nodes,
  int start,
  int end,
  String? url,
) {
  if (end <= start) {
    return nodes.map((n) => n.copy()).toList();
  }
  final result = <InlineNode>[];
  var cursor = 0;
  for (final node in nodes) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;

    if (nodeEnd <= start || nodeStart >= end) {
      result.add(node.copy());
      continue;
    }
    if (node is! TextRun) {
      result.add(node.copy());
      continue;
    }
    final localStart = start > nodeStart ? start - nodeStart : 0;
    final localEnd = end < nodeEnd ? end - nodeStart : node.text.length;
    final before = node.text.substring(0, localStart);
    final middle = node.text.substring(localStart, localEnd);
    final after = node.text.substring(localEnd);
    if (before.isNotEmpty) {
      result.add(TextRun(text: before, attributes: node.attributes));
    }
    if (middle.isNotEmpty) {
      result.add(
        TextRun(
          text: middle,
          attributes: TextAttributes(
            color: node.attributes.color,
            background: node.attributes.background,
            bold: node.attributes.bold,
            italic: node.attributes.italic,
            fontSize: node.attributes.fontSize,
            fontFamily: node.attributes.fontFamily,
            underline: node.attributes.underline,
            lineThrough: node.attributes.lineThrough,
            remark: node.attributes.remark,
            url: url, // overwrite (not merge) so null clears the link
          ),
        ),
      );
    }
    if (after.isNotEmpty) {
      result.add(TextRun(text: after, attributes: node.attributes));
    }
  }
  return mergeTextRuns(result);
}

/// Replaces the single placeholder character at [offset] with [embed]. Pairs
/// with [insertInline], which first drops a one-char placeholder run where the
/// embed should land.
List<InlineNode> replacePlaceholderWithEmbed(
  List<InlineNode> nodes,
  int offset,
  InlineEmbed embed,
) {
  final result = <InlineNode>[];
  var cursor = 0;
  var inserted = false;
  for (final node in nodes) {
    final length = inlineLength(node);
    final nodeStart = cursor;
    final nodeEnd = cursor + length;
    cursor = nodeEnd;

    if (!inserted &&
        node is TextRun &&
        offset >= nodeStart &&
        offset < nodeEnd) {
      final local = offset - nodeStart;
      final before = node.text.substring(0, local);
      final after = node.text.substring(local + 1);
      if (before.isNotEmpty) {
        result.add(TextRun(text: before, attributes: node.attributes));
      }
      result.add(embed);
      if (after.isNotEmpty) {
        result.add(TextRun(text: after, attributes: node.attributes));
      }
      inserted = true;
      continue;
    }
    result.add(node.copy());
  }
  if (!inserted) {
    result.add(embed);
  }
  return mergeTextRuns(result);
}
