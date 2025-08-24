import 'package:ydart/lib0/byte_input_stream.dart';

import 'abstract_stream_decoder.dart';

class RleIntDiffDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;

  RleIntDiffDecoder(super.input, int start, {super.leaveOpen = false}) {
    _state = start;
  }

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      _state += stream.readVarInt();

      if (hasContent) {
        _count = stream.readVarUint() + 1;
        assert(_count > 0);
      } else {
        // Read the current value forever.
        _count = -1;
      }
    }

    _count--;
    return _state;
  }
}
