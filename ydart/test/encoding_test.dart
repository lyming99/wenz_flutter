import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydart/lib0/byte_output_stream.dart';

void main() {
  test('Check if binary encoding is compatible with golang binary encoding', () {
    expect(writeVarUint(0), [0]);
    expect(writeVarUint(1), [1]);
    expect(writeVarUint(128), [128, 1]);
    expect(writeVarUint(200), [200, 1]);
    expect(writeVarUint(32), [32]);
    expect(writeVarUint(500), [244, 3]);
    expect(writeVarUint(256), [128, 2]);
    expect(writeVarUint(700), [188, 5]);
    expect(writeVarUint(1024), [128, 8]);
    expect(writeVarUint(1025), [129, 8]);
    expect(writeVarUint(4048), [208, 31]);
    expect(writeVarUint(5050), [186, 39]);
    expect(writeVarUint(1000000), [192, 132, 61]);
    expect(writeVarUint(34951959), [151, 166, 213, 16]);
    expect(writeVarUint(2147483646), [254, 255, 255, 255, 7]);
    expect(writeVarUint(2147483647), [255, 255, 255, 255, 7]);
    expect(writeVarUint(2147483648), [128, 128, 128, 128, 8]);
    expect(writeVarUint(2147483700), [180, 128, 128, 128, 8]);
    expect(writeVarUint(4294967294), [254, 255, 255, 255, 15]);
    expect(writeVarUint(4294967295), [255, 255, 255, 255, 15]);
  });
}

Uint8List writeVarUint(int value) {
  var out = ByteArrayOutputStream()..writeVarUint(value);
  return out.toByteArray();
}
