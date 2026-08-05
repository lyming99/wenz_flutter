import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

import '../helpers/selection_test_helpers.dart';

const double _kDefaultToolbarHorizontalPadding = 12.0;
const double _kGeometryTolerance = 0.1;

void main() {
  group('WenzDefaultDesktopToolbar rendering', () {
    testWidgets('renders core tooltips and derives enabled state', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      for (final tooltip in const <String>[
        '加粗',
        '斜体',
        '下划线',
        '删除线',
        '文字颜色',
        '清除样式',
        '插入元素',
        '正文',
        '引用',
        '任务列表',
        '有序列表',
        '无序列表',
        '行内代码',
        '对齐方式：无对齐',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }

      _expectDefaultToolbarSequence(tester);

      for (final tooltip in const <String>[
        '撤销',
        '重做',
        '批注',
        '表情',
        '增加缩进',
        '减少缩进',
        '无文字颜色',
        '添加链接',
        '编辑链接',
        '公式',
        '插入代码块',
        '插入标注',
        '插入表格',
        '块样式：正文',
        '块样式：H1',
        '块样式：混合',
        '一级标题',
        '二级标题',
        '三级标题',
        '段落',
        '左对齐',
        '居中对齐',
        '右对齐',
        '两端对齐',
        '清除对齐',
      ]) {
        expect(find.byTooltip(tooltip), findsNothing);
      }

      expect(_iconButton(tester, '加粗').onPressed, isNotNull);
      expect(_iconButton(tester, '插入元素').onPressed, isNotNull);
      expect(_textButton(tester, '正文').onPressed, isNotNull);
      expect(_textButton(tester, '对齐方式：无对齐').onPressed, isNotNull);

      await _openBlockStyleMenu(tester, '正文');
      for (final label in const <String>[
        'H1',
        'H2',
        'H3',
        'H4',
        'H5',
        'H6',
        '正文',
      ]) {
        expect(_menuItemButton(tester, label).onPressed, isNotNull);
      }
      await tester.tap(_textButtonFinder('正文'));
      await tester.pump();

      await _openAlignmentMenu(tester, '对齐方式：无对齐');
      for (final label in const <String>[
        '左对齐',
        '居中对齐',
        '右对齐',
        '两端对齐',
        '清除对齐',
      ]) {
        expect(_menuItemButton(tester, label).onPressed, isNotNull);
      }
      await tester.tap(_textButtonFinder('对齐方式：无对齐'));
      await tester.pump();

      await _openInsertMenu(tester);
      for (final label in const <String>[
        '添加链接',
        '公式',
        '插入代码块',
        '插入标注',
        '插入表格',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('表情'), findsNothing);

      for (final permission in <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        await _pumpToolbar(
          tester,
          permission: permission,
          selection: textSelection('p1', 0, 0, 5),
        );

        for (final tooltip in const <String>[
          '加粗',
          '斜体',
          '下划线',
          '删除线',
          '清除样式',
        ]) {
          expect(_iconButton(tester, tooltip).onPressed, isNull);
        }
        expect(_iconButton(tester, '文字颜色不可用').onPressed, isNotNull);
        expect(_iconButton(tester, '插入元素').onPressed, isNotNull);
        expect(_textButton(tester, '正文').onPressed, isNull);
        expect(_textButton(tester, '对齐方式：无对齐').onPressed, isNull);

        await _openInsertMenu(tester);
        for (final label in const <String>[
          '添加链接',
          '公式',
          '插入代码块',
          '插入标注',
          '插入表格',
        ]) {
          expect(_menuItemButton(tester, label).onPressed, isNull);
        }
      }
    });

    testWidgets('shows fallback body style for mixed block style state', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        document: _mixedBlockStyleDocument(),
        selection: _mixedBlockStyleSelection(),
      );

      expect(find.byTooltip('正文'), findsOneWidget);
      expect(find.byTooltip('块样式：混合'), findsNothing);
      expect(_textButton(tester, '正文').onPressed, isNotNull);
      _expectMutedTextButton(tester, '正文');
    });

    testWidgets('shows fallback body style for unsupported block style', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        document: _unsupportedBlockStyleDocument(),
        selection: collapsedTextSelection('p1', 0, 0),
      );

      expect(find.byTooltip('正文'), findsOneWidget);
      expect(_textButton(tester, '正文').onPressed, isNotNull);
      _expectMutedTextButton(tester, '正文');
    });

    testWidgets('lays out default actions as one left-aligned sequence', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      _expectDefaultToolbarSequence(tester);
      _expectToolbarStartsAtPadding(tester);
      expect(_iconButton(tester, '无序列表').onPressed, isNotNull);
      expect(_textButton(tester, '对齐方式：无对齐').onPressed, isNotNull);
      expect(_iconButton(tester, '插入元素').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls horizontally at narrow width without wrapping', (
      tester,
    ) async {
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        width: 320,
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      _expectDefaultToolbarSequence(tester);
      _expectToolbarStartsAtPadding(tester);
      expect(find.byTooltip('插入元素').hitTestable(), findsNothing);

      await _scrollToolbarUntilVisible(tester, '无序列表');
      expect(find.byTooltip('无序列表').hitTestable(), findsOneWidget);
      await _scrollToolbarUntilVisible(tester, '对齐方式：无对齐');
      expect(find.byTooltip('对齐方式：无对齐').hitTestable(), findsOneWidget);
      await _scrollToolbarUntilVisible(tester, '插入元素');
      expect(find.byTooltip('插入元素').hitTestable(), findsOneWidget);
      expect(_iconButton(tester, '无序列表').onPressed, isNotNull);
      expect(_textButton(tester, '对齐方式：无对齐').onPressed, isNotNull);
      expect(_iconButton(tester, '插入元素').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('maps an ordinary mouse wheel to horizontal toolbar scrolling',
        (tester) async {
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        width: 320,
      );

      final listener =
          find.byKey(const ValueKey('wenz.desktop-toolbar.wheel-scroll'));
      final scrollable = find.descendant(
        of: listener,
        matching: find.byType(Scrollable),
      );
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));

      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(listener),
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pump();

      expect(state.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls narrow overflow to extension and end actions', (
      tester,
    ) async {
      final calls = <String>[];
      final registry = WenzToolbarItemRegistry(<WenzToolbarItem>[
        WenzToolbarItem(
          id: 'extension-action',
          title: 'Extension action',
          tooltip: 'Extension action',
          priority: 0,
          action: (_, __) => calls.add('extension'),
        ),
      ]);
      await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        toolbarItemRegistry: registry,
        width: 320,
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      _expectToolbarSequence(tester, const <String>[
        '有序列表',
        'Extension action',
        '无序列表',
        '对齐方式：无对齐',
        '插入元素',
      ]);
      expect(find.byTooltip('Extension action').hitTestable(), findsNothing);

      await _scrollToolbarUntilVisible(tester, 'Extension action');
      expect(find.byTooltip('Extension action').hitTestable(), findsOneWidget);
      await _tapToolbarButton(tester, 'Extension action');
      expect(calls, <String>['extension']);

      await _scrollToolbarUntilVisible(tester, '插入元素');
      expect(find.byTooltip('插入元素').hitTestable(), findsOneWidget);
      await _openInsertMenu(tester);
      expect(find.text('插入表格'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resource actions hide, disable, pending, and invoke context', (
      tester,
    ) async {
      await _pumpToolbar(tester);
      _expectDefaultToolbarSequence(tester);
      await _openInsertMenu(tester);
      expect(find.text('插入图片'), findsNothing);
      expect(find.text('插入视频'), findsNothing);
      expect(find.text('插入文件'), findsNothing);
      expect(find.text('插入业务嵌入'), findsNothing);

      final disabledHarness = await _pumpToolbar(
        tester,
        actions: const WenzDefaultDesktopToolbarActions(
          imageUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          videoUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          fileUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
          blockEmbedUnavailablePolicy:
              WenzDefaultDesktopToolbarUnavailablePolicy.disable,
        ),
      );
      _expectDefaultToolbarSequence(tester);
      await _openInsertMenu(tester);
      expect(find.text('插入图片不可用'), findsOneWidget);
      expect(find.text('插入视频不可用'), findsOneWidget);
      expect(find.text('插入文件不可用'), findsOneWidget);
      expect(find.text('插入业务嵌入不可用'), findsOneWidget);
      expect(_menuItemButton(tester, '插入图片不可用').onPressed, isNull);
      expect(_menuItemButton(tester, '插入视频不可用').onPressed, isNull);
      expect(_menuItemButton(tester, '插入文件不可用').onPressed, isNull);
      expect(_menuItemButton(tester, '插入业务嵌入不可用').onPressed, isNull);

      final contexts = <WenzDefaultDesktopToolbarActionContext>[];
      await _pumpToolbar(
        tester,
        controller: disabledHarness.controller,
        toolbar: disabledHarness.toolbar,
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: contexts.add,
          onInsertVideo: contexts.add,
          onInsertFile: contexts.add,
          onInsertBlockEmbed: contexts.add,
        ),
      );
      _expectDefaultToolbarSequence(tester);

      await _openInsertMenu(tester);
      for (final label in const <String>[
        '添加链接',
        '公式',
        '插入代码块',
        '插入标注',
        '插入表格',
        '插入图片',
        '插入视频',
        '插入文件',
        '插入业务嵌入',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('表情'), findsNothing);
      await tester.tap(find.byTooltip('插入元素'));
      await tester.pump();

      for (final tooltip in const <String>[
        '插入图片',
        '插入视频',
        '插入文件',
        '插入业务嵌入',
      ]) {
        await _tapInsertMenuItem(tester, tooltip);
      }
      expect(contexts, hasLength(4));
      expect(contexts.first.controller, same(disabledHarness.controller));
      expect(contexts.first.toolbar, same(disabledHarness.toolbar));
      expect(contexts.first.state.hasSelection, isTrue);
      expect(contexts[1].controller, same(disabledHarness.controller));
      expect(contexts[1].toolbar, same(disabledHarness.toolbar));
      expect(contexts[1].state.hasSelection, isTrue);

      await _pumpToolbar(
        tester,
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: contexts.add,
          isPickingImage: true,
        ),
      );
      _expectDefaultToolbarSequence(tester);
      await _openInsertMenu(tester);
      expect(find.text('正在选择图片'), findsOneWidget);
      expect(_menuItemButton(tester, '正在选择图片').onPressed, isNull);

      for (final permission in <WenzEditorPermission>[
        WenzEditorPermission.read,
        WenzEditorPermission.comment,
      ]) {
        var mediaCalls = 0;
        await _pumpToolbar(
          tester,
          permission: permission,
          actions: WenzDefaultDesktopToolbarActions(
            onInsertImage: (_) => mediaCalls++,
            onInsertVideo: (_) => mediaCalls++,
          ),
        );
        _expectDefaultToolbarSequence(tester);
        await _openInsertMenu(tester);
        expect(_menuItemButton(tester, '插入图片').onPressed, isNull);
        expect(_menuItemButton(tester, '插入视频').onPressed, isNull);
        await tester.tap(find.text('插入图片'), warnIfMissed: false);
        await tester.tap(find.text('插入视频'), warnIfMissed: false);
        await tester.pump();
        expect(mediaCalls, 0);
      }
    });
  });

  group('WenzDefaultDesktopToolbar commands', () {
    testWidgets('toggles marks through toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isFalse);

      await _tapToolbarButton(tester, '加粗');
      expect(_iconButton(tester, '加粗').isSelected, isTrue);
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isTrue);

      await _tapToolbarButton(tester, '斜体');
      expect(_iconButton(tester, '斜体').isSelected, isTrue);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isTrue,
      );

      await _tapToolbarButton(tester, '下划线');
      expect(_iconButton(tester, '下划线').isSelected, isTrue);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.underline == true),
        isTrue,
      );

      await _tapToolbarButton(tester, '删除线');
      expect(_iconButton(tester, '删除线').isSelected, isTrue);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.lineThrough == true,
        ),
        isTrue,
      );

      expect(
        find.byKey(const ValueKey<String>('rich-inline-code-toggle')),
        findsOneWidget,
      );
      await _tapToolbarButton(tester, '行内代码');
      expect(_iconButton(tester, '移除行内代码').isSelected, isTrue);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.inlineCode == true,
        ),
        isTrue,
      );

      await _tapToolbarButton(tester, '清除样式');
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isFalse);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.italic == true),
        isFalse,
      );
      expect(
        _hasRun(harness.controller, (run) => run.attributes.underline == true),
        isFalse,
      );
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.lineThrough == true,
        ),
        isFalse,
      );
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.inlineCode == true,
        ),
        isFalse,
      );
    });

    testWidgets('sets block type, list, and alignment', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      for (var level = 1; level <= 6; level++) {
        await _tapBlockStyleMenuItem(
          tester,
          'H$level',
          '正文',
        );
        var block = _textBlock(harness.controller, 'p1');
        expect(block.type, BlockType.heading);
        expect(block.attributes.level, level);
        expect(
          _textButton(tester, 'H$level').onPressed,
          isNotNull,
        );

        await _tapBlockStyleMenuItem(tester, '正文', 'H$level');
        block = _textBlock(harness.controller, 'p1');
        expect(block.type, BlockType.paragraph);
        expect(_textButton(tester, '正文').onPressed, isNotNull);
      }

      var block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.paragraph);
      expect(_textButton(tester, '正文').onPressed, isNotNull);

      await _tapToolbarButton(tester, '有序列表');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, 'ordered');

      await _tapToolbarButton(tester, '无序列表');
      block = _textBlock(harness.controller, 'p1');
      expect(block.type, BlockType.listItem);
      expect(block.attributes.listType, isNull);

      var currentAlignmentTooltip = '对齐方式：无对齐';
      for (final entry in const <String, String>{
        '左对齐': 'left',
        '居中对齐': 'center',
        '右对齐': 'right',
        '两端对齐': 'justify',
      }.entries) {
        await _tapAlignmentMenuItem(
          tester,
          entry.key,
          currentAlignmentTooltip,
        );
        block = _textBlock(harness.controller, 'p1');
        expect(block.attributes.alignment, entry.value);
        currentAlignmentTooltip = '对齐方式：${entry.key}';
        expect(
          _textButton(tester, currentAlignmentTooltip).onPressed,
          isNotNull,
        );
      }

      await _tapAlignmentMenuItem(tester, '清除对齐', currentAlignmentTooltip);
      block = _textBlock(harness.controller, 'p1');
      expect(block.attributes.alignment, isNull);
      expect(_textButton(tester, '对齐方式：无对齐').onPressed, isNotNull);
    });

    testWidgets('uses text color palette, custom color, and mixed tooltips', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      expect(find.byTooltip('文字颜色'), findsOneWidget);
      expect(find.byTooltip('无文字颜色'), findsNothing);

      await _openTextColorMenu(tester, '文字颜色');
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
      for (final tooltip in const <String>[
        '黑色 #FF111827',
        '深灰 #FF374151',
        '岩灰 #FF455A64',
        '红色 #FFD32F2F',
        '橙色 #FFF57C00',
        '黄色 #FFFBC02D',
        '绿色 #FF388E3C',
        '墨绿 #FF0F766E',
        '青色 #FF0097A7',
        '蓝色 #FF1976D2',
        '紫色 #FF7B1FA2',
        '粉色 #FFC2185B',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
        expect(_menuItemButtonByTooltip(tester, tooltip).onPressed, isNotNull);
        _expectTextColorSwatchSelected(tester, tooltip, selected: false);
      }
      expect(find.text('红色'), findsNothing);
      expect(find.text('自定义颜色'), findsOneWidget);
      expect(find.byTooltip('自定义文字颜色'), findsOneWidget);
      expect(_menuItemButton(tester, '无文字颜色').onPressed, isNotNull);

      await _tapTextColorSwatch(tester, '红色 #FFD32F2F');
      expect(find.byTooltip('文字颜色 #FFD32F2F'), findsOneWidget);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFFD32F2F,
        ),
        isTrue,
      );

      await _openTextColorMenu(tester, '文字颜色 #FFD32F2F');
      _expectTextColorSwatchSelected(
        tester,
        '红色 #FFD32F2F',
        selected: true,
      );
      _expectTextColorSwatchSelected(
        tester,
        '蓝色 #FF1976D2',
        selected: false,
      );
      expect(find.text('自定义颜色'), findsOneWidget);
      expect(find.byTooltip('自定义文字颜色'), findsOneWidget);
      await tester.tap(_menuItemButtonFinder('自定义颜色'));
      await tester.pumpAndSettle();
      expect(find.byType(WenzRichTextColorPickerDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'D32F2F',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('文字颜色 #FFD32F2F'), findsOneWidget);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFFD32F2F,
        ),
        isTrue,
      );

      await _openTextColorMenu(tester, '文字颜色 #FFD32F2F');
      await tester.tap(_menuItemButtonFinder('自定义颜色'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '#336699');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('文字颜色 #FF336699'), findsOneWidget);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFF336699,
        ),
        isTrue,
      );

      await _openTextColorMenu(tester, '文字颜色 #FF336699');
      expect(find.text('自定义颜色 #FF336699'), findsOneWidget);
      expect(find.byTooltip('自定义文字颜色 #FF336699'), findsOneWidget);
      _expectTextColorSwatchSelected(
        tester,
        '红色 #FFD32F2F',
        selected: false,
      );
      _expectTextColorSwatchSelected(
        tester,
        '蓝色 #FF1976D2',
        selected: false,
      );
      expect(
        _menuItemButton(tester, '清除文字颜色 #FF336699').onPressed,
        isNotNull,
      );
      await _tapTextColorMenuItem(tester, '清除文字颜色 #FF336699');
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFF336699,
        ),
        isFalse,
      );
      expect(find.byTooltip('文字颜色'), findsOneWidget);
      expect(find.byTooltip('无文字颜色'), findsNothing);

      await _openTextColorMenu(tester, '文字颜色');
      expect(find.text('无文字颜色'), findsOneWidget);
      _expectTextColorSwatchSelected(
        tester,
        '红色 #FFD32F2F',
        selected: false,
      );
      await tester.tap(find.byTooltip('文字颜色'));
      await _pumpTextColorMenuOpen(tester);

      final mixedHarness = await _pumpToolbar(
        tester,
        document: _mixedTextColorDocument(),
        selection: textSelection('p1', 0, 0, 10),
      );
      expect(find.byTooltip('文字颜色（混合）'), findsOneWidget);
      expect(find.byTooltip('清除混合文字颜色'), findsNothing);

      await _openTextColorMenu(tester, '文字颜色（混合）');
      expect(find.text('清除混合文字颜色'), findsOneWidget);
      expect(find.text('自定义颜色（混合）'), findsOneWidget);
      expect(find.byTooltip('自定义文字颜色（混合）'), findsOneWidget);
      _expectTextColorSwatchSelected(
        tester,
        '红色 #FFD32F2F',
        selected: false,
      );
      _expectTextColorSwatchSelected(
        tester,
        '墨绿 #FF0F766E',
        selected: false,
      );
      await _tapTextColorMenuItem(tester, '清除混合文字颜色');
      expect(
        _hasRun(
          mixedHarness.controller,
          (run) => run.attributes.color != null,
        ),
        isFalse,
      );

      await _pumpToolbar(
        tester,
        document: _mixedAlignmentDocument(),
        selection: _mixedAlignmentSelection(),
      );
      expect(find.byTooltip('对齐方式：混合对齐'), findsOneWidget);
      expect(_textButton(tester, '对齐方式：混合对齐').onPressed, isNotNull);
    });

    testWidgets('selects text color from popup while mouse hovers a swatch', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );
      await _scrollToolbarUntilVisible(tester, '文字颜色');
      final mouse = await _addMousePointer(tester, find.byTooltip('文字颜色'));
      addTearDown(() async {
        await mouse.removePointer();
      });

      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('文字颜色'), kind: PointerDeviceKind.mouse);
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('红色 #FFD32F2F'), findsOneWidget);

      await _moveMouseTo(tester, mouse, find.byTooltip('红色 #FFD32F2F'));
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byTooltip('红色 #FFD32F2F'),
        kind: PointerDeviceKind.mouse,
      );
      await _pumpTextColorMenuAction(tester);

      expect(find.byTooltip('文字颜色 #FFD32F2F'), findsOneWidget);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFFD32F2F,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reopens text color popup after toolbar close', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _openTextColorMenu(
        tester,
        '文字颜色',
        kind: PointerDeviceKind.mouse,
      );
      expect(find.byTooltip('蓝色 #FF1976D2'), findsOneWidget);

      await tester.tap(find.byTooltip('文字颜色'), kind: PointerDeviceKind.mouse);
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('蓝色 #FF1976D2'), findsNothing);
      expect(tester.takeException(), isNull);

      await _openTextColorMenu(
        tester,
        '文字颜色',
        kind: PointerDeviceKind.mouse,
      );
      await _tapTextColorSwatch(
        tester,
        '蓝色 #FF1976D2',
        kind: PointerDeviceKind.mouse,
      );

      expect(find.byTooltip('文字颜色 #FF1976D2'), findsOneWidget);
      expect(
        _hasRun(
          harness.controller,
          (run) => run.attributes.color == 0xFF1976D2,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('clears and applies custom text color after delayed close', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        document: _styledTextColorDocument(),
        selection: textSelection('p1', 0, 0, 5),
      );

      await _openTextColorMenu(
        tester,
        '文字颜色 #FFD32F2F',
        kind: PointerDeviceKind.mouse,
      );
      await _tapTextColorMenuItem(
        tester,
        '清除文字颜色 #FFD32F2F',
        kind: PointerDeviceKind.mouse,
      );

      _expectStyledTextColorRun(harness, null);
      expect(tester.takeException(), isNull);

      await _openTextColorMenu(
        tester,
        '文字颜色',
        kind: PointerDeviceKind.mouse,
      );
      expect(_menuItemButton(tester, '自定义颜色').onPressed, isNotNull);
      await tester.tap(
        _menuItemButtonFinder('自定义颜色'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), '#336699');
      await tester.tap(find.text('应用'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      _expectStyledTextColorRun(harness, 0xFF336699);
      expect(tester.takeException(), isNull);
    });

    testWidgets('completes text color mouse workflow without tracker errors', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        document: _styledTextColorDocument(),
        selection: textSelection('p1', 0, 0, 5),
      );
      await _scrollToolbarUntilVisible(tester, '文字颜色 #FFD32F2F');
      final mouse = await _addMousePointer(
        tester,
        find.byTooltip('文字颜色 #FFD32F2F'),
      );
      addTearDown(mouse.removePointer);

      await _clickMouseAt(
        tester,
        mouse,
        find.byTooltip('文字颜色 #FFD32F2F'),
      );
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('蓝色 #FF1976D2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _moveMouseTo(tester, mouse, find.byTooltip('蓝色 #FF1976D2'));
      await _clickMouseAt(
        tester,
        mouse,
        find.byTooltip('蓝色 #FF1976D2'),
      );
      await _pumpTextColorMenuAction(tester);
      _expectStyledTextColorRun(harness, 0xFF1976D2);
      expect(find.byTooltip('文字颜色 #FF1976D2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _clickMouseAt(
        tester,
        mouse,
        find.byTooltip('文字颜色 #FF1976D2'),
      );
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('蓝色 #FF1976D2'), findsOneWidget);
      await _clickMouseAt(
        tester,
        mouse,
        find.byTooltip('文字颜色 #FF1976D2'),
      );
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('蓝色 #FF1976D2'), findsNothing);
      expect(tester.takeException(), isNull);

      await _clickMouseAt(
        tester,
        mouse,
        find.byTooltip('文字颜色 #FF1976D2'),
      );
      await _pumpTextColorMenuOpen(tester);
      await _clickMouseAt(
        tester,
        mouse,
        _menuItemButtonFinder('清除文字颜色 #FF1976D2'),
      );
      await _pumpTextColorMenuAction(tester);
      _expectStyledTextColorRun(harness, null);
      expect(find.byTooltip('文字颜色'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _clickMouseAt(tester, mouse, find.byTooltip('文字颜色'));
      await _pumpTextColorMenuOpen(tester);
      await _clickMouseAt(
        tester,
        mouse,
        _menuItemButtonFinder('自定义颜色'),
      );
      await _pumpTextColorMenuAction(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WenzRichTextColorPickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), '#336699');
      await _clickMouseAt(tester, mouse, find.text('应用'));
      await tester.pumpAndSettle();
      _expectStyledTextColorRun(harness, 0xFF336699);
      expect(find.byTooltip('文字颜色 #FF336699'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps disabled text color popup items inert', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        permission: WenzEditorPermission.read,
        selection: textSelection('p1', 0, 0, 5),
      );
      await _scrollToolbarUntilVisible(tester, '文字颜色不可用');
      final mouse = await _addMousePointer(
        tester,
        find.byTooltip('文字颜色不可用'),
      );
      addTearDown(() async {
        await mouse.removePointer();
      });

      await _openTextColorMenu(
        tester,
        '文字颜色不可用',
        kind: PointerDeviceKind.mouse,
      );
      expect(
        _menuItemButtonByTooltip(tester, '红色 #FFD32F2F').onPressed,
        isNull,
      );
      expect(_menuItemButton(tester, '清除文字颜色不可用').onPressed, isNull);
      expect(_menuItemButton(tester, '自定义颜色').onPressed, isNull);
      expect(find.byTooltip('自定义文字颜色不可用'), findsOneWidget);

      await _moveMouseTo(tester, mouse, find.byTooltip('红色 #FFD32F2F'));
      await tester.tap(
        find.byTooltip('红色 #FFD32F2F'),
        kind: PointerDeviceKind.mouse,
        warnIfMissed: false,
      );
      await _pumpTextColorMenuAction(tester);
      await tester.tap(
        _menuItemButtonFinder('清除文字颜色不可用'),
        kind: PointerDeviceKind.mouse,
        warnIfMissed: false,
      );
      await _pumpTextColorMenuAction(tester);
      await tester.tap(
        _menuItemButtonFinder('自定义颜色'),
        kind: PointerDeviceKind.mouse,
        warnIfMissed: false,
      );
      await _pumpTextColorMenuAction(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        _hasRun(harness.controller, (run) => run.attributes.color != null),
        isFalse,
      );
      await tester.tap(
        find.byTooltip('文字颜色不可用'),
        kind: PointerDeviceKind.mouse,
      );
      await _pumpTextColorMenuOpen(tester);
      expect(find.byTooltip('红色 #FFD32F2F'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inserts default structure blocks from insert popup', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: collapsedTextSelection('p1', 0, 0),
      );

      await _tapInsertMenuItem(tester, '公式');
      final textBlock = _textBlock(harness.controller, 'p1');
      expect(
        textBlock.content
            .whereType<InlineEmbed>()
            .any((embed) => embed.embedType == 'formula'),
        isTrue,
      );

      await _tapInsertMenuItem(tester, '插入代码块');
      expect(harness.controller.document.blocks.first, isA<CodeBlockNode>());

      await _tapInsertMenuItem(tester, '插入标注');
      expect(
        harness.controller.document.blocks.whereType<CalloutBlockNode>(),
        isNotEmpty,
      );

      await _tapInsertMenuItem(tester, '插入表格');
      expect(
        harness.controller.document.blocks.whereType<TableBlockNode>(),
        isNotEmpty,
      );
    });

    testWidgets('media buttons do not affect core toolbar commands', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
        actions: WenzDefaultDesktopToolbarActions(
          onInsertImage: (_) {},
          onInsertVideo: (_) {},
        ),
      );

      await _tapToolbarButton(tester, '加粗');
      expect(_hasRun(harness.controller, (run) => run.attributes.bold == true),
          isTrue);

      await _tapInsertMenuItem(tester, '插入表格');
      expect(
        harness.controller.document.blocks.whereType<TableBlockNode>(),
        isNotEmpty,
      );
    });
  });

  group('WenzDefaultDesktopToolbar link dialog', () {
    testWidgets('applies a new link', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapInsertMenuItem(tester, '添加链接');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://wenz.dev');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(
          harness.controller,
          (run) =>
              run.text == 'Hello' && run.attributes.url == 'https://wenz.dev',
        ),
        isTrue,
      );
      await _openInsertMenu(tester);
      expect(find.text('编辑链接'), findsOneWidget);
    });

    testWidgets('cancel leaves the document unchanged', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapInsertMenuItem(tester, '添加链接');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://ignored.test');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      await _openInsertMenu(tester);
      expect(find.text('添加链接'), findsOneWidget);
    });

    testWidgets('removes an existing link', (tester) async {
      final harness = await _pumpToolbar(
        tester,
        document: _textDocument(link: 'https://wenz.dev'),
        selection: textSelection('p1', 0, 0, 5),
      );

      await _tapInsertMenuItem(tester, '编辑链接');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(
        _hasRun(harness.controller, (run) => run.attributes.url != null),
        isFalse,
      );
      await _openInsertMenu(tester);
      expect(find.text('添加链接'), findsOneWidget);
    });
  });

  group('WenzDefaultDesktopToolbar table context', () {
    testWidgets('shows table buttons only for table cell selections', (
      tester,
    ) async {
      await _pumpToolbar(tester);
      _expectDefaultToolbarSequence(tester);
      expect(find.byTooltip('下方插入行'), findsNothing);

      final harness = await _pumpToolbar(
        tester,
        document: _tableDocument(),
        selection: _tableSelection(0, 0, 0, 0),
      );
      _expectToolbarSequence(tester, const <String>[
        '有序列表',
        '下方插入行',
        '右侧插入列',
        '删除行',
        '删除列',
        '合并单元格',
        '拆分单元格',
        '无序列表',
        '对齐方式：无对齐',
        '插入元素',
      ]);

      for (final tooltip in const <String>[
        '下方插入行',
        '右侧插入列',
        '删除行',
        '删除列',
        '合并单元格',
        '拆分单元格',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget);
        expect(_iconButton(tester, tooltip).onPressed, isNotNull);
      }

      await _tapToolbarButton(tester, '下方插入行');
      expect(_table(harness.controller).table.rowCount, 3);

      await _tapToolbarButton(tester, '右侧插入列');
      expect(_table(harness.controller).table.columnCount, 3);
    });

    testWidgets('merge and split table cells through toolbar buttons', (
      tester,
    ) async {
      final harness = await _pumpToolbar(
        tester,
        document: _tableDocument(),
        selection: _tableSelection(0, 0, 0, 1),
      );

      await _tapToolbarButton(tester, '合并单元格');
      var table = _table(harness.controller).table;
      expect(table.cellAt(0, 0)?.columnSpan, 2);
      expect(table.cellAt(0, 1)?.covered, isTrue);

      await _tapToolbarButton(tester, '拆分单元格');
      table = _table(harness.controller).table;
      expect(table.cellAt(0, 0)?.columnSpan, 1);
      expect(table.cellAt(0, 1)?.covered, isFalse);
    });
  });

  group('WenzDefaultDesktopToolbar registry items', () {
    testWidgets('sorts, renders, overrides, activates, disables, and acts', (
      tester,
    ) async {
      final calls = <String>[];
      final registry = WenzToolbarItemRegistry(<WenzToolbarItem>[
        WenzToolbarItem(
          id: 'later',
          title: 'Later item',
          tooltip: 'Later item',
          priority: 20,
          icon: 'extension',
          action: (_, __) => calls.add('later'),
        ),
        WenzToolbarItem(
          id: 'active',
          title: 'Active item',
          tooltip: 'Active item',
          priority: 5,
          icon: 'account_tree',
          isActive: (_) => true,
          action: (_, __) => calls.add('active'),
        ),
        WenzToolbarItem(
          id: 'disabled',
          title: 'Disabled item',
          tooltip: 'Disabled item',
          priority: 6,
          icon: 'table_chart',
          isEnabled: (_) => false,
          action: (_, __) => calls.add('disabled'),
        ),
        WenzToolbarItem(
          id: 'select-row',
          title: 'Select row alias',
          tooltip: 'Select row alias',
          priority: 7,
          icon: 'select-row',
          isActive: (_) => true,
          action: (_, __) => calls.add('select-row'),
        ),
        WenzToolbarItem(
          id: 'delete-table',
          title: 'Delete table alias',
          tooltip: 'Delete table alias',
          priority: 8,
          icon: 'delete-table',
          isEnabled: (_) => false,
          action: (_, __) => calls.add('delete-table'),
        ),
        WenzToolbarItem(
          id: 'override',
          title: 'Registry override',
          tooltip: 'Registry override',
          priority: 1,
          action: (_, __) => calls.add('registry'),
        ),
      ]);
      final explicit = <WenzToolbarItem>[
        WenzToolbarItem(
          id: 'first',
          title: 'First item',
          tooltip: 'First item',
          priority: -1,
          icon: 'callout',
          action: (_, __) => calls.add('first'),
        ),
        WenzToolbarItem(
          id: 'override',
          title: 'Host override',
          tooltip: 'Host override',
          priority: 0,
          icon: 'unknown-token',
          action: (_, __) => calls.add('host'),
        ),
      ];

      final harness = await _pumpToolbar(
        tester,
        toolbarItemRegistry: registry,
        toolbarItems: explicit,
        width: 520,
      );
      final toolbarWidget = tester.widget<WenzDefaultDesktopToolbar>(
        find.byType(WenzDefaultDesktopToolbar),
      );

      expect(
        toolbarWidget.effectiveToolbarItems.map((item) => item.id),
        <String>[
          'first',
          'override',
          'active',
          'disabled',
          'select-row',
          'delete-table',
          'later',
        ],
      );
      expect(find.byTooltip('Registry override'), findsNothing);
      expect(find.byTooltip('Host override'), findsOneWidget);
      expect(find.byTooltip('Active item'), findsOneWidget);
      expect(find.byTooltip('Disabled item'), findsOneWidget);
      _expectLucideIcon(
        tester,
        'Active item',
        WenzLucideToolbarIcons.workflow,
      );
      _expectLucideIcon(
        tester,
        'Host override',
        WenzLucideToolbarIcons.fallback,
      );
      _expectLucideIcon(
        tester,
        'First item',
        WenzLucideToolbarIcons.callout,
      );
      _expectLucideIcon(
        tester,
        'Disabled item',
        WenzLucideToolbarIcons.table,
      );
      _expectLucideIcon(
        tester,
        'Select row alias',
        WenzLucideToolbarIcons.tableSelectRow,
      );
      _expectLucideIcon(
        tester,
        'Delete table alias',
        WenzLucideToolbarIcons.tableDelete,
      );
      _expectLucideIcon(
        tester,
        'Later item',
        WenzLucideToolbarIcons.extension,
      );
      expect(find.byTooltip('First item'), findsOneWidget);
      expect(find.byTooltip('Later item'), findsOneWidget);
      _expectToolbarSequence(tester, const <String>[
        '有序列表',
        'First item',
        'Host override',
        'Active item',
        'Disabled item',
        'Select row alias',
        'Delete table alias',
        'Later item',
        '无序列表',
        '对齐方式：无对齐',
        '插入元素',
      ]);
      expect(_iconButton(tester, 'Active item').isSelected, isTrue);
      expect(_iconButton(tester, 'Select row alias').isSelected, isTrue);
      expect(_iconButton(tester, 'Disabled item').onPressed, isNull);
      expect(_iconButton(tester, 'Delete table alias').onPressed, isNull);

      for (var index = 0; index < 8; index++) {
        registry.register(
          WenzToolbarItem(
            id: 'dynamic-$index',
            title: 'Dynamic item $index',
            tooltip: 'Dynamic item $index',
            priority: 30 + index,
            action: (_, __) => calls.add('dynamic-$index'),
          ),
        );
      }
      await tester.pump();
      expect(find.byTooltip('Dynamic item 7'), findsOneWidget);
      _expectToolbarSequence(tester, const <String>[
        'Later item',
        'Dynamic item 0',
        'Dynamic item 7',
        '无序列表',
        '对齐方式：无对齐',
        '插入元素',
      ]);
      expect(tester.takeException(), isNull);

      registry.unregister('dynamic-7');
      await tester.pump();
      expect(find.byTooltip('Dynamic item 7'), findsNothing);
      _expectToolbarSequence(tester, const <String>[
        'Later item',
        '无序列表',
        '对齐方式：无对齐',
        '插入元素',
      ]);

      await _tapToolbarButton(tester, 'Host override');
      await _tapToolbarButton(tester, 'Active item');
      expect(calls, <String>['host', 'active']);
      expect(harness.toolbar.state.hasSelection, isTrue);
    });
  });
}

