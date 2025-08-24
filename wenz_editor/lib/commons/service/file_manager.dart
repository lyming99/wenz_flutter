import 'dart:async';
import 'dart:convert';
import 'dart:io';
import "dart:ui" as ui show Image, ImageByteFormat;

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../commons/util/image.dart';
import '../entity/wenz_file.dart';
import '../util/file_utils.dart';

class DirectoryFileManager extends WenzFileManager {
  DirectoryFileManager({
    required this.rootDir,
    required super.uploadFileCallback,
    required super.downloadFileCallback,
    required super.docId,
    required super.noteId,
  });

  final String rootDir;

  @override
  Future<String> getRootDir() async {
    return rootDir;
  }
}

class WenzFileManager {
  Future Function(
          String fileId, String filePath, String? docId, String? noteId)?
      uploadFileCallback;
  Future Function(
          String fileId, String filePath, String? docId, String? noteId)?
      downloadFileCallback;
  String? docId;
  String? noteId;
  Future<String> Function()? getRootDirFunction;

  WenzFileManager({
    required this.uploadFileCallback,
    required this.downloadFileCallback,
    required this.docId,
    required this.noteId,
    this.getRootDirFunction,
  });

  String createUuid() {
    var uuid = const Uuid();
    return uuid.v1();
  }

  Future uploadFile(String fileId, String filePath) async {
    await uploadFileCallback?.call(fileId, filePath, docId, noteId);
  }

  Future downloadFile(String fileId, String savePath) async {
    await downloadFileCallback?.call(fileId, savePath, docId, noteId);
  }

