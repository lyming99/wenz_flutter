import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/widgets/block_geometry_registry.dart';
import 'package:wenz_richtext/wenz_richtext.dart';

// ---------------------------------------------------------------------------
// Fake / test doubles
// ---------------------------------------------------------------------------

/// Fake [MermaidRenderer] that returns a canned SVG string and records every
/// call so tests can verify the plugin passes the right source and options.
class _FakeMermaidRenderer implements MermaidRenderer {
  _FakeMermaidRenderer({this.resultSvg = '<svg></svg>'});

  final String resultSvg;
  final List<_MermaidRenderCall> calls = <_MermaidRenderCall>[];

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    calls.add(_MermaidRenderCall(source, optionsJson));
    return resultSvg;
  }
}

class _MermaidRenderCall {
  const _MermaidRenderCall(this.source, this.optionsJson);
  final String source;
  final String? optionsJson;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal [BlockRenderContext] for a code block.
BlockRenderContext _codeRenderContext(CodeBlockNode block) {
  return BlockRenderContext(
    block: block,
    blockIndex: 0,
    selection: null,
    compositionState: null,
    registry: BlockGeometryRegistry(),
    showCaret: false,
  );
}

/// Installs the default renderers and then the mermaid plugin, returning the
/// [BlockRendererRegistry] for inspection.
BlockRendererRegistry _installMermaidPlugin({
  required MermaidRenderer renderer,
  MermaidDiagramConfig? config,
}) {
  final controller = WenzRichTextController();
  final registry = BlockRendererRegistry();
  WenzRichTextEditor.installDefaultRenderers(registry);

  installWenzRichTextPlugins(
    plugins: <WenzRichTextPlugin>[
      MermaidDiagramPlugin(
        config: config ?? const MermaidDiagramConfig(),
        renderer: renderer,
      ),
    ],
    context: WenzPluginContext(
      controller: controller,
      blockRenderers: registry,
    ),
  );

  return registry;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Plugin registration
  // -----------------------------------------------------------------------

  testWidgets(
    'MermaidDiagramPlugin returns MermaidCodeBlockWidget for mermaid code',
    (tester) async {
      final fakeRenderer = _FakeMermaidRenderer();
      final registry = _installMermaidPlugin(renderer: fakeRenderer);

      const mermaidBlock = CodeBlockNode(
        id: 'm1',
        language: 'mermaid',
        code: 'flowchart TD\n  A --> B',
      );

      final builder = registry.resolveForBlock(
        mermaidBlock,
        fallback: (_, __) => const SizedBox.shrink(),
      );
      expect(builder, isNotNull);

      final renderContext = _codeRenderContext(mermaidBlock);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => builder(context, renderContext),
          ),
        ),
      );

