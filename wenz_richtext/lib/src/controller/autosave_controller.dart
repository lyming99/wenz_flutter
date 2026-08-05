import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/model/rich_text_document.dart';
import 'wenz_rich_text_controller.dart';

const Duration _defaultAutoSaveDebounce = Duration(seconds: 2);

/// Persists one autosave snapshot.
///
/// Business code owns the durable storage target (local file, database, remote
/// API, etc.). The controller only supplies a stable JSON snapshot and tracks
/// whether that snapshot has been saved successfully.
typedef WenzAutoSaveCallback = Future<void> Function(
  AutoSaveSnapshot snapshot,
);

/// Current autosave phase.
enum AutoSaveStatus {
  /// The current document matches the most recently saved snapshot.
  clean,

  /// The document changed and no save is currently scheduled.
  dirty,

  /// The document changed and a debounced save is pending.
  scheduled,

  /// A save callback is running.
  saving,

  /// The latest save attempt failed; the document remains dirty.
  failed,
}

/// Immutable document snapshot passed to [WenzAutoSaveCallback].
class AutoSaveSnapshot {
  const AutoSaveSnapshot({
    required this.document,
    required this.json,
    required this.revision,
    required this.changedAt,
  });

  /// Document value at the moment the save was requested.
  final RichTextDocument document;

  /// Rich-text JSON for [document]. Store this string for draft recovery.
  final String json;

  /// Monotonic local revision assigned by [WenzAutoSaveController].
  final int revision;

  /// Time when this revision first became dirty.
  final DateTime changedAt;
}

/// Immutable autosave state for UI badges, draft banners, and tests.
class AutoSaveState {
  const AutoSaveState({
    this.status = AutoSaveStatus.clean,
    this.isDirty = false,
    this.revision = 0,
    this.lastChangedAt,
    this.lastSaveAttemptAt,
    this.lastSavedAt,
    this.error,
  });

  final AutoSaveStatus status;
  final bool isDirty;
  final int revision;
  final DateTime? lastChangedAt;
  final DateTime? lastSaveAttemptAt;
  final DateTime? lastSavedAt;
  final Object? error;

  bool get isScheduled => status == AutoSaveStatus.scheduled;
  bool get isSaving => status == AutoSaveStatus.saving;
  bool get hasError => status == AutoSaveStatus.failed;

