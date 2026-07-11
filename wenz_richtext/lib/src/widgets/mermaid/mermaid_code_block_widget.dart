import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/model/block_node.dart';
import '../../mermaid/mermaid.dart';
import '../../plugins/mermaid_diagram_plugin.dart';
import '../editor_tokens.dart';

// ---------------------------------------------------------------------------
// Visual constants — kept identical to _CodeBlockRenderer in the editor
// so mermaid blocks blend seamlessly into the document.
// ---------------------------------------------------------------------------
const double _kMermaidBlockRadius = 12.0;
const int _kMermaidBlockBackground = 0xFF1E1E2E;
const int _kMermaidBlockTextColor = 0xFFE6E6F0;
const double _kMermaidBlockLineHeight = 1.6;
const double _kMermaidBlockPaddingV = 18.0;
const double _kMermaidHeaderGap = 14.0;
const double _kMermaidHeaderHeight = 36.0;
const double _kMermaidHeaderPaddingH = 10.0;
const double _kMermaidHeaderEndPadding = 4.0;
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

// ---------------------------------------------------------------------------
// MermaidCodeBlockWidget
// ---------------------------------------------------------------------------

/// Renders a [CodeBlockNode] with `language == 'mermaid'` as a live diagram.
///
/// The widget offers two modes toggled by the header toolbar:
/// - **Source mode** (default): editor-provided code block source surface.
/// - **Preview mode**: pure Flutter Mermaid layout and CustomPaint output
///   inside an [InteractiveViewer] that supports pan and zoom.
///
/// Rendering is debounced (default 300 ms) and parsed on the UI isolate using
/// the internal pure Dart Mermaid parser/layout/painter stack. Unsupported or
/// invalid diagrams are shown as explicit error states with a source recovery
/// button.
class MermaidCodeBlockWidget extends StatefulWidget {
  const MermaidCodeBlockWidget({
    super.key,
    required this.block,
    required this.config,
    required this.renderer,
    required this.blockIndex,
    this.sourceBuilder,
  });

  /// The mermaid code block node from the document model.
  final CodeBlockNode block;

  /// Plugin-level configuration (debounce and theme are used by this widget).
  final MermaidDiagramConfig config;

  /// Retained for plugin API compatibility; the pure Flutter preview path does
  /// not call the SVG renderer.
  final MermaidRenderer renderer;

  /// Index of this block in the editor's top-level block list.
  final int blockIndex;

  /// Editable source surface supplied by the code block renderer that the
  /// Mermaid plugin wrapped.
  ///
  /// When omitted, the widget keeps its standalone read-only source fallback so
  /// direct usages outside [MermaidDiagramPlugin] remain source-compatible.
  final WidgetBuilder? sourceBuilder;

  @override
  State<MermaidCodeBlockWidget> createState() => _MermaidCodeBlockWidgetState();
}

/// Source-mode controls exposed by [MermaidCodeBlockWidget] to the ordinary
/// code block toolbar while it renders the editable Mermaid source surface.
class MermaidCodeBlockSourceControls extends InheritedWidget {
  const MermaidCodeBlockSourceControls({
    super.key,
    required this.onPreview,
    required super.child,
  });

  final VoidCallback onPreview;

  static MermaidCodeBlockSourceControls? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MermaidCodeBlockSourceControls>();
  }

  @override
  bool updateShouldNotify(covariant MermaidCodeBlockSourceControls oldWidget) {
    return oldWidget.onPreview != onPreview;
  }
}

class _MermaidCodeBlockWidgetState extends State<MermaidCodeBlockWidget> {
  bool _showSource = true;
  _MermaidPreviewData? _preview;
  String? _previewSource;
  String? _previewTheme;
  String? _error;
  String? _errorSource;
  String? _errorTheme;
  bool _rendering = false;
  bool _renderQueued = false;
  int _renderRequestId = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scheduleRender(notify: false);
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

