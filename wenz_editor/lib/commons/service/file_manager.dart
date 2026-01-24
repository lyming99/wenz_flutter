import 'dart:async';
import 'dart:io';
import "dart:ui" as ui show ImageByteFormat;

import 'package:dio/dio.dart';
import 'package:wenz_ui/utils/index.dart' hide readImageSize;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wenz_editor/commons/util/uuid_utils.dart';

import '../../commons/util/image.dart';
import '../entity/wenz_assets_file.dart';
import '../util/file_utils.dart';
import '../util/image_utils.dart';

abstract class WenzAssetsFileProvider {
  Future<WenzAssetsFile?> getFileInfo(String fileId);

  Future<Uint8List?> readFile(String fileId);

  Future<WenzAssetsFile?> createFile(String filename, Uint8List bytes);

  Future<WenzAssetsFile?> parseFile(String urlOrPath);
}

/// 用于读取附件文件或者用于doc模块读取笔记文件
class WenzAssetsFileManager extends WenzAssetsFileProvider {
  Map<String, dynamic>? documentInfo;

  WenzAssetsFileManager({this.documentInfo});

  Future<WenzAssetsFile?> _copyFile(String filepath) async {
    var id = UuidUtils.v1();
    var filename = FileUtils.getFileName(filepath);
    var savePath = await getAssetFilePath(
      id,
      id + FileUtils.getFileSuffix(filename),
      null,
    );
    await File(filepath).copy(savePath);
    await uploadFile(id, savePath);
    return WenzAssetsFile(path: savePath, uuid: id);
  }

  Future<String> _getOldImageFile(String? id) async {
    var dir = await getRootDir();
    var imageDir = "$dir/images";
    const types = [
      ".png",
      ".gif",
      ".jpg",
      ".jpeg",
      ".webp",
      "",
    ];
    var imageFile = "$imageDir/$id";
    for (var item in types) {
      if (File("$imageDir/$id$item").existsSync()) {
        imageFile = "$imageDir/$id$item";
        break;
      }
    }
    return imageFile;
  }

  /// 获取附件存储路径
  Future<String> getRootDir() async {
    if (Platform.isWindows) {
      return _getExePath();
    }
    // - `NSDocumentDirectory` on iOS and macOS.
    // - The Flutter engine's `PathUtils.getDataDirectory` API on Android.
    var document = (await getApplicationDocumentsDirectory()).path;
    if (PlatformUtils.isMacOS) {
      await Directory("$document/WenzDoc").create(recursive: true);
      return "$document/WenzDoc";
    }
    return document;
  }

  String _getExePath() {
    var exe = Platform.executable.replaceAll("\\", "/").replaceAll("\\\\", "/");
    int i = exe.lastIndexOf("/");
    if (i == -1) {
      return ".";
    }
    return exe.substring(0, i);
  }

  Future<String> getAssetsDir() async {
    var dir = await getRootDir();
    return "$dir/assets";
  }

  Future<String> getDownloadDir() async {
    var dir = await getRootDir();
    return "$dir/download";
  }

  Future<String> getAssetFilePath(String? dataId,
      String? name,
      String? extension,) async {
    var assetsDir = await getAssetsDir();
    var fileDir = "$assetsDir/$dataId";
    if (!Directory(fileDir).existsSync()) {
      Directory(fileDir).createSync(recursive: true);
    }
    if (name == null) {
      if (Directory(fileDir).existsSync()) {
        try {
          var path = Directory(fileDir)
              .listSync()
              .firstOrNull
              ?.path;
          if (path != null) {
            return path;
          }
        } catch (e) {
          print(e);
        }
      }
      return "$fileDir/$dataId${extension ?? ''}";
    }
    return "$fileDir/$name";
  }

  Future uploadFile(String fileId, String filePath) async {}

  Future<WenzAssetsFile?> downloadFile(String fileId) async {
    return null;
  }

