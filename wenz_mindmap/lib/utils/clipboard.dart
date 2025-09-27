import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:wenz_editor/commons/service/copy_service.dart';
import 'package:wenz_editor/commons/service/file_manager.dart';
import 'package:wenz_editor/commons/util/html/html.dart';
import 'package:wenz_editor/commons/util/image.dart';
import 'package:wenz_editor/commons/util/markdown/markdown.dart';
import 'package:wenz_editor/editor/block/element/element.dart';
import 'package:wenz_editor/editor/block/image/image_element.dart';
import 'package:wenz_editor/editor/block/text/text.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:wenz_ui/utils/device_util.dart';

import '../data/index.dart';

int getTabCount(String text) {
  for (var i = 0; i < text.length; i++) {
    if (text[i] != "\t") {
      return i;
    }
  }
  return 0;
}

MindNode? getParentNode(List<MindNode> nodes, int tabCount) {
  for (var i = nodes.length - 1; i >= 0; i--) {
    var item = nodes[i];
    if ((item.getProperty("tabCount") ?? item.depth) < tabCount) {
      return item;
    }
  }
  return null;
}

Future<List<MindNode>> readTextClipboard([String? text]) async {
  text = text ?? (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (text == null) {
    return [];
  }
  var lines = text.split("\n");
  var result = <MindNode>[];
  var nodes = <MindNode>[];
  for (var line in lines) {
    if (line.isEmpty) {
      continue;
    }
    var tabCount = getTabCount(line);
    var parent = getParentNode(nodes, tabCount);
    var node = MindNode(info: MindNodeInfo(content: line.substring(tabCount)))
      ..setProperty("tabCount", tabCount);
    nodes.add(node);
    if (parent == null) {
      result.add(node);
    } else {
      parent.addNodeToChildren(node);
    }
  }
  return result;
}

Future<void> writeTextClipboard(List<MindNode> nodes) async {
  StringBuffer result = StringBuffer();
  for (var node in nodes) {
    node.getText(result);
  }
  if (result.isNotEmpty) {
    var text = result.toString();
    Clipboard.setData(ClipboardData(text: text));
  }
}

Future<void> writeRichClipboard(
  List<MindNode> nodes, {
  required WenzAssetsFileManager fileManager,
  required CopyService copyService,
}) async {
  var elements = <WenElement>[];
  for (var item in nodes) {
    for (var node in item.getNodeList()) {
      var element = await nodeToElement(node, fileManager);
      if (element == null) {
        continue;
      }
      elements.add(element);
    }
  }
  copyService.copyWenElements(elements);
}

/// 将思维导图转换为富文本，方便复制粘贴
/// 1.文字✅
/// 2.待办✅
/// 3.图片(单独格式)✅
/// 4.公式(单独格式)✅
/// 5.子笔记✅
/// 6.缩进&标题
Future<WenElement?> nodeToElement(
  MindNode node,
  WenzAssetsFileManager fileManager,
) async {
  // 如果小于等于6，转换为 h
  // 否则，转换为indent + text
  if (node.isImage) {
    var imageFile = await fileManager.getFileInfo(node.info?.image ?? '');
    if (imageFile == null) {
      return null;
    }
    return WenImageElement(
      width: node.info?.imageWidth ?? 0,
      height: node.info?.imageHeight ?? 0,
      id: node.info?.image ?? "",
      file: imageFile.path ?? '',
      checked: node.info?.isChecked,
      childNote: node.info?.note,
    );
  } else if (node.isFormula) {
    return WenTextElement(
      itemType: node.isTodo ? "check" : "text",
      checked: node.info?.isChecked,
      childNote: node.info?.note,
      children: [WenTextElement(itemType: "formula", text: node.info?.formula)],
    );
  }
  var level = 0;
  var indent = 0;
  if (node.depth < 6) {
    level = node.depth + 1;
  } else {
    level = 0;
    indent = node.depth - 6;
  }
  return WenTextElement(
    itemType: node.isTodo ? "check" : "text",
    checked: node.info?.isChecked,
    text: node.info?.content,
    level: level,
    indent: indent,
    childNote: node.info?.note,
  );
}

/// 读取剪切板，生成富文本
/// 1.文本解析 ✅
/// 2.markdown解析 ✅
/// 3.html解析（富文本）
/// 4.图片解析 ✅
/// 5.文件解析 ❌
Future<List<MindNode>> readRichClipboard({
  required BuildContext context,
  required WenzAssetsFileManager fileManager,
  bool pasteText = false,
  bool pasteHtml = false,
  bool pasteMarkdown = false,
}) async {
  // 文字解析
  if (pasteText) {
    return readTextClipboard();
  }

  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return []; // Clipboard API is not supported on this platform.
  }
  final reader = await clipboard.read();
  String? text;
  String? html;
  if (reader.canProvide(Formats.htmlText)) {
    html = await reader.readValue(Formats.htmlText);
    // .. do something with the HTML text
  }
  if (reader.canProvide(Formats.plainText)) {
    try {
      text = await reader.readValue(Formats.plainText);
    } catch (e) {
      print(e);
      text = await Pasteboard.text;
    }
    // Do something with the plain text
  }
  Uint8List? image;
  if (!isMobile) {
    image = await Pasteboard.image;
  }
  // markdown解析
  if (pasteMarkdown) {
    var elements = await parseMarkdown(fileManager, text ?? "");
    return await elementsToNodes(elements, fileManager);
  }
  // 图片解析
  if (image != null) {
    var imageFile = await fileManager.writeImage(image);
    var path = imageFile?.path;

    if (imageFile != null && path != null) {
      var size = await readImageFileSize(File(path));
      return [
        MindNode(
          info: MindNodeInfo(
            image: imageFile.path,
            imageWidth: size.width,
            imageHeight: size.height,
          ),
        ),
      ];
    }
  }
  // 文字解析
  if (html == null) {
    return readTextClipboard(text);
  }
  // 富文本解析
  var elements = await parseCopyIdElement(
    context: context,
    copyService: copyService,
    fileManager: fileManager,
    html: html,
  );
  elements ??= await parseHtmlToBlockElement(context, html, fileManager);
  return await elementsToNodes(elements, fileManager);
  // 文件解析
}

