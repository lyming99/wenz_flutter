import 'package:flutter/services.dart';

enum EditorShortcutDisposition {
  handled,
  ignored,
  passThrough,
}

enum EditorShortcutIntent {
  selectAll,
  undo,
  redo,
  copy,
  cut,
  paste,
  find,
  replace,
  toggleHeading1,
  toggleHeading2,
  toggleHeading3,
  toggleHeading4,
  toggleHeading5,
  toggleHeading6,
  toggleQuote,
  insertFormula,
  toggleCodeBlock,
  toggleTodo,
  cycleList,
  insertTable,
  insertLink,
  moveTableCellBackward,
  moveTableCellForward,
  moveCaretBackward,
  moveCaretForward,
  moveCaretUp,
  moveCaretDown,
  moveCaretToBlockStart,
  moveCaretToBlockEnd,
  moveCaretByWordBackward,
  moveCaretByWordForward,
  moveCaretToDocumentStart,
  moveCaretToDocumentEnd,
  pageUp,
  pageDown,
  deleteBackward,
  deleteForward,
  enter,
  insertCharacter,
  indent,
  outdent,
}

enum EditorShortcutModifier {
  shift,
  control,
  alt,
  meta,
  primary,
}

enum EditorShortcutPlatform {
  all,
  windows,
  macOS,
  linux,
  android,
  iOS,
  web,
}

enum EditorShortcutConfigurationIssueCode {
  duplicateShortcut,
  emptyPlatforms,
  invalidCharacter,
}

class EditorShortcutKey {
  const EditorShortcutKey(
    this.key, {
    this.modifiers = const <EditorShortcutModifier>{},
    this.platforms = const <EditorShortcutPlatform>{EditorShortcutPlatform.all},
  });

  final LogicalKeyboardKey key;
  final Set<EditorShortcutModifier> modifiers;
  final Set<EditorShortcutPlatform> platforms;

  bool matches({
    required LogicalKeyboardKey key,
    required bool shiftPressed,
    required bool controlPressed,
    required bool altPressed,
    required bool metaPressed,
    required bool primaryPressed,
    required EditorShortcutPlatform platform,
  }) {
    if (this.key != key || !_matchesPlatform(platform)) {
      return false;
    }
    final actual = <EditorShortcutModifier>{
      if (shiftPressed) EditorShortcutModifier.shift,
      if (controlPressed) EditorShortcutModifier.control,
      if (altPressed) EditorShortcutModifier.alt,
      if (metaPressed) EditorShortcutModifier.meta,
    };
    final expected = modifiers.toSet();
    if (expected.remove(EditorShortcutModifier.primary)) {
      if (!primaryPressed) {
        return false;
      }
      actual
        ..remove(EditorShortcutModifier.control)
        ..remove(EditorShortcutModifier.meta);
    }
    return _setEquals(actual, expected);
  }

  bool sameCombination(EditorShortcutKey other) {
    return key == other.key &&
        _setEquals(modifiers, other.modifiers) &&
        _setEquals(platforms, other.platforms);
  }

  bool _matchesPlatform(EditorShortcutPlatform platform) {
    return platforms.contains(EditorShortcutPlatform.all) ||
        platforms.contains(platform);
  }
}

class EditorShortcutBinding {
  const EditorShortcutBinding.handled({
    required this.shortcut,
    required EditorShortcutIntent intent,
    bool expandSelection = false,
    String? character,
  })  : _disposition = EditorShortcutDisposition.handled,
        _intent = intent,
        _expandSelection = expandSelection,
        _character = character;

  const EditorShortcutBinding.ignored({required this.shortcut})
      : _disposition = EditorShortcutDisposition.ignored,
        _intent = null,
        _expandSelection = false,
        _character = null;

  const EditorShortcutBinding.passThrough({required this.shortcut})
      : _disposition = EditorShortcutDisposition.passThrough,
        _intent = null,
        _expandSelection = false,
        _character = null;

  final EditorShortcutKey shortcut;
  final EditorShortcutDisposition _disposition;
  final EditorShortcutIntent? _intent;
  final bool _expandSelection;
  final String? _character;

  EditorShortcutResolution get resolution {
    return EditorShortcutResolution._(
      disposition: _disposition,
      intent: _intent,
      expandSelection: _expandSelection,
      character: _character,
    );
  }
}

class EditorShortcutConfiguration {
  const EditorShortcutConfiguration({
    this.bindings = const <EditorShortcutBinding>[],
    this.disabledIntents = const <EditorShortcutIntent>{},
  });

  final List<EditorShortcutBinding> bindings;
  final Set<EditorShortcutIntent> disabledIntents;

