import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'package:wenz_editor/commons/util/platform_util.dart';
import 'package:wenz_editor/editor/toolbar/mobile_toolbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenz_editor/editor/widget/drop_menu.dart';
import 'package:wenz_editor/editor/widget/view_insets_observer.dart';
import '../block/code/code.dart';
import '../block/table/table_block.dart';
import '../block/text/text.dart';
import '../edit_controller.dart';
import '../edit_float_widget.dart';
import '../utils/table_utils.dart';
import '../widget/toggle_item.dart';
import 'toolbar.dart';

class WenzEditMobileToolbarController extends MvcController {
  WenzEditMobileToolbarController({
    required this.editController,
    this.isCurrentEditor,
  });

  WenzEditController editController;

  var toolbarController = MobileToolbarController();

  var textLevel = 0;
  var isSelected = false;
  var isMultiLineSelection = false;
  var toolScrollController = ScrollController();
  var selectFormatState = SelectFormatState();
  bool Function()? isCurrentEditor;

  bool get isCurrentEditing {
    return isCurrentEditor?.call() ?? true;
  }

  ValueNotifier<int> get bottomIndex => toolbarController.bottomIndex;

  bool get isShowBottomPane => toolbarController.isShowBottomPane;

  bool get hasSelection => editController.selectState.hasSelect;

  @override
  void onDidUpdateWidget(
      BuildContext context, WenzEditMobileToolbarController oldController) {
    super.onDidUpdateWidget(context, oldController);
    editController = oldController.editController;
    toolbarController = oldController.toolbarController;
    textLevel = oldController.textLevel;
    isSelected = oldController.isSelected;
    toolScrollController = oldController.toolScrollController;
    isMultiLineSelection = oldController.isMultiLineSelection;
  }

  @override
  void onInitState(BuildContext context,MvcViewState state) {
    super.onInitState(context,state);
    editController.cursorState.addListener(onSelectChanged);
    editController.selectState.addListener(onSelectChanged);
  }

  @override
  void onDispose() {
    editController.selectState.removeListener(onSelectChanged);
    editController.cursorState.removeListener(onSelectChanged);
    super.onDispose();
  }

  void onSelectChanged() {
    updateScrollBySelectChanged();
    updateFormatStateBySelectChanged();
    getSelectFormatState();
    notifyListeners();
  }

  void updateFormatStateBySelectChanged() {
    var index = editController.currentStartBlockIndex;
    if (index == -1) {
      return;
    }
    var block = editController.blockManager.blocks[index];
    if (block is TextBlock) {
      textLevel = block.level;
    } else {
      textLevel = 0;
    }
  }

  void updateScrollBySelectChanged() {
    var newIsSelected = editController.selectState.hasSelect;
    if (newIsSelected) {
      var newIsMultiLineSelection = editController.currentStartBlockIndex !=
          editController.currentEndBlockIndex;
      if (newIsMultiLineSelection != isMultiLineSelection ||
          isSelected != newIsSelected) {
        if (newIsMultiLineSelection) {
          animateToStart();
        } else {
          animateToEnd();
        }
        isMultiLineSelection = newIsMultiLineSelection;
      }
    }
    if (isSelected != newIsSelected) {
      if (!newIsSelected) {
        animateToStart();
      }
      isSelected = newIsSelected;
    }
  }

