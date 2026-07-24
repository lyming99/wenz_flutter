import 'dart:io';

/// Returns whether [location] points to an accessible local file.
Future<bool> externalImageFileExists(String location) async {
  final uri = Uri.tryParse(location);
  final File file;
  if (uri != null && uri.scheme.toLowerCase() == 'file') {
    file = File.fromUri(uri);
  } else {
    file = File(location);
  }
  try {
    return await file.exists();
  } on FileSystemException {
    return false;
  } on ArgumentError {
    return false;
  }
}