  static EditorShortcutConfiguration merge(
    Iterable<EditorShortcutConfiguration> configurations,
  ) {
    final bindings = <EditorShortcutBinding>[];
    final disabledIntents = <EditorShortcutIntent>{};
    for (final configuration in configurations) {
      bindings.addAll(configuration.bindings);
      disabledIntents.addAll(configuration.disabledIntents);
    }
    return EditorShortcutConfiguration(
      bindings: List<EditorShortcutBinding>.unmodifiable(bindings),
      disabledIntents: Set<EditorShortcutIntent>.unmodifiable(disabledIntents),
    );
  }

  List<EditorShortcutConfigurationIssue> validate() {
    final issues = <EditorShortcutConfigurationIssue>[];
    for (var i = 0; i < bindings.length; i++) {
      final binding = bindings[i];
      if (binding.shortcut.platforms.isEmpty) {
        issues.add(
          EditorShortcutConfigurationIssue(
            code: EditorShortcutConfigurationIssueCode.emptyPlatforms,
            bindingIndex: i,
            binding: binding,
          ),
        );
      }
      if (binding.resolution.intent == EditorShortcutIntent.insertCharacter &&
          !_isValidShortcutCharacter(binding.resolution.character)) {
        issues.add(
          EditorShortcutConfigurationIssue(
            code: EditorShortcutConfigurationIssueCode.invalidCharacter,
            bindingIndex: i,
            binding: binding,
          ),
        );
      }
      for (var previousIndex = 0; previousIndex < i; previousIndex++) {
        final previous = bindings[previousIndex];
        if (binding.shortcut.sameCombination(previous.shortcut)) {
          issues.add(
            EditorShortcutConfigurationIssue(
              code: EditorShortcutConfigurationIssueCode.duplicateShortcut,
              bindingIndex: i,
              binding: binding,
            ),
          );
          break;
        }
      }
    }
    return List<EditorShortcutConfigurationIssue>.unmodifiable(issues);
  }
}

class EditorShortcutConfigurationIssue {
  const EditorShortcutConfigurationIssue({
    required this.code,
    required this.bindingIndex,
    required this.binding,
  });

  final EditorShortcutConfigurationIssueCode code;
  final int bindingIndex;
  final EditorShortcutBinding binding;
}

class EditorShortcutResolution {
  const EditorShortcutResolution._({
    required this.disposition,
    this.intent,
    this.expandSelection = false,
    this.character,
  });

  const EditorShortcutResolution.handled(
    EditorShortcutIntent intent, {
    bool expandSelection = false,
    String? character,
  }) : this._(
          disposition: EditorShortcutDisposition.handled,
          intent: intent,
          expandSelection: expandSelection,
          character: character,
        );

  const EditorShortcutResolution.ignored()
      : this._(disposition: EditorShortcutDisposition.ignored);

  const EditorShortcutResolution.passThrough()
      : this._(disposition: EditorShortcutDisposition.passThrough);

  final EditorShortcutDisposition disposition;
  final EditorShortcutIntent? intent;
  final bool expandSelection;
  final String? character;
}

/// Resolves keyboard events into editor shortcut intents.
///
/// This class is pure keymap logic: it does not mutate the controller, touch the
/// clipboard, or know about widget state beyond the flags passed into [resolve].
///
/// Shortcut configuration must preserve this boundary: configuration can add,
/// override, disable, or pass through key combinations, but final execution
/// still happens through the returned [EditorShortcutResolution]. When a future
/// configuration object is supplied, it should keep the built-in keymap as the
/// default layer and apply caller overrides only during resolution.
class EditorShortcutManager {
  const EditorShortcutManager({
    this.configuration = const EditorShortcutConfiguration(),
    this.platform = EditorShortcutPlatform.all,
  });

  final EditorShortcutConfiguration configuration;
  final EditorShortcutPlatform platform;

