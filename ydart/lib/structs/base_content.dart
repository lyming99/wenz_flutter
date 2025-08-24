import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/update_encoder.dart';

import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import 'item.dart';

abstract class IContent {
  bool get isCountable;

  int get length;

  List<Object?> getContent();

  IContentEx copy();

  IContentEx splice(int offset);

  bool mergeWith(IContent right);
}

abstract class IContentEx extends IContent {
  int get ref;

  void integrate(Transaction transaction, Item item);

  void delete(Transaction transaction);

  void gc(StructStore store);

  void write(IUpdateEncoder encoder, int offset);
}
