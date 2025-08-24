import 'package:ydart/structs/base_content.dart';
import 'package:ydart/utils/y_doc.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';
import 'item.dart';

class ContentDoc extends IContentEx {
  YDoc? doc;
  late YDocOptions docOptions;

  ContentDoc(this.doc) {
    docOptions = YDocOptions();
    if (doc!.gc) {
      docOptions.gc = false;
    }
    if (doc!.autoLoad) {
      docOptions.autoLoad = true;
    }
    if (doc!.meta != null) {
      docOptions.meta = doc!.meta;
    }
  }

  @override
  int get ref => 9;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List<Object?> getContent() {
    return [doc];
  }

  @override
  IContentEx copy() {
    // todo 和yjs不一致
    return ContentDoc(doc);
  }

  @override
  IContentEx splice(int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(IContent right) {
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {
    doc!.item = item;
    transaction.subdocsAdded.add(doc!);
    if (doc!.shouldLoad) {
      transaction.subdocsLoaded.add(doc!);
    }
  }

  @override
  void delete(Transaction transaction) {
    if (transaction.subdocsAdded.contains(doc)) {
      transaction.subdocsAdded.remove(doc);
    } else {
      transaction.subdocsRemoved.add(doc!);
    }
  }

  @override
  void gc(StructStore store) {}

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeString(doc!.guid);
    docOptions.write(encoder, offset);
  }

  static ContentDoc read(IUpdateDecoder decoder) {
    var guid = decoder.readString();
    var opts = YDocOptions.read(decoder);
    opts.guid = guid;
    return ContentDoc(YDoc(opts));
  }
}
