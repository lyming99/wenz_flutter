import 'dart:typed_data';

import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/utils/id.dart';

import '../structs/item.dart';
import '../types/abstract_type.dart';

class RelativePosition {
  final int assoc;
  final ID? item;
  final ID? typeId;
  final String? tName;

  RelativePosition({this.assoc = 0, this.item, this.typeId, this.tName});

  factory RelativePosition.fromTypeItem(AbstractType type, ID? item,
      [int assoc = 0]) {
    String? tName;
    ID? typeId;
    if (type.item == null) {
      tName = type.findRootTypeKey();
    } else {
      typeId = ID.create(type.item!.id.clock, type.item!.id.clock);
    }
    var ret = RelativePosition(
        item: item, assoc: assoc, tName: tName, typeId: typeId);
    return ret;
  }

  factory RelativePosition.fromTypeIndex(AbstractType type, int index,
      [int assoc = 0]) {
    if (assoc < 0) {
      if (index == 0) {
        return RelativePosition.fromTypeItem(type, type.item?.id, assoc);
      }
      index--;
    }

    var tempItem = type.start;
    while (tempItem != null) {
      if (!tempItem.deleted && tempItem.countable) {
        if (tempItem.length > index) {
          return RelativePosition.fromTypeItem(
              type, ID.create(tempItem.id.client, tempItem.id.clock + index),
              assoc);
        }
        index -= tempItem.length;
      }
      if (tempItem.right == null && assoc < 0) {
        return RelativePosition.fromTypeItem(type, tempItem.lastId, assoc);
      }
      tempItem = tempItem.right as Item?;
    }
    return RelativePosition(typeId: type.item?.id, assoc: assoc);
  }

  void write(ByteArrayOutputStream writer) {
    if (item != null) {
      writer.writeVarUint(0);
      item!.write(writer);
    } else if (tName != null) {
      writer.writeVarUint(1);
      writer.writeVarString(tName!);
    } else if (typeId != null) {
      writer.writeVarUint(2);
      typeId!.write(writer);
    } else {
      throw Exception();
    }

    writer.writeVarInt(assoc!, treatZeroAsNegative: false);
  }

  static RelativePosition read(ByteArrayInputStream reader) {
    ID? itemId;
    ID? typeId;
    String? tName;

    switch (reader.readVarUint()) {
      case 0:
        itemId = ID.read(reader);
        break;
      case 1:
        tName = reader.readVarString();
        break;
      case 2:
        typeId = ID.read(reader);
        break;
      default:
        throw Exception();
    }

    int assoc = reader.pos < reader.count ? reader.readVarInt() : 0;
    return RelativePosition(
        typeId: typeId, tName: tName, item: itemId, assoc: assoc);
  }

  Uint8List toArray() {
    final stream = ByteArrayOutputStream();
    write(stream);
    return stream.toByteArray();
  }
}