  Future<WenzFile?> writeImage(
    Uint8List image, {
    String suffix = ".png",
  }) async {
    var id = createUuid();
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
      return WenzFile(path: savePath, uuid: id);
    }
    return null;
  }

  Future<WenzFile?> writeImageFile(String filepath) async {
    var id = createUuid();
    var filename = FileUtils.getFileName(filepath);
    var savePath = await getAssetFilePath(
      id,
      id + FileUtils.getFileSuffix(filename),
      null,
    );
    File(filepath).copySync(savePath);
    uploadFile(id, savePath);
    return WenzFile(path: filepath, uuid: id);
  }

  Future<String?> getImageFile(String? id) async {
    try {
      if (id == null) {
        return null;
      }
      String imageFile = await getOldImageFile(id);
      if (File(imageFile).existsSync()) {
        var fileItem = await writeImageFile(imageFile);
        if (fileItem == null) {
          return null;
        }
        return getAssetFilePath(fileItem.uuid, fileItem.name, null);
      }
      var assetFile = await getAssetFilePath(id, null, ".png");

      if (!File(assetFile).existsSync()) {
        await downloadFile(id, assetFile);
      }
      return assetFile;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<String> getOldImageFile(String? id) async {
    var imageDir = await getImageDir();
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

  Future<WenzFile?> downloadImageFile(String file) async {
    if (File(file).existsSync()) {
      return writeImageFile(file);
    } else if (file.startsWith("http")) {
      var downloadDir = await getDownloadDir();
      if (!Directory(downloadDir).existsSync()) {
        Directory(downloadDir).createSync(recursive: true);
      }

      var saveFile = "$downloadDir/${Uuid().v1()}.png";
      if (file.endsWith(".jpg")) {
        saveFile = "$downloadDir/${Uuid().v1()}.png";
      }
      if (file.endsWith(".webp")) {
        saveFile = "$downloadDir/${Uuid().v1()}.webp";
      }
      if (file.endsWith(".jpg")) {
        saveFile = "$downloadDir/${Uuid().v1()}.jpg";
      }
      if (file.endsWith(".gif")) {
        saveFile = "$downloadDir/${Uuid().v1()}.gif";
      }
      var get =
          await Dio(BaseOptions(connectTimeout: const Duration(seconds: 1)))
              .get(file,
                  options: Options(
                    responseType: ResponseType.bytes,
                    followRedirects: false,
                  ));
      if (get.statusCode == 200) {
        File(saveFile).writeAsBytesSync(get.data);
        return writeImageFile(saveFile);
      }
    }
    return null;
  }

  Future<String> getRootDir() async {
    if (getRootDirFunction != null) {
      return getRootDirFunction!.call();
    }
    if (Platform.isWindows) {
      return getExePath();
    }
    var document = (await getApplicationDocumentsDirectory()).path;
    if (Platform.isMacOS) {
      await Directory("$document/WenzDoc").create(recursive: true);
      return "$document/WenzDoc";
    }
    return document;
  }

  /// 获取软件数据存储路径，这个路径可以配置
  Future<String> getSaveDir() async {
    var defaultRootDir = await getRootDir();
    var configFile = "$defaultRootDir/config.json";
    if (File(configFile).existsSync()) {
      var configContent = await File(configFile).readAsString();
      if (configContent.isNotEmpty) {
        var rootDir = jsonDecode(configContent)['rootDir'] as String?;
        if (rootDir != null && rootDir.isNotEmpty) {
          return rootDir;
        }
      }
    }
    return defaultRootDir;
  }

  /// 设置软件数据存储路径
  Future<void> setSaveDir(String path) async {
    // 将rootDir中的文件全部转移过去
    if (!Directory(path).existsSync()) {
      return;
    }
    // 写入配置
    var currentRootDir = await getSaveDir();
    await FileUtils.copyDirectory(Directory(currentRootDir), Directory(path));
    var defaultRootDir = await getRootDir();
    if (!Directory(defaultRootDir).existsSync()) {
      Directory(defaultRootDir).createSync(recursive: true);
    }
    var configFile = "$defaultRootDir/config.json";
    Map configMap = {};
    if (File(configFile).existsSync()) {
      var configContent = await File(configFile).readAsString();
      if (configContent.isNotEmpty) {
        configMap = jsonDecode(configContent) as Map;
      }
    }
    configMap['rootDir'] = path;
    var saveConfig = jsonEncode(configMap);
    File(configFile).writeAsStringSync(saveConfig);
  }

  String getExePath() {
    var exe = Platform.executable.replaceAll("\\", "/").replaceAll("\\\\", "/");
    int i = exe.lastIndexOf("/");
    if (i == -1) {
      return ".";
    }
    return exe.substring(0, i);
  }

  Future<String> getDocDir() async {
    var dir = await getSaveDir();
    return "$dir/notes";
  }

  Future<String> getImageDir() async {
    var dir = await getSaveDir();
    return "$dir/images";
  }

  Future<String> getAssetsDir() async {
    var dir = await getSaveDir();
    return "$dir/assets";
  }

  Future<String> getDownloadDir() async {
    var dir = await getSaveDir();
    return "$dir/download";
  }

  Future<List<FileSystemEntity>> get docFileList async {
    var docDir = await getDocDir();
    return Directory(docDir).listSync();
  }

  Future<List<FileSystemEntity>> get imageFileList async {
    var dir = await getImageDir();
    return Directory(dir).listSync();
  }

  Future<String> getAndCreateSaveDir() async {
    var docDir = await getSaveDir();
    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    return docDir;
  }

  Future<String> readDocFileJsonContent(String uuid) async {
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.json";
    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    if (!File(docFile).existsSync()) {
      File(docFile).createSync();
    }
    return File(docFile).readAsStringSync();
  }

  Future<List> readDocFileContent(String uuid) async {
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.wennote";
    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    if (!File(docFile).existsSync()) {
      var content = await readDocFileJsonContent(uuid);
      if (content.isNotEmpty) {
        return jsonDecode(content) as List;
      }
      return [];
    }
    var buff = await File(docFile).readAsBytes();
    if (buff.isEmpty) {
      return [];
    }
    var unzipBuff = GZipDecoder().decodeBytes(buff);
    var str = utf8.decode(unzipBuff);
    if (str.isEmpty) {
      return [];
    }
    var result = jsonDecode(str) as List;
    return result;
  }

  Future<void> executeSaveThread(String uuid, List content) async {
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.wennote";

    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    if (!File(docFile).existsSync()) {
      File(docFile).createSync();
    }
    await _saveDocJsonFile(uuid, content);
  }

  Future<void> _saveDocJsonFile(String uuid, List content) async {
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.wennote";

    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    if (!File(docFile).existsSync()) {
      File(docFile).createSync();
    }
    var encode = jsonEncode(content);
    var saveBuff = GZipEncoder().encode(utf8.encode(encode));
    //100万文字估计会有很大的数据，可能需要压缩一下
    if (saveBuff != null) {
      File(docFile).writeAsBytesSync(saveBuff);
    }
  }

  Future<void> saveDocStringFile(String? uuid, String? content) async {
    if (uuid == null || content == null) {
      return;
    }
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.wennote";
    if (!Directory(docDir).existsSync()) {
      Directory(docDir).createSync(recursive: true);
    }
    if (!File(docFile).existsSync()) {
      File(docFile).createSync();
    }
    var saveBuff = GZipEncoder().encode(utf8.encode(content));
    //100万文字估计会有很大的数据，可能需要压缩一下
    if (saveBuff != null) {
      File(docFile).writeAsBytesSync(saveBuff);
    }
  }

  Future<void> lockExportAndImport() async {
    var docDir = await getDocDir();
    var af = File("$docDir/exportLock").openSync(mode: FileMode.write);
    af.lockSync();
  }

  Future<void> unlockExportAndImport() async {
    var docDir = await getDocDir();
    var af = File("$docDir/exportLock").openSync(mode: FileMode.write);
    af.unlockSync();
  }

  Future<void> deleteDoc(String? uuid) async {
    String docDir = await getDocDir();
    String docFile = "$docDir/$uuid.wennote";
    File(docFile).deleteSync();
  }

  Future<String> getAssetFilePath(
    String? dataId,
    String? name,
    String? extension,
  ) async {
    var assetsDir = await getAssetsDir();
    var fileDir = "$assetsDir/$dataId";
    if (!Directory(fileDir).existsSync()) {
      Directory(fileDir).createSync(recursive: true);
    }
    if (name == null) {
      if (Directory(fileDir).existsSync()) {
        try {
          var path = Directory(fileDir).listSync().firstOrNull?.path;
          if (path != null) {
            return path;
          }
        } catch (e) {
          print(e);
        }
      }
      return "$fileDir/$dataId$extension";
    }
    return "$fileDir/$name";
  }

  Future<String> getNoteDir() async {
    return getDocDir();
  }

  Future<String> getNoteFilePath(String docId) async {
    var noteDir = await getNoteDir();
    if (!await Directory(noteDir).exists()) {
      await Directory(noteDir).create(recursive: true);
    }
    return "$noteDir/$docId.wnote";
  }
}

class JsonContent {
  String uuid;
  List content;

  JsonContent({
    required this.uuid,
    required this.content,
  });
}

class ImageUtils {
  static Future<ui.Image> loadImageByProvider(
    ImageProvider provider, {
    ImageConfiguration config = ImageConfiguration.empty,
  }) async {
    Completer<ui.Image> completer = Completer<ui.Image>(); //完成的回调
    late ImageStreamListener listener;
    ImageStream stream = provider.resolve(config); //获取图片流
    listener = ImageStreamListener((ImageInfo frame, bool sync) {
      final ui.Image image = frame.image;
      completer.complete(image); //完成
      stream.removeListener(listener); //移除监听
    });
    stream.addListener(listener); //添加监听
    return completer.future; //返回
  }
}
