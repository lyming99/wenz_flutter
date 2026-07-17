import 'package:flutter/material.dart';
import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/scala.dart';
import 'package:highlight/languages/shell.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

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
    final tokens = _tokensForCode(code, language);
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

/// Selectively registered `highlight` instance (controls bundle size by only
/// pulling in the languages we actually need, rather than `allLanguages`).
///
/// The set covers every entry of `_kDefaultCodeLanguages` (dart, javascript,
/// typescript, python, java, kotlin, swift, go, rust, sql, json, yaml, html,
/// css, markdown, bash) plus commonly requested languages. highlight.js
/// aliases registered alongside each mode — e.g. `html`/`xhtml` → `xml`,
/// `toml` → `ini`, `c` → `cpp`, `csharp`/`c#` → `cs`, `sh` → `bash`, `md` →
/// `markdown` — are resolved automatically by [Highlight.parse].
final Highlight _highlighter = Highlight()
  ..registerLanguages({
    'plaintext': plaintext,
    'dart': dart,
    'javascript': javascript,
    'typescript': typescript,
    'python': python,
    'java': java,
    'kotlin': kotlin,
    'swift': swift,
    'go': go,
    'rust': rust,
    'sql': sql,
    'json': json,
    'yaml': yaml,
    'xml': xml,
    'css': css,
    'markdown': markdown,
    'bash': bash,
    'shell': shell,
    'php': php,
    'ruby': ruby,
    'cpp': cpp,
    'cs': cs,
    'scala': scala,
    'ini': ini,
  });

/// Parses [code] with the `highlight` library and flattens the resulting
/// [Node] tree into the colored-token list consumed by [CodeSyntaxHighlighter].
///
/// Returns `null` when the language is unknown / unregistered, when parsing
/// yields no colored tokens, or on a parse error — in all those cases the
/// caller falls back to plain (uncolored) text, matching prior behaviour.
List<_CodeSyntaxToken>? _tokensForCode(String code, String language) {
  if (code.isEmpty) {
    return null;
  }
  final normalized = _normalizeLanguage(language);
  final List<Node> nodes;
  try {
    final result = _highlighter.parse(code, language: normalized);
    nodes = result.nodes ?? const <Node>[];
  } catch (_) {
    return null;
  }
  final tokens = _flattenNodes(nodes);
  return tokens.isEmpty ? null : tokens;
}

/// Walks the highlight.js [Node] tree in document order, accumulating the
/// absolute character offset of each leaf text segment. Only leaves that map
/// to a palette category are emitted; unclassified text (punctuation,
/// operators, whitespace) is intentionally omitted so [CodeSyntaxHighlighter]
/// fills those gaps with `baseStyle`, exactly as the legacy scanner did.
List<_CodeSyntaxToken> _flattenNodes(List<Node> nodes) {
  final tokens = <_CodeSyntaxToken>[];
  var offset = 0;

  void visit(Node node, _CodeSyntaxTokenKind? inheritedKind) {
    final kind = _kindForScope(node.className) ?? inheritedKind;
    final value = node.value;
    if (value != null && value.isNotEmpty) {
      final start = offset;
      offset += value.length;
      if (kind != null) {
        tokens.add(_CodeSyntaxToken(start, offset, kind));
      }
      return;
    }
    final children = node.children;
    if (children != null) {
      for (final child in children) {
        visit(child, kind);
      }
    }
  }

  for (final node in nodes) {
    visit(node, null);
  }
  return tokens;
}

/// Maps a highlight.js scope (`Node.className`, space separated when compound)
/// onto a palette category. A scope may carry several words (e.g.
/// `"title function"`); the first word with an explicit mapping wins.
_CodeSyntaxTokenKind? _kindForScope(String? className) {
  if (className == null || className.isEmpty) {
    return null;
  }
  final parts = className.split(' ');
  for (final part in parts) {
    final mapped = _scopeKinds[part];
    if (mapped != null) {
      return mapped;
    }
  }
  for (final part in parts) {
    if (_markerScopes.contains(part)) {
      return _CodeSyntaxTokenKind.marker;
    }
  }
  return null;
}

