import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../button/toggle_item.dart';
import 'popup_stack.dart';
import 'popup_window.dart';

class DropSplit extends DropMenu {
  DropSplit({
    Color? color,
  }) {
    super.height = 10;
    super.text = Builder(builder: (context) {
      var lineColor = Theme.of(context).hintColor.withOpacity(0.1);

      return Container(
        color: color ?? lineColor,
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 0.5,
      );
    });
    super.enable = false;
  }
}

class DropMenu {
  List<DropMenu>? children;
  Widget? icon;
  Widget? text;
  Widget? description;
  double? height;
  bool enable;
  bool? checked;
  ScrollController? scrollController;

  ItemVoidCallback? onPress;
  double? childrenWidth;
  double? childrenHeight;

  DropMenu({
    this.children,
    this.icon,
    this.text,
    this.description,
    this.onPress,
    this.childrenWidth,
    this.childrenHeight,
    this.enable = true,
    this.checked,
    this.height,
    this.scrollController,
  });
}

class DropMenuWidget extends StatefulWidget {
  final BuildContext buttonContext;
  final Rect anchorRect;
  final List<DropMenu> menus;
  final bool modal;
  final double childrenWidth;
  final double childrenHeight;
  final double margin;
  final double maxHeight;
  final OverlayEntry? entry;
  final Alignment? popupAlignment;
  final Alignment? overflowAlignment;
  final ScrollController? rootScrollController;
  final EdgeInsets itemPadding;

  const DropMenuWidget({
    super.key,
    required this.buttonContext,
    required this.menus,
    required this.anchorRect,
    required this.childrenWidth,
    required this.childrenHeight,
    required this.margin,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.maxHeight = double.infinity,
    this.modal = false,
    this.popupAlignment,
    this.overflowAlignment,
    this.rootScrollController,
    this.entry,
  });

  @override
  State<DropMenuWidget> createState() => DropMenuWidgetState();
}

class DropMenuWidgetState extends State<DropMenuWidget> {
  List<List<DropMenu>> levelList = [];
  List<Rect> levelHoverRect = [];
  List<DropMenu?> levelHoverMenu = [];

  @override
  void initState() {
    super.initState();
    levelList.clear();
    levelHoverRect.clear();
    levelHoverMenu.clear();
    levelList.add(widget.menus);
    levelHoverRect.add(widget.anchorRect);
    levelHoverMenu.add(null);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: PopupStack(
          children: [
            for (var i = 0; i < levelList.length; i++)
              buildPopupWidgets(context, i),
          ],
        ),
      ),
    );
  }

  PopupPositionWidget buildPopupWidgets(BuildContext context, int level) {
    var children = <Widget>[];
    var menus = levelList[level];
    for (var menu in menus) {
      var menuHeight = menu.height ??
          (levelHoverMenu[level]?.childrenHeight ?? widget.childrenHeight);
      children.add(
        Builder(builder: (context) {
          return ToggleItem(
            checked: menu.checked == true,
            onTap: (ctx) {
              if (menu.enable) {
                menu.onPress?.call(ctx);
              }
              if(!kIsWeb) {
                if (Platform.isAndroid || Platform.isIOS) {
                  showChildrenMenu(level, menu, context);
                }
              }
            },
            onHoverEnter: (ctx) {
              //清除下一个level的menu即可
              showChildrenMenu(level, menu, context);
            },
            itemBuilder:
                (BuildContext context, bool checked, bool hover, bool pressed) {
              return Container(
                height: menuHeight,
                padding: widget.itemPadding,
                decoration: BoxDecoration(
                  color: menu.enable &&
                          ((hover || pressed || checked) ||
                              (levelHoverMenu.length > level + 1 &&
                                  levelHoverMenu[level + 1] == menu))
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : null,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    if (menu.icon != null) menu.icon!,
                    if (menu.text != null) Expanded(child: menu.text!),
                    if (menu.description != null) menu.description!,
                    if (menu.children?.isNotEmpty == true)
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: menu.enable
                            ? Theme.of(context).textTheme.bodyMedium?.color
                            : Theme.of(context).hintColor,
                      ),
                  ],
                ),
              );
            },
          );
        }),
      );
    }
    return PopupPositionWidget(
      anchorRect: levelHoverRect[level],
      keepVision: true,
      popupAlignment: level == 0
          ? (widget.popupAlignment ?? Alignment.bottomLeft)
          : Alignment.centerRight,
      overflowAlignment: level == 0
          ? (widget.overflowAlignment ?? Alignment.bottomRight)
          : Alignment.centerLeft,
      verticalAlignment: VerticalAlignment.top,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: levelHoverMenu[level]?.childrenWidth ?? widget.childrenWidth,
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight,
          ),
          margin: level == 0
              ? EdgeInsets.all(widget.margin)
              : const EdgeInsets.only(
                  left: 4,
                  right: 4,
                ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(4),
                controller: level == 0
                    ? widget.rootScrollController
                    : levelHoverMenu[level]?.scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void showChildrenMenu(int level, DropMenu menu, BuildContext context) {
    if (levelHoverMenu.length > level + 1 &&
        levelHoverMenu[level + 1] == menu) {
      return;
    }
    var box = context.findRenderObject() as RenderBox;
    var itemRect = box.localToGlobal(Offset.zero) & box.size;
    levelList.removeRange(level + 1, levelList.length);
    levelHoverRect.removeRange(level + 1, levelHoverRect.length);
    levelHoverMenu.removeRange(level + 1, levelHoverMenu.length);
    WidgetsBinding.instance.scheduleFrameCallback((timeStamp) {
      setState(() {
        if (menu.children != null && menu.enable) {
          levelList.add(menu.children!);
          levelHoverRect.add(itemRect);
          levelHoverMenu.add(menu);
        }
      });
    });
  }
}

