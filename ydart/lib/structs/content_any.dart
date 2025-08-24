import 'package:ydart/structs/base_content.dart';
import 'package:ydart/structs/item.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';

class ContentAny extends IContentEx {
  List<Object?> content;

  ContentAny({
    required this.content,
  });

  @override
  bool get isCountable => true;

  @override
  int get length => content.length;

  @override
  int get ref => 8;

  @override
  List<Object?> getContent() {
    return content;
  }

  @override
  IContentEx copy() {
    return ContentAny(content: content.toList());
  }

  @override
  IContentEx splice(int offset) {
    return ContentAny(content: content.sublist(offset));
  }

  @override
  bool mergeWith(IContent right) {
    if (right is ContentAny) {
      content.addAll(right.content);
      return true;
    }
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {}

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(IUpdateEncoder encoder, int offset) {
    int len = content.length;
    encoder.writeLength(len - offset);
    for (int i = offset; i < len; i++) {
      var c = content[i];
      encoder.writeAny(c);
    }
  }

  static ContentAny read(IUpdateDecoder decoder) {
    var len = decoder.readLength();
    var content = <Object>[];
    for (var i = 0; i < len; i++) {
      var c = decoder.readAny();
      content.add(c);
    }
    return ContentAny(content: content);
  }
}
