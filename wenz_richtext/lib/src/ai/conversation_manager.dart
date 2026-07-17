import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'ai_config_manager.dart';
import 'models/conversation.dart';
import 'services/ai_service.dart';

/// File name for persisting conversations.
const String _conversationsFileName = 'wenz_ai_conversations.json';

const Uuid _uuid = Uuid();

/// Manages the lifecycle of [Conversation] instances with JSON file persistence.
///
/// Coordinates with [AIConfigManager] to resolve AI service configurations
/// and with [AIServiceFactory] to dispatch chat requests.
class ConversationManager extends ChangeNotifier {
  final List<Conversation> _conversations = <Conversation>[];
  bool _initialized = false;
  AIConfigManager? _configManager;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// All loaded conversations, sorted by [Conversation.updatedAt] descending.
  List<Conversation> get conversations {
    final sorted = List<Conversation>.from(_conversations)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<Conversation>.unmodifiable(sorted);
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads persisted conversations from the local JSON file.
  ///
  /// [configManager] is retained for resolving AI configs when sending messages.
  Future<void> initialize(AIConfigManager configManager) async {
    if (_initialized) return;
    _configManager = configManager;

    final file = await _conversationsFile;
    if (!file.existsSync()) {
      _initialized = true;
      return;
    }
    try {
      final raw = await file.readAsString();
      final list = json.decode(raw) as List<dynamic>;
      _conversations.clear();
      for (final entry in list) {
        if (entry is Map<String, Object?>) {
          _conversations.add(Conversation.fromJson(entry));
        }
      }
    } catch (_) {
      // Corrupted file — start with an empty conversation list.
      _conversations.clear();
    }
    _initialized = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Finds a conversation by [id], or `null` if not found.
  Conversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new conversation and persists immediately.
  Future<Conversation> createConversation({
    required String title,
    required String aiConfigId,
    String? systemPrompt,
  }) async {
    final now = DateTime.now();
    final conversation = Conversation(
      id: _uuid.v4(),
      title: title,
      aiConfigId: aiConfigId,
      createdAt: now,
      updatedAt: now,
      systemPrompt: systemPrompt,
    );
    _conversations.add(conversation);
    await _persist();
    notifyListeners();
    return conversation;
  }

  /// Deletes the conversation with the given [id] and persists.
  ///
  /// Has no effect if no matching conversation exists.
  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  /// Sends a user message in the given conversation and streams the AI reply.
  ///
  /// The returned [Stream] emits token chunks as they arrive. The caller should
  /// also listen to [ConversationManager] itself (via `addListener`) to receive
  /// status-change notifications ([ConversationStatus.thinking] →
  /// [ConversationStatus.replying] → [ConversationStatus.idle] / [ConversationStatus.error]).
  ///
  /// Throws [StateError] if [initialize] hasn't been called yet, if the
  /// conversation doesn't exist, or if the associated AI config can't be found.
  Stream<String> sendMessage(String conversationId, String content) async* {
    if (!_initialized || _configManager == null) {
      throw StateError(
        'ConversationManager not initialized. Call initialize() first.',
      );
    }

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) {
      throw StateError('Conversation not found: $conversationId');
    }

    final config = _configManager!.getConfig(
      _conversations[index].aiConfigId,
    );
    if (config == null) {
      throw StateError(
        'AI config not found for conversation: $conversationId',
      );
    }

    // Build the user message.
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );

    // Append user message and set status → thinking.
    _conversations[index] = _conversations[index].copyWith(
      messages: [..._conversations[index].messages, userMessage],
      status: ConversationStatus.thinking,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();

    // Create placeholder assistant message.
    final assistantMessageId = _uuid.v4();
    final assistantPlaceholder = ChatMessage(
      id: assistantMessageId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
    );

    // Append placeholder.
    _conversations[index] = _conversations[index].copyWith(
      messages: [..._conversations[index].messages, assistantPlaceholder],
      updatedAt: DateTime.now(),
    );

    // Resolve the AI service.
    final service = AIServiceFactory.create(config.provider);

    final StringBuffer responseBuffer = StringBuffer();
    bool firstToken = true;

    try {
      final stream = service.chatStream(
        history: _conversations[index]
            .messages
            .where((m) => m.id != assistantMessageId)
            .toList(),
        config: config,
        systemPrompt: _conversations[index].systemPrompt,
      );

      await for (final token in stream) {
        responseBuffer.write(token);
        yield token;

        if (firstToken) {
          firstToken = false;
          // Transition: thinking → replying.
          _updateAssistantMessage(
            index,
            assistantMessageId,
            responseBuffer.toString(),
            ConversationStatus.replying,
          );
        }
      }

      // Stream completed successfully.
      _updateAssistantMessage(
        index,
        assistantMessageId,
        responseBuffer.toString(),
        ConversationStatus.idle,
      );
    } catch (e) {
      // Record error on the assistant message.
      _updateAssistantMessage(
        index,
        assistantMessageId,
        responseBuffer.toString(),
        ConversationStatus.error,
        error: e is AIServiceException ? e.message : '$e',
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Updates the in-progress assistant message with the accumulated content,
  /// new status, and optional error, then persists and notifies.
  void _updateAssistantMessage(
    int conversationIndex,
    String assistantMessageId,
    String content,
    ConversationStatus status, {
    String? error,
  }) {
    final conversation = _conversations[conversationIndex];
    final updatedMessages = conversation.messages.map((m) {
      if (m.id == assistantMessageId) {
        return m.copyWith(
          content: content,
          error: error,
          clearError: error == null,
        );
      }
      return m;
    }).toList();

    _conversations[conversationIndex] = conversation.copyWith(
      messages: updatedMessages,
      status: status,
      updatedAt: DateTime.now(),
    );
    _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<File> get _conversationsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_conversationsFileName');
  }

  Future<void> _persist() async {
    final file = await _conversationsFile;
    final list =
        _conversations.map((c) => c.toJson()).toList();
    await file.writeAsString(json.encode(list));
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _conversations.clear();
    _configManager = null;
    super.dispose();
  }
}
