import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/platform_utils.dart';
import '../mindmap.dart';

/// 1.双击进入输入模式
/// 2.回车、tab保存输入内容，并且触发回调
/// 3.点击窗口外触发保存
/// 4.自定义输入框
class MindTreeNodeWidget extends StatefulWidget {
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onEditChanged;

  final VoidCallback? onTap;
  final MindNode node;

  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final NodeContentBuilder? nodeWidgetBuilder;
  final MindMapController controller;

  const MindTreeNodeWidget({
    super.key,
    required this.controller,
    required this.node,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.onTapDown,
    this.onEditChanged,
    this.onTapUp,
    this.nodeWidgetBuilder,
  });

  @override
  State<MindTreeNodeWidget> createState() => _MindTreeNodeWidgetState();
}

class _MindTreeNodeWidgetState extends State<MindTreeNodeWidget> {
  var editController = TextEditingController();
  var editFocusNode = FocusNode();
  var lastUptime = 0;
  bool isDoubleTap = false;

  @override
  void initState() {
    super.initState();
    editController.text = label;
    widget.node.addListener(nodeUpdate);
    if (isEditing) {
      waitAttach(() {
        showEdit(context);
      });
    }
    var update =
        widget.controller.checkNodeSizeNeedUpdate(context, widget.node);
    if (update) {
      WidgetsBinding.instance.addPostFrameCallback((time) {
        widget.controller.layout();
      });
    }
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
    widget.node.removeListener(nodeUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MindTreeNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.node.removeListener(nodeUpdate);
    widget.node.addListener(nodeUpdate);
  }

  void nodeUpdate() {
    setState(() {});
    if (widget.node.editing) {
      showEdit(context);
    }else{
      closeEdit();
    }
  }

  String get label => widget.node.info?.content ?? "";

  bool get isEditing => widget.node.editing;

  set isEditing(bool value) {
    widget.node.editing = value;
  }

  @override
  Widget build(BuildContext context) {
    Widget? child;
    var widgetBuilder = widget.nodeWidgetBuilder;
    if (widgetBuilder != null) {
      child = TapRegion(
        key: ValueKey(widget.node.uuid),
        onTapOutside: (e) {
          if (PlatformUtils.isDesktop) {
            closeEdit();
          }
        },
        child: widgetBuilder(
          context,
          NodeEditController(
            controller: widget.controller,
            node: widget.node,
            focusNode: editFocusNode,
            onContentChanged: (value) {
              widget.onChanged?.call(value);
              widget.controller.layout();
              nodeUpdate();
            },
            onEditChanged: (value) {
              if (value) {
                showEdit(context);
              } else {
                closeEdit();
              }
            },
          ),
        ),
      );
    } else {
      if (isEditing) {
        child = buildEdit(context);
      } else {
        child = Container(
          alignment: Alignment.center,
          child: Text(label),
        );
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (e) {
        widget.onTapDown?.call();
        if (DateTime.now().millisecondsSinceEpoch - lastUptime < 300) {
          isDoubleTap = true;
        } else {
          isDoubleTap = false;
        }
      },
      onTapUp: (d) {
        if (isDoubleTap) {
          if (!isEditing) {
            showEdit(context);
          }
          lastUptime = 0;
        } else {
          lastUptime = DateTime.now().millisecondsSinceEpoch;
          widget.onTapUp?.call();
        }
        lastUptime = DateTime.now().millisecondsSinceEpoch;
      },
      onTap: () {
        widget.onTap?.call();
      },
      child: buildDragTarget(context, child),
    );
  }

  Widget buildDragTarget(BuildContext context, Widget child) {
    // 拖拽笔记到思维导图节点
    return DragTarget(
      onWillAcceptWithDetails: (details) {
        return false;
      },
      onAcceptWithDetails: (details) {
      },
      builder: (BuildContext context, List<Object?> candidateData,
          List<dynamic> rejectedData) {
        var isDragging = candidateData.isNotEmpty;
        return Opacity(
          opacity: isDragging ? 0.5 : 1,
          child: child,
        );
      },
    );
  }

  void showEdit(BuildContext context) {
    widget.onEditChanged?.call(true);
    setState(
      () {
        isEditing = true;
        editController.text = label;
      },
    );
    if (widget.nodeWidgetBuilder == null) {
      waitAttach(() {
        // FocusScope.of(context).requestFocus(editFocusNode);
        editFocusNode.requestFocus();
      });
    }
  }

  void closeEdit() {
    setState(() {
      isEditing = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((t) {
      widget.onEditChanged?.call(false);
    });
  }

  Widget buildEdit(BuildContext context) {
    return FocusScope(
      child: TextField(
        focusNode: editFocusNode,
        controller: editController,
        onSubmitted: (value) {
          widget.onSubmitted?.call(value);
          closeEdit();
        },
        onChanged: (value) {
          widget.onChanged?.call(value);
          widget.node.setContent(value);
        },
        onTapOutside: (event) {
          widget.onSubmitted?.call(editController.text);
          if (widget.controller.layoutState.viewBoundRect
                  .contains(event.position) ||
              PlatformUtils.isDesktop) {
            closeEdit();
          }
        },
      ),
    );
  }
}
