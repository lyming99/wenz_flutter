import 'package:flutter/foundation.dart';

import '../core/commands/inline_editing.dart';
import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/table_model.dart';
import '../core/position/document_position.dart';
import 'wenz_rich_text_controller.dart';

class FindReplaceOptions {
  const FindReplaceOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
  });

  final bool caseSensitive;
  final bool wholeWord;

  FindReplaceOptions copyWith({
    bool? caseSensitive,
    bool? wholeWord,
  }) {
    return FindReplaceOptions(
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWord: wholeWord ?? this.wholeWord,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FindReplaceOptions &&
        other.caseSensitive == caseSensitive &&
        other.wholeWord == wholeWord;
  }

  @override
  int get hashCode => Object.hash(caseSensitive, wholeWord);
}

class FindReplaceMatch {
  const FindReplaceMatch({
    required this.selection,
    required this.text,
    required this.blockId,
    required this.blockIndex,
    required this.path,
    required this.start,
    required this.end,
  });

  final DocumentSelection selection;
  final String text;
  final String blockId;
  final int blockIndex;
  final PositionPath path;
  final int start;
  final int end;

  bool containsPath(PositionPath targetPath, int targetBlockIndex) {
    return blockIndex == targetBlockIndex && path == targetPath;
  }

  @override
  bool operator ==(Object other) {
    return other is FindReplaceMatch &&
        other.selection == selection &&
        other.text == text &&
        other.blockId == blockId &&
        other.blockIndex == blockIndex &&
        other.path == path &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode {
    return Object.hash(selection, text, blockId, blockIndex, path, start, end);
  }
}

class WenzFindReplaceController extends ChangeNotifier {
  WenzFindReplaceController({
    required WenzRichTextController editor,
    FindReplaceOptions options = const FindReplaceOptions(),
  })  : _editor = editor,
        _options = options {
    _editor.addListener(_handleEditorChanged);
  }

  WenzRichTextController get editor => _editor;
  WenzRichTextController _editor;

  String get query => _query;
  String _query = '';

  String get replacement => _replacement;
  String _replacement = '';

  FindReplaceOptions get options => _options;
  FindReplaceOptions _options;

  List<FindReplaceMatch> get matches =>
      List<FindReplaceMatch>.unmodifiable(_matches);
  List<FindReplaceMatch> _matches = const <FindReplaceMatch>[];

  int get currentIndex => _currentIndex;
  int _currentIndex = -1;

  FindReplaceMatch? get currentMatch {
    if (_currentIndex < 0 || _currentIndex >= _matches.length) {
      return null;
    }
    return _matches[_currentIndex];
  }

  bool get hasQuery => _query.isNotEmpty;

  bool get hasMatches => _matches.isNotEmpty;

  void attachEditor(WenzRichTextController editor) {
    if (identical(_editor, editor)) {
      return;
    }
    _editor.removeListener(_handleEditorChanged);
    _editor = editor;
    _editor.addListener(_handleEditorChanged);
    refresh(selectNearest: true);
  }

  void setQuery(String value, {bool selectFirst = true}) {
    if (_query == value) {
      return;
    }
    _query = value;
    refresh(selectNearest: !selectFirst);
    if (selectFirst && _matches.isNotEmpty) {
      selectMatch(0);
    }
  }

  void setReplacement(String value) {
    if (_replacement == value) {
      return;
    }
    _replacement = value;
    notifyListeners();
  }

  void setOptions({
    bool? caseSensitive,
    bool? wholeWord,
  }) {
    final next = _options.copyWith(
      caseSensitive: caseSensitive,
      wholeWord: wholeWord,
    );
    if (next == _options) {
      return;
    }
    _options = next;
    refresh(selectNearest: true);
  }

  void refresh({bool selectNearest = false}) {
    final previous = currentMatch;
    _matches = _query.isEmpty
        ? const <FindReplaceMatch>[]
        : _findMatches(_editor.document.blocks, _query, _options);
    _currentIndex = _resolveCurrentIndex(
      previous: previous,
      selectNearest: selectNearest,
    );
    notifyListeners();
  }

  FindReplaceMatch? next({bool wrap = true}) {
    if (_matches.isEmpty) {
      return null;
    }
    final nextIndex = _currentIndex < 0
        ? 0
        : _currentIndex + 1 < _matches.length
            ? _currentIndex + 1
            : wrap
                ? 0
                : _currentIndex;
    return selectMatch(nextIndex);
  }

  FindReplaceMatch? previous({bool wrap = true}) {
    if (_matches.isEmpty) {
      return null;
    }
    final nextIndex = _currentIndex < 0
        ? _matches.length - 1
        : _currentIndex > 0
            ? _currentIndex - 1
            : wrap
                ? _matches.length - 1
                : _currentIndex;
    return selectMatch(nextIndex);
  }

  FindReplaceMatch? selectMatch(int index) {
    if (index < 0 || index >= _matches.length) {
      return null;
    }
    _currentIndex = index;
    final match = _matches[index];
    _editor.setSelection(match.selection);
    notifyListeners();
    return match;
  }

  bool replaceCurrent([String? value]) {
    final match = currentMatch;
    if (match == null) {
      return false;
    }
    final replacementText = value ?? _replacement;
    final oldIndex = _currentIndex;
    _editor.setSelection(match.selection);
    final change = _editor.insertText(
      replacementText,
      applyMarkdownShortcuts: false,
    );
    if (change.isNoop) {
      refresh(selectNearest: true);
      return false;
    }
    refresh();
    if (_matches.isNotEmpty) {
      selectMatch(oldIndex.clamp(0, _matches.length - 1).toInt());
    }
    return true;
  }

