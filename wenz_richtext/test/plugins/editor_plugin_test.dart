import 'package:flutter/widgets.dart';
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
              action: (_, __) {},
            ),
          ],
          toolbarItems: <WenzToolbarItem>[
            WenzToolbarItem(
              id: 'test.toolbar',
              title: 'Test Toolbar',
              action: (_, __) {},
              isEnabled: (state) => state.hasSelection,
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
      inlineEmbeds
          .buildTextSpan(
            _FakeBuildContext(),
            const InlineEmbed(embedType: 'token'),
            const TextStyle(),
          )
          ?.text,
      '[token]',
    );
    expect(slashMenu.items.map((item) => item.id), contains('test.item'));
    expect(toolbarItems.has('test.toolbar'), isTrue);
    expect(toolbarItems['test.toolbar']?.enabledFor(toolbar.state), isTrue);
    expect(controller.clipboardService.parse('plugin:value').text, 'value');
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
}

class _CountingMiddleware extends CommandMiddleware {}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
