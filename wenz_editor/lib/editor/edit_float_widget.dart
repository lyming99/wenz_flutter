import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wenz_editor/commons/widget/popup_stack.dart';
import 'package:wenz_editor/editor/block/code/code.dart';
import 'package:wenz_editor/editor/block/table/table_block.dart';
import 'package:wenz_editor/editor/cursor/cursor.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:wenz_editor/editor/widget/drop_menu.dart';
import 'package:wenz_editor/editor/widget/popup/vertical_popup_layout.dart';
import 'package:wenz_editor/editor/widget/popup/vertical_popup_widget.dart';

import '../commons/widget/colors.dart';
import 'block/text/text.dart';
import 'widget/toggle_item.dart';

var defaultColors = <Color?>[
  MyColors.yellow.darkest,
  MyColors.orange.darkest,
  MyColors.red.darkest,
  MyColors.magenta.darkest,
  MyColors.purple.darkest,
  MyColors.blue.darkest,
  MyColors.teal.darkest,
  MyColors.green.darkest,
  Colors.black,
  MyColors.yellow.darker,
  MyColors.orange.darker,
  MyColors.red.darker,
  MyColors.magenta.darker,
  MyColors.purple.darker,
  MyColors.blue.darker,
  MyColors.teal.darker,
  MyColors.green.darker,
  Colors.grey.shade800,
  MyColors.yellow.dark,
  MyColors.orange.dark,
  MyColors.red.dark,
  MyColors.magenta.dark,
  MyColors.purple.dark,
  MyColors.blue.dark,
  MyColors.teal.dark,
  MyColors.green.dark,
  Colors.grey.shade600,
  MyColors.yellow.normal,
  MyColors.orange.normal,
  MyColors.red.normal,
  MyColors.magenta.normal,
  MyColors.purple.normal,
  MyColors.blue.normal,
  MyColors.teal.normal,
  MyColors.green.normal,
  Colors.grey.shade400,
  MyColors.yellow.light,
  MyColors.orange.light,
  MyColors.red.light,
  MyColors.magenta.light,
  MyColors.purple.light,
  MyColors.blue.light,
  MyColors.teal.light,
  MyColors.green.light,
  Colors.grey.shade200,
  MyColors.yellow.lighter,
  MyColors.orange.lighter,
  MyColors.red.lighter,
  MyColors.magenta.lighter,
  MyColors.purple.lighter,
  MyColors.blue.lighter,
  MyColors.teal.lighter,
  MyColors.green.lighter,
  Colors.white,
  MyColors.yellow.lightest,
  MyColors.orange.lightest,
  MyColors.red.lightest,
  MyColors.magenta.lightest,
  MyColors.purple.lightest,
  MyColors.blue.lightest,
  MyColors.teal.lightest,
  MyColors.green.lightest,
  null,
];

