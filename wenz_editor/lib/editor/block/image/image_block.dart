import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:bot_toast/bot_toast.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:wenz_editor/commons/util/file_utils.dart';
import 'package:wenz_editor/commons/util/image_utils.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/block/table/table_block.dart';
import 'package:wenz_editor/editor/widget/drag_resize_container.dart';
import 'package:wenz_editor/editor/widget/modal_widget.dart';
import 'package:octo_image/octo_image.dart';
import 'package:wenz_editor/editor/widget/popup/index.dart';

import '../../edit_controller.dart';
import '../block.dart';
import '../element/element.dart';
import '../text/text.dart';
import 'image_element.dart';
import 'multi_source_file_image.dart';

class ImageBlock extends WenzBlock {
  bool delete = false;
  double imageWidth = 0;
  double imageHeight = 0;
  double padding = 4;
  @override
  WenImageElement element;
  bool showPopup = false;

  ImageBlock({
    required super.context,
    required this.element,
    required super.editController,
  }) {
    readImageId();
  }

  void readImageId() async {
    if (kIsWeb) {
      return;
    }
    if (element.file == "" || !File(element.file).existsSync()) {
      var info = await editController.fileManager.getFileInfo(element.id);
      element.file = info?.path ?? '';
      relayoutFlag = true;
      editController.updateWidgetState();
    }
  }

  double calcIndentWidth() {
    if (calcAlignment() == Alignment.topLeft) {
      var width = indentWidth * (element.indent ?? 0);
      if (width > max(0, this.width - imageWidth - padding * 2)) {
        return max(0, this.width - imageWidth - padding * 2);
      }
      return width;
    }
    return 0;
  }

  bool get isSelected =>
      selected && selectedStart?.offset == 0 && selectedEnd?.offset == 1;