Future<_ToolbarHarness> _pumpToolbar(
  WidgetTester tester, {
  WenzRichTextController? controller,
  ToolbarController? toolbar,
  RichTextDocument? document,
  DocumentSelection? selection,
  WenzEditorPermission permission = WenzEditorPermission.edit,
  WenzToolbarItemRegistry? toolbarItemRegistry,
  Iterable<WenzToolbarItem> toolbarItems = const <WenzToolbarItem>[],
  WenzDefaultDesktopToolbarActions actions =
      const WenzDefaultDesktopToolbarActions(),
  double width = 760,
}) async {
  final host = controller ??
      WenzRichTextController(
        document: document ?? _textDocument(),
        selection: selection ?? textSelection('p1', 0, 0, 5),
        permission: permission,
      );
  final toolbarController = toolbar ?? ToolbarController(host);
  if (toolbar == null) {
    addTearDown(toolbarController.dispose);
  }
  if (controller == null) {
    addTearDown(host.dispose);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: WenzDefaultDesktopToolbar(
              controller: host,
              toolbar: toolbarController,
              toolbarItemRegistry: toolbarItemRegistry,
              toolbarItems: toolbarItems,
              actions: actions,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return _ToolbarHarness(host, toolbarController);
}

Future<void> _tapToolbarButton(WidgetTester tester, String tooltip) async {
  await _scrollToolbarUntilVisible(tester, tooltip);
  expect(_iconButton(tester, tooltip).onPressed, isNotNull);
  await tester.tap(find.byTooltip(tooltip));
  await tester.pump();
}

Future<void> _openTextColorMenu(
  WidgetTester tester,
  String tooltip, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  await _scrollToolbarUntilVisible(tester, tooltip);
  expect(_iconButton(tester, tooltip).onPressed, isNotNull);
  await tester.tap(find.byTooltip(tooltip), kind: kind);
  await _pumpTextColorMenuOpen(tester);
}

Future<void> _tapTextColorSwatch(
  WidgetTester tester,
  String tooltip, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  expect(_menuItemButtonByTooltip(tester, tooltip).onPressed, isNotNull);
  await tester.tap(find.byTooltip(tooltip), kind: kind);
  await _pumpTextColorMenuAction(tester);
}

Future<void> _tapTextColorMenuItem(
  WidgetTester tester,
  String label, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  expect(_menuItemButton(tester, label).onPressed, isNotNull);
  await tester.tap(_menuItemButtonFinder(label), kind: kind);
  await _pumpTextColorMenuAction(tester);
}

Future<void> _pumpTextColorMenuOpen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpTextColorMenuAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<TestGesture> _addMousePointer(
  WidgetTester tester,
  Finder finder,
) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(finder));
  await tester.pump();
  return mouse;
}

