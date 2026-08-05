import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/style.dart';
import '../parser/mermaid_parser.dart';

/// Version of the pure Dart/Flutter Mermaid rendering pipeline.
///
/// Increment this value whenever parsing or layout semantics change so cached
/// results created by an older engine cannot be reused accidentally.
const String nativeMermaidEngineVersion = '3';

/// Stable error categories surfaced by the native Mermaid renderer.
enum MermaidRenderErrorCode {
  emptySource,
  sourceTooLong,
  tooManyNodes,
  tooManyEdges,
  layoutIterationLimit,
  timeout,
  cancelled,
  syntax,
  unsupportedType,
  invalidLayout,
  internal,
}

/// Cache result for a render request.
enum MermaidCacheStatus { hit, miss }

/// Stage represented by a privacy-safe diagnostic event.
enum MermaidRenderStage { cache, parser, layout, textMeasurement, paint, total }

/// Resource boundaries applied before and during native rendering.
class MermaidRenderLimits {
  const MermaidRenderLimits({
    this.maxSourceCharacters = 50000,
    this.maxNodes = 1000,
    this.maxEdges = 500,
    this.maxLayoutIterations = 4,
    this.maxTotalDuration = const Duration(seconds: 2),
  });

  final int maxSourceCharacters;
  final int maxNodes;
  final int maxEdges;
  final int maxLayoutIterations;
  final Duration maxTotalDuration;
}

/// Resolved visual theme used by the renderer and its cache key.
class MermaidRenderTheme {
  const MermaidRenderTheme({required this.key, required this.style});

  /// Stable key including brightness, contrast, and text-scale variants.
  final String key;

  /// Concrete painter/layout style for this request.
  final MermaidStyle style;
}

/// One native render request.
class MermaidRenderRequest {
  const MermaidRenderRequest({
    required this.source,
    required this.sourceDigest,
    required this.theme,
    required this.viewport,
    required this.limits,
    required this.requestId,
  });

  final String source;
  final String sourceDigest;
  final MermaidRenderTheme theme;
  final Size viewport;
  final MermaidRenderLimits limits;

  /// Globally unique for the lifetime of the editor instance.
  final String requestId;
}

/// Privacy-safe timings and cardinalities for a render attempt.
class MermaidRenderMetrics {
  const MermaidRenderMetrics({
    required this.characterCount,
    required this.nodeCount,
    required this.edgeCount,
    required this.diagramType,
    required this.parseDuration,
    required this.layoutDuration,
    required this.textMeasurementDuration,
    required this.totalDuration,
    required this.cacheStatus,
    required this.parseCacheHit,
    required this.workerUsed,
  });

  final int characterCount;
  final int nodeCount;
  final int edgeCount;
  final DiagramType diagramType;
  final Duration parseDuration;
  final Duration layoutDuration;
  final Duration textMeasurementDuration;
  final Duration totalDuration;
  final MermaidCacheStatus cacheStatus;
  final bool parseCacheHit;
  final bool workerUsed;

  MermaidRenderMetrics copyWith({
    Duration? totalDuration,
    MermaidCacheStatus? cacheStatus,
    bool? parseCacheHit,
  }) {
    return MermaidRenderMetrics(
      characterCount: characterCount,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      diagramType: diagramType,
      parseDuration: parseDuration,
      layoutDuration: layoutDuration,
      textMeasurementDuration: textMeasurementDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      cacheStatus: cacheStatus ?? this.cacheStatus,
      parseCacheHit: parseCacheHit ?? this.parseCacheHit,
      workerUsed: workerUsed,
    );
  }
}

/// Diagnostic event that deliberately excludes source text and source hashes.
class MermaidRenderDiagnosticEvent {
  const MermaidRenderDiagnosticEvent({
    required this.stage,
    required this.duration,
    required this.characterCount,
    required this.nodeCount,
    required this.edgeCount,
    required this.diagramType,
    required this.cacheStatus,
    this.errorCode,
  });

  final MermaidRenderStage stage;
  final Duration duration;
  final int characterCount;
  final int nodeCount;
  final int edgeCount;
  final DiagramType diagramType;
  final MermaidCacheStatus cacheStatus;
  final MermaidRenderErrorCode? errorCode;
}

typedef MermaidRenderDiagnostics = void Function(
  MermaidRenderDiagnosticEvent event,
);

