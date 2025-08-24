import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/update_encoder.dart';

const structSkipRefNumber = 10;

class Skip extends AbstractStruct {
  Skip({required super.id, required super.length});

  @override
  void delete(Transaction transaction) {}

  @override
  bool get deleted => true;

  @override
  int? getMissing(Transaction transaction, StructStore store) {
    return null;
  }

  @override
  void integrate(Transaction transaction, int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(AbstractStruct right) {
    if (right is! Skip) {
      return false;
    }
    length += right.length;
    return true;
  }

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeInfo(structSkipRefNumber);
    encoder.restWriter.writeVarUint(length - offset);
  }
}
