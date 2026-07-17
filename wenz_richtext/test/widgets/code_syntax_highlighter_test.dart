import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/widgets/code_syntax_highlighter.dart';

// Sentinel base color so unclassified text (punctuation, whitespace, plain
// fallback) is distinguishable from every palette category in assertions.
const Color _baseColor = Color(0xFFAABBCC);

const Color _keywordColor = Color(0xFFFF0000);
const Color _typeColor = Color(0xFF00AA00);
const Color _stringColor = Color(0xFF0000FF);
const Color _commentColor = Color(0xFFFF00FF);
const Color _numberColor = Color(0xFF00AAAA);
const Color _markerColor = Color(0xFFFF8800);

const CodeSyntaxPalette _palette = CodeSyntaxPalette(
  keyword: _keywordColor,
  type: _typeColor,
  string: _stringColor,
  comment: _commentColor,
  number: _numberColor,
  marker: _markerColor,
);

const TextStyle _baseStyle = TextStyle(
  color: _baseColor,
  fontFamily: 'RobotoMono',
  fontSize: 13.5,
  height: 1.6,
);

class _LangCase {
  const _LangCase(this.language, this.code, this.expectedColors);

  final String language;
  final String code;
  // A List (not a Set) so the const initializer can hold `Color`, which
  // overrides == / hashCode and therefore may not live in a const Set.
  final List<Color> expectedColors;
}

