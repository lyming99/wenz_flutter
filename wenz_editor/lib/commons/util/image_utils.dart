import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_size_getter/image_size_getter.dart';
import "dart:ui" as ui show Image, ImageByteFormat;

import 'package:wenz_editor/commons/util/uuid_utils.dart';

import 'image.dart';

void showImageSizeAdjustmentDialog(
  BuildContext context, {
  required double currentWidthDp,
  required double currentHeightDp,
  required int imageWidthPx,
  required int imageHeightPx,
  required void Function(double width, double height) setImageSizeDp,
}) {
  final TextEditingController widthController = TextEditingController(
    text: currentWidthDp.round().toString(),
  );
  final TextEditingController heightController = TextEditingController(
    text: currentHeightDp.round().toString(),
  );

  // 原始宽高比
  final double aspectRatio = imageWidthPx / imageHeightPx;
  bool maintainAspectRatio = true;
  double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: const Text('调整图片大小'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          decoration: const InputDecoration(
                            labelText: '宽度 (dp)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (maintainAspectRatio && value.isNotEmpty) {
                              try {
                                double width = double.parse(value);
                                double height = width / aspectRatio;
                                heightController.text =
                                    height.round().toString();
                              } catch (e) {
                                // 忽略解析错误
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          decoration: const InputDecoration(
                            labelText: '高度 (dp)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (maintainAspectRatio && value.isNotEmpty) {
                              try {
                                double height = double.parse(value);
                                double width = height * aspectRatio;
                                widthController.text = width.round().toString();
                              } catch (e) {
                                // 忽略解析错误
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: maintainAspectRatio,
                        onChanged: (value) {
                          setState(() {
                            maintainAspectRatio = value ?? true;
                            if (maintainAspectRatio) {
                              // 重新应用宽高比
                              try {
                                double width =
                                    double.parse(widthController.text);
                                double height = width / aspectRatio;
                                heightController.text =
                                    height.round().toString();
                              } catch (e) {
                                // 忽略解析错误
                              }
                            }
                          });
                        },
                      ),
                      const Text('保持宽高比'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '原始尺寸: ${(imageWidthPx / devicePixelRatio).round()} × ${(imageHeightPx / devicePixelRatio).round()}'),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            widthController.text =
                                (imageWidthPx / devicePixelRatio)
                                    .round()
                                    .toString();
                            heightController.text =
                                (imageHeightPx / devicePixelRatio)
                                    .round()
                                    .toString();
                          });
                        },
                        child: const Text('重置为原始尺寸'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    double width = double.parse(widthController.text);
                    double height = double.parse(heightController.text);
                    setImageSizeDp(width, height);
                    Navigator.of(dialogContext).pop();
                  } catch (e) {
                    BotToast.showText(text: "请输入有效的数字");
                  }
                },
                child: const Text('应用'),
              ),
            ],
          );
        },
      );
    },
  );
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

  static Future<Uint8List?> toPng(
    Uint8List image,
  ) async {
    var size = readImageSize(MemoryInput(image));
    var imageMemory = Image.memory(
      image,
      cacheWidth: size.width,
      cacheHeight: size.height,
    );
    var uiImage = await ImageUtils.loadImageByProvider(imageMemory.image);
    var bytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }
}
