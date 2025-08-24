/// 未完成编解码部分，1次review

import 'package:ydart/lib0/byte_output_stream.dart';

import 'delete_set.dart';
import 'id.dart';
import 'struct_store.dart';
import 'update_encoder_v2.dart';
import 'y_doc.dart';

class Snapshot {
  DeleteSet deleteSet;
  Map<int, int> stateVector;
  late StructStore structStore;

  Snapshot({
    required this.deleteSet,
    required this.stateVector,
  });

  YDoc restoreDocument(YDoc originDoc, [YDocOptions? opts]) {
    if (originDoc.gc) {
      throw Exception("originDoc must not be garbage collected");
    }
    var encoder = UpdateEncoderV2(ByteArrayOutputStream());
    originDoc.transact((tr) {
      var size = stateVector.values.where((element) => element > 0).length;
      encoder.restWriter.writeVarUint(size);
      for (var kvp in stateVector.entries) {
        var client = kvp.key;
        var clock = kvp.value;
        if (clock == 0) {
          continue;
        }
        if (clock < originDoc.store.getState(client)) {
          tr.doc.store.getItemCleanStart(tr, ID.create(client, clock));
        }
        var structs = originDoc.store.clients[client]!;
        var lastStructIndex = StructStore.findIndexSS(structs, clock - 1);
        encoder.restWriter.writeVarUint(lastStructIndex + 1);
        encoder.writeClient(client);
        encoder.restWriter.writeVarUint(0);
        for (int i = 0; i <= lastStructIndex; i++) {
          structs[i].write(encoder, 0);
        }
      }
      deleteSet.write(encoder);
    });
    var newDoc = YDoc(opts ?? originDoc.cloneOptionsWithNewGuid());
    newDoc.applyUpdateV2(encoder.toArray(), transactionOrigin: "snapshot");
    return newDoc;
  }

  bool equals(Snapshot? other) {
    if (other == null) {
      return false;
    }
    var ds1 = deleteSet.clients;
    var ds2 = other.deleteSet.clients;
    var sv1 = stateVector;
    var sv2 = other.stateVector;
    if (sv1.length != sv2.length || ds1.length != ds2.length) {
      return false;
    }
    for (var kvp in sv1.entries) {
      var key = kvp.key;
      var value = kvp.value;
      if (value != sv2[key]) {
        return false;
      }
    }
    for (var kvp in ds1.entries) {
      var client = kvp.key;
      var dsItem1 = kvp.value;
      var dsItem2 = ds2[client];
      if (dsItem2 == null) {
        return false;
      }
      if (dsItem1.length != dsItem2.length) {
        return false;
      }
      for (int i = 0; i < dsItem1.length; i++) {
        var item1 = dsItem1[i];
        var item2 = dsItem2[i];
        if (item1.clock != item2.clock || item1.length != item2.length) {
          return false;
        }
      }
    }
    return true;
  }
}
