import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/structs/skip.dart';
import 'package:ydart/utils/queue_stack.dart';

import '../structs/abstract_struct.dart';
import '../structs/gc.dart';
import '../structs/item.dart';
import 'delete_set.dart';
import 'id.dart';
import 'transaction.dart';
import 'update_decoder.dart';
import 'update_decoder_v2.dart';
import 'update_encoder_v2.dart';

class PendingClientStructRef {
  int i = 0;
  List<AbstractStruct> refs = [];
}

class FollowRedoneResult {
  AbstractStruct? item;

  int diff = 0;

  FollowRedoneResult({
    this.item,
    required this.diff,
  });
}

class StructStore {
  final Map<int, List<AbstractStruct>> clients = {};
  final Map<int, PendingClientStructRef> _pendingClientStructRefs = {};
  final QueueStack<AbstractStruct> _pendingStack = QueueStack<AbstractStruct>();
  final List<DSDecoderV2> _pendingDeleteReaders = [];

  Map<int, int> getStateVector() {
    var result = <int, int>{};
    for (var entry in clients.entries) {
      var str = entry.value.last;
      result[entry.key] = str.id.clock + str.length;
    }
    return result;
  }

  int getState(int clientId) {
    var structs = clients[clientId];
    if (structs != null) {
      var lastStruct = structs[structs.length - 1];
      return lastStruct.id.clock + lastStruct.length;
    }
    return 0;
  }

  void integrityCheck() {
    for (var structs in clients.values) {
      if (structs.isEmpty) {
        throw Exception(
            'StructStore failed integrity check: no structs for client');
      }

      for (var i = 1; i < structs.length; i++) {
        var left = structs[i - 1];
        var right = structs[i];

        if (left.id.clock + left.length != right.id.clock) {
          throw Exception('StructStore failed integrity check: missing struct');
        }
      }
    }

    if (_pendingDeleteReaders.isNotEmpty ||
        _pendingStack.isNotEmpty ||
        _pendingClientStructRefs.isNotEmpty) {
      throw Exception(
          'StructStore failed integrity check: still have pending items');
    }
  }

  void cleanupPendingStructs() {
    var clientsToRemove = [];

    for (var entry in _pendingClientStructRefs.entries) {
      var client = entry.key;
      var refs = entry.value;

      if (refs.i == refs.refs.length) {
        clientsToRemove.add(client);
      } else {
        refs.refs.removeRange(0, refs.i);
        refs.i = 0;
      }
    }

    for (var key in clientsToRemove) {
      _pendingClientStructRefs.remove(key);
    }
  }

  void addStruct(AbstractStruct str) {
    if (!clients.containsKey(str.id.client)) {
      clients[str.id.client] = [];
    } else {
      var structs = clients[str.id.client]!;
      var lastStruct = structs.last;
      if (lastStruct.id.clock + lastStruct.length != str.id.clock) {
        throw Exception('Unexpected');
      }
    }

    clients[str.id.client]!.add(str);
  }

  static int findIndexSS(List<AbstractStruct> structs, int clock) {
    assert(structs.isNotEmpty);

    var left = 0;
    var right = structs.length - 1;
    var mid = structs[right];
    var midClock = mid.id.clock;

    if (midClock == clock) {
      return right;
    }
    var midIndex = ((clock / (midClock + mid.length - 1)).floor() * right);
    while (left <= right) {
      mid = structs[midIndex];
      midClock = mid.id.clock;
      if (midClock <= clock) {
        if (clock < midClock + mid.length) {
          return midIndex;
        }
        left = midIndex + 1;
      } else {
        right = midIndex - 1;
      }
      midIndex = (left + right) ~/ 2;
    }

    throw Exception('Unexpected');
  }

  AbstractStruct getItem(ID id) {
    var structs = clients[id.client];
    if (structs != null) {
      int index = findIndexSS(structs, id.clock);
      if (index < 0 || index >= structs.length) {
        throw Exception('Invalid struct index: $index, max: ${structs.length}');
      }
      return structs[index];
    } else {
      throw Exception('No structs for client: ${id.client}');
    }
  }

