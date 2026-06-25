import 'package:flutter/material.dart';

enum _CodeSyntaxTokenKind { keyword, type, string, comment, number, marker }

final class CodeSyntaxPalette {
  const CodeSyntaxPalette({
    required this.keyword,
    required this.type,
    required this.string,
    required this.comment,
    required this.number,
    required this.marker,
  });

  factory CodeSyntaxPalette.fromColorScheme(ColorScheme scheme) {
    return CodeSyntaxPalette(
      keyword: scheme.primary,
      type: scheme.secondary,
      string: scheme.tertiary,
      comment: scheme.onSurfaceVariant,
      number: scheme.error,
      marker: scheme.primary,
    );
  }

  final Color keyword;
  final Color type;
  final Color string;
  final Color comment;
  final Color number;
  final Color marker;
}

final class CodeSyntaxHighlighter {
  const CodeSyntaxHighlighter({
    required this.language,
    required this.baseStyle,
    required this.palette,
    this.compositionStart,
    this.compositionEnd,
  });

  final String language;
  final TextStyle baseStyle;
  final CodeSyntaxPalette palette;
  final int? compositionStart;
  final int? compositionEnd;

  TextSpan highlight(String code) {
    final tokens = _tokensForLanguage(code, language);
    if (tokens == null || tokens.isEmpty) {
      return _plainSpan(code);
    }
    final children = <TextSpan>[];
    var offset = 0;
    for (final token in tokens) {
      final start = token.start.clamp(offset, code.length).toInt();
      final end = token.end.clamp(start, code.length).toInt();
      if (start > offset) {
        _appendSegment(children, code, offset, start, baseStyle);
      }
      if (end > start) {
        _appendSegment(children, code, start, end, _styleFor(token.kind));
      }
      offset = end;
    }
    if (offset < code.length) {
      _appendSegment(children, code, offset, code.length, baseStyle);
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _plainSpan(String code) {
    final range = _compositionRange(code.length);
    if (range == null) {
      return TextSpan(text: code, style: baseStyle);
    }
    final children = <TextSpan>[];
    _appendSegment(children, code, 0, code.length, baseStyle);
    return TextSpan(style: baseStyle, children: children);
  }

  TextStyle _styleFor(_CodeSyntaxTokenKind kind) {
    return switch (kind) {
      _CodeSyntaxTokenKind.keyword => baseStyle.copyWith(
          color: palette.keyword,
          fontWeight: FontWeight.w700,
        ),
      _CodeSyntaxTokenKind.type => baseStyle.copyWith(
          color: palette.type,
          fontWeight: FontWeight.w600,
        ),
      _CodeSyntaxTokenKind.string => baseStyle.copyWith(color: palette.string),
      _CodeSyntaxTokenKind.comment => baseStyle.copyWith(
          color: palette.comment,
          fontStyle: FontStyle.italic,
        ),
      _CodeSyntaxTokenKind.number => baseStyle.copyWith(color: palette.number),
      _CodeSyntaxTokenKind.marker => baseStyle.copyWith(
          color: palette.marker,
          fontWeight: FontWeight.w600,
        ),
    };
  }

  void _appendSegment(
    List<TextSpan> spans,
    String code,
    int start,
    int end,
    TextStyle style,
  ) {
    if (start >= end) {
      return;
    }
    final range = _compositionRange(code.length);
    if (range == null || end <= range.start || start >= range.end) {
      spans.add(TextSpan(text: code.substring(start, end), style: style));
      return;
    }
    if (start < range.start) {
      spans.add(TextSpan(
        text: code.substring(start, range.start),
        style: style,
      ));
    }
    final underlineStart = start < range.start ? range.start : start;
    final underlineEnd = end > range.end ? range.end : end;
    spans.add(TextSpan(
      text: code.substring(underlineStart, underlineEnd),
      style: style.copyWith(decoration: TextDecoration.underline),
    ));
    if (underlineEnd < end) {
      spans.add(TextSpan(
        text: code.substring(underlineEnd, end),
        style: style,
      ));
    }
  }

  ({int start, int end})? _compositionRange(int codeLength) {
    final start = compositionStart;
    final end = compositionEnd;
    if (start == null || end == null || start == end || codeLength <= 0) {
      return null;
    }
    final safeStart = start.clamp(0, codeLength).toInt();
    final safeEnd = end.clamp(safeStart, codeLength).toInt();
    if (safeStart == safeEnd) {
      return null;
    }
    return (start: safeStart, end: safeEnd);
  }
}

final class _CodeSyntaxToken {
  const _CodeSyntaxToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final _CodeSyntaxTokenKind kind;
}

List<_CodeSyntaxToken>? _tokensForLanguage(String code, String language) {
  return switch (_normalizeLanguage(language)) {
    'dart' => _highlightCodeLike(
        code,
        keywords: _dartKeywords,
        types: _dartTypes,
        rawStrings: true,
        tripleQuotedStrings: true,
      ),
    'javascript' => _highlightCodeLike(
        code,
        keywords: _javascriptKeywords,
        types: _javascriptTypes,
        backtickStrings: true,
      ),
    'typescript' => _highlightCodeLike(
        code,
        keywords: _typescriptKeywords,
        types: _typescriptTypes,
        backtickStrings: true,
      ),
    'json' => _highlightJson(code),
    'markdown' => _highlightMarkdown(code),
    _ => null,
  };
}

String _normalizeLanguage(String language) {
  final normalized = language.trim().toLowerCase();
  if (normalized.startsWith('.')) {
    return _normalizeLanguage(normalized.substring(1));
  }
  return switch (normalized) {
    'js' || 'jsx' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'md' || 'mdown' || 'gfm' => 'markdown',
    _ => normalized,
  };
}

List<_CodeSyntaxToken> _highlightCodeLike(
  String code, {
  required Set<String> keywords,
  required Set<String> types,
  bool rawStrings = false,
  bool tripleQuotedStrings = false,
  bool backtickStrings = false,
}) {
  final tokens = <_CodeSyntaxToken>[];
  var index = 0;
  while (index < code.length) {
    if (_startsWithAt(code, index, '//')) {
      final end = _lineEnd(code, index + 2);
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.comment));
      index = end;
      continue;
    }
    if (_startsWithAt(code, index, '/*')) {
      final close = code.indexOf('*/', index + 2);
      final end = close < 0 ? code.length : close + 2;
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.comment));
      index = end;
      continue;
    }
    final char = code.codeUnitAt(index);
    if (rawStrings &&
        char == _rCodeUnit &&
        index + 1 < code.length &&
        _isQuote(code.codeUnitAt(index + 1)) &&
        !_hasIdentifierBefore(code, index)) {
      final end = _scanString(
        code,
        index + 1,
        raw: true,
        tripleQuotedStrings: tripleQuotedStrings,
      );
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.string));
      index = end;
      continue;
    }
    if (_isQuote(char) || (backtickStrings && char == _backtickCodeUnit)) {
      final end = _scanString(
        code,
        index,
        raw: false,
        tripleQuotedStrings: tripleQuotedStrings,
        multiline: char == _backtickCodeUnit,
      );
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.string));
      index = end;
      continue;
    }
    if (_isDigit(char)) {
      final end = _scanNumber(code, index);
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.number));
      index = end;
      continue;
    }
    if (_isIdentifierStart(char)) {
      final end = _scanIdentifier(code, index);
      final text = code.substring(index, end);
      if (keywords.contains(text)) {
        tokens.add(_CodeSyntaxToken(
          index,
          end,
          _CodeSyntaxTokenKind.keyword,
        ));
      } else if (types.contains(text) || _looksLikeTypeName(text)) {
        tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.type));
      }
      index = end;
      continue;
    }
    index += 1;
  }
  return tokens;
}

