import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  // =========================================================================
  // AIServiceFactory
  // =========================================================================

  group('AIServiceFactory', () {
    test('create(openai) returns OpenAIService', () {
      final service = AIServiceFactory.create(AIProvider.openai);
      expect(service.providerName, 'OpenAI');
    });

    test('create(deepseek) returns DeepSeekService', () {
      final service = AIServiceFactory.create(AIProvider.deepseek);
      expect(service.providerName, 'DeepSeek');
    });
  });

  // =========================================================================
  // AIService — providerName
  // =========================================================================

  group('AIService.providerName', () {
    test('OpenAIService reports OpenAI', () {
      final service = AIServiceFactory.create(AIProvider.openai);
      expect(service.providerName, 'OpenAI');
    });

    test('DeepSeekService reports DeepSeek', () {
      final service = AIServiceFactory.create(AIProvider.deepseek);
      expect(service.providerName, 'DeepSeek');
    });
  });

  // =========================================================================
  // AIServiceException
  // =========================================================================

  group('AIServiceException', () {
    test('toString includes message', () {
      const ex = AIServiceException('Invalid API key');
      expect(ex.toString(), contains('Invalid API key'));
      expect(ex.toString(), contains('AIServiceException'));
    });

    test('toString includes cause when provided', () {
      const cause = FormatException('bad json');
      const ex = AIServiceException('Parse failed', cause: cause);
      expect(ex.toString(), contains('Parse failed'));
      expect(ex.toString(), contains('bad json'));
    });

    test('toString works without cause', () {
      const ex = AIServiceException('Network error');
      expect(ex.toString(), 'AIServiceException: Network error');
    });
  });

  // =========================================================================
  // AIService — validateConfig error handling
  // =========================================================================

  group('AIService.validateConfig', () {
    test(
      'throws AIServiceException for invalid OpenAI config',
      () async {
        final service = AIServiceFactory.create(AIProvider.openai);
        final config = OpenAIConfig(
          id: 'c1',
          name: 'Invalid',
          // Clearly invalid API key — should trigger a 401 quickly.
          apiKey: 'sk-invalid-key-that-does-not-exist',
          model: 'gpt-4o',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // The real HTTP call should fail rapidly with an auth error.
        // Use a generous timeout to avoid flakiness on slow networks.
        await expectLater(
          service.validateConfig(config).timeout(
            const Duration(seconds: 10),
          ),
          throwsA(isA<AIServiceException>()),
        );
      },
      // This test makes a real HTTP call — skip in CI without network.
      skip: false,
    );

    test(
      'throws AIServiceException for invalid DeepSeek config',
      () async {
        final service = AIServiceFactory.create(AIProvider.deepseek);
        final config = DeepSeekConfig(
          id: 'c1',
          name: 'Invalid',
          apiKey: 'sk-invalid-deepseek-key',
          model: 'deepseek-chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await expectLater(
          service.validateConfig(config).timeout(
            const Duration(seconds: 10),
          ),
          throwsA(isA<AIServiceException>()),
        );
      },
      skip: false,
    );
  });
}
