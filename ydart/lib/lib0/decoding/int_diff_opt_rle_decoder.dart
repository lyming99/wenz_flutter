import 'package:ydart/lib0/byte_input_stream.dart';

import '../constans.dart';
import 'abstract_stream_decoder.dart';

class IntDiffOptRleDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;
  int _diff = 0;

  IntDiffOptRleDecoder(ByteArrayInputStream input, {bool leaveOpen = false})
      : super(input, leaveOpen: leaveOpen);

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      int diff = stream.readVarInt();

      bool hasCount = (diff & Bit.bit1) > 0;

      if (diff < 0) {
        _diff = -((-diff) >> 1);
      } else {
        _diff = diff >> 1;
      }

      _count = hasCount ? stream.readVarUint() + 2 : 1;
    }

    _state += _diff;
    _count--;
    return _state;
  }
}