List<_CodeSyntaxToken> _highlightJson(String code) {
  final tokens = <_CodeSyntaxToken>[];
  var index = 0;
  while (index < code.length) {
    final char = code.codeUnitAt(index);
    if (_isQuote(char)) {
      final end = _scanString(code, index, raw: false);
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.string));
      index = end;
      continue;
    }
    if (_isDigit(char) || char == _dashCodeUnit) {
      final end = _scanNumber(code, index);
      if (end > index + (char == _dashCodeUnit ? 1 : 0)) {
        tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.number));
        index = end;
        continue;
      }
    }
    if (_isIdentifierStart(char)) {
      final end = _scanIdentifier(code, index);
      if (_jsonKeywords.contains(code.substring(index, end))) {
        tokens.add(_CodeSyntaxToken(
          index,
          end,
          _CodeSyntaxTokenKind.keyword,
        ));
      }
      index = end;
      continue;
    }
    index += 1;
  }
  return tokens;
}

List<_CodeSyntaxToken> _highlightMarkdown(String code) {
  final tokens = <_CodeSyntaxToken>[];
  _addMarkdownLineMarkers(code, tokens);
  var index = 0;
  while (index < code.length) {
    if (_startsWithAt(code, index, '<!--')) {
      final close = code.indexOf('-->', index + 4);
      final end = close < 0 ? code.length : close + 3;
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.comment));
      index = end;
      continue;
    }
    if (code.codeUnitAt(index) == _backtickCodeUnit) {
      final end = _scanMarkdownCodeSpan(code, index);
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.string));
      index = end;
      continue;
    }
    if (code.codeUnitAt(index) == _leftBracketCodeUnit) {
      final labelEnd = code.indexOf('](', index + 1);
      if (labelEnd > index) {
        final urlEnd = code.indexOf(')', labelEnd + 2);
        if (urlEnd > labelEnd) {
          tokens.add(_CodeSyntaxToken(
            index,
            index + 1,
            _CodeSyntaxTokenKind.marker,
          ));
          tokens.add(_CodeSyntaxToken(
            labelEnd,
            labelEnd + 2,
            _CodeSyntaxTokenKind.marker,
          ));
          tokens.add(_CodeSyntaxToken(
            labelEnd + 2,
            urlEnd,
            _CodeSyntaxTokenKind.string,
          ));
          tokens.add(_CodeSyntaxToken(
            urlEnd,
            urlEnd + 1,
            _CodeSyntaxTokenKind.marker,
          ));
          index = urlEnd + 1;
          continue;
        }
      }
    }
    if (_isMarkdownEmphasis(code.codeUnitAt(index))) {
      final end = _scanMarkdownEmphasisMarker(code, index);
      tokens.add(_CodeSyntaxToken(index, end, _CodeSyntaxTokenKind.marker));
      index = end;
      continue;
    }
    index += 1;
  }
  return _normalizeTokens(tokens, code.length);
}

