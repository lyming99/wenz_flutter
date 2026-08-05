import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:crypto/crypto.dart';

import '../config/responsive_config.dart';
import '../layout/dagre_layout.dart';
import '../layout/layout_engine.dart';
import '../layout/mindmap_layout.dart';
import '../layout/sugiyama_layout.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';
import '../painter/gantt_painter.dart';
import '../painter/pie_chart_painter.dart';
import '../parser/mermaid_parser.dart';
import 'layout_instrumentation.dart';
import 'render_models.dart';

const int _defaultCacheBytes = 64 * 1024 * 1024;
const int _viewportBucketExtent = 80;

/// SHA-256 digest used to identify a source version without logging it.
String mermaidSourceDigest(String source) {
  return sha256.convert(utf8.encode(source)).toString();
}

/// Stable viewport bucket used in render cache keys.
String mermaidViewportBucket(Size viewport) {
  final width = viewport.width.isFinite ? math.max(1.0, viewport.width) : 1.0;
  final height =
      viewport.height.isFinite ? math.max(1.0, viewport.height) : 1.0;
  final widthBucket = (width / _viewportBucketExtent).ceil();
  final heightBucket = (height / _viewportBucketExtent).ceil();
  return '${widthBucket}x$heightBucket';
}

/// Pure Dart/Flutter implementation backed by one reusable parser isolate.
class DefaultNativeMermaidRenderService implements NativeMermaidRenderService {
  DefaultNativeMermaidRenderService({
    this.maxCacheEntries = 32,
    this.maxCacheBytes = _defaultCacheBytes,
    this.diagnostics,
  })  : assert(maxCacheEntries > 0),
        assert(maxCacheBytes > 0);

  final int maxCacheEntries;
  final int maxCacheBytes;
  final MermaidRenderDiagnostics? diagnostics;

  final _MermaidParserWorker _worker = _MermaidParserWorker();
  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();
  final Map<String, Future<_WorkerParseResponse>> _inflightParses =
      <String, Future<_WorkerParseResponse>>{};
  final Set<String> _activeRequestIds = <String>{};
  final Set<String> _cancelledRequestIds = <String>{};

  bool _disposed = false;
  int _cacheBytes = 0;
  int _renderCacheHits = 0;
  int _renderCacheMisses = 0;
  int _parseCacheHits = 0;
  int _parseCount = 0;
  int _layoutCount = 0;
  int _cancelledCount = 0;
  int _limitRejectedCount = 0;
  int _timeoutCount = 0;

  @override
  NativeMermaidRenderServiceStats get stats {
    return NativeMermaidRenderServiceStats(
      renderCacheHits: _renderCacheHits,
      renderCacheMisses: _renderCacheMisses,
      parseCacheHits: _parseCacheHits,
      parseCount: _parseCount,
      layoutCount: _layoutCount,
      cancelledCount: _cancelledCount,
      limitRejectedCount: _limitRejectedCount,
      timeoutCount: _timeoutCount,
      workerSpawnCount: _worker.spawnCount,
      cacheEntryCount: _cache.length,
      cacheEstimatedBytes: _cacheBytes,
    );
  }

