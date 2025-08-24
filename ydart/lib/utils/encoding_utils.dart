import 'dart:typed_data';

import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../lib0/constans.dart';
import '../structs/abstract_struct.dart';
import '../structs/base_content.dart';
import '../structs/content_any.dart';
import '../structs/content_binary.dart';
import '../structs/content_deleted.dart';
import '../structs/content_doc.dart';
import '../structs/content_embed.dart';
import '../structs/content_format.dart';
import '../structs/content_json.dart';
import '../structs/content_string.dart';
import '../structs/content_type.dart';
import '../structs/gc.dart';
import '../structs/item.dart';
import 'id.dart';
import 'update_decoder.dart';
import 'update_decoder_v2.dart';
import 'update_encoder.dart';
import 'y_doc.dart';

class EncodingUtils {
  static IContentEx readItemContent(IUpdateDecoder decoder, int info) {
    switch (info & Bits.bits5) {
      case 0: // GC
        throw Exception('GC is not ItemContent');
      case 1: // Deleted
        return ContentDeleted.read(decoder);
      case 2: // JSON
        return ContentJson.read(decoder);
      case 3: // Binary
        return ContentBinary.read(decoder);
      case 4: // String
        return ContentString.read(decoder);
      case 5: // Embed
        return ContentEmbed.read(decoder);
      case 6: // Format
        return ContentFormat.read(decoder);
      case 7: // Type
        return ContentType.read(decoder);
      case 8: // Any
        return ContentAny.read(decoder);
      case 9: // Doc
        return ContentDoc.read(decoder);
      default:
        throw Exception('Content type not recognized: $info');
    }
  }

  static void readStructs(
      IUpdateDecoder decoder, Transaction transaction, StructStore store) {
    var clientStructRefs = readClientStructRefs(decoder, transaction.doc);
    store.mergeReadStructsIntoPendingReads(clientStructRefs);
    store.integrateStructs(transaction);
    store.cleanupPendingStructs();
    store.tryResumePendingDeleteReaders(transaction);
  }

  static void writeStructs(IUpdateEncoder encoder, List<AbstractStruct> structs,
      int client, int clock) {
    int startNewStructs = StructStore.findIndexSS(structs, clock);

    encoder.restWriter
        .writeVarUint((structs.length - startNewStructs).toUnsigned(32));
    encoder.writeClient(client);
    encoder.restWriter.writeVarUint(clock.toUnsigned(32));
    var firstStruct = structs[startNewStructs];
    firstStruct.write(encoder, clock - firstStruct.id.clock);
    for (int i = startNewStructs + 1; i < structs.length; i++) {
      structs[i].write(encoder, 0);
    }
  }

  static void writeClientsStructs(
      IUpdateEncoder encoder, StructStore store, Map<int, int> _sm) {
    var sm = <int, int>{};
    _sm.forEach((client, clock) {
      if (store.getState(client) > clock) {
        sm[client] = clock;
      }
    });

    store.getStateVector().forEach((client, _) {
      if (!_sm.containsKey(client)) {
        sm[client] = 0;
      }
    });

    encoder.restWriter.writeVarUint(sm.length.toUnsigned(32));

    var sortedClients = sm.keys.toList()..sort((a, b) => b.compareTo(a));

    for (var client in sortedClients) {
      writeStructs(encoder, store.clients[client]!, client, sm[client]!);
    }
  }