  EditorShortcutResolution resolve(
    KeyEvent event, {
    required bool shiftPressed,
    required bool primaryPressed,
    required bool readOnly,
    required bool imeEnabled,
    required bool inputClientAttached,
    bool controlPressed = false,
    bool altPressed = false,
    bool metaPressed = false,
    bool findEnabled = false,
    bool replaceEnabled = false,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return const EditorShortcutResolution.ignored();
    }

    final configured = _resolveConfiguredShortcut(
      event.logicalKey,
      shiftPressed: shiftPressed,
      controlPressed: controlPressed,
      altPressed: altPressed,
      metaPressed: metaPressed,
      primaryPressed: primaryPressed,
      readOnly: readOnly,
      imeEnabled: imeEnabled,
      inputClientAttached: inputClientAttached,
    );
    if (configured != null) {
      return configured;
    }

    final defaultShortcut = _resolveDefaultShortcut(
      event.logicalKey,
      shiftPressed: shiftPressed,
      controlPressed: controlPressed,
      altPressed: altPressed,
      metaPressed: metaPressed,
      primaryPressed: primaryPressed,
      readOnly: readOnly,
    );
    if (defaultShortcut != null) {
      return defaultShortcut;
    }

    if (primaryPressed) {
      return _applyDisabledIntent(_resolvePrimaryShortcut(
        event.logicalKey,
        shiftPressed: shiftPressed,
        readOnly: readOnly,
        findEnabled: findEnabled,
        replaceEnabled: replaceEnabled,
      ));
    }

    if (readOnly) {
      return const EditorShortcutResolution.ignored();
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        shiftPressed
            ? EditorShortcutIntent.outdent
            : EditorShortcutIntent.indent,
      ));
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretBackward,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretForward,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretUp,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretDown,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.home) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToBlockStart,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.end) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToBlockEnd,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.pageUp) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.pageUp,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.pageDown) {
      return _applyDisabledIntent(EditorShortcutResolution.handled(
        EditorShortcutIntent.pageDown,
        expandSelection: shiftPressed,
      ));
    }
    if (key == LogicalKeyboardKey.backspace) {
      return _applyDisabledIntent(const EditorShortcutResolution.handled(
        EditorShortcutIntent.deleteBackward,
      ));
    }
    if (key == LogicalKeyboardKey.delete) {
      return _applyDisabledIntent(const EditorShortcutResolution.handled(
        EditorShortcutIntent.deleteForward,
      ));
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return _applyDisabledIntent(const EditorShortcutResolution.handled(
        EditorShortcutIntent.enter,
      ));
    }

    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        _isControlCharacter(character)) {
      return const EditorShortcutResolution.ignored();
    }
    if (imeEnabled || inputClientAttached) {
      return const EditorShortcutResolution.ignored();
    }
    return _applyDisabledIntent(EditorShortcutResolution.handled(
      EditorShortcutIntent.insertCharacter,
      character: character,
    ));
  }

  EditorShortcutResolution? _resolveConfiguredShortcut(
    LogicalKeyboardKey key, {
    required bool shiftPressed,
    required bool controlPressed,
    required bool altPressed,
    required bool metaPressed,
    required bool primaryPressed,
    required bool readOnly,
    required bool imeEnabled,
    required bool inputClientAttached,
  }) {
    for (final binding in configuration.bindings.reversed) {
      if (!binding.shortcut.matches(
        key: key,
        shiftPressed: shiftPressed,
        controlPressed: controlPressed,
        altPressed: altPressed,
        metaPressed: metaPressed,
        primaryPressed: primaryPressed,
        platform: platform,
      )) {
        continue;
      }
      final resolution = binding.resolution;
      if (resolution.intent == EditorShortcutIntent.insertCharacter &&
          (imeEnabled || inputClientAttached ||
              !_isValidShortcutCharacter(resolution.character))) {
        return const EditorShortcutResolution.ignored();
      }
      return _applyReadOnlyGuard(_applyDisabledIntent(resolution), readOnly);
    }
    return null;
  }

  EditorShortcutResolution? _resolveDefaultShortcut(
    LogicalKeyboardKey key, {
    required bool shiftPressed,
    required bool controlPressed,
    required bool altPressed,
    required bool metaPressed,
    required bool primaryPressed,
    required bool readOnly,
  }) {
    for (final binding in _defaultRichTextShortcutBindings) {
      if (!binding.shortcut.matches(
        key: key,
        shiftPressed: shiftPressed,
        controlPressed: controlPressed,
        altPressed: altPressed,
        metaPressed: metaPressed,
        primaryPressed: primaryPressed,
        platform: platform,
      )) {
        continue;
      }
      return _applyReadOnlyGuard(
        _applyDisabledIntent(binding.resolution),
        readOnly,
      );
    }
    return null;
  }

  EditorShortcutResolution _applyDisabledIntent(
    EditorShortcutResolution resolution,
  ) {
    final intent = resolution.intent;
    if (intent != null && configuration.disabledIntents.contains(intent)) {
      return const EditorShortcutResolution.ignored();
    }
    return resolution;
  }

  EditorShortcutResolution _applyReadOnlyGuard(
    EditorShortcutResolution resolution,
    bool readOnly,
  ) {
    if (!readOnly || resolution.disposition != EditorShortcutDisposition.handled) {
      return resolution;
    }
    final intent = resolution.intent;
    if (intent != null && _writeIntents.contains(intent)) {
      return const EditorShortcutResolution.ignored();
    }
    return resolution;
  }

  EditorShortcutResolution _resolvePrimaryShortcut(
    LogicalKeyboardKey key, {
    required bool shiftPressed,
    required bool readOnly,
    required bool findEnabled,
    required bool replaceEnabled,
  }) {
    if (key == LogicalKeyboardKey.keyA) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.selectAll,
      );
    }
    if (key == LogicalKeyboardKey.keyZ) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return EditorShortcutResolution.handled(
        shiftPressed ? EditorShortcutIntent.redo : EditorShortcutIntent.undo,
      );
    }
    if (key == LogicalKeyboardKey.keyY) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.redo,
      );
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretByWordBackward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretByWordForward,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.home) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToDocumentStart,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.end) {
      return EditorShortcutResolution.handled(
        EditorShortcutIntent.moveCaretToDocumentEnd,
        expandSelection: shiftPressed,
      );
    }
    if (key == LogicalKeyboardKey.keyC) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.copy,
      );
    }
    if (key == LogicalKeyboardKey.keyX) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(EditorShortcutIntent.cut);
    }
    if (key == LogicalKeyboardKey.keyV) {
      if (readOnly) {
        return const EditorShortcutResolution.ignored();
      }
      return const EditorShortcutResolution.handled(EditorShortcutIntent.paste);
    }
    if (key == LogicalKeyboardKey.keyF && findEnabled) {
      return const EditorShortcutResolution.handled(EditorShortcutIntent.find);
    }
    if (key == LogicalKeyboardKey.keyH && replaceEnabled && !readOnly) {
      return const EditorShortcutResolution.handled(
        EditorShortcutIntent.replace,
      );
    }
    return const EditorShortcutResolution.passThrough();
  }
}

