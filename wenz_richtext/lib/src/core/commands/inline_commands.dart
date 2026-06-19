import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'style_commands.dart';
import 'text_commands.dart';

/// Sets (or replaces) the link URL on the current selection's text runs. Pass
/// `null` to clear the link — unlike [FormatTextCommand], this can remove a
/// URL because it rewrites the affected runs directly.
class SetLinkCommand extends EditorCommand {
  const SetLinkCommand(this.url, {this.selection});

  final String? url;
  final DocumentSelection? selection;

  @override
  String get description => url == null ? 'clearLink' : 'setLink';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex || start.path != end.path) {
      return const CommandResult(recordHistory: false);
    }
    final block = _blockAt(session.document, start.blockIndex);
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final nextContent = _withUrl(
      block.content,
      start.offset,
      end.offset,
      url,
    );
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: nextContent,
    );
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[start.blockIndex] = nextBlock;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

/// Rewrites the runs covering [start, end) so each carries [url] (or has its
/// url removed when [url] is null). Splits runs at the boundaries like
/// [formatInline] but overwrites the url field rather than merging.
List<InlineNode> _withUrl(
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

/// Toggles a boolean text mark (bold/italic/underline/lineThrough/remark) on
/// the current selection: if any run in the range has the mark set, the whole
/// range is cleared of it; otherwise it is applied.
class ToggleMarkCommand extends EditorCommand {
  const ToggleMarkCommand(this.mark, {this.selection});

  final TextMark mark;
  final DocumentSelection? selection;

  @override
  String get description => 'toggleMark:${mark.name}';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex || start.path != end.path) {
      return const CommandResult(recordHistory: false);
    }
    final block = _blockAt(session.document, start.blockIndex);
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final currentlyOn = _anyRunHasMark(
      block.content,
      start.offset,
      end.offset,
      mark,
    );
    if (currentlyOn) {
      // Clear the mark across the range. FormatTextCommand can't unset a bool,
      // so rewrite the runs directly.
      final nextContent = _clearMark(
        block.content,
        start.offset,
        end.offset,
        mark,
      );
      final nextBlock = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: block.attributes,
        content: nextContent,
      );
      final blocks = session.document.blocks.map((b) => b.copy()).toList();
      blocks[start.blockIndex] = nextBlock;
      session.document = RichTextDocument(
        version: session.document.version,
        blocks: blocks,
      );
    } else {
      final attrs = _markAttributes(mark);
      session.selection = target;
      FormatTextCommand(attributes: attrs, selection: target).execute(session);
      session.selection = target;
    }
    return CommandResult(selection: target);
  }
}

TextAttributes _markAttributes(TextMark mark) {
  return switch (mark) {
    TextMark.bold => const TextAttributes(bold: true),
    TextMark.italic => const TextAttributes(italic: true),
    TextMark.underline => const TextAttributes(underline: true),
    TextMark.lineThrough => const TextAttributes(lineThrough: true),
    TextMark.remark => const TextAttributes(remark: true),
  };
}

/// Boolean inline marks toggleable by [ToggleMarkCommand].
enum TextMark { bold, italic, underline, lineThrough, remark }

bool _anyRunHasMark(
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

List<InlineNode> _clearMark(
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
    final middleAttrs = _withoutMark(node.attributes, mark);
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

TextAttributes _withoutMark(TextAttributes attrs, TextMark mark) {
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

/// Inserts an inline embed (formula / mention / image) at the caret. If the
/// selection is non-collapsed the range is deleted first. The caret moves past
/// the inserted embed.
class InsertInlineEmbedCommand extends EditorCommand {
  const InsertInlineEmbedCommand({
    required this.embedType,
    this.data = const <String, Object?>{},
    this.selection,
  });

  final String embedType;
  final Map<String, Object?> data;
  final DocumentSelection? selection;

  @override
  String get description => 'insertInlineEmbed:$embedType';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    if (!target.isCollapsed) {
      final deleteResult =
          DeleteSelectionCommand(target).execute(session);
      if (deleteResult.selection != null) {
        session.selection = deleteResult.selection;
      }
    }
    final position = session.selection!.extent;
    final block = _blockAt(session.document, position.blockIndex);
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final embed = InlineEmbed(embedType: embedType, data: data);
    final nextContent = insertInline(
      block.content,
      position.offset,
      // Embeds render as a single placeholder char.
      embed.plainText,
      const TextAttributes(),
    );
    // Replace the inserted placeholder text run with the actual embed.
    final cleaned = _replacePlaceholderWithEmbed(
      nextContent,
      position.offset,
      embed,
    );
    final nextBlock = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: cleaned,
    );
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[position.blockIndex] = nextBlock;
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    final nextPosition = position.copyWith(offset: position.offset + 1);
    return CommandResult(
      selection: DocumentSelection(base: nextPosition, extent: nextPosition),
    );
  }
}

List<InlineNode> _replacePlaceholderWithEmbed(
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

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}
