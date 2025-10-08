import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wenz_ui/utils/mvc.dart';

import 'reorderable_tab_model.dart';

typedef OnReorderCallback = void Function(int oldIndex, int newIndex);
typedef OnTabChanged = void Function(int index);
typedef OnTabRemoved = void Function(TabItem tab, int index);
typedef OnTabAdded = void Function(TabItem tab);

class ReorderableTabController extends MvcController {
  Map<String, Widget> widgetCache = {};
  List<TabItem> items;
  TabItem? selectedItem;
  OnReorderCallback? onReorder;
  OnTabChanged? onTabChanged;
  OnTabRemoved? onTabRemoved;
  OnTabAdded? onTabAdded;
  VoidCallback? onOrderChanged;
  var isDragging = false;
  TabItem? dragItem;
  int dragStartIndex = 0;
  double dragStartEventX = 0;
  double dragUpdateEventX = 0;
  double dragStartItemPosition = 0;
  double dragItemPosition = 0;
  ScrollController scrollController = ScrollController();
  PageController pageController = PageController();

  Size viewSize = Size.zero;

  var focusScopeNode = FocusScopeNode();

  ReorderableTabController({
    required this.items,
    this.onReorder,
    this.onTabChanged,
    this.onTabRemoved,
    this.onTabAdded,
    this.onOrderChanged,
    this.selectedItem,
  }) {
    if (items.isNotEmpty) {
      selectedItem ??= items.first;
    }
  }

  int get selectedIndex =>
      selectedItem == null ? 0 : items.indexOf(selectedItem!);

  int get dragItemIndex => dragItem == null ? 0 : items.indexOf(dragItem!);

  bool get hasFocus => focusScopeNode.hasFocus;

  @override
  void onInitState(BuildContext context, MvcViewState state) {
    super.onInitState(context, state);
    pageController = PageController(initialPage: selectedIndex);
  }

  @override
  void onDidUpdateWidget(
      BuildContext context, covariant ReorderableTabController oldController) {
    super.onDidUpdateWidget(context, oldController);
    items = oldController.items;
    selectedItem = oldController.selectedItem;
    onReorder = oldController.onReorder;
    onTabChanged = oldController.onTabChanged;
    onTabRemoved = oldController.onTabRemoved;
    onTabAdded = oldController.onTabAdded;
    isDragging = oldController.isDragging;
    dragItem = oldController.dragItem;
    dragStartIndex = oldController.dragStartIndex;
    dragStartEventX = oldController.dragStartEventX;
    dragUpdateEventX = oldController.dragUpdateEventX;
    dragStartItemPosition = oldController.dragStartItemPosition;
    dragItemPosition = oldController.dragItemPosition;
    scrollController = oldController.scrollController;
    focusScopeNode = oldController.focusScopeNode;
  }

  void setItems(List<TabItem> newItems) {
    items = newItems;
    selectedItem = newItems.where((e) => e.id == selectedItem?.id).firstOrNull;
    updateView();
  }

  TabItem? getItem(String id) {
    return items.where((e) => e.id == id).firstOrNull;
  }

  void handleReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final TabItem item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    if (newIndex == selectedIndex) {
      if (pageController.hasClients) {
        pageController.jumpToPage(newIndex);
      }
    }
    onReorder?.call(oldIndex, newIndex);
    updateView();
  }

  void handleTabTap(TabItem item) {
    selectedItem = item;
    onTabChanged?.call(selectedIndex);
    scrollToCenter(selectedIndex);
    if (pageController.hasClients) {
      pageController.animateToPage(
        selectedIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    updateView();
  }

  void setSelectTab(String id) {
    var item = getItem(id);
    if (item == null) {
      return;
    }
    selectedItem = item;
    onTabChanged?.call(selectedIndex);
    scrollToCenter(selectedIndex);
    if (pageController.hasClients) {
      pageController.jumpToPage(selectedIndex);
    }
    updateView();
  }

  void addTab(TabItem tab) {
    items.add(tab);
    onTabAdded?.call(tab);
    selectedItem = tab;
    onTabChanged?.call(selectedIndex);
    if (pageController.hasClients) {
      pageController.jumpToPage(selectedIndex);
    }
    updateView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCenter(selectedIndex);
    });
  }

  void removeTab(TabItem tab, [bool keepOneTab = true]) {
    widgetCache.remove(tab.id);
    final index = items.indexOf(tab);
    if (index == -1) return;

    if (items.length <= 1 && keepOneTab) {
      // 不允许删除最后一个标签
      return;
    }

    items.removeAt(index);
    onTabRemoved?.call(tab, index);
    // 如果删除的是当前选中的标签
    if (tab == selectedItem) {
      if (items.isEmpty) {
        selectedItem = null;
      } else {
        // 选择前一个标签，如果没有前一个就选择第一个
        final newIndex = min(index, items.length - 1);
        selectedItem = items[newIndex];
        pageController.jumpToPage(newIndex);
        onTabChanged?.call(newIndex);
        scrollToCenter(newIndex);
      }
    }
    if (items.isNotEmpty && pageController.hasClients) {
      pageController.jumpToPage(selectedIndex);
    }
    updateView();
  }

  void scrollToCenter(int index) {
    if (!scrollController.hasClients) return;

    // 计算目标tab的位置和宽度
    double targetPosition = 0;
    for (int i = 0; i < index; i++) {
      targetPosition += items[i].titleWidth ?? 0;
    }
    double targetWidth = items[index].titleWidth ?? 0;

    // 计算滚动视图的中心位置

    // double viewportWidth = scrollController.position.viewportDimension;
    double maxScrollExtent = scrollController.position.maxScrollExtent;
    double viewportWidth = viewSize.width;
    double newPos = (targetPosition + targetWidth / 2) - viewportWidth / 2;
    // 计算需要滚动的偏移量
    newPos = newPos.clamp(0, maxScrollExtent);
    if (scrollController.hasClients) {
      // 执行滚动动画
      scrollController.animateTo(
        newPos,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  double calculateTotalWidth(double Function(int) getTabWidth) {
    double totalWidth = 0;
    for (int i = 0; i < items.length; i++) {
      totalWidth += getTabWidth(i);
    }
    return totalWidth;
  }

  double getTabWidth(int index, BuildContext context) {
    // 如果设置了固定宽度，直接返回
    if (items[index].titleWidth != null) {
      return items[index].titleWidth!;
    }
    return items[index].measureTitleSize(context).width;
  }

  double getIndicatorPosition(double Function(int) getTabWidth) {
    if (selectedIndex >= items.length) return 0;
    double position = 0;
    for (int i = 0; i < selectedIndex; i++) {
      position += getTabWidth(i);
    }
    return position;
  }

  double getIndicatorWidth(double Function(int) getTabWidth) {
    if (selectedIndex >= items.length) return 0;
    return getTabWidth(selectedIndex);
  }

  Widget buildItemView(BuildContext context, TabItem<dynamic> item) {
    return widgetCache.putIfAbsent(
        item.id, () => item.builder?.call(context, item) ?? Container());
  }
}
