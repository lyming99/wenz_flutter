import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const _goldenKey = ValueKey<String>('editor-golden-surface');
const _selectionHighlightKey = ValueKey<String>(
  'wenz-richtext-selection-highlight',
);

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
        'slotWidth': 24.0,
        'buttonSize': 24.0,
        'iconSize': 18.0,
      },
    );
    // The screenshot golden fixtures in this file do not render todo blocks;
    // compact todo geometry is covered by widget-level layout assertions.
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
    expect(BlockDragHandleSpec.railWidth, 64.0);
    expect(BlockDragHandleSpec.collapseChromeOverflow, 32.0);
    expect(BlockDragHandleSpec.chromeGap, 4.0);
    expect(BlockDragHandleSpec.gapToContent, 8.0);
    expect(BlockDragHandleSpec.hitSize, const Size.square(28.0));
    expect(BlockDragHandleSpec.visualSize, const Size.square(18.0));
    expect(BlockDragHandleSpec.topInset, 1.0);
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
    final rowStart = editorRect.left +
        editorPadding +
        BlockDragHandleSpec.hitSize.width +
        BlockDragHandleSpec.gapToContent;
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

  testWidgets(
      'consecutive same-indent quote blocks fuse into one continuous background',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'lead-paragraph',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Lead paragraph flanking the run.'),
            ],
          ),
          TextBlockNode(
            id: 'run-first',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'First of the run')],
          ),
          TextBlockNode(
            id: 'run-empty',
            type: BlockType.quote,
            content: <InlineNode>[],
          ),
          TextBlockNode(
            id: 'run-last',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Last of the run')],
          ),
          TextBlockNode(
            id: 'indented-quote',
            type: BlockType.quote,
            attributes: BlockAttributes(indent: 1),
            content: <InlineNode>[TextRun(text: 'Different indent level')],
          ),
          TextBlockNode(
            id: 'gap-paragraph',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Gap paragraph between quotes.'),
            ],
          ),
          TextBlockNode(
            id: 'standalone-quote',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Standalone quote')],
          ),
        ],
      ),
    );

    await _pumpGoldenEditor(tester, controller, size: const Size(520, 720));

    const endRadius = Radius.circular(8);
    const fusedTolerance = 0.01;

    final backgroundFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    final accentFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-accent'),
    );
    // Five quote surfaces, in tree order: run first, run interior (empty),
    // run last, an indent:1 standalone, and a standalone flanked by paragraphs.
    expect(backgroundFinder, findsNWidgets(5));
    // The accent bar is drawn per block; adjacent accents stack to read as one
    // continuous rail now that the inter-quote gap is collapsed.
    expect(accentFinder, findsNWidgets(5));

    final rects = <Rect>[
      for (var i = 0; i < 5; i++) tester.getRect(backgroundFinder.at(i)),
    ];
    final radii = <BorderRadius>[
      for (var i = 0; i < 5; i++)
        _quoteBackgroundRadius(tester, backgroundFinder.at(i)),
    ];

    // Same-indent quotes share one left column; the indent:1 quote starts
    // further right and is treated as a separate standalone block.
    expect(rects[1].left, closeTo(rects[0].left, 0.001));
    expect(rects[2].left, closeTo(rects[1].left, 0.001));
    expect(rects[3].left, greaterThan(rects[2].left));

    // The run fuses: neighbours touch vertically with no default-spacing gap.
    expect(rects[1].top, closeTo(rects[0].bottom, fusedTolerance));
    expect(rects[2].top, closeTo(rects[1].bottom, fusedTolerance));
    expect(rects[1].top - rects[0].bottom, lessThan(1.0));
    expect(rects[2].top - rects[1].bottom, lessThan(1.0));

    // Corners redistribute by group position so the right join edge carries no
    // inward notch: first keeps only the top-end corner, interior is square on
    // both joins, last keeps only the bottom-end corner.
    expect(radii[0].topRight, endRadius);
    expect(radii[0].bottomRight, Radius.zero);
    expect(radii[1].topRight, Radius.zero);
    expect(radii[1].bottomRight, Radius.zero);
    expect(radii[2].topRight, Radius.zero);
    expect(radii[2].bottomRight, endRadius);

    // A different-indent neighbour keeps the default inter-block gap and stays
    // standalone (both end corners rounded) — the run must not absorb it.
    expect(rects[3].top - rects[2].bottom, greaterThan(4.0));
    expect(radii[3].topRight, endRadius);
    expect(radii[3].bottomRight, endRadius);

    // A quote flanked by non-quote blocks is standalone as well.
    expect(rects[4].top - rects[3].bottom, greaterThan(4.0));
    expect(radii[4].topRight, endRadius);
    expect(radii[4].bottomRight, endRadius);
  });

  testWidgets(
      'heading and list neighbours split quote runs into standalone groups',
      (tester) async {
    // Only quote -> quote fuses; a heading or list between two quotes breaks
    // the run so each side keeps its own end-side corners as an independent
    // group. Two runs (split by a heading) and a list-flanked standalone cover
    // the heading/list/paragraph adjacency cases for criterion P005.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'run-a-first',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Run A first')],
          ),
          TextBlockNode(
            id: 'run-a-last',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Run A last')],
          ),
          TextBlockNode(
            id: 'heading-split',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Heading between runs')],
          ),
          TextBlockNode(
            id: 'run-b-first',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Run B first')],
          ),
          TextBlockNode(
            id: 'run-b-last',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Run B last')],
          ),
          TextBlockNode(
            id: 'list-split',
            type: BlockType.listItem,
            attributes: BlockAttributes(listType: 'bullet'),
            content: <InlineNode>[TextRun(text: 'List item after run')],
          ),
          TextBlockNode(
            id: 'solo-quote',
            type: BlockType.quote,
            content: <InlineNode>[TextRun(text: 'Standalone after list')],
          ),
        ],
      ),
    );

    await _pumpGoldenEditor(tester, controller, size: const Size(520, 640));

    const endRadius = Radius.circular(8);

    final backgroundFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-quote-background'),
    );
    // Five quote surfaces in tree order: run A first/last, run B first/last,
    // and a list-flanked standalone.
    expect(backgroundFinder, findsNWidgets(5));

    final rects = <Rect>[
      for (var i = 0; i < 5; i++) tester.getRect(backgroundFinder.at(i)),
    ];
    final radii = <BorderRadius>[
      for (var i = 0; i < 5; i++)
        _quoteBackgroundRadius(tester, backgroundFinder.at(i)),
    ];

    // Within each run the same-indent column is shared.
    expect(rects[1].left, closeTo(rects[0].left, 0.001));
    expect(rects[3].left, closeTo(rects[2].left, 0.001));
    expect(rects[4].left, closeTo(rects[0].left, 0.001));

    // Each run fuses internally: neighbours touch with no default-spacing gap.
    expect(rects[1].top - rects[0].bottom, lessThan(1.0));
    expect(rects[3].top - rects[2].bottom, lessThan(1.0));

    // Corners distribute by group position within each fused run: the first
    // keeps only the top-end corner and the last keeps only the bottom-end.
    expect(radii[0].topRight, endRadius);
    expect(radii[0].bottomRight, Radius.zero);
    expect(radii[1].topRight, Radius.zero);
    expect(radii[1].bottomRight, endRadius);
    expect(radii[2].topRight, endRadius);
    expect(radii[2].bottomRight, Radius.zero);
    expect(radii[3].topRight, Radius.zero);
    expect(radii[3].bottomRight, endRadius);

    // A heading between the runs keeps the default inter-block gap, so the two
    // runs stay physically separate rather than absorbing into one surface.
    expect(rects[2].top - rects[1].bottom, greaterThan(4.0));

    // A list between a run and a trailing quote keeps the same default gap, and
    // the trailing quote is standalone with both end corners rounded.
    expect(rects[4].top - rects[3].bottom, greaterThan(4.0));
    expect(radii[4].topRight, endRadius);
    expect(radii[4].bottomRight, endRadius);
  });

  testWidgets('golden: paragraph code and image placeholder', (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'expanded-section',
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
            code: 'final ready = true;\nprint(ready);',
          ),
          ImageBlockNode(id: 'image', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'collapsed-section',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Collapsed details')],
          ),
          TextBlockNode(
            id: 'hidden-detail',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden detail')],
          ),
          TextBlockNode(
            id: 'leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'No children heading')],
          ),
        ],
      ),
    );
    final outlineController = WenzOutlineController(editor: controller);
    addTearDown(outlineController.dispose);
    expect(outlineController.collapseByBlockId('collapsed-section'), isTrue);

    // Includes the leading row chrome gutter reserved for block drag handles.
    await _pumpGoldenEditor(
      tester,
      controller,
      outlineController: outlineController,
      size: const Size(520, 420),
    );

    final expandedButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-expanded-section'),
    );
    final collapsedButton = find.byKey(
      const ValueKey<String>(
          'wenz-richtext-heading-collapse-collapsed-section'),
    );
    final leafButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-leaf'),
    );
    expect(expandedButton, findsOneWidget);
    expect(collapsedButton, findsOneWidget);
    // Leaf headings without children do not mount disabled collapse chrome.
    expect(leafButton, findsNothing);
    expect(find.text('Hidden detail'), findsNothing);
    // Collapse button sits in the left gutter at full size, with the same
    // explicit editable rail geometry as the widget regression tests.
    final expandedButtonRect = tester.getRect(expandedButton);
    final dragHandleRect = tester.getRect(
        _blockDragHandleFinder('expanded-section'));
    expect(expandedButtonRect.width, greaterThan(0));
    expect(expandedButtonRect.height, greaterThan(0));
    expect(
      expandedButtonRect.left - dragHandleRect.right,
      moreOrLessEquals(BlockDragHandleSpec.chromeGap, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(_richText('Expanded blocks')).dx -
          expandedButtonRect.right,
      moreOrLessEquals(BlockDragHandleSpec.gapToContent, epsilon: 0.5),
    );

    await tester.tap(expandedButton);
    await tester.pumpAndSettle();
    await tester.tap(expandedButton);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(collapsedButton));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_blocks.png'),
    );
  });

  testWidgets(
      'selected image toolbar floats without resize lines or layout shift',
      (tester) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'lead',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Lead paragraph')],
          ),
          ImageBlockNode(
            id: 'image1',
            assetId: 'hero',
            file: 'hero.png',
            width: 640,
            height: 320,
            showWidth: 300,
            showHeight: 150,
          ),
          TextBlockNode(
            id: 'after',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'After image paragraph')],
          ),
        ],
      ),
    );

    await _pumpGoldenEditorWithOverlayCapture(
      tester,
      controller,
      size: const Size(520, 420),
    );

    final imageBlockFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-image-block-image1'),
    );
    final imageFrameFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-image-frame-image1'),
    );
    final trailingTextFinder = _richText('After image paragraph');
    final initialBlockRect = tester.getRect(imageBlockFinder);
    final initialFrameRect = tester.getRect(imageFrameFinder);
    final initialTrailingRect = tester.getRect(trailingTextFinder);

    controller.setSelection(_objectBlockSelection('image1', 1));
    await tester.pump();
    await tester.pump();

    _expectRectClose(tester.getRect(imageBlockFinder), initialBlockRect);
    _expectRectClose(tester.getRect(imageFrameFinder), initialFrameRect);
    _expectRectClose(tester.getRect(trailingTextFinder), initialTrailingRect);

    final strokeFinder = find.byKey(
      const ValueKey<String>('wenz-richtext-media-selection-stroke'),
    );
    expect(strokeFinder, findsOneWidget);
    _expectRectClose(tester.getRect(strokeFinder), initialFrameRect);
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-image-resize-left-image1'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>('wenz-richtext-image-resize-right-image1'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-image-resize-hit-zone-left-image1',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'wenz-richtext-image-resize-hit-zone-right-image1',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(_selectionHighlightKey), findsNothing);

    expect(find.byTooltip('预览媒体'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);

    final toolbarRect = _toolbarButtonsRect(
      tester,
      const <String>['预览媒体', '更多块操作'],
    );
    final blockerRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('object-block-toolbar-hit-test-blocker'),
      ),
    );
    expect(toolbarRect.bottom, lessThanOrEqualTo(initialFrameRect.top));
    expect(
      toolbarRect.right,
      moreOrLessEquals(initialFrameRect.right, epsilon: 0.75),
    );
    expect(blockerRect.width, lessThan(initialFrameRect.width));
    expect(blockerRect.height, lessThan(64));
    expect(blockerRect.left, lessThanOrEqualTo(toolbarRect.left));
    expect(blockerRect.top, lessThanOrEqualTo(toolbarRect.top));
    expect(blockerRect.right, greaterThanOrEqualTo(toolbarRect.right));
    expect(blockerRect.bottom, greaterThanOrEqualTo(toolbarRect.bottom));

    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    expect(find.text('图片宽度：小'), findsOneWidget);
    expect(find.text('重置图片尺寸'), findsOneWidget);

    await tester.tap(find.text('图片宽度：小'));
    await tester.pumpAndSettle();

    final image = controller.document.blocks[1] as ImageBlockNode;
    expect(image.showWidth, 240);
    expect(image.showHeight, 120);
  });

  testWidgets('golden: block handle opens row action menu', (tester) async {
    await _pumpGoldenEditorWithOverlayCapture(
      tester,
      _blockHandleGoldenController(),
    );

    await tester.tap(_blockDragHandleFinder('menu-title'));
    await tester.pumpAndSettle();

    expect(find.text('复制块内容'), findsOneWidget);
    expect(find.text('复制块引用'), findsOneWidget);
    expect(find.text('更多块操作'), findsOneWidget);
    expect(find.text('删除块'), findsOneWidget);
    final deleteLabel = tester.widget<Text>(find.text('删除块'));
    expect(
      deleteLabel.style?.color,
      Theme.of(tester.element(find.text('删除块'))).colorScheme.error,
    );
    _expectBlockHandleMenuChrome(tester, '复制块内容');

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

  testWidgets('golden: table cell alignment per column', (tester) async {
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'table',
              table: TableModel(
                // Column-level alignments as fallback for cells that don't
                // specify their own. Every cell in this table explicitly
                // overrides it, so the column alignments are not used in
                // rendering — they merely assert the per-cell path is taken.
                columnAlignments: <int, String>{
                  0: 'left',
                  1: 'center',
                  2: 'right',
                  3: 'justify',
                },
                rows: <List<TableCellNode>>[
                  // Header row: one header cell per alignment flavour.
                  <TableCellNode>[
                    TableCellNode(
                      id: 'h0',
                      isHeader: true,
                      alignment: 'left',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'h0p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Left Header'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'h1',
                      isHeader: true,
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'h1p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Center Header'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'h2',
                      isHeader: true,
                      alignment: 'right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'h2p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Right Header'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'h3',
                      isHeader: true,
                      alignment: 'justify',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'h3p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Justify Header'),
                          ],
                        ),
                      ],
                    ),
                  ],
                  // Data row 1: short content to clearly show each alignment.
                  <TableCellNode>[
                    TableCellNode(
                      id: 'd10',
                      alignment: 'left',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd10p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Alpha')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd11',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd11p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Beta')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd12',
                      alignment: 'right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd12p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Gamma')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd13',
                      alignment: 'justify',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd13p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Short justify'),
                          ],
                        ),
                      ],
                    ),
                  ],
                  // Data row 2: longer text so justify can be distinguished
                  // from left-aligned text.
                  <TableCellNode>[
                    TableCellNode(
                      id: 'd20',
                      alignment: 'left',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd20p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Left aligned longer text'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd21',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd21p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Centered longer text'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd22',
                      alignment: 'right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd22p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(text: 'Right aligned longer'),
                          ],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'd23',
                      alignment: 'justify',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'd23p',
                          type: BlockType.paragraph,
                          content: <InlineNode>[
                            TextRun(
                              text: 'Justified text '
                                  'wraps across lines',
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
      ),
      // Wider surface so all four alignment columns have enough room to
      // show their effect.
      size: const Size(740, 360),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_table_alignment.png'),
    );
  });

  testWidgets('golden: centered table cell selection highlight', (
    tester,
  ) async {
    const selectedText = 'Centered selection';
    const neighbourText = 'Neighbour cell';
    await _pumpGoldenEditor(
      tester,
      WenzRichTextController(
        document: const RichTextDocument(
          blocks: <BlockNode>[
            TableBlockNode(
              id: 'center-selection-table',
              table: TableModel(
                columnWidths: <int, double>{0: 240, 1: 240},
                rows: <List<TableCellNode>>[
                  <TableCellNode>[
                    TableCellNode(
                      id: 'selected-cell',
                      alignment: 'center',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'selected-cell-text',
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
                  <TableCellNode>[
                    TableCellNode(
                      id: 'left-reference-cell',
                      alignment: 'left',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'left-reference-cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Left ref')],
                        ),
                      ],
                    ),
                    TableCellNode(
                      id: 'right-reference-cell',
                      alignment: 'right',
                      blocks: <BlockNode>[
                        TextBlockNode(
                          id: 'right-reference-cell-text',
                          type: BlockType.paragraph,
                          content: <InlineNode>[TextRun(text: 'Right ref')],
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
            tableBlockId: 'center-selection-table',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 0,
          ),
          extent: DocumentPosition.tableCell(
            tableBlockId: 'center-selection-table',
            blockIndex: 0,
            tableRowIndex: 0,
            tableColumnIndex: 0,
            offset: 8,
          ),
        ),
      ),
      size: const Size(560, 240),
    );

    expect(_richText(selectedText), findsOneWidget);
    expect(_richText(neighbourText), findsOneWidget);
    expect(find.byKey(_selectionHighlightKey), findsOneWidget);

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_table_selection_centered.png'),
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

    expect(_richText('Selected words stay highlighted.'), findsOneWidget);
    expect(
      find.byKey(_selectionHighlightKey),
      findsOneWidget,
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
          CodeBlockNode(
            id: 'advanced-code',
            language: 'dart',
            code: 'final ids = List.generate(100, (index) => "ticket-\$index");\n'
                'debugPrint(ids.join(", "));',
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
      size: const Size(520, 420),
    );

    expect(find.byTooltip('复制代码内容'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('复制代码内容')),
      const Size.square(32),
    );
    _expectGoldenToolbarButtonCapsule(tester, '复制代码内容');
    expect(find.text('release-spec.pdf'), findsOneWidget);
    expect(find.text('Retry required'), findsOneWidget);

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_advanced_blocks.png'),
    );
  });

  testWidgets(
      'golden: read-only heading collapse buttons without drag handles',
      (tester) async {
    // Read-only mode: collapse buttons are visible but drag handles are not.
    // The buttons keep the compact no-drag gutter without reserving the
    // editable drag-handle rail.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ro-h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[
              TextRun(text: 'Read-only collapsed'),
            ],
          ),
          TextBlockNode(
            id: 'ro-hidden',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Hidden paragraph')],
          ),
          TextBlockNode(
            id: 'ro-h2',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[
              TextRun(text: 'Read-only expanded'),
            ],
          ),
          TextBlockNode(
            id: 'ro-para',
            type: BlockType.paragraph,
            content: <InlineNode>[
              TextRun(text: 'Visible paragraph for reference'),
            ],
          ),
        ],
      ),
    );
    final outlineController = WenzOutlineController(editor: controller);
    addTearDown(outlineController.dispose);
    expect(outlineController.collapseByBlockId('ro-h1'), isTrue);

    const size = Size(520, 360);
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
                  readOnly: true,
                  enableIme: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Collapse buttons are present.
    final collapsedBtn = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-ro-h1'),
    );
    final expandedBtn = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-ro-h2'),
    );
    expect(collapsedBtn, findsOneWidget);
    expect(expandedBtn, findsOneWidget);
    // No drag handles in read-only mode.
    expect(
      find.byKey(
          const ValueKey<String>('wenz-richtext-block-drag-handle-ro-h1')),
      findsNothing,
    );
    // Hidden content is collapsed.
    expect(find.text('Hidden paragraph'), findsNothing);

    // Verify collapse buttons are visible (not zero-sized, not off-screen).
    final collapsedRect = tester.getRect(collapsedBtn);
    final expandedRect = tester.getRect(expandedBtn);
    expect(collapsedRect.width, greaterThan(0));
    expect(collapsedRect.height, greaterThan(0));
    expect(expandedRect.width, greaterThan(0));
    expect(expandedRect.height, greaterThan(0));
    expect(
      tester.getTopLeft(_richText('Read-only collapsed')).dx -
          collapsedRect.right,
      moreOrLessEquals(0, epsilon: 0.5),
    );
    expect(
      tester.getTopLeft(_richText('Read-only expanded')).dx,
      moreOrLessEquals(
        tester.getTopLeft(_richText('Visible paragraph for reference')).dx,
        epsilon: 0.5,
      ),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_readonly_heading_collapse.png'),
    );
  });

  testWidgets(
      'golden: heading collapse buttons with drag handles in editable mode',
      (tester) async {
    // Editable mode: collapsible headings show both a drag handle and a
    // collapse button in the left gutter. Leaf headings keep their text aligned
    // by the reserved rail without mounting disabled collapse chrome.
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'ed-h1',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Editable section')],
          ),
          TextBlockNode(
            id: 'ed-body',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'Editable body text')],
          ),
          TextBlockNode(
            id: 'ed-leaf',
            type: BlockType.heading,
            attributes: BlockAttributes(level: 2),
            content: <InlineNode>[TextRun(text: 'Editable leaf heading')],
          ),
        ],
      ),
    );
    final outlineController = WenzOutlineController(editor: controller);
    addTearDown(outlineController.dispose);

    await _pumpGoldenEditor(
      tester,
      controller,
      outlineController: outlineController,
      size: const Size(520, 320),
    );

    final sectionButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-ed-h1'),
    );
    final leafButton = find.byKey(
      const ValueKey<String>('wenz-richtext-heading-collapse-ed-leaf'),
    );
    expect(sectionButton, findsOneWidget);
    expect(leafButton, findsNothing);
    // Drag handles render alongside the collapse buttons in editable mode.
    expect(
      find.byKey(
          const ValueKey<String>('wenz-richtext-block-drag-handle-ed-h1')),
      findsOneWidget,
    );
    expect(_blockDragHandleFinder('ed-leaf'), findsOneWidget);

    // Collapse buttons are full-size and inside the gutter: drag handle,
    // chromeGap, collapse button, then gapToContent before content.
    final sectionRect = tester.getRect(sectionButton);
    final sectionHandleRect = tester.getRect(
      _blockDragHandleFinder('ed-h1'),
    );
    final sectionTextLeft = tester.getTopLeft(_richText('Editable section')).dx;
    expect(sectionRect.width, greaterThan(0));
    expect(sectionRect.height, greaterThan(0));
    expect(sectionRect.left, greaterThanOrEqualTo(0));
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
      tester.getTopLeft(_richText('Editable body text')).dx,
      moreOrLessEquals(sectionTextLeft, epsilon: 0.5),
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_heading_collapse_editable.png'),
    );
  });

  testWidgets('golden: editor light theme surface', (tester) async {
    await _pumpThemeSurfaceGoldenEditor(
      tester,
      _emptyThemeGoldenController(),
      brightness: Brightness.light,
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_theme_light.png'),
    );
  });

  testWidgets('golden: editor dark theme surface', (tester) async {
    await _pumpThemeSurfaceGoldenEditor(
      tester,
      _emptyThemeGoldenController(),
      brightness: Brightness.dark,
    );

    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/editor_theme_dark.png'),
    );
  });
}