  int findIndexCleanStart(
      Transaction transaction, List<AbstractStruct> structs, int clock) {
    int index = findIndexSS(structs, clock);
    var str = structs[index];
    if (str.id.clock < clock && str is Item) {
      structs.insert(index + 1,
          str.splitItem(transaction, (clock - str.id.clock).toInt()));
      return index + 1;
    }
    return index;
  }

  AbstractStruct getItemCleanStart(Transaction transaction, ID id) {
    var structs = clients[id.client];
    if (structs != null) {
      int indexCleanStart = findIndexCleanStart(transaction, structs, id.clock);
      assert(indexCleanStart >= 0 && indexCleanStart < structs.length);
      return structs[indexCleanStart];
    } else {
      throw Exception();
    }
  }

  AbstractStruct getItemCleanEnd(Transaction transaction, ID id) {
    var structs = clients[id.client];
    if (structs != null) {
      int index = findIndexSS(structs, id.clock);
      var str = structs[index];

      if ((id.clock != str.id.clock + str.length - 1) && str is! GC) {
        structs.insert(
            index + 1,
            (str as Item)
                .splitItem(transaction, (id.clock - str.id.clock + 1).toInt()));
      }

      return str;
    } else {
      throw Exception();
    }
  }

  void replaceStruct(AbstractStruct oldStruct, AbstractStruct newStruct) {
    var structs = clients[oldStruct.id.client];
    if (structs != null) {
      int index = findIndexSS(structs, oldStruct.id.clock);
      structs[index] = newStruct;
    } else {
      throw Exception();
    }
  }

  void iterateStructs(Transaction transaction, List<AbstractStruct> structs,
      int clockStart, int length, bool Function(AbstractStruct) fun) {
    if (length <= 0) {
      return;
    }

    var clockEnd = clockStart + length;
    int index = findIndexCleanStart(transaction, structs, clockStart);
    AbstractStruct str;

    do {
      str = structs[index];

      if (clockEnd < str.id.clock + str.length) {
        findIndexCleanStart(transaction, structs, clockEnd);
      }

      if (!fun(str)) {
        break;
      }

      index++;
    } while (index < structs.length && structs[index].id.clock < clockEnd);
  }

  FollowRedoneResult followRedone(ID id) {
    ID? nextId = id;
    int diff = 0;
    AbstractStruct item;

    do {
      if (diff > 0) {
        nextId = ID.create(nextId!.client, nextId.clock + diff);
      }

      item = getItem(nextId!);
      diff = (nextId.clock - item.id.clock);
      nextId = (item as Item?)?.redone;
    } while (nextId != null && item is Item);

    return FollowRedoneResult(item: item, diff: diff);
  }

  void readAndApplyDeleteSet(IDSDecoder decoder, Transaction transaction) {
    var unappliedDs = DeleteSet(clients: {});
    var numClients = decoder.reader.readVarUint();
    for (int i = 0; i < numClients; i++) {
      decoder.resetDsCurVal();
      var client = decoder.reader.readVarUint();
      var numberOfDeletes = decoder.reader.readVarUint();
      var structs = clients[client] ?? [];
      var state = getState(client);
      for (int j = 0; j < numberOfDeletes; j++) {
        var clock = decoder.readDsClock();
        var dsLength = decoder.readDsLength();
        var clockEnd = clock + dsLength;
        if (clock < state) {
          if (state < clockEnd) {
            unappliedDs.add(client, state, clockEnd - state);
          }
          var index = findIndexSS(structs, clock);
          var struct = structs[index];
          if (!struct.deleted && struct.id.clock < clock) {
            var splitItem = (struct as Item)
                .splitItem(transaction, clock - struct.id.clock);
            structs.insert(index + 1, splitItem);
            index++;
          }
          while (index < structs.length) {
            struct = structs[index++];
            if (struct.id.clock >= clockEnd) {
              break;
            }
            if (!struct.deleted) {
              if (clockEnd < struct.id.clock + struct.length) {
                var splitItem = (struct as Item)
                    .splitItem(transaction, clockEnd - struct.id.clock);
                structs.insert(index, splitItem);
              }
              struct.delete(transaction);
            }
          }
        } else {
          unappliedDs.add(client, clock, dsLength);
        }
      }

      if (structs.isNotEmpty) {
        clients[client] = structs;
      }
    }

    if (unappliedDs.clients.isNotEmpty) {
      var unappliedDsEncoder = DSEncoderV2(ByteArrayOutputStream());
      unappliedDs.write(unappliedDsEncoder);
      _pendingDeleteReaders
          .add(DSDecoderV2(ByteArrayInputStream(unappliedDsEncoder.toArray())));
    }
  }

