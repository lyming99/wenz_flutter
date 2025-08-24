import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/struct_store.dart';

import '../structs/content_doc.dart';
import '../structs/item.dart';
import '../types/abstract_type.dart';
import '../types/y_array.dart';
import '../types/y_map.dart';
import '../types/y_text.dart';
import 'delete_set.dart';
import 'encoding_utils.dart';
import 'transaction.dart';
import 'update_decoder.dart';
import 'update_decoder_v2.dart';
import 'update_encoder.dart';
import 'update_encoder_v2.dart';

class YDocOptions {
  bool gc = true;
  bool Function(Item)? gcFilter;
  String guid = const Uuid().v4();
  Map<String, String>? meta;
  bool autoLoad = false;

  YDocOptions clone() {
    return YDocOptions()
      ..gc = gc
      ..gcFilter = gcFilter
      ..guid = guid
      ..meta = meta != null ? Map<String, String>.from(meta!) : null
      ..autoLoad = autoLoad;
  }

  void write(IUpdateEncoder encoder, int offset) {
    var dict = <String, dynamic>{
      'gc': gc,
      'guid': guid,
      'autoLoad': autoLoad,
    };

    if (meta != null) {
      dict['meta'] = meta;
    }
    encoder.writeAny(dict);
  }

  static YDocOptions read(IUpdateDecoder decoder) {
    var dict = decoder.readAny() as Map<String, dynamic>;

    var result = YDocOptions();
    result.gc = dict.containsKey('gc') ? dict['gc'] as bool : true;
    result.guid =
        dict.containsKey('guid') ? dict['guid'].toString() : const Uuid().v4();
    result.meta =
        dict.containsKey('meta') ? dict['meta'] as Map<String, String> : null;
    result.autoLoad =
        dict.containsKey('autoLoad') ? dict['autoLoad'] as bool : false;

    return result;
  }
}

class YDoc {
  final YDocOptions _opts;
  late int clientId;
  Map<String, AbstractType> share;
  StructStore store = StructStore();

  bool get gc => _opts.gc;
  final List<Transaction> transactionCleanups;
  bool shouldLoad;
  Transaction? transaction;
  Set<YDoc> subdocs;
  Item? item;

  YDoc([YDocOptions? opts])
      : _opts = opts ?? YDocOptions(),
        transactionCleanups = [],
        clientId = generateNewClientId(),
        share = {},
        store = StructStore(),
        subdocs = {},
        shouldLoad = opts?.autoLoad ?? false;

  String get guid => _opts.guid;

  bool Function(Item) get gcFilter => _opts.gcFilter ?? ((Item item) => true);

  Map<String, String>? get meta => _opts.meta;

  bool get autoLoad => _opts.autoLoad;

  static int generateNewClientId() {
    return Random().nextInt(0x7FFFFFFF);
  }

  void transact(void Function(Transaction transaction) fun,
      {Object? origin, bool local = true}) {
    var initialCall = false;
    if (transaction == null) {
      initialCall = true;
      transaction = Transaction(this, origin, local);
      transactionCleanups.add(transaction!);
      if (transactionCleanups.length == 1) {
        invokeBeforeAllTransactions();
      }
      invokeOnBeforeTransaction(transaction!);
    }
    try {
      fun(transaction!);
    } finally {
      if (initialCall && transactionCleanups[0] == transaction) {
        Transaction.cleanupTransactions(transactionCleanups, 0);
      }
    }
  }

  YArray getArray([String name = '']) {
    return get<YArray>(name, () => YArray())!;
  }

  YMap getMap([String name = '']) {
    return get<YMap>(name, () => YMap())!;
  }

  YText getText([String name = '']) {
    return get<YText>(name, () => YText(""))!;
  }

  T? get<T extends AbstractType>(String name, T? Function() create) {
    if (!share.containsKey(name)) {
      var type = create();
      if (type == null) {
        return null;
      }
      type.integrate(this, null);
      share[name] = type;
    }
    // T 和share类型不一样的话，就需要创建一个新的进行替换
    if (T != AbstractType && share[name] is! T) {
      var t = create();
      if (t == null) {
        return null;
      }
      t.map = share[name]!.map;

      for (var kvp in share[name]!.map.entries) {
        Item? n = kvp.value;
        for (; n != null; n = n.left as Item?) {
          n.parent = t;
        }
      }

      t.start = share[name]!.start;
      for (var n = t.start; n != null; n = n.right as Item?) {
        n.parent = t;
      }

      t.length = share[name]!.length;

      share[name] = t;
      t.integrate(this, null);
      return t;
    }

    return share[name] as T;
  }

  Object toJson() {
    return share.map((key, value) => MapEntry(key, value.toJson()));
  }

  void applyUpdateV2FromStream(ByteArrayInputStream input,
      {Object? transactionOrigin, bool local = false}) {
    transact((tr) {
      var structDecoder = UpdateDecoderV2(input);
      EncodingUtils.readStructs(structDecoder, tr, store);
      store.readAndApplyDeleteSet(structDecoder, tr);
    }, origin: transactionOrigin, local: local);
  }