Future<void> _moveMouseTo(
  WidgetTester tester,
  TestGesture mouse,
  Finder finder,
) async {
  await mouse.moveTo(tester.getCenter(finder));
  await tester.pump();
}

Future<void> _clickMouseAt(
  WidgetTester tester,
  TestGesture mouse,
  Finder finder,
) async {
  final location = tester.getCenter(finder);
  await mouse.moveTo(location);
  await tester.pump();
  await mouse.down(location);
  await tester.pump();
  await mouse.up();
}

Future<void> _openInsertMenu(WidgetTester tester) async {
  await _scrollToolbarUntilVisible(tester, '插入元素');
  expect(_iconButton(tester, '插入元素').onPressed, isNotNull);
  await tester.tap(find.byTooltip('插入元素'));
  await tester.pump();
}

void _expectDefaultToolbarSequence(WidgetTester tester) {
  _expectToolbarSequence(tester, const <String>[
    '加粗',
    '斜体',
    '下划线',
    '删除线',
    '文字颜色',
    '清除样式',
    '正文',
    '引用',
    '任务列表',
    '有序列表',
    '无序列表',
    '行内代码',
    '对齐方式：无对齐',
    '插入元素',
  ]);
}

void _expectToolbarSequence(WidgetTester tester, List<String> tooltips) {
  Rect? previousRect;
  Rect? firstRect;
  for (final tooltip in tooltips) {
    final rect = _tooltipRect(tester, tooltip);
    final first = firstRect;
    if (first == null) {
      firstRect = rect;
    } else {
      expect(rect.left, greaterThan(previousRect!.right));
      expect(rect.center.dy, closeTo(first.center.dy, _kGeometryTolerance));
    }
    previousRect = rect;
  }
}

