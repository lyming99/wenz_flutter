import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:merman/merman.dart';

import '../../core/model/block_node.dart';
import '../../plugins/mermaid_diagram_plugin.dart';

// ---------------------------------------------------------------------------
// Visual constants — kept identical to _CodeBlockRenderer in the editor
// so mermaid blocks blend seamlessly into the document.
// ---------------------------------------------------------------------------
const double _kMermaidBlockRadius = 12.0;
const int _kMermaidBlockBackground = 0xFF1E1E2E;
const int _kMermaidBlockTextColor = 0xFFE6E6F0;
const double _kMermaidBlockFontSize = 13.5;
const double _kMermaidBlockLineHeight = 1.6;
const double _kMermaidBlockPaddingV = 18.0;
const double _kMermaidBlockPaddingH = 20.0;
const double _kMermaidHeaderGap = 14.0;
const double _kMermaidHeaderHeight = 36.0;
const double _kMermaidHeaderPaddingH = 10.0;
const double _kMermaidHeaderEndPadding = 4.0;
const double _kMermaidToolbarButtonSize = 32.0;
const double _kMermaidToolbarIconSize = 18.0;
const int _kMermaidAccentColor = 0xB38A8AFF;
const double _kMermaidPreviewAspectRatio = 16.0 / 9.0;
const double _kMermaidPreviewMinHeight = 180.0;
const double _kMermaidPreviewMaxHeight = 520.0;
const double _kMermaidPreviewFitPadding = 20.0;
const double _kMermaidPreviewMinScale = 0.05;
const double _kMermaidPreviewMaxScale = 5.0;
const double _kMermaidPreviewWheelZoomIntensity = 0.0014;
const double _kMermaidPreviewFallbackWidth = 960.0;
const double _kMermaidPreviewFallbackHeight = 540.0;
const String _kMermaidSvgNumberPattern =
    r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?';
const String _kMermaidSvgPipeline = 'resvg-safe';
const String _kMermaidCanvasColor = '#1E1E2E';
const String _kMermaidSurfaceColor = '#2A2A3F';
const String _kMermaidSurfaceAltColor = '#31314A';
const String _kMermaidTextColor = '#F4F4FA';
const String _kMermaidSubtleTextColor = '#D6D6E8';
const String _kMermaidBorderColor = '#A7A7FF';
const String _kMermaidLineColor = '#D8D8FF';

const Map<String, String> _kMermaidThemeVariables = <String, String>{
  'background': _kMermaidCanvasColor,
  'mainBkg': _kMermaidSurfaceColor,
  'secondBkg': _kMermaidSurfaceAltColor,
  'primaryColor': _kMermaidSurfaceColor,
  'primaryTextColor': _kMermaidTextColor,
  'primaryBorderColor': _kMermaidBorderColor,
  'secondaryColor': '#233A3A',
  'secondaryTextColor': _kMermaidTextColor,
  'secondaryBorderColor': '#65D9D0',
  'tertiaryColor': '#3A3148',
  'tertiaryTextColor': _kMermaidTextColor,
  'tertiaryBorderColor': '#D8B4FE',
  'lineColor': _kMermaidLineColor,
  'textColor': _kMermaidTextColor,
  'nodeTextColor': _kMermaidTextColor,
  'edgeLabelBackground': _kMermaidCanvasColor,
  'clusterBkg': '#252538',
  'clusterBorder': '#7777AA',
  'titleColor': _kMermaidTextColor,
  'fontFamily': 'Inter, system-ui, sans-serif',
};

const String _kMermaidReadableSvgCss = '''
.node rect,
.node circle,
.node ellipse,
.node polygon,
.node path {
  fill: $_kMermaidSurfaceColor;
  stroke: $_kMermaidBorderColor;
}

.edgePaths path,
.flowchart-link,
.edgePath .path,
.marker path,
marker path,
marker polygon {
  stroke: $_kMermaidLineColor;
  fill: $_kMermaidLineColor;
}

.nodeLabel,
.edgeLabel,
.label,
.label text,
.merman-foreignobject-fallback-text {
  color: $_kMermaidTextColor;
  fill: $_kMermaidTextColor;
}

.edgeLabel .labelBkg,
.cluster rect {
  fill: $_kMermaidCanvasColor;
  stroke: #7777AA;
}
''';