  void mergeReadStructsIntoPendingReads(
      Map<int, List<AbstractStruct>> clientStructsRefs) {
    var pendingClientStructRefs = _pendingClientStructRefs;
    for (var entry in clientStructsRefs.entries) {
      var client = entry.key;
      var structRefs = entry.value;

      if (!pendingClientStructRefs.containsKey(client)) {
        pendingClientStructRefs[client] = PendingClientStructRef()
          ..refs = structRefs;
      } else {
        var pendingStructRefs = pendingClientStructRefs[client]!;
        if (pendingStructRefs.i > 0) {
          pendingStructRefs.refs.removeRange(0, pendingStructRefs.i);
        }

        var merged = pendingStructRefs.refs;
        for (var i = 0; i < structRefs.length; i++) {
          merged.add(structRefs[i]);
        }

        merged.sort((a, b) => a.id.clock.compareTo(b.id.clock));

        pendingStructRefs.i = 0;
        pendingStructRefs.refs = merged;
      }
    }
  }

  void integrateStructs1(Transaction transaction) {
    var stack = _pendingStack;
    var clientsStructRefs = _pendingClientStructRefs;
    if (clientsStructRefs.isEmpty) {
      return;
    }

    var clientsStructRefsIds = clientsStructRefs.keys.toList();
    clientsStructRefsIds.sort();

    PendingClientStructRef? getNextStructTarget() {
      if (clientsStructRefsIds.isEmpty) {
        return null;
      }
      var nextStructsTarget = clientsStructRefs[clientsStructRefsIds.last];
      while (nextStructsTarget!.refs.length == nextStructsTarget.i) {
        clientsStructRefsIds.removeLast();
        if (clientsStructRefsIds.isNotEmpty) {
          nextStructsTarget = clientsStructRefs[clientsStructRefsIds.last];
        } else {
          _pendingClientStructRefs.clear();
          return null;
        }
      }
      return nextStructsTarget;
    }

    var curStructsTarget = getNextStructTarget();
    if (curStructsTarget == null) {
      return;
    }
    var missingSV = <int, int>{};
    void updateMissingSv(client, clock) {
      var mclock = missingSV[client];
      if (mclock == null || mclock > clock) {
        missingSV[client] = clock;
      }
    }

    var stackHead = stack.isNotEmpty
        ? stack.pop()
        : curStructsTarget.refs[curStructsTarget.i++];
    var state = <int, int>{};

    while (true) {
      if (stackHead is! Skip) {
        var localClock = state.putIfAbsent(
            stackHead.id.client, () => getState(stackHead.id.client));
        var offset = localClock - stackHead.id.clock;
        if (offset < 0) {
          stack.push(stackHead);
          updateMissingSv(stackHead.id.client, stackHead.id.clock - 1);
        } else {
          var missing = stackHead.getMissing(transaction, this);
          if (missing != null) {
            stack.push(stackHead);
            var structRefs =
                clientsStructRefs[missing] ?? PendingClientStructRef();
            if (structRefs.refs.length == structRefs.i) {
              updateMissingSv(missing, getState(missing));
            } else {
              stackHead = structRefs.refs[structRefs.i++];
              continue;
            }
          } else if (offset == 0 || offset < stackHead.length) {
            stackHead.integrate(transaction, offset);
            state[stackHead.id.client] = stackHead.id.clock + stackHead.length;
          }
        }
      }
      if (stack.isNotEmpty) {
        stackHead = stack.pop();
      } else if (curStructsTarget != null &&
          curStructsTarget.i < curStructsTarget.refs.length) {
        stackHead = curStructsTarget.refs[curStructsTarget.i++];
      } else {
        curStructsTarget = getNextStructTarget();
        if (curStructsTarget == null) {
          break;
        } else {
          stackHead = curStructsTarget.refs[curStructsTarget.i++];
        }
      }
    }

    _pendingClientStructRefs.clear();
  }

