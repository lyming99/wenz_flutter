import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/ai_config.dart';

/// File name for persisting AI configurations.
const String _configFileName = 'wenz_ai_configs.json';

/// Manages the lifecycle of [AIConfig] instances with JSON file persistence.
///
/// API keys are stored with base64 obfuscation (not encryption) to prevent
/// accidental plain-text exposure in the persisted file.
class AIConfigManager extends ChangeNotifier {
  final List<AIConfig> _configs = <AIConfig>[];
  bool _initialized = false;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// All currently loaded AI configurations.
  List<AIConfig> get configs => List<AIConfig>.unmodifiable(_configs);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads persisted configurations from the local JSON file.
  Future<void> initialize() async {
    if (_initialized) return;
    final file = await _configFile;
    if (!file.existsSync()) {
      _initialized = true;
      return;
    }
    try {
      final raw = await file.readAsString();
      final list = json.decode(raw) as List<dynamic>;
      _configs.clear();
      for (final entry in list) {
        if (entry is Map<String, Object?>) {
          _configs.add(AIConfig.fromJson(_decodeApiKey(entry)));
        }
      }
    } catch (_) {
      // Corrupted file — start with an empty config list.
      _configs.clear();
    }
    _initialized = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Finds a config by [id], or `null` if not found.
  AIConfig? getConfig(String id) {
    try {
      return _configs.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adds a new configuration and persists immediately.
  Future<void> addConfig(AIConfig config) async {
    _configs.add(config);
    await _persist();
    notifyListeners();
  }

  /// Updates an existing configuration (matched by [config.id]) and persists.
  ///
  /// Has no effect if no config with the matching [config.id] exists.
  Future<void> updateConfig(AIConfig config) async {
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index == -1) return;
    _configs[index] = config;
    await _persist();
    notifyListeners();
  }

  /// Deletes the configuration with the given [id] and persists.
  ///
  /// Has no effect if no matching config exists.
  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<File> get _configFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFileName');
  }

  Future<void> _persist() async {
    final file = await _configFile;
    final list = _configs.map((c) => _encodeApiKey(c.toJson())).toList();
    await file.writeAsString(json.encode(list));
  }

  // ---------------------------------------------------------------------------
  // API key obfuscation
  // ---------------------------------------------------------------------------

  /// Returns a copy of [json] with the `apiKey` field base64-obfuscated.
  static Map<String, Object?> _encodeApiKey(Map<String, Object?> json) {
    final key = json['apiKey'] as String?;
    if (key != null && key.isNotEmpty) {
      json['apiKey'] = base64.encode(utf8.encode(key));
    }
    return json;
  }

  /// Returns a copy of [json] with the `apiKey` field decoded from base64.
  static Map<String, Object?> _decodeApiKey(Map<String, Object?> json) {
    final encoded = json['apiKey'] as String?;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        json['apiKey'] = utf8.decode(base64.decode(encoded));
      } catch (_) {
        // Not base64-encoded; keep as-is (handles migration from plaintext).
      }
    }
    return json;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _configs.clear();
    super.dispose();
  }
}