void _addMarkdownLineMarkers(String code, List<_CodeSyntaxToken> tokens) {
  var lineStart = 0;
  while (lineStart < code.length) {
    final lineEnd = _lineEnd(code, lineStart);
    var markerStart = lineStart;
    while (markerStart < lineEnd &&
        (code.codeUnitAt(markerStart) == _spaceCodeUnit ||
            code.codeUnitAt(markerStart) == _tabCodeUnit)) {
      markerStart += 1;
    }
    if (_startsWithAt(code, markerStart, '```') ||
        _startsWithAt(code, markerStart, '~~~')) {
      tokens.add(_CodeSyntaxToken(
        markerStart,
        markerStart + 3,
        _CodeSyntaxTokenKind.marker,
      ));
    } else if (markerStart < lineEnd &&
        code.codeUnitAt(markerStart) == _hashCodeUnit) {
      final markerEnd = _scanRepeated(code, markerStart, _hashCodeUnit);
      if (markerEnd <= markerStart + 6 &&
          (markerEnd == lineEnd ||
              code.codeUnitAt(markerEnd) == _spaceCodeUnit ||
              code.codeUnitAt(markerEnd) == _tabCodeUnit)) {
        tokens.add(_CodeSyntaxToken(
          markerStart,
          markerEnd,
          _CodeSyntaxTokenKind.keyword,
        ));
      }
    } else if (markerStart < lineEnd &&
        code.codeUnitAt(markerStart) == _greaterThanCodeUnit) {
      tokens.add(_CodeSyntaxToken(
        markerStart,
        markerStart + 1,
        _CodeSyntaxTokenKind.marker,
      ));
    } else {
      final listMarkerEnd = _markdownListMarkerEnd(code, markerStart, lineEnd);
      if (listMarkerEnd > markerStart) {
        tokens.add(_CodeSyntaxToken(
          markerStart,
          listMarkerEnd,
          _CodeSyntaxTokenKind.marker,
        ));
      }
    }
    if (lineEnd == code.length) {
      break;
    }
    lineStart = lineEnd + 1;
  }
}

