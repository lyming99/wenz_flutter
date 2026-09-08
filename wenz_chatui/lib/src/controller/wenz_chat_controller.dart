import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/wenz_chat_message.dart';

/// The latest collection mutation performed by [WenzChatController].
enum WenzChatMutationType { append, prepend, update, remove, replaceAll, clear }

/// Describes a controller mutation without copying the complete message list.
@immutable
class WenzChatMutation {
  const WenzChatMutation({
    required this.sequence,
    required this.type,
    required this.messageIds,
  });

  final int sequence;
  final WenzChatMutationType type;
  final List<String> messageIds;
}

class _MessageSlot {
  _MessageSlot(WenzChatMessage message)
    : notifier = ValueNotifier<WenzChatMessage>(message);

  final ValueNotifier<WenzChatMessage> notifier;

  WenzChatMessage get message => notifier.value;

  void dispose() => notifier.dispose();
}

/// Owns an old-to-new ordered chat timeline.
///
/// Structural changes notify [structureListenable]. Updating only the text,
/// status, payload, or metadata of one message notifies that message's own
/// listenable instead. [WenzChatView] uses this split to avoid rebuilding the
/// viewport for every token of a streaming response.
class WenzChatController extends ChangeNotifier {
  WenzChatController({Iterable<WenzChatMessage> initialMessages = const []}) {
    final messages = initialMessages.toList(growable: false);
    _validateUnique(messages);
    _slots.addAll(messages.map(_MessageSlot.new));
    _rebuildIndex();
  }

  final List<_MessageSlot> _slots = <_MessageSlot>[];
  final Map<String, int> _indices = <String, int>{};
  final ValueNotifier<int> _structureVersion = ValueNotifier<int>(0);

  int _mutationSequence = 0;
  WenzChatMutation? _lastMutation;
  bool _disposed = false;

  /// Notifies only when item count, order, keys, dates, or grouping changes.
  Listenable get structureListenable => _structureVersion;

  WenzChatMutation? get lastMutation => _lastMutation;

  int get length => _slots.length;
  bool get isEmpty => _slots.isEmpty;
  bool get isNotEmpty => _slots.isNotEmpty;

  /// An immutable snapshot in chronological (oldest-to-newest) order.
  List<WenzChatMessage> get messages =>
      UnmodifiableListView<WenzChatMessage>(_slots.map((slot) => slot.message));

  WenzChatMessage messageAt(int index) => _slots[index].message;

  WenzChatMessage? messageById(String id) {
    final index = _indices[id];
    return index == null ? null : _slots[index].message;
  }

  int indexOf(String id) => _indices[id] ?? -1;

  /// A fine-grained signal for advanced integrations and the built-in view.
  ValueListenable<WenzChatMessage> messageListenableAt(int index) {
    return _slots[index].notifier;
  }

  void append(WenzChatMessage message) => appendAll(<WenzChatMessage>[message]);

  /// Appends newer messages. [messages] must be in oldest-to-newest order.
  void appendAll(Iterable<WenzChatMessage> messages) {
    _ensureNotDisposed();
    final additions = messages.toList(growable: false);
    if (additions.isEmpty) return;
    _validateAdditions(additions);
    final start = _slots.length;
    _slots.addAll(additions.map(_MessageSlot.new));
    for (var index = start; index < _slots.length; index++) {
      _indices[_slots[index].message.id] = index;
    }
    _notifyStructure(WenzChatMutationType.append, additions);
  }

  void prepend(WenzChatMessage message) =>
      prependAll(<WenzChatMessage>[message]);

  /// Prepends history. [messages] must be in oldest-to-newest order.
  void prependAll(Iterable<WenzChatMessage> messages) {
    _ensureNotDisposed();
    final additions = messages.toList(growable: false);
    if (additions.isEmpty) return;
    _validateAdditions(additions);
    _slots.insertAll(0, additions.map(_MessageSlot.new));
    _rebuildIndex();
    _notifyStructure(WenzChatMutationType.prepend, additions);
  }

