import 'package:flutter/foundation.dart';

/// Supported AI service providers.
enum AIProvider { openai, deepseek }

/// Reasoning effort for OpenAI o-series models (maps to `reasoning_effort`).
enum ThinkingDepth {
  low,
  medium,
  high,
}

/// Thinking mode for DeepSeek-R1 (maps to `thinking` field in API).
enum DeepSeekThinkingMode {
  enabled,
  disabled,
}

/// Base configuration for an AI service connection.
///
/// Polymorphic deserialization uses the [provider] field as discriminator:
/// `openai` → [OpenAIConfig], `deepseek` → [DeepSeekConfig].
@immutable
class AIConfig {
  const AIConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AIProvider provider;
  final String apiKey;
  final String? baseUrl;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Serializes this config to a JSON-compatible map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'provider': provider.name,
      'apiKey': apiKey,
      if (baseUrl != null) 'baseUrl': baseUrl,
      'model': model,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes an [AIConfig] from a JSON map.
  ///
  /// The [provider] field determines which subclass is instantiated.
  /// Unknown provider values fall back to [OpenAIConfig].
  factory AIConfig.fromJson(Map<String, Object?> json) {
    final providerName = json['provider'] as String? ?? '';
    final provider = AIProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => AIProvider.openai,
    );
    switch (provider) {
      case AIProvider.openai:
        return OpenAIConfig.fromJson(json);
      case AIProvider.deepseek:
        return DeepSeekConfig.fromJson(json);
    }
  }

  /// Creates a copy with the given fields replaced.
  AIConfig copyWith({
    String? id,
    String? name,
    AIProvider? provider,
    String? apiKey,
    String? baseUrl,
    bool clearBaseUrl = false,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AIConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIConfig &&
        other.runtimeType == runtimeType &&
        other.id == id &&
        other.name == name &&
        other.provider == provider &&
        other.apiKey == apiKey &&
        other.baseUrl == baseUrl &&
        other.model == model &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        provider,
        apiKey,
        baseUrl,
        model,
        createdAt,
        updatedAt,
      );
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

/// OpenAI-specific configuration with reasoning-effort support.
@immutable
class OpenAIConfig extends AIConfig {
  const OpenAIConfig({
    required super.id,
    required super.name,
    required super.apiKey,
    super.baseUrl,
    required super.model,
    required super.createdAt,
    required super.updatedAt,
    this.thinkingDepth = ThinkingDepth.medium,
    this.organizationId,
  }) : super(provider: AIProvider.openai);

  /// Reasoning effort for o-series models (maps to `reasoning_effort`).
  final ThinkingDepth thinkingDepth;

  /// Optional OpenAI organization ID.
  final String? organizationId;

  @override
  Map<String, Object?> toJson() {
    final json = super.toJson();
    json['thinkingDepth'] = thinkingDepth.name;
    if (organizationId != null) {
      json['organizationId'] = organizationId;
    }
    return json;
  }

  /// Deserializes an [OpenAIConfig] from a JSON map.
  factory OpenAIConfig.fromJson(Map<String, Object?> json) {
    return OpenAIConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String?,
      model: json['model'] as String? ?? 'gpt-4o',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      thinkingDepth: _parseThinkingDepth(json['thinkingDepth']),
      organizationId: json['organizationId'] as String?,
    );
  }

  @override
  OpenAIConfig copyWith({
    String? id,
    String? name,
    AIProvider? provider,
    String? apiKey,
    String? baseUrl,
    bool clearBaseUrl = false,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
    ThinkingDepth? thinkingDepth,
    String? organizationId,
    bool clearOrganizationId = false,
  }) {
    return OpenAIConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thinkingDepth: thinkingDepth ?? this.thinkingDepth,
      organizationId:
          clearOrganizationId ? null : (organizationId ?? this.organizationId),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OpenAIConfig &&
        super == other &&
        other.thinkingDepth == thinkingDepth &&
        other.organizationId == organizationId;
  }

  @override
  int get hashCode =>
      Object.hash(super.hashCode, thinkingDepth, organizationId);
}

// ---------------------------------------------------------------------------
// DeepSeek
// ---------------------------------------------------------------------------

/// DeepSeek-specific configuration with thinking-mode support.
@immutable
class DeepSeekConfig extends AIConfig {
  const DeepSeekConfig({
    required super.id,
    required super.name,
    required super.apiKey,
    super.baseUrl,
    required super.model,
    required super.createdAt,
    required super.updatedAt,
    this.thinkingMode = DeepSeekThinkingMode.disabled,
    this.maxTokens,
  }) : super(provider: AIProvider.deepseek);

  /// Thinking mode for DeepSeek-R1 (maps to `thinking` field in API).
  final DeepSeekThinkingMode thinkingMode;

  /// Optional maximum token limit for responses.
  final int? maxTokens;

  @override
  Map<String, Object?> toJson() {
    final json = super.toJson();
    json['thinkingMode'] = thinkingMode.name;
    if (maxTokens != null) {
      json['maxTokens'] = maxTokens;
    }
    return json;
  }

  /// Deserializes a [DeepSeekConfig] from a JSON map.
  factory DeepSeekConfig.fromJson(Map<String, Object?> json) {
    return DeepSeekConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com/v1',
      model: json['model'] as String? ?? 'deepseek-chat',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      thinkingMode: _parseDeepSeekThinkingMode(json['thinkingMode']),
      maxTokens: json['maxTokens'] as int?,
    );
  }

  @override
  DeepSeekConfig copyWith({
    String? id,
    String? name,
    AIProvider? provider,
    String? apiKey,
    String? baseUrl,
    bool clearBaseUrl = false,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
    DeepSeekThinkingMode? thinkingMode,
    int? maxTokens,
    bool clearMaxTokens = false,
  }) {
    return DeepSeekConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      maxTokens: clearMaxTokens ? null : (maxTokens ?? this.maxTokens),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeepSeekConfig &&
        super == other &&
        other.thinkingMode == thinkingMode &&
        other.maxTokens == maxTokens;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, thinkingMode, maxTokens);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ThinkingDepth _parseThinkingDepth(Object? field) {
  final name = field?.toString() ?? '';
  return ThinkingDepth.values.firstWhere(
    (v) => v.name == name,
    orElse: () => ThinkingDepth.medium,
  );
}

DeepSeekThinkingMode _parseDeepSeekThinkingMode(Object? field) {
  final name = field?.toString() ?? '';
  return DeepSeekThinkingMode.values.firstWhere(
    (v) => v.name == name,
    orElse: () => DeepSeekThinkingMode.disabled,
  );
}