Future<void> _pumpGoldenEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  WenzOutlineController? outlineController,
  Size size = const Size(520, 320),
}) async {
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
  WenzRichTextController controller, {
  Size size = const Size(520, 320),
}) async {
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

Future<void> _pumpThemeSurfaceGoldenEditor(
  WidgetTester tester,
  WenzRichTextController controller, {
  required Brightness brightness,
}) async {
  const size = Size(520, 320);
  final background =
      brightness == Brightness.dark ? Colors.black : Colors.white;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
        scaffoldBackgroundColor: background,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: _goldenKey,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: WenzRichTextEditor(
              controller: controller,
              enableIme: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

WenzRichTextController _emptyThemeGoldenController() {
  return WenzRichTextController(
    document: const RichTextDocument(blocks: <BlockNode>[]),
  );
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

DocumentSelection _objectBlockSelection(String blockId, int blockIndex) {
  final start = DocumentPosition(
    blockId: blockId,
    blockIndex: blockIndex,
    path: PositionPath.blockObject(blockId),
    offset: 0,
  );
  return DocumentSelection(base: start, extent: start.copyWith(offset: 1));
}

Rect _toolbarButtonsRect(WidgetTester tester, List<String> tooltips) {
  assert(tooltips.isNotEmpty);
  var rect = tester.getRect(find.byTooltip(tooltips.first));
  for (final tooltip in tooltips.skip(1)) {
    rect = rect.expandToInclude(tester.getRect(find.byTooltip(tooltip)));
  }
  return rect;
}

void _expectRectClose(Rect actual, Rect expected, {double epsilon = 0.001}) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: epsilon));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: epsilon));
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: epsilon));
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: epsilon));
}

