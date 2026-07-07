import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake [MermaidRenderer] that returns a canned SVG and counts calls.
class _FakeMermaidRenderer implements MermaidRenderer {
  _FakeMermaidRenderer({this.resultSvg = '<svg></svg>'});

  final String resultSvg;
  int renderCount = 0;
  final List<String?> optionsJsonCalls = <String?>[];

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    renderCount++;
    optionsJsonCalls.add(optionsJson);
    return resultSvg;
  }
}

/// Fake [MermaidRenderer] that always throws — used to exercise the error path.
class _ThrowingMermaidRenderer implements MermaidRenderer {
  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    throw Exception('merman FFI not available');
  }
}

/// Fake [DiagramSvgSurface] that returns a recognisable widget so tests can
/// assert the preview mode is active.
class _FakeDiagramSvgSurface extends DiagramSvgSurface {
  const _FakeDiagramSvgSurface();

  @override
  Widget render(BuildContext context, String svg, {double? maxWidth}) {
    return const SizedBox(
      key: ValueKey<String>('fake-svg-surface'),
      width: 200,
      height: 100,
    );
  }
}

const String _kWideSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2000 500">'
    '<rect width="2000" height="500" fill="white"/></svg>';

const String _kTallSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 2000">'
    '<rect width="500" height="2000" fill="white"/></svg>';

const String _kSizeOnlySvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360">'
    '<rect width="640" height="360" fill="white"/></svg>';

const String _kNoSizeSvg =
    '<svg xmlns="http://www.w3.org/2000/svg">'
    '<rect width="100" height="100" fill="white"/></svg>';

const String _kMalformedSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<path d="M 0 0"><g></svg>';

// ---------------------------------------------------------------------------
// Widget under test harness
// ---------------------------------------------------------------------------