// ---------------------------------------------------------------------------
// MermaidCodeBlockWidget
// ---------------------------------------------------------------------------

/// Renders a [CodeBlockNode] with `language == 'mermaid'` as a live diagram.
///
/// The widget offers two modes toggled by the header toolbar:
/// - **Source mode** (default): read-only monospace source with line numbers.
/// - **Preview mode**: SVG rendered through [DiagramSvgSurface] inside an
///   [InteractiveViewer] that supports pan and zoom.
///
/// Rendering is debounced (default 300 ms) and performed on a background
/// isolate via [Isolate.run] so that the UI thread stays responsive. When
/// the isolate or FFI is unavailable the widget falls back to the injected
/// [MermaidRenderer] on the main isolate; if that also fails the error
/// message is displayed with a "View Source" recovery button.
///
/// Editing capability for the diagram source is deferred to a future
/// iteration — the source view is currently read-only.
class MermaidCodeBlockWidget extends StatefulWidget {
  const MermaidCodeBlockWidget({
    super.key,
    required this.block,
    required this.config,
    required this.renderer,
    required this.blockIndex,
  });

  /// The mermaid code block node from the document model.
  final CodeBlockNode block;

  /// Plugin-level configuration (SVG surface, debounce, theme).
  final MermaidDiagramConfig config;

  /// Mermaid engine bridge, replaceable for testing.
  final MermaidRenderer renderer;

  /// Index of this block in the editor's top-level block list.
  final int blockIndex;

  @override
  State<MermaidCodeBlockWidget> createState() => _MermaidCodeBlockWidgetState();
}

