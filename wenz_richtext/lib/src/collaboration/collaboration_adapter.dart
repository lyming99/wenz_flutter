import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controller/wenz_rich_text_controller.dart';
import '../core/model/rich_text_document.dart';
import '../core/position/document_position.dart';

/// Business-owned bridge between [WenzRichTextController] and a collaboration
/// backend.
///
/// The package deliberately does not prescribe CRDT/OT/storage semantics. Apps
/// can translate [publishDocumentChange] into Yjs, OT, WebSocket messages, or a
/// document-snapshot protocol, and feed resolved remote snapshots back through
/// [remoteDocumentUpdates]. Remote selections are kept out of the document
/// schema and are exposed as ephemeral UI state.
abstract class WenzCollaborationAdapter {
  /// Remote document snapshots or backend-resolved operation results.
  Stream<WenzRemoteDocumentUpdate> get remoteDocumentUpdates;

  /// Remote cursor/selection updates from other clients.
  Stream<WenzRemoteSelectionUpdate> get remoteSelectionUpdates;

  /// Publishes a local document mutation observed from the editor.
  Future<void> publishDocumentChange(WenzLocalDocumentChange change);

  /// Publishes the local cursor/selection. A `null` selection clears it.
  Future<void> publishSelection(WenzRemoteSelectionUpdate update);

  /// Optional cleanup hook for adapters owned by [WenzCollaborationController].
  Future<void> close() async {}
}

/// Minimal peer metadata for cursor labels and collaboration sidebars.
class WenzCollaborationPeer {
  const WenzCollaborationPeer({
    required this.id,
    required this.displayName,
    this.color,
    this.avatarUrl,
    this.metadata = const <String, Object?>{},
  });

  factory WenzCollaborationPeer.fromJson(Map<String, Object?> json) {
    final rawMetadata = json['metadata'];
    return WenzCollaborationPeer(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      color: _asIntOrNull(json['color']),
      avatarUrl: json['avatarUrl'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, Object?>.from(rawMetadata)
          : const <String, Object?>{},
    );
  }

  final String id;
  final String displayName;

  /// ARGB color value used by UI integrations for remote caret/selection tint.
  final int? color;
  final String? avatarUrl;
  final Map<String, Object?> metadata;

  WenzCollaborationPeer copyWith({
    String? id,
    String? displayName,
    Object? color = _unset,
    Object? avatarUrl = _unset,
    Map<String, Object?>? metadata,
  }) {
    return WenzCollaborationPeer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      color: identical(color, _unset) ? this.color : color as int?,
      avatarUrl:
          identical(avatarUrl, _unset) ? this.avatarUrl : avatarUrl as String?,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'displayName': displayName,
      if (color != null) 'color': color,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is WenzCollaborationPeer &&
        other.id == id &&
        other.displayName == displayName &&
        other.color == color &&
        other.avatarUrl == avatarUrl &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      displayName,
      color,
      avatarUrl,
      _mapHash(metadata),
    );
  }
}

/// Local document mutation published to [WenzCollaborationAdapter].
class WenzLocalDocumentChange {
  const WenzLocalDocumentChange({
    required this.clientId,
    required this.document,
    required this.json,
    required this.revision,
    required this.changedAt,
    this.selection,
    this.changedBlockIds,
    this.metadata = const <String, Object?>{},
  });

  final String clientId;
  final RichTextDocument document;
  final String json;
  final int revision;
  final DateTime changedAt;
  final DocumentSelection? selection;

  /// Same semantics as [WenzRichTextController.lastChangedBlockIds]: `null`
  /// means full refresh, empty means no block content changed.
  final Set<String>? changedBlockIds;
  final Map<String, Object?> metadata;
}

/// Remote document snapshot or backend-resolved operation result.
class WenzRemoteDocumentUpdate {
  const WenzRemoteDocumentUpdate({
    required this.clientId,
    required this.document,
    this.selection,
    this.revision,
    this.updatedAt,
    this.clearHistory = false,
    this.metadata = const <String, Object?>{},
  });

  final String clientId;
  final RichTextDocument document;

  /// Optional local selection after applying [document]. When `null`, the
  /// bridge keeps the editor's current selection.
  final DocumentSelection? selection;
  final int? revision;
  final DateTime? updatedAt;

  /// Whether applying this remote snapshot should clear local undo history.
  final bool clearHistory;
  final Map<String, Object?> metadata;
}

/// Cursor/selection update exchanged through [WenzCollaborationAdapter].
///
/// A `null` [selection] is a presence clear event. Non-null selections are
/// cached by [WenzCollaborationController.remoteSelections] for renderer layers.
class WenzRemoteSelectionUpdate {
  const WenzRemoteSelectionUpdate({
    required this.clientId,
    required this.updatedAt,
    this.peer,
    this.selection,
    this.metadata = const <String, Object?>{},
  });