  void animateToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (toolScrollController.hasClients) {
        toolScrollController.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.linear);
      }
    });
  }

  void animateToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (toolScrollController.hasClients) {
        toolScrollController.animateTo(
            toolScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.linear);
      }
    });
  }

  void showBottomPane(BuildContext context, int index) {
    toolbarController.showBottomPane(context, index);
    editController.inputManager.closeInputMethod();
  }

  void closeBottomPane() {
    toolbarController.isShowBottomPane = false;
    editController.inputManager.openInputMethod();
  }

  void openInputMethod() {
    toolbarController.isShowBottomPane = false;
    editController.inputManager.openInputMethod();
  }

  void closeInputMethod() {
    editController.focusNode.unfocus();
    toolbarController.isShowBottomPane = false;
    editController.inputManager.closeInputMethod();
    notifyListeners();
  }

  void addTextBlock() {
    editController.addTextBlock();
  }

  void addQuote() {
    editController.changeTextToQuote();
  }

  void addLine() {
    editController.addLine();
  }

  void addLink() {
    editController.addLink();
  }

  void addFormula() async {
    editController.addFormula();
  }

  void addCodeBlock() {
    editController.addCodeBlock();
  }

  void addTable() {
    TableUtils.showAddTableDialog(editController);
  }

  Future addImage(String imageFile) async {
    await editController.pasteImageFile(imageFile);
  }

  void setAlignment(String? param0) {
    editController.setAlignment(param0);
  }

  void setTextLevel(int level) {
    editController.setTextLevel(level);
  }

  void setTodoList() {
    editController.setItemType(itemType: "check");
  }

  void setBulletedList() {
    editController.setItemType(itemType: "li");
  }

  void setNumberList() {
    editController.setItemType(itemType: "oli");
  }

  void clearFormat() {
    editController.clearStyle();
  }

  void formatBold() {
    var value = !selectFormatState.isBold;
    editController.setBold(value);
    selectFormatState.isBold = value;
    notifyListeners();
  }

  void formatItalic() {
    var value = !selectFormatState.isItalic;
    editController.setItalic(value);
    selectFormatState.isItalic = value;
    notifyListeners();
  }

  void formatUnderline() {
    var value = !selectFormatState.isUnderLine;
    editController.setUnderline(value);
    selectFormatState.isUnderLine = value;
    notifyListeners();
  }

  void formatStrikethrough() {
    var value = !selectFormatState.isDeleteLine;
    editController.setLineThrough(value);
    selectFormatState.isDeleteLine = value;
    notifyListeners();
  }

  void setTextColor(int index) {
    editController.setTextColor(index);
    notifyListeners();
  }

  void setBackgroundColor(int index) {
    editController.setBackgroundColor(index);
    notifyListeners();
  }

  void increaseIndent() {
    editController.addIndent();
  }

  void decreaseIndent() {
    editController.removeIndent();
  }

  void getSelectFormatState() {
    var start = editController.selectState.realStart;
    var end = editController.selectState.realEnd;

    //标题、粗体、颜色、斜体、下划线、删除线、链接、标记
    bool showLink = start?.block == end?.block && start?.block is TextBlock;
    if (start?.block == end?.block && start?.block is TableBlock) {
      var tableBlock = start!.block as TableBlock;
      showLink = tableBlock.isShowLink(
          start.textPosition!.offset, end!.textPosition!.offset);
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

    editController.visitSelectElement((block, element) {
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
    editController.visitSelectBlock((block) {
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
    selectFormatState.blockTextLevel = blockTextLevel ?? 0;
    selectFormatState.showBlockTextLevel = showBlockTextLevel;
    selectFormatState.showAlignment = showAlignment;
    selectFormatState.showLink = showLink;
    selectFormatState.isRemark = isRemark;
    selectFormatState.isBold = isBold;
    selectFormatState.isItalic = isItalic;
    selectFormatState.isUnderLine = isUnderLine;
    selectFormatState.isDeleteLine = isDeleteLine;
    selectFormatState.hasText = hasText;
  }

  String getTextLevelText() {
    if (textLevel != 0) {
      return "H$textLevel";
    }
    return "H";
  }
}

class WenzEditMobileToolbar extends MvcView<WenzEditMobileToolbarController> {
  final Widget child;

  const WenzEditMobileToolbar({
    super.key,
    required super.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: controller.editController.focusNotifier,
        builder: (context, c) {
          if (!isMobile) {
            return child;
          }
          return MobileToolbar(
            controller: controller.toolbarController,
            showToolbar: controller.editController.focusNotifier.value,
            toolbar: buildBottomToolbar(context),
            bottomPanes: [
              buildCreatePane(context),
              buildFontStylePane(context)
            ],
            child: child,
          );
        });
  }

  Widget buildBottomToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          // 左侧"+"按钮
          SizedBox(
            height: 40,
            width: 40,
            child: ViewInsetsObserver(
              shouldRebuild: (oldInsets, newInsets) {
                var dp = oldInsets.bottom - newInsets.bottom;
                if (dp < 0) {
                  if (controller.isShowBottomPane) {
                    controller.closeBottomPane();
                  }
                }
                return oldInsets.bottom != newInsets.bottom;
              },
              builder: (context, viewInsets) {
                return ValueListenableBuilder(
                  valueListenable: controller.bottomIndex,
                  builder: (context, index, child) {
                    return IconButton(
                      icon: Icon(
                        (controller.isShowBottomPane && index == 0)
                            ? Icons.cancel
                            : Icons.add_box_outlined,
                        size: 24,
                      ),
                      onPressed: () {
                        if (controller.isShowBottomPane && index == 0) {
                          controller.closeBottomPane();
                        } else {
                          controller.showBottomPane(context, 0);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          // 中间滚动工具栏
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 40,
              child: ListenableBuilder(
                  listenable: controller.editController.selectState,
                  builder: (context, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: controller.toolScrollController,
                      child: Row(
                        children: controller.hasSelection
                            ? _buildSelectionTools(context)
                            : _buildNormalTools(context),
                      ),
                    );
                  }),
            ),
          ),
          // 右侧收起键盘按钮
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.keyboard_hide),
              onPressed: controller.closeInputMethod,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSelectionTools(BuildContext context) {
    var primary = Theme.of(context).colorScheme.primary;
    return [
      IconButton(
        icon: const Icon(Icons.check_box_outlined),
        onPressed: () {
          controller.setTodoList();
        },
        tooltip: '待办',
      ),
      IconButton(
        icon: const Icon(Icons.format_list_bulleted),
        onPressed: () {
          controller.setBulletedList();
        },
        tooltip: '无序列表',
      ),
      IconButton(
        icon: const Icon(Icons.format_list_numbered),
        onPressed: () {
          controller.setNumberList();
        },
        tooltip: '有序列表',
      ),
      buildTitlePopupMenu(),
      IconButton(
        icon: const Icon(Icons.format_indent_increase),
        onPressed: () {
          controller.increaseIndent();
        },
        tooltip: '增加缩进',
      ),
      IconButton(
        icon: const Icon(Icons.format_indent_decrease),
        onPressed: () {
          controller.decreaseIndent();
        },
        tooltip: '减少缩进',
      ),
      IconButton(
        icon: const Icon(Icons.format_clear),
        onPressed: () {
          controller.clearFormat();
        },
        tooltip: '清除格式',
      ),
      IconButton(
        icon: const Icon(Icons.format_color_text),
        onPressed: () {
          controller.showTextColorPicker(context);
        },
        tooltip: '文字颜色',
      ),
      IconButton(
        icon: const Icon(Icons.format_color_fill),
        onPressed: () {
          controller.showBackgroundColorPicker(context);
        },
        tooltip: '背景色',
      ),
      IconButton(
        icon: Icon(
          Icons.format_bold,
          color: controller.selectFormatState.isBold ? primary : null,
        ),
        onPressed: () {
          controller.formatBold();
        },
        tooltip: '加粗',
      ),
      IconButton(
        icon: Icon(
          Icons.format_italic,
          color: controller.selectFormatState.isItalic ? primary : null,
        ),
        onPressed: () {
          controller.formatItalic();
        },
        tooltip: '斜体',
      ),
      IconButton(
        icon: Icon(
          Icons.format_underline,
          color: controller.selectFormatState.isUnderLine ? primary : null,
        ),
        onPressed: () {
          controller.formatUnderline();
        },
        tooltip: '下划线',
      ),
      IconButton(
        icon: Icon(
          Icons.format_strikethrough,
          color: controller.selectFormatState.isDeleteLine ? primary : null,
        ),
        onPressed: () {
          controller.formatStrikethrough();
        },
        tooltip: '删除线',
      ),
    ];
  }

  List<Widget> _buildNormalTools(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.check_box_outlined),
        onPressed: () {
          controller.setTodoList();
        },
        tooltip: '待办',
      ),
      IconButton(
        icon: const Icon(Icons.format_list_bulleted),
        onPressed: () {
          controller.setBulletedList();
        },
        tooltip: '无序列表',
      ),
      IconButton(
        icon: const Icon(Icons.format_list_numbered),
        onPressed: () {
          controller.setNumberList();
        },
        tooltip: '有序列表',
      ),
      buildTitlePopupMenu(),
      IconButton(
        icon: const Icon(Icons.image),
        onPressed: () {
          showAddImageDialog(context);
        },
        tooltip: '图片',
      ),
      IconButton(
        icon: const Icon(Icons.format_indent_increase),
        onPressed: () {
          controller.increaseIndent();
        },
        tooltip: '增加缩进',
      ),
      IconButton(
        icon: const Icon(Icons.format_indent_decrease),
        onPressed: () {
          controller.decreaseIndent();
        },
        tooltip: '减少缩进',
      ),
    ];
  }

  Builder buildTitlePopupMenu() {
    return Builder(builder: (context) {
      return IconButton(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(EdgeInsets.zero),
        ),
        icon: Text(
          controller.getTextLevelText(),
          style: const TextStyle(fontSize: 20),
        ),
        tooltip: '标题',
        onPressed: () {
          showDropMenu(
            context,
            modal: false,
            childrenWidth: 120,
            childrenHeight: 40,
            popupAlignment: Alignment.topLeft,
            menus: [
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("正文"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 0)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(0);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题1"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 1)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(1);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题2"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 2)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(2);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题3"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 3)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(3);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题4"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 4)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(4);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题5"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 5)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(5);
                },
              ),
              DropMenu(
                text: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("标题6"),
                    SizedBox(
                      width: 8,
                    ),
                    if (controller.textLevel == 6)
                      Icon(
                        Icons.check,
                        size: 16,
                      ),
                  ],
                ),
                onPress: (ctx) {
                  hideDropMenu(ctx);
                  controller.setTextLevel(6);
                },
              ),
            ].reversed.toList(),
          );
        },
      );
    });
  }

  Widget buildCreatePane(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: GridView.extent(
        maxCrossAxisExtent: 180,
        padding: const EdgeInsets.all(10),
        childAspectRatio: 3.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _buildCreateButton(
            context,
            icon: Icons.text_fields,
            text: '添加行',
            onTap: () {
              controller.addTextBlock();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.format_quote,
            text: '引用',
            onTap: () {
              controller.addQuote();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.horizontal_rule,
            text: '分割线',
            onTap: () {
              controller.addLine();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.link,
            text: '链接',
            onTap: () {
              controller.addLink();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.functions,
            text: '公式',
            onTap: () {
              controller.addFormula();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.code,
            text: '代码',
            onTap: () {
              controller.addCodeBlock();
              controller.closeBottomPane();
            },
          ),
          _buildCreateButton(
            context,
            icon: Icons.table_chart,
            text: '表格',
            onTap: () {
              controller.addTable();
              controller.closeBottomPane();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon),
              ),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }

  void showAddImageDialog(BuildContext context) async {
    var imagePicker = ImagePicker();
    var list = await imagePicker.pickMultiImage();
    if (list.isNotEmpty) {
      for (var item in list) {
        await controller.addImage(item.path);
      }
    }
  }

  Widget buildFontStylePane(BuildContext context) {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        children: [
          // 正文-标题
          Container(
            height: 48,
            margin: EdgeInsets.only(
              top: 10,
              left: 10,
              bottom: 10,
              right: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.black54 : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: buildHeadingButton(context, i),
                  ),
              ],
            ),
          ),
          // 缩进-对齐方式
          Row(
            children: [
              // 缩进
              Expanded(
                flex: 2,
                child: Container(
                    height: 48,
                    margin: EdgeInsets.only(
                      left: 10,
                      bottom: 10,
                      right: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black54
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: buildToggleButton(
                            context,
                            child: Icon(
                              Icons.format_indent_increase_outlined,
                              size: 24,
                            ),
                            onPress: () {
                              controller.editController.addIndent();
                            },
                          ),
                        ),
                        Expanded(
                          child: buildToggleButton(
                            context,
                            child: Icon(
                              Icons.format_indent_decrease_outlined,
                              size: 24,
                            ),
                            onPress: () {
                              controller.editController.removeIndent();
                            },
                          ),
                        ),
                      ],
                    )),
              ),
              // 对齐方式
              Expanded(
                flex: 3,
                child: Container(
                    height: 48,
                    margin: EdgeInsets.only(
                      left: 5,
                      bottom: 10,
                      right: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: buildToggleButton(
                            context,
                            child: Icon(
                              Icons.format_align_left_outlined,
                              size: 24,
                            ),
                            onPress: () {
                              controller.setAlignment(null);
                            },
                          ),
                        ),
                        Expanded(
                          child: buildToggleButton(
                            context,
                            child: Icon(
                              Icons.format_align_center_outlined,
                              size: 24,
                            ),
                            onPress: () {
                              controller.setAlignment("center");
                            },
                          ),
                        ),
                        Expanded(
                          child: buildToggleButton(
                            context,
                            child: Icon(
                              Icons.format_align_right_outlined,
                              size: 24,
                            ),
                            onPress: () {
                              controller.setAlignment("right");
                            },
                          ),
                        ),
                      ],
                    )),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget buildHeadingButton(BuildContext context, int level) {
    String levelText = "正文";
    if (level > 0) {
      levelText = "H$level";
    }
    return ToggleItem(
      checked: controller.textLevel == level,
      onTap: (context) {
        if (controller.textLevel != level) {
          controller.setTextLevel(level);
          controller.textLevel = level;
          controller.closeBottomPane();
        }
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        bool isChecked = controller.textLevel == level;
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(levelText)),
        );
      },
    );
  }

  Widget buildToggleButton(
    BuildContext context, {
    Widget? child,
    bool isChecked = false,
    VoidCallback? onPress,
  }) {
    return ToggleItem(
      checked: isChecked,
      onTap: (context) {
        onPress?.call();
      },
      itemBuilder:
          (BuildContext context, bool checked, bool hover, bool pressed) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Opacity(
            opacity: pressed ? 0.4 : 1,
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

extension WenzEditMobileToolbarControllerExtension
    on WenzEditMobileToolbarController {
  void showTextColorPicker(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = Offset(0, button.size.height);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero) + offset,
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showDropMenu(
      context,
      childrenWidth: 270,
      childrenHeight: 30,
      popupAlignment: Alignment.topLeft,
      menus: [
        DropMenu(
          height: 270 * 7 / 9 + 10,
          text: Builder(
            builder: (context) {
              return Container(
                width: 270,
                height: 270 * 7 / 9 + 1,
                child: GridView.builder(
                  itemCount: defaultColors.length,
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 9,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4),
                  itemBuilder: (context, index) {
                    return ToggleItem(
                      onTap: (context) {
                        setTextColor(index);
                        hideDropMenu(context);
                      },
                      itemBuilder: (BuildContext context, bool checked,
                          bool hover, bool pressed) {
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
          ),
          enable: true,
        ),
      ],
    );
  }

  void showBackgroundColorPicker(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = Offset(0, button.size.height);
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero) + offset,
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showDropMenu(
      context,
      childrenWidth: 270,
      childrenHeight: 30,
      popupAlignment: Alignment.topLeft,
      menus: [
        DropMenu(
          height: 270 * 7 / 9 + 10,
          text: Builder(
            builder: (context) {
              return Container(
                width: 270,
                height: 270 * 7 / 9 + 1,
                child: GridView.builder(
                  itemCount: defaultColors.length,
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 9,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4),
                  itemBuilder: (context, index) {
                    return ToggleItem(
                      onTap: (context) {
                        setBackgroundColor(index);
                        hideDropMenu(context);
                      },
                      itemBuilder: (BuildContext context, bool checked,
                          bool hover, bool pressed) {
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
          ),
          enable: true,
        ),
      ],
    );
  }
}
