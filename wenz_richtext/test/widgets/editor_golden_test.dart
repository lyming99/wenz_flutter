import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const _goldenKey = ValueKey<String>('editor-golden-surface');

void main() {
  test('design baseline maps default renderer coverage and tokens', () {
    expect(WenzRichTextDesignBaseline.source, 'ui/richtext_design.html');
    expect(
      WenzRichTextDesignBaseline.defaultRendererBlockTypes,
      BlockType.values,
    );

    final registry = BlockRendererRegistry()..installDefaultBuilders();
    expect(
      registry.blockTypes.toList(growable: false),
      WenzRichTextDesignBaseline.defaultRendererBlockTypes,
    );
    expect(registry.embedTypes, isEmpty);

    for (final type in WenzRichTextDesignBaseline.defaultRendererBlockTypes) {
      expect(
          WenzRichTextDesignBaseline.currentRendererGaps, contains(type.name));
    }
    expect(WenzRichTextDesignBaseline.colorTokens['primary'], 0xFF4F6DF5);
    expect(WenzRichTextDesignBaseline.colorTokens['surface'], 0xFFFBFAFF);
    expect(WenzRichTextDesignBaseline.colorTokens['blueLink'], 0xFF1976D2);
    expect(WenzRichTextDesignBaseline.colorTokens['amberStrong'], 0xFFC97B00);
    expect(WenzRichTextDesignBaseline.typographyTokens['bodyFontSize'], 16.0);
    expect(WenzRichTextDesignBaseline.typographyTokens['bodyLineHeight'], 1.75);
    expect(
      WenzRichTextDesignBaseline.typographyTokens['headingFontSizes'],
      <int, double>{1: 24.0, 2: 21.0, 3: 18.0, 4: 16.0},
    );
    expect(WenzRichTextDesignBaseline.typographyTokens['headingStrongWeight'],
        700);
    expect(
        WenzRichTextDesignBaseline.typographyTokens['headingWeakWeight'], 600);
    expect(WenzRichTextDesignBaseline.typographyTokens['codeFontSize'], 13.5);
    expect(WenzRichTextDesignBaseline.typographyTokens['codeLineHeight'], 1.6);
    expect(WenzRichTextDesignBaseline.layoutTokens['radius'], 12.0);
    expect(WenzRichTextDesignBaseline.layoutTokens['paragraphMarginEm'], 0.55);
    expect(
      WenzRichTextDesignBaseline.layoutTokens['quotePadding'],
      <double>[8.0, 18.0],
    );
    expect(
        WenzRichTextDesignBaseline.layoutTokens['quoteBorderLeftWidth'], 4.0);
    expect(WenzRichTextDesignBaseline.layoutTokens['listPaddingLeft'], 26.0);
    expect(
      WenzRichTextDesignBaseline.layoutTokens['headingCollapse'],
      <String, double>{
        'slotWidth': 30.0,
        'buttonSize': 26.0,
        'iconSize': 20.0,
      },
    );
    expect(WenzRichTextDesignBaseline.layoutTokens['taskGap'], 10.0);
    expect(
      WenzRichTextDesignBaseline.layoutTokens['codePadding'],
      <double>[18.0, 20.0],
    );
    expect(WenzRichTextDesignBaseline.layoutTokens['dividerMarginEm'], 1.6);
    expect(
      WenzRichTextDesignBaseline.layoutTokens['headingMarginEm'],
      <String, double>{'top': 0.6, 'bottom': 0.35},
    );
    expect(BlockDragHandleSpec.railWidth, 32.0);
    expect(BlockDragHandleSpec.hitSize, const Size.square(28.0));
    expect(BlockDragHandleSpec.visualSize, const Size.square(18.0));
    expect(BlockDragHandleSpec.dragStartSlop, 6.0);
    expect(BlockDragHandleSpec.idleOpacity, 0.0);
    expect(BlockDragHandleSpec.hoverOpacity, 0.72);
    expect(BlockDragHandleSpec.activeOpacity, 1.0);
    expect(
        WenzRichTextDesignBaseline.stateTokens, contains('inline.highlight'));
    expect(WenzRichTextDesignBaseline.stateTokens, contains('callout.info'));
    expect(WenzRichTextDesignBaseline.stateTokens, contains('callout.success'));
    expect(WenzRichTextDesignBaseline.stateTokens, contains('callout.warning'));
    expect(WenzRichTextDesignBaseline.stateTokens, contains('callout.danger'));
    expect(
        WenzRichTextDesignBaseline.stateTokens, contains('heading.collapse'));

    Widget fallbackBuilder(BuildContext context, BlockRenderContext rc) {
      return const SizedBox.shrink();
    }

    Widget customBuilder(BuildContext context, BlockRenderContext rc) {
      return const SizedBox.shrink();
    }

    final previous = registry.register(BlockType.paragraph, customBuilder);
    expect(previous, isNotNull);
    expect(
      registry.resolve(BlockType.paragraph, fallback: fallbackBuilder),
      same(customBuilder),
    );
  });

  test('block drag handle spec gates read-only and row boundaries', () {
    expect(
      BlockDragHandleSpec.canShow(
        canEdit: false,
        blockIndex: 0,
        blockCount: 3,
      ),
      isFalse,
    );
    expect(
      BlockDragHandleSpec.canShow(
        canEdit: true,
        blockIndex: 0,
        blockCount: 3,
      ),
      isTrue,
    );
    expect(
      BlockDragHandleSpec.canDragSort(
        canEdit: true,
        blockIndex: 0,
        blockCount: 1,
      ),
      isFalse,
    );
    expect(
      BlockDragHandleSpec.canMoveUp(
        canEdit: true,
        blockIndex: 0,
        blockCount: 3,
      ),
      isFalse,
    );
    expect(
      BlockDragHandleSpec.canMoveDown(
        canEdit: true,
        blockIndex: 2,
        blockCount: 3,
      ),
      isFalse,
    );
    expect(
      BlockDragHandleSpec.canMoveUp(
        canEdit: true,
        blockIndex: 1,
        blockCount: 3,
      ),
      isTrue,
    );
    expect(
      BlockDragHandleSpec.canMoveDown(
        canEdit: true,
        blockIndex: 1,
        blockCount: 3,
      ),
      isTrue,
    );
  });

  testWidgets('quote blocks fill the editable row width', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'short-quote',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Short quote')],
          ),
          TextBlockNode(
            id: 'empty-quote',
            type: BlockType.quote,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'indented-quote',
            type: BlockType.quote,
            attributes: BlockAttributes(indent: 1),
            content: <InlineNode>[TextRun(text: 'Indented quote\nsecond line')],
          ),
        ],
      ),
    );

    await _pumpGoldenEditor(tester, controller);

    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    final backgroundFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    expect(backgroundFinder, findsNWidgets(3));

    const editorPadding = 16.0;
    const indentedQuoteStart = 24.0;
    final rowStart =
        editorRect.left + editorPadding + BlockDragHandleSpec.railWidth;
    final rowEnd = editorRect.right - editorPadding;
    final shortQuoteRect = tester.getRect(backgroundFinder.at(0));
    final emptyQuoteRect = tester.getRect(backgroundFinder.at(1));
    final indentedQuoteRect = tester.getRect(backgroundFinder.at(2));

    expect(shortQuoteRect.left, closeTo(rowStart, 0.001));
    expect(shortQuoteRect.right, closeTo(rowEnd, 0.001));
    expect(emptyQuoteRect.left, closeTo(rowStart, 0.001));
    expect(emptyQuoteRect.right, closeTo(rowEnd, 0.001));
    expect(
        indentedQuoteRect.left, closeTo(rowStart + indentedQuoteStart, 0.001));
    expect(indentedQuoteRect.right, closeTo(rowEnd, 0.001));
  });

  testWidgets('golden: paragraph code and image placeholder', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'title',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[
              TextRun(
                text: 'Release checklist',
                attributes: TextAttributes(bold: true),
              ),
            ],
          ),
          TextBlockNode(
            id: 'leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3),
            content: <InlineNode>[TextRun(text: 'No children heading')],
          ),
          TextBlockNode(
            id: 'content-section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Expanded blocks')],
          ),
          TextBlockNode(
            id: 'body',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Paragraph rendering with inline text.'),
            ],
          ),
          CodeBlockNode(
            id: 'code',
            language: 'dart',
            code: 'final ready = true;',
          ),
          ImageBlockNode(id: 'image', assetId: 'hero', file: 'hero.png'),
        ],
      ),
    );
    final outlineController = WenzOutlineController(editor: controller);
    addTearDown(outlineController.dispose);

    // Includes the leading row chrome gutter reserved for block drag handles.
    await _pumpGoldenEditor(
      tester,
      controller,
      outlineController: outlineController,
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_blocks.png'),
    );
  });

  testWidgets('golden: block handle opens row action menu', (tester) async {
    await _pumpGoldenEditorWithOverlayCapture(
      tester,
      _blockHandleGoldenController(),
    );

    await tester.tap(_blockDragHandleFinder('menu-title'));
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsOneWidget);
    expect(find.text('更多块操作'), findsOneWidget);

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_block_handle_menu.png'),
    );
  });

  testWidgets('golden: block drag shows reorder drop indicator', (
    tester,
  ) async {
    await _pumpGoldenEditorWithOverlayCapture(
      tester,
      _blockHandleGoldenController(),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(_blockDragHandleFinder('menu-title')),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveTo(
      tester.getBottomLeft(_richText('Second block')) + const Offset(12, -1),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-block-reorder-drop-indicator'),
      ),
      findsOneWidget,
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_block_drop_indicator.png'),
    );

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('golden: merged table cell visual span', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table',
              table: TableModel(
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'head-a',
                      isHeader: true,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'head-a-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Header A'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'head-b',
                      isHeader: true,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'head-b-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Header B')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'head-c',
                      isHeader: true,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'head-c-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Header C')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(
                      id: 'row-b1',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'row-b1-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Row stripe')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'row-b2',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'row-b2-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Row stripe')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'row-b3',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'row-b3-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Row stripe')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(
                      id: 'merge-a',
                      rowSpan: 2,
                      columnSpan: 2,
                      backgroundColor: 0xFFEAF4FF,
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merge-a-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Merged 2 x 2'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(id: 'merge-b', covered: true),
                    TableCellNode(
                      id: 'merge-c',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merge-c-p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Right')],
                        ),
                      ],
                    ),
                  ],
                  <TableCellNode>[
                    TableCellNode(id: 'merge-d', covered: true),
                    TableCellNode(id: 'merge-e', covered: true),
                    TableCellNode(
                      id: 'merge-f',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'merge-f-p',
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
        ),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_merged_table.png'),
    );
  });

  testWidgets('golden: selection highlight', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Selected words stay highlighted.'),
              ],
            ),
          ],
        ),
        selection: textSelection('p1', 0, 0, 14),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_selection.png'),
    );
  });

  testWidgets('golden: collapsed caret', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TextBlockNode(
              id: 'p1',
              type: BlockType.paragraph,
              content: <InlineNode>[
                TextRun(text: 'Caret is visible here.'),
              ],
            ),
          ],
        ),
        selection: collapsedTextSelection('p1', 0, 8),
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_caret.png'),
    );
  });

  testWidgets('golden: advanced blocks and inline embeds', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'advanced-title',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[
              TextRun(text: 'Advanced review'),
            ],
          ),
          CalloutBlockNode(
            id: 'advanced-callout',
            variant: CalloutBlockNode.warningVariant,
            title: 'Migration risk',
            icon: '!',
            content: <InlineNode>[
              TextRun(text: 'Check schema fallback before release.'),
            ],
          ),
          TextBlockNode(
            id: 'advanced-inline',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Owner '),
              InlineEmbed(
                embedType: 'mention',
                data: <String, Object?>{'id': 'u1', 'label': 'Ada'},
              ),
              TextRun(text: ' verifies '),
              InlineEmbed(
                embedType: 'formula',
                data: <String, Object?>{'text': 'x^2 + y^2'},
              ),
              TextRun(text: ' rendering.'),
            ],
          ),
          TextBlockNode(
            id: 'advanced-nested',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 3),
            content: <InlineNode>[TextRun(text: 'Nested evidence')],
          ),
          TextBlockNode(
            id: 'advanced-hidden',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden nested detail')],
          ),
          TextBlockNode(
            id: 'advanced-next',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Follow-up artifact')],
          ),
          FileBlockNode(
            id: 'advanced-file',
            assetId: 'spec-v2',
            name: 'release-spec.pdf',
            size: 1048576,
            mimeType: 'application/pdf',
            uploadStatus: FileUploadStatus.failed,
            uploadError: 'Retry required',
          ),
        ],
      ),
    );
    final outlineController = WenzOutlineController(editor: controller);
    addTearDown(outlineController.dispose);
    expect(outlineController.collapseByBlockId('advanced-nested'), isTrue);

    await _pumpGoldenEditor(
      tester,
      controller,
      outlineController: outlineController,
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_advanced_blocks.png'),
    );
  });
}

Future<void> _pumpGoldenEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  WenzOutlineController? outlineController,
}) async {
  const size = Size(520, 320);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: _goldenKey,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WenzRichTextEditor(
                controller: controller,
                outlineController: outlineController,
                enableIme: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpGoldenEditorWithOverlayCapture(
  WidgetTester tester,
  WenzRichTextController controller,
) async {
  const size = Size(520, 320);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenKey,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
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
  await tester.pumpAndSettle();
}

WenzRichTextController _blockHandleGoldenController() {
  return WenzRichTextController(
    document: const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'menu-title',
          type: BlockType.heading,
          attributes: BlockAttributes(level: 2),
          content: <InlineNode>[TextRun(text: 'Block actions')],
        ),
        TextBlockNode(
          id: 'menu-body',
          type: BlockType.paragraph,
          content: <InlineNode>[TextRun(text: 'Second block')],
        ),
        CodeBlockNode(
          id: 'menu-code',
          language: 'dart',
          code: 'final ok = true;',
        ),
      ],
    ),
  );
}

Finder _blockDragHandleFinder(String blockId) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-block-drag-handle-$blockId'),
  );
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}
