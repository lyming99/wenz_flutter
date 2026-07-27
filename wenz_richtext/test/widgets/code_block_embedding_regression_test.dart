import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

void main() {
  testWidgets('embedded editor can use a transparent root background', (
    tester,
  ) async {
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          TextBlockNode(
            id: 'paragraph',
            type: BlockType.paragraph,
            content: <InlineNode>[TextRun(text: 'chat message')],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WenzRichTextEditor(
            controller: controller,
            readOnly: true,
            enableIme: false,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
    await tester.pump();

    final background = tester.widget<ColoredBox>(
      find.byKey(
        const ValueKey<String>('wenz-richtext-editor-background'),
      ),
    );
    expect(background.color, Colors.transparent);
  });

  testWidgets('compact code line numbers stay aligned with long Unicode code', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const code = '''
lib/
├── main.dart                          # 应用入口，窗口初始化
├── src/
│   ├── app.dart                       # MaterialApp 根组件，生命周期管理
│   ├── controller/
│   │   └── editor_controller.dart     # 核心编辑器控制器（~1830行）
│   ├── model/                         # 数据模型
│   │   ├── editor_document.dart       # 文档模型
│   │   ├── editor_section_anchor.dart # 节锚点
│   │   └── workspace_node.dart        # 工作区节点
│   ├── ai/                            # AI 对话子系统
│   │   ├── ai_chat_controller.dart    # 对话控制器
│   │   ├── ai_chat_gateway.dart       # 网关抽象
│   │   ├── ai_chat_http_gateway.dart  # HTTP 网关实现
│   │   ├── ai_chat_store.dart         # 会话持久化
│   │   ├── ai_workspace_tools.dart    # 工作区工具（只读+编辑模式）
│   │   └── widgets/                   # AI UI 组件
│   ├── tasks/                         # 后台任务中心子系统
│   │   ├── task_controller.dart       # 任务总控
│   │   ├── task_runner.dart           # 运行器抽象
│   │   ├── codex_runner.dart          # Codex CLI 运行器
│   │   ├── claude_runner.dart         # Claude CLI 运行器
│   │   ├── kimi_runner.dart           # Kimi CLI 运行器
│   │   ├── script_runner.dart         # 脚本运行器
│   │   ├── task_db.dart               # Drift 数据库定义
│   │   └── widgets/                   # 任务 UI 组件
│   ├── widgets/                       # 编辑器 UI 组件
│   │   ├── editor_shell.dart          # 主布局外壳（SplitLayout）
│   │   ├── editor_workspace.dart      # 工作区视图
│   │   ├── workspace_sidebar.dart     # 侧栏（目录树）
│   │   ├── rich_text_editor_pane.dart # 富文本编辑面板
│   │   ├── title_bar.dart             # 自定义标题栏
│   │   └── document_tabs.dart         # 多标签管理
│   ├── auth/                          # 用户认证（Pro 会员）
│   ├── settings/                      # 偏好设置
│   ├── window/                        # 窗口状态管理
│   ├── theme/                         # 浅色/深色主题
│   ├── update/                        # 应用更新检查
│   └── services/                      # 基础服务层''';
    final controller = WenzRichTextController(
      document: const RichTextDocument(
        blocks: <BlockNode>[
          CodeBlockNode(id: 'unicode-tree', code: code),
        ],
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(420, 560)),
            child: WenzRichTextEditor(
              controller: controller,
              readOnly: true,
              enableIme: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const gutterKey = ValueKey<String>(
      'wenz-richtext-code-line-numbers-unicode-tree',
    );
    final gutterTextFinder = find.byKey(gutterKey);
    final gutterFinder = find.descendant(
      of: gutterTextFinder,
      matching: find.byType(RichText),
    );
    final codeFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == code,
    );
    expect(gutterFinder, findsOneWidget);
    expect(codeFinder, findsOneWidget);
    final gutterText = tester.widget<Text>(gutterTextFinder);
    final codeText = tester.widget<RichText>(codeFinder);
    expect(codeText.text.style?.fontSize, 12.5);
    expect(
      gutterText.style?.fontSize,
      codeText.text.style?.fontSize,
      reason: 'responsive code and gutter typography must use one font size',
    );

    final gutter = tester.renderObject<RenderParagraph>(gutterFinder);
    final renderedCode = tester.renderObject<RenderParagraph>(codeFinder);
    final labels = List<String>.generate(
      code.split('\n').length,
      (index) => '${index + 1}',
    ).join('\n');
    final gutterStarts = _lineStarts(labels);
    final codeStarts = _lineStarts(code);
    final gutterOrigin = gutter.localToGlobal(Offset.zero);
    final codeOrigin = renderedCode.localToGlobal(Offset.zero);

    for (var index = 0; index < codeStarts.length; index++) {
      final gutterY = gutterOrigin.dy +
          gutter
              .getOffsetForCaret(
                TextPosition(offset: gutterStarts[index]),
                Rect.zero,
              )
              .dy;
      final codeY = codeOrigin.dy +
          renderedCode
              .getOffsetForCaret(
                TextPosition(offset: codeStarts[index]),
                Rect.zero,
              )
              .dy;
      expect(
        gutterY,
        moreOrLessEquals(codeY, epsilon: 0.5),
        reason: 'logical code line ${index + 1} must align with its gutter',
      );
    }
  });
}

List<int> _lineStarts(String text) {
  final starts = <int>[0];
  for (var index = 0; index < text.length; index++) {
    if (text.codeUnitAt(index) == 0x0A) {
      starts.add(index + 1);
    }
  }
  return starts;
}