  factory WenzRemoteSelectionUpdate.fromJson(Map<String, Object?> json) {
    final rawPeer = json['peer'];
    final rawSelection = json['selection'];
    final rawMetadata = json['metadata'];
    return WenzRemoteSelectionUpdate(
      clientId: json['clientId'] as String? ?? '',
      updatedAt: _asDateTime(json['updatedAt']) ?? _epoch,
      peer: rawPeer is Map
          ? WenzCollaborationPeer.fromJson(Map<String, Object?>.from(rawPeer))
          : null,
      selection: rawSelection is Map
          ? _selectionFromJson(Map<String, Object?>.from(rawSelection))
          : null,
      metadata: rawMetadata is Map
          ? Map<String, Object?>.from(rawMetadata)
          : const <String, Object?>{},
    );
  }

  final String clientId;
  final WenzCollaborationPeer? peer;
  final DocumentSelection? selection;
  final DateTime updatedAt;
  final Map<String, Object?> metadata;

  bool get isClear => selection == null;

  bool get isCursor => selection?.isCollapsed ?? false;

  WenzRemoteSelectionUpdate copyWith({
    String? clientId,
    Object? peer = _unset,
    Object? selection = _unset,
    DateTime? updatedAt,
    Map<String, Object?>? metadata,
  }) {
    return WenzRemoteSelectionUpdate(
      clientId: clientId ?? this.clientId,
      peer:
          identical(peer, _unset) ? this.peer : peer as WenzCollaborationPeer?,
      selection: identical(selection, _unset)
          ? this.selection
          : selection as DocumentSelection?,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'clientId': clientId,
      if (peer != null) 'peer': peer!.toJson(),
      if (selection != null) 'selection': _selectionToJson(selection!),
      'updatedAt': updatedAt.toIso8601String(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is WenzRemoteSelectionUpdate &&
        other.clientId == clientId &&
        other.peer == peer &&
        other.selection == selection &&
        other.updatedAt == updatedAt &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      clientId,
      peer,
      selection,
      updatedAt,
      _mapHash(metadata),
    );
  }
}

/// Observes an editor and keeps collaboration concerns outside the document
/// model.
///
/// The bridge uses [ChangeNotifier.addListener] instead of taking over
/// `onChanged` / `onSelectionChanged`, so existing app callbacks keep working.
/// It only runs when explicitly instantiated; single-user editors pay no cost.
class WenzCollaborationController extends ChangeNotifier {
  WenzCollaborationController({
    required WenzRichTextController editor,
    required WenzCollaborationAdapter adapter,
    required String localClientId,
    WenzCollaborationPeer? localPeer,
    bool publishInitialSelection = false,
    bool closeAdapter = false,
    DateTime Function()? clock,
    this.onError,
  })  : _host = editor,
        _adapter = adapter,
        _localClientId = localClientId,
        _localPeer = localPeer,
        _closeAdapter = closeAdapter,
        _clock = clock ?? DateTime.now {
    _lastDocumentJson = _host.toJson();
    _lastSelection = _host.selection;
    _documentSubscription = _adapter.remoteDocumentUpdates.listen(
      applyRemoteDocument,
      onError: _handleStreamError,
    );
    _selectionSubscription = _adapter.remoteSelectionUpdates.listen(
      applyRemoteSelection,
      onError: _handleStreamError,
    );
    _host.addListener(_handleHostChanged);
    if (publishInitialSelection && _lastSelection != null) {
      _publishSelection(_lastSelection);
    }
  }

  final WenzRichTextController _host;
  final WenzCollaborationAdapter _adapter;
  final String _localClientId;
  final WenzCollaborationPeer? _localPeer;
  final bool _closeAdapter;
  final DateTime Function() _clock;

  late final StreamSubscription<WenzRemoteDocumentUpdate> _documentSubscription;
  late final StreamSubscription<WenzRemoteSelectionUpdate>
      _selectionSubscription;
  late String _lastDocumentJson;
  DocumentSelection? _lastSelection;
  final Map<String, WenzRemoteSelectionUpdate> _remoteSelections =
      <String, WenzRemoteSelectionUpdate>{};
  var _localRevision = 0;
  var _applyingRemoteDocument = false;
  var _disposed = false;
  Object? _lastError;

  /// Called when adapter publishing or stream delivery reports an error.
  final void Function(Object error, StackTrace stackTrace)? onError;

  String get localClientId => _localClientId;

  WenzCollaborationPeer? get localPeer => _localPeer;

  int get localRevision => _localRevision;

  bool get isApplyingRemoteDocument => _applyingRemoteDocument;

  Object? get lastError => _lastError;

  List<WenzRemoteSelectionUpdate> get remoteSelections {
    return List<WenzRemoteSelectionUpdate>.unmodifiable(
      _remoteSelections.values,
    );
  }

  /// Applies a backend-resolved remote document snapshot to the editor without
  /// echoing it back through [WenzCollaborationAdapter.publishDocumentChange].
  void applyRemoteDocument(WenzRemoteDocumentUpdate update) {
    if (_disposed || update.clientId == _localClientId) {
      return;
    }
    _applyingRemoteDocument = true;
    try {
      _host.replaceDocument(
        update.document,
        selection: update.selection ?? _host.selection,
        clearHistory: update.clearHistory,
      );
    } finally {
      _lastDocumentJson = _host.toJson();
      _lastSelection = _host.selection;
      _applyingRemoteDocument = false;
    }
  }

