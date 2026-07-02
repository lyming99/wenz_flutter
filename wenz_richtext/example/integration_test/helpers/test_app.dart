import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

const testThemeToggleKey = ValueKey<String>('wenz-example-theme-toggle');
const testEditorSurfaceKey = ValueKey<String>('wenz-example-editor-surface');
const _testSeedColor = Color(0xFF0F766E);
const _testWorkbenchFontFamily = '微软雅黑';

ThemeData _testWorkbenchTheme(Brightness brightness) {
  final background =
      brightness == Brightness.dark ? Colors.black : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: _testSeedColor,
    brightness: brightness,
  ).copyWith(surface: background);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: _testWorkbenchFontFamily,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
  );
}

Color _testEditorBackground(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.black
      : Colors.white;
}

/// The in-memory clipboard buffer shared between copy and paste within a test.
///
/// `flutter test`'s integration binding does not wire a real `Clipboard`
/// platform channel by default, so `Clipboard.setData` / `Clipboard.getData`
/// round-trip through this buffer. Install it once via [installTestClipboard].
String? _testClipboardBuffer;

void installTestClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    if (call.method == 'Clipboard.setData') {
      final args = Map<String, Object?>.from(call.arguments as Map);
      _testClipboardBuffer = args['text'] as String?;
      return null;
    }
    if (call.method == 'Clipboard.getData') {
      return <String, Object?>{'text': _testClipboardBuffer};
    }
    return null;
  });
}

/// Builds a realistic desktop workbench for integration tests.
///
/// Mirrors `lib/main.dart`'s `EditorWorkbench` (MaterialApp + Scaffold +
/// toolbar + scrollable editor) but lets each test supply its own initial
/// [document] and [selection] so assertions start from a known state. The
/// controller is held by the returned [TestWorkbench] so tests can read
/// `document` / `selection` / `canUndo` directly.
///
/// The editor is created with [enableIme] defaulting to `true` (the production
/// desktop path). Character entry in tests therefore goes through
/// [typeText] (which mirrors what the IME would commit via
/// [WenzRichTextController.insertText]); structural keys (Backspace, arrows,
/// Enter, Home/End, Ctrl+ shortcuts) use real key events.
class TestWorkbench {
  TestWorkbench({
    RichTextDocument? document,
    DocumentSelection? selection,
    bool enableIme = true,
  }) : controller = WenzRichTextController(
          document: document ?? _emptyDocument(),
          selection: selection,
        );

  static RichTextDocument _emptyDocument() {
    return const RichTextDocument(
      blocks: <BlockNode>[
        TextBlockNode(
          id: 'p1',
          type: BlockType.paragraph,
          content: <InlineNode>[],
        ),
      ],
    );
  }

  /// Ensures the controller has a collapsed caret at the given offset within
  /// the block identified by [blockId]. Call after pump when the test needs a
  /// known caret position (the editor does not auto-place one on an empty
  /// document in the headless test binding).
  void placeCaretAt(String blockId, int blockIndex, int offset) {
    controller.setSelection(
      DocumentSelection(
        base: DocumentPosition.text(
          blockId: blockId,
          blockIndex: blockIndex,
          offset: offset,
        ),
        extent: DocumentPosition.text(
          blockId: blockId,
          blockIndex: blockIndex,
          offset: offset,
        ),
      ),
    );
  }

  final WenzRichTextController controller;
  final bool enableIme = true;

  Widget build() => _WorkbenchApp(this);
}

class _WorkbenchApp extends StatefulWidget {
  const _WorkbenchApp(this.workbench);

  final TestWorkbench workbench;

  @override
  State<_WorkbenchApp> createState() => _WorkbenchAppState();
}

class _WorkbenchAppState extends State<_WorkbenchApp> {
  var _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _testWorkbenchTheme(Brightness.light),
      darkTheme: _testWorkbenchTheme(Brightness.dark),
      themeMode: _themeMode,
      home: _WorkbenchScaffold(
        workbench: widget.workbench,
        themeMode: _themeMode,
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}

class _WorkbenchScaffold extends StatefulWidget {
  const _WorkbenchScaffold({
    required this.workbench,
    required this.themeMode,
    required this.onToggleThemeMode,
  });

