// Matrix4's replacement helpers are unavailable on the Flutter 3.22 floor.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/model/block_node.dart';
import '../../mermaid/mermaid.dart';
import '../../plugins/mermaid_diagram_plugin.dart';
import '../editor_tokens.dart';

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

/// Source/preview wrapper for one Mermaid code block.
///
/// View state and request debouncing stay here; parser/layout work is delegated
/// to the editor-scoped [NativeMermaidRenderService].
class MermaidCodeBlockWidget extends StatefulWidget {
  const MermaidCodeBlockWidget({
    super.key,
    required this.block,
    required this.config,
    required this.renderer,
    required this.blockIndex,
    this.renderService,
    this.sourceBuilder,
  });

  final CodeBlockNode block;
  final MermaidDiagramConfig config;

  /// Retained for source compatibility. The pure Flutter path never calls it.
  final MermaidRenderer renderer;

  final int blockIndex;

  /// Shared service supplied by [MermaidDiagramPlugin]. Standalone usages get
  /// a widget-owned service that is disposed with this widget.
  final NativeMermaidRenderService? renderService;

  final WidgetBuilder? sourceBuilder;

  @override
  State<MermaidCodeBlockWidget> createState() => _MermaidCodeBlockWidgetState();
}

/// Controls exposed to the ordinary editable code-block toolbar.
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
  bool _rendering = false;
  MermaidRenderResult? _result;
  MermaidRenderFailure? _failure;
  MermaidRenderTheme? _theme;
  Timer? _debounceTimer;
  String? _activeRequestId;
  int _generation = 0;
  Size _viewport = const Size(
    _kMermaidPreviewFallbackWidth,
    _kMermaidPreviewFallbackHeight,
  );
  String _viewportBucket = mermaidViewportBucket(
    const Size(
      _kMermaidPreviewFallbackWidth,
      _kMermaidPreviewFallbackHeight,
    ),
  );
  String? _pendingViewportBucket;

  late NativeMermaidRenderService _renderService;
  late bool _ownsRenderService;

  @override
  void initState() {
    super.initState();
    _initializeRenderService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResolvedTheme(notify: false);
  }

  @override
  void didUpdateWidget(covariant MermaidCodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final serviceChanged = oldWidget.renderService != widget.renderService ||
        (widget.renderService == null &&
            oldWidget.config.diagnostics != widget.config.diagnostics);
    if (serviceChanged) {
      _cancelActiveRequest();
      if (_ownsRenderService) {
        unawaited(_renderService.dispose());
      }
      _initializeRenderService();
    }

    final themeChanged =
        oldWidget.config.defaultTheme != widget.config.defaultTheme;
    if (themeChanged) {
      _updateResolvedTheme(notify: false);
    }
    if (serviceChanged ||
        themeChanged ||
        oldWidget.block.code != widget.block.code ||
        !_sameLimits(oldWidget.config.limits, widget.config.limits)) {
      _scheduleRender();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelActiveRequest();
    if (_ownsRenderService) {
      unawaited(_renderService.dispose());
    }
    super.dispose();
  }

  void _initializeRenderService() {
    _ownsRenderService = widget.renderService == null;
    _renderService = widget.renderService ??
        DefaultNativeMermaidRenderService(
          diagnostics: widget.config.diagnostics,
        );
  }

  void _updateResolvedTheme({required bool notify}) {
    final next = _resolveRenderTheme(context, widget.config.defaultTheme);
    final previous = _theme;
    if (previous?.key == next.key) return;
    if (previous != null) {
      _renderService.invalidateTheme(previous.key);
    }
    _theme = next;
    _scheduleRender(notify: notify);
  }

  void _scheduleRender({bool notify = true, bool immediate = false}) {
    _debounceTimer?.cancel();
    _cancelActiveRequest();
    final generation = ++_generation;

    void resetOutcome() {
      _result = null;
      _failure = null;
      _rendering = !_isBlankSource(widget.block.code);
    }

    if (notify && mounted) {
      setState(resetOutcome);
    } else {
      resetOutcome();
    }

    if (_isBlankSource(widget.block.code) || _theme == null) {
      _rendering = false;
      return;
    }
    if (immediate) {
      scheduleMicrotask(() => _render(generation));
    } else {
      _debounceTimer = Timer(
        widget.config.debounce,
        () => _render(generation),
      );
    }
  }

  Future<void> _render(int generation) async {
    if (!mounted || generation != _generation || _theme == null) return;
    final source = widget.block.code;
    if (_isBlankSource(source)) return;
    final digest = mermaidSourceDigest(source);
    final requestId = '${widget.block.id}:$generation';
    final theme = _theme!;
    final viewport = _viewport;
    final viewportBucket = mermaidViewportBucket(viewport);
    _activeRequestId = requestId;

    MermaidRenderOutcome outcome;
    try {
      outcome = await _renderService.render(
        MermaidRenderRequest(
          source: source,
          sourceDigest: digest,
          theme: theme,
          viewport: viewport,
          limits: widget.config.limits,
          requestId: requestId,
        ),
      );
    } catch (_) {
      outcome = MermaidRenderFailure(
        requestId: requestId,
        sourceDigest: digest,
        code: MermaidRenderErrorCode.internal,
        diagnostic: 'Mermaid 预览服务发生内部错误。',
        metrics: null,
      );
    }

    if (!mounted ||
        generation != _generation ||
        _activeRequestId != requestId ||
        outcome.requestId != requestId ||
        outcome.sourceDigest != digest ||
        mermaidSourceDigest(widget.block.code) != digest ||
        _theme?.key != theme.key ||
        _viewportBucket != viewportBucket) {
      return;
    }
    setState(() {
      _activeRequestId = null;
      _rendering = false;
      if (outcome is MermaidRenderResult) {
        _result = outcome;
        _failure = null;
      } else {
        _result = null;
        _failure = outcome as MermaidRenderFailure;
      }
    });
  }

  void _cancelActiveRequest() {
    final requestId = _activeRequestId;
    if (requestId != null) {
      _renderService.cancel(requestId);
      _activeRequestId = null;
    }
  }

  void _queueViewportUpdate(Size next) {
    final bucket = mermaidViewportBucket(next);
    if (bucket == _viewportBucket || bucket == _pendingViewportBucket) return;
    _pendingViewportBucket = bucket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingViewportBucket != bucket) return;
      _pendingViewportBucket = null;
      _viewport = next;
      _viewportBucket = bucket;
      _scheduleRender();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? math.max(1.0, constraints.maxWidth)
            : _kMermaidPreviewFallbackWidth;
        final height = _resolveViewportHeight(width, constraints);
        _queueViewportUpdate(Size(width, height));
        return _buildBlock(context);
      },
    );
  }

  Widget _buildBlock(BuildContext context) {
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
    final accentColor =
        isDark ? theme.colorScheme.primary : const Color(_kMermaidAccentColor);
    final codeStyle = TextStyle(
      color: textColor,
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const <String>['Fira Code', 'Consolas', 'monospace'],
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
            _buildContent(codeStyle),
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
    if (!_showSource) return;
    setState(() => _showSource = false);
    if (_result == null && !_isBlankSource(widget.block.code)) {
      // An explicit user action bypasses the remaining debounce interval.
      _scheduleRender(immediate: true);
    }
  }

  void _showSourceMode() {
    if (_showSource) return;
    setState(() => _showSource = true);
  }

  Widget _buildContent(TextStyle codeStyle) {
    if (_showSource) {
      return _MermaidSourceView(source: widget.block.code, style: codeStyle);
    }
    if (_isBlankSource(widget.block.code)) {
      return _MermaidStatusView(
        icon: Icons.account_tree_outlined,
        title: 'Mermaid 源码为空',
        message: '添加 Mermaid DSL 后即可生成预览。',
        codeStyle: codeStyle,
        onViewSource: _showSourceMode,
      );
    }
    if (_rendering || (_result == null && _failure == null)) {
      return _MermaidStatusView.loading(
        title: '正在生成 Mermaid 预览',
        message: '解析和布局完成后会自动显示图表。',
        codeStyle: codeStyle,
        onViewSource: _showSourceMode,
      );
    }
    if (_failure != null) {
      return _MermaidErrorView(
        failure: _failure!,
        codeStyle: codeStyle,
        onViewSource: _showSourceMode,
      );
    }
    return _MermaidPreviewView(
      result: _result!,
      diagnostics: widget.config.diagnostics,
      onViewSource: _showSourceMode,
    );
  }
}

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
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accentColor.withAlpha(54)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Mermaid', style: labelStyle),
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey<String>('wenz-richtext-mermaid-toggle'),
                tooltip: showSource ? '预览图表' : '查看源码',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: tokens.minimalToolbarButtonSize,
                  height: tokens.minimalToolbarButtonSize,
                ),
                iconSize: tokens.minimalToolbarIconSize,
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

