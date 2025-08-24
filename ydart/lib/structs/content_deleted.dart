import 'package:ydart/structs/base_content.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';
import 'item.dart';

class ContentDeleted extends IContentEx {
  @override
  int length;

  ContentDeleted(this.length);

  @override
  int get ref => 1;

  @override
  bool get isCountable => false;

  @override
  List<Object?> getContent() {
    return [];
  }

  @override
  IContentEx copy() {
    return ContentDeleted(length);
  }

  @override
  IContentEx splice(int offset) {
    var right = ContentDeleted(length - offset);
    length = offset;
    return right;
  }

  @override
  bool mergeWith(IContent right) {
    if (right is ContentDeleted) {
      length += right.length;
      return true;
    }
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {
    transaction.deleteSet.add(item.id.client, item.id.clock, length);
    item.markDeleted();
  }

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeLength(length - offset);
  }

  static ContentDeleted read(IUpdateDecoder decoder) {
    var len = decoder.readLength();
    return ContentDeleted(len);
  }
}
