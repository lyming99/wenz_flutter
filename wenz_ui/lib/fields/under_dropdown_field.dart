
import 'dart:math';

import 'package:flutter/material.dart';

import '../index.dart';

typedef ItemText<T> = String Function(T? item);

class UnderDropdownField<T> extends StatefulWidget {
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final double itemHeight;
  final double? itemWidth;
  final bool isDense;
  final double maxMenuHeight;
  final T? initialItem;
  final ItemText<T>? itemText;
  final bool editable;
  final TextEditingController? controller;

  final ValueChanged<String>? onInputChanged;

  const UnderDropdownField({
    super.key,
    required this.items,
    this.controller,
    this.onInputChanged,
    this.onChanged,
    this.itemHeight = 40,
    this.itemWidth,
    this.maxMenuHeight = 400,
    this.initialItem,
    this.itemText,
    this.editable = true,
    this.isDense = true,
  });

  @override
  State<UnderDropdownField<T>> createState() => _UnderDropdownFieldState<T>();
}

class _UnderDropdownFieldState<T> extends State<UnderDropdownField<T>> {
  var overlayController = OverlayPortalController();
  var editController = TextEditingController();
  BuildContext? editContext;
  String? selectLabel;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      editController = widget.controller!;
    }
    if (!_isInitialized) {
      var text = widget.itemText?.call(widget.initialItem) ??
          widget.initialItem?.toString() ??
          "";
      editController.text = text;
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return NotificationListener<PopupNotification>(
        onNotification: (notification) {
          if (!notification.isShow) {
            // editController.text = selectLabel ?? "";
          }
          return false;
        },
        child: OverlayPortal(
          controller: overlayController,
          overlayChildBuilder: (BuildContext context) {
            var items = widget.items!;
            var box = editContext!.findRenderObject() as RenderBox;
            var topLeft = box.localToGlobal(Offset.zero);
            var anchorRect = topLeft & Size(box.size.width, box.size.height);
            var contentHeight =
                min(widget.maxMenuHeight, widget.itemHeight * (items.length));
            return TapRegion(
              onTapOutside: (e) {
                var box = editContext!.findRenderObject() as RenderBox;
                var rect = box.localToGlobal(Offset.zero) & box.size;
                if (!rect.contains(e.position)) {
                  overlayController.hide();
                  notifyChildPopupState(editContext!, false);
                }
              },
              child: CustomSingleChildLayout(
                delegate: _PopupLayout(
                  verticalMargin: 4,
                  anchorRect: anchorRect,
                  childSize:
                      Size(widget.itemWidth ?? cons.maxWidth, contentHeight),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    elevation: 2,
                    shape: const RoundedRectangleBorder(),
                    child: SizedBox(
                      width: widget.itemWidth,
                      height: contentHeight,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          return true;
                        },
                        child: ListView.builder(
                          itemBuilder: (context, index) {
                            var items = widget.items!;
                            var item = items[index];
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectLabel = editController.text =
                                        widget.itemText?.call(item.value) ??
                                            item.value?.toString() ??
                                            "";
                                  });
                                  overlayController.hide();
                                  notifyChildPopupState(editContext!, false);
                                  widget.onChanged?.call(item.value);
                                },
                                child: Container(
                                  height: widget.itemHeight,
                                  width: widget.itemWidth,
                                  alignment: Alignment.centerLeft,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: item.child,
                                ),
                              ),
                            );
                          },
                          itemCount: items.length,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Builder(builder: (context) {
            editContext = context;
            var theme = Theme.of(context).inputDecorationTheme.copyWith();
            return TextField(
              controller: editController,
              readOnly: !widget.editable,
              onChanged: (value) {
                widget.onInputChanged?.call(value);
              },
              decoration: InputDecoration(
                isDense: widget.isDense,
                contentPadding: theme.contentPadding,
                suffixIconConstraints: BoxConstraints(
                  maxWidth: widget.itemHeight,
                  maxHeight: widget.itemHeight,
                ),
                border: OutlineInputBorder(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: widget.itemHeight -
                          (theme.contentPadding?.vertical ?? 0),
                      height: widget.itemHeight -
                          (theme.contentPadding?.vertical ?? 0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                    onTap: () {
                      overlayController.show();
                      notifyChildPopupState(editContext!, true);
                    },
                  ),
                ),
              ),
              onTap: () {
                overlayController.toggle();
                notifyChildPopupState(
                    editContext!, overlayController.isShowing);
              },
            );
          }),
        ),
      );
    });
  }
}

typedef LazyFetchFunction<T> = Future<T> Function();

class LazyUnderDropdownField<T> extends StatefulWidget {
  final LazyFetchFunction<List<DropdownMenuItem<T>>> fetch;
  final ValueChanged<T?>? onChanged;
  final double itemHeight;
  final double? itemWidth;
  final double maxMenuHeight;
  final T? initialItem;
  final ItemText<T>? itemText;

  final ValueChanged<String>? onInputChanged;

  const LazyUnderDropdownField({
    super.key,
    required this.fetch,
    this.onInputChanged,
    this.onChanged,
    this.itemHeight = 40,
    this.itemWidth,
    this.maxMenuHeight = 400,
    this.initialItem,
    this.itemText,
  });

