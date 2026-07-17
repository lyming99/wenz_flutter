import '../core/model/rich_text_document.dart';

/// External document formats that are intentionally kept outside core codecs.
enum WenzDocumentFormat {
  pdf,
  docx,
}

/// Conversion direction for an external document format.
enum WenzDocumentConversionDirection {
  importDocument,
  exportDocument,
}

/// Who owns the conversion implementation.
enum WenzDocumentConversionOwner {
  /// Implemented by this package without extra runtime dependencies.
  core,

  /// Implemented by application code through an adapter.
  applicationAdapter,

  /// Implemented by a platform plugin, OS print pipeline, or server worker.
  platformOrServer,

  /// Not planned as a reliable editor conversion path.
  unsupported,
}

/// Dependency boundary allowed by the core package.
enum WenzDocumentDependencyBoundary {
  /// The core package must not add a PDF/DOCX runtime dependency.
  noCoreRuntimeDependency,

  /// A host application may choose a pure-Dart package at integration time.
  appOwnedPureDartPackage,

  /// A host application may choose a Flutter/native plugin.
  appOwnedPlatformPlugin,

  /// A host application may use the platform print pipeline.
  platformPrintPipeline,

  /// A host application may delegate conversion to a backend worker.
  serverWorker,
}

/// Known places where conversion cannot guarantee a full-fidelity round trip.
enum WenzDocumentDegradationBoundary {
  fixedLayoutIsNotEditable,
  visualLayoutMayDiffer,
  unsupportedEmbedsBecomeReadableText,
  attachmentsBecomeLinks,
  commentsAndRevisionsStayExternal,
  assetsRequireExternalResolver,
  pdfImportIsNotReliable,
}

/// Platform families where an adapter may be provided by the host application.
enum WenzDocumentConversionPlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  web,
  server,
}

/// Describes the supported boundary for one external document conversion path.
class WenzDocumentConversionPlan {
  const WenzDocumentConversionPlan({
    required this.format,
    required this.direction,
    required this.owner,
    required this.platforms,
    required this.dependencyBoundaries,
    required this.degradationBoundaries,
    required this.summary,
  });

  final WenzDocumentFormat format;
  final WenzDocumentConversionDirection direction;
  final WenzDocumentConversionOwner owner;
  final Set<WenzDocumentConversionPlatform> platforms;
  final Set<WenzDocumentDependencyBoundary> dependencyBoundaries;
  final Set<WenzDocumentDegradationBoundary> degradationBoundaries;
  final String summary;

  bool get isCoreProvided => owner == WenzDocumentConversionOwner.core;

  bool get isUnsupported => owner == WenzDocumentConversionOwner.unsupported;

  bool get requiresExternalAdapter =>
      owner == WenzDocumentConversionOwner.applicationAdapter ||
      owner == WenzDocumentConversionOwner.platformOrServer;

  bool get keepsCoreDependencyFree => dependencyBoundaries.contains(
        WenzDocumentDependencyBoundary.noCoreRuntimeDependency,
      );
}

/// Contract for app-owned export adapters.
abstract interface class WenzDocumentExporter<TOutput> {
  WenzDocumentConversionPlan get plan;

  Future<TOutput> exportDocument(RichTextDocument document);
}

/// Contract for app-owned import adapters.
abstract interface class WenzDocumentImporter<TSource> {
  WenzDocumentConversionPlan get plan;

  Future<RichTextDocument> importDocument(TSource source);
}

const Set<WenzDocumentConversionPlatform> _allAdapterPlatforms =
    <WenzDocumentConversionPlatform>{
  WenzDocumentConversionPlatform.android,
  WenzDocumentConversionPlatform.ios,
  WenzDocumentConversionPlatform.macos,
  WenzDocumentConversionPlatform.windows,
  WenzDocumentConversionPlatform.linux,
  WenzDocumentConversionPlatform.web,
  WenzDocumentConversionPlatform.server,
};

/// PDF export is an application/platform concern, not a core codec.
const WenzDocumentConversionPlan wenzPdfExportPlan = WenzDocumentConversionPlan(
  format: WenzDocumentFormat.pdf,
  direction: WenzDocumentConversionDirection.exportDocument,
  owner: WenzDocumentConversionOwner.platformOrServer,
  platforms: _allAdapterPlatforms,
  dependencyBoundaries: <WenzDocumentDependencyBoundary>{
    WenzDocumentDependencyBoundary.noCoreRuntimeDependency,
    WenzDocumentDependencyBoundary.appOwnedPlatformPlugin,
    WenzDocumentDependencyBoundary.platformPrintPipeline,
    WenzDocumentDependencyBoundary.serverWorker,
  },
  degradationBoundaries: <WenzDocumentDegradationBoundary>{
    WenzDocumentDegradationBoundary.fixedLayoutIsNotEditable,
    WenzDocumentDegradationBoundary.visualLayoutMayDiffer,
    WenzDocumentDegradationBoundary.unsupportedEmbedsBecomeReadableText,
    WenzDocumentDegradationBoundary.attachmentsBecomeLinks,
    WenzDocumentDegradationBoundary.assetsRequireExternalResolver,
  },
  summary: 'Export via host-provided PDF renderer, print pipeline, or server.',
);

