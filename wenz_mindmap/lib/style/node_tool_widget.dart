import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:wenz_editor/commons/util/file_utils.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'package:wenz_editor/commons/util/image_utils.dart';
import 'package:wenz_ui/layout/index.dart';
import 'package:wenz_ui/popup/index.dart' hide MenuItemButton;

import '../controller/mind_doc_controller.dart';
import '../controller/mind_map_controller.dart';
import '../data/mind_node.dart';

class NodeToolWidget extends StatelessWidget {
  final MindNode node;

  const NodeToolWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    var textColor = Theme.of(context).colorScheme.primary;
    var cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    var controller = MindMapController.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      child: TapRegion(
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SpacingRow(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!node.isImage)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    node.showEdit();
                  },
                  child: Icon(Icons.edit, color: textColor),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  controller?.addChild();
                },
                child: Image.asset(
                  "assets/icon/subnode.png",
                  width: 24,
                  height: 24,
                  color: textColor,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  controller?.addNext();
                },
                child: Image.asset(
                  "assets/icon/sisternode.png",
                  width: 24,
                  height: 24,
                  color: textColor,
                ),
              ),
              // 图片信息
              if (node.isImage)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showImageInfo(context);
                  },
                  child: Icon(Icons.info_outline, color: textColor),
                ),
              // 复制图片
              // 菜单
              HoverDropDownMenu(
                hoverPopup: false,
                bubbleArrowOffset: 24,
                menuOffset: const Offset(-14, 0),
                menuChildren: [
                  if (node.isImage)
                    MenuItemButton(
                      child: const Text("复制图片"),
                      onPressed: () {
                        copyImage(context);
                      },
                    ),
                  if (node.isImage)
                    MenuItemButton(
                      child: const Text("调整图片大小"),
                      onPressed: () {
                        var currentWidthDp = node.info?.imageShowWidth ?? 0;
                        var currentHeightDp = node.info?.imageShowHeight ?? 0;
                        var imageWidthPx = node.info?.imageWidth ?? 0;
                        var imageHeightPx = node.info?.imageHeight ?? 0;
                        showImageSizeAdjustmentDialog(
                          context,
                          currentWidthDp: currentWidthDp,
                          currentHeightDp: currentHeightDp,
                          imageWidthPx: imageWidthPx,
                          imageHeightPx: imageHeightPx,
                          setImageSizeDp: (w, h) {
                            controller?.updateImageShowSize(
                              w - currentWidthDp,
                              h - currentHeightDp,
                              node,
                            );
                          },
                        );
                      },
                    ),
                  if (node.isImage)
                    MenuItemButton(
                      child: const Text("打开文件"),
                      onPressed: () {
                        openImagePath(context);
                      },
                    ),
                  if (!node.isImage)
                    MenuItemButton(
                      child: const Text("复制"),
                      onPressed: () {
                        var controller = MindMapController.of(context);
                        controller?.copy();
                      },
                    ),
                  MenuItemButton(
                    child: const Text("粘贴"),
                    onPressed: () {
                      var controller = MindMapController.of(context);
                      controller?.paste(context);
                    },
                  ),
                  MenuItemButton(
                    child: const Text("展开/折叠"),
                    onPressed: () {
                      var controller = MindMapController.of(context);
                      controller?.toggleExpand(node);
                    },
                  ),
                  MenuItemButton(
                    child: const Text("删除"),
                    onPressed: () {
                      var controller = MindMapController.of(context);
                      controller?.delete();
                    },
                  ),
                ],
                builder: (context, controller, child) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      controller.open();
                    },
                    child: Icon(Icons.more_vert, color: textColor),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showImageInfo(BuildContext context) async {
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      node.info?.image ?? "",
      null,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // var imageFile = controller.node.info?.image ?? "";
        var imageWidth = node.info?.imageWidth;
        var imageHeight = node.info?.imageHeight;
        return Center(
          child: SizedBox(
            width: 500,
            height: 400,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: const Text("图片信息"),
              content: SelectableText(
                "文件名：${imageFile}\n\n 尺寸：$imageWidth * $imageHeight",
              ),
              actions: [
                TextButton(
                  child: const Text("确定"),
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

  void copyImage(BuildContext context) async {
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      node.info?.image ?? "",
      null,
    );
    if (imageFile == null) {
      return;
    }
    await Pasteboard.writeFiles([imageFile]);
    BotToast.showText(text: "复制成功");
  }

  void openImagePath(BuildContext context) async {
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      node.info?.image ?? "",
      null,
    );
    if (imageFile == null) {
      return;
    }
    FileUtils.openSystemFile((imageFile));
  }
}
