import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class FileUtils {
  FileUtils._();
  /// 删除文件，如果文件不存在则忽略
  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 删除文件，如果文件不存在则忽略
  static void deleteFileSync(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  static Future deleteDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static void openFile(String fileFolder) async {
    openFolder(fileFolder);
  }

  static void openFolder(String fileFolder) async {
    String encodedPath = Uri.encodeComponent(fileFolder);
    if (Platform.isWindows) {
      await Process.run('explorer', [fileFolder.replaceAll("/", "\\")]);
    } else {
      final Uri url =
          Uri.parse('file:///${encodedPath.replaceAll(' ', '%20')}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        print('无法打开文件夹:$fileFolder');
      }
    }
  }

  static void copyDirectorySync(Directory source, Directory destination) {
    /// create destination folder if not exist
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    /// get all files from source (recursive: false is important here)
    source.listSync(recursive: false).forEach((entity) {
      final newPath = destination.path +
          Platform.pathSeparator +
          path.basename(entity.path);
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        copyDirectorySync(entity, Directory(newPath));
      }
    });
  }

  static Future<void> copyDirectory(
      Directory source, Directory destination) async {
    /// create destination folder if not exist
    if (!destination.existsSync()) {
      await destination.create(recursive: true);
    }

    /// get all files from source (recursive: false is important here)
    var list = source.listSync(recursive: false);
    for (var entity in list) {
      final newPath = destination.path +
          Platform.pathSeparator +
          path.basename(entity.path);
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await copyDirectory(entity, Directory(newPath));
      }
    }
  }

  static String getFileSuffix(String file) {
    var index = file.lastIndexOf(".");
    if (index != -1) {
      return file.substring(index);
    }
    return "";
  }

  static String getFileName(String file) {
    file = file.replaceAll("\\\\", "/");
    var index = file.lastIndexOf("/");
    if (index != -1) {
      return file.substring(index + 1);
    }
    return file;
  }

  static String getFileType(String file) {
    var lower = file.toLowerCase();
    var suffix = getFileSuffix(lower);
    if (suffix.endsWith("png") ||
        suffix.endsWith("jpg") ||
        suffix.endsWith("jpeg") ||
        suffix.endsWith("gif") ||
        suffix.endsWith("webp")) {
      return "image";
    }
    return suffix;
  }

  static void openSystemFile(String fileFolder) async {
    openSystemFolder(fileFolder);
  }

  static void openSystemFolder(String fileFolder) async {
    String encodedPath = Uri.encodeComponent(fileFolder);
    if (Platform.isWindows) {
      await Process.run('explorer', [fileFolder.replaceAll("/", "\\")]);
    } else {
      final Uri url =
          Uri.parse('file:///${encodedPath.replaceAll(' ', '%20')}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        print('无法打开文件夹:$fileFolder');
      }
    }
  }
}
