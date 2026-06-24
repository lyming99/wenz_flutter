import '../model/attributes.dart';
import '../model/block_node.dart';
import '../model/rich_text_document.dart';
import '../position/document_position.dart';
import '../transaction/document_session.dart';
import 'editor_command.dart';

/// Adjusts the [BlockAttributes.indent] of every text block covered by the
/// current selection by [delta] (clamped to >= 0 and the schema max). Stage 3
/// uses indent for both paragraph indentation and quote nesting depth.
class IndentCommand extends EditorCommand {
  const IndentCommand(this.delta, {this.selection});

  final int delta;
  final DocumentSelection? selection;

  @override
  String get description => delta > 0 ? 'indent' : 'outdent';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || delta == 0) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final current = block.attributes.indent ?? 0;
      final next = (current + delta).clamp(0, 8).toInt();
      if (next == current) {
        continue;
      }
      blocks[i] = TextBlockNode(
        id: block.id,
        type: block.type,
        attributes: BlockAttributes(
          level: block.attributes.level,
          indent: next,
          alignment: block.attributes.alignment,
          listType: block.attributes.listType,
          checked: block.attributes.checked,
          childNote: block.attributes.childNote,
          anchor: block.attributes.anchor,
        ),
        content: block.content,
      );
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }
}

/// Toggles the checked state of a task list item at the caret. If the block is
/// not a task list item, converts it to one first.
class ToggleTodoCommand extends EditorCommand {
  const ToggleTodoCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleTodo';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      final isTask = block.type == BlockType.listItem &&
          block.attributes.listType == 'task';
      if (isTask) {
        blocks[i] = _withChecked(block, !(block.attributes.checked ?? false));
      } else {
        blocks[i] = TextBlockNode(
          id: block.id,
          type: BlockType.listItem,
          attributes: BlockAttributes(
            indent: block.attributes.indent,
            alignment: block.attributes.alignment,
            listType: 'task',
            checked: false,
            childNote: block.attributes.childNote,
            anchor: block.attributes.anchor,
          ),
          content: block.content,
        );
      }
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }

  TextBlockNode _withChecked(TextBlockNode block, bool checked) {
    return TextBlockNode(
      id: block.id,
      type: block.type,
      attributes: BlockAttributes(
        level: block.attributes.level,
        indent: block.attributes.indent,
        alignment: block.attributes.alignment,
        listType: block.attributes.listType,
        checked: checked,
        childNote: block.attributes.childNote,
        anchor: block.attributes.anchor,
      ),
      content: block.content,
    );
  }
}

/// Sets the [CodeBlockNode.language] of the code block at the caret.
class SetCodeLanguageCommand extends EditorCommand {
  const SetCodeLanguageCommand(this.language, {this.blockIndex});

  final String language;
  final int? blockIndex;

  @override
  String get description => 'setCodeLanguage';

