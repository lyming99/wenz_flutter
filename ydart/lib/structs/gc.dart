import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/update_encoder.dart';
import 'abstract_struct.dart';

const int structGCRefNumber = 0;

class GC extends AbstractStruct {
  GC({required super.id, required super.length});

  factory GC.create(ID id, int length) {
    return GC(id: id, length: length);
  }

  @override
  bool get deleted => true;

  @override
  bool mergeWith(AbstractStruct right) {
    if (right is! GC) {
      return false;
    }
    length += right.length;
    return true;
  }

  @override
  void delete(Transaction transaction) {}

  @override
  void integrate(Transaction transaction, int offset) {
    if (offset > 0) {
      id = ID(client: id.client, clock: id.clock + offset);
      length -= offset;
    }
    transaction.doc.store.addStruct(this);
  }

  @override
  int? getMissing(Transaction transaction, StructStore store) {
    return null;
  }

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeInfo(structGCRefNumber);
    encoder.writeLength(length - offset);
  }
}
