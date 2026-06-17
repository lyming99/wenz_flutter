import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Where an [ImageElement]'s raster data physically lives.
///
/// A single image source is described by exactly one of these fields. The
/// [ImageLoaderRegistry] dispatches to the first registered loader whose
/// [ImageLoader.supports] returns true for the source.
@immutable
class ImageSource {
  const ImageSource({
    this.base64,
    this.url,
    this.filePath,
    this.assetId,
    this.bytes,
    this.maxWidth,
  });

  /// Base64-encoded image bytes (with or without a `data:` prefix).
  final String? base64;

  /// A remote HTTP(S) URL.
  final String? url;

  /// An absolute path to a file on the local filesystem.
  final String? filePath;

  /// A reference into the document's asset manifest (see `CanvasDocument.assets`).
  final String? assetId;

  /// Raw, already-decoded image bytes.
  final Uint8List? bytes;

  /// Optional cap on the decoded image's longest side. Loaders that support
  /// downsampling use this to avoid allocating huge textures for large photos.
  final double? maxWidth;

  /// Whether this source carries no usable reference at all.
  bool get isEmpty =>
      base64 == null &&
      url == null &&
      filePath == null &&
      assetId == null &&
      bytes == null;

  @override
  bool operator ==(Object other) =>
      other is ImageSource &&
      other.base64 == base64 &&
      other.url == url &&
      other.filePath == filePath &&
      other.assetId == assetId &&
      other.bytes == bytes &&
      other.maxWidth == maxWidth;

  @override
  int get hashCode => Object.hash(
    base64,
    url,
    filePath,
    assetId,
    bytes,
    maxWidth,
  );
}

/// Decodes an [ImageSource] into a GPU-ready [ui.Image].
///
/// Built-in loaders exist for base64 strings and raw bytes. Applications that
/// fetch images from their own backend (an OSS bucket, a database, a signed
/// CDN, the local filesystem) implement this interface and register it for the
/// relevant source kind.
abstract class ImageLoader {
  const ImageLoader();

  /// Whether this loader can resolve and decode [source].
  bool supports(ImageSource source);

  /// Decode [source] into a [ui.Image]. The returned image is owned by the
  /// caller and must be [ui.Image.dispose]d when no longer needed.
  Future<ui.Image> load(ImageSource source);
}

/// Registry that maps [ImageSource] shapes to [ImageLoader]s.
///
/// Lookups consult loaders in registration order and return the first match.
/// Built-in loaders for base64 strings and raw bytes are installed lazily on
/// first use via [ensureBuiltInsRegistered]. Hosts add their own loaders
/// (network, file, custom backends) by calling [register].
class ImageLoaderRegistry {
  ImageLoaderRegistry._();

  /// Creates a fresh, isolated registry for testing. Built-in loaders are not
  /// installed automatically — call [ensureBuiltInsRegistered] if needed.
  @visibleForTesting
  ImageLoaderRegistry.forTesting();

  static final ImageLoaderRegistry instance = ImageLoaderRegistry._();

  final List<_LoaderEntry> _loaders = [];
  final Map<ImageSource, _CachedImage> _cache = {};
  bool _builtInsRegistered = false;

  /// Registers [loader] so it is consulted for sources it [supports].
  ///
  /// Loaders registered earlier take precedence. To override a built-in loader,
  /// register the replacement before any lookup occurs (or call [clear]).
  void register(ImageLoader loader, {String? debugName}) {
    _loaders.add(_LoaderEntry(loader, debugName ?? loader.runtimeType.toString()));
  }

  /// Removes the first registered loader equal to [loader].
  void unregister(ImageLoader loader) {
    _loaders.removeWhere((entry) => entry.loader == loader);
  }

  /// Clears every registered loader, including built-ins.
  void clear() {
    for (final cached in _cache.values) {
      cached.image.dispose();
    }
    _cache.clear();
    _loaders.clear();
    _builtInsRegistered = false;
  }

  /// Returns the decoded image for [source], caching the result so repeated
  /// lookups for the same source are cheap. Returns null when no loader
  /// [supports] the source.
  Future<ui.Image?> load(ImageSource source) async {
    if (source.isEmpty) return null;
    ensureBuiltInsRegistered();

    final cached = _cache[source];
    if (cached != null) return cached.image;

    for (final entry in _loaders) {
      if (entry.loader.supports(source)) {
        try {
          final image = await entry.loader.load(source);
          _cache[source] = _CachedImage(image);
          return image;
        } on Object {
          // A failed decode is not cached: a later retry may succeed.
          return null;
        }
      }
    }
    return null;
  }

  /// Drops the cached entry for [source] and disposes its image. Safe to call
  /// when a source's backing data has changed.
  void evict(ImageSource source) {
    final cached = _cache.remove(source);
    cached?.image.dispose();
  }

  /// Installs the platform-agnostic built-in loaders (base64, raw bytes) if
  /// they have not been installed yet. Network-URL and file-path loaders are
  /// intentionally omitted — fetching over HTTP or reading the filesystem
  /// needs `dart:io`, which is unavailable on the web, so hosts register their
  /// own [ImageLoader] for those sources. Idempotent.
  void ensureBuiltInsRegistered() {
    if (_builtInsRegistered) return;
    _builtInsRegistered = true;
    register(_Base64ImageLoader(), debugName: 'base64');
    register(_RawBytesImageLoader(), debugName: 'bytes');
  }
}

class _LoaderEntry {
  const _LoaderEntry(this.loader, this.debugName);

  final ImageLoader loader;
  final String debugName;
}

class _CachedImage {
  _CachedImage(this.image);

  final ui.Image image;
}

// ── Built-in loaders ────────────────────────────────────────────────────────

class _Base64ImageLoader extends ImageLoader {
  @override
  bool supports(ImageSource source) => source.base64 != null;

  @override
  Future<ui.Image> load(ImageSource source) {
    return _decodeBase64(source.base64!, maxWidth: source.maxWidth);
  }
}

class _RawBytesImageLoader extends ImageLoader {
  @override
  bool supports(ImageSource source) => source.bytes != null;

  @override
  Future<ui.Image> load(ImageSource source) {
    return _decodeBytes(source.bytes!, maxWidth: source.maxWidth);
  }
}

Future<ui.Image> _decodeBase64(String data, {double? maxWidth}) {
  final stripped = data.startsWith('data:')
      ? data.substring(data.indexOf(',') + 1)
      : data;
  final bytes = Uint8List.fromList(base64.decode(stripped));
  return _decodeBytes(bytes, maxWidth: maxWidth);
}

Future<ui.Image> _decodeBytes(Uint8List bytes, {double? maxWidth}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final targetWidth = maxWidth == null
        ? null
        : (descriptor.width > maxWidth ? maxWidth.round() : null);
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
