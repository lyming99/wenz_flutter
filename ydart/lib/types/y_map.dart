/// 完成1次review
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/update_decoder.dart';

import '../structs/item.dart';
import '../utils/encoding.dart';
import '../utils/transaction.dart';
import '../utils/update_encoder.dart';
import '../utils/y_doc.dart';
import '../utils/y_event.dart';

const yMapRefId = 1;

class YMapEvent extends YEvent {
  Set<String> keysChanged;

  YMapEvent(
    super.target,
    super.transaction,
    this.keysChanged,
  );
}

class YMap extends AbstractType {
  final Map<String, Object?> _prelimContent = {};

  @override
  int get length => _prelimContent.length;

  Object? get(String key) {
    return tryTypeMapGet(key);
  }

  Object? getPrelim(String key) {
    return _prelimContent[key];
  }

  void set(String key, Object? value) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        typeMapSet(tr, key, value);
      });
    } else {
      _prelimContent[key] = value;
    }
  }

  void delete(String key) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        typeMapDelete(tr, key);
      });
    } else {
      _prelimContent.remove(key);
    }
  }

  bool containsKey(String key) {
    var item = map[key];
    return item != null && !item.deleted;
  }

  @override
  void integrate(YDoc? doc, Item? item) {
    super.integrate(doc, item);
    for (var kvp in _prelimContent.entries) {
      set(kvp.key, kvp.value);
    }
    _prelimContent.clear();
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    callTypeObservers(transaction, YMapEvent(this, transaction, parentSubs));
  }

  @override
  void write(IUpdateEncoder encoder) {
    encoder.writeTypeRef(yMapRefId);
  }

  @override
  AbstractType internalCopy() {
    return YMap();
  }

  static YMap read(IUpdateDecoder decoder) {
    return YMap();
  }

  Map<String, Object?>? toJsonMap() {
    return typeMapEnumerateValues()
        .map((key, value) => MapEntry(key, contentToJsonValue(value)));
  }
}