extension EditFloatToolController on WenzEditController {
  void showToolbarContextMenu(BuildContext context, {bool showInsert = false}) {
    var textColor = Theme.of(context).textTheme.bodyMedium?.color;
    showDropMenu(
      context,
      childrenHeight: 38,
      modal: true,
      menus: [
        if (showInsert)
          DropMenu(
            text: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("上方插入"),
              ],
            ),
            onPress: (context) {
              hideDropMenu(context);
              addTextBlockBefore();
            },
          ),
        if (showInsert)
          DropMenu(
            text:  Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("下方添加"),
              ],
            ),
            onPress: (context) {
              addTextBlock();
            },
          ),
        if (showInsert) DropSplit(),
        DropMenu(
          text: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.copy,
                  color: textColor,
                ),
              ),
              Text("复制"),
            ],
          ),
          onPress: (context) {
            hideDropMenu(context);

            copySelect();
          },
        ),
        DropMenu(
          text: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.cut,
                  color: textColor,
                ),
              ),
              Text("剪切"),
            ],
          ),
          onPress: (context) {
            hideDropMenu(context);
            cut();
          },
        ),
        DropMenu(
          text: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.paste,
                  color: textColor,
                ),
              ),
              Text("粘贴"),
            ],
          ),
          onPress: (context) {
            hideDropMenu(context);
            paste();
          },
        ),
        DropMenu(
          text: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.select_all,
                  color: textColor,
                ),
              ),
              const Text("全选"),
            ],
          ),
          onPress: (context) {
            hideDropMenu(context);
            selectAll();
          },
        ),
      ],
    );
  }

  Rect getSelectRect() {
    var selectMarginBottom = isMobile ? 24 : 0;
    var selectStart = selectState.realStart;
    var selectEnd = selectState.realEnd;
    double left = double.infinity;
    double right = 0;
    double top = double.infinity;
    double bottom = 0;
    if (selectStart != null &&
        selectEnd != null &&
        selectStart.isValid &&
        selectEnd.isValid) {
      var startBlock = selectStart.block!;
      var startPosition = selectStart.textPosition!;
      var endBlock = selectEnd.block!;
      var endPosition = selectEnd.textPosition!;
      if (startBlock.top > endBlock.top) {
        startBlock = selectEnd.block!;
        endBlock = selectStart.block!;
        startPosition = selectEnd.textPosition!;
        endPosition = selectStart.textPosition!;
      }
      var blocks = blockManager.layout(viewContext, scrollOffset,
          Size(blockMaxWidth, visionHeight), padding);
      for (var block in blocks) {
        //判断block的y是否在start block和end block之间
        if (block.top < startBlock.top || block.top > endBlock.top) continue;
        TextPosition drawStart, drawEnd;
        drawStart = block.startPosition;
        drawEnd = block.endPosition;
        if (block.top == startBlock.top) {
          drawStart = startPosition;
        }
        if (block.top == endBlock.top) {
          drawEnd = endPosition;
        }
        block.selected = true;
        block.selectedStart = drawStart;
        block.selectedEnd = drawEnd;
        //绘制选择高亮
        var selection = TextSelection.fromPosition(drawStart).extendTo(drawEnd);
        var boxes = block.getBoxesForSelection(selection);
        for (var box in boxes) {
          var boxRect = box.toRect();
          left = min(left, boxRect.left);
          right = max(right, boxRect.right);
          top = min(top, boxRect.top + block.top);
          bottom = max(bottom, boxRect.bottom + block.top);
        }
      }

      var startRect = getCursorRect(selectState.start);
      if (startRect != null) {
        left = min(left, startRect.left);
        right = max(right, startRect.right);
        top = min(top, startRect.top);

        bottom = max(bottom, startRect.bottom + selectMarginBottom);
      }
      var endRect = getCursorRect(selectState.end);
      if (endRect != null) {
        left = min(left, endRect.left);
        right = max(right, endRect.right);
        top = min(top, endRect.top);
        bottom = max(bottom, endRect.bottom + selectMarginBottom);
      }
      return Rect.fromLTRB(left, top, right, bottom);
    }
    return Rect.zero;
  }

  Rect? getCursorRect([CursorPosition? position]) {
    position ??= cursorState.cursorPosition;
    if (position == null) {
      return null;
    }
    var block = position.block;
    var pos = position.textPosition;
    if (block == null || pos == null) {
      return null;
    }
    var rect = block.getCursorRect(pos);
    if (rect != null) {
      return rect.translate(0, block.top);
    }
    return rect;
  }

  PopupPositionWidget? buildDesktopFloatToolWidget(BuildContext context) {
    if (!editable) {
      return null;
    }
    if (rightMenuShowing) {
      return null;
    }
    if (!selectState.isCursorDragging &&
        !selectState.shiftDown &&
        !mouseKeyboardState.mouseLeftDown &&
        selectState.hasSelect) {
      var contextMenu = isMobile
          ? buildMobileFloatToolButton(context)
          : buildDesktopFloatToolButton(context);

      var selectRect = getSelectRect();
      selectRect =
          selectRect.translate(padding.left, padding.top - scrollOffset);

      return contextMenu.isEmpty ||
              selectRect.overlaps(
                      Rect.fromLTWH(0, 0, visionWidth, visionHeight)) ==
                  false
          ? null
          : PopupPositionWidget(
              layerIndex: 1,
              keepVision: true,
              anchorRect: selectRect,
              popupAlignment: Alignment.topCenter,
              overflowAlignment: Alignment.bottomCenter,
              child: Builder(builder: (context) {
                return Card(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  margin: const EdgeInsets.all(4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: contextMenu,
                      ),
                    ),
                  ),
                );
              }));
    }
    return null;
  }

  List<Widget> buildMobileFloatToolButton(BuildContext context) {
    // 剪切 复制 全选 分享
    return [
      IconButton(
        onPressed: () {
          cut();
        },
        icon: const Text("剪切"),
      ),
      IconButton(
        onPressed: () {
          copySelect();
        },
        icon: const Text("复制"),
      ),
      IconButton(
        onPressed: () {
          selectAll();
        },
        icon: const Text("全选"),
      ),
      IconButton(
        onPressed: () {
          paste();
        },
        icon: const Text("粘贴"),
      ),
    ];
  }

  List<Widget> buildDesktopFloatToolButton(BuildContext context) {
    var textColor = Theme.of(context).textTheme.bodyMedium?.color;
    var hoverColor =
        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6);
    var start = selectState.realStart;
    var end = selectState.realEnd;

    //标题、粗体、颜色、斜体、下划线、删除线、链接、标记
    bool showLink = start?.block == end?.block && start?.block is TextBlock;
    if (start?.block == end?.block && start?.block is TableBlock) {
      var tableBlock = start!.block as TableBlock;
      showLink = tableBlock.isShowLink(
          start!.textPosition!.offset, end!.textPosition!.offset);
    }
    bool isRemark = true;
    int? blockTextLevel;
    bool showBlockTextLevel = true;
    bool showAlignment = false;

    bool isBold = true;
    bool isItalic = true;
    bool isUnderLine = true;
    bool isDeleteLine = true;
    bool hasText = false;

    visitSelectElement((block, element) {
      if (element is WenTextElement) {
        hasText = true;
        if (element.bold != true) {
          isBold = false;
        }
        if (element.italic != true) {
          isItalic = false;
        }
        if (element.lineThrough != true) {
          isDeleteLine = false;
        }
        if (element.underline != true) {
          isUnderLine = false;
        }
        if (element.remark != true) {
          isRemark = false;
        }
      }
    });
    visitSelectBlock((block) {
      if (block is TextBlock) {
        var level = block.textElement.level;
        if (blockTextLevel == null) {
          blockTextLevel = level;
        } else {
          if (level != blockTextLevel) {
            showBlockTextLevel = false;
          }
        }
      }
      if (block is! CodeBlock) {
        showAlignment = true;
      }
    });
    var desktopMenu = [
      if (!isMobile && showAlignment) _buildLeftAlignmentButton(),
      if (!isMobile && showAlignment) _buildCenterAlignmentButton(),
      if (!isMobile && showAlignment) _buildRightAlignmentButton(),
      //字体颜色
      if (hasText) _buildFontColorPicker(context, null),
      //字体底色
      if (hasText) _buildBgColorPicker(context, null),
      //加粗
      if (hasText)
        ToggleItem(
          checked: isBold,
          onChanged: (val) {
            setBold(val);
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            return Container(
              width: 30,
              height: 30,
              color: hover ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                //刷子
                Icons.format_bold_outlined,
                color:
                    checked ? Theme.of(context).colorScheme.primary : textColor,
              ),
            );
          },
        ),
      //倾斜
      if (hasText)
        ToggleItem(
          checked: isItalic,
          onChanged: (val) {
            setItalic(val);
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            return Container(
              width: 30,
              height: 30,
              color: hover ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                Icons.format_italic_outlined,
                color:
                    checked ? Theme.of(context).colorScheme.primary : textColor,
              ),
            );
          },
        ),
      //下滑线
      if (hasText)
        ToggleItem(
          checked: isUnderLine,
          onChanged: (val) {
            setUnderline(val);
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            return Container(
              width: 30,
              height: 30,
              color: hover ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                Icons.format_underline_outlined,
                color:
                    checked ? Theme.of(context).colorScheme.primary : textColor,
              ),
            );
          },
        ),
      //删除线
      if (hasText)
        ToggleItem(
          checked: isDeleteLine,
          onChanged: (val) {
            setLineThrough(val);
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            return Container(
              width: 30,
              height: 30,
              color: hover ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                Icons.format_strikethrough_outlined,
                color:
                    checked ? Theme.of(context).colorScheme.primary : textColor,
              ),
            );
          },
        ),
      //链接
      if (showLink) _buildLinkButton(),
      //清除样式
      if (hasText) _buildClearStyleButton(),
      _buildContextMenuButton(),
    ];
    return desktopMenu;
  }

  ToggleItem _buildLeftAlignmentButton() {
    return ToggleItem(
      onTap: (context) {
        setAlignment(null);
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.format_align_left,
            color: textColor,
          ),
        );
      },
    );
  }

  ToggleItem _buildCenterAlignmentButton() {
    return ToggleItem(
      onTap: (context) {
        // 左对齐
        setAlignment("center");
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.format_align_center,
            color: textColor,
          ),
        );
      },
    );
  }

  ToggleItem _buildRightAlignmentButton() {
    return ToggleItem(
      onTap: (context) {
        setAlignment("right");
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.format_align_right,
            color: textColor,
          ),
        );
      },
    );
  }

  Widget _buildContextMenuButton() {
    return ToggleItem(
      onTap: (context) {
        showToolbarContextMenu(context);
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert_outlined,
            color: textColor,
          ),
        );
      },
    );
  }

  ToggleItem _buildLinkButton() {
    return ToggleItem(
      onTap: (context) {
        setLink();
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.link,
            color: textColor,
          ),
        );
      },
    );
  }

  ToggleItem _buildClearStyleButton() {
    return ToggleItem(
      onTap: (context) {
        clearStyle();
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        var textColor = Theme.of(context).textTheme.bodyMedium?.color;
        var hoverColor = Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.6);
        return Container(
          width: 30,
          height: 30,
          color: hover ? hoverColor : null,
          alignment: Alignment.center,
          child: Icon(
            Icons.format_clear,
            color: textColor,
          ),
        );
      },
    );
  }

  Widget _buildFontColorPicker(BuildContext context, int? color) {
    return VerticalPopupWidget(
      popupAlignment: PopupAlignment.center,
      popupWidth: 270,
      popupHeight: 270 * 7 / 9 + 1,
      popupBuilder: (BuildContext context, OverlayPortalController controller) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 2,
                // blurStyle: BlurStyle.outer,
                color: Colors.grey.shade500,
              ),
            ],
          ),
          width: 270,
          height: 270 * 7 / 9 + 1,
          child: GridView.builder(
            itemCount: defaultColors.length,
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (context, index) {
              return ToggleItem(
                onTap: (context) {
                  setTextColor(index);
                  controller.hide();
                },
                itemBuilder: (BuildContext context, bool checked, bool hover,
                    bool pressed) {
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        border: hover
                            ? Border.all(
                                color: Colors.grey,
                              )
                            : null),
                    padding: EdgeInsets.all(1),
                    child: defaultColors[index] != null
                        ? Container(
                            color: defaultColors[index],
                          )
                        : Container(
                            child: Icon(
                              Icons.block,
                              color: Colors.red,
                            ),
                          ),
                  );
                },
              );
            },
          ),
        );
      },
      childBuilder: (BuildContext context, OverlayPortalController controller) {
        return ToggleItem(
          onTap: (context) {
            if (!controller.isShowing) {
              controller.show();
            } else {
              controller.hide();
            }
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            hover = hover || controller.isShowing;
            var textColor = Theme.of(context).textTheme.bodyMedium?.color;
            var hoverColor = Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.6);
            return Container(
              width: 30,
              height: 30,
              color:
                  hover || controller.isShowing ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                //刷子
                Icons.format_color_text,
                color: textColor,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBgColorPicker(BuildContext context, int? color) {
    return VerticalPopupWidget(
      popupWidth: 270,
      popupHeight: 270 * 7 / 9 + 1,
      popupAlignment: PopupAlignment.center,
      popupBuilder: (BuildContext context, OverlayPortalController controller) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 2,
                // blurStyle: BlurStyle.outer,
                color: Colors.grey.shade500,
              ),
            ],
          ),
          width: 270,
          height: 270 * 7 / 9 + 1,
          child: GridView.builder(
            itemCount: defaultColors.length,
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (context, index) {
              return ToggleItem(
                onTap: (context) {
                  setBackgroundColor(index);
                  controller.hide();
                },
                itemBuilder: (BuildContext context, bool checked, bool hover,
                    bool pressed) {
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        border: hover
                            ? Border.all(
                                color: Colors.grey,
                              )
                            : null),
                    padding: EdgeInsets.all(1),
                    child: defaultColors[index] != null
                        ? Container(
                            color: defaultColors[index],
                          )
                        : Container(
                            child: Icon(
                              Icons.block,
                              color: Colors.red,
                            ),
                          ),
                  );
                },
              );
            },
          ),
        );
      },
      childBuilder: (BuildContext context, OverlayPortalController controller) {
        return ToggleItem(
          onTap: (context) {
            if (!controller.isShowing) {
              controller.show();
            } else {
              controller.hide();
            }
          },
          itemBuilder:
              (BuildContext context, bool checked, bool hover, bool pressed) {
            hover = hover || controller.isShowing;
            var textColor = Theme.of(context).textTheme.bodyMedium?.color;
            var hoverColor = Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.6);
            return Container(
              width: 30,
              height: 30,
              color:
                  hover || controller.isShowing ? hoverColor : null,
              alignment: Alignment.center,
              child: Icon(
                //刷子
                Icons.format_color_fill_outlined,
                color: textColor,
              ),
            );
          },
        );
      },
    );
  }
}