  final TestWorkbench workbench;
  final ThemeMode themeMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<_WorkbenchScaffold> createState() => _WorkbenchScaffoldState();
}

class _WorkbenchScaffoldState extends State<_WorkbenchScaffold> {
  @override
  void initState() {
    super.initState();
    widget.workbench.controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.workbench.controller.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wenz RichText'),
        actions: <Widget>[
          IconButton(
            key: testThemeToggleKey,
            tooltip: widget.themeMode == ThemeMode.dark
                ? '切换浅色主题'
                : '切换深色主题',
            onPressed: widget.onToggleThemeMode,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _TestToolbar(controller: widget.workbench.controller),
          Expanded(
            child: ColoredBox(
              key: testEditorSurfaceKey,
              color: _testEditorBackground(context),
              child: WenzRichTextEditor(
                controller: widget.workbench.controller,
                autofocus: true,
                enableIme: widget.workbench.enableIme,
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
                blockSpacing: 14,
                textStyle: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact toolbar mirroring the example's, keyed by `tooltip` so tests can
/// tap format buttons via `find.byTooltip`.
class _TestToolbar extends StatelessWidget {
  const _TestToolbar({required this.controller});

  final WenzRichTextController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 6,
          children: <Widget>[
            IconButton.filledTonal(
              tooltip: '加粗',
              onPressed: () =>
                  controller.formatText(const TextAttributes(bold: true)),
              icon: const Icon(Icons.format_bold),
            ),
            IconButton.filledTonal(
              tooltip: '斜体',
              onPressed: () =>
                  controller.formatText(const TextAttributes(italic: true)),
              icon: const Icon(Icons.format_italic),
            ),
            IconButton(
              tooltip: '标题',
              onPressed: () => controller.setBlockType(
                type: BlockType.heading,
                level: 1,
              ),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: '段落',
              onPressed: () =>
                  controller.setBlockType(type: BlockType.paragraph),
              icon: const Icon(Icons.notes),
            ),
            IconButton(
              tooltip: '插入表格',
              onPressed: () => controller.insertTable(
                index: controller.document.blocks.length,
                tableId: 'table-1',
                rowCount: 2,
                columnCount: 2,
              ),
              icon: const Icon(Icons.table_chart),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pumps a [TestWorkbench] into the harness and returns it so the test can
/// drive the controller directly. Sets a desktop-flavoured 1280x800 viewport.
///
/// When [selection] is omitted, a collapsed caret is placed at the end of the
/// first text/code block so keyboard/IME entry has somewhere to land. (The
/// editor does not auto-place a selection in the headless binding; tests that
/// need a different caret position override it after pump.)
Future<TestWorkbench> pumpWorkbench(
  WidgetTester tester, {
  RichTextDocument? document,
  DocumentSelection? selection,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Wire an in-memory Clipboard so copy/cut/paste round-trip in the headless
  // binding. Reset per test so payloads don't leak across cases.
  installTestClipboard();
  _testClipboardBuffer = null;

  final workbench = TestWorkbench(
    document: document,
    selection: selection,
  );
  await tester.pumpWidget(workbench.build());
  await tester.pumpAndSettle();

  if (selection == null) {
    _placeDefaultCaret(workbench.controller);
  }
  return workbench;
}

void _placeDefaultCaret(WenzRichTextController controller) {
  final blocks = controller.document.blocks;
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (block is TextBlockNode) {
      controller.setSelection(
        DocumentSelection(
          base: DocumentPosition.text(
            blockId: block.id,
            blockIndex: i,
            offset: block.plainText.length,
          ),
          extent: DocumentPosition.text(
            blockId: block.id,
            blockIndex: i,
            offset: block.plainText.length,
          ),
        ),
      );
      return;
    }
  }
}
