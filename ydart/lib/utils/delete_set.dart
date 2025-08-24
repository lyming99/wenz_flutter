import 'dart:math';

import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/abstract_struct.dart';
import '../structs/item.dart';
import '../types/abstract_type.dart';
import 'struct_store.dart';
import 'update_decoder.dart';
import 'update_encoder.dart';

class DeleteItem {
  int clock;
  int length;

  DeleteItem(this.clock, this.length);
  @override
  String toString() {
    return '{"clock":$clock,"length":$length}';
  }
}

class DeleteSet {
  late Map<int, List<DeleteItem>> clients;

  DeleteSet({
    required this.clients,
  });

  factory DeleteSet.store(StructStore store) {
    return DeleteSet(clients: {})..createDeleteSetFromStructStore(store);
  }

  factory DeleteSet.merge(List<DeleteSet> list) {
    return DeleteSet(clients: {})..mergeDeleteSets(list);
  }

  void add(int client, int clock, int length) {
    var arr = clients.putIfAbsent(client, () => []);
    arr.add(DeleteItem(clock, length));
  }

  void iterateDeletedStructs(
      Transaction transaction, bool Function(AbstractStruct struct) fun) {
    for (var kvp in clients.entries) {
      var structs = transaction.doc.store.clients[kvp.key];
      for (var del in kvp.value) {
        transaction.doc.store
            .iterateStructs(transaction, structs!, del.clock, del.length, fun);
      }
    }
  }

  int? findIndexSS(List<DeleteItem> dis, int clock) {
    var left = 0;
    var right = dis.length - 1;
    while (left <= right) {
      var midIndex = (left + right) ~/ 2;
      var mid = dis[midIndex];
      var midClock = mid.clock;
      if (midClock <= clock) {
        if (clock < midClock + mid.length) {
          return midIndex;
        }
        left = midIndex + 1;
      } else {
        right = midIndex - 1;
      }
    }
    return null;
  }

  bool isDeleted(ID id) {
    var dis = clients[id.client];
    return dis != null && findIndexSS(dis, id.clock) != null;
  }

  void sortDeleteSet() {
    clients.forEach((key, value) {
      value.sort((a, b) => a.clock.compareTo(b.clock));
    });
  }

  void sortAndMergeDeleteSet() {
    clients.forEach((client, deleteSets) {
      deleteSets.sort((a, b) => a.clock - b.clock);
      var i = 1;
      var j = 1;
      for (; i < deleteSets.length; i++) {
        var left = deleteSets[j - 1];
        var right = deleteSets[i];
        if (left.clock + left.length >= right.clock) {
          left.length =
              max(left.length, right.clock + right.length - left.clock);
        } else {
          if (j < i) {
            deleteSets[j] = right;
          }
          j++;
        }
      }
      deleteSets.length = j;
    });
  }

  void tryGc(StructStore store, bool Function(Item) gcFilter) {
    tryGcDeleteSet(store, gcFilter);
    tryMergeDeleteSet(store);
  }

  void tryGcDeleteSet(StructStore store, bool Function(Item) gcFilter) {
    clients.forEach((client, deleteItems) {
      var structs = store.clients[client]!;
      for (int di = deleteItems.length - 1; di >= 0; di--) {
        var deleteItem = deleteItems[di];
        var endDeleteItemClock = deleteItem.clock + deleteItem.length;
        for (var si = StructStore.findIndexSS(structs, deleteItem.clock);
            si < structs.length && structs[si].id.clock < endDeleteItemClock;
            si++) {
          var str = structs[si];
          if (deleteItem.clock + deleteItem.length <= str.id.clock) {
            break;
          }
          if (str is Item && str.deleted && !str.keep && gcFilter(str)) {
            str.gc(store, false);
          }
        }
      }
    });
  }

  void tryMergeDeleteSet(StructStore store) {
    clients.forEach((client, deleteItems) {
      var structs = store.clients[client]!;

      for (int di = deleteItems.length - 1; di >= 0; di--) {
        var deleteItem = deleteItems[di];
        var indexSs = 1 +
            StructStore.findIndexSS(
                structs, deleteItem.clock + deleteItem.length - 1);
        var mostRightIndexToCheck = min(structs.length - 1, indexSs);
        for (int si = mostRightIndexToCheck;
            si > 0 && structs[si].id.clock >= deleteItem.clock;
            si--) {
          tryToMergeWithLeft(structs, si);
        }
      }
    });
  }

  static void tryToMergeWithLeft(List<AbstractStruct> structs, int pos) {
    var left = structs[pos - 1];
    var right = structs[pos];

    if (left.deleted == right.deleted &&
        left.runtimeType == right.runtimeType) {
      if (left.mergeWith(right)) {
        structs.removeAt(pos);
        if (right is Item && right.parentSub != null) {
          if ((right.parent as AbstractType).map[right.parentSub] == right) {
            (right.parent as AbstractType).map[right.parentSub!] = left as Item;
          }
        }
      }
    }
  }

  void mergeDeleteSets(List<DeleteSet> dss) {
    for (int dssI = 0; dssI < dss.length; dssI++) {
      dss[dssI].clients.forEach((client, delsLeft) {
        if (!clients.containsKey(client)) {
          var dels = List<DeleteItem>.from(delsLeft);

          for (int i = dssI + 1; i < dss.length; i++) {
            if (dss[i].clients.containsKey(client)) {
              dels.addAll(dss[i].clients[client]!);
            }
          }

          clients[client] = dels;
        }
      });
    }

    sortAndMergeDeleteSet();
  }

  void createDeleteSetFromStructStore(StructStore ss) {
    ss.clients.forEach((client, structs) {
      var dsItems = <DeleteItem>[];
      for (int i = 0; i < structs.length; i++) {
        var str = structs[i];
        if (str.deleted) {
          var clock = str.id.clock;
          var len = str.length;

          while (i + 1 < structs.length) {
            var next = structs[i + 1];
            if (next.id.clock == clock + len && next.deleted) {
              len += next.length;
              i++;
            } else {
              break;
            }
          }
          dsItems.add(DeleteItem(clock, len));
        }
      }

      if (dsItems.isNotEmpty) {
        clients[client] = dsItems;
      }
    });
  }

  void write(IDSEncoder encoder) {
    encoder.restWriter.writeVarUint(clients.length);

    clients.forEach((client, dsItems) {
      var len = dsItems.length;

      encoder.resetDsCurVal();
      encoder.restWriter.writeVarUint(client);
      encoder.restWriter.writeVarUint(len);

      for (int i = 0; i < len; i++) {
        var item = dsItems[i];
        if (item.length == 0) {
          continue;
        }
        encoder.writeDsClock(item.clock);
        encoder.writeDsLength(item.length);
      }
    });
  }

  static DeleteSet read(IDSDecoder decoder) {
    var ds = DeleteSet(clients: {});

    var numClients = decoder.reader.readVarUint();
    assert(numClients >= 0);

    for (var i = 0; i < numClients; i++) {
      decoder.resetDsCurVal();

      var client = decoder.reader.readVarUint();
      var numberOfDeletes = decoder.reader.readVarUint();

      if (numberOfDeletes > 0) {
        if (!ds.clients.containsKey(client)) {
          ds.clients[client] = [];
        }

        for (var j = 0; j < numberOfDeletes; j++) {
          var deleteItem =
              DeleteItem(decoder.readDsClock(), decoder.readDsLength());
          ds.clients[client]!.add(deleteItem);
        }
      }
    }

    return ds;
  }
}
