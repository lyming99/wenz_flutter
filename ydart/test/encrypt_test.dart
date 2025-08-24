import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/utils/encoding_utils.dart';
import 'package:ydart/utils/update_decoder_v2.dart';
import 'package:ydart/utils/update_encoder_v2.dart';

void main() {
  var docBytes = File('demo/newData.data').readAsBytesSync();
  var encode = encodeDoc(docBytes);
  assert(encode.length != docBytes.length);
  var decode = decodeDoc(encode);
  assert(decode.length == docBytes.length);
  for (var i = 0; i < decode.length; i++) {
    assert(decode[i] == docBytes[i]);
  }
}

typedef EncryptFunction = Uint8List Function(Uint8List);
typedef DecryptFunction = Uint8List Function(Uint8List);

class EncryptByteArrayInputStream extends ByteArrayInputStream {
  final DecryptFunction decrypt;

  EncryptByteArrayInputStream(super.bytes, this.decrypt);

  @override
  String readVarString() {
    int remainingLen = readVarUint();
    if (remainingLen == 0) {
      return '';
    }
    Uint8List data = readNBytes(remainingLen);
    var dec = decrypt.call(data);
    var str = String.fromCharCodes(dec);
    return Uri.decodeComponent(str);
  }
}

class EncryptByteArrayOutputStream extends ByteArrayOutputStream {
  final EncryptFunction encrypt;

  EncryptByteArrayOutputStream(this.encrypt);

  @override
  void writeVarString(String str) {
    var value = Uri.encodeComponent(str);
    var data = Uint8List.fromList(value.codeUnits);
    var enc = encrypt.call(data);
    writeVarUint(enc.length);
    writeBytes(enc);
  }
}

Uint8List decodeDoc(Uint8List fileBytes) {
  var encryptInputStream = EncryptByteArrayInputStream(fileBytes, (bytes) {
    return decode(bytes);
  });
  var encoder = UpdateEncoderV2(ByteArrayOutputStream(fileBytes.length));
  EncodingUtils.encrypt(UpdateDecoderV2(encryptInputStream), encoder);
  return encoder.toArray();
}

Uint8List encodeDoc(Uint8List fileBytes) {
  var encryptOutputStream = EncryptByteArrayOutputStream((bytes) {
    return encode(bytes);
  });
  var encoder = UpdateEncoderV2(encryptOutputStream);
  EncodingUtils.encrypt(
      UpdateDecoderV2(ByteArrayInputStream(fileBytes)), encoder);
  return encoder.toArray();
}

Uint8List decode(Uint8List data, [int version = -1]) {
  var key = Key.fromUtf8("12345678901234567890123456789012");
  var encrypt = Encrypter(AES(key));
  var result = encrypt.decryptBytes(Encrypted(data),
      iv: IV.fromUtf8("1234567890123456"));
  return Uint8List.fromList(result);
}

Uint8List encode(Uint8List data, [int version = -1]) {
  var key = Key.fromUtf8("12345678901234567890123456789012");
  var encrypt = Encrypter(AES(key));
  var result = encrypt.encryptBytes(data, iv: IV.fromUtf8("1234567890123456"));
  return result.bytes;
}
