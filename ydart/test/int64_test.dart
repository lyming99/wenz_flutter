import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';

void main() {
  var max = 9223372036854775807;
  var min = -9223372036854775808;
  checkTest(min);
  checkTest(max);
}

void checkTest(int i) {
  var output = ByteArrayOutputStream()..writeUint64(i);
  var bytes = output.toByteArray();
  var r = ByteArrayInputStream(bytes).readUint64();
  print("$r==$i");
  assert(r == i);
}