class _MermaidSourceView extends StatelessWidget {
  const _MermaidSourceView({required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = source.split('\n');
    final digits = '${lines.length}'.length;
    final spans = <InlineSpan>[];
    for (var index = 0; index < lines.length; index++) {
      spans.add(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '${'${index + 1}'.padLeft(digits)}  ',
              style: style.copyWith(color: style.color?.withAlpha(120)),
            ),
            TextSpan(text: lines[index], style: style),
          ],
        ),
      );
      if (index < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: RichText(text: TextSpan(style: style, children: spans)),
    );
  }
}

class _MermaidPreviewView extends StatefulWidget {
  const _MermaidPreviewView({
    required this.result,
    required this.diagnostics,
    required this.onViewSource,
  });

  final MermaidRenderResult result;
  final MermaidRenderDiagnostics? diagnostics;
  final VoidCallback onViewSource;

  @override
  State<_MermaidPreviewView> createState() => _MermaidPreviewViewState();
}

class _MermaidPreviewViewState extends State<_MermaidPreviewView> {
  late final TransformationController _transformationController;
  late final FocusNode _focusNode;
  _MermaidPreviewFitKey? _lastAppliedFitKey;
  _MermaidPreviewFitKey? _pendingFitKey;
  double _currentMinScale = _kMermaidPreviewMinScale;
  Size _lastViewportSize = const Size(1, 1);

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _focusNode = FocusNode(debugLabel: 'wenz-richtext-mermaid-preview');
  }

  @override
  void didUpdateWidget(covariant _MermaidPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.cacheKey != widget.result.cacheKey) {
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
    final contentSize = widget.result.contentSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          1.0,
          constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0,
        );
        final height = _resolveViewportHeight(availableWidth, constraints);
        final viewportSize = Size(availableWidth, height);
        _lastViewportSize = viewportSize;
        final fitKey = _MermaidPreviewFitKey(
          cacheKey: widget.result.cacheKey,
          viewportSize: viewportSize,
          contentSize: contentSize,
        );
        _currentMinScale = math
            .min(
              _kMermaidPreviewMinScale,
              _fitScaleFor(
                  viewportSize: viewportSize, contentSize: contentSize),
            )
            .clamp(0.001, _kMermaidPreviewMaxScale)
            .toDouble();
        _scheduleFitToView(fitKey);

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.equal, control: true):
                _zoomIn,
            const SingleActivator(LogicalKeyboardKey.equal, meta: true):
                _zoomIn,
            const SingleActivator(LogicalKeyboardKey.minus, control: true):
                _zoomOut,
            const SingleActivator(LogicalKeyboardKey.minus, meta: true):
                _zoomOut,
            const SingleActivator(LogicalKeyboardKey.digit0, control: true):
                _reset,
            const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
                _reset,
            const SingleActivator(LogicalKeyboardKey.keyF): _fitToView,
            const SingleActivator(LogicalKeyboardKey.escape):
                widget.onViewSource,
          },
          child: FocusableActionDetector(
            focusNode: _focusNode,
            mouseCursor: SystemMouseCursors.grab,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _focusNode.requestFocus(),
              onPointerSignal: _handlePointerSignal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _PreviewToolbar(
                    onFit: _fitToView,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onReset: _reset,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: availableWidth,
                      height: height,
                      child: ColoredBox(
                        color: Color(widget.result.style.backgroundColor),
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          maxScale: _kMermaidPreviewMaxScale,
                          minScale: _currentMinScale,
                          constrained: false,
                          scaleEnabled: false,
                          child: MermaidDiagram(
                            result: widget.result,
                            diagnostics: widget.diagnostics,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _resolvePointerSignal,
    );
  }

  void _resolvePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !mounted) return;
    final delta =
        event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta == 0 || !delta.isFinite) return;
    final renderObject = context.findRenderObject();
    final focalPoint = renderObject is RenderBox
        ? renderObject.globalToLocal(event.position)
        : _lastViewportSize.center(Offset.zero);
    _zoomAt(
      focalPoint,
      math.exp(-delta * _kMermaidPreviewWheelZoomIntensity),
    );
  }

  void _zoomIn() => _zoomAt(_lastViewportSize.center(Offset.zero), 1.2);
  void _zoomOut() => _zoomAt(_lastViewportSize.center(Offset.zero), 1 / 1.2);

  void _zoomAt(Offset focalPoint, double zoomFactor) {
    if (!zoomFactor.isFinite || zoomFactor <= 0) return;
    final current = _transformationController.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (!currentScale.isFinite || currentScale <= 0) return;
    final desired = (currentScale * zoomFactor)
        .clamp(_currentMinScale, _kMermaidPreviewMaxScale)
        .toDouble();
    final effective = desired / currentScale;
    if (!effective.isFinite || (effective - 1).abs() < 0.0001) return;
    _transformationController.value = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(effective, effective)
      ..translate(-focalPoint.dx, -focalPoint.dy)
      ..multiply(current);
  }

  void _fitToView() {
    _transformationController.value = _buildFitMatrix(
      viewportSize: _lastViewportSize,
      contentSize: widget.result.contentSize,
    );
  }

  void _reset() {
    _transformationController.value = Matrix4.identity();
  }

  void _scheduleFitToView(_MermaidPreviewFitKey fitKey) {
    if (_lastAppliedFitKey == fitKey || _pendingFitKey == fitKey) return;
    _pendingFitKey = fitKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = _pendingFitKey;
      _pendingFitKey = null;
      if (pending == null || _lastAppliedFitKey == pending) return;
      _transformationController.value = _buildFitMatrix(
        viewportSize: pending.viewportSize,
        contentSize: pending.contentSize,
      );
      _lastAppliedFitKey = pending;
    });
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Wrap(
          spacing: 2,
          children: <Widget>[
            _button(
              key: 'wenz-richtext-mermaid-fit',
              tooltip: '适配视口 (F)',
              icon: Icons.fit_screen_outlined,
              onPressed: onFit,
            ),
            _button(
              key: 'wenz-richtext-mermaid-zoom-in',
              tooltip: '放大',
              icon: Icons.zoom_in,
              onPressed: onZoomIn,
            ),
            _button(
              key: 'wenz-richtext-mermaid-zoom-out',
              tooltip: '缩小',
              icon: Icons.zoom_out,
              onPressed: onZoomOut,
            ),
            _button(
              key: 'wenz-richtext-mermaid-reset',
              tooltip: '重置缩放',
              icon: Icons.restart_alt,
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: ValueKey<String>(key),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      onPressed: onPressed,
      icon: Icon(icon, semanticLabel: tooltip),
    );
  }
}