  void integrateStructs(Transaction transaction) {
    var stack = _pendingStack;
    var clientsStructRefs = _pendingClientStructRefs;
    if (clientsStructRefs.isEmpty) {
      return;
    }

    var clientsStructRefsIds = clientsStructRefs.keys.toList();
    clientsStructRefsIds.sort();

    PendingClientStructRef? getNextStructTarget() {
      if (clientsStructRefsIds.isEmpty) {
        return null;
      }
      var nextStructsTarget = clientsStructRefs[clientsStructRefsIds.last];
      while (nextStructsTarget!.refs.length == nextStructsTarget.i) {
        clientsStructRefsIds.removeLast();
        if (clientsStructRefsIds.isNotEmpty) {
          nextStructsTarget = clientsStructRefs[clientsStructRefsIds.last];
        } else {
          _pendingClientStructRefs.clear();
          return null;
        }
      }
      return nextStructsTarget;
    }

    var curStructsTarget = getNextStructTarget();
    if (curStructsTarget == null) {
      return;
    }

    var stackHead = stack.isNotEmpty
        ? stack.pop()
        : curStructsTarget.refs[curStructsTarget.i++];
    var state = <int, int>{};

    while (true) {
      if (!state.containsKey(stackHead.id.client)) {
        state[stackHead.id.client] = getState(stackHead.id.client);
      }

      var localClock = state[stackHead.id.client]!;
      var offset =
          stackHead.id.clock < localClock ? localClock - stackHead.id.clock : 0;
      if (stackHead.id.clock + offset != localClock) {
        if (!clientsStructRefs.containsKey(stackHead.id.client)) {
          clientsStructRefs[stackHead.id.client] = PendingClientStructRef();
        }

        if (clientsStructRefs[stackHead.id.client]!.refs.length !=
            clientsStructRefs[stackHead.id.client]!.i) {
          var r = clientsStructRefs[stackHead.id.client]!
              .refs[clientsStructRefs[stackHead.id.client]!.i];
          if (r.id.clock < stackHead.id.clock) {
            clientsStructRefs[stackHead.id.client]!
                .refs[clientsStructRefs[stackHead.id.client]!.i] = stackHead;
            stackHead = r;

            clientsStructRefs[stackHead.id.client]!
                .refs
                .removeRange(0, clientsStructRefs[stackHead.id.client]!.i);
            clientsStructRefs[stackHead.id.client]!
                .refs
                .sort((a, b) => a.id.clock.compareTo(b.id.clock));

            clientsStructRefs[stackHead.id.client]!.i = 0;
            continue;
          }
        }

        stack.push(stackHead);
        return;
      }

      var missing = stackHead.getMissing(transaction, this);
      if (missing == null) {
        if (offset == 0 || offset < stackHead.length) {
          stackHead.integrate(transaction, offset);
          state[stackHead.id.client] = stackHead.id.clock + stackHead.length;
        }

        if (stack.isNotEmpty) {
          stackHead = stack.pop();
        } else if (curStructsTarget != null &&
            curStructsTarget.i < curStructsTarget.refs.length) {
          stackHead = curStructsTarget.refs[curStructsTarget.i++];
        } else {
          curStructsTarget = getNextStructTarget();
          if (curStructsTarget == null) {
            break;
          } else {
            stackHead = curStructsTarget.refs[curStructsTarget.i++];
          }
        }
      } else {
        if (!clientsStructRefs.containsKey(missing)) {
          clientsStructRefs[missing] = PendingClientStructRef();
        }

        if (clientsStructRefs[missing]!.refs.length ==
            clientsStructRefs[missing]!.i) {
          stack.push(stackHead);
          return;
        }

        stack.push(stackHead);
        stackHead =
            clientsStructRefs[missing]!.refs[clientsStructRefs[missing]!.i++];
      }
    }

    _pendingClientStructRefs.clear();
  }

  void tryResumePendingDeleteReaders(Transaction transaction) {
    var pendingReaders = List.from(_pendingDeleteReaders);
    _pendingDeleteReaders.clear();

    for (var reader in pendingReaders) {
      readAndApplyDeleteSet(reader, transaction);
    }
  }
}
