import 'package:flutter/material.dart';

import '../utils/mvc.dart';
import 'under_dropdown_field.dart';

class DropdownItemValue<T> {
  String label;
  T? value;

  DropdownItemValue({required this.label, this.value});

  @override
  toString() => label;
}

typedef FetchFunction<T> = Future<List<DropdownItemValue<T>>> Function();

class SearchDropdownController<T> extends MvcController {
  String searchText = "";
  DropdownItemValue<T>? selectItem;
  List<DropdownItemValue<T>> filterItems = [];
  List<DropdownItemValue<T>> items = [];
  DropdownItemValue<T>? initialValue;
  FetchFunction<T>? fetch;

  var editController = TextEditingController();

  SearchDropdownController({
    this.fetch,
    this.initialValue,
  });

  @override
  void onInitState(BuildContext context, MvcViewState state) {
    super.onInitState(context, state);
    refresh();
  }

  @override
  void onDidUpdateWidget(BuildContext context,
      covariant SearchDropdownController<T> oldController) {
    super.onDidUpdateWidget(context, oldController);
    searchText = oldController.searchText;
    selectItem = oldController.selectItem;
    filterItems = oldController.filterItems;
    items = oldController.items;
    initialValue = oldController.initialValue;
    fetch = oldController.fetch;
    editController = oldController.editController;
  }

  Future refresh() async {
    items = await fetch?.call() ?? [];
    if (items.isNotEmpty) {
      initialValue ??= items.first;
    }
    updateSearchKey(searchText);
    updateView();
  }

  void updateSearchKey(String value) {
    searchText = value;
    filterItems = items
        .where((item) =>
            item.label.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
    notifyListeners();
  }

  void updateSelectItem(DropdownItemValue<T>? value) {
    selectItem = value;
    updateSearchKey("");
  }

  void updateFetch(FetchFunction<T>? fetch) {
    if (fetch == null) {
      return;
    }
    if (fetch != this.fetch || this.fetch == null) {
      this.fetch = fetch;
      WidgetsBinding.instance.addPostFrameCallback((t) {
        refresh();
      });
    }
  }

  @override
  void updateView() {
    editController.text = selectItem?.label ?? "";
    super.updateView();
  }
}

class SearchDropdownField<T> extends MvcView<SearchDropdownController<T>> {
  final ValueChanged<DropdownItemValue<T>?>? onSelectChanged;
  final FetchFunction<T>? fetch;

  const SearchDropdownField({
    super.key,
    this.onSelectChanged,
    required super.controller,
    this.fetch,
  });

  @override
  Widget build(BuildContext context) {
    controller.updateFetch(fetch);
    return UnderDropdownField(
      controller: controller.editController,
      onInputChanged: (value) {
        controller.updateSearchKey(value);
      },
      initialItem: controller.selectItem,
      items: controller.filterItems
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e.label),
            ),
          )
          .toList(),
      onChanged: (value) {
        controller.updateSelectItem(value);
        onSelectChanged?.call(value);
      },
    );
  }
}
