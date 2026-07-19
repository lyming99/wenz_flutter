import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';

import '../theme/theme.dart';

enum PrimaryPosition { left, top, right, bottom }

enum Pane { primary, secondary }

bool _isFiniteNonNegative(double value) {
  return value.isFinite && !value.isNaN && value >= 0;
}

double _finiteOrZero(double value) {
  return value.isFinite && !value.isNaN ? value : 0;
}

double _finiteNonNegativeOrZero(double value) {
  final safeValue = _finiteOrZero(value);
  return safeValue < 0 ? 0 : safeValue;
}

double _clampBetween(double value, double minValue, double maxValue) {
  final safeMin = _finiteOrZero(minValue);
  final safeMax = _finiteOrZero(maxValue);
  final lower = min(safeMin, safeMax);
  final upper = max(safeMin, safeMax);
  final safeValue = _finiteOrZero(value);
  return min(max(safeValue, lower), upper);
}

double _clampPositionForMinSizes({
  required double position,
  required double viewSize,
  required double primaryMinSize,
  required double secondaryMinSize,
}) {
  final safeViewSize = _finiteNonNegativeOrZero(viewSize);
  if (safeViewSize == 0) {
    return 0;
  }

  final safePosition = _clampBetween(
    _finiteNonNegativeOrZero(position),
    0,
    safeViewSize,
  );
  final minPosition = min(
    _finiteNonNegativeOrZero(primaryMinSize),
    safeViewSize,
  );
  final maxPosition = max(
    0.0,
    safeViewSize - _finiteNonNegativeOrZero(secondaryMinSize),
  );

  if (minPosition <= maxPosition) {
    return _clampBetween(safePosition, minPosition, maxPosition);
  }
  return safePosition;
}

Rect _safeRectFromLTWH(
  double left,
  double top,
  double width,
  double height,
) {
  return Rect.fromLTWH(
    _finiteOrZero(left),
    _finiteOrZero(top),
    _finiteNonNegativeOrZero(width),
    _finiteNonNegativeOrZero(height),
  );
}

Rect _horizontalSplitRect({
  required double boundary,
  required double viewWidth,
  required double viewHeight,
  required double splitWidth,
}) {
  final safeViewWidth = _finiteNonNegativeOrZero(viewWidth);
  final safeViewHeight = _finiteNonNegativeOrZero(viewHeight);
  final safeSplitWidth = min(
    _finiteNonNegativeOrZero(splitWidth),
    safeViewWidth,
  );
  if (safeViewWidth == 0 || safeViewHeight == 0 || safeSplitWidth == 0) {
    return Rect.zero;
  }

  return _safeRectFromLTWH(
    _clampBetween(
      _finiteOrZero(boundary) - safeSplitWidth / 2,
      0,
      safeViewWidth - safeSplitWidth,
    ),
    0,
    safeSplitWidth,
    safeViewHeight,
  );
}