  /// Schedules (or re-schedules) a debounced parse/layout of the source.
  void _scheduleRender({bool notify = true}) {
    _debounceTimer?.cancel();
    _renderRequestId++;
    final source = widget.block.code;

    void updateQueuedState() {
      if (_isBlankSource(source)) {
        _preview = null;
        _previewSource = null;
        _previewTheme = null;
        _error = null;
        _errorSource = null;
        _errorTheme = null;
        _renderQueued = false;
        _rendering = false;
        return;
      }
      _preview = null;
      _previewSource = null;
      _previewTheme = null;
      _error = null;
      _errorSource = null;
      _errorTheme = null;
      _renderQueued = true;
    }

    if (notify && mounted) {
      setState(updateQueuedState);
    } else {
      updateQueuedState();
    }

    if (_isBlankSource(source)) {
      return;
    }
    _debounceTimer = Timer(widget.config.debounce, _render);
  }

  /// Parses and lays out the current source using the pure Dart Mermaid core.
  void _render() {
    if (!mounted) return;
    if (_rendering) {
      if (!_renderQueued) {
        setState(() => _renderQueued = true);
      }
      return;
    }

    final requestId = _renderRequestId;
    final source = widget.block.code;
    final theme = widget.config.defaultTheme;
    if (_isBlankSource(source)) {
      setState(() {
        _preview = null;
        _previewSource = null;
        _previewTheme = null;
        _error = null;
        _errorSource = null;
        _errorTheme = null;
        _renderQueued = false;
        _rendering = false;
      });
      return;
    }

    setState(() {
      _rendering = true;
      _renderQueued = false;
      _error = null;
    });

    try {
      final preview = _buildPreviewData(source, theme);
      if (!mounted) return;
      if (!_isCurrentRenderRequest(requestId, source, theme)) {
        _finishStaleRender();
        return;
      }
      setState(() {
        _preview = preview;
        _previewSource = source;
        _previewTheme = theme;
        _rendering = false;
        _renderQueued = false;
        _error = null;
        _errorSource = null;
        _errorTheme = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_isCurrentRenderRequest(requestId, source, theme)) {
        _finishStaleRender();
        return;
      }
      setState(() {
        _preview = null;
        _previewSource = null;
        _previewTheme = null;
        _rendering = false;
        _renderQueued = false;
        _error = _stringifyRenderError(e);
        _errorSource = source;
        _errorTheme = theme;
      });
    }
  }

  bool get _hasCurrentPreview =>
      _preview != null &&
      _previewSource == widget.block.code &&
      _previewTheme == widget.config.defaultTheme;

  bool get _hasCurrentError =>
      _error != null &&
      _errorSource == widget.block.code &&
      _errorTheme == widget.config.defaultTheme;

  bool get _isPreviewPending =>
      !_isBlankSource(widget.block.code) && (_renderQueued || _rendering);

  bool _isCurrentRenderRequest(int requestId, String source, String theme) {
    return requestId == _renderRequestId &&
        source == widget.block.code &&
        theme == widget.config.defaultTheme;
  }

  void _finishStaleRender() {
    setState(() {
      _rendering = false;
    });
    _scheduleRender();
  }

  static bool _isBlankSource(String source) => source.trim().isEmpty;

  static _MermaidPreviewData _buildPreviewData(String source, String theme) {
    const parser = MermaidParser();
    final result = parser.parseWithData(source);
    if (result == null) {
      throw FormatException(parser.describeParseFailure(source));
    }

    final style = _styleForTheme(theme);
    final contentSize = _computeContentSize(
      result,
      style,
      const Size(
        _kMermaidPreviewFallbackWidth,
        _kMermaidPreviewFallbackHeight,
      ),
    );
    if (contentSize.width <= 0 ||
        contentSize.height <= 0 ||
        !contentSize.width.isFinite ||
        !contentSize.height.isFinite) {
      throw const FormatException('Mermaid 图表布局结果无效，无法生成预览。');
    }

    return _MermaidPreviewData(
      source: source,
      theme: theme,
      style: style,
      contentSize: contentSize,
    );
  }

  static Size _computeContentSize(
    MermaidParseResult result,
    MermaidStyle style,
    Size availableSize,
  ) {
    final diagram = result.diagram;
    switch (diagram.type) {
      case DiagramType.pieChart:
        final data = result.pieChartData;
        if (data == null) break;
        return PieChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.ganttChart:
        final data = result.ganttChartData;
        if (data == null) break;
        return GanttChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.timeline:
        final data = result.timelineChartData;
        if (data == null) break;
        return TimelineChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.kanban:
        final data = result.kanbanChartData;
        if (data == null) break;
        return KanbanChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.radar:
        final data = result.radarChartData;
        if (data == null) break;
        return RadarChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.xyChart:
        final data = result.xyChartData;
        if (data == null) break;
        return XYChartLayout().computeLayout(data, style, availableSize);
      case DiagramType.flowchart:
        return DagreLayout().computeLayout(diagram, style, availableSize);
      case DiagramType.sequence:
        return SequenceLayout().computeLayout(diagram, style, availableSize);
      case DiagramType.mindmap:
        return MindmapLayout().computeLayout(diagram, style, availableSize);
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
      case DiagramType.unknown:
        break;
    }
    throw const FormatException('Mermaid 图表数据不完整，无法生成预览。');
  }

  static MermaidStyle _styleForTheme(String defaultTheme) {
    switch (defaultTheme.trim().toLowerCase()) {
      case 'forest':
        return MermaidStyle.forest();
      case 'neutral':
        return MermaidStyle.neutral();
      case 'light':
        return const MermaidStyle();
      case 'dark':
      case 'base':
      case 'default':
      case '':
      default:
        return MermaidStyle.dark();
    }
  }

  static String _stringifyRenderError(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    final message = error.toString().trim();
    return message.isEmpty ? 'Mermaid 预览生成失败。' : message;
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sourceBuilder = widget.sourceBuilder;
    if (_showSource && sourceBuilder != null) {
      return MermaidCodeBlockSourceControls(
        onPreview: _showPreview,
        child: Builder(builder: sourceBuilder),
      );
    }

    final theme = Theme.of(context);
    final tokens = EditorTokens.resolve(context);
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
      fontSize: tokens.codeBlockFontSize,
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
        padding: EdgeInsets.symmetric(
          horizontal: tokens.codeBlockPaddingHorizontal,
          vertical: _kMermaidBlockPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MermaidToolbar(
              showSource: _showSource,
              accentColor: accentColor,
              onToggle: _toggleContentMode,
            ),
            const SizedBox(height: _kMermaidHeaderGap),
            _buildContent(context, codeStyle),
          ],
        ),
      ),
    );
  }

  void _toggleContentMode() {
    if (_showSource) {
      _showPreview();
    } else {
      _showSourceMode();
    }
  }

  void _showPreview() {
    if (!_showSource) {
      return;
    }
    setState(() => _showSource = false);
    if (!_hasCurrentPreview &&
        !_isPreviewPending &&
        !_hasCurrentError &&
        !_isBlankSource(widget.block.code)) {
      _scheduleRender();
    }
  }

  void _showSourceMode() {
    if (_showSource) {
      return;
    }
    setState(() => _showSource = true);
  }

  Widget _buildContent(BuildContext context, TextStyle codeStyle) {
    if (_showSource) {
      return _MermaidSourceView(source: widget.block.code, style: codeStyle);
    }

    if (_isBlankSource(widget.block.code)) {
      return _MermaidStatusView(
        icon: Icons.account_tree_outlined,
        title: 'Mermaid 源码为空',
        message: '添加 Mermaid DSL 后即可生成预览。',
        codeStyle: codeStyle,
        onViewSource: () => setState(() => _showSource = true),
      );
    }

    if (_isPreviewPending || (!_hasCurrentPreview && !_hasCurrentError)) {
      return _MermaidStatusView.loading(
        title: _rendering ? '正在解析 Mermaid 图表' : '正在准备 Mermaid 预览',
        message: '解析完成后会自动切换到图表预览。',
        codeStyle: codeStyle,
        onViewSource: () => setState(() => _showSource = true),
      );
    }

    if (_hasCurrentError) {
      return _MermaidErrorView(
        error: _error!,
        codeStyle: codeStyle,
        onViewSource: () => setState(() {
          _showSource = true;
        }),
      );
    }

    return _MermaidPreviewView(preview: _preview!);
  }
}