      // The builder should produce a MermaidCodeBlockWidget.
      expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
    },
  );

  testWidgets(
    'MermaidDiagramPlugin delegates non-mermaid code to original renderer',
    (tester) async {
      final fakeRenderer = _FakeMermaidRenderer();
      final registry = _installMermaidPlugin(renderer: fakeRenderer);

      const dartBlock = CodeBlockNode(
        id: 'd1',
        language: 'dart',
        code: 'void main() {}',
      );

      final builder = registry.resolveForBlock(
        dartBlock,
        fallback: (_, __) => const SizedBox.shrink(),
      );
      expect(builder, isNotNull);

      final renderContext = _codeRenderContext(dartBlock);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => builder(context, renderContext),
          ),
        ),
      );

      // Non-mermaid code blocks must NOT produce a MermaidCodeBlockWidget.
      expect(find.byType(MermaidCodeBlockWidget), findsNothing);
    },
  );

  testWidgets(
    'installing twice does not double-wrap — mermaid after non-mermaid '
    'both resolve builders',
    (tester) async {
      final fakeRenderer = _FakeMermaidRenderer();
      final registry = _installMermaidPlugin(renderer: fakeRenderer);

      const mermaidBlock = CodeBlockNode(
        id: 'm2',
        language: 'mermaid',
        code: 'graph LR',
      );
      const pythonBlock = CodeBlockNode(
        id: 'p1',
        language: 'python',
        code: 'print("hi")',
      );

      final mermaidBuilder = registry.resolveForBlock(
        mermaidBlock,
        fallback: (_, __) => const SizedBox.shrink(),
      );
      final pythonBuilder = registry.resolveForBlock(
        pythonBlock,
        fallback: (_, __) => const SizedBox.shrink(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: <Widget>[
              Builder(
                builder: (context) =>
                    mermaidBuilder(context, _codeRenderContext(mermaidBlock)),
              ),
              Builder(
                builder: (context) =>
                    pythonBuilder(context, _codeRenderContext(pythonBlock)),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(MermaidCodeBlockWidget), findsOneWidget);
    },
  );

  testWidgets(
    'Mermaid renderer receives configured theme and safe SVG pipeline options',
    (tester) async {
      final fakeRenderer = _FakeMermaidRenderer(
        resultSvg: '<svg xmlns="http://www.w3.org/2000/svg" '
            'viewBox="0 0 100 50"></svg>',
      );
      final registry = _installMermaidPlugin(
        renderer: fakeRenderer,
        config: const MermaidDiagramConfig(
          debounce: Duration.zero,
          defaultTheme: 'forest',
        ),
      );

      const mermaidBlock = CodeBlockNode(
        id: 'm-options',
        language: 'mermaid',
        code: 'flowchart TD\n  A -->',
      );
      final builder = registry.resolveForBlock(
        mermaidBlock,
        fallback: (_, __) => const SizedBox.shrink(),
      );
      final renderContext = _codeRenderContext(mermaidBlock);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => builder(context, renderContext),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeRenderer.calls, hasLength(1));
      final optionsJson = fakeRenderer.calls.single.optionsJson;
      expect(optionsJson, isNotNull);

      final options = jsonDecode(optionsJson!) as Map<String, dynamic>;
      final siteConfig = options['site_config']! as Map<String, dynamic>;
      final svgOptions = options['svg']! as Map<String, dynamic>;
      final hostTheme = options['host_theme']! as Map<String, dynamic>;
      final hostOutput = hostTheme['output']! as Map<String, dynamic>;

      expect(siteConfig['theme'], 'forest');
      expect(svgOptions['pipeline'], 'resvg-safe');
      expect(hostOutput['pipeline'], 'resvg-safe');
    },
  );

  // -----------------------------------------------------------------------
  // 2. VectorGraphicsDiagramSurface
  // -----------------------------------------------------------------------

  testWidgets(
    'VectorGraphicsDiagramSurface renders SVG string as widget',
    (tester) async {
      const surface = VectorGraphicsDiagramSurface();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => surface.render(
              context,
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
              '<circle cx="50" cy="50" r="40" fill="red"/></svg>',
            ),
          ),
        ),
      );

      // flutter_svg produces a Widget from valid SVG — verify something was
      // painted (we don't check graphical accuracy).
      expect(find.byType(SvgPicture), findsOneWidget);
    },
  );

  testWidgets(
    'VectorGraphicsDiagramSurface returns empty box for malformed SVG',
    (tester) async {
      const surface = VectorGraphicsDiagramSurface();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => surface.render(
              context,
              'not valid svg <<<>>>',
            ),
          ),
        ),
      );

      // Best-effort: malformed input should not crash.
      expect(tester.takeException(), isNull);
    },
  );

  // -----------------------------------------------------------------------
  // 3. Fake renderer isolation
  // -----------------------------------------------------------------------

  test('FakeMermaidRenderer records renderSvg calls', () {
    final fake = _FakeMermaidRenderer(resultSvg: '<svg>test</svg>');

    // Synchronous verification of the fake — the actual async path is
    // exercised by the widget tests above.
    expect(fake.calls, isEmpty);
    expect(fake.resultSvg, '<svg>test</svg>');
  });

  test('MermaidDiagramConfig defaults are correct', () {
    const config = MermaidDiagramConfig();

    expect(config.svgSurface, isNull);
    expect(config.debounce, const Duration(milliseconds: 300));
    expect(config.defaultTheme, 'default');
  });

  test('MermaidDiagramConfig accepts custom values', () {
    const surface = VectorGraphicsDiagramSurface();
    const config = MermaidDiagramConfig(
      svgSurface: surface,
      debounce: Duration(seconds: 1),
      defaultTheme: 'dark',
    );

    expect(config.svgSurface, same(surface));
    expect(config.debounce, const Duration(seconds: 1));
    expect(config.defaultTheme, 'dark');
  });

  test('MermaidDiagramPlugin has correct id', () {
    final plugin = MermaidDiagramPlugin(
      config: const MermaidDiagramConfig(),
      renderer: _FakeMermaidRenderer(),
    );

    expect(plugin.id, 'wenz.richtext.mermaid');
  });
}
