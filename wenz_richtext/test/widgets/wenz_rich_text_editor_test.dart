import 'dart:convert';
import 'dart:ui' show ImageByteFormat, LineMetrics, PointerDeviceKind, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const String _formulaPlaceholder = '\uFFFC';
const _inlineFormulaKey = ValueKey<String>('wenz-richtext-inline-formula');
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
    expect(firstRect.height, moreOrLessEquals(28, epsilon: 0.5));
    expect(
      secondRect.top - firstRect.bottom,
      moreOrLessEquals(8.8, epsilon: 0.75),
    );
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
    expect(leafButton, findsOneWidget);
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
    expect(
      tester.widget<IconButton>(leafButton).tooltip,
      '无可折叠内容',
    );
    expect(tester.widget<IconButton>(leafButton).onPressed, isNull);
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
    expect(find.text('3'), findsOneWidget);
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
    expect(
      indentedRect.left - editorRect.left,
      moreOrLessEquals(BlockDragHandleSpec.railWidth + 48, epsilon: 0.5),
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
    expect(
      decoration.borderRadius,
      const BorderRadiusDirectional.only(
        topEnd: Radius.circular(8),
        bottomEnd: Radius.circular(8),
      ),
    );
    expect(decoration.border, isNull);
    final editorRect = tester.getRect(find.byType(WenzRichTextEditor));
    final expectedQuoteLeft =
        editorRect.left + 16 + BlockDragHandleSpec.railWidth;
    final expectedQuoteRight = editorRect.right - 16;
    final firstQuoteRect = tester.getRect(backgroundFinder.first);
    final secondQuoteRect = tester.getRect(backgroundFinder.last);
    expect(firstQuoteRect.left, closeTo(expectedQuoteLeft, 0.001));
    expect(firstQuoteRect.right, closeTo(expectedQuoteRight, 0.001));
    expect(secondQuoteRect.left, closeTo(expectedQuoteLeft, 0.001));
    expect(secondQuoteRect.right, closeTo(expectedQuoteRight, 0.001));
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

    expect(find.byTooltip('复制代码'), findsOneWidget);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
    _expectToolbarButtonSize(tester, '复制代码');
    _expectToolbarButtonSize(tester, '更多块操作');
    expect(find.text('dart'), findsNothing);

    await tester.tap(find.byTooltip('复制代码'));
    await tester.pump();
    expect(clipboardText, 'final value = 1;');

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('python'));
    await tester.pumpAndSettle();

    expect((controller.document.blocks.single as CodeBlockNode).language,
        'python');
  });

  testWidgets(
    'code block syntax highlights supported languages and leaves unsupported plain',
    (tester) async {
      const dartCode = 'final value = 42; // done\nString name = "Ada";';
      const jsCode = 'const answer = 42; // ok';
      const jsonCode = '{"ok": true, "n": 3}';
      const markdownCode = '# Title\n- item with `code`';
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

    final codeSpan = _richTextSpan(tester, longCode);
    expect(codeSpan.style?.color, _codeBlockText);
    expect(codeSpan.style?.fontFamily, 'JetBrains Mono');
    expect(codeSpan.style?.fontSize, 13.5);
    expect(codeSpan.style?.height, 1.6);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey<String>('wenz-richtext-code-scroll-code1')),
    );
    expect(scroll.scrollDirection, Axis.horizontal);
    expect(find.text('dart'), findsNothing);
    expect(find.byTooltip('更多块操作'), findsOneWidget);
    final blockRect = tester.getRect(
      find.byKey(const ValueKey<String>('wenz-richtext-code-block-code1')),
    );
    final codeRect = tester.getRect(_richText(longCode));
    final copyButtonRect = tester.getRect(find.byTooltip('复制代码'));
    expect(codeRect.top - blockRect.top, lessThan(24));
    expect(copyButtonRect.bottom, lessThanOrEqualTo(blockRect.top));
    expect(copyButtonRect.right, lessThanOrEqualTo(blockRect.right));
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

    final imageRect = tester.getRect(_imageBlockFinder('image1'));
    final moreButtonRect = tester.getRect(find.byTooltip('更多块操作'));
    expect(moreButtonRect.top, lessThanOrEqualTo(imageRect.top + 40));
    expect(moreButtonRect.right, lessThanOrEqualTo(imageRect.right));

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();

    expect(_popupMenuItemFinder('图片宽度：小'), findsOneWidget);
    expect(_popupMenuItemFinder('创建块副本'), findsOneWidget);
    final menuRect = tester.getRect(_popupMenuItemFinder('图片宽度：小'));
    final viewportRect = tester.getRect(
      find.byKey(const ValueKey<String>('compact-object-menu-viewport')),
    );
    expect(menuRect.left, greaterThanOrEqualTo(viewportRect.left));
    expect(menuRect.right, lessThanOrEqualTo(viewportRect.right));
    expect(menuRect.top, greaterThanOrEqualTo(viewportRect.top));

    await tester.tap(_popupMenuItemFinder('图片宽度：小'));
    await tester.pumpAndSettle();

    final image = controller.document.blocks.single as ImageBlockNode;
    expect(image.showWidth, 240);
    expect(image.showHeight, 120);
  });

  testWidgets('object block toolbar copies duplicates moves and deletes', (
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
          ImageBlockNode(id: 'image1', assetId: 'hero', file: 'hero.png'),
          TextBlockNode(
            id: 'p1',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'after')],
          ),
        ],
      ),
      selection: objectBlockSelection('image1', 1),
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
    expect(find.byTooltip('复制块引用'), findsOneWidget);
    _expectToolbarButtonSize(tester, '预览媒体');
    _expectToolbarButtonSize(tester, '复制块引用');
    _expectToolbarButtonSize(tester, '更多块操作');
    expect(find.byTooltip('创建块副本'), findsNothing);
    expect(find.byTooltip('删除块'), findsNothing);
    final imageRect = tester.getRect(_imageBlockFinder('image1'));
    final previewButtonRect = tester.getRect(find.byTooltip('预览媒体'));
    expect(previewButtonRect.top, greaterThanOrEqualTo(imageRect.top));
    expect(previewButtonRect.top, lessThan(imageRect.top + 40));
    expect(previewButtonRect.right, lessThanOrEqualTo(imageRect.right));

    await tester.tap(find.byTooltip('复制块引用'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'hero.png');

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('创建块副本'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks, hasLength(4));
    final duplicate = controller.document.blocks[2] as ImageBlockNode;
    expect(duplicate.id, isNot('image1'));
    expect(duplicate.file, 'hero.png');
    expect(controller.selection?.extent.blockId, duplicate.id);
    expect(controller.selection?.extent.blockIndex, 2);

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上移块'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks[1].id, duplicate.id);
    expect(controller.document.blocks[2].id, 'image1');
    expect(controller.selection?.extent.blockIndex, 1);

    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    await tester.tap(_popupMenuItemFinder('删除块'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks, hasLength(3));
    expect(controller.document.blocks[1].id, 'image1');
    expect(
      controller.document.blocks.map((block) => block.id),
      isNot(contains(duplicate.id)),
    );
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
    expect(handleOpacity().opacity, BlockDragHandleSpec.idleOpacity);
    await mouse.moveTo(tester.getCenter(handle));
    await tester.pump();
    expect(handleOpacity().opacity, BlockDragHandleSpec.hoverOpacity);
    await mouse.removePointer();

    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(controller.selection, isNull);
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

    await tester.tap(_popupMenuItemFinder('下移块'));
    await tester.pumpAndSettle();

    expect(
      controller.document.blocks.map((block) => block.id),
      <String>['code1', 'p0', 'divider1'],
    );
    expect(controller.selection?.extent.blockId, 'p0');
    expect(controller.selection?.extent.blockIndex, 1);
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
            enableIme: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_blockDragHandleFinder('image1'));
    await tester.pumpAndSettle();
    expect(find.text('更多块操作'), findsOneWidget);
    expect(find.text('上移块'), findsNothing);
    expect(find.text('下移块'), findsNothing);

    await tester.tap(_popupMenuItemFinder('复制块引用'));
    await tester.pumpAndSettle();
    expect(clipboardText, 'hero.png');

    await tester.tap(_blockDragHandleFinder('image1'));
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
      <String>['p0', 'p1', 'image1'],
    );
    expect(controller.selection?.extent.blockId, 'image1');
    expect(controller.selection?.extent.blockIndex, 2);

    await tester.tap(_blockDragHandleFinder('image1'));
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
        editorBox.left + BlockDragHandleSpec.railWidth / 2,
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
    final imageRect = tester.getRect(_imageBlockFinder('image1'));
    final moreButtonRect = tester.getRect(find.byTooltip('更多块操作'));
    expect(
      moreButtonRect.top,
      lessThanOrEqualTo(imageRect.top + 40),
    );
    expect(moreButtonRect.right, lessThanOrEqualTo(imageRect.right));

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
    _expectLocalizedTooltip('复制代码');
    _expectLocalizedTooltip('更多块操作');
    expect(find.text('dart'), findsNothing);
    await tester.tap(find.byTooltip('更多块操作'));
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
      '复制块引用',
      '更多块操作',
    ]) {
      _expectLocalizedTooltip(tooltip);
    }
    expect(find.byTooltip('创建块副本'), findsNothing);
    expect(find.byTooltip('删除块'), findsNothing);
    await tester.tap(find.byTooltip('更多块操作'));
    await tester.pumpAndSettle();
    for (final label in <String>[
      '创建块副本',
      '上移块',
      '下移块',
      '图片宽度：小',
      '图片宽度：中',
      '图片宽度：大',
      '重置图片尺寸',
      '删除块',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

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
      '列左对齐',
      '列居中对齐',
      '列右对齐',
      '清除列对齐',
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

  testWidgets('divider uses design rule dot and keeps selected actions clear', (
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
    expect((shell.border as Border).top.color, theme.colorScheme.primary);
    expect((shell.border as Border).top.width, 1.5);

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
    expect(find.byTooltip('复制块引用'), findsOneWidget);
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

    await pressTableMoreItem('列居中对齐');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnAlignments[0], 'center');

    await pressTableMoreItem('清除单元格背景');
    table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.cellAt(0, 0)!.backgroundColor, isNull);

    await pressTableMoreItem('清除列对齐');
    table = controller.document.blocks.single as TableBlockNode;
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
    final dividerFinder = find.descendant(
      of: toolbarFinder,
      matching: find.byType(VerticalDivider),
    );
    expect(dividerFinder, findsWidgets);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(
      location: tester.getRect(find.byTooltip('在下方插入行')).center,
    );
    await tester.pump();
    await gesture.moveTo(tester.getRect(dividerFinder.first).center);
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

    await tester.drag(
      find.byKey(const ValueKey<String>('table-resize-table1-0')),
      const Offset(40, 0),
    );
    await tester.pump();

    final table = controller.document.blocks.single as TableBlockNode;
    expect(table.table.columnWidths[0], isNotNull);
    expect(table.table.columnWidths[0]!, greaterThan(48));
  });

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

  testWidgets('aligns todo checkbox with adjusted text line height',
      (tester) async {
    const singleLineText = 'Ship core';
    const wrappedText =
        'Ship a wrapped todo item with enough words to span two lines';
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
    final singleFirstLineCenter =
        _richTextFirstLineCenterY(tester, singleTextFinder);
    final wrappedFirstLineCenter =
        _richTextFirstLineCenterY(tester, wrappedTextFinder);
    final singleCheckboxOffset =
        singleCheckboxRect.center.dy - singleFirstLineCenter;
    final wrappedCheckboxOffset =
        wrappedCheckboxRect.center.dy - wrappedFirstLineCenter;
    final wrappedLineMetrics = _richTextLineMetrics(tester, wrappedTextFinder);

    expect(singleCheckboxRect.size, const Size(24, 28));
    expect(wrappedCheckboxRect.size, const Size(24, 28));
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
        tester.getRect(wrappedTextFinder).left,
        greaterThanOrEqualTo(wrappedCheckboxRect.right),
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

  testWidgets('updated shortcut configuration is used without controller swap', (
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

  testWidgets('media toolbar preview opens image and video preview',
      (tester) async {
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
    await tester.tap(find.byTooltip('预览媒体'));
    await tester.pumpAndSettle();
    expect(find.text('preview:video1'), findsNWidgets(2));
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
                data: <String, Object?>{'label': 'bob'},
              ),
              TextRun(text: 'C'),
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
            autofocus: true,
            enableIme: false,
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

    await _tapSingle(tester, mentionRight);
    _expectBlockTextSelection(
      controller.selection,
      blockId: 'p-inline',
      blockIndex: 0,
      baseOffset: 4,
      extentOffset: 4,
    );

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
                            data: <String, Object?>{'label': 'bob'},
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

      controller.replaceDocument(measuredDocument(tallBlock: false));
      await tester.pumpAndSettle();

      expect(
        scrollable().position.maxScrollExtent,
        lessThan(maxAfterTallMeasured - 200),
      );
    });

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
}

Future<void> _sendShiftArrowRight(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Finder _richText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

TextSpan _richTextSpan(WidgetTester tester, String text) {
  return tester.widget<RichText>(_richText(text)).text as TextSpan;
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

Finder _videoBlockFinder(String blockId) {
  return find.byKey(ValueKey<String>('wenz-richtext-video-block-$blockId'));
}

Finder _blockDragHandleFinder(String blockId) {
  return find.byKey(
    ValueKey<String>('wenz-richtext-block-drag-handle-$blockId'),
  );
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

void _expectToolbarButtonSize(WidgetTester tester, String tooltip) {
  expect(find.byTooltip(tooltip), findsOneWidget);
  expect(
    tester.getSize(find.byTooltip(tooltip)),
    const Size.square(32),
    reason: '$tooltip should use the shared block toolbar button hit area.',
  );
}

Future<void> _pumpTableToolbarOverlay(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
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

DecoratedBox _tableCellBorderBox(
  WidgetTester tester,
  String tableBlockId,
  int rowIndex,
  int columnIndex,
) {
  return tester.widget<DecoratedBox>(
    find.byKey(
      ValueKey<String>(
          'table-cell-border-$tableBlockId-$rowIndex-$columnIndex'),
    ),
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
  )..layout(maxWidth: size.width);
  final local = painter.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  return tester.getTopLeft(finder) +
      local +
      Offset(1, painter.preferredLineHeight / 2);
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
  )..layout(maxWidth: size.width);
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
