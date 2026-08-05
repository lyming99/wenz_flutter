import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenz_richtext/src/widgets/block_geometry_registry.dart';
import 'package:wenz_richtext/src/widgets/mermaid/mermaid_code_block_widget.dart'
    show MermaidCodeBlockSourceControls;
import 'package:wenz_richtext/wenz_richtext.dart';

class _RecordingMermaidRenderer implements MermaidRenderer {
  int renderCount = 0;

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    renderCount++;
    return '<svg></svg>';
  }
}

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

BlockRendererRegistry _installMermaidPlugin({
  MermaidRenderer? renderer,
  MermaidDiagramConfig config = const MermaidDiagramConfig(),
  BlockRendererBuilder? originalCodeRenderer,
}) {
  final controller = WenzRichTextController();
  final registry = BlockRendererRegistry();
  final renderService = DefaultNativeMermaidRenderService();
  addTearDown(controller.dispose);
  addTearDown(renderService.dispose);

  if (originalCodeRenderer != null) {
    registry.register(BlockType.code, originalCodeRenderer);
  } else {
    WenzRichTextEditor.installDefaultRenderers(registry);
  }

  installWenzRichTextPlugins(
    plugins: <WenzRichTextPlugin>[
      MermaidDiagramPlugin(
        config: config,
        renderer: renderer ?? const NativeMermaidRenderer(),
        renderService: renderService,
      ),
    ],
    context: WenzPluginContext(
      controller: controller,
      blockRenderers: registry,
    ),
  );

  return registry;
}

Widget _buildResolvedCodeBlock(
  BlockRendererRegistry registry,
  CodeBlockNode block,
) {
  final builder = registry.resolveForBlock(
    block,
    fallback: (_, __) => const SizedBox.shrink(),
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => builder(context, _codeRenderContext(block)),
    ),
  );
}

void main() {
  group('MermaidDiagramPlugin pure Flutter path', () {
    testWidgets('returns MermaidCodeBlockWidget for mermaid code blocks', (
      tester,
    ) async {
      final renderer = _RecordingMermaidRenderer();
      const config = MermaidDiagramConfig(
        debounce: Duration.zero,
        defaultTheme: 'forest',
      );
      final registry = _installMermaidPlugin(
        renderer: renderer,
        config: config,
      );

      const block = CodeBlockNode(
        id: 'm1',
        language: 'mermaid',
        code: 'flowchart TD\n  A --> B',
      );

      await tester.pumpWidget(_buildResolvedCodeBlock(registry, block));
      await tester.pump();

      final widget = tester.widget<MermaidCodeBlockWidget>(
        find.byType(MermaidCodeBlockWidget),
      );
      expect(widget.block, same(block));
      expect(widget.config.debounce, Duration.zero);
      expect(widget.config.defaultTheme, 'forest');
      expect(widget.renderer, same(renderer));
      expect(renderer.renderCount, 0);
    });

    testWidgets('passes the original code renderer into mermaid source mode', (
      tester,
    ) async {
      final registry = _installMermaidPlugin(
        originalCodeRenderer: (_, renderContext) {
          final block = renderContext.block as CodeBlockNode;
          return Text('source:${block.language}:${block.code}');
        },
      );

      const block = CodeBlockNode(
        id: 'm-source',
        language: 'mermaid',
        code: 'flowchart TD\n  A --> B',
      );

      await tester.pumpWidget(_buildResolvedCodeBlock(registry, block));
      await tester.pump();

      final widget = tester.widget<MermaidCodeBlockWidget>(
        find.byType(MermaidCodeBlockWidget),
      );
      expect(widget.sourceBuilder, isNotNull);
      expect(find.byType(MermaidCodeBlockSourceControls), findsOneWidget);
      expect(
        find.text('source:mermaid:flowchart TD\n  A --> B'),
        findsOneWidget,
      );
    });

    testWidgets('recognizes normalized mermaid info-string variants', (
      tester,
    ) async {
      final registry = _installMermaidPlugin();
      const blocks = <CodeBlockNode>[
        CodeBlockNode(
            id: 'trimmed', language: ' Mermaid ', code: 'flowchart TD'),
        CodeBlockNode(id: 'upper', language: 'MERMAID', code: 'flowchart TD'),
        CodeBlockNode(
          id: 'extra',
          language: 'mermaid theme=dark',
          code: 'flowchart TD',
        ),
        CodeBlockNode(
          id: 'lang-class',
          language: 'language-mermaid',
          code: 'flowchart TD',
        ),
        CodeBlockNode(
          id: 'brace-class',
          language: '{.mermaid}',
          code: 'flowchart TD',
        ),
        CodeBlockNode(
          id: 'dot-lang-class',
          language: '.language-mermaid',
          code: 'flowchart TD',
        ),
        CodeBlockNode(
          id: 'brace-lang-class',
          language: '{.language-mermaid}',
          code: 'flowchart TD',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (final block in blocks)
                  Builder(
                    builder: (context) {
                      final builder = registry.resolveForBlock(
                        block,
                        fallback: (_, __) => const SizedBox.shrink(),
                      );
                      return builder(context, _codeRenderContext(block));
                    },
                  ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MermaidCodeBlockWidget), findsNWidgets(blocks.length));
    });

    testWidgets('delegates non-mermaid code blocks to the original renderer', (
      tester,
    ) async {
      final registry = _installMermaidPlugin(
        originalCodeRenderer: (_, renderContext) {
          final block = renderContext.block as CodeBlockNode;
          return Text('original:${block.language}:${block.code}');
        },
      );

      const block = CodeBlockNode(
        id: 'dart',
        language: 'dart',
        code: 'void main() {}',
      );

      await tester.pumpWidget(_buildResolvedCodeBlock(registry, block));

      expect(find.byType(MermaidCodeBlockWidget), findsNothing);
      expect(find.text('original:dart:void main() {}'), findsOneWidget);
    });

    test('configuration defaults and custom values stay painter-only', () {
      const defaultConfig = MermaidDiagramConfig();
      const customConfig = MermaidDiagramConfig(
        debounce: Duration(seconds: 1),
        defaultTheme: 'dark',
      );

      expect(defaultConfig.debounce, const Duration(milliseconds: 300));
      expect(defaultConfig.defaultTheme, 'auto');
      expect(customConfig.debounce, const Duration(seconds: 1));
      expect(customConfig.defaultTheme, 'dark');
    });

    test('plugin id and legacy renderer compatibility are explicit', () async {
      final plugin = MermaidDiagramPlugin(config: const MermaidDiagramConfig());
      addTearDown(plugin.dispose);

      expect(plugin.id, MermaidDiagramPlugin.pluginId);
      expect(plugin.id, 'wenz.richtext.mermaid');
      await expectLater(
        const NativeMermaidRenderer().renderSvg('flowchart TD\n  A --> B'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