/// Normalizes a user- or selector-facing language string into a canonical id
/// registered with the [_highlighter] instance.
///
/// The input is lower-cased, trimmed, and stripped of any *leading or
/// trailing* dots (so `"Python"`, `".py"` and `"ts."` all resolve). Common
/// aliases and dialects are mapped to their canonical registered id — this
/// both documents the supported surface and takes the direct
/// `_languages[id]` lookup path instead of relying on highlight.js alias
/// resolution. Every entry of `_kDefaultCodeLanguages` resolves through here
/// to a registered language; anything unrecognized passes through unchanged
/// and is left to degrade to plain text by [_tokensForCode].
String _normalizeLanguage(String language) {
  var normalized = language.trim().toLowerCase();
  while (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return switch (normalized) {
    // Markdown dialects / extensions → registered `markdown`.
    'md' || 'mdown' || 'mkdown' || 'mkd' || 'gfm' => 'markdown',
    // Shell family → registered `bash`.
    'sh' || 'zsh' => 'bash',
    // JavaScript family → registered `javascript`.
    'js' || 'jsx' || 'mjs' || 'cjs' => 'javascript',
    // TypeScript family → registered `typescript`.
    'ts' || 'tsx' => 'typescript',
    // C# → registered `cs`.
    'c#' || 'csharp' => 'cs',
    // C / C++ → registered `cpp`.
    'c' || 'cc' || 'cxx' || 'c++' || 'hpp' || 'hh' || 'hxx' || 'h++' => 'cpp',
    // Markup dialects → registered `xml`.
    'html' || 'xhtml' || 'htm' || 'rss' || 'atom' || 'plist' => 'xml',
    // TOML → registered `ini`.
    'toml' => 'ini',
    // Python aliases → registered `python`.
    'py' || 'gyp' || 'ipython' => 'python',
    // Go alias → registered `go`.
    'golang' => 'go',
    // Rust alias → registered `rust`.
    'rs' => 'rust',
    // Ruby aliases → registered `ruby`.
    'rb' || 'gemspec' || 'podspec' => 'ruby',
    // Kotlin alias → registered `kotlin`.
    'kt' || 'kts' => 'kotlin',
    // YAML alias → registered `yaml`.
    'yml' => 'yaml',
    _ => normalized,
  };
}

/// highlight.js scopes → palette category. Covers the core semantic scopes
/// across the registered languages (keywords/literals, types & callable names,
/// strings, comments, numbers).
const Map<String, _CodeSyntaxTokenKind> _scopeKinds =
    <String, _CodeSyntaxTokenKind>{
  'keyword': _CodeSyntaxTokenKind.keyword,
  'literal': _CodeSyntaxTokenKind.keyword,
  'built_in': _CodeSyntaxTokenKind.type,
  'type': _CodeSyntaxTokenKind.type,
  'class': _CodeSyntaxTokenKind.type,
  'title': _CodeSyntaxTokenKind.type,
  'function': _CodeSyntaxTokenKind.type,
  'attr': _CodeSyntaxTokenKind.type,
  'attribute': _CodeSyntaxTokenKind.type,
  'section': _CodeSyntaxTokenKind.type,
  'string': _CodeSyntaxTokenKind.string,
  'subst': _CodeSyntaxTokenKind.string,
  'addition': _CodeSyntaxTokenKind.string,
  'comment': _CodeSyntaxTokenKind.comment,
  'quote': _CodeSyntaxTokenKind.comment,
  'doctag': _CodeSyntaxTokenKind.comment,
  'number': _CodeSyntaxTokenKind.number,
  'symbol': _CodeSyntaxTokenKind.number,
};

/// Structural scopes with no dedicated palette slot — tag names, markup
/// markers, preprocessor lines, regexps — collapse onto the marker category.
const Set<String> _markerScopes = <String>{
  'tag',
  'name',
  'bullet',
  'link',
  'meta',
  'regexp',
  'selector',
};
