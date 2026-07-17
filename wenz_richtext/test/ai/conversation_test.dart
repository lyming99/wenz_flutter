import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  // =========================================================================
  // ChatMessage
  // =========================================================================

  group('ChatMessage', () {
    test('toJson / fromJson round-trip', () {
      final original = ChatMessage(
        id: 'msg-1',
        role: MessageRole.user,
        content: 'Hello, world!',
        timestamp: DateTime(2025, 6, 1, 12, 0, 0),
        tokenCount: 5,
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, 'msg-1');
      expect(restored.role, MessageRole.user);
      expect(restored.content, 'Hello, world!');
      expect(restored.tokenCount, 5);
      expect(restored.error, isNull);
    });

    test('toJson / fromJson with error', () {
      final original = ChatMessage(
        id: 'msg-err',
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime(2025, 6, 1),
        error: 'Connection timed out',
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.error, 'Connection timed out');
      expect(restored.role, MessageRole.assistant);
    });

    test('fromJson with missing fields uses defaults', () {
      final restored = ChatMessage.fromJson(const <String, Object?>{});
      expect(restored.id, '');
      expect(restored.role, MessageRole.user); // fallback
      expect(restored.content, '');
    });

    test('copyWith preserves unchanged fields', () {
      final original = ChatMessage(
        id: 'm1',
        role: MessageRole.user,
        content: 'Hi',
        timestamp: DateTime(2025),
      );

      final copy = original.copyWith(content: 'Updated');
      expect(copy.content, 'Updated');
      expect(copy.id, 'm1');
      expect(copy.role, MessageRole.user);
    });

    test('copyWith clearError', () {
      final original = ChatMessage(
        id: 'm1',
        role: MessageRole.assistant,
        content: 'err',
        timestamp: DateTime(2025),
        error: 'some error',
      );

      final cleared = original.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('equality', () {
      final a = ChatMessage(
        id: 'm1',
        role: MessageRole.user,
        content: 'Hi',
        timestamp: DateTime(2025),
      );
      final b = ChatMessage(
        id: 'm1',
        role: MessageRole.user,
        content: 'Hi',
        timestamp: DateTime(2025),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      final c = a.copyWith(content: 'Bye');
      expect(a, isNot(c));
    });
  });

  // =========================================================================
  // Conversation
  // =========================================================================

  group('Conversation', () {
    test('toJson / fromJson round-trip', () {
      final original = Conversation(
        id: 'conv-1',
        title: 'Test Chat',
        aiConfigId: 'cfg-1',
        messages: [
          ChatMessage(
            id: 'm1',
            role: MessageRole.user,
            content: 'Hi',
            timestamp: DateTime(2025, 6, 1, 12, 0),
          ),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            content: 'Hello!',
            timestamp: DateTime(2025, 6, 1, 12, 1),
            tokenCount: 3,
          ),
        ],
        createdAt: DateTime(2025, 6, 1),
        updatedAt: DateTime(2025, 6, 1, 12, 1),
        systemPrompt: 'You are helpful.',
      );

      final json = original.toJson();
      final restored = Conversation.fromJson(json);

      expect(restored.id, 'conv-1');
      expect(restored.title, 'Test Chat');
      expect(restored.aiConfigId, 'cfg-1');
      expect(restored.messages.length, 2);
      expect(restored.messages[0].content, 'Hi');
      expect(restored.messages[1].content, 'Hello!');
      expect(restored.systemPrompt, 'You are helpful.');
    });

    test('status is NOT persisted — always resets to idle on load', () {
      final withStatus = Conversation(
        id: 'conv-1',
        title: 'Test',
        aiConfigId: 'cfg-1',
        status: ConversationStatus.thinking,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      // Serialize — status should be absent.
      final json = withStatus.toJson();
      expect(json.containsKey('status'), isFalse);

      // Deserialize — status resets to idle (the default).
      final restored = Conversation.fromJson(json);
      expect(restored.status, ConversationStatus.idle);
    });

    test('status is not in toJson output', () {
      final conv = Conversation(
        id: 'c1',
        title: 'T',
        aiConfigId: 'cfg-1',
        status: ConversationStatus.replying,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final json = conv.toJson();
      expect(json.containsKey('status'), isFalse);
    });

    test('copyWith returns new instance, original unchanged', () {
      final original = Conversation(
        id: 'conv-1',
        title: 'Original',
        aiConfigId: 'cfg-1',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      final copy = original.copyWith(title: 'Copy');
      expect(identical(original, copy), isFalse);
      expect(original.title, 'Original');
      expect(copy.title, 'Copy');
    });

    test('copyWith updates status', () {
      final original = Conversation(
        id: 'conv-1',
        title: 'Test',
        aiConfigId: 'cfg-1',
        status: ConversationStatus.idle,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

      final thinking = original.copyWith(status: ConversationStatus.thinking);
      expect(original.status, ConversationStatus.idle);
      expect(thinking.status, ConversationStatus.thinking);
    });

    test('fromJson with no messages produces empty list', () {
      final restored = Conversation.fromJson(const <String, Object?>{
        'id': 'c1',
        'title': 'T',
        'aiConfigId': 'cfg-1',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
      });
      expect(restored.messages, isEmpty);
    });

    test('equality', () {
      final a = Conversation(
        id: 'conv-1',
        title: 'Chat',
        aiConfigId: 'cfg-1',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final b = Conversation(
        id: 'conv-1',
        title: 'Chat',
        aiConfigId: 'cfg-1',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(a, b);

      final c = a.copyWith(title: 'Different');
      expect(a, isNot(c));
    });
  });

  // =========================================================================
  // ConversationManager CRUD
  // =========================================================================

  group('ConversationManager', () {
    testWidgets('initialize loads persisted conversations', (_) async {
      final appDir = await getApplicationDocumentsDirectory();

      // Seed configs first.
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      // Pre-seed conversations file.
      await File('${appDir.path}/wenz_ai_conversations.json').writeAsString('['
          '{"id":"conv-1","title":"Chat 1","aiConfigId":"cfg-1","messages":[],'
          '"createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000"},'
          '{"id":"conv-2","title":"Chat 2","aiConfigId":"cfg-1","messages":[],'
          '"createdAt":"2025-02-01T00:00:00.000","updatedAt":"2025-06-02T00:00:00.000"}'
          ']');

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);

      expect(convMgr.conversations.length, 2);
      // Sorted by updatedAt descending → Chat 2 first.
      expect(convMgr.conversations.first.title, 'Chat 2');
    });

    testWidgets('createConversation persists and returns new instance',
        (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);

      final conv = await convMgr.createConversation(
        title: 'New Chat',
        aiConfigId: 'cfg-1',
        systemPrompt: 'Be concise.',
      );

      expect(conv.title, 'New Chat');
      expect(conv.aiConfigId, 'cfg-1');
      expect(conv.systemPrompt, 'Be concise.');
      expect(conv.id.isNotEmpty, isTrue);
      expect(conv.messages, isEmpty);
      expect(convMgr.conversations.length, 1);
      expect(convMgr.getConversation(conv.id), isNotNull);

      // Verify file was written.
      final file = File('${appDir.path}/wenz_ai_conversations.json');
      expect(file.existsSync(), isTrue);
    });

    testWidgets('deleteConversation removes and persists', (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);
      final conv = await convMgr.createConversation(
        title: 'To Delete',
        aiConfigId: 'cfg-1',
      );

      expect(convMgr.conversations.length, 1);
      await convMgr.deleteConversation(conv.id);
      expect(convMgr.conversations.length, 0);
      expect(convMgr.getConversation(conv.id), isNull);
    });

    testWidgets('getConversation returns null for unknown id', (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);

      expect(convMgr.getConversation('nope'), isNull);
    });

    testWidgets('sendMessage throws StateError if not initialized', (_) async {
      final convMgr = ConversationManager();
      expect(
        () => convMgr.sendMessage('any', 'hi'),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('sendMessage throws StateError for unknown conversation',
        (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);

      expect(
        () => convMgr.sendMessage('nonexistent', 'hi'),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('conversations are sorted by updatedAt descending', (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);

      await convMgr.createConversation(title: 'First', aiConfigId: 'cfg-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await convMgr.createConversation(title: 'Second', aiConfigId: 'cfg-1');

      final list = convMgr.conversations;
      expect(list.first.title, 'Second');
      expect(list.last.title, 'First');
    });

    testWidgets('dispose clears conversations', (_) async {
      final appDir = await getApplicationDocumentsDirectory();
      await File('${appDir.path}/wenz_ai_configs.json').writeAsString('['
          '{"id":"cfg-1","name":"O","provider":"openai","apiKey":"azhzLWs=","model":"gpt-4o","createdAt":"2025-01-01T00:00:00.000","updatedAt":"2025-06-01T00:00:00.000","thinkingDepth":"medium"}'
          ']');

      final configMgr = AIConfigManager();
      await configMgr.initialize();

      final convMgr = ConversationManager();
      await convMgr.initialize(configMgr);
      await convMgr.createConversation(title: 'Test', aiConfigId: 'cfg-1');

      expect(convMgr.conversations.length, 1);
      convMgr.dispose();
      expect(convMgr.conversations.length, 0);
    });
  });
}
