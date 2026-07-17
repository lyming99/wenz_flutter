import 'package:flutter/foundation.dart';

import '../core/model/block_node.dart';
import '../core/model/inline_node.dart';
import '../core/model/persistent_block_list.dart';
import '../core/model/rich_text_document.dart';
import 'wenz_rich_text_controller.dart';

const int _defaultReadingWordsPerMinute = 275;
const int _objectReplacementCharacter = 0xFFFC;
final RegExp _whitespaceRegex = RegExp(r'\s', unicode: true);

/// Immutable document-level statistics derived from a [RichTextDocument].
///
/// Counts are read-only projections and are never written back into the schema.
/// Characters come from visible textual content, excluding synthetic separators
/// and structural placeholders. Word count treats CJK ideographs as individual
/// words and contiguous non-CJK letters/digits as one word.
class DocumentStats {
  const DocumentStats({
    this.blockCount = 0,
    this.paragraphCount = 0,
    this.headingCount = 0,
    this.imageCount = 0,
    this.wordCount = 0,
    this.characterCount = 0,
    this.characterCountExcludingWhitespace = 0,
    this.inlineEmbedCount = 0,
    this.readingTimeMinutes = 0,
  });

  factory DocumentStats.fromDocument(
    RichTextDocument document, {
    int readingWordsPerMinute = _defaultReadingWordsPerMinute,
  }) {
    final wordsPerMinute = _validateReadingWordsPerMinute(
      readingWordsPerMinute,
    );
    final collector = _DocumentStatsCollector();
    for (final block in document.blocks) {
      collector.visitBlock(block);
    }
    return DocumentStats(
      blockCount: document.blocks.length,
      paragraphCount: collector.paragraphCount,
      headingCount: collector.headingCount,
      imageCount: collector.imageCount,
      wordCount: collector.wordCount,
      characterCount: collector.characterCount,
      characterCountExcludingWhitespace:
          collector.characterCountExcludingWhitespace,
      inlineEmbedCount: collector.inlineEmbedCount,
      readingTimeMinutes: _estimatedReadingTimeMinutes(
        collector.wordCount,
        wordsPerMinute,
      ),
    );
  }

  final int blockCount;
  final int paragraphCount;
  final int headingCount;
  final int imageCount;
  final int wordCount;
  final int characterCount;
  final int characterCountExcludingWhitespace;
  final int inlineEmbedCount;
  final int readingTimeMinutes;

  Duration get readingTime => Duration(minutes: readingTimeMinutes);

  bool get isEmpty => wordCount == 0 && characterCountExcludingWhitespace == 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DocumentStats &&
            other.blockCount == blockCount &&
            other.paragraphCount == paragraphCount &&
            other.headingCount == headingCount &&
            other.imageCount == imageCount &&
            other.wordCount == wordCount &&
            other.characterCount == characterCount &&
            other.characterCountExcludingWhitespace ==
                characterCountExcludingWhitespace &&
            other.inlineEmbedCount == inlineEmbedCount &&
            other.readingTimeMinutes == readingTimeMinutes;
  }

  @override
  int get hashCode {
    return Object.hash(
      blockCount,
      paragraphCount,
      headingCount,
      imageCount,
      wordCount,
      characterCount,
      characterCountExcludingWhitespace,
      inlineEmbedCount,
      readingTimeMinutes,
    );
  }
}

/// Derives live document statistics from a [WenzRichTextController].
class WenzDocumentStatsController extends ChangeNotifier {
  WenzDocumentStatsController({
    required WenzRichTextController editor,
    int readingWordsPerMinute = _defaultReadingWordsPerMinute,
  })  : _host = editor,
        readingWordsPerMinute = _validateReadingWordsPerMinute(
          readingWordsPerMinute,
        ) {
    _rebuildAll(_host.document);
    _host.addListener(_handleHostChanged);
  }

  final WenzRichTextController _host;
  final int readingWordsPerMinute;
  DocumentStats _stats = const DocumentStats();
  late RichTextDocument _documentSnapshot;
  final Map<String, DocumentStats> _blockStats = <String, DocumentStats>{};
  int _recomputedBlockCount = 0;
  int _paragraphCount = 0;
  int _headingCount = 0;
  int _imageCount = 0;
  int _wordCount = 0;
  int _characterCount = 0;
  int _characterCountExcludingWhitespace = 0;
  int _inlineEmbedCount = 0;

  DocumentStats get stats => _stats;

  int get blockCount => _stats.blockCount;
  int get paragraphCount => _stats.paragraphCount;
  int get headingCount => _stats.headingCount;
  int get imageCount => _stats.imageCount;
  int get wordCount => _stats.wordCount;
  int get characterCount => _stats.characterCount;
  int get characterCountExcludingWhitespace =>
      _stats.characterCountExcludingWhitespace;
  int get inlineEmbedCount => _stats.inlineEmbedCount;
  int get readingTimeMinutes => _stats.readingTimeMinutes;
  Duration get readingTime => _stats.readingTime;

