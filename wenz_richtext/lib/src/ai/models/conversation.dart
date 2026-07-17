import 'package:flutter/foundation.dart';

/// Roles for chat messages in a conversation.
enum MessageRole { user, assistant, system }

/// Runtime status of a conversation, used for UI state display.
///
/// This is **not** persisted — it resets to [ConversationStatus.idle] on load.
enum ConversationStatus { idle, thinking, replying, error }

// ---------------------------------------------------------------------------
// ChatMessage
// ---------------------------------------------------------------------------

/// A single message in a conversation.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.tokenCount,
    this.error,
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  /// Estimated token count for this message, if available.
  final int? tokenCount;

  /// Error description when this message represents a failed response.
  final String? error;

  /// Serializes this message to a JSON-compatible map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (tokenCount != null) 'tokenCount': tokenCount,
      if (error != null) 'error': error,
    };
  }

  /// Deserializes a [ChatMessage] from a JSON map.
  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: _parseMessageRole(json['role']),
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      tokenCount: json['tokenCount'] as int?,
      error: json['error'] as String?,
    );
  }

  /// Creates a copy with the given fields replaced.
  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    int? tokenCount,
    bool clearTokenCount = false,
    String? error,
    bool clearError = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      tokenCount: clearTokenCount ? null : (tokenCount ?? this.tokenCount),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp &&
        other.tokenCount == tokenCount &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(id, role, content, timestamp, tokenCount, error);
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

/// A conversation thread containing messages and associated AI config.
///
/// [status] is a runtime-only field and is **not** included in serialization.
/// It always resets to [ConversationStatus.idle] when deserialized.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.aiConfigId,
    this.messages = const <ChatMessage>[],
    this.status = ConversationStatus.idle,
    required this.createdAt,
    required this.updatedAt,
    this.systemPrompt,
  });

  final String id;
  final String title;

  /// ID of the associated [AIConfig].
  final String aiConfigId;

  final List<ChatMessage> messages;

  /// Runtime UI status — **not persisted**.
  final ConversationStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional system-level prompt for the conversation.
  final String? systemPrompt;

  /// Serializes this conversation to a JSON-compatible map.
  ///
  /// [status] is intentionally excluded.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'aiConfigId': aiConfigId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
    };
  }

  /// Deserializes a [Conversation] from a JSON map.
  ///
  /// [status] is always reset to [ConversationStatus.idle].
  factory Conversation.fromJson(Map<String, Object?> json) {
    final rawMessages = json['messages'];
    return Conversation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      aiConfigId: json['aiConfigId'] as String? ?? '',
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((m) => ChatMessage.fromJson(Map<String, Object?>.from(m)))
              .toList()
          : const <ChatMessage>[],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      systemPrompt: json['systemPrompt'] as String?,
    );
  }

  /// Creates a copy with the given fields replaced.
  Conversation copyWith({
    String? id,
    String? title,
    String? aiConfigId,
    List<ChatMessage>? messages,
    ConversationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? systemPrompt,
    bool clearSystemPrompt = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      aiConfigId: aiConfigId ?? this.aiConfigId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      systemPrompt:
          clearSystemPrompt ? null : (systemPrompt ?? this.systemPrompt),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation &&
        other.id == id &&
        other.title == title &&
        other.aiConfigId == aiConfigId &&
        _listEquals(other.messages, messages) &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.systemPrompt == systemPrompt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        aiConfigId,
        Object.hashAll(messages),
        status,
        createdAt,
        updatedAt,
        systemPrompt,
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MessageRole _parseMessageRole(Object? field) {
  final name = field?.toString() ?? '';
  return MessageRole.values.firstWhere(
    (v) => v.name == name,
    orElse: () => MessageRole.user,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  final length = a.length;
  if (length != b.length) return false;
  for (int i = 0; i < length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
