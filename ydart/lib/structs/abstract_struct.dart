import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/id.dart';
import '../utils/update_encoder.dart';

abstract class AbstractStruct {
  ID id;
  int length;

  AbstractStruct? left;
  AbstractStruct? right;

  AbstractStruct({
    required this.id,
    required this.length,
  });

  bool get deleted;

  bool mergeWith(AbstractStruct right);

  void delete(Transaction transaction);

  void integrate(Transaction transaction,int offset);

  int? getMissing(Transaction transaction, StructStore store);

  void write(IUpdateEncoder encoder, int offset);
}