  int replaceAll([String? value]) {
    if (_matches.isEmpty) {
      return 0;
    }
    final replacementText = value ?? _replacement;
    final targets = List<FindReplaceMatch>.from(_matches);
    var count = 0;
    for (final match in targets.reversed) {
      _editor.setSelection(match.selection);
      final change = _editor.insertText(
        replacementText,
        applyMarkdownShortcuts: false,
      );
      if (!change.isNoop) {
        count += 1;
      }
    }
    refresh();
    return count;
  }

  int _resolveCurrentIndex({
    required FindReplaceMatch? previous,
    required bool selectNearest,
  }) {
    if (_matches.isEmpty) {
      return -1;
    }
    if (previous != null) {
      final same = _matches.indexWhere((match) => match == previous);
      if (same != -1) {
        return same;
      }
      if (selectNearest) {
        final nearest = _matches.indexWhere(
          (match) =>
              match.selection.start.compareTo(previous.selection.start) >= 0,
        );
        if (nearest != -1) {
          return nearest;
        }
      }
    }
    if (selectNearest) {
      final selection = _editor.selection;
      if (selection != null) {
        final nearest = _matches.indexWhere(
          (match) => match.selection.start.compareTo(selection.start) >= 0,
        );
        if (nearest != -1) {
          return nearest;
        }
      }
    }
    return 0;
  }

  void _handleEditorChanged() {
    refresh(selectNearest: true);
  }

  @override
  void dispose() {
    _editor.removeListener(_handleEditorChanged);
    super.dispose();
  }
}

List<FindReplaceMatch> _findMatches(
  List<BlockNode> blocks,
  String query,
  FindReplaceOptions options,
) {
  final matches = <FindReplaceMatch>[];
  for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
    final block = blocks[blockIndex];
    if (block is TextBlockNode) {
      matches.addAll(
        _findInText(
          text: _inlinePlainText(block.content),
          query: query,
          options: options,
          positionBuilder: (offset) => DocumentPosition.text(
            blockId: block.id,
            blockIndex: blockIndex,
            offset: offset,
          ),
          blockId: block.id,
          blockIndex: blockIndex,
          path: PositionPath.blockText(block.id),
        ),
      );
    } else if (block is CodeBlockNode) {
      matches.addAll(
        _findInText(
          text: block.code,
          query: query,
          options: options,
          positionBuilder: (offset) => DocumentPosition.code(
            blockId: block.id,
            blockIndex: blockIndex,
            offset: offset,
          ),
          blockId: block.id,
          blockIndex: blockIndex,
          path: PositionPath.blockCode(block.id),
        ),
      );
    } else if (block is TableBlockNode) {
      matches.addAll(_findInTable(block, blockIndex, query, options));
    }
  }
  return matches;
}

List<FindReplaceMatch> _findInTable(
  TableBlockNode block,
  int blockIndex,
  String query,
  FindReplaceOptions options,
) {
  final matches = <FindReplaceMatch>[];
  for (var row = 0; row < block.table.rows.length; row++) {
    final cells = block.table.rows[row];
    for (var column = 0; column < cells.length; column++) {
      final cell = cells[column];
      if (cell.covered) {
        continue;
      }
      final inline = _firstTextBlockInline(cell);
      final path = PositionPath.tableCellText(block.id, row, column);
      matches.addAll(
        _findInText(
          text: _inlinePlainText(inline),
          query: query,
          options: options,
          positionBuilder: (offset) => DocumentPosition.tableCell(
            tableBlockId: block.id,
            blockIndex: blockIndex,
            tableRowIndex: row,
            tableColumnIndex: column,
            offset: offset,
          ),
          blockId: block.id,
          blockIndex: blockIndex,
          path: path,
        ),
      );
    }
  }
  return matches;
}

List<InlineNode> _firstTextBlockInline(TableCellNode cell) {
  for (final block in cell.blocks) {
    if (block is TextBlockNode) {
      return block.content;
    }
  }
  return const <InlineNode>[];
}

List<FindReplaceMatch> _findInText({
  required String text,
  required String query,
  required FindReplaceOptions options,
  required DocumentPosition Function(int offset) positionBuilder,
  required String blockId,
  required int blockIndex,
  required PositionPath path,
}) {
  if (text.isEmpty || query.isEmpty) {
    return const <FindReplaceMatch>[];
  }
  final haystack = options.caseSensitive ? text : text.toLowerCase();
  final needle = options.caseSensitive ? query : query.toLowerCase();
  final matches = <FindReplaceMatch>[];
  var index = 0;
  while (index <= haystack.length - needle.length) {
    final found = haystack.indexOf(needle, index);
    if (found == -1) {
      break;
    }
    final end = found + needle.length;
    if (!options.wholeWord || _isWholeWord(haystack, found, end)) {
      final startPosition = positionBuilder(found);
      final endPosition = positionBuilder(end);
      matches.add(
        FindReplaceMatch(
          selection: DocumentSelection(
            base: startPosition,
            extent: endPosition,
          ),
          text: text.substring(found, end),
          blockId: blockId,
          blockIndex: blockIndex,
          path: path,
          start: found,
          end: end,
        ),
      );
    }
    index = found + needle.length;
  }
  return matches;
}

String _inlinePlainText(List<InlineNode> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is InlineEmbed) {
      buffer.write(' ' * inlineLength(node));
    } else {
      buffer.write(node.plainText);
    }
  }
  return buffer.toString();
}

bool _isWholeWord(String text, int start, int end) {
  final before = start == 0 ? null : text.codeUnitAt(start - 1);
  final after = end >= text.length ? null : text.codeUnitAt(end);
  return !_isWordCodeUnit(before) && !_isWordCodeUnit(after);
}

bool _isWordCodeUnit(int? codeUnit) {
  if (codeUnit == null) {
    return false;
  }
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F;
}
