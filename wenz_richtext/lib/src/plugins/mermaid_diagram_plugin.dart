import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:merman/merman.dart';

import '../core/model/block_node.dart';
import '../widgets/mermaid/mermaid_code_block_widget.dart';
import 'editor_plugin.dart';

// ---------------------------------------------------------------------------
// SVG surface abstraction
// ---------------------------------------------------------------------------

/// Renders an SVG string into a Flutter widget.
///
/// The default [VectorGraphicsDiagramSurface] uses [SvgPicture.string] for
/// best-effort rendering. Host apps can replace this with a WebView-backed
/// surface for higher fidelity.
abstract class DiagramSvgSurface {
  const DiagramSvgSurface();

  /// Builds a widget that renders [svg].
  ///
  /// [maxWidth] is an optional constraint hint from the editor layout.
  Widget render(BuildContext context, String svg, {double? maxWidth});
}

/// Default [DiagramSvgSurface] backed by [flutter_svg].
///
/// This is a best-effort renderer: complex Mermaid output may not be fully
/// supported by the flutter_svg parser. Host apps that need pixel-perfect
/// results should inject a WebView-based surface instead.
class VectorGraphicsDiagramSurface extends DiagramSvgSurface {
  const VectorGraphicsDiagramSurface();

  @override
  Widget render(BuildContext context, String svg, {double? maxWidth}) {
    final constrainedWidth =
        maxWidth != null && maxWidth.isFinite && maxWidth > 0
            ? maxWidth
            : null;
    try {
      final picture = SvgPicture.string(
        svg,
        width: constrainedWidth,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      if (constrainedWidth == null) {
        return Align(
          alignment: Alignment.center,
          child: picture,
        );
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constrainedWidth),
        child: SizedBox(
          width: constrainedWidth,
          child: picture,
        ),
      );
    } catch (_) {
      // Malformed or unsupported SVG — return an empty box so the error UI
      // in the mermaid widget can take over.
      return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for Mermaid diagram rendering.
///
/// Pass an instance to [MermaidDiagramPlugin] to control the SVG surface,
/// debounce interval, and default theme.
class MermaidDiagramConfig {
  const MermaidDiagramConfig({
    this.svgSurface,
    this.debounce = const Duration(milliseconds: 300),
    this.defaultTheme = 'default',
  });

  /// The SVG surface used to paint diagram output.
  ///
  /// When `null` the plugin creates a default [VectorGraphicsDiagramSurface].
  final DiagramSvgSurface? svgSurface;

  /// How long to wait after the last source change before re-rendering.
  final Duration debounce;

  /// Default Mermaid theme identifier (e.g. `'default'`, `'dark'`, `'forest'`).
  final String defaultTheme;
}

// ---------------------------------------------------------------------------
// Renderer abstraction (testable)
// ---------------------------------------------------------------------------

/// Renders Mermaid diagram source into an SVG string.
///
/// The default [NativeMermaidRenderer] delegates to the `merman` FFI package.
/// Inject a fake implementation in tests to avoid native library dependencies.
abstract class MermaidRenderer {
  /// Renders [source] (Mermaid DSL) into an SVG string.
  ///
  /// [optionsJson] is forwarded to the merman engine. Pass
  /// `'{"svg":{"pipeline":"resvg-safe"}}'` for the safe SVG pipeline.
  Future<String> renderSvg(String source, {String? optionsJson});
}

/// Default [MermaidRenderer] backed by the `merman` FFI package.
///
/// Each call to [renderSvg] creates a fresh [Merman] engine via
/// [Merman.open]. FFI failures (missing dynamic library, unsupported
/// platform) are surfaced as exceptions so the widget can fall back to
/// source-only mode.
class NativeMermaidRenderer implements MermaidRenderer {
  const NativeMermaidRenderer();

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) async {
    return Merman.open().renderSvg(source, optionsJson: optionsJson);
  }
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

/// Wraps the built-in [BlockType.code] renderer so that [CodeBlockNode]s with
/// `language == 'mermaid'` render as interactive diagram widgets instead of
/// plain syntax-highlighted code.
///
/// Non-mermaid code blocks are delegated to the original renderer unchanged.
class MermaidDiagramPlugin extends WenzRichTextPlugin {
  /// Creates a plugin that intercepts mermaid code blocks.
  ///
  /// [config] controls the SVG surface, debounce, and theme.
  /// [renderer] is the Mermaid engine bridge; defaults to
  /// [NativeMermaidRenderer] for production use.
  const MermaidDiagramPlugin({
    required this.config,
    this.renderer = const NativeMermaidRenderer(),
  });

  /// Plugin identifier.
  @override
  String get id => 'wenz.richtext.mermaid';

  /// Configuration for diagram rendering behaviour.
  final MermaidDiagramConfig config;

  /// The Mermaid engine bridge, replaceable for testing.
  final MermaidRenderer renderer;

  @override
  void install(WenzPluginContext context) {
    final registry = context.blockRenderers;
    if (registry == null) return;

    // Resolve the existing code block renderer so non-mermaid code blocks
    // continue to work exactly as before.
    final originalBuilder = registry.resolve(
      BlockType.code,
      fallback: (_, __) => const SizedBox.shrink(),
    );

    // Register a wrapper that intercepts mermaid code blocks.
    registry.register(BlockType.code, (buildContext, renderContext) {
      final block = renderContext.block;
      if (block is CodeBlockNode && block.language == 'mermaid') {
        return MermaidCodeBlockWidget(
          block: block,
          config: config,
          renderer: renderer,
          blockIndex: renderContext.blockIndex,
        );
      }
      return originalBuilder(buildContext, renderContext);
    });
  }
}