  /// Replaces one message without changing its stable id.
  ///
  /// Content-only updates are delivered directly to the affected cell. A
  /// sender, timestamp, or kind change also invalidates the list structure
  /// because it can change date separators and grouping.
  bool updateMessage(String id, WenzChatMessage replacement) {
    _ensureNotDisposed();
    final index = _indices[id];
    if (index == null) return false;
    if (replacement.id != id) {
      throw ArgumentError.value(
        replacement.id,
        'replacement.id',
        'The stable message id must remain $id.',
      );
    }
    final slot = _slots[index];
    final affectsLayout = !slot.message.hasSameLayoutIdentity(replacement);
    slot.notifier.value = replacement;
    _setMutation(WenzChatMutationType.update, <WenzChatMessage>[replacement]);
    if (affectsLayout) _structureVersion.value++;
    notifyListeners();
    return true;
  }

  /// Applies an update function when [id] exists.
  bool update(String id, WenzChatMessage Function(WenzChatMessage) transform) {
    final current = messageById(id);
    if (current == null) return false;
    return updateMessage(id, transform(current));
  }

  bool remove(String id) {
    _ensureNotDisposed();
    final index = _indices[id];
    if (index == null) return false;
    final removed = _slots.removeAt(index);
    _rebuildIndex();
    _notifyStructure(WenzChatMutationType.remove, <WenzChatMessage>[
      removed.message,
    ]);
    removed.dispose();
    return true;
  }

  /// Replaces the timeline while reusing per-message signals for retained ids.
  void replaceAll(Iterable<WenzChatMessage> messages) {
    _ensureNotDisposed();
    final replacements = messages.toList(growable: false);
    _validateUnique(replacements);

    final existing = <String, _MessageSlot>{
      for (final slot in _slots) slot.message.id: slot,
    };
    final next = <_MessageSlot>[];
    for (final message in replacements) {
      final retained = existing.remove(message.id);
      if (retained == null) {
        next.add(_MessageSlot(message));
      } else {
        retained.notifier.value = message;
        next.add(retained);
      }
    }
    for (final removed in existing.values) {
      removed.dispose();
    }
    _slots
      ..clear()
      ..addAll(next);
    _rebuildIndex();
    _notifyStructure(WenzChatMutationType.replaceAll, replacements);
  }

  void clear() {
    _ensureNotDisposed();
    if (_slots.isEmpty) return;
    final removed = _slots.map((slot) => slot.message).toList(growable: false);
    final oldSlots = List<_MessageSlot>.of(_slots);
    _slots.clear();
    _indices.clear();
    _notifyStructure(WenzChatMutationType.clear, removed);
    for (final slot in oldSlots) {
      slot.dispose();
    }
  }

  void _notifyStructure(
    WenzChatMutationType type,
    List<WenzChatMessage> messages,
  ) {
    _setMutation(type, messages);
    _structureVersion.value++;
    notifyListeners();
  }

  void _setMutation(WenzChatMutationType type, List<WenzChatMessage> messages) {
    _lastMutation = WenzChatMutation(
      sequence: ++_mutationSequence,
      type: type,
      messageIds: List<String>.unmodifiable(
        messages.map((message) => message.id),
      ),
    );
  }

  void _validateAdditions(List<WenzChatMessage> messages) {
    _validateUnique(messages);
    for (final message in messages) {
      if (_indices.containsKey(message.id)) {
        throw ArgumentError.value(
          message.id,
          'messages',
          'Message ids must be unique.',
        );
      }
    }
  }

  static void _validateUnique(List<WenzChatMessage> messages) {
    final ids = <String>{};
    for (final message in messages) {
      if (!ids.add(message.id)) {
        throw ArgumentError.value(
          message.id,
          'messages',
          'Message ids must be unique.',
        );
      }
    }
  }

  void _rebuildIndex() {
    _indices.clear();
    for (var index = 0; index < _slots.length; index++) {
      _indices[_slots[index].message.id] = index;
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('WenzChatController has already been disposed.');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final slot in _slots) {
      slot.dispose();
    }
    _structureVersion.dispose();
    super.dispose();
  }
}
