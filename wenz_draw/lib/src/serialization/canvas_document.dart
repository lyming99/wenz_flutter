import 'package:flutter/foundation.dart';

import '../elements/canvas_element.dart';
import '../layers/canvas_layer.dart';

/// Schema version of the serialized document format.
///
/// Bumped whenever the document shape changes in a way that needs a migration
/// (see [DocumentMigrator]). Old documents are upgraded on load so the in-memory
/// model always reflects [current].
class DocumentSchema {
  const DocumentSchema._();

  /// Current schema produced by [CanvasDocument.toJson].
  static const current = '2.0';

  /// Earliest schema still understood by the loader. Anything older is rejected.
  static const minSupported = '1.0';
}

/// User-facing metadata attached to a document. All fields optional.
@immutable
class DocumentMetadata {
  const DocumentMetadata({
    this.title,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.appId,
    this.appVersion,
    this.custom = const <String, dynamic>{},
  });

  final String? title;
  final String? description;

  /// Milliseconds since epoch, or null when unset.
  final int? createdAt;
  final int? updatedAt;

  /// Identifier of the application that produced the document.
  final String? appId;
  final String? appVersion;

  /// Free-form extension bag. Applications store domain-specific metadata here
  /// (project id, board owner, etc.) without forking the document format.
  final Map<String, dynamic> custom;

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (appId != null) 'appId': appId,
      if (appVersion != null) 'appVersion': appVersion,
      if (custom.isNotEmpty) 'custom': custom,
    };
  }

  static DocumentMetadata fromJson(Map<String, dynamic> json) {
    final custom = json['custom'];
    return DocumentMetadata(
      title: json['title'] as String?,
      description: json['description'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      appId: json['appId'] as String?,
      appVersion: json['appVersion'] as String?,
      custom: custom is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(custom)
          : custom is Map
              ? Map<String, dynamic>.unmodifiable(
                  custom.map((k, v) => MapEntry(k.toString(), v)),
                )
              : const <String, dynamic>{},
    );
  }

  DocumentMetadata copyWith({
    String? title,
    String? description,
    int? createdAt,
    int? updatedAt,
    String? appId,
    String? appVersion,
    Map<String, dynamic>? custom,
  }) {
    return DocumentMetadata(
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      appId: appId ?? this.appId,
      appVersion: appVersion ?? this.appVersion,
      custom: custom ?? this.custom,
    );
  }
}

/// Last-known viewport of the document, so a reopened board lands where the
/// user left it. All fields optional.
@immutable
class DocumentViewport {
  const DocumentViewport({this.scale, this.centerX, this.centerY});

  final double? scale;
  final double? centerX;
  final double? centerY;

  bool get isEmpty => scale == null && centerX == null && centerY == null;

  Map<String, dynamic> toJson() {
    return {
      if (scale != null) 'scale': scale,
      if (centerX != null) 'centerX': centerX,
      if (centerY != null) 'centerY': centerY,
    };
  }

  static DocumentViewport fromJson(Map<String, dynamic> json) {
    return DocumentViewport(
      scale: (json['scale'] as num?)?.toDouble(),
      centerX: (json['centerX'] as num?)?.toDouble(),
      centerY: (json['centerY'] as num?)?.toDouble(),
    );
  }
}

/// A binary asset referenced by elements but stored out-of-line from the
/// element list (typically an image). Decoupling assets from elements keeps
/// documents small when the raster lives on a CDN or filesystem.
@immutable
class DocumentAsset {
  const DocumentAsset({
    required this.id,
    required this.type,
    required this.source,
    this.ref,
    this.width,
    this.height,
    this.custom = const <String, dynamic>{},
  });

  /// Stable id referenced by elements (e.g. `ImageElement.assetId`).
  final String id;

  /// Discriminator for the asset kind. Currently `'image'`; reserved for
  /// future kinds (audio, video, …).
  final String type;

  /// How [ref] should be resolved: `'base64'`, `'url'`, `'file'`, or a custom
  /// kind matched by a host-supplied [ImageLoader].
  final String source;

  /// The actual locator: a base64 string, a URL, a file path, or a custom key.
  final String? ref;

  /// Natural dimensions when known, in pixels.
  final double? width;
  final double? height;

  final Map<String, dynamic> custom;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'source': source,
      if (ref != null) 'ref': ref,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (custom.isNotEmpty) 'custom': custom,
    };
  }

  static DocumentAsset fromJson(Map<String, dynamic> json) {
    final custom = json['custom'];
    return DocumentAsset(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      source: json['source'] as String? ?? 'base64',
      ref: json['ref'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      custom: custom is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(custom)
          : custom is Map
              ? Map<String, dynamic>.unmodifiable(
                  custom.map((k, v) => MapEntry(k.toString(), v)),
                )
              : const <String, dynamic>{},
    );
  }
}

/// A complete, serializable canvas document.
///
/// The shape is forward-compatible: unknown top-level keys are preserved
/// round-trip via [CanvasDocument extras], and elements whose type the loader
/// does not recognize are kept as [UnknownElement] instead of being silently
/// dropped or coerced.
class CanvasDocument {
  const CanvasDocument({
    this.schemaVersion = DocumentSchema.current,
    this.metadata = const DocumentMetadata(),
    this.viewport = const DocumentViewport(),
    this.assets = const <DocumentAsset>[],
    this.layers = const <CanvasLayer>[],
    this.elements = const <CanvasElement>[],
    this.extras = const <String, dynamic>{},
  });

  final String schemaVersion;
  final DocumentMetadata metadata;
  final DocumentViewport viewport;
  final List<DocumentAsset> assets;
  final List<CanvasLayer> layers;
  final List<CanvasElement> elements;

  /// Top-level keys the loader did not recognize, preserved verbatim so a
  /// document written by a newer app is not corrupted when opened by an older
  /// one and re-saved.
  final Map<String, dynamic> extras;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'metadata': metadata.toJson(),
      if (!viewport.isEmpty) 'viewport': viewport.toJson(),
      if (assets.isNotEmpty)
        'assets': [for (final asset in assets) asset.toJson()],
      'layers': [for (final layer in layers) layer.toJson()],
      'elements': [for (final element in elements) element.toJson()],
      ...extras,
    };
  }
}