  @override
  Future<MermaidRenderOutcome> render(MermaidRenderRequest request) async {
    final totalWatch = Stopwatch()..start();
    _activeRequestIds.add(request.requestId);

    try {
      final actualDigest = mermaidSourceDigest(request.source);
      if (_disposed || _isCancelled(request.requestId)) {
        return _cancelledFailure(request, actualDigest, totalWatch.elapsed);
      }
      if (request.sourceDigest != actualDigest) {
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.internal,
          diagnostic: 'Mermaid 源码版本校验失败，请重试。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (request.source.trim().isEmpty) {
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.emptySource,
          diagnostic: 'Mermaid 源码为空。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (request.source.length > request.limits.maxSourceCharacters) {
        _limitRejectedCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.sourceTooLong,
          diagnostic:
              'Mermaid 源码超过 ${request.limits.maxSourceCharacters} 字符上限。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (request.limits.maxLayoutIterations < 1) {
        _limitRejectedCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.layoutIterationLimit,
          diagnostic: 'Mermaid 布局迭代上限必须至少为 1。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (request.limits.maxTotalDuration <= Duration.zero) {
        _timeoutCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.timeout,
          diagnostic: 'Mermaid 预览超时，请缩小图表后重试。',
          totalDuration: totalWatch.elapsed,
        );
      }

      final viewportBucket = mermaidViewportBucket(request.viewport);
      final renderKey = _renderCacheKey(request, viewportBucket);
      final cachedEntry = _cacheGet(renderKey);
      if (cachedEntry is _RenderCacheEntry) {
        _renderCacheHits++;
        final cachedResult = cachedEntry.result;
        if (cachedResult.nodeCount > request.limits.maxNodes) {
          _limitRejectedCount++;
          return _failure(
            request: request,
            sourceDigest: actualDigest,
            code: MermaidRenderErrorCode.tooManyNodes,
            diagnostic:
                'Mermaid 图表包含 ${cachedResult.nodeCount} 个节点，超过 ${request.limits.maxNodes} 个节点上限。',
            totalDuration: totalWatch.elapsed,
            diagramType: cachedResult.diagramType,
            nodeCount: cachedResult.nodeCount,
            edgeCount: cachedResult.edgeCount,
            parseCacheHit: true,
            cacheStatus: MermaidCacheStatus.hit,
          );
        }
        if (cachedResult.edgeCount > request.limits.maxEdges) {
          _limitRejectedCount++;
          return _failure(
            request: request,
            sourceDigest: actualDigest,
            code: MermaidRenderErrorCode.tooManyEdges,
            diagnostic:
                'Mermaid 图表包含 ${cachedResult.edgeCount} 条连线，超过 ${request.limits.maxEdges} 条连线上限。',
            totalDuration: totalWatch.elapsed,
            diagramType: cachedResult.diagramType,
            nodeCount: cachedResult.nodeCount,
            edgeCount: cachedResult.edgeCount,
            parseCacheHit: true,
            cacheStatus: MermaidCacheStatus.hit,
          );
        }
        final result = cachedEntry.result.forRequest(
          requestId: request.requestId,
          sourceDigest: actualDigest,
          totalDuration: totalWatch.elapsed,
        );
        _emitResultMetrics(result.metrics);
        return result;
      }
      _renderCacheMisses++;
      _emit(
        MermaidRenderDiagnosticEvent(
          stage: MermaidRenderStage.cache,
          duration: Duration.zero,
          characterCount: request.source.length,
          nodeCount: 0,
          edgeCount: 0,
          diagramType: DiagramType.unknown,
          cacheStatus: MermaidCacheStatus.miss,
        ),
      );

      final parseKey = 'parse:$actualDigest:$nativeMermaidEngineVersion';
      final parseEntry = _cacheGet(parseKey);
      final bool parseCacheHit;
      final bool workerUsed;
      final Duration parseDuration;
      final _WorkerParseResponse parsed;

      if (parseEntry is _ParseCacheEntry) {
        _parseCacheHits++;
        parseCacheHit = true;
        workerUsed = false;
        parseDuration = Duration.zero;
        parsed = parseEntry.response;
      } else {
        parseCacheHit = false;
        workerUsed = true;
        final parseFuture = _inflightParses.putIfAbsent(
          parseKey,
          () {
            _parseCount++;
            late final Future<_WorkerParseResponse> started;
            started = _worker.parse(request.source);
            unawaited(
              started.then<void>(
                (_) => _releaseInflightParse(parseKey, started),
                onError: (Object _, StackTrace __) {
                  _releaseInflightParse(parseKey, started);
                },
              ),
            );
            return started;
          },
        );
        try {
          parsed = await parseFuture.timeout(
            _remaining(request.limits, totalWatch),
          );
        } on TimeoutException {
          _timeoutCount++;
          return _failure(
            request: request,
            sourceDigest: actualDigest,
            code: MermaidRenderErrorCode.timeout,
            diagnostic: 'Mermaid 解析超时，请缩小图表后重试。',
            totalDuration: totalWatch.elapsed,
          );
        } on Object {
          return _failure(
            request: request,
            sourceDigest: actualDigest,
            code: MermaidRenderErrorCode.internal,
            diagnostic: 'Mermaid 解析器发生内部错误。',
            totalDuration: totalWatch.elapsed,
          );
        }
        parseDuration = parsed.duration;
      }

      if (_disposed || _isCancelled(request.requestId)) {
        return _cancelledFailure(request, actualDigest, totalWatch.elapsed);
      }
      if (totalWatch.elapsed > request.limits.maxTotalDuration) {
        _timeoutCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.timeout,
          diagnostic: 'Mermaid 解析超时，请缩小图表后重试。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (parsed.error != null) {
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.internal,
          diagnostic: 'Mermaid 解析器发生内部错误。',
          totalDuration: totalWatch.elapsed,
        );
      }
      if (parsed.result == null) {
        final unsupported = parsed.type == DiagramType.classDiagram ||
            parsed.type == DiagramType.stateDiagram;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: unsupported
              ? MermaidRenderErrorCode.unsupportedType
              : MermaidRenderErrorCode.syntax,
          diagnostic: parsed.failureDescription,
          totalDuration: totalWatch.elapsed,
        );
      }

      final parsedResult = parsed.result!;
      final nodeCount = parsedResult.diagram.nodes.length;
      final edgeCount = parsedResult.diagram.edges.length;
      if (nodeCount > request.limits.maxNodes) {
        _limitRejectedCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.tooManyNodes,
          diagnostic:
              'Mermaid 图表包含 $nodeCount 个节点，超过 ${request.limits.maxNodes} 个节点上限。',
          totalDuration: totalWatch.elapsed,
          diagramType: parsed.type,
          nodeCount: nodeCount,
          edgeCount: edgeCount,
          parseDuration: parseDuration,
          parseCacheHit: parseCacheHit,
          workerUsed: workerUsed,
        );
      }
      if (edgeCount > request.limits.maxEdges) {
        _limitRejectedCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.tooManyEdges,
          diagnostic:
              'Mermaid 图表包含 $edgeCount 条连线，超过 ${request.limits.maxEdges} 条连线上限。',
          totalDuration: totalWatch.elapsed,
          diagramType: parsed.type,
          nodeCount: nodeCount,
          edgeCount: edgeCount,
          parseDuration: parseDuration,
          parseCacheHit: parseCacheHit,
          workerUsed: workerUsed,
        );
      }

      // Preserve the parser result before layout mutates node coordinates.
      if (!parseCacheHit) {
        _cachePut(
          parseKey,
          _ParseCacheEntry(
            response: parsed,
            estimatedBytes: _estimateBytes(
              request.source.length,
              nodeCount,
              edgeCount,
            ),
          ),
        );
      }
      final renderParseResult = _cloneParseResult(parsedResult);
      final responsive = _resolveResponsiveTheme(
        request.theme.style,
        request.viewport.width,
      );
      final measurementCollector = MermaidTextMeasurementCollector();
      final layoutWatch = Stopwatch()..start();
      late final Size contentSize;
      try {
        contentSize = collectMermaidTextMeasurements(
          measurementCollector,
          () => _computeLayout(
            renderParseResult,
            responsive.style,
            responsive.deviceConfig,
            request.viewport,
            request.limits.maxLayoutIterations,
          ),
        );
        _layoutCount++;
      } catch (_) {
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.internal,
          diagnostic: 'Mermaid 布局计算失败。',
          totalDuration: totalWatch.elapsed,
          diagramType: parsed.type,
          nodeCount: nodeCount,
          edgeCount: edgeCount,
          parseDuration: parseDuration,
          layoutDuration: layoutWatch.elapsed,
          textMeasurementDuration: measurementCollector.duration,
          parseCacheHit: parseCacheHit,
          workerUsed: workerUsed,
        );
      } finally {
        layoutWatch.stop();
      }

      if (_disposed || _isCancelled(request.requestId)) {
        return _cancelledFailure(request, actualDigest, totalWatch.elapsed);
      }
      if (totalWatch.elapsed > request.limits.maxTotalDuration) {
        _timeoutCount++;
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.timeout,
          diagnostic: 'Mermaid 布局超时，请缩小图表后重试。',
          totalDuration: totalWatch.elapsed,
          diagramType: parsed.type,
          nodeCount: nodeCount,
          edgeCount: edgeCount,
          parseDuration: parseDuration,
          layoutDuration: layoutWatch.elapsed,
          textMeasurementDuration: measurementCollector.duration,
          parseCacheHit: parseCacheHit,
          workerUsed: workerUsed,
        );
      }
      if (!_hasValidLayout(renderParseResult, contentSize)) {
        return _failure(
          request: request,
          sourceDigest: actualDigest,
          code: MermaidRenderErrorCode.invalidLayout,
          diagnostic: 'Mermaid 图表布局结果无效，无法生成预览。',
          totalDuration: totalWatch.elapsed,
          diagramType: parsed.type,
          nodeCount: nodeCount,
          edgeCount: edgeCount,
          parseDuration: parseDuration,
          layoutDuration: layoutWatch.elapsed,
          textMeasurementDuration: measurementCollector.duration,
          parseCacheHit: parseCacheHit,
          workerUsed: workerUsed,
        );
      }

      final estimatedBytes = _estimateBytes(
        request.source.length,
        nodeCount,
        edgeCount,
      );
      final metrics = MermaidRenderMetrics(
        characterCount: request.source.length,
        nodeCount: nodeCount,
        edgeCount: edgeCount,
        diagramType: parsed.type,
        parseDuration: parseDuration,
        layoutDuration: layoutWatch.elapsed,
        textMeasurementDuration: measurementCollector.duration,
        totalDuration: totalWatch.elapsed,
        cacheStatus: MermaidCacheStatus.miss,
        parseCacheHit: parseCacheHit,
        workerUsed: workerUsed,
      );
      final result = MermaidRenderResult(
        requestId: request.requestId,
        sourceDigest: actualDigest,
        cacheKey: renderKey,
        themeKey: request.theme.key,
        viewportBucket: viewportBucket,
        parseResult: renderParseResult,
        style: responsive.style,
        deviceConfig: responsive.deviceConfig,
        contentSize: contentSize,
        semanticSummary: _semanticSummary(
          parsed.type,
          nodeCount,
          edgeCount,
        ),
        metrics: metrics,
        estimatedBytes: estimatedBytes,
      );
      _cachePut(
        renderKey,
        _RenderCacheEntry(
          result: result,
          themeKey: request.theme.key,
          estimatedBytes: estimatedBytes,
        ),
      );
      _emitResultMetrics(metrics);
      return result;
    } finally {
      totalWatch.stop();
      _activeRequestIds.remove(request.requestId);
      _cancelledRequestIds.remove(request.requestId);
    }
  }

  @override
  void cancel(String requestId) {
    if (_activeRequestIds.contains(requestId)) {
      _cancelledRequestIds.add(requestId);
    }
  }

  @override
  void invalidateTheme(String themeKey) {
    final keys = _cache.entries
        .where(
          (entry) =>
              entry.value is _RenderCacheEntry &&
              (entry.value as _RenderCacheEntry).themeKey == themeKey,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in keys) {
      _removeCacheKey(key);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelledRequestIds.addAll(_activeRequestIds);
    _cache.clear();
    _cacheBytes = 0;
    await _worker.dispose();
  }

  bool _isCancelled(String requestId) {
    return _cancelledRequestIds.contains(requestId);
  }

  MermaidRenderFailure _cancelledFailure(
    MermaidRenderRequest request,
    String sourceDigest,
    Duration totalDuration,
  ) {
    _cancelledCount++;
    return _failure(
      request: request,
      sourceDigest: sourceDigest,
      code: MermaidRenderErrorCode.cancelled,
      diagnostic: 'Mermaid 预览请求已取消。',
      totalDuration: totalDuration,
    );
  }

  MermaidRenderFailure _failure({
    required MermaidRenderRequest request,
    required String sourceDigest,
    required MermaidRenderErrorCode code,
    required String diagnostic,
    required Duration totalDuration,
    DiagramType diagramType = DiagramType.unknown,
    int nodeCount = 0,
    int edgeCount = 0,
    Duration parseDuration = Duration.zero,
    Duration layoutDuration = Duration.zero,
    Duration textMeasurementDuration = Duration.zero,
    bool parseCacheHit = false,
    bool workerUsed = false,
    MermaidCacheStatus cacheStatus = MermaidCacheStatus.miss,
  }) {
    final metrics = MermaidRenderMetrics(
      characterCount: request.source.length,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      diagramType: diagramType,
      parseDuration: parseDuration,
      layoutDuration: layoutDuration,
      textMeasurementDuration: textMeasurementDuration,
      totalDuration: totalDuration,
      cacheStatus: cacheStatus,
      parseCacheHit: parseCacheHit,
      workerUsed: workerUsed,
    );
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.total,
        duration: totalDuration,
        characterCount: metrics.characterCount,
        nodeCount: nodeCount,
        edgeCount: edgeCount,
        diagramType: diagramType,
        cacheStatus: metrics.cacheStatus,
        errorCode: code,
      ),
    );
    return MermaidRenderFailure(
      requestId: request.requestId,
      sourceDigest: sourceDigest,
      code: code,
      diagnostic: diagnostic,
      metrics: metrics,
    );
  }

  void _emitResultMetrics(MermaidRenderMetrics metrics) {
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.cache,
        duration: Duration.zero,
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        cacheStatus: metrics.cacheStatus,
      ),
    );
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.parser,
        duration: metrics.parseDuration,
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        cacheStatus: metrics.cacheStatus,
      ),
    );
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.layout,
        duration: metrics.layoutDuration,
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        cacheStatus: metrics.cacheStatus,
      ),
    );
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.textMeasurement,
        duration: metrics.textMeasurementDuration,
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        cacheStatus: metrics.cacheStatus,
      ),
    );
    _emit(
      MermaidRenderDiagnosticEvent(
        stage: MermaidRenderStage.total,
        duration: metrics.totalDuration,
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        cacheStatus: metrics.cacheStatus,
      ),
    );
  }

  void _emit(MermaidRenderDiagnosticEvent event) {
    try {
      diagnostics?.call(event);
    } catch (_) {
      // Diagnostics must never break editing or rendering.
    }
  }

  void _releaseInflightParse(
    String parseKey,
    Future<_WorkerParseResponse> future,
  ) {
    if (identical(_inflightParses[parseKey], future)) {
      _inflightParses.remove(parseKey);
    }
  }

  Duration _remaining(MermaidRenderLimits limits, Stopwatch watch) {
    final remaining = limits.maxTotalDuration - watch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Mermaid render budget exhausted.');
    }
    return remaining;
  }

  String _renderCacheKey(
    MermaidRenderRequest request,
    String viewportBucket,
  ) {
    final material = StringBuffer()
      ..write(request.source)
      ..write('\u0000')
      ..write(request.theme.key)
      ..write('\u0000')
      ..write(nativeMermaidEngineVersion)
      ..write('\u0000')
      ..write(viewportBucket);
    return 'render:${sha256.convert(utf8.encode(material.toString()))}';
  }

  _CacheEntry? _cacheGet(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _cache[key] = entry;
    }
    return entry;
  }

  void _cachePut(String key, _CacheEntry entry) {
    final previous = _cache.remove(key);
    if (previous != null) {
      _cacheBytes -= previous.estimatedBytes;
    }
    _cache[key] = entry;
    _cacheBytes += entry.estimatedBytes;
    while (_cache.length > maxCacheEntries || _cacheBytes > maxCacheBytes) {
      final oldestKey = _cache.keys.first;
      _removeCacheKey(oldestKey);
    }
  }

  void _removeCacheKey(String key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _cacheBytes -= removed.estimatedBytes;
    }
  }
}

