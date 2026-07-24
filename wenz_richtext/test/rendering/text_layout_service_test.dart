import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/rendering/text_layout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextLayoutService precise em dash geometry', () {
    for (final text in const <String>[
      '—',
      '中文—结尾',
      '中文——English—结尾',
    ]) {
      test('round-trips every UTF-16 boundary in "$text"', () {
        final fixture = _layout(
          TextSpan(text: text, style: const TextStyle(fontSize: 20)),
          maxWidth: 1000,
        );

        _expectEveryBoundaryRoundTrips(fixture, text.length);
      });
    }

    test('round-trips boundaries across finite-width visual lines', () {
      const text = '中文——English—结尾—再见';
      final fixture = _layout(
        const TextSpan(text: text, style: TextStyle(fontSize: 20)),
        maxWidth: 88,
      );

      expect(fixture.painter.computeLineMetrics().length, greaterThan(1));
      _expectEveryBoundaryRoundTrips(fixture, text.length);
    });

    test('round-trips boundaries with mixed inline font sizes', () {
      const text = '中文——English—结尾';
      final fixture = _layout(
        const TextSpan(
          style: TextStyle(fontSize: 16),
          children: <InlineSpan>[
            TextSpan(text: '中文', style: TextStyle(fontSize: 13)),
            TextSpan(text: '——', style: TextStyle(fontSize: 30)),
            TextSpan(text: 'English', style: TextStyle(fontSize: 18)),
            TextSpan(text: '—', style: TextStyle(fontSize: 24)),
            TextSpan(text: '结尾', style: TextStyle(fontSize: 15)),
          ],
        ),
        maxWidth: 112,
      );

      expect(fixture.painter.computeLineMetrics().length, greaterThan(1));
      _expectEveryBoundaryRoundTrips(fixture, text.length);

      for (var offset = 2; offset <= 4; offset++) {
        final caret = fixture.service.caretOffset(fixture.painter, offset);
        expect(caret.dx.isFinite, isTrue);
        expect(caret.dy.isFinite, isTrue);
        expect(
          fixture.service.caretHeight(fixture.painter, offset),
          greaterThan(0),
        );
      }
    });

    test('locale is part of the cached layout geometry', () {
      final service = TextLayoutService();
      const span = TextSpan(
        text: '中文—English—结尾',
        style: TextStyle(fontSize: 20),
      );
      final zh = service.layout(
        span: span,
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        locale: const Locale('zh', 'CN'),
        maxWidth: 180,
      );
      final cachedZh = service.layout(
        span: span,
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        locale: const Locale('zh', 'CN'),
        maxWidth: 180,
      );
      final en = service.layout(
        span: span,
        textAlign: TextAlign.start,
        textDirection: TextDirection.ltr,
        locale: const Locale('en', 'US'),
        maxWidth: 180,
      );

      expect(identical(zh, cachedZh), isTrue);
      expect(identical(zh, en), isFalse);
      _expectEveryBoundaryRoundTrips(
        _LayoutFixture(service: service, painter: en),
        span.toPlainText().length,
      );
    });
  });
}

_LayoutFixture _layout(InlineSpan span, {required double maxWidth}) {
  final service = TextLayoutService();
  final painter = service.layout(
    span: span,
    textAlign: TextAlign.start,
    textDirection: TextDirection.ltr,
    locale: const Locale('zh', 'CN'),
    maxWidth: maxWidth,
  );
  return _LayoutFixture(service: service, painter: painter);
}

void _expectEveryBoundaryRoundTrips(_LayoutFixture fixture, int textLength) {
  for (var offset = 0; offset <= textLength; offset++) {
    final caret = fixture.service.caretOffset(fixture.painter, offset);
    final caretHeight = fixture.service.caretHeight(fixture.painter, offset);
    expect(caretHeight, isNotNull, reason: 'missing caret at offset $offset');

    final hitOffset = fixture.service.offsetAt(
      fixture.painter,
      caret + Offset(0, caretHeight! / 2),
      textLength,
    );
    expect(
      hitOffset,
      offset,
      reason: 'caret hit-test must round-trip UTF-16 offset $offset',
    );
  }
}

class _LayoutFixture {
  const _LayoutFixture({required this.service, required this.painter});

  final TextLayoutService service;
  final TextPainter painter;
}