void _expectToolbarStartsAtPadding(WidgetTester tester) {
  final toolbarRect = tester.getRect(find.byType(WenzDefaultDesktopToolbar));
  final firstRect = _tooltipRect(tester, '加粗');
  expect(
    firstRect.left - toolbarRect.left,
    closeTo(_kDefaultToolbarHorizontalPadding, _kGeometryTolerance),
  );
}

Rect _tooltipRect(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  return tester.getRect(tooltipFinder);
}

Future<void> _scrollToolbarUntilVisible(
  WidgetTester tester,
  String tooltip,
) async {
  expect(find.byType(SingleChildScrollView), findsOneWidget);
  expect(find.byTooltip(tooltip), findsOneWidget);
  await tester.ensureVisible(find.byTooltip(tooltip));
  await tester.pump();
}

Future<void> _tapInsertMenuItem(WidgetTester tester, String label) async {
  await _openInsertMenu(tester);
  expect(_menuItemButton(tester, label).onPressed, isNotNull);
  await tester.tap(_menuItemButtonFinder(label));
  await tester.pump();
}

Future<void> _openBlockStyleMenu(
  WidgetTester tester,
  String tooltip,
) async {
  await _scrollToolbarUntilVisible(tester, tooltip);
  expect(_textButton(tester, tooltip).onPressed, isNotNull);
  await tester.tap(_textButtonFinder(tooltip));
  await tester.pump();
}

