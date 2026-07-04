import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

/// P006 — integration coverage for the standard external interface
/// (`WenzEditorConfiguration` + `WenzEditorBootstrap`). Exercises zero-config
/// assembly, end-to-end widget + data I/O, permission gating, extension
/// injection, and lifecycle `dispose`. See the P006 acceptance bullets in
/// `docs/plan/plan_requirement_57_20260628-150959.md`.
void main() {
  group('zero-config assembly', () {
    test('create() wires controller, registries, and default derived controllers',
        () {
      final bootstrap =
          WenzEditorBootstrap.create(const WenzEditorConfiguration());
      addTearDown(bootstrap.dispose);

      // Controller assembled with a normalised empty document and edit
      // permission — `WenzEditorConfiguration()` is runnable as-is.
      final document = bootstrap.document;
      expect(document.blocks, hasLength(1));
      final onlyBlock = document.blocks.single;
      expect(onlyBlock, isA<TextBlockNode>());
      expect((onlyBlock as TextBlockNode).type, BlockType.paragraph);
      expect(document.plainText, isEmpty);
      expect(bootstrap.controller.permission, WenzEditorPermission.edit);

      // Registries seeded with the built-in defaults so hosts get a complete
      // surface before contributing any extensions.
      expect(bootstrap.blockRendererRegistry.has(BlockType.paragraph), isTrue);
      expect(bootstrap.blockRendererRegistry.has(BlockType.heading), isTrue);
      expect(bootstrap.slashMenuRegistry.contains('list'), isTrue);
      expect(bootstrap.slashMenuRegistry.contains('table'), isTrue);

      // Default-on derived controllers exist; autosave is opt-in (no sink).
      expect(bootstrap.toolbarController, isNotNull);
      expect(bootstrap.slashMenuController, isNotNull);
      expect(bootstrap.findReplaceController, isNotNull);
      expect(bootstrap.outlineController, isNotNull);
      expect(bootstrap.statsController, isNotNull);
      expect(bootstrap.autosaveController, isNull);
    });

    test('data I/O delegates forward to the controller verbatim', () {
      final bootstrap = WenzEditorBootstrap.create(
        const WenzEditorConfiguration(
          document: RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Hello')],
              ),
            ],
          ),
        ),
      );
      addTearDown(bootstrap.dispose);

      expect(bootstrap.toPlainText(), 'Hello');
      expect(bootstrap.toMarkdown(), 'Hello');
      expect(bootstrap.toJson(), contains('Hello'));
      expect(bootstrap.toHtml(), contains('Hello'));
    });
  });

  group('default desktop toolbar factory', () {
    test('buildDefaultDesktopToolbar reuses assembled controller and registry',
        () {
      final pluginOnly = WenzToolbarItem(
        id: 'plugin-only',
        title: 'Plugin only',
        priority: 2,
        action: (_, __) {},
      );
      final pluginShared = WenzToolbarItem(
        id: 'shared',
        title: 'Plugin shared',
        priority: 1,
        action: (_, __) {},
      );
      final hostShared = WenzToolbarItem(
        id: 'shared',
        title: 'Host shared',
        priority: 0,
        action: (_, __) {},
      );
      final explicit = WenzToolbarItem(
        id: 'explicit',
        title: 'Explicit',
        priority: -1,
        action: (_, __) {},
      );
      const style = WenzDefaultDesktopToolbarStyle(showBottomBorder: false);
      const actions = WenzDefaultDesktopToolbarActions(
        imageUnavailablePolicy:
            WenzDefaultDesktopToolbarUnavailablePolicy.disable,
      );

      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          plugins: <WenzRichTextPlugin>[
            WenzPluginBundle(
              id: 'toolbar.plugin',
              toolbarItems: <WenzToolbarItem>[pluginOnly, pluginShared],
            ),
          ],
          toolbarItems: <WenzToolbarItem>[hostShared],
        ),
      );
      addTearDown(bootstrap.dispose);

      expect(bootstrap.toolbarItemRegistry['shared'], same(hostShared));
      expect(bootstrap.toolbarItemRegistry['plugin-only'], same(pluginOnly));

      final toolbar = bootstrap.buildDefaultDesktopToolbar(
        actions: actions,
        style: style,
        toolbarItems: <WenzToolbarItem>[explicit],
      );

      expect(toolbar.controller, same(bootstrap.controller));
      expect(toolbar.toolbar, same(bootstrap.toolbarController));
      expect(toolbar.toolbarItemRegistry, same(bootstrap.toolbarItemRegistry));
      expect(toolbar.actions, same(actions));
      expect(toolbar.style, same(style));
      expect(
        toolbar.effectiveToolbarItems.map((item) => item.id),
        <String>['explicit', 'shared', 'plugin-only'],
      );
      expect(toolbar.effectiveToolbarItems[1].title, 'Host shared');
    });

    test('buildDefaultDesktopToolbar throws when toolbar is disabled', () {
      final bootstrap = WenzEditorBootstrap.create(
        const WenzEditorConfiguration(enableToolbar: false),
      );
      addTearDown(bootstrap.dispose);

      expect(bootstrap.toolbarController, isNull);
      expect(
        bootstrap.buildDefaultDesktopToolbar,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('enableToolbar=true'),
          ),
        ),
      );
    });

    testWidgets('configuration and plugin toolbar items render in helper', (
      tester,
    ) async {
      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          plugins: <WenzRichTextPlugin>[
            WenzPluginBundle(
              id: 'toolbar.plugin.render',
              toolbarItems: <WenzToolbarItem>[
                WenzToolbarItem(
                  id: 'plugin-action',
                  title: 'Plugin action',
                  tooltip: 'Plugin action',
                  action: (_, __) {},
                ),
              ],
            ),
          ],
          toolbarItems: <WenzToolbarItem>[
            WenzToolbarItem(
              id: 'host-action',
              title: 'Host action',
              tooltip: 'Host action',
              action: (_, __) {},
            ),
          ],
        ),
      );
      addTearDown(bootstrap.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: bootstrap.buildDefaultDesktopToolbar()),
        ),
      );
      await tester.pump();

      expect(find.byType(WenzDefaultDesktopToolbar), findsOneWidget);
      expect(find.byTooltip('Plugin action'), findsOneWidget);
      expect(find.byTooltip('Host action'), findsOneWidget);
    });
  });

  group('widget and data integration', () {
    testWidgets('buildEditor renders, edits, and round-trips rich JSON',
        (tester) async {
      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Hello')],
              ),
            ],
          ),
          selection: collapsedTextSelection('p1', 0, 5),
        ),
      );
      addTearDown(bootstrap.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: bootstrap.buildEditor(enableIme: false)),
        ),
      );
      await tester.pump();

      // The wired widget renders the initial document. The editor paints text
      // as RichText (not plain Text), so match on the RichText plain text.
      expect(_richText('Hello'), findsOneWidget);

      // Drive an edit through the assembled controller and read the selection.
      bootstrap.controller.insertText('!');
      await tester.pump();
      expect(bootstrap.document.plainText, 'Hello!');
      expect(bootstrap.selection?.extent.offset, 6);

      // Export via the facade, import into a fresh bootstrap, verify equality.
      final exported = bootstrap.toJson();
      final roundTrip =
          WenzEditorBootstrap.create(const WenzEditorConfiguration());
      addTearDown(roundTrip.dispose);
      final result = roundTrip.tryLoadJson(exported);
      expect(result.ok, isTrue);
      expect(roundTrip.document.plainText, 'Hello!');
      // The rich-JSON codec round-trips byte-for-byte for this document.
      expect(roundTrip.toJson(), exported);
    });

    testWidgets('mention search and tap callbacks stay on bootstrap surface',
        (tester) async {
      final searchRequests = <WenzMentionSearchRequest>[];
      final tapEvents = <WenzMentionTapDetails>[];

      List<WenzMentionCandidate> searchMentions(
        WenzMentionSearchRequest request,
      ) {
        searchRequests.add(request);
        return const <WenzMentionCandidate>[
          WenzMentionCandidate(
            id: 'u-ada',
            label: 'Ada',
            data: <String, Object?>{'email': 'ada@example.com'},
          ),
        ];
      }

      void handleMentionTap(WenzMentionTapDetails details) {
        tapEvents.add(details);
      }

      final mentionSearch = searchMentions;
      final onMentionTap = handleMentionTap;
      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[
                  TextRun(text: 'Hello '),
                  InlineEmbed(
                    embedType: 'mention',
                    data: <String, Object?>{
                      'id': 'u-ada',
                      'label': 'Ada',
                      'email': 'ada@example.com',
                    },
                  ),
                ],
              ),
            ],
          ),
          mentionSearch: mentionSearch,
          onMentionTap: onMentionTap,
        ),
      );
      addTearDown(bootstrap.dispose);

      expect(bootstrap.mentionSearch, same(mentionSearch));
      final candidates = await Future<List<WenzMentionCandidate>>.value(
        bootstrap.mentionSearch!(
          const WenzMentionSearchRequest(query: 'ad'),
        ),
      );
      expect(searchRequests.single.query, 'ad');
      expect(candidates.single.data['email'], 'ada@example.com');

      final editor = bootstrap.buildEditor(
        enableIme: false,
        padding: const EdgeInsets.all(24),
      );
      expect(editor.onMentionTap, same(onMentionTap));

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: editor)),
      );
      await tester.pumpAndSettle();
      expect(_richText('Hello @Ada'), findsOneWidget);

      await tester.tapAt(_globalTextRangePoint(tester, 'Hello @Ada', 6, 10));
      await tester.pump();
      await tester.pump();

      expect(tapEvents, hasLength(1));
      expect(tapEvents.single.id, 'u-ada');
      expect(tapEvents.single.label, 'Ada');
      expect(tapEvents.single.data['email'], 'ada@example.com');
      expect(tapEvents.single.blockId, 'p1');
    });

    test('comment and read permissions reject write commands at the gate', () {
      void assertBlocked(WenzEditorPermission permission) {
        final bootstrap = WenzEditorBootstrap.create(
          WenzEditorConfiguration(
            document: const RichTextDocument(
              blocks: <BlockNode>[
                TextBlockNode(
                  id: 'p1',
                  type: BlockType.paragraph,
                  content: <InlineNode>[TextRun(text: 'Hi')],
                ),
              ],
            ),
            selection: collapsedTextSelection('p1', 0, 2),
            permission: permission,
          ),
        );
        addTearDown(bootstrap.dispose);

        expect(bootstrap.controller.permission, permission);
        expect(bootstrap.controller.canEdit, isFalse);

        final blocked = bootstrap.controller.insertText('!');
        expect(blocked.isNoop, isTrue);
        expect(blocked.description, 'permission:blocked:insertText');
        expect(bootstrap.document.plainText, 'Hi');
      }

      assertBlocked(WenzEditorPermission.comment);
      assertBlocked(WenzEditorPermission.read);
    });

    testWidgets('read permission renders a read-only widget', (tester) async {
      final bootstrap = WenzEditorBootstrap.create(
        const WenzEditorConfiguration(
          permission: WenzEditorPermission.read,
          document: RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'View only')],
              ),
            ],
          ),
        ),
      );
      addTearDown(bootstrap.dispose);

      // Default readOnly tracks the read permission; an explicit override wins.
      expect(bootstrap.buildEditor(enableIme: false).readOnly, isTrue);
      expect(
        bootstrap.buildEditor(enableIme: false, readOnly: false).readOnly,
        isFalse,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: bootstrap.buildEditor(enableIme: false)),
        ),
      );
      await tester.pump();
      expect(_richText('View only'), findsOneWidget);
    });

    test('context menu configuration is copied and passed to buildEditor', () {
      const appendMenu = WenzEditorContextMenuConfiguration(
        items: <WenzEditorContextMenuEntry>[
          WenzEditorContextMenuItem(
            id: 'host.comment',
            title: 'Comment',
            icon: Icons.comment_outlined,
          ),
        ],
      );
      const replacementMenu = WenzEditorContextMenuConfiguration(
        defaultItemsPolicy: WenzEditorContextMenuDefaultItemsPolicy.customOnly,
        items: <WenzEditorContextMenuEntry>[
          WenzEditorContextMenuItem(
            id: 'host.rewrite',
            title: 'Rewrite',
            icon: Icons.auto_fix_high,
          ),
        ],
      );
      const configuration = WenzEditorConfiguration(
        contextMenuConfiguration: appendMenu,
      );

      expect(configuration.contextMenuConfiguration, same(appendMenu));
      expect(
        configuration.copyWith().contextMenuConfiguration,
        same(appendMenu),
      );
      expect(
        configuration
            .copyWith(contextMenuConfiguration: replacementMenu)
            .contextMenuConfiguration,
        same(replacementMenu),
      );
      expect(
        configuration
            .copyWith(contextMenuConfiguration: null)
            .contextMenuConfiguration,
        isNull,
      );

      final bootstrap = WenzEditorBootstrap.create(configuration);
      addTearDown(bootstrap.dispose);

      final editor = bootstrap.buildEditor(enableIme: false);
      expect(editor.contextMenuConfiguration, same(appendMenu));
    });

    testWidgets(
        'host block embed renderer and slash item injected via configuration '
        'take effect', (tester) async {
      const embedKey = ValueKey<String>('crm-card-render');

      // A slash item whose action inserts a CRM-card block embed.
      final crmSlashItem = SlashMenuItem(
        id: 'crm-card',
        title: 'CRM card',
        icon: '📇',
        action: (editor, _) {
          editor.insertBlockEmbed(
            blockId: 'crm-1',
            embedType: 'crm-card',
            data: const <String, Object?>{'recordId': '42'},
            fallbackText: 'Acme account',
          );
        },
      );

      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Lead text')],
              ),
            ],
          ),
          blockEmbedRenderers: <String, BlockRendererBuilder>{
            'crm-card': (context, renderContext) {
              final embed = renderContext.block as BlockEmbedNode;
              return Container(
                key: embedKey,
                child: Text('CRM ${embed.data['recordId']}'),
              );
            },
          },
          slashMenuItems: <SlashMenuItem>[crmSlashItem],
        ),
      );
      addTearDown(bootstrap.dispose);

      // Extensions landed in the assembled registries (host contributions
      // applied after the plugin install pass).
      expect(bootstrap.blockRendererRegistry.hasEmbed('crm-card'), isTrue);
      expect(bootstrap.slashMenuRegistry['crm-card'], same(crmSlashItem));

      // Invoking the injected slash item mutates the document.
      bootstrap.slashMenuRegistry['crm-card']!.action(
        bootstrap.controller,
        SlashMenuContext(
          trigger: SlashMenuTrigger(
            blockId: 'p1',
            blockIndex: 0,
            path: PositionPath.blockText('p1'),
            start: 0,
            end: 1,
            query: 'crm',
          ),
          generatedId: (prefix) => '$prefix-1',
        ),
      );
      expect(
        bootstrap.document.blocks.whereType<BlockEmbedNode>().single.embedType,
        'crm-card',
      );

      // The custom renderer paints the embed instead of the generic fallback.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: bootstrap.buildEditor(enableIme: false)),
        ),
      );
      await tester.pump();
      expect(find.byKey(embedKey), findsOneWidget);
      // The custom renderer's Text surfaces the embed data.
      expect(_richText('CRM 42'), findsOneWidget);
    });
  });

  group('lifecycle', () {
    test('dispose releases the editor controller and derived controllers', () {
      final bootstrap =
          WenzEditorBootstrap.create(const WenzEditorConfiguration());

      // The default derived controllers attach to the editor before dispose.
      // Verified behaviourally — the stats controller only re-notifies when the
      // editor's document changes — rather than via the protected hasListeners.
      expect(_derivedControllersListenToEditor(bootstrap), isTrue);

      bootstrap.dispose();

      // A disposed ChangeNotifier rejects new listeners — both the editor
      // controller and a representative derived controller are torn down, so
      // neither can notify anymore.
      expect(_disposedRejectsListeners(bootstrap.controller), isTrue);
      expect(_disposedRejectsListeners(bootstrap.slashMenuController!), isTrue);
    });

    test('dispose is idempotent and tolerates the full derived set', () {
      final bootstrap =
          WenzEditorBootstrap.create(const WenzEditorConfiguration());

      // Default config attaches toolbar/slash/outline/find/stats listeners, so
      // a correct (listeners-before-editor) dispose order is exercised here.
      expect(_derivedControllersListenToEditor(bootstrap), isTrue);
      expect(() => bootstrap.dispose(), returnsNormally);
      expect(
        () => bootstrap.dispose(),
        returnsNormally,
        reason: 'second dispose is a no-op',
      );
    });
  });
}