  /// Applies a remote cursor/selection update to the ephemeral renderer state.
  void applyRemoteSelection(WenzRemoteSelectionUpdate update) {
    if (_disposed || update.clientId == _localClientId) {
      return;
    }
    final previous = _remoteSelections[update.clientId];
    if (update.isClear) {
      if (_remoteSelections.remove(update.clientId) != null) {
        notifyListeners();
      }
      return;
    }
    if (previous == update) {
      return;
    }
    _remoteSelections[update.clientId] = update;
    notifyListeners();
  }

  void clearRemoteSelections() {
    if (_remoteSelections.isEmpty) {
      return;
    }
    _remoteSelections.clear();
    notifyListeners();
  }

  void _handleHostChanged() {
    final nextJson = _host.toJson();
    final nextSelection = _host.selection;
    final documentChanged = nextJson != _lastDocumentJson;
    final selectionChanged = nextSelection != _lastSelection;
    _lastDocumentJson = nextJson;
    _lastSelection = nextSelection;
    if (_disposed || _applyingRemoteDocument) {
      return;
    }
    if (documentChanged) {
      _localRevision++;
      final change = WenzLocalDocumentChange(
        clientId: _localClientId,
        document: _host.document,
        json: nextJson,
        revision: _localRevision,
        changedAt: _clock(),
        selection: nextSelection,
        changedBlockIds: _host.lastChangedBlockIds,
      );
      unawaited(_publishDocumentChange(change));
      notifyListeners();
    }
    if (selectionChanged) {
      _publishSelection(nextSelection);
    }
  }

  void _publishSelection(DocumentSelection? selection) {
    final update = WenzRemoteSelectionUpdate(
      clientId: _localClientId,
      peer: _localPeer,
      selection: selection,
      updatedAt: _clock(),
    );
    unawaited(_publishSelectionUpdate(update));
  }

  Future<void> _publishDocumentChange(WenzLocalDocumentChange change) async {
    try {
      await _adapter.publishDocumentChange(change);
    } on Object catch (error, stackTrace) {
      _recordError(error, stackTrace);
    }
  }

  Future<void> _publishSelectionUpdate(WenzRemoteSelectionUpdate update) async {
    try {
      await _adapter.publishSelection(update);
    } on Object catch (error, stackTrace) {
      _recordError(error, stackTrace);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _recordError(error, stackTrace);
  }

  void _recordError(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    _lastError = error;
    onError?.call(error, stackTrace);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _host.removeListener(_handleHostChanged);
    unawaited(_documentSubscription.cancel());
    unawaited(_selectionSubscription.cancel());
    if (_closeAdapter) {
      unawaited(_adapter.close());
    }
    super.dispose();
  }
}

const Object _unset = Object();

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Map<String, Object?> _selectionToJson(DocumentSelection selection) {
  return <String, Object?>{
    'base': _positionToJson(selection.base),
    'extent': _positionToJson(selection.extent),
  };
}

DocumentSelection _selectionFromJson(Map<String, Object?> json) {
  final rawBase = json['base'];
  final rawExtent = json['extent'];
  final base = rawBase is Map
      ? _positionFromJson(Map<String, Object?>.from(rawBase))
      : _emptyPosition;
  final extent = rawExtent is Map
      ? _positionFromJson(Map<String, Object?>.from(rawExtent))
      : base;
  return DocumentSelection(base: base, extent: extent);
}

Map<String, Object?> _positionToJson(DocumentPosition position) {
  return <String, Object?>{
    'blockId': position.blockId,
    'blockIndex': position.blockIndex,
    'path': position.path.segments,
    'offset': position.offset,
  };
}

DocumentPosition _positionFromJson(Map<String, Object?> json) {
  final blockId = json['blockId'] as String? ?? '';
  return DocumentPosition(
    blockId: blockId,
    blockIndex: _asInt(json['blockIndex']),
    path: _positionPathFromJson(json['path'], fallbackBlockId: blockId),
    offset: _asInt(json['offset']),
  );
}

final DocumentPosition _emptyPosition = DocumentPosition.text(
  blockId: '',
  blockIndex: 0,
  offset: 0,
);

PositionPath _positionPathFromJson(Object? value,
    {required String fallbackBlockId}) {
  if (value is List) {
    return PositionPath(<Object>[
      for (final segment in value)
        if (segment is int)
          segment
        else if (segment is num)
          segment.toInt()
        else
          segment.toString(),
    ]);
  }
  return PositionPath.blockText(fallbackBlockId);
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

int? _asIntOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _mapHash(Map<String, Object?> map) {
  final keys = map.keys.toList()..sort();
  return Object.hashAll(keys.map((key) => Object.hash(key, map[key])));
}
