/// 如果是searchKey的话，需要高亮背景为黄色
class SearchState {
  String? searchKey;

  bool get hasSearch => searchKey != null && searchKey!.isNotEmpty;
}