  @override
  Future<WenzAssetsFile?> getFileInfo(String id) async {
    var assetFile = await getAssetFilePath(id, null, null);
    if (!File(assetFile).existsSync()) {
      String imageFile = await _getOldImageFile(id);
      if (File(imageFile).existsSync()) {
        var fileItem = await _copyFile(imageFile);
        if (fileItem == null) {
          return null;
        }
        return fileItem;
      }
      return await downloadFile(id);
    }
    return WenzAssetsFile(
      uuid: id,
      path: assetFile,
      size: File(assetFile).lengthSync(),
      createTime: File(assetFile)
          .lastModifiedSync()
          .millisecondsSinceEpoch,
      updateTime: File(assetFile)
          .lastModifiedSync()
          .millisecondsSinceEpoch,
    );
  }

  /// 适用于小内存读取文件，如图片
  /// 其它大文件应该用getFileInfo，直接通过path读取，例如视频文件
  @override
  Future<Uint8List?> readFile(String fileId) async {
    var info = await getFileInfo(fileId);
    if (info == null) {
      return null;
    }
    var path = info.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith("http")) {
      var get =
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 1)))
          .get(path,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
          ));
      if (get.statusCode == 200) {
        return get.data;
      }
      return null;
    }
    return await File(path).readAsBytes();
  }

  /// 直接通过二进制创建文件，会根据filename后缀创建uuid+后缀的附件
  @override
  Future<WenzAssetsFile?> createFile(String filename, Uint8List bytes) async {
    var id = UuidUtils.v1();
    var name = FileUtils.getFileName(filename);
    var savePath = await getAssetFilePath(
      id,
      id + FileUtils.getFileSuffix(name),
      null,
    );
    await File(savePath).writeAsBytes(bytes);
    uploadFile(id, savePath);
    return WenzAssetsFile(path: savePath, uuid: id, name: name);
  }

  /// 解析url或path，将路径下的文件复制到附件目录下
  @override
  Future<WenzAssetsFile?> parseFile(String urlOrPath) async {
    if (urlOrPath.isEmpty) {
      return null;
    }
    if (urlOrPath.startsWith("http")) {
      var downloadDir = await getDownloadDir();
      if (!Directory(downloadDir).existsSync()) {
        Directory(downloadDir).createSync(recursive: true);
      }
      var resp =
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 1)))
          .get(urlOrPath,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
          ));
      if (resp.statusCode == 200) {
        var urlPath = Uri
            .parse(urlOrPath)
            .path;
        var suffix = FileUtils.getFileSuffix(urlPath);
        if (suffix.isEmpty) {
          var contentDisposition = resp.headers["content-disposition"];
          if (contentDisposition != null && contentDisposition.isNotEmpty) {
            var index = contentDisposition.first.indexOf("filename=");
            if (index != -1) {
              var name = contentDisposition.first.substring(index + 9);
              if (name.startsWith("\"") && name.endsWith("\"")) {
                name = name.substring(1, name.length - 1);
              }
              suffix = FileUtils.getFileSuffix(name);
            }
          } else {
            //image/png
            var end = resp.headers["content-type"]?.first
                .split("/")
                .last ?? '';
            if (end.isNotEmpty) {
              suffix = ".$end";
            }
          }
        }
        var saveFile = "$downloadDir/${UuidUtils.v1()}$suffix";
        File(saveFile).writeAsBytesSync(resp.data);
        return _copyFile(saveFile);
      }
    } else {
      if (File(urlOrPath).existsSync()) {
        var ret =  _copyFile(urlOrPath);
        return ret;
      }
    }
    return null;
  }

  Future<WenzAssetsFile?> writeImage(Uint8List image, {
    String suffix = ".png",
  }) async {
    var id = UuidUtils.v1();
    var size = readImageSize(MemoryInput(image));
    var imageMemory = Image.memory(
      image,
      cacheWidth: size.width,
      cacheHeight: size.height,
    );
    var uiImage = await ImageUtils.loadImageByProvider(imageMemory.image);
    var bytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) {
      var savePath = await getAssetFilePath(
        id,
        id + suffix,
        suffix,
      );
      await File(savePath).writeAsBytes(bytes.buffer.asInt8List());
      uploadFile(id, savePath);
      return WenzAssetsFile(path: savePath, uuid: id);
    }
    return null;
  }
}