void _expectBlockHandleMenuChrome(WidgetTester tester, String itemLabel) {
  final materialFinder = find.ancestor(
    of: find.text(itemLabel),
    matching: find.byWidgetPredicate(
      (widget) => widget is Material && widget.elevation == 3,
    ),
  );
  expect(materialFinder, findsOneWidget);
  final material = tester.widget<Material>(materialFinder);
  final theme = Theme.of(tester.element(materialFinder));
  expect(
    material.color,
    theme.brightness == Brightness.dark
        ? const Color(0xFF292A2D)
        : const Color(0xFFF8F9FA),
  );
  expect(material.shadowColor, theme.colorScheme.shadow.withAlpha(30));
  expect(material.surfaceTintColor, Colors.transparent);
  expect(material.clipBehavior, Clip.antiAlias);
  final shape = material.shape as RoundedRectangleBorder;
  expect(shape.borderRadius, BorderRadius.circular(10));
  expect(
    shape.side.color,
    theme.brightness == Brightness.dark
        ? const Color(0xFF4A4C50)
        : const Color(0xFFDADCE0),
  );
}

void _expectGoldenToolbarButtonCapsule(
  WidgetTester tester,
  String tooltip,
) {
  final button = _iconButtonByTooltip(tester, tooltip);
  final style = button.style;
  expect(style, isNotNull);
  // Background is now transparent for all states — no independent capsule.
  for (final states in <Set<WidgetState>>[
    <WidgetState>{},
    <WidgetState>{WidgetState.disabled},
    <WidgetState>{WidgetState.hovered},
    <WidgetState>{WidgetState.pressed},
  ]) {
    expect(
      style!.fixedSize?.resolve(states),
      const Size.square(32),
    );
    final background = style.backgroundColor?.resolve(states);
    expect(background, Colors.transparent);
    final shape = style.shape?.resolve(states);
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
  }
  // Hover / pressed states still show semi-transparent overlay highlight.
  for (final states in <Set<WidgetState>>[
    <WidgetState>{WidgetState.hovered},
    <WidgetState>{WidgetState.pressed},
  ]) {
    final overlay = style!.overlayColor?.resolve(states);
    expect(overlay, isNotNull);
    expect(overlay, isNot(Colors.transparent));
  }
}

IconButton _iconButtonByTooltip(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  final matchedWidget = tooltipFinder.evaluate().single.widget;
  if (matchedWidget is IconButton) {
    return matchedWidget;
  }
  return tester.widget<IconButton>(
    find.ancestor(
      of: tooltipFinder,
      matching: find.byType(IconButton),
    ),
  );
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

/// Resolved (LTR) border radius of the quote background found by [finder], so
/// tests can assert which end-side corners stay rounded per group position.
BorderRadius _quoteBackgroundRadius(WidgetTester tester, Finder finder) {
  final decoration =
      tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
  final borderRadius = decoration.borderRadius ?? BorderRadius.zero;
  return borderRadius.resolve(TextDirection.ltr);
}