  @visibleForTesting
  int get recomputedBlockCount => _recomputedBlockCount;

  void _handleHostChanged() {
    final nextDocument = _host.document;
    if (identical(nextDocument, _documentSnapshot) ||
        identical(nextDocument.blocks, _documentSnapshot.blocks)) {
      return;
    }
    final nextBlocks = nextDocument.blocks;
    final previousBlocks = _documentSnapshot.blocks;
    if (nextBlocks is PersistentBlockList &&
        nextBlocks.length == previousBlocks.length) {
      final delta = nextBlocks.deltaSince(previousBlocks);
      if (delta != null) {
        var sameStructure = true;
        for (final index in delta.changedIndexes) {
          if (nextBlocks[index].id != previousBlocks[index].id) {
            sameStructure = false;
            break;
          }
        }
        if (sameStructure) {
          for (final index in delta.changedIndexes) {
            final block = nextBlocks[index];
            final previous = _blockStats[block.id];
            if (previous != null) {
              _accumulate(previous, -1);
            }
            final next = _statsForBlock(block);
            _blockStats[block.id] = next;
            _accumulate(next, 1);
          }
          _documentSnapshot = nextDocument;
          _commitAggregatedStats();
          return;
        }
      }
    }
    _rebuildAll(nextDocument);
  }

  void _rebuildAll(RichTextDocument document) {
    _blockStats.clear();
    _resetTotals();
    for (final block in document.blocks) {
      final contribution = _statsForBlock(block);
      _blockStats[block.id] = contribution;
      _accumulate(contribution, 1);
    }
    _documentSnapshot = document;
    _commitAggregatedStats(notify: false);
  }

  DocumentStats _statsForBlock(BlockNode block) {
    _recomputedBlockCount++;
    return DocumentStats.fromDocument(
      RichTextDocument(blocks: <BlockNode>[block]),
      readingWordsPerMinute: readingWordsPerMinute,
    );
  }

  void _commitAggregatedStats({bool notify = true}) {
    final next = DocumentStats(
      blockCount: _documentSnapshot.blocks.length,
      paragraphCount: _paragraphCount,
      headingCount: _headingCount,
      imageCount: _imageCount,
      wordCount: _wordCount,
      characterCount: _characterCount,
      characterCountExcludingWhitespace: _characterCountExcludingWhitespace,
      inlineEmbedCount: _inlineEmbedCount,
      readingTimeMinutes: _estimatedReadingTimeMinutes(
        _wordCount,
        readingWordsPerMinute,
      ),
    );
    if (next == _stats) {
      return;
    }
    _stats = next;
    if (notify) {
      notifyListeners();
    }
  }

  void _resetTotals() {
    _paragraphCount = 0;
    _headingCount = 0;
    _imageCount = 0;
    _wordCount = 0;
    _characterCount = 0;
    _characterCountExcludingWhitespace = 0;
    _inlineEmbedCount = 0;
  }

  void _accumulate(DocumentStats contribution, int sign) {
    _paragraphCount += contribution.paragraphCount * sign;
    _headingCount += contribution.headingCount * sign;
    _imageCount += contribution.imageCount * sign;
    _wordCount += contribution.wordCount * sign;
    _characterCount += contribution.characterCount * sign;
    _characterCountExcludingWhitespace +=
        contribution.characterCountExcludingWhitespace * sign;
    _inlineEmbedCount += contribution.inlineEmbedCount * sign;
  }

  @override
  void dispose() {
    _host.removeListener(_handleHostChanged);
    super.dispose();
  }
}

class _DocumentStatsCollector {
  int wordCount = 0;
  int characterCount = 0;
  int characterCountExcludingWhitespace = 0;
  int paragraphCount = 0;
  int headingCount = 0;
  int imageCount = 0;
  int inlineEmbedCount = 0;
  bool _insideWord = false;

  void visitBlock(BlockNode block) {
    if (block is TextBlockNode) {
      if (block.type == BlockType.heading) {
        headingCount++;
      } else if (block.type == BlockType.paragraph) {
        paragraphCount++;
      }
      _visitInlineContent(block.content);
      endTextScope();
      return;
    }
    if (block is CodeBlockNode) {
      addText(block.code);
      endTextScope();
      return;
    }
    if (block is ImageBlockNode) {
      imageCount++;
      addText(block.caption);
      endTextScope();
      return;
    }
    if (block is TableBlockNode) {
      for (final row in block.table.rows) {
        for (final cell in row) {
          for (final nestedBlock in cell.blocks) {
            visitBlock(nestedBlock);
          }
          endTextScope();
        }
      }
      return;
    }
    if (block is CalloutBlockNode) {
      addText(block.title.trim());
      endTextScope();
      _visitInlineContent(block.content);
      endTextScope();
      return;
    }
    if (block is FileBlockNode) {
      addText(block.displayName);
      endTextScope();
      return;
    }
    endTextScope();
  }