class _MermaidPreviewFitKey {
  const _MermaidPreviewFitKey({
    required this.cacheKey,
    required this.viewportSize,
    required this.contentSize,
  });

  final String cacheKey;
  final Size viewportSize;
  final Size contentSize;

  @override
  bool operator ==(Object other) {
    return other is _MermaidPreviewFitKey &&
        other.cacheKey == cacheKey &&
        other.viewportSize == viewportSize &&
        other.contentSize == contentSize;
  }

  @override
  int get hashCode => Object.hash(cacheKey, viewportSize, contentSize);
}

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
    final foreground = codeStyle.color ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: codeStyle.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: codeStyle.copyWith(
              color: foreground.withAlpha(180),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onViewSource,
            icon: const Icon(Icons.code, size: 16),
            label: const Text('查看源码'),
          ),
        ],
      ),
    );
  }
}

class _MermaidErrorView extends StatelessWidget {
  const _MermaidErrorView({
    required this.failure,
    required this.codeStyle,
    required this.onViewSource,
  });

  final MermaidRenderFailure failure;
  final TextStyle codeStyle;
  final VoidCallback onViewSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final title = switch (failure.code) {
      MermaidRenderErrorCode.sourceTooLong ||
      MermaidRenderErrorCode.tooManyNodes ||
      MermaidRenderErrorCode.tooManyEdges ||
      MermaidRenderErrorCode.layoutIterationLimit =>
        'Mermaid 输入超过资源限制',
      MermaidRenderErrorCode.timeout => 'Mermaid 预览超时',
      MermaidRenderErrorCode.cancelled => 'Mermaid 预览已取消',
      MermaidRenderErrorCode.unsupportedType => '不支持的 Mermaid 图表类型',
      MermaidRenderErrorCode.syntax => 'Mermaid 语法错误',
      MermaidRenderErrorCode.emptySource => 'Mermaid 源码为空',
      MermaidRenderErrorCode.invalidLayout => 'Mermaid 布局结果无效',
      MermaidRenderErrorCode.internal => 'Mermaid 预览失败',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: errorColor.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorColor.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, color: errorColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: codeStyle.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      failure.diagnostic,
                      style: codeStyle.copyWith(
                        color: errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onViewSource,
            icon: const Icon(Icons.code, size: 16),
            label: const Text('查看源码'),
          ),
        ],
      ),
    );
  }
}