List<_CodeSyntaxToken> _normalizeTokens(
  List<_CodeSyntaxToken> tokens,
  int codeLength,
) {
  tokens.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart == 0 ? a.end.compareTo(b.end) : byStart;
  });
  final normalized = <_CodeSyntaxToken>[];
  var cursor = 0;
  for (final token in tokens) {
    final start = token.start.clamp(0, codeLength).toInt();
    final end = token.end.clamp(start, codeLength).toInt();
    if (end <= cursor) {
      continue;
    }
    normalized.add(_CodeSyntaxToken(
      start < cursor ? cursor : start,
      end,
      token.kind,
    ));
    cursor = end;
  }
  return normalized;
}

int _scanString(
  String code,
  int quoteIndex, {
  required bool raw,
  bool tripleQuotedStrings = false,
  bool multiline = false,
}) {
  final quote = code.codeUnitAt(quoteIndex);
  if (tripleQuotedStrings &&
      quoteIndex + 2 < code.length &&
      code.codeUnitAt(quoteIndex + 1) == quote &&
      code.codeUnitAt(quoteIndex + 2) == quote) {
    final delimiter = String.fromCharCodes(<int>[quote, quote, quote]);
    final close = code.indexOf(delimiter, quoteIndex + 3);
    return close < 0 ? code.length : close + 3;
  }
  var index = quoteIndex + 1;
  var escaped = false;
  while (index < code.length) {
    final char = code.codeUnitAt(index);
    if (!raw && escaped) {
      escaped = false;
      index += 1;
      continue;
    }
    if (!raw && char == _backslashCodeUnit) {
      escaped = true;
      index += 1;
      continue;
    }
    if (char == quote) {
      return index + 1;
    }
    if (!multiline && _isNewline(char)) {
      return index;
    }
    index += 1;
  }
  return code.length;
}

int _scanNumber(String code, int start) {
  var index = start;
  if (index < code.length && code.codeUnitAt(index) == _dashCodeUnit) {
    index += 1;
  }
  if (index + 1 < code.length &&
      code.codeUnitAt(index) == _zeroCodeUnit &&
      (code.codeUnitAt(index + 1) == _xCodeUnit ||
          code.codeUnitAt(index + 1) == _upperXCodeUnit)) {
    index += 2;
    while (
        index < code.length && _isHexDigitOrSeparator(code.codeUnitAt(index))) {
      index += 1;
    }
    return index;
  }
  while (index < code.length && _isDigitOrSeparator(code.codeUnitAt(index))) {
    index += 1;
  }
  if (index + 1 < code.length &&
      code.codeUnitAt(index) == _dotCodeUnit &&
      _isDigit(code.codeUnitAt(index + 1))) {
    index += 1;
    while (index < code.length && _isDigitOrSeparator(code.codeUnitAt(index))) {
      index += 1;
    }
  }
  if (index < code.length &&
      (code.codeUnitAt(index) == _eCodeUnit ||
          code.codeUnitAt(index) == _upperECodeUnit)) {
    final exponentStart = index;
    index += 1;
    if (index < code.length &&
        (code.codeUnitAt(index) == _plusCodeUnit ||
            code.codeUnitAt(index) == _dashCodeUnit)) {
      index += 1;
    }
    final digitsStart = index;
    while (index < code.length && _isDigitOrSeparator(code.codeUnitAt(index))) {
      index += 1;
    }
    if (index == digitsStart) {
      return exponentStart;
    }
  }
  return index;
}