  @override
  State<LazyUnderDropdownField<T>> createState() =>
      _LazyUnderDropdownFieldState<T>();
}

class _LazyUnderDropdownFieldState<T> extends State<LazyUnderDropdownField<T>> {
  var overlayController = OverlayPortalController();
  var editController = TextEditingController();
  BuildContext? editContext;
  String? selectLabel;
  List<DropdownMenuItem<T>> items = [];

  @override
  void initState() {
    super.initState();
    setState(() {
      editController.text = widget.itemText?.call(widget.initialItem) ??
          widget.initialItem?.toString() ??
          "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      return NotificationListener<PopupNotification>(
        onNotification: (notification) {
          if (!notification.isShow) {
            // editController.text = selectLabel ?? "";
          }
          return false;
        },
        child: OverlayPortal(
          controller: overlayController,
          overlayChildBuilder: (BuildContext context) {
            var box = editContext!.findRenderObject() as RenderBox;
            var topLeft = box.localToGlobal(Offset.zero);
            var anchorRect = topLeft & Size(box.size.width, box.size.height);
            var contentHeight =
                min(widget.maxMenuHeight, widget.itemHeight * (items.length));
            return TapRegion(
              onTapOutside: (e) {
                var box = editContext!.findRenderObject() as RenderBox;
                var rect = box.localToGlobal(Offset.zero) & box.size;
                if (!rect.contains(e.position)) {
                  overlayController.hide();
                  notifyChildPopupState(editContext!, false);
                }
              },
              child: CustomSingleChildLayout(
                delegate: _PopupLayout(
                  verticalMargin: 4,
                  anchorRect: anchorRect,
                  childSize:
                      Size(widget.itemWidth ?? cons.maxWidth, contentHeight),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    elevation: 2,
                    shape: const RoundedRectangleBorder(),
                    child: SizedBox(
                      width: widget.itemWidth,
                      height: contentHeight,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          return true;
                        },
                        child: buildListView(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Builder(builder: (context) {
            editContext = context;
            var theme = Theme.of(context).inputDecorationTheme.copyWith();
            return TextField(
              controller: editController,
              onChanged: (value) {
                widget.onInputChanged?.call(value);
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: theme.contentPadding,
                suffixIconConstraints: BoxConstraints(
                  maxWidth: widget.itemHeight,
                  maxHeight: widget.itemHeight,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: widget.itemHeight -
                          (theme.contentPadding?.vertical ?? 0),
                      height: widget.itemHeight -
                          (theme.contentPadding?.vertical ?? 0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                    onTap: () {
                      overlayController.show();
                      notifyChildPopupState(editContext!, true);
                    },
                  ),
                ),
              ),
              onTap: () {
                overlayController.toggle();
                notifyChildPopupState(
                    editContext!, overlayController.isShowing);
              },
            );
          }),
        ),
      );
    });
  }

  Widget buildListView() {
    return FutureBuilder(
      future: widget.fetch.call(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          items = snapshot.data;
          return ListView.builder(
            itemBuilder: (context, index) {
              var item = items[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectLabel = editController.text =
                          widget.itemText?.call(item.value) ??
                              item.value?.toString() ??
                              "";
                    });
                    overlayController.hide();
                    notifyChildPopupState(editContext!, false);
                    widget.onChanged?.call(item.value);
                  },
                  child: Container(
                    height: widget.itemHeight,
                    width: widget.itemWidth,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: item.child,
                  ),
                ),
              );
            },
            itemCount: items.length,
          );
        }
        return const SizedBox();
      },
    );
  }
}

class _PopupLayout extends SingleChildLayoutDelegate {
  Rect anchorRect = Rect.zero;
  Size childSize = Size.zero;
  double verticalMargin;

  _PopupLayout({
    required this.anchorRect,
    required this.childSize,
    this.verticalMargin = 0,
  });

  @override
  bool shouldRelayout(covariant _PopupLayout oldDelegate) {
    if (oldDelegate.anchorRect != anchorRect) {
      return true;
    }
    if (oldDelegate.childSize != childSize) {
      return true;
    }
    if (oldDelegate.verticalMargin != verticalMargin) {
      return true;
    }
    return false;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    var bottomExpand = constraints.maxHeight - anchorRect.bottom;
    var topExpand = anchorRect.top;
    double maxExpand =
        max(0, max(bottomExpand, topExpand) - verticalMargin * 2);
    return BoxConstraints(
      maxWidth: childSize.width,
      maxHeight: min(maxExpand, childSize.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size cSize) {
    var bottomExpand = size.height - anchorRect.bottom;
    var topExpand = anchorRect.top;
    double maxExpand =
        max(0, max(bottomExpand, topExpand) - verticalMargin * 2);
    if (childSize.height > bottomExpand && bottomExpand < topExpand) {
      return anchorRect.topLeft
          .translate(0, -min(maxExpand, childSize.height) - verticalMargin);
    }
    return anchorRect.bottomLeft.translate(0, verticalMargin);
  }
}