class _MermaidPreviewData {
  const _MermaidPreviewData({
    required this.source,
    required this.theme,
    required this.style,
    required this.contentSize,
  });

  final String source;
  final String theme;
  final MermaidStyle style;
  final Size contentSize;
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
    final tokens = EditorTokens.resolve(context);
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
              IconButton(
                key: const ValueKey<String>(
                  'wenz-richtext-mermaid-toggle',
                ),
                tooltip: showSource ? '预览图表' : '查看源码',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: tokens.minimalToolbarButtonSize,
                  height: tokens.minimalToolbarButtonSize,
                ),
                iconSize: tokens.minimalToolbarIconSize,
                style: IconButton.styleFrom(
                  foregroundColor: accentColor,
                  disabledForegroundColor: accentColor.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                ),
                onPressed: onToggle,
                icon: Icon(
                  showSource ? Icons.visibility_outlined : Icons.code,
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

/// Preview pane: pure Flutter Mermaid CustomPaint in a stable viewport.
///
/// The viewer is wrapped in a [LayoutBuilder] + bounded [SizedBox] because the
/// mermaid block lives inside the editor's loose-fit [Stack], which can supply
/// unbounded height. The viewport stays at a fixed 16:9 ratio while the diagram
/// content is initially transformed to fit inside it.
class _MermaidPreviewView extends StatefulWidget {
  const _MermaidPreviewView({required this.preview});

  final _MermaidPreviewData preview;

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
  void didUpdateWidget(covariant _MermaidPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.source != widget.preview.source ||
        oldWidget.preview.theme != widget.preview.theme ||
        oldWidget.preview.contentSize != widget.preview.contentSize) {
      _lastAppliedFitKey = null;
      _pendingFitKey = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentSize = widget.preview.contentSize;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final availableWidth = math.max(
          1.0,
          constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0,
        );
        final height = _resolveViewportHeight(availableWidth, constraints);
        final viewportSize = Size(availableWidth, height);
        final fitKey = _MermaidPreviewFitKey(
          source: widget.preview.source,
          theme: widget.preview.theme,
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
                  child: ColoredBox(
                    color: Color(widget.preview.style.backgroundColor),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      maxScale: _kMermaidPreviewMaxScale,
                      minScale: minScale,
                      constrained: false,
                      child: SizedBox(
                        width: contentSize.width,
                        height: contentSize.height,
                        child: MermaidDiagram(
                          code: widget.preview.source,
                          style: widget.preview.style,
                          width: contentSize.width,
                          height: contentSize.height,
                          enableResponsive: false,
                          errorBuilder: _buildInlineError,
                        ),
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

  Widget _buildInlineError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ) ??
              TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
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
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(effectiveScale, effectiveScale)
      ..translate(-focalPoint.dx, -focalPoint.dy)
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
      ..translate(dx, dy)
      ..scale(scale, scale);
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
}

class _MermaidPreviewFitKey {
  const _MermaidPreviewFitKey({
    required this.source,
    required this.theme,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentWidth,
    required this.contentHeight,
  });

  final String source;
  final String theme;
  final double viewportWidth;
  final double viewportHeight;
  final double contentWidth;
  final double contentHeight;

  @override
  bool operator ==(Object other) {
    return other is _MermaidPreviewFitKey &&
        other.source == source &&
        other.theme == theme &&
        other.viewportWidth == viewportWidth &&
        other.viewportHeight == viewportHeight &&
        other.contentWidth == contentWidth &&
        other.contentHeight == contentHeight;
  }

  @override
  int get hashCode => Object.hash(
        source,
        theme,
        viewportWidth,
        viewportHeight,
        contentWidth,
        contentHeight,
      );
}

/// Preview status fallback for loading and empty-source states.
class _MermaidStatusView extends StatelessWidget {
  const _MermaidStatusView({
    required this.icon,
    required this.title,
    required this.message,
    required this.codeStyle,
    required this.onViewSource,
  }) : loading = false;

  const _MermaidStatusView.loading({
    required this.title,
    required this.message,
    required this.codeStyle,
    required this.onViewSource,
  })  : icon = null,
        loading = true;

  final IconData? icon;
  final bool loading;
  final String title;
  final String message;
  final TextStyle codeStyle;
  final VoidCallback onViewSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final foregroundColor = codeStyle.color ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loading)
            SizedBox(
              width: 24.0,
              height: 24.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: accentColor,
              ),
            )
          else
            Icon(icon, color: accentColor, size: 24.0),
          const SizedBox(height: 12.0),
          Text(
            title,
            style: codeStyle.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6.0),
          Text(
            message,
            style: codeStyle.copyWith(
              color: foregroundColor.withAlpha(170),
              fontSize: 12.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12.0),
          TextButton.icon(
            onPressed: onViewSource,
            icon: const Icon(Icons.code, size: 16.0),
            label: const Text('查看源码'),
          ),
        ],
      ),
    );
  }
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
