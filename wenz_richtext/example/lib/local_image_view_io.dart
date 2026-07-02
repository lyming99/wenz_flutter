import 'dart:io';

import 'package:flutter/material.dart';

const _localImagePreviewCacheExtent = 1600;
const _localImageStatusHeight = 120.0;

final _windowsDrivePathPattern = RegExp(r'^[a-zA-Z]:[\\/]');

/// Renders local image sources stored in `ImageBlockNode.file`.
///
/// The example writes toolbar-selected images as ordinary paths, while external
/// image paste/drop may produce temporary file paths or file:// URIs. All three
/// shapes resolve here so the media strategy stays consistent.
Widget? buildLocalImageView(String source) {
  final resolution = _resolveLocalImageSource(source.trim());
  final errorMessage = resolution.errorMessage;
  if (errorMessage != null) {
    return _LocalImageStatus.error(message: errorMessage);
  }
  final file = resolution.file;
  if (file == null) {
    return null;
  }
  return Image.file(
    file,
    cacheWidth: _localImagePreviewCacheExtent,
    cacheHeight: _localImagePreviewCacheExtent,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) {
        return child;
      }
      return const _LocalImageStatus.loading();
    },
    errorBuilder: (context, error, stackTrace) =>
        const _LocalImageStatus.error(message: '本地图片加载失败。'),
  );
}

_LocalImageResolution _resolveLocalImageSource(String source) {
  if (source.isEmpty) {
    return const _LocalImageResolution.fallback();
  }
  final File file;
  final uri = Uri.tryParse(source);
  final isWindowsPath = _windowsDrivePathPattern.hasMatch(source);
  if (uri != null && uri.hasScheme && !isWindowsPath) {
    if (uri.scheme != 'file') {
      return const _LocalImageResolution.error('不支持此图片路径。');
    }
    try {
      file = File.fromUri(uri);
    } catch (_) {
      return const _LocalImageResolution.error('无法读取本地图片路径。');
    }
  } else {
    file = File(source);
  }
  try {
    final type = FileSystemEntity.typeSync(file.path, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      return const _LocalImageResolution.error('本地图片文件不存在。');
    }
    if (type != FileSystemEntityType.file) {
      return const _LocalImageResolution.error('所选路径不是图片文件。');
    }
    if (file.lengthSync() <= 0) {
      return const _LocalImageResolution.error('本地图片文件为空。');
    }
  } catch (_) {
    return const _LocalImageResolution.error('无法访问本地图片文件。');
  }
  return _LocalImageResolution.file(file);
}

class _LocalImageResolution {
  const _LocalImageResolution.file(this.file) : errorMessage = null;

  const _LocalImageResolution.fallback()
      : file = null,
        errorMessage = null;

  const _LocalImageResolution.error(this.errorMessage) : file = null;

  final File? file;
  final String? errorMessage;
}

class _LocalImageStatus extends StatelessWidget {
  const _LocalImageStatus.loading()
      : message = '正在加载本地图片...',
        isLoading = true;

  const _LocalImageStatus.error({required this.message}) : isLoading = false;

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLoading
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.error;
    return SizedBox(
      height: _localImageStatusHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (isLoading)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(Icons.broken_image_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