class _ResponsiveTheme {
  const _ResponsiveTheme({required this.style, required this.deviceConfig});

  final MermaidStyle style;
  final MermaidDeviceConfig deviceConfig;
}

_ResponsiveTheme _resolveResponsiveTheme(MermaidStyle base, double width) {
  final safeWidth = width.isFinite ? math.max(1.0, width) : 960.0;
  final rawDevice =
      const MermaidResponsiveConfig().getConfigForWidth(safeWidth);
  final textScale = base.defaultNodeStyle.fontSize / 14.0;
  final device = rawDevice.copyWith(
    fontSize: rawDevice.fontSize * textScale,
    titleFontSize: rawDevice.titleFontSize * textScale,
    legendFontSize: rawDevice.legendFontSize * textScale,
  );
  final style = base.copyWith(
    padding: device.padding,
    nodeSpacingX: device.nodeSpacingX,
    nodeSpacingY: device.nodeSpacingY,
    defaultNodeStyle: base.defaultNodeStyle.copyWith(
      fontSize: device.fontSize,
    ),
  );
  return _ResponsiveTheme(style: style, deviceConfig: device);
}

Size _computeLayout(
  MermaidParseResult result,
  MermaidStyle style,
  MermaidDeviceConfig deviceConfig,
  Size viewport,
  int maxLayoutIterations,
) {
  final availableSize = Size(
    viewport.width.isFinite ? math.max(1.0, viewport.width) : 960.0,
    viewport.height.isFinite ? math.max(1.0, viewport.height) : 540.0,
  );
  final diagram = result.diagram;
  switch (diagram.type) {
    case DiagramType.pieChart:
      final data = result.pieChartData;
      if (data != null) {
        return PieChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.ganttChart:
      final data = result.ganttChartData;
      if (data != null) {
        return GanttChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.timeline:
      final data = result.timelineChartData;
      if (data != null) {
        return TimelineChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.kanban:
      final data = result.kanbanChartData;
      if (data != null) {
        return KanbanChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.radar:
      final data = result.radarChartData;
      if (data != null) {
        return RadarChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.xyChart:
      final data = result.xyChartData;
      if (data != null) {
        return XYChartLayout(deviceConfig: deviceConfig)
            .computeLayout(data, style, availableSize);
      }
      break;
    case DiagramType.flowchart:
      return DagreLayout(
        deviceConfig: deviceConfig,
        crossingReductionIterations: maxLayoutIterations,
      ).computeLayout(diagram, style, availableSize);
    case DiagramType.sequence:
      return SequenceLayout(deviceConfig: deviceConfig)
          .computeLayout(diagram, style, availableSize);
    case DiagramType.mindmap:
      return MindmapLayout(deviceConfig: deviceConfig)
          .computeLayout(diagram, style, availableSize);
    case DiagramType.classDiagram:
    case DiagramType.stateDiagram:
    case DiagramType.unknown:
      break;
  }
  throw const FormatException('Incomplete Mermaid diagram data.');
}

bool _hasValidLayout(MermaidParseResult result, Size size) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0) {
    return false;
  }
  final type = result.diagram.type;
  if (type != DiagramType.flowchart &&
      type != DiagramType.sequence &&
      type != DiagramType.mindmap) {
    return true;
  }
  for (final node in result.diagram.nodes) {
    if (!node.x.isFinite ||
        !node.y.isFinite ||
        !node.width.isFinite ||
        !node.height.isFinite ||
        node.width <= 0 ||
        node.height <= 0) {
      return false;
    }
  }
  return true;
}

String _semanticSummary(DiagramType type, int nodes, int edges) {
  final typeName = switch (type) {
    DiagramType.flowchart => '流程图',
    DiagramType.sequence => '时序图',
    DiagramType.pieChart => '饼图',
    DiagramType.ganttChart => '甘特图',
    DiagramType.timeline => '时间线',
    DiagramType.kanban => '看板',
    DiagramType.mindmap => '思维导图',
    DiagramType.radar => '雷达图',
    DiagramType.xyChart => 'XY 图表',
    DiagramType.classDiagram => '类图',
    DiagramType.stateDiagram => '状态图',
    DiagramType.unknown => '图表',
  };
  return 'Mermaid $typeName，$nodes 个节点，$edges 条连线';
}

int _estimateBytes(int characters, int nodes, int edges) {
  return math.max(1024, characters * 2 + nodes * 512 + edges * 256);
}

MermaidParseResult _cloneParseResult(MermaidParseResult source) {
  final diagram = source.diagram;
  final nodes = diagram.nodes.map(_cloneNode).toList(growable: false);
  final edges = diagram.edges.map(_cloneEdge).toList(growable: false);
  final subgraphs = diagram.subgraphs
      .map(
        (subgraph) => Subgraph(
          id: subgraph.id,
          label: subgraph.label,
          nodeIds: List<String>.unmodifiable(subgraph.nodeIds),
          style: subgraph.style,
        ),
      )
      .toList(growable: false);
  return MermaidParseResult(
    diagram: MermaidDiagramData(
      type: diagram.type,
      nodes: List<MermaidNode>.unmodifiable(nodes),
      edges: List<MermaidEdge>.unmodifiable(edges),
      direction: diagram.direction,
      subgraphs: List<Subgraph>.unmodifiable(subgraphs),
      style: diagram.style,
      title: diagram.title,
    ),
    pieChartData: source.pieChartData,
    ganttChartData: source.ganttChartData,
    timelineChartData: source.timelineChartData,
    kanbanChartData: source.kanbanChartData,
    mindmapData: source.mindmapData,
    radarChartData: source.radarChartData,
    xyChartData: source.xyChartData,
  );
}

MermaidNode _cloneNode(MermaidNode source) {
  final MermaidNode clone;
  if (source is SequenceParticipant) {
    clone = SequenceParticipant(
      id: source.id,
      label: source.label,
      participantType: source.participantType,
      style: source.style,
    );
  } else {
    clone = MermaidNode(
      id: source.id,
      label: source.label,
      shape: source.shape,
      style: source.style,
      className: source.className,
      link: source.link,
      tooltip: source.tooltip,
    );
  }
  return clone;
}

MermaidEdge _cloneEdge(MermaidEdge source) {
  if (source is SequenceMessage) {
    return SequenceMessage(
      from: source.from,
      to: source.to,
      label: source.label,
      arrowType: source.arrowType,
      lineType: source.lineType,
      messageType: source.messageType,
      activate: source.activate,
      deactivate: source.deactivate,
    );
  }
  return MermaidEdge(
    from: source.from,
    to: source.to,
    label: source.label,
    arrowType: source.arrowType,
    lineType: source.lineType,
    style: source.style,
    animated: source.animated,
    bidirectional: source.bidirectional,
    isSubgraphEdge: source.isSubgraphEdge,
  );
}

abstract class _CacheEntry {
  const _CacheEntry({required this.estimatedBytes});

  final int estimatedBytes;
}

class _ParseCacheEntry extends _CacheEntry {
  const _ParseCacheEntry({
    required this.response,
    required super.estimatedBytes,
  });

  final _WorkerParseResponse response;
}

class _RenderCacheEntry extends _CacheEntry {
  const _RenderCacheEntry({
    required this.result,
    required this.themeKey,
    required super.estimatedBytes,
  });

  final MermaidRenderResult result;
  final String themeKey;
}

class _WorkerParseResponse {
  const _WorkerParseResponse({
    required this.type,
    required this.result,
    required this.failureDescription,
    required this.duration,
    this.error,
  });

  final DiagramType type;
  final MermaidParseResult? result;
  final String failureDescription;
  final Duration duration;
  final String? error;
}

class _MermaidParserWorker {
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<_WorkerParseResponse>> _pending =
      <int, Completer<_WorkerParseResponse>>{};

  Isolate? _isolate;
  SendPort? _commands;
  Future<void>? _starting;
  StreamSubscription<dynamic>? _responseSubscription;
  int _nextId = 0;
  bool _disposed = false;
  int spawnCount = 0;

  Future<_WorkerParseResponse> parse(String source) async {
    await _ensureStarted();
    if (_disposed || _commands == null) {
      throw StateError('Mermaid parser worker is disposed.');
    }
    final id = ++_nextId;
    final completer = Completer<_WorkerParseResponse>();
    _pending[id] = completer;
    _commands!.send(<Object>[id, source]);
    return completer.future;
  }

  Future<void> _ensureStarted() {
    if (_commands != null) return Future<void>.value();
    if (_disposed) {
      return Future<void>.error(
        StateError('Mermaid parser worker is disposed.'),
      );
    }
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final ready = Completer<void>();
    _responseSubscription = _responses.listen((dynamic message) {
      if (message is SendPort) {
        _commands = message;
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (message is! List<Object?> || message.length < 7) return;
      final id = message[0] as int;
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      completer.complete(
        _WorkerParseResponse(
          type: DiagramType.values[message[1] as int],
          result: message[2] as MermaidParseResult?,
          failureDescription: message[3] as String,
          duration: Duration(microseconds: message[4] as int),
          error: message[5] as String?,
        ),
      );
    });
    try {
      _isolate = await Isolate.spawn<SendPort>(
        _mermaidParserWorkerMain,
        _responses.sendPort,
        debugName: 'wenz-mermaid-parser',
      );
      spawnCount++;
      await ready.future;
    } catch (error, stackTrace) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(
          const _WorkerParseResponse(
            type: DiagramType.unknown,
            result: null,
            failureDescription: 'Mermaid parser worker was disposed.',
            duration: Duration.zero,
            error: 'disposed',
          ),
        );
      }
    }
    _pending.clear();
    _commands?.send(const <Object>['dispose']);
    _isolate?.kill(priority: Isolate.immediate);
    _responses.close();
    await _responseSubscription?.cancel();
  }
}

void _mermaidParserWorkerMain(SendPort replies) {
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is List<Object> &&
        message.length == 1 &&
        message.first == 'dispose') {
      commands.close();
      return;
    }
    if (message is! List<Object> || message.length != 2) return;
    final id = message[0] as int;
    final source = message[1] as String;
    final watch = Stopwatch()..start();
    const parser = MermaidParser();
    try {
      final type = parser.detectDiagramType(source);
      final result = parser.parseWithData(source);
      watch.stop();
      replies.send(<Object?>[
        id,
        type.index,
        result,
        result == null ? parser.describeParseFailure(source) : '',
        watch.elapsedMicroseconds,
        null,
        true,
      ]);
    } catch (error) {
      watch.stop();
      replies.send(<Object?>[
        id,
        DiagramType.unknown.index,
        null,
        'Mermaid parser failed.',
        watch.elapsedMicroseconds,
        error.runtimeType.toString(),
        true,
      ]);
    }
  });
}
