import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';

import '../theme/theme.dart';

enum PrimaryPosition { left, top, right, bottom }

enum Pane { primary, secondary }

class SplitLayoutController extends MvcController {
  SplitLayoutController();

  // position为primary那边的尺寸
  double position = 0;
  double primaryMinSize = 0;
  double secondaryMinSize = 0;

  // 主界面的矩形范围
  Rect primaryRect = Rect.zero;

  // 副界面的矩形范围
  Rect secondaryRect = Rect.zero;

  //分割线的矩形范围
  Rect splitRect = Rect.zero;

  // 分割线是否在拖拽过程
  bool isSplitPanStatus = false;

  // 记忆位置，用于toggle关闭或者打开primary
  double recordPosition = 0;

  // 用于判断是否隐藏了primary
  bool isPrimaryHide = false;
  bool isSecondaryHide = false;

  // 是否显示动画，拖拽过程可能要显示下动画
  bool showAnimate = false;
  int animateDuration = 50;

  bool keepPrimary = false;

  // 拖拽调节时的方向
  double? panDirectionDelta;

  double viewWidth = 0;
  double viewHeight = 0;
  PrimaryPosition primaryPosition = PrimaryPosition.left;

  void openPrimary() {
    try {
      animateDuration = 150;
      showAnimate = true;
      position = max(primaryMinSize, recordPosition);
      notifyListeners();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        animateDuration = 50;
      });
    }
  }

  void closePrimary() {
    try {
      animateDuration = 150;
      showAnimate = true;
      recordPosition = position;
      position = 0;
      notifyListeners();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        animateDuration = 50;
      });
    }
  }

  void openSecondary() {
    showAnimate = true;
    position = max(primaryMinSize, recordPosition);
    notifyListeners();
  }

  void closeSecondary() {
    showAnimate = true;
    recordPosition = position;
    position = primaryPosition == PrimaryPosition.left ||
            primaryPosition == PrimaryPosition.right
        ? viewWidth
        : viewHeight;
    notifyListeners();
  }

  void onBuildLayout({
    required SplitLayout splitLayout,
    required double viewWidth,
    required double viewHeight,
  }) {
    primaryPosition = splitLayout.primaryPosition;
    this.viewWidth = viewWidth;
    this.viewHeight = viewHeight;
    keepPrimary = splitLayout.keepPrimary;
    var position = this.position;
    if (position != 0) {
      if(isHorizontal) {
        position = min(viewWidth, position);
      }else{
        position = min(viewHeight, position);
      }
    }
    primaryMinSize = splitLayout.primaryMinSize;
    secondaryMinSize = splitLayout.secondaryMinSize;
    // 计算rect
    switch (splitLayout.primaryPosition) {
      case PrimaryPosition.left:
        var primaryWidth = max(splitLayout.primaryMinSize, position);
        var secondaryWidth =
            max(splitLayout.secondaryMinSize, viewWidth - position);
        double primaryLeft = position - primaryWidth;
        double secondaryLeft = position;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == viewWidth;
        primaryRect = Rect.fromLTWH(
          primaryLeft,
          0,
          primaryWidth,
          viewHeight,
        );
        secondaryRect = Rect.fromLTWH(
          secondaryLeft,
          0,
          secondaryWidth,
          viewHeight,
        );
        splitRect = Rect.fromLTWH(
          position - splitLayout.splitWidth / 2,
          0,
          splitLayout.splitWidth,
          viewHeight,
        );
        break;
      case PrimaryPosition.right:
        var primaryWidth = max(splitLayout.primaryMinSize, position);
        var secondaryWidth =
            max(splitLayout.secondaryMinSize, viewWidth - position);
        double primaryLeft = viewWidth - position;
        double secondaryLeft = primaryLeft - secondaryWidth;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == viewWidth;
        primaryRect = Rect.fromLTWH(
          primaryLeft,
          0,
          primaryWidth,
          viewHeight,
        );
        secondaryRect = Rect.fromLTWH(
          secondaryLeft,
          0,
          secondaryWidth,
          viewHeight,
        );
        splitRect = Rect.fromLTWH(
          (viewWidth - position) - splitLayout.splitWidth / 2,
          0,
          splitLayout.splitWidth,
          viewHeight,
        );
        break;
      case PrimaryPosition.top:
        var primaryHeight = max(splitLayout.primaryMinSize, position);
        var secondaryHeight =
            max(splitLayout.secondaryMinSize, viewHeight - position);
        double primaryTop = position - primaryHeight;
        double secondaryTop = position;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == viewHeight;
        primaryRect = Rect.fromLTWH(
          0,
          primaryTop,
          viewWidth,
          primaryHeight,
        );
        secondaryRect = Rect.fromLTWH(
          0,
          secondaryTop,
          viewWidth,
          secondaryHeight,
        );
        splitRect = Rect.fromLTWH(
          0,
          position - splitLayout.splitWidth / 2,
          viewWidth,
          splitLayout.splitWidth,
        );
        break;

      case PrimaryPosition.bottom:
        var primaryHeight = max(splitLayout.primaryMinSize, position);
        var secondaryHeight =
            max(splitLayout.secondaryMinSize, viewHeight - position);
        double primaryTop = viewHeight - position;
        double secondaryTop = primaryTop - secondaryHeight;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == viewHeight;
        primaryRect = Rect.fromLTWH(
          0,
          primaryTop,
          viewWidth,
          primaryHeight,
        );
        secondaryRect = Rect.fromLTWH(
          0,
          secondaryTop,
          viewWidth,
          secondaryHeight,
        );
        splitRect = Rect.fromLTWH(
          0,
          (viewHeight - position) - splitLayout.splitWidth / 2,
          viewWidth,
          splitLayout.splitWidth,
        );
        break;
    }
    if (splitLayout.onlyShowPosition == Pane.primary) {
      primaryRect = Rect.fromLTWH(0, 0, viewWidth, viewHeight);
      secondaryRect = Rect.zero;
      splitRect = Rect.zero;
    }
    if (splitLayout.onlyShowPosition == Pane.secondary) {
      secondaryRect = Rect.fromLTWH(0, 0, viewWidth, viewHeight);
      primaryRect = Rect.zero;
      splitRect = Rect.zero;
    }
  }

  void updatePosition(double position) {
    showAnimate = true;
    this.position = position;
    notifyListeners();
  }

  void updatePanStatus(bool isPanning) {
    isSplitPanStatus = isPanning;
    showAnimate = isPanning;
    notifyListeners();
  }

  void togglePrimary() {
    if (isPrimaryHide) {
      openPrimary();
    } else {
      closePrimary();
    }
  }

  void toggleSecondary() {
    if (isSecondaryHide) {
      openSecondary();
    } else {
      closeSecondary();
    }
  }

  void showPrimary() {
    if (isPrimaryHide) {
      openPrimary();
    }
  }

  void calcPanEndPosition(SplitLayout layout) {
    // 拖动结束时，需要将侧滑位置调到minSize
    if (position < layout.primaryMinSize) {
      if (!keepPrimary && panDirectionDelta != null && panDirectionDelta! < 0) {
        recordPosition = layout.primaryMinSize;
        position = 0;
      } else {
        position = layout.primaryMinSize;
      }
    }
  }

  void showTwoPane(SplitLayout layout) {
    if (position == 0) {
      togglePrimary();
    } else {
      position = layout.primaryMinSize;
      notifyListeners();
    }
  }

  bool isHorizontalDirection(PrimaryPosition primaryPosition) {
    return primaryPosition == PrimaryPosition.left ||
        primaryPosition == PrimaryPosition.right;
  }

  void restoreMinSize() {
    if (isHorizontal) {
      if (viewWidth - position < secondaryMinSize) {
        position = viewWidth - secondaryMinSize;
      }
    } else {
      if (viewHeight - position < secondaryMinSize) {
        position = viewHeight - secondaryMinSize;
      }
    }
    if (position < primaryMinSize) {
      position = primaryMinSize;
    }

    notifyListeners();
  }

  bool get isHorizontal => isHorizontalDirection(primaryPosition);
}