Future<void> _tapBlockStyleMenuItem(
  WidgetTester tester,
  String label,
  String currentTooltip,
) async {
  await _openBlockStyleMenu(tester, currentTooltip);
  expect(_menuItemButton(tester, label).onPressed, isNotNull);
  await tester.tap(_menuItemButtonFinder(label));
  await tester.pump();
}

Future<void> _openAlignmentMenu(
  WidgetTester tester,
  String tooltip,
) async {
  await _scrollToolbarUntilVisible(tester, tooltip);
  expect(_textButton(tester, tooltip).onPressed, isNotNull);
  await tester.tap(_textButtonFinder(tooltip));
  await tester.pump();
}

Future<void> _tapAlignmentMenuItem(
  WidgetTester tester,
  String label,
  String currentTooltip,
) async {
  await _openAlignmentMenu(tester, currentTooltip);
  expect(_menuItemButton(tester, label).onPressed, isNotNull);
  await tester.tap(_menuItemButtonFinder(label));
  await tester.pump();
}

IconButton _iconButton(WidgetTester tester, String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  expect(tooltipFinder, findsOneWidget);
  final matchedWidget = tooltipFinder.evaluate().single.widget;
  if (matchedWidget is IconButton) {
    return matchedWidget;
  }
  final iconButtonFinder = find.ancestor(
    of: tooltipFinder,
    matching: find.byType(IconButton),
  );
  expect(iconButtonFinder, findsOneWidget);
  return tester.widget<IconButton>(iconButtonFinder);
}

