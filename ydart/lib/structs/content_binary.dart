import 'dart:typed_data';

import 'package:ydart/structs/base_content.dart';
import 'package:ydart/structs/item.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';

class ContentBinary extends IContentEx {
  Uint8List content;

  ContentBinary(this.content);

  @override
  int get ref => 3;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List<Object?> getContent() {
    return [content];
  }

  @override
  IContentEx copy() {
    return ContentBinary(content);
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
  void integrate(Transaction transaction, Item item) {}

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeBuffer(content);
  }

  static ContentBinary read(IUpdateDecoder decoder) {
    Uint8List content = decoder.readBuffer();
    return ContentBinary(content);
  }
}
