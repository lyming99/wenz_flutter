import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';
import 'package:wenz_editor/commons/util/web/index.dart';
import 'package:ydart/ydart.dart';

import '../../editor/block/element/element.dart';
import '../../editor/block/image/image_element.dart';
import '../../editor/crdt/doc_utils.dart';
import 'file_manager.dart';

final copyService = CopyService();

typedef CopyCacheReader = Future<String> Function();
typedef CopyCacheWriter = Future<void> Function(String);

class CopyService {
  String? copyId;
  List<WenElement>? _copyElements;
  CopyCacheReader? copyCacheReader;
  CopyCacheWriter? copyCacheWriter;

  String generateCopyId() {
    return const Uuid().v1();
  }

  List<WenElement>? get copyElements {
    return _cloneCopyElements();
  }

  List<WenElement>? _cloneCopyElements() {
    var elements = _copyElements;
    if (elements != null) {
      var result = <WenElement>[];
      for (var element in elements) {
        result.add(WenElement.parseJson(element.toJson()));
      }
      return result;
    }
    return null;
  }

  Future<void> saveCopyCache(List<WenElement> elements,
      {String? copyId, String? copyCacheDir}) async {
    copyId ??= const Uuid().v1();
    this.copyId = copyId;
    _copyElements = elements;
    var copyContent = elements.map((e) => e.toJson()).toList();
    var map = {
      "copyId": copyId,
      "copyContent": jsonEncode(copyContent),
    };
    var saveJson = jsonEncode(map);
    if (copyCacheWriter != null) {
      await copyCacheWriter!(saveJson);
    } else {
      if (kIsWeb) {
        writeLocalStorage("copyCache", saveJson);
      } else {
        var document = await getApplicationDocumentsDirectory();
        copyCacheDir ??= document.path;
        await File("$copyCacheDir/copyCache").writeAsString(saveJson);
      }
    }
  }

  Future<void> readCopyCache(String copyCacheDir) async {
    String? saveJson;
    if (copyCacheReader != null) {
      saveJson = await copyCacheReader!();
    } else {
      if (kIsWeb) {
        saveJson = readLocalStorage("copyCache");
      } else {
        if (File("$copyCacheDir/copyCache").existsSync()) {
          saveJson = await File("$copyCacheDir/copyCache").readAsString();
        }
      }
    }
    if (saveJson != null) {
      Map content = jsonDecode(saveJson);
      copyId = content["copyId"];
      var copyContent = content["copyContent"] as String?;
      if (copyContent != null) {
        var copyElement = jsonDecode(copyContent) as List<dynamic>?;
        _copyElements =
            copyElement?.map((e) => WenElement.parseJson(e)).toList();
      }
    }
  }

  Future<void> copyDocContent(
      BuildContext context, YDoc? doc, String copyCacheDir) async {
    var copyId = generateCopyId();
    StringBuffer html = StringBuffer();
    html.writeln("<!DOCTYPE html>\n"
        "<html>\n<head>\n"
        "<meta charset=\"utf-8\"></meta></head><body copyid='$copyId'>");
    StringBuffer text = StringBuffer();
    var copyElements = yDocToWenElements(doc);
    this.copyId = copyId;
    await saveCopyCache(copyElements,
        copyId: copyId, copyCacheDir: copyCacheDir);
    for (var element in copyElements) {
      text.writeln(element.getText());
      html.writeln(element.getHtml());
    }
    html.writeln("</body>");
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.htmlText(html.toString()));
    item.add(Formats.plainText(text.toString()));
    await clipboard.write([item]);
  }

  Future<void> copyMarkdownContent(
      YDoc? doc, WenzAssetsFileManager fileManager) async {
    StringBuffer markdown = StringBuffer();
    var copyElements = yDocToWenElements(doc);
    for (var element in copyElements) {
      var filePath = "";
      if (element is WenImageElement) {
        var imageId = element.id;
        var info = await fileManager.getFileInfo(imageId);
        filePath = info?.path ?? "";
      }
      markdown.writeln(element.getMarkDown(filePathBuilder: (uuid) {
        return filePath;
      }));
    }
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.plainText(markdown.toString()));
    await clipboard.write([item]);
  }

  Future<void> copyWenElements(List<WenElement> copyElements,
      [bool copyPlanText = false]) async {
    var copyId = generateCopyId();
    StringBuffer html = StringBuffer();
    html.writeln("<!DOCTYPE html>\n"
        "<html>\n<head>\n"
        "<meta charset=\"utf-8\"></meta></head><body copyid='$copyId'>");
    StringBuffer text = StringBuffer();
    this.copyId = copyId;
    await saveCopyCache(
      copyElements,
      copyId: copyId,
    );
    for (var element in copyElements) {
      text.writeln(element.getText());
      html.writeln(element.getHtml());
    }
    html.writeln("</body>");

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    if (!copyPlanText) {
      item.add(Formats.htmlText(html.toString()));
    }
    item.add(Formats.plainText(text.toString()));
    await clipboard.write([item]);
  }
}
