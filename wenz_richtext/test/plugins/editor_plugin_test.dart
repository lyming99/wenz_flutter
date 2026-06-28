import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

void main() {
  test('plugin bundle installs every public extension registry', () {
    final pasteTransformers = <ClipboardPasteTransformer>[];
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
      clipboardService: ClipboardService(
        pasteTransformers: pasteTransformers,
      ),
    );
    final blockRenderers = BlockRendererRegistry();
    final inlineEmbeds = InlineEmbedRendererRegistry();
    final slashMenu = SlashMenuRegistry();
    final toolbarItems = WenzToolbarItemRegistry();
    final shortcutConfigurations = <EditorShortcutConfiguration>[];
    final toolbar = ToolbarController(controller);
    addTearDown(toolbar.dispose);

    installWenzRichTextPlugins(
      plugins: <WenzRichTextPlugin>[
        WenzPluginBundle(
          id: 'test.bundle',
          commands: <CommandDescriptor>[
            CommandDescriptor(
              name: 'test.insert',
              factory: (args) =>
                  InsertTextCommand(args.readString('text') ?? 'plugin'),
            ),
          ],
          middlewares: <CommandMiddleware>[_CountingMiddleware()],
          blockRenderers: <BlockType, BlockRendererBuilder>{
            BlockType.quote: (_, __) => const SizedBox.shrink(),
          },
          blockEmbedRenderers: <String, BlockRendererBuilder>{
            'crm-card': (_, __) => const SizedBox.shrink(),
          },
          inlineEmbedRenderers: <String, InlineEmbedSpanBuilder>{
            'token': (_, embed, __) => TextSpan(text: '[${embed.embedType}]'),
          },
          slashMenuItems: <SlashMenuItem>[
            SlashMenuItem(
              id: 'test.item',
              title: 'Test Item',
              icon: 'extension',
              keywords: const <String>['plugin'],
              action: (_, __) {},
            ),
            SlashMenuItem(
              id: 'test.hidden',
              title: 'Hidden Item',
              icon: 'extension',
              keywords: const <String>['plugin'],
              action: (_, __) {},
            ),
          ],
          slashMenuFilters: <SlashMenuItemFilter>[
            (item, query) => item.id != 'test.hidden',
          ],
          slashMenuSorter: (a, b, query) => b.id.compareTo(a.id),
          toolbarItems: <WenzToolbarItem>[
            WenzToolbarItem(
              id: 'test.toolbar',
              title: 'Test Toolbar',
              action: (_, __) {},
              isEnabled: (state) => state.hasSelection,
            ),
          ],
          shortcutConfigurations: <EditorShortcutConfiguration>[
            const EditorShortcutConfiguration(
              bindings: <EditorShortcutBinding>[
                EditorShortcutBinding.handled(
                  shortcut: EditorShortcutKey(
                    LogicalKeyboardKey.keyK,
                    modifiers: <EditorShortcutModifier>{
                      EditorShortcutModifier.primary,
                    },
                  ),
                  intent: EditorShortcutIntent.find,
                ),
              ],
            ),
          ],
          pasteTransformers: <ClipboardPasteTransformer>[
            ClipboardPasteTransformer(
              id: 'test.paste',
              transform: (context) {
                if (!context.raw.startsWith('plugin:')) {
                  return null;
                }
                return ClipboardPaste.plain(
                  context.raw.substring('plugin:'.length),
                );
              },
            ),
          ],
        ),
      ],
      context: WenzPluginContext(
        controller: controller,
        blockRenderers: blockRenderers,
        inlineEmbedRenderers: inlineEmbeds,
        slashMenuRegistry: slashMenu,
        toolbarItems: toolbarItems,
        shortcutConfigurations: shortcutConfigurations,
        pasteTransformers: pasteTransformers,
      ),
    );

    expect(controller.registry.contains('test.insert'), isTrue);
    controller.executeCommand('test.insert', <String, Object?>{'text': 'ok'});
    expect(controller.document.plainText, 'ok');
    expect(controller.middlewares.single, isA<_CountingMiddleware>());

    expect(blockRenderers.has(BlockType.quote), isTrue);
    expect(blockRenderers.hasEmbed('crm-card'), isTrue);
    expect(inlineEmbeds.has('token'), isTrue);
    expect(
      (inlineEmbeds.buildTextSpan(
        _FakeBuildContext(),
        const InlineEmbed(embedType: 'token'),
        const TextStyle(),
      ) as TextSpan?)
          ?.text,
      '[token]',
    );
    expect(slashMenu.items.map((item) => item.id), contains('test.item'));
    expect(slashMenu.items.map((item) => item.id), contains('test.hidden'));
    expect(slashMenu.filter('plugin').map((item) => item.id), <String>[
      'test.item',
    ]);
    expect(toolbarItems.has('test.toolbar'), isTrue);
    expect(toolbarItems['test.toolbar']?.enabledFor(toolbar.state), isTrue);
    expect(shortcutConfigurations, hasLength(1));
    expect(
      shortcutConfigurations.single.bindings.single.resolution.intent,
      EditorShortcutIntent.find,
    );
    expect(controller.clipboardService.parse('plugin:value').text, 'value');
  });

  test('plugin shortcuts merge before explicit editor configuration', () {
    const firstPlugin = EditorShortcutConfiguration(
      bindings: <EditorShortcutBinding>[
        EditorShortcutBinding.handled(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyS,
            modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
          ),
          intent: EditorShortcutIntent.copy,
        ),
      ],
    );
    const secondPlugin = EditorShortcutConfiguration(
      bindings: <EditorShortcutBinding>[
        EditorShortcutBinding.ignored(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyS,
            modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
          ),
        ),
      ],
    );
    const editor = EditorShortcutConfiguration(
      bindings: <EditorShortcutBinding>[
        EditorShortcutBinding.passThrough(
          shortcut: EditorShortcutKey(
            LogicalKeyboardKey.keyS,
            modifiers: <EditorShortcutModifier>{EditorShortcutModifier.primary},
          ),
        ),
      ],
      disabledIntents: <EditorShortcutIntent>{EditorShortcutIntent.paste},
    );

    final merged = mergeWenzShortcutConfigurations(
      pluginConfigurations: const <EditorShortcutConfiguration>[
        firstPlugin,
        secondPlugin,
      ],
      editorConfiguration: editor,
    );
    final manager = EditorShortcutManager(configuration: merged);
    final save = manager.resolve(
      _down(LogicalKeyboardKey.keyS),
      shiftPressed: false,
      primaryPressed: true,
      readOnly: false,
      imeEnabled: false,
      inputClientAttached: false,
    );
    final paste = manager.resolve(
      _down(LogicalKeyboardKey.keyV),
      shiftPressed: false,
      primaryPressed: true,
      readOnly: false,
      imeEnabled: false,
      inputClientAttached: false,
    );

    expect(merged.bindings, hasLength(3));
    expect(merged.validate().map((issue) => issue.code), contains(
      EditorShortcutConfigurationIssueCode.duplicateShortcut,
    ));
    expect(save.disposition, EditorShortcutDisposition.passThrough);
    expect(paste.disposition, EditorShortcutDisposition.ignored);
  });

  testWidgets('plugin renderers and media resolvers skip collapsed descendants',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Section')],
          ),
          TextBlockNode(
            id: 'hidden-p',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden paragraph')],
          ),
          ImageBlockNode(id: 'hidden-img', assetId: 'hidden-asset'),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Next')],
          ),
          TextBlockNode(
            id: 'visible-p',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Visible paragraph')],
          ),
          ImageBlockNode(id: 'visible-img', assetId: 'visible-asset'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('section'), isTrue);

    final builtBlockIds = <String>[];
    dynamic seenGeometryRegistry;
    final blockRenderers = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(blockRenderers);
    final mediaResolver = _RecordingMediaResolver();
    installWenzRichTextPlugins(
      plugins: <WenzRichTextPlugin>[
        WenzPluginBundle(
          id: 'collapse.extensions',
          blockRenderers: <BlockType, BlockRendererBuilder>{
            BlockType.paragraph: (context, renderContext) {
              builtBlockIds.add(renderContext.block.id);
              seenGeometryRegistry = renderContext.registry;
              return Text('plugin:${renderContext.block.id}');
            },
          },
        ),
      ],
      context: WenzPluginContext(
        controller: controller,
        blockRenderers: blockRenderers,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 720,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              blockRenderers: blockRenderers,
              mediaResolver: mediaResolver,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(builtBlockIds, contains('visible-p'));
    expect(builtBlockIds, isNot(contains('hidden-p')));
    expect(mediaResolver.seenBlockIds, contains('visible-img'));
    expect(mediaResolver.seenBlockIds, isNot(contains('hidden-img')));
    expect(find.text('plugin:hidden-p'), findsNothing);
    expect(find.text('resolved:hidden-img'), findsNothing);

    Iterable<String> rowBlockIds() {
      final entries = seenGeometryRegistry.rowEntries as Iterable<dynamic>;
      return entries.map((entry) => entry.blockId as String);
    }

    expect(rowBlockIds(), contains('visible-p'));
    expect(rowBlockIds(), isNot(contains('hidden-p')));
    expect(rowBlockIds(), isNot(contains('hidden-img')));

    builtBlockIds.clear();
    mediaResolver.seenBlockIds.clear();
    expect(outline.expandByBlockId('section'), isTrue);
    await tester.pump();

    expect(builtBlockIds, contains('hidden-p'));
    expect(mediaResolver.seenBlockIds, contains('hidden-img'));
    expect(find.text('plugin:hidden-p'), findsOneWidget);
    expect(find.text('resolved:hidden-img'), findsOneWidget);
    expect(rowBlockIds(), contains('hidden-p'));
    expect(rowBlockIds(), contains('hidden-img'));
  });

  test('plugin batch rejects duplicate ids', () {
    final controller = WenzRichTextController();
    const plugin = WenzPluginBundle(id: 'dup');

    expect(
      () => installWenzRichTextPlugins(
        plugins: <WenzRichTextPlugin>[plugin, plugin],
        context: WenzPluginContext(controller: controller),
      ),
      throwsStateError,
    );
  });

  test('plugin context exposes slash menu registry extension helpers', () {
    final controller = WenzRichTextController();
    final slashMenu = SlashMenuRegistry();
    final context = WenzPluginContext(
      controller: controller,
      slashMenuRegistry: slashMenu,
    );

    context.registerSlashMenuItems(<SlashMenuItem>[
      SlashMenuItem(
        id: 'b',
        title: 'B item',
        icon: 'extension',
        keywords: const <String>['custom'],
        action: (_, __) {},
      ),
      SlashMenuItem(
        id: 'a',
        title: 'A item',
        icon: 'extension',
        keywords: const <String>['custom'],
        action: (_, __) {},
      ),
    ]);
    context.addSlashMenuFilter((item, query) => item.id != 'b');
    context.setSlashMenuSorter((a, b, query) => a.id.compareTo(b.id));

    expect(slashMenu.filter('custom').map((item) => item.id), <String>['a']);
  });

  test('plugin context rejects slash extensions without registry', () {
    final context = WenzPluginContext(controller: WenzRichTextController());

    expect(
      () => context.addSlashMenuFilter((item, query) => true),
      throwsStateError,
    );
    expect(
      () => context.setSlashMenuSorter(null),
      throwsStateError,
    );
  });
}

KeyDownEvent _down(LogicalKeyboardKey key) {
  return KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );
}

class _CountingMiddleware extends CommandMiddleware {}

class _RecordingMediaResolver implements MediaResolver {
  final List<String> seenBlockIds = <String>[];

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    seenBlockIds.add(block.id);
    return Text('resolved:${block.id}');
  }
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