MermaidRenderTheme _resolveRenderTheme(
  BuildContext context,
  String configuredTheme,
) {
  final materialTheme = Theme.of(context);
  final mediaQuery = MediaQuery.maybeOf(context);
  final normalized = configuredTheme.trim().toLowerCase();
  final textScale = mediaQuery == null
      ? 1.0
      : (mediaQuery.textScaler.scale(14) / 14).clamp(1.0, 2.0).toDouble();
  final highContrast = mediaQuery?.highContrast ?? false;
  final resolvedName = normalized.isEmpty || normalized == 'auto'
      ? (materialTheme.brightness == Brightness.dark ? 'dark' : 'light')
      : normalized;

  MermaidStyle base;
  if (normalized.isEmpty || normalized == 'auto') {
    final colors = materialTheme.colorScheme;
    base = MermaidStyle(
      backgroundColor: colors.surface.toARGB32(),
      defaultNodeStyle: NodeStyle(
        fillColor: colors.surfaceContainerHighest.toARGB32(),
        strokeColor: colors.primary.toARGB32(),
        textColor: colors.onSurface.toARGB32(),
        strokeWidth: highContrast ? 2.2 : 1.2,
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: colors.outline.toARGB32(),
        strokeWidth: highContrast ? 2.4 : 1.5,
        labelColor: colors.onSurface.toARGB32(),
        labelBackgroundColor: colors.surface.toARGB32(),
      ),
      fontFamily: materialTheme.textTheme.bodyMedium?.fontFamily,
      themeMode: materialTheme.brightness == Brightness.dark
          ? MermaidThemeMode.dark
          : MermaidThemeMode.light,
    );
  } else {
    base = switch (resolvedName) {
      'dark' || 'base' => MermaidStyle.dark(),
      'forest' => MermaidStyle.forest(),
      'neutral' => MermaidStyle.neutral(),
      _ => const MermaidStyle(),
    };
  }
  final scaled = base.copyWith(
    defaultNodeStyle: base.defaultNodeStyle.copyWith(
      fontSize: base.defaultNodeStyle.fontSize * textScale,
      strokeWidth: highContrast
          ? math.max(2, base.defaultNodeStyle.strokeWidth)
          : base.defaultNodeStyle.strokeWidth,
    ),
    defaultEdgeStyle: base.defaultEdgeStyle.copyWith(
      labelFontSize: base.defaultEdgeStyle.labelFontSize * textScale,
      strokeWidth: highContrast
          ? math.max(2, base.defaultEdgeStyle.strokeWidth)
          : base.defaultEdgeStyle.strokeWidth,
    ),
  );
  final key = '$resolvedName-hc${highContrast ? 1 : 0}'
      '-ts${textScale.toStringAsFixed(2)}'
      '-bg${scaled.backgroundColor.toRadixString(16)}';
  return MermaidRenderTheme(key: key, style: scaled);
}

