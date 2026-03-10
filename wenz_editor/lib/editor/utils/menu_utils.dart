import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wenz_editor/editor/edit_controller.dart';
import 'package:wenz_ui/utils/index.dart';

import '../widget/drop_menu.dart';

class MenuUtils {
  MenuUtils._();

  static void showDropContextMenu(WenzEditController editController,
      BuildContext content, Offset position) async {
    editController.rightMenuShowing = true;
    editController.updateWidgetState();
    var box = editController.viewContext.findRenderObject() as RenderBox;
    await showMouseDropMenu(editController.viewContext,
        box.localToGlobal(position) & const Size(1, 1),
        childrenWidth: 260,
        childrenHeight: 30,
        // margin: 4,
        menus: [
          DropMenu(
              enable: editController.selectState.hasSelect,
              text: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                child: Text(
                  "复制",
                  style: editController.selectState.hasSelect
                      ? null
                      : TextStyle(
                          color:
                              editController.editTheme.fontColor.withOpacity(0.2),
                        ),
                ),
              ),
              childrenWidth: 200,
              onPress: (ctx) {
                if (editController.selectState.hasSelect) {
                  editController.copySelect();
                  hideDropMenu(ctx);
                }
              },
              children: [
                DropMenu(
                  text: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("复制纯文本"),
                  ),
                  onPress: (ctx) {
                    if (editController.selectState.hasSelect) {
                      editController.copySelectText();
                      hideDropMenu(ctx);
                    }
                  },
                ),
                DropMenu(
                  text: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("复制富文本"),
                  ),
                  onPress: (ctx) {
                    if (editController.selectState.hasSelect) {
                      editController.copySelect();
                      hideDropMenu(ctx);
                    }
                  },
                ),
                DropMenu(
                  text: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("复制 Markdown"),
                  ),
                  onPress: (ctx) {
                    if (editController.selectState.hasSelect) {
                      editController.copySelectMarkdown();
                      hideDropMenu(ctx);
                    }
                  },
                ),
              ]),
          DropMenu(
            text: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text(
                "剪切",
                style: editController.selectState.hasSelect
                    ? null
                    : TextStyle(
                        color:
                            editController.editTheme.fontColor.withOpacity(0.2),
                      ),
              ),
            ),
            onPress: (ctx) {
              if (editController.selectState.hasSelect) {
                editController.cut();
                hideDropMenu(ctx);
              }
            },
          ),
          //粘贴
          DropMenu(
              text: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                child: Text("粘贴"),
              ),
              childrenWidth: 200,
              onPress: (ctx) {
                editController.paste();
                hideDropMenu(ctx);
              },
              children: [
                DropMenu(
                  text: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("粘贴纯文本"),
                  ),
                  onPress: (ctx) {
                    editController.paste(pasteText: true);
                    hideDropMenu(ctx);
                  },
                ),
                DropMenu(
                  text: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("粘贴富文本"),
                  ),
                  onPress: (ctx) {
                    editController.paste();
                    hideDropMenu(ctx);
                  },
                ),
                DropMenu(
                  text: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("粘贴 Markdown"),
                  ),
                  onPress: (ctx) {
                    editController.paste(
                      pasteMarkdown: true,
                    );
                    hideDropMenu(ctx);
                  },
                ),
                DropMenu(
                  text: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text("粘贴 HTML"),
                  ),
                  onPress: (ctx) {
                    editController.paste(
                      pasteHtml: true,
                    );
                    hideDropMenu(ctx);
                  },
                ),
              ]),
          //表格
          if (editController.currentIsTable)
            DropMenu(
                text: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Text(
                    "表格",
                    style: null,
                  ),
                ),
                children: [
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "上方添加行",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.addTableRowOnPrevious();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "下方添加行",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.addTableRowOnNext();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropSplit(),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "左侧添加列",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.addTableColOnPrevious();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "右侧添加列",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.addTableColOnNext();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropSplit(),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "删除行",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.deleteTableRow();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "删除列",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.deleteTableCol();
                      hideDropMenu(ctx);
                    },
                  ),
                  DropSplit(),
                  DropMenu(
                    text: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Text(
                        "删除表格",
                        style: null,
                      ),
                    ),
                    onPress: (ctx) {
                      editController.deleteTable();
                      hideDropMenu(ctx);
                    },
                  ),
                ]),
          DropSplit(),
          DropMenu(
            enable: editController.canUndo,
            text: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text(
                "撤销",
                style: editController.canUndo
                    ? null
                    : TextStyle(
                        color: editController.editTheme.fontColor
                            .withOpacity(0.2)),
              ),
            ),
            description: Text(
              PlatformUtils.isMacOS ? "Command + Z" : "Ctrl + Z",
              style: editController.canUndo
                  ? null
                  : TextStyle(
                      color:
                          editController.editTheme.fontColor.withOpacity(0.2)),
            ),
            onPress: (ctx) {
              if (editController.canUndo) {
                editController.undo();
                hideDropMenu(ctx);
              }
            },
          ),
          DropMenu(
            enable: editController.canRedo,
            text: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text(
                "重做",
                style: editController.canRedo
                    ? null
                    : TextStyle(
                        color: editController.editTheme.fontColor
                            .withOpacity(0.2)),
              ),
            ),
            description: Text(
              PlatformUtils.isMacOS ? "Command + Y" : "Ctrl + Y",
              style: editController.canRedo
                  ? null
                  : TextStyle(
                      color:
                          editController.editTheme.fontColor.withOpacity(0.5)),
            ),
            onPress: (ctx) {
              if (editController.canRedo) {
                editController.redo();
                hideDropMenu(ctx);
              }
            },
          ),
          DropSplit(),
          DropMenu(
            text: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text("上方添加段"),
            ),
            description: Text(PlatformUtils.isMacOS
                ? "Command + Shift + Enter"
                : "Ctrl + Shift + Enter"),
            onPress: (ctx) {
              editController.addTextBlockBefore();
              hideDropMenu(ctx);
            },
          ),
          DropMenu(
            text: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text("下方添加段"),
            ),
            description:
                Text(PlatformUtils.isMacOS ? "Command + Enter" : "Ctrl + Enter"),
            onPress: (ctx) {
              editController.addTextBlock();
              hideDropMenu(ctx);
            },
          ),
        ]);
    editController.rightMenuShowing = false;
    editController.requestFocus();
    editController.updateWidgetState();
  }

  static void showContextMenu(
      WenzEditController editController, Offset localPosition) async {
    showDropContextMenu(
        editController, editController.viewContext, localPosition);
  }
}