bool _isControlCharacter(String character) {
  final codeUnit = character.codeUnitAt(0);
  return codeUnit < 0x20 || codeUnit == 0x7F;
}

bool _isValidShortcutCharacter(String? character) {
  return character != null &&
      character.length == 1 &&
      !_isControlCharacter(character);
}

bool _setEquals<T>(Set<T> left, Set<T> right) {
  return left.length == right.length && left.containsAll(right);
}

const Set<EditorShortcutModifier> _controlShortcutModifiers =
    <EditorShortcutModifier>{
  EditorShortcutModifier.control,
};

const Set<EditorShortcutModifier> _controlAltShortcutModifiers =
    <EditorShortcutModifier>{
  EditorShortcutModifier.control,
  EditorShortcutModifier.alt,
};

const Set<EditorShortcutModifier> _controlShiftShortcutModifiers =
    <EditorShortcutModifier>{
  EditorShortcutModifier.control,
  EditorShortcutModifier.shift,
};

const List<EditorShortcutBinding> _defaultRichTextShortcutBindings =
    <EditorShortcutBinding>[
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit1,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading1,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit2,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading2,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit3,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading3,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit4,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading4,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit5,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading5,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit6,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleHeading6,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit8,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleQuote,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.digit9,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.insertFormula,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.keyK,
      modifiers: _controlAltShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleCodeBlock,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.keyT,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.toggleTodo,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.keyI,
      modifiers: _controlShortcutModifiers,
    ),
    intent: EditorShortcutIntent.cycleList,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.keyT,
      modifiers: _controlShiftShortcutModifiers,
    ),
    intent: EditorShortcutIntent.insertTable,
  ),
  EditorShortcutBinding.handled(
    shortcut: EditorShortcutKey(
      LogicalKeyboardKey.keyL,
      modifiers: _controlShiftShortcutModifiers,
    ),
    intent: EditorShortcutIntent.insertLink,
  ),
];

const Set<EditorShortcutIntent> _writeIntents = <EditorShortcutIntent>{
  EditorShortcutIntent.undo,
  EditorShortcutIntent.redo,
  EditorShortcutIntent.cut,
  EditorShortcutIntent.paste,
  EditorShortcutIntent.replace,
  EditorShortcutIntent.toggleHeading1,
  EditorShortcutIntent.toggleHeading2,
  EditorShortcutIntent.toggleHeading3,
  EditorShortcutIntent.toggleHeading4,
  EditorShortcutIntent.toggleHeading5,
  EditorShortcutIntent.toggleHeading6,
  EditorShortcutIntent.toggleQuote,
  EditorShortcutIntent.insertFormula,
  EditorShortcutIntent.toggleCodeBlock,
  EditorShortcutIntent.toggleTodo,
  EditorShortcutIntent.cycleList,
  EditorShortcutIntent.insertTable,
  EditorShortcutIntent.insertLink,
  EditorShortcutIntent.moveTableCellBackward,
  EditorShortcutIntent.moveTableCellForward,
  EditorShortcutIntent.deleteBackward,
  EditorShortcutIntent.deleteForward,
  EditorShortcutIntent.enter,
  EditorShortcutIntent.insertCharacter,
  EditorShortcutIntent.indent,
  EditorShortcutIntent.outdent,
};
