import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  const manager = EditorShortcutManager();

  test('default rich-text shortcuts use the platform primary modifier', () {
    expect(defaultRichTextShortcutBindings, isNotEmpty);
    for (final binding in defaultRichTextShortcutBindings) {
      expect(
        binding.shortcut.modifiers,
        contains(EditorShortcutModifier.primary),
      );
      expect(
        binding.shortcut.modifiers,
        isNot(contains(EditorShortcutModifier.control)),
      );
      expect(
        binding.shortcut.modifiers,
        isNot(contains(EditorShortcutModifier.meta)),
      );
    }
  });

  EditorShortcutResolution resolve(
    KeyEvent event, {
    bool shift = false,
    bool primary = false,
    bool readOnly = false,
    bool imeEnabled = false,
    bool inputClientAttached = false,
    bool findEnabled = false,
    bool replaceEnabled = false,
  }) {
    return manager.resolve(
      event,
      shiftPressed: shift,
      primaryPressed: primary,
      readOnly: readOnly,
      imeEnabled: imeEnabled,
      inputClientAttached: inputClientAttached,
      findEnabled: findEnabled,
      replaceEnabled: replaceEnabled,
    );
  }

  EditorShortcutResolution resolveWith(
    EditorShortcutManager manager,
    KeyEvent event, {
    bool shift = false,
    bool primary = false,
    bool control = false,
    bool alt = false,
    bool meta = false,
    bool readOnly = false,
    bool imeEnabled = false,
    bool inputClientAttached = false,
    bool findEnabled = false,
    bool replaceEnabled = false,
  }) {
    return manager.resolve(
      event,
      shiftPressed: shift,
      primaryPressed: primary,
      controlPressed: control,
      altPressed: alt,
      metaPressed: meta,
      readOnly: readOnly,
      imeEnabled: imeEnabled,
      inputClientAttached: inputClientAttached,
      findEnabled: findEnabled,
      replaceEnabled: replaceEnabled,
    );
  }

  test('configuration overrides default binding with later match', () {
    const configured = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.keyA,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.primary
              },
            ),
            intent: EditorShortcutIntent.copy,
          ),
        ],
      ),
    );

    final result = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyA),
      primary: true,
    );

    expect(result.disposition, EditorShortcutDisposition.handled);
    expect(result.intent, EditorShortcutIntent.copy);
  });

  test('configuration adds exact modifier bindings', () {
    const configured = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.f2,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.shift,
                EditorShortcutModifier.alt,
              },
            ),
            intent: EditorShortcutIntent.find,
          ),
        ],
      ),
    );

    final match = resolveWith(
      configured,
      _down(LogicalKeyboardKey.f2),
      shift: true,
      alt: true,
    );
    final extraModifier = resolveWith(
      configured,
      _down(LogicalKeyboardKey.f2),
      shift: true,
      alt: true,
      control: true,
    );

    expect(match.intent, EditorShortcutIntent.find);
    expect(extraModifier.disposition, EditorShortcutDisposition.ignored);
  });

  test('configuration disables intents and passes through bindings', () {
    const configured = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.passThrough(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.keyS,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.primary
              },
            ),
          ),
        ],
        disabledIntents: <EditorShortcutIntent>{EditorShortcutIntent.paste},
      ),
    );

    final paste = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyV),
      primary: true,
    );
    final save = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyS),
      primary: true,
    );

    expect(paste.disposition, EditorShortcutDisposition.ignored);
    expect(save.disposition, EditorShortcutDisposition.passThrough);
  });

  test('configuration supports platform-specific primary shortcuts', () {
    const configured = EditorShortcutManager(
      platform: EditorShortcutPlatform.macOS,
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.keyP,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.primary
              },
              platforms: <EditorShortcutPlatform>{EditorShortcutPlatform.macOS},
            ),
            intent: EditorShortcutIntent.find,
          ),
        ],
      ),
    );

    final result = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyP),
      primary: true,
      meta: true,
    );

    expect(result.intent, EditorShortcutIntent.find);
  });

  test('configuration guards read-only writes and IME characters', () {
    const configured = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(LogicalKeyboardKey.keyD),
            intent: EditorShortcutIntent.deleteForward,
          ),
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(LogicalKeyboardKey.keyE),
            intent: EditorShortcutIntent.insertCharacter,
            character: 'e',
          ),
        ],
      ),
    );

    final readOnlyDelete = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyD),
      readOnly: true,
    );
    final imeCharacter = resolveWith(
      configured,
      _down(LogicalKeyboardKey.keyE),
      imeEnabled: true,
    );

    expect(readOnlyDelete.disposition, EditorShortcutDisposition.ignored);
    expect(imeCharacter.disposition, EditorShortcutDisposition.ignored);
  });

  test('configuration merge and validation are deterministic', () {
    const first = EditorShortcutConfiguration(
      bindings: <EditorShortcutBinding>[
        EditorShortcutBinding.handled(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyS,
            modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
          ),
          intent: EditorShortcutIntent.copy,
        ),
        EditorShortcutBinding.handled(
          shortcut: EditorShortcutKey(LogicalKeyboardKey.keyI),
          intent: EditorShortcutIntent.insertCharacter,
        ),
      ],
      disabledIntents: <EditorShortcutIntent>{EditorShortcutIntent.cut},
    );
    const second = EditorShortcutConfiguration(
      bindings: <EditorShortcutBinding>[
        EditorShortcutBinding.passThrough(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyS,
            modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
          ),
        ),
        EditorShortcutBinding.ignored(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyP,
            platforms: <EditorShortcutPlatform>{},
          ),
        ),
      ],
      disabledIntents: <EditorShortcutIntent>{EditorShortcutIntent.paste},
    );

    final merged =
        EditorShortcutConfiguration.merge(<EditorShortcutConfiguration>[
      first,
      second,
    ]);
    final issues = merged.validate();
    final resolved = resolveWith(
      EditorShortcutManager(configuration: merged),
      _down(LogicalKeyboardKey.keyS),
      primary: true,
    );

    expect(merged.bindings, hasLength(4));
    expect(merged.disabledIntents, contains(EditorShortcutIntent.cut));
    expect(merged.disabledIntents, contains(EditorShortcutIntent.paste));
    expect(resolved.disposition, EditorShortcutDisposition.passThrough);
    expect(
      issues.map((issue) => issue.code),
      containsAll(<EditorShortcutConfigurationIssueCode>[
        EditorShortcutConfigurationIssueCode.duplicateShortcut,
        EditorShortcutConfigurationIssueCode.invalidCharacter,
        EditorShortcutConfigurationIssueCode.emptyPlatforms,
      ]),
    );
  });

  test('ignores key-up events', () {
    final result = resolve(_up(LogicalKeyboardKey.keyA));

    expect(result.disposition, EditorShortcutDisposition.ignored);
    expect(result.intent, isNull);
  });

  test('allows select-all in read-only mode', () {
    final result = resolve(
      _down(LogicalKeyboardKey.keyA),
      primary: true,
      readOnly: true,
    );

    expect(result.disposition, EditorShortcutDisposition.handled);
    expect(result.intent, EditorShortcutIntent.selectAll);
  });

  test('passes through unknown primary shortcuts', () {
    final result = resolve(_down(LogicalKeyboardKey.keyS), primary: true);

    expect(result.disposition, EditorShortcutDisposition.passThrough);
    expect(result.intent, isNull);
  });

  test('keeps default shortcut baseline without configuration', () {
    const expectations = <_ShortcutExpectation>[
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyA, EditorShortcutIntent.selectAll),
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyC, EditorShortcutIntent.copy),
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyX, EditorShortcutIntent.cut),
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyV, EditorShortcutIntent.paste),
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyZ, EditorShortcutIntent.undo),
      _ShortcutExpectation.primary(
          LogicalKeyboardKey.keyY, EditorShortcutIntent.redo),
      _ShortcutExpectation.primary(
        LogicalKeyboardKey.arrowLeft,
        EditorShortcutIntent.moveCaretByWordBackward,
      ),
      _ShortcutExpectation.primary(
        LogicalKeyboardKey.arrowRight,
        EditorShortcutIntent.moveCaretByWordForward,
      ),
      _ShortcutExpectation.primary(
        LogicalKeyboardKey.home,
        EditorShortcutIntent.moveCaretToDocumentStart,
      ),
      _ShortcutExpectation.primary(
        LogicalKeyboardKey.end,
        EditorShortcutIntent.moveCaretToDocumentEnd,
      ),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.arrowLeft, EditorShortcutIntent.moveCaretBackward),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.arrowRight, EditorShortcutIntent.moveCaretForward),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.arrowUp, EditorShortcutIntent.moveCaretUp),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.arrowDown, EditorShortcutIntent.moveCaretDown),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.home, EditorShortcutIntent.moveCaretToBlockStart),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.end, EditorShortcutIntent.moveCaretToBlockEnd),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.pageUp, EditorShortcutIntent.pageUp),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.pageDown, EditorShortcutIntent.pageDown),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.backspace, EditorShortcutIntent.deleteBackward),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.delete, EditorShortcutIntent.deleteForward),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.enter, EditorShortcutIntent.enter),
      _ShortcutExpectation.plain(
          LogicalKeyboardKey.keyA, EditorShortcutIntent.insertCharacter,
          character: 'a'),
    ];

    for (final expectation in expectations) {
      final result = resolve(
        _down(expectation.key, character: expectation.character),
        primary: expectation.primary,
      );
      expect(result.disposition, EditorShortcutDisposition.handled);
      expect(result.intent, expectation.intent);
      if (expectation.character != null) {
        expect(result.character, expectation.character);
      }
    }
  });

  test('blocks undo and paste in read-only mode', () {
    final undo = resolve(
      _down(LogicalKeyboardKey.keyZ),
      primary: true,
      readOnly: true,
    );
    final paste = resolve(
      _down(LogicalKeyboardKey.keyV),
      primary: true,
      readOnly: true,
    );

    expect(undo.disposition, EditorShortcutDisposition.ignored);
    expect(paste.disposition, EditorShortcutDisposition.ignored);
  });

  test('maps primary shift z to redo', () {
    final result = resolve(
      _down(LogicalKeyboardKey.keyZ),
      primary: true,
      shift: true,
    );

    expect(result.intent, EditorShortcutIntent.redo);
  });

  test('maps find and replace only when enabled', () {
    final disabled = resolve(_down(LogicalKeyboardKey.keyF), primary: true);
    final findEnabled = resolve(
      _down(LogicalKeyboardKey.keyF),
      primary: true,
      findEnabled: true,
    );
    final replaceEnabled = resolve(
      _down(LogicalKeyboardKey.keyH),
      primary: true,
      replaceEnabled: true,
    );
    final readOnlyReplace = resolve(
      _down(LogicalKeyboardKey.keyH),
      primary: true,
      readOnly: true,
      replaceEnabled: true,
    );

    expect(disabled.disposition, EditorShortcutDisposition.passThrough);
    expect(findEnabled.intent, EditorShortcutIntent.find);
    expect(replaceEnabled.intent, EditorShortcutIntent.replace);
    expect(readOnlyReplace.disposition, EditorShortcutDisposition.passThrough);
  });

  test('maps primary arrow with shift to word movement with expansion', () {
    final result = resolve(
      _down(LogicalKeyboardKey.arrowLeft),
      primary: true,
      shift: true,
    );

    expect(result.intent, EditorShortcutIntent.moveCaretByWordBackward);
    expect(result.expandSelection, isTrue);
  });

  test('maps shift tab to outdent outside widget table context', () {
    final result = resolve(_down(LogicalKeyboardKey.tab), shift: true);

    expect(result.intent, EditorShortcutIntent.outdent);
  });

  test('maps key repeat navigation events', () {
    final result = resolve(_repeat(LogicalKeyboardKey.arrowRight));

    expect(result.disposition, EditorShortcutDisposition.handled);
    expect(result.intent, EditorShortcutIntent.moveCaretForward);
  });

  test('maps plain character only when IME is not active', () {
    final character = resolve(_down(LogicalKeyboardKey.keyA, character: 'a'));
    final ime = resolve(
      _down(LogicalKeyboardKey.keyA, character: 'a'),
      imeEnabled: true,
    );
    final attached = resolve(
      _down(LogicalKeyboardKey.keyA, character: 'a'),
      inputClientAttached: true,
    );

    expect(character.intent, EditorShortcutIntent.insertCharacter);
    expect(character.character, 'a');
    expect(ime.disposition, EditorShortcutDisposition.ignored);
    expect(attached.disposition, EditorShortcutDisposition.ignored);
  });

  test('maps ctrl enter shortcuts to insert text block intents', () {
    final below = resolveWith(
      manager,
      _down(LogicalKeyboardKey.enter),
      primary: true,
      control: true,
    );
    final numpadBelow = resolveWith(
      manager,
      _down(LogicalKeyboardKey.numpadEnter),
      primary: true,
      control: true,
    );
    final above = resolveWith(
      manager,
      _down(LogicalKeyboardKey.enter),
      shift: true,
      primary: true,
      control: true,
    );
    final numpadAbove = resolveWith(
      manager,
      _down(LogicalKeyboardKey.numpadEnter),
      shift: true,
      primary: true,
      control: true,
    );
    final plainEnter = resolve(_down(LogicalKeyboardKey.enter));

    expect(below.intent, EditorShortcutIntent.insertTextBlockBelow);
    expect(numpadBelow.intent, EditorShortcutIntent.insertTextBlockBelow);
    expect(above.intent, EditorShortcutIntent.insertTextBlockAbove);
    expect(numpadAbove.intent, EditorShortcutIntent.insertTextBlockAbove);
    expect(plainEnter.intent, EditorShortcutIntent.enter);
  });

  test('guards insert text block shortcuts in read-only and disabled intents',
      () {
    const disabled = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        disabledIntents: <EditorShortcutIntent>{
          EditorShortcutIntent.insertTextBlockAbove,
          EditorShortcutIntent.insertTextBlockBelow,
        },
      ),
    );

    final readOnlyBelow = resolveWith(
      manager,
      _down(LogicalKeyboardKey.enter),
      primary: true,
      control: true,
      readOnly: true,
    );
    final readOnlyAbove = resolveWith(
      manager,
      _down(LogicalKeyboardKey.enter),
      shift: true,
      primary: true,
      control: true,
      readOnly: true,
    );
    final disabledBelow = resolveWith(
      disabled,
      _down(LogicalKeyboardKey.enter),
      primary: true,
      control: true,
    );
    final disabledAbove = resolveWith(
      disabled,
      _down(LogicalKeyboardKey.enter),
      shift: true,
      primary: true,
      control: true,
    );

    expect(readOnlyBelow.disposition, EditorShortcutDisposition.ignored);
    expect(readOnlyAbove.disposition, EditorShortcutDisposition.ignored);
    expect(disabledBelow.disposition, EditorShortcutDisposition.ignored);
    expect(disabledAbove.disposition, EditorShortcutDisposition.ignored);
  });

  test(
      'configuration can override ignore or pass through insert text block shortcuts',
      () {
    const configured = EditorShortcutManager(
      configuration: EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.enter,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.control,
              },
            ),
            intent: EditorShortcutIntent.copy,
          ),
          EditorShortcutBinding.ignored(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.enter,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.control,
                EditorShortcutModifier.shift,
              },
            ),
          ),
          EditorShortcutBinding.passThrough(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.numpadEnter,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.control,
              },
            ),
          ),
        ],
      ),
    );

    final overridden = resolveWith(
      configured,
      _down(LogicalKeyboardKey.enter),
      primary: true,
      control: true,
    );
    final ignored = resolveWith(
      configured,
      _down(LogicalKeyboardKey.enter),
      shift: true,
      primary: true,
      control: true,
    );
    final passThrough = resolveWith(
      configured,
      _down(LogicalKeyboardKey.numpadEnter),
      primary: true,
      control: true,
    );

    expect(overridden.disposition, EditorShortcutDisposition.handled);
    expect(overridden.intent, EditorShortcutIntent.copy);
    expect(ignored.disposition, EditorShortcutDisposition.ignored);
    expect(passThrough.disposition, EditorShortcutDisposition.passThrough);
  });

  test('ignores control characters', () {
    final result = resolve(
      _down(LogicalKeyboardKey.enter, character: '\n'),
    );

    expect(result.intent, EditorShortcutIntent.enter);

    final control = resolve(
      _down(LogicalKeyboardKey.keyA, character: '\u0001'),
    );
    expect(control.disposition, EditorShortcutDisposition.ignored);
  });
}

class _ShortcutExpectation {
  const _ShortcutExpectation.plain(
    this.key,
    this.intent, {
    this.character,
  }) : primary = false;

  const _ShortcutExpectation.primary(
    this.key,
    this.intent,
  )   : primary = true,
        character = null;

  final LogicalKeyboardKey key;
  final EditorShortcutIntent intent;
  final bool primary;
  final String? character;
}

KeyDownEvent _down(LogicalKeyboardKey key, {String? character}) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
    character: character,
  );
}

KeyRepeatEvent _repeat(LogicalKeyboardKey key, {String? character}) {
  return KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
    character: character,
  );
}

KeyUpEvent _up(LogicalKeyboardKey key) {
  return KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}
