import 'dart:convert';

import '../position/document_position.dart';
import '../transaction/change_set.dart';
import 'command_executor.dart';
import 'editor_command.dart';

/// A named, argument-driven command factory registered with the editor.
///
/// Plugins register a [CommandDescriptor] via [CommandRegistry.register] so
/// they can contribute commands without editing [WenzRichTextController]'s
/// typed method surface. Arguments arrive as a JSON-decodable map; the
/// descriptor's [factory] turns them into an [EditorCommand].
class CommandDescriptor {
  const CommandDescriptor({required this.name, required this.factory});

  /// Unique command name, e.g. `'toggleBold'`.
  final String name;

  /// Builds the command from a JSON-like argument map.
  final EditorCommand Function(Map<String, Object?> args) factory;
}

/// Maps command names to [CommandDescriptor]s and dispatches execution.
///
/// Held by [WenzRichTextController]; the core executor is unchanged. Unknown
/// names throw an [ArgumentError] so callers can fall back to typed methods.
class CommandRegistry {
  CommandRegistry();

  final Map<String, CommandDescriptor> _descriptors =
      <String, CommandDescriptor>{};

  /// Registers [descriptor]. Replaces any prior descriptor with the same name.
  void register(CommandDescriptor descriptor) {
    _descriptors[descriptor.name] = descriptor;
  }

  /// Whether a command named [name] is registered.
  bool contains(String name) => _descriptors.containsKey(name);

  /// Builds the command named [name] from [args] and runs it through
  /// [executor]. Throws if [name] is not registered.
  ChangeSet execute(
    String name,
    Map<String, Object?> args,
    CommandExecutor executor,
  ) {
    final descriptor = _descriptors[name];
    if (descriptor == null) {
      throw ArgumentError('No command registered for name "$name".');
    }
    return executor.execute(descriptor.factory(args));
  }

  /// Convenience: build from a JSON string argument payload.
  ChangeSet executeFromJson(
    String name,
    String argsJson,
    CommandExecutor executor,
  ) {
    final decoded = jsonDecode(argsJson);
    if (decoded is! Map) {
      throw FormatException(
        'Command "$name" args must decode to a JSON object.',
      );
    }
    return execute(name, Map<String, Object?>.from(decoded), executor);
  }

  /// All registered command names.
  Iterable<String> get names => _descriptors.keys;
}

/// Helpers to read typed values out of a command argument map without crashing
/// when a key is missing or the wrong type.
extension CommandArgsRead on Map<String, Object?> {
  String? readString(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  int? readInt(String key) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  bool? readBool(String key) {
    final value = this[key];
    return value is bool ? value : null;
  }
}

/// Re-exported so external callers can resolve a [DocumentPosition] from args
/// without reaching into private model files.
DocumentPosition? positionFromArgs(Map<String, Object?> args) {
  final blockId = args.readString('blockId');
  final blockIndex = args.readInt('blockIndex');
  final offset = args.readInt('offset');
  if (blockId == null || blockIndex == null || offset == null) {
    return null;
  }
  return DocumentPosition.text(
    blockId: blockId,
    blockIndex: blockIndex,
    offset: offset,
  );
}