  @override
  CommandResult execute(DocumentSession session) {
    final nextLanguage = language.trim();
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CodeBlockNode || block.language == nextLanguage) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[index] = CodeBlockNode(
      id: block.id,
      code: block.code,
      language: nextLanguage,
      attributes: block.attributes,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

/// Sets the [CalloutBlockNode.variant] of the callout block at the caret.
class SetCalloutVariantCommand extends EditorCommand {
  const SetCalloutVariantCommand(this.variant, {this.blockIndex});

  final String variant;
  final int? blockIndex;

  @override
  String get description => 'setCalloutVariant';

  @override
  CommandResult execute(DocumentSession session) {
    final nextVariant = CalloutBlockNode.normalizeVariant(variant);
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CalloutBlockNode || block.normalizedVariant == nextVariant) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[index] = block.copyWith(variant: nextVariant);
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

/// Updates the metadata of the callout block at [blockIndex] or the caret.
///
/// Empty [title] or [icon] values clear the custom value, allowing the block to
/// fall back to the default title/icon for its current variant.
class UpdateCalloutBlockCommand extends EditorCommand {
  const UpdateCalloutBlockCommand({
    this.blockIndex,
    this.variant,
    this.title,
    this.icon,
  });

  final int? blockIndex;
  final String? variant;
  final String? title;
  final String? icon;

  @override
  String get description => 'updateCalloutBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final index = blockIndex ?? session.selection?.extent.blockIndex ?? -1;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CalloutBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final nextVariant = variant == null
        ? CalloutBlockNode.normalizeVariant(block.variant)
        : CalloutBlockNode.normalizeVariant(variant);
    final nextTitle = title == null ? block.title : title!.trim();
    final nextIcon = icon == null ? block.icon : icon!.trim();
    if (block.variant == nextVariant &&
        block.title == nextTitle &&
        block.icon == nextIcon) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[index] = block.copyWith(
      variant: nextVariant,
      title: nextTitle,
      icon: nextIcon,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return const CommandResult();
  }
}

/// Indents or outdents every code line touched by the current code selection.
class IndentCodeBlockCommand extends EditorCommand {
  const IndentCodeBlockCommand({
    this.selection,
    this.indent = '  ',
    this.outdent = false,
  });

  final DocumentSelection? selection;
  final String indent;
  final bool outdent;

  @override
  String get description => outdent ? 'outdentCodeBlock' : 'indentCodeBlock';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null || indent.isEmpty) {
      return const CommandResult(recordHistory: false);
    }
    final start = target.start;
    final end = target.end;
    if (start.blockIndex != end.blockIndex ||
        start.path != end.path ||
        !start.path.isBlockCode) {
      return const CommandResult(recordHistory: false);
    }
    final index = start.blockIndex;
    if (index < 0 || index >= session.document.blocks.length) {
      return const CommandResult(recordHistory: false);
    }
    final block = session.document.blocks[index];
    if (block is! CodeBlockNode) {
      return const CommandResult(recordHistory: false);
    }

    final code = block.code;
    final rangeStart = start.offset.clamp(0, code.length).toInt();
    final rangeEnd = end.offset.clamp(rangeStart, code.length).toInt();
    final lineStarts = _codeLineStartsForRange(code, rangeStart, rangeEnd);
    if (lineStarts.isEmpty) {
      return const CommandResult(recordHistory: false);
    }

    var nextCode = code;
    var baseOffset = target.base.offset.clamp(0, code.length).toInt();
    var extentOffset = target.extent.offset.clamp(0, code.length).toInt();
    var changed = false;

    for (final lineStart in lineStarts.reversed) {
      final removedLength =
          outdent ? _codeOutdentLength(nextCode, lineStart, indent) : 0;
      final inserted = outdent ? '' : indent;
      if (outdent && removedLength == 0) {
        continue;
      }
      nextCode = nextCode.replaceRange(
        lineStart,
        lineStart + removedLength,
        inserted,
      );
      baseOffset = _transformCodeOffset(
        baseOffset,
        lineStart,
        removedLength,
        inserted.length,
      );
      extentOffset = _transformCodeOffset(
        extentOffset,
        lineStart,
        removedLength,
        inserted.length,
      );
      changed = true;
    }

    if (!changed || nextCode == code) {
      return const CommandResult(recordHistory: false);
    }

    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    blocks[index] = CodeBlockNode(
      id: block.id,
      code: nextCode,
      language: block.language,
      attributes: block.attributes,
    );
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    final base = target.base.copyWith(offset: baseOffset);
    final extent = target.extent.copyWith(offset: extentOffset);
    return CommandResult(
        selection: DocumentSelection(base: base, extent: extent));
  }
}

List<int> _codeLineStartsForRange(String code, int start, int end) {
  if (code.isEmpty) {
    return const <int>[0];
  }
  final effectiveEnd =
      start == end || end == 0 || code.codeUnitAt(end - 1) != 0x0A
          ? end
          : end - 1;
  final firstLineStart = _codeLineStart(code, start);
  final lastLineStart = _codeLineStart(code, effectiveEnd);
  final starts = <int>[];
  var current = firstLineStart;
  while (current <= lastLineStart && current <= code.length) {
    starts.add(current);
    final nextBreak = code.indexOf('\n', current);
    if (nextBreak < 0) {
      break;
    }
    current = nextBreak + 1;
  }
  return starts;
}

int _codeLineStart(String code, int offset) {
  if (code.isEmpty) {
    return 0;
  }
  final clamped = offset.clamp(0, code.length).toInt();
  if (clamped == 0) {
    return 0;
  }
  final newline = code.lastIndexOf('\n', clamped - 1);
  return newline < 0 ? 0 : newline + 1;
}

int _codeOutdentLength(String code, int lineStart, String indent) {
  if (lineStart >= code.length) {
    return 0;
  }
  if (code.startsWith(indent, lineStart)) {
    return indent.length;
  }
  if (code.codeUnitAt(lineStart) == 0x09) {
    return 1;
  }
  var spaces = 0;
  while (spaces < indent.length &&
      lineStart + spaces < code.length &&
      code.codeUnitAt(lineStart + spaces) == 0x20) {
    spaces += 1;
  }
  return spaces;
}

int _transformCodeOffset(
  int offset,
  int changeStart,
  int removedLength,
  int insertedLength,
) {
  if (removedLength == 0) {
    return offset < changeStart ? offset : offset + insertedLength;
  }
  if (offset <= changeStart) {
    return offset;
  }
  final changeEnd = changeStart + removedLength;
  if (offset <= changeEnd) {
    return changeStart + insertedLength;
  }
  return offset + insertedLength - removedLength;
}

/// Toggles the quote type of the block at the caret: a non-quote becomes a
/// quote, a quote becomes a paragraph. Quote nesting depth uses indent.
class ToggleQuoteCommand extends EditorCommand {
  const ToggleQuoteCommand({this.selection});

  final DocumentSelection? selection;

  @override
  String get description => 'toggleQuote';

  @override
  CommandResult execute(DocumentSession session) {
    final target = selection ?? session.selection;
    if (target == null) {
      return const CommandResult(recordHistory: false);
    }
    final blocks = session.document.blocks.map((b) => b.copy()).toList();
    var changed = false;
    for (var i = target.start.blockIndex; i <= target.end.blockIndex; i++) {
      if (i < 0 || i >= blocks.length) {
        continue;
      }
      final block = blocks[i];
      if (block is! TextBlockNode) {
        continue;
      }
      blocks[i] = block.type == BlockType.quote
          ? _convert(block, BlockType.paragraph)
          : _convert(block, BlockType.quote);
      changed = true;
    }
    if (!changed) {
      return const CommandResult(recordHistory: false);
    }
    session.document = RichTextDocument(
      version: session.document.version,
      blocks: blocks,
    );
    return CommandResult(selection: target);
  }

  TextBlockNode _convert(TextBlockNode block, BlockType type) {
    return TextBlockNode(
      id: block.id,
      type: type,
      attributes: BlockAttributes(
        indent: block.attributes.indent,
        alignment: block.attributes.alignment,
        childNote: block.attributes.childNote,
        anchor: block.attributes.anchor,
      ),
      content: block.content,
    );
  }
}