Future<void> showDropMenu(
  BuildContext context, {
  required List<DropMenu> menus,
  EdgeInsets itemPadding = const EdgeInsets.symmetric(horizontal: 8),
  double childrenWidth = 200,
  double childrenHeight = 30,
  double margin = 0,
  Offset offset = Offset.zero,
  bool modal = false,
  Alignment? popupAlignment,
  Alignment? overflowAlignment,
}) async {
  var box = context.findRenderObject() as RenderBox;
  var anchorRect = box.localToGlobal(offset) & box.size;
  var widget = DropMenuWidget(
    buttonContext: context,
    menus: menus,
    anchorRect: anchorRect,
    childrenWidth: childrenWidth,
    childrenHeight: childrenHeight,
    margin: margin,
    popupAlignment: popupAlignment,
    overflowAlignment: overflowAlignment,
    itemPadding: itemPadding,
  );
  if (modal) {
    await showDialog(
        barrierColor: Colors.transparent,
        useSafeArea: false,
        context: context,
        builder: (context) {
          return PopupWindowWidget(
            entry: null,
            modal: true,
            child: widget,
          );
        });
    return;
  }
  await showPopupWindow(
    context,
    widget,
  );
}

Future<void> showMouseDropMenu(
  BuildContext context,
  Rect anchorRect, {
  required List<DropMenu> menus,
  double childrenWidth = 200,
  double childrenHeight = 30,
  double margin = 0,
  bool modal = false,
  Alignment? popupAlignment,
  Alignment? overflowAlignment,
}) async {
  var widget = DropMenuWidget(
    buttonContext: context,
    menus: menus,
    anchorRect: anchorRect,
    childrenWidth: childrenWidth,
    childrenHeight: childrenHeight,
    margin: margin,
    popupAlignment: popupAlignment,
    overflowAlignment: overflowAlignment,
  );
  if (modal) {
    await showDialog(
        barrierColor: Colors.transparent,
        useSafeArea: false,
        context: context,
        builder: (context) {
          return PopupWindowWidget(
            entry: null,
            modal: true,
            child: widget,
          );
        });
    return;
  }
  await showPopupWindow(context, widget);
}

void hideDropMenu(BuildContext context) {
  var widget = context.findAncestorWidgetOfExactType<PopupWindowWidget>();
  if (widget == null) {
    return;
  }
  widget.entry?.remove();
  if (widget.modal) {
    Navigator.of(context).pop();
  }
}

bool hasDropMenu(BuildContext context) {
  var widget = context.findAncestorWidgetOfExactType<PopupWindowWidget>();
  return widget != null;
}