  AutoSaveState copyWith({
    AutoSaveStatus? status,
    bool? isDirty,
    int? revision,
    DateTime? lastChangedAt,
    DateTime? lastSaveAttemptAt,
    DateTime? lastSavedAt,
    Object? error,
    bool clearError = false,
  }) {
    return AutoSaveState(
      status: status ?? this.status,
      isDirty: isDirty ?? this.isDirty,
      revision: revision ?? this.revision,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      lastSaveAttemptAt: lastSaveAttemptAt ?? this.lastSaveAttemptAt,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Tracks dirty state and optionally runs debounced autosaves for an editor.
///
/// The controller observes [WenzRichTextController] without taking over its
/// `onChanged` callback, so apps can continue using their own integration
/// callbacks. Selection-only notifications are ignored by comparing the current
/// rich JSON snapshot with the last observed document snapshot.
class WenzAutoSaveController extends ChangeNotifier {
  WenzAutoSaveController({
    required WenzRichTextController editor,
    required WenzAutoSaveCallback onSave,
    Duration debounceDuration = _defaultAutoSaveDebounce,
    bool enabled = true,
    DateTime Function()? clock,
  })  : assert(!debounceDuration.isNegative),
        _host = editor,
        _onSave = onSave,
        _debounceDuration = debounceDuration,
        _enabled = enabled,
        _clock = clock ?? DateTime.now {
    _lastDocumentJson = _host.toJson();
    _cleanJson = _lastDocumentJson;
    _host.addListener(_handleHostChanged);
  }

  final WenzRichTextController _host;
  final WenzAutoSaveCallback _onSave;
  final Duration _debounceDuration;
  final DateTime Function() _clock;

  Timer? _debounceTimer;
  bool _enabled;
  bool _disposed = false;
  int _revision = 0;
  late String _lastDocumentJson;
  late String _cleanJson;
  AutoSaveState _state = const AutoSaveState();

  AutoSaveState get state => _state;
  AutoSaveStatus get status => _state.status;
  bool get isDirty => _state.isDirty;
  bool get isScheduled => _state.isScheduled;
  bool get isSaving => _state.isSaving;
  bool get enabled => _enabled;
  int get revision => _revision;
  DateTime? get lastChangedAt => _state.lastChangedAt;
  DateTime? get lastSaveAttemptAt => _state.lastSaveAttemptAt;
  DateTime? get lastSavedAt => _state.lastSavedAt;
  Object? get error => _state.error;

  /// Turns debounced autosave on/off without changing the dirty flag.
  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (_enabled && isDirty && !isSaving) {
      _scheduleSave();
    } else if (!_enabled && isScheduled) {
      _debounceTimer?.cancel();
      _updateState(_state.copyWith(status: AutoSaveStatus.dirty));
    }
  }

  /// Marks the current editor document as persisted by an external save flow.
  void markClean({DateTime? savedAt}) {
    _debounceTimer?.cancel();
    _lastDocumentJson = _host.toJson();
    _cleanJson = _lastDocumentJson;
    _updateState(
      _state.copyWith(
        status: AutoSaveStatus.clean,
        isDirty: false,
        lastSavedAt: savedAt ?? _clock(),
        clearError: true,
      ),
    );
  }

  /// Saves immediately, cancelling any pending debounce timer.
  Future<void> saveNow({bool force = false}) async {
    _debounceTimer?.cancel();
    if (!force && !isDirty) {
      return;
    }
    final revision = _revision;
    final changedAt = _state.lastChangedAt ?? _clock();
    final snapshot = AutoSaveSnapshot(
      document: _host.document,
      json: _lastDocumentJson,
      revision: revision,
      changedAt: changedAt,
    );
    final attemptAt = _clock();
    _updateState(
      _state.copyWith(
        status: AutoSaveStatus.saving,
        isDirty: true,
        lastSaveAttemptAt: attemptAt,
        clearError: true,
      ),
    );
    try {
      await _onSave(snapshot);
    } on Object catch (error) {
      if (_disposed) {
        return;
      }
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.failed,
          isDirty: true,
          error: error,
        ),
      );
      return;
    }
    if (_disposed) {
      return;
    }
    if (revision == _revision && snapshot.json == _lastDocumentJson) {
      _cleanJson = snapshot.json;
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.clean,
          isDirty: false,
          lastSavedAt: _clock(),
          clearError: true,
        ),
      );
      return;
    }
    if (_lastDocumentJson == _cleanJson) {
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.clean,
          isDirty: false,
          clearError: true,
        ),
      );
      return;
    }
    if (_enabled) {
      _scheduleSave();
    } else {
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.dirty,
          isDirty: true,
          clearError: true,
        ),
      );
    }
  }

  void _handleHostChanged() {
    final nextJson = _host.toJson();
    if (nextJson == _lastDocumentJson) {
      return;
    }
    _lastDocumentJson = nextJson;
    _revision++;
    final dirty = nextJson != _cleanJson;
    if (!dirty) {
      _debounceTimer?.cancel();
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.clean,
          isDirty: false,
          revision: _revision,
          clearError: true,
        ),
      );
      return;
    }
    final changedAt = _clock();
    _updateState(
      _state.copyWith(
        status: isSaving
            ? AutoSaveStatus.saving
            : _enabled
                ? AutoSaveStatus.scheduled
                : AutoSaveStatus.dirty,
        isDirty: true,
        revision: _revision,
        lastChangedAt: changedAt,
        clearError: true,
      ),
    );
    if (_enabled && !isSaving) {
      _scheduleSave(notify: false);
    }
  }

  void _scheduleSave({bool notify = true}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(saveNow());
    });
    if (notify) {
      _updateState(
        _state.copyWith(
          status: AutoSaveStatus.scheduled,
          isDirty: true,
          clearError: true,
        ),
      );
    }
  }

  void _updateState(AutoSaveState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _host.removeListener(_handleHostChanged);
    super.dispose();
  }
}
