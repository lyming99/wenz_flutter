import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:wenz_editor/commons/util/file_utils.dart';
import 'package:wenz_ui/button/mini_icon_button.dart';
import 'package:wenz_ui/index.dart' hide MenuItemButton;
import 'package:wenz_ui/utils/mvc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wenz_ui/utils/platform_utils.dart';

import '../controller/mind_doc_controller.dart';
import '../mindmap.dart';
import '../widgets/doc_formula_node.dart';
import '../widgets/doc_image_node.dart';

class XMindNodeWidget extends StatefulWidget {
  final NodeEditController controller;
  final String? docRootDir;

  const XMindNodeWidget({super.key, required this.controller, this.docRootDir});

  @override
  State<XMindNodeWidget> createState() => _XMindNodeWidgetState();
}

class _XMindNodeWidgetState extends State<XMindNodeWidget> {
  late NodeEditController controller;
  var editController = TextEditingController();
  var popupController = OverlayPortalController();

  BuildContext? nodeChildContext;

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    controller.node.addListener(onNodeUpdate);
    editController.text = controller.node.info?.content ?? "";
    if (controller.isEditing) {
      waitAttach(() {
        controller.focusNode?.requestFocus();
      });
    }
  }

  void onNodeUpdate() {
    // var selected = controller.node.tapSelected;
    // if (selected && controller.node.isImage) {
    //   popupController.show();
    // } else {
    //   popupController.hide();
    // }
    setState(() {});
  }

  void waitAttach(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((t) {
      try {
        if (context.mounted) {
          callback();
        } else {
          Future.delayed(const Duration(milliseconds: 100)).then((t) {
            waitAttach(callback);
          });
        }
      } catch (e) {}
    });
  }

  @override
  void dispose() {
    controller.node.removeListener(onNodeUpdate);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.node.removeListener(onNodeUpdate);
    controller = widget.controller;
    controller.node.addListener(onNodeUpdate);
  }

  @override
  Widget build(BuildContext context) {
    var dStyle = controller.controller.defaultTextStyle;
    TextStyle textStyle;
    if (dStyle != null) {
      textStyle = dStyle.copyWith(
        color: controller.controller.document?.style?.getFontColor(
          controller.node,
        ),
        fontSize: controller.controller.document?.style?.getFontSize(
          controller.node,
        ),
        fontFamily: controller.controller.document?.style?.getFontFamily(
          controller.node,
        ),
      );
    } else {
      textStyle = TextStyle(
        color: controller.controller.document?.style?.getFontColor(
          controller.node,
        ),
        fontSize: controller.controller.document?.style?.getFontSize(
          controller.node,
        ),
        fontFamily: controller.controller.document?.style?.getFontFamily(
          controller.node,
        ),
        height: 1.6,
        letterSpacing: 0.5,
      );
    }
    // controller.controller.document?.style?;

    var padding = EdgeInsets.symmetric(
      horizontal:
          controller.controller.document?.style?.getHorizontalPadding(
            controller.node,
          ) ??
          0,
      vertical:
          controller.controller.document?.style?.getVerticalPadding(
            controller.node,
          ) ??
          0,
    );
    var child = Container(
      alignment: Alignment.center,
      margin: EdgeInsets.all(
        controller.controller.document?.style?.getMargin(controller.node) ?? 0,
      ),
      decoration: BoxDecoration(
        color: controller.controller.document?.style?.getBackgroundColor(
          controller.node,
        ),
        borderRadius: BorderRadius.circular(
          controller.controller.document?.style?.getRadius(controller.node) ??
              0,
        ),
        border: Border.all(
          color:
              controller.controller.document?.style?.getBorderColor(
                controller.node,
              ) ??
              Colors.transparent,
          width:
              controller.controller.document?.style?.getBorderWidth(
                controller.node,
              ) ??
              0,
        ),
      ),
      child:
          (!controller.isEditing ||
              controller.node.isImage ||
              controller.node.isFormula)
          ? buildNormalNodeContent(context, padding, textStyle)
          : buildEditNode(context, padding, textStyle),
    );
    // return child;
    return OverlayPortal(
      controller: popupController,
      overlayChildBuilder: (context) {
        // return Container();
        var renderBox = nodeChildContext?.findRenderObject() as RenderBox;
        var leftTop = renderBox.localToGlobal(Offset.zero);
        var anchorRect = leftTop & renderBox.size;
        var bottom = MediaQuery.of(context).size.height - anchorRect.top;
        var right = MediaQuery.of(context).size.width - anchorRect.right;
        return Stack(
          children: [
            Positioned(
              bottom: bottom,
              right: right,
              child: TapRegion(
                onTapOutside: (event) {
                  // popupController.hide();
                },
                child: Builder(
                  builder: (context) {
                    var textColor = Theme.of(context).colorScheme.primary;
                    var cardColor = Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest;
                    return Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SpacingRow(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 图片信息
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
                                MenuItemButton(
                                  child: const Text("复制图片"),
                                  onPressed: () {
                                    copyImage();
                                  },
                                ),
                                MenuItemButton(
                                  child: const Text("打开文件"),
                                  onPressed: () {
                                    openImagePath();
                                  },
                                ),
                              ],
                              builder: (context, controller, child) {
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20),
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
                  },
                ),
              ),
            ),
          ],
        );
      },
      child: Builder(
        builder: (context) {
          nodeChildContext = context;
          return child;
        },
      ),
    );
  }

  Widget buildEditNode(
    BuildContext context,
    EdgeInsets padding,
    TextStyle textStyle,
  ) {
    return TextField(
      // autofocus: true,
      focusNode: controller.focusNode,
      cursorColor: controller.controller.document?.style?.getCursorColor(
        controller.node,
      ),
      maxLines: 1,
      decoration: createInputDecoration(padding),
      textAlign: TextAlign.center,
      style: textStyle,
      controller: editController,
      onChanged: (value) {
        InputNotification(editController.value).dispatch(context);
        controller.onContentChanged?.call(value);
        controller.node.setContent(value);
      },
      onTapOutside: (event) {
        if (PlatformUtils.isDesktop) {
          controller.closeEdit();
          InputNotification(
            TextEditingValue(text: editController.value.text),
          ).dispatch(context);
        }
      },
      onSubmitted: (value) {
        controller.closeEdit();
        InputNotification(TextEditingValue(text: value)).dispatch(context);
      },
    );
  }

  InputDecoration createInputDecoration(EdgeInsets padding) {
    return InputDecoration(
      isCollapsed: true,
      isDense: true,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(0),
        gapPadding: 0,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(0),
        gapPadding: 0,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(0),
        gapPadding: 0,
      ),
      contentPadding: padding,
    );
  }

  // 待办、content、链接
  Widget buildNormalNodeContent(
    BuildContext context,
    EdgeInsets padding,
    TextStyle textStyle,
  ) {
    var iconColor = controller.controller.document?.style?.getIconButtonColor(
      controller.node,
    );
    var isChecked = controller.node.info?.isChecked ?? false;
    return Builder(
      builder: (context) {
        nodeChildContext = context;
        return Container(
          width: controller.node.widgetSize.width,
          height: controller.node.widgetSize.height,
          padding: padding,
          alignment: Alignment.center,
          // text field 有 border side，统一宽度高度
          child: Row(
            children: [
              if (controller.node.info?.isTodo ?? false)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    checkColor: isChecked ? Colors.white : iconColor,
                    activeColor: iconColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(color: iconColor ?? Colors.transparent),
                    // WidgetStateProperty.all(iconColor),
                    value: isChecked,
                    onChanged: (value) {
                      controller.controller.setChecked(controller.node, value);
                    },
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: controller.node.isImage
                      ? buildImageNodeContent(context)
                      : controller.node.isFormula
                      ? buildFormulaNodeContent(context)
                      : buildTextNodeContent(textStyle),
                ),
              ),
              if (controller.hasChildInfo(context, controller.node) &&
                  !controller.controller.isCaptureMode)
                HoverDropDownMenu(
                  menuAlignment: MenuAlignment.right,
                  bubbleArrowEndOffset: 24,
                  menuOffset: const Offset(-12, 0),
                  hoverPopup: true,
                  menuChildren: [
                    if (controller.node.hasLink)
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.link),
                        child: SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  controller.node.linkTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              MiniIconButton(
                                onPressed: () {
                                  removeLink(context, controller.node);
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        onPressed: () {
                          openLink(context, controller.node);
                        },
                      ),
                    if (controller.node.hasNote)
                      for (var noteItem in controller.getExistChildNoteList(
                        context,
                      ))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.edit_note),
                          child: SizedBox(
                            width: 120,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    controller.node.getNoteTitle(
                                      context,
                                      noteItem,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                MiniIconButton(
                                  onPressed: () {
                                    removeNote(
                                      context,
                                      controller.node,
                                      noteItem,
                                    );
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          onPressed: () {},
                        ),
                  ],
                  builder: (context, ctrl, child) {
                    return MiniIconButton(
                      onPressed: () {
                        if (controller.node.isSingleSuffix) {
                          if (controller.node.hasLink) {
                            openLink(context, controller.node);
                          } else {
                            if (controller.childNoteList.length == 1) {
                              openChildNote(
                                context,
                                controller.childNoteList.first,
                                controller.node,
                              );
                            }
                          }
                        }
                        ctrl.open();
                      },
                      icon: Icon(
                        (controller.node.isSingleSuffix &&
                                controller
                                        .getExistChildNoteList(context)
                                        .length <
                                    2)
                            ? (controller.node.hasLink
                                  ? Icons.link
                                  : Icons.edit_note)
                            : CupertinoIcons.ellipsis_circle,
                        color: iconColor,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Center buildTextNodeContent(TextStyle textStyle) {
    return Center(
      child: Text(
        textAlign: TextAlign.center,
        controller.node.info?.content ?? "",
        maxLines: 1,
        style: textStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void openLink(BuildContext context, MindNode node) {
    var url = node.info?.link ?? "";
    launchUrl(Uri.parse(url));
  }

  void openChildNote(BuildContext context, String noteId, MindNode node) {
    controller.controller.openChildNote(context, noteId, node);
  }

  void removeLink(BuildContext context, MindNode node) {
    controller.controller.removeLink(node);
  }

  void removeNote(BuildContext context, MindNode node, String uuid) {
    controller.controller.removeNote(node, uuid);
  }

  Widget buildImageNodeContent(BuildContext context) {
    var width = controller.node.info?.imageShowWidth ?? 0;
    var height = controller.node.info?.imageShowHeight ?? 0;
    return DocImageNode(
      key: ValueKey(controller.node),
      width: width,
      height: height,
      docRootDir: widget.docRootDir,
      imageId: controller.node.info?.image ?? "",
      docId: controller.controller.document?.docId,
      noteId: controller.controller.document?.noteId,
      onResized: (deltaX, deltaY) {
        if (deltaY == 0 && width > 0) {
          deltaY = deltaX * height / width;
        }
        if (deltaX == 0 && height > 0) {
          deltaX = deltaY * width / height;
        }
        controller.controller.updateImageShowSize(
          deltaX,
          deltaY,
          controller.node,
        );
      },
    );
  }

  Widget buildFormulaNodeContent(BuildContext context) {
    var width = controller.node.info?.formulaWidth ?? 0;
    var height = controller.node.info?.formulaHeight ?? 0;
    var formula = controller.node.info?.formula ?? "";
    return DocFormulaNode(width: width, height: height, formula: formula);
  }

  void showImageInfo(BuildContext context) async {
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      controller.node.info?.image ?? "",
      controller.controller.document?.docId,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // var imageFile = controller.node.info?.image ?? "";
        var imageWidth = controller.node.info?.imageWidth;
        var imageHeight = controller.node.info?.imageHeight;
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

  void copyImage() async {
    var context = nodeChildContext;
    if (context == null) {
      return;
    }
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      controller.node.info?.image ?? "",
      controller.controller.document?.docId,
    );
    if (imageFile == null) {
      return;
    }
    await Pasteboard.writeImage(File(imageFile).readAsBytesSync());
    BotToast.showText(text: "复制成功");
  }

  void openImagePath() async {
    var context = nodeChildContext;
    if (context == null) {
      return;
    }
    var docController = findController<MindDocController>(context);
    if (docController == null) {
      return;
    }
    var imageFile = await docController.getImageFile(
      controller.node.info?.image ?? "",
      controller.controller.document?.docId,
    );
    if (imageFile == null) {
      return;
    }
    FileUtils.openSystemFile(imageFile);
  }
}
