import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/device_util.dart';
import 'package:wenz_ui/utils/mvc.dart';
import 'reorderable_tab_controller.dart';

const kButtonWidth = 48.0;

class ReorderableTabBar extends StatelessWidget {
  final double height;
  final double tabHeight;
  final double indicatorHeight;
  final Color indicatorColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final ReorderableTabController controller;
  final WidgetBuilder? startBuilder;
  final WidgetBuilder? endBuilder;
  final WidgetBuilder? spaceBuilder;
  final WidgetBuilder? addButtonBuilder;

  const ReorderableTabBar({
    super.key,
    required this.controller,
    this.height = 48.0,
    this.tabHeight = 48.0,
    this.indicatorHeight = 2.0,
    this.indicatorColor = Colors.blue,
    this.selectedLabelColor = Colors.blue,
    this.unselectedLabelColor = Colors.black54,
    this.addButtonBuilder,
    this.startBuilder,
    this.endBuilder,
    this.spaceBuilder,
  });

  @override
  Widget build(BuildContext context) {
    double getTabWidth(int index) => controller.getTabWidth(index, context);
    final totalWidth = controller.calculateTotalWidth(getTabWidth);
    return Row(
      children: [
        if (startBuilder != null) startBuilder!(context),
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            var isAddButtonOutside = totalWidth + kButtonWidth >= cons.maxWidth;
            var spaceSize = addButtonBuilder != null
                ? cons.maxWidth - totalWidth - kButtonWidth
                : cons.maxWidth - totalWidth;
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: controller.scrollController,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: height,
                          width: totalWidth,
                          child: Stack(
                            children: [
                              ...List.generate(
                                controller.items.length,
                                (index) {
                                  double leftPosition = 0;
                                  for (int i = 0; i < index; i++) {
                                    leftPosition += getTabWidth(i);
                                  }
                                  return AnimatedPositioned(
                                    key: ValueKey(controller.items[index]),
                                    left: leftPosition,
                                    top: 0,
                                    height: tabHeight,
                                    width: getTabWidth(index),
                                    duration: Duration(
                                        milliseconds:
                                            controller.isDragging ? 200 : 0),
                                    child: InkWell(
                                      onTap: () => controller.handleTabTap(
                                          controller.items[index]),
                                      child: GestureDetector(
                                        onHorizontalDragStart: isMobile
                                            ? null
                                            : (details) {
                                                if (isMobile) {
                                                  return;
                                                }
                                                controller.dragItem =
                                                    controller.items[index];
                                                controller.dragStartIndex =
                                                    index;
                                                controller.dragStartEventX =
                                                    details.globalPosition.dx;
                                                controller.isDragging = true;
                                                controller
                                                    .dragItemPosition = controller
                                                        .dragStartItemPosition =
                                                    leftPosition;
                                                controller.updateView();
                                              },
                                        onHorizontalDragUpdate: isMobile
                                            ? null
                                            : (details) {
                                                if (isMobile) {
                                                  return;
                                                }
                                                controller.dragUpdateEventX =
                                                    details.globalPosition.dx;
                                                controller
                                                    .dragItemPosition = controller
                                                        .dragStartItemPosition +
                                                    details.globalPosition.dx -
                                                    controller.dragStartEventX;
                                                calculateDragItemPosition(
                                                    context);
                                                controller.updateView();
                                              },
                                        onHorizontalDragEnd: isMobile
                                            ? null
                                            : (details) {
                                                if (isMobile) {
                                                  return;
                                                }
                                                controller.isDragging = false;
                                                controller.updateView();
                                                controller.onOrderChanged
                                                    ?.call();
                                              },
                                        child: buildTitleItemWidget(
                                            context, index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (controller.isDragging)
                                Positioned(
                                  left: controller.dragItemPosition,
                                  top: 0,
                                  height: tabHeight,
                                  width: getTabWidth(controller.dragItemIndex),
                                  child: buildTitleItemWidget(
                                      context, controller.dragItemIndex, true),
                                ),

                              // Indicator line
                              AnimatedPositioned(
                                left: controller
                                    .getIndicatorPosition(getTabWidth),
                                bottom: 0,
                                width:
                                    controller.getIndicatorWidth(getTabWidth),
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  height: indicatorHeight,
                                  color: indicatorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isAddButtonOutside && addButtonBuilder != null)
                          buildAddButton(context),
                      ],
                    ),
                  ),
                ),
                if (isAddButtonOutside && addButtonBuilder != null)
                  buildAddButton(context),
                if (spaceSize > 0)
                  SizedBox(
                    width: spaceSize,
                    child: spaceBuilder?.call(context),
                  ),
              ],
            );
          }),
        ),
        if (endBuilder != null) endBuilder!(context),
      ],
    );
  }

  Widget buildTitleItemWidget(BuildContext context, int index,
      [bool isDragFloat = false]) {
    final item = controller.items[index];
    final isSelected = item == controller.selectedItem;
    final textColor = isSelected ? selectedLabelColor : unselectedLabelColor;
    final isDragItem = item == controller.dragItem;
    final isDragging = controller.isDragging;
    return Opacity(
      opacity: isDragging ? ((!isDragItem || isDragFloat) ? 1 : 0) : 1,
      child: item.buildTitleWidget(context, textColor),
    );
  }

  void calculateDragItemPosition(BuildContext context) {
    double getTabWidth(int index) => controller.getTabWidth(index, context);
    var startIndex = controller.dragItemIndex;
    var targetIndex = startIndex;
    var calcPosition =
        controller.dragItemPosition + getTabWidth(startIndex) / 2;
    double left = 0;
    for (var i = 0; i < controller.items.length; i++) {
      var itemWidth = getTabWidth(i);
      if (calcPosition >= left && calcPosition <= left + itemWidth / 2) {
        targetIndex = i;
        break;
      }
      if (calcPosition > left + itemWidth / 2 &&
          calcPosition <= left + itemWidth) {
        targetIndex = i + 1;
        if (targetIndex >= controller.items.length) {
          targetIndex = controller.items.length;
        }
        break;
      }
      left += itemWidth;
    }
    if (startIndex != targetIndex) {
      controller.handleReorder(startIndex, targetIndex);
    }
  }

  Widget buildAddButton(BuildContext context) {
    return addButtonBuilder!.call(context);
  }
}

