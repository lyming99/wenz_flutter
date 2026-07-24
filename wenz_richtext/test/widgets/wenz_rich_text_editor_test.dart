import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat, LineMetrics, PointerDeviceKind, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:wenz_richtext/src/widgets/lucide_toolbar_icons.dart';
import 'package:wenz_richtext/src/widgets/mobile_selection_handles_overlay.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const String _formulaPlaceholder = '\uFFFC';
const _inlineFormulaKey = ValueKey<String>('wenz-richtext-inline-formula');
const _formulaEditorPopupKey = ValueKey<String>(
  'wenz-richtext-formula-editor-popup',
);
const _formulaEditorInputKey = ValueKey<String>(
  'wenz-richtext-formula-editor-input',
);
const _formulaEditorCancelKey = ValueKey<String>(
  'wenz-richtext-formula-editor-cancel',
);
const _formulaEditorCloseKey = ValueKey<String>(
  'wenz-richtext-formula-editor-close',
);
const _formulaEditorConfirmKey = ValueKey<String>(
  'wenz-richtext-formula-editor-confirm',
);
const _selectionHighlightKey = ValueKey<String>(
  'wenz-richtext-selection-highlight',
);
const _externalImageDropOverlayKey = ValueKey<String>(
  'wenz-richtext-external-image-drop-overlay',
);
const _externalImageDragSourceKey = ValueKey<String>(
  'wenz-richtext-external-image-drag-source',
);
const _codeBlockBackground = Color(0xFF1E1E2E);
const _codeBlockText = Color(0xFFE6E6F0);
const _codeBlockSelectionHighlight = Color(0x944C7DFF);
const _codeKeyword = Color(0xFFC792EA);
const _codeString = Color(0xFFC3E88D);
const _codeType = Color(0xFF82AAFF);
const _codeNumber = Color(0xFFF78C6C);
const _codeComment = Color(0xFF6B7394);
const _dividerLine = Color(0xFFE4E1EE);
const _calloutInfoBackground = Color(0xFFF2F0F7);
const _calloutInfoForeground = Color(0xFF46464F);
const _calloutInfoBorder = Color(0xFFD8D5E2);
const _calloutSuccessBackground = Color(0x99D6E4E0);
const _calloutSuccessForeground = Color(0xFF0E1F1B);
const _calloutSuccessBorder = Color(0xFFBCD8D0);
const _calloutWarningBackground = Color(0xFFFFF8E1);
const _calloutWarningForeground = Color(0xFFC97B00);
const _calloutWarningBorder = Color(0xFFFFE082);
const _calloutDangerBackground = Color(0xB3FFDAD6);
const _calloutDangerForeground = Color(0xFF410002);
const _calloutDangerBorder = Color(0xFFF5B8B0);

void main() {
  testWidgets('renders document blocks', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[
              TextRun(text: 'Roadmap', attributes: TextAttributes(bold: true)),
            ],
          ),
          TextBlockNode(
            id: 'task1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'Ship core')],
          ),
          CodeBlockNode(
            id: 'code1',
            code: 'final done = true;',
            language: 'dart',
          ),
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Cell A')],
                      ),
                    ],
                  ),
                ],
              ],
              columnAlignments: <int, String>{0: 'center'},
            ),
          ),
          ImageBlockNode(
            id: 'image1',
            assetId: 'hero',
            file: 'hero.png',
            caption: 'Hero caption',
          ),
          DividerBlockNode(id: 'divider1'),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(_richText('Roadmap'), findsOneWidget);
    expect(_richText('Ship core'), findsOneWidget);
    final taskCheckbox = tester.widget<Checkbox>(find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-task1'),
    ));
    expect(taskCheckbox.value, isTrue);
    expect(find.text('[x]'), findsNothing);
    expect(_richText('final done = true;'), findsOneWidget);
    expect(_richText('Cell A'), findsOneWidget);
    expect(_imageBlockFinder('image1'), findsOneWidget);
    expect(find.text('[image: hero.png]'), findsNothing);
    expect(find.text('Hero caption'), findsNothing);
    final imageBlock =
        controller.document.blocks.whereType<ImageBlockNode>().single;
    expect(imageBlock.caption, 'Hero caption');
    expect(find.byTooltip('设置图片宽度'), findsNothing);
    expect(find.text('[video: clip]'), findsOneWidget);
  });

  testWidgets('divider block line expands beyond the center dot', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[DividerBlockNode(id: 'divider1')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              height: 180,
              child: WenzRichTextEditor(
                controller: controller,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const shellKey = ValueKey<String>('wenz-richtext-divider-shell-divider1');
    const lineKey = ValueKey<String>('wenz-richtext-divider-line-divider1');
    const dotKey = ValueKey<String>('wenz-richtext-divider-dot-divider1');
    final shellFinder = find.byKey(shellKey);
    final lineFinder = find.byKey(lineKey);
    final dotFinder = find.byKey(dotKey);

    expect(shellFinder, findsOneWidget);
    expect(lineFinder, findsOneWidget);
    expect(dotFinder, findsOneWidget);
    expect(tester.takeException(), isNull);

    final lineRect = tester.getRect(lineFinder);
    final dotRect = tester.getRect(dotFinder);
    expect(lineRect.width, greaterThan(dotRect.width * 4));
    expect(lineRect.width.isFinite, isTrue);
    expect(
        lineRect.width, lessThanOrEqualTo(tester.getSize(shellFinder).width));
    expect(lineRect.center.dx, moreOrLessEquals(dotRect.center.dx, epsilon: 1));
    final lineDecoration =
        tester.widget<DecoratedBox>(lineFinder).decoration as BoxDecoration;
    expect(lineDecoration.color, _dividerLine);
    final normalShellDecoration =
        tester.widget<DecoratedBox>(shellFinder).decoration as BoxDecoration;
    expect(normalShellDecoration.border, isNull);

    controller.setSelection(objectBlockSelection('divider1', 0));
    await tester.pump();

    expect(shellFinder, findsOneWidget);
    expect(lineFinder, findsOneWidget);
    expect(dotFinder, findsOneWidget);
    expect(find.byKey(_selectionHighlightKey), findsNothing);
    expect(tester.takeException(), isNull);

    final selectedLineRect = tester.getRect(lineFinder);
    final selectedDotRect = tester.getRect(dotFinder);
    expect(selectedLineRect.width, greaterThan(selectedDotRect.width * 4));
    expect(selectedLineRect.width.isFinite, isTrue);
    expect(
      selectedLineRect.width,
      lessThanOrEqualTo(tester.getSize(shellFinder).width),
    );
    expect(
      selectedLineRect.center.dx,
      moreOrLessEquals(selectedDotRect.center.dx, epsilon: 1),
    );
    final selectedShellDecoration =
        tester.widget<DecoratedBox>(shellFinder).decoration as BoxDecoration;
    expect(selectedShellDecoration.border, isNotNull);
  });

  group('editor context menu', () {
    testWidgets(
        'right-click opens default menu with shortcuts and disabled '
        'collapsed-selection actions', (tester) async {
      final controller = _contextMenuController(
        text: 'Alpha Beta',
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _pumpContextMenuEditor(tester, controller);
      final anchor = _globalTextRangePoint(tester, 'Alpha Beta', 0, 5, 0.5);
      await _openContextMenuAt(tester, anchor);

      expect(_contextMenuItemFinder('wenz.default.copy'), findsOneWidget);
      expect(_contextMenuItemFinder('wenz.default.cut'), findsOneWidget);
      expect(_contextMenuItemFinder('wenz.default.paste'), findsOneWidget);
      expect(_contextMenuItemFinder('wenz.default.select-all'), findsOneWidget);
      expect(_contextMenuShortcutFinder('C'), findsOneWidget);
      expect(_contextMenuShortcutFinder('X'), findsOneWidget);
      expect(_contextMenuShortcutFinder('V'), findsOneWidget);

      expect(_contextMenuItem(tester, 'wenz.default.copy').enabled, isFalse);
      expect(_contextMenuItem(tester, 'wenz.default.cut').enabled, isFalse);
      expect(_contextMenuItem(tester, 'wenz.default.delete').enabled, isFalse);
      expect(_contextMenuItem(tester, 'wenz.default.paste').enabled, isTrue);
      expect(
        _contextMenuItem(tester, 'wenz.default.select-all').enabled,
        isTrue,
      );

      final menuRect = tester.getRect(_contextMenuItemFinder(
        'wenz.default.copy',
      ));
      expect(menuRect.left, greaterThanOrEqualTo(0));
      expect(menuRect.top, greaterThanOrEqualTo(0));
      final logicalViewSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(menuRect.right, lessThanOrEqualTo(logicalViewSize.width));
      expect(menuRect.bottom, lessThanOrEqualTo(logicalViewSize.height));
    });

    testWidgets('default menu actions copy, cut, paste, select all, and delete',
        (tester) async {
      await Clipboard.setData(const ClipboardData(text: ''));
      addTearDown(() => Clipboard.setData(const ClipboardData(text: '')));
      final controller = _contextMenuController(
        text: 'Alpha Beta',
        selection: textSelection('p1', 0, 0, 5),
      );

      await _pumpContextMenuEditor(tester, controller);

      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Alpha Beta', 1, 4, 0.5),
      );
      await _tapContextMenuItem(tester, 'wenz.default.copy');
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      expect(copied?.text, startsWith(wenzClipboardPrefix));
      expect(controller.selection, textSelection('p1', 0, 0, 5));

      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Alpha Beta', 1, 4, 0.5),
      );
      await _tapContextMenuItem(tester, 'wenz.default.cut');
      expect(controller.document.plainText, ' Beta');

      await Clipboard.setData(const ClipboardData(text: 'Z'));
      await tester.pump();
      await _openContextMenuAt(
        tester,
        _globalTextOffset(tester, ' Beta', 0),
      );
      await _tapContextMenuItem(tester, 'wenz.default.paste');
      final pastedText = controller.document.plainText;
      expect(pastedText, contains('Z'));

      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, pastedText, 0, pastedText.length, 0.5),
      );
      await _tapContextMenuItem(tester, 'wenz.default.select-all');
      final allSelection = controller.selection;
      expect(allSelection, isNotNull);
      expect(allSelection!.isCollapsed, isFalse);
      expect(allSelection.start.offset, 0);
      expect(allSelection.end.offset, pastedText.length);

      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, pastedText, 0, pastedText.length, 0.5),
      );
      await _tapContextMenuItem(tester, 'wenz.default.delete');
      expect(controller.document.plainText, isEmpty);
    });

    testWidgets(
        'right-click inside selection preserves it and outside updates '
        'the action context', (tester) async {
      final captured = <WenzEditorContextMenuContext>[];
      final controller = _contextMenuController(
        text: 'Alpha Beta',
        selection: textSelection('p1', 0, 0, 5),
      );
      final configuration = WenzEditorContextMenuConfiguration(
        defaultItemsPolicy: WenzEditorContextMenuDefaultItemsPolicy.customOnly,
        items: <WenzEditorContextMenuEntry>[
          WenzEditorContextMenuItem(
            id: 'host.capture',
            title: 'Capture context',
            action: captured.add,
          ),
        ],
      );

      await _pumpContextMenuEditor(
        tester,
        controller,
        contextMenuConfiguration: configuration,
      );

      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Alpha Beta', 1, 4, 0.5),
      );
      await _tapContextMenuItem(tester, 'host.capture');
      expect(captured.single.hitInsideSelection, isTrue);
      expect(captured.single.selection, textSelection('p1', 0, 0, 5));

      captured.clear();
      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Alpha Beta', 7, 10, 0.5),
      );
      await _tapContextMenuItem(tester, 'host.capture');
      expect(captured.single.hitInsideSelection, isFalse);
      expect(captured.single.selection?.isCollapsed, isTrue);
      expect(captured.single.selection, controller.selection);
      expect(captured.single.hitPosition?.blockId, 'p1');
      expect(captured.single.controller, same(controller));
    });

    testWidgets(
        'read-only context menu disables write actions and leaves the '
        'document unchanged', (tester) async {
      final controller = _contextMenuController(
        text: 'Read only',
        selection: textSelection('p1', 0, 0, 4),
      );

      await _pumpContextMenuEditor(tester, controller, readOnly: true);
      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Read only', 1, 3, 0.5),
      );

      expect(_contextMenuItem(tester, 'wenz.default.copy').enabled, isTrue);
      expect(
        _contextMenuItem(tester, 'wenz.default.select-all').enabled,
        isTrue,
      );
      expect(_contextMenuItem(tester, 'wenz.default.cut').enabled, isFalse);
      expect(_contextMenuItem(tester, 'wenz.default.paste').enabled, isFalse);
      expect(_contextMenuItem(tester, 'wenz.default.delete').enabled, isFalse);
      expect(
        _contextMenuItem(tester, 'wenz.default.insert-paragraph').enabled,
        isFalse,
      );
      expect(controller.document.plainText, 'Read only');
    });

    testWidgets('custom context menu items can append to or replace defaults',
        (tester) async {
      final calls = <WenzEditorContextMenuContext>[];
      final controller = _contextMenuController(
        text: 'Host action',
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final customItem = WenzEditorContextMenuItem(
        id: 'host.comment',
        title: 'Add comment',
        icon: Icons.comment_outlined,
        action: calls.add,
      );

      await _pumpContextMenuEditor(
        tester,
        controller,
        contextMenuConfiguration: WenzEditorContextMenuConfiguration(
          items: <WenzEditorContextMenuEntry>[customItem],
        ),
      );
      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Host action', 0, 4, 0.5),
      );
      expect(_contextMenuItemFinder('wenz.default.select-all'), findsOneWidget);
      expect(_contextMenuItemFinder('host.comment'), findsOneWidget);
      await _tapContextMenuItem(tester, 'host.comment');
      expect(calls.single.controller, same(controller));
      expect(calls.single.hitPosition, isNotNull);
      expect(calls.single.globalPosition, isNot(Offset.zero));

      await _pumpContextMenuEditor(
        tester,
        controller,
        contextMenuConfiguration: WenzEditorContextMenuConfiguration(
          defaultItemsPolicy:
              WenzEditorContextMenuDefaultItemsPolicy.customOnly,
          items: <WenzEditorContextMenuEntry>[customItem],
        ),
      );
      await _openContextMenuAt(
        tester,
        _globalTextRangePoint(tester, 'Host action', 0, 4, 0.5),
      );
      expect(_contextMenuItemFinder('wenz.default.select-all'), findsNothing);
      expect(_contextMenuItemFinder('host.comment'), findsOneWidget);
    });
  });

  testWidgets('paste keeps Wenz rich JSON ahead of image flavors',
      (tester) async {
    const service = ClipboardService();
    const source = RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'src',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'X')],
        ),
      ],
    );
    final richPayload = service.copy(
      source,
      textSelection('src', 0, 0, 1),
    )!;
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/ignored.png',
          caption: 'ignored',
          altText: 'ignored',
        ),
      ],
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: richPayload,
          images: <ExternalImageInput>[
            ExternalImageInput.filePath(
              path: 'C:/tmp/ignored.png',
              source: ExternalImageInputSource.clipboard,
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.plainText, 'aXb');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
  });

  testWidgets('paste plain text into code block through shortcut is one event',
      (tester) async {
    const pastedCode = '# title\n\n  final url = "http://example.test";\n';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: 'ab', language: 'dart'),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 1),
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: const _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(plainText: pastedCode),
      ),
    );

    var docChanges = 0;
    var selectionChanges = 0;
    var commandRuns = 0;
    var listenerNotifications = 0;
    EditorCommand? commandSeen;
    controller.onChanged = (_) => docChanges++;
    controller.onSelectionChanged = (_) => selectionChanges++;
    controller.onCommandExecuted = (command, _) {
      commandRuns++;
      commandSeen = command;
    };
    controller.addListener(() => listenerNotifications++);

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final block = controller.document.blocks.single as CodeBlockNode;
    expect(block.code, 'a${pastedCode}b');
    expect(block.language, 'dart');
    expect(controller.selection?.extent.path, PositionPath.blockCode('code1'));
    expect(controller.selection?.extent.offset, 1 + pastedCode.length);
    expect(docChanges, 1);
    expect(selectionChanges, 1);
    expect(commandRuns, 1);
    expect(listenerNotifications, 1);
    expect(commandSeen, isA<InsertTextCommand>());
  });

  testWidgets('paste inserts external clipboard images before text fallback',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'plain fallback',
          images: <ExternalImageInput>[
            ExternalImageInput.filePath(
              path: 'C:/tmp/first.png',
              source: ExternalImageInputSource.clipboard,
            ),
            ExternalImageInput.filePath(
              path: 'C:/tmp/second.jpg',
              source: ExternalImageInputSource.clipboard,
            ),
          ],
        ),
      ),
      store: _FakeExternalImageStore(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/first.png',
            caption: 'first',
            altText: 'first',
          ),
          ExternalImageBlockDescription(
            file: 'C:/tmp/second.jpg',
            caption: 'second',
            altText: 'second',
          ),
        ],
      ),
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    final images = controller.document.blocks.whereType<ImageBlockNode>();
    expect(images.map((image) => image.file), <String>[
      'C:/tmp/first.png',
      'C:/tmp/second.jpg',
    ]);
    expect(images.map((image) => image.caption), <String>['first', 'second']);
    expect(controller.document.plainText, 'a\nfirst\nsecond\nb');
    expect(controller.hasFocus, isTrue);
    expect(controller.undo(), isTrue);
    expect(controller.document.blocks, hasLength(1));
    expect(
        (controller.document.blocks.single as TextBlockNode).plainText, 'ab');
    expect(controller.selection, collapsedTextSelection('p1', 0, 1));
  });

  testWidgets('paste inserts memory image clipboard flavors through store',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/materialized.png',
          caption: 'memory paste',
          altText: 'memory paste',
          width: 320,
          height: 80,
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'plain fallback',
          images: <ExternalImageInput>[
            ExternalImageInput.memory(
              bytes: _pngBytes,
              source: ExternalImageInputSource.clipboard,
              mimeType: 'image/png',
              fileName: 'memory-source.png',
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(store.prepareCount, 1);
    expect(store.preparedInputs.single.kind, ExternalImageInputKind.memory);
    expect(store.preparedInputs.single.fileName, 'memory-source.png');
    final image = controller.document.blocks[1] as ImageBlockNode;
    expect(image.file, 'C:/tmp/materialized.png');
    expect(image.width, 320);
    expect(image.height, 80);
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);
    expect(image.caption, 'memory paste');
    expect(image.altText, 'memory paste');
    expect(controller.document.plainText, 'a\nmemory paste\nb');
    expect(controller.document.plainText, isNot(contains('plain fallback')));
  });

  testWidgets('host can configure the insertion position of image files',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          DividerBlockNode(id: 'anchor'),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('before', 0, 3),
    );
    ExternalImageInsertionContext? insertionContext;

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'unused fallback',
          images: <ExternalImageInput>[
            ExternalImageInput.filePath(
              path: 'C:/tmp/configured.png',
              source: ExternalImageInputSource.clipboard,
            ),
          ],
        ),
      ),
      store: _FakeExternalImageStore(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/configured.png',
            caption: 'configured',
            altText: 'configured',
          ),
        ],
      ),
      insertionResolver: (context) {
        insertionContext = context;
        final position = DocumentPosition.object(
          blockId: 'anchor',
          blockIndex: 1,
        );
        return DocumentSelection(base: position, extent: position);
      },
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(insertionContext?.source, ExternalImageInsertionSource.clipboard);
    expect(
      insertionContext?.currentSelection,
      collapsedTextSelection('before', 0, 3),
    );
    expect(
      insertionContext?.suggestedSelection,
      collapsedTextSelection('before', 0, 3),
    );
    expect(controller.document.blocks, hasLength(4));
    expect(controller.document.blocks[0].id, 'before');
    expect(controller.document.blocks[1], isA<ImageBlockNode>());
    expect(controller.document.blocks[2].id, 'anchor');
    expect(controller.document.blocks[3].id, 'after');
  });

  testWidgets('paste keeps sized file URI ahead of paired memory fallback',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/from-file.png',
          caption: 'from file',
          altText: 'from file',
          width: 640,
          height: 320,
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          images: <ExternalImageInput>[
            ExternalImageInput.fileUri(
              uri: Uri.parse('file:///C:/tmp/from-file.png'),
              source: ExternalImageInputSource.clipboard,
              fileName: 'from-file.png',
            ),
            ExternalImageInput.memory(
              bytes: _pngBytes,
              source: ExternalImageInputSource.clipboard,
              mimeType: 'image/png',
              fileName: 'from-file.png',
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(store.prepareCount, 1);
    expect(store.preparedInputs.single.kind, ExternalImageInputKind.fileUri);
    final images = controller.document.blocks.whereType<ImageBlockNode>();
    expect(images, hasLength(1));
    final image = images.single;
    expect(image.file, 'C:/tmp/from-file.png');
    expect(image.width, 640);
    expect(image.height, 320);
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);
  });

  testWidgets(
      'paste corrects paired file dimensions from memory pixels without fallback materialization',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/from-file-wrong-ratio.png',
          caption: 'file candidate',
          altText: 'file candidate',
          width: 300,
          height: 100,
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          images: <ExternalImageInput>[
            ExternalImageInput.fileUri(
              uri: Uri.parse('file:///C:/tmp/from-file-wrong-ratio.png'),
              source: ExternalImageInputSource.clipboard,
              fileName: 'from-file-wrong-ratio.png',
            ),
            ExternalImageInput.memory(
              bytes: _pngBytesWithSize(width: 180, height: 120),
              source: ExternalImageInputSource.clipboard,
              mimeType: 'image/png',
              fileName: 'clipboard-neighbor.png',
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(store.prepareCount, 1);
    expect(store.preparedInputs.single.kind, ExternalImageInputKind.fileUri);
    final image = controller.document.blocks.whereType<ImageBlockNode>().single;
    expect(image.file, 'C:/tmp/from-file-wrong-ratio.png');
    expect(image.caption, 'file candidate');
    expect(image.altText, 'file candidate');
    expect(image.width, 180);
    expect(image.height, 120);
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);

    final frameRect = _imageFrameRect(tester, image.id);
    expect(frameRect.width, moreOrLessEquals(180, epsilon: 0.75));
    expect(frameRect.height, moreOrLessEquals(120, epsilon: 0.75));
    expect(
      frameRect.width / frameRect.height,
      moreOrLessEquals(1.5, epsilon: 0.02),
    );
  });

  testWidgets(
      'paste uses paired memory fallback dimensions and selected frame is tight',
      (tester) async {
    const strokeKey = ValueKey<String>('wenz-richtext-media-selection-stroke');
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/fallback.png',
          caption: 'file candidate',
          altText: 'file candidate',
        ),
        ExternalImageBlockDescription(
          file: 'C:/tmp/materialized-fallback.png',
          caption: 'memory fallback',
          altText: 'memory fallback',
          width: 320,
          height: 80,
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'plain fallback',
          images: <ExternalImageInput>[
            ExternalImageInput.fileUri(
              uri: Uri.parse('file:///C:/tmp/fallback.png'),
              source: ExternalImageInputSource.clipboard,
              fileName: 'fallback.png',
            ),
            ExternalImageInput.memory(
              bytes: _pngBytes,
              source: ExternalImageInputSource.clipboard,
              mimeType: 'image/png',
              fileName: 'fallback.png',
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(store.prepareCount, 2);
    expect(
      store.preparedInputs.map((input) => input.kind),
      <ExternalImageInputKind>[
        ExternalImageInputKind.fileUri,
        ExternalImageInputKind.memory,
      ],
    );
    final image = controller.document.blocks.whereType<ImageBlockNode>().single;
    expect(image.file, 'C:/tmp/materialized-fallback.png');
    expect(image.width, 320);
    expect(image.height, 80);
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);
    expect(controller.document.plainText, 'a\nmemory fallback\nb');
    expect(controller.document.plainText, isNot(contains('plain fallback')));

    final blockIndex = controller.document.blocks.indexWhere(
      (block) => block.id == image.id,
    );
    controller.setSelection(objectBlockSelection(image.id, blockIndex));
    await tester.pump();
    await tester.pump();

    final frameRect = _imageFrameRect(tester, image.id);
    final sizeRect = tester.getRect(
      find.byKey(ValueKey<String>('wenz-richtext-image-size-${image.id}')),
    );
    final strokeRect = tester.getRect(find.byKey(strokeKey));
    _expectRectClose(sizeRect, frameRect, epsilon: 0.75);
    _expectRectClose(strokeRect, frameRect, epsilon: 0.75);
    expect(
      frameRect.height,
      moreOrLessEquals(frameRect.width / 4, epsilon: 1),
    );
    expect((frameRect.height - frameRect.width / 2).abs(), greaterThan(20));
  });

  testWidgets('paste preserves mixed bytes and file image flavor order',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/wechat-bytes.png',
          caption: 'wechat bytes',
          altText: 'wechat bytes',
        ),
        ExternalImageBlockDescription(
          file: 'C:/tmp/qq-file.jpg',
          caption: 'qq file',
          altText: 'qq file',
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          images: <ExternalImageInput>[
            ExternalImageInput.memory(
              bytes: _pngBytes,
              source: ExternalImageInputSource.clipboard,
              fileName: 'clipboard-image.png',
            ),
            ExternalImageInput.filePath(
              path: 'C:/tmp/qq-file.jpg',
              source: ExternalImageInputSource.clipboard,
            ),
          ],
        ),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(
      store.preparedInputs.map((input) => input.kind),
      <ExternalImageInputKind>[
        ExternalImageInputKind.memory,
        ExternalImageInputKind.filePath,
      ],
    );
    final images = controller.document.blocks.whereType<ImageBlockNode>();
    expect(images.map((image) => image.file), <String>[
      'C:/tmp/wechat-bytes.png',
      'C:/tmp/qq-file.jpg',
    ]);
    expect(images.map((image) => image.caption), <String>[
      'wechat bytes',
      'qq file',
    ]);
  });

  testWidgets('paste ignores empty external clipboard data', (tester) async {
    await Clipboard.setData(const ClipboardData(text: ''));
    addTearDown(() => Clipboard.setData(const ClipboardData(text: '')));
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/unexpected.png',
          caption: 'unexpected',
          altText: 'unexpected',
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: const _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(),
      ),
      store: store,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.plainText, 'ab');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(controller.canUndo, isFalse);
    expect(store.prepareCount, 0);
  });

  testWidgets('paste keeps plain text fallback when external images are off',
      (tester) async {
    await Clipboard.setData(const ClipboardData(text: 'TEXT'));
    addTearDown(() => Clipboard.setData(const ClipboardData(text: '')));
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/ignored.png',
          caption: 'ignored',
          altText: 'ignored',
        ),
      ],
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          images: <ExternalImageInput>[
            ExternalImageInput.memory(
              bytes: _pngBytes,
              source: ExternalImageInputSource.clipboard,
              mimeType: 'image/png',
            ),
          ],
        ),
      ),
      store: store,
      enableExternalImageInput: false,
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.plainText, 'aTEXTb');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
  });

  testWidgets('paste falls back to plain text when image flavors fail',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'TEXT',
          images: <ExternalImageInput>[
            ExternalImageInput.filePath(
              path: 'C:/tmp/not-image.txt',
              source: ExternalImageInputSource.clipboard,
            ),
          ],
        ),
      ),
      store: _FakeExternalImageStore(const <ExternalImageBlockDescription>[]),
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.plainText, 'aTEXTb');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
  });

  testWidgets('paste uses HTML flavor before plain text fallback',
      (tester) async {
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
    );

    await _pumpPasteEditor(
      tester,
      controller,
      reader: const _FakeExternalImageClipboardReader(
        ExternalImageClipboardData(
          plainText: 'fallback',
          html: '<h1>Title</h1><p>Body</p>',
        ),
      ),
    );

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyV);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect((controller.document.blocks[0] as TextBlockNode).type,
        BlockType.heading);
    expect(controller.document.plainText, 'Title\nBody');
  });

  testWidgets('drop inserts external image files through command history',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/first.png',
          caption: 'first',
          altText: 'first',
        ),
        ExternalImageBlockDescription(
          file: 'C:/tmp/second.jpg',
          caption: 'second',
          altText: 'second',
        ),
      ],
    );

    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.filePath(
          path: 'C:/tmp/first.png',
          source: ExternalImageInputSource.drop,
        ),
        ExternalImageInput.filePath(
          path: 'C:/tmp/second.jpg',
          source: ExternalImageInputSource.drop,
        ),
      ],
      store: store,
    );

    await _dragExternalImagesOntoEditor(tester, expectOverlay: true);

    final images = controller.document.blocks.whereType<ImageBlockNode>();
    expect(images.map((image) => image.file), <String>[
      'C:/tmp/first.png',
      'C:/tmp/second.jpg',
    ]);
    expect(images.map((image) => image.caption), <String>['first', 'second']);
    expect(controller.document.plainText, 'a\nfirst\nsecond\nb');
    expect(controller.hasFocus, isTrue);
    expect(store.prepareCount, 2);
    expect(
      store.preparedInputs.map((input) => input.source),
      <ExternalImageInputSource>[
        ExternalImageInputSource.drop,
        ExternalImageInputSource.drop,
      ],
    );
    expect(controller.undo(), isTrue);
    expect(controller.document.blocks, hasLength(1));
    expect(
        (controller.document.blocks.single as TextBlockNode).plainText, 'ab');
    expect(controller.selection, collapsedTextSelection('p1', 0, 1));
  });

  testWidgets('drop inserts external image bytes through the store',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/materialized-drop.png',
          caption: 'memory drop',
          altText: 'memory drop',
          width: 320,
          height: 80,
        ),
      ],
    );
    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.memory(
          bytes: _pngBytes,
          source: ExternalImageInputSource.drop,
          mimeType: 'image/png',
          fileName: 'memory-drop.png',
        ),
      ],
      store: store,
    );
    await _dragExternalImagesOntoEditor(tester, expectOverlay: true);
    expect(store.prepareCount, 1);
    expect(store.preparedInputs.single.kind, ExternalImageInputKind.memory);
    expect(store.preparedInputs.single.source, ExternalImageInputSource.drop);
    expect(store.preparedInputs.single.fileName, 'memory-drop.png');
    final image = controller.document.blocks[1] as ImageBlockNode;
    expect(image.file, 'C:/tmp/materialized-drop.png');
    expect(image.width, 320);
    expect(image.height, 80);
    expect(image.caption, 'memory drop');
    expect(controller.document.plainText, 'a\nmemory drop\nb');
  });

  testWidgets('drop rejects non-image external file candidates',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/unexpected.png',
          caption: 'unexpected',
          altText: 'unexpected',
        ),
      ],
    );

    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.filePath(
          path: 'C:/tmp/not-image.txt',
          source: ExternalImageInputSource.drop,
        ),
      ],
      store: store,
    );

    await _dragExternalImagesOntoEditor(tester);

    expect(controller.document.plainText, 'ab');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
  });

  testWidgets('drop ignores external image files in read-only mode',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/first.png',
          caption: 'first',
          altText: 'first',
        ),
      ],
    );

    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.filePath(
          path: 'C:/tmp/first.png',
          source: ExternalImageInputSource.drop,
        ),
      ],
      store: store,
      readOnly: true,
    );

    await _dragExternalImagesOntoEditor(tester);

    expect(controller.document.plainText, 'ab');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
    expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
  });

  testWidgets('drop ignores external image files when the feature is disabled',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/ignored.png',
          caption: 'ignored',
          altText: 'ignored',
        ),
      ],
    );

    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.filePath(
          path: 'C:/tmp/ignored.png',
          source: ExternalImageInputSource.drop,
        ),
      ],
      store: store,
      enableExternalImageInput: false,
    );

    await _dragExternalImagesOntoEditor(tester);

    expect(controller.document.plainText, 'ab');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
    expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
  });

  testWidgets(
      'drop ignores external image files when drag and drop is disabled',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );
    final store = _FakeExternalImageStore(
      const <ExternalImageBlockDescription>[
        ExternalImageBlockDescription(
          file: 'C:/tmp/ignored.png',
          caption: 'ignored',
          altText: 'ignored',
        ),
      ],
    );
    await _pumpExternalImageDropEditor(
      tester,
      controller,
      dragData: <ExternalImageInput>[
        ExternalImageInput.filePath(
          path: 'C:/tmp/ignored.png',
          source: ExternalImageInputSource.drop,
        ),
      ],
      store: store,
      enableExternalDragDrop: false,
    );
    await _dragExternalImagesOntoEditor(tester);
    expect(controller.document.plainText, 'ab');
    expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
    expect(store.prepareCount, 0);
    expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
  });

  testWidgets('drop ignores external image files without edit permission',
      (tester) async {
    for (final permission in <WenzEditorPermission>[
      WenzEditorPermission.read,
      WenzEditorPermission.comment,
    ]) {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'ab')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 1),
        permission: permission,
      );
      final store = _FakeExternalImageStore(
        const <ExternalImageBlockDescription>[
          ExternalImageBlockDescription(
            file: 'C:/tmp/blocked.png',
            caption: 'blocked',
            altText: 'blocked',
          ),
        ],
      );
      await _pumpExternalImageDropEditor(
        tester,
        controller,
        dragData: <ExternalImageInput>[
          ExternalImageInput.filePath(
            path: 'C:/tmp/blocked.png',
            source: ExternalImageInputSource.drop,
          ),
        ],
        store: store,
      );
      await _dragExternalImagesOntoEditor(tester);
      expect(controller.document.plainText, 'ab');
      expect(controller.document.blocks.whereType<ImageBlockNode>(), isEmpty);
      expect(store.prepareCount, 0);
      expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
    }
  });

  testWidgets('slash popup follows editor controller refresh chain',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: '')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );
    final slash = SlashMenuController(editor: controller);
    addTearDown(slash.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            slashMenuController: slash,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(slash.isOpen, isFalse);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );

    controller.insertText('/');
    await tester.pump();

    expect(slash.trigger?.blockId, 'p1');
    expect(slash.query, isEmpty);
    expect(slash.isOpen, isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );

    controller.insertText('no-such-item');
    await tester.pump();

    expect(slash.trigger, isNotNull);
    expect(slash.items, isEmpty);
    // The menu stays open with an empty-state message when no items match
    // the query, rather than disappearing silently.
    expect(slash.isOpen, isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );
    expect(find.text('未找到命令'), findsOneWidget);
  });

  testWidgets('slash popup opens filters and executes from keyboard input',
      (tester) async {
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
    );
    final slash = SlashMenuController(editor: controller);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            slashMenuController: slash,
            focusNode: focusNode,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();
    await tester.pump();

    expect(controller.document.plainText, '/');
    expect(slash.isOpen, isTrue);
    expect(slash.query, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
    await tester.pump();
    await tester.pump();

    expect(controller.document.plainText, '/h');
    expect(slash.query, 'h');
    expect(slash.items.map((item) => item.id), contains('heading'));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    final block = controller.document.blocks.single as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.plainText, isEmpty);
    expect(slash.isOpen, isFalse);
    expect(
      find.byKey(const ValueKey<String>('wenz-slash-menu-overlay')),
      findsNothing,
    );
  });

  testWidgets('slash image item inserts a finite selected placeholder', (
    tester,
  ) async {
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
    );
    final slash = SlashMenuController(editor: controller);
    final focusNode = FocusNode();
    addTearDown(slash.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 520,
              child: WenzRichTextEditor(
                controller: controller,
                slashMenuController: slash,
                focusNode: focusNode,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();
    await tester.pump();

    expect(slash.isOpen, isTrue);
    final imageItem = slash.registry['image'];
    expect(imageItem, isNotNull);
    expect(slash.activate(imageItem!), isTrue);
    await tester.pump();
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final image = controller.document.blocks.single as ImageBlockNode;
    expect(image.id, 'p1');
    expect(image.width, 0);
    expect(image.height, 0);
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);
    expect(controller.selection?.extent.path.isBlockObject, isTrue);
    expect(find.text('图片占位'), findsNothing);
    expect(find.text('插入后将在此显示图片'), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(_imageBlockFinder('p1'), findsOneWidget);

    final frameSize = tester.getSize(_imageFrameFinder('p1'));
    expect(frameSize.width.isFinite, isTrue);
    expect(frameSize.height.isFinite, isTrue);
    expect(frameSize.width, greaterThan(0));
    expect(frameSize.height, greaterThan(0));
    expect(
      frameSize.height,
      moreOrLessEquals(frameSize.width / 2, epsilon: 1),
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-size-p1')),
      ),
      tester.getRect(_imageFrameFinder('p1')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mention search overlay filters and inserts a candidate',
      (tester) async {
    const candidates = <WenzMentionCandidate>[
      WenzMentionCandidate(
        id: 'u-ada',
        label: 'Ada Lovelace',
        description: 'Product',
        data: <String, Object?>{'email': 'ada@example.com'},
      ),
      WenzMentionCandidate(
        id: 'u-grace',
        label: 'Grace Hopper',
        description: 'Engineering',
        data: <String, Object?>{'email': 'grace@example.com'},
      ),
    ];
    final requests = <WenzMentionSearchRequest>[];
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
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              focusNode: focusNode,
              enableIme: false,
              mentionSearch: (request) {
                requests.add(request);
                final query = request.query.toLowerCase();
                return candidates.where((candidate) {
                  return candidate.label.toLowerCase().contains(query) ||
                      candidate.id.toLowerCase().contains(query);
                }).toList(growable: false);
              },
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    controller.insertText('@g');
    await tester.pump();
    await tester.pump();

    expect(requests.map((request) => request.query), contains('g'));
    expect(requests.last.position?.blockId, 'p1');
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Engineering'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);

    await tester.tap(find.text('Grace Hopper'));
    await tester.pump();
    await tester.pump();

    final block = controller.document.blocks.single as TextBlockNode;
    final mentions = block.content
        .whereType<InlineEmbed>()
        .where((node) => node.embedType == 'mention')
        .toList();
    expect(mentions, hasLength(1));
    expect(mentions.single.data['id'], 'u-grace');
    expect(mentions.single.data['label'], 'Grace Hopper');
    expect(mentions.single.data['email'], 'grace@example.com');
  });

  testWidgets('adapts editor surface, text, caret, and selection to theme', (
    tester,
  ) async {
    const text = 'Theme aware text';
    const darkOnSurface = Color(0xFFE9EDF8);
    const lightOnSurface = Color(0xFF152033);
    const darkPrimary = Color(0xFF9DB7FF);
    const lightPrimary = Color(0xFF3152D4);

    Future<void> pumpTheme({required Brightness brightness}) async {
      final primary =
          brightness == Brightness.dark ? darkPrimary : lightPrimary;
      final onSurface =
          brightness == Brightness.dark ? darkOnSurface : lightOnSurface;
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: text)],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final scheme = ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onSurface: onSurface,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            colorScheme: scheme,
            useMaterial3: true,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 480,
              child: WenzRichTextEditor(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      final background = tester.widget<ColoredBox>(
        find.byKey(
          const ValueKey<String>('wenz-richtext-editor-background'),
        ),
      );
      expect(
        background.color,
        brightness == Brightness.dark ? Colors.black : Colors.white,
      );
      expect(_richTextSpan(tester, text).style?.color, onSurface);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-caret')),
        findsOneWidget,
      );
      expect(_customPainterColor(tester, '_CaretPainter'), primary);

      controller.setSelection(textSelection('p1', 0, 0, 5));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
        findsOneWidget,
      );
      expect(
        _customPainterColor(tester, '_SelectionHighlightPainter'),
        primary.withAlpha(54),
      );
    }

    await pumpTheme(brightness: Brightness.light);
    await pumpTheme(brightness: Brightness.dark);
  });

  testWidgets('applies design body baseline and inline text attributes', (
    tester,
  ) async {
    const onSurface = Color(0xFF123456);
    const primary = Color(0xFF4F6DF5);
    const primaryContainer = Color(0xFFDDE0FF);
    const plainText =
        'plain bold italic underStrike colored highlight big mono '
        'link comment revision';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'plain'),
              TextRun(text: ' '),
              TextRun(
                text: 'bold',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'italic',
                attributes: TextAttributes(italic: true),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'underStrike',
                attributes: TextAttributes(
                  underline: true,
                  lineThrough: true,
                ),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'colored',
                attributes: TextAttributes(color: 0xFFD81B60),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'highlight',
                attributes: TextAttributes(background: 0xFFFFF59D),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'big',
                attributes: TextAttributes(fontSize: 22),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'mono',
                attributes: TextAttributes(fontFamily: 'JetBrains Mono'),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'link',
                attributes: TextAttributes(url: 'https://example.com'),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'comment',
                attributes: TextAttributes(
                  remark: true,
                  commentIds: <String>['c1'],
                ),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'revision',
                attributes: TextAttributes(revisionIds: <String>['r1']),
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
            onSurface: onSurface,
            primary: primary,
            primaryContainer: primaryContainer,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rootSpan = _richTextSpan(tester, plainText);
    final rootStyle = rootSpan.style!;
    TextStyle styleOf(String text) => _leafSpan(rootSpan, text)!.style!;

    expect(rootStyle.fontSize, 16);
    expect(rootStyle.height, 1.75);
    expect(rootStyle.color, onSurface);
    expect(styleOf('bold').fontWeight, FontWeight.w700);
    expect(styleOf('italic').fontStyle, FontStyle.italic);
    expect(
      styleOf('underStrike').decoration?.contains(TextDecoration.underline),
      isTrue,
    );
    expect(
      styleOf('underStrike').decoration?.contains(TextDecoration.lineThrough),
      isTrue,
    );
    expect(styleOf('colored').color, const Color(0xFFD81B60));
    expect(styleOf('highlight').backgroundColor, const Color(0xFFFFF59D));
    expect(styleOf('big').fontSize, 22);
    expect(styleOf('mono').fontFamily, 'JetBrains Mono');
    expect(styleOf('link').color, const Color(0xFF1976D2));
    expect(
      styleOf('link').decoration?.contains(TextDecoration.underline),
      isTrue,
    );
    expect(styleOf('comment').decorationStyle, TextDecorationStyle.dotted);
    expect(styleOf('comment').decorationColor, const Color(0xFFC97B00));
    expect(styleOf('comment').decorationThickness, 2);
    expect(
      styleOf('revision').backgroundColor,
      primaryContainer.withAlpha(72),
    );
    expect(styleOf('revision').decorationColor, primary);
  });

  testWidgets('defaultTextColor applies to uncolored text and updates', (
    tester,
  ) async {
    const firstDefault = Color(0xFF24507A);
    const secondDefault = Color(0xFF6A3A8A);
    const inlineColor = Color(0xFFD81B60);
    const plainText = 'plain colored link';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'plain'),
              TextRun(text: ' '),
              TextRun(
                text: 'colored',
                attributes: TextAttributes(color: 0xFFD81B60),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'link',
                attributes: TextAttributes(url: 'https://example.com'),
              ),
            ],
          ),
        ],
      ),
    );

    Widget build(Color defaultTextColor) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
              defaultTextColor: defaultTextColor,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(firstDefault));
    await tester.pumpAndSettle();

    var rootSpan = _richTextSpan(tester, plainText);
    TextStyle styleOfFirst(String text) => _leafSpan(rootSpan, text)!.style!;

    expect(rootSpan.style?.color, firstDefault);
    expect(styleOfFirst('plain').color, firstDefault);
    expect(styleOfFirst('colored').color, inlineColor);
    expect(styleOfFirst('link').color, const Color(0xFF1976D2));

    await tester.pumpWidget(build(secondDefault));
    await tester.pumpAndSettle();

    rootSpan = _richTextSpan(tester, plainText);
    TextStyle styleOfSecond(String text) => _leafSpan(rootSpan, text)!.style!;

    expect(rootSpan.style?.color, secondDefault);
    expect(styleOfSecond('plain').color, secondDefault);
    expect(styleOfSecond('colored').color, inlineColor);
    expect(styleOfSecond('link').color, const Color(0xFF1976D2));
  });

  testWidgets('applies design heading hierarchy and weak heading tones', (
    tester,
  ) async {
    const onSurface = Color(0xFF101018);
    const onSurfaceVariant = Color(0xFF5C5C66);
    const outline = Color(0xFF777680);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Heading 1')],
          ),
          TextBlockNode(
            id: 'h2',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Heading 2')],
          ),
          TextBlockNode(
            id: 'h3',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3),
            content: <InlineNode>[TextRun(text: 'Heading 3')],
          ),
          TextBlockNode(
            id: 'h4',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 4),
            content: <InlineNode>[TextRun(text: 'Heading 4')],
          ),
          TextBlockNode(
            id: 'h5',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 5),
            content: <InlineNode>[TextRun(text: 'Heading 5')],
          ),
          TextBlockNode(
            id: 'h6',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 6),
            content: <InlineNode>[TextRun(text: 'Heading 6')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            outline: outline,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextStyle styleOf(String text) => _richTextSpan(tester, text).style!;

    expect(styleOf('Heading 1').fontSize, 24);
    expect(styleOf('Heading 2').fontSize, 21);
    expect(styleOf('Heading 3').fontSize, 18);
    expect(styleOf('Heading 4').fontSize, 16);
    for (final text in <String>[
      'Heading 1',
      'Heading 2',
      'Heading 3',
      'Heading 4',
    ]) {
      expect(styleOf(text).fontWeight, FontWeight.w700);
      expect(styleOf(text).color, onSurface);
    }
    expect(styleOf('Heading 5').fontSize, 16);
    expect(styleOf('Heading 5').fontWeight, FontWeight.w600);
    expect(styleOf('Heading 5').color, onSurfaceVariant);
    expect(styleOf('Heading 6').fontSize, 16);
    expect(styleOf('Heading 6').fontWeight, FontWeight.w600);
    expect(styleOf('Heading 6').color, outline);
  });

  testWidgets('uses default paragraph spacing only between blocks', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First paragraph.')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second paragraph.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 160,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorTop = tester.getTopLeft(find.byType(WenzRichTextEditor)).dy;
    final firstRect = tester.getRect(_richText('First paragraph.'));
    final secondRect = tester.getRect(_richText('Second paragraph.'));

    expect(firstRect.top, moreOrLessEquals(editorTop, epsilon: 0.1));
    expect(firstRect.height, moreOrLessEquals(56, epsilon: 0.5));
    expect(
      secondRect.top - firstRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
  });

  testWidgets(
      'quote spacing collapses between adjacent quotes but not across non-quote neighbours',
      (tester) async {
    // Guards the P005 contract: only index-adjacent quote -> quote pairs fuse
    // (offset gap 0). Every quote <-> non-quote boundary must keep the default
    // inter-block spacing so the collapse never leaks past the run.
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Paragraph before.')],
          ),
          TextBlockNode(
            id: 'q-first',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'First quote.')],
          ),
          TextBlockNode(
            id: 'q-second',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Second quote.')],
          ),
          TextBlockNode(
            id: 'p-between',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Paragraph between.')],
          ),
          TextBlockNode(
            id: 'q-after',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Trailing quote.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 320,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(quoteBackground, findsNWidgets(3));

    final pBeforeRect = tester.getRect(_richText('Paragraph before.'));
    final qFirstRect = tester.getRect(quoteBackground.at(0));
    final qSecondRect = tester.getRect(quoteBackground.at(1));
    final pBetweenRect = tester.getRect(_richText('Paragraph between.'));
    final qAfterRect = tester.getRect(quoteBackground.at(2));

    // The two adjacent quotes fuse: their surface backgrounds touch vertically
    // with the spacing collapsed to 0 (offset adjacency).
    expect(
      qSecondRect.top - qFirstRect.bottom,
      moreOrLessEquals(0, epsilon: 0.5),
    );

    // Paragraph -> quote keeps the default spacing; the collapse does not reach
    // across the non-quote boundary.
    expect(
      qFirstRect.top - pBeforeRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );

    // Quote -> paragraph keeps the default spacing as well.
    expect(
      pBetweenRect.top - qSecondRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );

    // Paragraph -> quote again keeps the default spacing on the trailing run.
    expect(
      qAfterRect.top - pBetweenRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
  });

  testWidgets(
      'enter in a quoted paragraph keeps adjacent quote backgrounds fused immediately',
      (tester) async {
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final caret = DocumentPosition.text(
      blockId: 'quoted-enter',
      blockIndex: 0,
      offset: 5,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quoted-enter',
            type: BlockType.paragraph,
            attributes: BlockAttributes(quoted: true),
            content: <InlineNode>[TextRun(text: 'HelloWorld')],
          ),
        ],
      ),
      selection: DocumentSelection(base: caret, extent: caret),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 160,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.enter(newBlockId: 'quoted-enter-next');
    await tester.pump();

    final blocks = controller.document.blocks.cast<TextBlockNode>().toList();
    expect(blocks, hasLength(2));
    expect(blocks[0].attributes.isQuoted, isTrue);
    expect(blocks[1].attributes.isQuoted, isTrue);
    expect(quoteBackground, findsNWidgets(2));

    final firstRect = tester.getRect(quoteBackground.at(0));
    final secondRect = tester.getRect(quoteBackground.at(1));
    expect(
      secondRect.top - firstRect.bottom,
      moreOrLessEquals(4, epsilon: 0.5),
    );
  });

  testWidgets('keyboard enter on an empty quote line exits quote styling',
      (tester) async {
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final caret = DocumentPosition.text(
      blockId: 'quote-keyboard',
      blockIndex: 0,
      offset: 5,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quote-keyboard',
            type: BlockType.paragraph,
            attributes: BlockAttributes(quoted: true),
            content: <InlineNode>[TextRun(text: 'Quote')],
          ),
        ],
      ),
      selection: DocumentSelection(base: caret, extent: caret),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 160,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(quoteBackground, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    var blocks = controller.document.blocks.cast<TextBlockNode>().toList();
    expect(blocks, hasLength(2));
    expect(blocks[0].plainText, 'Quote');
    expect(blocks[0].attributes.isQuoted, isTrue);
    expect(blocks[1].plainText, isEmpty);
    expect(blocks[1].attributes.isQuoted, isTrue);
    expect(controller.selection?.extent.blockId, blocks[1].id);
    expect(controller.selection?.extent.offset, 0);
    expect(quoteBackground, findsNWidgets(2));

    final emptyQuoteBlockId = blocks[1].id;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    blocks = controller.document.blocks.cast<TextBlockNode>().toList();
    expect(blocks, hasLength(2));
    expect(blocks[0].attributes.isQuoted, isTrue);
    expect(blocks[1].id, emptyQuoteBlockId);
    expect(blocks[1].type, BlockType.paragraph);
    expect(blocks[1].plainText, isEmpty);
    expect(blocks[1].attributes.isQuoted, isFalse);
    expect(controller.selection?.extent.blockId, emptyQuoteBlockId);
    expect(controller.selection?.extent.offset, 0);
    expect(quoteBackground, findsOneWidget);
  });

  testWidgets(
      'quote spacing still collapses when editor blockSpacing is customised',
      (tester) async {
    // Regression root cause for consecutive quote seams: `blockSpacing` is the
    // transparent vertical offset between independently painted block surfaces.
    // It must not win for quote -> quote, but must still win at quote run
    // boundaries so paragraphs do not visually merge into the quote group.
    const customSpacing = 24.0;
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-before-custom-spacing',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before custom spacing.')],
          ),
          TextBlockNode(
            id: 'q-first-custom-spacing',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'First custom quote.')],
          ),
          TextBlockNode(
            id: 'q-second-custom-spacing',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Second custom quote.')],
          ),
          TextBlockNode(
            id: 'p-after-custom-spacing',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After custom spacing.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              blockSpacing: customSpacing,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(quoteBackground, findsNWidgets(2));

    final pBeforeRect = tester.getRect(_richText('Before custom spacing.'));
    final qFirstRect = tester.getRect(quoteBackground.first);
    final qSecondRect = tester.getRect(quoteBackground.last);
    final pAfterRect = tester.getRect(_richText('After custom spacing.'));

    expect(
      qSecondRect.top - qFirstRect.bottom,
      moreOrLessEquals(0, epsilon: 0.5),
    );
    expect(
      qFirstRect.top - pBeforeRect.bottom,
      moreOrLessEquals(customSpacing, epsilon: 0.75),
    );
    expect(
      pAfterRect.top - qSecondRect.bottom,
      moreOrLessEquals(customSpacing, epsilon: 0.75),
    );
  });

  testWidgets(
      'three or more adjacent quotes fuse across empty and indented quote blocks',
      (tester) async {
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final quoteAccent = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-accent'),
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-before-long-quote-run',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before long quote run.')],
          ),
          TextBlockNode(
            id: 'q-run-first',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'First quote in run.')],
          ),
          TextBlockNode(
            id: 'q-run-empty',
            type: BlockType.quote,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'q-run-indented',
            type: BlockType.quote,
            attributes: BlockAttributes(indent: 2),
            content: <InlineNode>[TextRun(text: 'Indented quote in run.')],
          ),
          TextBlockNode(
            id: 'q-run-last',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Last quote in run.')],
          ),
          TextBlockNode(
            id: 'p-after-long-quote-run',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After long quote run.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(quoteBackground, findsNWidgets(4));
    expect(quoteAccent, findsNWidgets(4));

    final pBeforeRect = tester.getRect(_richText('Before long quote run.'));
    final pAfterRect = tester.getRect(_richText('After long quote run.'));
    final quoteRects = List<Rect>.generate(
      4,
      (index) => tester.getRect(quoteBackground.at(index)),
    );
    final accentRects = List<Rect>.generate(
      4,
      (index) => tester.getRect(quoteAccent.at(index)),
    );

    for (var index = 1; index < quoteRects.length; index++) {
      expect(
        quoteRects[index].top - quoteRects[index - 1].bottom,
        moreOrLessEquals(0, epsilon: 0.5),
      );
      expect(
        accentRects[index].top - accentRects[index - 1].bottom,
        moreOrLessEquals(0, epsilon: 0.5),
      );
    }

    // The indented quote remains part of the same quote group: it receives an
    // interior radius and zero vertical gap. Horizontal indent still belongs to
    // the row shell and is intentionally not asserted as a group break here.
    expect(
      quoteRects.first.top - pBeforeRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
    expect(
      pAfterRect.top - quoteRects.last.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(quoteBackground)
        .map((widget) => widget.decoration as BoxDecoration)
        .toList();
    expect(
      decorations[0].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.circular(8),
        bottomEnd: Radius.zero,
      ),
    );
    expect(
      decorations[1].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.zero,
      ),
    );
    expect(
      decorations[2].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.zero,
      ),
    );
    expect(
      decorations[3].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.circular(8),
      ),
    );
  });

  testWidgets('quoted heading and list blocks fuse as one quote group',
      (tester) async {
    final quoteBackground = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final quoteAccent = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-accent'),
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before-composite-quote',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before composite quote.')],
          ),
          TextBlockNode(
            id: 'quoted-heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2, quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted heading')],
          ),
          TextBlockNode(
            id: 'quoted-ordered',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted ordered item')],
          ),
          TextBlockNode(
            id: 'quoted-task',
            type: BlockType.listItem,
            attributes:
                BlockAttributes(listType: 'task', checked: true, quoted: true),
            content: <InlineNode>[TextRun(text: 'Quoted checked task')],
          ),
          TextBlockNode(
            id: 'after-composite-quote',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After composite quote.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(quoteBackground, findsNWidgets(3));
    expect(quoteAccent, findsNWidgets(3));

    final beforeRect = tester.getRect(_richText('Before composite quote.'));
    final afterRect = tester.getRect(_richText('After composite quote.'));
    final quoteRects = List<Rect>.generate(
      3,
      (index) => tester.getRect(quoteBackground.at(index)),
    );
    final accentRects = List<Rect>.generate(
      3,
      (index) => tester.getRect(quoteAccent.at(index)),
    );

    for (var index = 1; index < quoteRects.length; index++) {
      expect(
        quoteRects[index].top - quoteRects[index - 1].bottom,
        moreOrLessEquals(0, epsilon: 0.5),
      );
      expect(
        accentRects[index].top - accentRects[index - 1].bottom,
        moreOrLessEquals(0, epsilon: 0.5),
      );
    }
    expect(
      quoteRects.first.top - beforeRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
    expect(
      afterRect.top - quoteRects.last.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(quoteBackground)
        .map((widget) => widget.decoration as BoxDecoration)
        .toList();
    expect(
      decorations[0].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.circular(8),
        bottomEnd: Radius.zero,
      ),
    );
    expect(
      decorations[1].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.zero,
      ),
    );
    expect(
      decorations[2].borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.circular(8),
      ),
    );
  });

  testWidgets('empty paragraph accepts taps across its visible text row', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'empty paragraph test editor');
    addTearDown(focusNode.dispose);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before paragraph')],
          ),
          TextBlockNode(
            id: 'empty',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After paragraph')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: WenzRichTextEditor(
              controller: controller,
              focusNode: focusNode,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emptyRect = tester.getRect(_emptyRichText());
    expect(emptyRect.height, greaterThan(0));
    expect(
      emptyRect.left,
      greaterThan(tester.getRect(_richText('Before paragraph')).left),
    );
    expect(
      emptyRect.right,
      lessThanOrEqualTo(tester.getRect(find.byType(WenzRichTextEditor)).right),
    );

    for (final fraction in <double>[0.05, 0.5, 0.95]) {
      await _tapSingle(
        tester,
        Offset(
          emptyRect.left + emptyRect.width * fraction,
          emptyRect.center.dy,
        ),
      );
      _expectBlockTextSelection(
        controller.selection,
        blockId: 'empty',
        blockIndex: 1,
        baseOffset: 0,
        extentOffset: 0,
      );
      expect(controller.hasFocus, isTrue);
    }
  });

  testWidgets('wrapped line right-side blank taps place caret on that line', (
    tester,
  ) async {
    const text =
        'one two extraordinarily three four magnificent five six seven eight';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'wrapped',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: text)],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 180,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = _richText(text);
    final lineMetrics = _richTextLineMetrics(tester, finder);
    expect(lineMetrics.length, greaterThanOrEqualTo(3));

    final firstTarget = _richTextRightBlankTarget(
      tester,
      finder,
      lineIndex: 0,
    );
    final secondTarget = _richTextRightBlankTarget(
      tester,
      finder,
      lineIndex: 1,
    );
    expect(
      firstTarget.lineRange.end,
      lessThanOrEqualTo(secondTarget.lineRange.start),
    );
    expect(secondTarget.lineRange.end, lessThan(text.length));

    await _tapSingle(tester, firstTarget.globalPoint);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'wrapped',
      blockIndex: 0,
      baseOffset: firstTarget.lineRange.end,
      extentOffset: firstTarget.lineRange.end,
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
    expect(controller.hasFocus, isTrue);

    await _tapSingle(tester, secondTarget.globalPoint);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'wrapped',
      blockIndex: 0,
      baseOffset: secondTarget.lineRange.end,
      extentOffset: secondTarget.lineRange.end,
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
    expect(controller.hasFocus, isTrue);
  });

  testWidgets('short paragraph right-side blank taps place caret at line end', (
    tester,
  ) async {
    const text = 'Tiny';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before paragraph')],
          ),
          TextBlockNode(
            id: 'short',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: text)],
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After paragraph')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = _richTextRightBlankTarget(
      tester,
      _richText(text),
      lineIndex: 0,
    );
    expect(target.lineRange.end, text.length);

    await _tapSingle(tester, target.globalPoint);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'short',
      blockIndex: 1,
      baseOffset: text.length,
      extentOffset: text.length,
    );
    expect(controller.hasFocus, isTrue);
  });

  testWidgets('explicit newline right-side blank taps use each line end', (
    tester,
  ) async {
    const text = 'alpha\nbeta\ngamma';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'multiline',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: text)],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = _richText(text);
    final lines = _richTextLineMetrics(tester, finder);
    expect(lines, hasLength(3));
    final targets = <_RichTextLineBlankTarget>[
      for (var i = 0; i < lines.length; i++)
        _richTextRightBlankTarget(tester, finder, lineIndex: i),
    ];
    expect(
      targets[0].lineRange.end,
      lessThanOrEqualTo(targets[1].lineRange.start),
    );
    expect(
      targets[1].lineRange.end,
      lessThanOrEqualTo(targets[2].lineRange.start),
    );
    expect(targets[2].lineRange.end, text.length);

    for (final target in targets) {
      await _tapSingle(tester, target.globalPoint);
      _expectBlockTextSelection(
        controller.selection,
        blockId: 'multiline',
        blockIndex: 0,
        baseOffset: target.lineRange.end,
        extentOffset: target.lineRange.end,
      );
      expect(controller.hasFocus, isTrue);
    }
  });

  testWidgets('empty text-bearing block variants accept line taps', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'empty-bullet',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'bullet'),
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'empty-todo',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'empty-quote',
            type: BlockType.quote,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'empty-heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'heading-child',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Heading child')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const expected = <MapEntry<String, int>>[
      MapEntry<String, int>('empty-bullet', 0),
      MapEntry<String, int>('empty-todo', 1),
      MapEntry<String, int>('empty-quote', 2),
      MapEntry<String, int>('empty-heading', 3),
    ];
    for (var index = 0; index < expected.length; index++) {
      final rect = tester.getRect(_emptyRichText(index));
      await _tapSingle(tester, rect.center);
      _expectBlockTextSelection(
        controller.selection,
        blockId: expected[index].key,
        blockIndex: expected[index].value,
        baseOffset: 0,
        extentOffset: 0,
      );
    }

    final checkboxFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-empty-todo'),
    );
    await tester.tap(checkboxFinder);
    await tester.pump();
    expect(
      (controller.document.blocks[1] as TextBlockNode).attributes.checked,
      isTrue,
    );

    final collapseFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-empty-heading'),
    );
    expect(
      tester.getRect(_emptyRichText(3)).center.dy -
          tester.getRect(collapseFinder).center.dy,
      moreOrLessEquals(0, epsilon: 2),
    );
    expect(_richText('Heading child'), findsOneWidget);
    await tester.tap(collapseFinder);
    await tester.pumpAndSettle();
    expect(_richText('Heading child'), findsNothing);
  });

  testWidgets('uses design heading spacing between adjacent blocks', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Intro paragraph.')],
          ),
          TextBlockNode(
            id: 'h2',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section heading')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Following paragraph.')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorTop = tester.getTopLeft(find.byType(WenzRichTextEditor)).dy;
    final introRect = tester.getRect(_richText('Intro paragraph.'));
    final headingRect = tester.getRect(_richText('Section heading'));
    final followingRect = tester.getRect(_richText('Following paragraph.'));

    expect(introRect.top, moreOrLessEquals(editorTop, epsilon: 0.1));
    expect(
      headingRect.top - introRect.bottom,
      moreOrLessEquals(9.6, epsilon: 0.5),
    );
    expect(
      followingRect.top - headingRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
  });

  testWidgets('renders heading collapse affordance and toggles by keyboard', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body-1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Body one')],
          ),
          TextBlockNode(
            id: 'body-2',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3),
            content: <InlineNode>[TextRun(text: 'Nested title')],
          ),
          TextBlockNode(
            id: 'body-3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Body three')],
          ),
          TextBlockNode(
            id: 'leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Leaf title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sectionButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-section'),
    );
    final leafButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-leaf'),
    );

    expect(sectionButton, findsOneWidget);
    expect(leafButton, findsNothing);
    expect(find.byTooltip('无可折叠内容'), findsNothing);
    expect(
      find.descendant(
        of: sectionButton,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<IconButton>(sectionButton).tooltip,
      '折叠标题内容（3 个块）',
    );
    expect(tester.widget<IconButton>(sectionButton).onPressed, isNotNull);
    expect(_richText('Body one'), findsOneWidget);
    expect(_richText('Body three'), findsOneWidget);
    expect(controller.selection, isNull);

    await tester.tap(sectionButton);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(
      find.descendant(
        of: sectionButton,
        matching: find.byIcon(Icons.keyboard_arrow_right_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('展开标题内容（3 个块已隐藏）'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(_richText('Body one'), findsNothing);
    expect(_richText('Nested title'), findsNothing);
    expect(_richText('Body three'), findsNothing);
    expect(_richText('Leaf title'), findsOneWidget);
    expect(controller.selection, isNull);
    expect(find.text('复制块内容'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isFalse);
    expect(find.byTooltip('折叠标题内容（3 个块）'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(_richText('Body one'), findsOneWidget);
    expect(_richText('Nested title'), findsOneWidget);
    expect(_richText('Body three'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(_richText('Body one'), findsNothing);
    expect(_richText('Nested title'), findsNothing);
    expect(_richText('Body three'), findsNothing);
  });

  testWidgets(
      'renders all blocks without a collapse button when no outline '
      'controller is attached', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Section body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
    );

    // No outlineController: the editor must fall back to rendering every block
    // and never reserve the left-side heading collapse slot, without throwing.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-section'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-next'),
      ),
      findsNothing,
    );
    expect(_richText('Section title'), findsOneWidget);
    expect(_richText('Section body'), findsOneWidget);
    expect(_richText('Next title'), findsOneWidget);

    final sectionHandleRect = tester.getRect(_blockDragHandleFinder('section'));
    final bodyHandleRect = tester.getRect(_blockDragHandleFinder('body'));
    final nextHandleRect = tester.getRect(_blockDragHandleFinder('next'));
    expect(
      tester.getTopLeft(_richText('Section title')).dx -
          sectionHandleRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(_richText('Section body')).dx - bodyHandleRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(_richText('Next title')).dx - nextHandleRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );
  });

  testWidgets(
      'mobile uses one collapse-button width for rows without collapse chrome',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'mobile-section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Mobile section')],
          ),
          TextBlockNode(
            id: 'mobile-body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Mobile body')],
          ),
          TextBlockNode(
            id: 'mobile-leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Mobile leaf')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            outlineController: outline,
            padding: EdgeInsets.zero,
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The compact row geometry is resolved during the build above. Restore
    // the foundation override before assertions so the test binding's global
    // invariant check also sees the default platform state.
    debugDefaultTargetPlatformOverride = null;

    final collapseButton = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-heading-collapse-mobile-section',
      ),
    );
    expect(collapseButton, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-heading-collapse-mobile-leaf',
        ),
      ),
      findsNothing,
    );

    final editorLeft = tester.getRect(find.byType(WenzRichTextEditor)).left;
    final buttonRect = tester.getRect(collapseButton);
    final sectionLeft = tester.getTopLeft(_richText('Mobile section')).dx;
    final bodyLeft = tester.getTopLeft(_richText('Mobile body')).dx;
    final leafLeft = tester.getTopLeft(_richText('Mobile leaf')).dx;

    expect(buttonRect.left, moreOrLessEquals(editorLeft, epsilon: 0.5));
    expect(buttonRect.width, moreOrLessEquals(24, epsilon: 0.5));
    expect(
      sectionLeft - buttonRect.right,
      moreOrLessEquals(0, epsilon: 0.5),
    );
    expect(
      bodyLeft - editorLeft,
      moreOrLessEquals(buttonRect.width, epsilon: 0.5),
    );
    expect(bodyLeft, moreOrLessEquals(sectionLeft, epsilon: 0.5));
    expect(leafLeft, moreOrLessEquals(sectionLeft, epsilon: 0.5));
  });

  testWidgets('read-only mode toggles heading collapse without editing', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Read-only section')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Read-only hidden body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next read-only section')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    final beforeJson = controller.toJson();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              readOnly: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-section'),
    );
    expect(button, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-next'),
      ),
      findsNothing,
    );
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    expect(_richText('Read-only hidden body'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(_richText('Read-only hidden body'), findsNothing);
    expect(controller.toJson(), beforeJson);
    expect(controller.canUndo, isFalse);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isFalse);
    expect(_richText('Read-only hidden body'), findsOneWidget);
    expect(controller.toJson(), beforeJson);
  });

  testWidgets(
      'heading collapse button keeps chrome gap from drag handle in editable '
      'rows', (tester) async {
    // Regression guard for the OverflowBox(maxWidth: 0) bug that shrank the
    // collapse affordance to zero width and made it disappear. In editable
    // mode collapsible headings render a full-size, hit-testable collapse
    // button in the row chrome rail. The block drag handle, chrome gap,
    // collapse button, and content gap must remain distinct rectangles. Leaf
    // headings do not mount disabled collapse chrome.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Body content')],
          ),
          TextBlockNode(
            id: 'leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Leaf title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sectionButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-section'),
    );
    final leafButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-leaf'),
    );
    expect(sectionButton, findsOneWidget);
    expect(leafButton, findsNothing);
    expect(tester.widget<IconButton>(sectionButton).onPressed, isNotNull);
    expect(find.byTooltip('无可折叠内容'), findsNothing);

    final visibleSectionRect = tester.getRect(sectionButton);
    // Full-size and visible — not shrunk to zero by a layout wrapper.
    expect(visibleSectionRect.width, greaterThan(0));
    expect(visibleSectionRect.height, greaterThan(0));
    // On-screen: left edge must not run off the viewport's left side.
    expect(visibleSectionRect.left, greaterThanOrEqualTo(0));

    // The collapsible section button must stay inside the gutter: it starts
    // after the drag-handle hit target plus chromeGap, and it leaves the
    // standard gapToContent before the heading text.
    final sectionRect = tester.getRect(sectionButton);
    final sectionTextLeft = tester.getTopLeft(_richText('Section title')).dx;
    final sectionHandleRect = tester.getRect(_blockDragHandleFinder('section'));
    expect(
      sectionRect.left - sectionHandleRect.right,
      moreOrLessEquals(BlockDragHandleSpec.chromeGap, epsilon: 0.5),
    );
    expect(
      sectionTextLeft - sectionRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );
    expect(
      sectionTextLeft - sectionHandleRect.left,
      moreOrLessEquals(BlockDragHandleSpec.railWidth, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(_richText('Body content')).dx,
      moreOrLessEquals(sectionTextLeft, epsilon: 0.5),
    );
  });

  testWidgets('programmatic selection in hidden block expands its heading', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('section'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_richText('Hidden body'), findsNothing);

    controller.setSelection(collapsedTextSelection('body', 1, 0));
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isFalse);
    expect(_richText('Hidden body'), findsOneWidget);
    expect(controller.selection, collapsedTextSelection('body', 1, 0));
  });

  testWidgets('body heading collapse leaves outline tree expanded', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'child',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Child heading')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Child body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Next section')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: 220,
                child: WenzOutlinePanel(controller: outline, width: 220),
              ),
              Expanded(
                child: WenzRichTextEditor(
                  controller: controller,
                  outlineController: outline,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child heading'), findsOneWidget);
    expect(_richText('Child heading'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-section'),
      ),
    );
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(_richText('Child heading'), findsNothing);
    expect(_richText('Child body'), findsNothing);
    expect(find.text('Child heading'), findsOneWidget);
  });

  testWidgets('heading chrome does not indent heading text', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'title',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Aligned title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Aligned body')],
          ),
          CodeBlockNode(
            id: 'code',
            code: 'final aligned = true;',
            language: 'dart',
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headingTextLeft = tester.getTopLeft(_richText('Aligned title')).dx;
    final bodyTextLeft = tester.getTopLeft(_richText('Aligned body')).dx;
    final headingRect = tester.getRect(_richText('Aligned title'));
    final bodyRect = tester.getRect(_richText('Aligned body'));
    final titleDragRect = tester.getRect(_blockDragHandleFinder('title'));
    final bodyDragRect = tester.getRect(_blockDragHandleFinder('body'));
    final codeDragRect = tester.getRect(_blockDragHandleFinder('code'));
    final collapseRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-title'),
      ),
    );
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-body'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-code'),
      ),
      findsNothing,
    );

    // The collapsible heading keeps the full editable row chrome sequence:
    // drag handle, chromeGap, collapse hit target, then gapToContent before
    // content.
    expect(
      collapseRect.left - titleDragRect.right,
      moreOrLessEquals(BlockDragHandleSpec.chromeGap, epsilon: 0.5),
    );
    expect(
      headingTextLeft - collapseRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );
    expect(
      headingTextLeft - titleDragRect.left,
      moreOrLessEquals(BlockDragHandleSpec.railWidth, epsilon: 0.5),
    );
    // Heading text vertically aligns with its collapse button.
    expect(
      headingRect.center.dy - collapseRect.center.dy,
      moreOrLessEquals(0, epsilon: 2),
    );
    // Heading and non-heading body text left edges align because every row
    // reserves the same rail while outline chrome is attached.
    expect(headingTextLeft, moreOrLessEquals(bodyTextLeft, epsilon: 0.5));
    // Rows without an actual collapse button reuse the collapse chrome slot for
    // their drag handle instead of remaining in the leftmost operation column.
    expect(
      bodyDragRect.left,
      moreOrLessEquals(collapseRect.left, epsilon: 0.5),
    );
    expect(
      codeDragRect.left,
      moreOrLessEquals(collapseRect.left, epsilon: 0.5),
    );
    // Non-heading rows still reserve the full editable outline rail, so they
    // do not shift left when a neighbouring heading shows the collapse button.
    expect(
      bodyTextLeft - titleDragRect.left,
      moreOrLessEquals(BlockDragHandleSpec.railWidth, epsilon: 0.5),
    );
    expect(
      tester
              .getRect(
                find.byKey(
                  const ValueKey<String>('wenz-richtext-code-block-code'),
                ),
              )
              .left -
          titleDragRect.left,
      moreOrLessEquals(BlockDragHandleSpec.railWidth, epsilon: 0.5),
    );
    expect(
      bodyRect.center.dy - bodyDragRect.center.dy,
      moreOrLessEquals(0, epsilon: 2),
    );
  });

  testWidgets(
      'collapsible heading text aligns with non-collapsible heading and paragraph',
      (tester) async {
    // P001/P003: with an outline attached, every editable row reserves the
    // full BlockDragHandleSpec.railWidth so heading text, leaf headings, and
    // non-heading paragraphs share one content edge.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Collapsible heading')],
          ),
          TextBlockNode(
            id: 'h1-child',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Child paragraph')],
          ),
          TextBlockNode(
            id: 'h2',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Non-collapsible heading')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Plain paragraph')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapse button is findable via key.
    final collapseBtn = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-h1'),
    );
    expect(collapseBtn, findsOneWidget);

    // Non-collapsible heading does not mount a disabled collapse button.
    final h2CollapseBtn = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-h2'),
    );
    expect(h2CollapseBtn, findsNothing);
    expect(find.byTooltip('无可折叠内容'), findsNothing);

    // All text left edges align — the collapse button does not push content.
    final h1TextLeft = tester.getTopLeft(_richText('Collapsible heading')).dx;
    final h2TextLeft =
        tester.getTopLeft(_richText('Non-collapsible heading')).dx;
    final p1TextLeft = tester.getTopLeft(_richText('Plain paragraph')).dx;
    expect(h1TextLeft, moreOrLessEquals(h2TextLeft, epsilon: 0.5));
    expect(h1TextLeft, moreOrLessEquals(p1TextLeft, epsilon: 0.5));

    // Collapse button does not extend into the content area.
    final collapseRect = tester.getRect(collapseBtn);
    expect(collapseRect.right, lessThan(h1TextLeft));
  });

  testWidgets(
      'read-only heading collapse: button visible, no drag handle, text aligns',
      (tester) async {
    // P003: In read-only mode the collapse button keeps its compact no-drag
    // gutter. No drag handles are rendered and no editable rail is reserved.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ro-h',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Read-only heading')],
          ),
          TextBlockNode(
            id: 'ro-child',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Read-only child')],
          ),
          TextBlockNode(
            id: 'ro-p',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Read-only paragraph')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              readOnly: true,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Collapse button is present and visible.
    final collapseBtn = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-ro-h'),
    );
    expect(collapseBtn, findsOneWidget);
    final collapseRect = tester.getRect(collapseBtn);
    expect(collapseRect.width, greaterThan(0));
    expect(collapseRect.height, greaterThan(0));

    // No drag handles in read-only mode (verified per-block via key pattern).
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-block-drag-handle-ro-h'),
      ),
      findsNothing,
    );

    // Collapse button does not extend into heading text and does not reserve
    // the editable drag-handle gap in read-only mode.
    final headingTextLeft =
        tester.getTopLeft(_richText('Read-only heading')).dx;
    final paragraphTextLeft =
        tester.getTopLeft(_richText('Read-only paragraph')).dx;
    expect(
      headingTextLeft - collapseRect.right,
      moreOrLessEquals(0, epsilon: 0.5),
    );
    expect(headingTextLeft, moreOrLessEquals(paragraphTextLeft, epsilon: 0.5));
  });

  testWidgets('Delete at collapsed heading boundary expands before editing', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
      selection: collapsedTextSelection('section', 0, 13),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('section'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_richText('Hidden body'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isFalse);
    expect(_richText('Hidden body'), findsOneWidget);
    expect((controller.document.blocks[1] as TextBlockNode).plainText,
        'Hidden body');
  });

  testWidgets('tap at a hidden block position does not target hidden content', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden body')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hiddenBodyCenter = tester.getCenter(_richText('Hidden body'));

    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-section'),
      ),
    );
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(_richText('Hidden body'), findsNothing);

    await tester.tapAt(hiddenBodyCenter);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(controller.selection?.extent.blockId, isNot('body'));
  });

  testWidgets('tap at hidden empty block position does not target empty child',
      (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'empty-child',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After visible')],
          ),
        ],
      ),
      selection: collapsedTextSelection('section', 0, 0),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hiddenEmptyCenter = tester.getCenter(_emptyRichText());
    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-section'),
      ),
    );
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(_emptyRichText(), findsNothing);

    await tester.tapAt(hiddenEmptyCenter);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('section'), isTrue);
    expect(controller.selection?.extent.blockId, isNot('empty-child'));
  });

  testWidgets('find match inside hidden content expands and restores selection',
      (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Section title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Find needle here')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    final findController = WenzFindReplaceController(
      editor: controller,
      outlineController: outline,
    );
    addTearDown(findController.dispose);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('section'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              findController: findController,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_richText('Find needle here'), findsNothing);

    findController.setQuery('needle');
    await tester.pumpAndSettle();

    expect(findController.currentMatch?.blockId, 'body');
    expect(outline.isCollapsed('section'), isFalse);
    expect(_richText('Find needle here'), findsOneWidget);
    expect(controller.selection, textSelection('body', 1, 5, 11));
  });

  testWidgets('outline jump to hidden heading reveals it and moves selection', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'parent',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Parent title')],
          ),
          TextBlockNode(
            id: 'child',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3, anchor: 'child-anchor'),
            content: <InlineNode>[TextRun(text: 'Child title')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Child body')],
          ),
          TextBlockNode(
            id: 'next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Next title')],
          ),
        ],
      ),
    );
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('parent'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              outlineController: outline,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_richText('Child title'), findsNothing);

    expect(outline.selectByAnchor('child-anchor', requestFocus: false), isTrue);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('parent'), isFalse);
    expect(_richText('Child title'), findsOneWidget);
    expect(controller.selection, collapsedTextSelection('child', 1, 0));
  });

  testWidgets('applies paragraph alignment and indent within bounds', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'left',
            type: BlockType.paragraph,
            attributes: BlockAttributes(alignment: 'left'),
            content: <InlineNode>[TextRun(text: 'Left aligned')],
          ),
          TextBlockNode(
            id: 'center',
            type: BlockType.paragraph,
            attributes: BlockAttributes(alignment: 'center'),
            content: <InlineNode>[TextRun(text: 'Center aligned')],
          ),
          TextBlockNode(
            id: 'right',
            type: BlockType.paragraph,
            attributes: BlockAttributes(alignment: 'right'),
            content: <InlineNode>[TextRun(text: 'Right aligned')],
          ),
          TextBlockNode(
            id: 'justify',
            type: BlockType.paragraph,
            attributes: BlockAttributes(alignment: 'justify'),
            content: <InlineNode>[TextRun(text: 'Justified aligned')],
          ),
          TextBlockNode(
            id: 'indent',
            type: BlockType.paragraph,
            attributes: BlockAttributes(indent: 2),
            content: <InlineNode>[TextRun(text: 'Indented paragraph')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextAlign alignOf(String text) {
      return tester.widget<RichText>(_richText(text)).textAlign;
    }

    expect(alignOf('Left aligned'), TextAlign.start);
    expect(alignOf('Center aligned'), TextAlign.center);
    expect(alignOf('Right aligned'), TextAlign.right);
    expect(alignOf('Justified aligned'), TextAlign.justify);

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    final indentedRect = tester.getRect(_richText('Indented paragraph'));
    // Editor uses EdgeInsets.zero padding; content starts at activeChromeWidth
    // (hitSize.width + gapToContent) for blocks with drag handles.
    expect(
      indentedRect.left - editorRect.left,
      moreOrLessEquals(
        BlockDragHandleSpec.hitSize.width +
            BlockDragHandleSpec.gapToContent +
            48,
        epsilon: 0.5,
      ),
    );
    expect(indentedRect.right, lessThanOrEqualTo(editorRect.right + 0.5));
  });

  testWidgets('todo checkbox toggles checked state without selecting text',
      (tester) async {
    final initialSelection = collapsedTextSelection('task1', 0, 4);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'task1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'Ship core')],
          ),
        ],
      ),
      selection: initialSelection,
    );
    var changedCount = 0;
    var selectionChangedCount = 0;
    final commands = <String>[];
    controller.onChanged = (_) => changedCount += 1;
    controller.onSelectionChanged = (_) => selectionChangedCount += 1;
    controller.onCommandExecuted = (command, _) {
      commands.add(command.description);
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final checkboxFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-task1'),
    );
    TextBlockNode taskBlock() =>
        controller.document.blocks.single as TextBlockNode;

    expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

    await tester.tap(checkboxFinder);
    await tester.pump();

    expect(taskBlock().attributes.checked, isTrue);
    expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    expect(changedCount, 1);
    expect(selectionChangedCount, 0);
    expect(commands, <String>['setTodoChecked']);
    expect(controller.selection, initialSelection);
    final checkedText = tester.widget<RichText>(_richText('Ship core'));
    expect((checkedText.text as TextSpan).style?.decoration,
        TextDecoration.lineThrough);

    await tester.tap(checkboxFinder);
    await tester.pump();

    expect(taskBlock().attributes.checked, isFalse);
    expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);
    expect(changedCount, 2);
    expect(selectionChangedCount, 0);
    expect(commands, <String>['setTodoChecked', 'setTodoChecked']);
    final uncheckedText = tester.widget<RichText>(_richText('Ship core'));
    expect((uncheckedText.text as TextSpan).style?.decoration,
        isNot(TextDecoration.lineThrough));

    await _tapTextOffset(tester, 'Ship core', 2);
    await tester.pump();

    _expectBlockTextSelection(
      controller.selection,
      blockId: 'task1',
      blockIndex: 0,
      baseOffset: 2,
      extentOffset: 2,
    );
  });

  testWidgets('ordered todo renders number and checkbox and toggles state',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ordered-todo-1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: false),
            content: <InlineNode>[TextRun(text: 'First ordered todo')],
          ),
          TextBlockNode(
            id: 'ordered-todo-2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', checked: true),
            content: <InlineNode>[TextRun(text: 'Second ordered todo')],
          ),
          TextBlockNode(
            id: 'plain-task',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'Plain todo')],
          ),
        ],
      ),
      selection: collapsedTextSelection('ordered-todo-1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller, enableIme: false),
        ),
      ),
    );

    final firstCheckbox = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-ordered-todo-1'),
    );
    final secondCheckbox = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-ordered-todo-2'),
    );
    final plainCheckbox = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-plain-task'),
    );
    expect(firstCheckbox, findsOneWidget);
    expect(secondCheckbox, findsOneWidget);
    expect(plainCheckbox, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('wenz-richtext-list-marker-ordered-todo-1'),
        ),
        matching: find.text('1.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('wenz-richtext-list-marker-ordered-todo-2'),
        ),
        matching: find.text('2.'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
          const ValueKey<String>('wenz-richtext-list-marker-plain-task')),
      findsNothing,
    );

    await tester.tap(firstCheckbox);
    await tester.pump();

    final first = controller.document.blocks[0] as TextBlockNode;
    expect(first.attributes.listType, 'ordered');
    expect(first.attributes.checked, isTrue);
    expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);
    final completedText =
        tester.widget<RichText>(_richText('First ordered todo'));
    expect((completedText.text as TextSpan).style?.decoration,
        TextDecoration.lineThrough);
  });

  testWidgets('renders quote blocks with themed background', (tester) async {
    const quoteRenderText =
        'Quoted $_formulaPlaceholder 😀 from @Ada\nsecond line';
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'quote1',
            type: BlockType.quote,
            content: <InlineNode>[
              TextRun(text: 'Quoted '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' '),
              InlineEmbed(
                embedType: 'emoji',
                data: <String, Object?>{'emoji': '😀'},
              ),
              TextRun(text: ' from '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
              TextRun(text: '\nsecond line'),
            ],
          ),
          TextBlockNode(
            id: 'quote2',
            type: BlockType.quote,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after quote')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final backgroundFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    expect(backgroundFinder, findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-quote-accent')),
      findsNWidgets(2),
    );
    final background = tester.widgetList<DecoratedBox>(backgroundFinder).first;
    final decoration = background.decoration as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surfaceContainer);
    // quote1 opens a same-indent run with quote2, so it keeps only the top-end
    // corner and squares its bottom edge; quote2 joins it without a seam.
    expect(
      decoration.borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.circular(8),
        bottomEnd: Radius.zero,
      ),
    );
    expect(decoration.border, isNull);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    final expectedQuoteLeft = editorRect.left +
        16 +
        BlockDragHandleSpec.hitSize.width +
        BlockDragHandleSpec.gapToContent;
    final expectedQuoteRight = editorRect.right - 16;
    final firstQuoteRect = tester.getRect(backgroundFinder.first);
    final secondQuoteRect = tester.getRect(backgroundFinder.last);
    expect(firstQuoteRect.left, closeTo(expectedQuoteLeft, 0.001));
    expect(firstQuoteRect.right, closeTo(expectedQuoteRight, 0.001));
    expect(secondQuoteRect.left, closeTo(expectedQuoteLeft, 0.001));
    expect(secondQuoteRect.right, closeTo(expectedQuoteRight, 0.001));
    // quote2 closes the run: its top edge squares and it keeps only the
    // bottom-end corner, so the right join edge carries no inward notch.
    final secondDecoration = tester
        .widgetList<DecoratedBox>(backgroundFinder)
        .last
        .decoration as BoxDecoration;
    expect(
      secondDecoration.borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.zero,
        bottomEnd: Radius.circular(8),
      ),
    );
    // The run fuses: the two backgrounds touch vertically with no
    // default-spacing gap, so they read as one continuous surface.
    expect(secondQuoteRect.top, closeTo(firstQuoteRect.bottom, 0.01));
    expect(secondQuoteRect.top - firstQuoteRect.bottom, lessThan(1.0));
    final accentFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-accent'),
    );
    final accent = tester.widgetList<DecoratedBox>(accentFinder).first;
    final accentDecoration = accent.decoration as BoxDecoration;
    expect(accentDecoration.color, theme.colorScheme.primary);
    expect(tester.getSize(accentFinder.first).width, 4);
    final quoteSpan = _richTextSpan(tester, quoteRenderText);
    expect(quoteSpan.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(quoteSpan.style?.fontStyle, FontStyle.italic);
    expect(find.text('|'), findsNothing);
    expect(_richText(quoteRenderText), findsOneWidget);
    expect(_richText('after quote'), findsOneWidget);

    await _tapTextOffset(tester, quoteRenderText, 0);
    await tester.pump();
    await _sendShiftArrowRight(tester);

    _expectBlockTextSelection(
      controller.selection,
      blockId: 'quote1',
      blockIndex: 0,
      baseOffset: 0,
      extentOffset: 1,
    );

    await _tapSingle(
        tester, Offset(secondQuoteRect.right - 4, secondQuoteRect.center.dy));
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'quote2',
      blockIndex: 1,
      baseOffset: 0,
      extentOffset: 0,
    );
  });

  testWidgets('renders list markers with design inset and compact nesting',
      (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'u1',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'Top bullet')],
          ),
          TextBlockNode(
            id: 'u2',
            type: BlockType.listItem,
            content: <InlineNode>[TextRun(text: 'Second bullet')],
          ),
          TextBlockNode(
            id: 'u-child',
            type: BlockType.listItem,
            attributes: BlockAttributes(indent: 1),
            content: <InlineNode>[TextRun(text: 'Nested bullet')],
          ),
          TextBlockNode(
            id: 'o1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'First ordered')],
          ),
          TextBlockNode(
            id: 'o-child',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered', indent: 1),
            content: <InlineNode>[TextRun(text: 'Nested ordered')],
          ),
          TextBlockNode(
            id: 'o2',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'ordered'),
            content: <InlineNode>[TextRun(text: 'Second ordered')],
          ),
          TextBlockNode(
            id: 'task-done',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: true),
            content: <InlineNode>[TextRun(text: 'Done task')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Finder marker(String blockId) => find.byKey(
          ValueKey<String>('wenz-richtext-list-marker-$blockId'),
        );

    expect(
      find.descendant(of: marker('u1'), matching: find.text('•')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marker('u-child'), matching: find.text('◦')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marker('o1'), matching: find.text('1.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marker('o-child'), matching: find.text('1.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marker('o2'), matching: find.text('2.')),
      findsOneWidget,
    );
    expect(marker('task-done'), findsNothing);

    final topMarkerRect = tester.getRect(marker('u1'));
    final topTextRect = tester.getRect(_richText('Top bullet'));
    final secondTextRect = tester.getRect(_richText('Second bullet'));
    final nestedTextRect = tester.getRect(_richText('Nested bullet'));
    final topLevelGap = secondTextRect.top - topTextRect.bottom;
    final nestedGap = nestedTextRect.top - secondTextRect.bottom;

    expect(topMarkerRect.width, 18);
    expect(
      topTextRect.left - topMarkerRect.left,
      moreOrLessEquals(26, epsilon: 0.1),
    );
    expect(
      nestedTextRect.left - secondTextRect.left,
      moreOrLessEquals(26, epsilon: 0.1),
    );
    expect(topLevelGap, lessThan(6));
    expect(nestedGap, lessThan(topLevelGap));

    final doneSpan = _richTextSpan(tester, 'Done task');
    expect(doneSpan.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(doneSpan.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('ordered list markers grow past two digits without wrapping',
      (tester) async {
    final blocks = List<BlockNode>.generate(
      105,
      (index) => TextBlockNode(
        id: 'ordered-${index + 1}',
        type: BlockType.listItem,
        attributes: const BlockAttributes(listType: 'ordered'),
        content: <InlineNode>[TextRun(text: 'Item ${index + 1}')],
      ),
    );
    final controller = WenzRichTextController(
      document: RichTextDocument(blocks: blocks),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 5000,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final marker = find.byKey(
      const ValueKey<String>('wenz-richtext-list-marker-ordered-100'),
    );
    await tester.scrollUntilVisible(
      marker,
      400,
      scrollable: find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 20,
    );
    await tester.pump();
    expect(marker, findsOneWidget);
    expect(
      find.descendant(of: marker, matching: find.text('100.')),
      findsOneWidget,
    );
    expect(tester.getSize(marker).width, greaterThan(18));
    final markerText = tester.widget<Text>(
      find.descendant(of: marker, matching: find.byType(Text)),
    );
    expect(markerText.maxLines, 1);
    expect(markerText.softWrap, isFalse);
  });

  testWidgets('paragraph converted to quote remains immediately selectable',
      (tester) async {
    const convertedText = 'converted quote text';
    const directQuoteText = 'direct quote text';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-convert',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'converted ',
                attributes: TextAttributes(bold: true),
              ),
              TextRun(text: 'quote text'),
            ],
          ),
          TextBlockNode(
            id: 'q-direct',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: directQuoteText)],
          ),
        ],
      ),
      selection: collapsedTextSelection('p-convert', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> expectConvertedTextSelectable() async {
      await _tapTextOffset(tester, convertedText, 0);
      await tester.pump();
      _expectBlockTextSelection(
        controller.selection,
        blockId: 'p-convert',
        blockIndex: 0,
        baseOffset: 0,
        extentOffset: 0,
      );

      await _sendShiftArrowRight(tester);
      _expectBlockTextSelection(
        controller.selection,
        blockId: 'p-convert',
        blockIndex: 0,
        baseOffset: 0,
        extentOffset: 1,
      );
      expect(
        controller.clipboardService.parse(controller.copySelection()!).text,
        'c',
      );

      await _waitPastMultiClickWindow(tester);
      final dragStart = _globalTextOffset(tester, convertedText, 0);
      final dragEnd = _globalTextOffset(tester, convertedText, 9);
      await tester.dragFrom(dragStart, dragEnd - dragStart);
      await tester.pump();
      _expectBlockTextSelection(
        controller.selection,
        blockId: 'p-convert',
        blockIndex: 0,
        baseOffset: 0,
        extentOffset: 9,
      );
      expect(
        controller.clipboardService.parse(controller.copySelection()!).text,
        'converted',
      );
    }

    controller.setBlockType(type: BlockType.quote);
    await tester.pump();
    expect((controller.document.blocks.first as TextBlockNode).type,
        BlockType.quote);
    expect(controller.lastChangedBlockIds, contains('p-convert'));
    await expectConvertedTextSelectable();

    expect(controller.undo(), isTrue);
    await tester.pump();
    expect((controller.document.blocks.first as TextBlockNode).type,
        BlockType.paragraph);
    await expectConvertedTextSelectable();

    expect(controller.redo(), isTrue);
    await tester.pump();
    expect((controller.document.blocks.first as TextBlockNode).type,
        BlockType.quote);
    await expectConvertedTextSelectable();
  });

  test('code block line-number policy is display-only', () {
    const code = 'alpha\n\nbeta\n';
    const block = CodeBlockNode(
      id: 'code1',
      code: code,
      language: 'dart',
    );
    const document = RichTextDocument(blocks: <BlockNode>[block]);

    expect(WenzCodeBlockLineNumbers.firstNumber, 1);
    expect(WenzCodeBlockLineNumbers.displayOnly, isTrue);
    expect(WenzCodeBlockLineNumbers.storedInDocumentModel, isFalse);
    expect(WenzCodeBlockLineNumbers.storedInCodecs, isFalse);
    expect(WenzCodeBlockLineNumbers.copiedWithCode, isFalse);
    expect(WenzCodeBlockLineNumbers.recordedInUndoRedoCommands, isFalse);
    expect(WenzCodeBlockLineNumbers.participatesInTextOffsetMapping, isFalse);
    expect(WenzCodeBlockLineNumbers.gutterScrollsHorizontallyWithCode, isFalse);

    expect(WenzCodeBlockLineNumbers.gutterTextAlign, TextAlign.right);
    expect(WenzCodeBlockLineNumbers.fontFamily, 'JetBrains Mono');
    expect(WenzCodeBlockLineNumbers.fontSize, 13.5);
    expect(WenzCodeBlockLineNumbers.lineHeight, 1.6);
    expect(WenzCodeBlockLineNumbers.color, 0x8AE6E6F0);
    expect(WenzCodeBlockLineNumbers.gapToCode, 12.0);

    expect(WenzCodeBlockLineNumbers.labelsForCode(''), equals(<String>['1']));
    expect(
        WenzCodeBlockLineNumbers.labelsForCode('one'), equals(<String>['1']));
    expect(
      WenzCodeBlockLineNumbers.labelsForCode(code),
      equals(<String>['1', '2', '3', '4']),
    );
    expect(
      WenzCodeBlockLineNumbers.labelsForCode('\n\n'),
      equals(<String>['1', '2', '3']),
    );
    expect(WenzCodeBlockLineNumbers.maxLabelDigits(''), 1);
    expect(
      WenzCodeBlockLineNumbers.maxLabelDigits(
        List<String>.filled(100, 'line').join('\n'),
      ),
      3,
    );

    final richJson = Map<String, Object?>.from(
      jsonDecode(const RichTextJsonCodec().encode(document)) as Map,
    );
    final richBlock = Map<String, Object?>.from(
      (richJson['blocks'] as List<Object?>).single as Map,
    );
    expect(richBlock['code'], code);
    expect(richBlock.keys, isNot(contains('lineNumber')));
    expect(richBlock.keys, isNot(contains('lineNumbers')));

    final legacyDocument = const LegacyWenJsonCodec().decode(
      jsonEncode(<String, Object?>{
        'blocks': <Map<String, Object?>>[
          <String, Object?>{
            'type': 'code',
            'code': code,
            'language': 'dart',
            'lineNumbers': <int>[1, 2, 3, 4],
          },
        ],
      }),
    );
    final legacyBlock = legacyDocument.blocks.single as CodeBlockNode;
    expect(legacyBlock.code, code);
    expect(legacyBlock.toJson().keys, isNot(contains('lineNumber')));
    expect(legacyBlock.toJson().keys, isNot(contains('lineNumbers')));

    expect(const PlainTextCodec().encode(document), code);
    expect(const MarkdownCodec().encode(document),
        '```dart\nalpha\n\nbeta\n\n```');
    expect(
      const HtmlCodec().encode(document),
      '<pre><code class="language-dart">alpha\n\nbeta\n</code></pre>',
    );

    final codePath = PositionPath.blockCode('code1');
    final codeSelection = DocumentSelection(
      base: DocumentPosition(
        blockId: 'code1',
        blockIndex: 0,
        path: codePath,
        offset: 0,
      ),
      extent: DocumentPosition(
        blockId: 'code1',
        blockIndex: 0,
        path: codePath,
        offset: code.length,
      ),
    );
    final controller = WenzRichTextController(
      document: document,
      selection: collapsedCodeSelection('code1', 0, 0),
    );
    expect(
      controller.clipboardService
          .parse(
            controller.copySelection(codeSelection)!,
          )
          .text,
      code,
    );

    controller.setCodeLanguage('python', blockIndex: 0);
    expect((controller.document.blocks.single as CodeBlockNode).code, code);
    expect(controller.undo(), isTrue);
    expect((controller.document.blocks.single as CodeBlockNode).code, code);
    expect(controller.redo(), isTrue);
    expect((controller.document.blocks.single as CodeBlockNode).code, code);
  });

  testWidgets('code block toolbar copies code and changes language', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(
            id: 'code1',
            code: 'final value = 1;',
            language: 'dart',
          ),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('复制代码内容'), findsOneWidget);
    expect(find.byTooltip('切换代码语言'), findsOneWidget);
    _expectToolbarButtonSize(tester, '复制代码内容');
    expect(find.text('dart'), findsOneWidget);

    await tester.tap(find.byTooltip('复制代码内容'));
    await tester.pump();
    expect(clipboardText, 'final value = 1;');

    await tester.tap(find.byTooltip('切换代码语言'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('python'));
    await tester.pumpAndSettle();

    expect((controller.document.blocks.single as CodeBlockNode).language,
        'python');
  });

  testWidgets(
    'mermaid source mode edits through ordinary code block pipeline',
    (tester) async {
      const initialCode = 'flowchart TD\n  A --> B';
      const editedCode = 'flowchart TD\n  A --> B\nd';
      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              CodeBlockNode(
                id: 'mermaid-code',
                language: 'mermaid',
                code: initialCode,
              ),
            ],
          ),
          selection: collapsedCodeSelection(
            'mermaid-code',
            0,
            initialCode.length,
          ),
          enableMermaidDiagrams: true,
        ),
      );
      addTearDown(bootstrap.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bootstrap.buildEditor(
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')),
        findsOneWidget,
      );
      expect(_richTextIgnoringCaret(initialCode), findsOneWidget);

      await tester.tap(_richTextIgnoringCaret(initialCode));
      await tester.pump();
      expect(
        bootstrap.selection?.extent.path,
        PositionPath.blockCode('mermaid-code'),
      );

      bootstrap.controller.setSelection(
        collapsedCodeSelection('mermaid-code', 0, initialCode.length),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, character: 'd');
      await tester.pump();

      expect(
        (bootstrap.document.blocks.single as CodeBlockNode).code,
        editedCode,
      );
      expect(bootstrap.document.blocks, hasLength(1));
      expect(
        bootstrap.selection?.extent.path,
        PositionPath.blockCode('mermaid-code'),
      );
      expect(bootstrap.selection?.extent.offset, editedCode.length);
    },
  );
  testWidgets(
    'mermaid source mode ignores keyboard input when read-only',
    (tester) async {
      const initialCode = 'flowchart TD\n  A --> B';
      final bootstrap = WenzEditorBootstrap.create(
        WenzEditorConfiguration(
          permission: WenzEditorPermission.read,
          document: const RichTextDocument(
            blocks: <BlockNode>[
              CodeBlockNode(
                id: 'mermaid-readonly',
                language: 'mermaid',
                code: initialCode,
              ),
            ],
          ),
          selection: collapsedCodeSelection(
            'mermaid-readonly',
            0,
            initialCode.length,
          ),
          enableMermaidDiagrams: true,
        ),
      );
      addTearDown(bootstrap.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: bootstrap.buildEditor(
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(bootstrap.controller.canEdit, isFalse);
      expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
      expect(_richText(initialCode), findsOneWidget);

      await tester.tap(_richText(initialCode));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        (bootstrap.document.blocks.single as CodeBlockNode).code,
        initialCode,
      );
      expect(bootstrap.document.blocks, hasLength(1));
    },
  );
  testWidgets(
    'code block syntax highlights supported languages and leaves unsupported plain',
    (tester) async {
      const dartCode = 'final value = 42; // done\nString name = "Ada";';
      const jsCode = 'const answer = 42; // ok';
      const jsonCode = '{"ok": true, "n": 3}';
      const markdownCode = '# Title\n- item with `code`';
      const pythonCode = 'def add(a, b):\n    return "sum"';
      const goCode = 'package main\nfunc add(x int) int {\n    return x + 1\n}';
      const sqlCode = 'SELECT id FROM users WHERE id = 3';
      const bashCode = 'echo "hello"\n# a comment';
      const unsupportedCode = 'final value = 42;';
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(id: 'dart1', code: dartCode, language: 'dart'),
            CodeBlockNode(id: 'js1', code: jsCode, language: 'javascript'),
            CodeBlockNode(id: 'json1', code: jsonCode, language: 'json'),
            CodeBlockNode(
              id: 'md1',
              code: markdownCode,
              language: 'markdown',
            ),
            CodeBlockNode(
              id: 'py1',
              code: pythonCode,
              language: 'python',
            ),
            CodeBlockNode(id: 'go1', code: goCode, language: 'go'),
            CodeBlockNode(id: 'sql1', code: sqlCode, language: 'sql'),
            CodeBlockNode(id: 'sh1', code: bashCode, language: 'bash'),
            CodeBlockNode(
              id: 'plain1',
              code: unsupportedCode,
              language: 'unknown',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      final dartSpan = _richTextSpan(tester, dartCode);
      expect(dartSpan.toPlainText(), dartCode);
      expect(_leafSpan(dartSpan, 'final')?.style?.color, _codeKeyword);
      expect(_leafSpan(dartSpan, 'String')?.style?.color, _codeType);
      expect(_leafSpan(dartSpan, '42')?.style?.color, _codeNumber);
      expect(_leafSpan(dartSpan, '"Ada"')?.style?.color, _codeString);
      expect(
        _leafSpan(dartSpan, '// done')?.style?.color,
        _codeComment,
      );

      expect(
        _leafSpan(_richTextSpan(tester, jsCode), 'const')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, jsonCode), 'true')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, jsonCode), '3')?.style?.color,
        _codeNumber,
      );
      expect(
        _leafSpan(_richTextSpan(tester, markdownCode), '#')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, markdownCode), '`code`')?.style?.color,
        _codeString,
      );

      // Newly supported languages (via the highlight library) produce genuine
      // category coloring rather than degrading to a single base-color span.
      expect(
        _leafSpan(_richTextSpan(tester, pythonCode), 'def')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, pythonCode), '"sum"')?.style?.color,
        _codeString,
      );
      expect(
        _leafSpan(_richTextSpan(tester, goCode), 'func')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, goCode), '1')?.style?.color,
        _codeNumber,
      );
      expect(
        _leafSpan(_richTextSpan(tester, sqlCode), 'SELECT')?.style?.color,
        _codeKeyword,
      );
      expect(
        _leafSpan(_richTextSpan(tester, sqlCode), '3')?.style?.color,
        _codeNumber,
      );
      expect(
        _leafSpan(_richTextSpan(tester, bashCode), 'echo')?.style?.color,
        _codeType,
      );
      expect(
        _leafSpan(_richTextSpan(tester, bashCode), '"hello"')?.style?.color,
        _codeString,
      );
      expect(
        _leafSpan(_richTextSpan(tester, bashCode), '# a comment')?.style?.color,
        _codeComment,
      );

      final unsupportedSpan = _richTextSpan(tester, unsupportedCode);
      expect(unsupportedSpan.text, unsupportedCode);
      expect(unsupportedSpan.style?.color, _codeBlockText);
      expect(unsupportedSpan.children, isNull);
    },
  );

  testWidgets('code block uses dark design surface and horizontal scroll', (
    tester,
  ) async {
    const longCode =
        'final veryLongIdentifier = List.generate(100, (index) => index).join(",");';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: longCode, language: 'dart'),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );

    final decoration = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-code-block-code1'),
    );
    expect(decoration.color, _codeBlockBackground);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(decoration.border, isNotNull);

    final codeSpan = _richTextSpan(tester, longCode);
    expect(codeSpan.style?.color, _codeBlockText);
    expect(codeSpan.style?.fontFamily, 'JetBrains Mono');
    expect(codeSpan.style?.fontSize, 13.5);
    expect(codeSpan.style?.height, 1.6);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('wenz-richtext-code-scroll-code1')),
    );
    expect(scroll.scrollDirection, Axis.horizontal);
    expect(find.text('dart'), findsOneWidget);
    expect(find.byTooltip('切换代码语言'), findsOneWidget);
    final blockRect = tester.getRect(
      find.byKey(const ValueKey<String>('wenz-richtext-code-block-code1')),
    );
    final codeRect = tester.getRect(_richText(longCode));
    final languageRect = tester.getRect(find.text('dart'));
    final copyButtonRect = tester.getRect(find.byTooltip('复制代码内容'));
    expect(languageRect.left, greaterThanOrEqualTo(blockRect.left));
    expect(
      (copyButtonRect.center.dy - languageRect.center.dy).abs(),
      lessThan(1),
    );
    expect(codeRect.top, greaterThan(copyButtonRect.bottom));
    expect(copyButtonRect.right, lessThanOrEqualTo(blockRect.right));
  });

  testWidgets('code block header handles narrow edge cases', (tester) async {
    await tester.binding.setSurfaceSize(const Size(260, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copiedTexts.add(args['text'] as String? ?? '');
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    const multilineCode = 'line 1\nline 2';
    const longLanguage = 'very-long-language-name-that-should-ellipsis';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'empty-language', code: multilineCode),
          CodeBlockNode(
            id: 'long-language',
            code: 'print("ok");',
            language: longLanguage,
          ),
          CodeBlockNode(id: 'empty-code', code: '', language: 'dart'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
              readOnly: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Plain text'), findsOneWidget);
    expect(find.text(longLanguage), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.byTooltip('复制代码内容'), findsNWidgets(3));
    expect(find.byTooltip('切换代码语言'), findsNothing);
    expect(_codeLineNumberText(tester, 'empty-language'), '1\n2');
    expect(_codeLineNumberText(tester, 'empty-code'), '1');

    final longBlockRect = tester.getRect(
      find.byKey(
          const ValueKey<String>('wenz-richtext-code-block-long-language')),
    );
    final longLabelRect = tester.getRect(find.text(longLanguage));
    final longCopyRect = tester.getRect(
      find.byKey(
          const ValueKey<String>('wenz-richtext-code-copy-long-language')),
    );
    expect(longLabelRect.left, greaterThanOrEqualTo(longBlockRect.left));
    expect(longLabelRect.right, lessThanOrEqualTo(longCopyRect.left));
    expect(longCopyRect.right, lessThanOrEqualTo(longBlockRect.right));

    await tester.tap(
      find.byKey(
          const ValueKey<String>('wenz-richtext-code-copy-empty-language')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-code-copy-empty-code')),
    );
    await tester.pump();

    expect(copiedTexts, <String>[multilineCode, '']);
  });

  testWidgets('code block line numbers cover edge-case line counts', (
    tester,
  ) async {
    Future<void> pumpCode(String blockId, String code) async {
      final controller = WenzRichTextController(
        document: RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(id: blockId, code: code, language: 'dart'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 720,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCode('empty', '');
    expect(_codeLineNumberText(tester, 'empty'), '1');

    await pumpCode('single', 'one line');
    expect(_codeLineNumberText(tester, 'single'), '1');

    await pumpCode('blank', 'one\n\nthree');
    expect(_codeLineNumberText(tester, 'blank'), '1\n2\n3');

    await pumpCode('trailing', 'one\ntwo\n');
    expect(_codeLineNumberText(tester, 'trailing'), '1\n2\n3');

    final tenLineCode =
        List<String>.generate(10, (index) => 'line $index').join('\n');
    await pumpCode('ten', tenLineCode);
    expect(
      _codeLineNumberText(tester, 'ten'),
      List<String>.generate(10, (index) => '${index + 1}').join('\n'),
    );
    final tenWidth = tester.getSize(_codeLineNumberFinder('ten')).width;

    final hundredLineCode =
        List<String>.generate(100, (index) => 'line $index').join('\n');
    await pumpCode('hundred', hundredLineCode);
    expect(
      _codeLineNumberText(tester, 'hundred'),
      List<String>.generate(100, (index) => '${index + 1}').join('\n'),
    );
    final hundredWidth = tester.getSize(_codeLineNumberFinder('hundred')).width;
    expect(hundredWidth, greaterThan(tenWidth));

    final lineNumberText =
        tester.widget<Text>(_codeLineNumberFinder('hundred'));
    expect(lineNumberText.textAlign, TextAlign.right);
    expect(lineNumberText.style?.fontFamily, 'JetBrains Mono');
    expect(lineNumberText.style?.fontSize, 13.5);
    expect(lineNumberText.style?.height, 1.6);
    expect(lineNumberText.style?.color, const Color(0x8AE6E6F0));
  });

  testWidgets('code block line numbers stay outside editing and scrolling', (
    tester,
  ) async {
    const code = 'aa\nbb';
    const longCode =
        'final veryLongIdentifier = List.generate(200, (index) => index).join(",");';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
          CodeBlockNode(id: 'long', code: longCode, language: 'dart'),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 520,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gutterRect = tester.getRect(_codeLineNumberFinder('code1'));
    final codeRect = tester.getRect(_richText(code));
    expect(gutterRect.right, lessThan(codeRect.left));
    expect(_codeLineNumberText(tester, 'code1'), '1\n2');

    await _tapSingle(tester, gutterRect.center);
    _expectBlockCodeSelection(
      controller.selection,
      blockId: 'code1',
      blockIndex: 0,
      baseOffset: 0,
      extentOffset: 0,
    );

    await _waitPastMultiClickWindow(tester);
    final dragStart = _globalTextOffset(tester, code, 0);
    final dragEnd = _globalTextOffset(tester, code, code.length);
    await tester.dragFrom(dragStart, dragEnd - dragStart);
    await tester.pump();
    expect(
      controller.clipboardService.parse(controller.copySelection()!).text,
      code,
    );

    controller.setSelection(collapsedCodeSelection('code1', 0, code.length));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      (controller.document.blocks.first as CodeBlockNode).code,
      'aa\n  bb',
    );
    expect(_codeLineNumberText(tester, 'code1'), '1\n2');

    controller.setCodeLanguage('python', blockIndex: 0);
    await tester.pump();
    expect(
      (controller.document.blocks.first as CodeBlockNode).code,
      'aa\n  bb',
    );
    expect(_codeLineNumberText(tester, 'code1'), '1\n2');

    final longGutterLeftBefore =
        tester.getTopLeft(_codeLineNumberFinder('long')).dx;
    final longScrollFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-code-scroll-long'),
    );
    final horizontalScrollable = tester.state<ScrollableState>(
      find.descendant(of: longScrollFinder, matching: find.byType(Scrollable)),
    );
    expect(horizontalScrollable.position.maxScrollExtent, greaterThan(0));
    horizontalScrollable.position.jumpTo(
      horizontalScrollable.position.maxScrollExtent,
    );
    await tester.pump();
    expect(
      tester.getTopLeft(_codeLineNumberFinder('long')).dx,
      moreOrLessEquals(longGutterLeftBefore, epsilon: 0.1),
    );
    expect(_codeLineNumberText(tester, 'long'), '1');
  });

  testWidgets('code block selection highlight is visible on dark surface', (
    tester,
  ) async {
    const code = 'final value = 42; // done';
    final codePath = PositionPath.blockCode('code1');
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'code1',
          blockIndex: 0,
          path: codePath,
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'code1',
          blockIndex: 0,
          path: codePath,
          offset: 11,
        ),
      ),
    );
    const boundaryKey = ValueKey<String>('code-selection-highlight-sample');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );

    final selectedSpacePoint = _globalTextRangePoint(tester, code, 5, 6, 0.5);
    final selectedColor = await _sampleBoundaryColor(
      tester,
      boundaryKey,
      selectedSpacePoint,
    );
    expect(_redOf(selectedColor), greaterThan(_redOf(_codeBlockBackground)));
    expect(
      _greenOf(selectedColor),
      greaterThan(_greenOf(_codeBlockBackground) + 30),
    );
    expect(
      _blueOf(selectedColor),
      greaterThan(_blueOf(_codeBlockBackground) + 80),
    );
    expect(_blueOf(selectedColor), greaterThan(_greenOf(selectedColor)));
    expect(_blueOf(selectedColor), greaterThan(_redOf(selectedColor)));
    expect(_alphaOf(_codeBlockSelectionHighlight), greaterThanOrEqualTo(0x90));
  });

  testWidgets('code block selection remains copyable with highlight visible', (
    tester,
  ) async {
    const code = 'final value = 42; // done';
    final codePath = PositionPath.blockCode('code1');
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition(
          blockId: 'code1',
          blockIndex: 0,
          path: codePath,
          offset: 0,
        ),
        extent: DocumentPosition(
          blockId: 'code1',
          blockIndex: 0,
          path: codePath,
          offset: 11,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
    final selectedPayload = controller.copySelection();
    expect(selectedPayload, isNotNull);
    expect(controller.clipboardService.parse(selectedPayload!).text,
        'final value');
  });

  testWidgets('object block more menu stays inside compact editor viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'image1',
            assetId: 'hero',
            file: 'hero.png',
            width: 640,
            height: 320,
          ),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: const ValueKey<String>('compact-object-menu-viewport'),
            width: 320,
            height: 260,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                height: 260,
                child: WenzRichTextEditor(
                  controller: controller,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final imageRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-image-frame-image1'),
    ));
    final moreButtonRect = tester.getRect(find.byTooltip('更多块操作'));
    final toolbarRect = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );
    _expectToolbarAboveBody(toolbarRect, imageRect);
    _expectToolbarAlignedToFrameEnd(toolbarRect, imageRect);
    expect(
      moreButtonRect.right,
      moreOrLessEquals(imageRect.right, epsilon: 0.75),
    );

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();

    for (final label in const <String>[
      '图片左对齐',
      '图片居中',
      '图片右对齐',
      '清除图片对齐',
      '图片宽度：小',
      '图片宽度：中',
      '图片宽度：大',
      '重置图片尺寸',
    ]) {
      expect(_popupMenuItemFinder(label), findsOneWidget);
    }
    expect(_popupMenuItemFinder('创建块副本'), findsNothing);
    final viewportRect = tester.getRect(
      find.byKey(const ValueKey<String>('compact-object-menu-viewport')),
    );
    for (final label in const <String>[
      '图片左对齐',
      '图片居中',
      '图片右对齐',
      '清除图片对齐',
    ]) {
      final menuRect = tester.getRect(_popupMenuItemFinder(label));
      expect(menuRect.left, greaterThanOrEqualTo(viewportRect.left));
      expect(menuRect.right, lessThanOrEqualTo(viewportRect.right));
      expect(menuRect.top, greaterThanOrEqualTo(viewportRect.top));
    }

    await tester.tap(_popupMenuItemFinder('图片左对齐'));
    await tester.pumpAndSettle();

    final image = controller.document.blocks.single as ImageBlockNode;
    expect(image.attributes.alignment, 'left');
  });

  testWidgets('divider block menu copies duplicates moves and deletes', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          DividerBlockNode(id: 'divider1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: objectBlockSelection('divider1', 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('复制块引用'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);

    await _waitPastMultiClickWindow(tester);
    await tester.tap(_blockDragHandleFinder('divider1'));
    await tester.pumpAndSettle();
    expect(_popupMenuItemFinder('复制块引用'), findsOneWidget);
    expect(_popupMenuItemFinder('创建块副本'), findsOneWidget);

    await tester.tap(_popupMenuItemFinder('复制块引用'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'divider');

    await _waitPastMultiClickWindow(tester);
    await tester.tap(_blockDragHandleFinder('divider1'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('创建块副本'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks, hasLength(4));
    final duplicate = controller.document.blocks[2] as DividerBlockNode;
    expect(duplicate.id, isNot('divider1'));
    expect(controller.selection?.extent.blockId, duplicate.id);
    expect(controller.selection?.extent.blockIndex, 2);

    await _openBlockMoreMenu(tester, duplicate.id);
    await tester.tap(_popupMenuItemFinder('上移块'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks[1].id, duplicate.id);
    expect(controller.document.blocks[2].id, 'divider1');
    expect(controller.selection?.extent.blockIndex, 1);

    await _openBlockMoreMenu(tester, duplicate.id);
    await tester.tap(_popupMenuItemFinder('删除块'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks, hasLength(3));
    expect(controller.document.blocks[1].id, 'divider1');
    expect(
      controller.document.blocks.map((block) => block.id),
      isNot(contains(duplicate.id)),
    );
  });

  testWidgets('image block drag handle menu omits only duplicate action', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Paragraph')],
          ),
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          DividerBlockNode(id: 'divider1'),
          FileBlockNode(id: 'file1', assetId: 'file-1', name: 'brief.pdf'),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          BlockEmbedNode(
            id: 'embed1',
            embedType: 'bookmark',
            data: <String, Object?>{'title': 'Bookmark'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> expectDuplicateEntry(String blockId, Matcher matcher) async {
      await tester.tap(_blockDragHandleFinder(blockId));
      await tester.pumpAndSettle();
      expect(_popupMenuItemFinder('复制块引用'), findsOneWidget);
      expect(_popupMenuItemFinder('创建块副本'), matcher);
      Navigator.of(tester.element(find.byType(WenzRichTextEditor))).pop();
      await tester.pumpAndSettle();
    }

    await expectDuplicateEntry('image1', findsNothing);
    for (final blockId in <String>[
      'p0',
      'divider1',
      'file1',
      'video1',
      'embed1',
    ]) {
      await expectDuplicateEntry(blockId, findsOneWidget);
    }
  });

  testWidgets('image duplicate action dispatch is ignored defensively', (
    tester,
  ) async {
    late ObjectBlockActionHandler dispatchObjectAction;
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );
    var selectionChanges = 0;
    controller.onSelectionChanged = (_) {
      selectionChanges++;
    };
    final registry = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(registry);
    registry.register(BlockType.image, (context, rc) {
      dispatchObjectAction = rc.onObjectBlockAction!;
      return SizedBox(
        key: ValueKey<String>('custom-image-action-${rc.block.id}'),
        height: 80,
        child: const Text('custom image'),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            blockRenderers: registry,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.canUndo, isFalse);

    dispatchObjectAction(
      const ObjectBlockActionIntent(
        action: ObjectBlockAction.duplicate,
        blockIndex: 0,
      ),
    );
    await tester.pump();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['image1', 'p1'],
    );
    expect(controller.selection, objectBlockSelection('image1', 0));
    expect(selectionChanges, 0);
    expect(controller.canUndo, isFalse);
  });

  testWidgets(
    'media object toolbars hide copy reference and ignore old action paths',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      Future<void> pumpSelectedMedia(String blockId, int blockIndex) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: WenzRichTextController(
                  document: const RichTextDocument(
                    blocks: <BlockNode>[
                      ImageBlockNode(
                        id: 'image1',
                        assetId: 'hero',
                        file: 'hero.png',
                        width: 640,
                        height: 320,
                        showWidth: 180,
                        showHeight: 90,
                      ),
                      VideoBlockNode(id: 'video1', assetId: 'clip'),
                    ],
                  ),
                  selection: objectBlockSelection(blockId, blockIndex),
                ),
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpSelectedMedia('image1', 0);
      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(find.byTooltip('更多块操作'), findsOneWidget);
      expect(find.byTooltip('复制块引用'), findsNothing);
      _expectToolbarButtonSize(tester, '预览媒体');
      _expectToolbarButtonSize(tester, '更多块操作');
      final imageFrameRect = tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-image-frame-image1'),
      ));
      final imageToolbarRect = _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      );
      _expectToolbarAboveBody(imageToolbarRect, imageFrameRect);
      _expectToolbarAlignedToFrameEnd(imageToolbarRect, imageFrameRect);

      await tester.tap(_blockDragHandleFinder('image1'));
      await tester.pumpAndSettle();
      await tester.tap(_popupMenuItemFinder('复制块引用'));
      await tester.pumpAndSettle();
      expect(clipboardText, isNull);

      await pumpSelectedMedia('video1', 1);
      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(find.byTooltip('更多块操作'), findsOneWidget);
      expect(find.byTooltip('复制块引用'), findsNothing);
      final videoFrameRect = tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-video-frame-video1'),
      ));
      final videoToolbarRect = _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      );
      _expectToolbarAboveBody(videoToolbarRect, videoFrameRect);
      _expectToolbarAlignedToFrameEnd(videoToolbarRect, videoFrameRect);

      await tester.tap(_blockDragHandleFinder('video1'));
      await tester.pumpAndSettle();
      await tester.tap(_popupMenuItemFinder('复制块引用'));
      await tester.pumpAndSettle();
      expect(clipboardText, isNull);
    },
  );

  testWidgets('read-only object toolbar keeps mutation actions hidden',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: WenzRichTextController(
              document: const RichTextDocument(
                blocks: <BlockNode>[
                  ImageBlockNode(
                    id: 'image1',
                    assetId: 'hero',
                    file: 'hero.png',
                  ),
                ],
              ),
              selection: objectBlockSelection('image1', 0),
            ),
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('复制块引用'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);
    expect(find.byTooltip('创建块副本'), findsNothing);
    expect(find.byTooltip('删除块'), findsNothing);
  });

  testWidgets('object block controls disable boundary move actions', (
    tester,
  ) async {
    Future<void> pumpEditor(WenzRichTextController controller) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpEditor(
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          ],
        ),
        selection: objectBlockSelection('image1', 0),
      ),
    );

    expect(find.byTooltip('上移块'), findsNothing);
    expect(find.byTooltip('下移块'), findsNothing);

    await pumpEditor(
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            FileBlockNode(id: 'file1', assetId: 'file-1', name: 'brief.pdf'),
          ],
        ),
        selection: objectBlockSelection('file1', 0),
      ),
    );
    await _openFileActionMenu(tester);

    PopupMenuItem menuItem(String label) => _popupMenuItem(tester, label);

    expect(menuItem('上移块').enabled, isFalse);
    expect(menuItem('下移块').enabled, isFalse);
  });

  testWidgets('block drag handles open row action menu without selection', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          CodeBlockNode(id: 'code1', code: 'final value = 1;'),
          DividerBlockNode(id: 'divider1'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_blockDragHandleFinder('p0'), findsOneWidget);
    expect(_blockDragHandleFinder('code1'), findsOneWidget);
    expect(_blockDragHandleFinder('divider1'), findsOneWidget);
    expect(controller.selection, isNull);

    final handle = _blockDragHandleFinder('p0');
    AnimatedOpacity handleOpacity() => tester.widget<AnimatedOpacity>(
          find.descendant(of: handle, matching: find.byType(AnimatedOpacity)),
        );
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);

    controller.setSelection(collapsedTextSelection('p0', 0, 0));
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);
    controller.setSelection(null);
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
        location: tester.getCenter(_richText('First block')));
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.hoverOpacity);
    await mouse.moveTo(tester.getCenter(handle));
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.hoverOpacity);
    await mouse.removePointer();
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);

    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(controller.selection, isNull);
    _expectPopupMenuChrome(tester, '复制块内容');
    for (final label in <String>[
      '复制块内容',
      '复制块引用',
      '创建块副本',
      '更多块操作',
      '删除块',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('上移块'), findsNothing);
    expect(find.text('下移块'), findsNothing);

    await tester.tap(_popupMenuItemFinder('复制块内容'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'First block');

    await tester.tap(_blockDragHandleFinder('p0'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('更多块操作'));
    await tester.pumpAndSettle();

    PopupMenuItem menuItem(String label) => _popupMenuItem(tester, label);

    expect(menuItem('上移块').enabled, isFalse);
    expect(menuItem('下移块').enabled, isTrue);
    _expectPopupMenuItemSelected(
      tester,
      '下移块',
      selected: false,
    );

    await tester.tap(_popupMenuItemFinder('下移块'));
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['code1', 'p0', 'divider1'],
    );
    expect(controller.selection?.extent.blockId, 'p0');
    expect(controller.selection?.extent.blockIndex, 1);
  });

  group('mobile current block action', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ]) {
      testWidgets(
        'shows and moves the compact ${platform.name} action with the caret',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() {
            debugDefaultTargetPlatformOverride = null;
          });
          await tester.binding.setSurfaceSize(const Size(320, 560));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final focusNode = FocusNode();
          addTearDown(focusNode.dispose);
          final controller = WenzRichTextController(
            document: const RichTextDocument(
              blocks: <BlockNode>[
                TextBlockNode(
                  id: 'first',
                  type: BlockType.paragraph,
                  content: <InlineNode>[TextRun(text: 'First block')],
                ),
                TextBlockNode(
                  id: 'second',
                  type: BlockType.paragraph,
                  content: <InlineNode>[TextRun(text: 'Second block')],
                ),
              ],
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WenzRichTextEditor(
                  controller: controller,
                  focusNode: focusNode,
                  enableIme: false,
                ),
              ),
            ),
          );
          await tester.pump();

          final firstHandle = _blockDragHandleFinder('first');
          final secondHandle = _blockDragHandleFinder('second');
          AnimatedOpacity actionOpacity(Finder handle) =>
              tester.widget<AnimatedOpacity>(
                find.descendant(
                  of: handle,
                  matching: find.byType(AnimatedOpacity),
                ),
              );

          expect(
            actionOpacity(firstHandle).opacity,
            BlockDragHandleSpec.idleOpacity,
          );
          expect(
            actionOpacity(secondHandle).opacity,
            BlockDragHandleSpec.idleOpacity,
          );

          controller.setSelection(collapsedTextSelection('first', 0, 0));
          focusNode.requestFocus();
          await tester.pump();

          expect(focusNode.hasFocus, isTrue);
          expect(
            actionOpacity(firstHandle).opacity,
            BlockDragHandleSpec.activeOpacity,
          );
          expect(
            actionOpacity(secondHandle).opacity,
            BlockDragHandleSpec.idleOpacity,
          );

          controller.setSelection(collapsedTextSelection('second', 1, 0));
          await tester.pump();

          expect(
            actionOpacity(firstHandle).opacity,
            BlockDragHandleSpec.idleOpacity,
          );
          expect(
            actionOpacity(secondHandle).opacity,
            BlockDragHandleSpec.activeOpacity,
          );

          await tester.tap(secondHandle);
          await tester.pumpAndSettle();
          expect(find.text('复制块内容'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'keeps the compact desktop action hover-gated with a focused caret',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        await tester.binding.setSurfaceSize(const Size(320, 560));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'desktop',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Desktop block')],
              ),
            ],
          ),
          selection: collapsedTextSelection('desktop', 0, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                focusNode: focusNode,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final handle = _blockDragHandleFinder('desktop');
        AnimatedOpacity actionOpacity() => tester.widget<AnimatedOpacity>(
              find.descendant(
                of: handle,
                matching: find.byType(AnimatedOpacity),
              ),
            );

        focusNode.requestFocus();
        await tester.pump();
        expect(actionOpacity().opacity, BlockDragHandleSpec.idleOpacity);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
            location: tester.getCenter(_richText('Desktop block')));
        await tester.pump();
        expect(actionOpacity().opacity, BlockDragHandleSpec.hoverOpacity);
        await mouse.removePointer();
      },
    );

    testWidgets(
      'does not force the compact action without a focused editable caret',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        await tester.binding.setSurfaceSize(const Size(320, 560));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'first',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'First block')],
              ),
              TextBlockNode(
                id: 'second',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Second block')],
              ),
            ],
          ),
          selection: collapsedTextSelection('first', 0, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                focusNode: focusNode,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final firstHandle = _blockDragHandleFinder('first');
        final secondHandle = _blockDragHandleFinder('second');
        AnimatedOpacity actionOpacity(Finder handle) =>
            tester.widget<AnimatedOpacity>(
              find.descendant(
                of: handle,
                matching: find.byType(AnimatedOpacity),
              ),
            );

        expect(
          actionOpacity(firstHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );

        focusNode.requestFocus();
        await tester.pump();
        expect(
          actionOpacity(firstHandle).opacity,
          BlockDragHandleSpec.activeOpacity,
        );

        controller.setSelection(
          DocumentSelection(
            base: DocumentPosition.text(
              blockId: 'first',
              blockIndex: 0,
              offset: 0,
            ),
            extent: DocumentPosition.text(
              blockId: 'second',
              blockIndex: 1,
              offset: 1,
            ),
          ),
        );
        await tester.pump();

        expect(
          actionOpacity(firstHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );
        expect(
          actionOpacity(secondHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );

        controller.setSelection(null);
        await tester.pump();
        expect(
          actionOpacity(firstHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );
        expect(
          actionOpacity(secondHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );

        final readOnlyController = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'read-only',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Read only')],
              ),
            ],
          ),
          selection: collapsedTextSelection('read-only', 0, 0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: readOnlyController,
                readOnly: true,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(_blockDragHandleFinder('read-only'), findsNothing);

        final noEditFocusNode = FocusNode();
        addTearDown(noEditFocusNode.dispose);
        final noEditController = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'no-edit',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'No edit')],
              ),
            ],
          ),
          permission: WenzEditorPermission.read,
          selection: collapsedTextSelection('no-edit', 0, 0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: noEditController,
                focusNode: noEditFocusNode,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
        noEditFocusNode.requestFocus();
        await tester.pump();

        expect(_blockDragHandleFinder('no-edit'), findsNothing);
      },
    );

    testWidgets(
      'keeps the visible compact current-block action touch-reorderable',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
        });
        await tester.binding.setSurfaceSize(const Size(320, 560));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'first',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'First block')],
              ),
              TextBlockNode(
                id: 'second',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Second block')],
              ),
            ],
          ),
          selection: collapsedTextSelection('second', 1, 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                focusNode: focusNode,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final firstHandle = _blockDragHandleFinder('first');
        final secondHandle = _blockDragHandleFinder('second');
        AnimatedOpacity actionOpacity(Finder handle) =>
            tester.widget<AnimatedOpacity>(
              find.descendant(
                of: handle,
                matching: find.byType(AnimatedOpacity),
              ),
            );

        focusNode.requestFocus();
        await tester.pump();
        expect(
          actionOpacity(secondHandle).opacity,
          BlockDragHandleSpec.activeOpacity,
        );

        final indicator = _blockReorderDropIndicatorFinder();
        final drag = await tester.startGesture(
          tester.getCenter(secondHandle),
          kind: PointerDeviceKind.touch,
        );
        await drag.moveTo(
          tester.getTopLeft(_richText('First block')) - const Offset(0, 10),
        );
        await tester.pump();

        expect(indicator, findsOneWidget);

        await drag.up();
        await tester.pumpAndSettle();

        expect(
          controller.document.blocks.map((block) => block.id),
          <String>['second', 'first'],
        );
        expect(controller.selection?.extent.blockId, 'second');
        expect(controller.selection?.extent.blockIndex, 0);
        expect(
          actionOpacity(secondHandle).opacity,
          BlockDragHandleSpec.activeOpacity,
        );
        expect(
          actionOpacity(firstHandle).opacity,
          BlockDragHandleSpec.idleOpacity,
        );
      },
    );
  });

  testWidgets('block drag handle popup applies dark chrome and item states', (
    tester,
  ) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_blockDragHandleFinder('p0'));
    await tester.pumpAndSettle();

    _expectPopupMenuChrome(tester, '复制块内容');
    _expectPopupMenuItemTextColor(
      tester,
      '删除块',
      theme.colorScheme.error,
    );

    await tester.tap(_popupMenuItemFinder('更多块操作'));
    await tester.pumpAndSettle();

    expect(_popupMenuItem(tester, '上移块').enabled, isFalse);
    expect(_popupMenuItem(tester, '下移块').enabled, isTrue);
    _expectPopupMenuItemTextColor(
      tester,
      '上移块',
      theme.colorScheme.onSurfaceVariant.withAlpha(110),
    );
    _expectPopupMenuItemSelected(
      tester,
      '下移块',
      selected: false,
    );
    _expectPopupMenuItemSelected(tester, '普通文本');
  });

  testWidgets('popup menu dividers use weak chrome token in light and dark', (
    tester,
  ) async {
    final themes = <ThemeData>[
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
    ];

    Future<void> pumpEditor(
      ThemeData theme,
      WenzRichTextController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 420,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final theme in themes) {
      await pumpEditor(
        theme,
        WenzRichTextController(
          document: _toolbarTableDocument(),
          selection: _tableCellSelection(),
        ),
      );
      await _pumpTableToolbarOverlay(tester);
      await tester.tap(find.byTooltip('更多表格操作'));
      await tester.pumpAndSettle();
      _expectWeakPopupMenuDividers(tester, '删除列', count: 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await pumpEditor(
        theme,
        WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p0',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Before')],
              ),
              DividerBlockNode(id: 'divider1'),
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'After')],
              ),
            ],
          ),
          selection: objectBlockSelection('divider1', 1),
        ),
      );
      await tester.tap(find.byTooltip('更多块操作'));
      await tester.pumpAndSettle();
      _expectWeakPopupMenuDividers(tester, '上移块', count: 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await pumpEditor(
        theme,
        WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              FileBlockNode(id: 'file1', assetId: 'file-1', name: 'brief.pdf'),
            ],
          ),
          selection: objectBlockSelection('file1', 0),
        ),
      );
      await _openFileActionMenu(tester);
      _expectWeakPopupMenuDividers(tester, '标记为已上传', count: 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('block drag handle menu switches row formats', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'print(1)')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _openBlockMoreMenu(tester, 'p0');
    expect(_popupMenuItem(tester, '普通文本').enabled, isFalse);
    expect(_popupMenuItem(tester, '标题').enabled, isTrue);
    expect(_popupMenuItem(tester, '代码块').enabled, isTrue);
    _expectPopupMenuItemSelected(tester, '普通文本');

    await tester.tap(find.text('标题'));
    await tester.pumpAndSettle();
    var block = controller.document.blocks.first as TextBlockNode;
    expect(block.type, BlockType.heading);
    expect(block.attributes.level, 1);
    expect(block.plainText, 'print(1)');
    expect(controller.selection?.extent.blockId, 'p0');
    expect(controller.selection?.extent.blockIndex, 0);

    await _openBlockMoreMenu(tester, 'p0');
    expect(_popupMenuItem(tester, '标题').enabled, isFalse);
    await tester.tap(find.text('代码块'));
    await tester.pumpAndSettle();
    final codeBlock = controller.document.blocks.first as CodeBlockNode;
    expect(codeBlock.code, 'print(1)');
    expect(controller.selection?.extent.path.isBlockCode, isTrue);

    await _openBlockMoreMenu(tester, 'p0');
    expect(_popupMenuItem(tester, '代码块').enabled, isFalse);
    await tester.tap(find.text('普通文本'));
    await tester.pumpAndSettle();
    block = controller.document.blocks.first as TextBlockNode;
    expect(block.type, BlockType.paragraph);
    expect(block.plainText, 'print(1)');
    expect(controller.undo(), isTrue);
    await tester.pump();
    expect(controller.document.blocks.first, isA<CodeBlockNode>());
  });

  testWidgets('block drag handle menu routes object block actions', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          DividerBlockNode(id: 'divider1'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_blockDragHandleFinder('divider1'));
    await tester.pumpAndSettle();
    expect(find.text('更多块操作'), findsOneWidget);
    expect(find.text('上移块'), findsNothing);
    expect(find.text('下移块'), findsNothing);

    await tester.tap(_popupMenuItemFinder('复制块引用'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'divider');

    await tester.tap(_blockDragHandleFinder('divider1'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('更多块操作'));
    await tester.pumpAndSettle();

    PopupMenuItem menuItem(String label) => _popupMenuItem(tester, label);

    expect(menuItem('上移块').enabled, isTrue);
    expect(menuItem('下移块').enabled, isTrue);

    await tester.tap(_popupMenuItemFinder('下移块'));
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p0', 'p1', 'divider1'],
    );
    expect(controller.selection?.extent.blockId, 'divider1');
    expect(controller.selection?.extent.blockIndex, 2);

    await tester.tap(_blockDragHandleFinder('divider1'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('更多块操作'));
    await tester.pumpAndSettle();
    expect(menuItem('上移块').enabled, isTrue);
    expect(menuItem('下移块').enabled, isFalse);
  });

  testWidgets('block drag handles suppress menu after drag threshold', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final handle = _blockDragHandleFinder('p0');
    AnimatedOpacity handleOpacity() => tester.widget<AnimatedOpacity>(
          find.descendant(of: handle, matching: find.byType(AnimatedOpacity)),
        );
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(
      const Offset(0, BlockDragHandleSpec.dragStartSlop + 2),
    );
    await tester.pump();

    expect(handleOpacity().opacity, BlockDragHandleSpec.activeOpacity);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsNothing);
    expect(controller.selection, isNull);
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(find.text('复制块内容'), findsOneWidget);
  });

  testWidgets('block drag handles show drop indicator and reorder blocks', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Third block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final indicator = find.byKey(
      const ValueKey<String>('wenz-richtext-block-reorder-drop-indicator'),
    );
    final dragDown = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('p0')),
      kind: PointerDeviceKind.touch,
    );
    await dragDown.moveTo(
      tester.getBottomLeft(_richText('Third block')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);

    await dragDown.up();
    await tester.pumpAndSettle();

    expect(indicator, findsNothing);
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p1', 'p2', 'p0'],
    );
    expect(controller.selection?.extent.blockId, 'p0');
    expect(controller.selection?.extent.blockIndex, 2);
    expect(controller.undo(), isTrue);
    await tester.pump();
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p0', 'p1', 'p2'],
    );

    expect(controller.redo(), isTrue);
    await tester.pump();
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p1', 'p2', 'p0'],
    );
    expect(controller.selection?.extent.blockId, 'p0');
    expect(controller.selection?.extent.blockIndex, 2);

    expect(controller.undo(), isTrue);
    await tester.pump();
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p0', 'p1', 'p2'],
    );

    final dragUp = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('p2')),
      kind: PointerDeviceKind.touch,
    );
    await dragUp.moveTo(
      tester.getTopLeft(_richText('First block')) - const Offset(0, 10),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);

    await dragUp.up();
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p2', 'p0', 'p1'],
    );
    expect(controller.selection?.extent.blockId, 'p2');
    expect(controller.selection?.extent.blockIndex, 0);
  });

  testWidgets('block drag handles move expanded heading ranges together', (
    tester,
  ) async {
    final controller = _headingRangeDragController();
    await _pumpOutlinedBlockDragEditor(tester, controller);

    final indicator = _blockReorderDropIndicatorFinder();
    final drag = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('parent')),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveTo(
      tester.getBottomLeft(_richText('Sibling body')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);

    await drag.up();
    await tester.pumpAndSettle();

    expect(indicator, findsNothing);
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>[
        'sibling',
        'sibling-body',
        'parent',
        'parent-body',
        'child-heading',
        'child-body',
        'after',
        'after-body',
      ],
    );
    expect(controller.selection?.extent.blockId, 'parent');
    expect(controller.selection?.extent.blockIndex, 2);

    final dragBack = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('parent')),
      kind: PointerDeviceKind.touch,
    );
    await dragBack.moveTo(
      tester.getTopLeft(_richText('Sibling title')) + const Offset(12, 1),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);

    await dragBack.up();
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>[
        'parent',
        'parent-body',
        'child-heading',
        'child-body',
        'sibling',
        'sibling-body',
        'after',
        'after-body',
      ],
    );
    expect(controller.selection?.extent.blockId, 'parent');
    expect(controller.selection?.extent.blockIndex, 0);
  });

  testWidgets('block drag handles drop after heading at target range tail', (
    tester,
  ) async {
    final controller = _headingRangeDragController();
    await _pumpOutlinedBlockDragEditor(tester, controller);

    final drag = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('parent')),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveTo(
      tester.getBottomLeft(_richText('Sibling title')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(_blockReorderDropIndicatorFinder(), findsOneWidget);

    await drag.up();
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>[
        'sibling',
        'sibling-body',
        'parent',
        'parent-body',
        'child-heading',
        'child-body',
        'after',
        'after-body',
      ],
    );
    expect(controller.selection?.extent.blockId, 'parent');
    expect(controller.selection?.extent.blockIndex, 2);
  });

  testWidgets('block drag handles ignore heading range internal targets', (
    tester,
  ) async {
    final controller = _headingRangeDragController();
    await _pumpOutlinedBlockDragEditor(tester, controller);
    final beforeOrder =
        controller.document.blocks.map((block) => block.id).toList();

    final drag = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('parent')),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveTo(
      tester.getBottomLeft(_richText('Parent body')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(_blockReorderDropIndicatorFinder(), findsNothing);

    await drag.up();
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      beforeOrder,
    );
    expect(controller.canUndo, isFalse);
  });

  testWidgets('block drag handles move collapsed heading hidden content', (
    tester,
  ) async {
    final controller = _headingRangeDragController();
    final outline = WenzOutlineController(editor: controller);
    addTearDown(outline.dispose);
    expect(outline.collapseByBlockId('parent'), isTrue);
    await _pumpOutlinedBlockDragEditor(
      tester,
      controller,
      outlineController: outline,
    );

    expect(_richText('Parent title'), findsOneWidget);
    expect(_richText('Parent body'), findsNothing);
    expect(_richText('Child title'), findsNothing);
    expect(_richText('Sibling body'), findsOneWidget);

    final indicator = _blockReorderDropIndicatorFinder();
    final drag = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('parent')),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveTo(
      tester.getBottomLeft(_richText('Sibling body')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);

    await drag.up();
    await tester.pumpAndSettle();

    expect(indicator, findsNothing);
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>[
        'sibling',
        'sibling-body',
        'parent',
        'parent-body',
        'child-heading',
        'child-body',
        'after',
        'after-body',
      ],
    );
    expect(outline.isCollapsed('parent'), isTrue);
    expect(_richText('Parent body'), findsNothing);
    expect(_richText('Child title'), findsNothing);

    final collapseButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-parent'),
    );
    expect(collapseButton, findsOneWidget);
    expect(
      tester.widget<IconButton>(collapseButton).tooltip,
      '展开标题内容（3 个块已隐藏）',
    );
    expect(
      tester.getTopLeft(_richText('Sibling body')).dy,
      lessThan(tester.getTopLeft(_richText('Parent title')).dy),
    );
    expect(
      tester.getTopLeft(_richText('Parent title')).dy,
      lessThan(tester.getTopLeft(_richText('After title')).dy),
    );

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    expect(outline.isCollapsed('parent'), isFalse);
    expect(_richText('Parent body'), findsOneWidget);
    expect(_richText('Child title'), findsOneWidget);
    expect(_richText('Child body'), findsOneWidget);
    expect(
      tester.getTopLeft(_richText('Parent title')).dy,
      lessThan(tester.getTopLeft(_richText('Parent body')).dy),
    );
    expect(
      tester.getTopLeft(_richText('Child body')).dy,
      lessThan(tester.getTopLeft(_richText('After title')).dy),
    );
  });

  testWidgets('block drag handle menu moves heading range but not normal block',
      (
    tester,
  ) async {
    final headingController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before block')],
          ),
          TextBlockNode(
            id: 'heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Heading block')],
          ),
          TextBlockNode(
            id: 'heading-body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Heading body')],
          ),
          TextBlockNode(
            id: 'next-heading',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 1),
            content: <InlineNode>[TextRun(text: 'Next heading')],
          ),
        ],
      ),
    );
    await _pumpOutlinedBlockDragEditor(tester, headingController);

    await _openBlockMoreMenu(tester, 'heading');
    await tester.tap(_popupMenuItemFinder('下移块'));
    await tester.pumpAndSettle();

    expect(
      headingController.document.blocks.map((block) => block.id),
      <String>['before', 'next-heading', 'heading', 'heading-body'],
    );
    expect(headingController.selection?.extent.blockId, 'heading');
    expect(headingController.selection?.extent.blockIndex, 2);

    await _openBlockMoreMenu(tester, 'heading');
    await tester.tap(_popupMenuItemFinder('上移块'));
    await tester.pumpAndSettle();

    expect(
      headingController.document.blocks.map((block) => block.id),
      <String>['before', 'heading', 'heading-body', 'next-heading'],
    );
    expect(headingController.selection?.extent.blockId, 'heading');
    expect(headingController.selection?.extent.blockIndex, 1);

    final normalController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First normal')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second normal')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Third normal')],
          ),
        ],
      ),
    );
    await _pumpOutlinedBlockDragEditor(tester, normalController);

    await _openBlockMoreMenu(tester, 'p0');
    await tester.tap(_popupMenuItemFinder('下移块'));
    await tester.pumpAndSettle();

    expect(
      normalController.document.blocks.map((block) => block.id),
      <String>['p1', 'p0', 'p2'],
    );
    expect(normalController.selection?.extent.blockId, 'p0');
    expect(normalController.selection?.extent.blockIndex, 1);
  });

  testWidgets('block drag handles do not record same-position drops', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final drag = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('p0')),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveTo(
      tester.getBottomLeft(_richText('First block')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-block-reorder-drop-indicator'),
      ),
      findsOneWidget,
    );

    await drag.up();
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsNothing);
    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['p0', 'p1'],
    );
    expect(controller.canUndo, isFalse);
  });

  testWidgets('block drag handles reset drag state after pointer cancel', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final handle = _blockDragHandleFinder('p0');
    AnimatedOpacity handleOpacity() => tester.widget<AnimatedOpacity>(
          find.descendant(of: handle, matching: find.byType(AnimatedOpacity)),
        );
    final start = tester.getCenter(handle);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(
      const Offset(BlockDragHandleSpec.dragStartSlop + 2, 0),
    );
    await tester.pump();

    expect(handleOpacity().opacity, BlockDragHandleSpec.activeOpacity);

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsNothing);
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(find.text('复制块内容'), findsOneWidget);
  });

  testWidgets('block drag handles keep long-document auto-scroll isolated', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: List<BlockNode>.generate(
          30,
          (index) => TextBlockNode(
            id: 'p$index',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'long-block-$index')],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 150,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
    final indicator = find.byKey(
      const ValueKey<String>('wenz-richtext-block-reorder-drop-indicator'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('p0')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(
      Offset(
        editorBox.left +
            (BlockDragHandleSpec.hitSize.width +
                    BlockDragHandleSpec.gapToContent) ~/
                2,
        editorBox.bottom - 8,
      ),
    );
    await tester.pump();

    expect(indicator, findsOneWidget);
    final scrollBefore = _scrollOffset(tester);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      _scrollOffset(tester),
      moreOrLessEquals(scrollBefore, epsilon: 0.01),
    );
    expect(controller.selection, isNull);

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(indicator, findsNothing);
    expect(find.text('复制块内容'), findsNothing);
  });

  testWidgets('block drag handles open row action menu from keyboard focus', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'First block')],
          ),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Second block')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final handle = _blockDragHandleFinder('p0');
    final focusChild =
        find.descendant(of: handle, matching: find.byType(Semantics)).first;
    Focus.of(tester.element(focusChild)).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsOneWidget);
    expect(controller.selection, isNull);
  });

  testWidgets('block drag handles wrap custom renderers and hide read-only', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'custom-p',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Custom paragraph')],
          ),
        ],
      ),
    );
    final registry = BlockRendererRegistry()
      ..register(BlockType.paragraph, (context, rc) {
        return Text(
          'custom:${rc.block.plainText}',
          key: ValueKey<String>('custom-renderer-${rc.block.id}'),
        );
      });

    Future<void> pump({required bool readOnly}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              blockRenderers: registry,
              readOnly: readOnly,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(readOnly: false);
    expect(
      find.byKey(const ValueKey<String>('custom-renderer-custom-p')),
      findsOneWidget,
    );
    expect(_blockDragHandleFinder('custom-p'), findsOneWidget);

    await pump(readOnly: true);
    expect(
      find.byKey(const ValueKey<String>('custom-renderer-custom-p')),
      findsOneWidget,
    );
    expect(_blockDragHandleFinder('custom-p'), findsNothing);
  });

  testWidgets('image object toolbar updates and resets display size', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(
            id: 'image1',
            assetId: 'hero',
            file: 'hero.png',
            width: 640,
            height: 320,
          ),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_imageBlockFinder('image1'), findsOneWidget);
    expect(find.text('Image'), findsNothing);
    expect(find.text('hero.png'), findsNothing);
    expect(find.byTooltip('设置图片宽度'), findsNothing);
    expect(find.byTooltip('重置图片尺寸'), findsNothing);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
    expect(find.byTooltip('复制块引用'), findsNothing);
    final imageRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-image-frame-image1'),
    ));
    final moreButtonRect = tester.getRect(find.byTooltip('更多块操作'));
    expect(
      moreButtonRect.top,
      lessThanOrEqualTo(imageRect.top + 40),
    );
    expect(moreButtonRect.right, lessThanOrEqualTo(imageRect.right));
    _expectToolbarAboveBody(
      _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      ),
      imageRect,
    );

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('图片宽度：中'));
    await tester.pumpAndSettle();

    var image = controller.document.blocks.single as ImageBlockNode;
    expect(image.showWidth, 360);
    expect(image.showHeight, 180);

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('重置图片尺寸'));
    await tester.pumpAndSettle();

    image = controller.document.blocks.single as ImageBlockNode;
    expect(image.showWidth, isNull);
    expect(image.showHeight, isNull);
  });

  testWidgets('file block stays compact and updates status from action menu',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          FileBlockNode(
            id: 'file1',
            assetId: 'file-1',
            name: 'brief.pdf',
            size: 4096,
            mimeType: 'application/pdf',
            file: 'storage/brief.pdf',
            downloadUrl: 'https://cdn.example.com/brief.pdf',
            uploadStatus: FileUploadStatus.uploading,
          ),
        ],
      ),
      selection: objectBlockSelection('file1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-file-card-file1')),
      findsOneWidget,
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(find.byTooltip('附件操作'), findsOneWidget);
    _expectToolbarButtonSize(tester, '附件操作');
    final fileToolbarRect = tester.getRect(find.byTooltip('附件操作'));
    final fileCardRect = tester.getRect(
      find.byKey(const ValueKey<String>('wenz-richtext-file-card-file1')),
    );
    _expectToolbarAboveBody(
      fileToolbarRect,
      tester.getRect(find.text('brief.pdf')),
    );
    _expectToolbarAlignedToFrameEnd(fileToolbarRect, fileCardRect);
    expect(find.text('4 KB'), findsOneWidget);
    expect(find.text('application/pdf'), findsOneWidget);
    expect(find.text('Uploading'), findsOneWidget);
    expect(find.text('storage/brief.pdf'), findsNothing);
    expect(find.text('https://cdn.example.com/brief.pdf'), findsNothing);
    expect(find.byTooltip('设置文件状态'), findsNothing);
    await _openFileActionMenu(tester);
    expect(
      tester.getSize(_popupMenuItemFinder('复制块引用')).width,
      greaterThanOrEqualTo(176),
    );
    expect(
      tester.getSize(_popupMenuItemFinder('标记为已上传')).width,
      greaterThanOrEqualTo(176),
    );
    final deleteLabel = tester.widget<Text>(find.text('删除块'));
    expect(
      deleteLabel.style?.color,
      Theme.of(tester.element(find.text('删除块'))).colorScheme.error,
    );
    await tester.tap(_popupMenuItemFinder('标记为已上传'));
    await tester.pumpAndSettle();

    var file = controller.document.blocks.single as FileBlockNode;
    expect(file.uploadStatus, FileUploadStatus.uploaded);
    expect(file.uploadError, isEmpty);

    await tester.tap(find.byTooltip('附件操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('标记为失败'));
    await tester.pumpAndSettle();

    file = controller.document.blocks.single as FileBlockNode;
    expect(file.uploadStatus, FileUploadStatus.failed);
    expect(file.uploadError, 'Upload failed');
  });

  testWidgets('embed object toolbar stays above body content', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'embed1',
            embedType: 'chart',
            fallbackText: 'Revenue chart',
            data: <String, Object?>{'source': 'Q4 report'},
          ),
        ],
      ),
      selection: objectBlockSelection('embed1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.all(8),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('复制块引用'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
    _expectToolbarButtonSize(tester, '复制块引用');
    _expectToolbarButtonSize(tester, '更多块操作');
    final toolbarRect = _toolbarButtonsRect(
      tester,
      const <String>['复制块引用', '更多块操作'],
    );
    _expectToolbarAboveBody(
      toolbarRect,
      tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-embed-fallback-embed1'),
      )),
    );
    _expectToolbarAlignedToFrameEnd(
      toolbarRect,
      tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-embed-card-embed1'),
      )),
    );
  });

  testWidgets('feedback 3 primary operation tooltips stay localized',
      (tester) async {
    Future<void> pumpEditor(WenzRichTextController controller) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 360,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpEditor(
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            CodeBlockNode(
              id: 'code1',
              code: 'final value = 1;',
              language: 'dart',
            ),
          ],
        ),
        selection: collapsedCodeSelection('code1', 0, 0),
      ),
    );
    _expectLocalizedTooltip('复制代码内容');
    _expectLocalizedTooltip('切换代码语言');
    expect(find.text('dart'), findsOneWidget);
    await tester.tap(find.byTooltip('切换代码语言'));
    await tester.pumpAndSettle();
    expect(find.text('python'), findsOneWidget);
    await tester.tap(_popupMenuItemFinder('python'));
    await tester.pumpAndSettle();
    expect(
      (tester
              .widget<WenzRichTextEditor>(find.byType(WenzRichTextEditor))
              .controller
              .document
              .blocks
              .single as CodeBlockNode)
          .language,
      'python',
    );

    await pumpEditor(
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          ],
        ),
        selection: objectBlockSelection('image1', 0),
      ),
    );
    for (final tooltip in <String>[
      '预览媒体',
      '更多块操作',
    ]) {
      _expectLocalizedTooltip(tooltip);
    }
    expect(find.byTooltip('创建块副本'), findsNothing);
    expect(find.byTooltip('删除块'), findsNothing);
    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    for (final label in <String>[
      '上移块',
      '下移块',
      '图片左对齐',
      '图片居中',
      '图片右对齐',
      '清除图片对齐',
      '图片宽度：小',
      '图片宽度：中',
      '图片宽度：大',
      '重置图片尺寸',
      '删除块',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('创建块副本'), findsNothing);

    await pumpEditor(
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            FileBlockNode(id: 'file1', assetId: 'file-1', name: 'brief.pdf'),
          ],
        ),
        selection: objectBlockSelection('file1', 0),
      ),
    );
    _expectLocalizedTooltip('附件操作');
    await tester.tap(find.byTooltip('附件操作'));
    await tester.pumpAndSettle();
    expect(find.text('复制块引用'), findsOneWidget);
    for (final label in <String>[
      '创建块副本',
      '上移块',
      '下移块',
      '标记为上传中',
      '标记为已上传',
      '标记为失败',
      '删除块',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await pumpEditor(
      WenzRichTextController(
        document: _toolbarTableDocument(),
        selection: _tableCellSelection(),
      ),
    );
    for (final tooltip in <String>[
      '在下方插入行',
      '在右侧插入列',
      '合并所选单元格',
      '更多表格操作',
    ]) {
      _expectLocalizedTooltip(tooltip);
    }
    await tester.tap(find.byTooltip('更多表格操作'));
    await tester.pumpAndSettle();
    for (final label in <String>[
      '在上方插入行',
      '在下方插入行',
      '删除行',
      '在左侧插入列',
      '在右侧插入列',
      '删除列',
      '切换表头单元格',
      '设置单元格背景',
      '清除单元格背景',
      '单元格左对齐',
      '单元格居中对齐',
      '单元格右对齐',
      '清除单元格对齐',
      '合并所选单元格',
      '拆分单元格',
      '重置列宽',
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('callout renders metadata and changes variant', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'co1',
            variant: 'warning',
            title: 'Watch',
            icon: '🚨',
            content: <InlineNode>[TextRun(text: 'Pay attention')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(find.text('🚨'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(_richText('Pay attention'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);

    await tester.tap(find.text('Warning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danger').last);
    await tester.pumpAndSettle();

    final callout = controller.document.blocks.single as CalloutBlockNode;
    expect(callout.variant, 'danger');
    expect(callout.title, 'Watch');
    expect(callout.icon, '🚨');
    expect(find.text('Danger'), findsOneWidget);
  });

  testWidgets('callout body accepts keyboard input after tap', (tester) async {
    const body = 'Edit me';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(
            id: 'callout1',
            variant: CalloutBlockNode.warningVariant,
            title: 'Heads up',
            icon: '!',
            attributes: BlockAttributes(anchor: 'note-anchor'),
            content: <InlineNode>[TextRun(text: body)],
          ),
        ],
      ),
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await _tapTextOffset(tester, body, body.length);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'callout1',
      blockIndex: 0,
      baseOffset: body.length,
      extentOffset: body.length,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyX, character: 'x');
    await tester.pump();

    final callout = controller.document.blocks.single as CalloutBlockNode;
    expect(
      callout.content.map((node) => node.plainText).join(),
      'Edit mex',
    );
    expect(callout.variant, CalloutBlockNode.warningVariant);
    expect(callout.title, 'Heads up');
    expect(callout.icon, '!');
    expect(callout.attributes, const BlockAttributes(anchor: 'note-anchor'));
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'callout1',
      blockIndex: 0,
      baseOffset: body.length + 1,
      extentOffset: body.length + 1,
    );
    expect(_richTextIgnoringCaret('Edit mex'), findsOneWidget);
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
  });

  testWidgets('callout body participates in selection and copy', (
    tester,
  ) async {
    const body = 'Info body selectable';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before callout')],
          ),
          CalloutBlockNode(
            id: 'info1',
            title: 'Info Title',
            content: <InlineNode>[TextRun(text: body)],
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after callout')],
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_richText(body), findsOneWidget);
    await _tapTextOffset(tester, body, 5);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'info1',
      blockIndex: 1,
      baseOffset: 5,
      extentOffset: 5,
    );

    await _sendShiftArrowRight(tester);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'info1',
      blockIndex: 1,
      baseOffset: 5,
      extentOffset: 6,
    );

    await _waitPastMultiClickWindow(tester);
    final bodyStart = _globalTextOffset(tester, body, 5);
    final bodyEnd = _globalTextOffset(tester, body, 9);
    await tester.dragFrom(bodyStart, bodyEnd - bodyStart);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'info1',
      blockIndex: 1,
      baseOffset: 5,
      extentOffset: 9,
    );
    expect(
      controller.clipboardService.parse(controller.copySelection()!).text,
      'body',
    );

    await _waitPastMultiClickWindow(tester);
    final beforeStart = _globalTextOffset(tester, 'before callout', 7);
    final calloutEnd = _globalTextOffset(tester, body, 4);
    await tester.dragFrom(beforeStart, calloutEnd - beforeStart);
    await tester.pump();
    expect(controller.selection?.base.blockId, 'before');
    expect(controller.selection?.base.path, PositionPath.blockText('before'));
    expect(controller.selection?.base.offset, 7);
    expect(controller.selection?.extent.blockId, 'info1');
    expect(controller.selection?.extent.path, PositionPath.blockText('info1'));
    expect(controller.selection?.extent.offset, 4);
    expect(
      controller.clipboardService.parse(controller.copySelection()!).text,
      'callout\nInfo',
    );

    await _waitPastMultiClickWindow(tester);
    final calloutStart = _globalTextOffset(tester, body, 10);
    final afterEnd = _globalTextOffset(tester, 'after callout', 5);
    await tester.dragFrom(calloutStart, afterEnd - calloutStart);
    await tester.pump();
    expect(controller.selection?.base.blockId, 'info1');
    expect(controller.selection?.base.path, PositionPath.blockText('info1'));
    expect(controller.selection?.base.offset, 10);
    expect(controller.selection?.extent.blockId, 'after');
    expect(controller.selection?.extent.path, PositionPath.blockText('after'));
    expect(controller.selection?.extent.offset, 5);
    expect(
      controller.clipboardService.parse(controller.copySelection()!).text,
      'selectable\nafter',
    );
  });

  testWidgets('callout variants use design colors and safe fallbacks', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CalloutBlockNode(id: 'info', content: <InlineNode>[]),
          CalloutBlockNode(
            id: 'success',
            variant: CalloutBlockNode.successVariant,
            content: <InlineNode>[TextRun(text: 'Success body')],
          ),
          CalloutBlockNode(
            id: 'warning',
            variant: CalloutBlockNode.warningVariant,
            content: <InlineNode>[TextRun(text: 'Warning body')],
          ),
          CalloutBlockNode(
            id: 'danger',
            variant: CalloutBlockNode.dangerVariant,
            content: <InlineNode>[TextRun(text: 'Danger body')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    void expectCalloutColors(
      String id,
      Color background,
      Color border,
    ) {
      final decoration = _firstDescendantBoxDecorationByKey(
        tester,
        ValueKey<String>('wenz-richtext-callout-$id'),
      );
      expect(decoration.color, background);
      expect((decoration.border as Border).top.color, border);
    }

    expectCalloutColors('info', _calloutInfoBackground, _calloutInfoBorder);
    expectCalloutColors(
      'success',
      _calloutSuccessBackground,
      _calloutSuccessBorder,
    );
    expectCalloutColors(
      'warning',
      _calloutWarningBackground,
      _calloutWarningBorder,
    );
    expectCalloutColors(
      'danger',
      _calloutDangerBackground,
      _calloutDangerBorder,
    );

    expect(find.text('Info'), findsWidgets);
    final infoIcon = tester.widget<Text>(find.text('ℹ️'));
    expect(infoIcon.style?.color, _calloutInfoForeground);
    expect(_richText('Success body'), findsOneWidget);
    expect(_richTextSpan(tester, 'Success body').style?.color,
        _calloutSuccessForeground);
    expect(_richTextSpan(tester, 'Warning body').style?.color,
        _calloutWarningForeground);
    expect(_richTextSpan(tester, 'Danger body').style?.color,
        _calloutDangerForeground);
  });

  testWidgets('divider selected state uses single shell border', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[DividerBlockNode(id: 'divider')],
      ),
      selection: objectBlockSelection('divider', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(WenzRichTextEditor)));
    final shell = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-divider-shell-divider'),
    );
    final shellBorder = shell.border as Border;
    expect(shell.color, isNull);
    expect(shellBorder.top.color, theme.colorScheme.primary);
    expect(shellBorder.top.width, 1.5);
    expect(find.byKey(_selectionHighlightKey), findsNothing);

    final line = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-divider-line-divider'),
    );
    expect(line.color, _dividerLine);
    final dot = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-divider-dot-divider'),
    );
    expect(dot.color, theme.colorScheme.primary);
    expect(dot.shape, BoxShape.circle);
    expect(find.byTooltip('复制块引用'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);
  });

  testWidgets('built-in block renderers derive readable dark theme colors', (
    tester,
  ) async {
    const primary = Color(0xFF9DB7FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(primary: primary);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-p',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(
                text: 'Link',
                attributes: TextAttributes(url: 'https://example.com'),
              ),
              TextRun(text: ' '),
              TextRun(
                text: 'remark',
                attributes: TextAttributes(remark: true),
              ),
            ],
          ),
          CodeBlockNode(id: 'code-dark', code: 'final dark = true;'),
          TableBlockNode(
            id: 'table-dark',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'head',
                    isHeader: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'head-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Head')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'body',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'body-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Body')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          DividerBlockNode(id: 'divider-dark'),
          CalloutBlockNode(
            id: 'callout-dark',
            variant: CalloutBlockNode.dangerVariant,
            content: <InlineNode>[TextRun(text: 'Danger dark')],
          ),
          FileBlockNode(id: 'file-dark', assetId: 'file', name: 'dark.pdf'),
          BlockEmbedNode(
            id: 'embed-dark',
            embedType: 'crm-card',
            fallbackText: 'Dark embed',
          ),
          BlockEmbedNode(
            id: 'formula-dark',
            embedType: 'formula',
            data: <String, Object?>{'text': 'x^2'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 900,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final inlineSpan = _richTextSpan(tester, 'Link remark');
    expect(_leafSpan(inlineSpan, 'Link')?.style?.color, scheme.primary);
    expect(
      _leafSpan(inlineSpan, 'remark')?.style?.decorationColor,
      scheme.secondary,
    );

    final codeDecoration = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-code-block-code-dark'),
    );
    expect(codeDecoration.color, scheme.surfaceContainerHighest);
    expect(
      _richTextSpan(tester, 'final dark = true;').style?.color,
      scheme.onSurface,
    );

    final tableBorder = _paintedTableCellBorder(tester, 'table-dark', 0, 0);
    expect(tableBorder.top.color, scheme.outlineVariant);
    final stripedBackground = _tableCellBackgroundBox(
      tester,
      'table-dark',
      1,
      0,
    );
    expect(
      (stripedBackground.decoration as BoxDecoration).color,
      scheme.surfaceContainerHighest.withAlpha(70),
    );

    final dividerLine = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-divider-line-divider-dark'),
    );
    expect(dividerLine.color, scheme.outlineVariant);

    final calloutDecoration = _firstDescendantBoxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-callout-callout-dark'),
    );
    expect(calloutDecoration.color, scheme.errorContainer.withAlpha(104));
    expect((calloutDecoration.border as Border).top.color, scheme.error);
    expect(
      _richTextSpan(tester, 'Danger dark').style?.color,
      scheme.onErrorContainer,
    );

    final fileCard = tester.widget<AnimatedContainer>(find.byKey(
      const ValueKey<String>('wenz-richtext-file-card-file-dark'),
    ));
    final fileDecoration = fileCard.decoration as BoxDecoration;
    expect((fileDecoration.border as Border).top.color, scheme.outlineVariant);

    final embedDecoration = _firstDescendantBoxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-embed-card-embed-dark'),
    );
    expect(embedDecoration.color, scheme.surfaceContainerHighest.withAlpha(72));

    _expectFormulaBlockHasNoDefaultBackground(
      tester,
      'formula-dark',
      scheme,
    );
    expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
  });

  testWidgets('built-in block renderers keep readable light theme colors', (
    tester,
  ) async {
    const primary = Color(0xFF3152D4);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code-light', code: 'final light = true;'),
          TableBlockNode(
            id: 'table-light',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'head',
                    isHeader: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'head-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Head')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'body',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'body-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Body')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          DividerBlockNode(id: 'divider-light'),
          CalloutBlockNode(
            id: 'callout-light',
            variant: CalloutBlockNode.successVariant,
            content: <InlineNode>[TextRun(text: 'Success light')],
          ),
          BlockEmbedNode(
            id: 'formula-light',
            embedType: 'formula',
            data: <String, Object?>{'text': 'a+b'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 720,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final codeDecoration = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-code-block-code-light'),
    );
    expect(codeDecoration.color, scheme.surfaceContainerHighest);
    expect(
      _richTextSpan(tester, 'final light = true;').style?.color,
      scheme.onSurface,
    );

    final tableBorder = _paintedTableCellBorder(tester, 'table-light', 0, 0);
    expect(tableBorder.top.color, scheme.outlineVariant);
    final stripedBackground = _tableCellBackgroundBox(
      tester,
      'table-light',
      1,
      0,
    );
    expect(
      (stripedBackground.decoration as BoxDecoration).color,
      scheme.surfaceContainerHighest.withAlpha(70),
    );

    final dividerLine = _boxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-divider-line-divider-light'),
    );
    expect(dividerLine.color, _dividerLine);

    final calloutDecoration = _firstDescendantBoxDecorationByKey(
      tester,
      const ValueKey<String>('wenz-richtext-callout-callout-light'),
    );
    expect(calloutDecoration.color, _calloutSuccessBackground);
    expect(
        (calloutDecoration.border as Border).top.color, _calloutSuccessBorder);
    expect(
      _richTextSpan(tester, 'Success light').style?.color,
      _calloutSuccessForeground,
    );

    _expectFormulaBlockHasNoDefaultBackground(
      tester,
      'formula-light',
      scheme,
    );
    expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
  });

  testWidgets('exposes block semantics labels and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'h2',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Plan')],
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Alpha')],
            ),
            CodeBlockNode(id: 'code1', code: 'print(1);', language: 'dart'),
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          ],
        ),
        selection: textSelection('p1', 1, 0, 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Heading block level 2'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Paragraph block, selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Code block'), findsOneWidget);
      expect(find.bySemanticsLabel('Image block hero.png'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('exposes editor-level accessibility semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Alpha')],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
              accessibility: const WenzRichTextEditorAccessibility(
                label: 'Project notes editor',
                hint: 'Compose project notes.',
              ),
            ),
          ),
        ),
      );

      final editorSemantics = tester.getSemantics(
        find.bySemanticsLabel('Project notes editor'),
      );

      expect(editorSemantics.hint, 'Compose project notes.');
      final flags = editorSemantics.flagsCollection;
      expect(flags.isTextField, isTrue);
      expect(flags.isFocused, isNot(Tristate.none));
      expect(flags.isMultiline, isTrue);
      expect(flags.isEnabled, isNot(Tristate.none));
      expect(flags.isEnabled, Tristate.isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('shows high contrast focus outline when focused', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Alpha')],
          ),
        ],
      ),
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            highContrast: true,
          ),
          child: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              focusNode: focusNode,
              enableIme: false,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-accessibility-focus-highlight'),
      ),
      findsNothing,
    );

    focusNode.requestFocus();
    await tester.pump();

    final highlightFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-accessibility-focus-highlight'),
    );
    expect(highlightFinder, findsOneWidget);

    final highlight = tester.widget<DecoratedBox>(highlightFinder);
    final decoration = highlight.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.width, 3);
  });

  testWidgets('exposes table and merged cell semantics labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'header',
                      isHeader: true,
                      rowSpan: 2,
                      columnSpan: 2,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'header-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Merged')],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'covered-right', covered: true),
                    TableCellNode(
                      id: 'top-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'top-right-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Q1')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(id: 'covered-bottom-left', covered: true),
                    TableCellNode(id: 'covered-bottom-right', covered: true),
                    TableCellNode(
                      id: 'bottom-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'bottom-right-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Done')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'table1',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'table1',
            blockIndex: 0,
            tableRowIndex: 1,
            tableColumnIndex: 2,
            offset: 0,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Table block, 2 rows, 3 columns'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Table cell row 1 column 1, header, spans 2 rows, '
          'spans 2 columns, selected',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Table cell row 1 column 3, selected'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Table cell row 2 column 3, selected'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Table cell row 1 column 2'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('table floating toolbar edits rows columns and cells', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('在下方插入行'), findsOneWidget);

    Future<void> pressTableMoreItem(String label) async {
      await tester.tap(find.byTooltip('更多表格操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await _pumpTableToolbarOverlay(tester);
    }

    await pressIconButtonByTooltip(tester, '在下方插入行');
    var table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 3);

    await pressIconButtonByTooltip(tester, '在右侧插入列');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 3);

    await pressTableMoreItem('切换表头单元格');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.isHeader, isTrue);

    await pressTableMoreItem('设置单元格背景');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.backgroundColor, 0xFFFFF3CD);

    await pressTableMoreItem('单元格居中对齐');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.alignment, 'center');
    // Alignment is cell-level now: it must not leak into the column map.
    expect(table.table.columnAlignments.containsKey(0), isFalse);

    await pressTableMoreItem('清除单元格背景');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.backgroundColor, isNull);

    await pressTableMoreItem('清除单元格对齐');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.alignment, isNull);
    expect(table.table.columnAlignments.containsKey(0), isFalse);

    controller.setTableColumnWidth(blockIndex: 0, columnIndex: 0, width: 180);
    await tester.pump();
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths[0], 180);

    await pressTableMoreItem('重置列宽');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths.containsKey(0), isFalse);

    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 1,
          offset: 0,
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    await pressIconButtonByTooltip(tester, '合并所选单元格');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.columnSpan, 2);
    expect(table.table.cellAt(0, 1)!.covered, isTrue);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 0,
      extentOffset: 0,
    );

    await pressIconButtonByTooltip(tester, '拆分单元格');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.columnSpan, 1);
    expect(table.table.cellAt(0, 1)!.covered, isFalse);

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 2,
        tableColumnIndex: 2,
        offset: 0,
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    await pressTableMoreItem('删除行');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 2);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 2,
      baseOffset: 0,
      extentOffset: 0,
    );

    await pressTableMoreItem('删除列');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 2);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 1,
      baseOffset: 0,
      extentOffset: 0,
    );

    expect(controller.canUndo, isTrue);
    expect(controller.undo(), isTrue);
    await tester.pump();
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 3);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 2,
      baseOffset: 0,
      extentOffset: 0,
    );

    expect(controller.redo(), isTrue);
    await tester.pump();
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnCount, 2);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 1,
      tableColumnIndex: 1,
      baseOffset: 0,
      extentOffset: 0,
    );
  });

  testWidgets('table floating toolbar group menus update selection and table', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableWithParagraphDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    for (final tooltip in const <String>[
      '行操作',
      '列操作',
      '单元格样式',
      '整表操作',
      '更多表格操作',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }

    await _openTableToolbarMenu(tester, '行操作');
    expect(find.text('在上方插入行'), findsOneWidget);
    expect(find.text('在下方插入行'), findsOneWidget);
    expect(find.text('删除行'), findsOneWidget);
    await _tapTableToolbarMenuItem(tester, '选择整行');
    _expectTableCellRangeSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      startRow: 0,
      endRow: 0,
      startColumn: 0,
      endColumn: 1,
    );

    await _openTableToolbarMenu(tester, '列操作');
    expect(find.text('在左侧插入列'), findsOneWidget);
    expect(find.text('在右侧插入列'), findsOneWidget);
    expect(find.text('删除列'), findsOneWidget);
    await _tapTableToolbarMenuItem(tester, '选择整列');
    _expectTableCellRangeSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      startRow: 0,
      endRow: 1,
      startColumn: 0,
      endColumn: 0,
    );

    await _openTableToolbarMenu(tester, '单元格样式');
    expect(find.text('切换表头单元格'), findsOneWidget);
    expect(find.text('设置单元格背景'), findsOneWidget);
    expect(find.text('合并所选单元格'), findsOneWidget);
    await _dismissPopupMenu(tester);

    await _openTableToolbarMenu(tester, '整表操作');
    expect(find.text('选择整表'), findsOneWidget);
    expect(find.text('删除整表'), findsOneWidget);
    await _tapTableToolbarMenuItem(tester, '选择整表');
    _expectTableCellRangeSelection(
      controller.selection,
      tableBlockId: 'table1',
      blockIndex: 0,
      startRow: 0,
      endRow: 1,
      startColumn: 0,
      endColumn: 1,
    );

    await _openTableToolbarMenu(tester, '整表操作');
    await _tapTableToolbarMenuItem(tester, '删除整表');
    expect(controller.document.blocks, hasLength(1));
    expect(controller.document.blocks.single.id, 'after-table');
  });

  testWidgets('table floating toolbar disables unsafe and blocked edits', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _singleCellToolbarTableDocument(),
      selection: _singleCellTableSelection(),
    );
    final initialJson = _documentJson(controller);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 300,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    expect(
      tester.widget<IconButton>(find.byTooltip('合并所选单元格')).onPressed,
      isNull,
    );

    await _openTableToolbarMenu(tester, '行操作');
    expect(_popupMenuItem(tester, '删除行').enabled, isFalse);
    await _dismissPopupMenu(tester);

    await _openTableToolbarMenu(tester, '列操作');
    expect(_popupMenuItem(tester, '删除列').enabled, isFalse);
    await _dismissPopupMenu(tester);

    await _openTableToolbarMenu(tester, '单元格样式');
    expect(_popupMenuItem(tester, '合并所选单元格').enabled, isFalse);
    expect(_popupMenuItem(tester, '拆分单元格').enabled, isFalse);
    await _dismissPopupMenu(tester);

    expect(_documentJson(controller), initialJson);

    Future<void> expectEditingBlocked({
      required bool readOnly,
      required WenzEditorPermission permission,
    }) async {
      final lockedController = WenzRichTextController(
        document: _singleCellToolbarTableDocument(),
        selection: _singleCellTableSelection(),
        permission: permission,
      );
      final lockedJson = _documentJson(lockedController);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 300,
              child: WenzRichTextEditor(
                controller: lockedController,
                readOnly: readOnly,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await _pumpTableToolbarOverlay(tester);

      expect(
        find.byKey(const ValueKey<String>('table-floating-toolbar')),
        findsNothing,
      );
      expect(find.byTooltip('更多表格操作'), findsNothing);
      expect(_documentJson(lockedController), lockedJson);
    }

    await expectEditingBlocked(
      readOnly: true,
      permission: WenzEditorPermission.edit,
    );
    await expectEditingBlocked(
      readOnly: false,
      permission: WenzEditorPermission.read,
    );
  });

  testWidgets('table floating toolbar renders Lucide icons for actions', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    _expectLucideToolbarIconForTooltip(
      tester,
      '在下方插入行',
      WenzLucideToolbarIcons.tableRowInsertBelow,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '在右侧插入列',
      WenzLucideToolbarIcons.tableColumnInsertAfter,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '合并所选单元格',
      WenzLucideToolbarIcons.tableMerge,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '行操作',
      WenzLucideToolbarIcons.tableSelectRow,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '列操作',
      WenzLucideToolbarIcons.tableSelectColumn,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '单元格样式',
      WenzLucideToolbarIcons.tableCellStyle,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '整表操作',
      WenzLucideToolbarIcons.table,
    );
    _expectLucideToolbarIconForTooltip(
      tester,
      '更多表格操作',
      WenzLucideToolbarIcons.tableMore,
    );

    await _openTableToolbarMenu(tester, '更多表格操作');
    _expectPopupMenuLucideIcon(
      tester,
      '在上方插入行',
      WenzLucideToolbarIcons.tableRowInsertAbove,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '删除行',
      WenzLucideToolbarIcons.tableRowDelete,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '在左侧插入列',
      WenzLucideToolbarIcons.tableColumnInsertBefore,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '删除列',
      WenzLucideToolbarIcons.tableColumnDelete,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '重置列宽',
      WenzLucideToolbarIcons.tableColumnWidthReset,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '切换表头单元格',
      WenzLucideToolbarIcons.tableHeaderToggle,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '设置单元格背景',
      WenzLucideToolbarIcons.tableBackgroundFill,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '清除单元格背景',
      WenzLucideToolbarIcons.tableBackgroundClear,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '单元格左对齐',
      WenzLucideToolbarIcons.tableCellAlignLeft,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '单元格居中对齐',
      WenzLucideToolbarIcons.tableCellAlignCenter,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '单元格右对齐',
      WenzLucideToolbarIcons.tableCellAlignRight,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '清除单元格对齐',
      WenzLucideToolbarIcons.tableCellAlignClear,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '合并所选单元格',
      WenzLucideToolbarIcons.tableMerge,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '拆分单元格',
      WenzLucideToolbarIcons.tableSplit,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '选择整行',
      WenzLucideToolbarIcons.tableSelectRow,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '选择整列',
      WenzLucideToolbarIcons.tableSelectColumn,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '选择整表',
      WenzLucideToolbarIcons.tableSelect,
    );
    _expectPopupMenuLucideIcon(
      tester,
      '删除整表',
      WenzLucideToolbarIcons.tableDelete,
    );
  });

  testWidgets('table floating toolbar wraps in a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(260, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 8,
                top: 120,
                right: 8,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);
    final toolbarRect = tester.getRect(toolbarFinder);
    final selectedCellRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-cell-border-table1-0-0')),
    );
    final selectedTextRect = tester.getRect(_richText('A1'));

    expect(toolbarRect.left, greaterThanOrEqualTo(-0.1));
    expect(toolbarRect.right, lessThanOrEqualTo(260.1));
    expect(toolbarRect.height, greaterThan(36));
    expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
    expect(toolbarRect.overlaps(selectedTextRect), isFalse);
    _expectMinimalToolbarSurface(tester, toolbarFinder);
    expect(tester.takeException(), isNull);
  });

  testWidgets('table renders cell alignment with column fallback', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              columnAlignments: <int, String>{1: 'right'},
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c0',
                    alignment: 'center',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellCenter')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'c1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellColumn')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'c2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c2p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellDefault')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextAlign alignOf(String text) =>
        tester.widget<RichText>(_richText(text)).textAlign;

    // Cell-level alignment wins over the column alignment.
    expect(alignOf('CellCenter'), TextAlign.center);
    // No cell alignment falls back to the column alignment.
    expect(alignOf('CellColumn'), TextAlign.right);
    // Neither cell nor column alignment resolves to the default (start).
    expect(alignOf('CellDefault'), TextAlign.start);
  });

  testWidgets('table renders left and justify cell alignment', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c0',
                    alignment: 'left',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CellLeft')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'c1',
                    alignment: 'justify',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[
                          TextRun(text: 'CellJustify'),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextAlign alignOf(String text) =>
        tester.widget<RichText>(_richText(text)).textAlign;

    // 'left' alignment maps to TextAlign.start (LTR default left alignment).
    expect(alignOf('CellLeft'), TextAlign.start);
    // 'justify' alignment maps to TextAlign.justify.
    expect(alignOf('CellJustify'), TextAlign.justify);
  });

  testWidgets(
      'table renders 2x2 grid with all four cell alignments and headers', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                // Header row.
                <TableCellNode>[
                  TableCellNode(
                    id: 'h0',
                    isHeader: true,
                    alignment: 'center',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'h0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'HdrCenter')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'h1',
                    isHeader: true,
                    alignment: 'right',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'h1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'HdrRight')],
                      ),
                    ],
                  ),
                ],
                // Data row.
                <TableCellNode>[
                  TableCellNode(
                    id: 'd0',
                    alignment: 'left',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'd0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'DataLeft')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'd1',
                    alignment: 'justify',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'd1p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[
                          TextRun(text: 'DataJustify'),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextAlign alignOf(String text) =>
        tester.widget<RichText>(_richText(text)).textAlign;

    // Header cells: alignment works same as regular cells.
    expect(alignOf('HdrCenter'), TextAlign.center);
    expect(alignOf('HdrRight'), TextAlign.right);
    // Data cells: covers left and justify in the same table.
    expect(alignOf('DataLeft'), TextAlign.start);
    expect(alignOf('DataJustify'), TextAlign.justify);
  });

  testWidgets('table default alignment resolves to TextAlign.start', (
    tester,
  ) async {
    // A table with no cell-level alignment and no column-level alignment
    // should render all cells with TextAlign.start.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'c0',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'c0p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'DefaultCell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 240,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textAlign =
        tester.widget<RichText>(_richText('DefaultCell')).textAlign;
    expect(textAlign, TextAlign.start);
  });

  testWidgets('table toolbar alignment targets selected cells not columns', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> pressTableMoreItem(String label) async {
      await tester.tap(find.byTooltip('更多表格操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await _pumpTableToolbarOverlay(tester);
    }

    TextAlign alignOf(String text) =>
        tester.widget<RichText>(_richText(text)).textAlign;

    // Single-cell selection aligns only that cell.
    await pressTableMoreItem('单元格居中对齐');
    var table = controller.document.blocks.single as TableBlockNode;
    expect(table.attributes.alignment, isNull);
    expect(table.table.cellAt(0, 0)!.alignment, 'center');
    expect(table.table.cellAt(0, 1)!.alignment, isNull);
    expect(table.table.cellAt(1, 0)!.alignment, isNull);
    expect(table.table.columnAlignments, isEmpty);
    expect(alignOf('A1'), TextAlign.center);
    expect(alignOf('B1'), TextAlign.start);

    // Multi-cell rectangular selection aligns every visible cell in range.
    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 1,
          tableColumnIndex: 1,
          offset: 0,
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);
    await pressTableMoreItem('单元格右对齐');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.alignment, 'right');
    expect(table.table.cellAt(0, 1)!.alignment, 'right');
    expect(table.table.cellAt(1, 0)!.alignment, 'right');
    expect(table.table.cellAt(1, 1)!.alignment, 'right');
    // Column alignment is never mutated by cell alignment actions.
    expect(table.attributes.alignment, isNull);
    expect(table.table.columnAlignments, isEmpty);
    expect(alignOf('A1'), TextAlign.right);
    expect(alignOf('B1'), TextAlign.right);
    expect(alignOf('A2'), TextAlign.right);
    expect(alignOf('B2'), TextAlign.right);
  });

  testWidgets('table toolbar clear alignment restores fallback rendering', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarAlignedTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> pressTableMoreItem(String label) async {
      await tester.tap(find.byTooltip('更多表格操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await _pumpTableToolbarOverlay(tester);
    }

    TextAlign alignOf(String text) =>
        tester.widget<RichText>(_richText(text)).textAlign;

    expect(alignOf('A1'), TextAlign.center);
    expect(alignOf('B1'), TextAlign.right);

    await pressTableMoreItem('清除单元格对齐');
    var table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.alignment, isNull);
    expect(table.table.columnAlignments[0], 'right');
    expect(alignOf('A1'), TextAlign.right);

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 1,
        offset: 0,
      ),
    );
    await _pumpTableToolbarOverlay(tester);
    await pressTableMoreItem('清除单元格对齐');

    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 1)!.alignment, isNull);
    expect(table.table.columnAlignments.containsKey(1), isFalse);
    expect(alignOf('B1'), TextAlign.start);
  });

  testWidgets('table floating toolbar follows active table lifecycle', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _multiToolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 520,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);
    final firstToolbarRect = tester.getRect(toolbarFinder);

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table2',
        blockIndex: 2,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );
    await tester.pump();

    expect(toolbarFinder, findsOneWidget);
    final secondToolbarRect = tester.getRect(toolbarFinder);
    final secondCellRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-cell-border-table2-0-0')),
    );
    expect(secondToolbarRect.top, greaterThan(firstToolbarRect.top));
    expect(secondCellRect.top - secondToolbarRect.bottom,
        moreOrLessEquals(4, epsilon: 0.1));

    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table2',
          blockIndex: 2,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
      ),
    );
    await tester.pump();
    expect(toolbarFinder, findsNothing);

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table2',
        blockIndex: 2,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );
    await tester.pump();
    expect(toolbarFinder, findsOneWidget);

    controller.replaceDocument(
      const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'only-paragraph',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Table removed')],
          ),
        ],
      ),
    );
    await tester.pump();
    expect(toolbarFinder, findsNothing);
  });

  test('table floating toolbar ignores stale inactive anchor refresh', () {
    final controller = TableFloatingToolbarOverlayController();
    const activeRange = TableCellRange(
      tableBlockId: 'table2',
      blockIndex: 2,
      startRow: 0,
      endRow: 0,
      startColumn: 0,
      endColumn: 0,
    );

    TableFloatingToolbarOverlayRequest request({
      required Object owner,
      required String tableBlockId,
      required int blockIndex,
      required TableCellRange range,
      required Rect anchorRect,
    }) {
      return TableFloatingToolbarOverlayRequest(
        owner: owner,
        anchorLink: LayerLink(),
        anchorRect: anchorRect,
        visibleTop: 0,
        tableBlockId: tableBlockId,
        blockIndex: blockIndex,
        selectionRange: range,
        toolbarBuilder: (_) => const SizedBox.shrink(),
      );
    }

    final activeRequest = request(
      owner: Object(),
      tableBlockId: 'table2',
      blockIndex: 2,
      range: activeRange,
      anchorRect: const Rect.fromLTWH(20, 120, 100, 40),
    );
    controller.show(activeRequest);

    controller.show(
      request(
        owner: Object(),
        tableBlockId: 'table1',
        blockIndex: 0,
        range: const TableCellRange(
          tableBlockId: 'table1',
          blockIndex: 0,
          startRow: 0,
          endRow: 0,
          startColumn: 0,
          endColumn: 0,
        ),
        anchorRect: const Rect.fromLTWH(20, 20, 100, 40),
      ),
      replaceDifferentRequest: false,
    );
    expect(controller.request, same(activeRequest));

    final refreshedActiveRequest = request(
      owner: Object(),
      tableBlockId: 'table2',
      blockIndex: 2,
      range: activeRange,
      anchorRect: const Rect.fromLTWH(20, 140, 100, 40),
    );
    controller.show(
      refreshedActiveRequest,
      replaceDifferentRequest: false,
    );
    expect(controller.request, same(refreshedActiveRequest));

    controller.dispose();
  });

  testWidgets('table floating toolbar renders in overlay and clears selection',
      (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);
    expect(
      find.ancestor(of: toolbarFinder, matching: find.byType(Overlay)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: toolbarFinder, matching: find.byType(OverlayPortal)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('table-cell-border-table1-0-0')),
        matching: toolbarFinder,
      ),
      findsNothing,
    );

    controller.setSelection(null);
    await _pumpTableToolbarOverlay(tester);

    expect(toolbarFinder, findsNothing);
  });

  testWidgets('table floating toolbar sits above the table cells', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final unselectedCellRect = tester.getRect(
      find.bySemanticsLabel('Table cell row 1 column 1'),
    );
    expect(find.byTooltip('在上方插入行'), findsNothing);

    controller.setSelection(_tableCellSelection());
    await tester.pump();

    final selectedCellRect = tester.getRect(
      find.bySemanticsLabel('Table cell row 1 column 1'),
    );
    final tableRightCellRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-cell-border-table1-0-1')),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-floating-toolbar')),
    );
    final toolbarGap = selectedCellRect.top - toolbarRect.bottom;

    expect(selectedCellRect.top, unselectedCellRect.top);
    expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
    expect(toolbarGap, moreOrLessEquals(4, epsilon: 0.1));
    expect(toolbarRect.right, lessThanOrEqualTo(tableRightCellRect.right));
    expect(toolbarRect.right, greaterThan(tableRightCellRect.center.dx));
    expect(toolbarRect.width, lessThan(tableRightCellRect.width * 2));
  });

  testWidgets('table floating toolbar keeps compact theme close to cells', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final selectedCellRect = tester.getRect(
      find.bySemanticsLabel('Table cell row 1 column 1'),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-floating-toolbar')),
    );
    final toolbarGap = selectedCellRect.top - toolbarRect.bottom;

    expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
    expect(toolbarGap, moreOrLessEquals(4, epsilon: 0.1));
  });

  testWidgets('table floating toolbar clamps to viewport top when close', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 58,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final selectedCellRect = tester.getRect(
      find.bySemanticsLabel('Table cell row 1 column 1'),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-floating-toolbar')),
    );
    final toolbarGap = selectedCellRect.top - toolbarRect.bottom;

    expect(toolbarRect.top, greaterThanOrEqualTo(-0.1));
    expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
    expect(toolbarGap, greaterThanOrEqualTo(-0.1));
    expect(toolbarGap, lessThanOrEqualTo(4.1));
  });

  testWidgets(
      'table floating toolbar follows the selected cell while scrolling',
      (tester) async {
    final controller = WenzRichTextController(
      document: _scrollingToolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 4,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    final cellFinder =
        find.byKey(const ValueKey<String>('table-cell-border-table1-0-0'));
    expect(toolbarFinder, findsOneWidget);
    expect(cellFinder, findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );
    final scrollBefore = scrollable.position.pixels;
    expect(
      scrollable.position.maxScrollExtent,
      greaterThanOrEqualTo(scrollBefore + 48),
    );
    final cellRectBefore = tester.getRect(cellFinder);
    final toolbarRectBefore = tester.getRect(toolbarFinder);

    scrollable.position.jumpTo(scrollBefore + 48);
    await _pumpTableToolbarOverlay(tester);

    final cellRectAfter = tester.getRect(cellFinder);
    final toolbarRectAfter = tester.getRect(toolbarFinder);
    final toolbarGapAfter = cellRectAfter.top - toolbarRectAfter.bottom;

    expect(cellRectAfter.top, lessThan(cellRectBefore.top));
    expect(toolbarRectAfter.top, lessThan(toolbarRectBefore.top));
    expect(toolbarRectAfter.bottom, lessThanOrEqualTo(cellRectAfter.top));
    expect(toolbarGapAfter, moreOrLessEquals(4, epsilon: 0.1));
  });

  testWidgets(
      'table floating toolbar follows cell during rapid large scroll jump',
      (tester) async {
    final controller = WenzRichTextController(
      document: _scrollingToolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 4,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    final cellFinder =
        find.byKey(const ValueKey<String>('table-cell-border-table1-0-0'));
    expect(toolbarFinder, findsOneWidget);
    expect(cellFinder, findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );
    final maxExtent = scrollable.position.maxScrollExtent;
    expect(maxExtent, greaterThan(100));

    // Jump near max scroll extent in one large step
    scrollable.position.jumpTo(maxExtent - 40);
    await tester.pump();
    await tester.pump();

    final cellRect = tester.getRect(cellFinder);
    final toolbarRect = tester.getRect(toolbarFinder);
    final toolbarGap = cellRect.top - toolbarRect.bottom;

    expect(toolbarRect.bottom, lessThanOrEqualTo(cellRect.top));
    expect(toolbarGap, moreOrLessEquals(4, epsilon: 0.1));
    expect(toolbarRect.top, greaterThanOrEqualTo(-0.1));
  });

  testWidgets(
      'table floating toolbar clamps to visibleTop when cell scrolls near top',
      (tester) async {
    final controller = WenzRichTextController(
      document: _scrollingToolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 4,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );

    // Scroll down first, then scroll back up so cell is near the viewport top.
    scrollable.position.jumpTo(scrollable.position.pixels + 80);
    await tester.pump();
    await tester.pump();

    scrollable.position.jumpTo(scrollable.position.pixels - 80);
    await tester.pump();
    await tester.pump();

    final toolbarRect = tester.getRect(toolbarFinder);
    // Toolbar must not go above the visible top (padding top = 72).
    expect(toolbarRect.top, greaterThanOrEqualTo(-0.1));
  });

  testWidgets('table floating toolbar hides offscreen and restores on reentry',
      (tester) async {
    final controller = WenzRichTextController(
      document: _scrollingToolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 4,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    final cellFinder =
        find.byKey(const ValueKey<String>('table-cell-border-table1-0-0'));
    expect(toolbarFinder, findsOneWidget);
    expect(cellFinder, findsOneWidget);

    final scrollableFinder = find.descendant(
      of: find.byType(WenzRichTextEditor),
      matching: find.byType(Scrollable),
    );
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    final initialOffset = scrollable.position.pixels;
    final viewportRect = tester.getRect(scrollableFinder);
    final initialCellRect = tester.getRect(cellFinder);

    final partialOffset =
        (initialOffset + initialCellRect.bottom - viewportRect.top - 8)
            .clamp(0.0, scrollable.position.maxScrollExtent)
            .toDouble();
    expect(partialOffset, greaterThan(initialOffset));

    scrollable.position.jumpTo(partialOffset);
    await _pumpTableToolbarOverlay(tester);

    final partialCellRect = tester.getRect(cellFinder);
    expect(partialCellRect.top, lessThan(viewportRect.top));
    expect(partialCellRect.bottom, greaterThan(viewportRect.top));
    expect(toolbarFinder, findsOneWidget);

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await _pumpTableToolbarOverlay(tester);

    expect(toolbarFinder, findsNothing);

    scrollable.position.jumpTo(initialOffset);
    await _pumpTableToolbarOverlay(tester);

    expect(toolbarFinder, findsOneWidget);
    final restoredCellRect = tester.getRect(cellFinder);
    final restoredToolbarRect = tester.getRect(toolbarFinder);
    expect(restoredToolbarRect.bottom, lessThanOrEqualTo(restoredCellRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('table floating toolbar leaves outside text editing available',
      (tester) async {
    final controller = WenzRichTextController(
      document: _toolbarTableWithParagraphDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);

    await _tapTextOffset(tester, 'After table', 11);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX, character: 'x');
    await tester.pump();

    final paragraph = controller.document.blocks[1] as TextBlockNode;
    expect(paragraph.plainText, 'After tablex');
    expect(toolbarFinder, findsNothing);
  });

  testWidgets(
      'table floating toolbar pointer does not penetrate selection layer',
      (tester) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 1,
        tableColumnIndex: 1,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    final toolbarRenderObject = tester.renderObject(toolbarFinder);
    final toolbarRect = tester.getRect(toolbarFinder);
    final toolbarBlockerFinder = find.byKey(
      const ValueKey<String>('table-floating-toolbar-hit-test-blocker'),
    );
    final toolbarBlockerRenderObject =
        tester.renderObject(toolbarBlockerFinder);
    final toolbarBlockerRect = tester.getRect(toolbarBlockerFinder);
    final selectedCellRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-cell-border-table1-1-1')),
    );
    _expectToolbarButtonSize(tester, '在下方插入行');
    _expectToolbarButtonSize(tester, '在右侧插入列');
    _expectToolbarButtonSize(tester, '更多表格操作');
    _expectToolbarButtonSize(tester, '合并所选单元格');
    _expectMinimalToolbarSurface(tester, toolbarFinder);
    expect(
      tester.widget<IconButton>(find.byTooltip('合并所选单元格')).onPressed,
      isNull,
    );
    final buttonPoint = tester.getRect(find.byTooltip('在下方插入行')).center;

    expect(toolbarBlockerRect.left, moreOrLessEquals(toolbarRect.left));
    expect(toolbarBlockerRect.top, moreOrLessEquals(toolbarRect.top));
    expect(toolbarBlockerRect.right, moreOrLessEquals(toolbarRect.right));
    expect(toolbarBlockerRect.bottom, moreOrLessEquals(toolbarRect.bottom));

    final selectionListenerFinder = find.byWidgetPredicate((widget) {
      return widget is Listener &&
          widget.behavior == HitTestBehavior.translucent &&
          widget.onPointerDown != null &&
          widget.onPointerMove != null &&
          widget.onPointerUp != null &&
          widget.onPointerCancel != null;
    });
    expect(selectionListenerFinder, findsOneWidget);
    final selectionListenerRenderObject =
        tester.renderObject(selectionListenerFinder);

    final hitTargets = tester
        .hitTestOnBinding(buttonPoint)
        .path
        .map((entry) => entry.target)
        .toList();

    expect(
      hitTargets,
      contains(toolbarBlockerRenderObject),
      reason: 'The full visible toolbar rect must own pointer hit testing.',
    );
    expect(
      hitTargets,
      contains(toolbarRenderObject),
      reason: 'The visual toolbar should be in the same hit-test chain.',
    );
    expect(
      hitTargets,
      isNot(contains(selectionListenerRenderObject)),
      reason: 'The editor-level SelectionGestureOverlay must not receive '
          'toolbar pointers.',
    );

    final outsideToolbarTargets = tester
        .hitTestOnBinding(selectedCellRect.center)
        .path
        .map((entry) => entry.target)
        .toList();
    expect(
      outsideToolbarTargets,
      contains(selectionListenerRenderObject),
      reason: 'The overlay must not install a full-screen blocker over cells.',
    );
    expect(
      outsideToolbarTargets,
      isNot(contains(toolbarBlockerRenderObject)),
      reason: 'Toolbar hit testing should be limited to the toolbar rect.',
    );

    await tester.tapAt(buttonPoint);
    await tester.pump();

    final table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.rowCount, 3);
    expect(controller.selection?.extent.path.tableRowIndex, isNot(0));
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
  });

  testWidgets('table floating toolbar hover keeps overlay stable', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _collapsedTableCellTextSelection(
        tableBlockId: 'table1',
        blockIndex: 0,
        tableRowIndex: 1,
        tableColumnIndex: 1,
        offset: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTableToolbarOverlay(tester);
    expect(tester.takeException(), isNull);

    final toolbarFinder =
        find.byKey(const ValueKey<String>('table-floating-toolbar'));
    expect(toolbarFinder, findsOneWidget);
    final toolbarRect = tester.getRect(toolbarFinder);
    final theme = Theme.of(tester.element(toolbarFinder));
    final expectedDividerColor = theme.colorScheme.outlineVariant.withAlpha(84);
    final dividerFinder = find.descendant(
      of: toolbarFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == expectedDividerColor,
      ),
    );
    expect(dividerFinder, findsOneWidget);
    expect(tester.getSize(dividerFinder), const Size(1, 18));
    expect(
      find.ancestor(
        of: dividerFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 9 && widget.height == 32,
        ),
      ),
      findsOneWidget,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(
      location: tester.getRect(find.byTooltip('在下方插入行')).center,
    );
    await tester.pump();
    await gesture.moveTo(tester.getRect(dividerFinder).center);
    await tester.pump();
    await gesture.moveTo(toolbarRect.topLeft + const Offset(2, 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(toolbarFinder, findsOneWidget);
    expect(controller.selection?.extent.path.tableRowIndex, 1);
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
  });

  testWidgets('table cell borders paint shared grid lines once', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final topLeft = _paintedTableCellBorder(tester, 'table1', 0, 0);
    final topRight = _paintedTableCellBorder(tester, 'table1', 0, 1);
    final bottomLeft = _paintedTableCellBorder(tester, 'table1', 1, 0);
    final bottomRight = _paintedTableCellBorder(tester, 'table1', 1, 1);
    final topLeftBorderBox = _tableCellBorderBox(tester, 'table1', 0, 0);

    expect(topLeftBorderBox.position, DecorationPosition.foreground);

    _expectBorderSidePainted(topLeft.top);
    _expectBorderSidePainted(topLeft.left);
    _expectBorderSideNotPainted(topLeft.right);
    _expectBorderSideNotPainted(topLeft.bottom);

    _expectBorderSidePainted(topRight.top);
    _expectBorderSidePainted(topRight.left);
    _expectBorderSidePainted(topRight.right);
    _expectBorderSideNotPainted(topRight.bottom);

    _expectBorderSidePainted(bottomLeft.top);
    _expectBorderSidePainted(bottomLeft.left);
    _expectBorderSideNotPainted(bottomLeft.right);
    _expectBorderSidePainted(bottomLeft.bottom);

    _expectBorderSidePainted(bottomRight.top);
    _expectBorderSidePainted(bottomRight.left);
    _expectBorderSidePainted(bottomRight.right);
    _expectBorderSidePainted(bottomRight.bottom);
  });

  testWidgets('table cells use design padding and backgrounds', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _styledTableDocument(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(WenzRichTextEditor)));
    final headerBorder = _paintedTableCellBorder(tester, 'table-style', 0, 0);
    expect(headerBorder.top.color, const Color(0xFFECE9F5));

    final headerCellFinder = find.byKey(
      const ValueKey<String>('table-cell-border-table-style-0-0'),
    );
    final headerPaddings = tester.widgetList<Padding>(
      find.descendant(
        of: headerCellFinder,
        matching: find.byType(Padding),
      ),
    );
    expect(
      headerPaddings.map((padding) => padding.padding),
      contains(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
    );

    final headerRichText = tester
        .widgetList<RichText>(
          find.descendant(
            of: headerCellFinder,
            matching: find.byType(RichText),
          ),
        )
        .first;
    expect(headerRichText.text.style?.fontSize, 15);
    expect(headerRichText.text.style?.fontWeight, FontWeight.w700);
    expect(
        headerRichText.text.style?.color, theme.colorScheme.onSurfaceVariant);

    final headerBackground = _tableCellBackgroundBox(
      tester,
      'table-style',
      0,
      0,
    );
    expect(
      (headerBackground.decoration as BoxDecoration).color,
      theme.colorScheme.surfaceContainer,
    );

    final stripedBackground = _tableCellBackgroundBox(
      tester,
      'table-style',
      1,
      0,
    );
    expect(
      (stripedBackground.decoration as BoxDecoration).color,
      const Color(0xFFFAFAFF),
    );

    final customBackground = _tableCellBackgroundBox(
      tester,
      'table-style',
      2,
      0,
    );
    expect(
      (customBackground.decoration as BoxDecoration).color,
      const Color(0xFFEAF4FF),
    );
  });

  testWidgets('table column resize handle stores explicit width', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: _toolbarTableDocument(),
      selection: _tableCellSelection(),
    );

    await _pumpTableResizeEditor(tester, controller);

    await tester.drag(
      _tableColumnResizeHandleFinder(0),
      const Offset(40, 0),
    );
    await tester.pump();

    final table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths[0], isNotNull);
    expect(table.table.columnWidths[0]!, greaterThan(48));
  });

  testWidgets(
    'merged table cell internal column boundary has no resize handle',
    (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table-merged',
              table: TableModel(
                columnWidths: <int, double>{0: 120, 1: 120, 2: 120},
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'merged-a',
                      columnSpan: 2,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merged-a-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Merged A')],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'covered-b', covered: true),
                    TableCellNode(
                      id: 'cell-c',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-c-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'C')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: _collapsedTableCellTextSelection(
          tableBlockId: 'table-merged',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
      );

      await _pumpTableResizeEditor(tester, controller);

      expect(_tableColumnResizeHandleFinder(0), findsNothing);
      expect(_tableColumnResizeHandleFinder(1), findsOneWidget);

      final mergedRect = tester.getRect(
        _tableCellFinder('table-merged', 0, 0),
      );
      final hiddenBoundary = Offset(
        mergedRect.left + 120,
        mergedRect.center.dy,
      );
      await tester.dragFrom(hiddenBoundary, const Offset(40, 0));
      await tester.pump();

      final table = controller.document.blocks.single as TableBlockNode;
      expect(
        table.table.columnWidths,
        <int, double>{0: 120, 1: 120, 2: 120},
      );
    },
  );

  testWidgets(
    'merged rows hide internal boundary while visible row boundary resizes',
    (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table-mixed',
              table: TableModel(
                columnWidths: <int, double>{0: 120, 1: 120, 2: 120},
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'merged-a',
                      columnSpan: 2,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merged-a-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Merged A')],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'covered-b', covered: true),
                    TableCellNode(
                      id: 'cell-c',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-c-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'C')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(
                      id: 'cell-a2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-a2-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'A2')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'cell-b2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-b2-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'B2')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'cell-c2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-c2-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'C2')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: _collapsedTableCellTextSelection(
          tableBlockId: 'table-mixed',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 0,
        ),
      );

      await _pumpTableResizeEditor(tester, controller);

      final mergedRect = tester.getRect(
        _tableCellFinder('table-mixed', 0, 0),
      );
      final hiddenBoundary = Offset(
        mergedRect.left + 120,
        mergedRect.center.dy,
      );
      await tester.dragFrom(hiddenBoundary, const Offset(40, 0));
      await tester.pump();
      var table = controller.document.blocks.single as TableBlockNode;
      expect(
        table.table.columnWidths,
        <int, double>{0: 120, 1: 120, 2: 120},
      );

      expect(_tableColumnResizeHandleFinder(0), findsOneWidget);
      final visibleBoundary = tester
          .getRect(
            _tableCellFinder('table-mixed', 1, 0),
          )
          .centerRight;
      await tester.dragFrom(visibleBoundary, const Offset(40, 0));
      await tester.pump();

      table = controller.document.blocks.single as TableBlockNode;
      expect(table.table.columnWidths[0], greaterThan(120));
      expect(table.table.columnWidths[1], 120);
      expect(table.table.columnWidths[2], 120);
    },
  );

  testWidgets(
    'renders formula, mention, and emoji inline embeds',
    (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Ask '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'x^2'},
                ),
                TextRun(text: ' '),
                InlineEmbed(
                  embedType: 'emoji',
                  data: <String, Object?>{'emoji': '😀'},
                ),
                TextRun(text: ' from '),
                InlineEmbed(
                  embedType: 'mention',
                  data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
                ),
                TextRun(text: ' bad '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': r'\Gaarbled$'},
                ),
              ],
            ),
            TableBlockNode(
              id: 'table1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'cell1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Score '),
                            InlineEmbed(
                              embedType: 'formula',
                              data: <String, Object?>{'text': 'a+b'},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            BlockEmbedNode(
              id: 'formula-block',
              embedType: 'formula',
              data: <String, Object?>{'text': r'\int_0^1 x dx'},
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(
        _richText(
            'Ask $_formulaPlaceholder 😀 from @Ada bad $_formulaPlaceholder'),
        findsOneWidget,
      );
      expect(_richText('Score $_formulaPlaceholder'), findsOneWidget);
      expect(find.byType(Math), findsNWidgets(4));
      final inlineFormulas = find.byKey(_inlineFormulaKey);
      expect(inlineFormulas, findsNWidgets(3));
      for (var index = 0; index < 3; index += 1) {
        _expectInlineFormulaHasNoDefaultBackground(
          tester,
          inlineFormulas.at(index),
        );
      }
      final scheme = Theme.of(
        tester.element(find.byType(WenzRichTextEditor)),
      ).colorScheme;
      _expectFormulaBlockHasNoDefaultBackground(
        tester,
        'formula-block',
        scheme,
      );
      final inlineSpan = _richTextSpan(
        tester,
        'Ask $_formulaPlaceholder 😀 from @Ada bad $_formulaPlaceholder',
      );
      expect(
        _leafSpan(inlineSpan, '@Ada')?.style?.backgroundColor,
        isNotNull,
      );
      expect(find.text('Formula'), findsNothing);
      expect(find.text(r'\int_0^1 x dx'), findsOneWidget);
      expect(find.text(r'\Gaarbled$'), findsOneWidget);
    },
  );

  testWidgets('feedback #2 regressions keep selection controls and layout',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mentionRenderText = 'Ask @Ada follow';
    const calloutBody = 'Info body selectable';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'mention-p',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Ask '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
              TextRun(text: ' follow'),
            ],
          ),
          TextBlockNode(
            id: 'quote1',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Quoted background')],
          ),
          TextBlockNode(
            id: 'todo1',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'Finish regression')],
          ),
          CalloutBlockNode(
            id: 'info1',
            title: 'Info Title',
            content: <InlineNode>[TextRun(text: calloutBody)],
          ),
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a1-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'A1')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b1-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'B1')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a2-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'A2')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b2-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'B2')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextBlockNode(
            id: 'formula-p',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Inline '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' end'),
            ],
          ),
          BlockEmbedNode(
            id: 'formula-block',
            embedType: 'formula',
            data: <String, Object?>{'text': r'\int_0^1 x dx'},
          ),
        ],
      ),
      selection: collapsedTextSelection('mention-p', 0, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 820,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 72,
                right: 16,
                bottom: 16,
              ),
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final quoteBackground = tester.widget<DecoratedBox>(find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    ));
    expect((quoteBackground.decoration as BoxDecoration).color, isNotNull);
    expect(find.text('|'), findsNothing);
    expect(_richText('Inline $_formulaPlaceholder end'), findsOneWidget);
    expect(find.byKey(_inlineFormulaKey), findsOneWidget);
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.text('Formula'), findsNothing);
    expect(find.text(r'\int_0^1 x dx'), findsOneWidget);

    final mentionRight = _globalTextRangePoint(
      tester,
      mentionRenderText,
      4,
      8,
      0.75,
    );
    final followingEnd = _globalTextOffset(
      tester,
      mentionRenderText,
      mentionRenderText.length,
    );
    await tester.dragFrom(mentionRight, followingEnd - mentionRight);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'mention-p',
      blockIndex: 0,
      baseOffset: 5,
      extentOffset: 12,
    );

    await _tapTextOffset(tester, calloutBody, 5);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'info1',
      blockIndex: 3,
      baseOffset: 5,
      extentOffset: 5,
    );

    final selectionBeforeTodo = controller.selection;
    final checkboxFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-todo1'),
    );
    await tester.tap(checkboxFinder);
    await tester.pump();

    final todoBlock = controller.document.blocks[2] as TextBlockNode;
    expect(todoBlock.attributes.checked, isTrue);
    expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    expect(controller.selection, selectionBeforeTodo);

    final topLeft = _paintedTableCellBorder(tester, 'table1', 0, 0);
    final bottomRight = _paintedTableCellBorder(tester, 'table1', 1, 1);
    _expectBorderSidePainted(topLeft.top);
    _expectBorderSidePainted(topLeft.left);
    _expectBorderSideNotPainted(topLeft.right);
    _expectBorderSideNotPainted(topLeft.bottom);
    _expectBorderSidePainted(bottomRight.top);
    _expectBorderSidePainted(bottomRight.left);
    _expectBorderSidePainted(bottomRight.right);
    _expectBorderSidePainted(bottomRight.bottom);

    final tablePosition = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 4,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    );
    controller.setSelection(
      DocumentSelection(base: tablePosition, extent: tablePosition),
    );
    await tester.pump();

    final selectedCellRect = tester.getRect(
      find.bySemanticsLabel('Table cell row 1 column 1'),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-floating-toolbar')),
    );
    expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
    expect(selectedCellRect.top - toolbarRect.bottom,
        moreOrLessEquals(4, epsilon: 0.1));
  });

  testWidgets('sizes normal and tall inline formulas', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'formula-baseline',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Before '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' middle '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{
                  'text': r'\frac{\sum_{i=1}^{n} i}{\sqrt{n}}',
                },
              ),
              TextRun(text: ' after'),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 160,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final formulaFinder = find.byKey(_inlineFormulaKey);
    expect(formulaFinder, findsNWidgets(2));
    final normalFormulaRect = tester.getRect(formulaFinder.at(0));
    final tallFormulaRect = tester.getRect(formulaFinder.at(1));

    expect(normalFormulaRect.height, moreOrLessEquals(23.2, epsilon: 0.1));
    expect(tallFormulaRect.height, greaterThan(normalFormulaRect.height + 12));
    expect(tallFormulaRect.height, lessThan(48));
  });

  testWidgets(
      'formula interaction entry points keep current renderer boundaries',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Before '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{
                  'text': 'x_text',
                  'latex': 'x_latex',
                  'value': 'x_value',
                  'formula': 'x_formula',
                },
              ),
              TextRun(text: ' after'),
            ],
          ),
          BlockEmbedNode(
            id: 'block-formula-fallback',
            embedType: 'formula',
            data: <String, Object?>{'text': 'data_text'},
            fallbackText: 'fallback_text',
          ),
          BlockEmbedNode(
            id: 'block-formula-data',
            embedType: 'formula',
            data: <String, Object?>{
              'latex': 'latex_text',
              'value': 'value_text',
              'formula': 'formula_text',
            },
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(_inlineFormulaKey), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-formula-card-block-formula-fallback',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-formula-preview-block-formula-data',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('fallback_text'), findsOneWidget);
    expect(find.text('latex_text'), findsOneWidget);

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();

    final inlineSelection = controller.selection;
    expect(inlineSelection, isNotNull);
    expect(inlineSelection!.isCollapsed, isTrue);
    expect(inlineSelection.extent.blockId, 'inline-formula');
    expect(inlineSelection.extent.path.isBlockText, isTrue);
    expect(inlineSelection.extent.offset, inInclusiveRange(7, 8));
    expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
    _expectChromeSurfaceMaterial(tester, find.byKey(_formulaEditorPopupKey));

    await tester.tap(find.byKey(_formulaEditorCancelKey));
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-formula-card-block-formula-fallback',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(_formulaEditorInputKey))
          .controller
          ?.text,
      'fallback_text',
    );
  });

  testWidgets('formula popup edits inline formula and writes all data fields',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' now'),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(_formulaEditorInputKey))
            .controller
            ?.text,
        'x^2');

    await tester.enterText(find.byKey(_formulaEditorInputKey), 'y^2');
    await tester.tap(find.byKey(_formulaEditorConfirmKey));
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    final block = controller.document.blocks.single as TextBlockNode;
    final formula = block.content[1] as InlineEmbed;
    expect(formula.data['text'], 'y^2');
    expect(formula.data['latex'], 'y^2');
    expect(formula.data['value'], 'y^2');
    expect(formula.data['formula'], 'y^2');
  });

  testWidgets('formula popup edits block formula and updates preview data',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'formula-block',
            embedType: 'formula',
            data: <String, Object?>{'latex': 'a+b'},
            fallbackText: 'a+b',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-formula-card-formula-block'),
      ),
    );
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(_formulaEditorInputKey))
            .controller
            ?.text,
        'a+b');

    await tester.enterText(find.byKey(_formulaEditorInputKey), 'c+d');
    await tester.tap(find.byKey(_formulaEditorConfirmKey));
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    expect(find.text('c+d'), findsOneWidget);
    final block = controller.document.blocks.single as BlockEmbedNode;
    expect(block.fallbackText, 'c+d');
    expect(block.data['text'], 'c+d');
    expect(block.data['latex'], 'c+d');
    expect(block.data['value'], 'c+d');
    expect(block.data['formula'], 'c+d');
  });

  testWidgets(
      'formula popup keeps arrow keys in input away from editor body (inline)',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' now'),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();

    await _verifyFormulaPopupOwnsArrowKeys(tester, controller, inputLength: 3);
  });

  testWidgets(
      'formula popup keeps arrow keys in input away from editor body (block)',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'intro',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Intro line')],
          ),
          BlockEmbedNode(
            id: 'formula-block',
            embedType: 'formula',
            data: <String, Object?>{'latex': 'a+b'},
            fallbackText: 'a+b',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    // Seed a known body caret so a stolen arrow key would visibly move it.
    await _tapTextOffset(tester, 'Intro line', 0);
    await tester.pump();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-formula-card-formula-block'),
      ),
    );
    await tester.pump();

    await _verifyFormulaPopupOwnsArrowKeys(tester, controller, inputLength: 3);
  });

  testWidgets(
      'formula popup cancel close and empty input keep document unchanged',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();
    await tester.enterText(find.byKey(_formulaEditorInputKey), 'cancelled');
    await tester.tap(find.byKey(_formulaEditorCancelKey));
    await tester.pump();

    var block = controller.document.blocks.single as TextBlockNode;
    var formula = block.content[1] as InlineEmbed;
    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    expect(formula.data['text'], 'x^2');

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();
    await tester.enterText(find.byKey(_formulaEditorInputKey), '   ');
    await tester.tap(find.byKey(_formulaEditorConfirmKey));
    await tester.pump();

    block = controller.document.blocks.single as TextBlockNode;
    formula = block.content[1] as InlineEmbed;
    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    expect(formula.data['text'], 'x^2');

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();
    await tester.enterText(find.byKey(_formulaEditorInputKey), 'closed');
    await tester.tap(find.byKey(_formulaEditorCloseKey));
    await tester.pump();

    block = controller.document.blocks.single as TextBlockNode;
    formula = block.content[1] as InlineEmbed;
    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    expect(formula.data['text'], 'x^2');

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();
    await tester.tapAt(const Offset(780, 580));
    await tester.pump();

    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
    block = controller.document.blocks.single as TextBlockNode;
    formula = block.content[1] as InlineEmbed;
    expect(formula.data['text'], 'x^2');
  });

  testWidgets('formula popup is disabled in read only mode', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
            ],
          ),
          BlockEmbedNode(
            id: 'formula-block',
            embedType: 'formula',
            data: <String, Object?>{'text': 'y^2'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_inlineFormulaKey));
    await tester.pump();
    expect(find.byKey(_formulaEditorPopupKey), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('wenz-richtext-formula-card-formula-block'),
      ),
    );
    await tester.pump();
    expect(find.byKey(_formulaEditorPopupKey), findsNothing);
  });

  testWidgets('formula renderers can be overridden by external renderers',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'inline-formula',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
            ],
          ),
          BlockEmbedNode(
            id: 'block-formula',
            embedType: 'formula',
            data: <String, Object?>{'text': 'y^2'},
          ),
        ],
      ),
    );
    final inlineRenderer = InlineEmbedRendererCallback((context, embed, style) {
      if (embed.embedType.trim() == 'formula') {
        return TextSpan(
          text: 'custom-inline-${embed.data['text']}',
          style: style,
        );
      }
      return null;
    });
    final blockRenderers = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(blockRenderers);
    blockRenderers.registerEmbed('formula', (context, renderContext) {
      final block = renderContext.block as BlockEmbedNode;
      return Text('custom-block-${block.data['text']}');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            inlineEmbedRenderer: inlineRenderer,
            blockRenderers: blockRenderers,
          ),
        ),
      ),
    );

    expect(_richText('Solve custom-inline-x^2'), findsOneWidget);
    expect(find.byKey(_inlineFormulaKey), findsNothing);
    expect(find.text('custom-block-y^2'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-formula-card-block-formula'),
      ),
      findsNothing,
    );
  });

  // Regression coverage for "formula popup updates then the rendering
  // disappears" (plan #60). The data-layer update was already covered; these
  // tests assert the *rendered output*: the formula widget stays present and
  // sized (not collapsed to nothing) and the laid-out math subtree reflects the
  // current content after popup confirm / cancel / undo / redo.
  group('formula update rendering regression', () {
    Widget editorFor(WenzRichTextController controller) => MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        );

    testWidgets(
        'inline formula keeps rendering new content after popup confirm',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'inline-formula',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Solve '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'x^2'},
                ),
                TextRun(text: ' now'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(editorFor(controller));
      await tester.pump();

      // Baseline: the formula is laid out with its original content.
      expect(find.byKey(_inlineFormulaKey), findsOneWidget);
      expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
      final before = tester.getRect(find.byKey(_inlineFormulaKey));
      expect(before.height, greaterThan(0));
      expect(before.width, greaterThan(0));

      await tester.tap(find.byKey(_inlineFormulaKey));
      await tester.pump();
      await tester.enterText(find.byKey(_formulaEditorInputKey), 'y^2');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      final inlineBlock = controller.document.blocks.single as TextBlockNode;
      expect((inlineBlock.content[1] as InlineEmbed).data['text'], 'y^2');

      // The formula did not disappear: it is still present, sized, and the math
      // subtree rebuilt with the new source (stale content is gone).
      expect(find.byKey(_inlineFormulaKey), findsOneWidget);
      expect(find.byKey(_formulaMathKey('y^2')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('x^2')), findsNothing);
      final after = tester.getRect(find.byKey(_inlineFormulaKey));
      expect(after.height, greaterThan(0));
      expect(after.width, greaterThan(0));
    });

    testWidgets('multiple inline formulas update independently and keep sizing',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'inline-formula',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Ask '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'a+b'},
                ),
                TextRun(text: ' then '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'c+d'},
                ),
                TextRun(text: ' end'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 160,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final formulaFinder = find.byKey(_inlineFormulaKey);
      expect(formulaFinder, findsNWidgets(2));
      expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);
      // Both placeholders lay out non-zero — the multi-placeholder dimension
      // path that previously collapsed one of them now keeps both.
      final firstBefore = tester.getRect(formulaFinder.at(0));
      final secondBefore = tester.getRect(formulaFinder.at(1));
      expect(firstBefore.height, greaterThan(0));
      expect(firstBefore.width, greaterThan(0));
      expect(secondBefore.height, greaterThan(0));
      expect(secondBefore.width, greaterThan(0));

      // Update only the first formula via its popup.
      await tester.tap(formulaFinder.at(0));
      await tester.pump();
      await tester.enterText(find.byKey(_formulaEditorInputKey), 'x+y');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      expect(find.byKey(_inlineFormulaKey), findsNWidgets(2));
      // The first formula rebuilt with the new content; the second is untouched.
      expect(find.byKey(_formulaMathKey('x+y')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('a+b')), findsNothing);
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);

      final firstAfter = tester.getRect(find.byKey(_inlineFormulaKey).at(0));
      final secondAfter = tester.getRect(find.byKey(_inlineFormulaKey).at(1));
      expect(firstAfter.height, greaterThan(0));
      expect(firstAfter.width, greaterThan(0));
      // The untouched formula keeps exactly its original slot size.
      expect(
        secondAfter.height,
        moreOrLessEquals(secondBefore.height, epsilon: 0.01),
      );
      expect(
        secondAfter.width,
        moreOrLessEquals(secondBefore.width, epsilon: 0.01),
      );

      final block = controller.document.blocks.single as TextBlockNode;
      expect((block.content[1] as InlineEmbed).data['text'], 'x+y');
      expect((block.content[3] as InlineEmbed).data['text'], 'c+d');
    });

    testWidgets('adjacent inline formulas open and update the tapped target',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'adjacent-inline-formulas',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Solve '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'a+b'},
                ),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'c+d'},
                ),
                TextRun(text: ' now'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 160,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      Finder formulas() => find.byKey(_inlineFormulaKey);
      expect(formulas(), findsNWidgets(2));
      expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);
      final firstBefore = tester.getRect(formulas().at(0));
      final secondBefore = tester.getRect(formulas().at(1));
      expect(firstBefore.height, greaterThan(0));
      expect(firstBefore.width, greaterThan(0));
      expect(secondBefore.height, greaterThan(0));
      expect(secondBefore.width, greaterThan(0));

      await tester.tap(formulas().at(1));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
      final secondInput = tester.widget<TextField>(
        find.byKey(_formulaEditorInputKey),
      );
      expect(secondInput.controller!.text, 'c+d');

      await tester.enterText(find.byKey(_formulaEditorInputKey), 'z^2');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      expect(formulas(), findsNWidgets(2));
      expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('z^2')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsNothing);
      final firstAfter = tester.getRect(formulas().at(0));
      final secondAfter = tester.getRect(formulas().at(1));
      expect(firstAfter.height, greaterThan(0));
      expect(firstAfter.width, greaterThan(0));
      expect(secondAfter.height, greaterThan(0));
      expect(secondAfter.width, greaterThan(0));

      final block = controller.document.blocks.single as TextBlockNode;
      final first = block.content[1] as InlineEmbed;
      final second = block.content[2] as InlineEmbed;
      expect(first.data['text'], 'a+b');
      expect(second.data['text'], 'z^2');

      await tester.tap(formulas().at(0));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
      final firstInput = tester.widget<TextField>(
        find.byKey(_formulaEditorInputKey),
      );
      expect(firstInput.controller!.text, 'a+b');
    });

    testWidgets('inline formula grows when updated to a tall fraction',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'inline-formula',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Answer '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'a'},
                ),
                TextRun(text: ' done'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(editorFor(controller));
      await tester.pump();

      expect(find.byKey(_formulaMathKey('a')), findsOneWidget);
      final before = tester.getRect(find.byKey(_inlineFormulaKey));
      expect(before.height, greaterThan(0));

      await tester.tap(find.byKey(_inlineFormulaKey));
      await tester.pump();
      await tester.enterText(
          find.byKey(_formulaEditorInputKey), r'\frac{1}{2}');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      // New tall content laid out from scratch; old flat content gone.
      expect(find.byKey(_formulaMathKey(r'\frac{1}{2}')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('a')), findsNothing);
      final after = tester.getRect(find.byKey(_inlineFormulaKey));
      expect(after.height, greaterThan(0));
      expect(after.width, greaterThan(0));
      // The taller formula reserves more vertical space than the flat one.
      expect(after.height, greaterThan(before.height + 8));
      expect(after.height, lessThan(48));
    });

    testWidgets('block formula preview renders new content after popup confirm',
        (tester) async {
      const blockId = 'formula-block';
      const cardKey = ValueKey<String>('wenz-richtext-formula-card-$blockId');
      const previewKey =
          ValueKey<String>('wenz-richtext-formula-preview-$blockId');
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            BlockEmbedNode(
              id: blockId,
              embedType: 'formula',
              data: <String, Object?>{'latex': 'a+b'},
              fallbackText: 'a+b',
            ),
          ],
        ),
      );

      await tester.pumpWidget(editorFor(controller));
      await tester.pump();

      expect(find.byKey(cardKey), findsOneWidget);
      expect(find.byKey(previewKey), findsOneWidget);
      expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
      expect(find.text('a+b'), findsOneWidget);

      await tester.tap(find.byKey(cardKey));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(_formulaEditorInputKey))
            .controller
            ?.text,
        'a+b',
      );
      await tester.enterText(find.byKey(_formulaEditorInputKey), 'c+d');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      // Preview refreshes (does not disappear): preview widget present, source
      // text and laid-out math reflect the new content.
      expect(find.byKey(previewKey), findsOneWidget);
      expect(find.text('c+d'), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('a+b')), findsNothing);
      final block = controller.document.blocks.single as BlockEmbedNode;
      expect(block.data['text'], 'c+d');
    });

    testWidgets(
        'cancel close empty and outside tap leave inline rendering intact',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'inline-formula',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Solve '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'x^2'},
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(editorFor(controller));
      await tester.pump();

      Rect formulaRect() => tester.getRect(find.byKey(_inlineFormulaKey));
      // Baseline render present and sized.
      expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
      expect(formulaRect().height, greaterThan(0));

      Future<void> dismissKeepingRender(Future<void> Function() dismiss) async {
        await tester.tap(find.byKey(_inlineFormulaKey));
        await tester.pump();
        await tester.enterText(find.byKey(_formulaEditorInputKey), 'changed');
        await dismiss();
        await tester.pump();
        expect(find.byKey(_formulaEditorPopupKey), findsNothing);
        expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
        expect(find.byKey(_formulaMathKey('changed')), findsNothing);
        expect(formulaRect().height, greaterThan(0));
      }

      // Cancel button.
      await dismissKeepingRender(
        () async => tester.tap(find.byKey(_formulaEditorCancelKey)),
      );
      // Empty/whitespace confirm is a no-op.
      await dismissKeepingRender(() async {
        await tester.enterText(find.byKey(_formulaEditorInputKey), '   ');
        await tester.tap(find.byKey(_formulaEditorConfirmKey));
      });
      // Close button.
      await dismissKeepingRender(
        () async => tester.tap(find.byKey(_formulaEditorCloseKey)),
      );
      // Outside tap dismisses the popup.
      await tester.tap(find.byKey(_inlineFormulaKey));
      await tester.pump();
      await tester.tapAt(const Offset(780, 580));
      await tester.pump();
      expect(find.byKey(_formulaEditorPopupKey), findsNothing);
      expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
      expect(formulaRect().height, greaterThan(0));

      // None of the dismiss paths mutated the document.
      final embed = (controller.document.blocks.single as TextBlockNode)
          .content[1] as InlineEmbed;
      expect(embed.data['text'], 'x^2');
    });

    testWidgets('undo and redo re-render inline and block formulas per history',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Solve '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'x^2'},
                ),
              ],
            ),
            BlockEmbedNode(
              id: 'formula-block',
              embedType: 'formula',
              data: <String, Object?>{'latex': 'a+b'},
              fallbackText: 'a+b',
            ),
          ],
        ),
      );

      await tester.pumpWidget(editorFor(controller));
      await tester.pump();

      // Step A: update the inline formula via its popup.
      await tester.tap(find.byKey(_inlineFormulaKey));
      await tester.pump();
      await tester.enterText(find.byKey(_formulaEditorInputKey), 'y^2');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();
      // Step B: update the block formula via its popup.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('wenz-richtext-formula-card-formula-block'),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(_formulaEditorInputKey), 'c+d');
      await tester.tap(find.byKey(_formulaEditorConfirmKey));
      await tester.pump();

      // Both rendered to their new content and the inline slot stays sized.
      expect(find.byKey(_formulaMathKey('y^2')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(_inlineFormulaKey)).height,
        greaterThan(0),
      );

      // Undo B (most recent): block reverts, inline unchanged.
      expect(controller.undo(), isTrue);
      await tester.pump();
      expect(find.byKey(_formulaMathKey('a+b')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('c+d')), findsNothing);
      expect(find.byKey(_formulaMathKey('y^2')), findsOneWidget);

      // Undo A: inline reverts, still rendered.
      expect(controller.undo(), isTrue);
      await tester.pump();
      expect(find.byKey(_formulaMathKey('x^2')), findsOneWidget);
      expect(find.byKey(_formulaMathKey('y^2')), findsNothing);
      expect(
        tester.getRect(find.byKey(_inlineFormulaKey)).height,
        greaterThan(0),
      );

      // Redo A then B: content replays in order.
      expect(controller.redo(), isTrue);
      await tester.pump();
      expect(find.byKey(_formulaMathKey('y^2')), findsOneWidget);
      expect(controller.redo(), isTrue);
      await tester.pump();
      expect(find.byKey(_formulaMathKey('c+d')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(_inlineFormulaKey)).height,
        greaterThan(0),
      );
    });
  });

  testWidgets('aligns todo checkbox with adjusted text line height',
      (tester) async {
    const singleLineText = 'Ship core';
    const wrappedText =
        'Ship a wrapped todo item with enough words to span two lines';
    const expectedCheckboxSize = Size(20, 28);
    const expectedTextGap = 6.0;
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'todo-single',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: singleLineText)],
          ),
          TextBlockNode(
            id: 'todo-wrapped',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: wrappedText)],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final singleCheckboxRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-todo-single'),
    ));
    final wrappedCheckboxRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-todo-wrapped'),
    ));
    final singleTextFinder = _richText(singleLineText);
    final wrappedTextFinder = _richText(wrappedText);
    final singleTextRect = tester.getRect(singleTextFinder);
    final wrappedTextRect = tester.getRect(wrappedTextFinder);
    final singleFirstLineCenter =
        _richTextFirstLineCenterY(tester, singleTextFinder);
    final wrappedFirstLineCenter =
        _richTextFirstLineCenterY(tester, wrappedTextFinder);
    final singleCheckboxOffset =
        singleCheckboxRect.center.dy - singleFirstLineCenter;
    final wrappedCheckboxOffset =
        wrappedCheckboxRect.center.dy - wrappedFirstLineCenter;
    final wrappedLineMetrics = _richTextLineMetrics(tester, wrappedTextFinder);

    expect(singleCheckboxRect.size, expectedCheckboxSize);
    expect(wrappedCheckboxRect.size, expectedCheckboxSize);
    expect(
      singleTextRect.left - singleCheckboxRect.right,
      moreOrLessEquals(expectedTextGap, epsilon: 0.1),
    );
    expect(
      wrappedTextRect.left - wrappedCheckboxRect.right,
      moreOrLessEquals(expectedTextGap, epsilon: 0.1),
    );
    expect(
      _richTextFirstLineHeight(tester, singleTextFinder),
      moreOrLessEquals(singleCheckboxRect.height, epsilon: 0.75),
    );
    expect(
      _richTextFirstLineHeight(tester, wrappedTextFinder),
      moreOrLessEquals(wrappedCheckboxRect.height, epsilon: 0.75),
    );
    expect(wrappedLineMetrics.length, greaterThan(1));
    expect(
      wrappedLineMetrics.skip(1).map((line) => line.left),
      everyElement(
          moreOrLessEquals(wrappedLineMetrics.first.left, epsilon: 0.1)),
    );
    expect(singleCheckboxOffset, moreOrLessEquals(0, epsilon: 0.75));
    expect(wrappedCheckboxOffset, moreOrLessEquals(0, epsilon: 0.75));
  });

  testWidgets('todo checkbox hover overlay is transparent and click toggles',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'todo-hover',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'task', checked: false),
            content: <InlineNode>[TextRun(text: 'Hover transparent todo')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final checkboxFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-todo-checkbox-todo-hover'),
    );
    expect(checkboxFinder, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(checkboxFinder));
    await tester.pump();

    final hoveredCheckbox = tester.widget<Checkbox>(checkboxFinder);
    expect(hoveredCheckbox.value, isFalse);
    expect(
      hoveredCheckbox.overlayColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      Colors.transparent,
    );
    expect(
      hoveredCheckbox.overlayColor?.resolve(<WidgetState>{
        WidgetState.hovered,
        WidgetState.focused,
      }),
      Colors.transparent,
    );

    await gesture.removePointer();
    await tester.tap(checkboxFinder);
    await tester.pump();

    expect(
      (controller.document.blocks.single as TextBlockNode).attributes.checked,
      isTrue,
    );
    expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
  });

  testWidgets(
    'feedback #4 visual regressions keep formula todo and toolbar metrics',
    (tester) async {
      tester.view.physicalSize = const Size(900, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const normalFormulaText = '中文 Before $_formulaPlaceholder after 😀';
      const tallFormulaText = 'Tall $_formulaPlaceholder after';
      const singleTodoText = 'Ship core';
      const wrappedTodoText =
          'Ship a wrapped todo item with enough words to span at least two '
          'lines while keeping every continuation aligned under the text';
      const expectedTodoTextGap = 6.0;
      const tableBlockIndex = 4;
      final tablePosition = DocumentPosition.tableCell(
        tableBlockId: 'table1',
        blockIndex: tableBlockIndex,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 0,
      );
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'formula-normal',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: '中文 Before '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{'text': 'x^2'},
                ),
                TextRun(text: ' after 😀'),
              ],
            ),
            TextBlockNode(
              id: 'formula-tall',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Tall '),
                InlineEmbed(
                  embedType: 'formula',
                  data: <String, Object?>{
                    'text': r'\frac{\sum_{i=1}^{n} i}{\sqrt{n}}',
                  },
                ),
                TextRun(text: ' after'),
              ],
            ),
            TextBlockNode(
              id: 'todo-single',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'task', checked: false),
              content: <InlineNode>[TextRun(text: singleTodoText)],
            ),
            TextBlockNode(
              id: 'todo-wrapped',
              type: BlockType.listItem,
              attributes: BlockAttributes(listType: 'task', checked: false),
              content: <InlineNode>[TextRun(text: wrappedTodoText)],
            ),
            TableBlockNode(
              id: 'table1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'cell-a1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-a1-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'A1')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'cell-b1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-b1-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'B1')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: DocumentSelection(
          base: tablePosition,
          extent: tablePosition,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 520,
              child: WenzRichTextEditor(
                controller: controller,
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 72,
                  right: 16,
                  bottom: 16,
                ),
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final formulaFinder = find.byKey(_inlineFormulaKey);
      expect(formulaFinder, findsNWidgets(2));
      final normalFormulaTextRect =
          tester.getRect(_richText(normalFormulaText));
      final tallFormulaTextRect = tester.getRect(_richText(tallFormulaText));
      final normalFormulaRect = tester.getRect(formulaFinder.at(0));
      final tallFormulaRect = tester.getRect(formulaFinder.at(1));

      expect(
          tallFormulaRect.height, greaterThan(normalFormulaRect.height + 12));
      expect(tallFormulaRect.height, lessThan(48));
      expect(
          tallFormulaTextRect.height, greaterThan(tallFormulaRect.height - 1));
      expect(
        normalFormulaRect.center.dy - normalFormulaTextRect.center.dy,
        moreOrLessEquals(0, epsilon: 0.75),
      );
      expect(
        tallFormulaRect.center.dy - tallFormulaTextRect.center.dy,
        moreOrLessEquals(0, epsilon: 0.75),
      );

      final singleCheckboxRect = tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-todo-checkbox-todo-single'),
      ));
      final wrappedCheckboxRect = tester.getRect(find.byKey(
        const ValueKey<String>('wenz-richtext-todo-checkbox-todo-wrapped'),
      ));
      final singleTextFinder = _richText(singleTodoText);
      final wrappedTextFinder = _richText(wrappedTodoText);
      final singleTextRect = tester.getRect(singleTextFinder);
      final wrappedTextRect = tester.getRect(wrappedTextFinder);
      final singleFirstLineCenter =
          _richTextFirstLineCenterY(tester, singleTextFinder);
      final wrappedFirstLineCenter =
          _richTextFirstLineCenterY(tester, wrappedTextFinder);
      final wrappedLineMetrics =
          _richTextLineMetrics(tester, wrappedTextFinder);

      expect(wrappedLineMetrics.length, greaterThan(1));
      expect(
        wrappedLineMetrics.skip(1).map((line) => line.left),
        everyElement(
            moreOrLessEquals(wrappedLineMetrics.first.left, epsilon: 0.1)),
      );
      expect(
        singleCheckboxRect.center.dy - singleFirstLineCenter,
        moreOrLessEquals(0, epsilon: 0.75),
      );
      expect(
        wrappedCheckboxRect.center.dy - wrappedFirstLineCenter,
        moreOrLessEquals(0, epsilon: 0.75),
      );
      expect(
        singleTextRect.left - singleCheckboxRect.right,
        moreOrLessEquals(expectedTodoTextGap, epsilon: 0.1),
      );
      expect(
        wrappedTextRect.left - wrappedCheckboxRect.right,
        moreOrLessEquals(expectedTodoTextGap, epsilon: 0.1),
      );

      final selectedCellRect = tester.getRect(
        find.bySemanticsLabel('Table cell row 1 column 1'),
      );
      final toolbarRect = tester.getRect(
        find.byKey(const ValueKey<String>('table-floating-toolbar')),
      );
      final toolbarGap = selectedCellRect.top - toolbarRect.bottom;

      expect(toolbarRect.bottom, lessThanOrEqualTo(selectedCellRect.top));
      expect(toolbarGap, moreOrLessEquals(4, epsilon: 0.1));
    },
  );

  testWidgets('allows custom inline embed text rendering', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Solve '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' '),
              InlineEmbed(
                embedType: 'emoji',
                data: <String, Object?>{'emoji': '😀'},
              ),
              TextRun(text: ' with '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
            ],
          ),
        ],
      ),
    );
    final renderer = InlineEmbedRendererCallback((context, embed, style) {
      if (embed.embedType == 'formula') {
        return TextSpan(text: 'formula(${embed.data['text']})', style: style);
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            inlineEmbedRenderer: renderer,
          ),
        ),
      ),
    );

    expect(_richText('Solve formula(x^2) 😀 with @Ada'), findsOneWidget);
  });

  testWidgets('mention inline embeds define default interaction boundary',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-mention-boundary',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Hi '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{
                  'id': 'u1',
                  'label': 'Ada',
                  'role': 'admin',
                },
              ),
              TextRun(text: ' and '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u2', 'label': ''},
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller, enableIme: false),
        ),
      ),
    );

    expect(_richText('Hi @Ada and @mention'), findsOneWidget);
    final block = controller.document.blocks.single as TextBlockNode;
    final mentions = block.content.whereType<InlineEmbed>().toList();
    expect(mentions.first.embedType, 'mention');
    expect(mentions.first.data, containsPair('id', 'u1'));
    expect(mentions.first.data, containsPair('label', 'Ada'));
    expect(mentions.first.data, containsPair('role', 'admin'));
    expect(mentions.last.data, containsPair('id', 'u2'));
    expect(mentions.last.data, containsPair('label', ''));

    final customRenderer = InlineEmbedRendererCallback((context, embed, style) {
      if (embed.embedType.trim() == 'mention') {
        return TextSpan(text: '#${embed.data['id']}', style: style);
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
            inlineEmbedRenderer: customRenderer,
          ),
        ),
      ),
    );

    expect(_richText('Hi #u1 and #u2'), findsOneWidget);
  });

  testWidgets('mention taps report details in mixed inline content',
      (tester) async {
    const renderedText = 'Hi @Ada + 😄 formula $_formulaPlaceholder then @Lin';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'mixed-mentions',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Hi '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{
                  'id': 'u-ada',
                  'label': 'Ada',
                  'team': 'core',
                },
              ),
              TextRun(text: ' + '),
              InlineEmbed(
                embedType: 'emoji',
                data: <String, Object?>{'emoji': '😄'},
              ),
              TextRun(text: ' formula '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2'},
              ),
              TextRun(text: ' then '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u-lin', 'label': 'Lin'},
              ),
            ],
          ),
        ],
      ),
    );
    final mentionTaps = <WenzMentionTapDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
            onMentionTap: mentionTaps.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final emojiStart = renderedText.indexOf('😄');
    final formulaStart = renderedText.indexOf(_formulaPlaceholder);
    final adaStart = renderedText.indexOf('@Ada');
    final linStart = renderedText.indexOf('@Lin');

    await _tapSingle(
      tester,
      _globalTextRangePoint(tester, renderedText, 0, 2, 0.5),
    );
    await _tapSingle(
      tester,
      _globalTextRangePoint(
        tester,
        renderedText,
        emojiStart,
        emojiStart + '😄'.length,
        0.5,
      ),
    );
    await _tapSingle(
      tester,
      _globalTextRangePoint(
        tester,
        renderedText,
        formulaStart,
        formulaStart + _formulaPlaceholder.length,
        0.5,
      ),
    );
    expect(mentionTaps, isEmpty);

    await _tapSingle(
      tester,
      _globalTextRangePoint(
        tester,
        renderedText,
        adaStart,
        adaStart + 4,
        0.75,
      ),
    );
    await _tapSingle(
      tester,
      _globalTextRangePoint(
        tester,
        renderedText,
        linStart,
        linStart + 4,
        0.75,
      ),
    );

    expect(mentionTaps, hasLength(2));
    expect(mentionTaps.first.id, 'u-ada');
    expect(mentionTaps.first.label, 'Ada');
    expect(mentionTaps.first.data, containsPair('team', 'core'));
    expect(mentionTaps.first.position.blockId, 'mixed-mentions');
    expect(mentionTaps.last.id, 'u-lin');
    expect(mentionTaps.last.label, 'Lin');
  });

  testWidgets('mention tap without callback keeps default selection only',
      (tester) async {
    const renderedText = 'No @Ada callback';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'mention-no-callback',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'No '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u-ada', 'label': 'Ada'},
              ),
              TextRun(text: ' callback'),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller, enableIme: false),
        ),
      ),
    );
    await tester.pump();

    final mentionStart = renderedText.indexOf('@Ada');
    await _tapSingle(
      tester,
      _globalTextRangePoint(
        tester,
        renderedText,
        mentionStart,
        mentionStart + 4,
        0.75,
      ),
    );

    expect(tester.takeException(), isNull);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'mention-no-callback',
      blockIndex: 0,
      baseOffset: 4,
      extentOffset: 4,
    );
  });

  testWidgets('rebuilds when controller document changes', (tester) async {
    final controller = WenzRichTextController(
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(_richText('Hi'), findsOneWidget);

    controller.insertText('!');
    await tester.pump();

    expect(_richText('Hi!'), findsOneWidget);
  });

  testWidgets('handles keyboard text, deletion, and enter', (tester) async {
    final controller = WenzRichTextController(
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();
    expect(controller.document.plainText, 'Hia');
    expect(_richTextIgnoringCaret('Hia'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.document.plainText, 'Hi');
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.document.blocks, hasLength(2));
    expect(controller.selection?.extent.blockIndex, 1);
  });

  testWidgets('keyboard enter at heading end starts a paragraph',
      (tester) async {
    const title = 'Heading title';
    final caret = DocumentPosition.text(
      blockId: 'h1',
      blockIndex: 0,
      offset: title.length,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2, anchor: 'heading-title'),
            content: <InlineNode>[TextRun(text: title)],
          ),
        ],
      ),
      selection: DocumentSelection(base: caret, extent: caret),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    final heading = controller.document.blocks[0] as TextBlockNode;
    final paragraph = controller.document.blocks[1] as TextBlockNode;
    expect(heading.type, BlockType.heading);
    expect(heading.plainText, title);
    expect(heading.attributes.level, 2);
    expect(heading.attributes.anchor, 'heading-title');
    expect(paragraph.type, BlockType.paragraph);
    expect(paragraph.plainText, isEmpty);
    expect(paragraph.attributes.level, isNull);
    expect(paragraph.attributes.anchor, isNull);
    expect(controller.selection?.extent.blockId, paragraph.id);
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('ctrl enter inserts an empty paragraph below the selection', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'One')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Two')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.document.blocks, hasLength(3));
    expect(controller.document.blocks[0].id, 'p1');
    expect(controller.document.blocks[2].id, 'p2');
    final inserted = controller.document.blocks[1] as TextBlockNode;
    expect(inserted.type, BlockType.paragraph);
    expect(inserted.plainText, isEmpty);
    expect(controller.selection?.extent.blockId, inserted.id);
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('ctrl shift enter inserts an empty paragraph above the selection',
      (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'One')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Two')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p2', 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.enter, shift: true);
    await tester.pump();

    expect(controller.document.blocks, hasLength(3));
    expect(controller.document.blocks[0].id, 'p1');
    expect(controller.document.blocks[2].id, 'p2');
    final inserted = controller.document.blocks[1] as TextBlockNode;
    expect(inserted.type, BlockType.paragraph);
    expect(inserted.plainText, isEmpty);
    expect(controller.selection?.extent.blockId, inserted.id);
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('keyboard text and backspace edit table cells', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Hi')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 2,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 2,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();

    var table = controller.document.blocks.single as TableBlockNode;
    var cellText = table.table.cellAt(0, 0)!.plainText;
    expect(cellText, 'Hia');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    table = controller.document.blocks.single as TableBlockNode;
    cellText = table.table.cellAt(0, 0)!.plainText;
    expect(cellText, 'Hi');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('enter inserts newline inside table cell', (tester) async {
    final position = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 1,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Hi')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(base: position, extent: position),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.plainText, 'H\ni');
    expect(controller.selection?.extent.path.isTableCellText, isTrue);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('table cell arrow keys and tab navigate cells', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p2',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BB')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
    expect(controller.selection?.extent.offset, 0);

    // Forward Tab on the last cell inserts a new row and lands the caret in
    // its first column (row 1, column 0).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 1);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);

    // Shift+Tab walks back to the previous (originally last) cell, with the
    // caret placed at its end.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 0);
    expect(controller.selection?.extent.path.tableColumnIndex, 1);
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('tab indents code blocks instead of navigating tables', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[CodeBlockNode(id: 'code1', code: 'aa\nbb')],
      ),
      selection: collapsedCodeSelection('code1', 0, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
        (controller.document.blocks.single as CodeBlockNode).code, 'aa\n  bb');
    expect(controller.selection?.extent.offset, 6);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect((controller.document.blocks.single as CodeBlockNode).code, 'aa\nbb');
    expect(controller.selection?.extent.offset, 4);
  });

  testWidgets('editor shortcut configuration overrides default dispatch', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
            shortcutConfiguration: const EditorShortcutConfiguration(
              bindings: <EditorShortcutBinding>[
                EditorShortcutBinding.handled(
                  shortcut: EditorShortcutKey(
                    LogicalKeyboardKey.keyL,
                    modifiers: <EditorShortcutModifier>{
                      EditorShortcutModifier.control,
                    },
                  ),
                  intent: EditorShortcutIntent.selectAll,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyL);
    await tester.pump();

    expect(controller.selection, textSelection('p1', 0, 0, 2));
  });

  testWidgets('selectAll shortcut configuration selects current code block', (
    tester,
  ) async {
    const code = 'one\ntwo';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Paragraph')],
          ),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
            shortcutConfiguration: const EditorShortcutConfiguration(
              bindings: <EditorShortcutBinding>[
                EditorShortcutBinding.handled(
                  shortcut: EditorShortcutKey(
                    LogicalKeyboardKey.keyL,
                    modifiers: <EditorShortcutModifier>{
                      EditorShortcutModifier.control,
                    },
                  ),
                  intent: EditorShortcutIntent.selectAll,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyL);
    await tester.pump();

    expect(controller.selection?.start.blockId, 'code1');
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'code1');
    expect(controller.selection?.end.offset, code.length);
  });

  testWidgets('updated shortcut configuration is used without controller swap',
      (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    Future<void> pumpWith(EditorShortcutConfiguration configuration) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
              shortcutConfiguration: configuration,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpWith(const EditorShortcutConfiguration());
    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyL);
    await tester.pump();
    expect(controller.selection, collapsedTextSelection('p1', 0, 0));

    await pumpWith(
      const EditorShortcutConfiguration(
        bindings: <EditorShortcutBinding>[
          EditorShortcutBinding.handled(
            shortcut: EditorShortcutKey(
              LogicalKeyboardKey.keyL,
              modifiers: <EditorShortcutModifier>{
                EditorShortcutModifier.control,
              },
            ),
            intent: EditorShortcutIntent.selectAll,
          ),
        ],
      ),
    );
    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyL);
    await tester.pump();

    expect(controller.selection, textSelection('p1', 0, 0, 2));
  });

  testWidgets('code block tab remains before shortcut configuration', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[CodeBlockNode(id: 'code1', code: 'aa')],
      ),
      selection: collapsedCodeSelection('code1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
            shortcutConfiguration: const EditorShortcutConfiguration(
              bindings: <EditorShortcutBinding>[
                EditorShortcutBinding.handled(
                  shortcut: EditorShortcutKey(LogicalKeyboardKey.tab),
                  intent: EditorShortcutIntent.selectAll,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect((controller.document.blocks.single as CodeBlockNode).code, '  aa');
    expect(controller.selection?.extent.path.isBlockCode, isTrue);
  });

  testWidgets('table cell arrow up/down navigate across rows', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell2',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p2',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BB')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      selection: DocumentSelection(
        base: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
        extent: DocumentPosition.tableCell(
          tableBlockId: 'table1',
          blockIndex: 0,
          tableRowIndex: 0,
          tableColumnIndex: 0,
          offset: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 1);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.selection?.extent.path.tableRowIndex, 0);
    expect(controller.selection?.extent.path.tableColumnIndex, 0);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('moves focused caret with arrow keys', (tester) async {
    final controller = WenzRichTextController(
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection?.extent.offset, 1);
    expect(_richTextIgnoringCaret('Hi'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 2);
  });

  testWidgets('arrow down crosses to the next paragraph block', (tester) async {
    // Two single-line paragraph blocks. ArrowDown from the end of p1 should
    // advance into p2 (the caret's last visual line == the block boundary).
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'first')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'second')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.selection?.extent.blockId, 'p2');
    expect(controller.selection?.extent.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // Up from the start of p2 returns to the end of p1.
    expect(controller.selection?.extent.blockId, 'p1');
    expect(controller.selection?.extent.offset, 5);
  });

  testWidgets('held arrow key (auto-repeat) moves the caret each repeat', (
    tester,
  ) async {
    // Holding a key down fires KeyDownEvent then repeated KeyRepeatEvents.
    // Each repeat must advance the caret, otherwise the view appears frozen
    // while a key is held.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Initial press.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 1);

    // Auto-repeat events while the key stays down.
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 2);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 3);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 3);
  });

  testWidgets('extends selection with shift and arrow keys', (tester) async {
    final controller = WenzRichTextController(
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.base.offset, 2);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('tap editable block places caret at block end', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hi')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'Hi', 2);
    await tester.pump();

    expect(controller.selection?.extent.blockId, 'p1');
    expect(controller.selection?.extent.offset, 2);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
  });

  testWidgets('tap image block selects the image object', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(_imageBlockFinder('image1')));
    await tester.pump();

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.isCollapsed, isFalse);
    expect(selection.start.blockId, 'image1');
    expect(selection.start.offset, 0);
    expect(selection.end.blockId, 'image1');
    expect(selection.end.offset, 1);
    expect(selection.extent.path.isBlockObject, isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
  });

  testWidgets('tap video block selects the video object', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            title: 'Launch clip',
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapSingle(tester, tester.getCenter(_videoBlockFinder('video1')));

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.isCollapsed, isFalse);
    expect(selection.start.blockId, 'video1');
    expect(selection.start.offset, 0);
    expect(selection.end.blockId, 'video1');
    expect(selection.end.offset, 1);
    expect(selection.extent.path.isBlockObject, isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
    expect(find.text('Launch clip'), findsNothing);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
  });

  testWidgets(
      'inline video resolver handles the first tap '
      'without replacing its player', (tester) async {
    final resolver = _TappableVideoResolver();
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            aspectRatio: 16 / 9,
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            mediaResolver: resolver,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final playerFinder = find.byKey(
      const ValueKey<String>('tappable-video-player-video1'),
    );
    expect(playerFinder, findsOneWidget);
    expect(resolver.tapCount, 0);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    await _tapSingle(tester, tester.getCenter(playerFinder));

    expect(resolver.tapCount, 1);
    expect(find.text('resolver instance:1 taps:1'), findsOneWidget);
    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.start.blockId, 'video1');
    expect(selection.end.blockId, 'video1');
    expect(selection.start.offset, 0);
    expect(selection.end.offset, 1);
    expect(selection.extent.path.isBlockObject, isTrue);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    // An already-selected player remains the same stateful instance and still
    // receives a mouse click directly.
    await _waitPastMultiClickWindow(tester);
    await _mouseClickAt(tester, tester.getCenter(playerFinder));
    expect(resolver.tapCount, 2);
    expect(find.text('resolver instance:1 taps:2'), findsOneWidget);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    // Shift+mouse remains an editor range-extension gesture. The resolver's
    // ordinary tap recognizer must not interpret it as another play command.
    controller.setSelection(collapsedTextSelection('p1', 0, 0));
    await tester.pump();
    await _shiftMouseClickAt(tester, tester.getCenter(playerFinder));

    expect(resolver.tapCount, 2);
    expect(controller.selection?.base.blockId, 'p1');
    expect(controller.selection?.extent.blockId, 'video1');
    expect(find.text('resolver instance:1 taps:2'), findsOneWidget);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    // The resolver's non-interactive background still selects the object. It
    // must not be mistaken for a player-control tap, and the explicit frame
    // scheduling in SelectionGestureOverlay makes this work even though the
    // child itself does not call setState.
    controller.setSelection(collapsedTextSelection('p2', 2, 0));
    await tester.pump();
    final surfaceRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('tappable-video-surface-video1'),
      ),
    );
    await _tapSingle(tester, surfaceRect.topLeft + const Offset(12, 12));

    expect(resolver.tapCount, 2);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.end.blockId, 'video1');
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.text('resolver instance:1 taps:2'), findsOneWidget);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);
  });

  testWidgets(
      'mobile video controls keep editor focus and text input disconnected',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resolver = _TappableVideoResolver();
    final focusNode = FocusNode();
    final initialSelection = collapsedTextSelection('p1', 0, 2);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            aspectRatio: 16 / 9,
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: initialSelection,
    );
    addTearDown(focusNode.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            focusNode: focusNode,
            mediaResolver: resolver,
          ),
        ),
      ),
    );
    await tester.pump();

    final playerFinder = find.byKey(
      const ValueKey<String>('tappable-video-player-video1'),
    );
    expect(playerFinder, findsOneWidget);
    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    await _tapSingle(tester, tester.getCenter(playerFinder));

    expect(resolver.tapCount, 1);
    expect(find.text('resolver instance:1 taps:1'), findsOneWidget);
    expect(controller.selection, initialSelection);
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    await _waitPastMultiClickWindow(tester);
    await _tapSingle(tester, tester.getCenter(playerFinder));

    expect(resolver.tapCount, 2);
    expect(find.text('resolver instance:1 taps:2'), findsOneWidget);
    expect(controller.selection, initialSelection);
    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    final surfaceRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('tappable-video-surface-video1'),
      ),
    );
    await _tapSingle(tester, surfaceRect.topLeft + const Offset(12, 12));

    expect(resolver.tapCount, 2);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.end.blockId, 'video1');
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(resolver.resolveCount, 1);
    expect(resolver.createCount, 1);
    expect(resolver.disposeCount, 0);

    await _tapSingle(tester, _globalTextOffset(tester, 'after', 2));

    expect(controller.selection?.extent.blockId, 'p2');
    expect(focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });

  testWidgets('media block drag handle aligns with image and video frame top',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 900,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final imageFrameRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-image-frame-image1'),
      ),
    );
    final imageHandleRect = tester.getRect(_blockDragHandleFinder('image1'));
    expect(
      imageHandleRect.top,
      moreOrLessEquals(imageFrameRect.top, epsilon: 0.75),
    );

    final videoFrameRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-video-frame-video1'),
      ),
    );
    final videoHandleRect = tester.getRect(_blockDragHandleFinder('video1'));
    expect(
      videoHandleRect.top,
      moreOrLessEquals(videoFrameRect.top, epsilon: 0.75),
    );
  });

  testWidgets('media toolbar preview opens image and video preview',
      (tester) async {
    tester.view.physicalSize = const Size(640, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );
    final resolver = _TestMediaResolver();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            mediaResolver: resolver,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(find.text('preview:image1'), findsNWidgets(2));
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await _tapSingle(tester, tester.getCenter(_videoBlockFinder('video1')));
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    final inlineFrame = find.byKey(
      const ValueKey<String>('wenz-richtext-video-frame-video1'),
    );
    expect(
      find.descendant(of: inlineFrame, matching: find.byType(ClipRRect)),
      findsWidgets,
    );
    final inlineDecoration =
        tester.widget<DecoratedBox>(inlineFrame).decoration as BoxDecoration;
    expect(inlineDecoration.borderRadius, isNotNull);
    expect(inlineDecoration.boxShadow, isNotEmpty);
    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(find.text('preview:video1'), findsNWidgets(2));
    expect(find.byType(Dialog), findsNothing);

    final surface = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-video-fullscreen-surface-video1',
      ),
    );
    final viewport = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-video-fullscreen-viewport-video1',
      ),
    );
    final frame = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-video-fullscreen-frame-video1',
      ),
    );
    expect(tester.getRect(surface), const Rect.fromLTWH(0, 0, 640, 960));
    expect(tester.getRect(viewport), const Rect.fromLTWH(0, 0, 640, 960));
    expect(
      find.descendant(of: surface, matching: find.byType(ClipRRect)),
      findsNothing,
    );
    final frameRect = tester.getRect(frame);
    expect(frameRect.width.isFinite, isTrue);
    expect(frameRect.height.isFinite, isTrue);
    expect(frameRect, const Rect.fromLTWH(0, 0, 640, 960));
    expect(find.byTooltip('关闭视频预览'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  testWidgets(
      'selected video toolbar renders in overlay without shifting video layout',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before video paragraph')],
          ),
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            aspectRatio: 16 / 9,
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After video paragraph')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.all(8),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final videoBlockFinder = _videoBlockFinder('video1');
    final videoFrameFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-video-frame-video1'),
    );
    final afterTextFinder = _richText('After video paragraph');
    final initialBlockRect = tester.getRect(videoBlockFinder);
    final initialFrameRect = tester.getRect(videoFrameFinder);
    final initialAfterRect = tester.getRect(afterTextFinder);
    expect(find.byTooltip('预览媒体'), findsNothing);

    controller.setSelection(objectBlockSelection('video1', 1));
    await tester.pump();
    await tester.pump();

    _expectRectClose(tester.getRect(videoBlockFinder), initialBlockRect);
    _expectRectClose(tester.getRect(videoFrameFinder), initialFrameRect);
    _expectRectClose(tester.getRect(afterTextFinder), initialAfterRect);

    final previewFinder = find.byTooltip('预览媒体');
    final moreFinder = find.byTooltip('更多块操作');
    expect(previewFinder, findsOneWidget);
    expect(moreFinder, findsOneWidget);
    expect(
      find.descendant(of: videoBlockFinder, matching: previewFinder),
      findsNothing,
      reason: 'The selected video toolbar must not be a video block child.',
    );
    expect(
      find.ancestor(of: previewFinder, matching: find.byType(Overlay)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: previewFinder, matching: find.byType(OverlayPortal)),
      findsOneWidget,
    );

    final toolbarRect = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );
    _expectToolbarAboveBody(toolbarRect, initialFrameRect);
    _expectToolbarAlignedToFrameEnd(toolbarRect, initialFrameRect);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    expect(toolbarRect.left, greaterThanOrEqualTo(editorRect.left));
    expect(toolbarRect.right, lessThanOrEqualTo(editorRect.right));

    final blockerRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('object-block-toolbar-hit-test-blocker'),
      ),
    );
    expect(blockerRect.left, lessThanOrEqualTo(toolbarRect.left));
    expect(blockerRect.top, lessThanOrEqualTo(toolbarRect.top));
    expect(blockerRect.right, greaterThanOrEqualTo(toolbarRect.right));
    expect(blockerRect.bottom, greaterThanOrEqualTo(toolbarRect.bottom));
    expect(blockerRect.width, lessThan(initialFrameRect.width));
    expect(blockerRect.height, lessThan(64));
  });

  testWidgets(
      'video overlay toolbar actions work without changing object selection',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
      selection: objectBlockSelection('video1', 0),
    );
    var selectionChanges = 0;
    controller.onSelectionChanged = (_) {
      selectionChanges++;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            mediaResolver: _TestMediaResolver(),
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(find.text('preview:video1'), findsNWidgets(2));
    expect(selectionChanges, 0);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);

    Navigator.of(
      tester.element(
        find.byKey(
          const ValueKey<String>(
            'wenz-richtext-video-fullscreen-surface-video1',
          ),
        ),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    expect(_popupMenuItemFinder('创建块副本'), findsOneWidget);
    expect(_popupMenuItemFinder('删除块'), findsOneWidget);
    expect(selectionChanges, 0);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
  });

  testWidgets(
      'video fullscreen handoff is non-reentrant and restores toolbar after back',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
      selection: objectBlockSelection('video1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            mediaResolver: _TestMediaResolver(),
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final previewButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.open_in_full),
    );
    final openPreview = previewButton.onPressed!;
    openPreview();
    openPreview();
    await tester.pump();
    expect(find.byTooltip('预览媒体'), findsNothing);

    await tester.pumpAndSettle();
    final surface = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-video-fullscreen-surface-video1',
      ),
    );
    expect(surface, findsOneWidget);
    expect(find.text('preview:video1'), findsNWidgets(2));
    expect(find.byTooltip('预览媒体'), findsNothing);

    // A retained callback cannot stack a second route while the first route is
    // active or beginning its exit transition.
    openPreview();
    await tester.pump();
    expect(surface, findsOneWidget);
    expect(find.text('preview:video1'), findsNWidgets(2));

    await tester.binding.handlePopRoute();
    openPreview();
    await tester.pump();
    expect(surface, findsOneWidget);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(controller.selection, objectBlockSelection('video1', 0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap opens the same guarded video fullscreen route',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            mediaResolver: _TestMediaResolver(),
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final target = tester.getCenter(_videoBlockFinder('video1'));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-video1',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('preview:video1'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-video-fullscreen-surface-video1',
        ),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'fullscreen exit does not restore toolbar after source deletion or replacement',
      (tester) async {
    final firstController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
      selection: objectBlockSelection('video1', 0),
    );
    final secondController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'replacement',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Replacement editor')],
          ),
        ],
      ),
      selection: collapsedTextSelection('replacement', 0, 0),
    );
    final activeController = ValueNotifier<WenzRichTextController>(
      firstController,
    );
    addTearDown(activeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<WenzRichTextController>(
            valueListenable: activeController,
            builder: (context, controller, _) {
              return WenzRichTextEditor(
                controller: controller,
                mediaResolver: _TestMediaResolver(),
                enableIme: false,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    final surface = find.byKey(
      const ValueKey<String>(
        'wenz-richtext-video-fullscreen-surface-video1',
      ),
    );
    expect(surface, findsOneWidget);

    activeController.value = secondController;
    await tester.pump();
    Navigator.of(tester.element(surface)).pop();
    await tester.pumpAndSettle();

    expect(surface, findsNothing);
    expect(find.text('Replacement editor'), findsOneWidget);
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(secondController.selection?.start.blockId, 'replacement');
    expect(tester.takeException(), isNull);

    // Rebuild the original source, then remove its block while fullscreen is
    // active. The old handoff must not resurrect the removed anchor on pop.
    activeController.value = firstController;
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(surface, findsOneWidget);

    firstController.deleteVideoBlock(blockIndex: 0);
    await tester.pump();
    Navigator.of(tester.element(surface)).pop();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(_videoBlockFinder('video1'), findsNothing);
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'video overlay toolbar disappears when selection changes or block is deleted',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before')],
          ),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After')],
          ),
        ],
      ),
      selection: objectBlockSelection('video1', 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);

    controller.setSelection(null);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);

    controller.setSelection(objectBlockSelection('video1', 1));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('预览媒体'), findsOneWidget);

    controller.setSelection(collapsedTextSelection('after', 2, 0));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);

    controller.setSelection(objectBlockSelection('video1', 1));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('预览媒体'), findsOneWidget);

    controller.deleteVideoBlock(blockIndex: 1);
    await tester.pump();
    await tester.pump();
    expect(_videoBlockFinder('video1'), findsNothing);
    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);
  });

  testWidgets('image block toolbar follows the image while scrolling',
      (tester) async {
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < 6; i++)
            TextBlockNode(
              id: 'before-img-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Before image $i')],
            ),
          const ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          for (var i = 0; i < 8; i++)
            TextBlockNode(
              id: 'after-img-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'After image $i')],
            ),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 32,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFrame = find.byKey(
      const ValueKey<String>('wenz-richtext-image-frame-image1'),
    );
    expect(imageFrame, findsOneWidget);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);

    final toolbarBefore = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );
    final imageRectBefore = tester.getRect(imageFrame);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );
    final maxExtent = scrollable.position.maxScrollExtent;
    expect(maxExtent, greaterThan(100));

    scrollable.position.jumpTo(
      (scrollable.position.pixels + 60).clamp(0.0, maxExtent),
    );
    await tester.pump();
    await tester.pump();

    final imageRectAfter = tester.getRect(imageFrame);
    final toolbarAfter = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );

    expect(imageRectAfter.top, lessThan(imageRectBefore.top));
    expect(toolbarAfter.top, lessThan(toolbarBefore.top));
    _expectToolbarAboveBody(toolbarAfter, imageRectAfter);
  });

  testWidgets('video block toolbar follows the video while scrolling',
      (tester) async {
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < 6; i++)
            TextBlockNode(
              id: 'before-vid-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Before video $i')],
            ),
          const VideoBlockNode(id: 'video1', assetId: 'clip'),
          for (var i = 0; i < 8; i++)
            TextBlockNode(
              id: 'after-vid-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'After video $i')],
            ),
        ],
      ),
      selection: objectBlockSelection('video1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 260,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 32,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final videoFrame = find.byKey(
      const ValueKey<String>('wenz-richtext-video-frame-video1'),
    );
    expect(videoFrame, findsOneWidget);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);

    final toolbarBefore = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );
    final videoRectBefore = tester.getRect(videoFrame);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );
    final maxExtent = scrollable.position.maxScrollExtent;
    expect(maxExtent, greaterThan(100));

    scrollable.position.jumpTo(
      (scrollable.position.pixels + 60).clamp(0.0, maxExtent),
    );
    await tester.pump();
    await tester.pump();

    final videoRectAfter = tester.getRect(videoFrame);
    final toolbarAfter = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );

    expect(videoRectAfter.top, lessThan(videoRectBefore.top));
    expect(toolbarAfter.top, lessThan(toolbarBefore.top));
    _expectToolbarAboveBody(toolbarAfter, videoRectAfter);
  });

  testWidgets(
      'object block toolbar follows partial scroll and hides outside viewport',
      (tester) async {
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < 3; i++)
            TextBlockNode(
              id: 'top-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Top paragraph $i')],
            ),
          const ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          for (var i = 0; i < 8; i++)
            TextBlockNode(
              id: 'bottom-$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Bottom paragraph $i')],
            ),
        ],
      ),
      selection: objectBlockSelection('image1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 960,
            height: 300,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.only(
                left: 16,
                top: 32,
                right: 16,
                bottom: 16,
              ),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFrame = find.byKey(
      const ValueKey<String>('wenz-richtext-image-frame-image1'),
    );
    expect(imageFrame, findsOneWidget);
    expect(find.byTooltip('预览媒体'), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(WenzRichTextEditor),
        matching: find.byType(Scrollable),
      ),
    );
    final maxExtent = scrollable.position.maxScrollExtent;
    expect(maxExtent, greaterThan(50));

    // Scroll just enough that the image is partially visible near the top of
    // the viewport; the toolbar must stay above the image frame.
    scrollable.position.jumpTo(
      (scrollable.position.pixels + 30).clamp(0.0, maxExtent),
    );
    await tester.pump();
    await tester.pump();

    final imageRect = tester.getRect(imageFrame);
    final toolbarRect = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );

    _expectToolbarAboveBody(toolbarRect, imageRect);
    // Toolbar must not render above the overlay coordinate origin.
    expect(toolbarRect.top, greaterThanOrEqualTo(-0.1));
    expect(tester.takeException(), isNull);

    scrollable.position.jumpTo(maxExtent);
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('预览媒体'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsNothing);

    scrollable.position.jumpTo(0);
    await tester.pump();
    await tester.pump();

    expect(imageFrame, findsOneWidget);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
  });

  testWidgets('video block keeps placeholder chrome inside a narrow card',
      (tester) async {
    const source =
        'https://cdn.example.test/videos/super-wide-launch-video.mp4';
    const cover = 'assets/poster-with-a-very-long-file-name-for-video.jpg';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            playbackUrl: source,
            coverUrl: cover,
            title: 'Narrow video',
            description: 'Long description that should stay inside the card.',
            aspectRatio: 9 / 16,
            uploadStatus: FileUploadStatus.failed,
            uploadError: 'network timeout while uploading a very tall clip',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 280,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.all(8),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final blockRect = tester.getRect(_videoBlockFinder('video1'));
    final frameRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-video-frame-video1'),
    ));
    expect(frameRect.left, greaterThanOrEqualTo(blockRect.left));
    expect(frameRect.right, lessThanOrEqualTo(blockRect.right));

    final coverRect = tester.getRect(
      find.text('Cover: poster-with-a-very-long-file-name-for-video.jpg'),
    );
    final sourceRect = tester.getRect(find.text('[video: $source]'));
    expect(coverRect.left, greaterThanOrEqualTo(frameRect.left));
    expect(coverRect.right, lessThanOrEqualTo(frameRect.right));
    expect(sourceRect.left, greaterThanOrEqualTo(frameRect.left));
    expect(sourceRect.right, lessThanOrEqualTo(frameRect.right));

    await _tapSingle(tester, tester.getCenter(_videoBlockFinder('video1')));

    expect(tester.takeException(), isNull);
    expect(find.text('Narrow video'), findsNothing);
    expect(find.text('Long description that should stay inside the card.'),
        findsNothing);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
  });

  testWidgets('video block constrains oversized resolver child',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(
            id: 'video1',
            assetId: 'clip',
            playbackUrl:
                'https://cdn.example.test/videos/very-long-custom-player-source.mp4',
            coverUrl: 'assets/poster-with-a-very-long-custom-player-name.jpg',
            title: 'Custom resolver video with a long title',
            description: 'Custom renderer should stay inside the video frame.',
            aspectRatio: 9 / 16,
            uploadStatus: FileUploadStatus.failed,
            uploadError: 'transcode failed after upload',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 190,
            height: 280,
            child: WenzRichTextEditor(
              controller: controller,
              mediaResolver: const _OversizedVideoResolver(),
              padding: const EdgeInsets.all(8),
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final blockRect = tester.getRect(_videoBlockFinder('video1'));
    final frameRect = tester.getRect(find.byKey(
      const ValueKey<String>('wenz-richtext-video-frame-video1'),
    ));
    expect(
        find.byKey(
          const ValueKey<String>('oversized-video-player-video1'),
        ),
        findsOneWidget);
    expect(frameRect.left, greaterThanOrEqualTo(blockRect.left));
    expect(frameRect.top, greaterThanOrEqualTo(blockRect.top));
    expect(frameRect.right, lessThanOrEqualTo(blockRect.right));
    expect(frameRect.bottom, lessThanOrEqualTo(blockRect.bottom));

    await _tapSingle(tester, tester.getCenter(_videoBlockFinder('video1')));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
  });

  testWidgets('video block shows non-editing cursor like the file block',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p0',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Editable paragraph text')],
          ),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          FileBlockNode(id: 'file1', assetId: 'file-1', name: 'brief.pdf'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // A plain editable text block keeps the text (I-beam) cursor, confirming
    // the change is scoped to the video block and did not affect text areas.
    final textCursor = _resolvedMouseCursor(
      tester,
      tester.getCenter(_richText('Editable paragraph text')),
    );
    expect(textCursor, SystemMouseCursors.text);

    // The video block resolves to the non-editing click cursor (matching the
    // file attachment card), not the text I-beam.
    final videoCursor = _resolvedMouseCursor(
      tester,
      tester.getCenter(_videoBlockFinder('video1')),
    );
    expect(videoCursor, isNot(SystemMouseCursors.text));
    expect(videoCursor, SystemMouseCursors.click);

    // The file attachment card resolves to the same non-editing click cursor.
    final fileCursor = _resolvedMouseCursor(
      tester,
      tester.getCenter(
        find.byKey(const ValueKey<String>('wenz-richtext-file-card-file1')),
      ),
    );
    expect(fileCursor, SystemMouseCursors.click);
    expect(fileCursor, videoCursor);
  });

  group('media block display states', () {
    testWidgets(
        'image caption metadata stays hidden while altText labels the frame',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'image1',
              assetId: 'hero',
              file: 'hero.png',
              caption: 'A scenic view',
              altText: 'Scenery alt',
              showWidth: 220,
              showHeight: 120,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              mediaResolver: _EmptyMediaResolver(),
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('A scenic view'), findsNothing);
      final image = controller.document.blocks.single as ImageBlockNode;
      expect(image.caption, 'A scenic view');
      expect(image.altText, 'Scenery alt');

      final frameRect = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-image1')),
      );
      final sizeRect = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-size-image1')),
      );
      _expectRectClose(sizeRect, frameRect, epsilon: 0.75);

      // altText surfaces as the frame's accessible label via Semantics.
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Scenery alt'), findsWidgets);
      semantics.dispose();
    });

    testWidgets(
        'image caption metadata is hidden and does not add block height',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'plain',
              assetId: 'a',
              file: 'a.png',
              showWidth: 200,
              showHeight: 120,
            ),
            ImageBlockNode(
              id: 'captioned',
              assetId: 'b',
              file: 'b.png',
              caption: 'With a caption',
              showWidth: 200,
              showHeight: 120,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );

      expect(find.text('With a caption'), findsNothing);
      final captionedImage = controller.document.blocks
          .whereType<ImageBlockNode>()
          .singleWhere((image) => image.id == 'captioned');
      expect(captionedImage.caption, 'With a caption');

      final plainFrameRect = tester.getRect(
        find.byKey(const ValueKey<String>('wenz-richtext-image-frame-plain')),
      );
      final captionedFrameRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-image-frame-captioned'),
        ),
      );
      expect(
        captionedFrameRect.height,
        moreOrLessEquals(plainFrameRect.height, epsilon: 0.75),
      );
      expect(
        captionedFrameRect.width,
        moreOrLessEquals(plainFrameRect.width, epsilon: 0.75),
      );

      final plainRect = tester.getRect(_imageBlockFinder('plain'));
      final captionedRect = tester.getRect(_imageBlockFinder('captioned'));
      expect(
        captionedRect.height,
        moreOrLessEquals(plainRect.height, epsilon: 0.75),
      );
    });

    testWidgets(
        'image default frame uses intrinsic ratio before placeholder fallback',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'memory-sized',
              assetId: 'memory-sized',
              file: 'memory-sized.png',
              width: 320,
              height: 80,
            ),
            ImageBlockNode(
              id: 'legacy-unsized',
              assetId: 'legacy-unsized',
              file: 'legacy-unsized.png',
            ),
          ],
        ),
      );

      await _pumpFixedWidthImageEditor(
        tester,
        controller,
        mediaResolver: _EmptyMediaResolver(),
      );

      final sizedFrame = _imageFrameRect(tester, 'memory-sized');
      expect(sizedFrame.width, moreOrLessEquals(320, epsilon: 0.75));
      expect(sizedFrame.height, moreOrLessEquals(80, epsilon: 0.75));
      expect(
        sizedFrame.width / sizedFrame.height,
        moreOrLessEquals(4, epsilon: 0.05),
      );

      final legacyFrame = _imageFrameRect(tester, 'legacy-unsized');
      expect(
        legacyFrame.height,
        moreOrLessEquals(legacyFrame.width / 2, epsilon: 1),
      );
    });

    testWidgets('image alignment positions placeholder frames in fixed width',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'default',
              assetId: 'default',
              file: 'default.png',
              showWidth: 160,
              showHeight: 80,
            ),
            ImageBlockNode(
              id: 'left',
              assetId: 'left',
              file: 'left.png',
              caption: 'Left caption',
              showWidth: 160,
              showHeight: 80,
              attributes: BlockAttributes(alignment: 'left'),
            ),
            ImageBlockNode(
              id: 'center',
              assetId: 'center',
              file: 'center.png',
              showWidth: 160,
              showHeight: 80,
              attributes: BlockAttributes(alignment: 'center'),
            ),
            ImageBlockNode(
              id: 'right',
              assetId: 'right',
              file: 'right.png',
              showWidth: 160,
              showHeight: 80,
              attributes: BlockAttributes(alignment: 'right'),
            ),
          ],
        ),
      );

      await _pumpFixedWidthImageEditor(tester, controller);

      _expectImageFrameHorizontalAlignment(tester, 'default', null);
      _expectImageFrameHorizontalAlignment(tester, 'left', 'left');
      _expectImageFrameHorizontalAlignment(tester, 'center', 'center');
      _expectImageFrameHorizontalAlignment(tester, 'right', 'right');
      expect(find.text('Left caption'), findsNothing);
      final leftImage = controller.document.blocks
          .whereType<ImageBlockNode>()
          .singleWhere((image) => image.id == 'left');
      expect(leftImage.caption, 'Left caption');
      expect(find.text('preview:left'), findsNothing);
    });

    testWidgets('video alignment positions placeholder frames in fixed width',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'default',
              assetId: 'default',
              showWidth: 160,
              showHeight: 90,
            ),
            VideoBlockNode(
              id: 'left',
              assetId: 'left',
              showWidth: 160,
              showHeight: 90,
              attributes: BlockAttributes(alignment: 'left'),
            ),
            VideoBlockNode(
              id: 'center',
              assetId: 'center',
              showWidth: 160,
              showHeight: 90,
              attributes: BlockAttributes(alignment: 'center'),
            ),
            VideoBlockNode(
              id: 'right',
              assetId: 'right',
              showWidth: 160,
              showHeight: 90,
              attributes: BlockAttributes(alignment: 'right'),
            ),
          ],
        ),
      );

      await _pumpFixedWidthImageEditor(tester, controller);

      _expectVideoFrameHorizontalAlignment(tester, 'default', null);
      _expectVideoFrameHorizontalAlignment(tester, 'left', 'left');
      _expectVideoFrameHorizontalAlignment(tester, 'center', 'center');
      _expectVideoFrameHorizontalAlignment(tester, 'right', 'right');
      expect(find.text('[video: left]'), findsOneWidget);
      expect(find.text('[video: center]'), findsOneWidget);
      expect(find.text('[video: right]'), findsOneWidget);
    });

    testWidgets(
        'image object menu sets clears alignment and preserves image metadata',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'image1',
              assetId: 'hero',
              file: 'hero.png',
              caption: 'Caption',
              altText: 'Alt text',
              width: 640,
              height: 320,
              showWidth: 160,
              showHeight: 80,
            ),
          ],
        ),
        selection: objectBlockSelection('image1', 0),
      );

      ImageBlockNode currentImage() =>
          controller.document.blocks.single as ImageBlockNode;

      void expectImageState(String? alignment) {
        final image = currentImage();
        expect(image.attributes.alignment, alignment);
        expect(image.assetId, 'hero');
        expect(image.file, 'hero.png');
        expect(image.caption, 'Caption');
        expect(image.altText, 'Alt text');
        expect(image.width, 640);
        expect(image.height, 320);
        expect(image.showWidth, 160);
        expect(image.showHeight, 80);
      }

      Future<void> openImageMenu() async {
        await tester.tap(find.byTooltip('更多块操作'));
        await tester.pumpAndSettle();
      }

      await _pumpFixedWidthImageEditor(tester, controller);
      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(find.byTooltip('更多块操作'), findsOneWidget);
      _expectImageFrameHorizontalAlignment(tester, 'image1', null);
      expect(find.text('Caption'), findsNothing);

      await openImageMenu();
      for (final label in const <String>[
        '图片左对齐',
        '图片居中',
        '图片右对齐',
        '清除图片对齐',
        '图片宽度：小',
        '图片宽度：中',
        '图片宽度：大',
        '重置图片尺寸',
      ]) {
        expect(_popupMenuItemFinder(label), findsOneWidget);
      }
      expect(_popupMenuItem(tester, '清除图片对齐').enabled, isFalse);
      await tester.tap(_popupMenuItemFinder('图片左对齐'));
      await tester.pumpAndSettle();

      expectImageState('left');
      _expectImageFrameHorizontalAlignment(tester, 'image1', 'left');

      await openImageMenu();
      expect(_popupMenuItem(tester, '图片左对齐').enabled, isFalse);
      expect(_popupMenuItem(tester, '清除图片对齐').enabled, isTrue);
      await tester.tap(_popupMenuItemFinder('图片居中'));
      await tester.pumpAndSettle();

      expectImageState('center');
      _expectImageFrameHorizontalAlignment(tester, 'image1', 'center');

      await openImageMenu();
      expect(_popupMenuItem(tester, '图片居中').enabled, isFalse);
      await tester.tap(_popupMenuItemFinder('图片右对齐'));
      await tester.pumpAndSettle();

      expectImageState('right');
      _expectImageFrameHorizontalAlignment(tester, 'image1', 'right');

      await openImageMenu();
      expect(_popupMenuItem(tester, '图片右对齐').enabled, isFalse);
      expect(_popupMenuItem(tester, '清除图片对齐').enabled, isTrue);
      await tester.tap(_popupMenuItemFinder('清除图片对齐'));
      await tester.pumpAndSettle();

      expectImageState(null);
      _expectImageFrameHorizontalAlignment(tester, 'image1', null);
      expect(find.text('Caption'), findsNothing);
    });

    testWidgets(
        'video object menu sets size alignment and preserves video metadata',
        (tester) async {
      final selection = objectBlockSelection('video1', 0);
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            VideoBlockNode(
              id: 'video1',
              assetId: 'clip',
              playbackUrl: 'https://cdn.example.test/clip.mp4',
              coverUrl: 'poster.jpg',
              title: 'Clip title',
              description: 'Clip description',
              aspectRatio: 16 / 9,
              showWidth: 160,
              showHeight: 90,
              uploadStatus: FileUploadStatus.uploaded,
            ),
          ],
        ),
        selection: selection,
      );

      VideoBlockNode currentVideo() =>
          controller.document.blocks.single as VideoBlockNode;

      void expectVideoMetadata(String? alignment) {
        final video = currentVideo();
        expect(video.attributes.alignment, alignment);
        expect(video.assetId, 'clip');
        expect(video.playbackUrl, 'https://cdn.example.test/clip.mp4');
        expect(video.coverUrl, 'poster.jpg');
        expect(video.title, 'Clip title');
        expect(video.description, 'Clip description');
        expect(video.aspectRatio, 16 / 9);
        expect(video.uploadStatus, FileUploadStatus.uploaded);
        expect(controller.selection, selection);
      }

      Future<void> openVideoMenu() async {
        await tester.tap(find.byTooltip('更多块操作'));
        await tester.pumpAndSettle();
      }

      await _pumpFixedWidthImageEditor(tester, controller);
      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(find.byTooltip('更多块操作'), findsOneWidget);
      _expectVideoFrameHorizontalAlignment(tester, 'video1', null);

      await openVideoMenu();
      for (final label in const <String>[
        '视频左对齐',
        '视频居中',
        '视频右对齐',
        '清除视频对齐',
        '视频宽度：小',
        '视频宽度：中',
        '视频宽度：大',
        '重置视频尺寸',
      ]) {
        expect(_popupMenuItemFinder(label), findsOneWidget);
      }
      expect(_popupMenuItem(tester, '清除视频对齐').enabled, isFalse);
      await tester.tap(_popupMenuItemFinder('视频左对齐'));
      await tester.pumpAndSettle();

      expectVideoMetadata('left');
      expect(currentVideo().showWidth, 160);
      expect(currentVideo().showHeight, 90);
      _expectVideoFrameHorizontalAlignment(tester, 'video1', 'left');

      await openVideoMenu();
      expect(_popupMenuItem(tester, '视频左对齐').enabled, isFalse);
      expect(_popupMenuItem(tester, '清除视频对齐').enabled, isTrue);
      await tester.tap(_popupMenuItemFinder('视频居中'));
      await tester.pumpAndSettle();

      expectVideoMetadata('center');
      _expectVideoFrameHorizontalAlignment(tester, 'video1', 'center');

      await openVideoMenu();
      expect(_popupMenuItem(tester, '视频居中').enabled, isFalse);
      await tester.tap(_popupMenuItemFinder('视频右对齐'));
      await tester.pumpAndSettle();

      expectVideoMetadata('right');
      _expectVideoFrameHorizontalAlignment(tester, 'video1', 'right');

      await openVideoMenu();
      expect(_popupMenuItem(tester, '视频右对齐').enabled, isFalse);
      await tester.tap(_popupMenuItemFinder('清除视频对齐'));
      await tester.pumpAndSettle();

      expectVideoMetadata(null);
      _expectVideoFrameHorizontalAlignment(tester, 'video1', null);

      await openVideoMenu();
      await tester.tap(_popupMenuItemFinder('视频宽度：小'));
      await tester.pumpAndSettle();

      expectVideoMetadata(null);
      expect(currentVideo().showWidth, moreOrLessEquals(240, epsilon: 0.75));
      expect(currentVideo().showHeight, moreOrLessEquals(135, epsilon: 0.75));
      _expectVideoFrameSize(tester, 'video1', 240, 135);

      await openVideoMenu();
      await tester.tap(_popupMenuItemFinder('视频宽度：中'));
      await tester.pumpAndSettle();

      expectVideoMetadata(null);
      expect(currentVideo().showWidth, moreOrLessEquals(360, epsilon: 0.75));
      expect(
        currentVideo().showHeight,
        moreOrLessEquals(202.5, epsilon: 0.75),
      );
      _expectVideoFrameSize(tester, 'video1', 360, 202.5);

      await openVideoMenu();
      await tester.tap(_popupMenuItemFinder('视频宽度：大'));
      await tester.pumpAndSettle();

      expectVideoMetadata(null);
      expect(currentVideo().showWidth, greaterThanOrEqualTo(360));
      expect(currentVideo().showWidth, lessThanOrEqualTo(520));
      expect(
        currentVideo().showHeight,
        moreOrLessEquals(currentVideo().showWidth! / (16 / 9), epsilon: 0.75),
      );

      await openVideoMenu();
      await tester.tap(_popupMenuItemFinder('重置视频尺寸'));
      await tester.pumpAndSettle();

      expectVideoMetadata(null);
      expect(currentVideo().showWidth, isNull);
      expect(currentVideo().showHeight, isNull);
    });

    testWidgets(
        'image alignment object menu is unavailable without edit access',
        (tester) async {
      Future<WenzRichTextController> pumpImageEditor({
        required String blockId,
        required bool readOnly,
        WenzEditorPermission permission = WenzEditorPermission.edit,
      }) async {
        final controller = WenzRichTextController(
          document: RichTextDocument(
            blocks: <BlockNode>[
              ImageBlockNode(
                id: blockId,
                assetId: 'hero',
                file: 'hero.png',
                caption: 'Caption',
                showWidth: 160,
                showHeight: 80,
                attributes: const BlockAttributes(alignment: 'right'),
              ),
            ],
          ),
          permission: permission,
          selection: objectBlockSelection(blockId, 0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                readOnly: readOnly,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
        return controller;
      }

      void expectUnchanged(WenzRichTextController controller) {
        final image = controller.document.blocks.single as ImageBlockNode;
        expect(image.attributes.alignment, 'right');
        expect(image.showWidth, 160);
        expect(image.showHeight, 80);
        expect(image.caption, 'Caption');
        expect(image.assetId, 'hero');
        expect(image.file, 'hero.png');
        expect(controller.canUndo, isFalse);
        expect(find.byTooltip('更多块操作'), findsNothing);
        expect(_popupMenuItemFinder('图片左对齐'), findsNothing);
        expect(_popupMenuItemFinder('清除图片对齐'), findsNothing);
      }

      final readOnlyController = await pumpImageEditor(
        blockId: 'readonly-image',
        readOnly: true,
      );
      expectUnchanged(readOnlyController);

      final readPermissionController = await pumpImageEditor(
        blockId: 'read-permission-image',
        readOnly: false,
        permission: WenzEditorPermission.read,
      );
      expectUnchanged(readPermissionController);
    });

    testWidgets(
        'video alignment object menu is unavailable without edit access',
        (tester) async {
      Future<WenzRichTextController> pumpVideoEditor({
        required String blockId,
        required bool readOnly,
        WenzEditorPermission permission = WenzEditorPermission.edit,
      }) async {
        final controller = WenzRichTextController(
          document: RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(
                id: blockId,
                assetId: 'clip',
                title: 'Clip title',
                showWidth: 160,
                showHeight: 90,
                attributes: const BlockAttributes(alignment: 'right'),
              ),
            ],
          ),
          permission: permission,
          selection: objectBlockSelection(blockId, 0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                readOnly: readOnly,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
        return controller;
      }

      void expectUnchanged(WenzRichTextController controller) {
        final video = controller.document.blocks.single as VideoBlockNode;
        expect(video.attributes.alignment, 'right');
        expect(video.showWidth, 160);
        expect(video.showHeight, 90);
        expect(video.title, 'Clip title');
        expect(video.assetId, 'clip');
        expect(controller.canUndo, isFalse);
        expect(find.byTooltip('更多块操作'), findsNothing);
        expect(_popupMenuItemFinder('视频左对齐'), findsNothing);
        expect(_popupMenuItemFinder('清除视频对齐'), findsNothing);
      }

      final readOnlyController = await pumpVideoEditor(
        blockId: 'readonly-video',
        readOnly: true,
      );
      expectUnchanged(readOnlyController);

      final readPermissionController = await pumpVideoEditor(
        blockId: 'read-permission-video',
        readOnly: false,
        permission: WenzEditorPermission.read,
      );
      expectUnchanged(readPermissionController);
    });

    testWidgets(
        'selected aligned image keeps height and moves toolbar with frame changes',
        (tester) async {
      const strokeKey =
          ValueKey<String>('wenz-richtext-media-selection-stroke');
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'image1',
              assetId: 'hero',
              file: 'hero.png',
              caption: 'Resolver caption',
              showWidth: 160,
              showHeight: 80,
              attributes: BlockAttributes(alignment: 'right'),
            ),
          ],
        ),
      );

      await _pumpFixedWidthImageEditor(
        tester,
        controller,
        mediaResolver: _TestMediaResolver(),
      );

      expect(find.text('preview:image1'), findsOneWidget);
      _expectImageFrameHorizontalAlignment(tester, 'image1', 'right');
      expect(find.text('Resolver caption'), findsNothing);
      expect(
        (controller.document.blocks.single as ImageBlockNode).caption,
        'Resolver caption',
      );
      final unselectedBlockRect = tester.getRect(_imageBlockFinder('image1'));
      final unselectedFrameRect = _imageFrameRect(tester, 'image1');

      controller.setSelection(objectBlockSelection('image1', 0));
      await tester.pump();
      await tester.pump();

      final selectedBlockRect = tester.getRect(_imageBlockFinder('image1'));
      expect(
        selectedBlockRect.height,
        moreOrLessEquals(unselectedBlockRect.height, epsilon: 0.75),
      );
      final selectedFrameRect = _imageFrameRect(tester, 'image1');
      _expectRectClose(selectedFrameRect, unselectedFrameRect, epsilon: 0.75);
      expect(tester.getRect(find.byKey(strokeKey)), selectedFrameRect);
      final selectedToolbarRect = _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      );
      _expectToolbarAboveBody(selectedToolbarRect, selectedFrameRect);
      _expectToolbarAlignedToFrameEnd(selectedToolbarRect, selectedFrameRect);

      final toolbar = ToolbarController(controller);
      addTearDown(toolbar.dispose);
      expect(toolbar.canSetAlignment, isTrue);

      toolbar.setAlignment('left');
      await tester.pump();
      await tester.pump();

      expect(
        (controller.document.blocks.single as ImageBlockNode)
            .attributes
            .alignment,
        'left',
      );
      _expectImageFrameHorizontalAlignment(tester, 'image1', 'left');
      final leftFrameRect = _imageFrameRect(tester, 'image1');
      final leftToolbarRect = _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      );
      _expectToolbarAboveBody(leftToolbarRect, leftFrameRect);
      _expectToolbarAlignedToFrameEnd(leftToolbarRect, leftFrameRect);
      expect(
        tester.getRect(_imageBlockFinder('image1')).height,
        moreOrLessEquals(unselectedBlockRect.height, epsilon: 0.75),
      );

      toolbar.clearAlignment();
      await tester.pump();
      await tester.pump();

      expect(
        (controller.document.blocks.single as ImageBlockNode)
            .attributes
            .alignment,
        isNull,
      );
      _expectImageFrameHorizontalAlignment(tester, 'image1', null);
      final defaultFrameRect = _imageFrameRect(tester, 'image1');
      final defaultToolbarRect = _toolbarButtonsRect(
        tester,
        const <String>['预览媒体', '更多块操作'],
      );
      _expectToolbarAboveBody(defaultToolbarRect, defaultFrameRect);
      _expectToolbarAlignedToFrameEnd(defaultToolbarRect, defaultFrameRect);
      expect(
        tester.getRect(_imageBlockFinder('image1')).height,
        moreOrLessEquals(unselectedBlockRect.height, epsilon: 0.75),
      );
    });

    testWidgets(
        'read-only hides the media block drag handle (no mutation entry)',
        (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
            VideoBlockNode(id: 'video1', assetId: 'clip'),
          ],
        ),
      );

      Future<void> pump({required bool readOnly}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                readOnly: readOnly,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      // Editable: each media block exposes a drag handle (mutation entry).
      await pump(readOnly: false);
      expect(_blockDragHandleFinder('image1'), findsOneWidget);
      expect(_blockDragHandleFinder('video1'), findsOneWidget);

      // Read-only: the drag handle is gone — media blocks keep only safe
      // actions, with no destructive/reorder mutation entry. Display is intact.
      await pump(readOnly: true);
      expect(_blockDragHandleFinder('image1'), findsNothing);
      expect(_blockDragHandleFinder('video1'), findsNothing);
      expect(_imageBlockFinder('image1'), findsOneWidget);
      expect(_videoBlockFinder('video1'), findsOneWidget);
    });
  });

  testWidgets('tap below a trailing image appends a paragraph', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('tap below a trailing table appends a paragraph', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'cell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('tap below a trailing code block appends a paragraph', (
    tester,
  ) async {
    const code = 'final value = 42;';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    final codeBlock = controller.document.blocks.first as CodeBlockNode;
    expect(codeBlock.id, 'code1');
    expect(codeBlock.code, code);
    expect(codeBlock.language, 'dart');

    final appended = controller.document.blocks.last as TextBlockNode;
    expect(appended.type, BlockType.paragraph);
    expect(appended.content, isEmpty);
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.blockId, appended.id);
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.offset, 0);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('tap below read-only code or trailing text does not append', (
    tester,
  ) async {
    const code = 'final readonly = true;';
    final readOnlyController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: readOnlyController,
              readOnly: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(readOnlyController.document.blocks, hasLength(1));
    final readOnlyCode =
        readOnlyController.document.blocks.single as CodeBlockNode;
    expect(readOnlyCode.id, 'code1');
    expect(readOnlyCode.code, code);
    expect(readOnlyCode.language, 'dart');

    final textController = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'plain text')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WenzRichTextEditor(
              controller: textController,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(Offset(editorRect.left + 24, editorRect.bottom - 24));
    await tester.pump();

    expect(textController.document.blocks, hasLength(1));
    final textBlock = textController.document.blocks.single as TextBlockNode;
    expect(textBlock.id, 'p1');
    expect(textBlock.type, BlockType.paragraph);
    expect(textBlock.plainText, 'plain text');
  });

  testWidgets('ArrowDown from a trailing image appends a paragraph', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(tester.getCenter(_imageBlockFinder('image1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('ArrowRight at text end selects the next video block',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'before')],
          ),
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'video1');
    expect(controller.selection?.end.offset, 1);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('ArrowDown from a trailing table appends a paragraph', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell1',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-p1',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'cell')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _tapTextOffset(tester, 'cell', 4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks.last, isA<TextBlockNode>());
    expect(controller.selection?.extent.blockIndex, 1);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
  });

  testWidgets('tap text uses text layout to place caret at offset', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'abcdef', 3);
    await tester.pump();

    expect(controller.selection?.extent.offset, 3);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsOneWidget,
    );
  });

  testWidgets(
    'em dash caret and hit testing follow the rendered RichText layout',
    (tester) async {
      const fixtures = <String>[
        '中文—结尾',
        '中文——结尾',
        '中文—English—结尾',
      ];

      for (final text in fixtures) {
        final controller = WenzRichTextController(
          document: RichTextDocument(
            blocks: <BlockNode>[
              TextBlockNode(
                id: 'p1',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: text)],
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 420,
                child: WenzRichTextEditor(
                  controller: controller,
                  autofocus: true,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        for (var offset = 0; offset <= text.length; offset++) {
          controller.setSelection(collapsedTextSelection('p1', 0, offset));
          await tester.pump();

          final renderedCaret = _renderParagraphCaretTopLeft(
            tester,
            text,
            offset,
          );
          final paintedCaret = _caretPainterGlobalTopLeft(tester);
          expect(
            paintedCaret.dx,
            moreOrLessEquals(renderedCaret.dx, epsilon: 0.01),
            reason: 'caret x must match RichText for "$text" at offset $offset',
          );
        }

        for (var offset = 0; offset < text.length; offset++) {
          if (text[offset] != '—') {
            continue;
          }
          final dashBox = _renderParagraphTextBox(
            tester,
            text,
            offset,
            offset + 1,
          );

          await _waitPastMultiClickWindow(tester);
          await _tapSingle(
            tester,
            Offset(
              dashBox.left + dashBox.width * 0.25,
              dashBox.top + dashBox.height / 2,
            ),
          );
          expect(
            controller.selection?.extent.offset,
            offset,
            reason: 'left side of dash in "$text" must select offset $offset',
          );

          await _waitPastMultiClickWindow(tester);
          await _tapSingle(
            tester,
            Offset(
              dashBox.left + dashBox.width * 0.75,
              dashBox.top + dashBox.height / 2,
            ),
          );
          expect(
            controller.selection?.extent.offset,
            offset + 1,
            reason:
                'right side of dash in "$text" must select offset ${offset + 1}',
          );
        }
      }
    },
  );

  testWidgets('dragging text creates highlighted selection range', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'abcdef', 1);
    final end = _globalTextOffset(tester, 'abcdef', 4);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.base.offset, inInclusiveRange(1, 2));
    expect(controller.selection?.extent.offset, 4);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('Shift-click extends a collapsed caret to the clicked offset', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _shiftMouseClickAt(tester, _globalTextOffset(tester, 'abcdef', 5));

    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p1',
      blockIndex: 0,
      baseOffset: 1,
      extentOffset: 5,
    );
    expect(controller.selection!.isCollapsed, isFalse);
    expect(find.byKey(_selectionHighlightKey), findsOneWidget);
  });

  testWidgets('Shift-click preserves an expanded selection base', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 2, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _shiftMouseClickAt(tester, _globalTextOffset(tester, 'abcdef', 0));

    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p1',
      blockIndex: 0,
      baseOffset: 2,
      extentOffset: 0,
    );
    expect(controller.selection!.start.offset, 0);
    expect(controller.selection!.end.offset, 2);
    expect(find.byKey(_selectionHighlightKey), findsOneWidget);
  });

  testWidgets('Shift-drag extends from the existing anchor across blocks', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ghijkl')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await _shiftMouseDragFrom(
      tester,
      _globalTextOffset(tester, 'abcdef', 5),
      _globalTextOffset(tester, 'ghijkl', 3),
    );

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.isCollapsed, isFalse);
    expect(selection.base.blockId, 'p1');
    expect(selection.base.offset, 2);
    expect(selection.extent.blockId, 'p2');
    expect(selection.extent.offset, 3);
    expect(find.byKey(_selectionHighlightKey), findsAtLeastNWidgets(1));
  });

  testWidgets('Shift-click preserves code block PositionPath', (tester) async {
    const code = 'final value = 1;';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'code1', code: code, language: 'dart'),
        ],
      ),
      selection: collapsedCodeSelection('code1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _shiftMouseClickAt(tester, _globalTextOffset(tester, code, 5));

    _expectBlockCodeSelection(
      controller.selection,
      blockId: 'code1',
      blockIndex: 0,
      baseOffset: 0,
      extentOffset: 5,
    );
    expect(find.byKey(_selectionHighlightKey), findsOneWidget);
  });

  testWidgets('ordinary drag keeps using the pointer-down anchor', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final start = _globalTextOffset(tester, 'abcdef', 2);
    final end = _globalTextOffset(tester, 'abcdef', 5);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.base.offset, isNot(0));
    expect(controller.selection!.base.offset, inInclusiveRange(2, 3));
    expect(controller.selection!.extent.offset, 5);
  });

  testWidgets('paragraph inline embeds select atomically by tap drag keyboard',
      (
    tester,
  ) async {
    const renderedText = 'A😄B@bobC';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p-inline',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'A'),
              InlineEmbed(
                embedType: 'emoji',
                data: <String, Object?>{'emoji': '😄'},
              ),
              TextRun(text: 'B'),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u-bob', 'label': 'bob'},
              ),
              TextRun(text: 'C'),
            ],
          ),
        ],
      ),
    );
    final mentionTaps = <WenzMentionTapDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
            onMentionTap: mentionTaps.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final emojiLeft = _globalTextRangePoint(tester, renderedText, 1, 3, 0.25);
    final emojiRight = _globalTextRangePoint(tester, renderedText, 1, 3, 0.75);
    final mentionLeft = _globalTextRangePoint(tester, renderedText, 4, 8, 0.25);
    final mentionMiddle =
        _globalTextRangePoint(tester, renderedText, 4, 8, 0.50);
    final mentionRight =
        _globalTextRangePoint(tester, renderedText, 4, 8, 0.75);
    final followingEnd =
        _globalTextOffset(tester, renderedText, renderedText.length);

    await _tapSingle(tester, emojiRight);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 2,
      extentOffset: 2,
    );
    expect(mentionTaps, isEmpty);

    await _tapSingle(tester, mentionRight);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 4,
      extentOffset: 4,
    );
    expect(mentionTaps, hasLength(1));
    expect(mentionTaps.single.id, 'u-bob');
    expect(mentionTaps.single.label, 'bob');
    expect(mentionTaps.single.data, containsPair('id', 'u-bob'));
    expect(mentionTaps.single.position.blockId, 'p-inline');
    expect(mentionTaps.single.position.offset, 4);

    await tester.dragFrom(emojiLeft, mentionRight - emojiLeft);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: controller.selection!.base.offset,
      extentOffset: 4,
    );
    expect(controller.selection!.base.offset, inInclusiveRange(1, 2));
    expect(mentionTaps, hasLength(1));

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionLeft, followingEnd - mentionLeft);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 3,
      extentOffset: 5,
    );
    expect(mentionTaps, hasLength(1));

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionMiddle, followingEnd - mentionMiddle);
    await tester.pump();
    expect(controller.selection?.base.offset, inInclusiveRange(3, 4));
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: controller.selection!.base.offset,
      extentOffset: 5,
    );
    expect(mentionTaps, hasLength(1));

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionRight, followingEnd - mentionRight);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 4,
      extentOffset: 5,
    );
    expect(mentionTaps, hasLength(1));
    expect(
      controller.clipboardService.parse(controller.copySelection()!).text,
      'C',
    );

    controller.setSelection(collapsedTextSelection('p-inline', 0, 4));
    await tester.pump();
    expect(_caretRenderOffsetForLogicalOffset(tester, 2), 3);
    expect(_caretRenderOffsetForLogicalOffset(tester, 4), 8);

    controller.setSelection(collapsedTextSelection('p-inline', 0, 1));
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 1,
      extentOffset: 2,
    );

    controller.setSelection(collapsedTextSelection('p-inline', 0, 3));
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 3,
      extentOffset: 4,
    );

    controller.setSelection(collapsedTextSelection('p-inline', 0, 4));
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 4,
      extentOffset: 5,
    );
  });

  testWidgets('read-only mention tap opens without editing caret',
      (tester) async {
    const renderedText = 'Read @bob only';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'readonly-mention',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Read '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u-bob', 'label': 'bob'},
              ),
              TextRun(text: ' only'),
            ],
          ),
        ],
      ),
    );
    final mentionTaps = <WenzMentionTapDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
            onMentionTap: mentionTaps.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final mentionRight =
        _globalTextRangePoint(tester, renderedText, 5, 9, 0.75);
    await _tapSingle(tester, mentionRight);

    expect(mentionTaps, hasLength(1));
    expect(mentionTaps.single.id, 'u-bob');
    expect(mentionTaps.single.label, 'bob');
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'readonly-mention',
      blockIndex: 0,
      baseOffset: 6,
      extentOffset: 6,
    );
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsNothing,
    );
  });

  testWidgets('table cell inline embeds select atomically by tap drag keyboard',
      (
    tester,
  ) async {
    const renderedText = 'A😄B@bobC';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table-inline',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-inline',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-inline-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[
                          TextRun(text: 'A'),
                          InlineEmbed(
                            embedType: 'emoji',
                            data: <String, Object?>{'emoji': '😄'},
                          ),
                          TextRun(text: 'B'),
                          InlineEmbed(
                            embedType: 'mention',
                            data: <String, Object?>{
                              'id': 'u-bob',
                              'label': 'bob',
                            },
                          ),
                          TextRun(text: 'C'),
                        ],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-tail',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-tail-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'tail')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final mentionTaps = <WenzMentionTapDetails>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
            onMentionTap: mentionTaps.add,
          ),
        ),
      ),
    );
    await tester.pump();

    final emojiLeft = _globalTextRangePoint(tester, renderedText, 1, 3, 0.25);
    final emojiRight = _globalTextRangePoint(tester, renderedText, 1, 3, 0.75);
    final mentionLeft = _globalTextRangePoint(tester, renderedText, 4, 8, 0.25);
    final mentionMiddle =
        _globalTextRangePoint(tester, renderedText, 4, 8, 0.50);
    final mentionRight =
        _globalTextRangePoint(tester, renderedText, 4, 8, 0.75);
    final followingEnd =
        _globalTextOffset(tester, renderedText, renderedText.length);

    await _tapSingle(tester, emojiRight);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 2,
      extentOffset: 2,
    );
    expect(mentionTaps, isEmpty);

    await _tapSingle(tester, mentionRight);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 4,
      extentOffset: 4,
    );
    expect(mentionTaps, hasLength(1));
    expect(mentionTaps.single.id, 'u-bob');
    expect(mentionTaps.single.label, 'bob');
    expect(mentionTaps.single.path.isTableCellText, isTrue);

    await tester.dragFrom(emojiLeft, mentionRight - emojiLeft);
    await tester.pump();
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: controller.selection!.base.offset,
      extentOffset: 4,
    );
    expect(controller.selection!.base.offset, inInclusiveRange(1, 2));
    expect(mentionTaps, hasLength(1));

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionLeft, followingEnd - mentionLeft);
    await tester.pump();
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 3,
      extentOffset: 5,
    );
    expect(mentionTaps, hasLength(1));

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionMiddle, followingEnd - mentionMiddle);
    await tester.pump();
    expect(controller.selection?.base.offset, inInclusiveRange(3, 4));
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: controller.selection!.base.offset,
      extentOffset: 5,
    );

    await _waitPastMultiClickWindow(tester);
    await tester.dragFrom(mentionRight, followingEnd - mentionRight);
    await tester.pump();
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 4,
      extentOffset: 5,
    );

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table-inline',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 4,
      ),
    );
    await tester.pump();
    expect(_caretRenderOffsetForLogicalOffset(tester, 4), 8);

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table-inline',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 1,
      ),
    );
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 1,
      extentOffset: 2,
    );

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table-inline',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 3,
      ),
    );
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 3,
      extentOffset: 4,
    );

    controller.setSelection(
      _collapsedTableCellTextSelection(
        tableBlockId: 'table-inline',
        blockIndex: 0,
        tableRowIndex: 0,
        tableColumnIndex: 0,
        offset: 4,
      ),
    );
    await tester.pump();
    await _sendShiftArrowRight(tester);
    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-inline',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      baseOffset: 4,
      extentOffset: 5,
    );
  });

  testWidgets('dragging across table cells creates table cell range', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BB')],
                      ),
                    ],
                  ),
                ],
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-c',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-c-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'CC')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-d',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-d-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'DD')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'AA', 1);
    final end = _globalTextOffset(tester, 'DD', 1);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.base.path.isTableCellText, isTrue);
    expect(selection.extent.path.isTableCellText, isTrue);
    expect(selection.base.path.tableRowIndex, 0);
    expect(selection.base.path.tableColumnIndex, 0);
    expect(selection.extent.path.tableRowIndex, 1);
    expect(selection.extent.path.tableColumnIndex, 1);

    final range = selection.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 0);
    expect(range.endRow, 1);
    expect(range.startColumn, 0);
    expect(range.endColumn, 1);
    expect(range.containsCell(0, 1), isTrue);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsAtLeastNWidgets(4),
    );
  });

  testWidgets('empty table cell tap collapses selection to cell text', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table-empty',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'filled-cell',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'filled-cell-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Filled')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'empty-cell',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'empty-cell-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 180,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emptyCellRect = tester.getRect(
      find.byKey(const ValueKey<String>('table-cell-border-table-empty-0-1')),
    );
    await _tapSingle(tester, emptyCellRect.center);

    _expectTableCellTextSelection(
      controller.selection,
      tableBlockId: 'table-empty',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 1,
      baseOffset: 0,
      extentOffset: 0,
    );
  });

  testWidgets('merged table cell spans covered columns for hit testing', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a',
                    columnSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Anchor')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b',
                    covered: true,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Covered')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    expect(find.text('Covered'), findsNothing);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(
      Offset(editorRect.right - 24, editorRect.top + 22),
    );
    await tester.pump();

    final extent = controller.selection?.extent;
    expect(extent, isNotNull);
    expect(extent!.path.isTableCellText, isTrue);
    expect(extent.path.tableRowIndex, 0);
    expect(extent.path.tableColumnIndex, 0);
  });

  testWidgets('merged table cell spans covered rows for hit testing', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a',
                    rowSpan: 2,
                    columnSpan: 2,
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'Anchor')],
                      ),
                    ],
                  ),
                  TableCellNode(id: 'cell-b', covered: true),
                ],
                <TableCellNode>[
                  TableCellNode(id: 'cell-c', covered: true),
                  TableCellNode(id: 'cell-d', covered: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    await tester.tapAt(
      Offset(editorRect.right - 24, editorRect.top + 56),
    );
    await tester.pump();

    final extent = controller.selection?.extent;
    expect(extent, isNotNull);
    expect(extent!.path.isTableCellText, isTrue);
    expect(extent.path.tableRowIndex, 0);
    expect(extent.path.tableColumnIndex, 0);
  });

  testWidgets(
      'selection from a table cell into a later block highlights later cells', (
    tester,
  ) async {
    final start = DocumentPosition.tableCell(
      tableBlockId: 'table1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 1,
    );
    final end = DocumentPosition.text(
      blockId: 'p2',
      blockIndex: 1,
      offset: 3,
    );
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 'table1',
            table: TableModel(
              rows: <List<TableCellNode>>[
                <TableCellNode>[
                  TableCellNode(
                    id: 'cell-a',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-a-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'AA')],
                      ),
                    ],
                  ),
                  TableCellNode(
                    id: 'cell-b',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 'cell-b-p',
                        type: BlockType.paragraph,
                        content: <InlineNode>[TextRun(text: 'BB')],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'tail')],
          ),
        ],
      ),
      selection: DocumentSelection(base: start, extent: end),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsAtLeastNWidgets(4),
    );
  });

  testWidgets('within-table reverse drag normalizes table cell range rectangle',
      (
    tester,
  ) async {
    // Drag from (row=2, col=3) to (row=0, col=1): the bounding box must
    // span rows 0-2 and columns 1-3 regardless of base/extent order.
    final base = DocumentPosition.tableCell(
      tableBlockId: 't1',
      blockIndex: 0,
      tableRowIndex: 2,
      tableColumnIndex: 3,
      offset: 0,
    );
    final extent = DocumentPosition.tableCell(
      tableBlockId: 't1',
      blockIndex: 0,
      tableRowIndex: 0,
      tableColumnIndex: 1,
      offset: 0,
    );
    final selection = DocumentSelection(base: base, extent: extent);
    final range = selection.tableCellRange;
    expect(range, isNotNull);
    expect(range!.startRow, 0);
    expect(range.endRow, 2);
    expect(range.startColumn, 1);
    expect(range.endColumn, 3);
    // Cells inside the bounding box.
    expect(range.containsCell(0, 1), isTrue);
    expect(range.containsCell(0, 2), isTrue);
    expect(range.containsCell(0, 3), isTrue);
    expect(range.containsCell(1, 1), isTrue);
    expect(range.containsCell(2, 1), isTrue);
    expect(range.containsCell(2, 3), isTrue);
    // Cells outside.
    expect(range.containsCell(0, 0), isFalse);
    expect(range.containsCell(0, 4), isFalse);
    expect(range.containsCell(3, 1), isFalse);
    expect(range.isSingleCell, isFalse);

    // Render a 3×4 table with this selection and verify highlights appear.
    final controller = WenzRichTextController(
      document: RichTextDocument(
        blocks: <BlockNode>[
          TableBlockNode(
            id: 't1',
            table: TableModel(
              rows: List<List<TableCellNode>>.generate(
                3,
                (r) => List<TableCellNode>.generate(
                  4,
                  (c) => TableCellNode(
                    id: 't1-r$r-c$c',
                    blocks: <BlockNode>[
                      TextBlockNode(
                        id: 't1-r$r-c$c-text',
                        type: BlockType.paragraph,
                        content: <InlineNode>[
                          TextRun(text: '$r,$c'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      selection: selection,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Drag selection highlights should appear for cells inside the range.
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-selection-highlight'),
      ),
      findsAtLeastNWidgets(3),
    );
    // tableCellRange from the active selection retains the normalized bounds.
    final activeRange = controller.selection?.tableCellRange;
    expect(activeRange, isNotNull);
    expect(activeRange!.startRow, 0);
    expect(activeRange.endRow, 2);
    expect(activeRange.startColumn, 1);
    expect(activeRange.endColumn, 3);
  });

  test('forward and reverse table cell drags produce identical ranges', () {
    const tableBlockId = 't1';
    const blockIndex = 0;
    // Forward: (0,0) -> (2,3)
    final fwdBase = DocumentPosition.tableCell(
      tableBlockId: tableBlockId,
      blockIndex: blockIndex,
      tableRowIndex: 0,
      tableColumnIndex: 0,
      offset: 0,
    );
    final fwdExtent = DocumentPosition.tableCell(
      tableBlockId: tableBlockId,
      blockIndex: blockIndex,
      tableRowIndex: 2,
      tableColumnIndex: 3,
      offset: 0,
    );
    final forward = DocumentSelection(base: fwdBase, extent: fwdExtent);
    final forwardRange = forward.tableCellRange;

    // Reverse: (2,3) -> (0,0)
    final reverse = DocumentSelection(base: fwdExtent, extent: fwdBase);
    final reverseRange = reverse.tableCellRange;

    expect(forwardRange, isNotNull);
    expect(reverseRange, isNotNull);
    // Both must produce the same normalized bounding box.
    expect(reverseRange!.startRow, forwardRange!.startRow);
    expect(reverseRange.endRow, forwardRange.endRow);
    expect(reverseRange.startColumn, forwardRange.startColumn);
    expect(reverseRange.endColumn, forwardRange.endColumn);
    expect(reverseRange.containsCell(1, 1), isTrue);
    expect(forwardRange.containsCell(1, 1), isTrue);
  });

  testWidgets('read-only mode still allows placing a selection',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
          ),
        ),
      ),
    );

    await _tapTextOffset(tester, 'abcdef', 3);
    await tester.pump();

    // Selection is updated even in read-only mode (for copy workflows).
    expect(controller.selection, isNotNull);
    expect(controller.selection?.extent.offset, 3);
    // No editing caret is rendered in read-only mode.
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-caret')),
      findsNothing,
    );
  });

  testWidgets('read-only mode blocks text insertion via keyboard', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();

    // Document is unchanged because read-only mode swallows editing keys.
    expect(controller.document.plainText, 'abc');
  });

  testWidgets('C0 control characters are not inserted', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // U+0001 (SOH) is a C0 control character that is not \n/\r/\t.
    await tester.sendKeyEvent(
      LogicalKeyboardKey.keyA,
      character: String.fromCharCode(0x01),
    );
    await tester.pump();

    expect(controller.document.plainText, 'ab');
  });

  testWidgets('IME composition underline only decorates the composing text', (
    tester,
  ) async {
    const text = 'Controller commands own document';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: text)],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            enableIme: false,
          ),
        ),
      ),
    );
    controller.setCompositionState(
      CompositionState(
        blockId: 'p1',
        blockIndex: 0,
        path: PositionPath.blockText('p1'),
        startOffset: 11,
        endOffset: 19,
      ),
    );
    await tester.pump();

    final richText = tester.widget<RichText>(_richText(text));

    expect(_underlinedTexts(richText.text), <String>['commands']);
  });

  testWidgets('re-reports IME geometry after growing content auto-scrolls', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'start')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 64,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    controller.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.log.clear();
    final scrollBefore = _scrollOffset(tester);

    controller.insertText(
      '\nline 1\nline 2\nline 3\nline 4\nline 5\nline 6',
    );
    // Growing content produces the caret-into-view scroll only after the
    // affected blocks' measured heights land: the mutation frame still carries
    // the pre-edit (short) heights, so the scroll re-arms on the frame where
    // the real extents are recorded. Two pumps advance past that post-frame
    // measurement and the subsequent re-layout.
    await tester.pump();
    await tester.pump();

    expect(_scrollOffset(tester), greaterThan(scrollBefore));
    tester.testTextInput.log.clear();

    await tester.pump();

    expect(
      tester.testTextInput.log.where(
          (call) => call.method == 'TextInput.setEditableSizeAndTransform'),
      isNotEmpty,
    );
  });

  testWidgets('platform selectors dispatch to editor commands', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello world')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await _performPlatformSelectors(tester, <String>['moveLeft:']);
    await tester.pump();

    expect(controller.selection?.extent.offset, 10);

    controller.setSelection(collapsedTextSelection('p1', 0, 11));
    await tester.pump();

    await _performPlatformSelectors(tester, <String>['deleteWordBackward:']);
    await tester.pump();

    expect(controller.document.plainText, 'hello ');
    expect(controller.selection?.extent.offset, 6);
  });

  testWidgets('Backspace deletes an expanded selection', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('Delete deletes an expanded selection', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('platform delete selector deletes an expanded selection', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: textSelection('p1', 0, 1, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await _performPlatformSelectors(tester, <String>['deleteBackward:']);
    await tester.pump();

    expect(controller.document.plainText, 'aef');
    expect(controller.selection?.isCollapsed, isTrue);
    expect(controller.selection?.extent.offset, 1);
  });

  testWidgets('debug overlay renders selection tag when enabled', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            showDebugOverlay: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // The debug tag surfaces the block id and path string.
    expect(find.textContaining('#0 p1'), findsOneWidget);
    expect(find.textContaining('block/p1/text'), findsOneWidget);
  });

  testWidgets('Ctrl+A selects the whole editable range', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.offset, 6);
  });

  testWidgets('Ctrl+A inside code block selects only that code',
      (tester) async {
    const code = 'aa\nbb\ncc';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'before',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Before')],
          ),
          CodeBlockNode(id: 'code1', code: code),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After')],
          ),
        ],
      ),
      selection: collapsedCodeSelection('code1', 1, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.start.blockId, 'code1');
    expect(controller.selection?.start.path, PositionPath.blockCode('code1'));
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'code1');
    expect(controller.selection?.end.path, PositionPath.blockCode('code1'));
    expect(controller.selection?.end.offset, code.length);

    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition.code(
          blockId: 'code1',
          blockIndex: 1,
          offset: 2,
        ),
        extent: DocumentPosition.code(
          blockId: 'code1',
          blockIndex: 1,
          offset: 5,
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.start.blockId, 'code1');
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'code1');
    expect(controller.selection?.end.offset, code.length);
  });

  testWidgets('Ctrl+A selects a lone image block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.blockId, 'image1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'image1');
    expect(controller.selection?.end.path.isBlockObject, isTrue);
    expect(controller.selection?.end.offset, 1);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  testWidgets('Ctrl+A selects a lone video block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.blockId, 'video1');
    expect(controller.selection?.end.path.isBlockObject, isTrue);
    expect(controller.selection?.end.offset, 1);
    expect(
      find.byKey(const ValueKey<String>('wenz-richtext-selection-highlight')),
      findsOneWidget,
    );
  });

  group('media block selection stroke', () {
    // The selection stroke drawn directly on the media frame (image/video).
    const strokeKey = ValueKey<String>('wenz-richtext-media-selection-stroke');
    const imageFrameKey = ValueKey<String>('wenz-richtext-image-frame-image1');
    const videoFrameKey = ValueKey<String>('wenz-richtext-video-frame-video1');
    // Media frame corner radius (_kMediaCornerRadius) and the vertical block
    // margin (_kMediaBlockMarginVertical) are private in the editor; assert the
    // spec'd values directly so the test pins the user-facing behaviour.
    const mediaCornerRadius = 12.0;
    const primaryStroke = Color(0xFF0B6E4F);
    // The generic full-size overlay painted by _BlockObjectSelectionSurface
    // when showSelectionOverlay is true. Media blocks disable it and paint
    // only the frame-hugging _MediaSelectionStroke, so a selected image/video
    // must not render this loose rectangle.
    const selectionHighlightKey =
        ValueKey<String>('wenz-richtext-selection-highlight');

    Future<void> pumpMediaEditor(
      WidgetTester tester,
      WenzRichTextController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: primaryStroke),
          ),
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // Matches the generic full-size selection overlay uniquely: a DecoratedBox
    // carrying the selection-highlight key with a non-null border (the loose
    // BorderRadius.circular(6) rectangle that floats over the block margins).
    // Excludes the plain SizedBox and border-less table-cell variants that
    // share the same key.
    Finder genericSelectionOverlay() => find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.key == selectionHighlightKey &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border != null,
        );

    testWidgets(
      'selected image uses only frame stroke while keeping resize hit zones',
      (tester) async {
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
            ],
          ),
          selection: objectBlockSelection('image1', 0),
        );
        await pumpMediaEditor(tester, controller);

        final decoration = tester
            .widget<DecoratedBox>(find.byKey(strokeKey))
            .decoration as BoxDecoration;
        // Radius matches the media frame (_kMediaCornerRadius), not the old
        // loose BorderRadius.circular(6) overlay rectangle.
        expect(
          decoration.borderRadius,
          BorderRadius.circular(mediaCornerRadius),
        );
        expect(decoration.border, isA<Border>());
        final side = (decoration.border as Border).top;
        expect(side.color, primaryStroke);
        expect(side.width, 2.0);

        // The stroke sits exactly on the media frame instead of floating over
        // the vertical _kMediaBlockMarginVertical padding above and below it.
        final strokeRect = tester.getRect(find.byKey(strokeKey));
        expect(strokeRect, tester.getRect(find.byKey(imageFrameKey)));
        final imageSizeRect = tester.getRect(
          find.byKey(
            const ValueKey<String>('wenz-richtext-image-size-image1'),
          ),
        );
        expect(imageSizeRect, strokeRect);
        expect(strokeRect.width.isFinite, isTrue);
        expect(strokeRect.height.isFinite, isTrue);
        expect(strokeRect.width, greaterThan(0));
        expect(strokeRect.height, greaterThan(0));
        expect(
          strokeRect.height,
          moreOrLessEquals(strokeRect.width / 2, epsilon: 1),
        );
        final blockRect = tester.getRect(_imageBlockFinder('image1'));
        expect(strokeRect.top, greaterThan(blockRect.top));
        expect(strokeRect.bottom, lessThan(blockRect.bottom));
        expect(_imageResizeVisualLineFinder('image1', 'left'), findsNothing);
        expect(_imageResizeVisualLineFinder('image1', 'right'), findsNothing);
        expect(_imageResizeHitZoneFinder('image1', 'left'), findsOneWidget);
        expect(_imageResizeHitZoneFinder('image1', 'right'), findsOneWidget);
        expect(genericSelectionOverlay(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dragging selected image edge resizes frame stroke and toolbar proportionally',
      (tester) async {
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              ImageBlockNode(
                id: 'image1',
                assetId: 'hero',
                file: 'hero.png',
                width: 640,
                height: 320,
                showWidth: 180,
                showHeight: 90,
                caption: 'Caption',
              ),
            ],
          ),
          selection: objectBlockSelection('image1', 0),
        );
        await pumpMediaEditor(tester, controller);
        await tester.pump();

        final rightHitZone = _imageResizeHitZoneFinder('image1', 'right');
        final frameFinder = find.byKey(imageFrameKey);
        expect(rightHitZone, findsOneWidget);
        expect(_imageResizeVisualLineFinder('image1', 'left'), findsNothing);
        expect(_imageResizeVisualLineFinder('image1', 'right'), findsNothing);
        expect(frameFinder, findsOneWidget);
        expect(find.byTooltip('预览媒体'), findsOneWidget);
        expect(find.byTooltip('更多块操作'), findsOneWidget);
        expect(find.text('Caption'), findsNothing);

        final frameBefore = tester.getRect(frameFinder);
        final toolbarBefore = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        _expectToolbarAlignedToFrameEnd(toolbarBefore, frameBefore);

        final hitZoneRect = tester.getRect(rightHitZone);
        final gesture = await tester.startGesture(hitZoneRect.center);
        await tester.pump();
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();

        final frameDuringDrag = tester.getRect(frameFinder);
        expect(frameDuringDrag.width, moreOrLessEquals(240, epsilon: 0.75));
        expect(frameDuringDrag.height, moreOrLessEquals(120, epsilon: 0.75));
        expect(tester.getRect(find.byKey(strokeKey)), frameDuringDrag);
        final toolbarDuringDrag = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        _expectToolbarAboveBody(toolbarDuringDrag, frameDuringDrag);
        _expectToolbarAlignedToFrameEnd(toolbarDuringDrag, frameDuringDrag);
        expect(toolbarDuringDrag.right, greaterThan(toolbarBefore.right));

        await gesture.up();
        await tester.pump();

        final frameAfterCommitPump = tester.getRect(frameFinder);
        final strokeAfterCommitPump = tester.getRect(find.byKey(strokeKey));
        final toolbarAfterCommitPump = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        expect(
            frameAfterCommitPump.width, moreOrLessEquals(240, epsilon: 0.75));
        expect(
          frameAfterCommitPump.height,
          moreOrLessEquals(120, epsilon: 0.75),
        );
        expect(strokeAfterCommitPump, frameAfterCommitPump);
        _expectToolbarAboveBody(toolbarAfterCommitPump, frameAfterCommitPump);
        _expectToolbarAlignedToFrameEnd(
          toolbarAfterCommitPump,
          frameAfterCommitPump,
        );
        expect(toolbarAfterCommitPump.right, greaterThan(toolbarBefore.right));

        await tester.pump();

        final image = controller.document.blocks.single as ImageBlockNode;
        expect(image.showWidth, moreOrLessEquals(240, epsilon: 0.75));
        expect(image.showHeight, moreOrLessEquals(120, epsilon: 0.75));
        expect(image.caption, 'Caption');

        final frameAfter = tester.getRect(frameFinder);
        final strokeAfter = tester.getRect(find.byKey(strokeKey));
        final toolbarAfter = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        expect(frameAfter.width, moreOrLessEquals(240, epsilon: 0.75));
        expect(frameAfter.height, moreOrLessEquals(120, epsilon: 0.75));
        expect(strokeAfter, frameAfter);
        _expectToolbarAboveBody(toolbarAfter, frameAfter);
        _expectToolbarAlignedToFrameEnd(toolbarAfter, frameAfter);
        expect(toolbarAfter.right, greaterThan(toolbarBefore.right));
      },
    );

    testWidgets(
      'dragging selected video edge resizes frame stroke and toolbar proportionally',
      (tester) async {
        final selection = objectBlockSelection('video1', 0);
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(
                id: 'video1',
                assetId: 'clip',
                aspectRatio: 2,
                showWidth: 180,
                showHeight: 90,
                title: 'Clip',
              ),
            ],
          ),
          selection: selection,
        );
        await pumpMediaEditor(tester, controller);
        await tester.pump();

        final rightHitZone = _videoResizeHitZoneFinder('video1', 'right');
        final frameFinder = _videoFrameFinder('video1');
        expect(rightHitZone, findsOneWidget);
        expect(_videoResizeHitZoneFinder('video1', 'left'), findsOneWidget);
        expect(find.byTooltip('拖拽右边缘调整视频宽度'), findsOneWidget);
        expect(frameFinder, findsOneWidget);
        expect(find.byTooltip('预览媒体'), findsOneWidget);
        expect(find.byTooltip('更多块操作'), findsOneWidget);

        final frameBefore = tester.getRect(frameFinder);
        final toolbarBefore = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        _expectToolbarAlignedToFrameEnd(toolbarBefore, frameBefore);

        final hitZoneRect = tester.getRect(rightHitZone);
        final gesture = await tester.startGesture(hitZoneRect.center);
        await tester.pump();
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();

        final frameDuringDrag = tester.getRect(frameFinder);
        expect(frameDuringDrag.width, moreOrLessEquals(240, epsilon: 0.75));
        expect(frameDuringDrag.height, moreOrLessEquals(120, epsilon: 0.75));
        expect(tester.getRect(find.byKey(strokeKey)), frameDuringDrag);
        final toolbarDuringDrag = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        _expectToolbarAboveBody(toolbarDuringDrag, frameDuringDrag);
        _expectToolbarAlignedToFrameEnd(toolbarDuringDrag, frameDuringDrag);
        expect(toolbarDuringDrag.right, greaterThan(toolbarBefore.right));
        expect(controller.selection, selection);

        await gesture.up();
        await tester.pump();
        await tester.pump();

        final video = controller.document.blocks.single as VideoBlockNode;
        expect(video.showWidth, moreOrLessEquals(240, epsilon: 0.75));
        expect(video.showHeight, moreOrLessEquals(120, epsilon: 0.75));
        expect(video.title, 'Clip');
        expect(controller.selection, selection);

        final frameAfter = tester.getRect(frameFinder);
        final strokeAfter = tester.getRect(find.byKey(strokeKey));
        final toolbarAfter = _toolbarButtonsRect(
          tester,
          const <String>['预览媒体', '更多块操作'],
        );
        expect(frameAfter.width, moreOrLessEquals(240, epsilon: 0.75));
        expect(frameAfter.height, moreOrLessEquals(120, epsilon: 0.75));
        expect(strokeAfter, frameAfter);
        _expectToolbarAboveBody(toolbarAfter, frameAfter);
        _expectToolbarAlignedToFrameEnd(toolbarAfter, frameAfter);
        expect(toolbarAfter.right, greaterThan(toolbarBefore.right));
      },
    );
    testWidgets(
      'read-only and read permission hide image resize hit zones without changing dimensions',
      (tester) async {
        Future<WenzRichTextController> pumpImageEditor({
          required String blockId,
          required bool readOnly,
          WenzEditorPermission permission = WenzEditorPermission.edit,
        }) async {
          final controller = WenzRichTextController(
            document: RichTextDocument(
              blocks: <BlockNode>[
                ImageBlockNode(
                  id: blockId,
                  assetId: 'hero',
                  file: 'hero.png',
                  width: 640,
                  height: 320,
                  showWidth: 180,
                  showHeight: 90,
                ),
              ],
            ),
            permission: permission,
            selection: objectBlockSelection(blockId, 0),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WenzRichTextEditor(
                  key: ValueKey<String>('resize-gated-editor-$blockId'),
                  controller: controller,
                  readOnly: readOnly,
                  enableIme: false,
                ),
              ),
            ),
          );
          await tester.pump();
          return controller;
        }

        void expectNoResizeHitZones(
          WenzRichTextController controller,
          String blockId,
        ) {
          expect(_imageResizeHitZoneFinder(blockId, 'left'), findsNothing);
          expect(_imageResizeHitZoneFinder(blockId, 'right'), findsNothing);
          expect(_imageResizeVisualLineFinder(blockId, 'left'), findsNothing);
          expect(_imageResizeVisualLineFinder(blockId, 'right'), findsNothing);
          expect(find.byTooltip('拖拽左边缘调整图片宽度'), findsNothing);
          expect(find.byTooltip('拖拽右边缘调整图片宽度'), findsNothing);

          final image = controller.document.blocks.single as ImageBlockNode;
          expect(image.showWidth, 180);
          expect(image.showHeight, 90);
          expect(controller.canUndo, isFalse);
        }

        final readOnlyController = await pumpImageEditor(
          blockId: 'readonly-image',
          readOnly: true,
        );
        expectNoResizeHitZones(readOnlyController, 'readonly-image');

        final readPermissionController = await pumpImageEditor(
          blockId: 'read-permission-image',
          readOnly: false,
          permission: WenzEditorPermission.read,
        );
        expectNoResizeHitZones(
          readPermissionController,
          'read-permission-image',
        );
      },
    );

    testWidgets(
      'read-only and read permission hide video resize hit zones without changing dimensions',
      (tester) async {
        Future<WenzRichTextController> pumpVideoEditor({
          required String blockId,
          required bool readOnly,
          WenzEditorPermission permission = WenzEditorPermission.edit,
        }) async {
          final controller = WenzRichTextController(
            document: RichTextDocument(
              blocks: <BlockNode>[
                VideoBlockNode(
                  id: blockId,
                  assetId: 'clip',
                  aspectRatio: 2,
                  showWidth: 180,
                  showHeight: 90,
                ),
              ],
            ),
            permission: permission,
            selection: objectBlockSelection(blockId, 0),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WenzRichTextEditor(
                  key: ValueKey<String>('resize-gated-editor-$blockId'),
                  controller: controller,
                  readOnly: readOnly,
                  enableIme: false,
                ),
              ),
            ),
          );
          await tester.pump();
          return controller;
        }

        void expectNoResizeHitZones(
          WenzRichTextController controller,
          String blockId,
        ) {
          expect(_videoResizeHitZoneFinder(blockId, 'left'), findsNothing);
          expect(_videoResizeHitZoneFinder(blockId, 'right'), findsNothing);
          expect(find.byTooltip('拖拽左边缘调整视频宽度'), findsNothing);
          expect(find.byTooltip('拖拽右边缘调整视频宽度'), findsNothing);

          final video = controller.document.blocks.single as VideoBlockNode;
          expect(video.showWidth, 180);
          expect(video.showHeight, 90);
          expect(controller.canUndo, isFalse);
        }

        final readOnlyController = await pumpVideoEditor(
          blockId: 'readonly-video',
          readOnly: true,
        );
        expectNoResizeHitZones(readOnlyController, 'readonly-video');

        final readPermissionController = await pumpVideoEditor(
          blockId: 'read-permission-video',
          readOnly: false,
          permission: WenzEditorPermission.read,
        );
        expectNoResizeHitZones(
          readPermissionController,
          'read-permission-video',
        );
      },
    );
    testWidgets(
      'selected video selection stroke hugs the media frame and uses media radius',
      (tester) async {
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(id: 'video1', assetId: 'clip'),
            ],
          ),
          selection: objectBlockSelection('video1', 0),
        );
        await pumpMediaEditor(tester, controller);

        final frameDecoration = tester
            .widget<DecoratedBox>(find.byKey(videoFrameKey))
            .decoration as BoxDecoration;
        expect(frameDecoration.color, Colors.black);
        expect(
          frameDecoration.borderRadius,
          BorderRadius.circular(mediaCornerRadius),
        );
        expect(frameDecoration.boxShadow, isNotNull);
        expect(frameDecoration.boxShadow, isNotEmpty);
        expect(frameDecoration.border, isNull);

        final decoration = tester
            .widget<DecoratedBox>(find.byKey(strokeKey))
            .decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          BorderRadius.circular(mediaCornerRadius),
        );
        final side = (decoration.border as Border).top;
        expect(side.color, primaryStroke);
        expect(side.width, 2.0);

        final strokeRect = tester.getRect(find.byKey(strokeKey));
        expect(strokeRect, tester.getRect(find.byKey(videoFrameKey)));
        final blockRect = tester.getRect(_videoBlockFinder('video1'));
        expect(strokeRect.top, greaterThan(blockRect.top));
        expect(strokeRect.bottom, lessThan(blockRect.bottom));
        expect(_videoResizeHitZoneFinder('video1', 'left'), findsOneWidget);
        expect(_videoResizeHitZoneFinder('video1', 'right'), findsOneWidget);
        expect(find.byTooltip('拖拽左边缘调整视频宽度'), findsOneWidget);
        expect(find.byTooltip('拖拽右边缘调整视频宽度'), findsOneWidget);
      },
    );

    testWidgets(
      'selected media blocks paint no generic full-size overlay (video mirrors image)',
      (tester) async {
        // Selected image: the generic _BlockObjectSelectionSurface overlay is
        // disabled (showSelectionOverlay: false), so only the frame-hugging
        // _MediaSelectionStroke paints.
        final imageController = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
            ],
          ),
          selection: objectBlockSelection('image1', 0),
        );
        await pumpMediaEditor(tester, imageController);
        expect(find.byKey(strokeKey), findsOneWidget);
        expect(genericSelectionOverlay(), findsNothing);

        // Selected video: must mirror the image exactly. Before the fix the
        // video wrapper left showSelectionOverlay at its default (true), so the
        // generic loose rectangle was painted over the block margins on top of
        // the frame-hugging stroke — a double frame. Now both blocks render
        // only the single _MediaSelectionStroke.
        final videoController = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              VideoBlockNode(id: 'video1', assetId: 'clip'),
            ],
          ),
          selection: objectBlockSelection('video1', 0),
        );
        await pumpMediaEditor(tester, videoController);
        expect(find.byKey(strokeKey), findsOneWidget);
        expect(genericSelectionOverlay(), findsNothing);
      },
    );

    testWidgets('deselected media blocks render no primary selection stroke', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
            VideoBlockNode(id: 'video1', assetId: 'clip'),
          ],
        ),
      );
      await pumpMediaEditor(tester, controller);

      expect(find.byKey(strokeKey), findsNothing);
      // The media frames themselves carry no selection border either.
      final imageDecoration = tester
          .widget<DecoratedBox>(find.byKey(imageFrameKey))
          .decoration as BoxDecoration;
      expect(imageDecoration.border, isNull);
    });

    testWidgets(
      'non-media selection highlight is unaffected by the media stroke',
      (tester) async {
        const code = 'final value = 42;';
        final codePath = PositionPath.blockCode('code1');
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              CodeBlockNode(id: 'code1', code: code, language: 'dart'),
              ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
            ],
          ),
          selection: DocumentSelection(
            base: DocumentPosition(
              blockId: 'code1',
              blockIndex: 0,
              path: codePath,
              offset: 0,
            ),
            extent: DocumentPosition(
              blockId: 'code1',
              blockIndex: 0,
              path: codePath,
              offset: 11,
            ),
          ),
        );
        await pumpMediaEditor(tester, controller);

        // Text/code selection highlight still renders normally.
        expect(
          find.byKey(
              const ValueKey<String>('wenz-richtext-selection-highlight')),
          findsOneWidget,
        );
        // The media stroke does not appear for non-media selections.
        expect(find.byKey(strokeKey), findsNothing);
      },
    );
  });

  testWidgets('Delete after Ctrl+A leaves one empty paragraph', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'middle')],
          ),
          ImageBlockNode(id: 'image2', assetId: 'hero2', file: 'hero2.png'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final block = controller.document.blocks.single;
    expect(block, isA<TextBlockNode>());
    expect((block as TextBlockNode).content, isEmpty);
    expect(block.type, BlockType.paragraph);
    expect(controller.selection?.extent.blockIndex, 0);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('Delete deletes a selected video block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
        ],
      ),
      selection: objectBlockSelection('video1', 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(controller.document.blocks, hasLength(1));
    final block = controller.document.blocks.single;
    expect(block, isA<TextBlockNode>());
    expect((block as TextBlockNode).content, isEmpty);
    expect(controller.selection?.extent.blockIndex, 0);
    expect(controller.selection?.extent.path.isBlockText, isTrue);
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('Backspace at text start selects the previous image block', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _tapTextOffset(tester, 'after', 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks[0].id, 'image1');
    expect(controller.document.blocks[1].id, 'p1');
    expect(_imageBlockFinder('image1'), findsOneWidget);
    expect(controller.selection?.start.blockId, 'image1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.blockIndex, 0);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.offset, 1);
  });

  testWidgets('Backspace at text start selects the previous video block', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          VideoBlockNode(id: 'video1', assetId: 'clip'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _tapTextOffset(tester, 'after', 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(controller.document.blocks, hasLength(2));
    expect(controller.document.blocks[0].id, 'video1');
    expect(controller.document.blocks[1].id, 'p1');
    expect(_videoBlockFinder('video1'), findsOneWidget);
    expect(controller.selection?.start.blockId, 'video1');
    expect(controller.selection?.start.path.isBlockObject, isTrue);
    expect(controller.selection?.start.blockIndex, 0);
    expect(controller.selection?.start.offset, 0);
    expect(controller.selection?.end.offset, 1);
  });

  testWidgets('Ctrl+Z / Ctrl+Shift+Z undo and redo', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ab')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
    await tester.pump();
    expect(controller.document.plainText, 'abc');

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(controller.document.plainText, 'ab');

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    await tester.pump();
    expect(controller.document.plainText, 'abc');
  });

  testWidgets('Home and End move to block boundaries', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.selection?.extent.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(controller.selection?.extent.offset, 6);
  });

  testWidgets('Ctrl+Left/Right move by word', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'foo bar')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            autofocus: true,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.selection?.extent.offset, 4);

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection?.extent.offset, 0);
  });

  testWidgets('read-only mode still allows Ctrl+A select-all', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    await _sendCtrlShortcut(tester, LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection?.end.offset, 6);
  });

  testWidgets('cross-block drag extends selection across paragraphs', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'abcdef')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ghijkl')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: WenzRichTextEditor(controller: controller),
          ),
        ),
      ),
    );

    final start = _globalTextOffset(tester, 'abcdef', 1);
    final end = _globalTextOffset(tester, 'ghijkl', 3);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.isCollapsed, isFalse);
    // The drag started in p1 and ended in p2 — a genuine cross-block selection.
    expect(controller.selection!.start.blockId, 'p1');
    expect(controller.selection!.end.blockId, 'p2');
  });

  testWidgets('dragging from an empty paragraph extends selection', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'empty',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after text')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: WenzRichTextEditor(
              controller: controller,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final start = tester.getRect(_emptyRichText()).center;
    final end = _globalTextOffset(tester, 'after text', 5);
    await tester.dragFrom(start, end - start);
    await tester.pump();

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(selection!.isCollapsed, isFalse);
    expect(selection.start.blockId, 'empty');
    expect(selection.start.offset, 0);
    expect(selection.end.blockId, 'after');
  });

  testWidgets('double and triple taps on an empty paragraph stay at offset 0', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'empty',
            type: BlockType.paragraph,
            content: <InlineNode>[],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            padding: EdgeInsets.zero,
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = tester.getRect(_emptyRichText()).center;
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'empty',
      blockIndex: 0,
      baseOffset: 0,
      extentOffset: 0,
    );

    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'empty',
      blockIndex: 0,
      baseOffset: 0,
      extentOffset: 0,
    );
  });

  testWidgets('double-tap selects a word', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello world')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller),
        ),
      ),
    );

    // Tap twice on the word "hello" quickly.
    final target = _globalTextOffset(tester, 'hello world', 2);
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    // "hello" occupies offsets 0..5.
    expect(controller.selection!.start.offset, 0);
    expect(controller.selection!.end.offset, 5);
  });

  testWidgets('triple-tap selects the whole block', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'hello world')],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(controller: controller),
        ),
      ),
    );

    final target = _globalTextOffset(tester, 'hello world', 2);
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pump();

    expect(controller.selection?.isCollapsed, isFalse);
    expect(controller.selection!.start.offset, 0);
    expect(controller.selection!.end.offset, 'hello world'.length);
  });

  // B2: auto-scroll-on-drag. A mouse drag held near a viewport edge drives a
  // per-frame ticker that keeps scrolling and re-extends the selection, so the
  // user can drag-select past the visible area without moving the pointer.
  group('auto-scroll on drag', () {
    // A tall document: many short paragraphs whose combined height exceeds the
    // 150px viewport, so the bottom edge sits mid-document and there is room
    // to scroll down.
    RichTextDocument tallDocument({int count = 30}) => RichTextDocument(
          blocks: List<BlockNode>.generate(
            count,
            (i) => TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'block-$i-content')],
            ),
          ),
        );

    testWidgets('dragging the scrollbar gutter does not start a selection', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child:
                  WenzRichTextEditor(controller: controller, enableIme: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Place an initial collapsed caret in the content so we can detect any
      // spurious change.
      final contentPoint = _globalTextOffset(tester, 'block-0-content', 2);
      await tester.tapAt(contentPoint);
      await tester.pump();
      expect(controller.selection, isNotNull);
      final selectionBefore = controller.selection;

      // Drag vertically inside the trailing scrollbar gutter (rightmost 16px).
      // The gutter is within _kScrollbarGutterWidth of the editor's right edge.
      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      final gutterX = editorBox.right - 8;
      final gesture = await tester.startGesture(
        Offset(gutterX, editorBox.top + 30),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(Offset(gutterX, editorBox.top + 90));
      await gesture.up();
      await tester.pump();

      // The selection must be unchanged — scrolling the thumb is not a content
      // selection drag.
      expect(controller.selection, selectionBefore);
    });

    testWidgets('mouse drag held at the bottom edge keeps scrolling down', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the editor's render box to derive a point inside the bottom edge
      // band (within _autoScrollEdge = 48px of the viewport bottom).
      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      // Start the drag near the top so the drag base is in an early block.
      final dragStart = Offset(editorBox.left + 80, editorBox.top + 20);
      // Hold the pointer just inside the bottom edge.
      final edgePoint = Offset(editorBox.left + 80, editorBox.bottom - 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      // Move into the bottom edge band to arm the auto-scroll ticker.
      await gesture.moveTo(edgePoint);
      await tester.pump();

      final scrollBefore = _scrollOffset(tester);
      final extentBefore = controller.selection!.extent.blockIndex;

      // Hold still and advance frames — the ticker should keep scrolling down
      // even though the pointer is not moving.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scrollAfter = _scrollOffset(tester);
      final extentAfter = controller.selection!.extent.blockIndex;
      expect(scrollAfter, greaterThan(scrollBefore));
      expect(extentAfter, greaterThan(extentBefore));

      await gesture.up();
    });

    testWidgets('mouse drag held at the top edge keeps scrolling up', (
      tester,
    ) async {
      // Seed the caret on a late block so the editor scrolls down on mount,
      // giving us room to scroll back up.
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Jump the caret to a late block; the editor scrolls it into view.
      controller.setSelection(collapsedTextSelection('p25', 25, 0));
      await tester.pumpAndSettle();
      final scrolledDown = _scrollOffset(tester);
      expect(scrolledDown, greaterThan(0));

      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      // Start the drag in the middle, then move up into the top edge band.
      final dragStart = Offset(editorBox.left + 80, editorBox.center.dy);
      final topEdge = Offset(editorBox.left + 80, editorBox.top + 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(topEdge);
      await tester.pump();

      final scrollBefore = _scrollOffset(tester);

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final scrollAfter = _scrollOffset(tester);
      // Scrolled up: the offset decreased.
      expect(scrollAfter, lessThan(scrollBefore));

      await gesture.up();
    });

    testWidgets('releasing the pointer stops the auto-scroll ticker', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: tallDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editorBox = tester.getRect(find.byType(WenzRichTextEditor));
      final dragStart = Offset(editorBox.left + 80, editorBox.top + 20);
      final edgePoint = Offset(editorBox.left + 80, editorBox.bottom - 10);

      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(edgePoint);
      await tester.pump();
      // Let the ticker scroll a bit.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrollBeforeRelease = _scrollOffset(tester);

      // Release the pointer — the ticker must stop.
      await gesture.up();
      await tester.pump();
      final scrollAtRelease = _scrollOffset(tester);

      // Advance more frames; the offset must not change once the pointer is up.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrollAfterRelease = _scrollOffset(tester);

      expect(scrollAtRelease, greaterThan(0));
      expect(scrollAfterRelease, equals(scrollBeforeRelease));
    });
  });

  testWidgets('PageDown moves the caret down by roughly one viewport', (
    tester,
  ) async {
    // Three short paragraphs stacked in a 360px-tall viewport. With the caret
    // at the top of p1, PageDown targets a Y one viewport below (clamped to the
    // viewport bottom) which lands in the last block p3.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.extent.blockId, 'p3');
    expect(controller.selection!.isCollapsed, isTrue);
  });

  testWidgets('PageUp moves the caret up by roughly one viewport', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      // Caret at the end of the last block.
      selection: collapsedTextSelection('p3', 2, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.extent.blockId, 'p1');
    expect(controller.selection!.isCollapsed, isTrue);
  });

  testWidgets('Shift+PageDown extends the selection keeping the anchor', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
          TextBlockNode(
            id: 'p2',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'bbb')],
          ),
          TextBlockNode(
            id: 'p3',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'ccc')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(controller.selection!.isCollapsed, isFalse);
    // Anchor stays on p1; extent jumped down the document.
    expect(controller.selection!.base.blockId, 'p1');
    expect(controller.selection!.extent.blockId, 'p3');
  });

  testWidgets('PageDown at the document bottom stays at the end', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'aaa')],
          ),
        ],
      ),
      selection: collapsedTextSelection('p1', 0, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: WenzRichTextEditor(
              controller: controller,
              autofocus: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    // Single short block: caret cannot move further down — stays at end.
    expect(controller.selection!.extent.blockId, 'p1');
    expect(controller.selection!.extent.offset, 3);
  });

  testWidgets('block renderer registry overrides block rendering', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'real text')],
          ),
          DividerBlockNode(id: 'd1'),
        ],
      ),
    );
    // A registry that replaces the divider renderer with a sentinel Container
    // while keeping the built-in text renderer. The editor should honour the
    // override only for the registered type.
    final registry = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(registry);
    registry.register(
      BlockType.divider,
      (_, __) => const ColoredBox(
        color: Color(0xFF123456),
        child: SizedBox(height: 12, width: double.infinity),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            blockRenderers: registry,
          ),
        ),
      ),
    );
    await tester.pump();

    // The override rendered for the divider.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF123456),
      ),
      findsOneWidget,
    );
    // The built-in text renderer still renders the paragraph (it uses RichText,
    // not a plain Text widget).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'real text',
      ),
      findsOneWidget,
    );
    // The default Divider widget is no longer present.
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets(
    'block renderer registry falls back for unregistered types',
    (tester) async {
      // An empty registry (no defaults installed): every type should fall back
      // to the editor's plain-text fallback rather than crash.
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'fallback me')],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              blockRenderers: BlockRendererRegistry(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('fallback me'), findsOneWidget);
    },
  );

  testWidgets('block embed renderer registry overrides embed type', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          BlockEmbedNode(
            id: 'embed1',
            embedType: 'crm-card',
            data: <String, Object?>{'recordId': '42'},
            fallbackText: 'Acme account',
          ),
        ],
      ),
    );
    final registry = BlockRendererRegistry();
    WenzRichTextEditor.installDefaultRenderers(registry);
    registry.registerEmbed(
      'crm-card',
      (_, renderContext) {
        final embed = renderContext.block as BlockEmbedNode;
        return WenzObjectBlockSurface(
          renderContext: renderContext,
          child: Text('CRM ${embed.data['recordId']}'),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            blockRenderers: registry,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CRM 42'), findsOneWidget);
    expect(find.text('Acme account'), findsNothing);
  });

  // The virtualisation tests use a tall document (500 blocks) in the default
  // 800x600 test viewport, so only a handful of blocks fit on screen. They
  // assert that off-screen blocks are NOT built, and that the caret / selection
  // endpoint blocks stay mounted via AutomaticKeepAlive.

  group('virtualisation', () {
    RichTextDocument bigDocument({int count = 500}) {
      return RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < count; i++)
            TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'block-$i-content')],
            ),
        ],
      );
    }

    RichTextDocument measuredDocument({required bool tallBlock}) {
      return RichTextDocument(
        blocks: <BlockNode>[
          for (var i = 0; i < 60; i++)
            TextBlockNode(
              id: 'p$i',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: tallBlock && i == 35 ? 'tall' : 'short'),
              ],
            ),
        ],
      );
    }

    String plainText(BlockNode block) {
      return (block as TextBlockNode)
          .content
          .whereType<TextRun>()
          .map((run) => run.text)
          .join();
    }

    BlockRendererRegistry measuredBlockRenderers() {
      return BlockRendererRegistry()
        ..register(BlockType.paragraph, (_, renderContext) {
          final block = renderContext.block;
          final text = plainText(block);
          return SizedBox(
            key: ValueKey<String>('measured-${block.id}'),
            height: text == 'tall' ? 320 : 40,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text),
            ),
          );
        });
    }

    RichTextDocument estimateShrinkDocument(String prefix) {
      return RichTextDocument(
        blocks: <BlockNode>[
          for (var index = 0; index < 160; index++)
            TextBlockNode(
              id: '$prefix-p$index',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: index < 19 ? 'tall' : 'short'),
              ],
            ),
        ],
      );
    }

    BlockRendererRegistry estimateShrinkRenderers() {
      return BlockRendererRegistry()
        ..register(BlockType.paragraph, (_, renderContext) {
          final block = renderContext.block;
          final text = plainText(block);
          return SizedBox(
            key: ValueKey<String>('measured-${block.id}'),
            height: text == 'tall' ? 160 : 40,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text),
            ),
          );
        });
    }

    testWidgets('only builds visible blocks for a large document', (
      tester,
    ) async {
      final controller = WenzRichTextController(document: bigDocument());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // The first (visible) block is built (text blocks render as RichText).
      expect(_richText('block-0-content'), findsOneWidget);
      // A far off-screen block is NOT built under virtualisation.
      expect(_richText('block-499-content'), findsNothing);
      expect(_richText('block-400-content'), findsNothing);
    });

    testWidgets('keeps the caret block alive when it is off-screen', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              // Direct key-event character insertion (no IME) keeps the test
              // deterministic.
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // p1 starts visible.
      expect(_richText('block-1-content'), findsOneWidget);

      // Scroll the viewport so p1 leaves the screen.
      await tester.drag(
        find.byType(WenzRichTextEditor),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      // p1 is off-screen now, but it owns the caret so AutomaticKeepAlive
      // keeps it mounted (so the caret still paints / registers geometry).
      expect(_richText('block-1-content'), findsOneWidget);
    });

    testWidgets('keeps both selection endpoints alive across a range', (
      tester,
    ) async {
      // Both endpoints start within the viewport, then the range's far end is
      // scrolled off-screen; it must stay mounted via keep-alive.
      final start = collapsedTextSelection('p0', 0, 0).base;
      final end = DocumentPosition(
        blockId: 'p2',
        blockIndex: 2,
        path: PositionPath.blockText('p2'),
        offset: 0,
      );
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: DocumentSelection(base: start, extent: end),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_richText('block-2-content'), findsOneWidget);

      await tester.drag(
        find.byType(WenzRichTextEditor),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();

      // p2 (an endpoint) stays mounted even though it scrolled off-screen.
      expect(_richText('block-2-content'), findsOneWidget);
    });

    testWidgets('programmatic caret jump scrolls the caret into view', (
      tester,
    ) async {
      // Start with the caret on a visible block near the top.
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sanity: p400 is off-screen before the jump.
      expect(_richText('block-400-content'), findsNothing);

      // Jump the caret to block 400 programmatically.
      controller.setSelection(collapsedTextSelection('p400', 400, 0));
      await tester.pumpAndSettle();

      // After the jump the caret block is scrolled into the viewport — the
      // target block is now built and visible.
      expect(_richText('block-400-content'), findsOneWidget);
    });

    testWidgets('programmatic caret jump moves the scroll offset forward', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: bigDocument(),
        selection: collapsedTextSelection('p0', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Scrollable state to read the offset.
      ScrollableState scrollable() => tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(WenzRichTextEditor),
              matching: find.byType(Scrollable),
            ),
          );
      final offsetBefore = scrollable().position.pixels;
      expect(offsetBefore, 0);

      controller.setSelection(collapsedTextSelection('p450', 450, 0));
      await tester.pumpAndSettle();

      final offsetAfter = scrollable().position.pixels;
      // Scrolled forward to bring the caret into view.
      expect(offsetAfter, greaterThan(offsetBefore));
    });

    testWidgets(
        'expanded heading does not pull user scroll back to unchanged caret',
        (tester) async {
      const preludeCount = 28;
      const hiddenCount = 14;
      const targetIndex = preludeCount + 1 + hiddenCount + 1;
      const tailIndex = targetIndex + 30;
      final controller = WenzRichTextController(
        document: RichTextDocument(
          blocks: <BlockNode>[
            for (var i = 0; i < preludeCount; i++)
              TextBlockNode(
                id: 'prelude-$i',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Prelude $i')],
              ),
            const TextBlockNode(
              id: 'section',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 1),
              content: <InlineNode>[TextRun(text: 'Expandable section')],
            ),
            for (var i = 0; i < hiddenCount; i++)
              TextBlockNode(
                id: 'hidden-$i',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Expanded child $i')],
              ),
            const TextBlockNode(
              id: 'after-section',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 1),
              content: <InlineNode>[TextRun(text: 'After section')],
            ),
            const TextBlockNode(
              id: 'target',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Caret target')],
            ),
            for (var i = 0; i < 34; i++)
              TextBlockNode(
                id: 'tail-$i',
                type: BlockType.paragraph,
                content: <InlineNode>[TextRun(text: 'Tail block $i')],
              ),
          ],
        ),
        selection: collapsedTextSelection('target', targetIndex, 0),
      );
      final outline = WenzOutlineController(editor: controller);
      addTearDown(outline.dispose);
      expect(outline.collapseByBlockId('section'), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                outlineController: outline,
                padding: EdgeInsets.zero,
                blockSpacing: 0,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collapseButton = find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-section'),
      );
      expect(collapseButton, findsOneWidget);
      expect(_scrollOffset(tester), greaterThan(0));

      await tester.tap(collapseButton);
      await tester.pump();
      expect(outline.isCollapsed('section'), isFalse);

      var previousOffset = _scrollOffset(tester);
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(WenzRichTextEditor),
          const Offset(0, 70),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final currentOffset = _scrollOffset(tester);
        expect(currentOffset, lessThan(previousOffset));
        previousOffset = currentOffset;
      }

      final userScrolledOffset = previousOffset;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(
        _scrollOffset(tester),
        moreOrLessEquals(userScrolledOffset, epsilon: 1),
      );
      expect(
        controller.selection,
        collapsedTextSelection('target', targetIndex, 0),
      );

      controller.setSelection(collapsedTextSelection('tail-29', tailIndex, 0));
      await tester.pumpAndSettle();

      expect(_scrollOffset(tester), greaterThan(userScrolledOffset));
      expect(
        controller.selection,
        collapsedTextSelection('tail-29', tailIndex, 0),
      );
    });

    testWidgets('updates scroll metrics from measured block extent cache', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: measuredDocument(tallBlock: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                padding: EdgeInsets.zero,
                blockSpacing: 0,
                blockRenderers: measuredBlockRenderers(),
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      ScrollableState scrollable() => tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(WenzRichTextEditor),
              matching: find.byType(Scrollable),
            ),
          );

      expect(
        find.byKey(const ValueKey<String>('measured-p35')),
        findsNothing,
      );
      final maxBeforeTallMeasured = scrollable().position.maxScrollExtent;

      scrollable().position.jumpTo(1400);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('measured-p35')),
        findsOneWidget,
      );
      final maxAfterTallMeasured = scrollable().position.maxScrollExtent;
      expect(
        maxAfterTallMeasured,
        greaterThan(maxBeforeTallMeasured + 200),
      );

      final diagnosticMessages = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          diagnosticMessages.add(message);
        }
        originalDebugPrint(message, wrapWidth: wrapWidth);
      };
      try {
        controller.replaceDocument(measuredDocument(tallBlock: false));
        await tester.pumpAndSettle();
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(
        scrollable().position.maxScrollExtent,
        lessThan(maxAfterTallMeasured - 200),
      );
      expect(
        diagnosticMessages,
        contains(
          allOf(
            contains('event=viewport-in-overestimated-block-gap'),
            contains('blockId=p35'),
            contains('oldEstimate=320.0'),
            contains('measured=40.0'),
          ),
        ),
      );
    });

    testWidgets(
      'pre-clamps the virtual window across two shrinking extent jumps',
      (tester) async {
        for (var run = 0; run < 2; run++) {
          final prefix = 'preclamp-$run';
          final controller = WenzRichTextController(
            document: estimateShrinkDocument(prefix),
          );
          final renderers = estimateShrinkRenderers();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: WenzRichTextEditor(
                    key: ValueKey<String>('preclamp-editor-$run'),
                    controller: controller,
                    padding: EdgeInsets.zero,
                    blockSpacing: 0,
                    blockRenderers: renderers,
                    enableIme: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final scrollable = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(WenzRichTextEditor),
              matching: find.byType(Scrollable),
            ),
          );
          final maxBeforeJump = scrollable.position.maxScrollExtent;
          expect(maxBeforeJump, greaterThan(20000));

          final drag = scrollable.position.drag(
            DragStartDetails(globalPosition: Offset.zero),
            () {},
          );
          drag.update(
            DragUpdateDetails(
              globalPosition: Offset.zero,
              delta: Offset(0, -maxBeforeJump),
              primaryDelta: -maxBeforeJump,
            ),
          );
          await tester.pump();
          final staleOffset = scrollable.position.pixels;

          // The first target frame measures the short tail blocks. The next
          // frame must build its virtual window from the smaller predicted max
          // before SingleChildScrollView applies that max during layout.
          await tester.pump();
          final correctedMax = scrollable.position.maxScrollExtent;
          drag.end(DragEndDetails(primaryVelocity: 0));
          expect(staleOffset - correctedMax, greaterThan(300));
          expect(
            scrollable.position.pixels,
            lessThanOrEqualTo(correctedMax + 0.5),
          );

          final mountedTailBlocks = find.byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('measured-$prefix-');
          });
          expect(mountedTailBlocks.evaluate().length, greaterThan(1));

          final viewport = tester.getRect(find.byType(WenzRichTextEditor));
          var coveredHeight = 0.0;
          for (var index = 0; index < 160; index++) {
            final block = find.byKey(
              ValueKey<String>('measured-$prefix-p$index'),
            );
            if (block.evaluate().isEmpty) {
              continue;
            }
            final rect = tester.getRect(block);
            coveredHeight += math.max(
              0.0,
              math.min(rect.bottom, viewport.bottom) -
                  math.max(rect.top, viewport.top),
            );
          }
          expect(
            coveredHeight,
            greaterThan(200),
            reason: 'run $run must not paint an empty corrected viewport',
          );

          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'keeps upward wheel displacement stable while extents converge',
      (tester) async {
        for (var run = 0; run < 2; run++) {
          final prefix = 'wheel-anchor-$run';
          final controller = WenzRichTextController(
            document: estimateShrinkDocument(prefix),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: WenzRichTextEditor(
                    key: ValueKey<String>('wheel-anchor-editor-$run'),
                    controller: controller,
                    padding: EdgeInsets.zero,
                    blockSpacing: 0,
                    blockRenderers: estimateShrinkRenderers(),
                    enableIme: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final scrollable = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(WenzRichTextEditor),
              matching: find.byType(Scrollable),
            ),
          );
          final maxBeforeJump = scrollable.position.maxScrollExtent;
          final drag = scrollable.position.drag(
            DragStartDetails(globalPosition: Offset.zero),
            () {},
          );
          drag.update(
            DragUpdateDetails(
              globalPosition: Offset.zero,
              delta: Offset(0, -maxBeforeJump),
              primaryDelta: -maxBeforeJump,
            ),
          );
          await tester.pump();
          await tester.pump();
          drag.end(DragEndDetails(primaryVelocity: 0));
          await tester.pumpAndSettle();

          final viewport = tester.getRect(find.byType(WenzRichTextEditor));
          Finder? trackedBlock;
          Rect? trackedRect;
          for (var index = 159; index >= 0; index--) {
            final candidate = find.byKey(
              ValueKey<String>('measured-$prefix-p$index'),
            );
            if (candidate.evaluate().isEmpty) {
              continue;
            }
            final rect = tester.getRect(candidate);
            if (rect.top >= viewport.top + 50 &&
                rect.bottom <= viewport.bottom - 120) {
              trackedBlock = candidate;
              trackedRect = rect;
              break;
            }
          }
          expect(trackedBlock, isNotNull);
          expect(trackedRect, isNotNull);
          final topBeforeWheel = trackedRect!.top;

          scrollable.position.pointerScroll(-120);
          // Sample at the end of layout/paint but before the measured-extent
          // post-frame callbacks update the layout index. A correction runs in
          // the following microtask and is consumed atomically by the next
          // frame, so this is the position a user actually sees at each vsync.
          for (var frame = 0; frame < 4; frame++) {
            Rect? paintedRect;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (trackedBlock!.evaluate().isNotEmpty) {
                paintedRect = tester.getRect(trackedBlock);
              }
            });
            await tester.pump();
            expect(trackedBlock, findsOneWidget);
            expect(paintedRect, isNotNull);
            final topAfterWheel = paintedRect!.top;
            expect(
              topAfterWheel - topBeforeWheel,
              closeTo(120, 1),
              reason: 'run $run frame $frame added layout drift',
            );
          }
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets('shrinks cached block extent after deleting content', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p0',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'tall')],
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'short')],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: WenzRichTextEditor(
                controller: controller,
                padding: EdgeInsets.zero,
                blockSpacing: 0,
                blockRenderers: measuredBlockRenderers(),
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final secondBlock = find.byKey(
        const ValueKey<String>('measured-p1'),
      );
      expect(tester.getTopLeft(secondBlock).dy, 320);

      controller.setSelection(textSelection('p0', 0, 0, 4));
      controller.deleteSelection();
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(secondBlock).dy, 40);
    });
  });

  group('link hover and Ctrl/Cmd+click interaction', () {
    testWidgets('hovering a link shows the edit/open overlay above it',
        (tester) async {
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {});
      final linkTop = _textRangeGlobalRect(
        tester,
        _kLinkRenderedText,
        _kLinkStart,
        _kLinkEnd,
      ).top;
      await _hoverMouseAt(tester, _linkPoint(tester));

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('打开'), findsOneWidget);
      // The popup anchors above the link run, so its bottom edge sits at or
      // above the link's top edge.
      final popupBottom = tester.getRect(find.text('打开')).bottom;
      expect(popupBottom, lessThanOrEqualTo(linkTop + 1.0));
    });

    testWidgets('overlay hides after a delay once the pointer leaves the link',
        (tester) async {
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {});
      final gesture = await _hoverMouseAt(tester, _linkPoint(tester));
      expect(find.text('打开'), findsOneWidget);

      // Move onto plain (non-link) text and advance past the hide delay.
      await gesture.moveTo(_plainTextPoint(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('打开'), findsNothing);
    });

    testWidgets(
        'overlay stays when the pointer travels onto it and hides after leaving both',
        (tester) async {
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {});
      final gesture = await _hoverMouseAt(tester, _linkPoint(tester));
      expect(find.text('打开'), findsOneWidget);

      // Travelling onto the popup must keep it alive past the hide delay so the
      // user can reach the actions.
      await gesture.moveTo(tester.getCenter(find.text('打开')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('打开'), findsOneWidget);

      // Leaving both the link text and the popup dismisses it.
      await gesture.moveTo(_plainTextPoint(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('打开'), findsNothing);
    });

    testWidgets('Ctrl+click opens the link without moving the caret',
        (tester) async {
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      final controller =
          await _pumpLinkEditor(tester, onOpenLink: (url, position) {
        opens.add(url);
        positions.add(position);
      });
      controller.setSelection(collapsedTextSelection('p-link', 0, 0));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouseClickAt(tester, _linkPoint(tester));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(opens, <String>[_kLinkUrl]);
      expect(positions.single.blockId, 'p-link');
      expect(positions.single.blockIndex, 0);
      expect(positions.single.path, PositionPath.blockText('p-link'));
      expect(positions.single.offset, _kLinkStart);
      // The caret stays put — modifier+click suppresses caret/selection setup.
      final selection = controller.selection;
      expect(selection, isNotNull);
      expect(selection!.extent.blockId, 'p-link');
      expect(selection.extent.offset, 0);
      expect(selection.isCollapsed, isTrue);
    });

    testWidgets('Cmd+click (macOS variant) also opens the link',
        (tester) async {
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {
        opens.add(url);
        positions.add(position);
      });

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await _mouseClickAt(tester, _linkPoint(tester));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(opens, <String>[_kLinkUrl]);
      expect(positions.single.blockId, 'p-link');
      expect(positions.single.blockIndex, 0);
      expect(positions.single.path, PositionPath.blockText('p-link'));
      expect(positions.single.offset, _kLinkStart);
    });

    testWidgets('a plain click on a link places the caret without opening it',
        (tester) async {
      final opens = <String>[];
      final controller =
          await _pumpLinkEditor(tester, onOpenLink: (url, position) {
        opens.add(url);
      });

      await _tapSingle(tester, _linkPoint(tester));

      expect(opens, isEmpty);
      final selection = controller.selection;
      expect(selection, isNotNull);
      expect(selection!.extent.blockId, 'p-link');
      // The caret lands somewhere inside the link run [_kLinkStart, _kLinkEnd).
      expect(selection.extent.offset, greaterThanOrEqualTo(_kLinkStart));
      expect(selection.extent.offset, lessThan(_kLinkEnd));
      expect(selection.isCollapsed, isTrue);
    });

    testWidgets('overlay Open action invokes onOpenLink and dismisses',
        (tester) async {
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {
        opens.add(url);
        positions.add(position);
      });
      await _hoverMouseAt(tester, _linkPoint(tester));
      expect(find.text('打开'), findsOneWidget);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(opens, <String>[_kLinkUrl]);
      expect(positions.single.blockId, 'p-link');
      expect(positions.single.blockIndex, 0);
      expect(positions.single.path, PositionPath.blockText('p-link'));
      expect(positions.single.offset, _kLinkStart);
      expect(find.text('打开'), findsNothing);
    });

    testWidgets('overlay Edit applies a new URL to the link run',
        (tester) async {
      final controller = await _pumpLinkEditor(tester);
      await _hoverMouseAt(tester, _linkPoint(tester));

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('链接地址'), findsWidgets);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('wenz-link-edit-dialog')),
          matching: find.byType(TextField),
        ),
        'https://new.example',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();

      expect(_linkUrlInBlock(controller), 'https://new.example');
    });

    testWidgets('overlay Edit Remove clears the link URL', (tester) async {
      final controller = await _pumpLinkEditor(tester);
      await _hoverMouseAt(tester, _linkPoint(tester));

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      expect(_linkUrlInBlock(controller), isNull);
    });

    testWidgets('hovering non-link text shows no overlay', (tester) async {
      await _pumpLinkEditor(tester, onOpenLink: (url, position) {});

      await _hoverMouseAt(tester, _plainTextPoint(tester));
      expect(find.text('编辑'), findsNothing);
      expect(find.text('打开'), findsNothing);

      // Hovering the link afterwards still reveals the overlay.
      await _hoverMouseAt(tester, _linkPoint(tester));
      expect(find.text('打开'), findsOneWidget);
    });

    testWidgets('read-only overlay hides Edit and keeps Open', (tester) async {
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      await _pumpLinkEditor(
        tester,
        readOnly: true,
        onOpenLink: (url, position) {
          opens.add(url);
          positions.add(position);
        },
      );
      await _hoverMouseAt(tester, _linkPoint(tester));

      expect(find.text('编辑'), findsNothing);
      expect(find.text('打开'), findsOneWidget);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(opens, <String>[_kLinkUrl]);
      expect(positions.single.offset, _kLinkStart);
    });

    testWidgets('overlay Open is disabled when onOpenLink is null',
        (tester) async {
      final controller = await _pumpLinkEditor(tester);
      await _hoverMouseAt(tester, _linkPoint(tester));

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('打开'), findsOneWidget);
      final openAction = find.ancestor(
        of: find.text('打开'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(openAction).onTap, isNull);

      controller.setSelection(collapsedTextSelection('p-link', 0, 0));
      await tester.pumpAndSettle();

      await _tapSingle(tester, _linkPoint(tester));

      final selection = controller.selection;
      expect(selection, isNotNull);
      expect(selection!.extent.blockId, 'p-link');
      expect(selection.extent.offset, greaterThanOrEqualTo(_kLinkStart));
      expect(selection.extent.offset, lessThan(_kLinkEnd));
      expect(selection.isCollapsed, isTrue);
    });

    testWidgets('a link split across same-url runs resolves to one range',
        (tester) async {
      const rendered = 'abcdef';
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p-merge',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'a'),
                TextRun(
                  text: 'bc',
                  attributes: TextAttributes(url: 'https://merge.example'),
                ),
                TextRun(
                  text: 'de',
                  attributes: TextAttributes(url: 'https://merge.example'),
                ),
                TextRun(text: 'f'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
              onOpenLink: (url, position) {
                opens.add(url);
                positions.add(position);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mergedLinkPoint = _globalTextRangePoint(
        tester,
        rendered,
        1,
        5,
        0.5,
      );
      await _hoverMouseAt(
        tester,
        mergedLinkPoint,
      );
      expect(find.text('打开'), findsOneWidget);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(opens, <String>['https://merge.example']);
      expect(positions.single.blockId, 'p-merge');
      expect(positions.single.offset, 1);

      await _hoverMouseAt(tester, mergedLinkPoint);
      expect(find.text('编辑'), findsOneWidget);

      // Edit selects the full merged run [1, 5), proving the two same-url runs
      // collapsed into a single range.
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final selection = controller.selection;
      expect(selection, isNotNull);
      expect(selection!.start.offset, 1);
      expect(selection.end.offset, 5);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouseClickAt(tester, mergedLinkPoint);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(opens, <String>[
        'https://merge.example',
        'https://merge.example',
      ]);
      expect(positions.last.offset, 1);
    });

    testWidgets('a link inside a table cell hovers and opens on Ctrl+click',
        (tester) async {
      const cellText = 'go docs';
      final opens = <String>[];
      final positions = <DocumentPosition>[];
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table1',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'cell1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'cell-p1',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'go '),
                            TextRun(
                              text: 'docs',
                              attributes: TextAttributes(
                                url: 'https://table.example',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
                onOpenLink: (url, position) {
                  opens.add(url);
                  positions.add(position);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cellLinkPoint = _globalTextRangePoint(tester, cellText, 3, 7, 0.5);
      await _hoverMouseAt(tester, cellLinkPoint);
      expect(find.text('打开'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _mouseClickAt(tester, cellLinkPoint);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(opens, <String>['https://table.example']);
      expect(positions.single.blockId, 'table1');
      expect(positions.single.blockIndex, 0);
      expect(positions.single.path.isTableCellText, isTrue);
      expect(positions.single.path.tableRowIndex, 0);
      expect(positions.single.path.tableColumnIndex, 0);
      expect(positions.single.offset, 3);
    });
  });

  group('block toolbar button transparent background', () {
    void expectTransparentToolbarButtonBackground(
      WidgetTester tester,
      String tooltip,
    ) {
      final buttonStyle = _toolbarButtonStyleForTooltip(tester, tooltip);
      expect(buttonStyle, isNotNull);
      for (final states in <Set<WidgetState>>[
        <WidgetState>{},
        <WidgetState>{WidgetState.disabled},
        <WidgetState>{WidgetState.hovered},
        <WidgetState>{WidgetState.pressed},
      ]) {
        final background = buttonStyle!.backgroundColor?.resolve(states);
        expect(
          background,
          Colors.transparent,
          reason: '$tooltip should not draw an independent capsule background.',
        );
      }
    }

    void expectToolbarButtonHoverOverlay(
      WidgetTester tester,
      String tooltip,
    ) {
      final buttonStyle = _toolbarButtonStyleForTooltip(tester, tooltip);
      expect(buttonStyle, isNotNull);
      for (final states in <Set<WidgetState>>[
        <WidgetState>{WidgetState.hovered},
        <WidgetState>{WidgetState.pressed},
      ]) {
        final overlay = buttonStyle!.overlayColor?.resolve(states);
        expect(overlay, isNotNull);
        expect(
          overlay,
          isNot(Colors.transparent),
          reason: '$tooltip should keep hover/pressed feedback visible.',
        );
      }
    }

    testWidgets('media object toolbar buttons transparent background', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            ImageBlockNode(
              id: 'img1',
              assetId: 'hero',
              file: 'hero.png',
              width: 640,
              height: 320,
              showWidth: 180,
              showHeight: 90,
            ),
          ],
        ),
        selection: objectBlockSelection('img1', 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('预览媒体'), findsOneWidget);
      expect(find.byTooltip('更多块操作'), findsOneWidget);
      expectTransparentToolbarButtonBackground(tester, '预览媒体');
      expectTransparentToolbarButtonBackground(tester, '更多块操作');
      expectToolbarButtonHoverOverlay(tester, '预览媒体');
      expectToolbarButtonHoverOverlay(tester, '更多块操作');
      // Shared surface provides the conjoined capsule background.
      _expectMinimalToolbarSurface(tester, find.byTooltip('预览媒体'));
    });

    testWidgets('table floating toolbar buttons transparent background', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: _toolbarTableDocument(),
        selection: _tableCellSelection(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 360,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await _pumpTableToolbarOverlay(tester);

      expect(find.byTooltip('在下方插入行'), findsOneWidget);
      expect(find.byTooltip('在右侧插入列'), findsOneWidget);
      expect(find.byTooltip('更多表格操作'), findsOneWidget);
      expectTransparentToolbarButtonBackground(tester, '在下方插入行');
      expectTransparentToolbarButtonBackground(tester, '在右侧插入列');
      expectTransparentToolbarButtonBackground(tester, '更多表格操作');
      expectToolbarButtonHoverOverlay(tester, '在下方插入行');
      expectToolbarButtonHoverOverlay(tester, '更多表格操作');
      // Shared surface provides the conjoined capsule background.
      final toolbarFinder = find.byKey(
        const ValueKey<String>('table-floating-toolbar'),
      );
      _expectMinimalToolbarSurface(tester, toolbarFinder);
    });

    testWidgets('file block action menu button transparent background', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            FileBlockNode(
              id: 'file1',
              assetId: 'file-1',
              name: 'brief.pdf',
              size: 4096,
              mimeType: 'application/pdf',
              uploadStatus: FileUploadStatus.uploading,
            ),
          ],
        ),
        selection: objectBlockSelection('file1', 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('附件操作'), findsOneWidget);
      expectTransparentToolbarButtonBackground(tester, '附件操作');
      expectToolbarButtonHoverOverlay(tester, '附件操作');
      // Shared surface provides the conjoined capsule background.
      _expectMinimalToolbarSurface(tester, find.byTooltip('附件操作'));
    });
  });

  group('table cell alignment selection', () {
    testWidgets('centred collapsed table cell caret uses text layout position',
        (
      tester,
    ) async {
      const text = 'Centered caret';
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'tbl-caret',
              table: TableModel(
                columnWidths: <int, double>{0: 320},
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'caret-cell',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'caret-cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: text)],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'tbl-caret',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'tbl-caret',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 380,
              height: 180,
              child: WenzRichTextEditor(
                controller: controller,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('wenz-richtext-caret')),
        findsOneWidget,
      );
      final cellRect = tester.getRect(_tableCellFinder('tbl-caret', 0, 0));
      final expectedCaret = _richTextCaretTopLeft(tester, text, 0);
      final paintedCaret = _caretPainterGlobalTopLeft(tester);

      expect(
        paintedCaret.dx,
        moreOrLessEquals(expectedCaret.dx, epsilon: 1),
      );
      expect(
        paintedCaret.dx,
        greaterThan(cellRect.left + 48),
        reason: 'center-aligned caret must not sit at the cell left padding',
      );
    });

    testWidgets('centred single-cell text selection only paints text highlight',
        (tester) async {
      const selectedText = 'Centered local';
      const neighbourText = 'Neighbour';
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'tbl-center-local',
              table: TableModel(
                columnWidths: <int, double>{0: 220, 1: 220},
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'center-cell',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'center-cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: selectedText)],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'neighbour-cell',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'neighbour-cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: neighbourText)],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        selection: DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'tbl-center-local',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'tbl-center-local',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 8,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 180,
              child: WenzRichTextEditor(
                controller: controller,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _tableCellHasWholeSelectionHighlight(
          tester,
          'tbl-center-local',
          0,
          0,
        ),
        isFalse,
      );
      expect(
        _tableCellHasTextSelectionHighlight(
          tester,
          'tbl-center-local',
          0,
          0,
        ),
        isTrue,
      );
      expect(
        _tableCellHasTextSelectionHighlight(
          tester,
          'tbl-center-local',
          0,
          1,
        ),
        isFalse,
      );
      expect(
        _textSelectionHighlightedTableCells(
          tester,
          'tbl-center-local',
          rowCount: 1,
          columnCount: 2,
        ),
        <String>{'0,0'},
      );

      final cellRect =
          tester.getRect(_tableCellFinder('tbl-center-local', 0, 0));
      final neighbourRect =
          tester.getRect(_tableCellFinder('tbl-center-local', 0, 1));
      final expectedRect = _textRangeGlobalRect(tester, selectedText, 0, 8);
      final paintedRect = _textSelectionHighlightGlobalRect(
        tester,
        'tbl-center-local',
        0,
        0,
      );
      _expectRectClose(paintedRect, expectedRect, epsilon: 1);
      expect(
        paintedRect.left,
        greaterThan(cellRect.left + 48),
        reason: 'centered highlight must not use the cell left padding origin',
      );
      expect(paintedRect.right, lessThan(neighbourRect.left));
    });

    testWidgets(
      'centred reverse text selection keeps centred highlight geometry',
      (tester) async {
        const text = 'Reverse centered text';
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TableBlockNode(
                id: 'tbl-center-reverse',
                table: TableModel(
                  columnWidths: <int, double>{0: 300},
                  rows: <List<TableCellNode>>[
                    <TableCellNode>[
                      TableCellNode(
                        id: 'reverse-cell',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'reverse-cell-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: text)],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          selection: DocumentSelection(
            base: DocumentPosition.tableCell(
              tableBlockId: 'tbl-center-reverse',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: text.length,
            ),
            extent: DocumentPosition.tableCell(
              tableBlockId: 'tbl-center-reverse',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: 4,
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 180,
                child: WenzRichTextEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          _tableCellHasWholeSelectionHighlight(
            tester,
            'tbl-center-reverse',
            0,
            0,
          ),
          isFalse,
        );
        expect(
          _textSelectionHighlightedTableCells(
            tester,
            'tbl-center-reverse',
            rowCount: 1,
            columnCount: 1,
          ),
          <String>{'0,0'},
        );

        final cellRect =
            tester.getRect(_tableCellFinder('tbl-center-reverse', 0, 0));
        final expectedRect = _textRangeGlobalRect(tester, text, 4, text.length);
        final paintedRect = _textSelectionHighlightGlobalRect(
          tester,
          'tbl-center-reverse',
          0,
          0,
        );
        _expectRectClose(paintedRect, expectedRect, epsilon: 1);
        expect(
          paintedRect.left,
          greaterThan(cellRect.left + 48),
          reason: 'reverse selection should keep the centered text origin',
        );
        expect(paintedRect.right, lessThan(cellRect.right));
      },
    );

    testWidgets(
      'cross-cell selection from centred endpoints paints whole cells only',
      (tester) async {
        const leftText = 'Center A';
        const rightText = 'Center B';
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TableBlockNode(
                id: 'tbl-center-cross',
                table: TableModel(
                  columnWidths: <int, double>{0: 210, 1: 210},
                  rows: <List<TableCellNode>>[
                    <TableCellNode>[
                      TableCellNode(
                        id: 'cross-left',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'cross-left-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: leftText)],
                          ),
                        ],
                      ),
                      TableCellNode(
                        id: 'cross-right',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'cross-right-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: rightText)],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          selection: DocumentSelection(
            base: DocumentPosition.tableCell(
              tableBlockId: 'tbl-center-cross',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: 2,
            ),
            extent: DocumentPosition.tableCell(
              tableBlockId: 'tbl-center-cross',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 1,
              offset: 5,
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 480,
                height: 180,
                child: WenzRichTextEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final range = controller.selection?.tableCellRange;
        expect(range, isNotNull);
        expect(range!.isSingleCell, isFalse);
        expect(
          _wholeCellHighlightedTableCells(
            tester,
            'tbl-center-cross',
            rowCount: 1,
            columnCount: 2,
          ),
          <String>{'0,0', '0,1'},
        );
        expect(
          _textSelectionHighlightedTableCells(
            tester,
            'tbl-center-cross',
            rowCount: 1,
            columnCount: 2,
          ),
          isEmpty,
        );
      },
    );

    testWidgets('centred cell text selection highlights cell', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'tbl',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c0',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c0-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Centered text'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set a text selection inside the centred cell.
      controller.setSelection(
        DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 8,
          ),
        ),
      );
      await tester.pump();

      // The centred cell should be marked as selected in semantics.
      expect(
        find.bySemanticsLabel(
          'Table cell row 1 column 1',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('selected'),
        findsWidgets,
      );
    });

    testWidgets('right-aligned cell text selection highlights cell', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'tbl',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'c0',
                      alignment: 'right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'c0-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Right text'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set a text selection inside the right-aligned cell.
      controller.setSelection(
        DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 5,
          ),
        ),
      );
      await tester.pump();

      // The right-aligned cell should be marked as selected.
      expect(
        find.bySemanticsLabel(
          'Table cell row 1 column 1',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('selected'),
        findsWidgets,
      );
    });

    testWidgets('cross-cell selection with merged cells highlights correctly', (
      tester,
    ) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'tbl',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'merged',
                      rowSpan: 2,
                      columnSpan: 2,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merged-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'A')],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'c-covered1', covered: true),
                    TableCellNode(
                      id: 'c-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'right-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'B')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(id: 'c-covered2', covered: true),
                    TableCellNode(id: 'c-covered3', covered: true),
                    TableCellNode(
                      id: 'c-bottom-right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'br-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'C')],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Select from the merged cell (0,0) to bottom-right (1,2).
      controller.setSelection(
        DocumentSelection(
          base: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'tbl',
            blockIndex: 0,
            tableRowIndex: 1,
            tableColumnIndex: 2,
            offset: 0,
          ),
        ),
      );
      await tester.pump();

      // Covered cells should NOT have semantics labels (they render
      // SizedBox.shrink). Only the merged cell (0,0), right cell (0,2),
      // and bottom-right cell (1,2) should have selection state.
      expect(
        find.bySemanticsLabel('spans 2 rows, spans 2 columns'),
        findsOneWidget,
      );

      // Verify the selection range respects visual layout.
      final range = controller.selection!.tableCellRange;
      expect(range, isNotNull);
      expect(range!.startRow, 0);
      expect(range.endRow, 1);
      expect(range.startColumn, 0);
      expect(range.endColumn, 2);
    });

    testWidgets(
      'mixed alignment cross-cell selection preserves per-cell state',
      (tester) async {
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TableBlockNode(
                id: 'tbl',
                table: TableModel(
                  rows: <List<TableCellNode>>[
                    <TableCellNode>[
                      TableCellNode(
                        id: 'c-left',
                        alignment: 'left',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'left-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: 'Left')],
                          ),
                        ],
                      ),
                      TableCellNode(
                        id: 'c-center',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'center-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: 'Center')],
                          ),
                        ],
                      ),
                    ],
                    <TableCellNode>[
                      TableCellNode(
                        id: 'c-right',
                        alignment: 'right',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'right-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: 'Right')],
                          ),
                        ],
                      ),
                      TableCellNode(
                        id: 'c-default',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'default-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: 'Default')],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: WenzRichTextEditor(
                  controller: controller,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Select from left-aligned (0,0) to default (1,1) — full 2×2 range.
        controller.setSelection(
          DocumentSelection(
            base: DocumentPosition.tableCell(
              tableBlockId: 'tbl',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: 0,
            ),
            extent: DocumentPosition.tableCell(
              tableBlockId: 'tbl',
              blockIndex: 0,
              tableRowIndex: 1,
              tableColumnIndex: 1,
              offset: 0,
            ),
          ),
        );
        await tester.pump();

        // All four cells should be in a multi-cell selection range.
        final range = controller.selection!.tableCellRange;
        expect(range, isNotNull);
        expect(range!.isSingleCell, isFalse);

        // Semantics labels for all 4 cells should include 'selected'.
        expect(
          find.bySemanticsLabel(
            'Table cell row 1 column 1',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Table cell row 1 column 2',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Table cell row 2 column 1',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Table cell row 2 column 2',
          ),
          findsOneWidget,
        );

        // Verify cell alignment is preserved after selection.
        final table =
            controller.document.blocks.whereType<TableBlockNode>().single;
        expect(table.table.cellAt(0, 0)?.alignment, 'left');
        expect(table.table.cellAt(0, 1)?.alignment, 'center');
        expect(table.table.cellAt(1, 0)?.alignment, 'right');
        expect(table.table.cellAt(1, 1)?.alignment, isNull);
      },
    );

    testWidgets(
      'pixel-constrained multi-cell selection skips indexed outside cell',
      (tester) async {
        const startText = 'Right anchor';
        const topEndText = 'Top center';
        const middleText = 'Right middle';
        const endText = 'Center end\nwrap';
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TableBlockNode(
                id: 'tbl-pixel',
                table: TableModel(
                  columnWidths: <int, double>{0: 160, 1: 160, 2: 160},
                  rows: <List<TableCellNode>>[
                    <TableCellNode>[
                      TableCellNode(
                        id: 'p-r0-c0',
                        columnSpan: 2,
                        alignment: 'right',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'p-r0-c0-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: startText)],
                          ),
                        ],
                      ),
                      TableCellNode(id: 'p-r0-c1', covered: true),
                      TableCellNode(
                        id: 'p-r0-c2',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'p-r0-c2-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: topEndText)],
                          ),
                        ],
                      ),
                    ],
                    <TableCellNode>[
                      TableCellNode(
                        id: 'p-r1-c0',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'p-r1-c0-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[],
                          ),
                        ],
                      ),
                      TableCellNode(
                        id: 'p-r1-c1',
                        alignment: 'right',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'p-r1-c1-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: middleText)],
                          ),
                        ],
                      ),
                      TableCellNode(
                        id: 'p-r1-c2',
                        alignment: 'center',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'p-r1-c2-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: endText)],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 520,
                height: 280,
                child: WenzRichTextEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final start = _globalTextOffset(tester, startText, startText.length);
        final end = _globalTextOffset(tester, endText, 6);

        Future<Set<String>> dragAndReadHighlights(
          Offset dragStart,
          Offset dragEnd,
        ) async {
          await tester.dragFrom(dragStart, dragEnd - dragStart);
          await tester.pump();
          return _wholeCellHighlightedTableCells(
            tester,
            'tbl-pixel',
            rowCount: 2,
            columnCount: 3,
          );
        }

        final forwardHighlights = await dragAndReadHighlights(start, end);
        final range = controller.selection?.tableCellRange;
        expect(range, isNotNull);
        expect(range!.containsCell(1, 0), isTrue);
        expect(forwardHighlights, <String>{'0,0', '0,2', '1,1', '1,2'});
        expect(
          _textSelectionHighlightedTableCells(
            tester,
            'tbl-pixel',
            rowCount: 2,
            columnCount: 3,
          ),
          isEmpty,
        );
        expect(
          _tableCellHasWholeSelectionHighlight(tester, 'tbl-pixel', 1, 0),
          isFalse,
        );
        expect(
          find.byKey(
            const ValueKey<String>('table-cell-border-tbl-pixel-0-1'),
          ),
          findsNothing,
        );

        final reverseHighlights = await dragAndReadHighlights(end, start);
        expect(reverseHighlights, forwardHighlights);
        expect(
          _textSelectionHighlightedTableCells(
            tester,
            'tbl-pixel',
            rowCount: 2,
            columnCount: 3,
          ),
          isEmpty,
        );
      },
    );

    testWidgets(
      'single aligned cell text selection keeps whole-cell highlight off',
      (tester) async {
        const text = 'Right local selection';
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              TableBlockNode(
                id: 'tbl-local',
                table: TableModel(
                  rows: <List<TableCellNode>>[
                    <TableCellNode>[
                      TableCellNode(
                        id: 'local-cell',
                        alignment: 'right',
                        blocks: <BlockNode>[
                          TextBlockNode(
                            id: 'local-cell-text',
                            type: BlockType.paragraph,
                            content: <InlineNode>[TextRun(text: text)],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          selection: DocumentSelection(
            base: DocumentPosition.tableCell(
              tableBlockId: 'tbl-local',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: 0,
            ),
            extent: DocumentPosition.tableCell(
              tableBlockId: 'tbl-local',
              blockIndex: 0,
              tableRowIndex: 0,
              tableColumnIndex: 0,
              offset: 5,
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 420,
                height: 180,
                child: WenzRichTextEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  enableIme: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          _tableCellHasWholeSelectionHighlight(tester, 'tbl-local', 0, 0),
          isFalse,
        );
        expect(
          _tableCellHasTextSelectionHighlight(tester, 'tbl-local', 0, 0),
          isTrue,
        );
        final cellRect = tester.getRect(_tableCellFinder('tbl-local', 0, 0));
        final selectionRect = _textRangeGlobalRect(tester, text, 0, 5);
        expect(selectionRect.left, greaterThan(cellRect.center.dx));
        expect(selectionRect.right, lessThan(cellRect.right));
      },
    );
  });

  group('Tab indent / Shift+Tab outdent', () {
    testWidgets('Tab indents a paragraph block', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 1);
    });

    testWidgets('Shift+Tab outdents an indented paragraph', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              attributes: BlockAttributes(indent: 2),
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 1);
    });

    testWidgets('Tab at max indent 8 does nothing', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              attributes: BlockAttributes(indent: 8),
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 8);
    });

    testWidgets('Shift+Tab at indent 0 does nothing', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, isNull);
    });

    testWidgets('Tab does not indent in read-only mode', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              readOnly: true,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, isNull);
    });

    testWidgets(
      'Tab in code block uses indentCodeBlock not block indent',
      (tester) async {
        const code = 'line1\nline2';
        final controller = WenzRichTextController(
          document: const RichTextDocument(
            blocks: <BlockNode>[
              CodeBlockNode(id: 'c1', code: code),
            ],
          ),
          selection: collapsedCodeSelection('c1', 0, code.length),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WenzRichTextEditor(
                controller: controller,
                enableIme: false,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        // Code block content should be indented, not block-level indent.
        final codeBlock = controller.document.blocks.first as CodeBlockNode;
        expect(codeBlock.code, 'line1\n  line2');
      },
    );

    testWidgets('indent can be undone and redone', (tester) async {
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Hello')],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Indent twice.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      var block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 2);

      // Undo — indent should go from 2 to 1.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 1);

      // Redo — indent should go back to 2.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      block = controller.document.blocks.first as TextBlockNode;
      expect(block.attributes.indent, 2);
    });
  });

  testWidgets(
    'leaf heading hides collapse button when canCollapse is false',
    (tester) async {
      // A heading block with no child content must not mount a disabled
      // collapse button, tooltip, or semantics button.
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'leaf-h',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Leaf heading')],
            ),
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Plain paragraph')],
            ),
          ],
        ),
      );
      final outline = WenzOutlineController(editor: controller);
      addTearDown(outline.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 180,
              child: WenzRichTextEditor(
                controller: controller,
                outlineController: outline,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leafBtn = find.byKey(
        const ValueKey<String>('wenz-richtext-heading-collapse-leaf-h'),
      );
      expect(leafBtn, findsNothing);
      expect(find.byTooltip('无可折叠内容'), findsNothing);

      // Heading text is still rendered.
      expect(_richText('Leaf heading'), findsOneWidget);

      // Paragraph block has no collapse button.
      expect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-heading-collapse-p1'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'heading collapse button spacing from drag handle is chromeGap',
    (tester) async {
      // P003: The heading collapse button starts exactly after the block
      // drag handle plus BlockDragHandleSpec.chromeGap, and leaves
      // gapToContent before heading text.
      final controller = WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'h',
              type: BlockType.heading,
              attributes: BlockAttributes(level: 2),
              content: <InlineNode>[TextRun(text: 'Collapsible')],
            ),
            TextBlockNode(
              id: 'child',
              type: BlockType.paragraph,
              content: <InlineNode>[TextRun(text: 'Child')],
            ),
          ],
        ),
      );
      final outline = WenzOutlineController(editor: controller);
      addTearDown(outline.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 180,
              child: WenzRichTextEditor(
                controller: controller,
                outlineController: outline,
                padding: EdgeInsets.zero,
                enableIme: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The drag handle is at x=0, heading collapse button starts after the
      // handle's right edge plus chromeGap.
      final dragHandleRect = tester.getRect(_blockDragHandleFinder('h'));
      final collapseRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('wenz-richtext-heading-collapse-h'),
        ),
      );

      expect(dragHandleRect.left, moreOrLessEquals(0, epsilon: 0.5));
      expect(
        collapseRect.left - dragHandleRect.right,
        moreOrLessEquals(BlockDragHandleSpec.chromeGap, epsilon: 0.5),
      );
      expect(
        tester.getTopLeft(_richText('Collapsible')).dx - collapseRect.right,
        moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
      );
    },
  );

  group('mobile selection overlay platform gate', () {
    testWidgets(
      'desktop target platform at narrow size does not mount mobile handles',
      (tester) async {
        await _pumpMobileSelectionOverlayEditor(
          tester,
          platform: TargetPlatform.windows,
        );

        expect(find.byType(MobileSelectionHandlesOverlay), findsNothing);
        expect(find.byType(WenzMobileCaretToolbar), findsNothing);
        expect(find.byType(WenzMobileSelectionToolbar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'compact mobile platform mounts handles and selection toolbar',
      (tester) async {
        final controller = await _pumpMobileSelectionOverlayEditor(
          tester,
          platform: TargetPlatform.iOS,
        );

        expect(find.byType(MobileSelectionHandlesOverlay), findsOneWidget);
        expect(find.byType(WenzMobileCaretToolbar), findsNothing);
        expect(find.byType(WenzMobileSelectionToolbar), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey<String>(
              'wenz.mobile-selection-toolbar.select-all',
            ),
          ),
        );
        await tester.pump();

        expect(
          controller.selection,
          textSelection(
            'p-mobile-selection',
            0,
            0,
            _mobileSelectionOverlayText.length,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'enableMobileSelectionHandles false suppresses mobile handles',
      (tester) async {
        await _pumpMobileSelectionOverlayEditor(
          tester,
          platform: TargetPlatform.android,
          enableMobileSelectionHandles: false,
        );

        expect(find.byType(MobileSelectionHandlesOverlay), findsNothing);
        expect(find.byType(WenzMobileCaretToolbar), findsNothing);
        expect(find.byType(WenzMobileSelectionToolbar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

const String _mobileSelectionOverlayText = 'Hello mobile selection';

Future<WenzRichTextController> _pumpMobileSelectionOverlayEditor(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool enableMobileSelectionHandles = true,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = const Size(320, 560);
  tester.view.devicePixelRatio = 1;

  final controller = WenzRichTextController(
    document: const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p-mobile-selection',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(text: _mobileSelectionOverlayText),
          ],
        ),
      ],
    ),
  );
  addTearDown(controller.dispose);

  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 560,
            child: WenzRichTextEditor(
              controller: controller,
              padding: const EdgeInsets.all(24),
              enableIme: false,
              enableMobileSelectionHandles: enableMobileSelectionHandles,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.setSelection(textSelection('p-mobile-selection', 0, 0, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return controller;
  } finally {
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

Future<void> _performPlatformSelectors(
  WidgetTester tester,
  List<String> selectors,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.performSelectors', <dynamic>[
        -1,
        selectors,
      ]),
    ),
    (_) {},
  );
}

Future<void> _sendCtrlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  if (key == LogicalKeyboardKey.keyV) {
    // Clipboard reads may cross more than one asynchronous platform boundary.
    // Wait for the paste route to finish before asserting its document change.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
}

WenzRichTextController _contextMenuController({
  required String text,
  DocumentSelection? selection,
}) {
  return WenzRichTextController(
    document: RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: text)],
        ),
      ],
    ),
    selection: selection,
  );
}

Future<void> _pumpContextMenuEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  bool readOnly = false,
  WenzEditorContextMenuConfiguration contextMenuConfiguration =
      const WenzEditorContextMenuConfiguration(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          height: 320,
          child: WenzRichTextEditor(
            controller: controller,
            readOnly: readOnly,
            padding: const EdgeInsets.all(24),
            enableIme: false,
            contextMenuConfiguration: contextMenuConfiguration,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openContextMenuAt(WidgetTester tester, Offset point) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  try {
    await gesture.addPointer(location: point);
    await tester.pump();
    await gesture.down(point);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  } finally {
    await gesture.removePointer();
  }
}

Finder _contextMenuItemFinder(String id, {int occurrence = 1}) {
  final suffix = occurrence <= 1 ? '' : '#$occurrence';
  return find.byKey(
    ValueKey<String>('wenz-richtext-context-menu-item:$id$suffix'),
  );
}

Finder _contextMenuShortcutFinder(String key) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        RegExp('^(Ctrl|Cmd)\\+$key\$').hasMatch(widget.data ?? ''),
    description: 'context menu shortcut for $key',
  );
}

PopupMenuItem<WenzEditorContextMenuItem> _contextMenuItem(
  WidgetTester tester,
  String id, {
  int occurrence = 1,
}) {
  return tester.widget<PopupMenuItem<WenzEditorContextMenuItem>>(
    _contextMenuItemFinder(id, occurrence: occurrence),
  );
}

Future<void> _tapContextMenuItem(WidgetTester tester, String id) async {
  await tester.tap(_contextMenuItemFinder(id));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpPasteEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  ExternalImageClipboardReader? reader,
  ExternalImageStore? store,
  ExternalImageInsertionSelectionResolver? insertionResolver,
  bool enableExternalImageInput = true,
}) async {
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WenzRichTextEditor(
          controller: controller,
          focusNode: focusNode,
          enableIme: false,
          enableExternalImageInput: enableExternalImageInput,
          externalImageClipboardReader: reader,
          externalImageStore: store,
          externalImageInsertionResolver: insertionResolver,
        ),
      ),
    ),
  );
  focusNode.requestFocus();
  await tester.pump();
}

Future<void> _pumpExternalImageDropEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  required List<ExternalImageInput> dragData,
  ExternalImageStore? store,
  bool readOnly = false,
  bool enableExternalImageInput = true,
  bool enableExternalDragDrop = true,
}) async {
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Draggable<List<ExternalImageInput>>(
              data: dragData,
              feedback: const SizedBox(width: 1, height: 1),
              childWhenDragging: const SizedBox(
                key: _externalImageDragSourceKey,
                width: 48,
                height: 48,
              ),
              child: const SizedBox(
                key: _externalImageDragSourceKey,
                width: 48,
                height: 48,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
            Expanded(
              child: WenzRichTextEditor(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                enableIme: false,
                enableExternalImageInput: enableExternalImageInput,
                enableExternalDragDrop: enableExternalDragDrop,
                externalImageStore: store,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  focusNode.requestFocus();
  await tester.pump();
}

Future<void> _dragExternalImagesOntoEditor(
  WidgetTester tester, {
  bool expectOverlay = false,
}) async {
  final source = tester.getCenter(find.byKey(_externalImageDragSourceKey));
  final target = tester.getCenter(find.byType(WenzRichTextEditor));
  final gesture = await tester.startGesture(source);
  await tester.pump();
  await gesture.moveBy(const Offset(0, 24));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  if (expectOverlay) {
    expect(find.byKey(_externalImageDropOverlayKey), findsOneWidget);
  } else {
    expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
  }
  await gesture.up();
  await tester.pump();
  await tester.pump();
  expect(find.byKey(_externalImageDropOverlayKey), findsNothing);
}

class _FakeExternalImageClipboardReader
    implements ExternalImageClipboardReader {
  const _FakeExternalImageClipboardReader(this.data);

  final ExternalImageClipboardData data;

  @override
  Future<ExternalImageClipboardData> read() async => data;
}

class _FakeExternalImageStore implements ExternalImageStore {
  _FakeExternalImageStore(this.descriptions);

  final List<ExternalImageBlockDescription> descriptions;
  final List<ExternalImageInput> preparedInputs = <ExternalImageInput>[];
  int prepareCount = 0;

  @override
  Future<ExternalImageStoreResult> prepare(ExternalImageInput input) async {
    final rejection = input.rejection;
    if (rejection != null) {
      return ExternalImageStoreResult.failure(rejection);
    }
    preparedInputs.add(input);
    final index = prepareCount;
    prepareCount += 1;
    if (index >= descriptions.length) {
      return const ExternalImageStoreResult.failure(
        ExternalImageInputRejection(
          reason: ExternalImageInputRejectionReason.unsupportedImageType,
          message: 'No fake image description is available.',
        ),
      );
    }
    return ExternalImageStoreResult.success(descriptions[index]);
  }
}

final Uint8List _pngBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
]);

Uint8List _pngBytesWithSize({required int width, required int height}) {
  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    ..._uint32BigEndianBytes(width),
    ..._uint32BigEndianBytes(height),
  ]);
}

List<int> _uint32BigEndianBytes(int value) {
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

Future<void> _sendShiftArrowRight(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// While the formula edit popup is open, arrow keys must drive the popup's
/// `TextField` and never reach the editor body's caret. See
/// `_WenzRichTextEditorState._handleKeyEvent`'s popup-focus guard.
Future<void> _verifyFormulaPopupOwnsArrowKeys(
  WidgetTester tester,
  WenzRichTextController controller, {
  required int inputLength,
}) async {
  // Let the popup's post-frame requestFocus settle onto the input.
  await tester.pump();

  expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
  final inputField = tester.widget<TextField>(
    find.byKey(_formulaEditorInputKey),
  );
  final inputFocusNode = inputField.focusNode!;
  final inputController = inputField.controller!;

  // The popup input holds focus with its caret seeded at the end of the text.
  expect(inputFocusNode.hasFocus, isTrue);
  expect(inputController.text.length, inputLength);
  expect(inputController.selection.extentOffset, inputLength);

  // Snapshot the editor body caret before sending any arrow keys.
  expect(controller.selection, isNotNull);
  final bodyExtentBefore = controller.selection!.extent;

  // Arrow keys reach the popup TextField: its caret moves inside the input.
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  await tester.pump();
  expect(inputController.selection.extentOffset, inputLength - 1);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump();
  expect(inputController.selection.extentOffset, inputLength);

  // The editor body must not have stolen the arrows: its caret is unchanged and
  // focus stays with the popup input.
  expect(controller.selection, isNotNull);
  expect(controller.selection!.extent, bodyExtentBefore);
  expect(inputFocusNode.hasFocus, isTrue);
  expect(find.byKey(_formulaEditorPopupKey), findsOneWidget);
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

Finder _emptyRichText([int index = 0]) {
  return find
      .byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().isEmpty,
        description: 'empty RichText at index $index',
      )
      .at(index);
}

TextSpan _richTextSpan(WidgetTester tester, String text) {
  return tester.widget<RichText>(_richText(text)).text as TextSpan;
}

Finder _codeLineNumberFinder(String blockId) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-code-line-numbers-$blockId'),
  );
}

String _codeLineNumberText(WidgetTester tester, String blockId) {
  return tester.widget<Text>(_codeLineNumberFinder(blockId)).data ?? '';
}

TextSpan? _leafSpan(TextSpan span, String text) {
  final children = span.children;
  if ((children == null || children.isEmpty) && span.text == text) {
    return span;
  }
  for (final child in children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final match = _leafSpan(child, text);
      if (match != null) {
        return match;
      }
    }
  }
  return null;
}

Finder _richTextIgnoringCaret(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText().replaceAll('\uFFFC', '') == text,
    description: 'RichText with plain text "$text" ignoring caret',
  );
}

double _richTextFirstLineCenterY(WidgetTester tester, Finder finder) {
  final firstLine = _richTextLineMetrics(tester, finder).first;
  return tester.getTopLeft(finder).dy +
      firstLine.baseline -
      firstLine.ascent +
      firstLine.height / 2;
}

double _richTextFirstLineHeight(WidgetTester tester, Finder finder) {
  return _richTextLineMetrics(tester, finder).first.height;
}

List<LineMetrics> _richTextLineMetrics(WidgetTester tester, Finder finder) {
  final richText = tester.widget<RichText>(finder);
  return _richTextPainter(tester, finder, richText).computeLineMetrics();
}

_RichTextLineBlankTarget _richTextRightBlankTarget(
  WidgetTester tester,
  Finder finder, {
  required int lineIndex,
}) {
  final richText = tester.widget<RichText>(finder);
  final painter = _richTextPainter(tester, finder, richText);
  final lines = painter.computeLineMetrics();
  expect(lines.length, greaterThan(lineIndex));
  final line = lines[lineIndex];
  final lineRange = _visualLineRange(painter, line);
  final rect = tester.getRect(finder);
  final lineRight = line.left + line.width;
  final blankWidth = rect.width - lineRight;
  expect(
    blankWidth,
    greaterThan(8),
    reason: 'test fixture must leave tappable blank space on the target line',
  );
  return _RichTextLineBlankTarget(
    globalPoint:
        rect.topLeft + Offset(lineRight + blankWidth / 2, _lineY(line)),
    lineRange: lineRange,
  );
}

TextRange _visualLineRange(TextPainter painter, LineMetrics line) {
  final y = _lineY(line);
  final start = painter.getPositionForOffset(Offset(-100000, y)).offset;
  final end = painter.getPositionForOffset(Offset(100000, y)).offset;
  return TextRange(start: start, end: end);
}

double _lineY(LineMetrics line) {
  final top = line.baseline - line.ascent;
  final bottom = line.baseline + line.descent;
  return top + (bottom - top) / 2;
}

class _RichTextLineBlankTarget {
  const _RichTextLineBlankTarget({
    required this.globalPoint,
    required this.lineRange,
  });

  final Offset globalPoint;
  final TextRange lineRange;
}

TextPainter _richTextPainter(
  WidgetTester tester,
  Finder finder,
  RichText richText,
) {
  final size = tester.getSize(finder);
  return TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
}

int _caretRenderOffsetForLogicalOffset(
  WidgetTester tester,
  int logicalOffset,
) {
  final editor = tester.widget<WenzRichTextEditor>(
    find.byType(WenzRichTextEditor),
  );
  final position = editor.controller.selection!.extent;
  final block = editor.controller.document.blocks[position.blockIndex];
  final nodes = position.path.isTableCellText
      ? ((block as TableBlockNode)
              .table
              .cellAt(
                position.path.tableRowIndex!,
                position.path.tableColumnIndex!,
              )!
              .blocks
              .whereType<TextBlockNode>()
              .first)
          .content
      : (block as TextBlockNode).content;
  return _renderOffsetForLogicalOffset(nodes, logicalOffset);
}

int _renderOffsetForLogicalOffset(
  List<InlineNode> nodes,
  int logicalOffset,
) {
  var logicalCursor = 0;
  var renderCursor = 0;
  for (final node in nodes) {
    final logicalLength = inlineLength(node);
    final renderText = _inlineRenderText(node);
    final nextLogicalCursor = logicalCursor + logicalLength;
    final nextRenderCursor = renderCursor + renderText.length;
    if (logicalOffset <= nextLogicalCursor) {
      if (node is TextRun) {
        return renderCursor + logicalOffset - logicalCursor;
      }
      return logicalOffset <= logicalCursor ? renderCursor : nextRenderCursor;
    }
    logicalCursor = nextLogicalCursor;
    renderCursor = nextRenderCursor;
  }
  return renderCursor;
}

String _inlineRenderText(InlineNode node) {
  if (node is TextRun) {
    return node.text;
  }
  if (node is InlineEmbed) {
    return switch (node.embedType.trim()) {
      'mention' => _mentionRenderText(node),
      'image' => '[img]',
      'formula' => _formulaRenderText(node),
      'emoji' => _emojiRenderText(node),
      _ => '[${node.embedType}]',
    };
  }
  return node.plainText;
}

String _mentionRenderText(InlineEmbed embed) {
  final raw = embed.data['label'] ?? embed.data['id'];
  final label = raw?.toString() ?? '';
  return label.isEmpty ? '@mention' : '@$label';
}

String _formulaRenderText(InlineEmbed embed) {
  for (final key in const <String>['text', 'latex', 'value', 'formula']) {
    final value = embed.data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return '[formula]';
}

String _emojiRenderText(InlineEmbed embed) {
  final raw = embed.data['emoji'] ??
      embed.data['text'] ??
      embed.data['value'] ??
      embed.data['shortName'] ??
      embed.data['label'];
  final text = raw?.toString() ?? '';
  return text.isEmpty ? '[emoji]' : text;
}

Finder _imageBlockFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-image-block-$blockId'));
}

Finder _imageFrameFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-image-frame-$blockId'));
}

Finder _imageResizeHitZoneFinder(String blockId, String edge) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-image-resize-hit-zone-$edge-$blockId'),
  );
}

Finder _imageResizeVisualLineFinder(String blockId, String edge) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-image-resize-$edge-$blockId'),
  );
}

Rect _imageFrameRect(WidgetTester tester, String blockId) {
  return tester.getRect(_imageFrameFinder(blockId));
}

Finder _videoBlockFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-video-block-$blockId'));
}

Finder _videoFrameFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-video-frame-$blockId'));
}

Finder _videoResizeHitZoneFinder(String blockId, String edge) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-video-resize-hit-zone-$edge-$blockId'),
  );
}

Rect _videoFrameRect(WidgetTester tester, String blockId) {
  return tester.getRect(_videoFrameFinder(blockId));
}

Future<void> _pumpFixedWidthImageEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  MediaResolver? mediaResolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 420,
            height: 580,
            child: WenzRichTextEditor(
              controller: controller,
              mediaResolver: mediaResolver,
              padding: EdgeInsets.zero,
              enableIme: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectImageFrameHorizontalAlignment(
  WidgetTester tester,
  String blockId,
  String? alignment,
) {
  final blockRect = tester.getRect(_imageBlockFinder(blockId));
  final frameRect = _imageFrameRect(tester, blockId);
  expect(frameRect.width, moreOrLessEquals(160, epsilon: 0.75));
  expect(frameRect.height, moreOrLessEquals(80, epsilon: 0.75));
  switch (alignment) {
    case 'left':
      expect(frameRect.left, moreOrLessEquals(blockRect.left, epsilon: 0.75));
      expect(frameRect.right, lessThan(blockRect.right));
      return;
    case 'right':
      expect(frameRect.right, moreOrLessEquals(blockRect.right, epsilon: 0.75));
      expect(frameRect.left, greaterThan(blockRect.left));
      return;
    case 'center':
    case null:
      expect(
        frameRect.center.dx,
        moreOrLessEquals(blockRect.center.dx, epsilon: 0.75),
      );
      expect(frameRect.left, greaterThan(blockRect.left));
      expect(frameRect.right, lessThan(blockRect.right));
      return;
    default:
      fail('Unsupported expected image alignment: $alignment');
  }
}

void _expectVideoFrameHorizontalAlignment(
  WidgetTester tester,
  String blockId,
  String? alignment,
) {
  final blockRect = tester.getRect(_videoBlockFinder(blockId));
  final frameRect = _videoFrameRect(tester, blockId);
  expect(frameRect.width, moreOrLessEquals(160, epsilon: 0.75));
  expect(frameRect.height, moreOrLessEquals(90, epsilon: 0.75));
  switch (alignment) {
    case 'left':
      expect(frameRect.left, moreOrLessEquals(blockRect.left, epsilon: 0.75));
      expect(frameRect.right, lessThan(blockRect.right));
      return;
    case 'right':
      expect(frameRect.right, moreOrLessEquals(blockRect.right, epsilon: 0.75));
      expect(frameRect.left, greaterThan(blockRect.left));
      return;
    case 'center':
    case null:
      expect(
        frameRect.center.dx,
        moreOrLessEquals(blockRect.center.dx, epsilon: 0.75),
      );
      expect(frameRect.left, greaterThan(blockRect.left));
      expect(frameRect.right, lessThan(blockRect.right));
      return;
    default:
      fail('Unsupported expected video alignment: $alignment');
  }
}

void _expectVideoFrameSize(
  WidgetTester tester,
  String blockId,
  double width,
  double height,
) {
  final frameRect = _videoFrameRect(tester, blockId);
  expect(frameRect.width, moreOrLessEquals(width, epsilon: 0.75));
  expect(frameRect.height, moreOrLessEquals(height, epsilon: 0.75));
}

/// Resolves the mouse cursor at [location] the same way Flutter's
/// [MouseTracker] does: the nearest (innermost) [MouseRegion] in the hit-test
/// path whose cursor is not [MouseCursor.defer] wins. The video and file
/// blocks override the editing surface's text cursor by nesting their own
/// [MouseRegion] closer to the leaf.
MouseCursor _resolvedMouseCursor(WidgetTester tester, Offset location) {
  for (final entry in tester.hitTestOnBinding(location).path) {
    final target = entry.target;
    if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) {
      return target.cursor;
    }
  }
  return MouseCursor.uncontrolled;
}

Finder _blockDragHandleFinder(String blockId) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-block-drag-handle-$blockId'),
  );
}

Finder _blockReorderDropIndicatorFinder() {
  return find.byKey(
    const ValueKey<String>('wenz-richtext-block-reorder-drop-indicator'),
  );
}

WenzRichTextController _headingRangeDragController() {
  return WenzRichTextController(
    document: const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'parent',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 1),
          content: <InlineNode>[TextRun(text: 'Parent title')],
        ),
        TextBlockNode(
          id: 'parent-body',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Parent body')],
        ),
        TextBlockNode(
          id: 'child-heading',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 2),
          content: <InlineNode>[TextRun(text: 'Child title')],
        ),
        TextBlockNode(
          id: 'child-body',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Child body')],
        ),
        TextBlockNode(
          id: 'sibling',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 1),
          content: <InlineNode>[TextRun(text: 'Sibling title')],
        ),
        TextBlockNode(
          id: 'sibling-body',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Sibling body')],
        ),
        TextBlockNode(
          id: 'after',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 1),
          content: <InlineNode>[TextRun(text: 'After title')],
        ),
        TextBlockNode(
          id: 'after-body',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'After body')],
        ),
      ],
    ),
  );
}

Future<WenzOutlineController> _pumpOutlinedBlockDragEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  WenzOutlineController? outlineController,
  Size size = const Size(560, 440),
}) async {
  final outline =
      outlineController ?? WenzOutlineController(editor: controller);
  if (outlineController == null) {
    addTearDown(outline.dispose);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: WenzRichTextEditor(
            controller: controller,
            outlineController: outline,
            padding: EdgeInsets.zero,
            enableIme: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return outline;
}

Future<void> _openBlockMoreMenu(WidgetTester tester, String blockId) async {
  await _waitPastMultiClickWindow(tester);
  await tester.tap(_blockDragHandleFinder(blockId));
  await tester.pumpAndSettle();
  await tester.tap(_popupMenuItemFinder('更多块操作'));
  await tester.pumpAndSettle();
}

Future<void> _openFileActionMenu(WidgetTester tester) async {
  await _waitPastMultiClickWindow(tester);
  await tester.tap(find.byTooltip('附件操作'));
  await tester.pumpAndSettle();
}

PopupMenuItem _popupMenuItem(WidgetTester tester, String label) {
  return tester.widget<PopupMenuItem>(_popupMenuItemFinder(label));
}

Finder _popupMenuItemFinder(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  );
}

Future<void> _openTableToolbarMenu(
  WidgetTester tester,
  String tooltip,
) async {
  expect(find.byTooltip(tooltip), findsOneWidget);
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

Future<void> _tapTableToolbarMenuItem(
  WidgetTester tester,
  String label,
) async {
  expect(_popupMenuItem(tester, label).enabled, isTrue);
  await tester.tap(find.text(label));
  await _pumpTableToolbarOverlay(tester);
}

Future<void> _dismissPopupMenu(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

String _documentJson(WenzRichTextController controller) {
  return jsonEncode(controller.document.toJson());
}

void _expectLucideToolbarIconForTooltip(
  WidgetTester tester,
  String tooltip,
  String icon,
) {
  expect(
    find.descendant(
      of: find.byTooltip(tooltip),
      matching: find.byWidgetPredicate(
        (widget) => widget is WenzLucideToolbarIcon && widget.icon == icon,
      ),
    ),
    findsOneWidget,
  );
}

void _expectPopupMenuLucideIcon(
  WidgetTester tester,
  String label,
  String icon,
) {
  expect(
    find.descendant(
      of: _popupMenuItemFinder(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is WenzLucideToolbarIcon && widget.icon == icon,
      ),
    ),
    findsOneWidget,
  );
}

DocumentSelection objectBlockSelection(String blockId, int blockIndex) {
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(
    base: start,
    extent: start.copyWith(offset: 1),
  );
}

DocumentSelection _collapsedTableCellTextSelection({
  required String tableBlockId,
  required int blockIndex,
  required int tableRowIndex,
  required int tableColumnIndex,
  required int offset,
}) {
  final position = DocumentPosition.tableCell(
    tableBlockId: tableBlockId,
    blockIndex: blockIndex,
    tableRowIndex: tableRowIndex,
    tableColumnIndex: tableColumnIndex,
    offset: offset,
  );
  return DocumentSelection(base: position, extent: position);
}

void _expectTableCellRangeSelection(
  DocumentSelection? selection, {
  required String tableBlockId,
  required int blockIndex,
  required int startRow,
  required int endRow,
  required int startColumn,
  required int endColumn,
}) {
  expect(selection, isNotNull);
  final range = selection!.tableCellRange;
  expect(range, isNotNull);
  final tableRange = range!;
  expect(tableRange.tableBlockId, tableBlockId);
  expect(tableRange.blockIndex, blockIndex);
  expect(tableRange.startRow, startRow);
  expect(tableRange.endRow, endRow);
  expect(tableRange.startColumn, startColumn);
  expect(tableRange.endColumn, endColumn);
}

void _expectBlockTextSelection(
  DocumentSelection? selection, {
  required String blockId,
  required int blockIndex,
  required int baseOffset,
  required int extentOffset,
}) {
  expect(selection, isNotNull);
  expect(selection!.base.blockId, blockId);
  expect(selection.base.blockIndex, blockIndex);
  expect(selection.base.path, PositionPath.blockText(blockId));
  expect(selection.base.offset, baseOffset);
  expect(selection.extent.blockId, blockId);
  expect(selection.extent.blockIndex, blockIndex);
  expect(selection.extent.path, PositionPath.blockText(blockId));
  expect(selection.extent.offset, extentOffset);
}

void _expectBlockCodeSelection(
  DocumentSelection? selection, {
  required String blockId,
  required int blockIndex,
  required int baseOffset,
  required int extentOffset,
}) {
  expect(selection, isNotNull);
  expect(selection!.base.blockId, blockId);
  expect(selection.base.blockIndex, blockIndex);
  expect(selection.base.path, PositionPath.blockCode(blockId));
  expect(selection.base.offset, baseOffset);
  expect(selection.extent.blockId, blockId);
  expect(selection.extent.blockIndex, blockIndex);
  expect(selection.extent.path, PositionPath.blockCode(blockId));
  expect(selection.extent.offset, extentOffset);
}

void _expectTableCellTextSelection(
  DocumentSelection? selection, {
  required String tableBlockId,
  required int blockIndex,
  required int tableRowIndex,
  required int tableColumnIndex,
  required int baseOffset,
  required int extentOffset,
}) {
  expect(selection, isNotNull);
  final expectedPath = PositionPath.tableCellText(
    tableBlockId,
    tableRowIndex,
    tableColumnIndex,
  );
  expect(selection!.base.blockId, tableBlockId);
  expect(selection.base.blockIndex, blockIndex);
  expect(selection.base.path, expectedPath);
  expect(selection.base.offset, baseOffset);
  expect(selection.extent.blockId, tableBlockId);
  expect(selection.extent.blockIndex, blockIndex);
  expect(selection.extent.path, expectedPath);
  expect(selection.extent.offset, extentOffset);
}

void _expectLocalizedTooltip(String tooltip) {
  expect(tooltip, matches(RegExp(r'[\u4e00-\u9fff]')));
  expect(find.byTooltip(tooltip), findsOneWidget);
}

Rect _toolbarButtonsRect(WidgetTester tester, List<String> tooltips) {
  final rects = <Rect>[
    for (final tooltip in tooltips) tester.getRect(find.byTooltip(tooltip)),
  ];
  return rects.skip(1).fold<Rect>(
        rects.first,
        (current, rect) => current.expandToInclude(rect),
      );
}

void _expectToolbarAboveBody(Rect toolbarRect, Rect bodyRect) {
  expect(
    toolbarRect.bottom,
    lessThanOrEqualTo(bodyRect.top),
    reason: 'Object toolbar should not overlap the block body.',
  );
}

void _expectToolbarAlignedToFrameEnd(Rect toolbarRect, Rect frameRect) {
  expect(toolbarRect.left, greaterThanOrEqualTo(frameRect.left));
  expect(
    toolbarRect.right,
    moreOrLessEquals(frameRect.right, epsilon: 0.75),
    reason: 'Object toolbar should align to the block frame end edge.',
  );
}

void _expectRectClose(Rect actual, Rect expected, {double epsilon = 0.001}) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: epsilon));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: epsilon));
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: epsilon));
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: epsilon));
}

void _expectToolbarButtonSize(WidgetTester tester, String tooltip) {
  expect(find.byTooltip(tooltip), findsOneWidget);
  expect(
    tester.getSize(find.byTooltip(tooltip)),
    const Size.square(32),
    reason: '$tooltip should use the shared block toolbar button hit area.',
  );
  final buttonStyle = _toolbarButtonStyleForTooltip(tester, tooltip);
  expect(buttonStyle, isNotNull);
  for (final states in <Set<WidgetState>>[
    <WidgetState>{},
    <WidgetState>{WidgetState.disabled},
    <WidgetState>{WidgetState.hovered},
    <WidgetState>{WidgetState.pressed},
  ]) {
    expect(
      buttonStyle!.fixedSize?.resolve(states),
      const Size.square(32),
      reason: '$tooltip should keep the shared fixed toolbar size.',
    );
    final background = buttonStyle.backgroundColor?.resolve(states);
    expect(
      background,
      Colors.transparent,
      reason: '$tooltip should use transparent background — no independent '
          'capsule. The shared surface provides the visual container.',
    );
    final shape = buttonStyle.shape?.resolve(states);
    expect(shape, isA<RoundedRectangleBorder>());
    final roundedShape = shape! as RoundedRectangleBorder;
    expect(
      roundedShape.borderRadius,
      BorderRadius.circular(16),
      reason: '$tooltip should render as a 32px capsule button.',
    );
  }
  for (final states in <Set<WidgetState>>[
    <WidgetState>{WidgetState.hovered},
    <WidgetState>{WidgetState.pressed},
  ]) {
    final overlay = buttonStyle!.overlayColor?.resolve(states);
    expect(overlay, isNotNull);
    expect(
      overlay,
      isNot(Colors.transparent),
      reason: '$tooltip should keep hover and pressed feedback visible.',
    );
  }
}

void _expectMinimalToolbarSurface(WidgetTester tester, Finder descendant) {
  final surfacePredicate = find.byWidgetPredicate(
    (widget) => widget is Material && widget.elevation == 3,
  );
  var materialFinder = find.descendant(
    of: descendant,
    matching: surfacePredicate,
  );
  if (tester.widgetList(materialFinder).isEmpty) {
    materialFinder = find.ancestor(
      of: descendant,
      matching: surfacePredicate,
    );
  }
  _expectChromeSurfaceMaterial(tester, materialFinder);
}

ButtonStyle? _toolbarButtonStyleForTooltip(
  WidgetTester tester,
  String tooltip,
) {
  final tooltipFinder = find.byTooltip(tooltip);
  final matchedWidget = tooltipFinder.evaluate().single.widget;
  if (matchedWidget is IconButton) {
    return matchedWidget.style;
  }
  if (matchedWidget is PopupMenuButton<dynamic>) {
    return matchedWidget.style;
  }
  final iconButtonFinder = find.ancestor(
    of: tooltipFinder,
    matching: find.byType(IconButton),
  );
  if (tester.widgetList(iconButtonFinder).isNotEmpty) {
    return tester.widget<IconButton>(iconButtonFinder).style;
  }
  final popupButtonFinder = find.ancestor(
    of: tooltipFinder,
    matching: find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton<dynamic>,
    ),
  );
  if (tester.widgetList(popupButtonFinder).isNotEmpty) {
    return tester.widget<PopupMenuButton<dynamic>>(popupButtonFinder).style;
  }
  return null;
}

void _expectPopupMenuChrome(WidgetTester tester, String itemLabel) {
  _expectChromeSurfaceMaterial(tester, _popupMenuMaterialFinder(itemLabel));
}

void _expectWeakPopupMenuDividers(
  WidgetTester tester,
  String itemLabel, {
  required int count,
}) {
  final materialFinder = _popupMenuMaterialFinder(itemLabel);
  final dividers = tester
      .widgetList<Divider>(
        find.descendant(of: materialFinder, matching: find.byType(Divider)),
      )
      .toList();
  expect(dividers, hasLength(count));

  final theme = Theme.of(tester.element(materialFinder));
  final surfaceColor = _expectedChromeSurfaceColor(theme);
  final borderColor = _expectedChromeBorderColor(theme);
  final dividerColor = _expectedChromeDividerColor(theme);
  expect(_alphaOf(dividerColor), greaterThan(0));
  expect(
    _luminanceDistance(dividerColor, surfaceColor),
    lessThan(_luminanceDistance(borderColor, surfaceColor)),
  );

  for (final divider in dividers) {
    expect(divider.height, 8);
    expect(divider.thickness, 1);
    expect(divider.color, dividerColor);
    expect(divider.color, isNot(theme.colorScheme.outlineVariant));
  }
}

Finder _popupMenuMaterialFinder(String itemLabel) {
  return find.ancestor(
    of: _popupMenuItemFinder(itemLabel),
    matching: find.byWidgetPredicate(
      (widget) => widget is Material && widget.elevation == 3,
    ),
  );
}

void _expectChromeSurfaceMaterial(WidgetTester tester, Finder materialFinder) {
  expect(materialFinder, findsOneWidget);
  final material = tester.widget<Material>(materialFinder);
  final theme = Theme.of(tester.element(materialFinder));
  expect(material.color, _expectedChromeSurfaceColor(theme));
  expect(material.elevation, 3);
  expect(material.shadowColor, theme.colorScheme.shadow.withAlpha(30));
  expect(material.surfaceTintColor, Colors.transparent);
  expect(material.clipBehavior, Clip.antiAlias);
  final shape = material.shape as RoundedRectangleBorder;
  expect(shape.borderRadius, BorderRadius.circular(10));
  expect(shape.side.color, _expectedChromeBorderColor(theme));
}

void _expectPopupMenuItemSelected(
  WidgetTester tester,
  String label, {
  bool selected = true,
}) {
  final decorations = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: _popupMenuItemFinder(label),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>();
  final itemDecoration = decorations.firstWhere(
    (decoration) => decoration.borderRadius == BorderRadius.circular(8),
  );
  final theme = Theme.of(tester.element(find.text(label)));
  if (selected) {
    expect(itemDecoration.color, _expectedChromeSelectedColor(theme));
    expect(
      itemDecoration.color,
      isNot(theme.colorScheme.primary.withAlpha(34)),
    );
  } else {
    expect(itemDecoration.color, Colors.transparent);
  }
}

Color _expectedChromeSurfaceColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF292A2D)
      : const Color(0xFFF8F9FA);
}

Color _expectedChromeBorderColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF4A4C50)
      : const Color(0xFFDADCE0);
}

Color _expectedChromeDividerColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF383A3E)
      : const Color(0xFFE9ECEF);
}

Color _expectedChromeSelectedColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF3C4043)
      : const Color(0xFFE8EAED);
}

double _luminanceDistance(Color a, Color b) {
  return (a.computeLuminance() - b.computeLuminance()).abs();
}

void _expectPopupMenuItemTextColor(
  WidgetTester tester,
  String label,
  Color expectedColor,
) {
  final text = tester.widget<Text>(
    find.descendant(
      of: _popupMenuItemFinder(label),
      matching: find.text(label),
    ),
  );
  expect(text.style?.color, expectedColor);
}

Future<void> _pumpTableToolbarOverlay(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpTableResizeEditor(
  WidgetTester tester,
  WenzRichTextController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 240,
          child: WenzRichTextEditor(
            controller: controller,
            padding: EdgeInsets.zero,
            enableIme: false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _tableColumnResizeHandleFinder(int columnIndex) {
  return find.bySemanticsLabel('Resize table column ${columnIndex + 1}');
}

Future<void> pressIconButtonByTooltip(
  WidgetTester tester,
  String tooltip,
) async {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  final matchedWidget = tooltipFinder.evaluate().single.widget;
  final button = matchedWidget is IconButton
      ? matchedWidget
      : tester.widget<IconButton>(
          find.ancestor(
            of: tooltipFinder,
            matching: find.byType(IconButton),
          ),
        );
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await _pumpTableToolbarOverlay(tester);
}

RichTextDocument _toolbarTableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A1')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B1')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a2',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a2-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A2')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b2',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b2-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B2')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

RichTextDocument _singleCellToolbarTableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'single-cell',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'single-cell-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Only')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _singleCellTableSelection() {
  return _collapsedTableCellTextSelection(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: 0,
  );
}

RichTextDocument _toolbarAlignedTableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          columnAlignments: <int, String>{0: 'right'},
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'cell-a1',
                alignment: 'center',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-a1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A1')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'cell-b1',
                alignment: 'right',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'cell-b1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B1')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

RichTextDocument _toolbarTableWithParagraphDocument() {
  return RichTextDocument(
    blocks: <BlockNode>[
      _toolbarTableDocument().blocks.single,
      const TextBlockNode(
        id: 'after-table',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'After table')],
      ),
    ],
  );
}

RichTextDocument _scrollingToolbarTableDocument() {
  return RichTextDocument(
    blocks: <BlockNode>[
      for (var i = 0; i < 4; i++)
        TextBlockNode(
          id: 'before-table-$i',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Before table $i')],
        ),
      _toolbarTableDocument().blocks.single,
      for (var i = 0; i < 12; i++)
        TextBlockNode(
          id: 'after-table-$i',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'After table $i')],
        ),
    ],
  );
}

RichTextDocument _multiToolbarTableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table1',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'table1-cell-a1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table1-cell-a1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A1')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      TextBlockNode(
        id: 'between-tables',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Between tables')],
      ),
      TableBlockNode(
        id: 'table2',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'table2-cell-a1',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table2-cell-a1-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'T2')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

RichTextDocument _styledTableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table-style',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'table-style-head-a',
                isHeader: true,
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-head-a-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Header A')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'table-style-head-b',
                isHeader: true,
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-head-b-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Header B')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'table-style-body-a',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-body-a-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Body A')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'table-style-body-b',
                backgroundColor: 0xFFEAF4FF,
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-body-b-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Body B')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'table-style-merge-a',
                rowSpan: 2,
                columnSpan: 2,
                backgroundColor: 0xFFEAF4FF,
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-merge-a-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Merged 2 x 2')],
                  ),
                ],
              ),
              TableCellNode(id: 'table-style-merge-b', covered: true),
            ],
            <TableCellNode>[
              TableCellNode(id: 'table-style-merge-c', covered: true),
              TableCellNode(
                id: 'table-style-merge-d',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'table-style-merge-d-text',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'Bottom')],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

DocumentSelection _tableCellSelection() {
  final position = DocumentPosition.tableCell(
    tableBlockId: 'table1',
    blockIndex: 0,
    tableRowIndex: 0,
    tableColumnIndex: 0,
    offset: 0,
  );
  return DocumentSelection(base: position, extent: position);
}

Border _paintedTableCellBorder(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  final decoratedBox = _tableCellBorderBox(
    tester,
    tableBlockId,
    rowIndex,
    columnIndex,
  );
  final decoration = decoratedBox.decoration as BoxDecoration;
  return decoration.border! as Border;
}

Finder _tableCellFinder(
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  return find.byKey(
    ValueKey<String>('table-cell-border-$tableBlockId-$rowIndex-$columnIndex'),
  );
}

DecoratedBox _tableCellBorderBox(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  return tester.widget<DecoratedBox>(
    _tableCellFinder(tableBlockId, rowIndex, columnIndex),
  );
}

DecoratedBox _tableCellBackgroundBox(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  final decoratedBoxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byKey(
        ValueKey<String>(
            'table-cell-border-$tableBlockId-$rowIndex-$columnIndex'),
      ),
      matching: find.byType(DecoratedBox),
    ),
  );
  return decoratedBoxes.firstWhere((box) {
    final decoration = box.decoration;
    return decoration is BoxDecoration && decoration.border == null;
  });
}

bool _tableCellHasWholeSelectionHighlight(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  final cellFinder = _tableCellFinder(tableBlockId, rowIndex, columnIndex);
  if (cellFinder.evaluate().isEmpty) {
    return false;
  }
  final highlights = find.descendant(
    of: cellFinder,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox && widget.key == _selectionHighlightKey,
      description: 'whole-cell selection highlight',
    ),
  );
  return highlights.evaluate().isNotEmpty;
}

bool _tableCellHasTextSelectionHighlight(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  final cellFinder = _tableCellFinder(tableBlockId, rowIndex, columnIndex);
  if (cellFinder.evaluate().isEmpty) {
    return false;
  }
  final highlights = find.descendant(
    of: cellFinder,
    matching: find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.key == _selectionHighlightKey,
      description: 'text selection highlight',
    ),
  );
  return highlights.evaluate().isNotEmpty;
}

Set<String> _wholeCellHighlightedTableCells(
  WidgetTester tester,
  String tableBlockId, {
  required int rowCount,
  required int columnCount,
}) {
  final highlighted = <String>{};
  for (var row = 0; row < rowCount; row++) {
    for (var column = 0; column < columnCount; column++) {
      if (_tableCellHasWholeSelectionHighlight(
        tester,
        tableBlockId,
        row,
        column,
      )) {
        highlighted.add('$row,$column');
      }
    }
  }
  return highlighted;
}

Set<String> _textSelectionHighlightedTableCells(
  WidgetTester tester,
  String tableBlockId, {
  required int rowCount,
  required int columnCount,
}) {
  final highlighted = <String>{};
  for (var row = 0; row < rowCount; row++) {
    for (var column = 0; column < columnCount; column++) {
      if (_tableCellHasTextSelectionHighlight(
        tester,
        tableBlockId,
        row,
        column,
      )) {
        highlighted.add('$row,$column');
      }
    }
  }
  return highlighted;
}

Rect _textSelectionHighlightGlobalRect(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  final cellFinder = _tableCellFinder(tableBlockId, rowIndex, columnIndex);
  final candidates = find
      .descendant(
        of: cellFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_SelectionHighlightPainter',
          description: 'selection highlight painter',
        ),
      )
      .evaluate();

  for (final element in candidates) {
    final customPaint = element.widget as CustomPaint;
    final painter = customPaint.painter as dynamic;
    final range = painter.range;
    if (range == null) {
      continue;
    }
    final textPainter = painter.layoutService.layout(
      span: painter.textSpan,
      textAlign: painter.textAlign,
      textDirection: painter.textDirection,
      minWidth: painter.minWidth,
      maxWidth: painter.maxWidth,
    );
    final renderStart =
        painter.offsetMapper.renderOffsetForLogicalOffset(range.start) as int;
    final renderEnd =
        painter.offsetMapper.renderOffsetForLogicalOffset(range.end) as int;
    final boxes = painter.layoutService.selectionBoxes(
      textPainter,
      renderStart,
      renderEnd,
    );
    expect(boxes, isNotEmpty);

    var rect = boxes.first.toRect() as Rect;
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect() as Rect);
    }
    final renderBox = element.renderObject as RenderBox;
    return rect.shift(renderBox.localToGlobal(Offset.zero));
  }

  throw StateError(
    'No active text selection highlight found in $tableBlockId '
    'cell $rowIndex,$columnIndex.',
  );
}

void _expectInlineFormulaHasNoDefaultBackground(
  WidgetTester tester,
  Finder formulaFinder,
) {
  final formulaSlot = tester.widget<SizedBox>(formulaFinder);
  final child = formulaSlot.child;
  if (child is DecoratedBox) {
    final decoration = child.decoration as BoxDecoration;
    expect(decoration.color, isNull);
  }
}

void _expectFormulaBlockHasNoDefaultBackground(
  WidgetTester tester,
  String blockId,
  ColorScheme scheme,
) {
  final cardDecoration = _firstDescendantBoxDecorationByKey(
    tester,
    ValueKey<String>('wenz-richtext-formula-card-$blockId'),
  );
  expect(cardDecoration.color, isNull);
  expect(cardDecoration.color, isNot(scheme.secondaryContainer));
  expect(
    cardDecoration.color,
    isNot(scheme.secondaryContainer.withAlpha(110)),
  );

  final previewDecoration = _boxDecorationByKey(
    tester,
    ValueKey<String>('wenz-richtext-formula-preview-$blockId'),
  );
  expect(previewDecoration.color, isNull);
  expect(previewDecoration.color, isNot(scheme.secondaryContainer));
}

BoxDecoration _boxDecorationByKey(WidgetTester tester, Key key) {
  final decoratedBox = tester.widget<DecoratedBox>(find.byKey(key));
  return decoratedBox.decoration as BoxDecoration;
}

BoxDecoration _firstDescendantBoxDecorationByKey(
  WidgetTester tester,
  Key key,
) {
  final decoratedBoxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)),
  );
  return decoratedBoxes.first.decoration as BoxDecoration;
}

/// Key the rendered math subtree is tagged with in `_FormulaMathView`, derived
/// from the (trimmed) formula source. Used by the formula-update rendering
/// regression tests to assert the laid-out math reflects the current content.
Key _formulaMathKey(String source) =>
    ValueKey<String>('wenz-richtext-formula-math::$source');

Color _customPainterColor(WidgetTester tester, String painterTypeName) {
  final customPaint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((widget) {
      if (widget is! CustomPaint) {
        return false;
      }
      return widget.painter.runtimeType.toString() == painterTypeName ||
          widget.foregroundPainter.runtimeType.toString() == painterTypeName;
    }),
  );
  final painter = customPaint.painter.runtimeType.toString() == painterTypeName
      ? customPaint.painter
      : customPaint.foregroundPainter;
  return (painter as dynamic).color as Color;
}

void _expectBorderSidePainted(BorderSide side) {
  expect(side.style, BorderStyle.solid);
  expect(side.width, 1);
}

void _expectBorderSideNotPainted(BorderSide side) {
  expect(side, BorderSide.none);
}

List<String> _underlinedTexts(InlineSpan span) {
  final result = <String>[];

  void visit(InlineSpan current, TextStyle? inheritedStyle) {
    if (current is! TextSpan) {
      return;
    }
    final style = current.style ?? inheritedStyle;
    final text = current.text;
    if (text != null &&
        text.isNotEmpty &&
        style?.decoration?.contains(TextDecoration.underline) == true) {
      result.add(text);
    }
    final children = current.children;
    if (children != null) {
      for (final child in children) {
        visit(child, style);
      }
    }
  }

  visit(span, null);
  return result;
}

Future<void> _tapTextOffset(
  WidgetTester tester,
  String text,
  int offset,
) async {
  await tester.tapAt(_globalTextOffset(tester, text, offset));
}

Future<void> _tapSingle(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump();
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
}

Future<void> _waitPastMultiClickWindow(WidgetTester tester) async {
  final delay = kDoubleTapTimeout + const Duration(milliseconds: 1);
  await tester.pump(delay);
  await tester.runAsync(() async {
    await Future<void>.delayed(delay);
  });
}

Offset _globalTextOffset(WidgetTester tester, String text, int offset) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: size.width, maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) +
      local +
      Offset(1, painter.preferredLineHeight / 2);
}

Offset _richTextCaretTopLeft(WidgetTester tester, String text, int offset) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: size.width, maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) + local;
}

Offset _renderParagraphCaretTopLeft(
  WidgetTester tester,
  String text,
  int offset,
) {
  final finder = _richText(text);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final local = paragraph.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return paragraph.localToGlobal(local);
}

Rect _renderParagraphTextBox(
  WidgetTester tester,
  String text,
  int start,
  int end,
) {
  final paragraph = tester.renderObject<RenderParagraph>(_richText(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  expect(boxes, hasLength(1));
  final local = boxes.single.toRect();
  return paragraph.localToGlobal(local.topLeft) & local.size;
}

Offset _caretPainterGlobalTopLeft(WidgetTester tester) {
  final caretFinder = find.byKey(
    const ValueKey<String>('wenz-richtext-caret'),
  );
  final customPaint = tester.widget<CustomPaint>(caretFinder);
  final painter = customPaint.foregroundPainter as dynamic;
  final caretOffset = painter.caretOffset as int?;
  expect(caretOffset, isNotNull);
  final textPainter = painter.layoutService.layout(
    span: painter.textSpan,
    textAlign: painter.textAlign,
    textDirection: painter.textDirection,
    minWidth: painter.minWidth,
    maxWidth: painter.maxWidth,
  );
  final textLength = painter.textLength as int;
  final safeOffset = caretOffset!.clamp(0, textLength).toInt();
  final renderOffset = painter.offsetMapper.renderOffsetForLogicalOffset(
    safeOffset,
  ) as int;
  final local = painter.layoutService.caretOffset(
    textPainter,
    renderOffset,
  ) as Offset;
  return tester.getTopLeft(caretFinder) + local;
}

Offset _globalTextRangePoint(
  WidgetTester tester,
  String text,
  int startOffset,
  int endOffset,
  double fraction,
) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: size.width, maxWidth: size.width);
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: startOffset, extentOffset: endOffset),
  );
  if (boxes.isEmpty) {
    final start = _globalTextOffset(tester, text, startOffset);
    final end = _globalTextOffset(tester, text, endOffset);
    return start + (end - start) * fraction;
  }
  final firstBox = boxes.first.toRect();
  final rangeRect = boxes.skip(1).fold<Rect>(
        firstBox,
        (current, box) => current.expandToInclude(box.toRect()),
      );
  return tester.getTopLeft(finder) +
      Offset(
        rangeRect.left + rangeRect.width * fraction,
        rangeRect.top + rangeRect.height / 2,
      );
}

// Link hover / Ctrl+Cmd+click interaction helpers.
const String _kLinkRenderedText = 'See our docs now';
const int _kLinkStart =
    4; // 'our docs' begins at offset 4 in the rendered text.
const int _kLinkEnd = 12; // 'our docs' ends at offset 12.
const String _kLinkUrl = 'https://example.com';

/// Pumps a single-paragraph editor whose 'our docs' run is a link. Generous
/// top padding leaves room for the hover popup to anchor *above* a link on the
/// first line instead of flipping below it.
Future<WenzRichTextController> _pumpLinkEditor(
  WidgetTester tester, {
  bool readOnly = false,
  WenzLinkInteractionCallback? onOpenLink,
}) async {
  final controller = WenzRichTextController(
    document: const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p-link',
          type: BlockType.paragraph,
          content: <InlineNode>[
            TextRun(text: 'See '),
            TextRun(
              text: 'our docs',
              attributes: TextAttributes(url: _kLinkUrl),
            ),
            TextRun(text: ' now'),
          ],
        ),
      ],
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WenzRichTextEditor(
          controller: controller,
          readOnly: readOnly,
          padding: const EdgeInsets.only(
            top: 96,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          enableIme: false,
          onOpenLink: onOpenLink,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Offset _linkPoint(WidgetTester tester) => _globalTextRangePoint(
    tester, _kLinkRenderedText, _kLinkStart, _kLinkEnd, 0.5);

Offset _plainTextPoint(WidgetTester tester) => _globalTextRangePoint(
      tester,
      _kLinkRenderedText,
      _kLinkEnd,
      _kLinkRenderedText.length,
      0.5,
    );

/// The url of the first link-bearing run in the editor's single block, or
/// `null` once the link has been cleared.
String? _linkUrlInBlock(WenzRichTextController controller) {
  final block = controller.document.blocks.single as TextBlockNode;
  for (final node in block.content) {
    if (node is TextRun && node.attributes.url != null) {
      return node.attributes.url;
    }
  }
  return null;
}

/// Global bounding rect of a rendered text range, mirroring
/// [_globalTextRangePoint] but returning the full [Rect] instead of a point.
Rect _textRangeGlobalRect(
  WidgetTester tester,
  String text,
  int startOffset,
  int endOffset,
) {
  final finder = _richText(text);
  final richText = tester.widget<RichText>(finder);
  final size = tester.getSize(finder);
  final painter = TextPainter(
    text: richText.text,
    textAlign: richText.textAlign,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: size.width, maxWidth: size.width);
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: startOffset, extentOffset: endOffset),
  );
  final firstBox = boxes.first.toRect();
  final rangeRect = boxes.skip(1).fold<Rect>(
        firstBox,
        (current, box) => current.expandToInclude(box.toRect()),
      );
  final topLeft = tester.getTopLeft(finder);
  return Rect.fromLTWH(
    topLeft.dx + rangeRect.left,
    topLeft.dy + rangeRect.top,
    rangeRect.width,
    rangeRect.height,
  );
}

/// Hovers a mouse pointer onto [point] and lets the link popup settle. Returns
/// the gesture so the caller can keep moving it (across the popup, away, etc.).
Future<TestGesture> _hoverMouseAt(WidgetTester tester, Offset point) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  // Start off the surface so the move produces a real hover-enter onto the
  // link rather than a no-op move at the same location.
  await gesture.addPointer(location: const Offset(-200, -200));
  await tester.pump();
  await gesture.moveTo(point);
  await tester.pumpAndSettle();
  return gesture;
}

Future<void> _shiftMouseClickAt(WidgetTester tester, Offset point) async {
  TestGesture? gesture;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: point);
    await tester.pump();
    await gesture.down(point);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  } finally {
    if (gesture != null) {
      await gesture.removePointer();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }
}

Future<void> _shiftMouseDragFrom(
  WidgetTester tester,
  Offset start,
  Offset end,
) async {
  TestGesture? gesture;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: start);
    await tester.pump();
    await gesture.down(start);
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  } finally {
    if (gesture != null) {
      await gesture.removePointer();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }
}

/// A mouse (down + up) click at [point] — the only pointer kind the
/// Ctrl/Cmd+click-to-open path responds to.
Future<void> _mouseClickAt(WidgetTester tester, Offset point) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: point);
  await tester.pump();
  await gesture.down(point);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<Color> _sampleBoundaryColor(
  WidgetTester tester,
  Key boundaryKey,
  Offset globalPoint,
) async {
  final boundaryFinder = find.byKey(boundaryKey);
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final image = await boundary.toImage(pixelRatio: 1);
  addTearDown(image.dispose);
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  expect(data, isNotNull);
  final localPoint = globalPoint - tester.getTopLeft(boundaryFinder);
  final x = localPoint.dx.round().clamp(0, image.width - 1).toInt();
  final y = localPoint.dy.round().clamp(0, image.height - 1).toInt();
  final offset = (y * image.width + x) * 4;
  return Color.fromARGB(
    data!.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

int _alphaOf(Color color) => (color.a * 255.0).round().clamp(0, 255);

int _redOf(Color color) => (color.r * 255.0).round().clamp(0, 255);

int _greenOf(Color color) => (color.g * 255.0).round().clamp(0, 255);

int _blueOf(Color color) => (color.b * 255.0).round().clamp(0, 255);

/// The current scroll offset of the editor's scrollable. Used by the
/// auto-scroll-on-drag tests to assert the ticker advances the offset.
double _scrollOffset(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(WenzRichTextEditor),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollable.position.pixels;
}

class _TestMediaResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is ImageBlockNode || block is VideoBlockNode) {
      return Center(child: Text('preview:${block.id}'));
    }
    return null;
  }
}

class _TappableVideoResolver implements MediaResolver {
  int tapCount = 0;
  int resolveCount = 0;
  int createCount = 0;
  int disposeCount = 0;

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! VideoBlockNode) {
      return null;
    }
    resolveCount++;
    return _TappableVideoPlayer(
      surfaceKey: ValueKey<String>('tappable-video-surface-${block.id}'),
      playerKey: ValueKey<String>('tappable-video-player-${block.id}'),
      onTap: () {
        tapCount++;
      },
      onCreated: () => ++createCount,
      onDisposed: () {
        disposeCount++;
      },
    );
  }
}

class _TappableVideoPlayer extends StatefulWidget {
  const _TappableVideoPlayer({
    required this.surfaceKey,
    required this.playerKey,
    required this.onTap,
    required this.onCreated,
    required this.onDisposed,
  });

  final Key surfaceKey;
  final Key playerKey;
  final VoidCallback onTap;
  final int Function() onCreated;
  final VoidCallback onDisposed;

  @override
  State<_TappableVideoPlayer> createState() => _TappableVideoPlayerState();
}

class _TappableVideoPlayerState extends State<_TappableVideoPlayer> {
  int _tapCount = 0;
  late final int _instanceId;

  @override
  void initState() {
    super.initState();
    _instanceId = widget.onCreated();
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: widget.surfaceKey,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onTap();
              setState(() {
                _tapCount++;
              });
            },
            child: SizedBox(
              key: widget.playerKey,
              width: 144,
              height: 72,
              child: ColoredBox(
                color: Colors.blueGrey,
                child: Center(
                  child: Text(
                    'resolver instance:$_instanceId taps:$_tapCount',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OversizedVideoResolver implements MediaResolver {
  const _OversizedVideoResolver();

  @override
  Widget? resolve(BuildContext context, BlockNode block) {
    if (block is! VideoBlockNode) {
      return null;
    }
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: ValueKey<String>('oversized-video-player-${block.id}'),
        width: 1200,
        height: 900,
        child: const ColoredBox(
          color: Colors.red,
          child: Text('oversized custom video player'),
        ),
      ),
    );
  }
}

/// A [MediaResolver] that returns an empty widget for every block. Used to
/// keep the figure frame free of placeholder content so image metadata and
/// altText semantics can be asserted without merged-label noise.
class _EmptyMediaResolver implements MediaResolver {
  @override
  Widget? resolve(BuildContext context, BlockNode block) =>
      const SizedBox.shrink();
}
