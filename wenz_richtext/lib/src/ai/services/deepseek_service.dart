import '../models/ai_config.dart';
import '../models/conversation.dart';
import 'ai_service.dart';

// ---------------------------------------------------------------------------
// DeepSeek service
// ---------------------------------------------------------------------------

/// [AIService] implementation for the DeepSeek API (OpenAI-compatible).
///
/// Sends raw HTTP requests with SSE streaming. Supports the DeepSeek-R1
/// `thinking` field via [DeepSeekConfig.thinkingMode].
class DeepSeekService extends AIService {
  @override
  String get providerName => 'DeepSeek';

  @override
  Stream<String> chatStream({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  }) {
    final deepseekConfig = config as DeepSeekConfig;

    final body = <String, dynamic>{
      'model': deepseekConfig.model,
      'stream': true,
      'messages': buildMessages(
        history: history,
        systemPrompt: systemPrompt,
      ),
      // Inject thinking field for DeepSeek-R1.
      'thinking': {
        'type': deepseekConfig.thinkingMode == DeepSeekThinkingMode.enabled
            ? 'enabled'
            : 'disabled',
      },
    };

    // Optional max_tokens.
    if (deepseekConfig.maxTokens != null) {
      body['max_tokens'] = deepseekConfig.maxTokens;
    }

    return chatStreamRequest(config: config, body: body);
  }

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  }) async {
    final deepseekConfig = config as DeepSeekConfig;

    final body = <String, dynamic>{
      'model': deepseekConfig.model,
      'messages': buildMessages(
        history: history,
        systemPrompt: systemPrompt,
      ),
      'thinking': {
        'type': deepseekConfig.thinkingMode == DeepSeekThinkingMode.enabled
            ? 'enabled'
            : 'disabled',
      },
    };

    if (deepseekConfig.maxTokens != null) {
      body['max_tokens'] = deepseekConfig.maxTokens;
    }

    return chatRequest(config: config, body: body);
  }

  @override
  Future<void> validateConfig(AIConfig config) async {
    try {
      await chat(history: const [], config: config);
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException('DeepSeek validation failed', cause: e);
    }
  }
}
