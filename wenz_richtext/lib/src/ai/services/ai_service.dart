import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';
import '../models/conversation.dart';
import 'openai_service.dart';
import 'deepseek_service.dart';

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Wraps errors from AI service calls (network, auth, API errors, etc.).
class AIServiceException implements Exception {
  const AIServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'AIServiceException: $message${cause != null ? ' ($cause)' : ''}';
}

// ---------------------------------------------------------------------------
// Abstract service
// ---------------------------------------------------------------------------

/// Abstract interface for an AI chat service.
abstract class AIService {
  /// Streams a chat completion token-by-token.
  Stream<String> chatStream({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  });

  /// Non-streaming chat completion returning the full response.
  Future<String> chat({
    required List<ChatMessage> history,
    required AIConfig config,
    String? systemPrompt,
  });

  /// Validates that the given [config] is usable (API key valid, etc.).
  Future<void> validateConfig(AIConfig config);

  /// Human-readable provider name (e.g. "OpenAI", "DeepSeek").
  String get providerName;
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/// Creates the appropriate [AIService] for a given [AIProvider].
class AIServiceFactory {
  AIServiceFactory._();

  static AIService create(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return OpenAIService();
      case AIProvider.deepseek:
        return DeepSeekService();
    }
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Builds the messages list for the API request body.
List<Map<String, dynamic>> buildMessages({
  required List<ChatMessage> history,
  String? systemPrompt,
}) {
  final messages = <Map<String, dynamic>>[];
  if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
    messages.add({
      'role': 'system',
      'content': systemPrompt.trim(),
    });
  }
  for (final m in history) {
    messages.add({
      'role': m.role.name,
      'content': m.content,
    });
  }
  return messages;
}

/// Resolves the base URL for a config, with per-provider defaults.
String resolveBaseUrl(AIConfig config) {
  return config.baseUrl ??
      (config.provider == AIProvider.deepseek
          ? 'https://api.deepseek.com/v1'
          : 'https://api.openai.com/v1');
}

/// Performs a streaming chat completion request via raw HTTP SSE.
///
/// [body] is the full JSON request body (model, messages, stream: true, plus
/// any provider-specific fields).
///
/// Yields extracted text tokens from the SSE stream.
Stream<String> chatStreamRequest({
  required AIConfig config,
  required Map<String, dynamic> body,
}) async* {
  final client = http.Client();
  try {
    final uri = Uri.parse('${resolveBaseUrl(config)}/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      })
      ..body = jsonEncode(body);

    final response = await client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      String errorMsg = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(errorBody) as Map<String, dynamic>;
        if (decoded.containsKey('error')) {
          final err = decoded['error'] as Map<String, dynamic>;
          errorMsg = err['message'] as String? ?? errorMsg;
        }
      } catch (_) {}
      throw AIServiceException(errorMsg);
    }

    // Parse SSE stream.
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6).trim();
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;

        final delta = (choices[0] as Map<String, dynamic>)['delta']
            as Map<String, dynamic>?;
        if (delta == null) continue;

        final content = delta['content'];
        final text = _extractContentText(content);
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      } catch (_) {
        // Skip unparseable chunks.
      }
    }
  } finally {
    client.close();
  }
}

/// Performs a non-streaming chat completion request.
Future<String> chatRequest({
  required AIConfig config,
  required Map<String, dynamic> body,
}) async {
  final client = http.Client();
  try {
    final uri = Uri.parse('${resolveBaseUrl(config)}/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      })
      ..body = jsonEncode(body);

    final response = await client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      String errorMsg = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        if (decoded.containsKey('error')) {
          final err = decoded['error'] as Map<String, dynamic>;
          errorMsg = err['message'] as String? ?? errorMsg;
        }
      } catch (_) {}
      throw AIServiceException(errorMsg);
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) return '';

    final message = (choices[0] as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    if (message == null) return '';

    final content = message['content'];
    return _extractContentText(content) ?? '';
  } finally {
    client.close();
  }
}

/// Extracts text from a content field that may be a String or a List of
/// `{"type":"text","text":"..."}` objects.
String? _extractContentText(dynamic content) {
  if (content == null) return null;
  if (content is String) return content;
  if (content is List) {
    return content
        .whereType<Map<String, dynamic>>()
        .where((c) => c['type'] == 'text')
        .map((c) => (c['text'] as String?) ?? '')
        .join();
  }
  return content.toString();
}