/// PDF import is not a reliable editor round-trip target.
const WenzDocumentConversionPlan wenzPdfImportPlan = WenzDocumentConversionPlan(
  format: WenzDocumentFormat.pdf,
  direction: WenzDocumentConversionDirection.importDocument,
  owner: WenzDocumentConversionOwner.unsupported,
  platforms: <WenzDocumentConversionPlatform>{},
  dependencyBoundaries: <WenzDocumentDependencyBoundary>{
    WenzDocumentDependencyBoundary.noCoreRuntimeDependency,
  },
  degradationBoundaries: <WenzDocumentDegradationBoundary>{
    WenzDocumentDegradationBoundary.pdfImportIsNotReliable,
    WenzDocumentDegradationBoundary.fixedLayoutIsNotEditable,
  },
  summary: 'Do not infer editable rich text from fixed-layout PDF in core.',
);

/// DOCX export is provided by an application adapter or backend worker.
const WenzDocumentConversionPlan wenzDocxExportPlan = WenzDocumentConversionPlan(
  format: WenzDocumentFormat.docx,
  direction: WenzDocumentConversionDirection.exportDocument,
  owner: WenzDocumentConversionOwner.applicationAdapter,
  platforms: _allAdapterPlatforms,
  dependencyBoundaries: <WenzDocumentDependencyBoundary>{
    WenzDocumentDependencyBoundary.noCoreRuntimeDependency,
    WenzDocumentDependencyBoundary.appOwnedPureDartPackage,
    WenzDocumentDependencyBoundary.appOwnedPlatformPlugin,
    WenzDocumentDependencyBoundary.serverWorker,
  },
  degradationBoundaries: <WenzDocumentDegradationBoundary>{
    WenzDocumentDegradationBoundary.visualLayoutMayDiffer,
    WenzDocumentDegradationBoundary.unsupportedEmbedsBecomeReadableText,
    WenzDocumentDegradationBoundary.attachmentsBecomeLinks,
    WenzDocumentDegradationBoundary.commentsAndRevisionsStayExternal,
    WenzDocumentDegradationBoundary.assetsRequireExternalResolver,
  },
  summary: 'Export through host-owned OOXML/DOCX mapping or server worker.',
);

/// DOCX import is provided by an application adapter or backend worker.
const WenzDocumentConversionPlan wenzDocxImportPlan = WenzDocumentConversionPlan(
  format: WenzDocumentFormat.docx,
  direction: WenzDocumentConversionDirection.importDocument,
  owner: WenzDocumentConversionOwner.applicationAdapter,
  platforms: _allAdapterPlatforms,
  dependencyBoundaries: <WenzDocumentDependencyBoundary>{
    WenzDocumentDependencyBoundary.noCoreRuntimeDependency,
    WenzDocumentDependencyBoundary.appOwnedPureDartPackage,
    WenzDocumentDependencyBoundary.appOwnedPlatformPlugin,
    WenzDocumentDependencyBoundary.serverWorker,
  },
  degradationBoundaries: <WenzDocumentDegradationBoundary>{
    WenzDocumentDegradationBoundary.visualLayoutMayDiffer,
    WenzDocumentDegradationBoundary.unsupportedEmbedsBecomeReadableText,
    WenzDocumentDegradationBoundary.attachmentsBecomeLinks,
    WenzDocumentDegradationBoundary.commentsAndRevisionsStayExternal,
    WenzDocumentDegradationBoundary.assetsRequireExternalResolver,
  },
  summary: 'Import through host-owned OOXML/DOCX parser or server worker.',
);

/// Default external conversion plan for this package.
const List<WenzDocumentConversionPlan> wenzDocumentConversionPlans =
    <WenzDocumentConversionPlan>[
  wenzPdfExportPlan,
  wenzPdfImportPlan,
  wenzDocxExportPlan,
  wenzDocxImportPlan,
];

/// Finds the default plan for [format] and [direction].
WenzDocumentConversionPlan wenzDocumentConversionPlanFor(
  WenzDocumentFormat format,
  WenzDocumentConversionDirection direction,
) {
  return wenzDocumentConversionPlans.firstWhere(
    (plan) => plan.format == format && plan.direction == direction,
  );
}