double _resolveViewportHeight(
  double availableWidth,
  BoxConstraints constraints,
) {
  final preferred = availableWidth / _kMermaidPreviewAspectRatio;
  final maxHeight = constraints.maxHeight.isFinite
      ? math.max(
          1.0, math.min(_kMermaidPreviewMaxHeight, constraints.maxHeight))
      : _kMermaidPreviewMaxHeight;
  final minHeight = math.min(_kMermaidPreviewMinHeight, maxHeight).toDouble();
  return preferred.clamp(minHeight, maxHeight).toDouble();
}

Matrix4 _buildFitMatrix({
  required Size viewportSize,
  required Size contentSize,
}) {
  final scale =
      _fitScaleFor(viewportSize: viewportSize, contentSize: contentSize);
  final dx = (viewportSize.width - contentSize.width * scale) / 2;
  final dy = (viewportSize.height - contentSize.height * scale) / 2;
  return Matrix4.identity()
    ..translate(dx, dy)
    ..scale(scale, scale);
}

double _fitScaleFor({
  required Size viewportSize,
  required Size contentSize,
}) {
  final width =
      math.max(1.0, viewportSize.width - _kMermaidPreviewFitPadding * 2);
  final height =
      math.max(1.0, viewportSize.height - _kMermaidPreviewFitPadding * 2);
  final raw = math.min(width / contentSize.width, height / contentSize.height);
  return raw.isFinite && raw > 0
      ? math.min(raw, _kMermaidPreviewMaxScale).toDouble()
      : 1.0;
}

bool _sameLimits(MermaidRenderLimits left, MermaidRenderLimits right) {
  return left.maxSourceCharacters == right.maxSourceCharacters &&
      left.maxNodes == right.maxNodes &&
      left.maxEdges == right.maxEdges &&
      left.maxLayoutIterations == right.maxLayoutIterations &&
      left.maxTotalDuration == right.maxTotalDuration;
}

bool _isBlankSource(String source) => source.trim().isEmpty;
