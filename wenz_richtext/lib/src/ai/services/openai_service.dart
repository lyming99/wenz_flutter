import '../models/ai_config.dart';
import '../models/conversation.dart';
import 'ai_service.dart';

// ---------------------------------------------------------------------------
// OpenAI service
// ---------------------------------------------------------------------------

/// [AIService] implementation for the OpenAI API.
///
/// Sends raw HTTP requests with SSE streaming. Supports `reasoning_effort`
/// via [OpenAIConfig.thinkingDepth].
class OpenAIService extends AIService {
  @override
  String get providerName => 'OpenAI';

  @override
  Stream<String> chatStream({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  }) {
    final openaiConfig = config as OpenAIConfig;

    final body = <String, dynamic>{
      'model': openaiConfig.model,
      'stream': true,
      'messages': buildMessages(
        history: history,
        systemPrompt: systemPrompt,
      ),
      // Inject reasoning_effort for o-series models.
      'reasoning_effort': openaiConfig.thinkingDepth.name,
    };

    return chatStreamRequest(config: config, body: body);
  }

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  }) async {
    final openaiConfig = config as OpenAIConfig;

    final body = <String, dynamic>{
      'model': openaiConfig.model,
      'messages': buildMessages(
        history: history,
        systemPrompt: systemPrompt,
      ),
      'reasoning_effort': openaiConfig.thinkingDepth.name,
    };

    return chatRequest(config: config, body: body);
  }

  @override
  Future<void> validateConfig(AIConfig config) async {
    try {
      await chat(history: const [], config: config);
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException('OpenAI validation failed', cause: e);
    }
  }
}
