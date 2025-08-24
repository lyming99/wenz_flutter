import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../commons/util/platform_util.dart';
import '../../commons/widget/popup_stack.dart';
import '../block/table/table_block.dart';
import '../block/text/link.dart';
import '../block/text/text.dart';

class LinkUtils {
  LinkUtils._();

  static BlockLink? getHoverLink(WenzEditController controller) {
    var cursorState = controller.cursorState;
    var hover = cursorState.hoverPosition;
    if (hover != null && hover.block != null && hover.textPosition != null) {
      var block = hover.block!;
      var position = hover.textPosition!;
      return block.getLink(position);
    }
    return null;
  }

  static Rect? getHoverLinkStartCursorRect(
      WenzEditController controller, BlockLink link) {
    var block = link.block;
    var rect = block.getCursorRect(TextPosition(offset: link.textOffset));
    if (rect != null) {
      var scrollOffset = controller.scrollOffset;
      var padding = controller.padding;
      double cursorY = block.top - scrollOffset;
      return rect.translate(padding.left, padding.top + cursorY + 2);
    }
    return null;
  }

  static Rect? getHoverLinkStartCursorGlobalRect(
      WenzEditController controller, BlockLink link) {
    var rect = getHoverLinkStartCursorRect(controller, link);
    if (rect != null) {
      var rendBox = controller.viewContext.findRenderObject();
      if (rendBox is RenderBox) {
        var maxWidth = controller.maxEditWidth;
        var boxWidth = rendBox.size.width;
        var leftOffset = 0.0;
        if (boxWidth > maxWidth) {
          leftOffset = (boxWidth - maxWidth) / 2;
        }
        var globalPosition = rendBox.localToGlobal(rect.topLeft);
        return Rect.fromLTWH(globalPosition.dx + leftOffset, globalPosition.dy,
            rect.width, rect.height);
      }
    }
    return null;
  }

  /// 链接悬浮打开
  static List<PopupPositionWidget> buildLinkFloatWidgets(
      WenzEditController controller,
      [bool callBuilder = false]) {
    var cursorState = controller.cursorState;
    var visionHeight = controller.visionHeight;
    var hover = cursorState.hoverPosition;
    var result = <PopupPositionWidget>[];
    if (hover != null && hover.block != null && hover.textPosition != null) {
      var block = hover.block!;
      var position = hover.textPosition!;
      var link = block.getLink(position);
      if (link != null) {
        var cursorRect = getHoverLinkStartCursorRect(controller, link);
        if (cursorRect != null) {
          if (callBuilder) {
            var buildResult =
                controller.linkFloatBuilder?.call(controller, link, cursorRect);
            if (buildResult != null && buildResult.isHandle) {
              var widget = buildResult.widget;
              if (widget != null) {
                result.add(widget);
              }
              return result;
            }
          }
          result.add(PopupPositionWidget(
            keepVision: true,
            left: cursorRect.left,
            bottom: visionHeight - (cursorRect.top),
            child: MouseRegion(
              hitTestBehavior: HitTestBehavior.opaque,
              onEnter: (event) {},
              onHover: (event) {},
              onExit: (event) {},
              cursor: WidgetStateMouseCursor.clickable,
              child: Container(
                height: 30,
                width: 150,
                color: Colors.black.withAlpha(155),
                child: Row(
                  children: [
                    //打开
                    GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse(link.textElement.url ?? ""));
                          cursorState.hoverPosition = null;
                          controller.updateWidgetState();
                        },
                        child: const SizedBox(
                          width: 50,
                          height: 30,
                          child: Center(
                            child: Text(
                              "打开",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )),
                    //复制
                    GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: link.textElement.url ?? ""));
                          cursorState.hoverPosition = null;
                          controller.updateWidgetState();
                        },
                        child: const SizedBox(
                          width: 50,
                          height: 30,
                          child: Center(
                            child: Text(
                              "复制",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )),
                    //编辑
                    GestureDetector(
                      onTap: () {
                        cursorState.hoverPosition = null;
                        controller.updateWidgetState();
                        showMobileDialog(
                          context: controller.viewContext,
                          builder: (context) {
                            var linkController = TextEditingController(
                                text: link.textElement.url);
                            var textController = TextEditingController(
                                text: link.textElement.text);
                            return Padding(
                              padding: MediaQuery.of(context).viewInsets,
                              child: AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                content: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minWidth: 300),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 10, top: 10),
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: link.textElement.text,
                                          ),
                                          controller: textController,
                                        ),
                                      ),
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: link.textElement.url,
                                          ),
                                          controller: linkController,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                title: const Text("编辑链接"),
                                actions: [
                                  ElevatedButton(
                                    child: const Text('取消'),
                                    onPressed: () {
                                      Navigator.pop(context, '取消');
                                      // Delete file here
                                    },
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      link.textElement.text =
                                          textController.text;
                                      link.textElement.url =
                                          linkController.text;
                                      if (block is TextBlock) {
                                        block.textElement.calcLength();
                                        block.relayoutFlag = true;
                                      } else if (block is TableBlock) {
                                        block.calcElementLength(position);
                                        block.calcLength();
                                        block.relayoutFlag = true;
                                      }
                                      Navigator.pop(context, '确定');
                                    },
                                    child: const Text("确定"),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: const SizedBox(
                        width: 50,
                        height: 30,
                        child: Center(
                          child: Text(
                            "编辑",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ));
        }
      }
    }
    return result;
  }

  static PopupPositionWidget buildLinkFloatBoxWidget(
    WenzEditController controller,
    BlockLink link,
    Rect startCursorRect, [
    SizedBox sizeBox = const SizedBox(width: 150, height: 30),
  ]) {
    var visionHeight = controller.visionHeight;
    return PopupPositionWidget(
      keepVision: true,
      left: startCursorRect.left,
      bottom: visionHeight - (startCursorRect.top),
      child: sizeBox,
    );
  }
}