Finder _textButtonFinder(String tooltip) {
  final tooltipFinder = find.byTooltip(tooltip);
  return find.descendant(
    of: tooltipFinder,
    matching: find.byType(TextButton),
  );
}

TextButton _textButton(WidgetTester tester, String tooltip) {
  final textButtonFinder = _textButtonFinder(tooltip);
  expect(textButtonFinder, findsOneWidget);
  return tester.widget<TextButton>(textButtonFinder);
}

void _expectMutedTextButton(WidgetTester tester, String tooltip) {
  final textButtonFinder = _textButtonFinder(tooltip);
  final context = tester.element(textButtonFinder);
  final expectedColor = Theme.of(context).colorScheme.onSurface.withAlpha(96);
  final foregroundColor =
      tester.widget<TextButton>(textButtonFinder).style?.foregroundColor;

  expect(foregroundColor?.resolve(<WidgetState>{}), expectedColor);
  expect(
    foregroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
    expectedColor,
  );
}

Finder _menuItemButtonFinder(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(MenuItemButton),
  );
}

MenuItemButton _menuItemButton(WidgetTester tester, String label) {
  final menuItemFinder = _menuItemButtonFinder(label);
  expect(menuItemFinder, findsOneWidget);
  return tester.widget<MenuItemButton>(menuItemFinder);
}