int _scanIdentifier(String code, int start) {
  var index = start + 1;
  while (index < code.length && _isIdentifierPart(code.codeUnitAt(index))) {
    index += 1;
  }
  return index;
}

int _scanMarkdownCodeSpan(String code, int start) {
  final markerEnd = _scanRepeated(code, start, _backtickCodeUnit);
  final marker = code.substring(start, markerEnd);
  final close = code.indexOf(marker, markerEnd);
  return close < 0 ? markerEnd : close + marker.length;
}

int _scanMarkdownEmphasisMarker(String code, int start) {
  final char = code.codeUnitAt(start);
  var index = start;
  while (index < code.length &&
      code.codeUnitAt(index) == char &&
      index - start < 3) {
    index += 1;
  }
  return index;
}

int _markdownListMarkerEnd(String code, int start, int lineEnd) {
  if (start >= lineEnd) {
    return start;
  }
  final char = code.codeUnitAt(start);
  if ((char == _dashCodeUnit ||
          char == _plusCodeUnit ||
          char == _asteriskCodeUnit) &&
      start + 1 < lineEnd &&
      _isWhitespace(code.codeUnitAt(start + 1))) {
    return start + 1;
  }
  if (!_isDigit(char)) {
    return start;
  }
  var index = start + 1;
  while (index < lineEnd && _isDigit(code.codeUnitAt(index))) {
    index += 1;
  }
  if (index < lineEnd &&
      (code.codeUnitAt(index) == _dotCodeUnit ||
          code.codeUnitAt(index) == _rightParenCodeUnit) &&
      index + 1 < lineEnd &&
      _isWhitespace(code.codeUnitAt(index + 1))) {
    return index + 1;
  }
  return start;
}

int _scanRepeated(String code, int start, int char) {
  var index = start;
  while (index < code.length && code.codeUnitAt(index) == char) {
    index += 1;
  }
  return index;
}

int _lineEnd(String code, int start) {
  final newline = code.indexOf('\n', start);
  return newline < 0 ? code.length : newline;
}

bool _startsWithAt(String code, int index, String pattern) {
  return index + pattern.length <= code.length &&
      code.substring(index, index + pattern.length) == pattern;
}

bool _hasIdentifierBefore(String code, int index) {
  return index > 0 && _isIdentifierPart(code.codeUnitAt(index - 1));
}

bool _looksLikeTypeName(String text) {
  if (text.isEmpty || text.length == 1) {
    return false;
  }
  final first = text.codeUnitAt(0);
  return first >= _upperACodeUnit && first <= _upperZCodeUnit;
}

bool _isIdentifierStart(int char) {
  return (char >= _lowerACodeUnit && char <= _lowerZCodeUnit) ||
      (char >= _upperACodeUnit && char <= _upperZCodeUnit) ||
      char == _underscoreCodeUnit ||
      char == _dollarCodeUnit;
}

bool _isIdentifierPart(int char) {
  return _isIdentifierStart(char) || _isDigit(char);
}

bool _isDigit(int char) => char >= _zeroCodeUnit && char <= _nineCodeUnit;

bool _isDigitOrSeparator(int char) {
  return _isDigit(char) || char == _underscoreCodeUnit;
}