  void applyUpdateV2(Uint8List update,
      {Object? transactionOrigin, bool local = false}) {
    applyUpdateV2FromStream(ByteArrayInputStream(update),
        transactionOrigin: transactionOrigin, local: local);
  }

  Uint8List encodeStateAsUpdateV2([Uint8List? encodedTargetStateVector]) {
    var targetStateVector = encodedTargetStateVector != null
        ? EncodingUtils.decodeStateVector(encodedTargetStateVector)
        : <int, int>{};
    var encoder = UpdateEncoderV2(ByteArrayOutputStream(1024 * 1024));
    writeStateAsUpdate(encoder, targetStateVector);
    return encoder.toArray();
  }

  Uint8List encodeStateVectorV2() {
    var encoder = DSEncoderV2(ByteArrayOutputStream());
    writeStateVector(encoder);
    return encoder.toArray();
  }

  void writeStateAsUpdate(
      IUpdateEncoder encoder, Map<int, int> targetStateVector) {
    EncodingUtils.writeClientsStructs(encoder, store, targetStateVector);
    DeleteSet.store(store).write(encoder);
  }

  void writeStateVector(IDSEncoder encoder) {
    EncodingUtils.writeStateVector(encoder, store.getStateVector());
  }

  Map<Object,Function(Transaction transaction)> beforeObserverCalls = {};

  Map<Object,Function(Transaction transaction)> beforeTransaction = {};

  Map<Object,Function(Transaction transaction)> afterTransaction = {};

  Map<Object,Function(Transaction transaction)> afterTransactionCleanup = {};

  Map<Object,Function()> beforeAllTransactions = {};

  Map<Object,Function(List<Transaction> transactions)> afterAllTransactions = {};

  Map<Object,Function(Uint8List data, Object? origin, Transaction transaction)>
      updateV2 = {};

  List<Function()> destroyed = [];

  List<Function(Set<YDoc> loaded, Set<YDoc> added, Set<YDoc> removed)>
      subdocsChanged = [];

  void invokeSubdocsChanged(
      Set<YDoc> loaded, Set<YDoc> added, Set<YDoc> removed) {
    for (var element in subdocsChanged) {
      element.call(loaded, added, removed);
    }
  }

  void invokeOnBeforeObserverCalls(Transaction transaction) {
    for (var element in beforeObserverCalls.values) {
      element.call(transaction);
    }
  }

  void invokeAfterAllTransactions(List<Transaction> transactions) {
    for (var element in afterAllTransactions.values) {
      element.call(transactions);
    }
  }

  void invokeOnBeforeTransaction(Transaction transaction) {
    for (var element in beforeTransaction.values) {
      element.call(transaction);
    }
  }

  void invokeOnAfterTransaction(Transaction transaction) {
    for (var element in afterTransaction.values) {
      element.call(transaction);
    }
  }

  void invokeOnAfterTransactionCleanup(Transaction transaction) {
    for (var element in afterTransactionCleanup.values) {
      element.call(transaction);
    }
  }

  void invokeBeforeAllTransactions() {
    for (var element in beforeAllTransactions.values) {
      element.call();
    }
  }

  void invokeDestroyed() {
    for (var element in destroyed) {
      element.call();
    }
  }

  void invokeUpdateV2(Transaction transaction) {
    var handler = updateV2;
    if (handler.isNotEmpty) {
      var encoder = UpdateEncoderV2(ByteArrayOutputStream());
      var hasContent = transaction.writeUpdateMessageFromTransaction(encoder);
      if (hasContent) {
        var array = encoder.toArray();
        for (var element in handler.values) {
          element.call(array, transaction.origin, transaction);
        }
      }
    }
  }

  YDocOptions cloneOptionsWithNewGuid() {
    var newOpts = _opts.clone();
    newOpts.guid = const Uuid().v4();
    return newOpts;
  }

  String findRootTypeKey(AbstractType type) {
    for (var kvp in share.entries) {
      if (type == kvp.value) {
        return kvp.key;
      }
    }

    throw Exception();
  }

  Snapshot createSnapshot() => Snapshot(
      deleteSet: DeleteSet.store(store), stateVector: store.getStateVector());

  void load() {
    var item = this.item;
    if (item != null && !shouldLoad) {
      (item.parent as AbstractType).doc?.transact((tr) {
        tr.subdocsLoaded.add(this);
      }, origin: null, local: true);
    }
    shouldLoad = true;
  }

  List<String> getSubdocGuids() {
    return subdocs.map((e) => e.guid).toSet().toList();
  }

  void destroy() {
    for (var sd in subdocs) {
      sd.destroy();
    }

    var item = this.item;
    if (item != null) {
      this.item = null;
      var content = item.content;
      if (item.deleted) {
        if (content is ContentDoc) {
          content.doc = null;
        }
      } else {
        var content = item.content as ContentDoc?;
        var newOpts = content!.docOptions;
        newOpts.guid = guid;

        content.doc = YDoc(newOpts);
        content.doc!.item = item;
      }
      (item.parent as AbstractType).doc!.transact((tr) {
        if (!item.deleted && content is ContentDoc) {
          tr.subdocsAdded.add(content.doc!);
        }
        tr.subdocsRemoved.add(this);
      }, origin: null, local: true);
    }

    invokeDestroyed();
  }
}
