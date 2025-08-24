import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../../data/index.dart';
import '../mind_map_controller.dart';

class MindScrollState with ChangeNotifier {
  MindScrollState(this.controller);

  MindMapController controller;

  var verticalController = ScrollController();
  var horizontalController = ScrollController();

  // 水平滚动控制器
  ViewportOffset? get xOffset =>
      horizontalController.hasClients ? horizontalController.position : null;

  // 垂直滚动控制器
  ViewportOffset? get yOffset =>
      verticalController.hasClients ? verticalController.position : null;

  // 是否需要重新计算滚动位置，默认为true
  bool needCalcScrollStatus = true;

  // 用来判断位置是否更新的
  double? xScrollEndRecord;
  double? yScrollEndRecord;
  Timer? scrollEndTimer;

  Offset get xScrollExtent {
    var xOffset = this.xOffset;
    if (xOffset is ScrollPosition) {
      return Offset(xOffset.minScrollExtent, xOffset.maxScrollExtent);
    }
    return Offset.zero;
  }

  Offset get yScrollExtent {
    var yOffset = this.yOffset;
    if (yOffset is ScrollPosition) {
      return Offset(yOffset.minScrollExtent, yOffset.maxScrollExtent);
    }
    return Offset.zero;
  }

  void scrollToNode(MindNode node, bool needUpdateExpand) {
    var viewSize = controller.layoutState.viewSize;
    if (viewSize == null) {
      return;
    }
    if (needUpdateExpand && controller.setParentExpand(node, true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToNode(node, false);
      });
      return;
    }
    var stackRect = node.getStackRect(
      viewSize: viewSize,
      scale: controller.scale,
      xOffset: xOffset,
      yOffset: yOffset,
    );
    var viewRect = Offset.zero & viewSize;
    var viewPadding = 50;
    if (stackRect.left - viewPadding < viewRect.left) {
      var pix = (xOffset?.pixels ?? 0) -
          (viewRect.left - stackRect.left + viewPadding);
      xOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    if (stackRect.right + viewPadding > viewRect.right) {
      var pix = (xOffset?.pixels ?? 0) +
          (stackRect.right + viewPadding - viewRect.right);
      xOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }

    if (stackRect.top - viewPadding < viewRect.top) {
      var pix =
          (yOffset?.pixels ?? 0) - (viewRect.top - stackRect.top + viewPadding);
      yOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    if (stackRect.bottom + viewPadding > viewRect.bottom) {
      var pix = (yOffset?.pixels ?? 0) +
          (stackRect.bottom + viewPadding - viewRect.bottom);
      yOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
  }

  void scrollToNodeLeftCenter(MindNode node, bool needUpdateExpand) {
    var viewSize = controller.layoutState.viewSize;
    if (viewSize == null) {
      return;
    }
    if (needUpdateExpand && controller.setParentExpand(node, true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToNode(node, false);
      });
      return;
    }
    var stackRect = node.getStackRect(
      viewSize: viewSize,
      scale: controller.scale,
      xOffset: xOffset,
      yOffset: yOffset,
    );
    var viewRect = Offset.zero & viewSize;
    var viewPadding = 50;
    if (stackRect.left - viewPadding < viewRect.left) {
      var pix = (xOffset?.pixels ?? 0) -
          (viewRect.left - stackRect.left + viewPadding);
      xOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    if (stackRect.right + viewPadding > viewRect.right) {
      var pix = (xOffset?.pixels ?? 0) +
          (stackRect.right + viewPadding - viewRect.right);
      xOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }

    if (stackRect.top - viewPadding < viewRect.top) {
      var pix =
          (yOffset?.pixels ?? 0) - (viewRect.top - stackRect.top + viewPadding);
      yOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    if (stackRect.bottom + viewPadding > viewRect.bottom) {
      var pix = (yOffset?.pixels ?? 0) +
          (stackRect.bottom + viewPadding - viewRect.bottom);
      yOffset?.animateTo(
        pix,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
  }

  void jumpTo(Offset offset) {
    xOffset?.jumpTo(offset.dx);
    yOffset?.jumpTo(offset.dy);
  }

  Offset getScrollOffset() {
    return Offset(xOffset?.pixels ?? 0, yOffset?.pixels ?? 0);
  }

  void onScrollEnd() {
    scrollEndTimer?.cancel();
    scrollEndTimer = Timer(
      const Duration(milliseconds: 200),
      () {
        var offset = getScrollOffset();
        if (xScrollEndRecord != offset.dx || yScrollEndRecord != offset.dy) {
          xScrollEndRecord = offset.dx;
          yScrollEndRecord = offset.dy;
          notifyListeners();
          controller.fireOnChange();
        }
      },
    );
  }
}
