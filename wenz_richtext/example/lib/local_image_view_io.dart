import 'dart:io';

import 'package:flutter/widgets.dart';

Widget? buildLocalImageView(String source) {
  final file = _fileFromLocalSource(source.trim());
  if (file == null) {
    return null;
  }
  return Image.file(
    file,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => const SizedBox(
      height: 80,
      child: Center(child: Text('⚠ local image load failed')),
    ),
  );
}

File? _fileFromLocalSource(String source) {
  if (source.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(source);
  final isWindowsPath = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source);
  if (uri != null &&
      uri.hasScheme &&
      uri.scheme != 'file' &&
      !isWindowsPath) {
    return null;
  }
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri);
  }
  return File(source);
}