/// Base type returned by [NativeMermaidRenderService.render].
sealed class MermaidRenderOutcome {
  const MermaidRenderOutcome({
    required this.requestId,
    required this.sourceDigest,
  });

  final String requestId;
  final String sourceDigest;
}

/// Fully parsed and laid-out data consumed directly by Flutter painters.
class MermaidRenderResult extends MermaidRenderOutcome {
  const MermaidRenderResult({
    required super.requestId,
    required super.sourceDigest,
    required this.cacheKey,
    required this.themeKey,
    required this.viewportBucket,
    required this.parseResult,
    required this.style,
    required this.deviceConfig,
    required this.contentSize,
    required this.semanticSummary,
    required this.metrics,
    required this.estimatedBytes,
  });

  final String cacheKey;
  final String themeKey;
  final String viewportBucket;
  final MermaidParseResult parseResult;
  final MermaidStyle style;
  final MermaidDeviceConfig deviceConfig;
  final Size contentSize;
  final String semanticSummary;
  final MermaidRenderMetrics metrics;
  final int estimatedBytes;

  MermaidDiagramData get diagram => parseResult.diagram;
  DiagramType get diagramType => diagram.type;
  int get nodeCount => diagram.nodes.length;
  int get edgeCount => diagram.edges.length;

  MermaidRenderResult forRequest({
    required String requestId,
    required String sourceDigest,
    required Duration totalDuration,
  }) {
    return MermaidRenderResult(
      requestId: requestId,
      sourceDigest: sourceDigest,
      cacheKey: cacheKey,
      themeKey: themeKey,
      viewportBucket: viewportBucket,
      parseResult: parseResult,
      style: style,
      deviceConfig: deviceConfig,
      contentSize: contentSize,
      semanticSummary: semanticSummary,
      metrics: MermaidRenderMetrics(
        characterCount: metrics.characterCount,
        nodeCount: metrics.nodeCount,
        edgeCount: metrics.edgeCount,
        diagramType: metrics.diagramType,
        parseDuration: Duration.zero,
        layoutDuration: Duration.zero,
        textMeasurementDuration: Duration.zero,
        totalDuration: totalDuration,
        cacheStatus: MermaidCacheStatus.hit,
        parseCacheHit: true,
        workerUsed: false,
      ),
      estimatedBytes: estimatedBytes,
    );
  }
}

/// Structured failure that keeps source recovery separate from rendering.
class MermaidRenderFailure extends MermaidRenderOutcome {
  const MermaidRenderFailure({
    required super.requestId,
    required super.sourceDigest,
    required this.code,
    required this.diagnostic,
    required this.metrics,
  });

  final MermaidRenderErrorCode code;
  final String diagnostic;
  final MermaidRenderMetrics? metrics;

  bool get isLimit =>
      code == MermaidRenderErrorCode.sourceTooLong ||
      code == MermaidRenderErrorCode.tooManyNodes ||
      code == MermaidRenderErrorCode.tooManyEdges ||
      code == MermaidRenderErrorCode.layoutIterationLimit;

  bool get isCancelled => code == MermaidRenderErrorCode.cancelled;
  bool get isUnsupported => code == MermaidRenderErrorCode.unsupportedType;
}

/// Read-only service counters used by tests and performance probes.
class NativeMermaidRenderServiceStats {
  const NativeMermaidRenderServiceStats({
    required this.renderCacheHits,
    required this.renderCacheMisses,
    required this.parseCacheHits,
    required this.parseCount,
    required this.layoutCount,
    required this.cancelledCount,
    required this.limitRejectedCount,
    required this.timeoutCount,
    required this.workerSpawnCount,
    required this.cacheEntryCount,
    required this.cacheEstimatedBytes,
  });

  final int renderCacheHits;
  final int renderCacheMisses;
  final int parseCacheHits;
  final int parseCount;
  final int layoutCount;
  final int cancelledCount;
  final int limitRejectedCount;
  final int timeoutCount;
  final int workerSpawnCount;
  final int cacheEntryCount;
  final int cacheEstimatedBytes;
}

/// Editor-scoped native Mermaid rendering contract.
abstract interface class NativeMermaidRenderService {
  Future<MermaidRenderOutcome> render(MermaidRenderRequest request);

  /// Marks an active request as cancelled. Completed/unknown ids are ignored.
  void cancel(String requestId);

  /// Removes render entries associated with a resolved theme variant.
  void invalidateTheme(String themeKey);

  NativeMermaidRenderServiceStats get stats;

  Future<void> dispose();
}