  void addText(String text) {
    for (final rune in text.runes) {
      if (rune == _objectReplacementCharacter) {
        endTextScope();
        continue;
      }
      final value = String.fromCharCode(rune);
      characterCount++;
      final whitespace = _whitespaceRegex.hasMatch(value);
      if (!whitespace) {
        characterCountExcludingWhitespace++;
      }
      if (whitespace || _isWordSeparator(rune)) {
        endTextScope();
      } else if (_isCjkIdeograph(rune)) {
        endTextScope();
        wordCount++;
      } else if (_isWordLikeRune(rune)) {
        _insideWord = true;
      } else {
        endTextScope();
      }
    }
  }

  void endTextScope() {
    if (_insideWord) {
      wordCount++;
      _insideWord = false;
    }
  }

  void _visitInlineContent(List<InlineNode> nodes) {
    for (final node in nodes) {
      if (node is TextRun) {
        addText(node.text);
      } else if (node is InlineEmbed) {
        inlineEmbedCount++;
        addText(_embedDisplayText(node));
      }
    }
  }
}

int _validateReadingWordsPerMinute(int value) {
  if (value <= 0) {
    throw ArgumentError.value(
      value,
      'readingWordsPerMinute',
      'must be greater than zero',
    );
  }
  return value;
}

int _estimatedReadingTimeMinutes(int wordCount, int wordsPerMinute) {
  if (wordCount <= 0) {
    return 0;
  }
  return (wordCount + wordsPerMinute - 1) ~/ wordsPerMinute;
}

String _embedDisplayText(InlineEmbed embed) {
  switch (embed.embedType) {
    case 'mention':
      return _mentionDisplayText(embed);
    case 'formula':
      return _formulaDisplayText(embed);
    case 'emoji':
      return _emojiDisplayText(embed);
    default:
      return embed.plainText.trim();
  }
}

String _mentionDisplayText(InlineEmbed embed) {
  final raw = embed.data['label'] ?? embed.data['id'];
  final label = raw?.toString() ?? '';
  return label.isEmpty ? '@mention' : '@$label';
}

String _formulaDisplayText(InlineEmbed embed) {
  final raw = embed.data['text'] ?? embed.data['latex'] ?? embed.data['value'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[formula]' : text;
}

String _emojiDisplayText(InlineEmbed embed) {
  final raw = embed.data['emoji'] ??
      embed.data['text'] ??
      embed.data['value'] ??
      embed.data['shortName'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[emoji]' : text;
}

bool _isWordLikeRune(int rune) {
  if (_isAsciiLetterOrDigit(rune) || rune == 0x5F) {
    return true;
  }
  if (rune < 0x80 || _isSymbolOrEmoji(rune)) {
    return false;
  }
  return !_isWordSeparator(rune);
}

bool _isAsciiLetterOrDigit(int rune) {
  return (rune >= 0x30 && rune <= 0x39) ||
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A);
}

bool _isCjkIdeograph(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF) ||
      (rune >= 0x2A700 && rune <= 0x2B73F) ||
      (rune >= 0x2B740 && rune <= 0x2B81F) ||
      (rune >= 0x2B820 && rune <= 0x2CEAF) ||
      (rune >= 0x2CEB0 && rune <= 0x2EBEF) ||
      (rune >= 0x30000 && rune <= 0x3134F);
}

bool _isWordSeparator(int rune) {
  return (rune >= 0x21 && rune <= 0x2F) ||
      (rune >= 0x3A && rune <= 0x40) ||
      (rune >= 0x5B && rune <= 0x60) ||
      (rune >= 0x7B && rune <= 0x7E) ||
      (rune >= 0x2000 && rune <= 0x206F) ||
      (rune >= 0x2E00 && rune <= 0x2E7F) ||
      (rune >= 0x3000 && rune <= 0x303F) ||
      (rune >= 0xFE10 && rune <= 0xFE1F) ||
      (rune >= 0xFE30 && rune <= 0xFE4F) ||
      (rune >= 0xFF01 && rune <= 0xFF0F) ||
      (rune >= 0xFF1A && rune <= 0xFF20) ||
      (rune >= 0xFF3B && rune <= 0xFF40) ||
      (rune >= 0xFF5B && rune <= 0xFF65);
}

bool _isSymbolOrEmoji(int rune) {
  return (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF);
}