/// Whether [notifier] is disposed, detected via the [ChangeNotifier] contract
/// that a disposed notifier rejects new listeners.
bool _disposedRejectsListeners(ChangeNotifier notifier) {
  void listener() {}
  try {
    notifier.addListener(listener);
    notifier.removeListener(listener);
    return false;
  } catch (_) {
    return true;
  }
}

/// Whether the default derived controllers wired themselves onto the editor,
/// observed through the stats controller: it only re-notifies when the editor's
/// document changes, so a notification reaching it proves it is listening. Uses
/// the public [ChangeNotifier] surface rather than the `@protected`
/// `hasListeners` member (which triggers `invalid_use_of_protected_member`).
bool _derivedControllersListenToEditor(WenzEditorBootstrap bootstrap) {
  final stats = bootstrap.statsController;
  if (stats == null) {
    return false;
  }
  var heard = false;
  void onStatsChanged() => heard = true;
  stats.addListener(onStatsChanged);
  // A real document change, not a bare notifyListeners(): the stats controller
  // early-returns when the document is unchanged, so only an actual edit can
  // prove it is subscribed to the editor.
  bootstrap.loadMarkdown('wiring probe');
  stats.removeListener(onStatsChanged);
  return heard && stats.wordCount > 0;
}

/// Finds the editor's rendered text. The editor paints paragraph/heading text
/// as `RichText` (built from inline runs) rather than a plain `Text` widget, so
/// `find.text` does not match it; match on the RichText's plain text instead.
Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

Offset _globalTextRangePoint(
  WidgetTester tester,
  String text,
  int startOffset,
  int endOffset, [
  double fraction = 0.75,
]) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: startOffset, extentOffset: endOffset),
  );
  if (boxes.isEmpty) {
    final local = painter.getOffsetForCaret(
      TextPosition(offset: startOffset),
      Rect.zero,
    );
    return tester.getTopLeft(finder) +
        local +
        Offset(1, painter.preferredLineHeight / 2);
  }
  final firstBox = boxes.first.toRect();
  final rangeRect = boxes.skip(1).fold<Rect>(
        firstBox,
        (current, box) => current.expandToInclude(box.toRect()),
      );
  return tester.getTopLeft(finder) +
      Offset(
        rangeRect.left + rangeRect.width * fraction,
        rangeRect.center.dy,
      );
}
