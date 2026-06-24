import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/inline_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';
import 'inline_editing.dart';
import 'markdown_shortcut_commands.dart';
import 'style_commands.dart';
import 'table_cell_editing.dart';
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
    // Table cell selection: route to the cell-aware link rewrite, which edits
    // the cell's first text block via replaceCellTextBlock (the block here is a
    // TableBlockNode and would otherwise short-circuit on the guard below).
    if (start.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return setTableCellLinkRange(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
        url,
      );
    }
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final nextContent = withUrl(
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

/// Finds URL-looking text in the current text scope and writes the matching
/// URL into [TextAttributes.url]. Existing linked runs are left untouched.
class AutoLinkUrlsCommand extends EditorCommand {
  const AutoLinkUrlsCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'autoLinkUrls';

  @override
  bool canMergeWith(EditorCommand previous) {
    return previous is InsertTextCommand ||
        previous is ApplyMarkdownShortcutCommand;
  }

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
    final rangeStart = target.isCollapsed ? 0 : start.offset;
    final rangeEnd = target.isCollapsed ? null : end.offset;

    if (start.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return _autoLinkTableCell(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        rangeStart,
        rangeEnd,
        target,
      );
    }

    if (!start.path.isBlockText || block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final result = _autoLinkContent(
      block.content,
      rangeStart,
      rangeEnd ?? inlineNodesLength(block.content),
    );
    if (!result.changed) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[start.blockIndex] = TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: block.attributes,
      content: result.content,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
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
    // Table cell selection: toggle the mark inside the cell's first text block
    // (the block here is a TableBlockNode and would otherwise short-circuit on
    // the guard below).
    if (start.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = start.path.tableRowIndex;
      final columnIndex = start.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return toggleTableCellMark(
        session,
        start.blockIndex,
        rowIndex,
        columnIndex,
        start.offset,
        end.offset,
        mark,
      );
    }
    if (block is! TextBlockNode) {
      return const CommandResult(recordHistory: false);
    }
    final currentlyOn = anyRunHasMark(
      block.content,
      start.offset,
      end.offset,
      mark,
    );
    if (currentlyOn) {
      // Clear the mark across the range. FormatTextCommand can't unset a bool,
      // so rewrite the runs directly.
      final nextContent = clearMark(
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
      final attrs = markAttributes(mark);
      session.selection = target;
      FormatTextCommand(attributes: attrs, selection: target).execute(session);
      session.selection = target;
    }
    return CommandResult(selection: target);
  }
}

// TextMark + the mark helpers (markAttributes / anyRunHasMark / clearMark /
// withoutMark) live in inline_editing.dart so both this file and
// table_cell_editing.dart can reuse them without a circular import. They are
// imported below and re-exported via the barrel file.

/// Inserts an inline embed (formula / mention / emoji / image) at the caret. If the
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
    // Table cell caret: route to the cell-aware embed insertion (the block here
    // is a TableBlockNode and would otherwise short-circuit on the guard below).
    if (position.path.isTableCellText && block is TableBlockNode) {
      final rowIndex = position.path.tableRowIndex;
      final columnIndex = position.path.tableColumnIndex;
      if (rowIndex == null || columnIndex == null) {
        return const CommandResult(recordHistory: false);
      }
      return insertTableCellInlineEmbed(
        session,
        position.blockIndex,
        rowIndex,
        columnIndex,
        position.offset,
        embedType,
        data,
      );
    }
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
    final cleaned = replacePlaceholderWithEmbed(
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

CommandResult _autoLinkTableCell(
  DocumentSession session,
  int blockIndex,
  int rowIndex,
  int columnIndex,
  int rangeStart,
  int? rangeEnd,
  DocumentSelection selection,
) {
  final target = tableCellTarget(session, blockIndex, rowIndex, columnIndex);
  if (target == null) {
    return const CommandResult(recordHistory: false);
  }
  final result = _autoLinkContent(
    target.textBlock.content,
    rangeStart,
    rangeEnd ?? target.textLength,
  );
  if (!result.changed) {
    return const CommandResult(recordHistory: false);
  }
  final nextTextBlock = TextBlockNode(
    id: target.textBlock.id,
    type: target.textBlock.type,
    attributes: target.textBlock.attributes,
    content: result.content,
  );
  return replaceCellTextBlock(
    session,
    blockIndex,
    target.tableBlock,
    rowIndex,
    columnIndex,
    target.cell,
    nextTextBlock,
    selection,
  );
}

class _AutoLinkContentResult {
  const _AutoLinkContentResult({required this.content, required this.changed});

  final List<InlineNode> content;
  final bool changed;
}

class _AutoLinkMatch {
  const _AutoLinkMatch({
    required this.start,
    required this.end,
    required this.url,
  });

  final int start;
  final int end;
  final String url;
}

final RegExp _autoLinkUrlRegex = RegExp(
  r'''(?:(?:https?)://|www\.)[^\s<>"'\[\]{}]+''',
  caseSensitive: false,
);

const String _trailingUrlPunctuation = '.,!?;:，。！？；：、';

_AutoLinkContentResult _autoLinkContent(
  List<InlineNode> content,
  int start,
  int end,
) {
  final text = content.map((node) => node.plainText).join();
  final safeStart = start.clamp(0, text.length).toInt();
  final safeEnd = end.clamp(safeStart, text.length).toInt();
  var nextContent = content.map((node) => node.copy()).toList();
  var changed = false;
  for (final match in _autoLinkMatches(text, safeStart, safeEnd)) {
    if (_rangeHasLinkedRun(nextContent, match.start, match.end)) {
      continue;
    }
    nextContent = withUrl(nextContent, match.start, match.end, match.url);
    changed = true;
  }
  return _AutoLinkContentResult(content: nextContent, changed: changed);
}

Iterable<_AutoLinkMatch> _autoLinkMatches(
  String text,
  int start,
  int end,
) sync* {
  final fragment = text.substring(start, end);
  for (final match in _autoLinkUrlRegex.allMatches(fragment)) {
    final matchStart = start + match.start;
    final matchEnd = _trimAutoLinkEnd(text, matchStart, start + match.end);
    if (matchEnd <= matchStart) {
      continue;
    }
    final rawUrl = text.substring(matchStart, matchEnd);
    final url = _normaliseAutoLinkUrl(rawUrl);
    if (!_isSupportedAutoLinkUrl(url)) {
      continue;
    }
    yield _AutoLinkMatch(start: matchStart, end: matchEnd, url: url);
  }
}

int _trimAutoLinkEnd(String text, int start, int end) {
  var nextEnd = end;
  while (nextEnd > start &&
      _trailingUrlPunctuation.contains(text[nextEnd - 1])) {
    nextEnd -= 1;
  }
  while (nextEnd > start &&
      text[nextEnd - 1] == ')' &&
      _countInRange(text, start, nextEnd, ')') >
          _countInRange(text, start, nextEnd, '(')) {
    nextEnd -= 1;
  }
  return nextEnd;
}

int _countInRange(String text, int start, int end, String value) {
  var count = 0;
  for (var i = start; i < end; i++) {
    if (text[i] == value) {
      count += 1;
    }
  }
  return count;
}

String _normaliseAutoLinkUrl(String rawUrl) {
  if (rawUrl.toLowerCase().startsWith('www.')) {
    return 'https://$rawUrl';
  }
  return rawUrl;
}

bool _isSupportedAutoLinkUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty || uri.host.endsWith('.')) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

bool _rangeHasLinkedRun(List<InlineNode> content, int start, int end) {
  var cursor = 0;
  for (final node in content) {
    final nodeStart = cursor;
    final nodeEnd = cursor + inlineLength(node);
    cursor = nodeEnd;
    if (nodeEnd <= start || nodeStart >= end) {
      continue;
    }
    if (node is TextRun &&
        node.attributes.url != null &&
        node.attributes.url!.isNotEmpty) {
      return true;
    }
  }
  return false;
}

// replacePlaceholderWithEmbed and withUrl live in inline_editing.dart so both
// inline_commands.dart and table_cell_editing.dart can reuse them without a
// circular import.

BlockNode? _blockAt(RichTextDocument document, int index) {
  if (index < 0 || index >= document.blocks.length) {
    return null;
  }
  return document.blocks[index];
}
