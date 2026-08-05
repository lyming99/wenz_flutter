import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/model/block_node.dart';
import '../mermaid/render/native_mermaid_render_service.dart';
import '../mermaid/render/render_models.dart';
import '../widgets/mermaid/mermaid_code_block_widget.dart';
import 'editor_plugin.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Configuration for the pure Flutter Mermaid code-block preview.
///
/// The preview path parses Mermaid source in Dart and paints it with Flutter
/// CustomPainters. No WebView, native library, SVG surface, network service, or
/// external process is required.
class MermaidDiagramConfig {
  const MermaidDiagramConfig({
    this.debounce = const Duration(milliseconds: 300),
    this.defaultTheme = 'auto',
    this.limits = const MermaidRenderLimits(),
    this.diagnostics,
  });

  /// How long to wait after the last source change before re-rendering.
  final Duration debounce;

  /// Mermaid theme identifier (`auto`, `light`, `dark`, `forest`, `neutral`).
  final String defaultTheme;

  /// Parser, layout, and total-time resource boundaries.
  final MermaidRenderLimits limits;

  /// Optional privacy-safe performance event sink.
  final MermaidRenderDiagnostics? diagnostics;
}

// ---------------------------------------------------------------------------
// Legacy renderer compatibility
// ---------------------------------------------------------------------------

/// Legacy SVG renderer contract retained for source compatibility.
///
/// Mermaid preview no longer calls this API. Host code that still injects a
/// renderer can keep compiling while migrating to the pure Flutter painter
/// path.
abstract class MermaidRenderer {
  /// Legacy SVG render entry point. The current preview path does not call it.
  Future<String> renderSvg(String source, {String? optionsJson});
}

/// Legacy default renderer retained for constructor compatibility.
///
/// This class no longer opens a native Mermaid library. Calling
/// [renderSvg] fails clearly because the supported default path is now the pure
/// Flutter painter.
class NativeMermaidRenderer implements MermaidRenderer {
  const NativeMermaidRenderer();

  @override
  Future<String> renderSvg(String source, {String? optionsJson}) {
    return Future<String>.error(
      UnsupportedError(
        'Mermaid SVG rendering has been replaced by the pure Flutter painter.',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

/// Wraps the built-in [BlockType.code] renderer so that [CodeBlockNode]s with
/// a Mermaid language marker render as interactive diagram widgets instead of
/// plain syntax-highlighted code.
///
/// Non-mermaid code blocks are delegated to the original renderer unchanged.
class MermaidDiagramPlugin extends WenzRichTextPlugin {
  /// Creates a plugin that intercepts mermaid code blocks.
  ///
  /// [config] controls debounce and theme. [renderer] is retained only for
  /// backwards constructor compatibility and is not used by the default pure
  /// Flutter preview path.
  MermaidDiagramPlugin({
    required this.config,
    this.renderer = const NativeMermaidRenderer(),
    NativeMermaidRenderService? renderService,
  })  : renderService = renderService ??
            DefaultNativeMermaidRenderService(
              diagnostics: config.diagnostics,
            ),
        _ownsRenderService = renderService == null;

  /// Stable plugin identifier used by bootstrap code to avoid duplicate
  /// auto-installation when a host supplies its own Mermaid plugin instance.
  static const String pluginId = 'wenz.richtext.mermaid';

  /// Plugin identifier.
  @override
  String get id => pluginId;

  /// Configuration for diagram rendering behaviour.
  final MermaidDiagramConfig config;

  /// Legacy renderer bridge retained for compatibility; not used by default.
  final MermaidRenderer renderer;

  /// Editor/plugin-scoped service shared by every Mermaid block widget.
  final NativeMermaidRenderService renderService;

  final bool _ownsRenderService;

  @override
  void install(WenzPluginContext context) {
    final registry = context.blockRenderers;
    if (registry == null) return;

    // Resolve the existing code block renderer so non-mermaid code blocks
    // continue to work exactly as before.
    final originalBuilder = registry.has(BlockType.code)
        ? registry.resolve(
            BlockType.code,
            fallback: (_, __) => const SizedBox.shrink(),
          )
        : null;

    // Register a wrapper that intercepts mermaid code blocks.
    registry.register(BlockType.code, (buildContext, renderContext) {
      final block = renderContext.block;
      if (block is CodeBlockNode && _isMermaidCodeLanguage(block.language)) {
        final sourceBuilder = originalBuilder;
        return MermaidCodeBlockWidget(
          block: block,
          config: config,
          renderer: renderer,
          renderService: renderService,
          blockIndex: renderContext.blockIndex,
          sourceBuilder: sourceBuilder == null
              ? null
              : (sourceContext) {
                  return sourceBuilder(sourceContext, renderContext);
                },
        );
      }
      return originalBuilder?.call(buildContext, renderContext) ??
          const SizedBox.shrink();
    });
  }

  @override
  void dispose() {
    if (_ownsRenderService) {
      unawaited(renderService.dispose());
    }
  }
}

const String _mermaidLanguage = 'mermaid';

bool _isMermaidCodeLanguage(String language) {
  final firstToken = _normalizeInfoStringToken(_firstInfoStringToken(language));
  return firstToken == _mermaidLanguage;
}

String _firstInfoStringToken(String infoString) {
  final trimmed = infoString.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final whitespace = RegExp(r'\s+').firstMatch(trimmed);
  if (whitespace == null) {
    return trimmed;
  }
  return trimmed.substring(0, whitespace.start);
}

String _normalizeInfoStringToken(String token) {
  var normalized = token.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  normalized = normalized.replaceFirst(RegExp(r'^\{+'), '');
  normalized = normalized.replaceFirst(RegExp(r'\}+$'), '');
  normalized = normalized.replaceFirst(RegExp(r'^\.+'), '');
  const languageClassPrefix = 'language-';
  if (normalized.startsWith(languageClassPrefix)) {
    normalized = normalized.substring(languageClassPrefix.length);
  }
  return normalized;
}
