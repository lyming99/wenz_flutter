import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

class _RecordingMermaidRenderer implements MermaidRenderer {
  int renderCount = 0;

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    renderCount++;
    return '<svg></svg>';
  }
}

class _DelayedRenderService implements NativeMermaidRenderService {
  _DelayedRenderService(this.delegate, this.delayFor);

  final DefaultNativeMermaidRenderService delegate;
  final Duration Function(String source) delayFor;
  final List<MermaidRenderRequest> requests = <MermaidRenderRequest>[];

  @override
  Future<MermaidRenderOutcome> render(MermaidRenderRequest request) async {
    requests.add(request);
    await Future<void>.delayed(delayFor(request.source));
    return delegate.render(request);
  }

  @override
  void cancel(String requestId) {
    // Deliberately ignore cancellation to prove requestId + digest stale guards.
  }

  @override
  void invalidateTheme(String themeKey) => delegate.invalidateTheme(themeKey);

  @override
  NativeMermaidRenderServiceStats get stats => delegate.stats;

  @override
  Future<void> dispose() => delegate.dispose();
}

const _toggleKey = ValueKey<String>('wenz-richtext-mermaid-toggle');

Widget _wrapMermaidBlock({
  required CodeBlockNode block,
  required MermaidDiagramConfig config,
  required MermaidRenderer renderer,
  required NativeMermaidRenderService service,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool highContrast = false,
  bool includeEditorFocus = false,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(900, 700),
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              if (includeEditorFocus)
                const TextField(
                  key: ValueKey<String>('document-editor-focus'),
                  autofocus: true,
                ),
              SizedBox(
                width: 720,
                child: MermaidCodeBlockWidget(
                  key: ValueKey<String>('mermaid-widget-${block.id}'),
                  block: block,
                  config: config,
                  renderer: renderer,
                  renderService: service,
                  blockIndex: 0,
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpBlock(
  WidgetTester tester, {
  required String code,
  required NativeMermaidRenderService service,
  required MermaidRenderer renderer,
  String blockId = 'mermaid',
  MermaidDiagramConfig config = const MermaidDiagramConfig(
    debounce: Duration.zero,
  ),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool highContrast = false,
  bool includeEditorFocus = false,
}) {
  return tester.pumpWidget(
    _wrapMermaidBlock(
      block: CodeBlockNode(
        id: blockId,
        language: 'mermaid',
        code: code,
      ),
      config: config,
      renderer: renderer,
      service: service,
      brightness: brightness,
      textScale: textScale,
      highContrast: highContrast,
      includeEditorFocus: includeEditorFocus,
    ),
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _showPreview(WidgetTester tester) async {
  await tester.tap(find.byKey(_toggleKey));
  await tester.pump();
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
  );
}

void main() {
  testWidgets('initial source view preserves UTF-8 text and line numbers', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A[开始 🚀] --> B{审批}',
      service: service,
      renderer: renderer,
    );

    expect(_richTextContaining('flowchart TD'), findsOneWidget);
    expect(_richTextContaining('A[开始 🚀] --> B{审批}'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(renderer.renderCount, 0);
  });

  testWidgets('explicit preview bypasses debounce and uses one render result', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);
    const source = 'flowchart LR\n  A[开始] -->|通过| B[结束]';

    await _pumpBlock(
      tester,
      code: source,
      service: service,
      renderer: renderer,
      config: const MermaidDiagramConfig(
        debounce: Duration(days: 1),
      ),
    );
    await _showPreview(tester);
    expect(find.text('正在生成 Mermaid 预览'), findsOneWidget);
    await _waitFor(tester, find.byType(MermaidDiagram));

    final diagram = tester.widget<MermaidDiagram>(find.byType(MermaidDiagram));
    expect(diagram.result.sourceDigest, mermaidSourceDigest(source));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(service.stats.parseCount, 1);
    expect(service.stats.layoutCount, 1);
    expect(renderer.renderCount, 0);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pump();
    expect(_richTextContaining('flowchart LR'), findsOneWidget);
    expect(_richTextContaining('A[开始] -->|通过| B[结束]'), findsOneWidget);
  });

  testWidgets('empty, unsupported, and limit failures have distinct cards', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: '   ',
      blockId: 'empty',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    expect(find.text('Mermaid 源码为空'), findsOneWidget);

    await _pumpBlock(
      tester,
      code: 'classDiagram\n  class Foo',
      blockId: 'unsupported',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.text('不支持的 Mermaid 图表类型'));
    expect(find.textContaining('classDiagram'), findsOneWidget);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A --> B',
      blockId: 'limit',
      service: service,
      renderer: renderer,
      config: const MermaidDiagramConfig(
        debounce: Duration.zero,
        limits: MermaidRenderLimits(maxSourceCharacters: 5),
      ),
    );
    await _showPreview(tester);
    await _waitFor(tester, find.text('Mermaid 输入超过资源限制'));
    expect(find.textContaining('5 字符上限'), findsOneWidget);

    await tester.tap(find.text('查看源码'));
    await tester.pump();
    expect(_richTextContaining('flowchart TD'), findsOneWidget);
  });

  testWidgets('stale results cannot overwrite newer source', (tester) async {
    final delegate = DefaultNativeMermaidRenderService();
    final service = _DelayedRenderService(
      delegate,
      (source) => source.contains('OLD')
          ? const Duration(milliseconds: 180)
          : const Duration(milliseconds: 5),
    );
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);
    const oldSource = 'flowchart TD\n  OLD --> A';
    const newSource = 'flowchart TD\n  NEW --> B';

    await _pumpBlock(
      tester,
      code: oldSource,
      blockId: 'stale',
      service: service,
      renderer: renderer,
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.requests, isNotEmpty);

    await _pumpBlock(
      tester,
      code: newSource,
      blockId: 'stale',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(MermaidDiagram));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    final result =
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).result;
    expect(result.sourceDigest, mermaidSourceDigest(newSource));
    expect(result.diagram.getNode('NEW'), isNotNull);
    expect(result.diagram.getNode('OLD'), isNull);
  });

  testWidgets('auto theme follows brightness and invalidates render cache', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);
    const source = 'flowchart TD\n  A --> B';

    await _pumpBlock(
      tester,
      code: source,
      blockId: 'theme',
      service: service,
      renderer: renderer,
      brightness: Brightness.light,
      config: const MermaidDiagramConfig(),
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(MermaidDiagram));
    final light =
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).result;

    await _pumpBlock(
      tester,
      code: source,
      blockId: 'theme',
      service: service,
      renderer: renderer,
      brightness: Brightness.dark,
      config: const MermaidDiagramConfig(),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
      final diagrams = find.byType(MermaidDiagram).evaluate();
      if (diagrams.isNotEmpty &&
          tester
                  .widget<MermaidDiagram>(find.byType(MermaidDiagram))
                  .result
                  .themeKey !=
              light.themeKey) {
        break;
      }
    }
    final dark =
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).result;

    expect(light.themeKey, contains('light'));
    expect(dark.themeKey, contains('dark'));
    expect(dark.style.backgroundColor, isNot(light.style.backgroundColor));
    expect(service.stats.parseCount, 1);
    expect(service.stats.layoutCount, 2);
  });

  testWidgets('200% scaling and high contrast affect native style', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A[可读文字] --> B[完成]',
      service: service,
      renderer: renderer,
      textScale: 2,
      highContrast: true,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(MermaidDiagram));
    final result =
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).result;

    expect(result.style.defaultNodeStyle.fontSize, greaterThanOrEqualTo(22));
    expect(result.style.defaultNodeStyle.strokeWidth, greaterThanOrEqualTo(2));
    expect(result.style.defaultEdgeStyle.strokeWidth, greaterThanOrEqualTo(2));
  });

  testWidgets('hover does not steal focus; clicking the preview does', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A --> B',
      service: service,
      renderer: renderer,
      includeEditorFocus: true,
    );
    await tester.pump();
    await _showPreview(tester);
    await _waitFor(tester, find.byType(InteractiveViewer));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(InteractiveViewer)));
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('wenz-richtext-mermaid-preview'),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'wenz-richtext-mermaid-preview',
    );
    await mouse.removePointer();
  });

  testWidgets('ordinary wheel is not zoom; Ctrl+wheel zooms', (tester) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart LR\n  A --> B --> C',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(InteractiveViewer));
    await tester.pump();
    final viewer = find.byType(InteractiveViewer);
    final controller =
        tester.widget<InteractiveViewer>(viewer).transformationController!;
    final before = controller.value.getMaxScaleOnAxis();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(viewer),
        scrollDelta: const Offset(0, -240),
      ),
    );
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(before, 0.0001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(viewer),
        scrollDelta: const Offset(0, -240),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(before));
  });

  testWidgets('preview toolbar supports zoom, reset, and fit', (tester) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart LR\n  A --> B --> C',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(InteractiveViewer));
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final controller = viewer.transformationController!;
    final fitScale = controller.value.getMaxScaleOnAxis();

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-mermaid-zoom-in')),
    );
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(fitScale));

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-mermaid-reset')),
    );
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.0001));

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-mermaid-fit')),
    );
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(fitScale, 0.0001));
  });

  testWidgets('preview viewport stays 16:9 under unbounded height', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A --> B',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(InteractiveViewer));
    final size = tester.getSize(find.byType(InteractiveViewer));

    expect(size.width, greaterThan(0));
    expect(size.height, closeTo(size.width / (16 / 9), 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Semantics summary identifies type, nodes, and edges', (
    tester,
  ) async {
    final service = DefaultNativeMermaidRenderService();
    final renderer = _RecordingMermaidRenderer();
    addTearDown(service.dispose);

    await _pumpBlock(
      tester,
      code: 'flowchart TD\n  A --> B',
      service: service,
      renderer: renderer,
    );
    await _showPreview(tester);
    await _waitFor(tester, find.byType(MermaidDiagram));

    expect(
      find.bySemanticsLabel(RegExp('流程图，2 个节点，1 条连线')),
      findsOneWidget,
    );
  });
}