class ReorderableTabView extends MvcView<ReorderableTabController> {
  final double tabHeight;
  final double indicatorHeight;
  final Color indicatorColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final Widget Function(BuildContext context, Widget child)? tabBuilder;
  final WidgetBuilder? tabBarStartBuilder;
  final WidgetBuilder? tabBarEndBuilder;
  final WidgetBuilder? tabBarSpaceBuilder;
  final WidgetBuilder? tabAddButtonBuilder;
  final Widget? divider;
  final bool showTab;

  const ReorderableTabView({
    super.key,
    required super.controller,
    this.tabHeight = 48.0,
    this.indicatorHeight = 2.0,
    this.indicatorColor = Colors.blue,
    this.selectedLabelColor = Colors.blue,
    this.unselectedLabelColor = Colors.black54,
    this.tabBarStartBuilder,
    this.tabBarEndBuilder,
    this.tabBarSpaceBuilder,
    this.tabAddButtonBuilder,
    this.divider,
    this.showTab = true,
    this.tabBuilder,
  });

  @override
  Widget build(BuildContext context) {
    var pageChild = PageView(
      controller: controller.pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var item in controller.items)
          Container(
            key: ValueKey(item.id),
            child: item.builder?.call(context, item) ??
                Center(
                  child: Text(
                    item.id ?? '',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
          ),
      ],
    );
    if (!showTab) {
      return pageChild;
    }
    Widget tabChild = ReorderableTabBar(
      controller: controller,
      height: tabHeight,
      tabHeight: tabHeight,
      indicatorHeight: indicatorHeight,
      indicatorColor: indicatorColor,
      selectedLabelColor: selectedLabelColor,
      unselectedLabelColor: unselectedLabelColor,
      startBuilder: tabBarStartBuilder,
      endBuilder: tabBarEndBuilder,
      spaceBuilder: tabBarSpaceBuilder,
      addButtonBuilder: tabAddButtonBuilder,
    );
    if (tabBuilder != null) {
      tabChild = tabBuilder!.call(context, tabChild);
    }
    return Column(
      children: [
        tabChild,
        if (divider != null) divider!,
        Expanded(child: pageChild),
      ],
    );
  }
}