Rect _verticalSplitRect({
  required double boundary,
  required double viewWidth,
  required double viewHeight,
  required double splitWidth,
}) {
  final safeViewWidth = _finiteNonNegativeOrZero(viewWidth);
  final safeViewHeight = _finiteNonNegativeOrZero(viewHeight);
  final safeSplitWidth = min(
    _finiteNonNegativeOrZero(splitWidth),
    safeViewHeight,
  );
  if (safeViewWidth == 0 || safeViewHeight == 0 || safeSplitWidth == 0) {
    return Rect.zero;
  }

  return _safeRectFromLTWH(
    0,
    _clampBetween(
      _finiteOrZero(boundary) - safeSplitWidth / 2,
      0,
      safeViewHeight - safeSplitWidth,
    ),
    safeViewWidth,
    safeSplitWidth,
  );
}

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
  VoidCallback? onPoistionChanged;

  void openPrimary() {
    try {
      animateDuration = 150;
      showAnimate = true;
      position = _clampPositionToCurrentView(
        max(
          _finiteNonNegativeOrZero(primaryMinSize),
          _finiteNonNegativeOrZero(recordPosition),
        ),
      );
      notifyListeners();
      onPoistionChanged?.call();
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
      recordPosition = _finiteNonNegativeOrZero(position);
      position = 0;
      notifyListeners();
      onPoistionChanged?.call();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        animateDuration = 50;
      });
    }
  }

  void openSecondary() {
    showAnimate = true;
    position = _clampPositionToCurrentView(
      max(
        _finiteNonNegativeOrZero(primaryMinSize),
        _finiteNonNegativeOrZero(recordPosition),
      ),
    );
    notifyListeners();
    onPoistionChanged?.call();
  }

  void closeSecondary() {
    showAnimate = true;
    recordPosition = _finiteNonNegativeOrZero(position);
    position = _currentMainAxisSize;
    notifyListeners();
    onPoistionChanged?.call();
  }

  void onBuildLayout({
    required SplitLayout splitLayout,
    required double viewWidth,
    required double viewHeight,
  }) {
    onPoistionChanged = splitLayout.onPoistionChanged;
    primaryPosition = splitLayout.primaryPosition;
    this.viewWidth = _finiteNonNegativeOrZero(viewWidth);
    this.viewHeight = _finiteNonNegativeOrZero(viewHeight);
    keepPrimary = splitLayout.keepPrimary;
    primaryMinSize = _finiteNonNegativeOrZero(splitLayout.primaryMinSize);
    secondaryMinSize = _finiteNonNegativeOrZero(splitLayout.secondaryMinSize);

    var position = _clampPositionToCurrentView(this.position);
    if (this.position != position) {
      this.position = position;
    }

    final splitWidth = _finiteNonNegativeOrZero(splitLayout.splitWidth);

    // 计算rect
    switch (splitLayout.primaryPosition) {
      case PrimaryPosition.left:
        final primaryWidth = max(primaryMinSize, position);
        final secondaryWidth = max(secondaryMinSize, this.viewWidth - position);
        final primaryLeft = position - primaryWidth;
        final secondaryLeft = position;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == this.viewWidth;
        primaryRect = isPrimaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                primaryLeft,
                0,
                primaryWidth,
                this.viewHeight,
              );
        secondaryRect = isSecondaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                secondaryLeft,
                0,
                secondaryWidth,
                this.viewHeight,
              );
        splitRect = _horizontalSplitRect(
          boundary: position,
          viewWidth: this.viewWidth,
          viewHeight: this.viewHeight,
          splitWidth: splitWidth,
        );
        break;
      case PrimaryPosition.right:
        final primaryWidth = max(primaryMinSize, position);
        final secondaryWidth = max(secondaryMinSize, this.viewWidth - position);
        final primaryLeft = this.viewWidth - position;
        final secondaryLeft = primaryLeft - secondaryWidth;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == this.viewWidth;
        primaryRect = isPrimaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                primaryLeft,
                0,
                primaryWidth,
                this.viewHeight,
              );
        secondaryRect = isSecondaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                secondaryLeft,
                0,
                secondaryWidth,
                this.viewHeight,
              );
        splitRect = _horizontalSplitRect(
          boundary: this.viewWidth - position,
          viewWidth: this.viewWidth,
          viewHeight: this.viewHeight,
          splitWidth: splitWidth,
        );
        break;
      case PrimaryPosition.top:
        final primaryHeight = max(primaryMinSize, position);
        final secondaryHeight =
            max(secondaryMinSize, this.viewHeight - position);
        final primaryTop = position - primaryHeight;
        final secondaryTop = position;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == this.viewHeight;
        primaryRect = isPrimaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                0,
                primaryTop,
                this.viewWidth,
                primaryHeight,
              );
        secondaryRect = isSecondaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                0,
                secondaryTop,
                this.viewWidth,
                secondaryHeight,
              );
        splitRect = _verticalSplitRect(
          boundary: position,
          viewWidth: this.viewWidth,
          viewHeight: this.viewHeight,
          splitWidth: splitWidth,
        );
        break;

      case PrimaryPosition.bottom:
        final primaryHeight = max(primaryMinSize, position);
        final secondaryHeight =
            max(secondaryMinSize, this.viewHeight - position);
        final primaryTop = this.viewHeight - position;
        final secondaryTop = primaryTop - secondaryHeight;
        isPrimaryHide = position == 0;
        isSecondaryHide = position == this.viewHeight;
        primaryRect = isPrimaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                0,
                primaryTop,
                this.viewWidth,
                primaryHeight,
              );
        secondaryRect = isSecondaryHide
            ? Rect.zero
            : _safeRectFromLTWH(
                0,
                secondaryTop,
                this.viewWidth,
                secondaryHeight,
              );
        splitRect = _verticalSplitRect(
          boundary: this.viewHeight - position,
          viewWidth: this.viewWidth,
          viewHeight: this.viewHeight,
          splitWidth: splitWidth,
        );
        break;
    }
    if (splitLayout.onlyShowPosition == Pane.primary) {
      primaryRect = _safeRectFromLTWH(0, 0, this.viewWidth, this.viewHeight);
      secondaryRect = Rect.zero;
      splitRect = Rect.zero;
    }
    if (splitLayout.onlyShowPosition == Pane.secondary) {
      secondaryRect = _safeRectFromLTWH(0, 0, this.viewWidth, this.viewHeight);
      primaryRect = Rect.zero;
      splitRect = Rect.zero;
    }
  }

  void updatePosition(double position) {
    showAnimate = true;
    this.position = _finiteNonNegativeOrZero(position);
    notifyListeners();
    onPoistionChanged?.call();
  }

  void updatePanStatus(bool isPanning) {
    isSplitPanStatus = isPanning;
    showAnimate = isPanning;
    notifyListeners();
    onPoistionChanged?.call();
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
    final oldPosition = position;
    final mainAxisSize = _currentMainAxisSize;
    final primaryMin = _finiteNonNegativeOrZero(layout.primaryMinSize);
    final secondaryMin = _finiteNonNegativeOrZero(layout.secondaryMinSize);
    position = _clampPositionToCurrentView(position);
    if (mainAxisSize == 0) {
      position = 0;
    }

    // 拖动结束时，需要将侧滑位置调到minSize
    final effectivePrimaryMin = min(primaryMin, mainAxisSize);
    if (position < effectivePrimaryMin) {
      if (!keepPrimary && panDirectionDelta != null && panDirectionDelta! < 0) {
        recordPosition = effectivePrimaryMin;
        position = 0;
      } else {
        position = effectivePrimaryMin;
      }
    } else if (position < mainAxisSize) {
      position = _clampPositionForMinSizes(
        position: position,
        viewSize: mainAxisSize,
        primaryMinSize: primaryMin,
        secondaryMinSize: secondaryMin,
      );
    }

    if (oldPosition != position) {
      onPoistionChanged?.call();
    }
  }

  void showTwoPane(SplitLayout layout) {
    if (position == 0) {
      togglePrimary();
    } else {
      position = _clampPositionToCurrentView(layout.primaryMinSize);
      notifyListeners();
      onPoistionChanged?.call();
    }
  }

  bool isHorizontalDirection(PrimaryPosition primaryPosition) {
    return primaryPosition == PrimaryPosition.left ||
        primaryPosition == PrimaryPosition.right;
  }

  void restoreMinSize() {
    final oldPosition = position;
    position = _clampPositionForMinSizes(
      position: position,
      viewSize: _currentMainAxisSize,
      primaryMinSize: primaryMinSize,
      secondaryMinSize: secondaryMinSize,
    );
    if (oldPosition != position) {
      onPoistionChanged?.call();
    }

    notifyListeners();
  }

  void restoreSize() {
    final mainAxisSize = _currentMainAxisSize;
    final restorePosition = min(
      _finiteNonNegativeOrZero(primaryMinSize),
      mainAxisSize,
    );
    if (mainAxisSize == 0) {
      position = 0;
    } else if (position >= mainAxisSize - 10) {
      position = restorePosition;
    }
    if (position < 10) {
      position = restorePosition;
    }
    position = _clampPositionToCurrentView(position);
    notifyListeners();
    onPoistionChanged?.call();
  }

  void resetLayout(SplitLayout splitLayout) {
    onPoistionChanged = splitLayout.onPoistionChanged;
    primaryPosition = splitLayout.primaryPosition;
    keepPrimary = splitLayout.keepPrimary;
    primaryMinSize = _finiteNonNegativeOrZero(splitLayout.primaryMinSize);
    secondaryMinSize = _finiteNonNegativeOrZero(splitLayout.secondaryMinSize);
    viewWidth = 0;
    viewHeight = 0;
    primaryRect = Rect.zero;
    secondaryRect = Rect.zero;
    splitRect = Rect.zero;
    isPrimaryHide = true;
    isSecondaryHide = true;
  }

  double get _currentMainAxisSize {
    return _finiteNonNegativeOrZero(isHorizontal ? viewWidth : viewHeight);
  }

  double _clampPositionToCurrentView(double value) {
    final mainAxisSize = _currentMainAxisSize;
    if (mainAxisSize == 0) {
      return 0;
    }
    return _clampBetween(
      _finiteNonNegativeOrZero(value),
      0,
      mainAxisSize,
    );
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
  final bool initPrimaryPosition;
  final Pane? onlyShowPosition;
  final bool keepPositionOnChangeSize;
  final VoidCallback? onPoistionChanged;

  const SplitLayout({
    super.key,
    required super.controller,
    required this.primary,
    required this.secondary,
    this.onlyShowPosition,
    this.splitWidth = 8,
    this.primarySize = 0,
    this.primaryMinSize = 0,
    this.secondaryMinSize = 0,
    this.primaryPosition = PrimaryPosition.left,
    this.splitColor,
    this.keepPrimary = false,
    this.isDrawerGesture = false,
    this.initPrimaryPosition = true,
    this.keepPositionOnChangeSize = false,
    this.onPoistionChanged,
  });

  @override
  void onInitState() {
    super.onInitState();
    if (initPrimaryPosition) {
      controller.updatePosition(primarySize);
    }
  }

  Size? _viewSizeFromConstraints(BoxConstraints constraints) {
    if (!_isFiniteNonNegative(constraints.maxWidth) ||
        !_isFiniteNonNegative(constraints.maxHeight)) {
      return null;
    }
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  void _debugReportInvalidConstraints(BoxConstraints constraints) {
    assert(() {
      final direction = controller.isHorizontalDirection(primaryPosition)
          ? 'horizontal'
          : 'vertical';
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('SplitLayout requires bounded finite constraints.'),
        ErrorDescription(
          'The $direction SplitLayout received $constraints. '
          'SplitLayout cannot compute pane rectangles from infinite, NaN, '
          'or negative viewport dimensions.',
        ),
        ErrorHint(
          'Give SplitLayout a bounded parent such as Expanded, SizedBox, '
          'Positioned.fill, or Scaffold.body before placing it in a Column, '
          'Row, Stack, or scrollable.',
        ),
        DiagnosticsProperty<PrimaryPosition>(
          'primaryPosition',
          primaryPosition,
        ),
        DoubleProperty('primarySize', primarySize),
        DoubleProperty('primaryMinSize', primaryMinSize),
        DoubleProperty('secondaryMinSize', secondaryMinSize),
      ]);
    }());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final viewSize = _viewSizeFromConstraints(cons);
      if (viewSize == null) {
        controller.resetLayout(this);
        _debugReportInvalidConstraints(cons);
        return const SizedBox.shrink();
      }

      if (keepPositionOnChangeSize) {
        if (primaryPosition == PrimaryPosition.right ||
            primaryPosition == PrimaryPosition.left) {
          var newWidth = viewSize.width;
          var oldWidth = controller.viewWidth;
          if (oldWidth != 0) {
            // newWidth/oldWidth = newPosition/oldPosition;
            controller.position = _finiteNonNegativeOrZero(
              newWidth / oldWidth * controller.position,
            );
          }
        } else {
          var newHeight = viewSize.height;
          var oldHeight = controller.viewHeight;
          if (oldHeight != 0) {
            controller.position = _finiteNonNegativeOrZero(
              newHeight / oldHeight * controller.position,
            );
          }
        }
      }
      controller.onBuildLayout(
        splitLayout: this,
        viewWidth: viewSize.width,
        viewHeight: viewSize.height,
      );
      var primaryRect = controller.primaryRect;
      var secondaryRect = controller.secondaryRect;
      var splitRect = controller.splitRect;
      final primaryVisible = onlyShowPosition == Pane.primary ||
          (onlyShowPosition == null && !controller.isPrimaryHide);
      final secondaryVisible = onlyShowPosition == Pane.secondary ||
          (onlyShowPosition == null && !controller.isSecondaryHide);
      final splitVisible = onlyShowPosition == null;

      return SizedBox(
        width: viewSize.width,
        height: viewSize.height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            buildAnimatedPositioned(
              primaryRect,
              buildDrawerGesture(context, primary),
              visible: primaryVisible,
            ),
            buildAnimatedPositioned(
              secondaryRect,
              secondary,
              visible: secondaryVisible,
            ),
            buildAnimatedPositioned(
              splitRect,
              buildSplitWidget(context),
              visible: splitVisible,
            ),
          ],
        ),
      );
    });
  }

  Widget buildDrawerGesture(BuildContext context, Widget child) {
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
        var position = controller._clampPositionToCurrentView(
          controller.position + delta,
        );
        controller.updatePosition(position);
        controller.panDirectionDelta = delta;
      } else {
        var delta = event.delta.dy;
        if (primaryPosition == PrimaryPosition.right ||
            primaryPosition == PrimaryPosition.bottom) {
          delta = -delta;
        }
        var position = controller._clampPositionToCurrentView(
          controller.position + delta,
        );
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
    Rect rect,
    Widget child, {
    bool visible = true,
  }) {
    final safeRect = _safeRectFromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );
    final isHidden = !visible || safeRect.width <= 0 || safeRect.height <= 0;
    final left = isHidden ? 0.0 : safeRect.left;
    final top = isHidden ? 0.0 : safeRect.top;
    final width = isHidden ? 0.0 : safeRect.width;
    final height = isHidden ? 0.0 : safeRect.height;

    return AnimatedPositioned(
      left: left,
      top: top,
      width: width,
      height: height,
      duration: Duration(
        milliseconds: controller.showAnimate ? controller.animateDuration : 0,
      ),
      onEnd: () {
        if (!controller.isSplitPanStatus) {
          controller.showAnimate = false;
        }
      },
      child: Offstage(
        offstage: isHidden,
        child: TickerMode(
          enabled: !isHidden,
          child: Container(
            width: width,
            height: height,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget buildSplitWidget(BuildContext context) {
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
        controller.position >= controller._currentMainAxisSize;
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
            var position = controller._clampPositionToCurrentView(
              controller.position + delta,
            );
            controller.updatePosition(position);
            controller.panDirectionDelta = delta;
          } else {
            var delta = details.delta.dy;
            if (primaryPosition == PrimaryPosition.right ||
                primaryPosition == PrimaryPosition.bottom) {
              delta = -delta;
            }
            var position = controller._clampPositionToCurrentView(
              controller.position + delta,
            );
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
    final safeSplitWidth = _finiteNonNegativeOrZero(splitWidth);
    if (primaryPosition == PrimaryPosition.left ||
        primaryPosition == PrimaryPosition.right) {
      return SizedBox(
        width: safeSplitWidth,
        child: InkWell(
          hoverColor: appColor.primary.withOpacity(0.2),
          onTap: () {
            controller.showTwoPane(this);
          },
        ),
      );
    }
    return SizedBox(
      height: safeSplitWidth,
      child: InkWell(
        hoverColor: appColor.primary.withOpacity(0.2),
        onTap: () {
          controller.showTwoPane(this);
        },
      ),
    );
  }
}
