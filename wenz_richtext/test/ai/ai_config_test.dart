import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  // =========================================================================
  // AIConfig — base class
  // =========================================================================

  group('AIConfig', () {
    test('toJson / fromJson round-trip (OpenAI)', () {
      final original = OpenAIConfig(
        id: 'cfg-1',
        name: 'My OpenAI',
        apiKey: 'sk-test-key',
        model: 'gpt-4o',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 6, 1),
        thinkingDepth: ThinkingDepth.high,
        organizationId: 'org-123',
      );

      final json = original.toJson();
      final restored = AIConfig.fromJson(json);

      expect(restored, isA<OpenAIConfig>());
      final openai = restored as OpenAIConfig;
      expect(openai.id, 'cfg-1');
      expect(openai.name, 'My OpenAI');
      expect(openai.provider, AIProvider.openai);
      expect(openai.apiKey, 'sk-test-key');
      expect(openai.model, 'gpt-4o');
      expect(openai.thinkingDepth, ThinkingDepth.high);
      expect(openai.organizationId, 'org-123');
    });

    test('toJson / fromJson round-trip (DeepSeek)', () {
      final original = DeepSeekConfig(
        id: 'cfg-2',
        name: 'My DeepSeek',
        apiKey: 'sk-deepseek-key',
        baseUrl: 'https://api.deepseek.com/v1',
        model: 'deepseek-chat',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 6, 1),
        thinkingMode: DeepSeekThinkingMode.enabled,
        maxTokens: 4096,
      );

      final json = original.toJson();
      final restored = AIConfig.fromJson(json);

      expect(restored, isA<DeepSeekConfig>());
      final ds = restored as DeepSeekConfig;
      expect(ds.id, 'cfg-2');
      expect(ds.name, 'My DeepSeek');
      expect(ds.provider, AIProvider.deepseek);
      expect(ds.apiKey, 'sk-deepseek-key');
      expect(ds.baseUrl, 'https://api.deepseek.com/v1');
      expect(ds.model, 'deepseek-chat');
      expect(ds.thinkingMode, DeepSeekThinkingMode.enabled);
      expect(ds.maxTokens, 4096);
    });

    test('polymorphic fromJson reads provider discriminator', () {
      // OpenAI discriminator
      final openaiJson = <String, Object?>{
        'id': 'c1',
        'name': 'O',
        'provider': 'openai',
        'apiKey': 'k1',
        'model': 'gpt-4o',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
        'thinkingDepth': 'low',
      };
      expect(AIConfig.fromJson(openaiJson), isA<OpenAIConfig>());

      // DeepSeek discriminator
      final dsJson = <String, Object?>{
        'id': 'c2',
        'name': 'D',
        'provider': 'deepseek',
        'apiKey': 'k2',
        'model': 'deepseek-chat',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
        'thinkingMode': 'enabled',
      };
      expect(AIConfig.fromJson(dsJson), isA<DeepSeekConfig>());

      // Unknown provider falls back to OpenAI
      final unknownJson = <String, Object?>{
        'id': 'c3',
        'name': 'U',
        'provider': 'unknown',
        'apiKey': 'k3',
        'model': 'gpt-4o',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
      };
      expect(AIConfig.fromJson(unknownJson), isA<OpenAIConfig>());
    });

    test('defaults: OpenAIConfig.thinkingDepth == medium', () {
      final cfg = OpenAIConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(cfg.thinkingDepth, ThinkingDepth.medium);
    });

    test('defaults: DeepSeekConfig.thinkingMode == disabled', () {
      final cfg = DeepSeekConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        model: 'deepseek-chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(cfg.thinkingMode, DeepSeekThinkingMode.disabled);
    });

    test('defaults: DeepSeekConfig.fromJson baseUrl', () {
      final cfg = DeepSeekConfig.fromJson(const <String, Object?>{
        'id': 'c1',
        'name': 'Test',
        'provider': 'deepseek',
        'apiKey': 'k',
        'model': 'deepseek-chat',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
      });
      expect(cfg.baseUrl, 'https://api.deepseek.com/v1');
    });

    test('defaults: OpenAIConfig.fromJson model', () {
      final cfg = OpenAIConfig.fromJson(const <String, Object?>{
        'id': 'c1',
        'name': 'Test',
        'provider': 'openai',
        'apiKey': 'k',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
      });
      expect(cfg.model, 'gpt-4o');
    });

    test('copyWith preserves unchanged fields', () {
      final original = OpenAIConfig(
        id: 'c1',
        name: 'Original',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        thinkingDepth: ThinkingDepth.high,
      );

      final copy = original.copyWith(name: 'Renamed');
      expect(copy.name, 'Renamed');
      expect(copy.id, 'c1');
      expect(copy.apiKey, 'k');
      expect(copy.thinkingDepth, ThinkingDepth.high);
    });

    test('copyWith clearBaseUrl', () {
      final original = OpenAIConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        baseUrl: 'https://custom.example.com',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cleared = original.copyWith(clearBaseUrl: true);
      expect(cleared.baseUrl, isNull);
    });

    test('equality and hashCode', () {
      final a = OpenAIConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final b = OpenAIConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      final c = a.copyWith(name: 'Different');
      expect(a, isNot(c));
    });

    test('AIConfig and subclass are not equal', () {
      final base = AIConfig(
        id: 'c1',
        name: 'Test',
        provider: AIProvider.openai,
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final openai = OpenAIConfig(
        id: 'c1',
        name: 'Test',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      // Different runtimeType — not equal.
      expect(base, isNot(openai));
    });
  });

  // =========================================================================
  // AIConfigManager CRUD
  // =========================================================================

  group('AIConfigManager', () {
    testWidgets('initialize loads persisted configs', (_) async {
      // Pre-seed the config file.
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/wenz_ai_configs.json');
      await file.writeAsString('['
          '{"id":"c1","name":"O","provider":"openai","apiKey":"azhzLXRlc3Qta2V5","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"},'
          '{"id":"c2","name":"D","provider":"deepseek","apiKey":"azhzLWRzLWtleQ==","model":"deepseek-chat","baseUrl":"https://api.deepseek.com/v1","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingMode":"disabled"}'
          ']');

      final manager = AIConfigManager();
      await manager.initialize();

      expect(manager.configs.length, 2);

      final openai = manager.getConfig('c1');
      expect(openai, isA<OpenAIConfig>());
      // API key was base64-encoded in file → decoded on load.
      expect(openai!.apiKey, 'sk-test-key');

      final ds = manager.getConfig('c2');
      expect(ds, isA<DeepSeekConfig>());
      expect(ds!.apiKey, 'sk-ds-key');
    });

    testWidgets('addConfig persists and notifies', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();

      var notified = false;
      manager.addListener(() => notified = true);

      await manager.addConfig(OpenAIConfig(
        id: 'new-cfg',
        name: 'New',
        apiKey: 'sk-new',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(notified, isTrue);
      expect(manager.configs.length, 1);
      expect(manager.getConfig('new-cfg')!.name, 'New');

      // Verify file was written.
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/wenz_ai_configs.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('new-cfg'));
      // API key should be base64-encoded in the persisted file.
      expect(content, isNot(contains('sk-new')));
    });

    testWidgets('updateConfig modifies and persists', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();

      await manager.addConfig(OpenAIConfig(
        id: 'cfg-1',
        name: 'Original',
        apiKey: 'sk-key',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await manager.updateConfig(OpenAIConfig(
        id: 'cfg-1',
        name: 'Updated',
        apiKey: 'sk-key',
        model: 'gpt-4-turbo',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final updated = manager.getConfig('cfg-1')!;
      expect(updated.name, 'Updated');
      expect(updated.model, 'gpt-4-turbo');
    });

    testWidgets('updateConfig no-op for unknown id', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();

      await manager.updateConfig(OpenAIConfig(
        id: 'nonexistent',
        name: 'Ghost',
        apiKey: 'k',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      expect(manager.configs.length, 0);
    });

    testWidgets('deleteConfig removes and persists', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();

      await manager.addConfig(OpenAIConfig(
        id: 'cfg-1',
        name: 'To Delete',
        apiKey: 'sk-key',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(manager.configs.length, 1);

      await manager.deleteConfig('cfg-1');
      expect(manager.configs.length, 0);
      expect(manager.getConfig('cfg-1'), isNull);
    });

    testWidgets('getConfig returns null for unknown id', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();
      expect(manager.getConfig('nope'), isNull);
    });

    testWidgets('isInitialized is false before initialize', (_) async {
      final manager = AIConfigManager();
      expect(manager.isInitialized, isFalse);
      await manager.initialize();
      expect(manager.isInitialized, isTrue);
    });

    testWidgets('dispose clears configs', (_) async {
      final manager = AIConfigManager();
      await manager.initialize();
      await manager.addConfig(OpenAIConfig(
        id: 'cfg-1',
        name: 'Test',
        apiKey: 'sk-key',
        model: 'gpt-4o',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(manager.configs.length, 1);

      manager.dispose();
      expect(manager.configs.length, 0);
    });
  });
}