  static void encrypt(IUpdateDecoder decoder, IUpdateEncoder encoder) {
    // structs
    var numOfStateUpdates = decoder.reader.readVarUint();
    encoder.restWriter.writeVarUint(numOfStateUpdates);
    for (var i = 0; i < numOfStateUpdates; i++) {
      var numberOfStructs = decoder.reader.readVarUint();
      encoder.restWriter.writeVarUint(numberOfStructs);
      var client = decoder.readClient();
      encoder.writeClient(client);
      var clock = decoder.reader.readVarUint();
      encoder.restWriter.writeVarUint(clock);
      for (var j = 0; j < numberOfStructs; j++) {
        var info = decoder.readInfo();
        encoder.writeInfo(info);
        if ((Bits.bits5 & info) != 0) {
          if ((info & Bit.bit8) == Bit.bit8) {
            encoder.writeLeftId(decoder.readLeftId());
          }
          if ((info & Bit.bit7) == Bit.bit7) {
            encoder.writeRightId(decoder.readRightId());
          }
          var cantCopyParentInfo = (info & (Bit.bit7 | Bit.bit8)) == 0;
          var hasParentYKey =
              cantCopyParentInfo ? decoder.readParentInfo() : false;
          if (cantCopyParentInfo) {
            encoder.writeParentInfo(hasParentYKey);
          }
          var parentYKey =
              cantCopyParentInfo && hasParentYKey ? decoder.readString() : null;
          if (cantCopyParentInfo && hasParentYKey) {
            encoder.writeString(parentYKey!);
          }
          if (cantCopyParentInfo && !hasParentYKey) {
            encoder.writeLeftId(decoder.readLeftId());
          }
          if (cantCopyParentInfo && (info & Bit.bit6) == Bit.bit6) {
            encoder.writeString(decoder.readString());
          }
          readItemContent(decoder, info).write(encoder, 0);
        } else {
          var length = decoder.readLength();
          encoder.writeLength(length);
        }
      }
    }

    // delete set
    var numClients = decoder.reader.readVarUint();
    encoder.restWriter.writeVarUint(numClients);
    for (int i = 0; i < numClients; i++) {
      decoder.resetDsCurVal();
      encoder.resetDsCurVal();
      var client = decoder.reader.readVarUint();
      encoder.restWriter.writeVarUint(client);
      var numberOfDeletes = decoder.reader.readVarUint();
      encoder.restWriter.writeVarUint(numberOfDeletes);
      for (int j = 0; j < numberOfDeletes; j++) {
        var clock = decoder.readDsClock();
        encoder.writeDsClock(clock);
        var dsLength = decoder.readDsLength();
        encoder.writeDsLength(dsLength);
      }
    }
  }

  static Map<int, List<AbstractStruct>> readClientStructRefs(
      IUpdateDecoder decoder, YDoc doc) {
    var clientRefs = <int, List<AbstractStruct>>{};
    var numOfStateUpdates = decoder.reader.readVarUint();
    for (var i = 0; i < numOfStateUpdates; i++) {
      var numberOfStructs = decoder.reader.readVarUint();
      assert(numberOfStructs >= 0);
      var refs = <AbstractStruct>[];
      var client = decoder.readClient();
      var clock = decoder.reader.readVarUint();
      clientRefs[client] = refs;
      for (var j = 0; j < numberOfStructs; j++) {
        var info = decoder.readInfo();
        if ((Bits.bits5 & info) != 0) {
          var leftOrigin =
              (info & Bit.bit8) == Bit.bit8 ? decoder.readLeftId() : null;
          var rightOrigin =
              (info & Bit.bit7) == Bit.bit7 ? decoder.readRightId() : null;
          var cantCopyParentInfo = (info & (Bit.bit7 | Bit.bit8)) == 0;
          var hasParentYKey =
              cantCopyParentInfo ? decoder.readParentInfo() : false;
          var parentYKey =
              cantCopyParentInfo && hasParentYKey ? decoder.readString() : null;

          var str = Item.create(
            ID.create(client, clock),
            null,
            leftOrigin,
            null,
            rightOrigin,
            cantCopyParentInfo && !hasParentYKey
                ? decoder.readLeftId()
                : (parentYKey != null
                    ? doc.get<AbstractType>(parentYKey, () => AbstractType())
                    : null),
            cantCopyParentInfo && (info & Bit.bit6) == Bit.bit6
                ? decoder.readString()
                : null,
            readItemContent(decoder, info),
          );
          refs.add(str);
          clock += str.length;
        } else {
          var length = decoder.readLength();
          refs.add(GC.create(ID.create(client, clock), length));
          clock += length;
        }
      }
    }

    return clientRefs;
  }

  static void writeStateVector(IDSEncoder encoder, Map<int, int> sv) {
    encoder.restWriter.writeVarUint(sv.length.toUnsigned(32));

    sv.forEach((client, clock) {
      encoder.restWriter.writeVarUint(client.toUnsigned(32));
      encoder.restWriter.writeVarUint(clock.toUnsigned(32));
    });
  }

  static Map<int, int> readStateVector(IDSDecoder decoder) {
    var ssLength = decoder.reader.readVarUint().toInt();
    var ss = <int, int>{};

    for (var i = 0; i < ssLength; i++) {
      var client = decoder.reader.readVarUint().toInt();
      var clock = decoder.reader.readVarUint().toInt();
      ss[client] = clock;
    }

    return ss;
  }

  static Map<int, int> decodeStateVector(Uint8List input) {
    if (input.isEmpty) {
      return {};
    }
    return readStateVector(DSDecoderV2(ByteArrayInputStream(input)));
  }
}
