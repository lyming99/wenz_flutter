import 'dart:math';

import 'package:flutter/material.dart';

class AutoSuggestBox<T> extends StatefulWidget {
  final double itemWidth;
  final double itemHeight;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final double maxHeight;
  final DropdownMenuItem? initialValue;

  const AutoSuggestBox({
    super.key,
    this.items,
    this.onChanged,
    this.itemHeight = 38,
    this.itemWidth = 120,
    this.maxHeight = 400,
    this.initialValue,
  });

  @override
  State<AutoSuggestBox> createState() => _AutoSuggestBoxState();
}

class _AutoSuggestBoxState<T> extends State<AutoSuggestBox<T>> {
  var overlayController = OverlayPortalController();
  BuildContext? childContext;
  var searchController = TextEditingController();
  var focusNode = FocusNode();

  List<DropdownMenuItem> get filteredItems {
    if (searchController.text.isEmpty) {
      return widget.items ?? [];
    }
    return widget.items
            ?.where((element) =>
                element.value.toString().contains(searchController.text))
            .toList() ??
        [];
  }

  @override
  void initState() {
    super.initState();
    searchController.text = widget.initialValue?.value.toString() ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      childContext = context;
      var isFocused = focusNode.hasFocus || overlayController.isShowing;
      var textColor = Theme.of(context)
          .colorScheme
          .onSurface
          .withOpacity(isFocused ? 1 : 0.6);
      return OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (BuildContext context) {
          var items = filteredItems;
          var box = childContext!.findRenderObject() as RenderBox;
          var topLeft = box.localToGlobal(Offset.zero);
          var anchorRect = topLeft & box.size;
          var contentHeight =
              min(widget.maxHeight, widget.itemHeight * (items.length));

          return TapRegion(
            onTapOutside: (e) {
              var box = childContext!.findRenderObject() as RenderBox;
              var rect = box.localToGlobal(Offset.zero) & box.size;
              if (!rect.contains(e.position)) {
                overlayController.hide();
              }
            },
            child: CustomSingleChildLayout(
              delegate: _PopupLayout(
                anchorRect: anchorRect,
                childSize: Size(widget.itemWidth, contentHeight),
              ),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: widget.itemWidth,
                    height: contentHeight,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        return true;
                      },
                      child: ListView.builder(
                        itemBuilder: (context, index) {
                          var item = items[index];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                searchController.text = item.value;
                              });
                              widget.onChanged?.call(item.value);
                              overlayController.hide();
                            },
                            child: Container(
                              height: widget.itemHeight,
                              width: widget.itemWidth,
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.only(left: 8),
                              child: Text(item.value.toString()),
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
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              TextField(
                focusNode: focusNode,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
                controller: searchController,
                decoration: InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(
                      top: 4, left: 4, bottom: 8, right: 24),
                  border: isFocused
                      ? null
                      : const OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    overlayController.show();
                    var item = widget.items
                        ?.where((e) => e.value == value)
                        .firstOrNull;
                    if (item != null) {
                      widget.onChanged?.call(value as T);
                    }
                  } else {
                    overlayController.hide();
                  }
                  setState(() {});
                },
                onSubmitted: (value) {
                  overlayController.hide();
                },
                onTap: () {
                  overlayController.toggle();
                },
              ),
              if (isFocused)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () {
                        overlayController.show();
                      },
                      child: Icon(
                        Icons.arrow_drop_down,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _PopupLayout extends SingleChildLayoutDelegate {
  Rect anchorRect = Rect.zero;
  Size childSize = Size.zero;

  _PopupLayout({
    required this.anchorRect,
    required this.childSize,
  });

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) {
    return true;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: childSize.width,
      maxHeight: childSize.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size _) {
    var calcSize = Size(
      childSize.width,
      min(
        childSize.height,
        size.height - anchorRect.bottom - 8,
      ),
    );
    var childRect = anchorRect.bottomLeft.translate(0, 4) & calcSize;
    return childRect.topLeft;
  }
}
