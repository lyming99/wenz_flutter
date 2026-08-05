import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import 'mermaid_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all nine supported types retain minimum, CJK, and long-text rendering',
      () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);
    var request = 0;

    for (final fixture in supportedMermaidFixtures) {
      for (final source in <String>[
        fixture.minimum,
        fixture.cjk,
        fixture.longText,
      ]) {
        final outcome = await service.render(
          MermaidRenderRequest(
            source: source,
            sourceDigest: mermaidSourceDigest(source),
            theme: const MermaidRenderTheme(
              key: 'regression',
              style: MermaidStyle(),
            ),
            viewport: const Size(960, 540),
            limits: const MermaidRenderLimits(),
            requestId: 'regression-${request++}',
          ),
        );

        expect(outcome, isA<MermaidRenderResult>(), reason: fixture.name);
        final result = outcome as MermaidRenderResult;
        expect(result.diagramType, fixture.type);
        expect(result.contentSize.width.isFinite, isTrue);
        expect(result.contentSize.height.isFinite, isTrue);
      }
    }
  });

  test('each supported type retains an invalid-input fixture without crashing',
      () async {
    final service = DefaultNativeMermaidRenderService();
    addTearDown(service.dispose);

    for (final fixture in supportedMermaidFixtures) {
      final source = fixture.invalid;
      final outcome = await service.render(
        MermaidRenderRequest(
          source: source,
          sourceDigest: mermaidSourceDigest(source),
          theme: const MermaidRenderTheme(
            key: 'invalid',
            style: MermaidStyle(),
          ),
          viewport: const Size(960, 540),
          limits: const MermaidRenderLimits(),
          requestId: 'invalid-${fixture.name}',
        ),
      );

      expect(
        outcome,
        anyOf(isA<MermaidRenderFailure>(), isA<MermaidRenderResult>()),
        reason: fixture.name,
      );
    }
  });
}
