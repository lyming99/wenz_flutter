import 'dart:convert';

import '../../codecs/document_errors.dart';
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
/// names throw an [UnknownCommandException] so callers can fall back to typed
/// methods (or use `WenzRichTextController.tryExecuteCommand` for a no-throw
/// entry point).
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

  /// Builds the command named [name] from [args]. Throws
  /// [UnknownCommandException] if [name] is not registered. Exposed so callers
  /// (e.g. [WenzRichTextController]) can route the resulting [EditorCommand]
  /// through their own execution path while still benefiting from argument
  /// decoding.
  EditorCommand build(String name, Map<String, Object?> args) {
    final descriptor = _descriptors[name];
    if (descriptor == null) {
      throw UnknownCommandException(name);
    }
    return descriptor.factory(args);
  }

  /// Builds the command named [name] from [args] and runs it through
  /// [executor]. Throws if [name] is not registered.
  ChangeSet execute(
    String name,
    Map<String, Object?> args,
    CommandExecutor executor,
  ) {
    return executor.execute(build(name, args));
  }

  /// Convenience: build from a JSON string argument payload. Throws
  /// [DocumentDecodeException] when [argsJson] is malformed or not a JSON
  /// object, and [UnknownCommandException] when [name] is not registered.
  ChangeSet executeFromJson(
    String name,
    String argsJson,
    CommandExecutor executor,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(argsJson);
    } on FormatException catch (error) {
      throw DocumentDecodeException(
        'Command "$name" args are not valid JSON.',
        raw: error,
      );
    }
    if (decoded is! Map) {
      throw DocumentDecodeException(
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