/// Wraps [MermaidCodeBlockWidget] with the minimum Material ancestor it needs.
Widget _wrapWidget(
  MermaidCodeBlockWidget child,
) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required String svg,
  String blockId = 'preview',
}) async {
  final renderer = _FakeMermaidRenderer(resultSvg: svg);

  await tester.pumpWidget(
    _wrapWidget(
      MermaidCodeBlockWidget(
        block: CodeBlockNode(
          id: blockId,
          language: 'mermaid',
          code: 'flowchart TD\n  A -->',
        ),
        config: const MermaidDiagramConfig(
          svgSurface: _FakeDiagramSvgSurface(),
          debounce: Duration.zero,
        ),
        renderer: renderer,
        blockIndex: 0,
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Initial source mode
  // -----------------------------------------------------------------------

  testWidgets('initial state shows source code with line numbers', (
    tester,
  ) async {
    const block = CodeBlockNode(
      id: 'm1',
      language: 'mermaid',
      code: 'flowchart TD\n  A --> B',
    );
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: block,
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    // Before any async rendering completes, the widget must be in source mode
    // and show the diagram source text.
    expect(find.textContaining('flowchart TD'), findsOneWidget);
    expect(find.textContaining('A --> B'), findsOneWidget);

    // The toggle button should show the "preview" icon (visibility_outlined)
    // because we're currently in source mode.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.code), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 2. Toggle between source and preview
  // -----------------------------------------------------------------------

  testWidgets('toggle button switches between source and preview modes', (
    tester,
  ) async {
    const block = CodeBlockNode(
      id: 'm2',
      language: 'mermaid',
      code: 'graph LR',
    );
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: block,
          config: const MermaidDiagramConfig(
            svgSurface: _FakeDiagramSvgSurface(),
          ),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    // Wait for the debounce timer to fire and the async render to complete.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Still in source mode initially — the SVG was computed in the background
    // but _showSource is still true.
    expect(find.textContaining('graph LR'), findsOneWidget);

    // Tap the toggle button to switch to preview mode.
    final toggleButton = find.byKey(
      const ValueKey<String>('wenz-richtext-mermaid-toggle'),
    );
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Source text should be gone, fake SVG surface should appear.
    expect(find.textContaining('graph LR'), findsNothing);
    expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    // Toggle icon now shows "code" since we're in preview mode.
    expect(find.byIcon(Icons.code), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    // Tap again to switch back to source mode.
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Source text should be back.
    expect(find.textContaining('graph LR'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 3. Debounce — multiple rapid source changes coalesce
  // -----------------------------------------------------------------------

  testWidgets('debounce coalesces rapid source changes into one render', (
    tester,
  ) async {
    final renderer = _FakeMermaidRenderer();

    // First pump: source "code-A"
    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: const CodeBlockNode(
            id: 'm3',
            language: 'mermaid',
            code: 'code-A',
          ),
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    // Rapidly replace with different sources — each pumpWidget disposes the
    // previous widget (cancelling its debounce Timer) and creates a new one.
    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: const CodeBlockNode(
            id: 'm3',
            language: 'mermaid',
            code: 'code-B',
          ),
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: const CodeBlockNode(
            id: 'm3',
            language: 'mermaid',
            code: 'code-C',
          ),
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    // Now let the last debounce timer fire and the render complete.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Only one render call should have been made — for the final source.
    expect(renderer.renderCount, 1);

    // The visible source should be the last one.
    expect(find.textContaining('code-C'), findsOneWidget);
    expect(find.textContaining('code-A'), findsNothing);
    expect(find.textContaining('code-B'), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 4. Error state
  // -----------------------------------------------------------------------

  testWidgets('shows error message and view-source button on render failure', (
    tester,
  ) async {
    const block = CodeBlockNode(
      id: 'm4',
      language: 'mermaid',
      code: 'invalid diagram',
    );
    final renderer = _ThrowingMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: block,
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    // Wait for the debounce timer and render attempt.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // We should still be in source mode (error is only visible in preview).
    expect(find.textContaining('invalid diagram'), findsOneWidget);

    // Switch to preview — the error view should appear.
    final toggleButton = find.byKey(
      const ValueKey<String>('wenz-richtext-mermaid-toggle'),
    );
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Error icon and "查看源码" recovery button should be visible.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('查看源码'), findsOneWidget);

    // Tap "查看源码" to go back to source mode.
    await tester.tap(find.text('查看源码'));
    await tester.pumpAndSettle();

    // Should be back in source mode, error cleared.
    expect(find.textContaining('invalid diagram'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('widget does not crash when renderer throws', (tester) async {
    const block = CodeBlockNode(
      id: 'm5',
      language: 'mermaid',
      code: 'graph TD',
    );
    final renderer = _ThrowingMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: block,
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Widget must still be in the tree — no crash.
    expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // -----------------------------------------------------------------------
  // 5. Loading indicator
  // -----------------------------------------------------------------------

  testWidgets('preview request shows loading before rendering completes', (
    tester,
  ) async {
    const block = CodeBlockNode(
      id: 'm6',
      language: 'mermaid',
      code: 'flowchart TD',
    );

    // Capture the preview-request state before the debounce fires.
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: block,
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')),
    );
    await tester.pump();

    expect(find.textContaining('flowchart TD'), findsNothing);
    expect(find.text('正在准备 Mermaid 预览'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 6. Empty source
  // -----------------------------------------------------------------------

  testWidgets('empty source does not trigger a render call', (tester) async {
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: const CodeBlockNode(
            id: 'm7',
            language: 'mermaid',
            code: '',
          ),
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Empty source should not trigger rendering.
    expect(renderer.renderCount, 0);
  });

  testWidgets('empty source preview shows feedback and source recovery', (
    tester,
  ) async {
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      _wrapWidget(
        MermaidCodeBlockWidget(
          block: const CodeBlockNode(
            id: 'm-empty-preview',
            language: 'mermaid',
            code: '',
          ),
          config: const MermaidDiagramConfig(),
          renderer: renderer,
          blockIndex: 0,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')),
    );
    await tester.pump();

    expect(find.text('Mermaid 源码为空'), findsOneWidget);
    expect(find.text('查看源码'), findsOneWidget);

    await tester.tap(find.text('查看源码'));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(renderer.renderCount, 0);
  });

  // -----------------------------------------------------------------------
  // 7. Preview under unbounded height (regression: infinite-size crash)
  // -----------------------------------------------------------------------

  testWidgets('preview does not crash under unbounded height constraints', (
    tester,
  ) async {
    // Reproduce the original crash condition: the mermaid block sits inside
    // the editor's loose-fit Stack, which supplies
    // BoxConstraints(w=<finite>, 0.0<=h<=Infinity) to its children. The
    // InteractiveViewer (constrained: false) used to resolve its internal
    // OverflowBox to infinite height and trip a layout assertion.
    //
    // We mirror that context with an unbounded-height Stack + Column.
    const block = CodeBlockNode(
      id: 'm8',
      language: 'mermaid',
      code: 'flowchart TD\n  A --> B',
    );
    final renderer = _FakeMermaidRenderer();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            // Column inside a loose Stack, just like the editor.
            child: Stack(
              children: <Widget>[
                MermaidCodeBlockWidget(
                  block: block,
                  config: const MermaidDiagramConfig(
                    svgSurface: _FakeDiagramSvgSurface(),
                  ),
                  renderer: renderer,
                  blockIndex: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Let the debounce fire and the render complete, then switch to preview.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')));
    await tester.pumpAndSettle();

    // No layout exception should be recorded while painting the preview.
    expect(tester.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
  });

  testWidgets(
    'preview viewport keeps a fixed ratio for wide and tall SVGs',
    (tester) async {
      await _pumpPreview(tester, svg: _kWideSvg, blockId: 'wide');

      final wideViewportSize = tester.getSize(find.byType(InteractiveViewer));
      expect(wideViewportSize.width, greaterThan(0));
      expect(
        wideViewportSize.height,
        closeTo(wideViewportSize.width / (16.0 / 9.0), 0.5),
      );
      expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pumpPreview(tester, svg: _kTallSvg, blockId: 'tall');

      final tallViewportSize = tester.getSize(find.byType(InteractiveViewer));
      expect(tallViewportSize.width, closeTo(wideViewportSize.width, 0.5));
      expect(tallViewportSize.height, closeTo(wideViewportSize.height, 0.5));
      expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview accepts width-height and missing-size SVG roots without crashing',
    (tester) async {
      await _pumpPreview(tester, svg: _kSizeOnlySvg, blockId: 'size-only');

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pumpPreview(tester, svg: _kNoSizeSvg, blockId: 'no-size');

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default SVG surface failure shows a visible fallback in preview',
    (tester) async {
      final renderer = _FakeMermaidRenderer(resultSvg: _kMalformedSvg);

      await tester.pumpWidget(
        _wrapWidget(
          MermaidCodeBlockWidget(
            block: const CodeBlockNode(
              id: 'surface-failure',
              language: 'mermaid',
              code: 'flowchart TD\n  A --> B',
            ),
            config: const MermaidDiagramConfig(debounce: Duration.zero),
            renderer: renderer,
            blockIndex: 0,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wenz-richtext-mermaid-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('SVG 预览暂不可用'), findsOneWidget);
      expect(find.text('查看源码'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview initial transform fits the SVG into the viewport',
    (tester) async {
      await _pumpPreview(tester, svg: _kWideSvg, blockId: 'fit');

      final interactiveViewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = interactiveViewer.transformationController!;
      final viewportSize = tester.getSize(find.byType(InteractiveViewer));
      final scale = controller.value.getMaxScaleOnAxis();

      expect(scale, lessThan(1));
      expect(2000 * scale, lessThanOrEqualTo(viewportSize.width));
      expect(500 * scale, lessThanOrEqualTo(viewportSize.height));
      expect(find.byKey(const ValueKey<String>('fake-svg-surface')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview focuses on click and wheel scroll zooms around the pointer',
    (tester) async {
      await _pumpPreview(tester, svg: _kWideSvg, blockId: 'wheel');

      final viewerFinder = find.byType(InteractiveViewer);
      await tester.tap(viewerFinder);
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'wenz-richtext-mermaid-preview',
      );

      final before = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!
          .value
          .getMaxScaleOnAxis();

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewerFinder),
          scrollDelta: const Offset(0, -240),
        ),
      );
      await tester.pump();

      final after = tester
          .widget<InteractiveViewer>(viewerFinder)
          .transformationController!
          .value
          .getMaxScaleOnAxis();

      expect(after, greaterThan(before));
    },
  );
}