// Every entry of `_kDefaultCodeLanguages` (dart/javascript/typescript/python/
// java/kotlin/swift/go/rust/sql/json/yaml/html/css/markdown/bash) plus the
// acceptance-required new languages. Each sample is expected to carry at least
// the listed palette categories — proving the highlighter produces genuine
// category coloring rather than a single base-color span.
const List<_LangCase> _langCases = <_LangCase>[
  _LangCase(
    'dart',
    'final value = 42; // done\nString name = "Ada";',
    <Color>[
      _keywordColor,
      _typeColor,
      _numberColor,
      _stringColor,
      _commentColor,
    ],
  ),
  _LangCase('javascript', 'const answer = 42; // ok',
      <Color>[_keywordColor, _numberColor, _commentColor]),
  _LangCase('typescript', 'const count: number = 7; // total',
      <Color>[_keywordColor, _numberColor, _commentColor]),
  _LangCase('python', 'def add(a, b):\n    return "sum"',
      <Color>[_keywordColor, _stringColor]),
  _LangCase('java', 'public class App {\n    int count = 5;\n}',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('kotlin', 'fun main() {\n    println("hi")\n}',
      <Color>[_keywordColor, _stringColor]),
  _LangCase('swift', 'let total = 7\nprint(total)',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('go', 'package main\nfunc add(x int) int {\n    return x + 1\n}',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('rust', 'fn main() {\n    let x = 7;\n}',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('sql', 'SELECT id FROM users WHERE id = 3',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('json', '{"ok": true, "n": 3}',
      <Color>[_keywordColor, _numberColor]),
  _LangCase('yaml', 'name: app\nport: 8080',
      <Color>[_typeColor, _numberColor]),
  _LangCase('html', '<div class="box">Hi</div>',
      <Color>[_stringColor, _markerColor]),
  _LangCase('css', '.btn { margin: 8px; }',
      <Color>[_typeColor, _numberColor]),
  _LangCase('markdown', '# Title\n- item with `code`',
      <Color>[_keywordColor, _stringColor]),
  _LangCase('bash', 'echo "hello"\n# a comment',
      <Color>[_stringColor, _commentColor]),
];

void main() {
  for (final c in _langCases) {
    test(
      'highlights ${c.language} with category colors (not a single base span)',
      () {
        final span = _highlight(c.language, c.code);
        expect(span.toPlainText(), c.code);
        final colors = _colors(span, _baseColor);
        expect(
          colors,
          containsAll(c.expectedColors),
          reason: '${c.language}: expected ${c.expectedColors}, got $colors',
        );
        expect(
          colors.length,
          greaterThanOrEqualTo(2),
          reason: '${c.language}: should carry more than one category color',
        );
      },
    );
  }

  test('dart carves keyword/type/number/string/comment leaves', () {
    const code = 'final value = 42; // done\nString name = "Ada";';
    final span = _highlight('dart', code);
    expect(_leaf(span, 'final')?.style?.color, _keywordColor);
    expect(_leaf(span, 'String')?.style?.color, _typeColor);
    expect(_leaf(span, '42')?.style?.color, _numberColor);
    expect(_leaf(span, '"Ada"')?.style?.color, _stringColor);
    expect(_leaf(span, '// done')?.style?.color, _commentColor);
  });

  test('bash carves echo built-in, string and comment leaves', () {
    const code = 'echo "hello"\n# a comment';
    final span = _highlight('bash', code);
    expect(_leaf(span, 'echo')?.style?.color, _typeColor);
    expect(_leaf(span, '"hello"')?.style?.color, _stringColor);
    expect(_leaf(span, '# a comment')?.style?.color, _commentColor);
  });

  test('html carves tag marker, attribute type and string leaves', () {
    const code = '<div class="box">Hi</div>';
    final span = _highlight('html', code);
    expect(_leaf(span, 'div')?.style?.color, _markerColor);
    expect(_leaf(span, 'class')?.style?.color, _typeColor);
    expect(_leaf(span, '"box"')?.style?.color, _stringColor);
  });

  test(
    'unknown/unregistered language falls back to a plain span without throwing',
    () {
      const code = 'final value = 42;';
      // A clearly unregistered id resolves to plaintext parsing, which yields
      // no categorized tokens — so the highlighter returns one plain span.
      final span = _highlight('klingon', code);
      expect(span.toPlainText(), code);
      expect(span.style?.color, _baseColor);
      expect(span.children, isNull);
      expect(_colors(span, _baseColor), isEmpty);
    },
  );

  test('empty code returns a plain span without throwing', () {
    final span = _highlight('dart', '');
    expect(span.toPlainText(), '');
    expect(span.children, isNull);
  });

  test('composition range underlines the active segment across languages', () {
    // Python: the composition window covers the function-name leaf, so it is
    // recolored to its category AND underlined.
    const python = 'def greet(name):';
    final pythonSpan = _highlight('python', python, compStart: 4, compEnd: 9);
    expect(_underlinedText(pythonSpan), 'greet');
    expect(_colors(pythonSpan, _baseColor), contains(_typeColor));

    // Bash: the composition window covers an unscoped argument, which stays in
    // the base style but still receives the IME underline.
    const bash = 'echo hello';
    final bashSpan = _highlight('bash', bash, compStart: 5, compEnd: 10);
    expect(_underlinedText(bashSpan), 'hello');
  });

  test('no composition range yields no underline', () {
    const python = 'def greet(name):';
    final span = _highlight('python', python);
    expect(_underlinedText(span), '');
  });
}

TextSpan _highlight(
  String language,
  String code, {
  int? compStart,
  int? compEnd,
}) {
  return CodeSyntaxHighlighter(
    language: language,
    baseStyle: _baseStyle,
    palette: _palette,
    compositionStart: compStart,
    compositionEnd: compEnd,
  ).highlight(code);
}

/// Distinct colors carried by leaf [TextSpan]s, excluding [base] (the
/// unclassified-text color) so plain fallback spans produce an empty set.
Set<Color> _colors(TextSpan span, Color base) {
  final colors = <Color>{};
  void visit(InlineSpan s) {
    if (s is TextSpan) {
      final children = s.children;
      final color = s.style?.color;
      if (color != null && color != base) {
        colors.add(color);
      }
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  visit(span);
  return colors;
}

TextSpan? _leaf(TextSpan span, String text) {
  final children = span.children;
  if ((children == null || children.isEmpty) && span.text == text) {
    return span;
  }
  for (final child in children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final match = _leaf(child, text);
      if (match != null) {
        return match;
      }
    }
  }
  return null;
}

/// Concatenated text of every leaf span carrying an underline decoration —
/// i.e. the IME composition window content.
String _underlinedText(TextSpan span) {
  final buffer = StringBuffer();
  void visit(InlineSpan s) {
    if (s is TextSpan) {
      final children = s.children;
      final decoration = s.style?.decoration;
      final text = s.text;
      if (decoration != null &&
          decoration.contains(TextDecoration.underline) &&
          text != null &&
          text.isNotEmpty) {
        buffer.write(text);
      }
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  visit(span);
  return buffer.toString();
}