class SplitLayout extends MvcView<SplitLayoutController> {
  final Widget primary;
  final Widget secondary;
  final double splitWidth;
  final double primarySize;
  final double primaryMinSize;
  final double secondaryMinSize;
  final PrimaryPosition primaryPosition;
  final Color? splitColor;
  final bool keepPrimary;
  final bool isDrawerGesture;
  final Pane? onlyShowPosition;

  const SplitLayout({
    super.key,
    required super.controller,
    required this.primary,
    required this.secondary,
    this.splitWidth = 8,
    this.primarySize = 0,
    this.primaryMinSize = 0,
    this.secondaryMinSize = 0,
    this.primaryPosition = PrimaryPosition.left,
    this.splitColor,
    this.keepPrimary = false,
    this.isDrawerGesture = false,
    this.onlyShowPosition,
  });

  @override
  void onInitState() {
    super.onInitState();
    controller.updatePosition(primarySize);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      controller.onBuildLayout(
        splitLayout: this,
        viewWidth: cons.maxWidth,
        viewHeight: cons.maxHeight,
      );
      var primaryRect = controller.primaryRect;
      var secondaryRect = controller.secondaryRect;
      var splitRect = controller.splitRect;
      return Stack(
        children: [
          buildAnimatedPositioned(
              cons, primaryRect, buildDrawerGesture(context, cons, primary)),
          buildAnimatedPositioned(cons, secondaryRect, secondary),
          buildAnimatedPositioned(
              cons, splitRect, buildSplitWidget(context, cons)),
        ],
      );
    });
  }

  Widget buildDrawerGesture(
      BuildContext context, BoxConstraints cons, Widget child) {
    if (!isDrawerGesture) {
      return child;
    }
    bool isHorizontal = controller.isHorizontalDirection(primaryPosition);
    void panStart(event) {
      controller.updatePanStatus(true);
    }

    void panUpdate(event) {
      if (isHorizontal) {
        var delta = event.delta.dx;
        if (primaryPosition == PrimaryPosition.right ||
            primaryPosition == PrimaryPosition.bottom) {
          delta = -delta;
        }
        var position = controller.position + delta;
        position = max(0, position);
        position = min(cons.maxWidth, position);
        controller.updatePosition(position);
        controller.panDirectionDelta = delta;
      } else {
        var delta = event.delta.dy;
        if (primaryPosition == PrimaryPosition.right ||
            primaryPosition == PrimaryPosition.bottom) {
          delta = -delta;
        }
        var position = controller.position + delta;
        position = max(0, position);
        position = min(cons.maxHeight, position);
        controller.updatePosition(position);
        controller.panDirectionDelta = delta;
      }
    }

    void panEnd(event) {
      controller.updatePanStatus(false);
      controller.calcPanEndPosition(this);
    }

    return GestureDetector(
      onHorizontalDragStart: !isHorizontal ? null : panStart,
      onHorizontalDragUpdate: !isHorizontal ? null : panUpdate,
      onHorizontalDragEnd: !isHorizontal ? null : panEnd,
      onVerticalDragStart: isHorizontal ? null : panStart,
      onVerticalDragUpdate: isHorizontal ? null : panUpdate,
      onVerticalDragEnd: isHorizontal ? null : panEnd,
      child: child,
    );
  }

  Widget buildAnimatedPositioned(
      BoxConstraints boxConstraints, Rect rect, Widget child) {
    return AnimatedPositioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      duration: Duration(
        milliseconds: controller.showAnimate ? controller.animateDuration : 0,
      ),
      onEnd: () {
        if (!controller.isSplitPanStatus) {
          controller.showAnimate = false;
        }
      },
      child: SizedBox(width: rect.width, height: rect.height, child: child),
    );
  }

  Widget buildSplitWidget(BuildContext context, BoxConstraints cons) {
    MouseCursor cursor;
    bool isHorizontal = controller.isHorizontalDirection(primaryPosition);
    if (isHorizontal) {
      cursor = SystemMouseCursors.resizeColumn;
    } else {
      cursor = SystemMouseCursors.resizeRow;
    }
    var splitColor = controller.isSplitPanStatus
        ? appColor.primary
        : (this.splitColor ?? appColor.splitColor);
    double splitSize = controller.isSplitPanStatus ? 2 : 0.6;
    bool buildSide = controller.position == 0 ||
        (cursor == SystemMouseCursors.resizeRow &&
            controller.position >= cons.maxHeight) ||
        (cursor == SystemMouseCursors.resizeColumn &&
            controller.position >= cons.maxWidth);
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (e) {
          controller.updatePanStatus(true);
        },
        onPanUpdate: (details) {
          if (isHorizontal) {
            var delta = details.delta.dx;
            if (primaryPosition == PrimaryPosition.right ||
                primaryPosition == PrimaryPosition.bottom) {
              delta = -delta;
            }
            var position = controller.position + delta;
            position = max(0, position);
            position = min(cons.maxWidth, position);
            controller.updatePosition(position);
            controller.panDirectionDelta = delta;
          } else {
            var delta = details.delta.dy;
            if (primaryPosition == PrimaryPosition.right ||
                primaryPosition == PrimaryPosition.bottom) {
              delta = -delta;
            }
            var position = controller.position + delta;
            position = max(0, position);
            position = min(cons.maxHeight, position);
            controller.updatePosition(position);
            controller.panDirectionDelta = delta;
          }
        },
        onPanCancel: () {
          controller.updatePanStatus(false);
          controller.calcPanEndPosition(this);
        },
        onPanEnd: (e) {
          controller.updatePanStatus(false);
          controller.calcPanEndPosition(this);
        },
        child: buildSide
            ? buildOpenPane(context)
            : IgnorePointer(
                child: Center(
                  child: Container(
                    width: cursor == SystemMouseCursors.resizeColumn
                        ? splitSize
                        : double.infinity,
                    height: cursor == SystemMouseCursors.resizeRow
                        ? splitSize
                        : double.infinity,
                    color: splitColor,
                  ),
                ),
              ),
      ),
    );
  }

  Widget buildOpenPane(BuildContext context) {
    if (primaryPosition == PrimaryPosition.left ||
        primaryPosition == PrimaryPosition.right) {
      return SizedBox(
        width: splitWidth,
        child: InkWell(
          hoverColor: appColor.primary.withOpacity(0.2),
          onTap: () {
            controller.showTwoPane(this);
          },
        ),
      );
    }
    return SizedBox(
      height: splitWidth,
      child: InkWell(
        hoverColor: appColor.primary.withOpacity(0.2),
        onTap: () {
          controller.showTwoPane(this);
        },
      ),
    );
  }
}