class _MermaidCodeBlockWidgetState extends State<MermaidCodeBlockWidget> {
  bool _showSource = true;
  String? _svg;
  String? _error;
  bool _rendering = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scheduleRender();
  }

  @override
  void didUpdateWidget(covariant MermaidCodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.code != oldWidget.block.code ||
        widget.config.defaultTheme != oldWidget.config.defaultTheme) {
      _scheduleRender();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Rendering pipeline
  // -----------------------------------------------------------------------

  /// Schedules (or re-schedules) a debounced render of the current source.
  void _scheduleRender() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.config.debounce, _render);
  }

  /// Entry point: tries the background isolate first, then the main-isolate
  /// renderer as a fallback.
  Future<void> _render() async {
    if (_rendering || !mounted) return;
    final source = widget.block.code;
    if (source.isEmpty) {
      setState(() {
        _svg = null;
        _error = null;
        _rendering = false;
      });
      return;
    }

    setState(() {
      _rendering = true;
      _error = null;
    });

    final optionsJson = _buildMermaidRenderOptionsJson(
      widget.config.defaultTheme,
    );

    try {
      final svg = await Isolate.run(
        () => _isolateRenderSvg(source, optionsJson),
      );
      if (!mounted) return;
      setState(() {
        _svg = svg;
        _rendering = false;
        _error = null;
      });
    } catch (_) {
      // Isolate path failed (e.g. FFI not available on this platform) —
      // fall back to the injected renderer running on the main isolate.
      try {
        final svg = await widget.renderer.renderSvg(
          source,
          optionsJson: optionsJson,
        );
        if (!mounted) return;
        setState(() {
          _svg = svg;
          _rendering = false;
          _error = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _svg = null;
          _rendering = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Runs inside a background isolate: initialises the merman FFI engine and
  /// renders [source] to SVG.
  ///
  /// This must be a **static** method so [Isolate.run] can send it across
  /// isolate boundaries without capturing `this`.
  static String _isolateRenderSvg(String source, String optionsJson) {
    return Merman.open().renderSvg(
      source,
      optionsJson: optionsJson,
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(_kMermaidBlockBackground);
    final textColor = isDark
        ? theme.colorScheme.onSurface
        : const Color(_kMermaidBlockTextColor);
    final accentColor = isDark
        ? theme.colorScheme.primary
        : const Color(_kMermaidAccentColor);

    final codeStyle = TextStyle(
      color: textColor,
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const <String>[
        'Fira Code',
        'Consolas',
        'monospace',
      ],
      fontSize: _kMermaidBlockFontSize,
      height: _kMermaidBlockLineHeight,
    );

    return DecoratedBox(
      key: ValueKey<String>('wenz-richtext-mermaid-block-${widget.block.id}'),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_kMermaidBlockRadius),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant.withAlpha(150)
              : Colors.white.withAlpha(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kMermaidBlockPaddingH,
          vertical: _kMermaidBlockPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MermaidToolbar(
              showSource: _showSource,
              accentColor: accentColor,
              onToggle: () => setState(() => _showSource = !_showSource),
            ),
            const SizedBox(height: _kMermaidHeaderGap),
            _buildContent(codeStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(TextStyle codeStyle) {
    // Loading indicator while the isolate is working.
    if (_rendering) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: SizedBox(
            width: 24.0,
            height: 24.0,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    // Error state: show the error message with a "View Source" recovery.
    if (_error != null && !_showSource) {
      return _MermaidErrorView(
        error: _error!,
        codeStyle: codeStyle,
        onViewSource: () => setState(() {
          _showSource = true;
          _error = null;
        }),
      );
    }

    // Source mode: plain text with line numbers.
    if (_showSource || _svg == null) {
      return _MermaidSourceView(
        source: widget.block.code,
        style: codeStyle,
      );
    }

    // Preview mode: SVG inside an InteractiveViewer.
    return _MermaidPreviewView(
      svg: _svg!,
      config: widget.config,
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Toolbar row mimicking the layout of `_CodeBlockToolbar`.
///
/// Displays a "Mermaid" language tag on the left and a source/preview toggle
/// button on the right.
class _MermaidToolbar extends StatelessWidget {
  const _MermaidToolbar({
    required this.showSource,
    required this.accentColor,
    required this.onToggle,
  });

  final bool showSource;
  final Color accentColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ) ??
        TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: _kMermaidHeaderHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _kMermaidHeaderPaddingH,
            end: _kMermaidHeaderEndPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              // Language tag (non-interactive — no language switching needed)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accentColor.withAlpha(54)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    'Mermaid',
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Spacer(),
              // Toggle button: source ↔ preview
              IconButton(
                key: const ValueKey<String>(
                  'wenz-richtext-mermaid-toggle',
                ),
                tooltip: showSource ? '预览图表' : '查看源码',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: _kMermaidToolbarButtonSize,
                  height: _kMermaidToolbarButtonSize,
                ),
                iconSize: _kMermaidToolbarIconSize,
                style: IconButton.styleFrom(
                  foregroundColor: accentColor,
                  disabledForegroundColor: accentColor.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                ),
                onPressed: onToggle,
                icon: Icon(
                  showSource
                      ? Icons.visibility_outlined
                      : Icons.code,
                  semanticLabel: showSource ? '预览图表' : '查看源码',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only source view with line numbers.
class _MermaidSourceView extends StatelessWidget {
  const _MermaidSourceView({
    required this.source,
    required this.style,
  });

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n');
    final lineDigits = '${lines.length}'.length;
    final lineNumberStyle = style.copyWith(
      color: style.color?.withAlpha(120),
    );

    // Build spans with line number prefix styled distinctly.
    final styledSpans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final num = '${i + 1}'.padLeft(lineDigits);
      styledSpans.add(TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$num  ', style: lineNumberStyle),
          TextSpan(text: lines[i], style: style),
        ],
      ));
      if (i < lines.length - 1) {
        styledSpans.add(const TextSpan(text: '\n'));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: RichText(
        text: TextSpan(
          style: style,
          children: styledSpans,
        ),
      ),
    );
  }
}

/// Preview pane: SVG rendered through [DiagramSvgSurface] in a stable viewport.
///
/// The viewer is wrapped in a [LayoutBuilder] + bounded [SizedBox] because the
/// mermaid block lives inside the editor's loose-fit [Stack], which supplies
/// unbounded height. With `constrained: false` the [InteractiveViewer] builds
/// an internal [OverflowBox] that takes its size from the parent constraint —
/// an infinite height there trips the "given an infinite size" layout
/// assertion. The viewport itself stays at a fixed 16:9 ratio while the SVG
/// content is initially transformed to fit inside it.
class _MermaidPreviewView extends StatefulWidget {
  const _MermaidPreviewView({
    required this.svg,
    required this.config,
  });

  final String svg;
  final MermaidDiagramConfig config;

  @override
  State<_MermaidPreviewView> createState() => _MermaidPreviewViewState();
}

class _MermaidPreviewViewState extends State<_MermaidPreviewView> {
  late final TransformationController _transformationController;
  late final FocusNode _focusNode;
  _MermaidPreviewFitKey? _lastAppliedFitKey;
  _MermaidPreviewFitKey? _pendingFitKey;
  double _currentMinScale = _kMermaidPreviewMinScale;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _focusNode = FocusNode(
      debugLabel: 'wenz-richtext-mermaid-preview',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        widget.config.svgSurface ?? const VectorGraphicsDiagramSurface();
    final contentSize = _parseSvgContentSize(widget.svg);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final availableWidth = math.max(
          1.0,
          constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0,
        );
        final height = _resolveViewportHeight(availableWidth, constraints);
        final viewportSize = Size(availableWidth, height);
        final fitKey = _MermaidPreviewFitKey(
          svg: widget.svg,
          viewportWidth: viewportSize.width,
          viewportHeight: viewportSize.height,
          contentWidth: contentSize.width,
          contentHeight: contentSize.height,
        );
        final minScale = math
            .min(
              _kMermaidPreviewMinScale,
              _fitScaleFor(
                viewportSize: viewportSize,
                contentSize: contentSize,
              ),
            )
            .clamp(0.001, _kMermaidPreviewMaxScale)
            .toDouble();
        _currentMinScale = minScale;
        _scheduleFitToView(fitKey);

        return FocusableActionDetector(
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.grab,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            onEnter: (_) => _focusNode.requestFocus(),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _focusNode.requestFocus(),
              onPointerSignal: _handlePointerSignal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: SizedBox(
                  width: availableWidth,
                  height: height,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    maxScale: _kMermaidPreviewMaxScale,
                    minScale: minScale,
                    constrained: false,
                    child: SizedBox(
                      width: contentSize.width,
                      height: contentSize.height,
                      child: surface.render(
                        context,
                        widget.svg,
                        maxWidth: contentSize.width,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _focusNode.requestFocus();
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _resolvePointerSignal,
    );
  }

  void _resolvePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !mounted) return;
    final delta = event.scrollDelta.dy != 0.0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0.0 || !delta.isFinite) return;

    final renderObject = context.findRenderObject();
    final localPosition = renderObject is RenderBox
        ? renderObject.globalToLocal(event.position)
        : null;
    final fallbackFocalPoint = renderObject is RenderBox
        ? renderObject.size.center(Offset.zero)
        : Offset.zero;
    final focalPoint = localPosition == null ||
            !localPosition.dx.isFinite ||
            !localPosition.dy.isFinite
        ? fallbackFocalPoint
        : localPosition;
    final zoomFactor = math.exp(
      -delta * _kMermaidPreviewWheelZoomIntensity,
    );
    _zoomAt(focalPoint, zoomFactor);
  }

  void _zoomAt(Offset focalPoint, double zoomFactor) {
    if (!zoomFactor.isFinite || zoomFactor <= 0) return;
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (!currentScale.isFinite || currentScale <= 0) return;

    final desiredScale = (currentScale * zoomFactor)
        .clamp(_currentMinScale, _kMermaidPreviewMaxScale)
        .toDouble();
    final effectiveScale = desiredScale / currentScale;
    if (!effectiveScale.isFinite || (effectiveScale - 1.0).abs() < 0.0001) {
      return;
    }

    final nextMatrix = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0.0, 1.0)
      ..scaleByDouble(effectiveScale, effectiveScale, 1.0, 1.0)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0.0, 1.0)
      ..multiply(currentMatrix);
    _transformationController.value = nextMatrix;
  }

  void _scheduleFitToView(_MermaidPreviewFitKey fitKey) {
    if (_lastAppliedFitKey == fitKey || _pendingFitKey == fitKey) {
      return;
    }
    _pendingFitKey = fitKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pendingFitKey = _pendingFitKey;
      _pendingFitKey = null;
      if (pendingFitKey == null || _lastAppliedFitKey == pendingFitKey) {
        return;
      }
      _transformationController.value = _buildFitMatrix(
        viewportSize: Size(
          pendingFitKey.viewportWidth,
          pendingFitKey.viewportHeight,
        ),
        contentSize: Size(
          pendingFitKey.contentWidth,
          pendingFitKey.contentHeight,
        ),
      );
      _lastAppliedFitKey = pendingFitKey;
    });
  }

  static double _resolveViewportHeight(
    double availableWidth,
    BoxConstraints constraints,
  ) {
    final preferredHeight = availableWidth / _kMermaidPreviewAspectRatio;
    final maxHeight = constraints.maxHeight.isFinite
        ? math
            .max(1.0, math.min(_kMermaidPreviewMaxHeight, constraints.maxHeight))
            .toDouble()
        : _kMermaidPreviewMaxHeight;
    final minHeight = math.min(_kMermaidPreviewMinHeight, maxHeight).toDouble();
    return preferredHeight.clamp(minHeight, maxHeight).toDouble();
  }

  static Matrix4 _buildFitMatrix({
    required Size viewportSize,
    required Size contentSize,
  }) {
    final scale = _fitScaleFor(
      viewportSize: viewportSize,
      contentSize: contentSize,
    );
    final dx = (viewportSize.width - contentSize.width * scale) / 2;
    final dy = (viewportSize.height - contentSize.height * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  static double _fitScaleFor({
    required Size viewportSize,
    required Size contentSize,
  }) {
    final paddedWidth = math.max(
      1.0,
      viewportSize.width - _kMermaidPreviewFitPadding * 2,
    );
    final paddedHeight = math.max(
      1.0,
      viewportSize.height - _kMermaidPreviewFitPadding * 2,
    );
    final rawScale = math.min(
      paddedWidth / contentSize.width,
      paddedHeight / contentSize.height,
    );
    return rawScale.isFinite && rawScale > 0
        ? math.min(rawScale, _kMermaidPreviewMaxScale).toDouble()
        : 1.0;
  }

  /// Extracts a stable logical content size from the SVG's `viewBox` or root
  /// `width`/`height` attributes.
  static Size _parseSvgContentSize(String svg) {
    final rootSvgTag =
        RegExp(r'<svg\b[^>]*>', caseSensitive: false).firstMatch(svg)?.group(0);
    final svgHeader = rootSvgTag ?? svg;
    final viewBoxMatch = RegExp(
      '\\bviewBox\\s*=\\s*["\']\\s*$_kMermaidSvgNumberPattern[\\s,]+'
      '$_kMermaidSvgNumberPattern[\\s,]+($_kMermaidSvgNumberPattern)[\\s,]+'
      '($_kMermaidSvgNumberPattern)',
      caseSensitive: false,
    ).firstMatch(svgHeader);
    if (viewBoxMatch != null) {
      final w = double.tryParse(viewBoxMatch.group(1)!);
      final h = double.tryParse(viewBoxMatch.group(2)!);
      if (w != null &&
          h != null &&
          w.isFinite &&
          h.isFinite &&
          w > 0 &&
          h > 0) {
        return Size(w, h);
      }
    }

    final width = _parseSvgLengthAttribute(svgHeader, 'width');
    final height = _parseSvgLengthAttribute(svgHeader, 'height');
    if (width != null && height != null) {
      return Size(width, height);
    }
    return const Size(
      _kMermaidPreviewFallbackWidth,
      _kMermaidPreviewFallbackHeight,
    );
  }

  static double? _parseSvgLengthAttribute(String svgHeader, String name) {
    final match = RegExp(
      '\\b$name\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(svgHeader);
    if (match == null) return null;
    final value = match.group(1)?.trim();
    if (value == null || value.isEmpty || value.contains('%')) return null;
    final numberMatch = RegExp(
      '^\\s*($_kMermaidSvgNumberPattern)',
      caseSensitive: false,
    ).firstMatch(value);
    final parsed = double.tryParse(numberMatch?.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }
}

class _MermaidPreviewFitKey {
  const _MermaidPreviewFitKey({
    required this.svg,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentWidth,
    required this.contentHeight,
  });

  final String svg;
  final double viewportWidth;
  final double viewportHeight;
  final double contentWidth;
  final double contentHeight;

  @override
  bool operator ==(Object other) {
    return other is _MermaidPreviewFitKey &&
        other.svg == svg &&
        other.viewportWidth == viewportWidth &&
        other.viewportHeight == viewportHeight &&
        other.contentWidth == contentWidth &&
        other.contentHeight == contentHeight;
  }

  @override
  int get hashCode => Object.hash(
        svg,
        viewportWidth,
        viewportHeight,
        contentWidth,
        contentHeight,
      );
}

String _buildMermaidRenderOptionsJson(String defaultTheme) {
  final theme = defaultTheme.trim().isEmpty ? 'default' : defaultTheme.trim();
  return jsonEncode(<String, Object?>{
    'version': 1,
    'host_theme': <String, Object?>{
      'preset': 'one-dark',
      'appearance': 'dark',
      'font_family': 'Inter, system-ui, sans-serif',
      'roles': <String, Object?>{
        'canvas': _kMermaidCanvasColor,
        'surface': _kMermaidSurfaceColor,
        'surface_alt': _kMermaidSurfaceAltColor,
        'text': _kMermaidTextColor,
        'subtle_text': _kMermaidSubtleTextColor,
        'border': _kMermaidBorderColor,
        'line': _kMermaidLineColor,
        'success': '#34D399',
      },
      'themeVariables': _kMermaidThemeVariables,
      'output': <String, Object?>{
        'pipeline': _kMermaidSvgPipeline,
        'root_background': 'canvas',
        'css_override_policy': 'strip-existing-important',
      },
    },
    'site_config': <String, Object?>{
      'theme': theme,
      'themeVariables': _kMermaidThemeVariables,
    },
    'svg': <String, Object?>{
      'pipeline': _kMermaidSvgPipeline,
      'scoped_css': _kMermaidReadableSvgCss,
      'css_override_policy': 'strip-existing-important',
      'root_background_color': _kMermaidCanvasColor,
    },
  });
}

/// Error fallback: displays the error message and a button to switch back
/// to source view.
class _MermaidErrorView extends StatelessWidget {
  const _MermaidErrorView({
    required this.error,
    required this.codeStyle,
    required this.onViewSource,
  });

  final String? error;
  final TextStyle codeStyle;
  final VoidCallback onViewSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: errorColor.withAlpha(18),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: errorColor.withAlpha(60)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, color: errorColor, size: 18.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: SelectableText(
                  error ?? '未知错误',
                  style: codeStyle.copyWith(
                    color: errorColor,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),
        Center(
          child: TextButton.icon(
            onPressed: onViewSource,
            icon: const Icon(Icons.code, size: 16.0),
            label: const Text('查看源码'),
          ),
        ),
      ],
    );
  }
}