  @override
  Widget buildWidget(BuildContext context) {
    this.context = context;
    if (delete) {
      return Container(
        padding: EdgeInsets.all(padding),
      );
    }
    var alignment = calcAlignment();
    var offsetX = calcIndentWidth();
    return Container(
      padding: offsetX > 0 ? EdgeInsets.only(left: offsetX) : null,
      height: height,
      child: Stack(
        children: [
          Align(
            alignment: alignment,
            child: DragResizeContainer(
              strokeWidth: padding * 2,
              onResized: (dx, dy) {
                updateImageSize(dx, dy);
              },
              child: SizedBox(
                width: imageWidth,
                height: imageHeight,
                child: OctoImage(
                  key: Key(element.id),
                  fit: BoxFit.cover,
                  color: isSelected ? Colors.blueAccent.withOpacity(0.4) : null,
                  colorBlendMode: isSelected ? BlendMode.darken : null,
                  width: element.width.toDouble(),
                  height: element.height.toDouble(),
                  placeholderBuilder: (context) => Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: SizedBox(
                        width: min(100, min(width, height)),
                        height: min(100, min(width, height)),
                      ),
                    ),
                  ),
                  image: MultiSourceFileImage(
                      imageId: element.id,
                      reader: (id) async {
                        try {
                          var bytes =
                              await editController.fileManager.readFile(id);
                          if (bytes != null) {
                            return bytes;
                          }
                          return Uint8List(0);
                        } catch (e) {
                          print(e);
                          return Uint8List(0);
                        }
                      }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> createImageData(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawOval(const Rect.fromLTWH(0, 0, 200, 200), paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> showImageViewerModal(BuildContext context) async {
    var controller = ModalController.of(context);
    await controller?.showModal(
      (ctx) {
        return GestureDetector(
          onTap: () {
            controller.pop();
          },
          child: Container(
            padding: const EdgeInsets.all(50),
            color: Colors.black.withOpacity(0.8),
            child: GestureDetector(
              onTap: () {
                controller.pop();
              },
              child: Center(
                child: OctoImage(
                  // width: element.width.toDouble(),
                  // height: element.height.toDouble(),
                  placeholderBuilder: (context) => Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Container(
                        width: min(100, min(width, height)),
                        height: min(100, min(width, height)),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  image: MultiSourceFileImage(
                      imageId: element.id,
                      reader: (id) async {
                        var fileInfo =
                            await editController.fileManager.getFileInfo(id);
                        var imageFile = fileInfo?.path;
                        if (imageFile == null || imageFile.isEmpty) {
                          return Uint8List(0);
                        }
                        return File(imageFile).readAsBytes();
                      }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  int get length => delete ? 0 : 1;

  @override
  WenElement copyElement(TextPosition start, TextPosition end) {
    if (delete) {
      return WenTextElement();
    }
    if (end.offset == 1 && start.offset == 0) {
      return element.copy();
    }
    return WenTextElement();
  }

  @override
  int deletePosition(TextPosition textPosition) {
    int len = length;
    if (textPosition.offset == 1) {
      delete = true;
      relayoutFlag = true;
    }
    return len - length;
  }

  @override
  void deleteRange(TextPosition start, TextPosition end) {
    if (end.offset == 1 && start.offset == 0) {
      delete = true;
      relayoutFlag = true;
    }
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    int start = selection.baseOffset;
    int end = selection.extentOffset;
    var alignment = calcAlignment();
    var offset = calcAlignmentOffset(
        Size(imageWidth + padding * 2, imageHeight + padding * 2), alignment);
    offset = offset.translate(calcIndentWidth(), 0);
    if (start == 0 && end == 1) {
      return [
        TextBox.fromLTRBD(offset.dx + padding, offset.dy + padding, imageWidth,
            imageHeight, TextDirection.ltr)
      ];
    }
    return [];
  }

  @override
  Rect? getCursorRect(TextPosition textPosition) {
    var alignment = calcAlignment();
    var offset = calcAlignmentOffset(
        Size(imageWidth + padding * 2, imageHeight + padding * 2), alignment);
    offset = offset.translate(calcIndentWidth(), 0);
    if (delete || textPosition.offset == 0) {
      return Rect.fromLTWH(
          offset.dx + padding - 1, offset.dy + padding, 1, imageHeight);
    } else {
      return Rect.fromLTWH(imageWidth + offset.dx + padding - 1,
          offset.dy + padding, 1, imageHeight);
    }
  }

  @override
  TextRange? getWordBoundary(TextPosition textPosition) {
    return const TextRange(start: 0, end: 1);
  }

  @override
  TextPosition? getPositionForOffset(Offset offset) {
    var alignment = calcAlignment();
    var calcOffset = calcAlignmentOffset(
        Size(imageWidth + padding * 2, imageHeight + padding * 2), alignment);
    calcOffset = calcOffset.translate(calcIndentWidth(), 0);

    if (delete || offset.dx <= calcOffset.dx + imageWidth / 2) {
      return const TextPosition(offset: 0);
    } else {
      return const TextPosition(offset: 1);
    }
  }

  @override
  void inputText(WenzEditController controller, TextEditingValue text,
      {bool isComposing = false}) {}

  @override
  void layout(BuildContext context, Size viewSize) {
    this.context = context;
    var mq = MediaQuery.of(context);
    var ratio = mq.devicePixelRatio;
    if (ratio <= 0) {
      ratio = 1;
    }
    var w = element.width;
    var h = element.height;
    var viewMaxImageHeight = (viewSize.width - padding * 2) * h / w;
    // var windowMaxImageHeight = ui.window.physicalSize.height / ratio * 0.6;
    var maxImageHeight = viewMaxImageHeight;
    var imageHeight = h / ratio;
    imageHeight = element.showHeight ?? imageHeight;
    if (imageHeight < maxImageHeight) {
      height = imageHeight + padding * 2;
    } else {
      imageHeight = maxImageHeight;
      height = maxImageHeight + padding * 2;
    }

    this.imageHeight = imageHeight;
    imageWidth = imageHeight * w / h;

    width = viewSize.width;
  }

  @override
  WenzBlock? mergeBlock(WenzBlock endBlock) {
    return null;
  }

  @override
  WenzBlock splitBlock(TextPosition textPosition) {
    return TextBlock(
      context: context,
      textElement: WenTextElement(),
      editController: editController,
    );
  }

  @override
  ui.TextRange? getLineBoundary(ui.TextPosition textPosition) {
    return getWordBoundary(textPosition);
  }

  @override
  void visitElement(
      TextPosition start, TextPosition end, WenzElementVisitor visit) {
    if (start.offset == 0 && end.offset == 1) {
      visit.call(this, element);
    }
  }

  void updateImageSize(double deltaX, double deltaY) {
    if (deltaY == 0 && imageWidth > 0) {
      deltaY = deltaX * imageHeight / imageWidth;
    } else {
      return;
    }
    imageWidth += deltaX;
    imageHeight += deltaY;
    element.showWidth = imageWidth;
    element.showHeight = imageHeight;
    editController.onUpdateImageSize(this, imageWidth, imageHeight);
  }

  void setImageSize(double width, double height) {
    // 保持宽高比
    double aspectRatio = element.width / element.height;

    // 如果只设置了一个值，根据宽高比计算另一个值
    if (width > 0 && height <= 0) {
      height = width / aspectRatio;
    } else if (height > 0 && width <= 0) {
      width = height * aspectRatio;
    }

    // 确保尺寸合理
    if (width <= 0 || height <= 0) {
      return;
    }

    imageWidth = width;
    imageHeight = height;
    element.showWidth = imageWidth;
    element.showHeight = imageHeight;
    editController.onUpdateImageSize(this, imageWidth, imageHeight);
  }

  void showSizeAdjustmentDialog(BuildContext context) {
    showImageSizeAdjustmentDialog(
      context,
      currentWidthDp: imageWidth,
      currentHeightDp: imageHeight,
      imageWidthPx: element.width,
      imageHeightPx: element.height,
      setImageSizeDp: setImageSize,
    );
  }

  void copyImage(BuildContext context) async {
    WenElement element = copyElement(
        const TextPosition(offset: 0), const TextPosition(offset: 1));
    await editController.copyService.saveCopyCache([element]);
    String html = "<!DOCTYPE html>\n"
        "<html>\n<head>\n"
        "<meta charset=\"utf-8\"></meta></head><body copyid='${editController.copyService.copyId}'>";
    html += element.getHtml();
    html += "</body></html>";
    // RichClipboard.setData(
    //   RichClipboardData(html: html, text: element.getText()),
    // );
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.htmlText(html.toString()));
    item.add(Formats.plainText(element.getText()));
    await clipboard.write([item]);
    BotToast.showText(text: "复制成功！");
    // Pasteboard.writeImage(await File(this.element.file).readAsBytes());
    Pasteboard.writeFiles([this.element.file]);
  }

  void saveImageToLocal(BuildContext context) async {
    try {
      var fileInfo = await editController.fileManager.getFileInfo(element.id);
      var imageFile = fileInfo?.path;
      if (imageFile == null || imageFile.isEmpty) {
        BotToast.showText(text: "找不到图片文件");
        return;
      }

      // 获取文件名和扩展名
      String fileName = imageFile.split(Platform.pathSeparator).last;
      String ext = fileName.split('.').last.toLowerCase();

      // 读取文件内容
      Uint8List bytes = await File(imageFile).readAsBytes();

      // 根据扩展名确定MIME类型
      MimeType mimeType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = MimeType.jpeg;
          break;
        case 'png':
          mimeType = MimeType.png;
          break;
        case 'gif':
          mimeType = MimeType.gif;
          break;
        case 'webp':
          // file_saver 包可能不直接支持 webp 类型，使用其他类型
          mimeType = MimeType.other;
          break;
        default:
          mimeType = MimeType.other;
      }

      // 使用系统对话框选择保存位置
      String? result = await FileSaver.instance.saveFile(
        name: fileName.split('.').first, // 不包含扩展名的文件名
        bytes: bytes,
        ext: ext,
        mimeType: mimeType,
      );

      if (result.isNotEmpty) {
        BotToast.showText(text: "图片已保存：$result");
      } else {
        BotToast.showText(text: "保存已取消");
      }
    } catch (e) {
      BotToast.showText(text: "保存失败: ${e.toString().split('\n').first}");
      print("Save image error: $e");
    }
  }

  void openImagePath(BuildContext context) async {
    var fileInfo = await editController.fileManager.getFileInfo(element.id);
    var file = fileInfo?.path;
    if (file == null || file.isEmpty) {
      return;
    }
    FileUtils.openFile(file);
  }

  void openImageDir(BuildContext context) async {
    var fileInfo = await editController.fileManager.getFileInfo(element.id);
    var file = fileInfo?.path;
    if (file == null || file.isEmpty) {
      return;
    }
    var dir = File(file).parent;
    FileUtils.openFile(dir.path);
  }

  void showImageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // MediaQuery.of(context).devicePixelRatio*500=真实像素;
        return Center(
          child: SizedBox(
            width: 500,
            height: 400,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text("图片信息"),
              content: SelectableText(
                  "文件名：${element.file}\n\n 尺寸：${element.width} * ${element.height}"),
              actions: [
                TextButton(
                  child: Text("确定"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void previewImage(BuildContext context) {
    var imageBlocks = <ImageBlock>[];
    for (var block in blocks) {
      if (block is ImageBlock) {
        imageBlocks.add(block);
      }
      if (block is TableBlock) {
        for (var row in block.rows) {
          for (var cell in row) {
            if (cell is ImageBlock) {
              imageBlocks.add(cell);
            }
          }
        }
      }
    }
    var index = imageBlocks.indexWhere((e) => e.element.id == element.id);
    List<ImageProvider> imagesProvider = imageBlocks.map((e) {
      var file = e.element.file;
      return FileImage(File(file));
    }).toList();
    showImageViewerPager(
      context,
      MultiImageProvider(imagesProvider, initialIndex: index),
    );
  }

  @override
  List<PopupPositionWidget> buildFloatWidgets() {
    var toolHeight = 24.0;
    return [
      if (isFocusBlock)
        PopupPositionWidget(
          top: top -
              editController.scrollOffset +
              editController.padding.top -
              toolHeight +
              padding,
          right: width - imageWidth - padding + editController.padding.right,
          child: Builder(builder: (context) {
            var textColor = Theme.of(context).colorScheme.primary;
            var cardColor =
                Theme.of(context).colorScheme.surfaceContainerHighest;
            return Card(
              margin: EdgeInsets.zero,
              color: cardColor,
              child: Container(
                height: toolHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 图片信息
                    InkWell(
                      borderRadius: BorderRadius.circular(toolHeight / 2),
                      onTap: () {
                        showImageInfo(context);
                      },
                      child: Icon(
                        Icons.info_outline,
                        color: textColor,
                      ),
                    ),
                    SizedBox(width: 8),
                    // 预览图片
                    InkWell(
                      borderRadius: BorderRadius.circular(toolHeight / 2),
                      onTap: () {
                        previewImage(context);
                      },
                      child: Icon(
                        Icons.remove_red_eye_outlined,
                        color: textColor,
                      ),
                    ),
                    SizedBox(width: 8),

                    // 复制图片
                    // 菜单
                    HoverDropDownMenu(
                      hoverPopup: false,
                      bubbleArrowOffset: 24,
                      menuOffset: const Offset(-14, 0),
                      menuChildren: [
                        MenuItemButton(
                          child: const Text("复制图片"),
                          onPressed: () {
                            copyImage(context);
                          },
                        ),
                        MenuItemButton(
                          child: const Text("打开文件"),
                          onPressed: () {
                            openImagePath(context);
                          },
                        ),
                        MenuItemButton(
                          child: const Text("打开文件夹"),
                          onPressed: () {
                            openImageDir(context);
                          },
                        ),
                        MenuItemButton(
                          child: const Text("调整图片大小"),
                          onPressed: () {
                            showSizeAdjustmentDialog(context);
                          },
                        ),
                        MenuItemButton(
                          child: const Text("保存到文件"),
                          onPressed: () {
                            saveImageToLocal(context);
                          },
                        ),
                      ],
                      builder: (context, controller, child) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(toolHeight / 2),
                          onTap: () {
                            controller.open();
                          },
                          child: Icon(
                            Icons.more_vert,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
    ];
  }
}