bool _isHexDigitOrSeparator(int char) {
  return _isDigitOrSeparator(char) ||
      (char >= _lowerACodeUnit && char <= _lowerFCodeUnit) ||
      (char >= _upperACodeUnit && char <= _upperFCodeUnit);
}

bool _isQuote(int char) {
  return char == _singleQuoteCodeUnit || char == _doubleQuoteCodeUnit;
}

bool _isNewline(int char) {
  return char == _lineFeedCodeUnit || char == _carriageReturnCodeUnit;
}

bool _isWhitespace(int char) {
  return char == _spaceCodeUnit || char == _tabCodeUnit;
}

bool _isMarkdownEmphasis(int char) {
  return char == _asteriskCodeUnit || char == _underscoreCodeUnit;
}

const Set<String> _dartKeywords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

const Set<String> _dartTypes = <String>{
  'BigInt',
  'bool',
  'DateTime',
  'double',
  'Duration',
  'dynamic',
  'Future',
  'int',
  'Iterable',
  'List',
  'Map',
  'Never',
  'num',
  'Object',
  'Pattern',
  'Record',
  'RegExp',
  'Set',
  'Stream',
  'String',
  'Symbol',
};

const Set<String> _javascriptKeywords = <String>{
  'as',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'debugger',
  'default',
  'delete',
  'do',
  'else',
  'export',
  'extends',
  'false',
  'finally',
  'for',
  'from',
  'function',
  'get',
  'if',
  'import',
  'in',
  'instanceof',
  'let',
  'new',
  'null',
  'of',
  'return',
  'set',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'typeof',
  'undefined',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

const Set<String> _javascriptTypes = <String>{
  'Array',
  'BigInt',
  'Boolean',
  'Date',
  'Error',
  'Map',
  'Number',
  'Object',
  'Promise',
  'Record',
  'RegExp',
  'Set',
  'String',
  'Symbol',
  'WeakMap',
  'WeakSet',
};

const Set<String> _typescriptKeywords = <String>{
  ..._javascriptKeywords,
  'abstract',
  'declare',
  'enum',
  'implements',
  'interface',
  'keyof',
  'namespace',
  'private',
  'protected',
  'public',
  'readonly',
  'type',
};

const Set<String> _typescriptTypes = <String>{
  ..._javascriptTypes,
  'any',
  'boolean',
  'never',
  'number',
  'string',
  'unknown',
};

const Set<String> _jsonKeywords = <String>{'true', 'false', 'null'};

const int _lineFeedCodeUnit = 0x0A;
const int _carriageReturnCodeUnit = 0x0D;
const int _tabCodeUnit = 0x09;
const int _spaceCodeUnit = 0x20;
const int _doubleQuoteCodeUnit = 0x22;
const int _hashCodeUnit = 0x23;
const int _dollarCodeUnit = 0x24;
const int _singleQuoteCodeUnit = 0x27;
const int _rightParenCodeUnit = 0x29;
const int _asteriskCodeUnit = 0x2A;
const int _plusCodeUnit = 0x2B;
const int _dashCodeUnit = 0x2D;
const int _dotCodeUnit = 0x2E;
const int _zeroCodeUnit = 0x30;
const int _nineCodeUnit = 0x39;
const int _greaterThanCodeUnit = 0x3E;
const int _upperACodeUnit = 0x41;
const int _upperECodeUnit = 0x45;
const int _upperFCodeUnit = 0x46;
const int _upperXCodeUnit = 0x58;
const int _upperZCodeUnit = 0x5A;
const int _leftBracketCodeUnit = 0x5B;
const int _backslashCodeUnit = 0x5C;
const int _underscoreCodeUnit = 0x5F;
const int _backtickCodeUnit = 0x60;
const int _lowerACodeUnit = 0x61;
const int _eCodeUnit = 0x65;
const int _lowerFCodeUnit = 0x66;
const int _rCodeUnit = 0x72;
const int _xCodeUnit = 0x78;
const int _lowerZCodeUnit = 0x7A;