Finder _menuItemButtonByTooltipFinder(String tooltip) {
  return find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(MenuItemButton),
  );
}

MenuItemButton _menuItemButtonByTooltip(
  WidgetTester tester,
  String tooltip,
) {
  final menuItemFinder = _menuItemButtonByTooltipFinder(tooltip);
  expect(menuItemFinder, findsOneWidget);
  return tester.widget<MenuItemButton>(menuItemFinder);
}

void _expectTextColorSwatchSelected(
  WidgetTester tester,
  String tooltip, {
  required bool selected,
}) {
  final menuItemFinder = _menuItemButtonByTooltipFinder(tooltip);
  expect(menuItemFinder, findsOneWidget);
  final context = tester.element(menuItemFinder);
  final expectedColor = selected
      ? Theme.of(context).colorScheme.primaryContainer
      : Colors.transparent;
  final backgroundColor = tester
      .widget<MenuItemButton>(menuItemFinder)
      .style
      ?.backgroundColor
      ?.resolve(<WidgetState>{});

  expect(backgroundColor, expectedColor);
}

void _expectLucideIcon(
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

RichTextDocument _textDocument({String? link}) {
  return RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello world',
            attributes: TextAttributes(url: link),
          ),
        ],
      ),
    ],
  );
}

RichTextDocument _styledTextColorDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello world',
            attributes: TextAttributes(
              bold: true,
              color: 0xFFD32F2F,
              background: 0xFFFFF59D,
              url: 'https://example.test',
            ),
          ),
        ],
      ),
    ],
  );
}