/// 将elements转换为思维导图节点
/// 1.element转换 ✅
/// 2.构建树 ✅
Future<List<MindNode>> elementsToNodes(
  List<WenElement> elements,
  WenzAssetsFileManager fileManager,
) async {
  var nodes = <MindNode>[];
  for (var item in elements) {
    var node = await elementToNode(item, fileManager);
    if (node != null) {
      nodes.add(node);
    }
  }
  var previous = <MindNode>[];
  var roots = <MindNode>[];
  for (var item in nodes) {
    var parent = getParentNode(previous, item.depth);
    if (parent == null) {
      roots.add(item);
    } else {
      parent.addNodeToChildren(item);
    }
    previous.add(item);
  }
  return roots;
}

/// 将富文本转换为思维导图节点
/// 1.level识别
/// 2.indent识别
/// 3.图片 ✅
/// 4.公式 ❌
/// 5.待办 ✅
/// 6.子笔记 ❌
Future<MindNode?> elementToNode(
  WenElement element,
  WenzAssetsFileManager fileManager,
) async {
  var level = element.level;
  var indent = element.indent;
  if (level == 0) {
    level = 7 + (indent ?? 0);
  }
  if (element is WenTextElement) {
    // 文字、公式、待办、子笔记
    // 计算公式 size 存在问题
    // var first = element.children?.first;
    // String? formula;
    // if (first?.itemType == "formula") {
    //   formula = first?.text;
    // }
    return MindNode(
      depth: level,
      info: MindNodeInfo(
        content: element.getText(),
        isTodo: element.itemType == "check",
        isChecked: element.checked,
        note: element.childNote,
      ),
    );
  }
  if (element is WenImageElement) {
    return MindNode(
      depth: level,
      info: MindNodeInfo(
        image: element.id,
        imageWidth: element.width,
        imageHeight: element.height,
        imageShowWidth: element.width.toDouble() / 2,
        imageShowHeight: element.height.toDouble() / 2,
        isChecked: element.checked,
        note: element.childNote,
      ),
    );
  }
  return null;
}