void _expectStyledTextColorRun(_ToolbarHarness harness, int? color) {
  final runs = _textBlock(harness.controller, 'p1')
      .content
      .whereType<TextRun>()
      .toList();
  expect(
    runs,
    contains(
      isA<TextRun>()
          .having((run) => run.text, 'text', 'Hello')
          .having((run) => run.attributes.color, 'color', color),
    ),
  );
  for (final run in runs) {
    expect(run.attributes.background, 0xFFFFF59D);
    expect(run.attributes.bold, isTrue);
    expect(run.attributes.url, 'https://example.test');
  }
}

RichTextDocument _mixedTextColorDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[
          TextRun(
            text: 'Hello',
            attributes: TextAttributes(color: 0xFFFF0000),
          ),
          TextRun(
            text: 'World',
            attributes: TextAttributes(color: 0xFF00FF00),
          ),
        ],
      ),
    ],
  );
}

RichTextDocument _mixedAlignmentDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        attributes: BlockAttributes(alignment: 'left'),
        content: <InlineNode>[TextRun(text: 'One')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.paragraph,
        attributes: BlockAttributes(alignment: 'center'),
        content: <InlineNode>[TextRun(text: 'Two')],
      ),
    ],
  );
}

RichTextDocument _mixedBlockStyleDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.paragraph,
        content: <InlineNode>[TextRun(text: 'Body')],
      ),
      TextBlockNode(
        id: 'p2',
        type: BlockType.heading,
        attributes: BlockAttributes(level: 2),
        content: <InlineNode>[TextRun(text: 'Heading')],
      ),
    ],
  );
}

RichTextDocument _unsupportedBlockStyleDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TextBlockNode(
        id: 'p1',
        type: BlockType.listItem,
        attributes: BlockAttributes(listType: 'ordered'),
        content: <InlineNode>[TextRun(text: 'List item')],
      ),
    ],
  );
}

DocumentSelection _mixedBlockStyleSelection() {
  return DocumentSelection(
    base: DocumentPosition(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      offset: 0,
    ),
    extent: DocumentPosition(
      blockId: 'p2',
      blockIndex: 1,
      path: PositionPath.blockText('p2'),
      offset: 7,
    ),
  );
}

DocumentSelection _mixedAlignmentSelection() {
  return DocumentSelection(
    base: DocumentPosition(
      blockId: 'p1',
      blockIndex: 0,
      path: PositionPath.blockText('p1'),
      offset: 0,
    ),
    extent: DocumentPosition(
      blockId: 'p2',
      blockIndex: 1,
      path: PositionPath.blockText('p2'),
      offset: 3,
    ),
  );
}

RichTextDocument _tableDocument() {
  return const RichTextDocument(
    blocks: <BlockNode>[
      TableBlockNode(
        id: 'table',
        table: TableModel(
          rows: <List<TableCellNode>>[
            <TableCellNode>[
              TableCellNode(
                id: 'c00',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c00p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'A')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c01',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c01p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'B')],
                  ),
                ],
              ),
            ],
            <TableCellNode>[
              TableCellNode(
                id: 'c10',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c10p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'C')],
                  ),
                ],
              ),
              TableCellNode(
                id: 'c11',
                blocks: <BlockNode>[
                  TextBlockNode(
                    id: 'c11p',
                    type: BlockType.paragraph,
                    content: <InlineNode>[TextRun(text: 'D')],
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

DocumentSelection _tableSelection(
  int startRow,
  int startColumn,
  int endRow,
  int endColumn,
) {
  return DocumentSelection(
    base: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: startRow,
      tableColumnIndex: startColumn,
      offset: 0,
    ),
    extent: DocumentPosition.tableCell(
      tableBlockId: 'table',
      blockIndex: 0,
      tableRowIndex: endRow,
      tableColumnIndex: endColumn,
      offset: 0,
    ),
  );
}

TextBlockNode _textBlock(WenzRichTextController controller, String blockId) {
  return controller.document.blocks
      .whereType<TextBlockNode>()
      .singleWhere((block) => block.id == blockId);
}

TableBlockNode _table(WenzRichTextController controller) {
  return controller.document.blocks.whereType<TableBlockNode>().single;
}

bool _hasRun(
  WenzRichTextController controller,
  bool Function(TextRun run) test,
) {
  return _textBlock(controller, 'p1').content.whereType<TextRun>().any(test);
}

class _ToolbarHarness {
  const _ToolbarHarness(this.controller, this.toolbar);

  final WenzRichTextController controller;
  final ToolbarController toolbar;
}
